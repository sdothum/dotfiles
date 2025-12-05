-- /storage/emulated/0/koreader/defaults.custom.lua

-- screen dpi:           300  -- from auto

-- font:                 singspiel
-- font size:            11.4
-- line spacing:         246%
-- l/r margin:           132
-- top margin:           40
-- bottom margin:        34

-- alt status font size: 27
-- status bar font size: 11 bold
-- status bar height:    10
-- status bottom margin: 3

return {

DTAP_ZONE_MENU         = { x = 0,      y = 0,     h = 0.06,  w = 1     },  -- top menu bar
DTAP_ZONE_MENU_EXT     = { x = 0,      y = 0,     h = 0.20,  w = 1     },

DTAP_ZONE_CONFIG       = { x = 0,      y = 0.94,  h = 0.06,  w = 1     },  -- bottom layout bar
DTAP_ZONE_CONFIG_EXT   = { x = 0,      y = 0.80,  h = 0.20,  w = 1     },

DTAP_ZONE_FORWARD      = { x = 0.045,  y = 0,     h = 1,     w = 0.955 },  -- page advance edge
DTAP_ZONE_BACKWARD     = { x = 0,      y = 0,     h = 1,     w = 0.045 },

DTAP_ZONE_TOP_LEFT     = { x = 0,      y = 0,     h = 0.06,  w = 0.05  },  -- long press corners
DTAP_ZONE_TOP_RIGHT    = { x = 0.95,   y = 0,     h = 0.06,  w = 0.05  },
DTAP_ZONE_BOTTOM_LEFT  = { x = 0,      y = 0.95,  h = 0.05,  w = 0.05  },
DTAP_ZONE_BOTTOM_RIGHT = { x = 0.95,   y = 0.95,  h = 0.05,  w = 0.05  },

}
