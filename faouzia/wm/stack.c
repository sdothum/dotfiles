// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <stdint.h>
#include <xcb/xcb.h>

#include "clients.h"
#include "focus.h"
#include "geometry.h"
#include "helpers.h"
#include "list.h"
#include "stack.h"
#include "types.h"
#include "wm_state.h"

void
window_stack_toggle(struct client *client)
{
	struct list_item *item;
	struct client *other;
	struct client *first = NULL;
	struct client *next = NULL;
	bool seen_client = false;
	uint32_t values[2];

	if (client == NULL)
		return;

	for (item = win_list; item != NULL; item = item->next) {
		other = item->data;

		if (other == NULL)
			continue;

		if (other == client) {
			seen_client = true;
			continue;
		}

		if (!other->mapped)
			continue;

		if (!clients_overlap(client, other))
			continue;

		if (first == NULL)
			first = other;

		if (seen_client) {
			next = other;
			break;
		}
	}

	if (next == NULL)
		next = first;

	if (next == NULL)
		return;

	values[0] = next->window;
	values[1] = XCB_STACK_MODE_BELOW;

	xcb_configure_window(conn,
		client->window,
		XCB_CONFIG_WINDOW_SIBLING |
		XCB_CONFIG_WINDOW_STACK_MODE,
		values);

	set_focused(next);
	xcb_flush(conn);
}


