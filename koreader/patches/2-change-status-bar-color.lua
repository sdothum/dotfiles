-- MOVED TO https://github.com/sebdelsol/KOReader.patches

-- based on https://gist.github.com/IntrovertedMage/d759ff214f799cfb5e1f8c85daab6cae
-- Menu added in the Reader menu:
-- settings > Status bar > Progress bar > Thickness, height & colors > Read color
-- settings > Status bar > Progress bar > Thickness, height & colors > Unread color

local Blitbuffer = require("ffi/blitbuffer")
local Math = require("optmath")
local ProgressWidget = require("ui/widget/progresswidget")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template

-- local logger = require("logger")

-- Utils
local function serializeColor(color) return color.a end
local function deserializeColor(value) return Blitbuffer.Color8(value) end
local function blackPctOfColor(color) return Math.round((0xFF - color.a) * 100 / 0xFF) end
local function colorFromBlackPct(percent) return Blitbuffer.gray(Math.round(percent / 100)) end

-- Settings
local Settings = {}

local function colorAttrib(read) return read and "fillcolor" or "bgcolor" end
local function getStyle(thin) return thin and "progress_style_thin_colors" or "progress_style_thick_colors" end

function Settings:init(footer)
	local function defaultColor(thin)
		ProgressWidget:updateStyle(not thin, nil, false) -- no object needed, since height is nil, do no set colors
		local read, unread = colorAttrib(true), colorAttrib(false)
		return {
			[read] = serializeColor(ProgressWidget[read]),
			[unread] = serializeColor(ProgressWidget[unread]),
		}
	end

	self.footer = footer
	self.default = {
		[getStyle(true)] = defaultColor(true),
		[getStyle(false)] = defaultColor(false),
	}
end

function Settings:getDefault(thin, color_attrib)
	local default = self.default[getStyle(thin)]
	return deserializeColor(self.default[getStyle(thin)][color_attrib])
end

function Settings:get(thin, color_attrib)
	local settings = self.footer.settings and self.footer.settings[getStyle(thin)]
	local color = settings and settings[color_attrib]
	return color and deserializeColor(color) or self:getDefault(thin, color_attrib)
end

function Settings:set(thin, color_attrib, color)
	local style = getStyle(thin)
	local settings = self.footer.settings[style] or {}
	settings[color_attrib] = serializeColor(color)
	self.footer.settings[style] = settings
end

-- ReaderFooter
local orig_ReadFooter_init = ReaderFooter.init

function ReaderFooter:init()
	Settings:init(self)
	orig_ReadFooter_init(self)
	self.progress_bar:setColors(self.settings.progress_style_thin)
end

-- ProgressWidget
local orig_ProgressWidget_updateStyle = ProgressWidget.updateStyle

function ProgressWidget:updateStyle(thick, height, do_setcolors)
	do_setcolors = do_setcolors or do_setcolors == nil -- default: do_setcolors = true
	orig_ProgressWidget_updateStyle(self, thick, height)
	if do_setcolors then self:setColors(not thick) end
end

function ProgressWidget:setColors(thin)
	local read, unread = colorAttrib(true), colorAttrib(false)
	self[read] = Settings:get(thin, read)
	self[unread] = Settings:get(thin, unread)
end

-- Menu
local function getMenuItem(menu, ...) -- path
	local function findItem(sub_items, texts)
		local find = {}
		local texts = type(texts) == "table" and texts or { texts }
		-- stylua: ignore
		for _, text in ipairs(texts) do find[text] = true end
		for _, item in ipairs(sub_items) do
			local text = item.text or (item.text_func and item.text_func())
			if text and find[text] then return item end
		end
	end

	local sub_items, item
	for _, texts in ipairs { ... } do -- walk path
		sub_items = (item or menu).sub_item_table
		if not sub_items then return end
		item = findItem(sub_items, texts)
		if not item then return end
	end
	return item
end

function ReaderFooter:statusBarColorMenu(read)
	local color_attrib = colorAttrib(read)
	return {
		text_func = function()
			return T(
				read and _("Read color: %1% black") or _("Unread color: %1% black"),
				blackPctOfColor(self.progress_bar[color_attrib])
			)
		end,
		keep_menu_open = true,
		enabled_func = function() return not self.settings.disable_progress_bar end,
		callback = function(touchmenu_instance)
			local spin_widget = SpinWidget:new {
				title_text = read and _("Read color % black") or _("Unread color % black"),
				default_value = blackPctOfColor(Settings:getDefault(self.settings.progress_style_thin, color_attrib)),
				value = blackPctOfColor(self.progress_bar[color_attrib]),
				value_min = 0,
				value_step = 1,
				value_hold_step = 10,
				value_max = 100,
				unit = "% " .. _("black"),
				callback = function(spin)
					local color = colorFromBlackPct(spin.value)
					Settings:set(self.settings.progress_style_thin, color_attrib, color)
					self.progress_bar[color_attrib] = color
					touchmenu_instance:updateItems()
					self:refreshFooter(true)
				end,
			}
			UIManager:show(spin_widget)
		end,
	}
end

local orig_ReaderFooter_addToMainMenu = ReaderFooter.addToMainMenu

function ReaderFooter:addToMainMenu(menu_items)
	orig_ReaderFooter_addToMainMenu(self, menu_items)

	local item = getMenuItem(
		menu_items.status_bar,
		_("Progress bar"),
		{ _("Thickness and height: thin"), _("Thickness and height: thick") }
	)
	if item then
		item.text_func = function()
			return self.settings.progress_style_thin and _("Thickness, height & colors: thin")
				or _("Thickness, height & colors: thick")
		end
		table.insert(item.sub_item_table, self:statusBarColorMenu(true))
		table.insert(item.sub_item_table, self:statusBarColorMenu(false))
	end
end
