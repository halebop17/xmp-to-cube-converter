"""Generate the identity lattice ("Hald"-style) image for a given LUT size.

The image is fed through Lightroom with a look applied; sampling it back
(see cube.py) yields the LUT. Because we own both generation and sampling, the
layout is our own simple deterministic grid rather than a canonical Hald square.

Layout (see core/__init__.py): width = N*N, height = N,
    pixel (x, y) holds lattice cell (r, g, b) where b = x // N, r = x % N, g = y.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

from .imageio16 import write_tiff16

U16_MAX = 65535


def index_to_u16(n: int) -> np.ndarray:
    """Map lattice indices [0, N-1] -> uint16 code values [0, 65535], endpoints exact."""
    idx = np.arange(n, dtype=np.float64)
    return np.rint(idx * U16_MAX / (n - 1)).astype(np.uint16)


def identity_array(n: int) -> np.ndarray:
    """Return the (N, N*N, 3) uint16 identity image as a numpy array."""
    if n < 2:
        raise ValueError("LUT size must be >= 2")
    codes = index_to_u16(n)  # (N,)

    # Build via index grids so the mapping is explicit and matches cube.py exactly.
    r = np.arange(n)
    g = np.arange(n)
    b = np.arange(n)
    # x = b*N + r  -> columns; y = g -> rows.
    # Column index c in [0, N*N): b = c // N, r = c % N.
    col = np.arange(n * n)
    col_b = col // n
    col_r = col % n

    img = np.empty((n, n * n, 3), dtype=np.uint16)
    img[:, :, 0] = codes[col_r][None, :]          # R varies within each N-block
    img[:, :, 1] = codes[g][:, None]              # G varies down rows
    img[:, :, 2] = codes[col_b][None, :]          # B selects the N-block
    return img


def write_identity(path: str | Path, n: int, icc_profile: str | Path | None = None) -> tuple[int, int]:
    """Write the identity image for size ``n``; return (width, height)."""
    img = identity_array(n)
    write_tiff16(path, img, icc_profile=icc_profile)
    return img.shape[1], img.shape[0]
