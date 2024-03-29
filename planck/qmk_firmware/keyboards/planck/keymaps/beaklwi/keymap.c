// sdothum - 2016 (c) wtfpl

// This is the canonical layout file for the Quantum project. If you want to add another keyboard,
// this is the style you want to emulate.
//
// To flash corne / chimera / planck firmware
// ═════════════════════════
//   Reset keyboard or press hw reset button on base
//
//   cd qmk_firmware/keyboards/<keyboard>
//   sudo make KEYMAP=<keymap> dfu
//
//   sudo make clean           (good practice before flashing)
//   sudo make KEYMAP=<keymap> (to compile check)
//
// Package requirements (for arch linux)
// ═════════════════════════════════════
//   avr-gcc-atmel
//   avr-libc-atmel
//   dfu-programmer
//
// Notes
// ═════
//   ** E R G O   W I D E   S P L I T ** Layout
//
//   Autocompletion tap dance key pairs (),[],{} are available from the
//   number/symbol layer, as well as, numerous (un)shift key values
//
//   #define PRIVATE_STRING includes private_string.h, a user defined code
//   block for the PRIV tap dance e.g. SEND_STRING("secret messape"),
//   see function private()
//
// Code
// ════
//   This source is shamelessly based on the "default" planck layout
//
//   #ifdef/#endif block structures are not indented, as syntax highlighting
//   in vim is sufficient for identification
//
//   c++ commenting style is used throughout
//
// Change history
// ══════════════
//   See http://thedarnedestthing.com/colophon
//
//                === N O T E ===
//
// sudo CPATH=<keymap.c directory>/common make ...

// Hardware
// ═════════════════════════════════════════════════════════════════════════════

#include "hardware.h"

// Keymaps
// ═════════════════════════════════════════════════════════════════════════════

extern keymap_config_t keymap_config;

// ...................................................................... Layers

enum keyboard_layers {
  _BASE = 0
 ,_SHIFT
 ,_TTCAPS
 ,_SYMGUI
 ,_REGEX
 ,_MOUSE
 ,_NUMBER
 ,_FNCKEY
 ,_EDIT
 ,_TTBASEL
 ,_TTBASER
 ,_TTFNCKEY
 ,_TTCURSOR
 ,_TTMOUSE
 ,_TTNUMBER
 ,_TTREGEX
#ifdef STENO_ENABLE
 ,_PLOVER
#endif
#ifdef PLANCK
 ,_ADJUST
#endif
#ifdef TEST
 ,_TEST
#endif
 ,_END_LAYERS
};

// .................................................................... Keycodes

#include "keycodes.h"

// .............................................................. Tapdance Codes

#include "tapcodes.h"

// Layouts
// ═════════════════════════════════════════════════════════════════════════════

// map to new #defines..
#define KEYMAP LAYOUT_planck_grid
// ..current qmk master

// ........................................................ Default Alpha Layout

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {

#include "base_layout.h"

// ............................................................... Plover Layout
 
#ifdef STENO_ENABLE
#include "steno_layout.h"
#endif

// ...................................................... Number / Function Keys

#include "number_fkey_layout.h"

// ......................................................... Symbol / Navigation

#include "symbol_guifn_layout.h"

// ............................................................... Toggle Layers

#include "toggle_layout.h"

// .............................................................. Mouse / Chords

#include "mouse_chord_layout.h"

};

// User Keycode Trap
// ═════════════════════════════════════════════════════════════════════════════

#include "keycode_functions.c"
#include "tapdance.c"

// ..................................................... Dynamic Pinkie Stagger!

static uint16_t pinkies[][3] = { {KC_X, KC_V, KC_Z},    // ZVX beakl wi (row 3 -> 1)
                                 {KC_V, KC_X, KC_Z},    // ZXV beakl wi-v
                                 {KC_V, KC_Z, KC_X} };  // XZV beakl wi-x
static uint8_t  stagger      = PINKIE_STAGGER;          // pinkie on (0) home row (1,2) bottom row stagger variant, see case STAGGER

#define PINKIE(r) pinkies[stagger][r - 1]

// ............................................................... Keycode Cycle

static uint16_t first_tap = 0;     // tap timer (time) first (0) second

#define DOUBLETAP         if (KEY_DOWN) { first_tap = KEY_TAPPED(first_tap) ? 0 : timer_read(); }
#define LEADERCAP         leadercap = KEY_DOWN ? 1 : 0
#define MOD_ROLL(m, k, c) mod_roll(record, m, LOWER, k, c)

bool process_record_user(uint16_t keycode, keyrecord_t *record)
{
#ifdef CORNE
  if (record->event.pressed) {
#ifdef SSD1306OLED
    set_keylog(keycode, record);
#endif
    // set_timelog();
  }
#endif

// ...................................................... Smart Keypad Delimiter

static uint16_t postfix    = KC_SPC;  // see case DELIM
static bool     numerating = 0;       // see case LT_TAB
static bool     smart      = 1;       // see case SMART

#ifdef SMART_DELIM
  if (numerating && smart) {
    switch (keycode) {
    case KC_0:  LEADERCAP;  // DELIM -> 0x
    case KC_1:
    case KC_2:
    case KC_3:
    case KC_4:
    case KC_5:
    case KC_6:
    case KC_7:
    case KC_8:
    case KC_9:
      postfix = KC_G;       // Vim ..G'oto
      break;
    case DELIM:
      break;                // apply context rule
    default:
      postfix = KC_SPC;
    }
  } else { postfix = KC_SPC; }
#endif

// Home Row
// ═════════════════════════════════════════════════════════════════════════════

// .......................................................... Home Row Modifiers

  switch (keycode) {

#ifdef ROLLING
#define HOME_ROLL(m, k, c) MOD_ROLL(m, k, c); break

  case HOME_Q:  HOME_ROLL(KC_LGUI, KC_Q,      0);
  case HOME_H:  HOME_ROLL(KC_LCTL, KC_H,      1);
  case HOME_E:  HOME_ROLL(KC_LALT, KC_E,      2);
  case HOME_A:
    LEADERCAP;  HOME_ROLL(KC_LSFT, KC_A,      3);  // space/enter + shift shortcut, see leader_cap()

  case HOME_T:  HOME_ROLL(KC_RSFT, KC_T,      6);
  case HOME_R:  HOME_ROLL(KC_RALT, KC_R,      7);
  case HOME_S:  HOME_ROLL(KC_RCTL, KC_S,      8);
  case PINKY2:  HOME_ROLL(KC_RGUI, PINKIE(2), 9);

#else
#define HOME_MOD(k) if (KEY_UP) { unregister_code(k); }; MOD_BITS(k); break

  case HOME_A:
    LEADERCAP;  HOME_MOD(KC_LSFT);                 // space/enter + shift shortcut, see leader_cap()
  case HOME_T:  HOME_MOD(KC_RSFT);
  case PINKY2:  toggle(record, KC_RGUI, PINKIE(2)); break;
#endif

// Thumb Keys
// ═════════════════════════════════════════════════════════════════════════════

#ifdef SPLITOGRAPHY
#include "steno_thumbs_keymap.c"
#else

// ............................................................. Left Thumb Keys

  case TT_ESC:  base_layer(0); return false;     // exit TT layer
  case LT_ESC:  if (tt_keycode) { base_layer(0); return false; }; break;

  case LT_I:
#ifdef ROLLING
#ifdef LEFT_SPC_ENT
    if (roll_shift(record, KC_LSFT, LOWER, KC_SPC, 4)) { return false; }  // non-autorepeating
#endif
    if (MOD_ROLL(0, KC_I, 4))                          { return false; }  // MO(_REGEX) -> LT(_REGEX, KC_I)
#else
#ifdef LEFT_SPC_ENT
    if (map_shift(record, KC_LSFT, LOWER, KC_SPC))     { return false; }
#endif
#endif
    break;
  case TT_I:  layer_toggle(record, _REGEX, UPPER, KC_I); break;

  case LT_TAB:
    numerating = KEY_DOWN ? 1 : 0;
#ifdef LEFT_SPC_ENT
    if (map_shift(record, KC_LSFT, LOWER, KC_ENT)) { return false; }
#endif
    if (map_shift(record, KC_LSFT, UPPER, KC_ENT)) { return false; }
    break;

// ............................................................ Right Thumb Keys

#ifdef ROLLING
  case LT_ENT:  leaderlayer = _EDIT; if (MOD_ROLL(0, KC_ENT, 10)) { return false; }; break;  // KC_ENT -> enter shift
  case KC_ENT:                       if (MOD_ROLL(0, KC_ENT, 10)) { return false; }; break;  // KC_ENT from LT_ENT -> enter enter* shift
#else
  case LT_ENT:  if (leader_cap(record, _EDIT, KC_ENT))            { return false; }; break;  // KC_ENT -> enter shift
  case KC_ENT:  if (leader_cap(record, _BASE, KC_ENT))            { return false; }; break;  // KC_ENT from LT_ENT -> enter enter* shift
#endif

  case LT_SPC:
#ifdef ROLLING
    leaderlayer = _SYMGUI; if (MOD_ROLL(0, KC_SPC, 11)) { return false; }  // KC_SPC -> space shift
#else
    if (leader_cap(record, _SYMGUI, KC_SPC))            { return false; }  // KC_SPC -> space shift
#endif
    break;
  case TT_SPC:  layer_toggle(record, _SYMGUI, LOWER, KC_SPC); break;
  case KC_SPC:  if (KEY_UP) { CLR_1SHOT; }; break;  // see leader_cap()

  case LT_BSPC:
  case KC_BSPC:
    if (KEY_UP) { CLR_1SHOT; }                      // see leader_cap()
    if (map_shift(record, KC_LSFT, LOWER, KC_DEL)) { layer_off(_SYMGUI); return false; }  // rolling cursor to del
    if (map_shift(record, KC_RSFT, LOWER, KC_DEL)) { return false; }
    break;
#endif

// Key Pad
// ═════════════════════════════════════════════════════════════════════════════

// .................................................................... HEX Keys

static bool hexcase = HEXADECIMAL_CASE;  // hex case (0) lower case abcdef (1) upper case ABCDEF, see case HEXCASE

#ifdef ROLLING
#define HEX(m, k, c) mod_roll(record, m, hexcase, k, c); break

  case HEX_A:  HEX(0,                   KC_A, 1);
  case HEX_B:  HEX(MOD_LALT | MOD_LCTL, KC_B, 2);
  case HEX_C:  HEX(0,                   KC_C, 3);
  case HEX_D:  HEX(KC_LCTL,             KC_D, 1);
  case HEX_E:  HEX(KC_LALT,             KC_E, 2);
  case HEX_F:  HEX(KC_LSFT,             KC_F, 3);

#else
#define HEX(m, k) mod_tap(record, m, hexcase, k)

  case HEX_A:  HEX(0,                   KC_A);
  case HEX_B:  HEX(MOD_LALT | MOD_LCTL, KC_B);
  case HEX_C:  HEX(0,                   KC_C);
  case HEX_D:  HEX(KC_LCTL,             KC_D);
  case HEX_E:  HEX(KC_LALT,             KC_E);
  case HEX_F:  HEX(KC_LSFT,             KC_F);
#endif

// ......................................................... Numpad Bracket Keys

static uint16_t brkts[][3] = { {LOWER, KC_LBRC, KC_RBRC},    // [] (side 1 -> 2)
                               {UPPER, KC_9,    KC_0},       // ()
                               {UPPER, KC_LCBR, KC_RCBR} };  // {}
static uint8_t  brktype    = 0;                              // default (0) [], see case BRKTYPE

#ifdef ROLLING
#define BRACKET(m, s, c) mod_roll(record, m, brkts[brktype][0], brkts[brktype][s], c); break

  case L_BRKT:  BRACKET(0,                   LEFT,  1);
  case R_BRKT:  BRACKET(MOD_LALT | MOD_LSFT, RIGHT, 2);

#else
#define BRACKET(m, s) mod_tap(record, m, brkts[brktype][0], brkts[brktype][s]); break

  case L_BRKT:  BRACKET(0,                   LEFT);
  case R_BRKT:  BRACKET(MOD_LALT | MOD_LSFT, RIGHT);
#endif

// ............................................................. Smart Delimiter

#define POSTCASE postfix == KC_G ? UPPER : LOWER

  case DELIM:
#ifdef ROLLING
    if (leadercap) { mod_roll(record, _BASE, LOWER,    KC_X,    3); }  // 0x
    else           { mod_roll(record, _BASE, POSTCASE, postfix, 3); }  // smart vim goto
#else
    if (leadercap) { mod_tap(record, _BASE, LOWER,    KC_X); }         // 0x
    else           { mod_tap(record, _BASE, POSTCASE, postfix); }      // smart vim goto
#endif
    break;

// Symbols
// ═════════════════════════════════════════════════════════════════════════════

// ........................................................... Shift Mapped Keys

#ifndef HASKELL
  case HS_GT:  mod_tap(record, KC_LSFT, UPPER, KC_DOT);  break;
  case HS_LT:  mod_tap(record, KC_LCTL, UPPER, KC_COMM); break;
#endif

// ......................................................... Shift Mapped Leader

#ifdef ROLLING
#define MAP(k, c) LEADERCAP; if (map_shift_event(record, KC_RSFT, LOWER, k, c)) { return false; }; break

  case HS_COLN:  MAP(KC_SCLN, 0);  // semi/colon + space/enter + shift shortcut, see leader_cap()
  case KC_COMM:  MAP(KC_GRV,  1);  // comma + space/enter + shift shortcut, see leader_cap()

#else
#define MAP(k) LEADERCAP; if (map_shift(record, KC_RSFT, LOWER, k)) { return false; }; break

  case HS_COLN:  MAP(KC_SCLN);     // semi/colon + space/enter + shift shortcut, see leader_cap()
  case KC_COMM:  MAP(KC_GRV);      // comma + space/enter + shift shortcut, see leader_cap()
#endif

// .................................................... (Shift) Mapped Tap Dance

  case KC_DOT:
#ifdef UNIX
#define TILDE_SLASH first_tap ? UPPER : LOWER, first_tap ? KC_GRV : KC_SLSH

#ifdef ROLLING
    LEADERCAP;  DOUBLETAP; if (map_shift_event(record, KC_RSFT, TILDE_SLASH, 2))   { return false; }  // doubletap ~~ -> ~/
#else
    LEADERCAP;  DOUBLETAP; if (map_shift      (record, KC_RSFT, TILDE_SLASH))      { return false; }  // doubletap ~~ -> ~/
#endif
#else
#ifdef ROLLING
    LEADERCAP;             if (map_shift_event(record, KC_RSFT, UPPER, KC_GRV, 2)) { return false; }  // dot + space/enter + shift shortcut, see leader_cap()
#else
    LEADERCAP;             if (map_shift      (record, KC_RSFT, UPPER, KC_GRV))    { return false; }  // dot + space/enter + shift shortcut, see leader_cap()
#endif
#endif
    break;

#ifndef SPLITOGRAPHY
#ifndef EQLEQL
#define EQUAL_MATCH first_tap ? LOWER : UPPER, first_tap ? KC_EQL : KC_GRV

  case DT_EQL:  DOUBLETAP; type(record, EQUAL_MATCH); return false;  // doubletap == -> =~/
#endif
#endif

// ....................................................... Leader Capitalization

#ifdef ROLLING
  case KC_EXLM:  LEADERCAP; set_leadercap(record, keycode, 2); break;  // exclamation + space/enter + shift shortcut, see leader_cap()
  case KC_QUES:  LEADERCAP; set_leadercap(record, keycode, 1); break;  // question + space/enter + shift shortcut, see leader_cap()
#else
  case KC_EXLM:
  case KC_QUES:  LEADERCAP; break;
#endif

// Alpha Keys
// ═════════════════════════════════════════════════════════════════════════════

// ...................................................... Capslock Modifier Keys

#define SHIFT_LAYER(m, l, k) layer_toggle(record, l, UPPER, k); MOD_BITS(m); break

  case TT_A:  SHIFT_LAYER(KC_LSFT, _TTBASEL, KC_A);
  case TT_T:  SHIFT_LAYER(KC_RSFT, _TTBASER, KC_T);

// ..................................................... Remaining Rollover Keys

#ifdef ROLLING
#define CASE_ROLL(k, c) case k: MOD_ROLL(0, k, c); return false

  CASE_ROLL(KC_Y,    1);  // top row 3
  CASE_ROLL(KC_O,    2);
  CASE_ROLL(KC_U,    3);
  CASE_ROLL(KC_MINS, 4);

  CASE_ROLL(KC_G,    5);
  CASE_ROLL(KC_D,    6);
  CASE_ROLL(KC_N,    7);
  CASE_ROLL(KC_M,    8);
  case PINKY3:
    MOD_ROLL(0, PINKIE(3), 9); return false;

  CASE_ROLL(KC_W,    4);  // middle row 2
  CASE_ROLL(KC_C,    5);

  CASE_ROLL(KC_J,    0);  // bottom row 1
  CASE_ROLL(KC_K,    3);
  CASE_ROLL(KC_QUOT, 4);

  CASE_ROLL(KC_B,    5);
  CASE_ROLL(KC_P,    6);
  CASE_ROLL(KC_L,    7);
  CASE_ROLL(KC_F,    8);
  case PINKY1:
    MOD_ROLL(0, PINKIE(1), 9); return false;
#endif

// Layers
// ═════════════════════════════════════════════════════════════════════════════

// .................................................... Toggle Layer Pinkie Keys

#define TYPE_LOWER(r) type(record, LOWER, PINKIE(r)); break
#define TYPE_UPPER(r) type(record, UPPER, PINKIE(r)); break

#ifndef ROLLING
  case PINKY3:
#endif
  case KEY3:    TYPE_LOWER(3);
  case KEY2:    TYPE_LOWER(2);
#ifndef ROLLING
  case PINKY1:
#endif
  case KEY1:    TYPE_LOWER(1);
  case SHIFT3:  TYPE_UPPER(3);
  case SHIFT2:  TYPE_UPPER(2);
  case SHIFT1:  TYPE_UPPER(1);

// ............................................................... Toggle Layers

static uint8_t dual_down = 0;  // dual keys down (2 -> 1 -> 0) reset on last up stroke, see case TGL_TL, TGL_TR

#define DEFAULTS brktype = 0;                \
                 hexcase = HEXADECIMAL_CASE; \
                 postfix = KC_SPC;           \
                 smart   = 1;                \
                 stagger = PINKIE_STAGGER

#define RAISE(s) if (dualkey_raise(record, _BASE, s, INVERT)) { dual_down = 2; return false; }                                \
                 if (dual_down)                               { dual_down--; base_layer(dual_down); DEFAULTS; return false; } \
                 tt_escape(record, keycode); break

  case TGL_TL:  RAISE(LEFT);
  case TGL_TR:  RAISE(RIGHT);
  case TGL_HL:
  case TGL_HR:
  case TGL_BL:
  case TGL_BR:  tt_escape(record, keycode); break;

// .................................................................. Steno Keys

#define BASE(s) if (dualkey_raise(record, _BASE, s, INVERT)) { base_layer(0); }; return false

#ifdef STENO_ENABLE
  case PLOVER:  steno(record); return false;
  case BASE1:   BASE(LEFT);
  case BASE2:   BASE(RIGHT);
#endif

// Special Keys
// ═════════════════════════════════════════════════════════════════════════════

// .................................................................. Other Keys

#define CYCLE(n)  if (KEY_DOWN) { n = (n == 0) ? 1 : ((n == 1) ? 2 : 0); }; return false
#define TOGGLE(b) if (KEY_DOWN) { b = !b; }; return false

  case BRKTYPE:  CYCLE(brktype);  // see BRACKET()
  case HEXCASE:  TOGGLE(hexcase);
  case SMART:    TOGGLE(smart);
  case STAGGER:  CYCLE(stagger);  // see PINKIE()
  }
  
  CLR_1SHOT;                      // see leader_cap()
  return true;
}

// Initialization
// ═════════════════════════════════════════════════════════════════════════════

#include "initialize.c"
