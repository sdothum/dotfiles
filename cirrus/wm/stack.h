// See LICENSE file for copyright and license details.

#ifndef STACK_H
#define STACK_H

#include <stddef.h>
#include <stdbool.h>
#include <xcb/xcb.h>
#include "types.h"

struct client;

enum window_stack_result {
	WindowStackSuccess,
	WindowStackReferenceNotMapped,
	WindowStackAllocationFailed,
	WindowStackOrderUnavailable,
	WindowStackReferenceMissing,
};

struct window_stack {
	struct client **clients;
	size_t count;
	size_t reference_index;
};

enum window_stack_result get_window_stack(struct client *, struct window_stack *);
void free_window_stack(struct window_stack *);
void circulate_window_stacking(xcb_window_t, uint8_t);
bool set_window_layer(struct client *, enum stacking_layer, bool);
void refresh_window_layer(struct client *);
void enforce_stacking_layers(void);
void configure_window_stacking(xcb_connection_t *, xcb_window_t, uint16_t, const void *);
void map_window_stacking(xcb_connection_t *, xcb_window_t);

#endif
