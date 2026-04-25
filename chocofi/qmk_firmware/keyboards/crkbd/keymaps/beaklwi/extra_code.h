void cap(CHORD* self) {
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

	"extra_code": "void cap(CHORD* self) {\n\tswitch (*self->state) {\n\tcase ACTIVATED:\n\t\ttap_key(self->value1);\n\t\ttap_key(self->value2);\n\t\tbreak;\n\tcase DEACTIVATED:\n\t\tcurrent_pseudolayer = CAPS;\n\t\t*self->state = IN_ONE_SHOT;\n\t\tbreak;\n\tcase FINISHED:\n\tcase PRESS_FROM_ACTIVE:\n\t\tcurrent_pseudolayer = CAPS;\n\t\ta_key_went_through = false;\n\t\tbreak;\n\tcase RESTART:\n\t\tif (a_key_went_through) {\n\t\t\tcurrent_pseudolayer = self->pseudolayer;\n\t\t} else {\n\t\t\t*self->state = IN_ONE_SHOT;\n\t\t}\n\t}\n}",

	"extra_code": "void cap(CHORD* self) {\n switch (*self->state) {\n case ACTIVATED:\n tap_key(self->value1);\n tap_key(self->value2);\n break;\n case DEACTIVATED:\n current_pseudolayer = CAPS;\n *self->state = IN_ONE_SHOT;\n break;\n case FINISHED:\n case PRESS_FROM_ACTIVE:\n current_pseudolayer = CAPS;\n a_key_went_through = false;\n break;\n case RESTART:\n if (a_key_went_through) {\n current_pseudolayer = self->pseudolayer;\n } else {\n *self->state = IN_ONE_SHOT;\n }\n }\n }\n",


void cap(CHORD* self) {
	switch (*self->state) {
	case ACTIVATED:
		tap_key(self->value1);
		tap_key(self->value2);
		break;
	case DEACTIVATED:
		*self->state = IN_ONE_SHOT;
		break;
	case FINISHED:
	case PRESS_FROM_ACTIVE:
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


"extra_code": "void cap(CHORD* self) {\n\tswitch (*self->state) {\n\tcase ACTIVATED:\n\t\ttap_key(self->value1);\n\t\ttap_key(self->value2);\n\t\tbreak;\n\tcase DEACTIVATED:\n\t\t*self->state = IN_ONE_SHOT;\n\t\tbreak;\n\tcase FINISHED:\n\tcase PRESS_FROM_ACTIVE:\n\t\ta_key_went_through = false;\n\t\tbreak;\n\tcase RESTART:\n\t\tif (a_key_went_through) {\n\t\t\tcurrent_pseudolayer = self->pseudolayer;\n\t\t} else {\n\t\t\t*self->state = IN_ONE_SHOT;\n\t\t}\n\t}\n}\n",
