type
  ZephyrError* = object of CatchableError


# Raises the controller's recoverable ZephyrError with the supplied public diagnostic.

proc raiseZephyrError*(message: string) {.noreturn.} =
  raise newException(ZephyrError, message)
