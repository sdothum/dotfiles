// See LICENSE file for copyright and license details.

#ifndef CLIENTS_H
#define CLIENTS_H

#include <stdbool.h>
#include <stdint.h>
#include <xcb/xcb.h>

#include "types.h"

bool is_mapped(xcb_window_t);
bool is_special(struct client *);
bool get_geometry(xcb_window_t *,
	int16_t *, int16_t *,
	uint16_t *, uint16_t *,
	uint8_t *);

struct client *find_client(xcb_window_t *);
struct client *find_client_by_frame(xcb_window_t);
struct client *setup_window(xcb_window_t);

void free_window(struct client *);
void raise_client_with_frame(struct client *);
void reset_window(struct client *);
void update_client_list(void);

#endif
