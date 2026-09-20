# xmp-to-cube

A Lightroom Classic plugin that turns your develop presets and profiles — including film looks like RNI — into `.cube` 3D LUTs. Once a look is a LUT, you can use it anywhere: Photoshop, DaVinci Resolve, Affinity, Capture One, video editors, and mobile apps.

It's **fully self-contained**: the whole conversion runs inside the plugin. No Python, no Homebrew, no ImageMagick, nothing to install alongside Lightroom.

## Install

1. Download this repo (green **Code ▸ Download ZIP**, then unzip) — or clone it.
2. In Lightroom Classic: **File ▸ Plug-in Manager… ▸ Add**, and select the
   `xmp-to-cube.lrdevplugin` folder.

That's it. The only requirement is **Lightroom Classic** itself.

The plugin is pure Lua, so the same folder installs on **macOS and Windows** —
there is no separate build for either platform.

## How it works

The plugin applies your look to a small reference image that ships inside it, then
reads the rendered result back and writes the `.cube`. On first use that image is
copied to `xmp-to-cube/identity_33.tif` in your Lightroom app-data folder and
imported into your catalog **automatically** — there's no setup step. It is used
from the copy rather than from the plugin folder so that Lightroom's metadata
writeback never modifies the shipped file.

Before each preset is applied, the reference image is reset to Lightroom's default
develop settings. That matters for *partial* presets — ones saved without every
group ticked — which would otherwise inherit whatever the previous preset in the
batch left behind and blend two looks into one `.cube`.

## Use

Both commands live under **File ▸ Plug-in Extras**.

**Batch — a whole folder of presets**
1. Run **xmp-to-cube: Batch convert a preset folder**.
2. Pick a folder whose name matches one of your Lightroom preset groups.
3. Pick an output folder — every preset in the group is saved as a `.cube`.

**Single — one look**
1. Select the reference image `identity_33.tif` (imported automatically on the
   first batch run), go to **Develop**, and apply the look you want (a profile-based
   look is correct with the sliders at their defaults).
2. Run **xmp-to-cube: Export LUT from selected photo**.
3. Pick an output folder — you get one `.cube`.

## Upgrading from 0.2.0

Version 0.2.0 shipped a reference image that had a film profile baked into its
metadata, so LUTs built with it could carry that look on top of your own. Version
0.3.0 ships a clean reference image and imports it from a new path, so upgrading
fixes this by itself. **Re-run any conversions you did with 0.2.0.** The stale
`identity_33.tif` left in your catalog from the old version is no longer used and
can be removed.

## Good to know

A LUT only carries color and tone. Effects that depend on pixel position — grain,
vignette, clarity, dehaze, sharpening, noise reduction, lens corrections, masks —
can't be baked into a LUT and are left out.

## How it's built

Everything runs inside the plugin — the converter is pure Lua
([`Cube.lua`](xmp-to-cube.lrdevplugin/Cube.lua)), which reads Lightroom's 16-bit TIFF
export and writes the `.cube` directly. It was validated to produce byte-identical
output against a reference NumPy/ImageMagick implementation across both TIFF byte
orders and every strip layout. The `.cube` is written in binary mode, so a given
preset yields the same bytes on Windows as on macOS.
