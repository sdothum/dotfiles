#include <stdlib.h>
#include <stdint.h>
#include <xcb/xcb.h>
#include <xcb/randr.h>

typedef struct {
  uint32_t output;
  int16_t x, y;
  uint16_t width, height;
  uint8_t active;
} CirrusRandrMonitor;

__attribute__((weak)) int cirrus_randr_initialize(xcb_connection_t *connection) {
  const xcb_query_extension_reply_t *extension =
      xcb_get_extension_data(connection, &xcb_randr_id);
  if (extension == NULL || !extension->present) return -1;
  return extension->first_event;
}

__attribute__((weak)) void cirrus_randr_select(xcb_connection_t *connection, xcb_window_t root) {
  xcb_randr_select_input(connection, root,
      XCB_RANDR_NOTIFY_MASK_SCREEN_CHANGE |
      XCB_RANDR_NOTIFY_MASK_OUTPUT_CHANGE |
      XCB_RANDR_NOTIFY_MASK_CRTC_CHANGE |
      XCB_RANDR_NOTIFY_MASK_OUTPUT_PROPERTY);
}

__attribute__((weak)) int cirrus_randr_snapshot(xcb_connection_t *connection, xcb_window_t root,
    CirrusRandrMonitor **monitors_out) {
  *monitors_out = NULL;
  xcb_randr_get_screen_resources_current_reply_t *resources =
      xcb_randr_get_screen_resources_current_reply(connection,
          xcb_randr_get_screen_resources_current(connection, root), NULL);
  if (resources == NULL) return -1;
  int outputs_count = xcb_randr_get_screen_resources_current_outputs_length(resources);
  xcb_randr_output_t *outputs =
      xcb_randr_get_screen_resources_current_outputs(resources);
  CirrusRandrMonitor *monitors = calloc(outputs_count ? outputs_count : 1,
      sizeof(*monitors));
  if (monitors == NULL) { free(resources); return -1; }
  int count = 0;
  for (int index = 0; index < outputs_count; index++) {
    xcb_randr_get_output_info_reply_t *output =
        xcb_randr_get_output_info_reply(connection,
            xcb_randr_get_output_info(connection, outputs[index],
                resources->config_timestamp), NULL);
    if (output == NULL) continue;
    if (output->crtc == XCB_NONE) {
      monitors[count++] = (CirrusRandrMonitor){outputs[index], 0, 0, 0, 0, 0};
      free(output);
      continue;
    }
    xcb_randr_get_crtc_info_reply_t *crtc =
        xcb_randr_get_crtc_info_reply(connection,
            xcb_randr_get_crtc_info(connection, output->crtc,
                resources->config_timestamp), NULL);
    if (crtc == NULL) { free(output); break; }
    int clone = 0;
    for (int existing = 0; existing < count; existing++)
      if (monitors[existing].output != outputs[index] &&
          monitors[existing].x == crtc->x && monitors[existing].y == crtc->y)
        clone = 1;
    if (!clone) {
      monitors[count++] = (CirrusRandrMonitor){outputs[index], crtc->x,
          crtc->y, crtc->width, crtc->height, 1};
    }
    free(crtc);
    free(output);
  }
  free(resources);
  *monitors_out = monitors;
  return count;
}

__attribute__((weak)) void cirrus_randr_free(CirrusRandrMonitor *monitors) { free(monitors); }
