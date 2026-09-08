// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <xcb/xcb.h>

#include "clients.h"
#include "geometry.h"
#include "list.h"
#include "stack.h"
#include "types.h"
#include "wm_state.h"

enum window_stack_result
get_window_stack(struct client *reference, struct window_stack *stack)
{
	bool changed;
	bool *included = NULL;
	int children_length;
	size_t client_count = 0;
	size_t i, j;
	struct client *client;
	struct client **clients = NULL;
	struct list_item *item;
	xcb_query_tree_reply_t *tree = NULL;
	xcb_window_t *children;
	enum window_stack_result result = WindowStackSuccess;

	stack->clients = NULL;
	stack->count = 0;
	stack->reference_index = 0;
	if (!reference->mapped)
		return WindowStackReferenceNotMapped;

	for (item = win_list; item != NULL; item = item->next)
		client_count++;
	clients = calloc(client_count, sizeof(*clients));
	included = calloc(client_count, sizeof(*included));
	if (clients == NULL || included == NULL) {
		result = WindowStackAllocationFailed;
		goto done;
	}

	tree = xcb_query_tree_reply(conn, xcb_query_tree(conn, scr->root), NULL);
	if (tree == NULL) {
		result = WindowStackOrderUnavailable;
		goto done;
	}
	children = xcb_query_tree_children(tree);
	children_length = xcb_query_tree_children_length(tree);
	client_count = 0;
	for (int child = 0; child < children_length; child++) {
		client = find_client(&children[child]);
		if (client == NULL || !client->mapped)
			continue;
		for (i = 0; i < client_count && clients[i] != client; i++);
		if (i == client_count)
			clients[client_count++] = client;
	}

	for (i = 0; i < client_count && clients[i] != reference; i++);
	if (i == client_count) {
		result = WindowStackReferenceMissing;
		goto done;
	}
	included[i] = true;
	do {
		changed = false;
		for (i = 0; i < client_count; i++) {
			if (included[i])
				continue;
			for (j = 0; j < client_count; j++) {
				if (included[j] && clients_overlap(clients[i], clients[j])) {
					included[i] = true;
					changed = true;
					break;
				}
			}
		}
	} while (changed);

	stack->clients = clients;
	clients = NULL;
	for (i = 0; i < client_count; i++) {
		if (!included[i])
			continue;
		if (stack->clients[i] == reference)
			stack->reference_index = stack->count;
		stack->clients[stack->count++] = stack->clients[i];
	}

done:
	free(tree);
	free(included);
	free(clients);
	return result;
}

void
free_window_stack(struct window_stack *stack)
{
	free(stack->clients);
	stack->clients = NULL;
	stack->count = 0;
	stack->reference_index = 0;
}
