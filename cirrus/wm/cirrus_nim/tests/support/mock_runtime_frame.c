#include "mock_randr_runtime.c"
xcb_void_cookie_t xcb_map_window_checked(xcb_connection_t *c, xcb_window_t w) {
  (void)c; (void)w; return (xcb_void_cookie_t){1};
}
xcb_void_cookie_t xcb_unmap_window_checked(xcb_connection_t *c, xcb_window_t w) {
  (void)c; (void)w; return (xcb_void_cookie_t){1};
}
