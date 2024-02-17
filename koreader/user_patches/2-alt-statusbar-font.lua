-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/document/credocument.lua
--
-- set alt-statusbar font to reading font

local CreDocument = require("document/credocument")

CreDocument.header_font = "drift"  -- see frontend/apps/reader/modules/readerfont.lua:onReadSettings()
