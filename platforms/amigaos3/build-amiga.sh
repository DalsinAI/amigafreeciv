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
PARTS=${FREECIV_PARTS:-server client}
mkdir -p "$WORK"
START=$(date +%s)

echo "stove: ${STOVE:-unset}"
if [[ -n "${STOVE:-}" && -f "$STOVE/provenance.json" ]]; then
    python3 -c "import json,sys; r=json.load(open(sys.argv[1])); print('stove release', r.get('release'), r.get('archive_sha256'))" "$STOVE/provenance.json" || true
fi
echo "host: $(uname -srm), $(nproc) cores"
# On failure: the logs into the job's own log, and no work tree left in OUT.
trap 'rc=$?; for l in "$WORK"/game/configure.log "$WORK"/game/build.log; do
        [[ -f $l ]] && { echo "--- $l"; tail -60 "$l"; }; done
      rm -rf "$WORK"; exit $rc' ERR

# Host tools: the Meson and ninja this port was developed with, pinned, in
# a virtual environment in WORK; pkg-config from the PC, or pinned too.
TOOLS=(meson==1.12.1 ninja==1.11.1.1)
command -v pkg-config >/dev/null || TOOLS+=(pkgconf==2.3.0.post1)
if python3 -m venv "$WORK/venv" 2>/dev/null; then
    "$WORK/venv/bin/pip" install -q --disable-pip-version-check "${TOOLS[@]}"
else
    # No venv module on this PC: the same packages, installed beside WORK
    python3 -m pip install -q --disable-pip-version-check --target "$WORK/venv/lib" "${TOOLS[@]}"
    mkdir -p "$WORK/venv/bin"
    for t in meson ninja pkgconf; do
        [[ -e "$WORK/venv/lib/bin/$t" ]] && printf '#!/bin/sh\nPYTHONPATH="%s" exec python3 "%s" "$@"\n' \
            "$WORK/venv/lib" "$WORK/venv/lib/bin/$t" > "$WORK/venv/bin/$t" && chmod +x "$WORK/venv/bin/$t"
    done
fi
export PATH="$WORK/venv/bin:$PATH"
command -v pkg-config >/dev/null || ln -s "$(command -v pkgconf)" "$WORK/venv/bin/pkg-config"
echo "tools: meson $(meson --version), ninja $(ninja --version), pkg-config $(pkg-config --version)"

[[ " $PARTS " == *" client "* ]] && export FREECIV_SDK_SDL2=1
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
for f in "$PKG"/freeciv-* "$PKG"/*.amigados "$PKG"/*.serv "$WORK"/game/tests/*; do
    [[ -f "$f" ]] && cp "$f" "$OUT/"
done
cp "$WORK/game/build.log" "$WORK/game/configure.log" "$OUT/"
# The receipt, with the Cradle stove it ran beside. The build uses its own
# pinned open3 compiler (sdk_pins), whatever the stove is.
python3 - "$WORK/game/receipt.json" "$OUT/receipt.json" "${STOVE:-}" <<'PY'
import json, sys
from pathlib import Path
r = json.loads(Path(sys.argv[1]).read_text())
stove = Path(sys.argv[3]) if sys.argv[3] else None
prov = stove / "provenance.json" if stove else None
info = {"path": str(stove) if stove else None}
if prov and prov.is_file():
    p = json.loads(prov.read_text())
    info.update(release=p.get("release"), archive_sha256=p.get("archive_sha256"))
r["cradle_stove"] = info
r["compiler_used"] = "GFOpenAmigaGCC 16.2.0-open3 release (sdk_pins.GCC_BIN_SHA), downloaded and checked by build_sdk.sh"
Path(sys.argv[2]).write_text(json.dumps(r, indent=2) + "\n")
PY
# GFOpenRTG's SDL2 modules the client was linked against, for LIBS:GFOpenGPU/
if [[ -d "$WORK/sdk/modules" ]]; then
    cp "$WORK/sdk/modules/"*.module "$WORK/sdk/SDL2-SHA256SUMS" "$OUT/"
fi
(cd "$OUT" && sha256sum freeciv-* UnTar FreecivData.tar $(ls *.module 2>/dev/null)) > "$OUT/SHA256SUMS"
rm -rf "$WORK"
echo "total $(( $(date +%s) - START )) s"
ls -la "$OUT"
cat "$OUT/SHA256SUMS"
