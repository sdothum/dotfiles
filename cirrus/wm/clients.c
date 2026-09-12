// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <err.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <xcb/xcb.h>
#include <xcb/xcb_icccm.h>

#include "border.h"
#include "clients.h"
#include "stack.h"
#include "common.h"
#include "config.h"
#include "ewmh.h"
#include "events.h"
#include "focus.h"
#include "groups.h"
#include "input.h"
#include "list.h"
#include "monitor.h"
#include "types.h"
#include "window.h"
#include "wm_state.h"
#include "xutil.h"

bool
is_mapped(xcb_window_t win)
{
	bool yes;
	xcb_get_window_attributes_reply_t *r =
		xcb_get_window_attributes_reply(conn,
				xcb_get_window_attributes(conn, win),
				NULL);
	if (r == NULL)
		return false;

	yes = r->map_state == XCB_MAP_STATE_VIEWABLE;
	free(r);

	return yes;
}

bool
is_special(struct client *client)
{
	if (client == NULL)
		return false;

	return client->maxed
		|| client->vmaxed
		|| client->hmaxed
		|| client->monocled;
}

bool
get_geometry(xcb_window_t *win, int16_t *x, int16_t *y, uint16_t *width, uint16_t *height, uint8_t *depth)
{
	xcb_get_geometry_reply_t *reply = xcb_get_geometry_reply(conn, xcb_get_geometry(conn, *win), NULL);

	if (reply == NULL)
		return false;
	if (x != NULL)
		*x = reply->x;
	if (y != NULL)
		*y = reply->y;
	if (width != NULL)
		*width = reply->width;
	if (height != NULL)
		*height = reply->height;
	if (depth != NULL)
		*depth = reply->depth;

	free(reply);
	return true;
}

struct client*
find_client(xcb_window_t *win)
{
	struct list_item *item;

	item = win_list;
	while (item != NULL && ((struct client *)item->data)->window != *win)
		item = item ->next;

	if (item == NULL)
		return NULL;
	else
		return item->data;
}

struct client *
find_client_by_frame(xcb_window_t win)
{
	struct list_item *item;
	struct client *client;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (client != NULL && client->frame == win)
			return client;
	}

	return NULL;
}

/* Resolve either the application window or its WM frame to the managed
 * client.  Root-pointer and crossing events may name either object. */
struct client *
find_client_from_window(xcb_window_t win)
{
	struct client *client = find_client(&win);

	if (client != NULL)
		return client;
	return find_client_by_frame(win);
}

void
format_client_token(struct client *client, char *buffer, size_t size)
{
	if (client == NULL || buffer == NULL || size < 50)
		return;
	snprintf(buffer, size, "%016lx%016lx:%016lx",
			(unsigned long)wm_epoch[0], (unsigned long)wm_epoch[1],
			(unsigned long)client->generation);
}

struct client *
setup_window(xcb_window_t win)
{
	uint32_t values[2];
	xcb_ewmh_get_atoms_reply_t win_type;
	xcb_atom_t atom;
	struct client *client;
	struct list_item *item;
	struct list_item *focus_item;
	xcb_size_hints_t hints;

	if (xcb_ewmh_get_wm_window_type_reply(ewmh,
				xcb_ewmh_get_wm_window_type(ewmh, win),
				&win_type, NULL) == 1) {
		unsigned int i = 0;
			/* if the window is a toolbar or a dock, map it and ignore it */
		while (i < win_type.atoms_len &&
			(atom = win_type.atoms[i]) != ewmh->_NET_WM_WINDOW_TYPE_TOOLBAR
			&& atom != ewmh->_NET_WM_WINDOW_TYPE_DOCK
			&& atom != ewmh->_NET_WM_WINDOW_TYPE_DESKTOP)
			i++;

		if (i < win_type.atoms_len) {
			xcb_ewmh_get_atoms_reply_wipe(&win_type);
			trace_restart("map special xid=0x%08x", win);
			map_window_stacking(conn, win);
			return NULL;
		}
	}

	/* subscribe to events */
	values[0] = XCB_EVENT_MASK_ENTER_WINDOW | XCB_EVENT_MASK_FOCUS_CHANGE |
			XCB_EVENT_MASK_PROPERTY_CHANGE;
	xcb_change_window_attributes(conn, win, XCB_CW_EVENT_MASK, values);
	trace_restart("setup_window xid=0x%08x event_mask=0x%x", win, values[0]);

	/* in case of fire */
	xcb_change_save_set(conn, XCB_SET_MODE_INSERT, win);

	/* assign to the null group */
	xcb_ewmh_set_wm_desktop(ewmh, win, NULL_GROUP);

	item = list_add_item(&win_list);
	if (item == NULL)
		return NULL;

	focus_item = list_add_item(&focus_list);
	if (focus_item == NULL)
		return NULL;

	client = malloc(sizeof(struct client));
	if (client == NULL)
		return NULL;
	if (next_client_generation == 0)
		errx(EXIT_FAILURE, "client identity generation exhausted");
	client->generation = next_client_generation++;

	/* initialize variables */
	focus_item->data = client;
	client->focus_item = focus_item;
	item->data = client;
	client->item = item;
	client->window = win;
	client->frame = XCB_NONE;
	client->layer_explicit = false;
	client->layer = default_window_layer(win);
	client->geom.x = client->geom.y = client->geom.width
			= client->geom.height
			= client->min_width = client->min_height = 0;
	client->width_inc = client->height_inc = 1;
	client->maxed  = client->hmaxed = client->vmaxed
			= client->monocled = client->geom.set_by_user = false;
	client->monitor = NULL;
	client->mapped = client->group_map_pending
			= client->group_unmap_pending = false;
	client->group   = NULL_GROUP;
	get_geometry(&client->window, &client->geom.x, &client->geom.y,
			&client->geom.width, &client->geom.height, &client->depth);
	client->orig_geom = client->geom;

	xcb_icccm_get_wm_normal_hints_reply(conn,
			xcb_icccm_get_wm_normal_hints_unchecked(conn, win),
			&hints, NULL);

	if (hints.flags & XCB_ICCCM_SIZE_HINT_US_POSITION)
		client->geom.set_by_user = true;

	if (hints.flags & XCB_ICCCM_SIZE_HINT_P_MIN_SIZE) {
		client->min_width = hints.min_width;
		client->min_height = hints.min_height;
	}

	if (hints.flags & XCB_ICCCM_SIZE_HINT_P_RESIZE_INC) {
		client->width_inc  = hints.width_inc;
		client->height_inc = hints.height_inc;
	}

	update_window_status(client);
	DMSG("new window was born 0x%08x\n", client->window);
	invalidate_snapshot_state();

	return client;
}

static uint32_t
existing_window_group(xcb_window_t win)
{
	xcb_get_property_reply_t *reply;
	uint32_t group = conf.groups > 1 ? 1 : NULL_GROUP;

	reply = xcb_get_property_reply(conn,
			xcb_get_property(conn, false, win, ewmh->_NET_WM_DESKTOP,
				XCB_ATOM_CARDINAL, 0, 1), NULL);
	if (reply != NULL) {
		if (reply->format == 32 && reply->value_len >= 1) {
			uint32_t value = *(uint32_t *)xcb_get_property_value(reply);
			if (value < conf.groups)
				group = value;
		}
		free(reply);
	}

	return group;
}

/* A normally unmapped client with a normal WM_STATE and a valid desktop is
 * an existing Cirrus-managed hidden client.  Withdrawn/helper windows do
 * not carry this combination and remain unmanaged at startup. */
static bool
existing_hidden_window(xcb_window_t win, uint32_t *group)
{
	xcb_get_property_reply_t *state_reply;
	xcb_get_property_reply_t *desktop_reply;
	uint32_t state;

	state_reply = xcb_get_property_reply(conn,
			xcb_get_property(conn, false, win, ATOMS[ICCCM_WM_STATE],
				ATOMS[ICCCM_WM_STATE], 0, 2), NULL);
	if (state_reply == NULL || state_reply->format != 32 ||
			state_reply->value_len < 1) {
		free(state_reply);
		return false;
	}
	state = *(uint32_t *)xcb_get_property_value(state_reply);
	free(state_reply);
	if (state != XCB_ICCCM_WM_STATE_NORMAL)
		return false;

	desktop_reply = xcb_get_property_reply(conn,
		xcb_get_property(conn, false, win, ewmh->_NET_WM_DESKTOP,
			XCB_ATOM_CARDINAL, 0, 1), NULL);
	if (desktop_reply == NULL || desktop_reply->format != 32 ||
			desktop_reply->value_len < 1) {
		free(desktop_reply);
		return false;
	}
	*group = *(uint32_t *)xcb_get_property_value(desktop_reply);
	free(desktop_reply);
	return *group < conf.groups;
}

void
adopt_existing_windows(void)
{
	xcb_query_tree_reply_t *tree;
	xcb_window_t *children;
	xcb_get_window_attributes_reply_t *attributes;
	xcb_get_input_focus_reply_t *input_focus;
	struct client *client;
	xcb_window_t focused;
	uint32_t group;
	int length;

	tree = xcb_query_tree_reply(conn,
			xcb_query_tree(conn, scr->root), NULL);
	if (tree == NULL)
		return;
	children = xcb_query_tree_children(tree);
	length = xcb_query_tree_children_length(tree);
	for (int i = 0; i < length; i++) {
		bool mapped;

		if (find_client(&children[i]) != NULL)
			continue;

		attributes = xcb_get_window_attributes_reply(conn,
				xcb_get_window_attributes(conn, children[i]), NULL);
		if (attributes == NULL)
			continue;
		if (attributes->override_redirect != 0) {
			trace_restart("adopt xid=0x%08x skip=override_redirect", children[i]);
			free(attributes);
			continue;
		}
		mapped = attributes->map_state == XCB_MAP_STATE_VIEWABLE;
		trace_restart("adopt xid=0x%08x map_state=%u mapped=%d", children[i],
				attributes->map_state, mapped);
		free(attributes);

		if (!mapped && !existing_hidden_window(children[i], &group)) {
			trace_restart("adopt xid=0x%08x skip=unmapped-unmarked", children[i]);
			continue;
		}
		if (mapped)
			group = existing_window_group(children[i]);
		client = setup_window(children[i]);
		if (client == NULL)
			continue;

		client->mapped = mapped;
		trace_restart("adopt xid=0x%08x managed mapped=%d group=%u frame=0x%08x",
				client->window, client->mapped, client->group, client->frame);
		group_add_window(client, group);
		if (randr_base != -1) {
			client->monitor = find_monitor_by_coord(client->geom.x,
					client->geom.y);
			if (client->monitor == NULL && mon_list != NULL)
				client->monitor = mon_list->data;
		}
		create_frame(client);
		if (mapped && client->frame != XCB_NONE) {
			trace_restart("adopt map frame=0x%08x client=0x%08x", client->frame,
					client->window);
			map_window_stacking(conn, client->frame);
			paint_frame(client, conf.outer_unfocus_color,
					conf.inner_unfocus_color);
			/* The client was already mapped before the new frame existed.
			 * Put it immediately above its frame without raising the pair
			 * relative to other application windows. */
			{
				uint32_t values[2] = { client->frame, XCB_STACK_MODE_ABOVE };
				configure_window_stacking(conn, client->window,
						XCB_CONFIG_WINDOW_SIBLING |
						XCB_CONFIG_WINDOW_STACK_MODE, values);
			}
		}
		if (mapped)
			set_borders(client, conf.outer_unfocus_color,
					conf.inner_unfocus_color);
	}
	free(tree);
	/* Startup adoption bypasses MapRequest's ordinary completion path.  Rebuild
	 * all per-client passive grabs before accepting pointer/button input. */
	grab_buttons();

	input_focus = xcb_get_input_focus_reply(conn,
			xcb_get_input_focus(conn), NULL);
	if (input_focus != NULL) {
		focused = input_focus->focus;
		trace_restart("adopt input_focus=0x%08x", focused);
		client = find_client(&focused);
		if (client != NULL && client->mapped)
			set_focused_no_raise(client);
		free(input_focus);
	}
	update_client_list();
}

/*
 * Deletes and frees a client from the list.
 */

void
free_window(struct client *client)
{
	struct list_item *item;
	struct list_item *focus_item;

	DMSG("freeing 0x%08x\n", client->window);
	item = client->item;
	focus_item = client->focus_item;

	destroy_frame(client);
	free(client);
	list_delete_item(&win_list, item);
	list_delete_item(&focus_list, focus_item);
	invalidate_snapshot_state();
}

void
raise_client_with_frame(struct client *client)
{
	if (client == NULL)
		return;

	if (client->frame != XCB_NONE)
		raise_window(client->frame);

	raise_window(client->window);
}

void
reset_window(struct client *client)
{
	client->geom.x = client->orig_geom.x;
	client->geom.y = client->orig_geom.y;
	client->geom.width = client->orig_geom.width;
	client->geom.height = client->orig_geom.height;
	client->maxed = client->hmaxed
			= client->vmaxed = client->monocled = false;

	teleport_window(client->window, client->geom.x, client->geom.y);
	resize_window_absolute(client->window, client->geom.width, client->geom.height);
	set_borders(client, conf.outer_unfocus_color, conf.inner_unfocus_color);

	update_ewmh_wm_state(client);
	update_window_status(client);
}

/*
 * Adds all windows to the ewmh client list.
 */

void
update_client_list(void)
{
	xcb_window_t *children;
	struct client *client;
	uint32_t len;

	xcb_query_tree_reply_t *reply = xcb_query_tree_reply(conn,
			xcb_query_tree(conn, scr->root), NULL);
	xcb_delete_property(conn, scr->root, ewmh->_NET_CLIENT_LIST);
	xcb_delete_property(conn, scr->root, ewmh->_NET_CLIENT_LIST_STACKING);

	if (reply == NULL) {
		add_to_client_list(0);
		return;
	}

	len = xcb_query_tree_children_length(reply);
	children = xcb_query_tree_children(reply);

	for (unsigned int i = 0; i < len; i++) {
		client = find_client(&children[i]);
		if (client != NULL)
			add_to_client_list(client->window);
	}

	free(reply);
}
