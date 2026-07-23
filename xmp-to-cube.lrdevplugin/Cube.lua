--[[ Cube.lua -- pure-Lua identity-lattice TIFF -> .cube converter.

Replaces the old Python + numpy + ImageMagick core so the plugin is fully
self-contained: no external interpreter, no Homebrew, nothing to install
alongside Lightroom.

Only the exact file Lightroom exports has to be read: an *uncompressed*,
16-bit-per-channel, chunky RGB TIFF (LR_export_bitDepth = 16,
LR_tiff_compressionMethod = 'compressionMethod_None'). Both byte orders (II/MM)
and any strip layout are handled; compressed or planar input is rejected with a
clear message rather than producing garbage.

Layout MUST match core/identity.py + core/cube.py (the reference oracle):
    image is (H = N) tall, (W = N*N) wide; cell (r, g, b) lives at
    pixel (x = b*N + r, y = g); .cube body orders red fastest, then green, blue.

Lua 5.1 safe: no bitwise operators, no integer '//', no goto. Byte assembly is
plain arithmetic; Lua numbers are doubles and represent 32-bit values exactly.
]]

local Cube = {}

-- TIFF field type -> size in bytes (only the ones we read).
local TYPE_SIZE = { [1] = 1, [3] = 2, [4] = 4 }

-- Build order-aware byte readers over a 0-indexed view of a Lua string.
-- `s` is the whole string (1-indexed); off is a 0-indexed offset into it.
local function makeReaders(s, little)
    local byte = string.byte
    local function u8(off) return byte(s, off + 1) end
    local u16, u32
    if little then
        u16 = function(off) return u8(off) + u8(off + 1) * 256 end
        u32 = function(off)
            return u8(off) + u8(off + 1) * 256 + u8(off + 2) * 65536 + u8(off + 3) * 16777216
        end
    else
        u16 = function(off) return u8(off) * 256 + u8(off + 1) end
        u32 = function(off)
            return u8(off) * 16777216 + u8(off + 1) * 65536 + u8(off + 2) * 256 + u8(off + 3)
        end
    end
    return u8, u16, u32
end

-- Parse the minimal set of tags from the first IFD and return the assembled,
-- chunky 16-bit RGB pixel string plus geometry. Returns (info) or (nil, err).
local function parseTiff(data)
    if #data < 8 then return nil, 'file too small to be a TIFF' end
    local bom = data:sub(1, 2)
    local little
    if bom == 'II' then little = true
    elseif bom == 'MM' then little = false
    else return nil, 'not a TIFF (bad byte-order mark)' end

    local _, u16, u32 = makeReaders(data, little)
    if u16(2) ~= 42 then return nil, 'not a TIFF (bad magic)' end

    local ifd = u32(4)
    if ifd == 0 or ifd + 2 > #data then return nil, 'bad IFD offset' end
    local count = u16(ifd)

    -- Return the list of numeric values for one IFD entry.
    local function entryValues(entryOff)
        local typ = u16(entryOff + 2)
        local cnt = u32(entryOff + 4)
        local tsize = TYPE_SIZE[typ]
        if not tsize then return {} end          -- type we never ask for; ignore
        local total = tsize * cnt
        local base
        if total <= 4 then base = entryOff + 8   -- value stored inline, left-justified
        else base = u32(entryOff + 8) end        -- value field is an offset to the array
        local vals = {}
        for i = 0, cnt - 1 do
            local o = base + i * tsize
            if typ == 3 then vals[#vals + 1] = u16(o)
            elseif typ == 4 then vals[#vals + 1] = u32(o)
            else vals[#vals + 1] = string.byte(data, o + 1) end
        end
        return vals
    end

    local tags = {}
    for i = 0, count - 1 do
        local entryOff = ifd + 2 + i * 12
        if entryOff + 12 > #data then return nil, 'truncated IFD' end
        local tag = u16(entryOff)
        tags[tag] = entryValues(entryOff)
    end

    local function first(tag, default)
        local v = tags[tag]
        if v and v[1] ~= nil then return v[1] end
        return default
    end

    local width  = first(256)
    local height = first(257)
    if not width or not height then return nil, 'missing image dimensions' end
    local compression = first(259, 1)
    if compression ~= 1 then
        return nil, 'compressed TIFF (compression=' .. tostring(compression)
            .. '); export with compression set to None'
    end
    local spp = first(277, 3)
    if spp < 3 then return nil, 'expected >= 3 samples per pixel, got ' .. tostring(spp) end
    local planar = first(284, 1)
    if planar ~= 1 then return nil, 'planar TIFF unsupported; need chunky (interleaved) RGB' end
    local bps = tags[258] or { 16, 16, 16 }
    for i = 1, 3 do
        if bps[i] ~= 16 then
            return nil, 'expected 16 bits per sample, got ' .. tostring(bps[i]) .. ' on channel ' .. i
        end
    end

    local offsets = tags[273]
    local counts = tags[279]
    if not offsets or #offsets == 0 then return nil, 'no strip offsets' end
    if not counts or #counts ~= #offsets then return nil, 'strip offset/count mismatch' end

    local parts = {}
    for i = 1, #offsets do
        local o, c = offsets[i], counts[i]
        if o + c > #data then return nil, 'strip runs past end of file' end
        parts[i] = data:sub(o + 1, o + c)
    end
    local pix = table.concat(parts)

    local stride = spp * 2                         -- bytes per pixel (RGB[A], 16-bit)
    local expected = width * height * stride
    if #pix < expected then
        return nil, 'pixel data short: have ' .. #pix .. ' need ' .. expected
    end

    return { width = width, height = height, stride = stride, pix = pix, little = little }
end

-- Turn a rendered identity TIFF (as a byte string) into .cube text.
-- Returns (cubeText, n) or (nil, err).
function Cube.buildCubeText(data, title, domain)
    if domain == nil then domain = true end
    local info, err = parseTiff(data)
    if not info then return nil, err end

    local n = info.height
    if info.width ~= n * n then
        return nil, 'geometry ' .. info.width .. 'x' .. n
            .. ' is not an identity lattice (expected width ' .. (n * n) .. ')'
    end

    local pix, stride, little = info.pix, info.stride, info.little
    local byte = string.byte
    local rd16
    if little then
        rd16 = function(off) return byte(pix, off + 1) + byte(pix, off + 2) * 256 end
    else
        rd16 = function(off) return byte(pix, off + 1) * 256 + byte(pix, off + 2) end
    end

    -- Pixel (x, y) channel c (0-based) -> value byte offset in the chunky buffer.
    local w = info.width
    local function sample(x, y, c)
        return rd16((y * w + x) * stride + c * 2) / 65535
    end

    local out = {}
    if title and title ~= '' then out[#out + 1] = 'TITLE "' .. title .. '"' end
    out[#out + 1] = 'LUT_3D_SIZE ' .. n
    if domain then
        out[#out + 1] = 'DOMAIN_MIN 0.0 0.0 0.0'
        out[#out + 1] = 'DOMAIN_MAX 1.0 1.0 1.0'
    end
    out[#out + 1] = ''

    -- red fastest -> inner loop over r; then g; outer b. cell (r,g,b) at (x=b*N+r, y=g).
    local fmt = string.format
    for b = 0, n - 1 do
        for g = 0, n - 1 do
            local y = g
            for r = 0, n - 1 do
                local x = b * n + r
                out[#out + 1] = fmt('%.6f %.6f %.6f',
                    sample(x, y, 0), sample(x, y, 1), sample(x, y, 2))
            end
        end
    end
    return table.concat(out, '\n') .. '\n', n
end

return Cube
