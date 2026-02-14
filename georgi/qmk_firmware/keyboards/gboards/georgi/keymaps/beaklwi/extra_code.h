void cap(const struct Chord* self) {
	switch (*self->state) {
	case ACTIVATED:
		tap_key(self->value1);
		tap_key(self->value2);
		break;
	case DEACTIVATED:
		current_pseudolayer = CAPS;
		*self->state = IN_ONE_SHOT;
		break;
	case FINISHED:
	case PRESS_FROM_ACTIVE:
		current_pseudolayer = CAPS;
		a_key_went_through = false;
		break;
	case RESTART:
		if (a_key_went_through) {
			current_pseudolayer = self->pseudolayer;
		} else {
			*self->state = IN_ONE_SHOT;
		}
	}
}

static uint8_t harmonic = 0;

#define interval(k) if (record->event.pressed) { harmonic |= k; if (harmonic == 3) { layer_move(0); return false; } } else { harmonic &= ~k; } break

bool process_steno_user(uint16_t keycode, keyrecord_t *record) { 
	switch (keycode) {
	case STN_FN:
		interval(1);
	case STN_PWR:
		interval(2);
	}
	return true;
}

void matrix_init_user() {
	steno_set_mode(STENO_MODE_GEMINI);
}



	"extra_code": "void cap(const struct Chord* self) {\n switch (*self->state) {\n case ACTIVATED:\n tap_key(self->value1);\n tap_key(self->value2);\n break;\n case DEACTIVATED:\n current_pseudolayer = CAPS;\n *self->state = IN_ONE_SHOT;\n break;\n case FINISHED:\n case PRESS_FROM_ACTIVE:\n current_pseudolayer = CAPS;\n a_key_went_through = false;\n break;\n case RESTART:\n if (a_key_went_through) {\n current_pseudolayer = self->pseudolayer;\n } else {\n *self->state = IN_ONE_SHOT;\n }\n }\n }\n \n static uint8_t harmonic = 0;\n \n #define interval(k) if (record->event.pressed) { harmonic |= k; if (harmonic == 3) { layer_move(0); return false; } } else { harmonic &= ~k; } break\n \n bool process_steno_user(uint16_t keycode, keyrecord_t *record) { \n switch (keycode) {\n case STN_FN:\n interval(1);\n case STN_PWR:\n interval(2);\n }\n return true;\n }\n \n void matrix_init_user() {\n steno_set_mode(STENO_MODE_GEMINI);\n }\n",
