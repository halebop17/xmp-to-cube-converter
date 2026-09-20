--[[ xmp-to-cube -- Lightroom Classic plugin manifest.

Two functions, both under File > Plug-in Extras:
  1. Export LUT from selected photo  -- apply a look by hand, export one .cube.
  2. Batch convert a preset folder   -- every preset in a folder -> a .cube each.
Plus a read-only SDK probe for diagnostics.
]]
return {
    LrSdkVersion = 13.0,
    LrSdkMinimumVersion = 6.0,

    LrToolkitIdentifier = 'com.xmptocube.lrplugin',
    LrPluginName = 'xmp-to-cube',

    LrExportMenuItems = {
        {
            title = 'xmp-to-cube: Export LUT from selected photo',
            file = 'ExportLutSpike.lua',
        },
        {
            title = 'xmp-to-cube: Batch convert a preset folder',
            file = 'Batch.lua',
        },
        {
            title = 'xmp-to-cube: Probe SDK (diagnostics)',
            file = 'ProbeSdk.lua',
        },
    },

    VERSION = { major = 0, minor = 3, revision = 0 },
}
