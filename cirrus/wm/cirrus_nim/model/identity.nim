## X-free ClientToken serialization matching the frozen Stage 0 grammar.

import std/strformat
import ./types

proc formatToken*(token: ClientToken): string =
  &"{token.epoch.hi:016x}{token.epoch.lo:016x}:{token.generation.raw:016x}"
