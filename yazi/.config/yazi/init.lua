-- sdothum - 2016 (c) wtfpl
-- yazi
-- ═════════════════════════════════════════════════════════════════════════════

-- ........................................................................ init

-- last photo shoot
local day   = io.popen("ls -1 /home/photos/$(date '+%Y') | tail -1")
local snaps = day:read()

require("bunny"):setup({
	hops = {
		{ key = "/",          path = "/",                                                         },
		{ key = "~",          path = "~",                                                         },
		{ key = { ".", "b" }, path = "~/.local/bin",                                              },
		{ key = { ".", "s" }, path = "~/.local/share",                                            },
		{ key = { ".", "t" }, path = "~/.local/state",                                            },
		{ key = "B",          path = "/bin",                                                      },
		{ key = "b",          path = "~/build/nvidia",                                            },
		{ key = "C",          path = "/home/depot/CATLG",                                         },
		{ key = "c",          path = "~/.config",                                                 },
		{ key = "D",          path = "/home/depot/dotfiles",                                      },
		{ key = { "d", "d" }, path = "~/downloads",                                               },
		{ key = { "d", "h" }, path = "/net/downloads/http",                                       },
		{ key = { "d", "n" }, path = "/net/downloads/nzbs/completed",                             },
		{ key = "E",          path = "/etc",                                                      },
		{ key = { "e", "d" }, path = "/etc/dinit.d",                                              },
		{ key = { "e", "r" }, path = "/etc/sv",                                                   },
		{ key = "F",          path = "~/.fonts",                                                  },
		{ key = "f",          path = "~/bin/functions",                                           },
		{ key = "H",          path = "/home",                                                     },
		{ key = "I",          path = "~/images/backgrounds",                                      },
		{ key = "i",          path = "/srv/http/thedarnedestthing.com/application/public/images", },
		{ key = "L",          path = "/home/library/calibre",                                     },
		{ key = { "l", "b" }, path = "/usr/local/bin",                                            },
		{ key = { "l", "s" }, path = "/usr/local/share",                                          },
		{ key = "m",          path = "/home/music",                                               },
		{ key = "N",          path = "/net/home/".. os.getenv("USER"),                            },
		{ key = "n",          path = "/net/downloads/nicotine",                                   },
		{ key = "p",          path = "/home/photos/" .. os.date("%Y/") .. snaps                   },
		{ key = "r",          path = "/home/library/references",                                  },
		{ key = "S",          path = "~/sandbox",                                                 },
		{ key = "s",          path = "~/stow",                                                    },
		{ key = "T",          path = "/tmp",                                                      },
		{ key = "t",          path = "~/tmp",                                                     },
		{ key = "U",          path = "/usr/share",                                                },
		{ key = { "u", "m" }, path = "~/mtp",                                                     },
		{ key = { "u", "u" }, path = "/run/media/" .. os.getenv("USER"),                          },
		{ key = "v",          path = "/net/media/videos",                                         },
		{ key = "w",          path = "~/vimwiki",                                                 },
		{ key = "y",          path = "~/.config/yazi",                                            },
	-- { key = <key>,        path = <path>,        [ desc = <desc> ]                             },
	},

	desc_strategy = "path",  -- If desc isn't present, use "path" or "filename", default is "path"
	ephemeral     = true,    -- Enable ephemeral hops, default is true
	tabs          = true,    -- Enable tab hops, default is true
	notify        = false,   -- Notify after hopping, default is false
	fuzzy_cmd     = "fzf",   -- Fuzzy searching command, default is "fzf"
})
