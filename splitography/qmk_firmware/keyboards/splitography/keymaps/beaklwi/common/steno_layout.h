// sdothum - 2016 (c) wtfpl

// const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = LAYOUT( 

// ...................................................................... Plover

#ifdef STENO_ENABLE
  [_PLOVER] = LAYOUT( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      STN_N1  , STN_N2  , STN_N3  , STN_N4  , STN_N5  , STN_N6  , STN_N7  , STN_N8  , STN_N9  , STN_NA  , STN_NB  , STN_NC  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      BASE1   , STN_S1  , STN_TL  , STN_PL  , STN_HL  , STN_ST1 , STN_ST3 , STN_FR  , STN_PR  , STN_LR  , STN_TR  , STN_DR  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      BASE2   , STN_S2  , STN_KL  , STN_WL  , STN_RL  , STN_ST2 , STN_ST4 , STN_RR  , STN_BR  , STN_GR  , STN_SR  , STN_ZR  ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
                                              STN_A   , STN_O   , STN_E   , STN_U                                           
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),
#else
  [_PLOVER] = LAYOUT( 
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      KC_1   ,  KC_1   ,  KC_1   ,  KC_1   ,  KC_1   ,  KC_1   ,  KC_1   ,  KC_1   ,  KC_1   ,  KC_1   ,  KC_1   ,  KC_1    ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      BASE1   , KC_Q   ,  KC_W   ,  KC_E   ,  KC_R   ,  KC_T   ,  KC_Y   ,  KC_U   ,  KC_I   ,  KC_O   ,  KC_P   ,  KC_LBRC ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
      BASE2   , KC_A   ,  KC_S   ,  KC_D   ,  KC_F   ,  KC_G   ,  KC_H   ,  KC_J   ,  KC_K   ,  KC_L   ,  KC_SCLN , KC_QUOT ,
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
                                              KC_C   ,  KC_V   ,  KC_N   ,  KC_M                                           
  // ---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------
  ),
#endif
