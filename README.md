# Any2Play

**Any2Play** is an early-stage fork of [chiaki-ng](https://github.com/chiaki-ng/chiaki-ng)
focused on low latency and on GPU upscaling of the stream (up to 1080p) to 1440p
and 4K displays. Windows comes first, then Android and iOS.

- It builds on chiaki-ng's open-source implementation of the protocol; it does
  not reverse engineer Sony's official client.
- Latency work is driven by measurement: per-stage timings, including the GPU
  cost of each upscaler, rather than guesses.
- License: AGPL-3.0, the same as upstream.

Building on Windows: see [scripts/any2play](scripts/any2play/README.md).

Any2Play is not affiliated with, endorsed or certified by Sony Interactive
Entertainment. PlayStation and PS5 are trademarks of Sony Interactive
Entertainment Inc.

The upstream chiaki-ng README follows.

---

![chiaki-ng Logo](gui/res/chiaking-logo.svg)

# [chiaki-ng](https://streetpea.github.io/chiaki-ng/)

An open source PlayStation remote play project serving as the next-generation of Chiaki with improvements and ongoing support now that the original Chiaki project is in maintenance mode only. [Click here to see the accompanying site for documentation, updates and more](https://streetpea.github.io/chiaki-ng/).

## Discord
[chiaki-ng community Discord](https://discord.gg/tAMbRuwXDH)

## Disclaimer
This project is not endorsed or certified by Sony Interactive Entertainment LLC.

Chiaki is a Free and Open Source Software Client for PlayStation 4 and PlayStation 5 Remote Play
for Linux, FreeBSD, OpenBSD, Android, macOS, Windows, Nintendo Switch and potentially even more platforms.
