// See LICENSE file for copyright and license details.

#include <err.h>
#include <errno.h>
#include <getopt.h>
#include <limits.h>
#include <poll.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/time.h>
#include <xcb/xcb.h>

#include "common.h"
#include "ipc.h"
#include "types.h"

xcb_connection_t *conn;
xcb_screen_t *scr;

int opterr = 0;

static bool fn_offset(uint32_t *, int, char **);
static bool fn_naturals(uint32_t *, int, char **);
static bool fn_bool(uint32_t *, int, char **);
static bool fn_config(uint32_t *, int, char **);
static bool fn_hex(uint32_t *, int, char **);
static bool fn_position(uint32_t *, int, char **);
static bool fn_gap(uint32_t *, int, char **);
static bool fn_direction(uint32_t *, int, char **);
static bool fn_pac(uint32_t *, int, char **);
static bool fn_mod(uint32_t *, int, char **);
static bool fn_button(uint32_t *, int, char **);
static bool fn_hack(uint32_t *, int, char **);

static void usage(char *, int);
static void version(void);
static int query_window(enum IPCCommand, const char *, enum IPCClientScope,
		enum IPCClientSelector, bool, xcb_window_t);

static int
compare_ids(const void *a, const void *b)
{
	const char *const *id_a = a;
	const char *const *id_b = b;

	return strcmp(*id_a, *id_b);
}

struct Command {
	char *string_command;
	enum IPCCommand command;
	int argc;
	bool (*handler)(uint32_t *, int , char **);
};

enum ActionDomain { ActionWindow, ActionGroup };
enum ActionModifier {
	ActionModifierNone,
	ActionModifierRelative,
	ActionModifierHorizontal,
	ActionModifierVertical,
	ActionModifierLast,
	ActionModifierCardinal,
	ActionModifierExclusive
};

struct ActionCommand {
	enum ActionDomain domain;
	const char *verb;
	enum ActionModifier modifier;
	bool reverse;
	bool group_scope;
	int32_t numeric[2];
	uint32_t winid;
	uint32_t groupid;
	uint32_t direction;
};

struct ConfigEntry {
	char *key;
	enum IPCConfig config;
	int argc;
	bool (*handler)(uint32_t *, int, char **);
};

static struct Command c[] = {
	{ "group_activate"              , IPCGroupActivate                  ,  1  , fn_naturals } ,
	{ "group_activate_specific"     , IPCGroupActivateSpecific          ,  1  , fn_naturals } ,
	{ "group_add_window"            , IPCGroupAddWindow                 ,  1  , fn_naturals } ,
	{ "group_deactivate"            , IPCGroupDeactivate                ,  1  , fn_naturals } ,
	{ "group_remove_all_windows"    , IPCGroupRemoveAllWindows          ,  1  , fn_naturals } ,
	{ "group_remove_window"         , IPCGroupRemoveWindow              ,  0  , NULL        } ,
	{ "group_toggle"                , IPCGroupToggle                    ,  1  , fn_naturals } ,
	{ "window_cardinal_focus"       , IPCWindowCardinalFocus            ,  1  , fn_direction} ,
	{ "window_close"                , IPCWindowClose                    ,  0  , NULL        } ,
	{ "window_cycle"                , IPCWindowCycle                    ,  0  , NULL        } ,
	{ "window_cycle_in_group"       , IPCWindowCycleInGroup             ,  0  , NULL        } ,
	{ "window_focus"                , IPCWindowFocus                    ,  1  , fn_hex      } ,
	{ "window_focus_last"           , IPCWindowFocusLast                ,  0  , NULL        } ,
	{ "window_hide"                 , IPCWindowHide                     ,  1  , fn_hex      } ,
	{ "window_hor_maximize"         , IPCWindowHorMaximize              ,  0  , NULL        } ,
	{ "window_maximize"             , IPCWindowMaximize                 ,  0  , NULL        } ,
	{ "window_monocle"              , IPCWindowMonocle                  ,  0  , NULL        } ,
	{ "window_move"                 , IPCWindowMove                     ,  2  , fn_offset   } ,
	{ "window_move_absolute"        , IPCWindowMoveAbsolute             ,  2  , fn_offset   } ,
	{ "window_move_in_grid"         , IPCWindowMoveInGrid               ,  2  , fn_offset   } ,
	{ "window_put_in_grid"          , IPCWindowPutInGrid                ,  6  , fn_hack     } ,
	{ "window_resize"               , IPCWindowResize                   ,  2  , fn_offset   } ,
	{ "window_resize_absolute"      , IPCWindowResizeAbsolute           ,  2  , fn_naturals } ,
	{ "window_resize_in_grid"       , IPCWindowResizeInGrid             ,  2  , fn_offset   } ,
	{ "window_rev_cycle"            , IPCWindowRevCycle                 ,  0  , NULL        } ,
	{ "window_rev_cycle_in_group"   , IPCWindowRevCycleInGroup          ,  0  , NULL        } ,
	{ "window_snap"                 , IPCWindowSnap                     ,  1  , fn_position } ,
	{ "window_stack_toggle"         , IPCWindowStackToggle              ,  0  , NULL        } ,
	{ "window_unmaximize"           , IPCWindowUnmaximize               ,  0  , NULL        } ,
	{ "window_ver_maximize"         , IPCWindowVerMaximize              ,  0  , NULL        } ,
	{ "wm_config"                   , IPCWMConfig                       , -1  , fn_config   } ,
	{ "wm_quit"                     , IPCWMQuit                         ,  1  , fn_naturals } ,
};

static struct ConfigEntry configs[] = {
	{ "apply_settings"              , IPCConfigApplySettings            ,  1  , fn_bool     } ,
	{ "border_style"                , IPCConfigBorderStyle              ,  1  , fn_naturals } ,
	{ "border_width"                , IPCConfigBorderWidth              ,  1  , fn_naturals } ,
	{ "click_to_focus"              , IPCConfigClickToFocus             ,  1  , fn_button   } ,
	{ "color_focused"               , IPCConfigColorFocused             ,  1  , fn_hex      } ,
	{ "color_unfocused"             , IPCConfigColorUnfocused           ,  1  , fn_hex      } ,
	{ "corner_mask"                 , IPCConfigCornerMask               ,  1  , fn_naturals } ,
	{ "corner_percent"              , IPCConfigCornerPercent            ,  1  , fn_naturals } ,
	{ "cursor_position"             , IPCConfigCursorPosition           ,  1  , fn_position } ,
	{ "enable_borders"              , IPCConfigEnableBorders            ,  1  , fn_bool     } ,
	{ "enable_last_window_focusing" , IPCConfigEnableLastWindowFocusing ,  1  , fn_bool     } ,
	{ "enable_resize_hints"         , IPCConfigEnableResizeHints        ,  1  , fn_bool     } ,
	{ "enable_sloppy_focus"         , IPCConfigEnableSloppyFocus        ,  1  , fn_bool     } ,
	{ "gap_width"                   , IPCConfigGapWidth                 ,  2  , fn_gap      } ,
	{ "grid_gap_width"              , IPCConfigGridGapWidth             ,  1  , fn_naturals } ,
	{ "groups_nr"                   , IPCConfigGroupsNr                 ,  1  , fn_naturals } ,
	{ "internal_border_width"       , IPCConfigInternalBorderWidth      ,  1  , fn_naturals } ,
	{ "internal_color_focused"      , IPCConfigInternalColorFocused     ,  1  , fn_hex      } ,
	{ "internal_color_unfocused"    , IPCConfigInternalColorUnfocused   ,  1  , fn_hex      } ,
	{ "pointer_actions"             , IPCConfigPointerActions           ,  3  , fn_pac      } ,
	{ "pointer_modifier"            , IPCConfigPointerModifier          ,  1  , fn_mod      } ,
	{ "replay_click_on_focus"       , IPCConfigReplayClickOnFocus       ,  1  , fn_bool     } ,
	{ "sticky_windows"              , IPCConfigStickyWindows            ,  1  , fn_bool     } ,
};

/*
 * An offset is a pair of two signed integers.
 *
 * data[0], data[1] - if 1, then the number in negative
 * data[2], data[3] - the actual numbers, unsigned
 */

static bool
fn_offset(uint32_t *data, int argc, char **argv)
{
	int i = 0;
	do {
		errno = 0;
		int c = strtol(argv[i], NULL, 10);
		if (c >= 0)
			data[i] = IPC_MUL_PLUS;
		else
			data[i] = IPC_MUL_MINUS;
		data[i + 2] = abs(c);
		i++;
	} while (i < argc && errno == 0);

	if (errno != 0)
		return false;
	else
		return true;
}

static bool
fn_naturals(uint32_t *data, int argc, char **argv)
{
	int i = 0;
	do {
		errno = 0;
		data[i] = strtol(argv[i], NULL, 10);
		i++;
	} while (i < argc && errno == 0);

	if (errno != 0)
		return false;
	return true;
}

static bool
fn_bool(uint32_t *data, int argc, char **argv) {
	int i = 0;
	char *arg;
	do {
		arg = argv[i];
		if (strcasecmp(argv[i], "true") == 0
				|| strcasecmp(arg, "yes") == 0
				|| strcasecmp(arg, "t")   == 0
				|| strcasecmp(arg, "y")   == 0
				|| strcasecmp(arg, "1")   == 0)
				data[i] = true;
		else
			data[i] = false;
		i++;
	} while (i < argc);

	return true;
}

static bool
fn_config(uint32_t *data, int argc, char **argv) {
	char *key;
	bool status;
	int i;

	key = argv[0];

	i = 0;
	while (i < NR_IPC_CONFIGS && strcmp(key, configs[i].key) != 0)
		i++;

	if (i < NR_IPC_CONFIGS) {
		if (configs[i].argc != argc - 1)
			errx(EXIT_FAILURE, "too many or not enough arguments. Want: %d", configs[i].argc);
		data[0] = configs[i].config;
		status = (configs[i].handler)(data + 1, argc - 1, argv + 1);

		if (status == false)
			errx(EXIT_FAILURE, "malformed input");
	} else {
		errx(EXIT_FAILURE, "no such config key");
	}
	return true;
}

static bool
fn_hex(uint32_t *data, int argc, char **argv)
{
	int i = 0;
	do {
		errno = 0;
		data[i] = strtol(argv[i], NULL, 16);
		i++;
	} while (i < argc && errno == 0);

	if (errno != 0)
		return false;
	else
		return true;
}

static bool
fn_direction(uint32_t *data, int argc, char **argv)
{
	char *pos = argv[0];
	enum direction dir_sel;

	if (strcasecmp(pos, "up") == 0 || strcasecmp(pos, "north") == 0)
		dir_sel = NORTH;
	else if (strcasecmp(pos, "down") == 0 || strcasecmp(pos, "south") == 0)
		dir_sel = SOUTH;
	else if (strcasecmp(pos, "left") == 0 || strcasecmp(pos, "west") == 0)
		dir_sel = WEST;
	else if (strcasecmp(pos, "right") == 0 || strcasecmp(pos, "east") == 0)
		dir_sel = EAST;
	else
		return false;

	(void)(argc);

	data[0] = dir_sel;

	return true;
}

static bool
fn_pac(uint32_t *data, int argc, char **argv)
{
	for (int i = 0; i < argc; i++) {
		char *pac = argv[i];
		if (strcasecmp(pac, "nothing") == 0)
			data[i] = POINTER_ACTION_NOTHING;
		else if (strcasecmp(pac, "focus") == 0)

			data[i] = POINTER_ACTION_FOCUS;
		else if (strcasecmp(pac, "move") == 0)
			data[i] = POINTER_ACTION_MOVE;
		else if (strcasecmp(pac, "resize_corner") == 0)
			data[i] = POINTER_ACTION_RESIZE_CORNER;
		else if (strcasecmp(pac, "resize_side") == 0)
			data[i] = POINTER_ACTION_RESIZE_SIDE;
		else
			return false;
	}

	return true;
}

static bool
fn_mod(uint32_t *data, int argc, char **argv)
{
	(void)(argc);
	if (strcasecmp(argv[0], "alt") == 0)
		data[0] = XCB_MOD_MASK_1;
	else if (strcasecmp(argv[0], "super") == 0)
		data[0] = XCB_MOD_MASK_4;
	else
		return false;

	return true;

}

static bool
fn_button(uint32_t *data, int argc, char **argv)
{
	char *btn = argv[0];
	(void)(argc);

	if (strcasecmp(btn, "left") == 0)
		data[0] = 1;
	else if (strcasecmp(btn, "middle") == 0)
		data[0] = 2;
	else if (strcasecmp(btn, "right") == 0)
		data[0] = 3;
	else if (strcasecmp(btn, "none") == 0)
		data[0] = UINT32_MAX;
	else if (strcasecmp(btn, "any") == 0)
		data[0] = 0;
	else
		return false;

	return true;
}

/*
 * Kinda like fn_naturals, but each two numbers are put as 16-bit numbers
 * in one uint32_t.
 */

static bool
fn_hack(uint32_t *data, int argc, char **argv)
{
	int i = 0, j = 0;
	unsigned long d;
	do {
		errno = 0;
		d = strtoul(argv[i], NULL, 10);
		if (i % 2 == 0) {
			data[j] = d << 16U;
		} else {
			data[j] |= d;
			j++;
		}
		i++;
	} while (i < argc && errno == 0);

	if (i % 2 == 1 || errno != 0)
		return false;
	return true;
}

static bool
fn_position(uint32_t *data, int argc, char **argv)
{
	char *pos = argv[0];
	enum position snap_pos;

	if (strcasecmp(pos, "topleft") == 0)
		snap_pos = TOP_LEFT;
	else if (strcasecmp(pos, "topright") == 0)
		snap_pos = TOP_RIGHT;
	else if (strcasecmp(pos, "bottomleft") == 0)
		snap_pos = BOTTOM_LEFT;
	else if (strcasecmp(pos, "bottomright") == 0)
		snap_pos = BOTTOM_RIGHT;
	else if (strcasecmp(pos, "middle") == 0 ||
			strcasecmp(pos, "center") == 0 ||
			strcasecmp(pos, "centre") == 0)
		snap_pos = CENTER;
	else if (strcasecmp(pos, "left") == 0)
		snap_pos = LEFT;
	else if (strcasecmp(pos, "bottom") == 0)
		snap_pos = BOTTOM;
	else if (strcasecmp(pos, "top") == 0)
		snap_pos = TOP;
	else if (strcasecmp(pos, "right") == 0)
		snap_pos = RIGHT;
	else if (strcasecmp(pos, "all") == 0)
		snap_pos = ALL;
	else
		return false;

	(void)(argc);
	data[0] = snap_pos;

	return true;
}

static bool
fn_gap(uint32_t *data, int argc, char **argv)
{
	(void)(argc);
	bool status = true;

	status = status && fn_position(data, 1, argv);
	status = status && fn_naturals(data + 1, 1, argv + 1);

	return status;
}

static void
init_xcb(xcb_connection_t **conn)
{
	*conn = xcb_connect(NULL, NULL);
	if (xcb_connection_has_error(*conn))
		errx(EXIT_FAILURE, "unable to connect to X server");
	scr = xcb_setup_roots_iterator(xcb_get_setup(*conn)).data;
}

static xcb_atom_t
get_atom(char *name)
{
	xcb_intern_atom_cookie_t cookie = xcb_intern_atom(conn, 0, strlen(name), name);
	xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(conn, cookie, NULL);

	if (!reply)
		return XCB_ATOM_STRING;

	return reply->atom;
}

static bool
parse_int32(const char *argument, int32_t *value)
{
	char *end;
	long parsed;

	errno = 0;
	parsed = strtol(argument, &end, 10);
	if (errno != 0 || *argument == '\0' || *end != '\0' ||
			parsed < INT32_MIN || parsed > INT32_MAX)
		return false;
	*value = parsed;
	return true;
}

static bool
parse_uint32(const char *argument, int base, uint32_t *value)
{
	char *end;
	unsigned long parsed;

	if (*argument == '-' || *argument == '\0')
		return false;
	errno = 0;
	parsed = strtoul(argument, &end, base);
	if (errno != 0 || *end != '\0' || parsed > UINT32_MAX)
		return false;
	*value = parsed;
	return true;
}

static bool
parse_winid(const char *argument, uint32_t *winid)
{
	return parse_uint32(argument, 16, winid) && *winid != XCB_NONE;
}

static bool
parse_groupid(const char *argument, uint32_t *groupid)
{
	return parse_uint32(argument, 10, groupid) && *groupid != 0;
}

static bool
parse_cardinal_direction(const char *argument, uint32_t *direction)
{
	char *arguments[] = { (char *)argument };
	return fn_direction(direction, 1, arguments);
}

static void
send_ipc(enum IPCCommand command, const uint32_t arguments[4])
{
	xcb_client_message_event_t msg = {0};
	xcb_generic_error_t *error;
	xcb_void_cookie_t cookie;

	msg.response_type = XCB_CLIENT_MESSAGE;
	msg.type = get_atom(ATOM_COMMAND);
	msg.format = 32;
	msg.data.data32[0] = command;
	if (arguments != NULL)
		memcpy(msg.data.data32 + 1, arguments, 4 * sizeof(uint32_t));
	cookie = xcb_send_event_checked(conn, false, scr->root,
			XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT, (char *)&msg);
	error = xcb_request_check(conn, cookie);
	if (error != NULL) {
		fprintf(stderr, "oops %d\n", error->error_code);
		free(error);
	}
	xcb_flush(conn);
}

static void
send_command(struct Command *c, int argc, char **argv)
{
	xcb_client_message_event_t msg = {0};
	xcb_client_message_data_t data = {0};
	xcb_generic_error_t *err;
	xcb_void_cookie_t cookie;
	bool status = true;

	msg.response_type = XCB_CLIENT_MESSAGE;
	msg.type = get_atom(ATOM_COMMAND);
	msg.format = 32;
	data.data32[0] = c->command;
	if (c->handler != NULL)
		status = (c->handler)(data.data32 + 1, argc, argv);
	if (status == false)
		errx(EXIT_FAILURE, "malformed input");

	msg.data = data;

	cookie = xcb_send_event_checked(conn, false, scr->root,
			XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT, (char *)&msg);

	err = xcb_request_check(conn, cookie);
	if (err)
		fprintf(stderr, "oops %d\n", err->error_code);
	xcb_flush(conn);
}

static int
query_window(enum IPCCommand query, const char *selector,
		enum IPCClientScope scope, enum IPCClientSelector selector_type,
		bool explicit_window, xcb_window_t window)
{
	const int timeout_ms = 2000;
	int status = EXIT_FAILURE;
	struct timeval wait_started;
	struct timeval wait_finished;
	struct pollfd pfd;
	xcb_atom_t response_atom;
	xcb_client_message_event_t msg = {0};
	xcb_generic_error_t *error;
	xcb_generic_event_t *event = NULL;
	xcb_property_notify_event_t *property;
	xcb_get_property_reply_t *reply = NULL;
	xcb_void_cookie_t cookie;
	xcb_window_t reply_window;
	uint32_t values[] = { XCB_EVENT_MASK_PROPERTY_CHANGE };
	char *response = NULL;
	char **ids = NULL;
	char *id;
	char *line_end;
	char *parse_end;
	const bool ids_query = query == IPCWindowIds;
	const bool count_query = query == IPCWindowCount;
	const bool classname_query = query == IPCWindowClassname;
	const bool geometry_query = query == IPCWindowGeometry;
	const char *query_name = ids_query ? "ids" : count_query ? "count" :
			classname_query ? "classname" : geometry_query ? "geometry" : "focused";
	long elapsed_ms;
	size_t id_count;
	size_t i;
	int poll_result;
	int remaining_ms;
	int response_len;
	(void)(query_name);

	response_atom = get_atom(ATOM_RESPONSE);
	reply_window = xcb_generate_id(conn);
	cookie = xcb_create_window_checked(conn, XCB_COPY_FROM_PARENT,
			reply_window, scr->root, 0, 0, 1, 1, 0,
			XCB_WINDOW_CLASS_INPUT_ONLY, XCB_COPY_FROM_PARENT,
			XCB_CW_EVENT_MASK, values);
	error = xcb_request_check(conn, cookie);
	if (error != NULL) {
		fprintf(stderr, "sirocco: unable to create reply window: X error %u\n",
				error->error_code);
		free(error);
		return EXIT_FAILURE;
	}

	msg.response_type = XCB_CLIENT_MESSAGE;
	msg.type = get_atom(ATOM_COMMAND);
	msg.format = 32;
	msg.data.data32[0] = query;
	msg.data.data32[1] = reply_window;
	if (selector != NULL)
		msg.data.data32[2] = get_atom((char *)selector);
	msg.data.data32[3] = scope;
	msg.data.data32[4] = selector_type;
	if (geometry_query) {
		msg.data.data32[2] = explicit_window;
		msg.data.data32[3] = window;
	}

	cookie = xcb_send_event_checked(conn, false, scr->root,
			XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT, (char *)&msg);
	DMSG("sirocco ipc window %s: reply=0x%08x seq=%u send attempt\n",
			query_name, reply_window, cookie.sequence);
	error = xcb_request_check(conn, cookie);
	if (error != NULL) {
		DMSG("sirocco ipc window %s: reply=0x%08x seq=%u send result=X error %u\n",
				query_name, reply_window, cookie.sequence, error->error_code);
		fprintf(stderr, "sirocco: unable to send query: X error %u\n",
				error->error_code);
		free(error);
		goto done;
	}
	DMSG("sirocco ipc window %s: reply=0x%08x seq=%u send result=success\n",
			query_name, reply_window, cookie.sequence);
	xcb_flush(conn);

	pfd.fd = xcb_get_file_descriptor(conn);
	pfd.events = POLLIN;
	pfd.revents = 0;

	gettimeofday(&wait_started, NULL);
	DMSG("sirocco ipc window %s: reply=0x%08x seq=%u reply wait start timeout_ms=%d\n",
			query_name, reply_window, cookie.sequence, timeout_ms);
	for (;;) {
		while ((event = xcb_poll_for_event(conn)) != NULL) {
			if ((event->response_type & ~0x80) != XCB_PROPERTY_NOTIFY) {
				free(event);
				continue;
			}

			property = (xcb_property_notify_event_t *)event;
			DMSG("sirocco ipc window %s: reply=0x%08x seq=%u PropertyNotify window=0x%08x atom=%u state=%u\n",
					query_name, reply_window, cookie.sequence, property->window,
					property->atom, property->state);
			if (property->window != reply_window ||
					property->atom != response_atom) {
				free(event);
				continue;
			}

			free(event);
			event = NULL;
			DMSG("sirocco ipc window %s: reply=0x%08x seq=%u property read attempt atom=%u\n",
					query_name, reply_window, cookie.sequence, response_atom);
			reply = xcb_get_property_reply(conn,
					xcb_get_property(conn, false, reply_window, response_atom,
						XCB_ATOM_STRING, 0, UINT32_MAX), NULL);
			if (reply == NULL) {
				DMSG("sirocco ipc window %s: reply=0x%08x seq=%u property read result=failure\n",
						query_name, reply_window, cookie.sequence);
				fprintf(stderr, "sirocco: unable to read windowchef response\n");
				goto done;
			}

			response_len = xcb_get_property_value_length(reply);
			DMSG("sirocco ipc window %s: reply=0x%08x seq=%u property read result=success bytes=%d\n",
					query_name, reply_window, cookie.sequence, response_len);
			response = calloc((size_t)response_len + 1, 1);
			if (response == NULL) {
				fprintf(stderr, "sirocco: unable to allocate response buffer\n");
				goto done;
			}
			memcpy(response, xcb_get_property_value(reply), response_len);

			if (ids_query && strcmp(response, "OK") == 0) {
				DMSG("sirocco ipc window ids: reply=0x%08x seq=%u decoded ID count=0\n",
						reply_window, cookie.sequence);
				status = EXIT_SUCCESS;
			} else if (ids_query && strncmp(response, "OK\n", 3) == 0) {
				id_count = 1;
				for (id = response + 3; *id != '\0'; id++)
					if (*id == '\n')
						id_count++;
				ids = calloc(id_count, sizeof(*ids));
				if (ids == NULL) {
					fprintf(stderr, "sirocco: unable to allocate ID list\n");
					goto done;
				}
				id = response + 3;
				for (i = 0; i < id_count; i++) {
					ids[i] = id;
					line_end = strchr(id, '\n');
					if (line_end != NULL)
						*line_end = '\0';
					if (strlen(id) != 10 || id[0] != '0' || id[1] != 'x')
						break;
					(void)strtoul(id + 2, &parse_end, 16);
					if (*parse_end != '\0')
						break;
					id = line_end == NULL ? id + strlen(id) : line_end + 1;
				}
				if (i != id_count) {
					fprintf(stderr, "sirocco: malformed windowchef response\n");
					goto done;
				}
				qsort(ids, id_count, sizeof(*ids), compare_ids);
				DMSG("sirocco ipc window ids: reply=0x%08x seq=%u decoded ID count=%zu\n",
						reply_window, cookie.sequence, id_count);
				for (i = 0; i < id_count; i++)
					printf("%s\n", ids[i]);
				status = EXIT_SUCCESS;
			} else if (count_query && strncmp(response, "OK ", 3) == 0 &&
					response[3] != '\0' &&
					strspn(response + 3, "0123456789") == strlen(response + 3)) {
				DMSG("sirocco ipc window count: reply=0x%08x seq=%u decoded count=%s\n",
						reply_window, cookie.sequence, response + 3);
				printf("%s\n", response + 3);
				status = EXIT_SUCCESS;
			} else if (classname_query && strcmp(response, "OK") == 0) {
				DMSG("sirocco ipc window classname: reply=0x%08x seq=%u decoded empty classname\n",
						reply_window, cookie.sequence);
				status = EXIT_SUCCESS;
			} else if (classname_query && strncmp(response, "OK ", 3) == 0 &&
					response[3] != '\0') {
				DMSG("sirocco ipc window classname: reply=0x%08x seq=%u decoded classname=%s\n",
						reply_window, cookie.sequence, response + 3);
				printf("%s\n", response + 3);
				status = EXIT_SUCCESS;
			} else if (geometry_query && strncmp(response, "OK\n", 3) == 0 &&
					response[3] != '\0') {
				DMSG("sirocco ipc window geometry: reply=0x%08x seq=%u decoded geometry\n",
						reply_window, cookie.sequence);
				fputs(response + 3, stdout);
				status = EXIT_SUCCESS;
			} else if (!ids_query && !count_query && !classname_query && !geometry_query &&
					strncmp(response, "OK ", 3) == 0 && response[3] != '\0') {
				DMSG("sirocco ipc window focused: reply=0x%08x seq=%u decoded window=%s\n",
						reply_window, cookie.sequence, response + 3);
				printf("%s\n", response + 3);
				status = EXIT_SUCCESS;
			} else if (strncmp(response, "ERROR ", 6) == 0) {
				fprintf(stderr, "sirocco: %s\n", response + 6);
			} else {
				fprintf(stderr, "sirocco: malformed windowchef response\n");
			}
			goto done;
		}

		if (xcb_connection_has_error(conn)) {
			fprintf(stderr, "sirocco: connection closed without a windowchef response\n");
			goto done;
		}

		gettimeofday(&wait_finished, NULL);
		elapsed_ms = (wait_finished.tv_sec - wait_started.tv_sec) * 1000L +
				(wait_finished.tv_usec - wait_started.tv_usec) / 1000L;
		remaining_ms = timeout_ms - elapsed_ms;
		if (remaining_ms <= 0)
			poll_result = 0;
		else
			poll_result = poll(&pfd, 1, remaining_ms);
		if (poll_result <= 0) {
			gettimeofday(&wait_finished, NULL);
			elapsed_ms = (wait_finished.tv_sec - wait_started.tv_sec) * 1000L +
					(wait_finished.tv_usec - wait_started.tv_usec) / 1000L;
			DMSG("sirocco ipc window %s: reply=0x%08x seq=%u timeout elapsed_ms=%ld\n",
					query_name, reply_window, cookie.sequence, elapsed_ms);
			fprintf(stderr,
					"sirocco: timed out waiting for windowchef response\n");
			goto done;
		}
	}

done:
	free(event);
	free(ids);
	free(response);
	free(reply);
	xcb_destroy_window(conn, reply_window);
	xcb_flush(conn);
	return status;
}

static bool
parse_collection_query(int argc, char **argv, const char **selector,
		enum IPCClientScope *scope, enum IPCClientSelector *selector_type)
{
	*selector = NULL;
	*scope = IPCClientScopeMapped;
	*selector_type = IPCClientSelectorNone;

	switch (argc) {
	case 0:
		return true;
	case 1:
		if (strcmp(argv[0], "--all") == 0) {
			*scope = IPCClientScopeAll;
			return true;
		}
		if (argv[0][0] == '-')
			return false;
		*selector = argv[0];
		*selector_type = IPCClientSelectorClassname;
		return true;
	case 2:
		if (strcmp(argv[0], "--name") == 0 &&
				strcmp(argv[1], "--all") != 0 &&
				strcmp(argv[1], "--name") != 0) {
			*selector = argv[1];
			*selector_type = IPCClientSelectorName;
			return true;
		}
		if (strcmp(argv[0], "--all") == 0 && argv[1][0] != '-') {
			*scope = IPCClientScopeAll;
			*selector = argv[1];
			*selector_type = IPCClientSelectorClassname;
			return true;
		}
		return false;
	case 3:
		if (strcmp(argv[0], "--all") != 0 ||
				strcmp(argv[1], "--name") != 0 ||
				strcmp(argv[2], "--all") == 0 ||
				strcmp(argv[2], "--name") == 0)
			return false;
		*scope = IPCClientScopeAll;
		*selector = argv[2];
		*selector_type = IPCClientSelectorName;
		return true;
	default:
		return false;
	}
}

static void
usage(char *name, int status)
{
	fprintf(stderr, "Usage: %s [-h|-v] <command> [args...]\n", name);
	exit(status);
}

static void
version(void)
{
	fprintf(stderr, "%s %s\n", __NAME_CLIENT__, __THIS_VERSION__);
	fprintf(stderr, "Copyright (c) 2016-2019 Tudor Ioan Roman\n");
	fprintf(stderr, "Released under the ISC License\n");

	exit(EXIT_SUCCESS);
}

static void
invalid_action(void)
{
	errx(EXIT_FAILURE, "invalid action command");
}

static void
parse_optional_winid(int argc, char **argv, uint32_t *winid)
{
	if (argc > 1)
		invalid_action();
	*winid = XCB_NONE;
	if (argc == 1 && !parse_winid(argv[0], winid))
		errx(EXIT_FAILURE, "malformed winid");
}

static void
parse_window_geometry_arguments(int argc, char **argv, int first_argument,
		struct ActionCommand *action)
{
	if (argc - first_argument < 2 || argc - first_argument > 3)
		invalid_action();
	if (!parse_int32(argv[first_argument], &action->numeric[0]) ||
			!parse_int32(argv[first_argument + 1], &action->numeric[1]))
		errx(EXIT_FAILURE, "malformed numeric argument");
	if (strcmp(action->verb, "resize") == 0 &&
			action->modifier != ActionModifierRelative &&
			(action->numeric[0] < 0 || action->numeric[1] < 0))
		errx(EXIT_FAILURE, "malformed dimensions");
	parse_optional_winid(argc - first_argument - 2,
			argv + first_argument + 2, &action->winid);
}

static void
send_normalized_action(const struct ActionCommand *action)
{
	uint32_t data[4] = {0};
	enum IPCCommand command;

	if (action->domain == ActionWindow) {
		if (strcmp(action->verb, "move") == 0) {
			command = IPCActionWindowMove;
			data[0] = action->modifier != ActionModifierRelative;
			data[1] = (uint32_t)action->numeric[0];
			data[2] = (uint32_t)action->numeric[1];
			data[3] = action->winid;
		} else if (strcmp(action->verb, "resize") == 0) {
			command = IPCActionWindowResize;
			data[0] = action->modifier != ActionModifierRelative;
			data[1] = (uint32_t)action->numeric[0];
			data[2] = (uint32_t)action->numeric[1];
			data[3] = action->winid;
		} else if (strcmp(action->verb, "maximize") == 0) {
			command = IPCActionWindowMaximize;
			data[0] = action->modifier == ActionModifierHorizontal ?
					IPCMaximizeHorizontal : action->modifier == ActionModifierVertical ?
					IPCMaximizeVertical : IPCMaximizeFull;
			data[1] = action->winid;
		} else if (strcmp(action->verb, "monocle") == 0) {
			command = IPCActionWindowMonocle;
			data[0] = action->winid;
		} else if (strcmp(action->verb, "close") == 0) {
			command = IPCActionWindowClose;
			data[0] = action->winid;
		} else if (strcmp(action->verb, "hide") == 0) {
			command = IPCActionWindowHide;
			data[0] = action->winid;
		} else if (strcmp(action->verb, "cycle") == 0) {
			if (action->group_scope)
				command = action->reverse ?
						IPCWindowRevCycleInGroup : IPCWindowCycleInGroup;
			else
				command = action->reverse ? IPCWindowRevCycle : IPCWindowCycle;
		} else if (strcmp(action->verb, "focus") == 0) {
			if (action->modifier == ActionModifierLast)
				command = IPCWindowFocusLast;
			else if (action->modifier == ActionModifierCardinal) {
				command = IPCWindowCardinalFocus;
				data[0] = action->direction;
			} else {
				command = IPCWindowFocus;
				data[0] = action->winid;
			}
		} else {
			invalid_action();
			return;
		}
	} else {
		if (strcmp(action->verb, "add") == 0) {
			command = IPCActionGroupAdd;
			data[0] = action->groupid;
			data[1] = action->winid;
		} else if (strcmp(action->verb, "remove") == 0) {
			command = IPCActionGroupRemove;
			data[0] = action->winid;
		} else if (strcmp(action->verb, "clear") == 0) {
			command = IPCGroupRemoveAllWindows;
			data[0] = action->groupid;
		} else if (strcmp(action->verb, "focus") == 0) {
			command = action->modifier == ActionModifierExclusive ?
					IPCGroupActivateSpecific : IPCGroupActivate;
			data[0] = action->groupid;
		} else if (strcmp(action->verb, "toggle") == 0) {
			command = IPCGroupToggle;
			data[0] = action->groupid;
		} else if (strcmp(action->verb, "hide") == 0) {
			command = IPCGroupDeactivate;
			data[0] = action->groupid;
		} else {
			invalid_action();
			return;
		}
	}
	send_ipc(command, data);
}

static void
parse_window_action(int argc, char **argv, struct ActionCommand *action)
{
	int first_argument = 1;

	if (argc < 1)
		invalid_action();
	action->domain = ActionWindow;
	action->verb = argv[0];
	if (strcmp(action->verb, "move") == 0 ||
			strcmp(action->verb, "resize") == 0) {
		if (first_argument < argc && strcmp(argv[first_argument], "--relative") == 0) {
			action->modifier = ActionModifierRelative;
			first_argument++;
		}
		parse_window_geometry_arguments(argc, argv, first_argument, action);
	} else if (strcmp(action->verb, "maximize") == 0) {
		if (first_argument < argc && strcmp(argv[first_argument], "--horizontal") == 0) {
			action->modifier = ActionModifierHorizontal;
			first_argument++;
		} else if (first_argument < argc && strcmp(argv[first_argument], "--vertical") == 0) {
			action->modifier = ActionModifierVertical;
			first_argument++;
		}
		parse_optional_winid(argc - first_argument, argv + first_argument,
				&action->winid);
	} else if (strcmp(action->verb, "monocle") == 0 ||
			strcmp(action->verb, "close") == 0 ||
			strcmp(action->verb, "hide") == 0) {
		parse_optional_winid(argc - 1, argv + 1, &action->winid);
	} else if (strcmp(action->verb, "cycle") == 0) {
		for (int i = 1; i < argc; i++) {
			if (strcmp(argv[i], "--reverse") == 0) {
				if (action->reverse)
					invalid_action();
				action->reverse = true;
			} else if (strcmp(argv[i], "--group") == 0) {
				if (action->group_scope)
					invalid_action();
				action->group_scope = true;
			} else {
				invalid_action();
			}
		}
	} else if (strcmp(action->verb, "focus") == 0) {
		if (argc == 2 && strcmp(argv[1], "--last") == 0) {
			action->modifier = ActionModifierLast;
		} else if (argc == 3 && strcmp(argv[1], "--cardinal") == 0) {
			action->modifier = ActionModifierCardinal;
			if (!parse_cardinal_direction(argv[2], &action->direction))
				errx(EXIT_FAILURE, "malformed direction");
		} else if (argc == 2 && parse_winid(argv[1], &action->winid)) {
			action->modifier = ActionModifierNone;
		} else {
			invalid_action();
		}
	} else {
		invalid_action();
	}
}

static void
parse_group_action(int argc, char **argv, struct ActionCommand *action)
{
	int group_index = 1;

	if (argc < 1)
		invalid_action();
	action->domain = ActionGroup;
	action->verb = argv[0];
	if (strcmp(action->verb, "add") == 0) {
		if (argc < 2 || argc > 3)
			invalid_action();
		if (!parse_groupid(argv[1], &action->groupid))
			errx(EXIT_FAILURE, "malformed groupid");
		parse_optional_winid(argc - 2, argv + 2, &action->winid);
	} else if (strcmp(action->verb, "remove") == 0) {
		parse_optional_winid(argc - 1, argv + 1, &action->winid);
	} else if (strcmp(action->verb, "focus") == 0) {
		if (argc > 1 && strcmp(argv[1], "--exclusive") == 0) {
			action->modifier = ActionModifierExclusive;
			group_index++;
		}
		if (argc != group_index + 1)
			invalid_action();
		if (!parse_groupid(argv[group_index], &action->groupid))
			errx(EXIT_FAILURE, "malformed groupid");
	} else if (strcmp(action->verb, "clear") == 0 ||
			strcmp(action->verb, "hide") == 0 ||
			strcmp(action->verb, "toggle") == 0) {
		if (argc != 2)
			invalid_action();
		if (!parse_groupid(argv[1], &action->groupid))
			errx(EXIT_FAILURE, "malformed groupid");
	} else {
		invalid_action();
	}
}

static void
legacy_window_geometry_action(const char *command, int argc, char **argv)
{
	struct ActionCommand action = {0};

	action.domain = ActionWindow;
	if (strcmp(command, "window_move") == 0) {
		action.verb = "move";
		action.modifier = ActionModifierRelative;
	} else if (strcmp(command, "window_move_absolute") == 0) {
		action.verb = "move";
	} else if (strcmp(command, "window_resize") == 0) {
		action.verb = "resize";
		action.modifier = ActionModifierRelative;
	} else {
		action.verb = "resize";
	}
	parse_window_geometry_arguments(argc, argv, 0, &action);
	send_normalized_action(&action);
}

static struct Command *
find_command(const char *name)
{
	const int command_count = sizeof(c) / sizeof(c[0]);

	for (int i = 0; i < command_count; i++)
		if (strcmp(name, c[i].string_command) == 0)
			return &c[i];
	return NULL;
}

static void
send_wm_config(int argc, char **argv)
{
	if (argc < 1)
		errx(EXIT_FAILURE, "wm config requires a configuration key");
	send_command(find_command("wm_config"), argc, argv);
}

static void
send_wm_quit(int argc, char **argv)
{
	uint32_t exit_status;

	if (argc != 1)
		errx(EXIT_FAILURE, "wm quit expects one exit status");
	if (!parse_uint32(argv[0], 10, &exit_status))
		errx(EXIT_FAILURE, "malformed exit status");
	send_command(find_command("wm_quit"), argc, argv);
}

static void
normalized_wm(int argc, char **argv)
{
	if (argc < 1)
		errx(EXIT_FAILURE, "invalid wm command");
	if (strcmp(argv[0], "config") == 0) {
		send_wm_config(argc - 1, argv + 1);
	} else if (strcmp(argv[0], "quit") == 0) {
		send_wm_quit(argc - 1, argv + 1);
	} else {
		errx(EXIT_FAILURE, "invalid wm command");
	}
}

static void
normalized_action(int argc, char **argv)
{
	struct ActionCommand action = {0};

	if (strcmp(argv[0], "window") == 0)
		parse_window_action(argc - 1, argv + 1, &action);
	else
		parse_group_action(argc - 1, argv + 1, &action);
	send_normalized_action(&action);
}

// perform chained command

static void
sirocco(int argc, char **argv)
{
	int i = 0;
	const int command_count = sizeof(c) / sizeof(c[0]);
	int command_argc = argc - 1;
	char **command_argv = argv + 1;

	if (strcmp(argv[0], "window") == 0 || strcmp(argv[0], "group") == 0) {
		normalized_action(argc, argv);
		return;
	}
	if (strcmp(argv[0], "wm") == 0) {
		normalized_wm(argc - 1, argv + 1);
		return;
	}
	if (strcmp(argv[0], "wm_config") == 0) {
		send_wm_config(command_argc, command_argv);
		return;
	}
	if (strcmp(argv[0], "wm_quit") == 0) {
		send_wm_quit(command_argc, command_argv);
		return;
	}
	if (strcmp(argv[0], "window_move") == 0 ||
			strcmp(argv[0], "window_move_absolute") == 0 ||
			strcmp(argv[0], "window_resize") == 0 ||
			strcmp(argv[0], "window_resize_absolute") == 0) {
		legacy_window_geometry_action(argv[0], command_argc, command_argv);
		return;
	}

	i = 0;
	while (i < command_count && strcmp(argv[0], c[i].string_command) != 0)
		i++;

	if (i < command_count) {
		if (c[i].argc != -1) {
			if (command_argc < c[i].argc)
				errx(EXIT_FAILURE, "not enough arguments");
			else if (command_argc > c[i].argc)
				warnx("too many arguments");
		}
		if (c[i].argc == -1 || command_argc == c[i].argc)
			send_command(&c[i], command_argc, command_argv);

	} else {
		errx(EXIT_FAILURE, "no such command");
	}
}

int main(int argc, char **argv) {
	int cmd_argv = 1;  // expected sirocco command (after executable name argv[0])
	const char *collection_classname = NULL;
	enum IPCClientScope collection_scope = IPCClientScopeMapped;
	enum IPCClientSelector collection_selector = IPCClientSelectorNone;
	bool collection_query;

	if (argc == 1) {
		usage(argv[0], EXIT_FAILURE);
	} else if (argc > 1) {
		if (strcmp(argv[1], "-h") == 0)
			usage(argv[0], EXIT_SUCCESS);
		else if (strcmp(argv[1], "-v") == 0)
			version();
	}
	collection_query = argc >= 3 && strcmp(argv[1], "window") == 0 &&
			(strcmp(argv[2], "ids") == 0 || strcmp(argv[2], "count") == 0);
	if (collection_query && !parse_collection_query(argc - 3, argv + 3,
			&collection_classname, &collection_scope, &collection_selector))
		errx(EXIT_FAILURE, "invalid window collection query arguments");

	init_xcb(&conn);
	if (argc == 3 && strcmp(argv[1], "window") == 0 &&
			strcmp(argv[2], "classname") == 0) {
		int status = query_window(IPCWindowClassname, NULL, IPCClientScopeMapped,
				IPCClientSelectorNone, false, XCB_NONE);
		xcb_disconnect(conn);
		return status;
	}
	if (argc == 3 && strcmp(argv[1], "window") == 0 &&
			strcmp(argv[2], "focused") == 0) {
		int status = query_window(IPCWindowFocused, NULL, IPCClientScopeMapped,
				IPCClientSelectorNone, false, XCB_NONE);
		xcb_disconnect(conn);
		return status;
	}
	if (argc >= 3 && strcmp(argv[1], "window") == 0 &&
			strcmp(argv[2], "geometry") == 0) {
		uint32_t window = XCB_NONE;

		if (argc > 4)
			errx(EXIT_FAILURE, "too many arguments");
		if (argc == 4 && !fn_hex(&window, 1, argv + 3))
			errx(EXIT_FAILURE, "malformed input");
		int status = query_window(IPCWindowGeometry, NULL, IPCClientScopeMapped,
				IPCClientSelectorNone, argc == 4, window);
		xcb_disconnect(conn);
		return status;
	}
	if (collection_query) {
		enum IPCCommand query = strcmp(argv[2], "ids") == 0 ?
				IPCWindowIds : IPCWindowCount;
		int status = query_window(query, collection_classname, collection_scope,
				collection_selector, false, XCB_NONE);
		xcb_disconnect(conn);
		return status;
	}
	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], ".") == 0) {
			int cmd_argc = i - cmd_argv;
			if (cmd_argc > 0)
				sirocco(cmd_argc, &argv[cmd_argv]);
			cmd_argv = i + 1;
		}
	}

	if (cmd_argv < argc)
		sirocco(argc - cmd_argv, &argv[cmd_argv]);

	if (conn != NULL)
		xcb_disconnect(conn);

	return 0;
}
