#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 AmiCradle Team
#
# The SDK Freeciv builds against, from pinned inputs only:
#   - GFOpenAmigaGCC 16.2.0-open3 (compiler, libnix with its socket and
#     pthread libraries) and GFOpenNDK from the open3 source release;
#   - the OpenSocket SDK's BSD socket headers (sys/socket.h, netinet/in.h,
#     netdb.h ...) from DalsinAI/openamigasdk at OPENSDK_NET_COMMIT, which
#     the open3 release predates;
#   - zlib 1.3.1, static;
#   - compat/icu: the four ICU string calls Freeciv makes (not ICU);
#   - compat/net: select() for libnix's sockets through WaitSelect();
#   - compat/stack: a 1 MiB stack for the programs, however they are started;
#   - a host `tolua` from Freeciv's own dependencies/ (the cross build runs it);
#   - with FREECIV_SDK_SDL2=1: GFOpenRTG's SDL2.module, SDL2_image.module and
#     link stubs, and SDL2_ttf (with FreeType) linked in.
# Every download is checked against a pinned commit or SHA-256. The output is
# a local build workspace, not something to publish.
#
#   bash build_sdk.sh OUT_DIR
set -euo pipefail
[[ $# == 1 ]] || { echo "Usage: $0 OUT_DIR" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
TOP=$(cd "$HERE/../.." && pwd)
mkdir -p "$1"
OUT=$(cd "$1" && pwd)
JOBS=${JOBS:-$(nproc)}

GCC_TAG=v16.2.0-open3
GCC_BIN=openamigagcc-16.2.0-open3-x86_64-linux.tar.xz
GCC_BIN_SHA=9fcc136ab59e3bb5b91d2764d0bf290b709d72d7380be4ce0cdf005edf8eff21
GCC_SRC=openamigagcc-16.2.0-open3-src.tar.xz
GCC_SRC_SHA=d8b7cf2101cf70df1cf719d199230260790420f43ec6e899f3d061a85ff3bcda
OPENSDK_NET_COMMIT=dca5000e5f7fffdbdba8725f6923052379b865ff
ZLIB=zlib-1.3.1
ZLIB_SHA=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
OPENRTG_COMMIT=bbf126e28e3035db7bebd1b71c636f7b8fcdb162
AROS_REPOSITORY=https://github.com/aros-development-team/AROS.git
AROS_REF=c8860e674d7c5fbab304e2bf201f7a9c81c98629
VASM_COMMIT=a13e7e728a3dd5a9ba468bf479119e0bc23e70fd

fetch() {  # url file sha256
    if [[ ! -f "$2" ]]; then
        curl --fail --location --retry 2 --connect-timeout 20 --max-time 900 "$1" -o "$2.part"
        mv "$2.part" "$2"
    fi
    printf '%s  %s\n' "$3" "$2" | sha256sum --check --status || { echo "hash mismatch: $2" >&2; exit 3; }
}
checkout() {  # url dir commit
    [[ -d "$2/.git" ]] || git clone -q --filter=blob:none --no-checkout "$1" "$2"
    git -C "$2" cat-file -e "$3^{commit}" 2>/dev/null || git -C "$2" fetch -q origin "$3"
}

# 1. Compiler, and GFOpenNDK from the source release as the compiler's NDK.
mkdir -p "$OUT/downloads"
PREFIX=$OUT/prefix
if [[ ! -x "$PREFIX/bin/m68k-amigaos-gcc" ]]; then
    fetch "https://github.com/DalsinAI/gfopengcc/releases/download/$GCC_TAG/$GCC_BIN" "$OUT/downloads/$GCC_BIN" $GCC_BIN_SHA
    rm -rf "$PREFIX.tmp"; mkdir -p "$PREFIX.tmp"
    tar --no-same-owner -xJf "$OUT/downloads/$GCC_BIN" -C "$PREFIX.tmp" --strip-components=1
    mv "$PREFIX.tmp" "$PREFIX"
fi
SRC=$OUT/openamigagcc-src
if [[ ! -d "$SRC/amiga-gcc/projects/openamigasdk" ]]; then
    fetch "https://github.com/DalsinAI/gfopengcc/releases/download/$GCC_TAG/$GCC_SRC" "$OUT/downloads/$GCC_SRC" $GCC_SRC_SHA
    rm -rf "$SRC.tmp"; mkdir -p "$SRC.tmp"
    tar --no-same-owner -xJf "$OUT/downloads/$GCC_SRC" -C "$SRC.tmp" --strip-components=1 \
        openamigagcc-16.2.0-open3-src/amiga-gcc/projects/openamigasdk \
        openamigagcc-16.2.0-open3-src/openamigagcc/scripts
    mv "$SRC.tmp" "$SRC"
    rm -f "$OUT/downloads/$GCC_SRC"
fi
export PATH="$PREFIX/bin:$PATH"
OPENSDK=$SRC/amiga-gcc/projects/openamigasdk
NDKINC=$PREFIX/m68k-amigaos/ndk-include
if [[ ! -f "$NDKINC/.freeciv-sdk" ]]; then
    rm -rf "$NDKINC"; mkdir -p "$NDKINC"
    cp -a "$OPENSDK/OpenNDK/Include_H/." "$NDKINC/"
    cp -a "$OPENSDK/Include/." "$NDKINC/"
    STOVE=$PREFIX sh "$OPENSDK/OpenNDK/lib/build.sh" >/dev/null
    cp "$OPENSDK/OpenNDK/lib/build/m68k-amigaos/libamiga.a" "$PREFIX/m68k-amigaos/lib/libamiga.a"
    touch "$NDKINC/.freeciv-sdk"
fi
CC=$PREFIX/bin/m68k-amigaos-gcc
AR=$PREFIX/bin/m68k-amigaos-ar
CFLAGS_T="-noixemul -m68040 -m68881 -O2 -fno-delete-null-pointer-checks"

# 2. Sysroot overlay: socket headers, zlib, the ICU subset.
SYS=$OUT/sysroot
rm -rf "$SYS"; mkdir -p "$SYS/include" "$SYS/lib/pkgconfig"
NET=$OUT/openamigasdk
checkout https://github.com/DalsinAI/openamigasdk.git "$NET" $OPENSDK_NET_COMMIT
NETFILES=(amitcp arpa bsdsocket net netdb.h netinet pwd.h sys libraries/bsdsocket.h
          clib/bsdsocket_protos.h inline/bsdsocket.h proto/bsdsocket.h)
git -C "$NET" archive $OPENSDK_NET_COMMIT "${NETFILES[@]/#/OpenNDK/Include_H/}" \
    | tar -x -C "$SYS/include" --strip-components=2

fetch "https://github.com/madler/zlib/releases/download/v1.3.1/$ZLIB.tar.gz" "$OUT/downloads/$ZLIB.tar.gz" $ZLIB_SHA
rm -rf "$OUT/$ZLIB"; tar xzf "$OUT/downloads/$ZLIB.tar.gz" -C "$OUT"
mkdir -p "$OUT/$ZLIB/amiga"
for f in adler32 crc32 deflate infback inffast inflate inftrees trees zutil compress uncompr gzclose gzlib gzread gzwrite; do
    $CC $CFLAGS_T -DHAVE_UNISTD_H -c "$OUT/$ZLIB/$f.c" -o "$OUT/$ZLIB/amiga/$f.o" &
done
wait
$AR rcs "$SYS/lib/libz.a" "$OUT/$ZLIB"/amiga/*.o
cp "$OUT/$ZLIB/zlib.h" "$OUT/$ZLIB/zconf.h" "$SYS/include/"

mkdir -p "$SYS/include/unicode" "$OUT/icu"
cp "$HERE/compat/icu/unicode/ustring.h" "$SYS/include/unicode/"
$CC $CFLAGS_T -Wall -Wextra -I"$HERE/compat/icu" -c "$HERE/compat/icu/fc_icu_amiga.c" -o "$OUT/icu/fc_icu_amiga.o"
$AR rcs "$SYS/lib/libfcicu.a" "$OUT/icu/fc_icu_amiga.o"

# libnix's select() misses its sockets' data: compat/net bridges it to
# WaitSelect() (patches/0006 calls it).
mkdir -p "$OUT/fcamiga"
$CC $CFLAGS_T -Wall -Wextra -I"$SYS/include" -c "$HERE/compat/net/fc_amiga_select.c" -o "$OUT/fcamiga/fc_amiga_select.o"
$AR rcs "$SYS/lib/libfcamiga.a" "$OUT/fcamiga/fc_amiga_select.o"

# A 1 MiB stack for every program (libnix's swapstack): compat/stack.
$CC $CFLAGS_T -c "$HERE/compat/stack/fc_stack.c" -o "$SYS/lib/fc_stack.o"

pc() {  # name version cflags libs
    printf 'Name: %s\nDescription: %s for the Freeciv AmigaOS 3.x build\nVersion: %s\nCflags: %s\nLibs: %s\n' \
        "$1" "$1" "$2" "$3" "$4" > "$SYS/lib/pkgconfig/$1.pc"
}
pc zlib 1.3.1 "-I$SYS/include" "-L$SYS/lib -lz"
pc icu-uc 0.amiga "-I$SYS/include" "-L$SYS/lib -lfcicu"

# 3. Host tolua (Freeciv's bundled tolua 5.2 on its bundled Lua 5.5).
D=$TOP/dependencies
mkdir -p "$OUT/host/bin"
gcc -O1 -w -DLUA_USE_POSIX -I"$D/lua-5.5/src" -I"$D/tolua-5.2/include" \
    "$D/tolua-5.2/src/bin/tolua.c" "$D/tolua-5.2/src/bin/toluabind.c" \
    "$D"/tolua-5.2/src/lib/*.c "$D"/lua-5.5/src/*.c -lm -o "$OUT/host/bin/tolua"

# 4. SDL2 for the client.
if [[ ${FREECIV_SDK_SDL2:-0} == 1 ]]; then
    bash "$HERE/build_sdk_sdl2.sh" "$OUT"
fi

# 5. Meson cross file.
cat > "$OUT/cross.ini" <<EOF
[binaries]
c = '$PREFIX/bin/m68k-amigaos-gcc'
cpp = '$PREFIX/bin/m68k-amigaos-g++'
ar = '$PREFIX/bin/m68k-amigaos-ar'
strip = '$PREFIX/bin/m68k-amigaos-strip'
pkg-config = 'pkg-config'

[properties]
pkg_config_libdir = '$SYS/lib/pkgconfig'
cross_inc_path = '$SYS/include'

[built-in options]
c_args = ['-noixemul', '-m68040', '-m68881', '-pthread', '-fno-delete-null-pointer-checks', '-I$SYS/include']
c_link_args = ['-noixemul', '-m68040', '-m68881', '-pthread', '-L$SYS/lib', '$SYS/lib/fc_stack.o']
cpp_args = ['-noixemul', '-m68040', '-m68881', '-pthread', '-fno-delete-null-pointer-checks', '-I$SYS/include']
cpp_link_args = ['-noixemul', '-m68040', '-m68881', '-pthread', '-L$SYS/lib', '$SYS/lib/fc_stack.o']

[host_machine]
system = 'amigaos'
cpu_family = 'm68k'
cpu = 'm68040'
endian = 'big'
EOF
cat > "$OUT/PINS" <<EOF
GCC_BIN_SHA=$GCC_BIN_SHA
GCC_SRC_SHA=$GCC_SRC_SHA
OPENSDK_NET_COMMIT=$OPENSDK_NET_COMMIT
ZLIB_SHA=$ZLIB_SHA
SDL2=${FREECIV_SDK_SDL2:-0}
OPENRTG_COMMIT=$OPENRTG_COMMIT
EOF
printf 'PREFIX=%s\nSYSROOT=%s\nOPENSDK=%s\nCROSS=%s\nHOSTBIN=%s\n' \
    "$PREFIX" "$SYS" "$OPENSDK" "$OUT/cross.ini" "$OUT/host/bin" > "$OUT/sdk.env"
echo "Freeciv SDK ready: $OUT/sdk.env"
