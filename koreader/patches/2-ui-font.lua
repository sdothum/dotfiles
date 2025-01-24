-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- settings.reader.lua
-- frontend/ui/font.lua
--
-- override system UI font
--
-- NOTE: this does not consistently override widget titles and dictionary lookups
--       which can result in unusal fontface pairings

local Font = require("ui/font")

-- a nice dictionary font (must be installed)
local regular = "AtkinsonHyperlegible-Regular.ttf"
local bold = "AtkinsonHyperlegible-Bold.ttf"

-- default document font family
local DataStorage = require("datastorage")
local G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
local fontface = G_reader_settings:readSetting("cre_font")  -- default font

local names = { "-normalbookupright.ttf", "-book.ttf", "-book.otf", "-regular.ttf", "-regular.otf" }  -- selection order of user ttf and otf font files

for _, n in pairs(names) do
	local f = io.open(DataStorage:getDataDir() .. "/fonts/" .. fontface .. "/" .. fontface .. n, "r")
	if f ~= nil then  -- font source exists
		io.close(f)
		if n == "-normalbookupright.ttf" then
			regular = fontface .. n
			bold = fontface .. "-normalboldupright.ttf"
			-- regular = bold  -- FOR: increase dictionary contrast
		end
		break              -- if default font is a standard font, use AtkinsonHyperlegible font
	end
end

for k, v in pairs(Font.fontmap) do
	if v == "NotoSans-Regular.ttf" then
		Font.fontmap[k] = regular
	elseif v == "NotoSans-Bold.ttf" then
		Font.fontmap[k] = bold
	end
end

-- HACK: use screen dpi setting to reduce overall system UI proportions
if regular == bold then        -- setting UI font to custom Iosevka font
	for k, v in pairs(Font.sizemap) do
		Font.sizemap[k] = v - 1  -- NOTE: line spacing (positioning) remains unaffected
	end
end

