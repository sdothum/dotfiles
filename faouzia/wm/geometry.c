// See LICENSE file for copyright and license details.

#include <math.h>
#include <stdbool.h>
#include <stdint.h>

#include "clients.h"
#include "constants.h"
#include "geometry.h"
#include "types.h"

/*
 * Set window to the top or bottom of the window stack depending on where it is now.
 */

bool
clients_overlap(struct client *a, struct client *b)
{
	int ax1, ay1, ax2, ay2;
	int bx1, by1, bx2, by2;

	if (a == NULL || b == NULL || a == b)
		return false;

	ax1 = a->geom.x;
	ay1 = a->geom.y;
	ax2 = a->geom.x + a->geom.width;
	ay2 = a->geom.y + a->geom.height;

	bx1 = b->geom.x;
	by1 = b->geom.y;
	bx2 = b->geom.x + b->geom.width;
	by2 = b->geom.y + b->geom.height;

	return ax1 < bx2 && ax2 > bx1 &&
			ay1 < by2 && ay2 > by1;
}

float
get_angle_between_windows(struct client *a, struct client *b)
{
	struct win_position a_pos = get_window_position(CENTER, a);
	struct win_position b_pos = get_window_position(CENTER, b);

	float dx = (float)(b_pos.x - a_pos.x);
	float dy = (float)(b_pos.y - a_pos.y);

	if (dx == 0.0 && dy == 0.0)
		return 0.0;

	return atan2(dx,dy) * (180 / PI);
}

float
get_distance_between_windows(struct client *a, struct client *b)
{
	struct win_position a_pos = get_window_position(CENTER, a);
	struct win_position b_pos = get_window_position(CENTER, b);

	float distance = hypot((float)(b_pos.x - a_pos.x), (float)(b_pos.y - a_pos.y));
	return distance;
}

struct win_position
get_window_position(uint32_t mode, struct client *win)
{
	struct win_position pos;
	pos.x = 0;
	pos.y = 0;

	switch (mode) {
		case CENTER:
			pos.x = win->geom.x + (win->geom.width / 2);
			pos.y = win->geom.y + (win->geom.height / 2);
			break;
		case TOP_LEFT:
			pos.x = win->geom.x;
			pos.y = win->geom.y;
			break;
		case TOP_RIGHT:
			pos.x = win->geom.x + win->geom.width;
			pos.y = win->geom.y;
			break;
		case BOTTOM_RIGHT:
			pos.x = win->geom.x + win->geom.width;
			pos.y = win->geom.y + win->geom.height;
			break;
		case BOTTOM_LEFT:
			pos.x = win->geom.x;
			pos.y = win->geom.y + win->geom.height;
			break;
	}
	return pos;
}


