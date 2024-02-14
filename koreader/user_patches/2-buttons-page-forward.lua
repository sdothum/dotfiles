-- koreader/patches
-- sdothum - 2016 (c) wtfpl
--
-- frontend/device/input.lua
--
-- make page turn buttons all page forward

local logger = require("logger")
local Device = require("device")

Device.input.rotation_map = {
	[0] = { RPgBack = "RPgFwd" },  -- from {}
	[1] = { Up = "Right", Right = "Down", Down = "Left",  Left = "Up",    LPgBack = "LPgFwd",  LPgFwd  = "LPgBack", RPgBack = "RPgFwd",  RPgFwd  = "RPgFwd" },  -- from RPgFwd  = "RPgBack"
	[2] = { Up = "Down",  Right = "Left", Down = "Up",    Left = "Right", LPgFwd  = "LPgBack", LPgBack = "LPgFwd",  RPgFwd  = "RPgFwd",  RPgBack = "RPgFwd" },  -- from RPgFwd  = "RPgBack"
	[3] = { Up = "Left",  Right = "Up",   Down = "Right", Left = "Down",  RPgBack = "RPgFwd" },  -- from default RPgBack = "RPgBack"
}
logger.info("Hardware button rotation disabled by user patch")
