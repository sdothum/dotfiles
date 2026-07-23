// See LICENSE file for copyright and license details.

#include <xcb/xcb_icccm.h>

#include "atoms.h"
#include "border.h"
#include "clients.h"
#include "common.h"
#include "events.h"
#include "ewmh.h"
#include "focus.h"
#include "groups.h"
#include "helpers.h"
#include "input.h"
#include "ipc.h"
#include "list.h"
#include "randr.h"
#include "stack.h"
#include "window.h"
#include "wm_state.h"
#include "xutil.h"

void
event_button_press(xcb_generic_event_t *ev)
{
	xcb_button_press_event_t *e = (xcb_button_press_event_t *)ev;
	bool replay = false;

	for (int i = 0; i < NR_BUTTONS; i++) {
		if (e->detail != mouse_buttons[i])
			continue;
		if ((conf.click_to_focus == (int8_t) XCB_BUTTON_INDEX_ANY ||
				conf.click_to_focus == (int8_t) mouse_buttons[i]) &&
				(e->state & ~(num_lock | scroll_lock | caps_lock)) == XCB_NONE) {

			replay = !pointer_grab(POINTER_ACTION_FOCUS);
		} else {
			pointer_grab(conf.pointer_actions[i]);
		}
	}
	xcb_allow_events(conn, replay ? XCB_ALLOW_REPLAY_POINTER : XCB_ALLOW_SYNC_POINTER, e->time);
	xcb_flush(conn);
}

/*
 * Window wants to change its position in the stacking order.
 */

void
event_circulate_request(xcb_generic_event_t *ev)
{
	xcb_circulate_request_event_t *e = (xcb_circulate_request_event_t *)ev;

	xcb_circulate_window(conn, e->window, e->place);
}

/*
 * Received client message. Either ewmh/icccm thing or
 * message from the client.
 */

void
event_client_message(xcb_generic_event_t *ev)
{
	xcb_client_message_event_t *e = (xcb_client_message_event_t *)ev;
	uint32_t ipc_command;
	uint32_t *data;
	struct client *client;

	if (e->type == ATOMS[_IPC_ATOM_COMMAND] && e->format == 32) {
		/* Message from the client */
		data = e->data.data32;
		ipc_command = data[0];
		if (ipc_command < NR_IPC_COMMANDS && ipc_handlers[ipc_command] != NULL)
			(ipc_handlers[ipc_command])(data + 1);
		DMSG("IPC Command %u with arguments %u %u %u\n", ipc_command, data[1], data[2], data[3]);
	} else {
		client = find_client(&e->window);
		if (client == NULL)
			return;
		if (e->type == ewmh->_NET_WM_STATE) {
			DMSG("got _NET_WM_STATE for 0x%08x\n", client->window);
			handle_wm_state(client, e->data.data32[1], e->data.data32[0]);
			handle_wm_state(client, e->data.data32[2], e->data.data32[0]);
		} else if (e->type == ewmh->_NET_ACTIVE_WINDOW) {
			DMSG("got _NET_ACTIVE_WINDOW for 0x%08x\n", client->window);
			set_focused(client);
		}
	}
}

/*
 * Window has been configured.
 */

void
event_configure_notify(xcb_generic_event_t *ev)
{
	xcb_configure_notify_event_t *e = (xcb_configure_notify_event_t *)ev;
	struct client *client;
	struct list_item *item;

	// The root window changes its geometry when the
	// user adds/removes/tilts screens

	if (e->window == scr->root) {
		if (e->width != scr->width_in_pixels
				|| e->height != scr->height_in_pixels) {
			scr->width_in_pixels = e->width;
			scr->height_in_pixels = e->height;

			if (randr_base != -1) {
				get_randr();
				for (item = win_list; item != NULL; item = item->next) {
					client = item->data;
					fit_on_screen(client);
				}
			}
		}
	} else {
		client = find_client(&e->window);
		if (client != NULL) {
			client->monitor = find_monitor_by_coord(client->geom.x, client->geom.y);
			update_current_desktop(client);
		}
	}
}

void
event_configure_request(xcb_generic_event_t *ev)
{
	xcb_configure_request_event_t *e = (xcb_configure_request_event_t *)ev;
	struct client *client;
	uint32_t values[7];
	int i = 0;
	uint16_t mask = 0;

	client = find_client(&e->window);
	if (client == NULL && find_client_by_frame(e->window) != NULL)
		return;

	if (client != NULL) {

		if (e->value_mask & XCB_CONFIG_WINDOW_X
				&& !client->maxed && !client->monocled && !client->hmaxed)
			client->geom.x = e->x;

		if (e->value_mask & XCB_CONFIG_WINDOW_Y
				&& !client->maxed && !client->monocled && !client->vmaxed)
			client->geom.y = e->y;

		if (e->value_mask & XCB_CONFIG_WINDOW_WIDTH
				&& !client->maxed && !client->monocled && !client->hmaxed)
			client->geom.width = e->width;

		if (e->value_mask & XCB_CONFIG_WINDOW_HEIGHT
				&& !client->maxed && !client->monocled && !client->vmaxed)
			client->geom.height = e->height;

		if (e->value_mask & XCB_CONFIG_WINDOW_STACK_MODE) {
			values[0] = e->stack_mode;
			xcb_configure_window(conn, e->window,
					XCB_CONFIG_WINDOW_STACK_MODE, values);
		}

		// if (e->value_mask & XCB_CONFIG_WINDOW_BORDER_WIDTH) {
		// 	values[0] = e->border_width;
		// 	xcb_configure_window(conn, e->window,
		// 			XCB_CONFIG_WINDOW_BORDER_WIDTH, values);
		// }

		if (!client->maxed) {
			fit_on_screen(client);
		}

		teleport_window(client->window, client->geom.x, client->geom.y);
		resize_window_absolute(client->window, client->geom.width, client->geom.height);
	} else {
		if (e->value_mask & XCB_CONFIG_WINDOW_X) {
			mask |= XCB_CONFIG_WINDOW_X;
			values[i++] = (uint32_t)e->x;
		}

		if (e->value_mask & XCB_CONFIG_WINDOW_Y) {
			mask |= XCB_CONFIG_WINDOW_Y;
			values[i++] = (uint32_t)e->y;
		}

		if (e->value_mask & XCB_CONFIG_WINDOW_WIDTH) {
			mask |= XCB_CONFIG_WINDOW_WIDTH;
			values[i++] = u32_from_i32(e->width);
		}

		if (e->value_mask & XCB_CONFIG_WINDOW_HEIGHT) {
			mask |= XCB_CONFIG_WINDOW_HEIGHT;
			values[i++] = u32_from_i32(e->height);
		}

		if (e->value_mask & XCB_CONFIG_WINDOW_SIBLING) {
			mask |= XCB_CONFIG_WINDOW_SIBLING;
			values[i] = e->sibling;
			i++;
		}

		if (e->value_mask & XCB_CONFIG_WINDOW_STACK_MODE) {
			mask |= XCB_CONFIG_WINDOW_STACK_MODE;
			values[i] = e->stack_mode;
			i++;
		}

		if (i == 0)
			return;
		xcb_configure_window(conn, e->window, mask, values);
	}
}

/*
 * Window has been destroyed.
 */

void
event_destroy_notify(xcb_generic_event_t *ev)
{
	struct client *client;
	xcb_destroy_notify_event_t *e = (xcb_destroy_notify_event_t *)ev;

	client = find_client(&e->window);
	if (conf.last_window_focusing && focused_win != NULL && focused_win == client) {
		focused_win = NULL;
		set_focused_last_best();
	}

	if (client != NULL) {
		free_window(client);
	}


	update_client_list();
	update_group_list();
}

/*
 * The mouse pointer has entered the window.
 */

void
event_enter_notify(xcb_generic_event_t *ev)
{
	xcb_enter_notify_event_t *e = (xcb_enter_notify_event_t *)ev;
	struct client *client;

	if (conf.sloppy_focus == false)
		return;

	if (focused_win != NULL && e->event == focused_win->window)
		return;

	client = find_client(&e->event);

	if (client != NULL)
		set_focused_no_raise(client);
}

void
event_focus_in(xcb_generic_event_t *ev)
{
	xcb_focus_in_event_t *e = (xcb_focus_in_event_t *)ev;
	xcb_window_t win = e->event;
	struct client *client = find_client(&win);

	if (client != NULL)
		update_current_desktop(client);
}

void
event_focus_out(xcb_generic_event_t *ev)
{
	(void)(ev);
	xcb_get_input_focus_reply_t *focus = xcb_get_input_focus_reply(conn,
			xcb_get_input_focus(conn), NULL);
	struct client *client = NULL;

	if (focused_win != NULL && focus->focus == focused_win->window)
		return;

	if (focus->focus == scr->root) {
		focused_win = NULL;
	} else {
		client = find_client(&focus->focus);
		if (client != NULL)
			set_focused_no_raise(client);
	}
}

void
event_map_notify(xcb_generic_event_t *ev)
{
	xcb_map_notify_event_t *e = (xcb_map_notify_event_t *)ev;
	struct client *client = find_client(&e->window);

	if (client != NULL) {
		client->mapped = true;
		set_focused(client);
		update_window_status(client);
	}
}

/*
 * A window wants to show up on the screen.
 */

void
event_map_request(xcb_generic_event_t *ev)
{
	xcb_map_request_event_t *e = (xcb_map_request_event_t *)ev;
	struct client *client;
	long data[] = {
		XCB_ICCCM_WM_STATE_NORMAL,
		XCB_NONE,
	};

	/* create window if new */
	client = find_client(&e->window);
	if (client == NULL) {
		client = setup_window(e->window);

		/* client is a dock or some kind of window that needs to be ignored */
		if (client == NULL)
			return;

		if (!client->geom.set_by_user) {
			if (!get_pointer_location(&scr->root, &client->geom.x, &client->geom.y))
				client->geom.x = client->geom.y = 0;

			client->geom.x -= client->geom.width / 2;
			client->geom.y -= client->geom.height / 2;
			teleport_window(client->window, client->geom.x, client->geom.y);
		}
		if (conf.sticky_windows)
			group_add_window(client, last_group);
	}

	if (client != NULL && client->frame != XCB_NONE)
		xcb_map_window(conn, client->frame);

	xcb_map_window(conn, e->window);

	/* in case of fire, abort */
	if (client == NULL)
		return;

	if (randr_base != -1) {
		client->monitor = find_monitor_by_coord(client->geom.x, client->geom.y);
		if (client->monitor == NULL && mon_list != NULL)
			client->monitor = mon_list->data;
	}

	fit_on_screen(client);

	if (client->frame == XCB_NONE)
		create_frame(client);

if (client->frame != XCB_NONE) {
	xcb_map_window(conn, client->frame);
	paint_frame(client, conf.focus_color, conf.internal_focus_color);
}
	/* window is normal */
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, client->window,
			ewmh->_NET_WM_STATE, ewmh->_NET_WM_STATE, 32, 2, data);

	center_pointer(client);
	update_client_list();

	if (!client->maxed)
		set_borders(client, conf.focus_color, conf.internal_focus_color);
	update_current_desktop(client);
}

/*
 * Window has been unmapped (became invisible).
 */

void
event_unmap_notify(xcb_generic_event_t *ev)
{
	xcb_map_request_event_t *e = (xcb_map_request_event_t *)ev;

	if (find_client_by_frame(e->window) != NULL)
		return;

	struct client *client = NULL;

	client = find_client(&e->window);
	if (client == NULL)
		return;

	if (client->frame != XCB_NONE)
		xcb_unmap_window(conn, client->frame);

	client->mapped = false;

	if (conf.last_window_focusing && focused_win != NULL && client->window == focused_win->window) {
		focused_win = NULL;
		set_focused_last_best();
	}

	update_client_list();
	update_window_status(client);
}
