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

### Package and icons

Target `platforms/amigaos3/package` (`package/build-amiga.sh`) builds the game
as `platforms/amigaos3` does and packs the release archive with
`tools/make_package.py`: `freeciv-VERSION-68040.lha` (LhA level-1, `-lh5-`,
written by `tools/lha_archive.py`) holding the `Freeciv` drawer and
`Freeciv.info` beside it, with the `.sha256`, an Aminet `.readme`,
`package.json`, the drawer as it unpacks and `Freeciv.tar` with `UnTar` (for a
lab: `UnTar Freeciv.tar` in the drawer that is to hold it). The drawer holds
the client and the server, the data and docs from `FreecivData.tar` (already
unpacked), `ReadMe` (from `package/ReadMe.in`), `COPYING`, and the
`Freeciv.amigados` script as `Freeciv`, the game's icon: a project icon whose
default tool is `C:IconX`, so a double-click runs the script (the stack, the
image decoder and the tileset it sets).

The drawer, the game and the documents have OS 3.5 GlowIcons (`icons/*.info`;
the drawer's is `Freeciv-drawer.info` in the repository, as the game's icon is
`Freeciv.info`): the classic four-colour picture for older Workbenches and two
colour frames, drawn from Freeciv's own client icon (`icons/art/freeciv.png`,
from `data/icons/128x128/freeciv-client.png`). They are committed, so the
package needs nothing else; to draw them again, with a DalsinAI/amicradle
checkout:

```sh
python3 ../amicradle/scripts/port_icons.py platforms/amigaos3/icons/icons.json --out platforms/amigaos3/icons
```

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
- The game: `Execute Freeciv.amigados` (the SDL2 client; its modules go in
  `LIBS:GFOpenGPU/`). "Start New Game" starts `freeciv-server` beside it.

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

### 2 November 2026: client and server together (steps 3 and 4, partial)

Cradle build of `team4/freeciv-connect-20261102` at `d6bb5c8`, same lab, with
the build's `SDL2.module` and `SDL2_image.module` in `LIBS:GFOpenGPU/`:

- `Freeciv.amigados` opens the client in a 640 x 480 window on the RTG
  Workbench: intro picture, messages, main menu (screenshots). Colours are
  right since patch 0012; before it red and blue were crossed.
- "Start New Game" started `PROGDIR:freeciv-server` as its own process
  (`Status` lists both), the client connected over 127.0.0.1, logged in,
  took hack access ("Established control over the server. You have command
  access level 'hack'") and drew the pregame page with the saved games the
  server offers.
- **Then the client seemed to stop answering**: no click on the pregame
  page did anything. The next entry has the cause, which was the mouse, not
  the connection.
- With the host decode service, loading the client's ~1,100 pictures took
  the lab's runtime down on the PC (glibc heap assertion); the launcher sets
  `SDL_IMAGE_DECODER=cpu`.

### 2 November 2026: a game played from the client (steps 5 and 6)

Cradle builds of `team4/freeciv-play-20261102`: `c1d867c` (patch 0013) and
`ebdeb42` (`sdl2-patches/0011`). Both exited 0, the second in 286 s. In
both, `freeciv-sdl2` is
`10302aaeb638a2338197625893248a413318949fb323ae63149ab570fe89f9e8` and
`freeciv-server` is
`730aead6e125f9d0a0ce408081434568ea352320f3217c23862a8a9a544b1b6d`.
`SDL2.module` is `836e3f79…` and `SDL2_image.module` is `40f73aa6…`. Same lab.

**Why the client "stopped answering".** It was never the network.
- An IntuiMessage gives the mouse relative to the window's outer corner.
  This is true for a GimmeZeroZero window as well (OS 3.2.3, and
  OpenIntuition since 26 October).
- GFOpenRTG's SDL2 back end read those coordinates as inside the borders.
  So every move and click landed the title bar's height (about 22 pixels)
  below the pointer.
- On the main menu, the item lit up was the one under the pointed item.
  That was easy to miss.
- On the pregame page, Start, Pick Nation and Back sit at the foot of the
  window, so a click on them landed outside it.
- Keys worked throughout. With patch 0013 alone the client behaved exactly
  as before. TaskPeek showed both programs idle in `Wait()`, which is
  normal between events.

**The fix.**
- `sdl2-patches/0011` takes the borders off and moves SDL's pointer to a
  button's own position before the click. `build_sdk_sdl2.sh` applies it
  on top of GFOpenRTG at the pinned commit.
- The same patch is offered to GFOpenRTG in DalsinAI/gfopenrtg#171. Once
  that is merged and the pin moves, the port's copy goes.
- Patch 0013 stays: Freeciv's sockets use bsdsocket.library's own numbers
  and never libnix's descriptor table. The game below ran on it. Whether
  the old libnix sockets would also have worked once the mouse was fixed
  was not tried.

**Played by hand** (screenshots taken in the lab):
- Launch: `Freeciv.amigados`, then Start New Game. The server was started
  from the client. Its defaults were the civ2civ3 ruleset, a 44 x 44 map,
  and six easy AIs plus animals.
- Pregame: Start → turn 1, 4000 BCE, playing the Babylonians.
- Turn 1: the Explorer explored, the Workers went on auto, and the Settlers
  founded the first city, Babilum (OK in the city name dialog).
- Next turns: fortified the Warriors the city built, and accepted a
  ceasefire the Persians offered in the diplomacy dialog.
- Shift+Return ended each turn.
- Turn 5: Options → Save Game wrote
  `User/saves/freeciv-T0005-Y-3800-manual.sav.gz` (46 KB). Options → Quit
  closed the client, and the server ended with it (`Status`: neither left).
- Relaunch: `Freeciv.amigados`, then Load Game. The list showed the manual
  save first.
- Loading it put Hammurabi back under the client's user, along with the
  five AI nations.
- Start → 3800 BCE, with the same city, units and explored map. After
  typing in the chat line, the first click only leaves the line; the
  second presses Start.
- Played turns 6 to 8 after the load. On turn 8 the Mali offered a
  ceasefire, which was accepted.

**Turn times with a human player.** Each figure is from Shift+Return to the
next turn's autosave, on the lab's emulated 68040. civ2civ3, 44 x 44, six
easy AIs:

| Turn change | Seconds |
| --- | --- |
| 1 → 2 | 5 |
| 2 → 3 | 3 |
| 3 → 4 | 3 |
| 4 → 5 | 4 |
| 5 → 6 (after the load) | 2 |
| 6 → 7 | 1 to 2 |
| 7 → 8 | 1 to 2 |

The times come from the Amiga clock and the save file times, so each is
good to about a second. These are the first turns, with one city per
nation. Longer games will be slower.

**Still not shown or not right:**
- Sound (SDL2_mixer not used).
- A long game, and the AI's cost late in a game.
- A real 68040 and its memory (the client alone used about 45 MB in step
  3; the server's use with the client was not measured).
- In the diplomacy dialog, the left (broken) seal cancels the meeting and
  the right one accepts. That is upstream's design, not a fault.
- Map-scrolling speed was not measured.
- The host decode service fault above is still open, and the launcher
  still decodes on the 68040.

This is TESTING, not RELEASE.
