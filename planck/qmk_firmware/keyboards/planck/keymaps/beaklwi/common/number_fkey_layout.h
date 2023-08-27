// sdothum - 2016 (c) wtfpl

// const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = KEYMAP( 

// ....................................................... Numberic Keypad Layer

  [_NUMBER] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   , HEX_A   , HEX_B   , HEX_C   ,   ___   ,  __x__  , SMART   , KC_SLSH , KC_4    , KC_5    , KC_9    , KC_ASTR ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      OS_GUI  , HEX_D   , HEX_E   , HEX_F   ,   ___   ,  __x__  , HEXCASE , TD_DOT  , KC_1    , KC_2    , KC_3    , KC_MINS ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   , L_BRKT  , R_BRKT  , DELIM   ,   ___   ,  __x__  , BRKTYPE , TD_COMM , KC_8    , KC_6    , KC_7    , KC_PLUS ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   ,   ___   ,  __x__  , KC_BSLS , KC_0    , KC_EQL  ,   ___   ,   ___   ,   ___   
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),

// .......................................................... Function Key Layer

  [_FNCKEY] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   ,   ___   ,  __x__  ,  __x__  ,   ___   , KC_F4 ,   KC_F5 ,   KC_F9 ,   KC_F12  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      OS_GUI  , OS_CTL  , OS_ALT  , OS_SFT  ,   ___   ,  __x__  ,  __x__  ,   ___   , KC_F1 ,   KC_F2 ,   KC_F3 ,   KC_F11  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   ,   ___   ,  __x__  ,  __x__  ,   ___   , KC_F8 ,   KC_F6 ,   KC_F7 ,   KC_F10  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,  __x__  ,   ___   ,   ___   ,   ___   ,   ___   , MO_ADJ  ,   ___   ,   ___   ,   ___   
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),