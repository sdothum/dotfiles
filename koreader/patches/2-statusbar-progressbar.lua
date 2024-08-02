-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- ffi/blitbuffer.lua
-- frontend/device.lua
-- frontend/ui/widget/progresswidget.lua
--
-- increase contrast of "thin" progress bar

local Blitbuffer = require("ffi/blitbuffer")
local Screen = require("device").screen
local ProgressWidget = require("ui/widget/progresswidget")

function ProgressWidget:updateStyle(thick, height)
    if thick then
        self.margin_h = Screen:scaleBySize(3)
        self.margin_v = Screen:scaleBySize(1)
        self.bordersize = Screen:scaleBySize(1)
        self.radius = Screen:scaleBySize(2)
        self.bgcolor = Blitbuffer.COLOR_WHITE
        self.fillcolor = Blitbuffer.COLOR_DARK_GRAY
        self._orig_margin_v = nil
        self._orig_bordersize = nil
        if height then
            self:setHeight(height)
        end
    else
        self.margin_h = 0
        self.margin_v = 0
        self.bordersize = 0
        self.radius = 0
        self.bgcolor = Blitbuffer.COLOR_WHITE
        self.fillcolor = Blitbuffer.COLOR_BLACK
        self.ticks = nil
        self._orig_margin_v = nil
        self._orig_bordersize = nil
        if height then
            self:setHeight(height)
        end
    end
end

