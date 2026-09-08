// See LICENSE file for copyright and license details.

#ifndef EWMH_H
#define EWMH_H

#include <xcb/xcb.h>

#include "types.h"

extern int scrno;

void add_to_client_list(xcb_window_t);
void handle_wm_state(struct client *, xcb_atom_t, unsigned int);
void update_current_desktop(uint32_t);
void update_desktop_viewport(void);
void update_ewmh_wm_state(struct client *);
void update_window_status(struct client *);
void update_wm_desktop(struct client *);
void invalidate_snapshot_state(void);

#endif
