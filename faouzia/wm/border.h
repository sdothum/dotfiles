// See LICENSE file for copyright and license details.

#ifndef BORDER_H
#define BORDER_H

#include <stdbool.h>
#include <stdint.h>

#define CORNER_TOP_LEFT     (1 << 3)  // NOTE: see gaps (sirocco script)
#define CORNER_TOP_RIGHT    (1 << 2)
#define CORNER_BOTTOM_RIGHT (1 << 1)
#define CORNER_BOTTOM_LEFT  (1 << 0)

#define MAX_BORDER_RECTS 8
#define MAX_GAP_RECTS 8

#define RECT(rx, ry, rw, rh)                 \
	((xcb_rectangle_t){                       \
		.x = i16_from_i32((int32_t)(rx)),      \
		.y = i16_from_i32((int32_t)(ry)),      \
		.width = u16_from_u32((uint32_t)(rw)), \
		.height = u16_from_u32((uint32_t)(rh)) \
	})

struct client;

bool using_frame_borders(void);

int32_t border_extent(void);

void create_frame(struct client *);
void destroy_frame(struct client *);
void paint_frame(struct client *client, uint32_t color, uint32_t internal_color);
void refresh_borders(void);
void set_borders(struct client *, uint32_t, uint32_t);
void update_frame_geometry(struct client *);

#endif
