// See LICENSE file for copyright and license details.

#ifndef INPUT_H
#define INPUT_H

#include <stdbool.h>
#include <stdint.h>
#include <xcb/xcb.h>

enum {
	BUTTON_LEFT,
	BUTTON_MIDDLE,
	BUTTON_RIGHT,
	NR_BUTTONS
};

extern const xcb_button_index_t mouse_buttons[NR_BUTTONS];

extern uint16_t caps_lock;
extern uint16_t num_lock;
extern uint16_t scroll_lock;

void grab_buttons(void);
void ungrab_buttons(void);
void window_grab_buttons(xcb_window_t);
void window_grab_button(xcb_window_t, uint8_t, uint16_t);

bool get_pointer_location(xcb_window_t *, int16_t *, int16_t *);
bool pointer_grab(enum pointer_action);
void pointer_init(void);
int16_t pointer_modfield_from_keysym(xcb_keysym_t);
void track_pointer(struct client *, enum pointer_action, xcb_point_t);

#endif
