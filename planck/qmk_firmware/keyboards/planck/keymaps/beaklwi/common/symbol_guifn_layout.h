// sdothum - 2016 (c) wtfpl

// const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = KEYMAP( 

// .................................................. Symbols / Navigation Layer

  [_SYMGUI] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   , KC_DOT  , KC_ASTR , KC_AMPR , KC_PLUS ,  __x__  ,  __x__  , KC_G    , KC_D    , KC_N    , KC_M    , PINKY3  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+--------- 
      OS_GUI  , KC_QUES , KC_EXLM , KC_SLSH , KC_PIPE ,  __x__  ,  __x__  , KC_C    , HOME_T  , HOME_R  , HOME_S  , PINKY2  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+--------- 
        ___   , HS_LT   , HS_GT   , KC_PERC , KC_AT   ,  __x__  ,  __x__  , KC_B    , KC_P    , KC_L    , KC_F    , PINKY1  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   , KC_ESC  , DT_EQL  , KC_BSLS ,   ___   ,  __x__  ,   ___   ,   ___   ,   ___   ,   ___   
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
   ),

// ................................................................. Regex Layer

  [_REGEX] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      HS_COLN , KC_Y    , KC_O    , KC_U    , KC_MINS ,  __x__  ,  __x__  , TD_ASTR , KC_LBRC , KC_CIRC , KC_RBRC ,   ___   ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      HOME_Q  , HOME_H  , HOME_E  , HOME_A  , KC_W    ,  __x__  ,  __x__  , KC_QUES , KC_LPRN , KC_DLR  , KC_RPRN ,   ___   ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      KC_J    , KC_COMM , KC_DOT  , KC_K    , KC_QUOT ,  __x__  ,  __x__  , KC_PIPE , KC_LCBR , KC_HASH , KC_RCBR ,   ___   ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   ,  __x__  ,   ___   , KC_ENT  , KC_BSLS , KC_DEL  ,   ___   ,   ___   ,   ___   
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
   ),
