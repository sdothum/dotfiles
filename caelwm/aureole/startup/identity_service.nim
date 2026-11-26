## Process-start identity service. Epoch entropy is generated once per process.

import std/sysrand
import ../model/types


# Constructs a 128-bit epoch from OS entropy, raising IOError when entropy is unavailable.

proc newProcessEpoch*(): ProcessEpoch =
  var bytes: array[16, byte]
  if not urandom(bytes):
    raise newException(IOError, "operating-system entropy unavailable for process epoch")
  for index in 0 ..< 8:
    result.hi = (result.hi shl 8) or uint64(bytes[index])
    result.lo = (result.lo shl 8) or uint64(bytes[index + 8])
