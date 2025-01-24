-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- settings.reader.lua
-- frontend/document/credocument.lua
-- frontend/ui/font.lua
--
-- match alt-/statusbar font to document font set as "default"
--
-- ATTENTION: KOReader must be restarted to apply "default" font change and the document settings reinitialized with..
-- top msenu -> document -> document settings -> reset document settings to default -> reset
-- WARNING: a load error will occur if a default font has not been set to properly initialize "settings.reader.lua"
-- NOTE: fontface expected to be in fontface folder

-- default document font family
local DataStorage = require("datastorage")
local G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
local fontface = G_reader_settings:readSetting("cre_font")  -- default font

local CreDocument = require("document/credocument")         -- set alt-statusbar font family
CreDocument.header_font = fontface  -- see frontend/apps/reader/modules/readerfont.lua:onReadSettings()

-- set statusbar font source
local Font = require("ui/font")
local names = { "-normalbookupright.ttf", "-book.ttf", "-book.otf", "-regular.ttf", "-regular.otf" }  -- selection order of user ttf and otf font files

for _, n in pairs(names) do
	local f = io.open(DataStorage:getDataDir() .. "/fonts/" .. fontface .. "/" .. fontface .. n, "r")
	if f ~= nil then  -- font source exists
		io.close(f)
		local filename = fontface .. n
		for k, _ in pairs(Font.fontmap) do
			if k == "ffont" then
				Font.fontmap[k] = filename
			elseif k == "smallffont" then
				Font.fontmap[k] = filename
			elseif k == "largeffont" then
				Font.fontmap[k] = filename
			end
		end
		break
	end
end

