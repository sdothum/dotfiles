-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- settings.reader.lua
-- frontend/document/credocument.lua
-- frontend/ui/font.lua
--
-- match alt-/statusbar font to document font set as "default"

-- ATTENTION: KOReader must be restarted to apply "default" font change and the document settings reinitialized with..
-- top msenu -> document -> document settings -> reset document settings to default -> reset

-- default document font family
local DataStorage = require("datastorage")
local G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")

local fontface = G_reader_settings:readSetting("cre_font")

-- set alt-statusbar font family
local CreDocument = require("document/credocument")

CreDocument.header_font = fontface  -- see frontend/apps/reader/modules/readerfont.lua:onReadSettings()

-- set statusbar font source
local Font = require("ui/font")

names = { "-book.ttf", "-book.otf", "-regular.ttf", "-regular.otf" }  -- selection order of user ttf and otf font files

for _, n in pairs(names) do
	local f = io.open(DataStorage:getDataDir() .. "/fonts/CUSTOM/" .. fontface .. n, "r")  -- NOTE: folder for keeping "custom" fonts separate from KOReader installed fonts!
	if f ~= nil then  -- font source exists
		io.close(f)
		local fontsource = fontface .. n
		for k, _ in pairs(Font.fontmap) do
			if k == "ffont" then
				Font.fontmap[k] = fontsource
			elseif k == "smallffont" then
				Font.fontmap[k] = fontsource
			elseif k == "largeffont" then
				Font.fontmap[k] = fontsource
			end
		end
		break
	end
end

