# xmp-to-cube

A Lightroom Classic plugin that turns your develop presets and profiles — including film looks like RNI — into `.cube` 3D LUTs. Once a look is a LUT, you can use it anywhere: Photoshop, DaVinci Resolve, Affinity, Capture One, video editors, and mobile apps.

Two ways to use it:

- **Single** — convert one look into one LUT.
- **Batch** — convert every preset in a folder into LUTs in one go.

## Install

1. You need macOS with **Lightroom Classic**, plus **Python 3** and **ImageMagick** (`brew install imagemagick`).
2. In Lightroom: **File ▸ Plug-in Manager… ▸ Add**, then select the `xmp-to-cube.lrdevplugin` folder from this repo.

## Use

Both commands live under **File ▸ Plug-in Extras**.

**Batch — a whole folder**
1. Run **xmp-to-cube: Batch convert a preset folder**.
2. Pick the folder of presets you want to convert.
3. Pick an output folder — every preset in it is saved as a `.cube`.

**Single — one look**
1. Select your identity image and apply the look you want in the Develop module.
2. Run **xmp-to-cube: Export LUT from selected photo**.
3. Pick an output folder — you get one `.cube`.

## Good to know

A LUT only carries color and tone. Effects that depend on pixel position — grain, vignette, clarity, dehaze, sharpening, noise reduction, lens corrections, masks — can't be baked into a LUT and are left out.
