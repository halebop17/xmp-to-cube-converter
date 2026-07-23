--[[ M0 spike: export the selected photo's rendered develop state and build a .cube.

Workflow:
  1. Generate an identity image:  python3 cli.py gen-identity --size 33 --out identity_33.tif
  2. Import identity_33.tif into Lightroom.
  3. Select it, go to Develop, apply your RNI 5 profile (Profile Browser). Sliders at
     default is correct for a profile-based look.
  4. Run this menu item, pick an output folder.
The plugin exports a 16-bit sRGB TIFF (no resize, no output sharpening), derives the
LUT size from the export height, and calls the Python core to write the .cube.
]]

local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

-- Tools. Full paths because LrTasks.execute runs with a minimal PATH.
local PYTHON = '/opt/homebrew/bin/python3'
local MAGICK = '/opt/homebrew/bin/magick'
local EXTRA_PATH = '/opt/homebrew/bin'          -- prepended so the Python core finds `magick`

local REPO = LrPathUtils.parent(_PLUGIN.path)   -- the plugin lives inside the repo
local CLI = LrPathUtils.child(REPO, 'cli.py')

-- Run a shell command, capturing stdout via a temp file. Returns (exitCode, stdout).
local function capture(cmd)
    local tmp = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'),
        'x2c_out_' .. tostring(LrApplication.activeCatalog():getPath():len()) .. '.txt')
    local full = string.format('PATH=%s:$PATH %s > "%s" 2>&1', EXTRA_PATH, cmd, tmp)
    local rc = LrTasks.execute(full)
    local out = LrFileUtils.exists(tmp) and (LrFileUtils.readFile(tmp) or '') or ''
    LrFileUtils.delete(tmp)
    return rc, out
end

local function trim(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    if not photo then
        LrDialogs.message('xmp-to-cube', 'Select the identity photo (with your look applied) first.')
        return
    end

    local folders = LrDialogs.runOpenPanel({
        title = 'Choose output folder for the .cube',
        canChooseFiles = false,
        canChooseDirectories = true,
        allowsMultipleSelection = false,
    })
    if not folders or #folders == 0 then return end
    local outDir = folders[1]

    -- Export a 16-bit sRGB TIFF of the rendered develop state.
    local exportSettings = {
        LR_export_destinationType = 'specificFolder',
        LR_export_destinationPathPrefix = outDir,
        LR_export_useSubfolder = false,
        LR_format = 'TIFF',
        LR_export_bitDepth = 16,
        LR_export_colorSpace = 'sRGB',
        LR_tiff_compressionMethod = 'compressionMethod_None',
        LR_size_doConstrain = false,            -- no resize
        LR_outputSharpeningOn = false,          -- no output sharpening
        LR_reimportExportedPhoto = false,
        LR_collisionHandling = 'overwrite',
        LR_minimizeEmbeddedMetadata = true,
    }

    local session = LrExportSession({
        photosToExport = { photo },
        exportSettings = exportSettings,
    })

    local renderedPath
    for _, rendition in session:renditions() do
        local ok, pathOrMsg = rendition:waitForRender()
        if ok then
            renderedPath = pathOrMsg
        else
            LrDialogs.message('xmp-to-cube', 'Export failed: ' .. tostring(pathOrMsg))
            return
        end
    end
    if not renderedPath then
        LrDialogs.message('xmp-to-cube', 'No rendered file produced.')
        return
    end

    -- LUT size N = export height (identity image is N tall, N*N wide).
    local rcH, hOut = capture(string.format('"%s" identify -format "%%h" "%s"', MAGICK, renderedPath))
    local n = tonumber(trim(hOut))
    if not n or n < 2 then
        LrDialogs.message('xmp-to-cube',
            'Could not read LUT size from export height.\nidentify said: ' .. tostring(hOut))
        return
    end

    -- Build the .cube via the Python core.
    local name = photo:getFormattedMetadata('fileName') or 'LUT'
    name = name:gsub('%.%w+$', '')
    local cubePath = LrPathUtils.child(outDir, name .. '_' .. n .. '.cube')
    local buildCmd = string.format('"%s" "%s" build-cube --size %d --in "%s" --out "%s" --title "%s"',
        PYTHON, CLI, n, renderedPath, cubePath, name)
    local rcB, buildOut = capture(buildCmd)

    if rcB == 0 then
        LrDialogs.message('xmp-to-cube: done',
            string.format('LUT_3D_SIZE %d\n\nRendered: %s\nCube: %s', n, renderedPath, cubePath))
    else
        LrDialogs.message('xmp-to-cube: build failed',
            'Command exited ' .. tostring(rcB) .. '\n\n' .. tostring(buildOut))
    end
end)
