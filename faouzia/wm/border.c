// See LICENSE file for copyright and license details.

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <xcb/render.h>
#include <xcb/xcb.h>

#include "border.h"
#include "clients.h"
#include "config.h"
#include "randr.h"
#include "render.h"
#include "types.h"
#include "wm_state.h"
#include "xutil.h"

bool
using_frame_borders(void)
{
	return conf.borders && argb_visual != NULL;
}

int32_t
border_extent(void)
{
	return using_frame_borders() ? 0 : conf.border_width;
}

static void
compute_frame_geometry(struct client *client, int32_t *x, int32_t *y, uint32_t *w, uint32_t *h)
{
	int32_t bw  = conf.border_width;
	int32_t gap = conf.internal_border_width;

	switch (conf.border_style) {
		case BORDER_STYLE_SPINE_LEFT:
			*x = client->geom.x - bw - gap;
			*y = client->geom.y;
			*w = (uint32_t)(bw + gap);
			*h = client->geom.height;
			break;

		case BORDER_STYLE_SPINE_RIGHT:
			*x = client->geom.x + client->geom.width;
			*y = client->geom.y;
			*w = (uint32_t)(bw + gap);
			*h = client->geom.height;
			break;

		case BORDER_STYLE_SPINE_TOP:
			*x = client->geom.x;
			*y = client->geom.y - bw - gap;
			*w = client->geom.width;
			*h = (uint32_t)(bw + gap);
			break;

		case BORDER_STYLE_SPINE_BOTTOM:
			*x = client->geom.x;
			*y = client->geom.y + client->geom.height;
			*w = client->geom.width;
			*h = (uint32_t)(bw + gap);
			break;

		case BORDER_STYLE_CORNERS:
		case BORDER_STYLE_FRAME:
		default:
			*x = client->geom.x - bw - gap;
			*y = client->geom.y - bw - gap;
			*w = (uint32_t)(client->geom.width + 2 * (bw + gap));
			*h = (uint32_t)(client->geom.height + 2 * (bw + gap));
			break;
	}
}

void
create_frame(struct client *client)
{
	uint32_t mask;
	uint32_t values[5];

	if (client == NULL || client->frame != XCB_NONE || argb_visual == NULL)
		return;

	client->frame = xcb_generate_id(conn);

	mask = XCB_CW_BACK_PIXEL
			| XCB_CW_BORDER_PIXEL
			| XCB_CW_OVERRIDE_REDIRECT
			| XCB_CW_COLORMAP
			| XCB_CW_EVENT_MASK;

	values[0] = 0x00000000;               // BACK_PIXEL
	values[1] = 0x00000000;               // BORDER_PIXEL
	values[2] = 1;                        // OVERRIDE_REDIRECT
	values[3] = XCB_EVENT_MASK_EXPOSURE;  // EVENT_MASK
	values[4] = argb_colormap;            // COLORMAP

	int32_t x, y;
	uint32_t w, h;

	compute_frame_geometry(client, &x, &y, &w, &h);

	xcb_create_window(conn,
			32,
			client->frame,
			scr->root,
			i16_from_i32(x),
			i16_from_i32(y),
			u16_from_u32(w),
			u16_from_u32(h),
			0,
			XCB_WINDOW_CLASS_INPUT_OUTPUT,
			argb_visual->visual_id,
			mask,
			values);

	xcb_map_window(conn, client->frame);
	xcb_flush(conn);
}

void
destroy_frame(struct client *client)
{
	if (client == NULL || client->frame == XCB_NONE)
		return;

	xcb_destroy_window(conn, client->frame);
	client->frame = XCB_NONE;
}

void
paint_frame(struct client *client, uint32_t color, uint32_t internal_color)
{
	if (client == NULL ||
			client->frame == XCB_NONE ||
			!client->mapped ||
			argb_format == XCB_NONE)
		return;

	update_frame_geometry(client);

	int32_t bw  = conf.border_width;
	int32_t gap = conf.internal_border_width;

	if (bw < 0 || gap < 0)
		return;

	int32_t fx, fy;
	uint32_t w, h;

	compute_frame_geometry(client, &fx, &fy, &w, &h);

	if (w <= 0 || h <= 0)
		return;

	xcb_render_picture_t picture = xcb_generate_id(conn);
	xcb_render_create_picture(conn, picture, client->frame, argb_format, 0, NULL);

	uint32_t min_dim = 2U * u32_from_i32(bw);

	if ((conf.border_style == BORDER_STYLE_FRAME ||
			conf.border_style == BORDER_STYLE_CORNERS) &&
			(w < min_dim || h < min_dim))
		goto cleanup;

	xcb_rectangle_t clear[] = {
		RECT( 0, 0, w, h )
	};

	xcb_render_color_t transparent = {
		.red = 0, .green = 0, .blue = 0, .alpha = 0
	};

	xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC,
			picture, transparent, 1, clear);

	uint32_t a = (color >> 24) & 0xff;
	uint32_t r = (color >> 16) & 0xff;
	uint32_t g = (color >> 8)  & 0xff;
	uint32_t b =  color        & 0xff;

	xcb_render_color_t c = {
		.red   = (uint16_t)((r * a * 257u) / 255u),
		.green = (uint16_t)((g * a * 257u) / 255u),
		.blue  = (uint16_t)((b * a * 257u) / 255u),
		.alpha = (uint16_t)(a * 257U)
	};

	uint32_t ia = (internal_color >> 24) & 0xff;
	uint32_t ir = (internal_color >> 16) & 0xff;
	uint32_t ig = (internal_color >> 8)  & 0xff;
	uint32_t ib =  internal_color        & 0xff;

	xcb_render_color_t ic = {
		.red   = (uint16_t)((ir * ia * 257u) / 255u),
		.green = (uint16_t)((ig * ia * 257u) / 255u),
		.blue  = (uint16_t)((ib * ia * 257u) / 255u),
		.alpha = (uint16_t)(ia * 257U)
	};

	xcb_rectangle_t rects[MAX_BORDER_RECTS];
	xcb_rectangle_t gaps[MAX_GAP_RECTS];

	int ngaps = 0;
	int nrects = 0;

	min_dim = client->geom.width < client->geom.height
			? client->geom.width
			: client->geom.height;

	uint32_t ubw = (uint32_t)bw;
	uint32_t corner_len = (min_dim * conf.corner_percent) / 100;

	if (corner_len < ubw * 2)
		corner_len = ubw * 2;

	if (corner_len > min_dim)
		corner_len = min_dim;

	switch (conf.border_style) {
		case BORDER_STYLE_SPINE_LEFT:
			if (gap > 0)
				gaps[ngaps++] = RECT( bw, 0, gap, h );

			rects[nrects++] = RECT( 0, 0, bw, h );
			break;

		case BORDER_STYLE_SPINE_RIGHT:
			if (gap > 0)
				gaps[ngaps++] = RECT( 0, 0, gap, h );

			rects[nrects++] = RECT( gap, 0, bw, h );
			break;

		case BORDER_STYLE_SPINE_TOP:
			if (gap > 0)
				gaps[ngaps++] = RECT( 0, bw, w, gap );

			rects[nrects++] = RECT( 0, 0, w, bw );
			break;

		case BORDER_STYLE_SPINE_BOTTOM:
			if (gap > 0)
				gaps[ngaps++] = RECT( 0, 0, w, gap );

			rects[nrects++] = RECT( 0, gap, w, bw );
			break;

		case BORDER_STYLE_CORNERS:

			if (conf.corner_mask & CORNER_TOP_LEFT) {
				if (gap > 0) {
					gaps[ngaps++] = RECT( bw, bw, corner_len, gap );
					gaps[ngaps++] = RECT( bw, bw + gap, gap, corner_len );
				}

				rects[nrects++] = RECT( 0, 0, corner_len + bw + gap, bw );
				rects[nrects++] = RECT( 0, 0, bw, corner_len + bw + gap );
			}

			if (conf.corner_mask & CORNER_TOP_RIGHT) {
				if (gap > 0) {
					gaps[ngaps++] = RECT( w - bw - gap - corner_len, bw, corner_len, gap );
					gaps[ngaps++] = RECT( w - bw - gap, bw + gap, gap, corner_len );
				}

				rects[nrects++] = RECT( w - corner_len - bw - gap, 0, corner_len + bw + gap, bw );
				rects[nrects++] = RECT( w - bw, 0, bw, corner_len + bw + gap );
			}

			if (conf.corner_mask & CORNER_BOTTOM_RIGHT) {
				if (gap > 0) {
					gaps[ngaps++] = RECT( w - bw - gap - corner_len, h - bw - gap, corner_len, gap );
					gaps[ngaps++] = RECT( w - bw - gap, h - bw - gap - corner_len, gap, corner_len );
				}

				rects[nrects++] = RECT( w - corner_len - bw - gap, h - bw, corner_len + bw + gap, bw );
				rects[nrects++] = RECT( w - bw, h - corner_len - bw - gap, bw, corner_len + bw + gap );
			}

			if (conf.corner_mask & CORNER_BOTTOM_LEFT) {
				if (gap > 0) {
					gaps[ngaps++] = RECT( bw, h - bw - gap, corner_len, gap );
					gaps[ngaps++] = RECT( bw, h - bw - gap - corner_len, gap, corner_len );
				}

				rects[nrects++] = RECT( 0, h - bw, corner_len + bw + gap, bw );
				rects[nrects++] = RECT( 0, h - corner_len - bw - gap, bw, corner_len + bw + gap );
			}

			break;

		case BORDER_STYLE_FRAME:
		default:
			if (gap > 0) {
				gaps[ngaps++] = RECT( bw, bw, w - 2*bw, gap );
				gaps[ngaps++] = RECT( bw, h - bw - gap, w - 2*bw, gap );
				gaps[ngaps++] = RECT( bw, bw + gap, gap, h - 2*(bw + gap) );
				gaps[ngaps++] = RECT( w - bw - gap, bw + gap, gap, h - 2*(bw + gap) );
			}

			rects[nrects++] = RECT( 0, 0, w, bw );
			rects[nrects++] = RECT( 0, h - bw, w, bw );
			rects[nrects++] = RECT( 0, 0, bw, h );
			rects[nrects++] = RECT( w - bw, 0, bw, h );
			break;
	}

	if (ngaps > 0)
		xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC,
				picture, ic, ngaps, gaps);

	if (nrects > 0)
		xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC,
				picture, c, nrects, rects);

	cleanup:
		xcb_render_free_picture(conn, picture);
		xcb_flush(conn);
}

// void
// refresh_borders(void)
// {
// 	if (!conf.apply_settings)
// 		return;

// 	struct list_item *item;
// 	struct client *client;

// 	for (item = win_list; item != NULL; item = item->next) {
// 		client = item->data;
// 		if (client->maxed)
// 			continue;

// 		if (client == focused_win)
// 			set_borders(client, conf.focus_color, conf.internal_focus_color);
// 		else
// 			set_borders(client, conf.unfocus_color, conf.internal_unfocus_color);
// 	}
// }

void
refresh_borders(void)
{
	struct list_item *item;
	struct client *client;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;
		if (client == NULL)
			continue;

		if (!conf.borders) {
			destroy_frame(client);
			continue;
		}

		if (!client->mapped)
			continue;

		set_borders(client,
			client == focused_win ? conf.focus_color : conf.unfocus_color,
			client == focused_win ? conf.internal_focus_color : conf.internal_unfocus_color);
	}
}

void
set_borders(struct client *client, uint32_t color, uint32_t internal_color)
{
	if (client == NULL || conf.borders == false)
		return;

	if (!client->mapped) {
		if (client->frame != XCB_NONE)
			xcb_unmap_window(conn, client->frame);
		return;
	}

	create_frame(client);
	update_frame_geometry(client);
	paint_frame(client, color, internal_color);
}

void
update_frame_geometry(struct client *client)
{
	int32_t x, y;
	uint32_t w, h;
	uint32_t values[4];
	int16_t mon_x, mon_y;
	uint16_t mon_w, mon_h;

	if (client == NULL || client->frame == XCB_NONE || !client->mapped)
		return;

	compute_frame_geometry(client, &x, &y, &w, &h);

	get_monitor_size(client, &mon_x, &mon_y, &mon_w, &mon_h);

	int32_t right, bottom;
	int32_t mon_right, mon_bottom;
	int32_t delta;

	right = x + (int32_t)w;
	bottom = y + (int32_t)h;
	mon_right = (int32_t)mon_x + (int32_t)mon_w;
	mon_bottom = (int32_t)mon_y + (int32_t)mon_h;

	if (x < mon_x) {
		delta = (int32_t)mon_x - x;
		x = mon_x;
		w += (uint32_t)delta;
	}

	if (y < mon_y) {
		delta = (int32_t)mon_y - y;
		y = mon_y;
		h += (uint32_t)delta;
	}

	if (right > mon_right)
		w -= (uint32_t)(right - mon_right);

	if (bottom > mon_bottom)
		h -= (uint32_t)(bottom - mon_bottom);

	if (w == 0 || h == 0) {
		xcb_unmap_window(conn, client->frame);
		return;
	}

	values[0] = (uint32_t)x;
	values[1] = (uint32_t)y;
	values[2] = w;
	values[3] = h;

	xcb_configure_window(conn, client->frame,
			XCB_CONFIG_WINDOW_X |
			XCB_CONFIG_WINDOW_Y |
			XCB_CONFIG_WINDOW_WIDTH |
			XCB_CONFIG_WINDOW_HEIGHT,
			values);

	xcb_map_window(conn, client->frame);
}

