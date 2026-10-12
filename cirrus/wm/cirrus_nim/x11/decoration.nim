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
    uint32_t format, uint32_t width, uint32_t height, uint32_t color) {
  if (!frame || !format) return;
  /* Frozen default: corners, width 5, gap 0, 28%, TL and BR. */
  uint32_t w = width + 10, h = height + 10;
  uint32_t minimum = width < height ? width : height;
  uint32_t corner = minimum * 28 / 100;
  if (corner < 10) corner = 10;
  if (corner > minimum) corner = minimum;
  uint32_t picture = xcb_generate_id(conn);
  xcb_render_create_picture(conn, picture, frame, format, 0, NULL);
  xcb_rectangle_t clear = {0, 0, w, h};
  xcb_render_color_t transparent = {0, 0, 0, 0};
  xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC, picture,
    transparent, 1, &clear);
  uint32_t a = color >> 24;
  xcb_render_color_t c = {
    (((color >> 16) & 255) * a * 257u) / 255u,
    (((color >> 8) & 255) * a * 257u) / 255u,
    ((color & 255) * a * 257u) / 255u, a * 257u};
  xcb_rectangle_t rectangles[] = {
    {0, 0, corner + 5, 5}, {0, 0, 5, corner + 5},
    {w - corner - 5, h - 5, corner + 5, 5},
    {w - 5, h - corner - 5, 5, corner + 5}};
  xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC, picture,
    c, 4, rectangles);
  xcb_render_free_picture(conn, picture);
}
""".}

proc rawDecorationResources(raw: ptr XcbConnection; screen: ptr XcbScreen;
    visual, format, colormap: ptr uint32) {.importc: "cirrus_decoration_resources", nodecl.}
proc rawPaintDecoration(raw: ptr XcbConnection; frame, format, width, height,
    color: uint32) {.importc: "cirrus_paint_decoration", nodecl.}

proc decorationResources*(raw: ptr XcbConnection; screen: ptr XcbScreen;
    visual, format, colormap: ptr uint32) =
  rawDecorationResources(raw, screen, visual, format, colormap)

proc paintDecoration*(raw: ptr XcbConnection; frame, format, width, height,
    color: uint32) =
  rawPaintDecoration(raw, frame, format, width, height, color)
