# Freeciv on AmigaOS 3.x: feasibility and build plan

2 November 2026. Target: AmigaOS 3.x / AmiCradle AC090, 68040 + FPU,
AGA or RTG, SDL2 through the GF libraries, GCC 16.2.0-open3. Goal: a
single-player game started and played on one Amiga.

## Source

- Upstream Freeciv `900908ae2c3b7ce69352edb4188036f9d576960f` (1 November
  2026), version 3.3.90.17-dev, the 3.4 development line. GPL-2.0-or-later.
- This repository's tree (`git ls-tree -r`) matches that upstream commit
  exactly, apart from `.github/` and `AMIGA_PORT.md`: SOURCE VERIFIED in the
  Port Atlas's terms.
- Build system: Meson (0.63 or later). It runs Python generators (packets,
  specenums) and `tolua` on the build host, which the port builds from
  Freeciv's own `dependencies/`.

## Architecture: client, server, loopback

Freeciv is client/server even for one player: the client starts
`freeciv-server` as a child process and connects to it over TCP on the
same machine.

- **Loopback sockets.** libnix's `libsocket.a` (in the open3 compiler)
  gives `socket`, `bind`, `listen`, `accept`, `connect`, `select`,
  `gethostbyname` and the rest over `bsdsocket.library`, sharing libnix's
  file descriptors, so Freeciv's `netintf.c` needs no socket rewrite. On
  AmiCradle `bsdsocket.library` is GFOpenSocket: its Host backend carries the
  calls to the PC's sockets, so `127.0.0.1` is a real loopback; its Direct
  backend (lwIP) has a loopback interface of its own. The server binds to
  `127.0.0.1` only. The BSD socket headers come from the OpenSocket SDK
  (DalsinAI/openamigasdk, pinned), which the open3 release predates. IPv4
  only.
- **Starting the server.** Upstream starts it with `fork`/`execvp` (Unix) or
  `CreateProcess` (Windows). AmigaOS has neither; the port adds a
  `SystemTags(..., SYS_Asynch, TRUE)` launch in step 4. Until then the
  server is started from a Shell script with `Run` and the client connects
  to it, which needs no code change.
- **In-process server: not feasible.** Server and client each link the whole
  `common/` library with its global game state (`game`, `wld`, the
  rulesets); one program cannot hold two copies. Freeciv has no in-process
  mode (freeciv-web runs the server separately too). It would mean renaming
  or partitioning every global in `common/`: a fork of Freeciv, not a port.
  Loopback through GFOpenSocket is the way.
- **The console.** The server reads operator commands from its Shell
  window. AmigaOS's console is not a socket, so the port reads it with
  `WaitForChar()` beside `select()` (upstream's Windows arrangement,
  `FREECIV_SOCKET_ZERO_NOT_STDIN`).

## Dependencies: what the GF SDK has, what the port brings

| Freeciv needs | On AmigaOS 3.x | Plan |
| --- | --- | --- |
| C11 compiler, libm | GCC 16.2.0-open3, libnix | as is, `-noixemul -m68040 -m68881` |
| threads | libnix `libpthread.a` | as is (only the server's few helper threads; `tex` AI off) |
| sockets | libnix `libsocket.a` + OpenSocket SDK headers | as is |
| zlib | not in the compiler | zlib 1.3.1, static, pinned by SHA-256 |
| ICU (`icu-uc`) | none; full ICU is tens of MiB | `compat/icu`: the four calls Freeciv makes (`u_strFromUTF8`, `u_strFromUTF8Lenient`, `u_strToUTF8`, `u_strCaseCompare`), simple case folding |
| libcurl | not needed | off: metaserver and modpack downloads report "no HTTP support" (patch) |
| SQLite3 | only for fcdb and the modpack installer | not built |
| Lua 5.5, tolua | bundled in `dependencies/` | bundled |
| iconv | not in libnix | off: Freeciv works in UTF-8 internally |
| gettext (NLS) | not needed | off: English |
| readline | not needed | off |
| SDL2 (client) | GFOpenRTG `SDL2.module` 2.32.10, GFOpenGPU renderer, AGA c2p | link stub `libSDL2.a` |
| SDL2_image | GFOpenRTG `SDL2_image.module` | link stub |
| SDL2_ttf | GFOpenRTG `libSDL2_ttf.a` with FreeType 2.14.3 | static |
| SDL2_gfx | bundled in `dependencies/SDL2_gfx` | bundled |
| SDL2_mixer | GFOpenRTG `SDL2_mixer.module` | not used yet: sound off |

## Cost on a 68040

- `freeciv-server`, server-only build, classic AI: 3.7 MB executable
  (3.1 MB code), and 22 MB of BSS. 14.5 MB of that is `research_array`
  (one research record for each of the 512 player slots,
  `MAX_NUM_PLAYER_SLOTS`, a network-protocol constant) and 5.3 MB the
  unit-type table. The client links the same `common/` and will need about
  as much again. On an AC090 with plenty of Fast RAM this fits; on a
  real 68040 with 64 MB or less it will not, and lowering
  `MAX_NUM_PLAYER_SLOTS` (both programs together, as they must agree) is the
  remedy, measured before it is applied.
- Keep the game small: `size 1` (1000 tiles), three AI players, the
  `classic` ruleset (lighter than civ2civ3), no sound, the 2D `trident`
  tileset (30x30, no isometric blending).
- Freeciv's UTF-8 string helpers round-trip through UTF-16 on every copy;
  if they show in a profile, `compat/icu` can short-cut the common cases.

## Build plan, one pull request each

1. This note and the build plan; the port's manifests (`gameports/`,
   `source.json`).
2. `freeciv-server` builds with the pinned SDK (`build_sdk.sh`,
   `build-amigaos3.sh`, Cradle `build-amiga.sh`) and plays an AI-only game
   headless in a lab (`ServerTest.amigados`): starts, loads the ruleset,
   makes the map, plays turns, saves, exits.
3. The SDL2 client builds against GFOpenRTG's SDL2 modules.
4. The client connects to the server on the same Amiga and shows the map;
   the server is started by the client (`SystemTags`) or by a launcher.
5. A few turns played by hand, a save and a load.
6. Turn times measured; README "Observed" and the Port Atlas entry updated
   honestly (TESTING, never RELEASE).

## Stop rules

- The lab cannot open `bsdsocket.library`, or loopback connect fails: the
  server is still testable headless; report what GFOpenSocket needs.
- The client does not fit in memory beside the server: measure, then
  shrink `MAX_NUM_PLAYER_SLOTS` in both.
- AI turns take minutes on the 68040: report the numbers, and measure with
  fewer AIs or a smaller map before anything else.
