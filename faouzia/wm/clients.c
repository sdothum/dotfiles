// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <xcb/xcb.h>
#include <xcb/xcb_icccm.h>

#include "border.h"
#include "clients.h"
#include "common.h"
#include "config.h"
#include "ewmh.h"
#include "events.h"
#include "list.h"
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
		|| client->monocled
		|| client->gridded;
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
			xcb_map_window(conn, win);
			return NULL;
		}
	}

	/* subscribe to events */
	values[0] = XCB_EVENT_MASK_ENTER_WINDOW | XCB_EVENT_MASK_FOCUS_CHANGE;
	xcb_change_window_attributes(conn, win, XCB_CW_EVENT_MASK, values);

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

	/* initialize variables */
	focus_item->data = client;
	client->focus_item = focus_item;
	item->data = client;
	client->item = item;
	client->window = win;
	client->frame = XCB_NONE;
	client->geom.x = client->geom.y = client->geom.width
			= client->geom.height
			= client->min_width = client->min_height = 0;
	client->grid.gx = client->grid.gy = client->grid.px
			= client->grid.py = client->grid.sx = client->grid.sy = 0;
	client->width_inc = client->height_inc = 1;
	client->maxed  = client->hmaxed = client->vmaxed
			= client->monocled = client->gridded = client->geom.set_by_user = false;
	client->monitor = NULL;
	client->mapped  = false;
	client->group   = NULL_GROUP;
	get_geometry(&client->window, &client->geom.x, &client->geom.y,
			&client->geom.width, &client->geom.height, &client->depth);

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

	return client;
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
	xcb_atom_t state[] = {
		XCB_ICCCM_WM_STATE_NORMAL,
		XCB_NONE
	};
	client->geom.x = client->orig_geom.x;
	client->geom.y = client->orig_geom.y;
	client->geom.width = client->orig_geom.width;
	client->geom.height = client->orig_geom.height;
	client->maxed = client->hmaxed
			= client->vmaxed = client->monocled = client->gridded = false;

	teleport_window(client->window, client->geom.x, client->geom.y);
	resize_window_absolute(client->window, client->geom.width, client->geom.height);
	set_borders(client, conf.unfocus_color, conf.internal_unfocus_color);

	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, client->window,
			ewmh->_NET_WM_STATE, ewmh->_NET_WM_STATE, 32, 2, state);
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

