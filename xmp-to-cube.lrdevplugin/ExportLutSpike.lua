--[[ Export the selected photo's rendered develop state and build a .cube.

Workflow:
  1. Import the bundled identity image (identity/identity_33.tif) into Lightroom.
  2. Select it, go to Develop, apply your profile/preset (a profile-based look
     is correct with the sliders at default).
  3. Run this menu item, pick an output folder -> you get one .cube.
The plugin exports a 16-bit sRGB TIFF (no resize, no output sharpening), derives
the LUT size from the export height, and builds the .cube in pure Lua (Cube.lua)
-- no Python, no ImageMagick, nothing to install.
]]

local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local Cube = require 'Cube'

local function readBytes(path)
    local fh = io.open(path, 'rb')
    if not fh then return nil end
    local data = fh:read('*a'); fh:close(); return data
end
local function writeText(path, text)
    -- 'wb': in text mode the Windows CRT turns every \n into \r\n, so the same
    -- photo would produce a different .cube on Windows than on macOS.
    local fh = io.open(path, 'wb')
    if not fh then return false end
    fh:write(text); fh:close(); return true
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

    -- Build the .cube in pure Lua. LUT size N is inferred from the export height.
    local name = photo:getFormattedMetadata('fileName') or 'LUT'
    name = name:gsub('%.%w+$', '')

    local data = readBytes(renderedPath)
    local text, nOrErr = data and Cube.buildCubeText(data, name)
    if not text then
        LrDialogs.message('xmp-to-cube: build failed', tostring(nOrErr or 'could not read export'))
        return
    end

    local cubePath = LrPathUtils.child(outDir, name .. '_' .. nOrErr .. '.cube')
    if not writeText(cubePath, text) then
        LrDialogs.message('xmp-to-cube', 'Could not write .cube to:\n' .. cubePath)
        return
    end
    LrFileUtils.delete(renderedPath)   -- leave only the .cube in the output folder

    LrDialogs.message('xmp-to-cube: done',
        string.format('LUT_3D_SIZE %d\n\nCube: %s', nOrErr, cubePath))
end)
