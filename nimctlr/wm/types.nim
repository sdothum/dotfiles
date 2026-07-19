import std/strutils

type
  CompareOp* = enum
    Eq
    Ne
    Lt
    Le
    Gt
    Ge

proc parseCompareOp*(s: string): CompareOp =
  parseEnum[CompareOp](s)

