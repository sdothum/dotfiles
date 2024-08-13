-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/device/input.lua
--
-- sync page turn directions with portrait rotations

local Device = require("device")
local Event = require("ui/event")
local UIManager
local framebuffer = require("ffi/framebuffer")
local Input = require("frontend/device/input")

-- We're going to need a few <linux/input.h> constants...
local ffi = require("ffi")
local C = ffi.C
require("ffi/posix_h")
require("ffi/linux_input_h")

--- Accelerometer, in a platform-agnostic, custom format (EV_MSC:MSC_GYRO).
--- (Translation should be done via registerEventAdjustHook in Device implementations).
--- This needs to be called *via handleGyroEv* in a handleMiscEv implementation (c.f., Kobo, Kindle or PocketBook).
function Input:handleMiscGyroEv(ev)
	local rotation
	if ev.value == C.DEVICE_ROTATED_UPRIGHT then
		-- i.e., UR
		rotation = framebuffer.DEVICE_ROTATED_UPRIGHT
	elseif ev.value == C.DEVICE_ROTATED_CLOCKWISE then
		-- i.e., CW
		rotation = framebuffer.DEVICE_ROTATED_CLOCKWISE
	elseif ev.value == C.DEVICE_ROTATED_UPSIDE_DOWN then
		-- i.e., UD
		rotation = framebuffer.DEVICE_ROTATED_UPSIDE_DOWN
	elseif ev.value == C.DEVICE_ROTATED_COUNTER_CLOCKWISE then
		-- i.e., CCW
		rotation = framebuffer.DEVICE_ROTATED_COUNTER_CLOCKWISE
	else
		-- Discard FRONT/BACK
		return
	end

	local old_rotation = self.device.screen:getRotationMode()
	if self.device:isGSensorLocked() then
		local matching_orientation = bit.band(rotation, 1) == bit.band(old_rotation, 1)
		if rotation and rotation ~= old_rotation and matching_orientation then
			-- Cheaper than a full SetRotationMode event, as we don't need to re-layout anything.
			self.device.screen:setRotationMode(rotation)
			UIManager:onRotation()
			UIManager:sendEvent(Event:new("ToggleReadingOrder"))  -- toggle page turn orientaton
		end
	else
		if rotation and rotation ~= old_rotation then
			-- NOTE: We do *NOT* send a broadcast manually, and instead rely on the main loop's sendEvent:
			--	   this ensures that only widgets that actually know how to handle a rotation will do so ;).
			return Event:new("SetRotationMode", rotation)
		end
	end
end
