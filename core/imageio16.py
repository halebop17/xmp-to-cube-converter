"""16-bit RGB TIFF I/O via ImageMagick.

Pillow cannot handle 48-bit (16-bit-per-channel) RGB, so we shell out to
ImageMagick and exchange raw little-endian RGB16 buffers, which is bit-exact
(verified round-trip). Everything here is pure: no Adobe involved.
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import numpy as np

# ImageMagick 7 ships `magick`; older installs expose `convert`.
_MAGICK = shutil.which("magick") or shutil.which("convert")


def _require_magick() -> str:
    if _MAGICK is None:
        raise RuntimeError(
            "ImageMagick not found. Install it (e.g. `brew install imagemagick`)."
        )
    return _MAGICK


def write_tiff16(path: str | Path, arr: np.ndarray, icc_profile: str | Path | None = None) -> None:
    """Write an (H, W, 3) uint16 array as a 16-bit RGB TIFF.

    If ``icc_profile`` is given, it is *assigned* (not converted) so the pixels
    are declared to live in that space without being remapped.
    """
    magick = _require_magick()
    if arr.ndim != 3 or arr.shape[2] != 3:
        raise ValueError(f"expected (H, W, 3) array, got shape {arr.shape}")
    h, w, _ = arr.shape
    raw = np.ascontiguousarray(arr, dtype="<u2").tobytes()

    cmd = [magick, "-size", f"{w}x{h}", "-depth", "16", "-endian", "LSB", "rgb:-"]
    if icc_profile is not None:
        # -profile assigns an ICC profile to an image that has none (no conversion).
        cmd += ["-profile", str(icc_profile)]
    cmd += [str(path)]
    subprocess.run(cmd, input=raw, check=True)


def read_tiff16(path: str | Path) -> np.ndarray:
    """Read any image ImageMagick understands as an (H, W, 3) uint16 array."""
    magick = _require_magick()
    # Query dimensions first so we can reshape the raw stream.
    dims = subprocess.run(
        [magick, "identify", "-format", "%w %h", str(path)],
        capture_output=True, check=True, text=True,
    ).stdout.split()
    w, h = int(dims[0]), int(dims[1])
    res = subprocess.run(
        [magick, str(path), "-depth", "16", "-endian", "LSB", "rgb:-"],
        capture_output=True, check=True,
    )
    return np.frombuffer(res.stdout, dtype="<u2").reshape(h, w, 3)
