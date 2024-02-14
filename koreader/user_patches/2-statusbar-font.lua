-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/ui/font.lua
--
-- change statusbar font to reading font

local Font = require("ui/font")

for k, v in pairs(Font.fontmap) do
	if k == "ffont" then
		Font.fontmap[k] = "drift-book.ttf"
	elseif k == "smallffont" then
		Font.fontmap[k] = "drift-book.ttf"
	elseif k == "largeffont" then
		Font.fontmap[k] = "drift-book.ttf"
	end
end
