-- ./settings/gestures.lua
return {
    ["custom_multiswipes"] = {},
    ["gesture_fm"] = {
        ["hold_top_right_corner"] = {
            ["refresh_content"] = true,
        },
        ["multiswipe"] = {},
        ["multiswipe_east_north"] = {
            ["history"] = true,
        },
        ["multiswipe_east_north_west"] = {},
        ["multiswipe_east_north_west_east"] = {},
        ["multiswipe_east_south"] = {
            ["go_to"] = true,
        },
        ["multiswipe_east_south_west_north"] = {
            ["full_refresh"] = true,
        },
        ["multiswipe_east_west"] = {},
        ["multiswipe_east_west_east"] = {
            ["favorites"] = true,
        },
        ["multiswipe_north_east"] = {},
        ["multiswipe_north_south"] = {
            ["folder_up"] = true,
        },
        ["multiswipe_north_south_north"] = {},
        ["multiswipe_north_west"] = {
            ["folder_shortcuts"] = true,
        },
        ["multiswipe_northwest_southwest_northwest"] = {
            ["toggle_wifi"] = true,
        },
        ["multiswipe_south_east"] = {},
        ["multiswipe_south_east_north"] = {},
        ["multiswipe_south_east_north_south"] = {},
        ["multiswipe_south_north"] = {},
        ["multiswipe_south_north_south"] = {},
        ["multiswipe_south_west"] = {
            ["show_frontlight_dialog"] = true,
        },
        ["multiswipe_southeast_northeast"] = {},
        ["multiswipe_southeast_northeast_northwest"] = {
            ["wifi_on"] = true,
        },
        ["multiswipe_southeast_southwest_northwest"] = {
            ["wifi_off"] = true,
        },
        ["multiswipe_west_east"] = {},
        ["multiswipe_west_east_west"] = {
            ["open_previous_document"] = true,
        },
        ["multiswipe_west_north"] = {},
        ["multiswipe_west_south"] = {
            ["back"] = true,
        },
        ["one_finger_swipe_left_edge_down"] = {
            ["decrease_frontlight"] = 0,
        },
        ["one_finger_swipe_left_edge_up"] = {
            ["increase_frontlight"] = 0,
        },
        ["one_finger_swipe_right_edge_down"] = {
            ["decrease_frontlight_warmth"] = 0,
        },
        ["one_finger_swipe_right_edge_up"] = {
            ["increase_frontlight_warmth"] = 0,
        },
        ["short_diagonal_swipe"] = {
            ["full_refresh"] = true,
        },
        ["tap_left_bottom_corner"] = {
            ["toggle_frontlight"] = true,
        },
        ["two_finger_swipe_north"] = {
            ["increase_frontlight"] = 0,
        },
        ["two_finger_swipe_south"] = {
            ["decrease_frontlight"] = 0,
        },
        ["two_finger_swipe_west"] = {
            ["folder_shortcuts"] = true,
        },
    },
    ["gesture_reader"] = {
        ["double_tap_bottom_left_corner"] = {
            ["settings"] = {
                ["order"] = {
                    [1] = "wifi_off",
                },
            },
            ["wifi_off"] = true,
        },
        ["double_tap_bottom_right_corner"] = {
            ["exit"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "exit",
                },
            },
        },
        ["double_tap_left_side"] = {
            ["settings"] = {
                ["order"] = {
                    [1] = "show_vocab_builder",
                },
            },
            ["show_vocab_builder"] = true,
        },
        ["double_tap_right_side"] = {
            ["reading_progress"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "reading_progress",
                },
            },
        },
        ["double_tap_top_left_corner"] = {
            ["book_description"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "book_description",
                },
            },
        },
        ["double_tap_top_right_corner"] = {
            ["settings"] = {
                ["order"] = {
                    [1] = "start_usbms",
                },
            },
            ["start_usbms"] = true,
        },
        ["hold_bottom_left_corner"] = {
            ["settings"] = {
                ["order"] = {
                    [1] = "show_frontlight_dialog",
                },
            },
            ["show_frontlight_dialog"] = true,
        },
        ["hold_bottom_right_corner"] = {
            ["history"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "history",
                },
            },
        },
        ["hold_top_left_corner"] = {
            ["book_map"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "book_map",
                },
            },
        },
        ["hold_top_right_corner"] = {
            ["bookmarks"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "bookmarks",
                },
            },
        },
        ["multiswipe"] = {},
        ["multiswipe_east_north"] = {
            ["history"] = true,
        },
        ["multiswipe_east_north_west"] = {
            ["zoom"] = "contentwidth",
        },
        ["multiswipe_east_north_west_east"] = {
            ["zoom"] = "pagewidth",
        },
        ["multiswipe_east_south"] = {
            ["go_to"] = true,
        },
        ["multiswipe_east_south_west_north"] = {
            ["full_refresh"] = true,
        },
        ["multiswipe_east_west"] = {
            ["latest_bookmark"] = true,
        },
        ["multiswipe_east_west_east"] = {
            ["favorites"] = true,
        },
        ["multiswipe_north_east"] = {
            ["toc"] = true,
        },
        ["multiswipe_north_south"] = {},
        ["multiswipe_north_south_north"] = {
            ["prev_chapter"] = true,
        },
        ["multiswipe_north_west"] = {
            ["bookmarks"] = true,
        },
        ["multiswipe_northwest_southwest_northwest"] = {
            ["toggle_wifi"] = true,
        },
        ["multiswipe_south_east"] = {
            ["toggle_reflow"] = true,
        },
        ["multiswipe_south_east_north"] = {
            ["zoom"] = "contentheight",
        },
        ["multiswipe_south_east_north_south"] = {
            ["zoom"] = "pageheight",
        },
        ["multiswipe_south_north"] = {
            ["skim"] = true,
        },
        ["multiswipe_south_north_south"] = {
            ["next_chapter"] = true,
        },
        ["multiswipe_south_west"] = {
            ["show_frontlight_dialog"] = true,
        },
        ["multiswipe_southeast_northeast"] = {
            ["follow_nearest_link"] = true,
        },
        ["multiswipe_southeast_northeast_northwest"] = {
            ["wifi_on"] = true,
        },
        ["multiswipe_southeast_southwest_northwest"] = {
            ["wifi_off"] = true,
        },
        ["multiswipe_west_east"] = {
            ["previous_location"] = true,
        },
        ["multiswipe_west_east_west"] = {
            ["open_previous_document"] = true,
        },
        ["multiswipe_west_north"] = {
            ["book_status"] = true,
        },
        ["multiswipe_west_south"] = {
            ["back"] = true,
        },
        ["one_finger_swipe_bottom_edge_left"] = {
            ["previous_location"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "previous_location",
                },
            },
        },
        ["one_finger_swipe_bottom_edge_right"] = {
            ["settings"] = {
                ["order"] = {
                    [1] = "toggle_inverse_reading_order",
                },
            },
            ["toggle_inverse_reading_order"] = true,
        },
        ["one_finger_swipe_left_edge_down"] = {
            ["decrease_frontlight"] = 0,
        },
        ["one_finger_swipe_left_edge_up"] = {
            ["increase_frontlight"] = 0,
        },
        ["one_finger_swipe_right_edge_down"] = {
            ["decrease_frontlight_warmth"] = 0,
        },
        ["one_finger_swipe_right_edge_up"] = {
            ["increase_frontlight_warmth"] = 0,
        },
        ["one_finger_swipe_top_edge_left"] = {
            ["calibre_search"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "calibre_search",
                },
            },
        },
        ["one_finger_swipe_top_edge_right"] = {
            ["settings"] = {
                ["order"] = {
                    [1] = "toc",
                },
            },
            ["toc"] = true,
        },
        ["pinch_gesture"] = {
            ["decrease_font"] = 0,
        },
        ["short_diagonal_swipe"] = {
            ["full_refresh"] = true,
        },
        ["spread_gesture"] = {
            ["increase_font"] = 0,
        },
        ["tap_left_bottom_corner"] = {
            ["toggle_frontlight"] = true,
        },
        ["tap_right_bottom_corner"] = {
            ["b_page_margin"] = 18,
            ["font_base_weight"] = 1.5,
            ["font_gamma"] = 36,
            ["font_size"] = 11.5,
            ["h_page_margins"] = {
                [1] = 70,
                [2] = 70,
            },
            ["line_spacing"] = 220,
            ["set_font"] = "proof",
            ["settings"] = {
                ["order"] = {
                    [1] = "set_font",
                    [2] = "font_size",
                    [3] = "line_spacing",
                    [4] = "font_gamma",
                    [5] = "font_base_weight",
                    [6] = "h_page_margins",
                    [7] = "t_page_margin",
                    [8] = "b_page_margin",
                    [9] = "word_spacing",
                },
            },
            ["t_page_margin"] = 32,
            ["word_spacing"] = {
                [1] = 100,
                [2] = 100,
            },
        },
        ["tap_top_left_corner"] = {
            ["night_mode"] = true,
            ["settings"] = {
                ["order"] = {
                    [1] = "night_mode",
                },
            },
        },
        ["tap_top_right_corner"] = {
            ["toggle_bookmark"] = true,
        },
        ["two_finger_swipe_east"] = {
            ["toc"] = true,
        },
        ["two_finger_swipe_north"] = {
            ["increase_frontlight"] = 0,
        },
        ["two_finger_swipe_south"] = {
            ["decrease_frontlight"] = 0,
        },
        ["two_finger_swipe_west"] = {
            ["bookmarks"] = true,
        },
    },
}
