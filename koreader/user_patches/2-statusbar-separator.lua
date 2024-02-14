-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/apps/reader/modules/readerfooter.lua
--
-- widen statusbar spacer for better visual content separation

local ReaderFooter = require("apps/reader/modules/readerfooter")

ReaderFooter.get_separator_symbol = function(self)
	return " "  -- from "" to 1 space for drift font
end
