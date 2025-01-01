-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/ui/font.lua
--
-- override system UI font
--
-- NOTE: this does not consistently override widget titles and dictionary entries
--       resulting in an unusal font pairing with the radical "galley" font

local Font = require("ui/font")

for k, v in pairs(Font.fontmap) do
	if v == "NotoSans-Regular.ttf" then
		Font.fontmap[k] = "AtkinsonHyperlegible-Regular.ttf"
	elseif v == "NotoSans-Bold.ttf" then
		Font.fontmap[k] = "AtkinsonHyperlegible-Bold.ttf"
	end
end

