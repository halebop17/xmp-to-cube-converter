# xmp-to-cube

A Lightroom Classic plugin that turns your develop presets and profiles — including film looks like RNI — into `.cube` 3D LUTs. Once a look is a LUT, you can use it anywhere: Photoshop, DaVinci Resolve, Affinity, Capture One, video editors, and mobile apps.

It's **fully self-contained**: the whole conversion runs inside the plugin. No Python, no Homebrew, no ImageMagick, nothing to install alongside Lightroom.

## Install

1. Download this repo (green **Code ▸ Download ZIP**, then unzip) — or clone it.
2. In Lightroom Classic: **File ▸ Plug-in Manager… ▸ Add**, and select the
   `xmp-to-cube.lrdevplugin` folder.

That's it. The only requirement is **Lightroom Classic** itself.

## How it works

The plugin applies your look to a small reference image that ships inside it, then
reads the rendered result back and writes the `.cube`. That reference image is
imported into your catalog **automatically** the first time you run the batch
command — there's no setup step.

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

## Good to know

A LUT only carries color and tone. Effects that depend on pixel position — grain,
vignette, clarity, dehaze, sharpening, noise reduction, lens corrections, masks —
can't be baked into a LUT and are left out.

## How it's built

Everything runs inside the plugin — the converter is pure Lua
([`Cube.lua`](xmp-to-cube.lrdevplugin/Cube.lua)), which reads Lightroom's 16-bit TIFF
export and writes the `.cube` directly. It was validated to produce byte-identical
output against a reference NumPy/ImageMagick implementation across both TIFF byte
orders and every strip layout.
