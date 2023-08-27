
// const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = KEYMAP( 

// .................................................. Symbols / Navigation Layer

  [_SYMGUI] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   , TD_DOT  , KC_ASTR , KC_AMPR , KC_PIPE ,  __x__  ,  __x__  , KC_G    , KC_D    , KC_N    , KC_M    , KC_X    ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+--------- 
      OS_GUI  , HS_LT   , TD_PERC , HS_GT   , KC_QUES ,  __x__  ,  __x__  , KC_C    , HOME_T  , HOME_R  , HOME_S  , HOME_W  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+--------- 
        ___   , KC_PLUS , KC_AT   , KC_SLSH , KC_EXLM ,  __x__  ,  __x__  , KC_B    , KC_P    , KC_L    , KC_F    , KC_V    ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   , KC_BSLS , TD_EQL  ,  __x__  ,  __x__  ,   ___   ,   ___   ,   ___   ,   ___     // _x_ capslock
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),

// ................................................................. Regex Layer

  [_REGEX] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      KC_Z    , KC_Y    , KC_O    , KC_U    , TD_COLN ,  __x__  ,  __x__  , TD_ASTR , KC_LBRC , KC_CIRC , KC_RBRC ,   ___   ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      HOME_Q  , HOME_H  , HOME_E  , HOME_A  , KC_DOT  ,  __x__  ,  __x__  , KC_QUES , KC_LPRN , KC_DLR  , KC_RPRN ,   ___   ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      KC_J    , KC_MINS , KC_QUOT , KC_K    , KC_COMM ,  __x__  ,  __x__  , KC_PIPE , KC_LCBR , KC_HASH , KC_RCBR ,   ___   ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   ,  __x__  ,  __x__  , ML_BSLS , KC_DEL  ,   ___   ,   ___   ,   ___   ,   ___   
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),

// ......................................................... Mouse Pointer Layer

  [_MOUSE] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   ,   ___   ,  __x__  ,  __x__  ,   ___   , KC_WH_L , KC_MS_U , KC_WH_R , KC_WH_U ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   , KC_BTN3 , KC_BTN2 , KC_BTN1 ,   ___   ,  __x__  ,  __x__  ,   ___   , KC_MS_L , KC_MS_D , KC_MS_R , KC_WH_D ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   ,   ___   ,  __x__  ,  __x__  ,   ___   ,   ___   ,   ___   ,   ___   ,   ___   ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
        ___   ,   ___   ,   ___   ,   ___   ,  __x__  ,  __x__  ,  __x__  ,  __x__  ,   ___   ,   ___   ,   ___   ,   ___   
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),