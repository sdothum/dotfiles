// See LICENSE file for copyright and license details.

#include "clients.h"
#include "stack.h"
#include "atoms.h"
#include "common.h"
#include "ewmh.h"
#include "focus.h"
#include "helpers.h"
#include "monitor.h"
#include "window.h"

static uint32_t snapshot_invalidation;

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

	if (state == ewmh->_NET_WM_STATE_ABOVE) {
		/* An explicit assignment owns the tier until this client is unmanaged. */
		if (client->layer_explicit)
			return;
		switch (action) {
		case XCB_EWMH_WM_STATE_ADD:
			set_window_layer(client, LayerAbove, false);
			break;
		case XCB_EWMH_WM_STATE_REMOVE:
			set_window_layer(client, window_has_ewmh_atom(client->window,
					ewmh->_NET_WM_WINDOW_TYPE, ewmh->_NET_WM_WINDOW_TYPE_DOCK) ?
					LayerAbove : LayerNormal, false);
			break;
		case XCB_EWMH_WM_STATE_TOGGLE:
			set_window_layer(client, client->layer == LayerAbove &&
					!window_has_ewmh_atom(client->window, ewmh->_NET_WM_WINDOW_TYPE,
					ewmh->_NET_WM_WINDOW_TYPE_DOCK) ? LayerNormal : LayerAbove, false);
			break;
		}
		return;
	}

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
			hmaximize_window(client, mon_x, mon_w);
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
update_current_desktop(uint32_t group)
{
	xcb_ewmh_set_current_desktop(ewmh, 0, group);
}

void
invalidate_snapshot_state(void)
{
	snapshot_invalidation++;
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, scr->root,
			ATOMS[CIRRUS_STATE_INVALIDATE], XCB_ATOM_CARDINAL, 32, 1,
			&snapshot_invalidation);
	xcb_flush(conn);
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

bool
update_ewmh_wm_state(struct client *client)
{
	int i;
	uint32_t values[12];

	if (client == NULL)
		return false;

#define HANDLE_WM_STATE(s)              \
	values[i] = ewmh->_NET_WM_STATE_##s; \
	i++;                                 \
	DMSG("ewmh net_wm_state %s present\n", #s);

	i = 0;
	if (client->layer == LayerAbove) {
		HANDLE_WM_STATE(ABOVE);
	}
	if (client->maxed) {
		HANDLE_WM_STATE(FULLSCREEN);
	}
	if (client->vmaxed) {
		HANDLE_WM_STATE(MAXIMIZED_VERT);
	}
	if (client->hmaxed) {
		HANDLE_WM_STATE(MAXIMIZED_HORZ);
	}

	xcb_generic_error_t *error = xcb_request_check(conn,
			xcb_ewmh_set_wm_state_checked(ewmh, client->window, i, values));
	bool ok = error == NULL && !xcb_connection_has_error(conn);
	free(error);
	return ok;
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
			ATOMS[CIRRUS_STATUS], XCB_ATOM_STRING, 8, size, str);
	free(str);
}

void
update_wm_desktop(struct client *client)
{
	if (client != NULL)
		xcb_ewmh_set_wm_desktop(ewmh, client->window, client->group);
}

bool
window_has_ewmh_atom(xcb_window_t window, xcb_atom_t property, xcb_atom_t atom)
{
	bool found = false;
	xcb_get_property_reply_t *reply = xcb_get_property_reply(conn,
			xcb_get_property(conn, false, window, property, XCB_ATOM_ATOM, 0, UINT32_MAX), NULL);
	if (reply != NULL && reply->type == XCB_ATOM_ATOM && reply->format == 32) {
		xcb_atom_t *atoms = xcb_get_property_value(reply);
		int count = xcb_get_property_value_length(reply) / sizeof(*atoms);
		for (int i = 0; i < count; i++)
			if (atoms[i] == atom)
				found = true;
	}
	free(reply);
	return found;
}

enum stacking_layer
default_window_layer(xcb_window_t window)
{
	if (window_has_ewmh_atom(window, ewmh->_NET_WM_WINDOW_TYPE, ewmh->_NET_WM_WINDOW_TYPE_DOCK) ||
			window_has_ewmh_atom(window, ewmh->_NET_WM_STATE, ewmh->_NET_WM_STATE_ABOVE))
		return LayerAbove;
	return LayerNormal;
}

/* Change only ABOVE: unrelated application state belongs to its existing
 * EWMH handlers, not to the layer request. */
static bool
set_ewmh_above(xcb_window_t window, bool above)
{
	xcb_ewmh_get_atoms_reply_t reply = {0};
	bool ok = false;
	bool got = xcb_ewmh_get_wm_state_reply(ewmh,
			xcb_ewmh_get_wm_state(ewmh, window), &reply, NULL);
	uint32_t count = got ? reply.atoms_len : 0;
	xcb_atom_t *atoms = calloc((size_t)count + 1, sizeof(*atoms));
	if (atoms != NULL) {
		uint32_t length = 0;
		for (uint32_t i = 0; i < count; i++)
			if (reply.atoms[i] != ewmh->_NET_WM_STATE_ABOVE)
				atoms[length++] = reply.atoms[i];
		if (above)
			atoms[length++] = ewmh->_NET_WM_STATE_ABOVE;
		xcb_generic_error_t *error = xcb_request_check(conn,
				xcb_ewmh_set_wm_state_checked(ewmh, window, length, atoms));
		ok = error == NULL && !xcb_connection_has_error(conn);
		free(error);
		free(atoms);
	}
	if (got)
		xcb_ewmh_get_atoms_reply_wipe(&reply);
	return ok;
}

bool
update_ewmh_layer_state(struct client *client)
{
	return client != NULL && set_ewmh_above(client->window, client->layer == LayerAbove);
}

/* Panels are intentionally absent from the ordinary managed/focus lists. */
void
handle_unmanaged_wm_state(xcb_window_t window, xcb_atom_t state, unsigned int action)
{
	if (state != ewmh->_NET_WM_STATE_ABOVE || action > XCB_EWMH_WM_STATE_TOGGLE)
		return;
	bool above = action == XCB_EWMH_WM_STATE_ADD ||
			(action == XCB_EWMH_WM_STATE_TOGGLE &&
			 !window_has_ewmh_atom(window, ewmh->_NET_WM_STATE, state));
	set_ewmh_above(window, above);
}
