-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- settings.reader.lua
-- frontend/ui/font.lua
--
-- override system UI font
--
-- ATTN: this patch must be the first patch loaded
--       hence, the "2--<patch>.lua" naming for load order precedence
-- NOTE: this does not consistently override widget titles and dictionary lookups
--       which can result in unusal fontface pairings

local Font = require("ui/font")

local regular = "NotoSans-Regular.ttf"
local bold = "NotoSans-Bold.ttf"
-- NOTE: regular/bold dictionary font must be installed
-- local regular = "AtkinsonHyperlegible-Regular.ttf"
-- local bold = "AtkinsonHyperlegible-Bold.ttf"

-- default document font family
local DataStorage = require("datastorage")
local G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
local fontface = G_reader_settings:readSetting("cre_font")  -- default font

local bookweights = { "-normalbookupright.ttf", "-book.ttf", "-book.otf", "-regular.ttf", "-regular.otf" }  -- selection order of user ttf and otf font files
local boldweights = {
	["-normalbookupright.ttf"] = function () return "-normalboldupright.ttf" end,
	["-book.ttf"]              = function () return "-bold.ttf"              end,
	["-book.otf"]              = function () return "-bold.otf"              end,
	["-regular.ttf"]           = function () return "-bold.ttf"              end,
	["-regular.otf"]           = function () return "-bold.otf"              end
}

for _, n in pairs(bookweights) do
	local f = io.open(DataStorage:getDataDir() .. "/fonts/" .. fontface .. "/" .. fontface .. n, "r")
	if f ~= nil then  -- font source exists
		io.close(f)
		regular = fontface .. n
		bold    = fontface .. boldweights[n]()
		-- regular = bold  -- HACK: increase dictionary contrast
		break
	end
end

if regular ~= "NotoSans-Regular.ttf" then
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
end
