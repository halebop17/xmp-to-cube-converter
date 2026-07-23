#!/usr/bin/env python3
"""xmp-to-cube command-line core (no Adobe dependency).

Two commands bracket the Lightroom step:

    # 1. make the identity image to import into Lightroom
    python3 cli.py gen-identity --size 33 --out identity_33.tif

    # ... in Lightroom: apply a look to that image, export a 16-bit TIFF ...

    # 2. turn the rendered export back into a .cube
    python3 cli.py build-cube --size 33 --in rendered_33.tif --out MyLook.cube --title "My Look"

    # self-check the pipeline with no Lightroom in the loop:
    python3 cli.py selftest --size 33
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from core.identity import identity_array, write_identity  # noqa: E402
from core.cube import sample_lattice, format_cube, build_cube_from_image  # noqa: E402
from core.imageio16 import write_tiff16, read_tiff16  # noqa: E402

# Default macOS sRGB ICC; assigned (not converted) to the identity image.
DEFAULT_ICC = "/System/Library/ColorSync/Profiles/sRGB Profile.icc"


def _icc_arg(value: str | None) -> str | None:
    if value in (None, "none", ""):
        return None
    return value


def cmd_gen_identity(a: argparse.Namespace) -> int:
    icc = _icc_arg(a.icc)
    if icc and not Path(icc).exists():
        print(f"warning: ICC profile not found, writing untagged: {icc}", file=sys.stderr)
        icc = None
    w, h = write_identity(a.out, a.size, icc_profile=icc)
    print(f"wrote {a.out}  ({w}x{h}, 16-bit{', sRGB-tagged' if icc else ''})")
    return 0


def cmd_build_cube(a: argparse.Namespace) -> int:
    build_cube_from_image(a.inp, a.size, a.out, title=a.title, domain=not a.no_domain)
    print(f"wrote {a.out}  (LUT_3D_SIZE {a.size})")
    return 0


def cmd_selftest(a: argparse.Namespace) -> int:
    """Prove gen->write->read->sample->cube is loss-free through actual disk I/O."""
    n = a.size
    tmp = Path(a.out or ".") / f"_selftest_{n}.tif"
    write_tiff16(tmp, identity_array(n))
    img = read_tiff16(tmp)
    lattice = sample_lattice(img, n)
    axis = np.arange(n) / (n - 1)
    expected = np.stack(np.meshgrid(axis, axis, axis, indexing="ij"), axis=-1)
    max_delta = float(np.max(np.abs(lattice - expected)))
    tmp.unlink(missing_ok=True)
    ok = max_delta < 2e-5
    print(f"selftest size {n}: max delta {max_delta:.2e} -> {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="xmp-to-cube", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("gen-identity", help="write the identity image to import into Lightroom")
    g.add_argument("--size", type=int, required=True, help="LUT size N (e.g. 17, 33, 64)")
    g.add_argument("--out", required=True, help="output .tif path")
    g.add_argument("--icc", default=DEFAULT_ICC, help="ICC to assign, or 'none'")
    g.set_defaults(func=cmd_gen_identity)

    b = sub.add_parser("build-cube", help="turn a rendered identity export into a .cube")
    b.add_argument("--size", type=int, required=True, help="LUT size N (must match the identity)")
    b.add_argument("--in", dest="inp", required=True, help="rendered identity image from Lightroom")
    b.add_argument("--out", required=True, help="output .cube path")
    b.add_argument("--title", default=None, help="optional LUT title")
    b.add_argument("--no-domain", action="store_true", help="omit DOMAIN_MIN/MAX header")
    b.set_defaults(func=cmd_build_cube)

    s = sub.add_parser("selftest", help="round-trip check through disk, no Lightroom")
    s.add_argument("--size", type=int, default=33)
    s.add_argument("--out", default=None, help="scratch dir for temp file")
    s.set_defaults(func=cmd_selftest)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
