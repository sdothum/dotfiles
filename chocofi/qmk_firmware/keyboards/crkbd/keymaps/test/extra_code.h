void cap(const struct Chord* self) {
}

void output(int16_t modifier, int16_t keycode) {
	key_in(modifier);
	tap_key(keycode);
	key_out(modifier);
}

void hexpad(const struct Chord* self) {
}

"extra_code": "void cap(const struct Chord* self) { switch (*self->state) { case ACTIVATED: tap_key(self->value1); tap_key(self->value2); break; case DEACTIVATED: current_pseudolayer = CAPS; *self->state = IN_ONE_SHOT; break; case FINISHED: case PRESS_FROM_ACTIVE: current_pseudolayer = CAPS; a_key_went_through = false; break; case RESTART: if (a_key_went_through) { current_pseudolayer = self->pseudolayer; } else { *self->state = IN_ONE_SHOT; } } } static uint16_t postfix = KC_G; static uint8_t postcap = 0; static uint16_t pairs[][3] = { {KC_NO, KC_LBRC, KC_RBRC}, {KC_LSFT, KC_9, KC_0}, {KC_LSFT, KC_LCBR, KC_RCBR} }; static uint8_t bracket = 0; void output(int16_t modifier, int16_t keycode) { key_in(modifier); tap_key(keycode); key_out(modifier); } void hexpad(const struct Chord* self) { switch (*self->state) { case ACTIVATED: switch (self->value1) { case 0: switch (self->value2) { case 1: postfix = postfix == KC_G ? KC_SPC : KC_G; break; case 2: bracket = (bracket == 0) ? 1 : ((bracket == 1) ? 2 : 0); break; case 0: current_pseudolayer = BEAKL; if (!postcap) { break; } case 3: tap_key(KC_CAPS); postcap = !postcap; } break; case 1: output(postcap == 0 ? KC_LSFT : KC_NO, postfix); break; case 2: output(pairs[bracket][0], pairs[bracket][self->value2]); } } }""

"extra_code": "void cap(const struct Chord* self) { } void output(int16_t modifier, int16_t keycode) { key_in(modifier); tap_key(keycode); key_out(modifier); } void hexpad(const struct Chord* self) { }",



