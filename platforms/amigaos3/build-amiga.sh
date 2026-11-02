#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 AmiCradle Team
#
# Cradle's entry point (stove_build, target platforms/amigaos3). The port pins
# its own SDK (build_sdk.sh): the GFOpenAmigaGCC 16.2.0-open3 release, checked
# against the same SHA-256 as the verified open3 stove, so STOVE is only
# reported. OUT gets what a lab needs, as single files lab_put can copy:
#   freeciv-server (and freeciv-sdl2), FreecivData.tar (the data drawer),
#   UnTar (unpacks it on the Amiga), the .amigados scripts, receipt.json.
# Cradle runs it with sh; the port's scripts need bash.
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
: "${OUT:?OUT must be set}"
mkdir -p "$OUT"
WORK=${FREECIV_WORK:-$OUT/.work}
PARTS=${FREECIV_PARTS:-server}
mkdir -p "$WORK"
START=$(date +%s)

echo "stove: ${STOVE:-unset}"
if [[ -n "${STOVE:-}" && -f "$STOVE/provenance.json" ]]; then
    python3 -c "import json,sys; r=json.load(open(sys.argv[1])); print('stove release', r.get('release'), r.get('archive_sha256'))" "$STOVE/provenance.json" || true
fi
echo "host: $(uname -srm), $(nproc) cores"

[[ -f "$WORK/sdk/sdk.env" ]] || nice -n 19 bash "$HERE/build_sdk.sh" "$WORK/sdk"
echo "sdk ready after $(( $(date +%s) - START )) s"
rm -rf "$WORK/game"
# shellcheck disable=SC2086
nice -n 19 bash "$HERE/build-amigaos3.sh" "$WORK/sdk" "$WORK/game" $PARTS
echo "build done after $(( $(date +%s) - START )) s"

source "$WORK/sdk/sdk.env"
PKG=$WORK/game/freeciv
"$PREFIX/bin/m68k-amigaos-gcc" -noixemul -m68040 -m68881 -O2 -Wall -Wextra \
    "$HERE/scripts/untar.c" -o "$OUT/UnTar"
"$PREFIX/bin/m68k-amigaos-strip" "$OUT/UnTar"
(cd "$PKG" && tar --format=ustar --owner=0 --group=0 --numeric-owner --sort=name \
    --mtime="@$(python3 -c "import json;print(json.load(open('$WORK/game/receipt.json'))['source_date_epoch'])")" \
    -cf "$OUT/FreecivData.tar" data docs)
for f in "$PKG"/freeciv-* "$PKG"/*.amigados "$PKG"/*.serv; do
    [[ -f "$f" ]] && cp "$f" "$OUT/"
done
cp "$WORK/game/receipt.json" "$WORK/game/build.log" "$WORK/game/configure.log" "$OUT/"
(cd "$OUT" && sha256sum freeciv-* UnTar FreecivData.tar) > "$OUT/SHA256SUMS"
rm -rf "$WORK"
echo "total $(( $(date +%s) - START )) s"
ls -la "$OUT"
cat "$OUT/SHA256SUMS"
