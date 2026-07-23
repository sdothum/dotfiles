// See LICENSE file for copyright and license details.

#ifndef GEOMETRY_H
#define GEOMETRY_H

#include <stdbool.h>
#include <stdint.h>

struct client;

bool clients_overlap(struct client *a, struct client *b);

float get_angle_between_windows(
	struct client *a,
	struct client *b
);

float get_distance_between_windows(
	struct client *a,
	struct client *b
);

struct win_position get_window_position(
	uint32_t pos,
	struct client *win
);

#endif
