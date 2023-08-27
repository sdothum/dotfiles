// sdothum - 2016 (c) wtfpl

// const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = KEYMAP( 

// .................................................................... BEAKL WI

  [_BASE] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      HS_COLN , KC_Y    , KC_O    , KC_U    , KC_MINS , TGL_TL  , TGL_TR  , KC_G    , KC_D    , KC_N    , KC_M    , PINKY3  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      HOME_Q  , HOME_H  , HOME_E  , HOME_A  , KC_W    , TGL_HL  , TGL_HR  , KC_C    , HOME_T  , HOME_R  , HOME_S  , PINKY2  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      KC_J    , KC_COMM , KC_DOT  , KC_K    , KC_QUOT , TGL_BL  , TGL_BR  , KC_B    , KC_P    , KC_L    , KC_F    , PINKY1  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      OS_GUI  , OS_CTL  , OS_ALT  , LT_ESC  , LT_I    , LT_TAB  , LT_ENT  , LT_SPC  , LT_BSPC , OS_ALT  , OS_CTL  , OS_GUI 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),

  [_SHIFT] = KEYMAP( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      KC_SCLN , S(KC_Y) , S(KC_O) , S(KC_U) , KC_UNDS ,  __x__  ,  __x__  , S(KC_G) , S(KC_D) , S(KC_N) , S(KC_M) , SHIFT3  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      S(KC_Q) , S(KC_H) , S(KC_E) , S(KC_A) , S(KC_W) ,  __x__  ,  __x__  , S(KC_C) , S(KC_T) , S(KC_R) , S(KC_S) , SHIFT2  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      S(KC_J) , KC_GRV  , KC_TILD , S(KC_K) , KC_DQT  ,  __x__  ,  __x__  , S(KC_B) , S(KC_P) , S(KC_L) , S(KC_F) , SHIFT1  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
       __x__  ,  __x__  ,  __x__  , KC_ESC  , S(KC_I) , KC_TAB  , KC_ENT  , KC_SPC  , KC_BSPC ,  __x__  ,  __x__  ,  __x__  
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),