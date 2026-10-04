type
  ZephyrError* = object of CatchableError

proc raiseZephyrError*(message: string) {.noreturn.} =
  raise newException(ZephyrError, message)
