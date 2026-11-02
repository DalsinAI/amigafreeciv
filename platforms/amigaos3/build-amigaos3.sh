#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 AmiCradle Team
#
# Freeciv for AmigaOS 3.x, 68040 + FPU (-m68040 -m68881), libnix.
#
#   bash build-amigaos3.sh SDK_DIR OUT_DIR [server] [client]
#
# SDK_DIR is build_sdk.sh's output. The source is this repository's own tree
# at REF (default HEAD), exported clean, with patches/ applied, built offline.
# OUT_DIR/freeciv is the package: the programs, the data they need and docs.
set -euo pipefail
[[ $# -ge 2 ]] || { echo "Usage: $0 SDK_DIR OUT_DIR [server] [client]" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
TOP=$(git -C "$HERE" rev-parse --show-toplevel)
SDK=$(cd "$1" && pwd)
[[ ! -e "$2" ]] || { echo "Use a new OUT_DIR" >&2; exit 2; }
mkdir -p "$2"
OUT=$(cd "$2" && pwd)
shift 2
PARTS=${*:-server}
JOBS=${JOBS:-$(nproc)}
REF=${REF:-HEAD}
# shellcheck source=/dev/null
source "$SDK/sdk.env"
export PATH="$HOSTBIN:$PATH"
UPSTREAM=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['upstream_commit'])" "$HERE/source.json")
COMMIT=$(git -C "$TOP" rev-parse "$REF^{commit}")
EPOCH=$(git -C "$TOP" show -s --format=%ct "$COMMIT")

# 1. The tree, exported clean, with the Amiga patches.
TREE=$OUT/source
mkdir -p "$TREE"
git -C "$TOP" archive "$COMMIT" -- . ':!translations' ':!.github' ':!platforms/amigaos3' | tar -x -C "$TREE"
for p in "$HERE"/patches/*.patch; do
    patch -s --batch --forward --fuzz=0 -p1 -d "$TREE" < "$p"
done

# 2. Configure: only what a single-player game on one Amiga needs.
CLIENTS="[]"; SERVER=disabled; TARGETS=()
for part in $PARTS; do
    case $part in
        server) SERVER=enabled; TARGETS+=(freeciv-server) ;;
        client) CLIENTS="['sdl2']"; TARGETS+=(freeciv-sdl2) ;;
        *) echo "unknown part: $part" >&2; exit 2 ;;
    esac
done
SOURCE_DATE_EPOCH=$EPOCH meson setup "$OUT/build" "$TREE" --cross-file "$CROSS" \
    --buildtype=release -Dprefix=/freeciv -Ddefault_library=static \
    -Db_staticpic=false -Db_pie=false \
    -Dc_args="-ffile-prefix-map=$TREE=." \
    -Dserver=$SERVER -Dclients="$CLIENTS" -Dfcmp=[] -Dtools=[] \
    -Dnls=false -Daudio=none -Dreadline=false -Dfcdb=[] -Daimodules=classic \
    -Dmwand=false -Dsyslua=false -Djson-protocol=false -Dsvgflags=false \
    > "$OUT/configure.log" 2>&1 || { tail -40 "$OUT/configure.log"; exit 4; }
SOURCE_DATE_EPOCH=$EPOCH ninja -C "$OUT/build" -j"$JOBS" "${TARGETS[@]}" > "$OUT/build.log" 2>&1 \
    || { grep -E "error|Error|FAILED" "$OUT/build.log" | head -40; exit 5; }

# The diagnostic tools in tests/, against the same library.
mkdir -p "$OUT/tests"
"$PREFIX/bin/m68k-amigaos-gcc" -noixemul -m68040 -m68881 -O2 -std=gnu2x -DHAVE_CONFIG_H \
    -I"$OUT/build" -I"$TREE/utility" -I"$SYSROOT/include" "$HERE/tests/registry_load.c" \
    "$OUT/build/libfreeciv.a" -Wl,--wrap=fileinfoname -L"$SYSROOT/lib" "$SYSROOT/lib/fc_stack.o" \
    -lfcicu -lz -lfcamiga -lsocket -lm -pthread -o "$OUT/tests/RegistryLoad"

# 3. The package. Data: the classic and civ2civ3 rulesets with what they
#    include, and for the client its theme, one tileset and fonts.
PKG=$OUT/freeciv
mkdir -p "$PKG/data" "$PKG/User/saves" "$PKG/docs"
for t in "${TARGETS[@]}"; do
    cp "$OUT/build/$t" "$PKG/$t"
    "$PREFIX/bin/m68k-amigaos-strip" "$PKG/$t"
done
D=$TREE/data
cp -r "$D/classic" "$D/civ2civ3" "$D/default" "$D/nation" "$D/override" "$PKG/data/"
cp "$D/classic.modpack" "$D/civ2civ3.modpack" "$D/default.modpack" "$PKG/data/" 2>/dev/null || true
cp "$D/helpdata.txt" "$PKG/data/"
if [[ " $PARTS " == *" client "* ]]; then
    bash "$HERE/scripts/stage_client_data.sh" "$D" "$PKG/data"
fi
find "$PKG/data" \( -name 'Makefile*' -o -name 'meson.build' \) -delete
cp "$TREE/COPYING" "$TREE/README" "$TREE/AUTHORS" "$PKG/docs/"
cp "$HERE/README.md" "$PKG/docs/README-Amiga.md"
cp "$HERE/scripts/"*.amigados "$HERE/scripts/"*.serv "$PKG/"

python3 - "$OUT" "$COMMIT" "$UPSTREAM" "$EPOCH" "$HERE" "$SDK" "${TARGETS[@]}" <<'PY'
import hashlib, json, sys
from pathlib import Path
out, commit, upstream, epoch, here, sdk = Path(sys.argv[1]), *sys.argv[2:6], Path(sys.argv[6])
targets = sys.argv[7:]
d = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
here = Path(here)
receipt = {
    "repository_commit": commit, "upstream_commit": upstream, "source_date_epoch": epoch,
    "patches": {p.name: d(p) for p in sorted((here / "patches").glob("*.patch"))},
    "executables": {t: {"unstripped_sha256": d(out / "build" / t),
                        "sha256": d(out / "freeciv" / t)} for t in targets},
    "sdk_pins": dict(l.split("=", 1) for l in (sdk / "PINS").read_text().split()),
    "cpu": "68040 + FPU (-m68040 -m68881), libnix",
    "scope": "Offline source build only; no runtime or release pass implied",
}
(out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
PY
