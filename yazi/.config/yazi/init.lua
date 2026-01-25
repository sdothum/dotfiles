-- sdothum - 2016 (c) wtfpl
-- yazi
-- ═════════════════════════════════════════════════════════════════════════════

-- ........................................................................ init

-- last photo shoot
local photos =  "/home/photos/sigma_fp/" .. os.date("%Y/")
os.execute("test -d " .. photos .. " || mkdir " .. photos)  -- new year rollover
local day    = io.popen("ls -1 \"/home/photos/sigma_fp/$(date '+%Y')\" | tail -1")
local snaps  = day:read()
if snaps == nil then snaps = "" end                         -- new year rollover

require("bunny"):setup({
	hops = {
		{ key = "/",          path = "/",                                                 },
		{ key = "~",          path = "~",                                                 },
		{ key = { ".", "b" }, path = "~/.local/bin",                                      },
		{ key = { ".", "s" }, path = "~/.local/share",                                    },
		{ key = { ".", "t" }, path = "~/.local/state",                                    },
		{ key = "B",          path = "~/bin",                                             },
		{ key = "b",          path = "/bin",                                              },
		{ key = "C",          path = "/home/depot/CATLG",                                 },
		{ key = "c",          path = "~/.config",                                         },
		{ key = "D",          path = "/home/depot/dotfiles",                              },
		{ key = { "d", "~" }, path = "~/downloads",                                       },
		{ key = { "d", "d" }, path = "/net/downloads/http",                               },
		{ key = { "d", "n" }, path = "/net/downloads/nzbs/completed",                     },
		{ key = "E",          path = "/etc",                                              },
		{ key = { "e", "d" }, path = "/etc/dinit.d",                                      },
		{ key = { "e", "r" }, path = "/etc/sv",                                           },
		{ key = "F",          path = "~/.local/share/fonts",                              },
		{ key = "f",          path = "~/bin/functions",                                   },
		{ key = "H",          path = "/home",                                             },
		{ key = "I",          path = "~/images/backgrounds",                              },
		{ key = "i",          path = "~/thedarnedestthing.com/application/public/images", },
		{ key = "k",          path = "~/.config/kak",                                     },
		{ key = "L",          path = "/home/library/calibre",                             },
		{ key = { "l", "b" }, path = "/usr/local/bin",                                    },
		{ key = { "l", "s" }, path = "/usr/local/share",                                  },
		{ key = "M",          path = "/home/music",                                       },
		{ key = "m",          path = "/net/media/videos",                                 },
		{ key = "N",          path = "/net/home/" .. os.getenv("USER"),                   },
		{ key = "n",          path = "/net/downloads/nicotine",                           },
		{ key = "o",          path = "/opt",                                              },
		{ key = "p",          path = photos .. snaps,                                     },
		{ key = "r",          path = "/home/library/references",                          },
		{ key = "S",          path = "~/sandbox",                                         },
		{ key = { "s", "." }, path = "~/.session",                                        },
		{ key = { "s", "s" }, path = "~/stow",                                            },
		{ key = "T",          path = "~/tmp",                                             },
		{ key = "t",          path = "/tmp",                                              },
		{ key = "U",          path = "/usr/share",                                        },
		{ key = { "u", "m" }, path = "~/mtp",                                             },
		{ key = { "u", "u" }, path = "/run/media/" .. os.getenv("USER"),                  },
		{ key = "v",          path = "~/build/nvidia",                                    },
		{ key = "W",          path = "/dev/shm",                                          },
		{ key = "w",          path = "~/vimwiki",                                         },
		{ key = "y",          path = "~/.config/yazi",                                    },
	-- { key = <key>,        path = <path>,        [ desc = <desc> ]                     },
	},

	desc_strategy = "path",  -- If desc isn't present, use "path" or "filename", default is "path"
	ephemeral     = true,    -- Enable ephemeral hops, default is true
	tabs          = true,    -- Enable tab hops, default is true
	notify        = false,   -- Notify after hopping, default is false
	fuzzy_cmd     = "fzf",   -- Fuzzy searching command, default is "fzf"
})
