-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/apps/reader/modules/readerfooter.lua
--
-- widen statusbar spacer for better visual content separation

local ReaderFooter = require("apps/reader/modules/readerfooter")

-- koreader v2024.07
ReaderFooter.get_separator_symbol = function(self)
	if self.settings.items_separator == "bar" then
		return " "  -- was "|"
	elseif self.settings.items_separator == "dot" then
		return "·"
	elseif self.settings.items_separator == "bullet" then
		return "•"
	end

	return ""
end

-- koreader v2024.11
ReaderFooter.genSeparator = function(self)
	local strings = {
		bar    = "   ",  -- was " | ",
		bullet = " • ",
		dot    = " · ",
	}
	return strings[self.settings.items_separator]
		or (self.settings.item_prefix == "compact_items" and " " or "  ")
end
