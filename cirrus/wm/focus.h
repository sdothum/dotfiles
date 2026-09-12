// See LICENSE file for copyright and license details.

#ifndef FOCUS_H
#define FOCUS_H

#include <xcb/xcb_icccm.h>

#include "border.h"
#include "types.h"
#include "wm_state.h"

struct explicit_geometry_guard {
	bool stacking;
	bool active;
	xcb_window_t focused_window;
	xcb_window_t pointer_child;
	int16_t root_x, root_y;
	uint32_t lower_sequence;
};

bool is_in_cardinal_direction(uint32_t , struct client *, struct client *);
bool is_in_valid_direction(uint32_t, float, float);
bool is_overlapping(struct client *, struct client *);

void cardinal_focus(uint32_t);
void center_pointer(struct client *);
void clear_focused(void);
void begin_explicit_geometry_guard(struct client *, struct explicit_geometry_guard *);
void expire_stacking_guards(uint32_t);
void begin_stacking_guard(struct explicit_geometry_guard *);
void finish_explicit_geometry_guard(struct explicit_geometry_guard *);
void set_focused_last_best(void);
void set_focused_no_raise(struct client *);
void set_focused(struct client *);
bool suppress_explicit_geometry_enter(xcb_generic_event_t *, xcb_enter_notify_event_t *);

#endif
