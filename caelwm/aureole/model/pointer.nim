## X-free expansion of Cirrus's click-focus and pointer-action grab policy.

type
  ButtonGrabSpec* = object
    button*: uint8
    modifiers*: uint16

proc normalizeLockMasks*(masks: array[3, uint16]; capsFallback: uint16): array[3, uint16] =
  result = masks
  if result[1] == 0: result[1] = capsFallback

proc modifierVariants*(base: uint16; locks: array[3, uint16]): seq[uint16] =
  let haveNum = locks[0] != 0
  let haveCaps = locks[1] != 0
  let haveScroll = locks[2] != 0
  result.add(base)
  if haveNum and haveCaps and haveScroll:
    result.add(base or locks[0] or locks[1] or locks[2])
  if haveNum and haveCaps: result.add(base or locks[0] or locks[1])
  if haveCaps and haveScroll: result.add(base or locks[1] or locks[2])
  if haveNum and haveScroll: result.add(base or locks[0] or locks[2])
  if haveNum: result.add(base or locks[0])
  if haveCaps: result.add(base or locks[1])
  if haveScroll: result.add(base or locks[2])

proc buttonGrabPlan*(pointerModifier: uint16;
                     locks: array[3, uint16]): seq[ButtonGrabSpec] =
  for button in [1'u8, 2'u8, 3'u8]:
    for base in [0'u16, pointerModifier]:
      for modifiers in modifierVariants(base, locks):
        result.add(ButtonGrabSpec(button: button, modifiers: modifiers))

proc sourceButtonGrabPlan*(clickToFocus: int8;
    pointerActions: array[3, uint32]; pointerModifier: uint16;
    locks: array[3, uint16]): seq[ButtonGrabSpec] =
  ## Mirrors input.c:window_grab_buttons. Preserve duplicate requests when
  ## click-focus and pointer-action policies select the same button/mask.
  for index, button in [1'u8, 2'u8, 3'u8]:
    if clickToFocus == 0'i8 or clickToFocus == int8(button):
      for modifiers in modifierVariants(0'u16, locks):
        result.add(ButtonGrabSpec(button: button, modifiers: modifiers))
    if pointerActions[index] != 0'u32:
      for modifiers in modifierVariants(pointerModifier, locks):
        result.add(ButtonGrabSpec(button: button, modifiers: modifiers))
