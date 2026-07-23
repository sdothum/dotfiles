// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <stdint.h>

#include "clients.h"
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

	for (uint32_t i = 0; i < until; i++)
		copy[i] = group_in_use[i];

	if (groups < conf.groups)
		for (item = win_list; item != NULL; item = item->next) {
			client = item->data;
			if (client->group != NULL_GROUP && client->group >= groups) {
				group_activate(client->group);
				client->group = NULL_GROUP;
				update_wm_desktop(client);
			}
		}

	conf.groups = groups;
	free(group_in_use);
	group_in_use = copy;
}

void
group_activate(uint32_t group) {
	if (group >= conf.groups)
		return;

	struct list_item *item;
	struct client *client;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (client->group == group) {
			if (client->frame != XCB_NONE)
				xcb_map_window(conn, client->frame);
			xcb_map_window(conn, client->window);
			set_focused(client);
		}
	}
	group_in_use[group] = true;
	last_group = group;
	update_group_list();
}

void
group_activate_specific(uint32_t group)
{
	if (group >= conf.groups)
		return;

	for (unsigned int i = 0; i < conf.groups; i++) {
		if (i == group)
			group_activate(i);
		else
			group_deactivate(i);
	}
	update_group_list();
}

void
group_deactivate(uint32_t group)
{
	if (group >= conf.groups)
		return;

	struct list_item *item;
	struct client *client;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (client->group == group) {
			if (client->frame != XCB_NONE)
				xcb_unmap_window(conn, client->frame);
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
		client->group = group;
		group_in_use[group] = true;
		update_wm_desktop(client);
		update_group_list();
		update_current_desktop(client);
		update_window_status(client);
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
		client->group = NULL_GROUP;
		update_wm_desktop(client);
		update_group_list();
		update_current_desktop(client);
		update_window_status(client);
	}
}

void
group_toggle(uint32_t group)
{
	if (group >= conf.groups)
		return;

	if (group_in_use[group])
		group_deactivate(group);
	else
		group_activate(group);
	last_group = group;
	update_group_list();
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
			data[0] = i + 1;
			if (first) {
				mode = XCB_PROP_MODE_REPLACE;
				first = false;
			}
			xcb_change_property(conn, mode, scr->root, ATOMS[FAOUZIA_ACTIVE_GROUPS], XCB_ATOM_INTEGER, 32, 1, data);
		}
	}

	if (first) {
		data[0] = 0;
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, scr->root, ATOMS[FAOUZIA_ACTIVE_GROUPS], XCB_ATOM_INTEGER, 32, 1, data);
	}
}

