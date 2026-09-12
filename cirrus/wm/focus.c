// See LICENSE file for copyright and license details.

#include <tgmath.h>
#include <stdlib.h>

#include "clients.h"
#include "stack.h"
#include "ewmh.h"
#include "focus.h"
#include "geometry.h"
#include "input.h"

struct geometry_enter_suppression {
	bool stacking;
	xcb_window_t focused_window;
	xcb_window_t entered_window;
	int16_t root_x, root_y;
	uint32_t lower_sequence, upper_sequence;
	struct geometry_enter_suppression *next;
};

static struct geometry_enter_suppression *geometry_enter_suppressions;

static bool
sequence_between(uint32_t sequence, uint32_t lower, uint32_t upper)
{
	return (int32_t)(sequence - lower) > 0 &&
			(int32_t)(upper - sequence) > 0;
}

void
begin_explicit_geometry_guard(struct client *client,
		struct explicit_geometry_guard *guard)
{
	xcb_query_pointer_cookie_t cookie;
	xcb_query_pointer_reply_t *pointer;
	struct client *pointer_client;

	guard->active = false;
	guard->stacking = false;
	if (!conf.sloppy_focus || client == NULL || client != focused_win ||
			!client->mapped)
		return;

	cookie = xcb_query_pointer(conn, scr->root);
	pointer = xcb_query_pointer_reply(conn, cookie, NULL);
	if (pointer == NULL)
		return;

	pointer_client = find_client_from_window(pointer->child);
	if (pointer->same_screen && pointer_client == client) {
		guard->active = true;
		guard->focused_window = client->window;
		guard->pointer_child = pointer->child;
		guard->root_x = pointer->root_x;
		guard->root_y = pointer->root_y;
		guard->lower_sequence = cookie.sequence;
	}
	free(pointer);
}

/* Layer changes can expose any client, including intermediate restack
 * positions. Reuse the sequence/coordinate guard without requiring the
 * focused client to be under the pointer. Real later pointer motion remains
 * eligible for sloppy focus. */
void
begin_stacking_guard(struct explicit_geometry_guard *guard)
{
	xcb_query_pointer_cookie_t cookie;
	xcb_query_pointer_reply_t *pointer;
	guard->active = false;
	guard->stacking = true;
	if (!conf.sloppy_focus)
		return;
	cookie = xcb_query_pointer(conn, scr->root);
	pointer = xcb_query_pointer_reply(conn, cookie, NULL);
	if (pointer != NULL && pointer->same_screen) {
		guard->active = true;
		guard->focused_window = focused_win ? focused_win->window : XCB_NONE;
		guard->pointer_child = pointer->child;
		guard->root_x = pointer->root_x;
		guard->root_y = pointer->root_y;
		guard->lower_sequence = cookie.sequence;
	}
	free(pointer);
}

void
finish_explicit_geometry_guard(struct explicit_geometry_guard *guard)
{
	xcb_query_pointer_cookie_t cookie;
	xcb_query_pointer_reply_t *pointer;
	struct client *entered;
	struct geometry_enter_suppression *pending;
	struct geometry_enter_suppression **tail;

	if (!guard->active)
		return;
	guard->active = false;

	cookie = xcb_query_pointer(conn, scr->root);
	pointer = xcb_query_pointer_reply(conn, cookie, NULL);
	if (pointer == NULL)
		return;

	entered = find_client_from_window(pointer->child);
	if (!pointer->same_screen || pointer->root_x != guard->root_x ||
			pointer->root_y != guard->root_y ||
			(!guard->stacking && (pointer->child == guard->pointer_child || entered == NULL ||
			entered->window == guard->focused_window || focused_win == NULL)) ||
			(focused_win ? focused_win->window : XCB_NONE) != guard->focused_window) {
		free(pointer);
		return;
	}

	pending = calloc(1, sizeof(*pending));
	if (pending == NULL) {
		free(pointer);
		return;
	}
	pending->stacking = guard->stacking;
	pending->focused_window = guard->focused_window;
	pending->entered_window = entered ? entered->window : XCB_NONE;
	pending->root_x = guard->root_x;
	pending->root_y = guard->root_y;
	pending->lower_sequence = guard->lower_sequence;
	pending->upper_sequence = cookie.sequence;

	tail = &geometry_enter_suppressions;
	while (*tail != NULL)
		tail = &(*tail)->next;
	*tail = pending;
	free(pointer);
}

/* Retire stacking guards even when a restack generated no crossing event. */
void
expire_stacking_guards(uint32_t sequence)
{
	struct geometry_enter_suppression **link = &geometry_enter_suppressions;
	while (*link != NULL) {
		struct geometry_enter_suppression *pending = *link;
		if (pending->stacking && (int32_t)(sequence - pending->upper_sequence) >= 0) {
			*link = pending->next;
			free(pending);
		} else {
			link = &pending->next;
		}
	}
}

bool
suppress_explicit_geometry_enter(xcb_generic_event_t *ev,
		xcb_enter_notify_event_t *enter)
{
	struct geometry_enter_suppression **link = &geometry_enter_suppressions;

	while (*link != NULL) {
		struct geometry_enter_suppression *pending = *link;
		struct client *entered = find_client_from_window(enter->event);
		bool focus_changed = (focused_win ? focused_win->window : XCB_NONE) !=
				pending->focused_window;
		bool sequence_passed =
				(int32_t)(ev->full_sequence - pending->upper_sequence) >= 0;
		bool normal_mode = enter->mode == XCB_NOTIFY_MODE_NORMAL;
		bool coordinate_match = enter->root_x == pending->root_x &&
				enter->root_y == pending->root_y;
		bool client_match = entered != NULL &&
				entered->window == pending->entered_window;
		bool sequence_match = sequence_between(ev->full_sequence,
				pending->lower_sequence, pending->upper_sequence);
		bool matches = !focus_changed && normal_mode &&
				(pending->stacking || client_match) && coordinate_match && sequence_match;


		if (matches && pending->stacking)
			return true;
		if (matches || focus_changed || sequence_passed) {
			*link = pending->next;
			free(pending);
			if (matches)
				return true;
			continue;
		}
		link = &pending->next;
	}

	return false;
}

bool
is_in_valid_direction(uint32_t direction, float window_direction, float delta)
{
	switch((uint32_t)direction) {
		case NORTH:
			if (window_direction >= (180 - delta) || window_direction <= (-180 + delta))
				return true;
			break;
		case SOUTH:
			if (fabs(window_direction) <= ( 0 + delta))
				return true;
			break;
		case EAST:
			if (window_direction <= (90 + delta) && window_direction > (90 - delta))
				return true;
			break;
		case WEST:
			if (window_direction <= (-90 + delta) && window_direction >= (-90 - delta))
				return true;
			break;
	}

	return false;
}

bool
is_in_cardinal_direction(uint32_t direction, struct client *a, struct client *b)
{
	struct win_position pos_a_top_left = get_window_position(TOP_LEFT, a);
	struct win_position pos_a_top_right = get_window_position(TOP_RIGHT, a);
	struct win_position pos_a_bot_left = get_window_position(BOTTOM_LEFT, a);

	struct win_position pos_b_center = get_window_position(CENTER, b);

	switch(direction) {
		case NORTH:
		case SOUTH:
			return pos_a_top_left.x <= pos_b_center.x && pos_a_top_right.x >= pos_b_center.x;

		case WEST:
		case EAST:
			return pos_a_top_left.y <= pos_b_center.y && pos_a_bot_left.y >= pos_b_center.y;
	}

	return false;
}

bool
is_overlapping(struct client *a, struct client *b)
{
	struct win_position pos_a_top_left = get_window_position(TOP_LEFT, a);
	struct win_position pos_a_top_right = get_window_position(TOP_RIGHT, a);
	struct win_position pos_a_bot_left = get_window_position(BOTTOM_LEFT, a);

	struct win_position pos_b_top_left = get_window_position(TOP_LEFT, b);
	struct win_position pos_b_top_right = get_window_position(TOP_RIGHT, b);
	struct win_position pos_b_bot_left = get_window_position(BOTTOM_LEFT, b);

	bool is_x_top_overlapped = pos_a_top_left.x <= pos_b_top_left.x && pos_a_top_right.x >= pos_b_top_left.x;
	bool is_x_bot_overlapped = pos_a_top_left.x <= pos_b_top_right.x && pos_a_top_right.x >= pos_b_top_right.x;

	bool is_y_top_overlapped = pos_a_top_left.y <= pos_b_top_left.y && pos_a_bot_left.y >= pos_b_top_left.y;
	bool is_y_bot_overlapped = pos_a_top_left.y <= pos_b_bot_left.y && pos_a_bot_left.y >= pos_b_bot_left.y;

	return (is_x_top_overlapped || is_x_bot_overlapped) && (is_y_top_overlapped || is_y_bot_overlapped);
}

void
cardinal_focus(uint32_t dir)
{
	/* Don't focus if we don't have a current focus! */
	if (focused_win == NULL)
		return;

	struct list_item *valid_windows = NULL;
	struct list_item *desired_window = NULL;
	struct list_item *valid_window;
	struct list_item *win;

	struct win_position focus_win_pos = get_window_position(CENTER, focused_win);

	float closest_distance = -1;

	win = win_list;

	while(win != NULL) {
		/* Skip focused window */
		if (((struct client *)win->data)->window == focused_win->window) {
			win = win->next;
			continue;
		}

		/* Skip unmapped windows */
		if (!((struct client *)win->data)->mapped) {
			win = win->next;
			continue;
		}

		struct win_position win_pos = get_window_position(CENTER, (struct client *)win->data);

		valid_window = NULL;

		switch (dir) {
			case NORTH:
				if (win_pos.y < focus_win_pos.y)
					valid_window = list_add_item(&valid_windows);
				break;
			case SOUTH:
				if (win_pos.y >= focus_win_pos.y)
					valid_window = list_add_item(&valid_windows);
				break;
			case WEST:
				if (win_pos.x < focus_win_pos.x)
					valid_window = list_add_item(&valid_windows);
				break;
			case EAST:
				if (win_pos.x >= focus_win_pos.x)
					valid_window = list_add_item(&valid_windows);
				break;
		}

		if (valid_window != NULL)
			valid_window->data = win->data;

		win = win->next;
	}

	win = valid_windows;
	while(win != NULL) {
		float cur_distance;
		float cur_angle;

		cur_distance = get_distance_between_windows(focused_win, (struct client *)win->data);
		cur_angle = get_angle_between_windows(focused_win, (struct client *)win->data);

		if (is_in_valid_direction(dir, cur_angle, 10)) {
			if (is_overlapping(focused_win, (struct client *)win->data))
				cur_distance = cur_distance * 0.1;
			cur_distance = cur_distance * 0.80;
		}
		else if (is_in_valid_direction(dir, cur_angle, 25)) {
			if (is_overlapping(focused_win, (struct client *)win->data))
				cur_distance = cur_distance * 0.1;
			cur_distance = cur_distance * 0.85;
		}
		else if (is_in_valid_direction(dir, cur_angle, 35)) {
			if (is_overlapping(focused_win, (struct client *)win->data))
				cur_distance = cur_distance * 0.1;
			cur_distance = cur_distance * 0.9;
		}
		else if (is_in_valid_direction(dir, cur_angle, 50)) {
			if (is_overlapping(focused_win, (struct client *)win->data))
				cur_distance = cur_distance * 0.1;
			cur_distance = cur_distance * 3;
		}
		else {
			win = win->next;
			continue;
		}

		if (is_in_cardinal_direction(dir, focused_win, (struct client *)win->data))
			cur_distance = cur_distance * 0.9;


		if (closest_distance == -1 || (cur_distance < closest_distance)) {
			closest_distance = cur_distance;
			desired_window = win;
		}

		win = win->next;
	}

	if (desired_window != NULL)
		set_focused(desired_window->data);

	if (valid_windows != NULL)
		list_delete_all_items(&valid_windows, false);
}

void
center_pointer(struct client *client)
{
	int16_t cur_x, cur_y;
	int32_t be = outer_border_extent();

	cur_x = cur_y = 0;

	switch (conf.cursor_position) {
	case TOP_LEFT:
		cur_x = -be;
		cur_y = -be;
		break;
	case TOP_RIGHT:
		cur_x = client->geom.width + be;
		cur_y = 0 - be;
		break;
	case BOTTOM_LEFT:
		cur_x = 0 - be;
		cur_y = client->geom.height + be;
		break;
	case BOTTOM_RIGHT:
		cur_x = client->geom.width + be;
		cur_y = client->geom.height + be;
		break;
	case CENTER:
		cur_x = client->geom.width / 2;
		cur_y = client->geom.height / 2;
		break;
	default: break;
	}

	xcb_warp_pointer(conn, XCB_NONE, client->window, 0, 0, 0, 0, cur_x, cur_y);
	xcb_flush(conn);
}

/*
 * Focus last best focus (in a valid group, mapped, etc)
 */

void
set_focused_last_best()
{
	struct list_item *focused_item;
	struct client *client;

	if (focus_list == NULL)
		return;

	focused_item = focus_list->next;
	if (focused_item == NULL)
		focused_item = focus_list;

	while (focused_item != NULL) {
		client = focused_item->data;

		if (client != NULL && client->mapped) {
			set_focused(client);
			return;
		}

		focused_item = focused_item->next;
	}
}

/*
 * Clear focus without selecting another managed client.
 */

void
clear_focused(void)
{
	bool had_focus = focused_win != NULL;
	if (focused_win != NULL && !focused_win->maxed)
		set_borders(focused_win, conf.outer_unfocus_color, conf.inner_unfocus_color);

	focused_win = NULL;
	xcb_set_input_focus(conn, XCB_INPUT_FOCUS_POINTER_ROOT,
			scr->root, XCB_CURRENT_TIME);
	xcb_ewmh_set_active_window(ewmh, 0, XCB_NONE);
	update_current_desktop(NULL_GROUP);
	if (had_focus)
		invalidate_snapshot_state();
}

/*
 * Set focus state to active or inactive without raising the window.
 */

void
set_focused_no_raise(struct client *client)
{
	if (client == NULL)
		return;
	bool changed = client != focused_win;
	trace_restart("set_focused_no_raise xid=0x%08x mapped=%d old=0x%08x",
			client->window, client->mapped,
			focused_win == NULL ? XCB_NONE : focused_win->window);

	/* show window if hidden */
	if (client->frame != XCB_NONE) {
		trace_restart("map frame via focus frame=0x%08x client=0x%08x",
				client->frame, client->window);
		map_window_stacking(conn, client->frame);
	}
	trace_restart("map client via focus xid=0x%08x", client->window);
	map_window_stacking(conn, client->window);

	if (!client->maxed)
		set_borders(client, conf.outer_focus_color, conf.inner_focus_color);

	/* focus the window */
	xcb_set_input_focus(conn, XCB_INPUT_FOCUS_POINTER_ROOT,
			client->window, XCB_CURRENT_TIME);

	/* set ewmh property */
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, scr->root,
			ewmh->_NET_ACTIVE_WINDOW, XCB_ATOM_WINDOW, 32, 1, &client->window);

	/* set the focus state to inactive on the previously focused window */
	if (client != focused_win) {
		// if (focused_win != NULL && !focused_win->maxed)
		if (focused_win != NULL)
			set_borders(focused_win, conf.outer_unfocus_color, conf.inner_unfocus_color);
	}

	if (client->focus_item != NULL)
		list_move_to_head(&focus_list, client->focus_item);

	focused_win = client;
	update_current_desktop(focused_win->group);
	if (changed)
		invalidate_snapshot_state();

	window_grab_buttons(focused_win->window);
	trace_restart("focused xid=0x%08x group=%u", focused_win->window,
			focused_win->group);
}

/*
 * Focus and raise.
 */

void
set_focused(struct client *client)
{
	set_focused_no_raise(client);
	raise_client_with_frame(client);
}
