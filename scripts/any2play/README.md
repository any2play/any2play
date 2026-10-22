# Building Any2Play on Windows (MSYS2 UCRT64)

A development build that mirrors upstream's MSYS2 CI, using the UCRT64
environment because MSYS2 no longer ships every dependency for MINGW64.

1. Install [MSYS2](https://www.msys2.org/) and open the **MSYS2 UCRT64** shell.
2. From the repository root:

   ```bash
   scripts/any2play/build-client-ucrt64.sh all
   ```

   Steps can also run one at a time: `packages` (pacman dependencies), `deps`
   (libplacebo, FFmpeg n7.1, SDL3 and sdl2-compat, installed into `/ucrt64`),
   `configure` and `build`. Third-party sources go to `deps/` next to the clone;
   set `ANY2PLAY_DEPS_DIR` to put them elsewhere.
3. Run the build without packaging by double-clicking
   `scripts\any2play\run-client.cmd`. It finds MSYS2 through `MSYS2_ROOT`,
   `C:\msys64` or `%USERPROFILE%\Tools\msys64`; pass `-Msys2Root <dir>` otherwise.
