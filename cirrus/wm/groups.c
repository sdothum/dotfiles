// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <stdint.h>

#include "clients.h"
#include "stack.h"
#include "ewmh.h"
#include "focus.h"
#include "groups.h"
#include "list.h"
#include "wm_state.h"
#include "xutil.h"

void
change_nr_of_groups(uint32_t groups)
{
	bool *copy = malloc(groups * sizeof(bool));
	uint32_t until = groups < conf.groups ? groups : conf.groups;
	struct list_item *item;
	struct client *client;
	bool changed = false;

	for (uint32_t i = 0; i < until; i++)
		copy[i] = group_in_use[i];

	if (groups < conf.groups)
		for (item = win_list; item != NULL; item = item->next) {
			client = item->data;
			if (client->group != NULL_GROUP && client->group >= groups) {
				group_in_use[client->group] = false;
				group_activate(client->group);
				client->group = NULL_GROUP;
				update_wm_desktop(client);
				changed = true;
			}
		}
	if (changed)
		invalidate_snapshot_state();

	conf.groups = groups;
	free(group_in_use);
	group_in_use = copy;
}

void
group_activate(uint32_t group) {
	if (group >= conf.groups || group_in_use[group])
		return;

	struct list_item *item;
	struct client *client;
	bool has_members = false;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (client->group == group) {
			has_members = true;
			if (client->mapped)
				continue;
			client->group_map_pending = true;
			if (client->frame != XCB_NONE) {
				trace_restart("map frame via group_activate frame=0x%08x client=0x%08x",
						client->frame, client->window);
				map_window_stacking(conn, client->frame);
			}
			trace_restart("map client via group_activate xid=0x%08x", client->window);
			map_window_stacking(conn, client->window);
		}
	}
	if (!has_members)
		return;
	group_in_use[group] = true;
	last_group = group;
	update_group_list();
}

void
group_deactivate(uint32_t group)
{
	if (group >= conf.groups || !group_in_use[group])
		return;

	struct list_item *item;
	struct client *client;

	if (focused_win != NULL && focused_win->group == group)
		clear_focused();

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (client->group == group) {
			if (!client->mapped)
				continue;
			client->group_unmap_pending = true;
			if (client->frame != XCB_NONE) {
				trace_restart("unmap frame via group_deactivate frame=0x%08x client=0x%08x",
						client->frame, client->window);
				xcb_unmap_window(conn, client->frame);
			}
			trace_restart("unmap client via group_deactivate xid=0x%08x", client->window);
			xcb_unmap_window(conn, client->window);
		}
	}
	group_in_use[group] = false;
	update_group_list();
}

void
group_add_window(struct client *client, uint32_t group)
{
	if (client != NULL && group < conf.groups) {
		bool changed = client->group != group;
		client->group = group;
		group_in_use[group] = true;
		update_wm_desktop(client);
		update_group_list();
		if (client == focused_win)
			update_current_desktop(focused_win->group);
		update_window_status(client);
		if (changed)
			invalidate_snapshot_state();
	}
}

void
group_remove_all_windows(uint32_t group)
{
	if (group >= conf.groups)
		return;

	struct list_item *item;
	struct client *client;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (client != NULL && client->group == group) {
			group_remove_window(client);
		}
	}

	group_in_use[group] = false;
}

void
group_remove_window(struct client *client)
{
	if (client != NULL) {
		bool changed = client->group != NULL_GROUP;
		client->group = NULL_GROUP;
		update_wm_desktop(client);
		update_group_list();
		if (client == focused_win)
			update_current_desktop(focused_win->group);
		update_window_status(client);
		if (changed)
			invalidate_snapshot_state();
	}
}

void 
update_group_list(void)
{
	struct list_item *item;
	struct client *client;
	bool first = true;
	uint32_t data[1];

	for (unsigned int i = 0; i < conf.groups; i++) {
		/* deactivate group if no window in group */
		item = win_list;
		while (item != NULL && (client = item->data)->group != i)
			item = item->next;
		if (item == NULL)
			group_in_use[i] = false;

		if (group_in_use[i]) {
			uint8_t mode = XCB_PROP_MODE_APPEND;
			data[0] = i;
			if (first) {
				mode = XCB_PROP_MODE_REPLACE;
				first = false;
			}
			xcb_change_property(conn, mode, scr->root, ATOMS[CIRRUS_ACTIVE_GROUPS], XCB_ATOM_INTEGER, 32, 1, data);
		}
	}

	if (first) {
		data[0] = 0;
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, scr->root, ATOMS[CIRRUS_ACTIVE_GROUPS], XCB_ATOM_INTEGER, 32, 1, data);
	}
}
