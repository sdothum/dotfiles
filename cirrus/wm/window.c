// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <stdint.h>
#include <xcb/xcb.h>

#include "border.h"
#include "clients.h"
#include "common.h"
#include "ewmh.h"
#include "focus.h"
#include "monitor.h"
#include "randr.h"
#include "types.h"
#include "window.h"
#include "wm_state.h"
#include "xutil.h"

/*
 * Ask window to close gracefully. If the window doesn't respond, kill it.
 */

void
close_window(struct client *client)
{
	if (client == NULL)
		return;

	if (conf.last_window_focusing && client != NULL && client == focused_win)
		set_focused_last_best();

	if (focused_win == client)
		clear_focused();

	xcb_window_t win = client->window;
	xcb_get_property_cookie_t cookie =
		xcb_icccm_get_wm_protocols_unchecked(conn,
				win, ewmh->WM_PROTOCOLS);
	xcb_icccm_get_wm_protocols_reply_t reply;
	unsigned int i = 0;
	bool got = false;

	if (xcb_icccm_get_wm_protocols_reply(conn, cookie, &reply, NULL)) {
		for (i = 0; i < reply.atoms_len; i++) {
			got = (reply.atoms[i] == ATOMS[WM_DELETE_WINDOW]);
			if (got)
				break;
		}

		xcb_icccm_get_wm_protocols_reply_wipe(&reply);
	}

	if (got)
		delete_window(win);
	else
		xcb_kill_client(conn, win);
}

void
cycle_window_in_group(struct client *client)
{
	struct list_item *item;
	struct client *data;

	if (client == NULL)
		return;

	item = win_list;
	while (item != NULL && item->data != client)
		item = item->next;
	if (item != NULL)
		do {
			item = item->next;
			if (item == NULL)
				item = win_list;
			data = item->data;
		} while (!data->mapped || data->group != client->group);

	if (item != NULL && data != client && data->group == client->group)
		set_focused(item->data);
}

void
cycle_window(struct client *client)
{
	struct list_item *item;
	struct client *data;

	item = win_list;
	if (client != NULL)
			while (item != NULL && item->data != client)
				item = item->next;

	/* if item is not found item will be null and we'll get a nice segmentation fault */
	if (item != NULL)
		do {
			item = item->next;
			if (item == NULL)
				item = win_list;
			data = item->data;
		} while (!data->mapped);

	if (item != NULL && item->data != client)
		set_focused(item->data);
}

void
delete_window(xcb_window_t win)
{
	xcb_client_message_event_t ev;

	ev.response_type = XCB_CLIENT_MESSAGE;
	ev.sequence = 0;
	ev.format = 32;
	ev.window = win;
	ev.type = ewmh->WM_PROTOCOLS;
	ev.data.data32[0] = ATOMS[WM_DELETE_WINDOW];
	ev.data.data32[1] = XCB_CURRENT_TIME;

	xcb_send_event(conn, 0, win, XCB_EVENT_MASK_NO_EVENT, (char *)&ev);
}

/*
 * Put window at the top of the window stack.
 */

void
raise_window(xcb_window_t win)
{
	uint32_t values[1] = { XCB_STACK_MODE_ABOVE };
	xcb_configure_window(conn, win, XCB_CONFIG_WINDOW_STACK_MODE, values);
}

void
rcycle_window_in_group(struct client *client)
{
	struct list_item *item = NULL;
	struct list_item *last_item;
	struct list_item *client_item;
	struct client *data;

	if (win_list == NULL || client == NULL)
		return;

	/* find item of client */
	item = win_list;
	while (item != NULL && item->data != client)
		item = item->next;

	if (item == NULL)
		return;

	client_item = item;

	/* find last window */
	item = win_list;
	while (item != NULL) {
		last_item = item;
		item = item->next;
	}

	item = client_item;
	do {
		item = item->prev;
		if (item == NULL)
			item = last_item;
		data = item->data;
	} while (!data->mapped || data->group != client->group);

	if (item != NULL && data != client && data->group == client->group)
		set_focused(item->data);
}

void
rcycle_window(struct client *client)
{
	struct list_item *item = NULL;
	struct list_item *last_item;
	struct list_item *client_item;
	struct client *data;

	if (win_list == NULL)
		return;

	/* find last window */
	item = win_list;
	while (item != NULL) {
		last_item = item;
		item = item->next;
	}

	/* find item of client */
	item = win_list;
	while (item != NULL && item->data != client)
		item = item->next;

	if (item == NULL)
		item = last_item;

	client_item = item;

	item = client_item;
	do {
		item = item->prev;
		if (item == NULL)
			item = last_item;
		data = item->data;
	} while (!data->mapped);

	if (item != NULL && item->data != client)
		set_focused(item->data);
}

/*
 * Hide (unmap) window.
 */

void
window_hide(struct client *client)
{
	trace_restart("window_hide xid=0x%08x frame=0x%08x mapped=%d",
			client->window, client->frame, client->mapped);
	if (client->frame != XCB_NONE) {
		trace_restart("unmap frame via hide frame=0x%08x client=0x%08x",
				client->frame, client->window);
		xcb_unmap_window(conn, client->frame);
	}

	trace_restart("unmap client via hide xid=0x%08x", client->window);
	xcb_unmap_window(conn, client->window);
	xcb_flush(conn);
}

/*
 * Fit window on screen if too big.
 */

void
fit_on_screen(struct client *client)
{
	int16_t mon_x, mon_y;
	uint16_t mon_width, mon_height;
	bool will_resize, will_move;

	will_resize = will_move = false;
	client->hmaxed = client->vmaxed = false;
	get_monitor_size(client, &mon_x, &mon_y, &mon_width, &mon_height);
	if (client->maxed) {
		client->maxed = false;
	} else if (client->geom.width == mon_width && client->geom.height == mon_height) {
		struct window_geom normal_geom = client->geom;

		client->geom.x = mon_x;
		client->geom.y = mon_y;
		client->geom.width -= 2 * outer_border_extent();
		client->geom.height -= 2 * outer_border_extent();
		maximize_window(client, mon_x, mon_y, mon_width, mon_height);
		client->orig_geom = normal_geom;
		return;
	}

	/* Is it outside the display? */
	if (client->geom.x > mon_x + mon_width || client->geom.y > mon_y + mon_height
			|| client->geom.x < mon_x || client->geom.y < mon_y) {
		will_move = true;
		if (client->geom.x > mon_x + mon_width)
			client->geom.x = mon_x + mon_width - client->geom.width - 2 * outer_border_extent();
		else if (client->geom.x < mon_x)
			client->geom.x = mon_x;
		if (client->geom.y > mon_y + mon_height)
			client->geom.y = mon_y + mon_height - client->geom.height - 2 * outer_border_extent();
		else if (client->geom.y < mon_y)
			client->geom.y = mon_y;
	}

	/* Is it smaller than it wants to be? */
	if (client->min_width != 0 && client->geom.width < client->min_width) {
		client->geom.width = client->min_width;
		will_resize = true;
	}
	if (client->min_height != 0 && client->geom.height < client->min_height) {
		client->geom.height = client->min_height;

		will_resize = true;
	}

	// If the window is larger than the screen or is a bit in the outside,
	// move it to the corner and resize it accordingly.
	if (client->geom.width + 2 * outer_border_extent() > mon_width) {
		client->geom.x = mon_x;
		client->geom.width = mon_width - 2 * outer_border_extent();
		will_move = will_resize = true;
	} else if (client->geom.x + client->geom.width + 2 * outer_border_extent()
			> mon_x + mon_width) {
		client->geom.x = mon_x + mon_width - client->geom.width - 2 * outer_border_extent();
		will_move = true;
	}

	if (client->geom.height + 2 * outer_border_extent() > mon_height) {
		client->geom.y = mon_y;
		client->geom.height = mon_height - 2 * outer_border_extent();
		will_move = will_resize = true;
	} else if (client->geom.y + client->geom.height + 2 * outer_border_extent()
			> mon_y + mon_height) {
		client->geom.y = mon_y + mon_height - client->geom.height - 2 * outer_border_extent();
		will_move = true;
	}

	if (will_move)
		teleport_window(client->window, client->geom.x, client->geom.y);
	if (will_resize)
		resize_window_absolute(client->window, client->geom.width, client->geom.height);
}

void
maximize_window(struct client *client, int16_t mon_x, int16_t mon_y, uint16_t mon_width, uint16_t mon_height)
{
	uint32_t values[1];
	if (client == NULL || client->window == XCB_NONE)
		return;

	if (is_special(client))
		reset_window(client);

	client->maxed = true;

	/* maximized windows don't have borders */
	values[0] = 0;
	client->orig_geom = client->geom;
	xcb_configure_window(conn, client->window, XCB_CONFIG_WINDOW_BORDER_WIDTH,
			values);

	client->geom.x = mon_x;
	client->geom.y = mon_y;
	// client->geom.width = mon_width - 2 * outer_border_extent();
	// client->geom.height = mon_height - 2 * outer_border_extent();
	client->geom.width = mon_width;
	client->geom.height = mon_height;

	teleport_window(client->window, client->geom.x, client->geom.y);
	resize_window_absolute(client->window, client->geom.width, client->geom.height);
	set_focused_no_raise(client);

	update_ewmh_wm_state(client);
	update_window_status(client);
}

void
hmaximize_window(struct client *client, int16_t mon_x, uint16_t mon_width)
{
	if (client == NULL)
		return;

	if (is_special(client))
		reset_window(client);

	client->orig_geom = client->geom;
	client->geom.x = mon_x + conf.gap_left;
	client->geom.width = mon_width - conf.gap_left - conf.gap_right - 2 * outer_border_extent();

	teleport_window(client->window, client->geom.x, client->geom.y);
	resize_window_absolute(client->window, client->geom.width, client->geom.height);
	client->hmaxed = true;

	update_ewmh_wm_state(client);
	update_window_status(client);
}

void
vmaximize_window(struct client *client, int16_t mon_y, uint16_t mon_height)
{
	if (client == NULL)
		return;

	if (is_special(client))
		reset_window(client);

	client->orig_geom = client->geom;

	client->geom.y = mon_y + conf.gap_up;
	client->geom.height = mon_height - conf.gap_up - conf.gap_down - 2 * outer_border_extent();

	teleport_window(client->window, client->geom.x, client->geom.y);
	resize_window_absolute(client->window, client->geom.width, client->geom.height);
	client->vmaxed = true;

	update_ewmh_wm_state(client);
	update_window_status(client);
}

void
monocle_window(struct client *client, int16_t mon_x, int16_t mon_y, uint16_t mon_width, uint16_t mon_height)
{
	if (client == NULL)
		return;

	if (is_special(client))
		reset_window(client);

	client->orig_geom = client->geom;

	client->geom.x = mon_x + conf.gap_left;
	client->geom.y = mon_y + conf.gap_up;
	client->geom.width = mon_width - 2 * outer_border_extent()
		- conf.gap_left - conf.gap_right;
	client->geom.height = mon_height - 2 * outer_border_extent()
		- conf.gap_up - conf.gap_down;
	teleport_window(client->window, client->geom.x, client->geom.y);
	resize_window_absolute(client->window, client->geom.width, client->geom.height);
	client->monocled = true;
	set_focused_no_raise(client);

	update_ewmh_wm_state(client);
	update_window_status(client);
}

/*
 * Resizes window to the given size.
 */

void
resize_window_absolute(xcb_window_t win, uint16_t w, uint16_t h)
{
	uint32_t val[2];
	uint32_t mask = XCB_CONFIG_WINDOW_WIDTH
			| XCB_CONFIG_WINDOW_HEIGHT;

	val[0] = w;
	val[1] = h;

	xcb_configure_window(conn, win, mask, val);
	update_window_status(find_client(&win));
	refresh_borders();
}

/*
 * Resizes window by a certain amount.
 */

void
resize_window(xcb_window_t win, int16_t w, int16_t h)
{
	struct client *client;
	int32_t aw, ah;

	client = find_client(&win);
	if (client == NULL)
		return;

	aw = client->geom.width;
	ah = client->geom.height;

	if (aw + w > 0)
		aw += w;
	if (ah + h > 0)
		ah += h;

	/* avoid weird stuff */
	if (aw < 0)
		aw = 0;
	if (ah < 0)
		ah = 0;

	if (client->min_width != 0 && aw < client->min_width)
		aw = client->min_width;

	if (client->min_height != 0 && ah < client->min_height)
		ah = client->min_height;

	client->geom.width  = aw - conf.resize_hints * (aw % client->width_inc);
	client->geom.height = ah - conf.resize_hints * (ah % client->height_inc);

	resize_window_absolute(win, client->geom.width, client->geom.height);
}

/*
 * Moves the window by a certain amount.
 */

void
move_window(xcb_window_t win, int16_t x, int16_t y)
{
	int16_t win_x = 0, win_y = 0;
	uint16_t win_w, win_h;

	if (!is_mapped(win) || win == scr->root)
		return;

	get_geometry(&win, &win_x, &win_y, &win_w, &win_h, NULL);

	win_x += x;
	win_y += y;

	teleport_window(win, win_x, win_y);
}

void
teleport_window(xcb_window_t win, int16_t x, int16_t y)
{
	uint32_t values[2] = {
		(uint32_t)x,
		(uint32_t)y
	};
	struct client *client;

	if (win == scr->root || win == XCB_NONE)
		return;

	xcb_configure_window(conn, win,
		XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y,
		values);

	client = find_client(&win);
	if (client != NULL) {
		update_frame_geometry(client);
		update_window_status(client);
	}

	xcb_flush(conn);
}
