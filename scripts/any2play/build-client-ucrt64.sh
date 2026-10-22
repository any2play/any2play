#!/bin/bash
# Any2Play dev build for Windows under MSYS2 UCRT64.
#
# Mirrors upstream .github/workflows/build-pr.yaml, with two deviations:
#   - UCRT64 instead of MINGW64: MSYS2 dropped hidapi (and is phasing out the
#     rest) from the MINGW64 repo, so the upstream package list no longer
#     resolves there.
#   - Third-party sources (libplacebo, SDL3, sdl2-compat, FFmpeg) live outside
#     the repository, in $ANY2PLAY_DEPS_DIR (default: deps/ next to the clone).
#
# Run from an MSYS2 UCRT64 shell:
#   scripts/any2play/build-client-ucrt64.sh [packages|deps|configure|build|all]

set -euo pipefail

[ "${MSYSTEM:-}" = "UCRT64" ] || { echo "run from an MSYS2 UCRT64 shell" >&2; exit 1; }

CLIENT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPS="${ANY2PLAY_DEPS_DIR:-$(cd "$CLIENT/.." && pwd)/deps}"
PREFIX=/ucrt64
LIBPLACEBO_VERSION="${LIBPLACEBO_VERSION:-3be579e6c7f6b421d9ac3ab4860edc437c50b3eb}"
FFMPEG_NAME=ffmpeg-n7.1-latest-win64-gpl-shared-7.1
FFMPEG_URL="https://github.com/streetpea/FFmpeg-Builds/releases/download/latest/$FFMPEG_NAME.zip"
FFMPEG_DIR="$DEPS/ffmpeg/$FFMPEG_NAME"

# Same set as build-pr.yaml (pacboy names), plus python-protobuf from pacman
# instead of pip, which MSYS2's Python refuses (PEP 668).
PACKAGES=(ca-certificates cmake curl fast_float fftw hidapi json-c libevent lcms2
    libdovi meson miniupnpc gcc nasm ninja openssl opus pkgconf protobuf python
    python-protobuf python-psutil python-glad python-jinja python-pip qt6-base
    qt6-declarative qt6-svg shaderc speexdsp spirv-cross vulkan-loader vulkan-headers)

install_packages() {
    pacman -S --needed --noconfirm git diffutils make unzip zip \
        "${PACKAGES[@]/#/mingw-w64-ucrt-x86_64-}"
}

build_deps() {
    mkdir -p "$DEPS"

    # libplacebo (same pin and options as scripts/build-libplacebo-windows.sh)
    if [ ! -d "$DEPS/libplacebo" ]; then
        git clone --recursive https://github.com/haasn/libplacebo.git "$DEPS/libplacebo"
    fi
    git -C "$DEPS/libplacebo" checkout "$LIBPLACEBO_VERSION"
    git -C "$DEPS/libplacebo" submodule update --init --recursive
    meson setup --reconfigure --prefix "$PREFIX" -Dxxhash=disabled "$DEPS/libplacebo/build" "$DEPS/libplacebo"
    ninja -C "$DEPS/libplacebo/build"
    ninja -C "$DEPS/libplacebo/build" install

    # FFmpeg n7.1 shared (prebuilt, same asset as upstream CI)
    if [ ! -d "$FFMPEG_DIR" ]; then
        mkdir -p "$DEPS/ffmpeg"
        curl -fL -o "$DEPS/ffmpeg/$FFMPEG_NAME.zip" "$FFMPEG_URL"
        unzip -q -o "$DEPS/ffmpeg/$FFMPEG_NAME.zip" -d "$DEPS/ffmpeg"
    fi
    cp -a "$FFMPEG_DIR/bin/." "$PREFIX/bin"
    cp -a "$FFMPEG_DIR/include/." "$PREFIX/include"
    cp -a "$FFMPEG_DIR/lib/." "$PREFIX/lib"

    # SDL3 + sdl2-compat (upstream script takes a dir relative to the client root)
    INSTALL_PREFIX="$PREFIX" "$CLIENT/scripts/build-sdl2-compat.sh" "$(realpath --relative-to="$CLIENT" "$DEPS")"
    cp "$PREFIX/lib/pkgconfig/sdl2-compat.pc" "$PREFIX/lib/pkgconfig/sdl2.pc"
}

configure() {
    cmake -S "$CLIENT" -B "$CLIENT/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCHIAKI_ENABLE_CLI=OFF
}

build() {
    cmake --build "$CLIENT/build" --target chiaki
}

case "${1:-all}" in
    packages) install_packages ;;
    deps) build_deps ;;
    configure) configure ;;
    build) build ;;
    all) install_packages; build_deps; configure; build ;;
    *) echo "usage: $0 [packages|deps|configure|build|all]" >&2; exit 1 ;;
esac
