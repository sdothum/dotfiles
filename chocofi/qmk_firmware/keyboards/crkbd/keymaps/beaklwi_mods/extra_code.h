// NOTE: to create json line select code block and PIPE..

tr '\n' '@' | sed 's/\t/\\t/g; s/@/\\n/g'

		{
			"name": "CAPS",
			"chords": [
				{
					"type": "chord_set",
					"_comment": "SEE: M(cap, .. , ..) capitalization chords",
					"set": "rows",
					"keycodes": [
						":"          , "MK(LSFT,Y)"    , "MK(LSFT,O)"    , "MK(LSFT,U)"    , "-"                  ,            "MK(LSFT,G)"    , "MK(LSFT,D)"  , "MK(LSFT,N)"     , "MK(LSFT,M)" , "MK(LSFT,X)" ,
						"MK(LSFT,Q)" , "MK(LSFT,H)"    , "MK(LSFT,E)"    , "MK(LSFT,A)"    , "MK(LSFT,W)"         ,            "MK(LSFT,C)"    , "MK(LSFT,T)"  , "MK(LSFT,R)"     , "MK(LSFT,S)" , "MK(LSFT,Z)" ,
						"MK(LSFT,J)" , ","             , "."             , "MK(LSFT,K)"    , "'"                  ,            "MK(LSFT,B)"    , "MK(LSFT,P)"  , "MK(LSFT,L)"     , "MK(LSFT,F)" , "MK(LSFT,V)" ,
						"LALT"       , "MK(LALT,LCTL)" , "MK(LALT,LGUI)" , "MK(LALT,LSFT)" , "MK(LALT,LCTL,LGUI)" ,            "DF(NUM)"       , "CAPS"        , "DF(SYMBOL)"     , "DF(NAV)"    , "RALT"       ,
																	"KL(ESC,FKEY)"  , "KL(I,REGEX)"   , "KL(TAB,NUM)"        ,            "KL(ENTER,NAV)" , "KL(SPC,SYM)" , "KL(BSPC,MOUSE)"
					]
				}
			]
		},

		{
			"name": "CAPS",
			"chords": [
				{
					"type": "chord_set",
					"_comment": "SEE:  M(cap, .. , ..) capitalization chords",
					"_comment": "NOTE: STR(..) replaces MK(LSFT, ..) (??) fails with 64bit conversion",
					"set": "rows",
					"keycodes": [
						":"      , "STR(Y)" , "STR(O)" , "STR(U)" , "-"      ,            "STR(G)" , "STR(D)" , "STR(N)" , "STR(M)" , "STR(X)" ,
						"STR(Q)" , "STR(H)" , "STR(E)" , "STR(A)" , "STR(W)" ,            "STR(C)" , "STR(T)" , "STR(R)" , "STR(S)" , "STR(Z)" ,
						"STR(J)" , ","      , "."      , "STR(K)" , "'"      ,            "STR(B)" , "STR(P)" , "STR(L)" , "STR(F)" , "STR(V)" ,
						" "      , " "      , " "      , " "      , " "      ,            " "      , " "      , " "      , " "      , " "      ,
													 " "      , " "      , " "      ,            " "      , " "      , " "
					]
				}
			]
		},

"extra_code": "void cap(CHORD* self) {
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
}",

	"extra_code": "void cap(CHORD* self) {\n\tswitch (*self->state) {\n\tcase ACTIVATED:\n\t\ttap_key(self->value1);\n\t\ttap_key(self->value2);\n\t\tbreak;\n\tcase DEACTIVATED:\n\t\tcurrent_pseudolayer = CAPS;\n\t\t*self->state = IN_ONE_SHOT;\n\t\tbreak;\n\tcase FINISHED:\n\tcase PRESS_FROM_ACTIVE:\n\t\tcurrent_pseudolayer = CAPS;\n\t\ta_key_went_through = false;\n\t\tbreak;\n\tcase RESTART:\n\t\tif (a_key_went_through) {\n\t\t\tcurrent_pseudolayer = self->pseudolayer;\n\t\t} else {\n\t\t\t*self->state = IN_ONE_SHOT;\n\t\t}\n\t}\n}",


"extra_code": "void cap(CHORD* self) {
	switch (*self->state) {
	case ACTIVATED:
		tap_key(self->value1);
		tap_key(self->value2);
		break;
	case DEACTIVATED:
		tap_key(KC_CAPS);
		*self->state = IN_ONE_SHOT;
		break;
	case FINISHED:
	case PRESS_FROM_ACTIVE:
		a_key_went_through = false;
		break;
	case RESTART:
		if (a_key_went_through) {
			tap_key(KC_CAPS);
			current_pseudolayer = self->pseudolayer;
		} else {
			*self->state = IN_ONE_SHOT;
		}
	}
}",
