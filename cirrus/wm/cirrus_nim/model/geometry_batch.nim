## X-free normalization of C's property-backed geometry batch grammar.
import std/[options, strutils]
import ./[types, state, identity]

type GeometryBatchRecord* = object
  window*: WindowId
  x*, y*: int32
  width*, height*: uint16

proc number(text: string; base: uint64; unsigned: bool; value: var int64): bool =
  var index = 0
  while index < text.len and text[index] in {' ', '\t', '\r', '\v', '\f'}:
    inc index
  var negative = false
  if index < text.len and text[index] in {'+', '-'}:
    negative = text[index] == '-'
    inc index
  if base == 16 and index + 2 < text.len and text[index] == '0' and
      text[index + 1] in {'x', 'X'} and text[index + 2] in HexDigits:
    index += 2
  let first = index
  var magnitude = 0'u64
  let limit = if unsigned: uint64(high(culong))
      elif negative: 2147483648'u64 else: 2147483647'u64
  while index < text.len:
    let ch = text[index]
    let digit = case ch
      of '0'..'9': uint64(ord(ch) - ord('0'))
      of 'a'..'f': uint64(ord(ch) - ord('a') + 10)
      of 'A'..'F': uint64(ord(ch) - ord('A') + 10)
      else: high(uint64)
    if digit >= base or magnitude > (limit - digit) div base:
      return false
    magnitude = magnitude * base + digit
    inc index
  if index == first: return false
  if unsigned:
    if negative and magnitude != 0:
      magnitude = uint64(high(culong)) - magnitude + 1
    # Every unsigned field in this protocol is at most uint32.
    if magnitude > uint64(high(uint32)): return false
    value = int64(magnitude)
  else:
    value = if negative: -int64(magnitude) else: int64(magnitude)
  true

proc decodeGeometryBatch*(state: WmState; opcode: uint32; payload: seq[byte];
                          records: var seq[GeometryBatchRecord]): bool =
  records.setLen(0)
  if opcode notin [33'u32, 35'u32] or payload.len == 0 or payload.len > 65536:
    return false
  var count = 0
  var text = ""
  var terminated = false
  for value in payload:
    if value == byte('\n'): inc count
    if value == 0: terminated = true
    if not terminated: text.add(char(value))
  if payload[^1] != byte('\n'): inc count
  let checked = opcode == 35
  if count == 0 or count > 65536 div (if checked: 3 else: 2): return false
  var decoded: seq[GeometryBatchRecord]
  for line in text.split('\n'):
    # C strtok skips blank records, but checks the original newline count.
    if line.len == 0: continue
    if line[0] == ' ' or line[^1] == ' ' or "  " in line: return false
    let fields = line.split(' ')
    if fields.len != (if checked: 6 else: 5) or fields[0].len != 10 or
        not fields[0].startsWith("0x"): return false
    var xid, x, y, width, height: int64
    if not number(fields[0][2..^1], 16, true, xid): return false
    let window = WindowId(uint32(xid))
    let client = state.lookup(window)
    if client.isNone: return false
    for previous in decoded:
      if previous.window == window: return false
    let offset = if checked: 1 else: 0
    if checked and fields[1] != client.get.token.formatToken(): return false
    if not number(fields[1 + offset], 10, false, x) or
        not number(fields[2 + offset], 10, false, y) or
        not number(fields[3 + offset], 10, true, width) or
        not number(fields[4 + offset], 10, true, height) or
        width > int64(high(uint16)) or height > int64(high(uint16)):
      return false
    decoded.add(GeometryBatchRecord(window: window, x: int32(x), y: int32(y),
        width: uint16(width), height: uint16(height)))
  if decoded.len != count: return false
  records = decoded
  true
