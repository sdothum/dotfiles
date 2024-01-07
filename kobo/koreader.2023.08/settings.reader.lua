-- ./settings.reader.lua
return {
    ["auto_disable_wifi"] = true,
    ["auto_save_settings_interval_minutes"] = 15,
    ["auto_standby_timeout_seconds"] = -1,
    ["auto_suspend_timeout_seconds"] = 300,
    ["autodim_duration_seconds"] = 5,
    ["autodim_fraction"] = 20,
    ["autodim_starttime_minutes"] = -1,
    ["autoshutdown_timeout_seconds"] = 259200,
    ["autostart_profiles"] = {},
    ["autoturn_distance"] = 1,
    ["autoturn_timeout_seconds"] = 0,
    ["autowarmth_fl_off_during_day_offset_s"] = 0,
    ["autowarmth_timezone"] = 0,
    ["back_in_filemanager"] = "default",
    ["back_in_reader"] = "previous_location",
    ["back_to_exit"] = "prompt",
    ["book_map_ten_pages_markers"] = 0,
    ["bookmarks_items_font_size"] = 19,
    ["bookmarks_items_per_page"] = 14,
    ["calibre_search_find_by_series"] = true,
    ["calibre_search_find_by_tag"] = true,
    ["closed_rotation_mode"] = 2,
    ["collate"] = "percent_unopened_last",
    ["copt_b_page_margin"] = 30,
    ["copt_font_base_weight"] = 1.5,
    ["copt_font_gamma"] = 25,
    ["copt_font_size"] = 11.5,
    ["copt_h_page_margins"] = {
        [1] = 55,
        [2] = 55,
    },
    ["copt_line_spacing"] = 210,
    ["copt_status_line"] = 0,
    ["copt_sync_t_b_page_margins"] = 1,
    ["copt_t_page_margin"] = 30,
    ["copt_word_spacing"] = {
        [1] = 100,
        [2] = 100,
    },
    ["coverbrowser_initial_default_setup_done"] = true,
    ["cre_font"] = "grote",
    ["cre_font_family_fonts"] = {},
    ["cre_font_family_ignore_font_names"] = true,
    ["cre_fonts_recently_selected"] = {
        [1] = "grote",
        [2] = "stria",
        [3] = "patio",
        [4] = "Noto Serif",
        [5] = "Droid Sans Mono",
        [6] = "FreeSans",
        [7] = "FreeSerif",
        [8] = "Noto Naskh Arabic",
        [9] = "Noto Sans",
        [10] = "Noto Sans Arabic UI",
        [11] = "Noto Sans Bengali UI",
        [12] = "Noto Sans CJK SC",
        [13] = "Noto Sans Devanagari UI",
    },
    ["cre_header_auto_refresh"] = 1,
    ["cre_header_battery"] = 1,
    ["cre_header_battery_percent"] = 0,
    ["cre_header_chapter_marks"] = 1,
    ["cre_header_clock"] = 1,
    ["cre_header_page_count"] = 1,
    ["cre_header_page_number"] = 0,
    ["cre_header_reading_percent"] = 0,
    ["cre_header_status_font_size"] = 22,
    ["cre_header_title"] = 1,
    ["default_highlight_action"] = "ask",
    ["dev_no_c_blitter"] = false,
    ["device_id"] = "50CE58A8FE3D429EA12282E8DADCB639",
    ["device_status_battery_interval_minutes"] = 10,
    ["device_status_battery_threshold"] = 20,
    ["device_status_battery_threshold_high"] = 100,
    ["device_status_memory_interval_minutes"] = 5,
    ["device_status_memory_threshold"] = 100,
    ["dict_font_size"] = 14,
    ["dicts_disabled"] = {
        ["data/dict/stardict-dictd_www.dict.org_wn-2.4.2/dictd_www.dict.org_wn.ifo"] = true,
    },
    ["dicts_order"] = {
        ["data/dict/etymonline/stardict.ifo"] = 2,
        ["data/dict/stardict-Concise_Oxford_English_Dictionary-2.4.2/Concise_Oxford_English_Dictionary.ifo"] = 3,
        ["data/dict/stardict-Oxford_English_Dictionary_2nd_Ed._P1-2.4.2/Oxford_English_Dictionary_2nd_Ed._P1.ifo"] = 5,
        ["data/dict/stardict-Oxford_English_Dictionary_2nd_Ed._P2-2.4.2/Oxford_English_Dictionary_2nd_Ed._P2.ifo"] = 6,
        ["data/dict/stardict-WordNet_3-2.4.2/WordNet_3.ifo"] = 1,
        ["data/dict/stardict-dictd_www.dict.org_gcide-2.4.2/dictd_www.dict.org_gcide.ifo"] = 4,
    },
    ["disable_double_tap"] = false,
    ["document_metadata_folder"] = "doc",
    ["duration_format"] = "classic",
    ["exporter"] = {
        ["html"] = {
            ["enabled"] = false,
        },
        ["joplin"] = {
            ["enabled"] = false,
        },
        ["json"] = {
            ["enabled"] = false,
        },
        ["markdown"] = {
            ["formatting_options"] = {
                ["invert"] = "bold",
                ["lighten"] = "italic",
                ["strikeout"] = "strikethrough",
                ["underscore"] = "underline_markdownit",
            },
            ["highlight_formatting"] = true,
        },
        ["memos"] = {
            ["enabled"] = false,
        },
        ["my_clippings"] = {
            ["enabled"] = false,
        },
        ["readwise"] = {
            ["enabled"] = false,
        },
        ["text"] = {
            ["enabled"] = false,
        },
    },
    ["filemanagermenu_tab_index"] = 5,
    ["folder_shortcuts"] = {},
    ["footer"] = {
        ["align"] = "center",
        ["all_at_once"] = true,
        ["auto_refresh_time"] = true,
        ["battery"] = false,
        ["battery_hide_threshold"] = 100,
        ["book_chapter"] = true,
        ["book_chapter_max_width_pct"] = 100,
        ["book_time_to_read"] = false,
        ["book_title"] = false,
        ["book_title_max_width_pct"] = 100,
        ["bookmark_count"] = false,
        ["bottom_horizontal_separator"] = false,
        ["chapter_progress"] = false,
        ["chapter_time_to_read"] = false,
        ["container_bottom_padding"] = 1,
        ["container_height"] = 14,
        ["custom_text"] = false,
        ["disable_progress_bar"] = true,
        ["disabled"] = false,
        ["frontlight"] = false,
        ["hide_empty_generators"] = true,
        ["initial_marker"] = false,
        ["item_prefix"] = "icons",
        ["items_separator"] = "none",
        ["lock_tap"] = true,
        ["mem_usage"] = false,
        ["page_progress"] = false,
        ["pages_left"] = true,
        ["pages_left_book"] = false,
        ["pages_left_includes_current_page"] = false,
        ["percentage"] = false,
        ["progress_bar_min_width_pct"] = 20,
        ["progress_bar_position"] = "below",
        ["progress_margin"] = false,
        ["progress_margin_width"] = 22,
        ["progress_pct_format"] = "0",
        ["progress_style_thick_height"] = 7,
        ["progress_style_thin_height"] = 3,
        ["reclaim_height"] = true,
        ["skim_widget_on_hold"] = false,
        ["text_font_bold"] = false,
        ["text_font_size"] = 10,
        ["time"] = false,
        ["toc_markers"] = true,
        ["toc_markers_width"] = 1,
        ["wifi_status"] = true,
    },
    ["frontlight_intensity"] = 28,
    ["frontlight_warmth"] = 70,
    ["ges_hold_interval_ms"] = 500,
    ["ges_swipe_interval_ms"] = 2000,
    ["ges_tap_interval_ms"] = 0,
    ["ges_tap_interval_on_keyboard_ms"] = 0,
    ["highlight_lighten_factor"] = 0.2,
    ["highlight_long_hold_threshold_s"] = 3,
    ["history_filter"] = "all",
    ["hold_pan_rate"] = 5,
    ["home_dir"] = "/mnt/onboard/books",
    ["hyph_soft_hyphens_only"] = true,
    ["inertial_scroll"] = false,
    ["input_invert_page_turn_keys"] = true,
    ["input_lock_gsensor"] = true,
    ["inverse_reading_order"] = true,
    ["invert_ui_layout_mirroring"] = true,
    ["is_frontlight_on"] = true,
    ["keyboard_key_font_size"] = 22,
    ["keyboard_layouts"] = {},
    ["kosync"] = {
        ["auto_sync"] = false,
        ["checksum_method"] = 0,
        ["sync_backward"] = 3,
        ["sync_forward"] = 1,
    },
    ["language"] = "C",
    ["last_migration_date"] = 20230901,
    ["lastdir"] = "/mnt/onboard/books",
    ["lastfile"] = "/mnt/onboard/books/James White/Sector General 01 - Beginning Operations - James White.epub",
    ["metric_length"] = true,
    ["multiswipes_enabled"] = false,
    ["night_mode"] = false,
    ["notification_sources_to_show_mask"] = 60,
    ["opds_servers"] = {
        [1] = {
            ["title"] = "Project Gutenberg",
            ["url"] = "https://m.gutenberg.org/ebooks.opds/?format=opds",
        },
        [2] = {
            ["title"] = "Standard Ebooks",
            ["url"] = "https://standardebooks.org/feeds/opds",
        },
        [3] = {
            ["title"] = "Feedbooks",
            ["url"] = "https://catalog.feedbooks.com/catalog/public_domain.atom",
        },
        [4] = {
            ["title"] = "ManyBooks",
            ["url"] = "http://manybooks.net/opds/index.php",
        },
        [5] = {
            ["title"] = "Internet Archive",
            ["url"] = "https://bookserver.archive.org/",
        },
        [6] = {
            ["title"] = "textos.info (Spanish)",
            ["url"] = "https://www.textos.info/catalogo.atom",
        },
        [7] = {
            ["title"] = "Gallica (French)",
            ["url"] = "https://gallica.bnf.fr/opds",
        },
    },
    ["page_turns_tap_zone_backward_size_ratio"] = 0.25,
    ["page_turns_tap_zone_forward_size_ratio"] = 0.75,
    ["page_turns_tap_zones"] = "left_right",
    ["pagemap_show_page_labels"] = false,
    ["plugins_disabled"] = {
        ["calibrecompanion"] = true,
        ["evernote"] = true,
        ["goodreads"] = true,
        ["kobolight"] = true,
        ["send2ebook"] = true,
        ["storagestat"] = true,
        ["zsync"] = true,
    },
    ["quickstart_shown_version"] = 202308000000,
    ["reader_footer_custom_text"] = "KOReader",
    ["reader_footer_custom_text_repetitions"] = "1",
    ["reader_footer_mode"] = 1,
    ["screensaver_delay"] = "disable",
    ["screensaver_hide_fallback_msg"] = true,
    ["screensaver_image"] = "/mnt/onboard/.adds/koreader/screensaver/Flying_Books.png",
    ["screensaver_img_background"] = "none",
    ["screensaver_message"] = "sdothum@gmail.com",
    ["screensaver_message_position"] = "bottom",
    ["screensaver_msg_background"] = "none",
    ["screensaver_show_message"] = false,
    ["screensaver_stretch_images"] = false,
    ["screensaver_type"] = "image_file",
    ["scroll_method"] = "classic",
    ["show_bottom_menu"] = false,
    ["show_finished"] = true,
    ["start_with"] = "history",
    ["statistics"] = {
        ["calendar_browse_future_months"] = false,
        ["calendar_nb_book_spans"] = 3,
        ["calendar_show_histogram"] = true,
        ["calendar_start_day_of_week"] = 2,
        ["convert_to_db"] = true,
        ["is_enabled"] = true,
        ["max_sec"] = 120,
        ["min_sec"] = 5,
    },
    ["style_tweaks"] = {
        ["footnote-inpage_epub_smaller"] = true,
        ["footnote-inpage_fb2"] = true,
        ["lineheight_all_inherit"] = true,
    },
    ["style_tweaks_in_dispatcher"] = {},
    ["terminal_buffer_size"] = 16,
    ["text_lang_fallback"] = "en-US",
    ["toc_items_font_size"] = 14,
    ["toc_items_per_page"] = 22,
    ["vocabulary_builder"] = {
        ["enabled"] = true,
        ["with_context"] = true,
    },
    ["wifi_was_on"] = true,
}
