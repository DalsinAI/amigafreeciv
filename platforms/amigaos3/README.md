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

## Building

Linux host with `bash`, `curl`, `git`, `python3`, `meson` (0.63 or later),
`ninja`, `pkg-config` and a host `gcc` (for the `tolua` generator):

```sh
bash platforms/amigaos3/build_sdk.sh /tmp/fc-sdk              # once
bash platforms/amigaos3/build-amigaos3.sh /tmp/fc-sdk /tmp/fc-out server
```

`build_sdk.sh` fetches only pinned inputs (the open3 compiler release, the
OpenSocket headers, zlib 1.3.1) and checks each against its SHA-256 or
commit. `build-amigaos3.sh` exports the tree at `HEAD` (or `REF=`), applies
`patches/` with no fuzz, configures with Meson for the cross target and
builds offline. `/tmp/fc-out/freeciv` is the drawer to copy to the Amiga;
`receipt.json` records the commit, patch and executable hashes.

The Cradle builds the same with `stove_build` (target `platforms/amigaos3`,
script `build-amiga.sh`), which also packs the data drawer into
`FreecivData.tar` and builds `UnTar` to unpack it on the Amiga.

## What is left out, and why

| Upstream part | Here | Why |
| --- | --- | --- |
| ICU | `compat/icu`: the four calls Freeciv makes | full ICU and its data are tens of MiB |
| libcurl | none: metaserver and downloads answer "no HTTP support" | single player needs neither |
| SQLite (fcdb), modpack installer, ruledit | not built | not needed to play |
| IPv6 | off | the Amiga socket headers are IPv4 |
| NLS (translations), readline, sound | off | first milestone; English only, muted |
| AI modules | `classic` only | `tex` adds threads and memory |

## Running

In the Freeciv drawer, `UnTar FreecivData.tar` once (it makes `data/` and
`docs/`). Give programs a large stack (`Stack 1000000`). Settings and saves
go to `PROGDIR:User` (beside the programs).

- Server alone, headless: `Execute ServerTest.amigados` plays five AI turns
  on a small classic map and saves each turn in `User/saves`.

## Observed

### 2 November 2026: the server, headless (step 2)

Cradle `stove_build` of `team4/freeciv-server-20261102` at `8098c32`
(`os32-gcc16` job, 241 s on the build PC; the build fetches and checks its own
open3 compiler). `freeciv-server` SHA-256
`a9a1627ea16b2f9cf19391ae85561d98bd18662ea1f70c6bd6c33c9fb5c84b43`;
`receipt.json` has the patch and unstripped hashes. The same build here gave
the same executable bytes as the Cradle's.

Lab `lab:freeciv` (a copy of Instance-32, AmigaOS 3.2 Kickstart 47.100,
`bsdsocket.library` 4.4 = GFOpenSocket, about 500 MB Fast RAM free), muted:
`ServerTest.amigados` loaded the classic ruleset with its ~570 nation files,
listened on 127.0.0.1:5599 through GFOpenSocket, created a 30 x 40 map, three
easy AIs played turns 1 to 5, the game ended at the turn limit, every turn was
saved (`auto-T0001.sav.gz` ... `T0006`, 15 to 17 KB each) and the server
exited by itself (`-e`). Start to the first save took 17 s, each AI turn 1 to
2 s at this size. The same run in a CON: window was screenshotted in the lab.

What it took (each now a patch or a compat part): no `fork`, `fcntl`
non-blocking or SIGTERM on libnix; libnix `select()` misses socket data
(WaitSelect bridge); `exec/io.h`'s `CMD_RESET`; Amiga paths and `;` as the
path separator; and the UTF-8 string helpers without the UTF-16 round trip.
One build-script fault cost the most: a `-Dc_args` that silently dropped
`-m68040 -m68881`, so the first lab builds were 68000 soft-float code that
ran out of memory building a hash table (the build now checks the flags).

Not shown yet: a client connecting, a human game, loading a save into a
running game, sound, and any timing beyond these first turns. This is TESTING,
not RELEASE.
