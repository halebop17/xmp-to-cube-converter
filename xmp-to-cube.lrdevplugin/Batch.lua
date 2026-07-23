--[[ Function 2: batch-convert every preset in a chosen folder to .cube files.

Stripped to the exact shape that exported successfully in the single-preset test:
one top-level async task, runOpenPanel only, identity fetched READ-ONLY (no
addPhoto write), no progress scope. If this exports, we add conveniences back.

Flow: pick the preset folder (name matches a Lightroom preset group) -> pick an
output folder. For each preset: applyDevelopPreset (resolves stubbed profile ->
real film LUT), strip spatial ops, export 16-bit sRGB, build the .cube. Size 33.
]]

local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local Cube = require 'Cube'   -- pure-Lua TIFF -> .cube, bundled in the plugin

local BUILD = 'b18'
local SIZE = 33

local SPATIAL_OFF = {
    GrainAmount = 0, Clarity2012 = 0, Dehaze = 0, Texture = 0, Sharpness = 0,
    LuminanceSmoothing = 0, ColorNoiseReduction = 0,
    PostCropVignetteAmount = 0, VignetteAmount = 0,
}

local function sanitize(s) return (s:gsub('[^%w%-%. ]', '_')) end

-- Read a whole file as a byte string; write a text string to a file.
local function readBytes(path)
    local fh = io.open(path, 'rb')
    if not fh then return nil end
    local data = fh:read('*a'); fh:close(); return data
end
local function writeText(path, text)
    local fh = io.open(path, 'w')
    if not fh then return false end
    fh:write(text); fh:close(); return true
end

-- Zero-setup identity: the reference image ships inside the plugin. If it isn't
-- in the catalog yet, import it (by reference) so the user never has to. Returns
-- (photo) or (nil, errorMessage).
local function ensureIdentity(catalog, n)
    local bundled = LrPathUtils.child(LrPathUtils.child(_PLUGIN.path, 'identity'), 'identity_' .. n .. '.tif')
    local photo = catalog:findPhotoByPath(bundled)
    if photo then return photo end
    if not LrFileUtils.exists(bundled) then
        return nil, 'bundled identity image missing from the plugin:\n' .. bundled
    end
    -- Not in the catalog yet: add it. Direct withWriteAccessDo in the async task
    -- (NOT wrapped in a plain pcall) so Lightroom's task context is preserved.
    local added
    catalog:withWriteAccessDo('xmp-to-cube: import identity', function()
        added = catalog:addPhoto(bundled)
    end)
    if not added then
        return nil, 'could not import the bundled identity image into the catalog.'
    end
    return added
end

local function exportSettings(outDir)
    return {
        LR_export_destinationType = 'specificFolder', LR_export_destinationPathPrefix = outDir,
        LR_export_useSubfolder = false, LR_format = 'TIFF', LR_export_bitDepth = 16,
        LR_export_colorSpace = 'sRGB', LR_tiff_compressionMethod = 'compressionMethod_None',
        LR_size_doConstrain = false, LR_outputSharpeningOn = false,
        LR_reimportExportedPhoto = false, LR_collisionHandling = 'overwrite',
        LR_minimizeEmbeddedMetadata = true,
    }
end

-- Root cause found (d3): a plain Lua pcall strips Lightroom's task context, so an
-- export wrapped in pcall runs "outside a task" -> "must not call on main UI task".
-- Fix: use LrTasks.pcall (task-preserving) around BOTH apply and export. Simple loop,
-- no virtual copies, no bridge needed.
LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()

    local pick = LrDialogs.runOpenPanel{
        title = 'Pick the preset folder to convert (Cmd+Shift+G to paste a path)',
        canChooseFiles = false, canChooseDirectories = true, allowsMultipleSelection = false }
    if not pick then return end
    local wantName = LrPathUtils.leafName(pick[1])

    local folder, available = nil, {}
    for _, f in ipairs(LrApplication.developPresetFolders()) do
        available[#available + 1] = f:getName()
        if f:getName() == wantName then folder = f end
    end
    if not folder then
        LrDialogs.message('xmp-to-cube: folder not matched',
            'Picked "' .. wantName .. '", no Lightroom preset group has that exact name.\n\nAvailable:\n'
            .. table.concat(available, '\n'))
        return
    end
    local presets = folder:getDevelopPresets()
    if #presets == 0 then LrDialogs.message('xmp-to-cube', 'That folder has no presets.'); return end

    local outPick = LrDialogs.runOpenPanel{ title = 'Output folder for the .cube files',
        canChooseFiles = false, canChooseDirectories = true, allowsMultipleSelection = false }
    if not outPick then return end
    local outDir = outPick[1]

    local photo, idErr = ensureIdentity(catalog, SIZE)
    if not photo then
        LrDialogs.message('xmp-to-cube: identity image problem', idErr or 'No identity photo.')
        return
    end

    -- Fail fast with a clear message if the identity's master file is offline/missing,
    -- which would otherwise surface later as "render: The file could not be found".
    local idPath = photo:getRawMetadata('path')
    if not idPath or not LrFileUtils.exists(idPath) then
        LrDialogs.message('xmp-to-cube: identity file not on disk',
            'The identity photo is in the catalog but its file is missing at:\n\n'
            .. tostring(idPath) .. '\n\nRe-add the plugin so the bundled identity/identity_33.tif is present.')
        return
    end

    local settings = exportSettings(outDir)
    local done, failed, failNames, firstErr = 0, 0, {}, nil
    for _, preset in ipairs(presets) do
        local pname = preset:getName()

        -- LrTasks.pcall (NOT plain pcall) so the task context survives.
        local rendered, exErr
        local ok, err = LrTasks.pcall(function()
            catalog:withWriteAccessDo('x2c ' .. pname, function()
                photo:applyDevelopPreset(preset)
                photo:applyDevelopSettings(SPATIAL_OFF)
            end)
            local session = LrExportSession{ photosToExport = { photo }, exportSettings = settings }
            for _, r in session:renditions() do
                local rok, p = r:waitForRender()
                if rok then rendered = p else exErr = 'render: ' .. tostring(p) end
            end
        end)
        if not ok then exErr = tostring(err) end

        if rendered then
            local data = readBytes(rendered)
            local text, nn = data and Cube.buildCubeText(data, sanitize(pname))
            if text then
                local cube = LrPathUtils.child(outDir, sanitize(pname) .. '_' .. tostring(nn) .. '.cube')
                writeText(cube, text)
                LrFileUtils.delete(rendered)   -- keep the output folder .cube-only
                done = done + 1
            else
                failed = failed + 1
                failNames[#failNames + 1] = pname
                if not firstErr then firstErr = tostring(nn or 'could not read export') end
            end
        else
            failed = failed + 1
            failNames[#failNames + 1] = pname
            if not firstErr then firstErr = tostring(exErr) end
        end
    end

    LrDialogs.message('xmp-to-cube batch complete [' .. BUILD .. ']',
        string.format('%d cubes written to:\n%s\n\n%d failed%s%s',
            done, outDir, failed,
            firstErr and ('\n\nfirst error -> ' .. firstErr) or '',
            (failed > 0) and ('\n\n' .. table.concat(failNames, ', ')) or ''))
end)
