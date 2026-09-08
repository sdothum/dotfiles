// See LICENSE file for copyright and license details.

#include <stdio.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <regex.h>

#include "border.h"
#include "clients.h"
#include "common.h"
#include "input.h"
#include "ipc_handlers.h"
#include "focus.h"
#include "geometry.h"
#include "groups.h"
#include "monitor.h"
#include "stack.h"
#include "types.h"
#include "window.h"
#include "wm_state.h"

static void ipc_action_group_activate(uint32_t *);
static void ipc_action_group_deactivate(uint32_t *);
static void ipc_group_current(uint32_t *);
static void ipc_group_count(uint32_t *);
static void ipc_group_remove_all_windows(uint32_t *);
static void ipc_window_cardinal_focus(uint32_t *);
static void ipc_window_classname(uint32_t *);
static void ipc_window_cycle_in_group(uint32_t *);
static void ipc_window_cycle(uint32_t *);
static void ipc_window_focus_last(uint32_t *);
static void ipc_window_focus(uint32_t *);
static void ipc_window_focused(uint32_t *);
static void ipc_window_geometry(uint32_t *);
static void ipc_window_ids(uint32_t *);
static void ipc_window_count(uint32_t *);
static void ipc_window_rev_cycle_in_group(uint32_t *);
static void ipc_window_rev_cycle(uint32_t *);
static void ipc_window_stack(uint32_t *);
static void ipc_window_stack_geometries(uint32_t *);
static void ipc_window_apply_geometries(uint32_t *);
static void ipc_window_apply_geometries_checked(uint32_t *);
static void ipc_action_window_raise_many(uint32_t *);
static void ipc_window_groups(uint32_t *);
static void ipc_window_group(uint32_t *);
static void ipc_window_snapshot(uint32_t *);
static void ipc_wm_config(uint32_t *);
static void ipc_wm_quit(uint32_t *);
static void ipc_wm_restart(uint32_t *);
static void ipc_action_window_move(uint32_t *);
static void ipc_action_window_resize(uint32_t *);
static void ipc_action_window_maximize(uint32_t *);
static void ipc_action_window_monocle(uint32_t *);
static void ipc_action_window_close(uint32_t *);
static void ipc_action_window_hide(uint32_t *);
static void ipc_action_window_reset(uint32_t *);
static void ipc_action_window_stack_cycle(uint32_t *);
static void ipc_action_group_add(uint32_t *);
static void ipc_action_group_remove(uint32_t *);
static void action_window_move(struct client *, int32_t, int32_t, bool, bool);
static void action_window_resize(struct client *, int32_t, int32_t, bool, bool);

static bool trace_stack_enabled(void)
{
	const char *value = getenv("CIRRUS_TRACE_STACK");
	return value != NULL && value[0] != '\0' && strcmp(value, "0") != 0;
}

static bool trace_stack_pending;

static void trace_stack(const char *label)
{
	xcb_query_tree_reply_t *reply;
	xcb_window_t *children;
	int length;

	if (!trace_stack_enabled())
		return;
	reply = xcb_query_tree_reply(conn,
			xcb_query_tree(conn, scr->root), NULL);
	if (reply == NULL) {
		fprintf(stderr, "STACK %s unavailable\n", label);
		return;
	}
	children = xcb_query_tree_children(reply);
	length = xcb_query_tree_children_length(reply);
	fprintf(stderr, "STACK %s\n", label);
	for (int i = 0; i < length; i++) {
		struct client *client = find_client(&children[i]);
		struct client *frame = find_client_by_frame(children[i]);
		if (client != NULL)
			fprintf(stderr, "  %02d 0x%08x client focused=%s\n", i,
				children[i], client == focused_win ? "yes" : "no");
		else if (frame != NULL)
			fprintf(stderr, "  %02d 0x%08x frame client=0x%08x focused=%s\n", i,
				children[i], frame->window, frame == focused_win ? "yes" : "no");
		else
			fprintf(stderr, "  %02d 0x%08x unmanaged\n", i, children[i]);
	}
	free(reply);
}

void ipc_trace_event_loop(void)
{
	if (!trace_stack_pending)
		return;
	trace_stack_pending = false;
	trace_stack("STACK-4");
}

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
	ipc_handlers[IPCActionGroupActivate]   = ipc_action_group_activate;
	ipc_handlers[IPCActionGroupDeactivate] = ipc_action_group_deactivate;
	ipc_handlers[IPCGroupCurrent]          = ipc_group_current;
	ipc_handlers[IPCGroupCount]            = ipc_group_count;
	ipc_handlers[IPCGroupRemoveAllWindows] = ipc_group_remove_all_windows;
	ipc_handlers[IPCWindowCardinalFocus]   = ipc_window_cardinal_focus;
	ipc_handlers[IPCWindowClassname]       = ipc_window_classname;
	ipc_handlers[IPCWindowCycleInGroup]    = ipc_window_cycle_in_group;
	ipc_handlers[IPCWindowCycle]           = ipc_window_cycle;
	ipc_handlers[IPCWindowFocus]           = ipc_window_focus;
	ipc_handlers[IPCWindowFocusLast]       = ipc_window_focus_last;
	ipc_handlers[IPCWindowFocused]         = ipc_window_focused;
	ipc_handlers[IPCWindowGeometry]        = ipc_window_geometry;
	ipc_handlers[IPCWindowIds]             = ipc_window_ids;
	ipc_handlers[IPCWindowCount]           = ipc_window_count;
	ipc_handlers[IPCWindowRevCycleInGroup] = ipc_window_rev_cycle_in_group;
	ipc_handlers[IPCWindowRevCycle]        = ipc_window_rev_cycle;
	ipc_handlers[IPCWMConfig]              = ipc_wm_config;
	ipc_handlers[IPCWMQuit]                = ipc_wm_quit;
	ipc_handlers[IPCWMRestart]             = ipc_wm_restart;
	ipc_handlers[IPCActionWindowMove]       = ipc_action_window_move;
	ipc_handlers[IPCActionWindowResize]     = ipc_action_window_resize;
	ipc_handlers[IPCActionWindowMaximize]   = ipc_action_window_maximize;
	ipc_handlers[IPCActionWindowMonocle]    = ipc_action_window_monocle;
	ipc_handlers[IPCActionWindowClose]      = ipc_action_window_close;
	ipc_handlers[IPCActionWindowHide]       = ipc_action_window_hide;
	ipc_handlers[IPCActionWindowReset]      = ipc_action_window_reset;
	ipc_handlers[IPCActionWindowStackCycle] = ipc_action_window_stack_cycle;
	ipc_handlers[IPCActionGroupAdd]         = ipc_action_group_add;
	ipc_handlers[IPCActionGroupRemove]      = ipc_action_group_remove;
	ipc_handlers[IPCWindowStack]            = ipc_window_stack;
	ipc_handlers[IPCWindowStackGeometries]  = ipc_window_stack_geometries;
	ipc_handlers[IPCActionWindowApplyGeometries] = ipc_window_apply_geometries;
	ipc_handlers[IPCActionWindowApplyGeometriesChecked] = ipc_window_apply_geometries_checked;
	ipc_handlers[IPCActionWindowRaiseMany] = ipc_action_window_raise_many;
	ipc_handlers[IPCWindowGroup]            = ipc_window_group;
	ipc_handlers[IPCWindowGroups]           = ipc_window_groups;
	ipc_handlers[IPCWindowSnapshot]         = ipc_window_snapshot;
}

static void
ipc_group_current(uint32_t *d)
{
	char response[64];
	xcb_window_t reply_window = d[0];
	uint32_t group = focused_win == NULL ? NULL_GROUP : focused_win->group;

	if (reply_window == XCB_NONE)
		return;
	snprintf(response, sizeof(response), "OK %u", group);
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			strlen(response), response);
	xcb_flush(conn);
}

static void
ipc_group_count(uint32_t *d)
{
	char response[64];
	xcb_window_t reply_window = d[0];
	if (reply_window == XCB_NONE)
		return;
	snprintf(response, sizeof(response), "OK %u", conf.groups);
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
		ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
		strlen(response), response);
	xcb_flush(conn);
}

static void
ipc_window_stack(uint32_t *d)
{
	bool explicit_window = d[1] != 0;
	char *response = NULL;
	char *write_at;
	const char *error_response = NULL;
	enum window_stack_result stack_result;
	int flush_result;
	size_t i;
	struct client *reference;
	struct window_stack stack = {0};
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];

	if (reply_window == XCB_NONE)
		return;

	reference = explicit_window ? find_client(&d[2]) : focused_win;
	if (reference == NULL) {
		error_response = explicit_window ? "ERROR unknown or unmanaged window" :
				"ERROR no focused managed window";
		goto respond;
	}
	stack_result = get_window_stack(reference, &stack);
	switch (stack_result) {
	case WindowStackSuccess:
		break;
	case WindowStackReferenceNotMapped:
		error_response = "ERROR reference window is not mapped";
		goto respond;
	case WindowStackAllocationFailed:
		error_response = "ERROR unable to allocate response";
		goto respond;
	case WindowStackOrderUnavailable:
		error_response = "ERROR unable to read stacking order";
		goto respond;
	case WindowStackReferenceMissing:
		error_response = "ERROR reference window missing from stacking order";
		goto respond;
	}

	response = malloc(3 + stack.count * 11);
	if (response == NULL) {
		error_response = "ERROR unable to allocate response";
		goto respond;
	}
	write_at = response;
	memcpy(write_at, "OK", 2);
	write_at += 2;
	for (i = 0; i < stack.count; i++)
		write_at += sprintf(write_at, "\n0x%08x", stack.clients[i]->window);

respond:
	if (error_response != NULL) {
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				strlen(error_response), error_response);
	} else {
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				write_at - response, response);
	}
	flush_result = xcb_flush(conn);
	(void)(property_cookie);
	(void)(flush_result);
	free_window_stack(&stack);
	free(response);
}

static void
ipc_window_stack_geometries(uint32_t *d)
{
	const size_t record_size = 48;
	char *response = NULL;
	char *write_at;
	const char *error_response = NULL;
	struct client *reference;
	struct window_stack stack = {0};
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];
	bool explicit_window = d[1] != 0;
	size_t response_size;
	size_t remaining;
	size_t i;
	int written;

	if (reply_window == XCB_NONE)
		return;
	reference = explicit_window ? find_client(&d[2]) : focused_win;
	if (reference == NULL)
		error_response = explicit_window ? "ERROR unknown or unmanaged window" :
				"ERROR no focused managed window";
	else {
		switch (get_window_stack(reference, &stack)) {
		case WindowStackSuccess:
			break;
		case WindowStackReferenceNotMapped:
			error_response = "ERROR reference window is not mapped";
			break;
		case WindowStackAllocationFailed:
			error_response = "ERROR unable to allocate response";
			break;
		case WindowStackOrderUnavailable:
			error_response = "ERROR unable to read stacking order";
			break;
		case WindowStackReferenceMissing:
			error_response = "ERROR reference window missing from stacking order";
			break;
		}
	}
	if (error_response == NULL &&
			stack.count > (SIZE_MAX - 4) / record_size) {
		error_response = "ERROR response too large";
	}
	if (error_response == NULL) {
		response_size = 3 + stack.count * record_size + 1;
		response = malloc(response_size);
		if (response == NULL)
			error_response = "ERROR unable to allocate response";
	}
	if (error_response == NULL) {
		write_at = response;
		remaining = response_size;
		memcpy(write_at, "OK\n", 3);
		write_at += 3;
		remaining -= 3;
		for (i = 0; i < stack.count; i++) {
			written = snprintf(write_at, remaining,
					"0x%08x %d %d %u %u\n",
					(unsigned int)stack.clients[i]->window,
					(int)stack.clients[i]->geom.x,
					(int)stack.clients[i]->geom.y,
					(unsigned int)stack.clients[i]->geom.width,
					(unsigned int)stack.clients[i]->geom.height);
			if (written < 0 || (size_t)written >= remaining) {
				error_response = "ERROR response too large";
				break;
			}
			write_at += written;
			remaining -= (size_t)written;
		}
	}
	if (error_response != NULL) {
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				strlen(error_response), error_response);
	} else {
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				write_at - response, response);
	}
	xcb_flush(conn);
	(void)property_cookie;
	free_window_stack(&stack);
	free(response);
}

static void
ipc_window_apply_geometries(uint32_t *d)
{
	const size_t max_request = 65536;
	char *copy = NULL;
	char *line;
	char *field;
	struct geometry_record {
		struct client *client;
		int32_t x, y;
		uint16_t width, height;
	};
	struct geometry_record *records = NULL;
	xcb_get_property_reply_t *reply = NULL;
	xcb_window_t reply_window = d[0];
	const char *error_response = NULL;
	size_t length, count = 0, capacity, i;
	xcb_void_cookie_t property_cookie;

	if (reply_window == XCB_NONE)
		return;
	reply = xcb_get_property_reply(conn,
			xcb_get_property(conn, false, reply_window,
				ATOMS[_IPC_ATOM_REQUEST], XCB_ATOM_STRING, 0, max_request), NULL);
	if (reply == NULL || reply->format != 8 || reply->type != XCB_ATOM_STRING) {
		error_response = "ERROR invalid geometry request";
		goto respond;
	}
	length = (size_t)xcb_get_property_value_length(reply);
	if (length == 0 || length > max_request) {
		error_response = "ERROR invalid geometry request";
		goto respond;
	}
	copy = malloc(length + 1);
	if (copy == NULL) {
		error_response = "ERROR unable to allocate geometry request";
		goto respond;
	}
	memcpy(copy, xcb_get_property_value(reply), length);
	copy[length] = '\0';
	for (size_t i = 0; i < length; i++)
		if (copy[i] == '\n')
			count++;
	if (copy[length - 1] != '\n')
		count++;
	if (count == 0 || count > max_request / 2) {
		error_response = "ERROR invalid geometry request";
		goto respond;
	}
	records = calloc(count, sizeof(*records));
	if (records == NULL) {
		error_response = "ERROR unable to allocate geometry request";
		goto respond;
	}
	capacity = count;
	line = strtok(copy, "\n");
	for (i = 0; line != NULL; i++) {
		char *tokens[5];
		char *end;
		unsigned long value;
		long signed_value;
		uint32_t winid;
		if (i >= capacity || line[0] == ' ' || line[strlen(line) - 1] == ' ' ||
				strstr(line, "  ") != NULL)
			goto invalid;
		field = line;
		for (size_t j = 0; j < 5; j++) {
			char *separator = strchr(field, ' ');
			tokens[j] = field;
			if (j < 4) {
				if (separator == NULL)
					goto invalid;
				*separator = '\0';
				field = separator + 1;
			} else if (separator != NULL) {
				goto invalid;
			}
		}
		if (strlen(tokens[0]) != 10 || tokens[0][0] != '0' || tokens[0][1] != 'x')
			goto invalid;
		errno = 0;
		value = strtoul(tokens[0] + 2, &end, 16);
		if (errno != 0 || *end != '\0' || value > UINT32_MAX)
			goto invalid;
		winid = (uint32_t)value;
		records[i].client = find_client(&winid);
		if (records[i].client == NULL)
			goto invalid;
		errno = 0;
		signed_value = strtol(tokens[1], &end, 10);
		if (errno != 0 || *end != '\0' || signed_value < INT32_MIN || signed_value > INT32_MAX)
			goto invalid;
		records[i].x = (int32_t)signed_value;
		errno = 0;
		signed_value = strtol(tokens[2], &end, 10);
		if (errno != 0 || *end != '\0' || signed_value < INT32_MIN || signed_value > INT32_MAX)
			goto invalid;
		records[i].y = (int32_t)signed_value;
		for (size_t j = 3; j < 5; j++) {
			errno = 0;
			value = strtoul(tokens[j], &end, 10);
			if (errno != 0 || *end != '\0' || value > UINT16_MAX)
				goto invalid;
			if (j == 3)
				records[i].width = (uint16_t)value;
			else
				records[i].height = (uint16_t)value;
		}
		for (size_t j = 0; j < i; j++)
			if (records[j].client->window == records[i].client->window)
				goto invalid;
		line = strtok(NULL, "\n");
	}
	if (i != count)
		goto invalid;
	trace_stack("STACK-0");
	for (size_t i = 0; i < count; i++) {
		action_window_move(records[i].client, records[i].x, records[i].y, true, true);
		action_window_resize(records[i].client, records[i].width, records[i].height, true, true);
	}
	trace_stack("STACK-1");
	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
			reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8, 2, "OK");
	xcb_flush(conn);
	(void)property_cookie;
	free(records);
	free(copy);
	free(reply);
	return;
invalid:
	error_response = "ERROR invalid geometry request";
respond:
	if (error_response != NULL) {
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				strlen(error_response), error_response);
		xcb_flush(conn);
		(void)property_cookie;
	}
	free(records);
	free(copy);
	free(reply);
}

static void
ipc_action_window_raise_many(uint32_t *d)
{
	const size_t max_request = 65536;
	char *copy = NULL;
	char *line;
	struct client **clients = NULL;
	xcb_get_property_reply_t *reply = NULL;
	xcb_window_t reply_window = d[0];
	const char *error_response = NULL;
	size_t length, count = 0, i;
	xcb_void_cookie_t property_cookie;
	xcb_query_tree_reply_t *tree = NULL;
	xcb_window_t *objects = NULL;
	size_t object_count = 0;
	xcb_window_t sibling = XCB_NONE;

	if (reply_window == XCB_NONE)
		return;
	reply = xcb_get_property_reply(conn,
			xcb_get_property(conn, false, reply_window,
				ATOMS[_IPC_ATOM_REQUEST], XCB_ATOM_STRING, 0, max_request), NULL);
	if (reply == NULL || reply->format != 8 || reply->type != XCB_ATOM_STRING) {
		error_response = "ERROR invalid raise request";
		goto respond;
	}
	length = (size_t)xcb_get_property_value_length(reply);
	if (length == 0 || length > max_request) {
		error_response = "ERROR invalid raise request";
		goto respond;
	}
	copy = malloc(length + 1);
	if (copy == NULL) {
		error_response = "ERROR unable to allocate raise request";
		goto respond;
	}
	memcpy(copy, xcb_get_property_value(reply), length);
	copy[length] = '\0';
	for (i = 0; i < length; i++)
		if (copy[i] == '\n')
			count++;
	if (copy[length - 1] != '\n')
		count++;
	if (count == 0 || count > max_request / 3) {
		error_response = "ERROR invalid raise request";
		goto respond;
	}
	clients = calloc(count, sizeof(*clients));
	if (clients == NULL) {
		error_response = "ERROR unable to allocate raise request";
		goto respond;
	}
	line = strtok(copy, "\n");
	for (i = 0; line != NULL; i++) {
		char *end;
		unsigned long value;
		xcb_window_t window;

		if (i >= count || strlen(line) != 10 || line[0] != '0' || line[1] != 'x')
			goto invalid;
		errno = 0;
		value = strtoul(line + 2, &end, 16);
		if (errno != 0 || *end != '\0' || value > UINT32_MAX)
			goto invalid;
		window = (xcb_window_t)value;
		clients[i] = find_client(&window);
		if (clients[i] == NULL || !clients[i]->mapped)
			goto invalid;
		for (size_t j = 0; j < i; j++)
			if (clients[j] == clients[i])
				goto invalid;
		line = strtok(NULL, "\n");
	}
	if (i != count)
		goto invalid;
	trace_stack("STACK-2");
	tree = xcb_query_tree_reply(conn, xcb_query_tree(conn, scr->root), NULL);
	if (tree == NULL)
		goto stack_invalid;
	objects = calloc(count * 2, sizeof(*objects));
	if (objects == NULL)
		goto stack_invalid;
	for (i = 0; i < count; i++) {
		bool client_found = false;
		bool frame_found = clients[i]->frame == XCB_NONE;
		xcb_window_t *children = xcb_query_tree_children(tree);
		int child_count = xcb_query_tree_children_length(tree);
		for (int j = 0; j < child_count; j++) {
			if (children[j] == clients[i]->window)
				client_found = true;
			if (children[j] == clients[i]->frame)
				frame_found = true;
		}
		if (!client_found || !frame_found)
			goto stack_invalid;
		if (clients[i]->frame != XCB_NONE)
			objects[object_count++] = clients[i]->frame;
		objects[object_count++] = clients[i]->window;
	}
	/* Anchor the first target object above the highest unrelated root child,
	 * then insert each following object immediately above its predecessor. */
	{
		xcb_window_t *children = xcb_query_tree_children(tree);
		int child_count = xcb_query_tree_children_length(tree);
		for (i = child_count; i > 0; i--) {
			bool target = false;
			for (size_t j = 0; j < object_count; j++)
				if (children[i - 1] == objects[j])
					target = true;
			if (!target) {
				sibling = children[i - 1];
				break;
			}
		}
	}
	for (i = 0; i < object_count; i++) {
		uint16_t mask = XCB_CONFIG_WINDOW_STACK_MODE;
		uint32_t values[2] = { XCB_STACK_MODE_ABOVE };
		if (sibling != XCB_NONE) {
			mask |= XCB_CONFIG_WINDOW_SIBLING;
			values[0] = sibling;
			values[1] = XCB_STACK_MODE_ABOVE;
		}
		if (trace_stack_enabled())
			fprintf(stderr, "RESTACK configure object=0x%08x sibling=0x%08x mode=ABOVE\n",
				objects[i], sibling);
		xcb_configure_window(conn, objects[i], mask, values);
		sibling = objects[i];
	}
	free(objects);
	free(tree);
	trace_stack("STACK-3");
	trace_stack_pending = true;
	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
			reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8, 2, "OK");
	xcb_flush(conn);
	(void)property_cookie;
	free(clients);
	free(copy);
	free(reply);
	return;
stack_invalid:
	error_response = "ERROR unable to determine stacking order";
	goto respond;
invalid:
	error_response = "ERROR invalid raise request";
respond:
	if (error_response != NULL) {
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				strlen(error_response), error_response);
		xcb_flush(conn);
		(void)property_cookie;
	}
	free(clients);
	free(objects);
	free(tree);
	free(copy);
	free(reply);
}

/* History-sensitive bulk geometry: identity is checked for every record
 * before any geometry request is issued.  The request body is intentionally
 * separate from the public XID-only apply-geometries grammar. */
static void
ipc_window_apply_geometries_checked(uint32_t *d)
{
	const size_t max_request = 65536;
	char *copy = NULL, *line, *field;
	xcb_get_property_reply_t *reply = NULL;
	xcb_window_t reply_window = d[0];
	struct record { struct client *client; int32_t x, y; uint16_t width, height; } *records = NULL;
	const char *error_response = NULL;
	size_t length, count = 0, i;
	xcb_void_cookie_t property_cookie;
	if (reply_window == XCB_NONE) return;
	reply = xcb_get_property_reply(conn, xcb_get_property(conn, false, reply_window,
		ATOMS[_IPC_ATOM_REQUEST], XCB_ATOM_STRING, 0, max_request), NULL);
	if (reply == NULL || reply->format != 8 || reply->type != XCB_ATOM_STRING)
		goto invalid;
	length = (size_t)xcb_get_property_value_length(reply);
	if (length == 0 || length > max_request) goto invalid;
	copy = malloc(length + 1);
	if (copy == NULL) { error_response = "ERROR unable to allocate geometry request"; goto respond; }
	memcpy(copy, xcb_get_property_value(reply), length); copy[length] = '\0';
	for (i = 0; i < length; i++) if (copy[i] == '\n') count++;
	if (copy[length - 1] != '\n') count++;
	if (count == 0 || count > max_request / 3) goto invalid;
	records = calloc(count, sizeof(*records));
	if (records == NULL) { error_response = "ERROR unable to allocate geometry request"; goto respond; }
	line = strtok(copy, "\n");
	for (i = 0; line != NULL; i++) {
		char *tokens[6], *end; unsigned long value; long signed_value; uint32_t winid;
		if (i >= count || line[0] == ' ' || line[strlen(line)-1] == ' ' || strstr(line, "  ") != NULL) goto invalid;
		field = line;
		for (size_t j = 0; j < 6; j++) {
			char *separator = strchr(field, ' '); tokens[j] = field;
			if (j < 5) { if (separator == NULL) goto invalid; *separator = '\0'; field = separator + 1; }
			else if (separator != NULL) goto invalid;
		}
		if (strlen(tokens[0]) != 10 || tokens[0][0] != '0' || tokens[0][1] != 'x') goto invalid;
		errno = 0; value = strtoul(tokens[0] + 2, &end, 16);
		if (errno || *end != '\0' || value > UINT32_MAX) goto invalid;
		winid = (uint32_t)value; records[i].client = find_client(&winid);
		if (records[i].client == NULL) goto invalid;
		{
			char canonical[50];
			if (strlen(tokens[1]) != 49 || tokens[1][32] != ':') goto invalid;
			for (size_t j = 0; j < 49; j++)
				if (j != 32 && !((tokens[1][j] >= '0' && tokens[1][j] <= '9') || (tokens[1][j] >= 'a' && tokens[1][j] <= 'f'))) goto invalid;
			if (strspn(tokens[1] + 33, "0") == 16) goto invalid;
			format_client_token(records[i].client, canonical, sizeof(canonical));
			if (strcmp(canonical, tokens[1]) != 0) goto invalid;
		}
		for (size_t j = 2; j < 4; j++) {
			errno = 0; signed_value = strtol(tokens[j], &end, 10);
			if (errno || *end != '\0' || signed_value < INT32_MIN || signed_value > INT32_MAX) goto invalid;
			if (j == 2) records[i].x = (int32_t)signed_value; else records[i].y = (int32_t)signed_value;
		}
		for (size_t j = 4; j < 6; j++) {
			errno = 0; value = strtoul(tokens[j], &end, 10);
			if (errno || *end != '\0' || value > UINT16_MAX) goto invalid;
			if (j == 4) records[i].width = (uint16_t)value; else records[i].height = (uint16_t)value;
		}
		for (size_t j = 0; j < i; j++) if (records[j].client == records[i].client) goto invalid;
		line = strtok(NULL, "\n");
	}
	if (i != count) goto invalid;
	for (i = 0; i < count; i++) {
		action_window_move(records[i].client, records[i].x, records[i].y, true, true);
		action_window_resize(records[i].client, records[i].width, records[i].height, true, true);
	}
	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
		ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8, 2, "OK");
	xcb_flush(conn); (void)property_cookie; free(records); free(copy); free(reply); return;
invalid: error_response = "ERROR invalid checked geometry request";
respond:
	if (error_response == NULL) error_response = "ERROR invalid checked geometry request";
	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
		ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8, strlen(error_response), error_response);
	xcb_flush(conn); (void)property_cookie; free(records); free(copy); free(reply);
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
ipc_window_group(uint32_t *d)
{
	char response[64];
	struct client *client;
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];

	if (reply_window == XCB_NONE)
		return;

	client = find_client(&d[2]);
	if (client == NULL) {
		snprintf(response, sizeof(response),
				"ERROR unknown or unmanaged window");
	} else if (client->group == NULL_GROUP) {
		snprintf(response, sizeof(response), "OK %u", NULL_GROUP);
	} else {
		snprintf(response, sizeof(response), "OK %u", client->group);
	}

	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
			reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			strlen(response), response);
	(void)(property_cookie);
	xcb_flush(conn);
}

static void
ipc_window_groups(uint32_t *d)
{
	const size_t record_size = 22;
	const size_t envelope_size = 3;
	char *response;
	char *write_at;
	size_t client_count = 0;
	size_t response_size;
	struct client *client;
	struct list_item *item;
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];

	if (reply_window == XCB_NONE)
		return;

	for (item = win_list; item != NULL; item = item->next)
		client_count++;
	if (client_count > (SIZE_MAX - envelope_size - 1) / record_size) {
		static const char error_response[] = "ERROR response too large";

		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				sizeof(error_response) - 1, error_response);
		(void)(property_cookie);
		xcb_flush(conn);
		return;
	}

	response_size = envelope_size + client_count * record_size + 1;
	response = malloc(response_size);
	if (response == NULL) {
		static const char error_response[] = "ERROR unable to allocate response";

		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				sizeof(error_response) - 1, error_response);
		(void)(property_cookie);
		xcb_flush(conn);
		return;
	}

	write_at = response;
	if (client_count != 0) {
		memcpy(write_at, "OK\n", 3);
		write_at += 3;
	} else {
		memcpy(write_at, "OK", 2);
		write_at += 2;
	}
	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		uint32_t group = client->group;
		int written = snprintf(write_at, response_size - (size_t)(write_at - response),
				"0x%08x %u\n", (unsigned int)client->window, group);

		if (written < 0 || (size_t)written >=
				response_size - (size_t)(write_at - response)) {
			free(response);
			return;
		}
		write_at += written;
	}

	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
			reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			write_at - response, response);
	(void)(property_cookie);
	xcb_flush(conn);
	free(response);
}

static void
ipc_window_snapshot(uint32_t *d)
{
	const size_t envelope_size = 3;
	const size_t header_size = envelope_size + 11 + 19 + 19;
	const size_t client_record_size = 100;
	char *response;
	char *write_at;
	size_t client_count = 0;
	size_t response_size;
	struct client *client;
	struct list_item *item;
	xcb_void_cookie_t property_cookie;
	xcb_window_t reply_window = d[0];
	uint32_t current_group = focused_win == NULL ||
			focused_win->group == NULL_GROUP ? NULL_GROUP : focused_win->group;

	if (reply_window == XCB_NONE)
		return;
	for (item = win_list; item != NULL; item = item->next)
		client_count++;
	if (client_count > (SIZE_MAX - header_size) / client_record_size) {
		static const char error_response[] = "ERROR response too large";
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				sizeof(error_response) - 1, error_response);
		(void)property_cookie;
		xcb_flush(conn);
		return;
	}
	response_size = header_size + client_count * client_record_size + 1;
	response = malloc(response_size);
	if (response == NULL) {
		static const char error_response[] = "ERROR unable to allocate response";
		property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
				reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
				sizeof(error_response) - 1, error_response);
		(void)property_cookie;
		xcb_flush(conn);
		return;
	}

	write_at = response;
	memcpy(write_at, "OK\n", envelope_size);
	write_at += envelope_size;
	write_at += sprintf(write_at, "SNAPSHOT 2\nFOCUSED ");
	if (focused_win == NULL)
		write_at += sprintf(write_at, "NONE\n");
	else
		write_at += sprintf(write_at, "0x%08x\n", (unsigned int)focused_win->window);
	write_at += sprintf(write_at, "CURRENT %u\n", current_group);
	for (item = win_list; item != NULL; item = item->next) {
		char token[50];
		client = item->data;
		format_client_token(client, token, sizeof(token));
		write_at += sprintf(write_at, "CLIENT 0x%08x %u %d %s\n",
				(unsigned int)client->window,
				client->group,
				client->mapped ? 1 : 0, token);
	}
	property_cookie = xcb_change_property(conn, XCB_PROP_MODE_REPLACE,
			reply_window, ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			write_at - response, response);
	(void)property_cookie;
	xcb_flush(conn);
	free(response);
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
action_window_move(struct client *client, int32_t x, int32_t y, bool absolute,
		bool explicit_window)
{
	struct explicit_geometry_guard guard;

	if (client == NULL)
		return;
	begin_explicit_geometry_guard(explicit_window ? client : NULL, &guard);
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
	finish_explicit_geometry_guard(&guard);
	if (!explicit_window)
		center_pointer(client);
}

static void
action_window_resize(struct client *client, int32_t width, int32_t height,
		bool absolute, bool explicit_window)
{
	struct explicit_geometry_guard guard;

	if (client == NULL)
		return;
	begin_explicit_geometry_guard(explicit_window ? client : NULL, &guard);
	if (is_special(client)) {
		reset_window(client);
		set_focused(client);
	}
	if (!absolute) {
		resize_window(client->window, width, height);
		finish_explicit_geometry_guard(&guard);
		if (!explicit_window)
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
	finish_explicit_geometry_guard(&guard);
	if (!explicit_window)
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
ipc_action_group_activate(uint32_t *d)
{
	const char *response = d[1] >= conf.groups ?
			"ERROR invalid group" : "OK";

	if (d[0] == XCB_NONE)
		return;
	if (response[0] == 'O')
		group_activate(d[1]);
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, d[0],
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			strlen(response), response);
	xcb_flush(conn);
}

static void
ipc_action_group_deactivate(uint32_t *d)
{
	const char *response = d[1] >= conf.groups ?
			"ERROR invalid group" : "OK";

	if (d[0] == XCB_NONE)
		return;
	if (response[0] == 'O')
		group_deactivate(d[1]);
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, d[0],
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			strlen(response), response);
	xcb_flush(conn);
}

static void
ipc_group_remove_all_windows(uint32_t *d)
{
	group_remove_all_windows(d[0]);
}

static void
ipc_action_group_add(uint32_t *d)
{
	group_add_window(action_client(d[1]), d[0]);
}

static void
ipc_action_group_remove(uint32_t *d)
{
	group_remove_window(action_client(d[0]));
}

static void
ipc_action_window_move(uint32_t *d)
{
	bool explicit_window = d[3] != XCB_NONE;

	action_window_move(action_client(d[3]), (int16_t)(int32_t)d[1],
			(int16_t)(int32_t)d[2], d[0], explicit_window);
}

static void
ipc_action_window_resize(uint32_t *d)
{
	bool explicit_window = d[3] != XCB_NONE;

	action_window_resize(action_client(d[3]), (int16_t)(int32_t)d[1],
			(int16_t)(int32_t)d[2], d[0], explicit_window);
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
	bool explicit_window = d[1] != 0;
	const char *response;
	struct client *client = explicit_window ? find_client(&d[2]) : focused_win;
	xcb_window_t reply_window = d[0];

	if (reply_window == XCB_NONE)
		return;
	if (client == NULL) {
		response = explicit_window ? "ERROR unknown or unmanaged window" :
				"ERROR no focused managed window";
	} else if (!client->mapped) {
		response = "ERROR window is already hidden";
	} else {
		window_hide(client);
		response = "OK";
	}
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			strlen(response), response);
	xcb_flush(conn);
}

static void
ipc_action_window_reset(uint32_t *d)
{
	bool explicit_window = d[1] != 0;
	const char *response;
	struct client *client = explicit_window ? find_client(&d[2]) : focused_win;
	xcb_window_t reply_window = d[0];

	if (reply_window == XCB_NONE)
		return;
	if (client == NULL) {
		response = explicit_window ? "ERROR unknown or unmanaged window" :
				"ERROR no focused managed window";
	} else if (is_special(client)) {
		reset_window(client);
		set_focused(client);
		response = "OK";
	} else {
		response = "OK";
	}
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			strlen(response), response);
	xcb_flush(conn);
}

static void
ipc_action_window_stack_cycle(uint32_t *d)
{
	bool explicit_window = d[1] != 0;
	const char *response;
	enum window_stack_result stack_result;
	struct client *target;
	struct client *reference = explicit_window ? find_client(&d[2]) : focused_win;
	struct window_stack stack = {0};
	xcb_window_t reply_window = d[0];

	if (reply_window == XCB_NONE)
		return;
	if (reference == NULL) {
		response = explicit_window ? "ERROR unknown or unmanaged window" :
				"ERROR no focused managed window";
		goto respond;
	}
	stack_result = get_window_stack(reference, &stack);
	switch (stack_result) {
	case WindowStackSuccess:
		break;
	case WindowStackReferenceNotMapped:
		response = "ERROR reference window is not mapped";
		goto respond;
	case WindowStackAllocationFailed:
		response = "ERROR unable to allocate response";
		goto respond;
	case WindowStackOrderUnavailable:
		response = "ERROR unable to read stacking order";
		goto respond;
	case WindowStackReferenceMissing:
		response = "ERROR reference window missing from stacking order";
		goto respond;
	}
	if (stack.count > 1) {
		target = stack.reference_index == stack.count - 1 ?
				stack.clients[0] : reference;
		set_focused(target);
	}
	response = "OK";

respond:
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, reply_window,
			ATOMS[_IPC_ATOM_RESPONSE], XCB_ATOM_STRING, 8,
			strlen(response), response);
	xcb_flush(conn);
	free_window_stack(&stack);
}

static void
ipc_window_cardinal_focus(uint32_t *d)
{
	uint32_t mode = d[0];
	cardinal_focus(mode);
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
		case IPCConfigOuterBorderWidth:
			conf.outer_border_width = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigOuterColorFocused:
			conf.outer_focus_color = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigOuterColorUnfocused:
			conf.outer_unfocus_color = d[1];
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
		case IPCConfigInnerBorderWidth:
			conf.inner_border_width = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigInnerColorFocused:
			conf.inner_focus_color = d[1];
			if (conf.apply_settings)
				refresh_borders();
			break;
		case IPCConfigInnerColorUnfocused:
			conf.inner_unfocus_color = d[1];
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

static void
ipc_wm_restart(uint32_t *d)
{
	(void)d;
	halt = true;
	exit_code = WM_EXIT_RESTART;
}
