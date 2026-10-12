## Runtime modifier discovery used by the frozen-C passive pointer-grab policy.

import ./bindings

{.emit: """
#include <xcb/xcb_keysyms.h>
#include <xcb/xcb.h>
#include <X11/keysym.h>
#include <stdlib.h>
static uint16_t cirrus_pointer_modifier_mask(xcb_connection_t *c, xcb_keysym_t sym) {
  uint16_t mask = 0;
  xcb_key_symbols_t *symbols = xcb_key_symbols_alloc(c);
  xcb_keycode_t *codes = symbols ? xcb_key_symbols_get_keycode(symbols, sym) : NULL;
  xcb_get_modifier_mapping_cookie_t ck = xcb_get_modifier_mapping(c);
  xcb_get_modifier_mapping_reply_t *r = xcb_get_modifier_mapping_reply(c, ck, NULL);
  if (codes && r && r->keycodes_per_modifier) {
    xcb_keycode_t *mods = xcb_get_modifier_mapping_keycodes(r);
    int n = xcb_get_modifier_mapping_keycodes_length(r);
    for (int i = 0; i < n; ++i) {
      if (!mods[i]) continue;
      for (xcb_keycode_t *p = codes; *p; ++p)
        if (*p == mods[i]) mask |= (uint16_t)(1u << (i / r->keycodes_per_modifier));
    }
  }
  free(codes);
  free(r);
  if (symbols) xcb_key_symbols_free(symbols);
  return mask;
}
static uint32_t cirrus_pointer_modifier_masks(xcb_connection_t *c) {
  return (uint32_t)(uint8_t)cirrus_pointer_modifier_mask(c, XK_Num_Lock) |
      ((uint32_t)(uint8_t)cirrus_pointer_modifier_mask(c, XK_Caps_Lock) << 8) |
      ((uint32_t)(uint8_t)cirrus_pointer_modifier_mask(c, XK_Scroll_Lock) << 16);
}
static uint16_t cirrus_default_pointer_modifier(void) { return XCB_MOD_MASK_4; }
""".}
{.passL: "-lxcb-keysyms".}

proc rawPointerModifierMasks(connection: ptr XcbConnection): uint32 {.importc: "cirrus_pointer_modifier_masks", nodecl.}
proc rawDefaultPointerModifier(): uint16 {.importc: "cirrus_default_pointer_modifier", nodecl.}

proc defaultPointerModifier*(): uint16 = rawDefaultPointerModifier()

proc discoverPointerLockMasks*(connection: ptr XcbConnection): array[3, uint16] =
  let packed = rawPointerModifierMasks(connection)
  result[0] = uint16(packed and 0xff'u32)
  result[1] = uint16((packed shr 8) and 0xff'u32)
  result[2] = uint16((packed shr 16) and 0xff'u32)
