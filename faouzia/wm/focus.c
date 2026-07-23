// See LICENSE file for copyright and license details.

#include <tgmath.h>

#include "clients.h"
#include "focus.h"
#include "geometry.h"
#include "input.h"

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
	int32_t be = border_extent();

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
 * Set focus state to active or inactive without raising the window.
 */

void
set_focused_no_raise(struct client *client)
{
	long data[] = {
		XCB_ICCCM_WM_STATE_NORMAL,
		XCB_NONE,
	};
	if (client == NULL)
		return;

	/* show window if hidden */
	if (client->frame != XCB_NONE)
		xcb_map_window(conn, client->frame);
	xcb_map_window(conn, client->window);

	if (!client->maxed)
		set_borders(client, conf.focus_color, conf.internal_focus_color);

	/* focus the window */
	xcb_set_input_focus(conn, XCB_INPUT_FOCUS_POINTER_ROOT,
			client->window, XCB_CURRENT_TIME);

	/* set ewmh property */
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, scr->root,
			ewmh->_NET_ACTIVE_WINDOW, XCB_ATOM_WINDOW, 32, 1, &client->window);

	/* set window state */
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, client->window,
						ewmh->_NET_WM_STATE, ewmh->_NET_WM_STATE, 32, 2, data);

	/* set the focus state to inactive on the previously focused window */
	if (client != focused_win) {
		// if (focused_win != NULL && !focused_win->maxed)
		if (focused_win != NULL)
			set_borders(focused_win, conf.unfocus_color, conf.internal_unfocus_color);
	}

	if (client->focus_item != NULL)
		list_move_to_head(&focus_list, client->focus_item);

	focused_win = client;

	window_grab_buttons(focused_win->window);
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

