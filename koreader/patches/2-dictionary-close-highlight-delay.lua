- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/ui/widget/dictquicklookup.lua
--
-- lengthen highlight delay for visual word relocation (when hidden behind dictionary popup)

local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local DictQuickLookup = require("ui/widget/dictquicklookup")

DictQuickLookup.onClose = function(self)
	for menu, _ in pairs(self.menu_opened) do
		UIManager:close(menu)
	end
	self.menu_opened = {}

	UIManager:close(self)

	if self.update_wiki_languages_on_close then
		-- except if we got no result for current language
		if not self.results.no_result then
			self.ui:handleEvent(Event:new("UpdateWikiLanguages", self.wiki_languages))
		end
	end
	if self.highlight and not no_clear then
		-- delay unhighlight of selection, so we can see where we stopped when
		-- back from our journey into dictionary or wikipedia
		local clear_id = self.highlight:getClearId()
		UIManager:scheduleIn(1.5, function()  -- from 0.5 seconds delay
			self.highlight:clear(clear_id)
		end)
	end
	return true
end


