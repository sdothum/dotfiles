// See LICENSE file for copyright and license details.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <regex.h>

#include "border.h"
#include "clients.h"
#include "common.h"
#include "input.h"
#include "ipc_handlers.h"
#include "focus.h"
#include "groups.h"
#include "monitor.h"
#include "stack.h"
#include "types.h"
#include "window.h"
#include "wm_state.h"

static void ipc_group_activate_specific(uint32_t *);
static void ipc_group_activate(uint32_t *);
static void ipc_group_add_window(uint32_t *);
static void ipc_group_deactivate(uint32_t *);
static void ipc_group_remove_all_windows(uint32_t *);
static void ipc_group_remove_window(uint32_t *);
static void ipc_group_toggle(uint32_t *);
static void ipc_window_cardinal_focus(uint32_t *);
static void ipc_window_classname(uint32_t *);
static void ipc_window_close(uint32_t *);
static void ipc_window_cycle_in_group(uint32_t *);
static void ipc_window_cycle(uint32_t *);
static void ipc_window_focus_last(uint32_t *);
static void ipc_window_focus(uint32_t *);
static void ipc_window_focused(uint32_t *);
static void ipc_window_geometry(uint32_t *);
static void ipc_window_ids(uint32_t *);
static void ipc_window_count(uint32_t *);
static void ipc_window_hide(uint32_t *);
static void ipc_window_hor_maximize(uint32_t *);
static void ipc_window_maximize(uint32_t *);
static void ipc_window_monocle(uint32_t *);
static void ipc_window_move_absolute(uint32_t *);
static void ipc_window_move_in_grid(uint32_t *);
static void ipc_window_move(uint32_t *);
static void ipc_window_put_in_grid(uint32_t *);
static void ipc_window_resize_absolute(uint32_t *);
static void ipc_window_resize_in_grid(uint32_t *);
static void ipc_window_resize(uint32_t *);
static void ipc_window_rev_cycle_in_group(uint32_t *);
static void ipc_window_rev_cycle(uint32_t *);
static void ipc_window_snap(uint32_t *);
static void ipc_window_stack_toggle(uint32_t *);
static void ipc_window_unmaximize(uint32_t *);
static void ipc_window_ver_maximize(uint32_t *);
static void ipc_wm_config(uint32_t *);
static void ipc_wm_quit(uint32_t *);
static void ipc_action_window_move(uint32_t *);
static void ipc_action_window_resize(uint32_t *);
static void ipc_action_window_maximize(uint32_t *);
static void ipc_action_window_monocle(uint32_t *);
static void ipc_action_window_close(uint32_t *);
static void ipc_action_window_hide(uint32_t *);
static void ipc_action_group_add(uint32_t *);
static void ipc_action_group_remove(uint32_t *);

static bool
ipc_client_classname(struct client *client, xcb_atom_t wm_class,
		xcb_get_property_reply_t **property_reply, char **classname,
		size_t *classname_length)
{
	char *class_end;
	char *instance_end;
	int property_length;
	xcb_get_property_reply_t *reply;

	reply = xcb_get_property_reply(conn,
			xcb_get_property(conn, false, client->window, wm_class,
				XCB_ATOM_STRING, 0, UINT32_MAX), NULL);
	if (reply == NULL || reply->format != 8) {
		free(reply);
		return false;
	}

	property_length = xcb_get_property_value_length(reply);
	instance_end = memchr(xcb_get_property_value(reply), '\0', property_length);
	if (instance_end == NULL || instance_end + 1 >=
			(char *)xcb_get_property_value(reply) + property_length) {
		free(reply);
		return false;
	}

	*classname = instance_end + 1;
	class_end = memchr(*classname, '\0',
			(char *)xcb_get_property_value(reply) + property_length - *classname);
	*classname_length = class_end == NULL ?
			(size_t)((char *)xcb_get_property_value(reply) + property_length - *classname) :
			(size_t)(class_end - *classname);
	if (*classname_length == 0) {
		free(reply);
		return false;
	}

	*property_reply = reply;
	return true;
}

static bool
ipc_client_class_matches(struct client *client, xcb_atom_t wm_class,
		const char *classname)
{
	char *client_classname;
	size_t client_classname_length;
	xcb_get_property_reply_t *property_reply;
	bool matches;

	if (!ipc_client_classname(client, wm_class, &property_reply,
			&client_classname, &client_classname_length))
		return false;
	matches = client_classname_length == strlen(classname) &&
			memcmp(client_classname, classname, client_classname_length) == 0;
	free(property_reply);
	return matches;
}

struct ipc_client_query {
	enum IPCClientScope scope;
	enum IPCClientSelector selector;
	char *pattern;
	xcb_atom_t wm_class;
	regex_t title_regex;
	bool regex_compiled;
};

enum ipc_query_prepare_result {
	IPCQueryPrepareOK,
	IPCQueryPrepareError,
	IPCQueryPrepareInvalidRegex
};

static bool
ipc_client_title(struct client *client, char **title, const char **source)
{
	int title_length;
	xcb_get_property_reply_t *reply;

	reply = xcb_get_property_reply(conn,
			xcb_get_property(conn, false, client->window, ewmh->_NET_WM_NAME,
				ewmh->UTF8_STRING, 0, UINT32_MAX), NULL);
	if (reply == NULL || reply->format != 8 ||
			xcb_get_property_value_length(reply) == 0) {
		free(reply);
		reply = xcb_get_property_reply(conn,
				xcb_get_property(conn, false, client->window, XCB_ATOM_WM_NAME,
					XCB_ATOM_STRING, 0, UINT32_MAX), NULL);
		*source = "WM_NAME";
	} else {
		*source = "_NET_WM_NAME";
	}
	if (reply == NULL || reply->format != 8 ||
			(title_length = xcb_get_property_value_length(reply)) == 0) {
		free(reply);
		return false;
	}

	*title = calloc((size_t)title_length + 1, 1);
	if (*title == NULL) {
		free(reply);
		return false;
	}
	memcpy(*title, xcb_get_property_value(reply), title_length);
	free(reply);
	return true;
}

static bool
ipc_client_query_matches(struct client *client, struct ipc_client_query *query)
{
	char *title;
	const char *title_source;
	bool matches;

	if (query->scope != IPCClientScopeAll && !client->mapped)
		return false;
	switch (query->selector) {
	case IPCClientSelectorNone:
		return true;
	case IPCClientSelectorClassname:
		return ipc_client_class_matches(client, query->wm_class, query->pattern);
	case IPCClientSelectorName:
		if (!ipc_client_title(client, &title, &title_source))
			return false;
		DMSG("windowchef ipc collection: client=0x%08x selector=name title_source=%s\n",
				client->window, title_source);
		matches = regexec(&query->title_regex, title, 0, NULL, 0) == 0;
		free(title);
		return matches;
	}
	return false;
}

static enum ipc_query_prepare_result
ipc_client_query_prepare(uint32_t *d, struct ipc_client_query *query)
{
	int pattern_length;
	xcb_get_atom_name_reply_t *pattern_reply;
	xcb_intern_atom_reply_t *wm_class_reply;

	memset(query, 0, sizeof(*query));
	query->scope = d[2] == IPCClientScopeAll ?
			IPCClientScopeAll : IPCClientScopeMapped;
	query->selector = d[3];
	if (query->selector == IPCClientSelectorNone) {
		DMSG("windowchef ipc collection: selector=none scope=%s\n",
				query->scope == IPCClientScopeAll ? "all" : "mapped");
		return IPCQueryPrepareOK;
	}
	if ((query->selector != IPCClientSelectorClassname &&
			query->selector != IPCClientSelectorName) || d[1] == XCB_ATOM_NONE)
		return IPCQueryPrepareError;

	pattern_reply = xcb_get_atom_name_reply(conn,
			xcb_get_atom_name(conn, d[1]), NULL);
	if (pattern_reply == NULL)
		return IPCQueryPrepareError;
	pattern_length = xcb_get_atom_name_name_length(pattern_reply);
	query->pattern = calloc((size_t)pattern_length + 1, 1);
	if (query->pattern == NULL) {
		free(pattern_reply);
		return IPCQueryPrepareError;
	}
	memcpy(query->pattern, xcb_get_atom_name_name(pattern_reply), pattern_length);
	free(pattern_reply);

	if (query->selector == IPCClientSelectorName) {
		DMSG("windowchef ipc collection: selector=name scope=%s regex=%s\n",
				query->scope == IPCClientScopeAll ? "all" : "mapped", query->pattern);
		if (regcomp(&query->title_regex, query->pattern,
				REG_EXTENDED | REG_ICASE | REG_NOSUB) != 0)
			return IPCQueryPrepareInvalidRegex;
		query->regex_compiled = true;
		return IPCQueryPrepareOK;
	}

	wm_class_reply = xcb_intern_atom_reply(conn,
			xcb_intern_atom(conn, false, strlen("WM_CLASS"), "WM_CLASS"), NULL);
	if (wm_class_reply == NULL)
		return IPCQueryPrepareError;
	query->wm_class = wm_class_reply->atom;
	DMSG("windowchef ipc collection: selector=classname scope=%s classname=%s\n",
			query->scope == IPCClientScopeAll ? "all" : "mapped", query->pattern);
	free(wm_class_reply);
	return IPCQueryPrepareOK;
}

static void
ipc_client_query_cleanup(struct ipc_client_query *query)
{
	if (query->regex_compiled)
		regfree(&query->title_regex);
	free(query->pattern);
}

/*
 * Populates array with functions for handling IPC commands.
 */

void
register_ipc_handlers(void)
{
	ipc_handlers[IPCGroupActivate]         = ipc_group_activate;
	ipc_handlers[IPCGroupActivateSpecific] = ipc_group_activate_specific;
	ipc_handlers[IPCGroupAddWindow]        = ipc_group_add_window;
	ipc_handlers[IPCGroupDeactivate]       = ipc_group_deactivate;
	ipc_handlers[IPCGroupRemoveAllWindows] = ipc_group_remove_all_windows;
	ipc_handlers[IPCGroupRemoveWindow]     = ipc_group_remove_window;
	ipc_handlers[IPCGroupToggle]           = ipc_group_toggle;
	ipc_handlers[IPCWindowCardinalFocus]   = ipc_window_cardinal_focus;
	ipc_handlers[IPCWindowClassname]       = ipc_window_classname;
	ipc_handlers[IPCWindowClose]           = ipc_window_close;
	ipc_handlers[IPCWindowCycleInGroup]    = ipc_window_cycle_in_group;
	ipc_handlers[IPCWindowCycle]           = ipc_window_cycle;
	ipc_handlers[IPCWindowFocus]           = ipc_window_focus;
	ipc_handlers[IPCWindowFocusLast]       = ipc_window_focus_last;
	ipc_handlers[IPCWindowFocused]         = ipc_window_focused;
	ipc_handlers[IPCWindowGeometry]        = ipc_window_geometry;
	ipc_handlers[IPCWindowIds]             = ipc_window_ids;
	ipc_handlers[IPCWindowCount]           = ipc_window_count;
	ipc_handlers[IPCWindowHide]            = ipc_window_hide;
	ipc_handlers[IPCWindowHorMaximize]     = ipc_window_hor_maximize;
	ipc_handlers[IPCWindowMaximize]        = ipc_window_maximize;
	ipc_handlers[IPCWindowMonocle]         = ipc_window_monocle;
	ipc_handlers[IPCWindowMoveAbsolute]    = ipc_window_move_absolute;
	ipc_handlers[IPCWindowMoveInGrid]      = ipc_window_move_in_grid;
	ipc_handlers[IPCWindowMove]            = ipc_window_move;
	ipc_handlers[IPCWindowPutInGrid]       = ipc_window_put_in_grid;
	ipc_handlers[IPCWindowResizeAbsolute]  = ipc_window_resize_absolute;
	ipc_handlers[IPCWindowResizeInGrid]    = ipc_window_resize_in_grid;
	ipc_handlers[IPCWindowResize]          = ipc_window_resize;
	ipc_handlers[IPCWindowRevCycleInGroup] = ipc_window_rev_cycle_in_group;
	ipc_handlers[IPCWindowRevCycle]        = ipc_window_rev_cycle;
	ipc_handlers[IPCWindowSnap]            = ipc_window_snap;
	ipc_handlers[IPCWindowStackToggle]     = ipc_window_stack_toggle;
	ipc_handlers[IPCWindowUnmaximize]      = ipc_window_unmaximize;
	ipc_handlers[IPCWindowVerMaximize]     = ipc_window_ver_maximize;
	ipc_handlers[IPCWMConfig]              = ipc_wm_config;
	ipc_handlers[IPCWMQuit]                = ipc_wm_quit;
	ipc_handlers[IPCActionWindowMove]       = ipc_action_window_move;
	ipc_handlers[IPCActionWindowResize]     = ipc_action_window_resize;
	ipc_handlers[IPCActionWindowMaximize]   = ipc_action_window_maximize;
	ipc_handlers[IPCActionWindowMonocle]    = ipc_action_window_monocle;
	ipc_handlers[IPCActionWindowClose]      = ipc_action_window_close;
	ipc_handlers[IPCActionWindowHide]       = ipc_action_window_hide;
	ipc_handlers[IPCActionGroupAdd]         = ipc_action_group_add;
	ipc_handlers[IPCActionGroupRemove]      = ipc_action_group_remove;
}

static void
ipc_window_classname(uint32_t *d)
{
	char *classname;
	char *response;
	int flush_result;
	size_t classname_length = 0;
	size_t response_length = 2;
	xcb_get_property_reply_t *property_reply = NULL;
	xcb_intern_atom_reply_t *wm_class_reply = NULL;
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];

	DMSG("windowchef ipc window classname: reply=0x%08x query ClientMessage received\n",
			reply_window);
	if (reply_window == XCB_NONE)
		return;

	if (focused_win != NULL) {
		wm_class_reply = xcb_intern_atom_reply(conn,
				xcb_intern_atom(conn, false, strlen("WM_CLASS"), "WM_CLASS"), NULL);
		if (wm_class_reply != NULL)
			(void)ipc_client_classname(focused_win, wm_class_reply->atom,
					&property_reply, &classname, &classname_length);
	}
	if (classname_length > SIZE_MAX - 4 ||
			(response = malloc(classname_length + 4)) == NULL) {
		static const char error_response[] = "ERROR unable to allocate response";

		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				sizeof(error_response) - 1, error_response);
		(void)(property_cookie);
		xcb_flush(conn);
		free(property_reply);
		free(wm_class_reply);
		return;
	}
	memcpy(response, "OK", 2);
	if (classname_length != 0) {
		response[2] = ' ';
		memcpy(response + 3, classname, classname_length);
		response_length = classname_length + 3;
	}
	DMSG("windowchef ipc window classname: reply=0x%08x bytes=%zu reply prepared\n",
			reply_window, response_length);
	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			response_length, response);
	flush_result = xcb_flush(conn);
	DMSG("windowchef ipc window classname: reply=0x%08x property write result=queued seq=%u flush result=%d\n",
			reply_window, property_cookie.sequence, flush_result);
	(void)(property_cookie);
	(void)(flush_result);
	free(response);
	free(property_reply);
	free(wm_class_reply);
}

static void
ipc_window_focused(uint32_t *d)
{
	char response[32];
	int flush_result;
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];
	xcb_window_t focused_window = focused_win == NULL ? XCB_NONE : focused_win->window;

	DMSG("windowchef ipc window focused: reply=0x%08x query ClientMessage received\n",
			reply_window);
	DMSG("windowchef ipc window focused: reply=0x%08x focused=0x%08x reply prepared\n",
			reply_window, focused_window);
	(void)(focused_window);

	if (reply_window == XCB_NONE)
		return;

	if (focused_win == NULL) {
		snprintf(response, sizeof(response),
				"ERROR no focused managed window");
	} else {
		snprintf(response, sizeof(response),
				"OK 0x%08x", focused_win->window);
	}

	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			strlen(response), response);
	DMSG("windowchef ipc window focused: reply=0x%08x focused=0x%08x property write result=queued seq=%u\n",
			reply_window, focused_window, property_cookie.sequence);
	(void)(property_cookie);
	flush_result = xcb_flush(conn);
	DMSG("windowchef ipc window focused: reply=0x%08x focused=0x%08x flush result=%d\n",
			reply_window, focused_window, flush_result);
	(void)(flush_result);
}

static void
ipc_window_geometry(uint32_t *d)
{
	char response[96];
	int flush_result;
	int response_length;
	struct client *client;
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];
	bool explicit_window = d[1] != 0;

	DMSG("windowchef ipc window geometry: reply=0x%08x explicit=%u window=0x%08x query ClientMessage received\n",
			reply_window, explicit_window, d[2]);
	if (reply_window == XCB_NONE)
		return;

	client = explicit_window ? find_client(&d[2]) : focused_win;
	if (client == NULL) {
		response_length = snprintf(response, sizeof(response), explicit_window ?
				"ERROR unknown or unmanaged window" :
				"ERROR no focused managed window");
	} else {
		response_length = snprintf(response, sizeof(response),
				"OK\nX=%d\nY=%d\nWIDTH=%u\nHEIGHT=%u\n",
				(int)client->geom.x, (int)client->geom.y,
				(unsigned int)client->geom.width,
				(unsigned int)client->geom.height);
	}

	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			response_length, response);
	flush_result = xcb_flush(conn);
	DMSG("windowchef ipc window geometry: reply=0x%08x property write result=queued seq=%u flush result=%d\n",
			reply_window, property_cookie.sequence, flush_result);
	(void)(property_cookie);
	(void)(flush_result);
}

static void
ipc_window_ids(uint32_t *d)
{
	char *response;
	char *write_at;
	int flush_result;
	size_t client_count = 0;
	size_t matched_count = 0;
	size_t response_size;
	struct client *client;
	struct ipc_client_query query;
	struct list_item *item;
	enum ipc_query_prepare_result prepare_result;
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];

	DMSG("windowchef ipc window ids: reply=0x%08x query ClientMessage received\n",
			reply_window);

	if (reply_window == XCB_NONE)
		return;
	prepare_result = ipc_client_query_prepare(d, &query);
	if (prepare_result != IPCQueryPrepareOK)
		goto query_error;

	for (item = win_list; item != NULL; item = item->next)
		client_count++;

	response_size = 3 + client_count * 11;
	response = malloc(response_size);
	if (response == NULL) {
		static const char error_response[] = "ERROR unable to allocate response";

		DMSG("windowchef ipc window ids: reply=0x%08x reply preparation failed\n",
				reply_window);
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				sizeof(error_response) - 1, error_response);
		DMSG("windowchef ipc window ids: reply=0x%08x property write result=queued seq=%u\n",
				reply_window, property_cookie.sequence);
		flush_result = xcb_flush(conn);
		DMSG("windowchef ipc window ids: reply=0x%08x flush result=%d\n",
				reply_window, flush_result);
		ipc_client_query_cleanup(&query);
		return;
	}

	write_at = response;
	memcpy(write_at, "OK", 2);
	write_at += 2;
	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (!ipc_client_query_matches(client, &query))
			continue;
		write_at += sprintf(write_at, "\n0x%08x", client->window);
		matched_count++;
	}
	DMSG("windowchef ipc window ids: reply=0x%08x clients=%zu bytes=%zu reply prepared\n",
			reply_window, matched_count, (size_t)(write_at - response));

	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			write_at - response, response);
	DMSG("windowchef ipc window ids: reply=0x%08x clients=%zu property write result=queued seq=%u\n",
			reply_window, matched_count, property_cookie.sequence);
	flush_result = xcb_flush(conn);
	DMSG("windowchef ipc window ids: reply=0x%08x clients=%zu flush result=%d\n",
			reply_window, matched_count, flush_result);
	(void)(property_cookie);
	(void)(flush_result);
	free(response);
	ipc_client_query_cleanup(&query);
	return;

query_error:
	ipc_client_query_cleanup(&query);
	{
		static const char query_error_response[] = "ERROR unable to prepare selector query";
		static const char regex_error_response[] = "ERROR invalid title regex";
		const char *error_response = prepare_result == IPCQueryPrepareInvalidRegex ?
				regex_error_response : query_error_response;

		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				strlen(error_response), error_response);
		xcb_flush(conn);
		(void)(property_cookie);
	}
}

static struct client *
action_client(uint32_t winid)
{
	return winid == XCB_NONE ? focused_win : find_client(&winid);
}

static void
action_window_move(struct client *client, int32_t x, int32_t y, bool absolute)
{
	if (client == NULL)
		return;
	if (is_special(client)) {
		reset_window(client);
		set_focused(client);
	}
	if (absolute) {
		client->geom.x = x;
		client->geom.y = y;
		teleport_window(client->window, x, y);
	} else {
		client->geom.x += x;
		client->geom.y += y;
		move_window(client->window, x, y);
	}
	center_pointer(client);
}

static void
action_window_resize(struct client *client, int32_t width, int32_t height,
		bool absolute)
{
	if (client == NULL)
		return;
	if (is_special(client)) {
		reset_window(client);
		set_focused(client);
	}
	if (!absolute) {
		resize_window(client->window, width, height);
		center_pointer(client);
		return;
	}
	if (client->min_width != 0 && width < client->min_width)
		width = client->min_width;
	if (client->min_height != 0 && height < client->min_height)
		height = client->min_height;
	client->geom.width = width;
	client->geom.height = height;
	resize_window_absolute(client->window, width, height);
	center_pointer(client);
}

static void
action_window_maximize(struct client *client, enum IPCMaximizeAxis axis)
{
	int16_t mon_x, mon_y;
	uint16_t mon_w, mon_h;

	if (client == NULL)
		return;
	get_monitor_size(client, &mon_x, &mon_y, &mon_w, &mon_h);
	switch (axis) {
	case IPCMaximizeHorizontal:
		if (client->hmaxed)
			reset_window(client);
		else
			hmaximize_window(client, mon_x, mon_w);
		break;
	case IPCMaximizeVertical:
		if (client->vmaxed)
			reset_window(client);
		else
			vmaximize_window(client, mon_y, mon_h);
		break;
	case IPCMaximizeFull:
		if (client->maxed)
			reset_window(client);
		else
			maximize_window(client, mon_x, mon_y, mon_w, mon_h);
		break;
	}
	set_focused(client);
	xcb_flush(conn);
}

static void
action_window_monocle(struct client *client)
{
	int16_t mon_x, mon_y;
	uint16_t mon_w, mon_h;

	if (client == NULL)
		return;
	if (client->monocled) {
		reset_window(client);
	} else {
		get_monitor_size(client, &mon_x, &mon_y, &mon_w, &mon_h);
		monocle_window(client, mon_x, mon_y, mon_w, mon_h);
	}
	set_focused(client);
	xcb_flush(conn);
}

static void
ipc_window_count(uint32_t *d)
{
	char response[64];
	int flush_result;
	int response_length;
	size_t matched_count = 0;
	struct client *client;
	struct ipc_client_query query;
	struct list_item *item;
	enum ipc_query_prepare_result prepare_result;
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];

	DMSG("windowchef ipc window count: reply=0x%08x query ClientMessage received\n",
			reply_window);

	if (reply_window == XCB_NONE)
		return;
	prepare_result = ipc_client_query_prepare(d, &query);
	if (prepare_result != IPCQueryPrepareOK)
		goto query_error;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (ipc_client_query_matches(client, &query))
			matched_count++;
	}
	response_length = snprintf(response, sizeof(response), "OK %zu", matched_count);
	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			response_length, response);
	flush_result = xcb_flush(conn);
	DMSG("windowchef ipc window count: reply=0x%08x clients=%zu flush result=%d\n",
			reply_window, matched_count, flush_result);
	(void)(property_cookie);
	(void)(flush_result);
	ipc_client_query_cleanup(&query);
	return;

query_error:
	ipc_client_query_cleanup(&query);
	{
		static const char query_error_response[] = "ERROR unable to prepare selector query";
		static const char regex_error_response[] = "ERROR invalid title regex";
		const char *error_response = prepare_result == IPCQueryPrepareInvalidRegex ?
				regex_error_response : query_error_response;

		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				strlen(error_response), error_response);
		xcb_flush(conn);
		(void)(property_cookie);
	}
}

static void
ipc_group_activate(uint32_t *d)
{
	group_activate(d[0] - 1);
}

static void
ipc_group_activate_specific(uint32_t *d)
{
	group_activate_specific(d[0] - 1);
}

static void
ipc_group_add_window(uint32_t *d)
{
	if (focused_win != NULL)
		group_add_window(focused_win, d[0] - 1);
}

static void
ipc_group_deactivate(uint32_t *d)
{
	group_deactivate(d[0] - 1);
}

static void
ipc_group_remove_all_windows(uint32_t *d)
{
	group_remove_all_windows(d[0] - 1);
}

static void
ipc_group_remove_window(uint32_t *d)
{
	(void)(d);
	if (focused_win != NULL)
		group_remove_window(focused_win);
}

static void
ipc_group_toggle(uint32_t *d)
{
	group_toggle(d[0] - 1);
}

static void
ipc_action_group_add(uint32_t *d)
{
	group_add_window(action_client(d[1]), d[0] - 1);
}

static void
ipc_action_group_remove(uint32_t *d)
{
	group_remove_window(action_client(d[0]));
}

static void
ipc_action_window_move(uint32_t *d)
{
	action_window_move(action_client(d[3]), (int16_t)(int32_t)d[1],
			(int16_t)(int32_t)d[2], d[0]);
}

static void
ipc_action_window_resize(uint32_t *d)
{
	action_window_resize(action_client(d[3]), (int16_t)(int32_t)d[1],
			(int16_t)(int32_t)d[2], d[0]);
}

static void
ipc_action_window_maximize(uint32_t *d)
{
	if (d[0] <= IPCMaximizeVertical)
		action_window_maximize(action_client(d[1]), d[0]);
}

static void
ipc_action_window_monocle(uint32_t *d)
{
	action_window_monocle(action_client(d[0]));
}

static void
ipc_action_window_close(uint32_t *d)
{
	close_window(action_client(d[0]));
}

static void
ipc_action_window_hide(uint32_t *d)
{
	struct client *client = action_client(d[0]);
	if (client != NULL)
		window_hide(client);
}

static void
ipc_window_cardinal_focus(uint32_t *d)
{
	uint32_t mode = d[0];
	cardinal_focus(mode);
}

static void
ipc_window_close(uint32_t *d)
{
	(void)(d);
	close_window(focused_win);
}

static
void ipc_window_cycle(uint32_t *d)
{
	(void)(d);

	cycle_window(focused_win);
}

static void
ipc_window_cycle_in_group(uint32_t *d)
{
	(void)(d);

	if (focused_win == NULL)
		return;

	cycle_window_in_group(focused_win);
}

static void
ipc_window_focus(uint32_t *d)
{
	struct client *client = find_client(&d[0]);

	if (client != NULL)
		set_focused(client);
}

static void
ipc_window_focus_last(uint32_t *d)
{
	(void)(d);
	if (focused_win != NULL)
		set_focused_last_best();
}

static void
ipc_window_hide(uint32_t *d)
{
	struct client *client = find_client(&d[0]);

	if (client != NULL)
		window_hide(client);
}

static void
ipc_window_hor_maximize(uint32_t *d)
{
	(void)(d);
	action_window_maximize(focused_win, IPCMaximizeHorizontal);
}

static void
ipc_window_maximize(uint32_t *d)
{
	(void)(d);
	action_window_maximize(focused_win, IPCMaximizeFull);
}

static void
ipc_window_monocle(uint32_t *d)
{
	(void)(d);
	action_window_monocle(focused_win);
}

static void
ipc_window_move(uint32_t *d)
{
	int16_t x, y;

	x = d[2];
	y = d[3];
	if (d[0])
		x = -x;
	if (d[1])
		y = -y;

	action_window_move(focused_win, x, y, false);
}

static void
ipc_window_move_absolute(uint32_t *d)
{
	int16_t x, y;

	x = d[2];
	y = d[3];

	if (d[0] == IPC_MUL_MINUS)
		x = -x;
	if (d[1] == IPC_MUL_MINUS)
		y = -y;

	action_window_move(focused_win, x, y, true);
}

static void
ipc_window_move_in_grid(uint32_t *d)
{
	uint16_t x, y;

	if (focused_win == NULL)
		return;

	x = d[2];
	y = d[3];

	if (d[0] == IPC_MUL_MINUS)
		x = -x;
	if (d[1] == IPC_MUL_MINUS)
		y = -y;

	move_grid_window(focused_win, x, y);
}

static void
ipc_window_put_in_grid(uint32_t *d)
{
	uint16_t grid_width, grid_height;
	uint16_t grid_x, grid_y;
	uint16_t occ_w, occ_h;
	const uint16_t m1 = 16U, m2 = 0xffffU;

	DMSG("data[4] = %d\n", d[4]);
	grid_width  = d[0] >> m1;
	grid_height = d[0] & m2;
	grid_x      = d[1] >> m1;
	grid_y      = d[1] & m2;
	occ_w       = d[2] >> m1;
	occ_h       = d[2] & m2;

	if (focused_win == NULL || grid_x >= grid_width || grid_y >= grid_height)
		return;

	grid_window(focused_win, grid_width, grid_height, grid_x, grid_y, occ_w, occ_h);
}

static void
ipc_window_resize(uint32_t *d)
{
	int16_t w, h;

	w = d[2];
	h = d[3];

	if (d[0] == IPC_MUL_MINUS)
		w = -w;
	if (d[1] == IPC_MUL_MINUS)
		h = -h;

	action_window_resize(focused_win, w, h, false);
}

static void
ipc_window_resize_absolute(uint32_t *d)
{
	int16_t w, h;

	w = d[0];
	h = d[1];

	action_window_resize(focused_win, w, h, true);
}

static void
ipc_window_resize_in_grid(uint32_t *d)
{
	uint16_t x, y;

	if (focused_win == NULL)
		return;

	x = d[2];
	y = d[3];

	if (d[0] == IPC_MUL_MINUS)
		x = -x;
	if (d[1] == IPC_MUL_MINUS)
		y = -y;

	resize_grid_window(focused_win, x, y);
}

static
void ipc_window_rev_cycle(uint32_t *d)
{
	(void)(d);

	rcycle_window(focused_win);
}

static void
ipc_window_rev_cycle_in_group(uint32_t *d)
{
	(void)(d);

	rcycle_window_in_group(focused_win);
}

static void
ipc_window_snap(uint32_t *d)
{
	enum position pos = d[0];
	snap_window(focused_win, pos);
}

static void
ipc_window_stack_toggle(uint32_t *d)
{
	(void)(d);
	if (focused_win == NULL)
		return;

	window_stack_toggle(focused_win);
}

static void
ipc_window_unmaximize(uint32_t *d)
{
	(void)(d);

	if (focused_win == NULL)
		return;

	if (is_special(focused_win)) {
		reset_window(focused_win);
		set_focused(focused_win);
	}

	xcb_flush(conn);
}

static void
ipc_window_ver_maximize(uint32_t *d)
{
	(void)(d);
	action_window_maximize(focused_win, IPCMaximizeVertical);

	xcb_flush(conn);
}

static void
ipc_wm_config(uint32_t *d)
{
	enum IPCConfig key;

	key = d[0];

	switch (key) {
		case IPCConfigBorderStyle:
			conf.border_style = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigBorderWidth:
			conf.border_width = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigColorFocused:
			conf.focus_color = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigColorUnfocused:
			conf.unfocus_color = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigCornerPercent:
			conf.corner_percent = d[1];
			if (conf.corner_percent > 100)
				conf.corner_percent = 100;
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigCornerMask:
			conf.corner_mask= d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigInternalBorderWidth:
			conf.internal_border_width = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigInternalColorFocused:
			conf.internal_focus_color = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigInternalColorUnfocused:
			conf.internal_unfocus_color = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigGapWidth:
			switch (d[1]) {
			case LEFT: conf.gap_left   = d[2]; break;
			case BOTTOM: conf.gap_down = d[2]; break;
			case TOP: conf.gap_up      = d[2]; break;
			case RIGHT: conf.gap_right = d[2]; break;
			case ALL: conf.gap_left = conf.gap_down
					= conf.gap_up = conf.gap_right = d[2];
			default: break;
			}
			break;
		case IPCConfigGridGapWidth:
			conf.grid_gap = d[1];
			break;
		case IPCConfigCursorPosition:
			conf.cursor_position = d[1];
			break;
		case IPCConfigGroupsNr:
			change_nr_of_groups(d[1]);
			break;
		case IPCConfigEnableSloppyFocus:
			conf.sloppy_focus = d[1];
			break;
		case IPCConfigEnableResizeHints:
			conf.resize_hints = d[1];
			break;
		case IPCConfigStickyWindows:
			conf.sticky_windows = d[1];
			break;
		case IPCConfigEnableBorders:
			conf.borders = d[1];
			refresh_borders();
			break;
		case IPCConfigEnableLastWindowFocusing:
			conf.last_window_focusing = d[1];
			break;
		case IPCConfigApplySettings:
			conf.apply_settings = d[1];
			break;
		case IPCConfigReplayClickOnFocus:
			conf.replay_click_on_focus = d[1];
			break;
		case IPCConfigPointerActions:
			for (int i = 0; i < NR_BUTTONS; i++) {
				conf.pointer_actions[i] = d[i + 1];
			}
			ungrab_buttons();
			grab_buttons();
			break;
		case IPCConfigPointerModifier:
			conf.pointer_modifier = d[1];
			ungrab_buttons();
			grab_buttons();
			break;
		case IPCConfigClickToFocus:
			if (d[1] == UINT32_MAX)
				conf.click_to_focus = -1;
			else
				conf.click_to_focus = d[1];
			ungrab_buttons();
			grab_buttons();
			break;
		default:
			DMSG("!!! unhandled config key %d\n", key);
			break;
	}
}

static void
ipc_wm_quit(uint32_t *d)
{
	uint32_t code = d[0];
	halt = true;
	exit_code = code;
}
