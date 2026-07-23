--[[ Read-only SDK probe (informs M2: programmatic apply).

Select a photo that ALREADY has your RNI 5 profile applied, then run this. It:
  * counts develop-preset folders/presets (proves enumeration works), and
  * dumps every develop-setting key that looks profile/look-related, so we can
    see exactly how the applied profile is represented -> how to set it in code.
Results are written to a text file on your Desktop and shown in a dialog.
Nothing is modified.
]]

local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

local function looksProfileRelated(key)
    local k = key:lower()
    return k:find('profile') or k:find('look') or k:find('camera') or k:find('convert')
end

-- Recursively render a Lua value (tables expanded) for inspection. Depth/length capped.
local function dump(v, indent, depth)
    indent = indent or ''
    depth = depth or 0
    if type(v) ~= 'table' then
        local s = tostring(v)
        if type(v) == 'string' and #s > 120 then s = s:sub(1, 120) .. ('...(%d chars)'):format(#s) end
        return s
    end
    if depth > 4 then return '<table: too deep>' end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local out = { '{' }
    for _, k in ipairs(keys) do
        out[#out + 1] = string.format('%s  %s = %s', indent, k, dump(v[k], indent .. '  ', depth + 1))
    end
    out[#out + 1] = indent .. '}'
    return table.concat(out, '\n')
end

LrTasks.startAsyncTask(function()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    -- 1. Preset enumeration.
    local folders = LrApplication.developPresetFolders()
    add('Develop preset folders: ' .. tostring(#folders))
    local total = 0
    for _, folder in ipairs(folders) do
        local presets = folder:getDevelopPresets()
        total = total + #presets
    end
    add('Total develop presets: ' .. total)
    if #folders > 0 then
        local sample = folders[1]:getDevelopPresets()
        if #sample > 0 then
            add('Example preset name: ' .. tostring(sample[1]:getName()))
        end
    end
    add('')

    -- 2. Selected photo's develop settings, profile-related keys.
    local catalog = LrApplication.activeCatalog()
    local photo = catalog:getTargetPhoto()
    if not photo then
        add('No photo selected -> skipping develop-settings dump.')
    else
        add('Photo: ' .. tostring(photo:getFormattedMetadata('fileName')))
        add('File format: ' .. tostring(photo:getRawMetadata('fileFormat')))
        local settings = photo:getDevelopSettings()
        add('Develop settings keys: ' .. tostring((function()
            local c = 0; for _ in pairs(settings) do c = c + 1 end; return c
        end)()))
        add('--- profile/look-related keys ---')
        local hits = 0
        for k, v in pairs(settings) do
            if looksProfileRelated(k) then
                hits = hits + 1
                add(string.format('  %s = %s', k, tostring(v)))
            end
        end
        if hits == 0 then add('  (none matched -- dumping ALL keys below)') end
        add('')
        add('--- FULL "Look" table (this is what M2 needs) ---')
        if type(settings.Look) == 'table' then
            add(dump(settings.Look, '', 0))
        else
            add('  Look = ' .. tostring(settings.Look))
        end
        add('')
        add('--- all keys (name only) ---')
        local names = {}
        for k in pairs(settings) do names[#names + 1] = k end
        table.sort(names)
        add('  ' .. table.concat(names, ', '))
    end

    local text = table.concat(lines, '\n')
    local outPath = LrPathUtils.child(LrPathUtils.getStandardFilePath('desktop'), 'xmp-to-cube-probe.txt')
    local f = io.open(outPath, 'w')
    if f then f:write(text); f:close() end

    LrDialogs.message('xmp-to-cube: SDK probe',
        text .. '\n\nSaved to: ' .. outPath)
end)
