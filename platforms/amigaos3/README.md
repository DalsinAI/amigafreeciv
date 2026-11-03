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
the SDL2 client as `Freeciv` (the game's icon, a tool icon with the
1,000,000-byte stack the client needs) and the server, the data and docs from
`FreecivData.tar` (already unpacked), `ReadMe` (from `package/ReadMe.in`) and
`COPYING`. `patches/0016-sdl2-workbench-start-amigaos.patch` lets the client
start from that icon: started from Workbench (libnix gives argc 0) or with no
options it takes `-t trident -P sdl` (the tileset packed, sound through
SDL2_mixer), and on AmigaOS it sets the `SDL_IMAGE_DECODER` and
`SDL_MIXER_DECODER` hints to `cpu` (environment variables still outrank them),
as `Freeciv.amigados` does from a Shell. OpenBench runs no script from an icon
and the system has no IconX, so an icon on the script would not start the game
(seen in `lab:showcase` on 2 November 2026).

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
| NLS (translations), readline | off | English only |
| AI modules | `classic` only | `tex` adds threads and memory |

## Running

In the Freeciv drawer, `UnTar FreecivData.tar` once (it makes `data/` and
`docs/`). Give programs a large stack (`Stack 1000000`). Settings and saves
go to `PROGDIR:User` (beside the programs).

- Server alone, headless: `Execute ServerTest.amigados` plays five AI turns
  on a small classic map and saves each turn in `User/saves`.
- The game: `Execute Freeciv.amigados` (the SDL2 client; `SDL2.module`,
  `SDL2_image.module` and `SDL2_mixer.module` go in `LIBS:GFOpenGPU/`).
  "Start New Game" starts `freeciv-server` beside it.
- Sound: the client plays Freeciv's own `stdsounds` effects and `stdmusic`
  menu music (Ogg Vorbis, in the data drawer) through SDL2_mixer and AHI.
  `-P none` in `Freeciv.amigados` turns it off. On AmigaOS the client
  mixes 4096-sample buffers (patches/0014).
- F10 saves the client's window as `User/shot-NNN.png` (patches/0015).
- For measuring: `SetEnv FREECIV_AUDIOSTATS <file>` before starting the
  client writes the mixer's buffer count and gaps every five seconds, and
  each sound's load time, to that file; `FREECIV_AUDIOBUFFER` sets another
  buffer size.

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

### 2 November 2026: sound, screenshots and a long game

Cradle builds of `team4/freeciv-sound-20261102`, last at `37712e7` (job
`j20261102T212531-6d1fe8`, exit 0): `freeciv-sdl2`
`7a5347bff4ced653eaca60068dda7496be53df189869ab9d486badddd0605f81`,
`freeciv-server` unchanged at `730aead6…`, `SDL2_mixer.module`
`07410c8b0039e2a9867f744d339aca8164d646909ee2acdbe4baffdcd515314d`.
GFOpenRTG is now main at `210df77` (after #171 and #173). Same lab,
muted, so nothing was heard: the sound was checked by measuring it.

**Sound.**
- SDL opened AHI (`Audio: ahi, 44100 Hz, 2 channel(s), format 0x9010`,
  16-bit stereo) and loaded the menu music and every effect it was asked
  for with no error. The music decoders SDL2_mixer opened were WAVE and
  Ogg (its `media.decode` interface and stb_vorbis); the launcher keeps
  decoding on the 68040 (`SDL_MIXER_DECODER=cpu`). A menu run with the
  host decoder (`auto`) also kept time, with no fault.
- Buffer size. Upstream mixes 1024 samples (23 ms). In the lab's main
  menu that gave 213 to 217 buffers per five seconds against 215 or 216
  expected, with gaps of up to 72 ms: late buffers. With 4096 samples
  (93 ms, upstream's Windows size) every window had its 53 or 54, worst
  gap 96 to 137 ms. patches/0014 makes 4096 the AmigaOS default.
- The long game below, with sound on, 46 minutes (552 five-second
  windows): 29,790 buffers mixed. 537 windows had all their buffers.
  15 fell 1 to 4 short, their worst gaps 0.18 to 0.51 s, all while
  the client was busy with turns arriving every 2 to 20 seconds (game
  start, the switch to AI play, turns 67 to 71 and 148 to 155). So a
  short break in the sound is possible during a heavy turn change.
- The log for that run is
  [docs/observed/audio-game-20261102.txt](docs/observed/audio-game-20261102.txt).
- Loading. Effects are decoded whole when first played, on the client's
  own task: 10 to 260 ms for most, 370 to 490 ms for `fanfare.ogg`
  (stereo, 44.1 kHz, 296 KB), and once 2.5 s for `complete.ogg` while a
  game was loading. The menu music streams and opens in 12 to 330 ms
  (once 4 s, back at the menu while the server was busy).
- No slowdown in play. Turns 100 to 111 of the same save, run by the
  server with `timeout -1`: 167 s with no client, and 167 s with the
  client connected, watching, with sound on.
- Quit with sound on, from the main menu: five times, each time the
  process ended at once and the statistics file ends `audio: closed`
  (no SDL audio task left, by TaskPeek).
- Quit from inside a game while the server was running AI turns as fast
  as it could (`timeout -1`) took effect only after about four minutes,
  once the client had worked through the turns queued for it. The
  client then ended cleanly, audio closed. Once the client stayed busy
  with that queue and the lab was reset. At normal play (`timeout 0`)
  Quit was immediate.

**Screenshots** (the client's 640 x 480 window, in
[docs/observed](docs/observed)):

| Picture | What |
| --- | --- |
| [01-main-menu.png](docs/observed/01-main-menu.png) | Intro picture and main menu, music playing |
| [02-turn1-first-city.png](docs/observed/02-turn1-first-city.png) | Turn 1, 4000 BCE: the Incas' first city, Kitu |
| [03-city-dialog-turn1.png](docs/observed/03-city-dialog-turn1.png) | Kitu's city dialog on turn 1 |
| [04-game-turn103.png](docs/observed/04-game-turn103.png) | Turn 103, 40 CE: the map with the Inca cities and their neighbours |
| [05-city-dialog-turn110.png](docs/observed/05-city-dialog-turn110.png) | Pachakamaq's city dialog on turn 110 |
| [06-load-game.png](docs/observed/06-load-game.png) | Load Game: the list of saves the server offers |
| [07-diplomacy.png](docs/observed/07-diplomacy.png) | Diplomacy: the Arab ambassador (Foreign Minister dialog) |
| [08-options-save-game.png](docs/observed/08-options-save-game.png) | Options with Save Game; it wrote `freeciv-T0100-Y-0025-manual.sav.gz` (84 KB) |

Pictures 01 to 05 were taken from the lab's screen; 06 to 08 with the
client's own F10 (patches/0015). "Call Diplomatic Meeting" with the
Arabs on turn 100 opened no treaty window (the AI did not take the
meeting); the treaty window itself is not pictured.

**A long game.** civ2civ3, 44 x 44, the Incas and six easy AIs plus
animals. Turns 1 to 3 by hand, then the Incas went to the AI
(`/aitoggle`) and `timeout -1` let the server start each turn as soon as
the AIs had moved, with the client (sound on) watching up to turn 164.
Each figure is the time between autosaves (Amiga clock, to the second),
from [docs/observed/turns-20261102.txt](docs/observed/turns-20261102.txt):

| Turns | Year | Seconds a turn, mean (range) | Cities (all nations) | Units |
| --- | --- | --- | --- | --- |
| 4 to 10 | 3850 to 3550 BCE | 2.7 (1 to 5) | | |
| 10 to 20 | to 3050 BCE | 3.0 (1 to 5) | | |
| 20 to 30 | to 2550 BCE | 3.1 (2 to 4) | | |
| 30 to 40 | to 2050 BCE | 4.5 (3 to 7) | | |
| 40 to 50 | to 1550 BCE | 5.7 (3 to 9) | 30 at turn 51 | 43 |
| 50 to 60 | to 1050 BCE | 9.3 (6 to 14) | | |
| 60 to 70 | to 775 BCE | 14.4 (9 to 22) | | |
| 70 to 80 | to 525 BCE | 22.7 (14 to 30) | | |
| 80 to 90 | to 275 BCE | 16.2 (9 to 26) | | |
| 90 to 100 | to 25 BCE | 16.9 (10 to 21) | 68 at turn 101 | 210 |
| 100 to 110 | to 180 CE | 17.9 (13 to 23) | | |
| 110 to 120 | to 380 CE | 14.7 (9 to 27) | | |
| 120 to 130 | to 580 CE | 17.7 (12 to 28) | | |
| 130 to 140 | to 780 CE | 12.8 (9 to 22) | | |
| 140 to 150 | to 980 CE | 17.3 (9 to 36) | 71 at turn 151 | 282 |
| 150 to 160 | to 1090 CE | 18.5 (11 to 33) | | |
| 160 to 170 | to 1190 CE | 17.7 (11 to 33) | | |
| 170 to 180 | to 1290 CE | 16.5 (12 to 24) | | |
| 180 to 195 | to 1440 CE | 16.6 (9 to 37) | 71 at turn 196 | 293 |

- These are AI turns with nobody waiting on a human. In a game played by
  hand, each turn change costs the same plus the player's own moves.
- The cost grows with the cities until the land is nearly full (68
  cities by turn 101) and then stays at 13 to 19 seconds a turn on the
  lab's emulated 68040. The peak at turns 70 to 80 (23 s) is not
  explained.
- Turn 196 was 1450 CE, the land was full, and no nation had been
  destroyed.
- City and unit counts are from uncompressed saves of the same game,
  made by the server alone and searched for `ncities` and `nunits`.
  Their sizes were 478 KB at turn 51, 563 KB at turn 101 and 636 KB at
  turn 196; the game's own compressed autosaves were 41 KB at turn 1,
  84 KB at turn 101 and 96 KB at turn 195.

**Memory** (Fast RAM free, `Avail`, about 660 MB in the lab):
- Before the client: 527 MB.
- Client and server, the game at turn 2: 397 MB. At turn 81: 386 MB.
  At turn 160: 374 MB. So the two together use about 130 MB at the
  start and 155 MB by turn 160.
- The server alone at turn 187: 457 MB free (about 70 MB).
- After both had ended, 525 MB were free again.
- Loading the turn-100 save: client and server took 151 MB; the server
  alone, once the client had quit, took about 63 MB.
- A real 68040 with 64 MB or less cannot hold this. FEASIBILITY.md has
  the remedy (fewer player slots), still not measured.

**Still not shown or not right:**
- Nobody has listened: the lab is muted. A person on an instance with
  sound should confirm the music and effects sound right.
- Only the menu music exists in stdmusic. Upstream's music for each
  style and era is not in its source tree, and the game plays no music
  in play.
- An effect is decoded on the client's task the first time it plays; the
  larger ones stop the client for up to half a second (2.5 s once).
- A heavy turn change can still drop a few hundred milliseconds of
  sound.
- Quit during fast AI turns waits for the client to catch up.
- The treaty window of the diplomacy dialog was not pictured.
- The host decode service fault is still open (pictures and sound
  decode on the 68040).

This is TESTING, not RELEASE.
