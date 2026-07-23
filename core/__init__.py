"""xmp-to-cube pure core: no Adobe dependency.

Modules:
    imageio16 -- 16-bit RGB TIFF read/write (via ImageMagick)
    identity  -- generate the L^3 identity lattice image
    cube      -- sample a rendered image back into an L^3 lattice and write .cube

Layout convention (shared by identity + cube, must stay in lock-step):
    For LUT size N, the image is (width = N*N, height = N).
    The lattice cell (r, g, b) with each index in [0, N-1] lives at pixel:
        x = b * N + r
        y = g
    Cell value encodes (r, g, b) mapped from [0, N-1] to [0, 65535].
"""
