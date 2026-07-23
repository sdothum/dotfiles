// See LICENSE file for copyright and license details.

#ifndef SETUP_H
#define SETUP_H

int setup(void);
int setup_randr(void);

void cleanup(void);
void load_config(char *config_path);
void load_defaults(void);
void register_event_handlers(void);

xcb_render_pictformat_t find_argb_format(void);
xcb_visualtype_t *find_argb_visual(void);

#endif

