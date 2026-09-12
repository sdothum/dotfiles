// See LICENSE file for copyright and license details.

#include <xcb/xcb_icccm.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
trace_x_event(xcb_generic_event_t *ev)
{
	const char *enabled = getenv("CIRRUS_TRACE_STACK");
	uint8_t type;

	if (enabled == NULL || enabled[0] == '\0' || strcmp(enabled, "0") == 0)
		return;
	type = ev->response_type & ~0x80;
	switch (type) {
	case XCB_ENTER_NOTIFY: {
		xcb_enter_notify_event_t *e = (xcb_enter_notify_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u EnterNotify event=0x%08x child=0x%08x mode=%u detail=%u root=(%d,%d) event=(%d,%d)\n",
			ev->full_sequence, e->event, e->child, e->mode, e->detail,
			e->root_x, e->root_y, e->event_x, e->event_y);
		break;
	}
	case XCB_LEAVE_NOTIFY: {
		xcb_leave_notify_event_t *e = (xcb_leave_notify_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u LeaveNotify event=0x%08x child=0x%08x mode=%u detail=%u root=(%d,%d) event=(%d,%d)\n",
			ev->full_sequence, e->event, e->child, e->mode, e->detail,
			e->root_x, e->root_y, e->event_x, e->event_y);
		break;
	}
	case XCB_FOCUS_IN: {
		xcb_focus_in_event_t *e = (xcb_focus_in_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u FocusIn event=0x%08x mode=%u detail=%u\n",
			ev->full_sequence, e->event, e->mode, e->detail);
		break;
	}
	case XCB_FOCUS_OUT: {
		xcb_focus_out_event_t *e = (xcb_focus_out_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u FocusOut event=0x%08x mode=%u detail=%u\n",
			ev->full_sequence, e->event, e->mode, e->detail);
		break;
	}
	case XCB_CONFIGURE_NOTIFY: {
		xcb_configure_notify_event_t *e = (xcb_configure_notify_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u ConfigureNotify window=0x%08x above=0x%08x geometry=(%d,%d %ux%u)\n",
			ev->full_sequence, e->window, e->above_sibling, e->x, e->y,
			e->width, e->height);
		break;
	}
	case XCB_CONFIGURE_REQUEST: {
		xcb_configure_request_event_t *e = (xcb_configure_request_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u ConfigureRequest window=0x%08x sibling=0x%08x mode=%u mask=0x%x\n",
			ev->full_sequence, e->window, e->sibling, e->stack_mode,
			e->value_mask);
		break;
	}
	case XCB_MAP_NOTIFY: {
		xcb_map_notify_event_t *e = (xcb_map_notify_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u MapNotify window=0x%08x\n", ev->full_sequence, e->window);
		break;
	}
	case XCB_UNMAP_NOTIFY: {
		xcb_unmap_notify_event_t *e = (xcb_unmap_notify_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u UnmapNotify window=0x%08x\n", ev->full_sequence, e->window);
		break;
	}
	case XCB_CLIENT_MESSAGE: {
		xcb_client_message_event_t *e = (xcb_client_message_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u ClientMessage window=0x%08x type=0x%08x\n", ev->full_sequence, e->window, e->type);
		break;
	}
	case XCB_PROPERTY_NOTIFY: {
		xcb_property_notify_event_t *e = (xcb_property_notify_event_t *)ev;
		fprintf(stderr, "EVENT seq=%u PropertyNotify window=0x%08x atom=0x%08x state=%u\n", ev->full_sequence, e->window, e->atom, e->state);
		break;
	}
	default:
		break;
	}
}

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

	circulate_window_stacking(e->window, e->place);
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
		if (client == NULL) {
			if (e->type == ewmh->_NET_WM_STATE && e->format == 32 && e->window != scr->root) {
				handle_unmanaged_wm_state(e->window, e->data.data32[1], e->data.data32[0]);
				handle_unmanaged_wm_state(e->window, e->data.data32[2], e->data.data32[0]);
				enforce_stacking_layers();
			}
			return;
		}
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
		if (client == NULL && e->override_redirect && find_client_by_frame(e->window) == NULL)
			enforce_stacking_layers();
		if (client != NULL) {
			client->monitor = find_monitor_by_coord(client->geom.x, client->geom.y);
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
			configure_window_stacking(conn, e->window,
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
		configure_window_stacking(conn, e->window, mask, values);
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
	bool was_focused = client != NULL && focused_win == client;
	if (was_focused)
		clear_focused();

	if (client != NULL) {
		free_window(client);
	}
	if (was_focused && conf.last_window_focusing)
		set_focused_last_best();


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
	if (suppress_explicit_geometry_enter(ev, e))
		return;

	client = find_client_from_window(e->event);
	trace_restart("EnterNotify event=0x%08x child=0x%08x mode=%u detail=%u resolved=0x%08x focused=0x%08x",
			e->event, e->child, e->mode, e->detail,
			client == NULL ? XCB_NONE : client->window,
			focused_win == NULL ? XCB_NONE : focused_win->window);
	if (client != NULL && focused_win != NULL && client == focused_win)
		return;

	if (client != NULL)
		set_focused_no_raise(client);
}

void
event_focus_in(xcb_generic_event_t *ev)
{
	(void)(ev);
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
		clear_focused();
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
	refresh_window_layer(client);
	enforce_stacking_layers();
	trace_restart("MapNotify xid=0x%08x resolved=%d", e->window,
			client != NULL);

	if (client != NULL) {
		bool was_mapped = client->mapped;
		client->mapped = true;
		if (client->group_map_pending)
			client->group_map_pending = false;
		else
			set_focused(client);
		update_window_status(client);
		if (!was_mapped)
			invalidate_snapshot_state();
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
	uint32_t data[] = {
		XCB_ICCCM_WM_STATE_NORMAL,
		XCB_NONE,
	};

	/* create window if new */
	trace_restart("MapRequest xid=0x%08x existing=%d", e->window,
			find_client(&e->window) != NULL);
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
		if (conf.sticky_windows) {
			group_add_window(client, last_group);
		} else {
			uint32_t group = conf.groups > 1 ? 1 : NULL_GROUP;

			if (focused_win != NULL && focused_win->group != NULL_GROUP &&
					focused_win->group < conf.groups)
				group = focused_win->group;
			group_add_window(client, group);
		}
	}

	if (client != NULL && client->frame != XCB_NONE) {
		trace_restart("map frame via MapRequest frame=0x%08x client=0x%08x",
				client->frame, client->window);
		map_window_stacking(conn, client->frame);
	}

	trace_restart("map client via MapRequest xid=0x%08x", e->window);
	map_window_stacking(conn, e->window);

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
	trace_restart("map frame via MapRequest completion frame=0x%08x client=0x%08x",
			client->frame, client->window);
	map_window_stacking(conn, client->frame);
	paint_frame(client, conf.outer_focus_color, conf.inner_focus_color);
}
	/* window is normal */
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, client->window,
			ATOMS[ICCCM_WM_STATE], ATOMS[ICCCM_WM_STATE], 32, 2, data);

	center_pointer(client);
	update_client_list();

	if (!client->maxed)
		set_borders(client, conf.outer_focus_color, conf.inner_focus_color);
}

/*
 * Window has been unmapped (became invisible).
 */

void
event_unmap_notify(xcb_generic_event_t *ev)
{
	xcb_map_request_event_t *e = (xcb_map_request_event_t *)ev;
	trace_restart("UnmapNotify xid=0x%08x", e->window);

	if (find_client_by_frame(e->window) != NULL)
		return;

	struct client *client = NULL;

	client = find_client(&e->window);
	if (client == NULL)
		return;

	if (client->frame != XCB_NONE) {
		trace_restart("unmap frame via UnmapNotify frame=0x%08x client=0x%08x",
				client->frame, client->window);
		xcb_unmap_window(conn, client->frame);
	}

	bool was_mapped = client->mapped;
	client->mapped = false;

	bool group_unmap_pending = client->group_unmap_pending;
	bool was_focused = focused_win == client;
	if (was_focused)
		clear_focused();

	if (group_unmap_pending) {
		client->group_unmap_pending = false;
	} else if (was_focused && conf.last_window_focusing) {
		set_focused_last_best();
	}

	update_client_list();
	update_window_status(client);
	if (was_mapped)
		invalidate_snapshot_state();
}

void
event_property_notify(xcb_generic_event_t *ev)
{
	xcb_property_notify_event_t *e = (xcb_property_notify_event_t *)ev;
	if (e->window == scr->root || (e->atom != ewmh->_NET_WM_STATE &&
			e->atom != ewmh->_NET_WM_WINDOW_TYPE))
		return;
	refresh_window_layer(find_client(&e->window));
	enforce_stacking_layers();
}
