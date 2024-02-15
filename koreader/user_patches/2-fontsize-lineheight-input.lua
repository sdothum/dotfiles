-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/apps/reader/modules/readerfont.lua
-- 
-- set minimum font size / maximum line spacing range

local Screen = require("device").screen
local Event = require("ui/event")
local Notification = require("ui/widget/notification")
local T = require("ffi/util").template
local _ = require("gettext")
local ReaderFont = require("apps/reader/modules/readerfont")

-- ReaderFont.onSetFontSize = function(self, size)
function ReaderFont:onSetFontSize(size)
	size = math.max(10, math.min(size, 255))  -- from 12
	self.configurable.font_size = size
	self.ui.document:setFontSize(Screen:scaleBySize(size))
	self.ui:handleEvent(Event:new("UpdatePos"))
	Notification:notify(T(_("Font size set to: %1."), size))
	return true
end

-- ReaderFont.onSetLineSpace = function(self, space)
function ReaderFont:onSetLineSpace(space)
	space = math.max(50, math.min(space, 250))  -- from 200
	self.configurable.line_spacing = space
	self.ui.document:setInterlineSpacePercent(space)
	self.ui:handleEvent(Event:new("UpdatePos"))
	Notification:notify(T(_("Line spacing set to: %1%."), space))
	return true
end

