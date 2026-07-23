// See LICENSE file for copyright and license details.

#ifndef EVENTS_H
#define EVENTS_H

void event_button_press(xcb_generic_event_t *);
void event_circulate_request(xcb_generic_event_t *);
void event_client_message(xcb_generic_event_t *);
void event_configure_notify(xcb_generic_event_t *);
void event_configure_request(xcb_generic_event_t *);
void event_destroy_notify(xcb_generic_event_t *);
void event_enter_notify(xcb_generic_event_t *);
void event_focus_in(xcb_generic_event_t *);
void event_focus_out(xcb_generic_event_t *);
void event_map_notify(xcb_generic_event_t *);
void event_map_request(xcb_generic_event_t *);
void event_unmap_notify(xcb_generic_event_t *);

#endif

