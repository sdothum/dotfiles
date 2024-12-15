-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/apps/reader/modules/readerfooter.lua
--
-- widen statusbar spacer for better visual content separation

local ReaderFooter = require("apps/reader/modules/readerfooter")

ReaderFooter.genSeparator = function(self)
	local strings = {
		bar    = "   ",  -- was " | ",
		bullet = " • ",
		dot    = " · ",
	}
	return strings[self.settings.items_separator]
		or (self.settings.item_prefix == "compact_items" and " " or "  ")
end
