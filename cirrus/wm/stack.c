// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <xcb/xcb.h>

#include "clients.h"
#include "focus.h"
#include "ewmh.h"
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

/* X remains the source of within-tier order. Include EWMH ABOVE/dock root
 * windows without enrolling panels in focus/group policy. Other unmanaged
 * children retain their slots. Frames share their owner's
 * tier. Callers hold the server grab so a request and its tier correction are
 * one externally observable operation. */
static bool
restack_layers(void)
{
	xcb_query_tree_reply_t *tree = xcb_query_tree_reply(conn,
			xcb_query_tree(conn, scr->root), NULL);
	xcb_window_t *ordered;
	int *layers;
	xcb_window_t *children;
	bool ok = true, changed = false;
	int count, slot = 0;
	if (tree == NULL)
		return false;
	count = xcb_query_tree_children_length(tree);
	children = xcb_query_tree_children(tree);
	ordered = calloc(count ? count : 1, sizeof(*ordered));
	layers = calloc(count ? count : 1, sizeof(*layers));
	if (ordered == NULL || layers == NULL) {
		free(ordered);
		free(layers);
		free(tree);
		return false;
	}
	for (int i = 0; i < count; i++) {
		struct client *client = find_client_from_window(children[i]);
		ordered[i] = children[i];
		layers[i] = client != NULL ? (int)client->layer : -1;
		if (client == NULL) {
			/* Read properties on the live root child: no XID lifetime cache. */
			if (default_window_layer(children[i]) == LayerAbove)
				layers[i] = LayerAbove;
			xcb_get_window_attributes_reply_t *attributes = xcb_get_window_attributes_reply(
					conn, xcb_get_window_attributes(conn, children[i]), NULL);
			if (attributes != NULL) {
				uint32_t mask = attributes->your_event_mask | XCB_EVENT_MASK_PROPERTY_CHANGE;
				if (mask != attributes->your_event_mask)
					xcb_change_window_attributes(conn, children[i], XCB_CW_EVENT_MASK, &mask);
				free(attributes);
			}
		}
	}
	for (int layer = LayerNormal; layer <= LayerOverlay; layer++) {
		for (int i = 0; i < count; i++) {
			if (layers[i] != layer)
				continue;
			while (slot < count && layers[slot] < 0)
				slot++;
			ordered[slot++] = children[i];
		}
	}
	for (int i = 0; i < count; i++)
		if (ordered[i] != children[i])
			changed = true;
	if (changed) {
		struct explicit_geometry_guard guard;
		begin_stacking_guard(&guard);
		for (int i = 1; i < count; i++) {
			uint32_t values[] = { ordered[i - 1], XCB_STACK_MODE_ABOVE };
			xcb_generic_error_t *error = xcb_request_check(conn,
					xcb_configure_window_checked(conn, ordered[i],
						XCB_CONFIG_WINDOW_SIBLING | XCB_CONFIG_WINDOW_STACK_MODE, values));
			if (error != NULL) {
				free(error);
				ok = false;
				break;
			}
		}
		finish_explicit_geometry_guard(&guard);
	}
	free(layers);
	free(ordered);
	free(tree);
	return ok;
}

void
configure_window_stacking(xcb_connection_t *connection, xcb_window_t window,
		uint16_t mask, const void *values)
{
	if (!(mask & XCB_CONFIG_WINDOW_STACK_MODE)) {
		xcb_configure_window(connection, window, mask, values);
		return;
	}
	xcb_grab_server(conn);
	xcb_configure_window(connection, window, mask, values);
	if (!restack_layers())
		fprintf(stderr, "cirrus: unable to enforce stacking layers\n");
	xcb_ungrab_server(conn);
}

void
map_window_stacking(xcb_connection_t *connection, xcb_window_t window)
{
	refresh_window_layer(find_client(&window));
	/* New root children initially sit at the top, even before mapping. */
	xcb_grab_server(conn);
	if (!restack_layers())
		fprintf(stderr, "cirrus: unable to enforce stacking layers\n");
	xcb_map_window(connection, window);
	xcb_ungrab_server(conn);
}

bool
set_window_layer(struct client *client, enum stacking_layer layer, bool explicit_layer)
{
	enum stacking_layer previous;
	bool previous_explicit;
	bool ok = false;
	xcb_get_window_attributes_reply_t *attributes;
	if (client == NULL || layer < LayerNormal || layer > LayerOverlay)
		return false;
	xcb_grab_server(conn);
	/* A DestroyNotify may still be queued: reject stale managed records. */
	attributes = xcb_get_window_attributes_reply(conn,
			xcb_get_window_attributes(conn, client->window), NULL);
	if (attributes == NULL)
		goto done;
	free(attributes);
	previous = client->layer;
	previous_explicit = client->layer_explicit;
	client->layer_explicit = explicit_layer;
	client->layer = layer;
	if (!restack_layers()) {
		client->layer = previous;
		client->layer_explicit = previous_explicit;
		restack_layers();
		goto done;
	}
	ok = update_ewmh_layer_state(client);
	if (!ok) {
		client->layer = previous;
		client->layer_explicit = previous_explicit;
		restack_layers();
		update_ewmh_layer_state(client);
	}
 done:
	xcb_ungrab_server(conn);
	xcb_flush(conn);
	return ok;
}

void
circulate_window_stacking(xcb_window_t window, uint8_t direction)
{
	xcb_grab_server(conn);
	xcb_circulate_window(conn, window, direction);
	if (!restack_layers())
		fprintf(stderr, "cirrus: unable to enforce stacking layers\n");
	xcb_ungrab_server(conn);
}

void
refresh_window_layer(struct client *client)
{
	if (client == NULL)
		return;
	if (client->layer_explicit) {
		/* Keep the published state consistent if an application rewrites it. */
		bool above = window_has_ewmh_atom(client->window, ewmh->_NET_WM_STATE,
				ewmh->_NET_WM_STATE_ABOVE);
		if (above != (client->layer == LayerAbove))
			update_ewmh_layer_state(client);
		return;
	}
	enum stacking_layer layer = default_window_layer(client->window);
	if (layer != client->layer)
		set_window_layer(client, layer, false);
}

void
enforce_stacking_layers(void)
{
	xcb_grab_server(conn);
	if (!restack_layers())
		fprintf(stderr, "cirrus: unable to enforce stacking layers\n");
	xcb_ungrab_server(conn);
}
