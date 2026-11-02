# Freeciv for AmigaOS 3.x (AmiCradle)

Freeciv, the open Civilization II-style strategy game, for AmigaOS 3.x on a
68040 with FPU (`-m68040 -m68881`), libnix, GCC 16.2.0-open3. It is built
from this repository's own tree: upstream Freeciv
[`900908ae`](https://github.com/freeciv/freeciv/commit/900908ae2c3b7ce69352edb4188036f9d576960f)
(3.4 development, GPL-2.0-or-later), with the Amiga changes kept as patches
in `patches/`, so the upstream files stay as they were imported.

A single-player game is the server (`freeciv-server`) and the SDL2 client
(`freeciv-sdl2`) on the same Amiga, talking over a loopback TCP connection
through `bsdsocket.library` (GFOpenSocket). The feasibility note and build
plan are in [FEASIBILITY.md](FEASIBILITY.md).

This is TESTING work, not a RELEASE ([RELEASE_POLICY.md](RELEASE_POLICY.md)).

## Status

Plan only: [FEASIBILITY.md](FEASIBILITY.md) sets out what the GF SDK
already has, what the port brings (zlib, a small ICU subset, the OpenSocket
headers) and what it leaves out (libcurl, SQLite, NLS, sound), and the
steps: server headless, SDL2 client, client and server together on one
Amiga, a few turns with save and load, then measurement.

## Observed

Nothing observed yet; see the pull requests that add each step.
