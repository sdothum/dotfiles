// See LICENSE file for copyright and license details.

#include <X11/keysym.h>
#include <xcb/xcb_keysyms.h>

#include "clients.h"
#include "common.h"
#include "focus.h"
#include "input.h"
#include "types.h"
#include "window.h"
#include "wm_state.h"

static enum resize_handle
get_handle(struct client *client, xcb_point_t pos, enum pointer_action pac)
{
	if (client == NULL)
		return pac == POINTER_ACTION_RESIZE_SIDE ? HANDLE_LEFT : HANDLE_TOP_LEFT;

	enum resize_handle handle;
	struct window_geom geom = client->geom;

	if (pac == POINTER_ACTION_RESIZE_SIDE) {
		/* coordinates relative to the window */
		int16_t x = pos.x - geom.x;
		int16_t y = pos.y - geom.y;
		bool left_of_a = (x * geom.height) < (geom.width * y);
		bool left_of_b = ((geom.width - x) * geom.height) > (geom.width * y);

		// Problem is that the above algorithm works in a 2d system
		// where the origin is in the bottom-left.
		if (left_of_a) {
			if (left_of_b) {
				handle = HANDLE_LEFT;
			}
			else
				handle = HANDLE_BOTTOM;
		} else {
			if (left_of_b)
				handle = HANDLE_TOP;
			else
				handle = HANDLE_RIGHT;
		}
	} else if (pac == POINTER_ACTION_RESIZE_CORNER) {
		int16_t mid_x = geom.x + geom.width / 2;
		int16_t mid_y = geom.y + geom.height / 2;

		if (pos.y < mid_y) {
			if (pos.x < mid_x)
				handle = HANDLE_TOP_LEFT;
			else
				handle = HANDLE_TOP_RIGHT;
		} else {
			if (pos.x < mid_x)
				handle = HANDLE_BOTTOM_LEFT;
			else
				handle = HANDLE_BOTTOM_RIGHT;
		}
	} else {
		handle = HANDLE_TOP_LEFT;
	}

	return handle;
}

void
grab_buttons(void)
{
	struct list_item *item;
	struct client *client;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		window_grab_buttons(client->window);
	}
}

void
ungrab_buttons(void)
{
	struct list_item *item;
	struct client *client;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		xcb_ungrab_button(conn, XCB_BUTTON_INDEX_ANY, client->window, XCB_MOD_MASK_ANY);
	}
}

void
window_grab_buttons(xcb_window_t win)
{
	for (int i = 0; i < NR_BUTTONS; i++) {
		if (conf.click_to_focus == (int8_t) XCB_BUTTON_INDEX_ANY ||
			conf.click_to_focus == (int8_t) mouse_buttons[i])
			window_grab_button(win, mouse_buttons[i], XCB_NONE);
		if (conf.pointer_actions[i] != POINTER_ACTION_NOTHING)
			window_grab_button(win, mouse_buttons[i], conf.pointer_modifier);
	}
	DMSG("grabbed buttons on 0x%08x\n", win);
}

void
window_grab_button(xcb_window_t win, uint8_t button, uint16_t modifier)
{
#define GRAB(b, m)                                                \
	xcb_grab_button(conn, false, win, XCB_EVENT_MASK_BUTTON_PRESS, \
			XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC, XCB_NONE, XCB_NONE, b, m)

	GRAB(button, modifier);
	if (num_lock != XCB_NO_SYMBOL && caps_lock != XCB_NO_SYMBOL && scroll_lock != XCB_NO_SYMBOL)
		GRAB(button, modifier | num_lock | caps_lock | scroll_lock);
	if (num_lock != XCB_NO_SYMBOL && caps_lock != XCB_NO_SYMBOL)
		GRAB(button, modifier | num_lock | caps_lock);
	if (caps_lock != XCB_NO_SYMBOL && scroll_lock != XCB_NO_SYMBOL)
		GRAB(button, modifier | caps_lock | scroll_lock);
	if (num_lock != XCB_NO_SYMBOL && scroll_lock != XCB_NO_SYMBOL)
		GRAB(button, modifier | num_lock | scroll_lock);
	if (num_lock != XCB_NO_SYMBOL)
		GRAB(button, modifier | num_lock);
	if (caps_lock != XCB_NO_SYMBOL)
		GRAB(button, modifier | caps_lock);
	if (scroll_lock != XCB_NO_SYMBOL)
		GRAB(button, modifier | scroll_lock);
}

/*
 * Get the mouse pointer's coordinates.
 */

bool
get_pointer_location(xcb_window_t *win, int16_t *x, int16_t *y)
{
	xcb_query_pointer_reply_t *pointer;

	pointer = xcb_query_pointer_reply(conn,
			xcb_query_pointer(conn, *win), 0);

	*x = pointer->win_x;
	*y = pointer->win_y;

	free(pointer);

	return pointer != NULL;
}

/*
 * Returns true if pointer needs to be synced.
 */

bool
pointer_grab(enum pointer_action pac)
{
	xcb_window_t win = XCB_NONE;
	xcb_point_t pos = (xcb_point_t) {0, 0};
	struct client *client;

	xcb_query_pointer_reply_t *qr =
		xcb_query_pointer_reply(conn, xcb_query_pointer(conn, scr->root), NULL);

	if (qr == NULL) {
		return false;
	}

	win = qr->child;
	pos = (xcb_point_t) {qr->root_x, qr->root_y};
	free(qr);

	client = find_client(&win);
	if (client == NULL)
		return true;

	raise_window(client->window);
	if (pac == POINTER_ACTION_FOCUS) {
		DMSG("grabbing pointer to focus on 0x%08x\n", client->window);
		if (client != focused_win) {
			set_focused(client);
			if (!conf.replay_click_on_focus)
				return true;
		}
		return false;
	}

	if (is_special(client)) {
		return true;
	}

	xcb_grab_pointer_reply_t *reply =
		xcb_grab_pointer_reply(conn, xcb_grab_pointer(conn, 0, scr->root, XCB_EVENT_MASK_BUTTON_RELEASE | XCB_EVENT_MASK_BUTTON_MOTION, XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC, XCB_NONE, XCB_NONE, XCB_CURRENT_TIME), NULL);

	if (reply == NULL || reply->status != XCB_GRAB_STATUS_SUCCESS) {
		free(reply);
		return true;
	}
	free(reply);

	track_pointer(client, pac, pos);

	return true;
}

void
pointer_init(void)
{
	num_lock = pointer_modfield_from_keysym(XK_Num_Lock);
	caps_lock = pointer_modfield_from_keysym(XK_Caps_Lock);
	scroll_lock = pointer_modfield_from_keysym(XK_Scroll_Lock);

	if (caps_lock == XCB_NO_SYMBOL)
		caps_lock = XCB_MOD_MASK_LOCK;
}

int16_t
pointer_modfield_from_keysym(xcb_keysym_t keysym)
{
	uint16_t modfield = 0;
	xcb_keycode_t *keycodes = NULL, *mod_keycodes = NULL;
	xcb_get_modifier_mapping_reply_t *reply = NULL;
	xcb_key_symbols_t *symbols = xcb_key_symbols_alloc(conn);

	/* wrapped all of them in an ugly if to prevent getting values when we don't need them */
	if (!((keycodes = xcb_key_symbols_get_keycode(symbols, keysym)) == NULL ||
		  (reply = xcb_get_modifier_mapping_reply(conn, xcb_get_modifier_mapping(conn), NULL)) == NULL ||
		  reply->keycodes_per_modifier < 1 ||
		  (mod_keycodes = xcb_get_modifier_mapping_keycodes(reply)) == NULL)) {

		int num_mod =
			xcb_get_modifier_mapping_keycodes_length(reply) /
			reply->keycodes_per_modifier;

		for (int i = 0; i < num_mod; i++) {
			for (int j = 0; j < reply->keycodes_per_modifier; j++) {
				xcb_keycode_t mk = mod_keycodes[i * reply->keycodes_per_modifier + j];
				if (mk != XCB_NO_SYMBOL) {
					for (xcb_keycode_t *k = keycodes; *k != XCB_NO_SYMBOL; k++) {
						if (*k == mk)
							modfield |= (1 << i);
					}
				}
			}
		}
	}

	xcb_key_symbols_free(symbols);
	free(keycodes);
	free(reply);
	return modfield;
}

void
track_pointer(struct client *client, enum pointer_action pac, xcb_point_t pos)
{
	enum resize_handle handle = get_handle(client, pos, pac);
	struct window_geom geom = client->geom;

	xcb_generic_event_t *ev = NULL;

	bool grabbing = true;
	struct client *grabbed = client;

	if (client == NULL)
		return;

	do {
		free(ev);
		while ((ev = xcb_wait_for_event(conn)) == NULL)
			xcb_flush(conn);
		uint8_t resp = EVENT_MASK(ev->response_type);

		if (resp == XCB_MOTION_NOTIFY) {
			xcb_motion_notify_event_t *e = (xcb_motion_notify_event_t *)ev;
			DMSG("tracking window by mouse root_x = %d  root_y = %d  posx = %d  posy = %d\n", e->root_x, e->root_y, pos.x, pos.y);
			int16_t dx = e->root_x - pos.x;
			int16_t dy = e->root_y - pos.y;
			int32_t x = client->geom.x, y = client->geom.y,
				width = client->geom.width, height = client->geom.height;

			if (pac == POINTER_ACTION_MOVE) {
				client->geom.x = geom.x + dx;
				client->geom.y = geom.y + dy;
				teleport_window(client->window, client->geom.x, client->geom.y);
			} else if (pac == POINTER_ACTION_RESIZE_SIDE || pac == POINTER_ACTION_RESIZE_CORNER) {

				DMSG("dx: %d\tdy: %d\n", dx, dy);
				if (conf.resize_hints) {
					dx /= client->width_inc;
					dx *= client->width_inc;

					dy /= client->width_inc;
					dy *= client->width_inc;
					DMSG("we have resize hints\tdx: %d\tdy: %d\n", dx, dy);
				}
				/* oh boy */
				switch (handle) {
				case HANDLE_LEFT:
					x = geom.x + dx;
					width = geom.width - dx;
					break;
				case HANDLE_BOTTOM:
					height  = geom.height + dy;
					break;
				case HANDLE_TOP:
					y = geom.y + dy;
					height = geom.height - dy;
					break;
				case HANDLE_RIGHT:
					width = geom.width + dx;
					break;

				case HANDLE_TOP_LEFT:
					y = geom.y + dy;
					height = geom.height - dy;
					x = geom.x + dx;
					width = geom.width - dx;
					break;
				case HANDLE_TOP_RIGHT:
					y = geom.y + dy;
					height = geom.height - dy;
					width = geom.width + dx;
					break;
				case HANDLE_BOTTOM_LEFT:
					x = geom.x + dx;
					width = geom.width - dx;
					height = geom.height + dy;
					break;
				case HANDLE_BOTTOM_RIGHT:
					width = geom.width + dx;
					height = geom.height + dy;
					break;
				}

				/* check for overflow */
				if (width < client->min_width) {
					width = client->min_width;
					x = client->geom.x;
				}

				if (height < client->min_height) {
					height = client->min_height;
					y = client->geom.y;
				}

				DMSG("moving by %d %d\n", x - geom.x, y - geom.y);
				DMSG("resizing by %d %d\n", width - geom.width, height - geom.height);
				client->geom.x = x;
				client->geom.width = width;
				client->geom.height = height;
				client->geom.y = y;

				resize_window_absolute(client->window, client->geom.width, client->geom.height);
				teleport_window(client->window, client->geom.x, client->geom.y);
				xcb_flush(conn);
			}
		} else if (resp == XCB_BUTTON_RELEASE) {

			grabbing = false;
		} else {
			if (events[resp] != NULL)
				(events[resp])(ev);
		}
	} while (grabbing && grabbed != NULL);
	free(ev);

	xcb_ungrab_pointer(conn, XCB_CURRENT_TIME);
}

