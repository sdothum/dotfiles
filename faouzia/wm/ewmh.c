// See LICENSE file for copyright and license details.

#include "clients.h"
#include "common.h"
#include "ewmh.h"
#include "focus.h"
#include "helpers.h"
#include "monitor.h"
#include "window.h"

/*
 * Add window to the ewmh client list.
 */

void
add_to_client_list(xcb_window_t win)
{
	xcb_change_property(conn, XCB_PROP_MODE_APPEND, scr->root,
			ewmh->_NET_CLIENT_LIST, XCB_ATOM_WINDOW, 32, 1, &win);
	xcb_change_property(conn, XCB_PROP_MODE_APPEND, scr->root, ewmh->_NET_CLIENT_LIST_STACKING, XCB_ATOM_WINDOW, 32, 1, &win);
}

void
handle_wm_state(struct client *client, xcb_atom_t state, unsigned int action)
{
	int16_t mon_x, mon_y;
	uint16_t mon_w, mon_h;

	get_monitor_size(client, &mon_x, &mon_y, &mon_w, &mon_h);

	if (state == ewmh->_NET_WM_STATE_FULLSCREEN) {
		if (action == XCB_EWMH_WM_STATE_ADD) {
			maximize_window(client, mon_x, mon_y, mon_w, mon_h);
		} else if (action == XCB_EWMH_WM_STATE_REMOVE && client->maxed) {
			reset_window(client);
			set_focused(client);
		} else if (action == XCB_EWMH_WM_STATE_TOGGLE) {
			if (client->maxed) {
				reset_window(client);
				set_focused(client);
			} else {
				maximize_window(client, mon_x, mon_y, mon_w, mon_h);
			}
		}
	} else if (state == ewmh->_NET_WM_STATE_MAXIMIZED_VERT) {
		if (action == XCB_EWMH_WM_STATE_ADD) {
			vmaximize_window(client, mon_y, mon_h);
		} else if (action == XCB_EWMH_WM_STATE_REMOVE) {
			if (client->vmaxed)
				reset_window(client);
		} else if (action == XCB_EWMH_WM_STATE_TOGGLE) {
			if (client->vmaxed)
				reset_window(client);
			else
				vmaximize_window(client, mon_y, mon_h);
		}
	} else if (state == ewmh->_NET_WM_STATE_MAXIMIZED_HORZ) {
		if (action == XCB_EWMH_WM_STATE_ADD) {
			hmaximize_window(client, mon_y, mon_w);
		} else if (action == XCB_EWMH_WM_STATE_REMOVE) {
			if (client->hmaxed)
				reset_window(client);
		} else if (action == XCB_EWMH_WM_STATE_TOGGLE) {
			if (client->hmaxed)
				reset_window(client);
			else
				hmaximize_window(client, mon_x, mon_w);
		}
	}
}

void
update_current_desktop(struct client *client)
{
	if (client != NULL)
		xcb_ewmh_set_current_desktop(ewmh, 0, client->group);
}

/*
 * Update _NET_DESKTOP_VIEWPORT root property.
 */

void
update_desktop_viewport(void)
{
	xcb_ewmh_coordinates_t coord = {0, 0};
	xcb_ewmh_set_desktop_viewport(ewmh, scrno, 1, &coord);
}

void
update_ewmh_wm_state(struct client *client)
{
	int i;
	uint32_t values[12];

	if (client == NULL)
		return;

#define HANDLE_WM_STATE(s)              \
	values[i] = ewmh->_NET_WM_STATE_##s; \
	i++;                                 \
	DMSG("ewmh net_wm_state %s present\n", #s);

	i = 0;
	if (client->maxed) {
		HANDLE_WM_STATE(FULLSCREEN);
	}
	if (client->vmaxed) {
		HANDLE_WM_STATE(MAXIMIZED_VERT);
	}
	if (client->hmaxed) {
		HANDLE_WM_STATE(MAXIMIZED_HORZ);
	}

	xcb_ewmh_set_wm_state(ewmh, client->window, i, values);
}

void
update_window_status(struct client *client)
{
	/* it really shouldn't happen */
	if (client == NULL)
		return;
	int size = 0;
	char *str = NULL;
	char *state;
	if (client->maxed) state = "maxed";
	else if (client->hmaxed) state = "hmaxed";
	else if (client->vmaxed) state = "vmaxed";
	else if (client->monocled) state = "monocled";
	else if (client->gridded) state = "gridded";
	else state = "normal";

	/* this is going to be fun */

#define _BOOL_VALUE(value) ((value) ? "true" : "false")

	size = asprintf(&str,
	"{"
		"\"window\":\"0x%08x\","
		"\"geom\":{"
			"\"x\":%d,"
			"\"y\":%d,"
			"\"width\":%d,"
			"\"height\":%d,"
			"\"set_by_user\":%s"
		"},"
		"\"state\":\"%s\","
		"\"min_width\":%d,"
		"\"min_height\":%d,"
		"\"max_width\":%d,"
		"\"max_height\":%d,"
		"\"width_inc\":%d,"
		"\"height_inc\":%d,"
		"\"mapped\":%s,"
		"\"group\":%d"
	"}", client->window, client->geom.x, client->geom.y, client->geom.width,
	client->geom.height, _BOOL_VALUE(client->geom.set_by_user), state,
	client->min_width, client->min_height, client->max_width, client->max_height,
	client->width_inc, client->height_inc, _BOOL_VALUE(client->mapped), client->group);

#undef _BOOL_VALUE

	if (size == -1) {
		DMSG("asprintf returned -1\n");
		return;
	}
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, client->window,
			ATOMS[FAOUZIA_STATUS], XCB_ATOM_STRING, 8, size, str);
	free(str);
}

void
update_wm_desktop(struct client *client)
{
	if (client != NULL)
		xcb_ewmh_set_wm_desktop(ewmh, client->window, client->group);
}

