#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 AmiCradle Team
#
# The data the SDL2 client needs, from the source tree's data/ into the
# package's: the "human" theme (without its Chinese, Japanese and Korean
# fonts: the client is built without translations), the 2D trident tileset
# with the shared misc/ graphics, and the small nation flags and shields
# (PNG; SVG flags are off in this build), and the sound and music sets
# (stdsounds, stdmusic: Ogg Vorbis, about 1.5 MB, in the source tree).
#
#   stage_client_data.sh SOURCE_DATA PACKAGE_DATA
set -euo pipefail
D=$1
P=$2
mkdir -p "$P/themes/gui-sdl2" "$P/flags"
cp -r "$D/themes/gui-sdl2/human" "$P/themes/gui-sdl2/"
rm -f "$P/themes/gui-sdl2/human/"{fireflysung.ttf,sazanami-gothic.ttf,UnDotum.ttf} \
      "$P/themes/gui-sdl2/human/"COPYING.{fireflysung,sazanami,UnDotum}
cp -r "$D/trident" "$D/misc" "$P/"
cp "$D/trident.tilespec" "$P/"
rm -f "$P/misc/"*-large.spec
for f in "$D"/flags/*.png; do
    case $f in *-large.png) ;; *) cp "$f" "$P/flags/" ;; esac
done
cp "$D/flags/credits" "$P/flags/" 2>/dev/null || true
cp -r "$D/stdsounds" "$D/stdmusic" "$P/"
cp "$D/stdsounds.soundspec" "$D/stdmusic.musicspec" "$P/"
find "$P" -name .gitignore -delete
