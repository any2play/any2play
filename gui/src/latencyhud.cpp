// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#include "latencyhud.h"

#include <chiaki/time.h>

#include <libplacebo/renderer.h>

extern "C" {
#include <libavutil/dict.h>
#include <libavutil/frame.h>
}

#include <QMutexLocker>
#include <QStringList>

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <iterator>
#include <utility>

namespace {

constexpr char upscale_pass_prefix[] = "upscale: ";
constexpr char arrival_metadata_key[] = "any2play_arrival_us";
constexpr qint64 window_us = 1000000;
// Bounds memory if publish() stops being called (e.g. no frames rendered).
constexpr int max_samples_per_stage = 4096;

struct StageNames {
    const char *hud;
    const char *log;
};

constexpr StageNames stage_names[] = {
    {"frame age", "frame_age"},
    {"decode", "decode"},
    {"GPU frame", "gpu_frame"},
    {"upscaler GPU", "gpu_upscale"},
    {"render CPU", "render_cpu"},
    {"acquire wait", "acquire_wait"},
    {"submit", "submit"},
    {"present call", "present"},
};
static_assert(std::size(stage_names) == static_cast<size_t>(LatencyHud::Stage::Count),
              "stage_names must cover every LatencyHud::Stage");

struct LabelRoute {
    const char *label;
    LatencyHud::Stage stage;
};

constexpr LabelRoute label_routes[] = {
    {"render_image", LatencyHud::Stage::RenderCpu},
    {"start_frame_block", LatencyHud::Stage::AcquireWait},
    {"submit_call", LatencyHud::Stage::Submit},
    {"swap_call", LatencyHud::Stage::Present},
};

}

LatencyHud &LatencyHud::instance()
{
    static LatencyHud hud;
    return hud;
}

QByteArray LatencyHud::tagUpscaleShader(const QByteArray &shader)
{
    QByteArray tagged = shader;
    tagged.replace("//!DESC ", QByteArray("//!DESC ") + upscale_pass_prefix);
    return tagged;
}

void LatencyHud::plInfoCallback(void *priv, const struct pl_render_info *info)
{
    auto *hud = static_cast<LatencyHud *>(priv);
    const struct pl_dispatch_info *pass = info ? info->pass : nullptr;
    // Timer results arrive asynchronously; num_samples stays 0 until the GPU
    // has reported at least one execution, or forever without timer queries.
    if (!hud || !pass || pass->num_samples <= 0)
        return;

    hud->frame_timed = true;
    hud->frame_gpu_ns += pass->last;
    const char *description = pass->shader ? pass->shader->description : nullptr;
    if (description && std::strncmp(description, upscale_pass_prefix, sizeof(upscale_pass_prefix) - 1) == 0)
        hud->frame_upscale_ns += pass->last;
}

void LatencyHud::setFrameArrival(AVFrame *frame, quint64 arrival_us)
{
    if (frame && arrival_us > 0)
        av_dict_set_int(&frame->metadata, arrival_metadata_key, static_cast<int64_t>(arrival_us), 0);
}

quint64 LatencyHud::frameArrival(const AVFrame *frame)
{
    if (!frame)
        return 0;
    const AVDictionaryEntry *entry = av_dict_get(frame->metadata, arrival_metadata_key, nullptr, 0);
    return entry ? std::strtoull(entry->value, nullptr, 10) : 0;
}

void LatencyHud::noteRenderedFrame(quint64 arrival_us)
{
    rendered_arrival_us.store(arrival_us, std::memory_order_relaxed);
}

void LatencyHud::addSample(Stage stage, qint64 delta_us)
{
    if (delta_us < 0)
        return;
    QMutexLocker locker(&mutex);
    QVector<qint64> &stage_samples = samples[static_cast<size_t>(stage)];
    if (stage_samples.size() < max_samples_per_stage)
        stage_samples.append(delta_us);
}

void LatencyHud::addLabeledSample(const char *label, qint64 delta_us)
{
    if (!label)
        return;
    if (std::strcmp(label, "swap_call") == 0) {
        // The present that shows the last rendered frame just returned. Count a
        // frame's age only on its first present; repeats would inflate it.
        const quint64 arrival_us = rendered_arrival_us.load(std::memory_order_relaxed);
        if (arrival_us > 0 && presented_arrival_us.exchange(arrival_us, std::memory_order_relaxed) != arrival_us) {
            const quint64 now_us = chiaki_time_now_monotonic_us();
            if (now_us >= arrival_us)
                addSample(Stage::FrameAge, static_cast<qint64>(now_us - arrival_us));
        }
    }
    for (const LabelRoute &route : label_routes) {
        if (std::strcmp(label, route.label) == 0) {
            addSample(route.stage, delta_us);
            return;
        }
    }
}

void LatencyHud::beginRender()
{
    frame_gpu_ns = 0;
    frame_upscale_ns = 0;
    frame_timed = false;
}

void LatencyHud::endRender()
{
    if (!frame_timed)
        return;
    addSample(Stage::GpuFrame, static_cast<qint64>(frame_gpu_ns / 1000));
    // Frames re-rendered from libplacebo's cache skip the upscaler entirely.
    if (frame_upscale_ns > 0)
        addSample(Stage::GpuUpscale, static_cast<qint64>(frame_upscale_ns / 1000));
}

LatencyHud::Summary LatencyHud::summarize(QVector<qint64> &samples_us)
{
    Summary summary;
    summary.count = samples_us.size();
    if (samples_us.isEmpty())
        return summary;

    std::sort(samples_us.begin(), samples_us.end());
    qint64 sum_us = 0;
    for (qint64 sample_us : samples_us)
        sum_us += sample_us;
    const int p99_index = std::max(0, static_cast<int>(std::ceil(0.99 * samples_us.size())) - 1);
    summary.avg_ms = static_cast<double>(sum_us) / 1000.0 / samples_us.size();
    summary.p99_ms = samples_us[p99_index] / 1000.0;
    summary.max_ms = samples_us.last() / 1000.0;
    return summary;
}

bool LatencyHud::publish(qint64 now_us, QString *hud_text, QString *log_line)
{
    std::array<QVector<qint64>, static_cast<size_t>(Stage::Count)> window;
    qint64 window_length_us = 0;
    {
        QMutexLocker locker(&mutex);
        if (window_start_us == 0) {
            window_start_us = now_us;
            return false;
        }
        window_length_us = now_us - window_start_us;
        if (window_length_us < window_us)
            return false;
        std::swap(window, samples);
        window_start_us = now_us;
    }

    QStringList hud_lines;
    QStringList log_parts;
    for (size_t i = 0; i < window.size(); i++) {
        const Summary summary = summarize(window[i]);
        if (summary.count == 0)
            continue;
        hud_lines << QStringLiteral("%1 %2 / %3")
            .arg(QString::fromLatin1(stage_names[i].hud), -13)
            .arg(summary.avg_ms, 5, 'f', 2)
            .arg(summary.p99_ms, 5, 'f', 2);
        log_parts << QStringLiteral("%1 n=%2 avg=%3 p99=%4 max=%5")
            .arg(QString::fromLatin1(stage_names[i].log))
            .arg(summary.count)
            .arg(summary.avg_ms, 0, 'f', 3)
            .arg(summary.p99_ms, 0, 'f', 3)
            .arg(summary.max_ms, 0, 'f', 3);
    }
    if (hud_lines.isEmpty())
        return false;

    if (hud_text) {
        const QString header = QStringLiteral("%1 %2 / %3")
            .arg(QStringLiteral("ms"), -13)
            .arg(QStringLiteral("avg"), 5)
            .arg(QStringLiteral("p99"), 5);
        *hud_text = header + QLatin1Char('\n') + hud_lines.join(QLatin1Char('\n'));
    }
    if (log_line)
        *log_line = QStringLiteral("[any2play] latency window_ms=%1 | %2")
            .arg(window_length_us / 1000)
            .arg(log_parts.join(QStringLiteral(" | ")));
    return true;
}

void LatencyHud::reset()
{
    QMutexLocker locker(&mutex);
    for (QVector<qint64> &stage_samples : samples)
        stage_samples.clear();
    window_start_us = 0;
    rendered_arrival_us.store(0, std::memory_order_relaxed);
    presented_arrival_us.store(0, std::memory_order_relaxed);
}
