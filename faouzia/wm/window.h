// See LICENSE file for copyright and license details.

#ifndef WINDOW_H
#define WINDOW_H

#include <stdint.h>
#include <xcb/xcb.h>
#include <xcb/xcb_icccm.h>

struct client;

void close_window(struct client *);
void cycle_window_in_group(struct client *);
void cycle_window(struct client *);
void delete_window(xcb_window_t);
void raise_window(xcb_window_t);
void rcycle_window_in_group(struct client *);
void rcycle_window(struct client *);
void window_hide(struct client *);

void fit_on_screen(struct client *);
void maximize_window(struct client *, int16_t, int16_t, uint16_t, uint16_t);
void hmaximize_window(struct client *, int16_t, uint16_t);
void vmaximize_window(struct client *, int16_t, uint16_t);
void monocle_window(struct client *, int16_t, int16_t, uint16_t, uint16_t);

void resize_grid_window(struct client *, uint16_t, uint16_t);
void resize_window_absolute(xcb_window_t, uint16_t, uint16_t);
void resize_window(xcb_window_t, int16_t, int16_t);

void grid_window(struct client *, uint16_t, uint16_t, uint16_t, uint16_t, uint16_t, uint16_t);
void move_grid_window(struct client *, uint16_t, uint16_t);
void move_window(xcb_window_t, int16_t, int16_t);
void snap_window(struct client *, enum position);
void teleport_window(xcb_window_t, int16_t, int16_t);

#endif
