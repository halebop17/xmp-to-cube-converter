"""Sample a rendered lattice image back into an L^3 grid and write a .cube LUT.

Sampling layout MUST match core/identity.py exactly:
    cell (r, g, b) lives at pixel (x = b*N + r, y = g).

.cube body ordering (IRIDAS/Adobe): red index varies fastest, then green,
then blue. So the write loops are: for b: for g: for r.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

from .imageio16 import read_tiff16

U16_MAX = 65535.0


def sample_lattice(img: np.ndarray, n: int) -> np.ndarray:
    """Return an (N, N, N, 3) float array indexed [r, g, b] in [0, 1].

    ``img`` is the rendered (N, N*N, 3) uint16 image.
    """
    exp_h, exp_w = n, n * n
    if img.shape[:2] != (exp_h, exp_w):
        raise ValueError(
            f"image is {img.shape[1]}x{img.shape[0]}, expected {exp_w}x{exp_h} for size {n}"
        )
    out = np.empty((n, n, n, 3), dtype=np.float64)
    # Vectorised sample: for every (r, g, b), read pixel (y=g, x=b*N+r).
    r = np.arange(n)[:, None, None]
    g = np.arange(n)[None, :, None]
    b = np.arange(n)[None, None, :]
    x = b * n + r            # (N,1,N) broadcast target x
    y = g                    # (1,N,1) broadcast target y
    xx, yy = np.broadcast_arrays(x, y)  # -> (N,N,N)
    out[:] = img[yy, xx].astype(np.float64) / U16_MAX
    return out


def format_cube(lattice: np.ndarray, title: str | None = None, domain: bool = True) -> str:
    """Render an (N, N, N, 3) [r,g,b]->color lattice as .cube text."""
    n = lattice.shape[0]
    lines: list[str] = []
    if title:
        lines.append(f'TITLE "{title}"')
    lines.append(f"LUT_3D_SIZE {n}")
    if domain:
        lines.append("DOMAIN_MIN 0.0 0.0 0.0")
        lines.append("DOMAIN_MAX 1.0 1.0 1.0")
    lines.append("")
    # red fastest -> innermost loop over r; then g; outer b.
    for b in range(n):
        for g in range(n):
            for r in range(n):
                cr, cg, cb = lattice[r, g, b]
                lines.append(f"{cr:.6f} {cg:.6f} {cb:.6f}")
    return "\n".join(lines) + "\n"


def build_cube_from_image(
    rendered_path: str | Path, n: int, out_path: str | Path,
    title: str | None = None, domain: bool = True,
) -> None:
    """Read a rendered identity image and write its .cube LUT."""
    img = read_tiff16(rendered_path)
    lattice = sample_lattice(img, n)
    text = format_cube(lattice, title=title, domain=domain)
    Path(out_path).write_text(text)
