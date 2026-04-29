#!/usr/bin/env python3

# chord.py
#
# NOTE: 64bit HASH_TYPE for handling up to 64 key keyboards

import re
from functools import reduce

strings = []
number_of_strings = -1

def top_level_split(s):
	"""
	Split `s` by top-level commas only. Commas within parentheses are ignored.
	"""

	# Parse the string tracking whether the current character is within
	# parentheses.
	balance = 0
	parts = []
	part = ""

	for i in range(len(s)):
		c = s[i]
		part += c
		if c == '(':
			balance += 1
		elif c == ')':
			balance -= 1
		elif c == ',' and balance == 0 and not s[i+1] == ',':
			part = part[:-1].strip()
			parts.append(part)
			part = ""

	# Capture last part
	if len(part):
		parts.append(part.strip())

	return parts

def new_chord(on_pseudolayer, keycodes_hash, has_counter, value1, value2, function, output_buffer, index):
	counter_link = "NULL"
	output_buffer += "uint8_t state_" + str(index) + " = IDLE;\n"
	if has_counter:
		output_buffer += "uint8_t counter_" + str(index) + " = 0;\n"
		counter_link = "&counter_" + str(index)
	output_buffer += "CHORD chord_" + str(index) + " PROGMEM = {" + keycodes_hash + ", " + on_pseudolayer + ", &state_" + str(index) + ", " + counter_link + ", " + str(value1) + ", " + str(value2) + ", " + function + "};\n"
	index += 1
	return [output_buffer, index]

def KC(on_pseudolayer, keycodes_hash, keycode, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, keycode, 0, "single_dance", output_buffer, index)

def AS(on_pseudolayer, keycodes_hash, keycode, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, True, keycode, 0, "autoshift_dance", output_buffer, index)

def AT(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "autoshift_toggle", output_buffer, index)

def KL(on_pseudolayer, keycodes_hash, keycode, to_pseudolayer, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, True, keycode, to_pseudolayer, "key_layer_dance", output_buffer, index)

def KK(on_pseudolayer, keycodes_hash, keycode1, keycode2, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, True, keycode1, keycode2, "key_key_dance", output_buffer, index)

def KM(on_pseudolayer, keycodes_hash, keycode, to_pseudolayer, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, keycode, to_pseudolayer, "key_mod_dance", output_buffer, index)

def MO(on_pseudolayer, keycodes_hash, to_pseudolayer, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, to_pseudolayer, 0, "temp_pseudolayer", output_buffer, index)

def MO_alt(on_pseudolayer, keycodes_hash, from_pseudolayer, to_pseudolayer, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, to_pseudolayer, from_pseudolayer, "temp_pseudolayer_alt", output_buffer, index)

def LOCK(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "lock", output_buffer, index)

def DF(on_pseudolayer, keycodes_hash, to_pseudolayer, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, to_pseudolayer, 0, "perm_pseudolayer", output_buffer, index)

def TO(on_pseudolayer, keycodes_hash, to_pseudolayer, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, to_pseudolayer, 0, "switch_layer", output_buffer, index)

def OSK(on_pseudolayer, keycodes_hash, keycode, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, keycode, 0, "one_shot_key", output_buffer, index)

def OSL(on_pseudolayer, keycodes_hash, to_pseudolayer, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, to_pseudolayer, 0, "one_shot_layer", output_buffer, index)

def CMD(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "command", output_buffer, index)

def DM_RECORD(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "dynamic_macro_record", output_buffer, index)

def DM_NEXT(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "dynamic_macro_next", output_buffer, index)

def DM_END(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "dynamic_macro_end", output_buffer, index)

def DM_PLAY(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "dynamic_macro_play", output_buffer, index)

def LEAD(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "leader", output_buffer, index)

def CLEAR(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "clear", output_buffer, index)

def RESET(on_pseudolayer, keycodes_hash, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, False, 0, 0, "reset", output_buffer, index)

def STR(on_pseudolayer, keycodes_hash, string_input, output_buffer, index, number_of_strings, strings):
	[a, b] = new_chord(on_pseudolayer, keycodes_hash, False, number_of_strings, 0, "string_in", output_buffer, index)
	return [a, b, number_of_strings + 1, strings + [string_input]]

def M(on_pseudolayer, keycodes_hash, value1, value2, fnc, output_buffer, index):
	return new_chord(on_pseudolayer, keycodes_hash, True, value1, value2, fnc, output_buffer, index)

def expand_keycode_fnc(DEFINITION):
	if DEFINITION == "`":
		DEFINITION = "GRAVE"
	elif DEFINITION == "-":
		DEFINITION = "MINUS"
	elif DEFINITION == "=":
		DEFINITION = "EQUAL"
	elif DEFINITION == "[":
		DEFINITION = "LBRC"
	elif DEFINITION == "]":
		DEFINITION = "RBRC"
	elif DEFINITION == "\\":
		DEFINITION = "BSLS"
	elif DEFINITION == ";":
		DEFINITION = "SCLN"
	elif DEFINITION == "'":
		DEFINITION = "QUOTE"
	elif DEFINITION == ",":
		DEFINITION = "COMMA"
	elif DEFINITION == ".":
		DEFINITION = "DOT"
	elif DEFINITION == "/":
		DEFINITION = "SLASH"
	elif DEFINITION == "~":
		DEFINITION = "TILDE"
	elif DEFINITION == "*":
		DEFINITION = "ASTERISK"
	elif DEFINITION == "+":
		DEFINITION = "PLUS"
	elif DEFINITION == "(":
		DEFINITION = "LEFT_PAREN"
	elif DEFINITION == ")":
		DEFINITION = "RIGHT_PAREN"
	elif DEFINITION == "<":
		DEFINITION = "LEFT_ANGLE_BRACKET"
	elif DEFINITION == ">":
		DEFINITION = "RIGHT_ANGLE_BRACKET"
	elif DEFINITION == "{":
		DEFINITION = "LEFT_CURLY_BRACE"
	elif DEFINITION == "}":
		DEFINITION = "RIGHT_CURLY_BRACE"
	elif DEFINITION == "?":
		DEFINITION = "QUESTION"
	elif DEFINITION == "~":
		DEFINITION = "TILDE"
	elif DEFINITION == ":":
		DEFINITION = "COLON"
	elif DEFINITION == "_":
		DEFINITION = "UNDERSCORE"
	elif DEFINITION == '"':
		DEFINITION = "DOUBLE_QUOTE"
	elif DEFINITION == "@":
		DEFINITION = "AT"
	elif DEFINITION == "#":
		DEFINITION = "HASH"
	elif DEFINITION == "$":
		DEFINITION = "DOLLAR"
	elif DEFINITION == "!":
		DEFINITION = "EXCLAIM"
	elif DEFINITION == "%":
		DEFINITION = "PERCENT"
	elif DEFINITION == "^":
		DEFINITION = "CIRCUMFLEX"
	elif DEFINITION == "&":
		DEFINITION = "AMPERSAND"
	elif DEFINITION == "|":
		DEFINITION = "PIPE"

	if DEFINITION in [
			"0",
			"1",
			"2",
			"3",
			"4",
			"5",
			"6",
			"7",
			"8",
			"9",
			"A",
			"AGAIN",
			"AGIN",
			"ALGR",
			"ALTERNATE_ERASE",
			"AMPERSAND",
			"AMPR",
			"APP",
			"APPLICATION",
			"ASSISTANT",
			"ASST",
			"ASTERISK",
			"ASTR",
			"AT",
			"AUDIO_MUTE",
			"AUDIO_VOL_DOWN",
			"AUDIO_VOL_UP",
			"B",
			"BACKSLASH",
			"BACKSPACE",
			"BRID",
			"BRIGHTNESS_DOWN",
			"BRIGHTNESS_UP",
			"BRIU",
			"BRK",
			"BRMD",
			"BRMU",
			"BSLS",
			"BSPC",
			"C",
			"CALC",
			"CALCULATOR",
			"CANCEL",
			"CAPS",
			"CAPS_LOCK",
			"CIRC",
			"CIRCUMFLEX",
			"CLAG",
			"CLEAR",
			"CLEAR_AGAIN",
			"CLR",
			"CNCL",
			"COLN",
			"COLON",
			"COMM",
			"COMMA",
			"CONTROL_PANEL",
			"COPY",
			"CPNL",
			"CRSEL",
			"CRSL",
			"CUT",
			"D",
			"DEL",
			"DELETE",
			"DLR",
			"DOLLAR",
			"DOT",
			"DOUBLE_QUOTE",
			"DOWN",
			"DQT",
			"DQUO",
			"E",
			"EJCT",
			"END",
			"ENT",
			"ENTER",
			"EQL",
			"EQUAL",
			"ERAS",
			"ESC",
			"ESCAPE",
			"EXCLAIM",
			"EXEC",
			"EXECUTE",
			"EXLM",
			"EXSEL",
			"EXSL",
			"F",
			"F1",
			"F10",
			"F11",
			"F12",
			"F13",
			"F14",
			"F15",
			"F16",
			"F17",
			"F18",
			"F19",
			"F2",
			"F20",
			"F21",
			"F22",
			"F23",
			"F24",
			"F3",
			"F4",
			"F5",
			"F6",
			"F7",
			"F8",
			"F9",
			"FIND",
			"G",
			"GRAVE",
			"GRV",
			"GT",
			"H",
			"HASH",
			"HELP",
			"HOME",
			"HYPR",
			"I",
			"INS",
			"INSERT",
			"INT1",
			"INT2",
			"INT3",
			"INT4",
			"INT5",
			"INT6",
			"INT7",
			"INT8",
			"INT9",
			"INTERNATIONAL_1",
			"INTERNATIONAL_2",
			"INTERNATIONAL_3",
			"INTERNATIONAL_4",
			"INTERNATIONAL_5",
			"INTERNATIONAL_6",
			"INTERNATIONAL_7",
			"INTERNATIONAL_8",
			"INTERNATIONAL_9",
			"J",
			"K",
			"KB_MUTE",
			"KB_POWER",
			"KB_VOLUME_DOWN",
			"KB_VOLUME_UP",
			"KP_0",
			"KP_1",
			"KP_2",
			"KP_3",
			"KP_4",
			"KP_5",
			"KP_6",
			"KP_7",
			"KP_8",
			"KP_9",
			"KP_ASTERISK",
			"KP_COMMA",
			"KP_DOT",
			"KP_ENTER",
			"KP_EQUAL",
			"KP_EQUAL_AS400",
			"KP_MINUS",
			"KP_PLUS",
			"KP_SLASH",
			"L",
			"LABK",
			"LALT",
			"LANGUAGE_1",
			"LANGUAGE_2",
			"LANGUAGE_3",
			"LANGUAGE_4",
			"LANGUAGE_5",
			"LANGUAGE_6",
			"LANGUAGE_7",
			"LANGUAGE_8",
			"LANGUAGE_9",
			"LAUNCHPAD",
			"LBRC",
			"LCAP",
			"LCBR",
			"LCMD",
			"LCTL",
			"LEFT",
			"LEFT_ALT",
			"LEFT_ANGLE_BRACKET",
			"LEFT_BRACKET",
			"LEFT_CTRL",
			"LEFT_CURLY_BRACE",
			"LEFT_GUI",
			"LEFT_PAREN",
			"LEFT_SHIFT",
			"LGUI",
			"LNG1",
			"LNG2",
			"LNG3",
			"LNG4",
			"LNG5",
			"LNG6",
			"LNG7",
			"LNG8",
			"LNG9",
			"LNUM",
			"LOCKING_CAPS_LOCK",
			"LOCKING_NUM_LOCK",
			"LOCKING_SCROLL_LOCK",
			"LOPT",
			"LPAD",
			"LPRN",
			"LSCR",
			"LSFT",
			"LT",
			"LWIN",
			"M",
			"MAIL",
			"MCTL",
			"MEDIA_EJECT",
			"MEDIA_FAST_FORWARD",
			"MEDIA_NEXT_TRACK",
			"MEDIA_PLAY_PAUSE",
			"MEDIA_PREV_TRACK",
			"MEDIA_REWIND",
			"MEDIA_SELECT",
			"MEDIA_STOP",
			"MEH",
			"MENU",
			"MFFD",
			"MINS",
			"MINUS",
			"MISSION_CONTROL",
			"MNXT",
			"MPLY",
			"MPRV",
			"MRWD",
			"MSEL",
			"MSTP",
			"MUTE",
			"MYCM",
			"MY_COMPUTER",
			"N",
			"NO",
			"NONUS_BACKSLASH",
			"NONUS_HASH",
			"NUBS",
			"NUHS",
			"NUM",
			"NUM_LOCK",
			"O",
			"OPER",
			"OUT",
			"P",
			"P0",
			"P1",
			"P2",
			"P3",
			"P4",
			"P5",
			"P6",
			"P7",
			"P8",
			"P9",
			"PAGE_DOWN",
			"PAGE_UP",
			"PAST",
			"PASTE",
			"PAUS",
			"PAUSE",
			"PCMM",
			"PDOT",
			"PENT",
			"PEQL",
			"PERC",
			"PERCENT",
			"PGDN",
			"PGUP",
			"PIPE",
			"PLUS",
			"PMNS",
			"PPLS",
			"PRINT_SCREEN",
			"PRIOR",
			"PRIR",
			"PSCR",
			"PSLS",
			"PSTE",
			"PWR",
			"Q",
			"QUES",
			"QUESTION",
			"QUOT",
			"QUOTE",
			"R",
			"RABK",
			"RALT",
			"RBRC",
			"RCBR",
			"RCMD",
			"RCTL",
			"RETN",
			"RETURN",
			"RGHT",
			"RGUI",
			"RIGHT",
			"RIGHT_ALT",
			"RIGHT_ANGLE_BRACKET",
			"RIGHT_BRACKET",
			"RIGHT_CTRL",
			"RIGHT_CURLY_BRACE",
			"RIGHT_GUI",
			"RIGHT_PAREN",
			"RIGHT_SHIFT",
			"ROPT",
			"RPRN",
			"RSFT",
			"RWIN",
			"S",
			"SCLN",
			"SCRL",
			"SCROLL_LOCK",
			"SELECT",
			"SEMICOLON",
			"SEPARATOR",
			"SEPR",
			"SLASH",
			"SLCT",
			"SLEP",
			"SLSH",
			"SPACE",
			"SPC",
			"STOP",
			"SYRQ",
			"SYSTEM_POWER",
			"SYSTEM_REQUEST",
			"SYSTEM_SLEEP",
			"SYSTEM_WAKE",
			"T",
			"TAB",
			"TILD",
			"TILDE",
			"TRANSPARENT",
			"TRNS",
			"TRNS",
			"U",
			"UNDERSCORE",
			"UNDO",
			"UNDS",
			"UP",
			"V",
			"VOLD",
			"VOLU",
			"W",
			"WAKE",
			"WBAK",
			"WFAV",
			"WFWD",
			"WHOM",
			"WREF",
			"WSCH",
			"WSTP",
			"WWW_BACK",
			"WWW_FAVORITES",
			"WWW_FORWARD",
			"WWW_HOME",
			"WWW_REFRESH",
			"WWW_SEARCH",
			"WWW_STOP",
			"X",
			"Y",
			"Z",
		]:
		return "KC_" + DEFINITION
	else:
		return DEFINITION

def MK(on_pseudolayer, keycodes_hash, definition, output_buffer, index):
	l = len(definition.split(','))
	output_buffer += "void function_" + str(index) + "(CHORD* self) {\n"
	output_buffer += "	switch (*self->state) {\n"
	output_buffer += "		case ACTIVATED:\n"
	for i in range(0, l):
		val = definition.split(',')[i].strip()
		code = expand_keycode_fnc(val)
		output_buffer += "			key_in(" + code + ");\n"
	output_buffer += "			break;\n"
	output_buffer += "		case DEACTIVATED:\n"
	for i in range(0, l):
		val = definition.split(',')[i].strip()
		code = expand_keycode_fnc(val)
		output_buffer += "			key_out(" + code + ");\n"
	output_buffer += "			*self->state = IDLE;\n"
	output_buffer += "			break;\n"
	output_buffer += "		case RESTART:\n"
	for i in range(0, l):
		val = definition.split(',')[i].strip()
		code = expand_keycode_fnc(val)
		output_buffer += "			key_out(" + code + ");\n"
	output_buffer += "			break;\n"
	output_buffer += "		default:\n"
	output_buffer += "			break;\n"
	output_buffer += "	};\n"
	output_buffer += "}\n"
	return new_chord(on_pseudolayer, keycodes_hash, True, 0, 0, "function_" + str(index), output_buffer, index)

def D(on_pseudolayer, keycodes_hash, DEFINITION, output_buffer, index):
	l = len(DEFINITION.split(','))
	output_buffer += "void function_" + str(index) + "(CHORD* self) {\n"
	output_buffer += "	switch (*self->state) {\n"
	output_buffer += "		case ACTIVATED:\n"
	output_buffer += "			*self->counter = *self->counter + 1;\n"
	output_buffer += "			break;\n"
	output_buffer += "		case PRESS_FROM_ACTIVE:\n"
	output_buffer += "			switch (*self->counter) {\n"
	for i in range(0, l):
		val = DEFINITION.split(',')[i].strip()
		code = expand_keycode_fnc(val)
		output_buffer += "				case " + str(i + 1) + ":\n"
		output_buffer += "					key_in( " + code + ");\n"
		output_buffer += "					break;\n"
	output_buffer += "				default:\n"
	output_buffer += "					break;\n"
	output_buffer += "			}\n"
	output_buffer += "			*self->state = FINISHED_FROM_ACTIVE;\n"
	output_buffer += "			break;\n"
	output_buffer += "		case FINISHED:\n"
	output_buffer += "			switch (*self->counter) {\n"
	for i in range(0, l):
		val = DEFINITION.split(',')[i].strip()
		code = expand_keycode_fnc(val)
		output_buffer += "				case " + str(i + 1) + ":\n"
		output_buffer += "					tap_key( " + code + ");\n"
		output_buffer += "					break;\n"
	output_buffer += "				default:\n"
	output_buffer += "					break;\n"
	output_buffer += "			}\n"
	output_buffer += "			*self->counter = 0;\n"
	output_buffer += "			*self->state = IDLE;\n"
	output_buffer += "			break;\n"
	output_buffer += "		case RESTART:\n"
	output_buffer += "			switch (*self->counter) {\n"
	for i in range(0, l):
		val = DEFINITION.split(',')[i].strip()
		code = expand_keycode_fnc(val)
		output_buffer += "				case " + str(i + 1) + ":\n"
		output_buffer += "					key_out( " + code + ");\n"
		output_buffer += "					break;\n"
	output_buffer += "				default:\n"
	output_buffer += "					break;\n"
	output_buffer += "			}\n"
	output_buffer += "			*self->counter = 0;\n"
	output_buffer += "			break;\n"
	output_buffer += "		default:\n"
	output_buffer += "			break;\n"
	output_buffer += "	}\n"
	output_buffer += "}\n"
	return new_chord(on_pseudolayer, keycodes_hash, True, 0, 0, "function_" + str(index), output_buffer, index)

def O(on_pseudolayer, keycodes_hash, DEFINITION, output_buffer, index):
	if DEFINITION[0:3] == "KC_":
		return OSK(on_pseudolayer, keycodes_hash, DEFINITION, output_buffer, index)
	else:
		return OSL(on_pseudolayer, keycodes_hash, DEFINITION, output_buffer, index)

def add_key(PSEUDOLAYER, KEYCODES_HASH, DEFINITION, output_buffer, index, number_of_strings, strings):
	# if "= {" + KEYCODES_HASH + ", " + PSEUDOLAYER in output_buffer:
	#	 KEYCODES_HASH = re.sub('H_', '', KEYCODES_HASH)
	#	 raise Exception("You are trying to register a chord that you already registered (" + KEYCODES_HASH + ", " + PSEUDOLAYER + ")")

	if DEFINITION == "":
		return [output_buffer, index, number_of_strings, strings]
	else:
		split = DEFINITION.split("(")
		type = split[0].strip()
		if len(split) == 1:
			if type == "LOCK":
				[output_buffer, index] = LOCK(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "AT":
				[output_buffer, index] = AT(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "CMD":
				[output_buffer, index] = CMD(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "LEAD":
				[output_buffer, index] = LEAD(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "DM_RECORD":
				[output_buffer, index] = DM_RECORD(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "DM_NEXT":
				[output_buffer, index] = DM_NEXT(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "DM_END":
				[output_buffer, index] = DM_END(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "DM_PLAY":
				[output_buffer, index] = DM_PLAY(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "CLEAR_KB":
				[output_buffer, index] = CLEAR(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			elif type == "RESET":
				[output_buffer, index] = RESET(PSEUDOLAYER, KEYCODES_HASH, output_buffer, index)
			else:
				code = expand_keycode_fnc(type)
				[output_buffer, index] = KC(PSEUDOLAYER, KEYCODES_HASH, code, output_buffer, index)
		else:
			val = split[1][:-1].strip()
			if type == "O":
				code = expand_keycode_fnc(val)
				[output_buffer, index] = O(PSEUDOLAYER, KEYCODES_HASH, code, output_buffer, index)
			elif type == "D":
				[output_buffer, index] = D(PSEUDOLAYER, KEYCODES_HASH, val, output_buffer, index)
			elif type == "MK":
				[output_buffer, index] = MK(PSEUDOLAYER, KEYCODES_HASH, val, output_buffer, index)
			elif type == "M":
				fnc = val.split(',')[0].strip()
				val1 = val.split(',')[1].strip()
				val2 = val.split(',')[2].strip()
				[output_buffer, index] = M(PSEUDOLAYER, KEYCODES_HASH, val1, val2, fnc, output_buffer, index)
			elif type == "KK":
				val1 = val.split(',')[0].strip()
				code1 = expand_keycode_fnc(val1)
				val2 = val.split(',')[1].strip()
				code2 = expand_keycode_fnc(val2)
				[output_buffer, index] = KK(PSEUDOLAYER, KEYCODES_HASH, code1, code2, output_buffer, index)
			elif type == "KL":
				val1 = val.split(',')[0].strip()
				code1 = expand_keycode_fnc(val1)
				val2 = val.split(',')[1].strip()
				[output_buffer, index] = KL(PSEUDOLAYER, KEYCODES_HASH, code1, val2, output_buffer, index)
			elif type == "KM":
				val1 = val.split(',')[0].strip()
				code1 = expand_keycode_fnc(val1)
				val2 = val.split(',')[1].strip()
				code2 = expand_keycode_fnc(val2)
				[output_buffer, index] = KM(PSEUDOLAYER, KEYCODES_HASH, code1, code2, output_buffer, index)
			elif type == "AS":
				code = expand_keycode_fnc(val)
				[output_buffer, index] = AS(PSEUDOLAYER, KEYCODES_HASH, code, output_buffer, index)
			elif type == "MO":
				if not ',' in val:
					[output_buffer, index] = MO(PSEUDOLAYER, KEYCODES_HASH, val, output_buffer, index)
				else:
					val1 = val.split(',')[0].strip()
					val2 = val.split(',')[1].strip()
					[output_buffer, index] = MO_alt(PSEUDOLAYER, KEYCODES_HASH, val1, val2, output_buffer, index)
			elif type == "DF":
				[output_buffer, index] = DF(PSEUDOLAYER, KEYCODES_HASH, val, output_buffer, index)
			elif type == "TO":
				[output_buffer, index] = TO(PSEUDOLAYER, KEYCODES_HASH, val, output_buffer, index)
			elif type == "STR":
				[output_buffer, index, number_of_strings, strings] = STR(PSEUDOLAYER, KEYCODES_HASH, re.sub("''", " ", val), output_buffer, index, number_of_strings, strings)
	return [output_buffer, index, number_of_strings, strings]

def add_leader_combo(DEFINITION, FUNCTION):
	return list_of_leader_combos.append([DEFINITION, FUNCTION])

def add_chord_set(PSEUDOLAYER, INPUT_STRING, TYPE, data, output_buffer, index, number_of_strings, strings):
	chord_set = {}
	for set in data["chord_sets"]:
		if set["name"] == TYPE:
			chord_set = set["chords"]
			break

	separated_string = top_level_split(INPUT_STRING)
	for word, chord in zip(separated_string, chord_set):
		chord_hash = reduce((lambda x, y: str(x) + " + " + str(y)), ["H_" + key for key in chord])
		[output_buffer, index, number_of_strings, strings] = add_key(PSEUDOLAYER, chord_hash, word, output_buffer, index, number_of_strings, strings)

	return [output_buffer, index, number_of_strings, strings]

def add_dictionary(PSEUDOLAYER, keycodes, array, output_buffer, index, number_of_strings, strings):
	for chord in array:
		hash = ""
		for word, key in zip(chord[:-1], keycodes):
			if word == "X":
				hash = hash + " + H_" + key
		hash = hash[3:]
		if hash != "":
			[output_buffer, index, number_of_strings, strings] = add_key(PSEUDOLAYER, hash, chord[-1], output_buffer, index, number_of_strings, strings)

	return [output_buffer, index, number_of_strings, strings]

def secret_chord(PSEUDOLAYER, ACTION, INPUT_STRING, data, output_buffer, index, number_of_strings, strings):
	separated_string = top_level_split(INPUT_STRING)
	hash = ""
	for word, key in zip(separated_string, data["keys"]):
		if word == "X":
			hash = hash + " + H_" + key

	hash = hash[3:]
	if hash != "":
		return add_key(PSEUDOLAYER, hash, ACTION, output_buffer, index, number_of_strings, strings)

# kak: filetype=py
