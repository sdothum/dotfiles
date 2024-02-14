-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/apps/reader/modules/readerfont.lua
-- 
-- set minimum font size / maximum line spacing range and alt-statusbar font

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

ReaderFont.onReadSettings = function(self)
	-- self.font_face = config:readSetting("font_face")
	-- 			or G_reader_settings:readSetting("cre_font")
	-- 			or self.ui.document.default_font
	self.font_face = "drift"
	self.ui.document:setFontFace(self.font_face)

	-- self.header_font_face = config:readSetting("header_font_face")
	-- 					or G_reader_settings:readSetting("header_font")
	-- 					or self.ui.document.header_font
	self.header_font_face = "drift"                        -- bypass cr3.ini file :-)
	self.ui.document:setHeaderFont(self.header_font_face)  -- force custom alt-status font

	self.ui.document:setFontSize(Screen:scaleBySize(self.configurable.font_size))
	self.ui.document:setFontBaseWeight(self.configurable.font_base_weight)
	self.ui.document:setFontHinting(self.configurable.font_hinting)
	self.ui.document:setFontKerning(self.configurable.font_kerning)
	self.ui.document:setWordSpacing(self.configurable.word_spacing)
	self.ui.document:setWordExpansion(self.configurable.word_expansion)
	self.ui.document:setCJKWidthScaling(self.configurable.cjk_width_scaling)
	self.ui.document:setInterlineSpacePercent(self.configurable.line_spacing)
	self.ui.document:setGammaIndex(self.configurable.font_gamma)

	-- self.font_family_fonts = config:readSetting("font_family_fonts") or {}  -- causes crash (ditto above config:)
	-- self:updateFontFamilyFonts()                                            -- causes crash

	-- Dirty hack: we have to add following call in order to set
	-- m_is_rendered(member of LVDocView) to true. Otherwise position inside
	-- document will be reset to 0 on first view render.
	-- So far, I don't know why this call will alter the value of m_is_rendered.

	table.insert(self.ui.postInitCallback, function()
		self.ui:handleEvent(Event:new("UpdatePos"))
	end)
end


