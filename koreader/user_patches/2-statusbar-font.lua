-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/document/credocument.lua
-- frontend/ui/font.lua
--
-- set alt-/statusbar font to reading font

-- my reading font
local fontface = "drift"
local fontsource = "drift-book.ttf"

-- alt-statusbar header
local CreDocument = require("document/credocument")

# ATTENTION: if the expected alt-statusbar font does not display for the current document, tap..
# top menu -> document -> document settings -> reset document settings to default
CreDocument.header_font = fontface  -- see frontend/apps/reader/modules/readerfont.lua:onReadSettings()

-- statusbar footer
local Font = require("ui/font")

for k, v in pairs(Font.fontmap) do
	if k == "ffont" then
		Font.fontmap[k] = fontsource
	elseif k == "smallffont" then
		Font.fontmap[k] = fontsource
	elseif k == "largeffont" then
		Font.fontmap[k] = fontsource
	end
end
