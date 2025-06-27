-- sdothum - 2016 (c) wtfpl
-- yazi
-- ═════════════════════════════════════════════════════════════════════════════

-- ........................................................................ init

require("bunny"):setup({
	hops = {
		{ key = "/",          path = "/",                                                         },
		{ key = "~",          path = "~",                                                         },
		{ key = "B",          path = "/bin",                                                      },
		{ key = "C",          path = "/home/depot/CATLG",                                         },
		{ key = "D",          path = "/home/depot/dotfiles",                                      },
		{ key = "F",          path = "~/.fonts",                                                  },
		{ key = "H",          path = "/home",                                                     },
		{ key = "I",          path = "~/images/backgrounds",                                      },
		{ key = "L",          path = "/home/library/calibre",                                     },
		{ key = "M",          path = "~/mtp",                                                     },
		{ key = "N",          path = "/net",                                                      },
		{ key = "S",          path = "~/sandbox",                                                 },
		{ key = "T",          path = "/tmp",                                                      },
		{ key = "U",          path = "/usr/share",                                                },
		{ key = "W",          path = "~/vimwiki/colophon",                                        },
		{ key = "b",          path = "~/build/nvidia",                                            },
		{ key = "c",          path = "~/.config",                                                 },
		{ key = "d",          path = "/net/downloads/http",                                       },
		{ key = "e",          path = "/etc",                                                      },
		{ key = { "e", "d" }, path = "/etc/dinit.d",                                              },
		{ key = { "e", "r" }, path = "/etc/sv",                                                   },
		{ key = "f",          path = "~/bin/functions",                                           },
		{ key = "i",          path = "/srv/http/thedarnedestthing.com/application/public/images", },
		{ key = "l",          path = "~/.local",                                                  },
		{ key = { "l", "b" }, path = "~/.local/bin",                                              },
		{ key = { "l", "s" }, path = "~/.local/share",                                            },
		{ key = { "l", "t" }, path = "~/.local/state",                                            },
		{ key = "m",          path = "/home/music",                                               },
		{ key = "n",          path = "/net/downloads/nicotine",                                   },
		{ key = "p",          path = "/home/photos/2025"                                          },
		{ key = "r",          path = "/home/library/references",                                  },
		{ key = "s",          path = "~/stow",                                                    },
		{ key = "t",          path = "~/tmp",                                                     },
		{ key = "u",          path = "/run/media/" .. os.getenv("USER"),                          },
		{ key = "v",          path = "/net/media/videos",                                         },
		{ key = "y",          path = "~/.config/yazi",                                            },
		{ key = "w",          path = "~/vimwiki",                                                 },
		-- key and path attributes are required, desc is optional,
	},
	desc_strategy = "path",  -- If desc isn't present, use "path" or "filename", default is "path"
	ephemeral     = true,    -- Enable ephemeral hops, default is true
	tabs          = true,    -- Enable tab hops, default is true
	notify        = false,   -- Notify after hopping, default is false
	fuzzy_cmd     = "fzf",   -- Fuzzy searching command, default is "fzf"
})
