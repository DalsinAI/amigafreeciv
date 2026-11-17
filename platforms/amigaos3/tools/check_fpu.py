#!/usr/bin/env python3
"""The FPU check: no soft-float in a 68040 + FPU build. Lists each
executable's symbols with the stove's nm and fails when any of libgcc's
soft-float routines (__adddf3, __mulsf3, __fixdfsi, __extendsfdf2,
__ltdf2 and the rest) is linked in: those are the code a build gets when
-m68881 is lost somewhere, and they would make the game crawl. The 64-bit
integer conversions (__fixdfdi, __floatdidf and so on) are left out: the
68881 has no instruction for them, so libgcc has them with the FPU too.

    check_fpu.py NM EXECUTABLE...

Prints one line per executable and exits 1 if any has soft-float.
MIT, Copyright (c) 2026 AmiCradle Team."""
import re
import subprocess
import sys

SOFT = re.compile(
    r"^_*(?:(?:add|sub|mul|div|neg)[sdxt]f3"
    r"|(?:fix|fixuns)[sdxt]fsi|float(?:un)?si[sdxt]f"
    r"|(?:extend|trunc)[sdxt]f[sdxt]f2"
    r"|(?:eq|ne|lt|le|gt|ge|cmp|unord)[sdxt]f2|pow[sdx]i2)$")


def soft_symbols(nm_output: str) -> list[str]:
    """The soft-float routines in nm's listing (defined or not)."""
    found = set()
    for line in nm_output.splitlines():
        parts = line.split()
        if parts and SOFT.match(parts[-1]):
            found.add(parts[-1].lstrip("_"))
    return sorted(found)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__.split("\n\n")[1].strip(), file=sys.stderr)
        return 2
    nm, bad = argv[1], 0
    for exe in argv[2:]:
        out = subprocess.run([nm, exe], capture_output=True, text=True, check=True).stdout
        soft = soft_symbols(out)
        if soft:
            bad = 1
            print(f"FPU check: FAIL {exe}: soft-float {', '.join(soft)}")
        else:
            print(f"FPU check: OK {exe}: no soft-float")
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv))
