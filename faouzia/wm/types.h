// See LICENSE file for copyright and license details.

#ifndef WM_TYPES_H
#define WM_TYPES_H

#include <xcb/randr.h>
#include <stdbool.h>

enum position {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,

	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_RIGHT,
	BOTTOM_LEFT,

	CENTER,
	ALL,
};

enum direction {
	NORTH,
	EAST,
	SOUTH,
	WEST,
};

enum mouse_mode {
	MOUSE_NONE,
	MOUSE_MOVE,
	MOUSE_RESIZE,
};

enum pointer_action {
	POINTER_ACTION_NOTHING,
	POINTER_ACTION_FOCUS,
	POINTER_ACTION_MOVE,
	POINTER_ACTION_RESIZE_CORNER,
	POINTER_ACTION_RESIZE_SIDE,
};

enum resize_handle {
	HANDLE_TOP,
	HANDLE_BOTTOM,
	HANDLE_LEFT,
	HANDLE_RIGHT,

	HANDLE_BOTTOM_LEFT,
	HANDLE_BOTTOM_RIGHT,
	HANDLE_TOP_LEFT,
	HANDLE_TOP_RIGHT,
};

enum border_style {
	BORDER_STYLE_FRAME,
	BORDER_STYLE_SPINE_LEFT,
	BORDER_STYLE_SPINE_TOP,
	BORDER_STYLE_SPINE_BOTTOM,
	BORDER_STYLE_SPINE_RIGHT,
	BORDER_STYLE_CORNERS,
};

struct win_position {
	int16_t x, y;
};

struct window_geom {
	bool set_by_user;
	int16_t x, y;
	uint16_t width, height;
};

struct grid {
	int16_t gx, gy;
	int16_t px, py;
	int16_t sx, sy;
};

struct client {
	bool mapped;
	bool maxed, hmaxed, vmaxed, monocled, gridded;
	struct grid grid;
	struct list_item *focus_item;
	struct list_item *item;
	struct monitor *monitor;
	struct window_geom geom;
	struct window_geom orig_geom;
	uint16_t max_width, max_height;
	uint16_t min_width, min_height;
	uint16_t width_inc, height_inc;
	uint32_t group;
	uint8_t depth;
	xcb_window_t frame;
	xcb_window_t window;
};

struct monitor {
	char *name;
	int16_t x, y;
	struct list_item *item;
	uint16_t width, height;
	xcb_randr_output_t monitor;
};

struct conf {
	bool apply_settings;
	bool borders;
	bool last_window_focusing;
	bool replay_click_on_focus;
	bool resize_hints;
	bool sloppy_focus;
	bool sticky_windows;
	enum pointer_action pointer_actions[3];
	enum position cursor_position;
	int32_t border_width, internal_border_width, grid_gap;
	int32_t gap_left, gap_down, gap_up, gap_right;
	int8_t click_to_focus;
	uint16_t pointer_modifier;
	uint32_t border_style;
	uint32_t corner_mask;
	uint32_t corner_percent;
	uint32_t focus_color, unfocus_color, internal_focus_color, internal_unfocus_color;
	uint32_t groups;
};

#endif
