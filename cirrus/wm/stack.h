// See LICENSE file for copyright and license details.

#ifndef STACK_H
#define STACK_H

#include <stddef.h>

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

#endif
