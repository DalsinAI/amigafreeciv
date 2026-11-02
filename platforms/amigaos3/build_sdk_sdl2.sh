#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 AmiCradle Team
#
# The SDL2 part of the Freeciv SDK (build_sdk.sh runs it with
# FREECIV_SDK_SDL2=1), the same recipe as the fheroes2 port:
#   - the CyberGraphX and AHI developer headers SDL's back ends need, from
#     the AROS tree at AROS_REF (cybergraphics calls via conf_to_sfd.py);
#   - vasm, for SDL's c2p and blitter sources;
#   - GFOpenRTG's SDL2.module and libSDL2.a (link stub), SDL2_image.module
#     and libSDL2_image.a, SDL2_mixer.module and libSDL2_mixer.a (Ogg Vorbis
#     through stb_vorbis, WAV, and libxmp's tracker formats, all built in),
#     and libSDL2_ttf.a with FreeType built in.
# GFOpenRTG at OPENRTG_COMMIT is main after DalsinAI/gfopenrtg#173: SDL's
# threads get 256 KB stacks, and SDL's audio device closes from any task
# (Freeciv opens and closes it on the main task, but the mixer's audio
# thread is SDL's). #171, the mouse fix the port carried as
# sdl2-patches/0011, is in it.
# Expects build_sdk.sh's variables in the environment of the caller's file:
#
#   bash build_sdk_sdl2.sh SDK_DIR
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(cd "$1" && pwd)
JOBS=${JOBS:-$(nproc)}
PREFIX=$OUT/prefix
SYS=$OUT/sysroot
SRC=$OUT/openamigagcc-src
export PATH="$PREFIX/bin:$PATH"
NDKINC=$PREFIX/m68k-amigaos/ndk-include
AROS_REPOSITORY=https://github.com/aros-development-team/AROS.git
AROS_REF=c8860e674d7c5fbab304e2bf201f7a9c81c98629
VASM_COMMIT=a13e7e728a3dd5a9ba468bf479119e0bc23e70fd
OPENRTG_COMMIT=210df77692fa620cba1bdad96dfdac1d333b3123

fetch() {  # url file sha256
    if [[ ! -f "$2" ]]; then
        curl --fail --location --retry 2 --connect-timeout 20 --max-time 900 "$1" -o "$2.part"
        mv "$2.part" "$2"
    fi
    printf '%s  %s\n' "$3" "$2" | sha256sum --check --status || { echo "hash mismatch: $2" >&2; exit 3; }
}
shallow() {  # url dir commit: one commit, no history
    if ! git -C "$2" cat-file -e "$3^{commit}" 2>/dev/null; then
        rm -rf "$2"; git init -q "$2"
        git -C "$2" fetch -q --depth 1 --filter=blob:none "$1" "$3"
    fi
}

SDLOUT=$OUT/sdl2
# The port's own fixes to GFOpenRTG's SDL2 back end at OPENRTG_COMMIT
# (sdl2-patches/, applied after GFOpenRTG's patches/amigaos3), until
# GFOpenRTG has them. A built SDL2 is reused only with the same fixes.
# None at present.
shopt -s nullglob
PORT_SDL2_PATCHES=("$HERE"/sdl2-patches/*.patch)
shopt -u nullglob
PORT_SDL2_STAMP=$( (for p in "${PORT_SDL2_PATCHES[@]}"; do cat "$p"; done; echo "$OPENRTG_COMMIT") | sha256sum | cut -d' ' -f1)
if [[ -f "$OUT/SDL2-SHA256SUMS" && -f "$OUT/SDL2-PORT-PATCHES" ]] \
   && [[ "$(cat "$OUT/SDL2-PORT-PATCHES")" == "$PORT_SDL2_STAMP" ]] \
   && (cd "$SDLOUT" && sha256sum --check --status "$OUT/SDL2-SHA256SUMS"); then
    echo "SDL2 already built in $SDLOUT"
else
# 1. CyberGraphX and AHI developer headers from the pinned AROS tree.
AROS=$OUT/aros
shallow "$AROS_REPOSITORY" "$AROS" "$AROS_REF"
git -C "$AROS" checkout -q "$AROS_REF" -- \
    workbench/devs/diskimage/include/amigaos/cybergraphx/cybergraphics.h \
    workbench/devs/diskimage/include/amigaos/clib/cybergraphics_protos.h \
    workbench/libs/cgfx/cybergraphics.conf \
    workbench/devs/AHI/Include/C workbench/devs/AHI/Include/SFD
H=$OUT/sdk-headers
rm -rf "$H"; mkdir -p "$H"/{cybergraphx,clib,inline,proto,devices,libraries}
cp "$AROS/workbench/devs/diskimage/include/amigaos/cybergraphx/cybergraphics.h" "$H/cybergraphx/"
cp "$AROS/workbench/devs/diskimage/include/amigaos/clib/cybergraphics_protos.h" "$H/clib/"
cp "$AROS/workbench/devs/AHI/Include/C/devices/ahi.h" "$H/devices/"
cp "$AROS/workbench/devs/AHI/Include/C/libraries/ahi_sub.h" "$H/libraries/"
# AROS's copies say IPTR, its pointer-sized integer: ULONG on 68k AmigaOS.
sed -i 's/\bIPTR\b/ULONG/g' "$H"/cybergraphx/*.h "$H"/clib/*.h "$H"/devices/*.h "$H"/libraries/*.h
python3 "$HERE/scripts/conf_to_sfd.py" "$AROS/workbench/libs/cgfx/cybergraphics.conf" "$H/cybergraphics_lib.sfd" \
    --base CyberGfxBase --libname cybergraphics.library \
    --include '<exec/types.h>' --include '<utility/tagitem.h>' --include '<utility/hooks.h>' \
    --include '<graphics/rastport.h>' --include '<graphics/view.h>'
AHI_SFD=$AROS/workbench/devs/AHI/Include/SFD/ahi_lib.sfd
sfdc -q --target=m68k-gcc-amigaos --mode=macros --output="$H/inline/cybergraphics.h" "$H/cybergraphics_lib.sfd"
sfdc -q --target=m68k-amigaos --mode=proto --output="$H/proto/cybergraphics.h" "$H/cybergraphics_lib.sfd"
sfdc -q --target=m68k-gcc-amigaos --mode=macros --output="$H/inline/ahi.h" "$AHI_SFD"
sfdc -q --target=m68k-amigaos --mode=proto --output="$H/proto/ahi.h" "$AHI_SFD"
sfdc -q --target=m68k-amigaos --mode=clib --output="$H/clib/ahi_protos.h" "$AHI_SFD"
python3 "$SRC/openamigagcc/scripts/fix_sfdc_base_order.py" "$H/inline/cybergraphics.h" "$H/inline/ahi.h"
cp -a "$H/." "$NDKINC/"

# 2. vasm.
shallow https://github.com/mbitsnbites/vasm-mirror.git "$OUT/vasm" $VASM_COMMIT
git -C "$OUT/vasm" checkout -q "$VASM_COMMIT"
make -s -C "$OUT/vasm" CPU=m68k SYNTAX=mot -j"$JOBS" >/dev/null

# 3. GFOpenRTG's SDL2, SDL2_image, SDL2_mixer and SDL2_ttf (FreeType inside).
RTG=$OUT/gfopenrtg
shallow https://github.com/DalsinAI/gfopenrtg.git "$RTG" $OPENRTG_COMMIT
git -C "$RTG" checkout -q "$OPENRTG_COMMIT"
SDLDIR=$RTG/library/modules/sdl2
# GFOpenRTG's build.sh applies patches/amigaos3/*.patch in name order: the
# port's fixes go in beside them, numbered after GFOpenRTG's own.
for p in "${PORT_SDL2_PATCHES[@]}"; do
    [[ -f "$p" ]] && cp "$p" "$SDLDIR/patches/amigaos3/$(basename "$p")"
done
STOVE=$PREFIX SDK_HEADERS=$H VASM=$OUT/vasm/vasmm68k_mot TARBALLS=$OUT/downloads JOBS=$JOBS \
    sh "$SDLDIR/build.sh" "$SDLOUT" module stub
pin() { python3 -c "import json,sys; print(json.load(open('$SDLDIR/UPSTREAM.json'))[sys.argv[1]][sys.argv[2]])" "$1" "$2"; }
for lib in sdl2_image sdl2_mixer sdl2_ttf sdl2_net freetype libxmp; do
    t=$OUT/downloads/$(pin $lib file)
    fetch "$(pin $lib url)" "$t" "$(pin $lib sha256)"
    rm -rf "$SDLOUT/sdl2-work/$(pin $lib dir)"
    tar xf "$t" -C "$SDLOUT/sdl2-work"
    for p in "$SDLDIR"/patches/$lib/*.patch; do
        [[ -f "$p" ]] && patch -s -p1 -d "$SDLOUT/sdl2-work/$(pin $lib dir)" < "$p"
    done
done
make -s -f "$SDLDIR/satellites/Makefile" -j"$JOBS" STOVE="$PREFIX" OUT="$SDLOUT" WORK="$SDLOUT/sdl2-work" \
    headers abi "$SDLOUT/SDL2_image.module" "$SDLOUT/libSDL2_image.a" \
    "$SDLOUT/SDL2_mixer.module" "$SDLOUT/libSDL2_mixer.a" "$SDLOUT/libSDL2_ttf.a"
python3 "$SDLDIR/fpcr_check.py" "$PREFIX/bin/m68k-amigaos-objdump" \
    "$SDLOUT/SDL2.module" "$SDLOUT/SDL2_image.module" "$SDLOUT/SDL2_mixer.module" "$SDLOUT/libSDL2.a" \
    "$SDLOUT/libSDL2_image.a" "$SDLOUT/libSDL2_mixer.a" "$SDLOUT/libSDL2_ttf.a"

(cd "$SDLOUT" && sha256sum SDL2.module SDL2_image.module SDL2_mixer.module \
    libSDL2.a libSDL2_image.a libSDL2_mixer.a libSDL2_ttf.a) > "$OUT/SDL2-SHA256SUMS"
echo "$PORT_SDL2_STAMP" > "$OUT/SDL2-PORT-PATCHES"
fi

# 4. Into the sysroot, with pkg-config files for Meson.
cp -a "$SDLOUT/include/SDL2" "$SYS/include/"
cp "$SDLOUT/libSDL2.a" "$SDLOUT/libSDL2_image.a" "$SDLOUT/libSDL2_mixer.a" "$SDLOUT/libSDL2_ttf.a" "$SYS/lib/"
pc() {  # name version cflags libs
    printf 'Name: %s\nDescription: %s (GFOpenRTG) for the Freeciv AmigaOS 3.x build\nVersion: %s\nCflags: %s\nLibs: %s\n' \
        "$1" "$1" "$2" "$3" "$4" > "$SYS/lib/pkgconfig/$1.pc"
}
pc sdl2 2.32.10 "-I$SYS/include/SDL2" "-L$SYS/lib -lSDL2"
pc SDL2 2.32.10 "-I$SYS/include/SDL2" "-L$SYS/lib -lSDL2"
pc SDL2_image 2.8.12 "-I$SYS/include/SDL2" "-L$SYS/lib -lSDL2_image"
pc SDL2_mixer 2.8.2 "-I$SYS/include/SDL2" "-L$SYS/lib -lSDL2_mixer"
pc SDL2_ttf 2.24.0 "-I$SYS/include/SDL2" "-L$SYS/lib -lSDL2_ttf"
mkdir -p "$OUT/modules"
cp "$SDLOUT/SDL2.module" "$SDLOUT/SDL2_image.module" "$SDLOUT/SDL2_mixer.module" "$OUT/modules/"
cat "$OUT/SDL2-SHA256SUMS"
