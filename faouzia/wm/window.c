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
		focused_win = NULL;

	xcb_window_t win = client->window;
	xcb_get_property_cookie_t cookie =
		xcb_icccm_get_wm_protocols_unchecked(conn,
				win, ewmh->WM_PROTOCOLS);
	xcb_icccm_get_wm_protocols_reply_t reply;
	unsigned int i = 0;
	bool got = false;

	if (xcb_icccm_get_wm_protocols_reply(conn, cookie, &reply, NULL)) {
		for (i = 0; i < reply.atoms_len; i++) {
			got = (reply.atoms[i] = ATOMS[WM_DELETE_WINDOW]);
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
	if (client->frame != XCB_NONE)
		xcb_unmap_window(conn, client->frame);

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
		client->geom.x = mon_x;
		client->geom.y = mon_y;
		client->geom.width -= 2 * border_extent();
		client->geom.height -= 2 * border_extent();
		maximize_window(client, mon_x, mon_y, mon_width, mon_height);
		return;
	}

	/* Is it outside the display? */
	if (client->geom.x > mon_x + mon_width || client->geom.y > mon_y + mon_height
			|| client->geom.x < mon_x || client->geom.y < mon_y) {
		will_move = true;
		if (client->geom.x > mon_x + mon_width)
			client->geom.x = mon_x + mon_width - client->geom.width - 2 * border_extent();
		else if (client->geom.x < mon_x)
			client->geom.x = mon_x;
		if (client->geom.y > mon_y + mon_height)
			client->geom.y = mon_y + mon_height - client->geom.height - 2 * border_extent();
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
	if (client->geom.width + 2 * border_extent() > mon_width) {
		client->geom.x = mon_x;
		client->geom.width = mon_width - 2 * border_extent();
		will_move = will_resize = true;
	} else if (client->geom.x + client->geom.width + 2 * border_extent()
			> mon_x + mon_width) {
		client->geom.x = mon_x + mon_width - client->geom.width - 2 * border_extent();
		will_move = true;
	}

	if (client->geom.height + 2 * border_extent() > mon_height) {
		client->geom.y = mon_y;
		client->geom.height = mon_height - 2 * border_extent();
		will_move = will_resize = true;
	} else if (client->geom.y + client->geom.height + 2 * border_extent()
			> mon_y + mon_height) {
		client->geom.y = mon_y + mon_height - client->geom.height - 2 * border_extent();
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
	if (client->geom.width != mon_width || client->geom.height != mon_height)
		client->orig_geom = client->geom;
	xcb_configure_window(conn, client->window, XCB_CONFIG_WINDOW_BORDER_WIDTH,
			values);

	client->geom.x = mon_x;
	client->geom.y = mon_y;
	// client->geom.width = mon_width - 2 * border_extent();
	// client->geom.height = mon_height - 2 * border_extent();
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

	if (client->geom.width != mon_width)
		client->orig_geom = client->geom;
	client->geom.x = mon_x + conf.gap_left;
	client->geom.width = mon_width - conf.gap_left - conf.gap_right - 2 * border_extent();

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

	if (client->geom.height != mon_height)
		client->orig_geom = client->geom;

	client->geom.y = mon_y + conf.gap_up;
	client->geom.height = mon_height - conf.gap_up - conf.gap_down - 2 * border_extent();

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
	client->geom.width = mon_width - 2 * border_extent()
		- conf.gap_left - conf.gap_right;
	client->geom.height = mon_height - 2 * border_extent()
		- conf.gap_up - conf.gap_down;
	teleport_window(client->window, client->geom.x, client->geom.y);
	resize_window_absolute(client->window, client->geom.width, client->geom.height);
	client->monocled = true;
	set_focused_no_raise(client);

	update_ewmh_wm_state(client);
	update_window_status(client);
}

void
resize_grid_window(struct client *client, uint16_t x, uint16_t y)
{

	int16_t new_sx, new_sy;

	new_sx = client->grid.sx + x;
	new_sy = client->grid.sy + y;

	if (!client->gridded
			|| client->grid.gx < new_sx + client->grid.px
			|| client->grid.gy < new_sy + client->grid.py
			|| new_sx < 1
			|| new_sy < 1)
		return;

	grid_window(client, client->grid.gx, client->grid.gy, client->grid.px, client->grid.py, new_sx, new_sy);
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
 * Put window in grid.
 */

void
grid_window(struct client *client, uint16_t grid_width, uint16_t grid_height, uint16_t grid_x, uint16_t grid_y, uint16_t occ_w, uint16_t occ_h)
{
	int16_t mon_x, mon_y;
	uint16_t base_w, base_h;
	uint16_t new_w, new_h;
	uint16_t mon_w, mon_h;

	if (client == NULL || grid_x >= grid_width || grid_y >= grid_height)
		return;

	DMSG("Gridding window in grid of size (%d, %d) pos (%d, %d) window size (%d, %d)\n", grid_width, grid_height, grid_x, grid_y, occ_w, occ_h);
	if (is_special(client)) {
		reset_window(client);
		set_focused(client);
	}

	get_monitor_size(client, &mon_x, &mon_y, &mon_w, &mon_h);

	base_w = (mon_w - conf.gap_left - conf.gap_right - (grid_width - 1) * conf.grid_gap
			- grid_width * 2 * border_extent()) / grid_width;
	base_h = (mon_h - conf.gap_up - conf.gap_down - (grid_height - 1) * conf.grid_gap
			- grid_height * 2 * border_extent()) / grid_height;
	/* calculate new window size */
	new_w = base_w * occ_w + (occ_w - 1) * (conf.grid_gap + 2 * border_extent());

	new_h = base_h * occ_h + (occ_h - 1) * (conf.grid_gap + 2 * border_extent());

	client->orig_geom = client->geom;

	client->geom.width = new_w;
	client->geom.height = new_h;

	// client->geom.x = mon_x + conf.gap_left + grid_x
	// 	* (conf.border_width + base_w + conf.border_width + conf.grid_gap);
	// client->geom.y = mon_y + conf.gap_up + grid_y
	// 	* (conf.border_width + base_h + conf.border_width + conf.grid_gap);
	client->geom.x = mon_x + conf.gap_left + grid_x
			* (2 * border_extent() + base_w + conf.grid_gap);
	client->geom.y = mon_y + conf.gap_up + grid_y
			* (2 * border_extent() + base_h + conf.grid_gap);

	client->gridded = true;
	client->grid.gx = grid_width;
	client->grid.gy = grid_height;
	client->grid.px = grid_x;
	client->grid.py = grid_y;
	client->grid.sx = occ_w;
	client->grid.sy = occ_h;

	DMSG("w: %d\th: %d\n", new_w, new_h);

	teleport_window(client->window, client->geom.x, client->geom.y);
	resize_window_absolute(client->window, client->geom.width, client->geom.height);

	xcb_flush(conn);
}

void
move_grid_window(struct client *client, uint16_t x, uint16_t y)
{

	int16_t new_px, new_py;

	new_px = client->grid.px + x;
	new_py = client->grid.py + y;

	if (!client->gridded
			|| client->grid.gx < new_px + client->grid.sx
			|| client->grid.gy < new_py + client->grid.sy
			|| new_px < 0
			|| new_py < 0)
		return;

	grid_window(client, client->grid.gx, client->grid.gy, new_px, new_py, client->grid.sx, client->grid.sy);
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

/*
 * Snap window in corner.
 */

void
snap_window(struct client *client, enum position pos)
{
	int16_t mon_x, mon_y, win_x, win_y;
	uint16_t mon_w, mon_h, win_w, win_h;

	if (client == NULL)
		return;

	if (is_special(client)) {
		reset_window(client);
		set_focused(client);
	}

	fit_on_screen(client);

	win_x = client->geom.x;
	win_y = client->geom.y;
	win_w = client->geom.width + 2 * border_extent();
	win_h = client->geom.height + 2 * border_extent();

	get_monitor_size(client, &mon_x, &mon_y, &mon_w, &mon_h);

	switch (pos) {
		case TOP_LEFT:
			win_x = mon_x + conf.gap_left;
			win_y = mon_y + conf.gap_up;
			break;

		case TOP_RIGHT:
			win_x = mon_x + mon_w - conf.gap_right - win_w;
			win_y = mon_y + conf.gap_up;
			break;

		case BOTTOM_LEFT:
			win_x = mon_x + conf.gap_left;
			win_y = mon_y + mon_h - conf.gap_down - win_h;
			break;

		case BOTTOM_RIGHT:
			win_x = mon_x + mon_w - conf.gap_right - win_w;
			win_y = mon_y + mon_h - conf.gap_down - win_h;
			break;

		case CENTER:
			win_x = mon_x + (mon_w - win_w) / 2;
			win_y = mon_y + (mon_h - win_h) / 2;
			break;

		default:
			return;
	}

	client->geom.x = win_x;
	client->geom.y = win_y;
	teleport_window(client->window, win_x, win_y);
	center_pointer(client);
	xcb_flush(conn);
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

