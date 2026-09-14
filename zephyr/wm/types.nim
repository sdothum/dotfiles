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

type
  Geometry* = object
    x*: int
    y*: int
    width*: int
    height*: int

type
  ScreenGeometry* = object
    gap*: int
    margin*: int
    top*: int
    bottom*: int
    width*: int
    height*: int

type
  Grid* = object
    columns*: int
    column*: int
    rows*: int
    row*: int

type
  Spread* = object
    columns*: int
    rows*: int
