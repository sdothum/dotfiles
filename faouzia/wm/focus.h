// See LICENSE file for copyright and license details.

#ifndef FOCUS_H
#define FOCUS_H

#include <xcb/xcb_icccm.h>

#include "border.h"
#include "types.h"
#include "wm_state.h"

bool is_in_cardinal_direction(uint32_t , struct client *, struct client *);
bool is_in_valid_direction(uint32_t, float, float);
bool is_overlapping(struct client *, struct client *);

void cardinal_focus(uint32_t);
void center_pointer(struct client *);
void set_focused_last_best(void);
void set_focused_no_raise(struct client *);
void set_focused(struct client *);

#endif
