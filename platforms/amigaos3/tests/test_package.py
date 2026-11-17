#!/usr/bin/env python3
"""Host tests for the release archive: the Installer spec and Install-Freeciv,
the FPU check, and tools/make_package.py on a stand-in build (the client
drawer, with Install-Freeciv beside it).

    python3 platforms/amigaos3/tests/test_package.py
MIT, Copyright (c) 2026 AmiCradle Team."""
import importlib.util
import io
import json
import re
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent          # platforms/amigaos3
sys.path.insert(0, str(ROOT / "tools"))
import lha_archive  # noqa: E402

spec = importlib.util.spec_from_file_location("check_fpu", ROOT / "tools/check_fpu.py")
check_fpu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_fpu)

VERSION = (ROOT / "package/VERSION").read_text().strip()
SPEC = json.loads((ROOT / "package/installer.json").read_text())
SCRIPT = (ROOT / "package/Install-Freeciv").read_text()


def tar_of(files: dict) -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.USTAR_FORMAT) as t:
        for name, data in sorted(files.items()):
            info = tarfile.TarInfo(name)
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))
    return buf.getvalue()


class Installer(unittest.TestCase):
    def test_versions_agree(self):
        self.assertEqual(SPEC["version"], VERSION)
        m = re.match(r"; \$VER: Install-Freeciv (\S+) \(", SCRIPT)
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1), VERSION)

    def test_cpu_fpu_and_modules(self):
        self.assertIn('(database "cpu")', SCRIPT)
        self.assertIn('"NOFPU"', SCRIPT)
        for mod in ("SDL2.module", "SDL2_image.module", "SDL2_mixer.module"):
            self.assertIn(f'"LIBS:GFOpenGPU/{mod}"', SCRIPT)

    def test_update_keeps_user(self):
        self.assertEqual(SPEC["keep"], ["User"])
        self.assertIn('(tackon #dest "User")', SCRIPT)

    def test_parens_balance(self):
        depth = 0
        for line in SCRIPT.splitlines():
            code, in_str, esc = "", False, False
            for ch in line:
                if in_str:
                    esc = (ch == "\\" and not esc)
                    if ch == '"' and not esc:
                        in_str = False
                    continue
                if ch == '"':
                    in_str = True
                elif ch == ";":
                    break
                else:
                    code += ch
            depth += code.count("(") - code.count(")")
            self.assertGreaterEqual(depth, 0, line)
        self.assertEqual(depth, 0)


class FpuCheck(unittest.TestCase):
    def test_soft_float_found(self):
        self.assertEqual(check_fpu.soft_symbols("0 T ___muldf3\n0 T _main\n U ___gesf2\n"),
                         ["gesf2", "muldf3"])

    def test_fpu_build_passes(self):
        self.assertEqual(check_fpu.soft_symbols("0 T _main\n0 T ___floatdidf\n0 T ___fixunsdfdi\n"), [])


class Package(unittest.TestCase):
    def make(self, d: Path):
        build = d / "build"
        build.mkdir()
        (build / "freeciv-sdl2").write_bytes(b"\x00\x00\x03\xf3client")
        (build / "freeciv-server").write_bytes(b"\x00\x00\x03\xf3server")
        (build / "FreecivData.tar").write_bytes(tar_of({
            "data/classic/game.ruleset": b"x", "data/trident.tilespec": b"y", "docs/COPYING": b"z"}))
        (build / "receipt.json").write_text(json.dumps({
            "repository_commit": "abc", "upstream_commit": "def", "source_date_epoch": 1762000000}))
        return subprocess.run([sys.executable, str(ROOT / "tools/make_package.py"), "--build", str(build),
                               "--version", VERSION, "--out", str(d / "out")], capture_output=True, text=True)

    def test_archive_has_drawer_and_installer(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            r = self.make(d)
            self.assertEqual(r.returncode, 0, r.stderr)
            lha = d / "out" / f"freeciv-{VERSION}-68040.lha"
            paths = [m.path for m in lha_archive.read(lha.read_bytes())]
            for p in ("Freeciv/Freeciv", "Freeciv/freeciv-server", "Freeciv/ReadMe",
                      "Freeciv/data/trident.tilespec", "Freeciv.info",
                      "Install-Freeciv", "Install-Freeciv.info"):
                self.assertIn(p, paths)
            self.assertEqual(paths[-2:], ["Install-Freeciv", "Install-Freeciv.info"])
            self.assertTrue((d / "out/Install-Freeciv").is_file())
            readme = (d / "out/Freeciv/ReadMe").read_text(encoding="latin-1")
            self.assertIn("Install-Freeciv", readme)
            self.assertIn("client drawer", readme)
            self.assertIn(VERSION, readme)

    def test_beside_name_must_be_plain(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            bad = json.loads((ROOT / "package/package.json").read_text())
            bad["beside"] = [{"name": "Freeciv/Install-Freeciv", "repo": "package/Install-Freeciv"}]
            (d / "bad.json").write_text(json.dumps(bad))
            self.make(d)
            r = subprocess.run([sys.executable, str(ROOT / "tools/make_package.py"), "--build", str(d / "build"),
                                "--version", VERSION, "--out", str(d / "out2"), "--spec", str(d / "bad.json")],
                               capture_output=True, text=True)
            self.assertNotEqual(r.returncode, 0)
            self.assertIn("plain name", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
