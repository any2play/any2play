// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#ifndef CHIAKI_LATENCYHUD_H
#define CHIAKI_LATENCYHUD_H

#include <QByteArray>
#include <QMutex>
#include <QString>
#include <QVector>

#include <array>

struct pl_render_info;

// Any2Play: rolling per-stage latency statistics for the stream stats overlay
// and the session log. Each stage keeps its own one-second window (upstream's
// logLatencyStats() shares one accumulator across most labels), and GPU time
// comes from libplacebo's per-pass timer queries instead of CPU timestamps.
class LatencyHud
{
public:
    enum class Stage {
        GpuFrame,    // sum of libplacebo pass GPU times for one rendered frame
        GpuUpscale,  // part of GpuFrame spent in upscaler user shaders
        RenderCpu,   // pl_render_image() call
        AcquireWait, // pl_swapchain_start_frame() blocking for an image
        Submit,      // pl_swapchain_submit_frame() call
        Present,     // pl_swapchain_swap_buffers() call
        Count
    };

    static LatencyHud &instance();

    // Prefixes every //!DESC of an mpv-style upscaler shader so its passes can
    // be told apart from libplacebo's own passes in the info callback.
    static QByteArray tagUpscaleShader(const QByteArray &shader);

    // pl_render_params::info_callback; priv must point to a LatencyHud.
    static void plInfoCallback(void *priv, const struct pl_render_info *info);

    void addSample(Stage stage, qint64 delta_us);
    // Routes upstream logLatencyStats() labels to stages; other labels are ignored.
    void addLabeledSample(const char *label, qint64 delta_us);

    // Bracket a pl_render_image*() call on the render thread.
    void beginRender();
    void endRender();

    // Closes the current window once it is at least a second old. Returns false
    // while the window is still open or when it had no samples.
    bool publish(qint64 now_us, QString *hud_text, QString *log_line);
    void reset();

private:
    struct Summary {
        int count = 0;
        double avg_ms = 0.0;
        double p99_ms = 0.0;
        double max_ms = 0.0;
    };
    static Summary summarize(QVector<qint64> &samples_us);

    QMutex mutex;
    std::array<QVector<qint64>, static_cast<size_t>(Stage::Count)> samples;
    qint64 window_start_us = 0;

    // Render thread only, between beginRender() and endRender().
    quint64 frame_gpu_ns = 0;
    quint64 frame_upscale_ns = 0;
    bool frame_timed = false;
};

#endif // CHIAKI_LATENCYHUD_H
