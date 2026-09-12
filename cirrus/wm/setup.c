// See LICENSE file for copyright and license details.

#include <err.h>
#include <errno.h>
#include <string.h>
#include <sys/random.h>
#include <unistd.h>
#include <xcb/xcb.h>

#include "border.h"
#include "common.h"
#include "events.h"
#include "ewmh.h"
#include "groups.h"
#include "input.h"
#include "ipc.h"
#include "ipc_handlers.h"
#include "monitor.h"
#include "render.h"
#include "setup.h"
#include "wm_state.h"

/*
 * Get atom by name.
 */

static char *atom_names[NR_ATOMS] = {
	"WM_DELETE_WINDOW",
	"WM_STATE",
	"CIRRUS_ACTIVE_GROUPS",
	ATOM_COMMAND,
	ATOM_RESPONSE,
	"CIRRUS_STATUS",
	"_CIRRUS_STATE_INVALIDATE",
	"__WM_IPC_REQUEST",
};

static xcb_atom_t
get_atom(char *name)
{
	xcb_intern_atom_cookie_t cookie = xcb_intern_atom(conn, false, strlen(name), name);
	xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(conn, cookie, NULL);

	if (!reply)
		return XCB_ATOM_STRING;

	return reply->atom;
}

int
setup(void)
{
	unsigned char *epoch = (unsigned char *)wm_epoch;
	size_t remaining = sizeof(wm_epoch);
	while (remaining > 0) {
		ssize_t n = getrandom(epoch, remaining, 0);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			err(EXIT_FAILURE, "unable to generate WM identity epoch");
		}
		if (n == 0)
			errx(EXIT_FAILURE, "unable to generate WM identity epoch");
		epoch += n;
		remaining -= (size_t)n;
	}
	/* init xcb and grab events */
	unsigned int values[1];
	int mask;

	conn = xcb_connect(NULL, &scrno);
	if (xcb_connection_has_error(conn)) {
		return -1;
	}

	/* get the first screen. hope it's the last one too */
	scr = xcb_setup_roots_iterator(xcb_get_setup(conn)).data;
	focused_win = NULL;

	argb_visual = find_argb_visual();

	if (argb_visual != NULL) {
		argb_colormap = xcb_generate_id(conn);
		xcb_create_colormap(conn, XCB_COLORMAP_ALLOC_NONE,
				argb_colormap, scr->root, argb_visual->visual_id);
	} else {
		argb_colormap = scr->default_colormap;
	}

	argb_format = find_argb_format();

	mask = XCB_CW_EVENT_MASK;
	values[0] = XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY
		| XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT;
	xcb_generic_error_t *e = xcb_request_check(conn,
			xcb_change_window_attributes_checked(conn, scr->root,
				mask, values));
	if (e != NULL) {
		free(e);
		errx(EXIT_FAILURE, "Another window manager is already running.");
	}

	/* initialize ewmh variables */
	ewmh = calloc(1, sizeof(xcb_ewmh_connection_t));
	if (!ewmh)
		warnx("couldn't set up ewmh connection");
	xcb_intern_atom_cookie_t *cookie = xcb_ewmh_init_atoms(conn, ewmh);
	xcb_ewmh_init_atoms_replies(ewmh, cookie, (void *)0);
	xcb_ewmh_set_wm_pid(ewmh, scr->root, getpid());
	xcb_ewmh_set_wm_name(ewmh, scr->root, strlen(__NAME__), __NAME__);
	xcb_ewmh_set_current_desktop(ewmh, 0, 0);
	xcb_ewmh_set_number_of_desktops(ewmh, 0, GROUPS);
	update_desktop_viewport();

	xcb_atom_t supported_atoms[] = {
		ewmh->_NET_SUPPORTED               , ewmh->_NET_WM_DESKTOP              ,
		ewmh->_NET_NUMBER_OF_DESKTOPS      , ewmh->_NET_CURRENT_DESKTOP         ,
		ewmh->_NET_ACTIVE_WINDOW           , ewmh->_NET_WM_STATE                ,
		ewmh->_NET_WM_STATE_ABOVE          ,
		ewmh->_NET_WM_STATE_FULLSCREEN     , ewmh->_NET_WM_STATE_MAXIMIZED_VERT ,
		ewmh->_NET_WM_STATE_MAXIMIZED_HORZ , ewmh->_NET_WM_NAME                 ,
		ewmh->_NET_WM_ICON_NAME            , ewmh->_NET_WM_WINDOW_TYPE          ,
		ewmh->_NET_WM_WINDOW_TYPE_DOCK     , ewmh->_NET_WM_PID                  ,
		ewmh->_NET_WM_WINDOW_TYPE_TOOLBAR  , ewmh->_NET_WM_WINDOW_TYPE_DESKTOP  ,
		ewmh->_NET_SUPPORTING_WM_CHECK     , ewmh->_NET_DESKTOP_VIEWPORT        ,
	};
	xcb_ewmh_set_supported(ewmh, scrno, sizeof(supported_atoms) / sizeof(xcb_atom_t), supported_atoms);

	xcb_ewmh_set_supporting_wm_check(ewmh, scr->root, scr->root);

	pointer_init();

	/* send requests */
	xcb_flush(conn);

	/* get various atoms for icccm and ewmh */
	for (int i = 0; i < NR_ATOMS; i++)
		ATOMS[i] = get_atom(atom_names[i]);

	randr_base = setup_randr();

	group_in_use = malloc(conf.groups * sizeof(bool));
	for (uint32_t i = 0; i < conf.groups; i++)
		group_in_use[i] = false;
	return 0;
}

/*
 * Tells the server we want to use randr.
 */

int
setup_randr(void)
{
	int base;
	const xcb_query_extension_reply_t *r = xcb_get_extension_data(conn, &xcb_randr_id);

	if (!r->present)
		return -1;
	else
		get_randr();

	base = r->first_event;
	xcb_randr_select_input(conn, scr->root,
			XCB_RANDR_NOTIFY_MASK_SCREEN_CHANGE
			| XCB_RANDR_NOTIFY_MASK_OUTPUT_CHANGE
			| XCB_RANDR_NOTIFY_MASK_CRTC_CHANGE
			| XCB_RANDR_NOTIFY_MASK_OUTPUT_PROPERTY);

	return base;
}

/*
 * Gracefully disconnect.
 */

void
cleanup(void)
{
	trace_restart("cleanup begin focused=0x%08x", focused_win == NULL ? XCB_NONE : focused_win->window);
	for (struct list_item *item = win_list; item != NULL; item = item->next) {
		struct client *client = item->data;
		xcb_get_window_attributes_reply_t *attributes =
			xcb_get_window_attributes_reply(conn,
				xcb_get_window_attributes(conn, client->window), NULL);
		trace_restart("cleanup client=0x%08x frame=0x%08x mapped=%d map_state=%u",
				client->window, client->frame, client->mapped,
				attributes == NULL ? 0 : attributes->map_state);
		free(attributes);
	}
	xcb_set_input_focus(conn, XCB_NONE, XCB_INPUT_FOCUS_POINTER_ROOT,
			XCB_CURRENT_TIME);
	if (exit_code == WM_EXIT_RESTART) {
		/* Detach clients before save-set processing at connection close.  This
		 * makes the visibility state explicit rather than relying on server
		 * handling of WM-owned frame/save-set relationships. */
		for (struct list_item *item = win_list; item != NULL; item = item->next) {
			struct client *client = item->data;
			xcb_query_tree_reply_t *tree = xcb_query_tree_reply(conn,
				xcb_query_tree(conn, client->window), NULL);
			xcb_window_t parent = tree == NULL ? XCB_NONE : tree->parent;
			trace_restart("restart teardown xid=0x%08x parent=0x%08x frame=0x%08x mapped=%d",
					client->window, parent, client->frame, client->mapped);
			free(tree);
			if (parent != XCB_NONE && parent != scr->root) {
				xcb_generic_error_t *error = xcb_request_check(conn,
					xcb_reparent_window_checked(conn, client->window,
						scr->root, client->geom.x, client->geom.y));
				if (error != NULL) {
					trace_restart("restart reparent error xid=0x%08x code=%u",
							client->window, error->error_code);
					free(error);
				}
			}
			xcb_generic_error_t *save_error = xcb_request_check(conn,
				xcb_change_save_set_checked(conn, XCB_SET_MODE_DELETE,
						client->window));
			if (save_error != NULL) {
				trace_restart("restart save-set delete error xid=0x%08x code=%u",
						client->window, save_error->error_code);
				free(save_error);
			}
			if (!client->mapped) {
				trace_restart("restart preserve hidden xid=0x%08x", client->window);
				xcb_generic_error_t *unmap_error = xcb_request_check(conn,
					xcb_unmap_window_checked(conn, client->window));
				if (unmap_error != NULL) {
					trace_restart("restart unmap error xid=0x%08x code=%u",
							client->window, unmap_error->error_code);
					free(unmap_error);
				}
			}
		}
		xcb_flush(conn);
		for (struct list_item *item = win_list; item != NULL; item = item->next) {
			struct client *client = item->data;
			xcb_query_tree_reply_t *tree = xcb_query_tree_reply(conn,
				xcb_query_tree(conn, client->window), NULL);
			xcb_get_window_attributes_reply_t *attributes =
				xcb_get_window_attributes_reply(conn,
					xcb_get_window_attributes(conn, client->window), NULL);
			trace_restart("restart pre-disconnect xid=0x%08x parent=0x%08x mapped=%d map_state=%u",
					client->window,
					tree == NULL ? XCB_NONE : tree->parent,
					client->mapped,
					attributes == NULL ? 0 : attributes->map_state);
			free(tree);
			free(attributes);
		}
	}
	ungrab_buttons();
	if (ewmh != NULL)
		xcb_ewmh_connection_wipe(ewmh);
	if (win_list != NULL)
		list_delete_all_items(&win_list, true);
	/* focus_list contains the same client payloads; only its nodes own data
	 * after win_list has released the clients. */
	if (focus_list != NULL)
		list_delete_all_items(&focus_list, false);
	if (conn != NULL)
		xcb_disconnect(conn);
}

void
load_config(char *config_path)
{
	int f = fork();
	if (f == 0) {
		setsid();
		DMSG("loading %s\n", config_path);
		execl(config_path, config_path, NULL);
		err(EXIT_FAILURE, "couldn't load config file");
	} else if (f == -1) {
		err(EXIT_FAILURE, NULL);
	}
}

void
load_defaults(void)
{
	conf.outer_border_width             = OUTER_BORDER_WIDTH;
	conf.outer_focus_color              = OUTER_COLOR_FOCUS;
	conf.outer_unfocus_color            = OUTER_COLOR_UNFOCUS;
	conf.inner_border_width             = INNER_BORDER_WIDTH;
	conf.inner_focus_color              = INNER_COLOR_FOCUS;
	conf.inner_unfocus_color            = INNER_COLOR_UNFOCUS;
	conf.gap_left                       = conf.gap_down = conf.gap_up = conf.gap_right = GAP;
	conf.cursor_position                = CURSOR_POSITION;
	conf.groups                         = GROUPS;
	/* Group 0 is the reserved VOID slot; sticky clients still need a
	 * usable initial group when no group has been activated yet. */
	last_group                          = conf.groups > 1 ? 1 : NULL_GROUP;
	conf.sloppy_focus                   = SLOPPY_FOCUS;
	conf.resize_hints                   = RESIZE_HINTS;
	conf.sticky_windows                 = STICKY_WINDOWS;
	conf.borders                        = BORDERS;
	conf.last_window_focusing           = LAST_WINDOW_FOCUSING;
	conf.apply_settings                 = APPLY_SETTINGS;
	conf.replay_click_on_focus          = REPLAY_CLICK_ON_FOCUS;
	conf.pointer_actions[BUTTON_LEFT]   = DEFAULT_LEFT_BUTTON_ACTION;
	conf.pointer_actions[BUTTON_MIDDLE] = DEFAULT_MIDDLE_BUTTON_ACTION;
	conf.pointer_actions[BUTTON_RIGHT]  = DEFAULT_RIGHT_BUTTON_ACTION;
	conf.pointer_modifier               = POINTER_MODIFIER;
	conf.click_to_focus                 = CLICK_TO_FOCUS_BUTTON;
	conf.border_style                   = BORDER_STYLE_CORNERS;
	conf.corner_percent                 = 28;
	// conf.corner_mask                 = CORNER_TOP_LEFT | CORNER_TOP_RIGHT | CORNER_BOTTOM_RIGHT | CORNER_BOTTOM_LEFT;
	// conf.corner_mask                    = CORNER_TOP_LEFT | CORNER_BOTTOM_RIGHT;
	conf.corner_mask                    = 10;
}

/*
 * Adds X event handlers to the array.
 */

void
register_event_handlers(void)
{
	for (int i = 0; i <= LAST_XCB_EVENT; i++)
		events[i] = NULL;

	events[XCB_CONFIGURE_REQUEST] = event_configure_request;
	events[XCB_DESTROY_NOTIFY]    = event_destroy_notify;
	events[XCB_ENTER_NOTIFY]      = event_enter_notify;
	events[XCB_MAP_REQUEST]       = event_map_request;
	events[XCB_PROPERTY_NOTIFY]   = event_property_notify;
	events[XCB_MAP_NOTIFY]        = event_map_notify;
	events[XCB_UNMAP_NOTIFY]      = event_unmap_notify;
	events[XCB_CLIENT_MESSAGE]    = event_client_message;
	events[XCB_CONFIGURE_NOTIFY]  = event_configure_notify;
	events[XCB_CIRCULATE_REQUEST] = event_circulate_request;
	events[XCB_FOCUS_IN]          = event_focus_in;
	events[XCB_FOCUS_OUT]         = event_focus_out;
	events[XCB_BUTTON_PRESS]      = event_button_press;
}

xcb_render_pictformat_t
find_argb_format(void)
{
	xcb_render_query_pict_formats_reply_t *reply;
	xcb_render_pictforminfo_iterator_t it;
	xcb_render_pictformat_t format = XCB_NONE;

	reply = xcb_render_query_pict_formats_reply(conn,
		xcb_render_query_pict_formats(conn), NULL);

	if (reply == NULL)
		return XCB_NONE;

	it = xcb_render_query_pict_formats_formats_iterator(reply);

	for (; it.rem; xcb_render_pictforminfo_next(&it)) {
		if (it.data->type == XCB_RENDER_PICT_TYPE_DIRECT &&
				it.data->depth == 32 &&
				it.data->direct.alpha_mask != 0) {
			format = it.data->id;
			break;
		}
	}

	free(reply);
	return format;
}

xcb_visualtype_t *
find_argb_visual(void)
{
	xcb_depth_iterator_t depth_iter;
	xcb_visualtype_iterator_t visual_iter;

	depth_iter = xcb_screen_allowed_depths_iterator(scr);

	for (; depth_iter.rem; xcb_depth_next(&depth_iter)) {
		if (depth_iter.data->depth != 32)
			continue;

		visual_iter = xcb_depth_visuals_iterator(depth_iter.data);

		for (; visual_iter.rem; xcb_visualtype_next(&visual_iter)) {
			if (visual_iter.data->_class == XCB_VISUAL_CLASS_TRUE_COLOR)
				return visual_iter.data;
		}
	}

	return NULL;
}
