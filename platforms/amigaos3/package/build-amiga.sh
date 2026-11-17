#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 AmiCradle Team
#
# The release archive, for Cradle's stove_build (target
# platforms/amigaos3/package, STOVE= and OUT= set): the game built as
# ../build-amiga.sh builds it (server and SDL2 client, the data drawer as
# FreecivData.tar), then tools/make_package.py:
# freeciv-VERSION-68040.lha with its .sha256 and .readme, the Freeciv drawer
# with its GlowIcons (icons/), the programs, the Freeciv script (started by
# IconX from its icon) and the data, the drawer as it unpacks and as
# Freeciv.tar with UnTar (for a lab), and package.json.
# VERSION is package/VERSION. Nothing is published from here.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
: "${OUT:?OUT must be set}"
VERSION=$(cat "$HERE/VERSION")
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/freeciv-package.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT INT TERM

OUT=$BUILD FREECIV_WORK=$BUILD/.work bash "$ROOT/build-amiga.sh" > "$OUT/build-output.txt" 2>&1 \
    || { tail -n 80 "$OUT/build-output.txt"; exit 1; }
tail -n 25 "$OUT/build-output.txt"
cp "$BUILD/receipt.json" "$BUILD/UnTar" "$BUILD/fpu-check.txt" "$OUT/"
cp "$BUILD"/*.module "$OUT/" 2>/dev/null || true
python3 "$ROOT/tools/make_package.py" --build "$BUILD" --version "$VERSION" --out "$OUT"
