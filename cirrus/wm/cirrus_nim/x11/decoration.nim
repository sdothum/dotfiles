## ARGB frame realization. Geometry and paint selection arrive as model effects.
import ./bindings

{.passL: "-lxcb-render".}
{.emit: """
#include <xcb/render.h>
#include <stdlib.h>
static void cirrus_decoration_resources(xcb_connection_t *conn,
    xcb_screen_t *screen, uint32_t *visual, uint32_t *format,
    uint32_t *colormap) {
  *visual = *format = *colormap = 0;
  xcb_depth_iterator_t depth = xcb_screen_allowed_depths_iterator(screen);
  for (; depth.rem && !*visual; xcb_depth_next(&depth)) {
    if (depth.data->depth != 32) continue;
    xcb_visualtype_iterator_t v = xcb_depth_visuals_iterator(depth.data);
    for (; v.rem; xcb_visualtype_next(&v)) {
      if (v.data->_class == XCB_VISUAL_CLASS_TRUE_COLOR) {
        *visual = v.data->visual_id; break;
      }
    }
  }
  xcb_render_query_pict_formats_reply_t *reply =
    xcb_render_query_pict_formats_reply(conn,
      xcb_render_query_pict_formats(conn), NULL);
  if (reply) {
    xcb_render_pictforminfo_iterator_t f =
      xcb_render_query_pict_formats_formats_iterator(reply);
    for (; f.rem; xcb_render_pictforminfo_next(&f)) {
      if (f.data->type == XCB_RENDER_PICT_TYPE_DIRECT &&
          f.data->depth == 32 && f.data->direct.alpha_mask != 0) {
        *format = f.data->id; break;
      }
    }
    free(reply);
  }
  if (*visual && *format) {
    *colormap = xcb_generate_id(conn);
    xcb_create_colormap(conn, XCB_COLORMAP_ALLOC_NONE, *colormap,
      screen->root, *visual);
  }
}
static void cirrus_paint_decoration(xcb_connection_t *conn, uint32_t frame,
    uint32_t format, uint32_t client_width, uint32_t client_height,
    uint32_t outer_color, uint32_t inner_color, uint32_t border_style,
    uint32_t corner_mask, uint32_t corner_percent, int32_t border_width,
    int32_t inner_width) {
  if (!frame || !format) return;
  if (border_width < 0 || inner_width < 0) return;
  uint32_t bw = (uint32_t)border_width, gap = (uint32_t)inner_width;
  uint32_t w, h;
  switch (border_style) {
    case 1: w = bw + gap; h = client_height; break;
    case 2: case 3: w = client_width; h = bw + gap; break;
    case 4: w = bw + gap; h = client_height; break;
    default: w = client_width + 2 * (bw + gap); h = client_height + 2 * (bw + gap); break;
  }
  if ((border_style == 0 || border_style == 5) && (w < 2 * bw || h < 2 * bw)) return;
  uint32_t picture = xcb_generate_id(conn);
  xcb_render_create_picture(conn, picture, frame, format, 0, NULL);
  xcb_rectangle_t clear = {0, 0, w, h};
  xcb_render_color_t transparent = {0, 0, 0, 0};
  xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC, picture,
    transparent, 1, &clear);
  uint32_t oa = (outer_color >> 24) & 255, ia = (inner_color >> 24) & 255;
  xcb_render_color_t outer = {
    (((outer_color >> 16) & 255) * oa * 257u) / 255u,
    (((outer_color >> 8) & 255) * oa * 257u) / 255u,
    ((outer_color & 255) * oa * 257u) / 255u, oa * 257u};
  xcb_render_color_t inner = {
    (((inner_color >> 16) & 255) * ia * 257u) / 255u,
    (((inner_color >> 8) & 255) * ia * 257u) / 255u,
    ((inner_color & 255) * ia * 257u) / 255u, ia * 257u};
  xcb_rectangle_t rects[8], gaps[8]; int nr = 0, ng = 0;
  uint32_t minimum = client_width < client_height ? client_width : client_height;
  uint32_t cx, cy;
  if (corner_percent == 0) { cx = client_width; cy = client_height; }
  else { uint32_t corner = minimum * corner_percent / 100;
    if (corner < 2 * bw) corner = 2 * bw;
    if (corner > minimum) corner = minimum; cx = cy = corner; }
#define R(x,y,rw,rh) ((xcb_rectangle_t){(int16_t)(int32_t)(x),(int16_t)(int32_t)(y),(uint16_t)(uint32_t)(rw),(uint16_t)(uint32_t)(rh)})
  switch (border_style) {
    case 1:
      if (gap) gaps[ng++] = R(bw,0,gap,h);
      rects[nr++] = R(0,0,bw,h); break;
    case 4:
      if (gap) gaps[ng++] = R(0,0,gap,h);
      rects[nr++] = R(gap,0,bw,h); break;
    case 2:
      if (gap) gaps[ng++] = R(0,bw,w,gap);
      rects[nr++] = R(0,0,w,bw); break;
    case 3:
      if (gap) gaps[ng++] = R(0,0,w,gap);
      rects[nr++] = R(0,gap,w,bw); break;
    case 5:
      if (corner_mask & 8) {
        if (gap) { gaps[ng++]=R(bw,bw,cx,gap); gaps[ng++]=R(bw,bw+gap,gap,cy); }
        rects[nr++]=R(0,0,cx+bw+gap,bw); rects[nr++]=R(0,0,bw,cy+bw+gap);
      }
      if (corner_mask & 4) {
        if (gap) { gaps[ng++]=R(w-bw-gap-cx,bw,cx,gap); gaps[ng++]=R(w-bw-gap,bw+gap,gap,cy); }
        rects[nr++]=R(w-cx-bw-gap,0,cx+bw+gap,bw); rects[nr++]=R(w-bw,0,bw,cy+bw+gap);
      }
      if (corner_mask & 2) {
        if (gap) { gaps[ng++]=R(w-bw-gap-cx,h-bw-gap,cx,gap); gaps[ng++]=R(w-bw-gap,h-bw-gap-cy,gap,cy); }
        rects[nr++]=R(w-cx-bw-gap,h-bw,cx+bw+gap,bw); rects[nr++]=R(w-bw,h-cy-bw-gap,bw,cy+bw+gap);
      }
      if (corner_mask & 1) {
        if (gap) { gaps[ng++]=R(bw,h-bw-gap,cx,gap); gaps[ng++]=R(bw,h-bw-gap-cy,gap,cy); }
        rects[nr++]=R(0,h-bw,cx+bw+gap,bw); rects[nr++]=R(0,h-cy-bw-gap,bw,cy+bw+gap);
      }
      break;
    default:
      if (gap) { gaps[ng++]=R(bw,bw,w-2*bw,gap); gaps[ng++]=R(bw,h-bw-gap,w-2*bw,gap);
        gaps[ng++]=R(bw,bw+gap,gap,h-2*(bw+gap)); gaps[ng++]=R(w-bw-gap,bw+gap,gap,h-2*(bw+gap)); }
      rects[nr++]=R(0,0,w,bw); rects[nr++]=R(0,h-bw,w,bw);
      rects[nr++]=R(0,0,bw,h); rects[nr++]=R(w-bw,0,bw,h); break;
  }
  if (ng) xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC, picture, inner, ng, gaps);
  if (nr) xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC, picture, outer, nr, rects);
#undef R
  xcb_render_free_picture(conn, picture);
}
""".}

proc rawDecorationResources(raw: ptr XcbConnection; screen: ptr XcbScreen;
    visual, format, colormap: ptr uint32) {.importc: "cirrus_decoration_resources", nodecl.}
proc rawPaintDecoration(raw: ptr XcbConnection; frame, format, width, height,
    outerColor, innerColor, borderStyle, cornerMask, cornerPercent: uint32;
    outerBorderWidth, innerBorderWidth: int32) {.importc: "cirrus_paint_decoration", nodecl.}

proc decorationResources*(raw: ptr XcbConnection; screen: ptr XcbScreen;
    visual, format, colormap: ptr uint32) =
  rawDecorationResources(raw, screen, visual, format, colormap)

proc paintDecoration*(raw: ptr XcbConnection; frame, format, width, height,
    outerColor, innerColor, borderStyle, cornerMask, cornerPercent: uint32;
    outerBorderWidth, innerBorderWidth: int32) =
  rawPaintDecoration(raw, frame, format, width, height, outerColor, innerColor,
      borderStyle, cornerMask, cornerPercent, outerBorderWidth, innerBorderWidth)
