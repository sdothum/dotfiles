## X-free ClientToken serialization matching the frozen Stage 0 grammar.

import std/strformat
import ./types


# Formats the process epoch and client generation as fixed-width hexadecimal identity fields.

proc formatToken*(token: ClientToken): string =
  &"{token.epoch.hi:016x}{token.epoch.lo:016x}:{token.generation.raw:016x}"
