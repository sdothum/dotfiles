// See LICENSE file for copyright and license details.

#ifndef RENDER_H
#define RENDER_H

#include <xcb/render.h>

extern xcb_colormap_t argb_colormap;
extern xcb_render_pictformat_t argb_format;
extern xcb_render_query_pict_formats_reply_t *pictformats;
extern xcb_visualtype_t *argb_visual;

#endif
