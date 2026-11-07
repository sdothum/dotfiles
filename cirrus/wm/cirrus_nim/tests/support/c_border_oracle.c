#include <xcb/xcb.h>
#include <xcb/render.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define BORDER_STYLE_FRAME 0
#define BORDER_STYLE_SPINE_LEFT 1
#define BORDER_STYLE_SPINE_TOP 2
#define BORDER_STYLE_SPINE_BOTTOM 3
#define BORDER_STYLE_SPINE_RIGHT 4
#define BORDER_STYLE_CORNERS 5
#define CORNER_TOP_LEFT 8
#define CORNER_TOP_RIGHT 4
#define CORNER_BOTTOM_RIGHT 2
#define CORNER_BOTTOM_LEFT 1
#define MAX_BORDER_RECTS 8
#define MAX_GAP_RECTS 8
#define RECT(x,y,w,h) ((xcb_rectangle_t){(int16_t)(x),(int16_t)(y),(uint16_t)(w),(uint16_t)(h)})
struct client { uint32_t frame; int mapped; struct { int32_t x,y; uint32_t width,height; } geom; };
static struct { int32_t outer_border_width,inner_border_width; uint32_t border_style,corner_mask,corner_percent; } conf;
static xcb_connection_t *conn;
static uint32_t argb_format=3;
static uint32_t u32_from_i32(int32_t v) { return (uint32_t)v; }
void update_frame_geometry(struct client *c);
#include <stdint.h>
#include <xcb/render.h>
#include <xcb/xcb.h>

static int calls;
static int fill_count;
static uint32_t rect_count[4];
static xcb_rectangle_t captured[4][16];
static xcb_render_color_t colors[4];

void border_mock_reset(void) {
  calls = 0; fill_count = 0;
  for (int i = 0; i < 4; ++i) rect_count[i] = 0;
}
int border_mock_calls(void) { return calls; }
int border_mock_fills(void) { return fill_count; }
uint32_t border_mock_rect_count(int i) { return rect_count[i]; }
int16_t border_mock_x(int i, int j) { return captured[i][j].x; }
int16_t border_mock_y(int i, int j) { return captured[i][j].y; }
uint16_t border_mock_width(int i, int j) { return captured[i][j].width; }
uint16_t border_mock_height(int i, int j) { return captured[i][j].height; }
uint16_t border_mock_red(int i) { return colors[i].red; }
uint16_t border_mock_alpha(int i) { return colors[i].alpha; }

uint32_t xcb_generate_id(xcb_connection_t *c) { (void)c; return 77; }
xcb_void_cookie_t xcb_render_create_picture(xcb_connection_t *c,
    xcb_render_picture_t p, xcb_drawable_t d, xcb_render_pictformat_t f,
    uint32_t mask, const void *v) {
  (void)c; (void)p; (void)d; (void)f; (void)mask; (void)v;
  ++calls; return (xcb_void_cookie_t){0};
}
xcb_void_cookie_t xcb_render_fill_rectangles(xcb_connection_t *c,
    uint8_t op, xcb_render_picture_t p, xcb_render_color_t color,
    uint32_t n, const xcb_rectangle_t *r) {
  (void)c; (void)op; (void)p;
  int i = fill_count++;
  ++calls;
  if (i < 4) {
    colors[i] = color;
    rect_count[i] = n > 16 ? 16 : n;
    for (uint32_t j = 0; j < rect_count[i]; ++j) captured[i][j] = r[j];
  }
  return (xcb_void_cookie_t){0};
}
xcb_void_cookie_t xcb_render_free_picture(xcb_connection_t *c,
    xcb_render_picture_t p) {
  (void)c; (void)p; ++calls; return (xcb_void_cookie_t){0};
}

static uint32_t configured[4];
int xcb_flush(xcb_connection_t *c) { (void)c; return 1; }
static void get_monitor_size(struct client *c, int16_t *x,int16_t *y,uint16_t *w,uint16_t *h) { (void)c; *x=*y=0; *w=1024; *h=768; }
static void map_window_stacking(xcb_connection_t *c,uint32_t w) { (void)c;(void)w; }
xcb_void_cookie_t xcb_configure_window(xcb_connection_t *c,xcb_window_t w,uint16_t mask,const void *v) { (void)c;(void)w;(void)mask;memcpy(configured,v,sizeof configured);return (xcb_void_cookie_t){0}; }
xcb_void_cookie_t xcb_unmap_window(xcb_connection_t *c,xcb_window_t w) { (void)c;(void)w;return (xcb_void_cookie_t){0}; }
uint16_t border_mock_green(int i) { return colors[i].green; }
uint16_t border_mock_blue(int i) { return colors[i].blue; }
static void
compute_frame_geometry(struct client *client, int32_t *x, int32_t *y, uint32_t *w, uint32_t *h)
{
	int32_t bw  = conf.outer_border_width;
	int32_t gap = conf.inner_border_width;

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

	map_window_stacking(conn, client->frame);
}
void
paint_frame(struct client *client, uint32_t outer_color, uint32_t inner_color)
{
	if (client == NULL ||
			client->frame == XCB_NONE ||
			!client->mapped ||
			argb_format == XCB_NONE)
		return;

	update_frame_geometry(client);

	int32_t bw  = conf.outer_border_width;
	int32_t gap = conf.inner_border_width;

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

	uint32_t a = (outer_color >> 24) & 0xff;
	uint32_t r = (outer_color >> 16) & 0xff;
	uint32_t g = (outer_color >> 8)  & 0xff;
	uint32_t b =  outer_color        & 0xff;

	xcb_render_color_t c = {
		.red   = (uint16_t)((r * a * 257u) / 255u),
		.green = (uint16_t)((g * a * 257u) / 255u),
		.blue  = (uint16_t)((b * a * 257u) / 255u),
		.alpha = (uint16_t)(a * 257U)
	};

	uint32_t ia = (inner_color >> 24) & 0xff;
	uint32_t ir = (inner_color >> 16) & 0xff;
	uint32_t ig = (inner_color >> 8)  & 0xff;
	uint32_t ib =  inner_color        & 0xff;

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
	uint32_t corner_len_x;
	uint32_t corner_len_y;

	if (conf.corner_percent == 0) {
		corner_len_x = client->geom.width;
		corner_len_y = client->geom.height;
	} else {
		uint32_t corner_len = (min_dim * conf.corner_percent) / 100;

		if (corner_len < ubw * 2)
			corner_len = ubw * 2;

		if (corner_len > min_dim)
			corner_len = min_dim;

		corner_len_x = corner_len;
		corner_len_y = corner_len;
	}

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
					gaps[ngaps++] = RECT( bw, bw, corner_len_x, gap );
					gaps[ngaps++] = RECT( bw, bw + gap, gap, corner_len_y );
				}

				rects[nrects++] = RECT( 0, 0, corner_len_x + bw + gap, bw );
				rects[nrects++] = RECT( 0, 0, bw, corner_len_y + bw + gap );
			}

			if (conf.corner_mask & CORNER_TOP_RIGHT) {
				if (gap > 0) {
					gaps[ngaps++] = RECT(
							w - bw - gap - corner_len_x,
							bw,
							corner_len_x,
							gap);

					gaps[ngaps++] = RECT(
							w - bw - gap,
							bw + gap,
							gap,
							corner_len_y);
				}

				rects[nrects++] = RECT(
						w - corner_len_x - bw - gap,
						0,
						corner_len_x + bw + gap,
						bw);

				rects[nrects++] = RECT(
						w - bw,
						0,
						bw,
						corner_len_y + bw + gap);
			}

			if (conf.corner_mask & CORNER_BOTTOM_RIGHT) {
				if (gap > 0) {
					gaps[ngaps++] = RECT(
							w - bw - gap - corner_len_x,
							h - bw - gap,
							corner_len_x,
							gap);

					gaps[ngaps++] = RECT(
							w - bw - gap,
							h - bw - gap - corner_len_y,
							gap,
							corner_len_y);
				}

				rects[nrects++] = RECT(
						w - corner_len_x - bw - gap,
						h - bw,
						corner_len_x + bw + gap,
						bw);

				rects[nrects++] = RECT(
						w - bw,
						h - corner_len_y - bw - gap,
						bw,
						corner_len_y + bw + gap);
			}

			if (conf.corner_mask & CORNER_BOTTOM_LEFT) {
				if (gap > 0) {
					gaps[ngaps++] = RECT(
							bw,
							h - bw - gap,
							corner_len_x,
							gap);

					gaps[ngaps++] = RECT(
							bw,
							h - bw - gap - corner_len_y,
							gap,
							corner_len_y);
				}

				rects[nrects++] = RECT(
						0,
						h - bw,
						corner_len_x + bw + gap,
						bw);

				rects[nrects++] = RECT(
						0,
						h - corner_len_y - bw - gap,
						bw,
						corner_len_y + bw + gap);
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
void reference_geometry(uint32_t style,int32_t bw,int32_t gap,int32_t x,int32_t y,uint32_t w,uint32_t h,int clip,uint32_t *out) {
 conf.border_style=style;conf.outer_border_width=bw;conf.inner_border_width=gap;
 struct client c={.frame=2,.mapped=1,.geom={x,y,w,h}};
 if(clip) { update_frame_geometry(&c);memcpy(out,configured,sizeof configured); }
 else { int32_t fx,fy;compute_frame_geometry(&c,&fx,&fy,&out[2],&out[3]);out[0]=(uint32_t)fx;out[1]=(uint32_t)fy; }
}
void reference_paint(uint32_t style,uint32_t mask,uint32_t percent,int32_t bw,int32_t gap,uint32_t w,uint32_t h,uint32_t outer,uint32_t inner) {
 conf.border_style=style;conf.corner_mask=mask;conf.corner_percent=percent;conf.outer_border_width=bw;conf.inner_border_width=gap;
 struct client c={.frame=2,.mapped=1,.geom={160,180,w,h}};
 paint_frame(&c,outer,inner);
}
