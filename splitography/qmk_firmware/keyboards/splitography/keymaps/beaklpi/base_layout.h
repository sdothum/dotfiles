
// const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = KEYMAP( 

// .................................................................... BEAKL SI

  [_BASE] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      KC_Z    , KC_Y    , KC_O    , KC_U    , TD_COLN , TGL_TL  , TGL_TR  , KC_G    , KC_D    , KC_N    , KC_M    , KC_X    ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      HOME_Q  , HOME_H  , HOME_E  , HOME_A  , KC_DOT  , TGL_HL  , TGL_HR  , KC_C    , HOME_T  , HOME_R  , HOME_S  , HOME_W  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      KC_J    , KC_MINS , KC_QUOT , KC_K    , KC_COMM , TGL_BL  , TGL_BR  , KC_B    , KC_P    , KC_L    , KC_F    , KC_V    ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      _______ , _______ , _______ , _______ , LT_ESC  , LT_I    , LT_SPC  , LT_BSPC , _______ , _______ , _______ , _______ 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),

  [_SHIFT] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      S(KC_Z) , S(KC_Y) , S(KC_O) , S(KC_U) , KC_COLN , ___x___ , ___x___ , S(KC_G) , S(KC_D) , S(KC_N) , S(KC_M) , S(KC_X) ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      S(KC_Q) , S(KC_H) , S(KC_E) , S(KC_A) , KC_QUES , ___x___ , ___x___ , S(KC_C) , S(KC_T) , S(KC_R) , S(KC_S) , S(KC_W) ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      S(KC_J) , KC_UNDS , KC_DQT  , S(KC_K) , KC_EXLM , ___x___ , ___x___ , S(KC_B) , S(KC_P) , S(KC_L) , S(KC_F) , S(KC_V) ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      _______ , _______ , _______ , _______ , KC_ESC  , S(KC_I) , KC_SPC  , KC_BSPC , _______ , _______ , _______ , _______ 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),
