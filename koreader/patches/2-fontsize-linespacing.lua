-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/ui/data/creoptions.lua
-- frontend/apps/reader/modules/readerfont.lua
-- 
-- extend font size and line spacing ranges

-- my new ranges
local min_fontsize = 8       -- point size
local max_linespacing = 300  -- percent

local CreOptions = require("ui/data/creoptions")

CreOptions[3].options[4].more_options_param.value_max = max_linespacing  -- tweak visual "proof" mode
CreOptions[4].options[2].more_options_param.value_min = min_fontsize     -- allow even smaller point sizes

local Screen = require("device").screen
local Event = require("ui/event")
local Notification = require("ui/widget/notification")
local T = require("ffi/util").template
local _ = require("gettext")
local ReaderFont = require("apps/reader/modules/readerfont")

-- ReaderFont.onSetFontSize = function(self, size)
function ReaderFont:onSetFontSize(size)
	size = math.max(min_fontsize, math.min(size, 255))      -- from 12pt min
	self.configurable.font_size = size
	self.ui.document:setFontSize(Screen:scaleBySize(size))
	self.ui:handleEvent(Event:new("UpdatePos"))
	Notification:notify(T(_("Font size set to: %1."), size))
	return true
end

-- ReaderFont.onSetLineSpace = function(self, space)
function ReaderFont:onSetLineSpace(space)
	space = math.max(50, math.min(space, max_linespacing))  -- from 200% max
	self.configurable.line_spacing = space
	self.ui.document:setInterlineSpacePercent(space)
	self.ui:handleEvent(Event:new("UpdatePos"))
	Notification:notify(T(_("Line spacing set to: %1%."), space))
	return true
end

