# Direct port of cirrus/client.c. See LICENSE.reference and behavioral_inventory.md.
import std/strutils
import posix
import xcb_compat

const clientVersion {.strdefine.} = "0.5.2"
var
  cmdCount {.importc: "cmdCount".}: cint
  cmdLine {.importc: "cmdLine".}: cstringArray
proc gettimeofday(tv: ptr Timeval, zone: pointer): cint {.importc, header: "<sys/time.h>".}
proc cExit(status: cint) {.importc: "exit", header: "<stdlib.h>", noreturn.}
proc strtol(s: cstring, tail: ptr cstring, base: cint): clong {.importc, header: "<stdlib.h>".}
proc strtoul(s: cstring, tail: ptr cstring, base: cint): culong {.importc, header: "<stdlib.h>".}
proc strtoull(s: cstring, tail: ptr cstring, base: cint): culonglong {.importc, header: "<stdlib.h>".}
proc strchr(s: cstring, ch: cint): cstring {.importc, header: "<string.h>".}
proc malloc(size: csize_t): pointer {.importc, header: "<stdlib.h>".}
proc calloc(count,size: csize_t): pointer {.importc, header: "<stdlib.h>".}
proc strlen(s: cstring): csize_t {.importc, header: "<string.h>".}
proc strcmp(a,b: cstring): cint {.importc, header: "<string.h>".}
proc strncmp(a,b: cstring, n: csize_t): cint {.importc, header: "<string.h>".}
proc strspn(s,accept: cstring): csize_t {.importc, header: "<string.h>".}
proc strtok(s,delimiters: cstring): cstring {.importc, header: "<string.h>".}
type ConstPointer {.importc: "const void *", nodecl.} = distinct pointer
proc qsort(base: pointer, count,size: csize_t, cmp: proc(a,b: ConstPointer): cint {.cdecl.}) {.importc, header: "<stdlib.h>".}
proc snprintf(buffer: cstring, size: csize_t, format: cstring): cint {.importc, header: "<stdio.h>", varargs.}
proc strcasecmp(a,b: cstring): cint {.importc, header: "<strings.h>".}
proc printf(format: cstring): cint {.importc, header: "<stdio.h>", varargs, discardable.}
proc fprintf(f: File, format: cstring): cint {.importc, header: "<stdio.h>", varargs, discardable.}
proc fputs(s: cstring, f: File): cint {.importc, header: "<stdio.h>", discardable.}
proc errx(status: cint, format: cstring) {.importc, header: "<err.h>", varargs, noreturn.}
proc fail(s: string) = errx(1, "%s", s.cstring)
proc invalid() = fail("invalid action command")
proc usage(status: cint) =
  fprintf(stderr, "Usage: %s [-h|-v] <command> [args...]\n", cmdLine[0])
  cExit(status)
proc equalCI(a,b: string): bool = strcasecmp(a.cstring,b.cstring) == 0
proc signed(s: string, v: var int32): bool =
  var tail: cstring
  errno = 0
  let n = strtol(s.cstring, addr tail, 10)
  if errno != 0 or s.len == 0 or tail[0] != '\0' or n < low(int32).clong or n > high(int32).clong: return false
  v = int32(n)
  true
proc unsigned(s: string, base: cint, v: var uint32): bool =
  if s.len == 0 or s[0] == '-': return false
  var tail: cstring
  errno = 0
  let n = strtoul(s.cstring, addr tail, base)
  if errno != 0 or tail[0] != '\0' or n > high(uint32).culong: return false
  v = uint32(n)
  true
proc winid(s: string, v: var uint32): bool = unsigned(s,16,v) and v != 0
proc loose(s: string, base: cint, v: var uint32): bool =
  errno = 0
  v = cast[uint32](strtol(s.cstring,nil,base))
  errno == 0
proc choice(s: string, options: openArray[string], values: openArray[uint32], v: var uint32): bool =
  for i,key in options:
    if equalCI(s,key):
      v = values[i]
      return true
proc direction(s: string, v: var uint32): bool =
  choice(s,["up","north","down","south","left","west","right","east"],[0'u32,0,2,2,3,3,1,1],v)
proc position(s: string, v: var uint32): bool =
  choice(s,["topleft","topright","bottomleft","bottomright","middle","center","centre","left","bottom","top","right","all"],[4'u32,5,7,6,8,8,8,2,1,0,3,9],v)
proc optional(a: seq[string]): uint32 =
  if a.len > 1: invalid()
  if a.len == 1 and not winid(a[0],result): fail("malformed winid")

include protocol
var conn: ptr Connection
var scr: ptr Screen
var bulkBody, raiseBody: cstring
proc sendIpc(command: uint32, data: array[4,uint32]) =
  var msg: Message
  msg.response_type = 33
  msg.`type` = atom(conn,"__WM_IPC_COMMAND")
  msg.format = 32
  msg.data.data32[0] = command
  for i in 0..3: msg.data.data32[i+1] = data[i]
  let error = check(conn,send(conn,0,scr.root,1'u32 shl 20,cast[cstring](addr msg)))
  if error != nil:
    fprintf(stderr,"oops %d\n",cint(error.error_code))
    freeMem(error)
  flush(conn)

proc after(s: cstring, n: int): cstring = cast[cstring](cast[uint](s)+uint(n))
proc compareIds(a,b: ConstPointer): cint {.cdecl.} =
  strcmp(cast[ptr cstring](a)[],cast[ptr cstring](b)[])

type GeometryRecord = object
  window: uint32
  x,y: int32
  width,height: uint32

proc decodeRecords(response: cstring, geometries: bool): bool =
  if strcmp(response,"OK") == 0: return true
  if strncmp(response,"OK\n",3) != 0: return false
  let body = after(response,3)
  let size = strlen(body)
  let copy = cast[cstring](malloc(size+1))
  if copy == nil: return false
  copyMem(copy,body,int(size)+1)
  defer: freeMem(copy)
  var count = 0
  for i in 0..<int(size):
    if copy[i] == '\n': inc count
  if size != 0 and copy[int(size)-1] != '\n': inc count
  var records: ptr UncheckedArray[GeometryRecord]
  var windows,groups: ptr UncheckedArray[uint32]
  if geometries:
    records = cast[ptr UncheckedArray[GeometryRecord]](calloc(csize_t(count),csize_t(sizeof(GeometryRecord))))
    if count != 0 and records == nil: return false
  else:
    windows = cast[ptr UncheckedArray[uint32]](calloc(csize_t(count),csize_t(sizeof(uint32))))
    groups = cast[ptr UncheckedArray[uint32]](calloc(csize_t(count),csize_t(sizeof(uint32))))
    if count != 0 and (windows == nil or groups == nil):
      freeMem(windows); freeMem(groups)
      return false
  defer:
    freeMem(records)
    freeMem(windows)
    freeMem(groups)
  var line = strtok(copy,"\n")
  var i = 0
  while line != nil:
    var field = strchr(line,cint(ord(' ')))
    if field == nil or field == line: return false
    if geometries:
      if strchr(after(field,1),cint(ord(' '))) == after(field,1): return false
    else:
      if strchr(after(field,1),cint(ord(' '))) != nil: return false
    field[0] = '\0'
    field = after(field,1)
    if strlen(line) != 10 or line[0] != '0' or line[1] != 'x': return false
    var tail: cstring
    errno = 0
    let w = strtoul(after(line,2),addr tail,16)
    if errno != 0 or tail[0] != '\0' or (geometries and w > high(uint32).culong): return false
    if geometries:
      records[i].window = cast[uint32](w)
      for number in 0..3:
        # Keep this before the NULL check: historical C SIGSEGV behavior.
        var next = strchr(field,cint(ord(' ')))
        if field == nil or field[0] == '\0': return false
        if next != nil:
          next[0] = '\0'
          next = after(next,1)
        errno = 0
        if number < 2:
          let n = strtol(field,addr tail,10)
          if errno != 0 or field[0] == '\0' or tail[0] != '\0' or n < low(int32).clong or n > high(int32).clong: return false
          if number == 0: records[i].x = int32(n)
          else: records[i].y = int32(n)
        else:
          let n = strtoul(field,addr tail,10)
          if errno != 0 or field[0] == '\0' or tail[0] != '\0' or n > 65535: return false
          if number == 2: records[i].width = uint32(n)
          else: records[i].height = uint32(n)
        field = next
      if field != nil and field[0] != '\0': return false
      for j in 0..<i:
        if records[j].window == records[i].window: return false
    else:
      errno = 0
      let g = strtoull(field,addr tail,10)
      if errno != 0 or field[0] == '\0' or tail[0] != '\0' or g > high(uint32).culonglong: return false
      windows[i] = cast[uint32](w)
      groups[i] = uint32(g)
      for j in 0..<i:
        if windows[j] == windows[i]: return false
    inc i
    line = strtok(nil,"\n")
  if i != count: return false
  for j in 0..<count:
    if geometries:
      let r = records[j]
      printf("0x%08x %d %d %u %u\n",r.window,r.x,r.y,r.width,r.height)
    else: printf("0x%08x %u\n",windows[j],groups[j])
  true

proc decode(q: uint32, response: cstring): cint =
  let ids = q in [IPCWindowIds,IPCWindowStack]
  let count = q in [IPCWindowCount,IPCGroupCount,IPCWindowGroup]
  let ack = q in [IPCActionWindowLayer,IPCActionWindowReset,IPCActionWindowHide,IPCActionWindowStackCycle,IPCActionGroupActivate,IPCActionGroupDeactivate,IPCActionWindowApplyGeometries,IPCActionWindowRaiseMany]
  var valid = false
  let suffix = after(response,min(3,int(strlen(response))))
  if ids and strcmp(response,"OK") == 0: valid = true
  elif ids and strncmp(response,"OK\n",3) == 0:
    var count = 1
    for i in 0..<int(strlen(suffix)):
      if suffix[i] == '\n': inc count
    let lines = cast[ptr UncheckedArray[cstring]](calloc(csize_t(count),csize_t(sizeof(cstring))))
    if lines == nil:
      fprintf(stderr,"borealis: unable to allocate ID list\n")
      return 1
    defer: freeMem(lines)
    var id = suffix
    valid = true
    for i in 0..<count:
      lines[i] = id
      var lineEnd = strchr(id,cint(ord('\n')))
      if lineEnd != nil: lineEnd[0] = '\0'
      if strlen(id) != 10 or id[0] != '0' or id[1] != 'x': valid = false; break
      var tail: cstring
      discard strtoul(after(id,2),addr tail,16)
      if tail[0] != '\0': valid = false; break
      id = if lineEnd == nil: after(id,int(strlen(id))) else: after(lineEnd,1)
    if valid:
      if q != IPCWindowStack: qsort(lines,csize_t(count),csize_t(sizeof(cstring)),compareIds)
      for i in 0..<count: printf("%s\n",lines[i])
  elif count and strncmp(response,"OK ",3) == 0 and suffix[0] != '\0' and strspn(suffix,"0123456789") == strlen(suffix):
    printf("%s\n",suffix)
    valid = true
  elif q == IPCWindowClassname and strcmp(response,"OK") == 0: valid = true
  elif q == IPCWindowClassname and strncmp(response,"OK ",3) == 0 and suffix[0] != '\0':
    printf("%s\n",suffix)
    valid = true
  elif q == IPCWindowGeometry and strncmp(response,"OK\n",3) == 0 and suffix[0] != '\0':
    fputs(suffix,stdout)
    valid = true
  elif q == IPCWindowSnapshot and (strncmp(response,"OK\nSNAPSHOT 1\n",14) == 0 or strncmp(response,"OK\nSNAPSHOT 2\n",14) == 0):
    fputs(suffix,stdout)
    valid = true
  elif q == IPCWindowStackGeometries: valid = decodeRecords(response,true)
  elif q == IPCWindowGroups: valid = decodeRecords(response,false)
  elif ack and strcmp(response,"OK") == 0: valid = true
  elif q in [IPCWindowFocused,IPCGroupCurrent] and strncmp(response,"OK ",3) == 0 and suffix[0] != '\0':
    printf("%s\n",suffix)
    valid = true
  if valid: return 0
  if strncmp(response,"ERROR ",6) == 0: fprintf(stderr,"borealis: %s\n",after(response,6))
  else: fprintf(stderr,"borealis: malformed windowchef response\n")
  1

proc query(q: uint32, selector = "", scope = 0'u32, selectorType = 0'u32, explicit = false, window = 0'u32, hasSelector = false): cint =
  result = 1
  let responseAtom = atom(conn,"__WM_IPC_RESPONSE")
  let replyWindow = generateId(conn)
  var values = [1'u32 shl 22]
  var error = check(conn,create(conn,0,replyWindow,scr.root,0,0,1,1,0,2,0,1'u32 shl 11,addr values[0]))
  if error != nil:
    fprintf(stderr,"borealis: unable to create reply window: X error %u\n",cuint(error.error_code))
    freeMem(error)
    return
  var msg: Message
  msg.response_type = 33
  msg.`type` = atom(conn,"__WM_IPC_COMMAND")
  msg.format = 32
  msg.data.data32 = [q,replyWindow,0'u32,scope,selectorType]
  if hasSelector: msg.data.data32[2] = atom(conn,selector)
  if q == IPCWindowIds and window != 0:
    var group = window
    error = check(conn,changeChecked(conn,0,replyWindow,atom(conn,"__WM_IPC_REQUEST"),6,32,1,addr group))
    if error != nil:
      fprintf(stderr,"borealis: unable to write group filter: X error %u\n",cuint(error.error_code))
      freeMem(error)
      destroy(conn,replyWindow)
      return
  if q in [IPCActionWindowApplyGeometries,IPCActionWindowRaiseMany]:
    let body = if q == IPCActionWindowApplyGeometries: bulkBody else: raiseBody
    change(conn,0,replyWindow,atom(conn,"__WM_IPC_REQUEST"),31,8,uint32(strlen(body)),cast[pointer](body))
  if q in [IPCWindowGeometry,IPCActionWindowReset,IPCActionWindowHide,IPCActionWindowLayer,IPCWindowStack,IPCWindowStackGeometries,IPCActionWindowStackCycle]:
    msg.data.data32[2] = uint32(explicit)
    msg.data.data32[3] = window
  elif q == IPCWindowGroup:
    msg.data.data32[2] = 1
    msg.data.data32[3] = window
  elif q in [IPCActionGroupActivate,IPCActionGroupDeactivate]: msg.data.data32[2] = window
  defer:
    destroy(conn,replyWindow)
    flush(conn)
  error = check(conn,send(conn,0,scr.root,1'u32 shl 20,cast[cstring](addr msg)))
  if error != nil:
    fprintf(stderr,"borealis: unable to send query: X error %u\n",cuint(error.error_code))
    freeMem(error)
    return
  flush(conn)
  var pfd = TPollfd(fd: fd(conn),events: POLLIN,revents: 0)
  var started, finished: Timeval
  discard gettimeofday(addr started,nil)
  while true:
    var e = event(conn)
    while e != nil:
      var matches = false
      if (e.response_type and 0x7f) == 28:
        let prop = cast[ptr PropertyEvent](e)
        matches = prop.window == replyWindow and prop.atom == responseAtom
      freeMem(e)
      if matches:
        let reply = property(conn,replyWindow,responseAtom)
        if reply == nil:
          fprintf(stderr,"borealis: unable to read windowchef response\n")
          return
        let size = valueLength(reply)
        let response = cast[cstring](calloc(cast[csize_t](int(size))+1,1))
        if response == nil:
          fprintf(stderr,"borealis: unable to allocate response buffer\n")
          freeMem(reply)
          return
        if size != 0: copyMem(response,value(reply),cast[int](size))
        let status = decode(q,response)
        freeMem(response)
        freeMem(reply)
        return status
      e = event(conn)
    if hasError(conn) != 0:
      fprintf(stderr,"borealis: connection closed without a windowchef response\n")
      return
    discard gettimeofday(addr finished,nil)
    let elapsed = (int64(finished.tv_sec)-int64(started.tv_sec))*1000 + (int64(finished.tv_usec)-int64(started.tv_usec)) div 1000
    let remaining = cast[cint](2000'i64-elapsed)
    let polled = if remaining <= 0: 0 else: poll(addr pfd,1,cint(remaining))
    if polled <= 0:
      fprintf(stderr,"borealis: timed out waiting for windowchef response\n")
      return

type Collection = object
  selector: string
  scope, kind, group: uint32
  hasSelector: bool
proc collectionVArgs(a: seq[string], c: var Collection): bool =
  c.scope = 0
  c.kind = 0
  c.hasSelector = false
  case a.len
  of 0: return true
  of 1:
    if a[0] == "--all": c.scope = 1; return true
    if a[0].startsWith("-"): return false
    c.selector = a[0]; c.kind = 1; c.hasSelector = true
    return true
  of 2:
    if a[0] == "--name" and a[1] notin ["--all","--name"]:
      c.selector = a[1]; c.kind = 2; c.hasSelector = true
      return true
    if a[0] == "--all" and not a[1].startsWith("-"):
      c.scope = 1; c.selector = a[1]; c.kind = 1; c.hasSelector = true
      return true
    if not a[0].startsWith("-") and a[1] == "--all":
      c.scope = 1; c.selector = a[0]; c.kind = 1; c.hasSelector = true
      return true
    return false
  of 3:
    if a[0] != "--all" or a[1] != "--name" or a[2] in ["--all","--name"]: return false
    c.scope = 1; c.selector = a[2]; c.kind = 2; c.hasSelector = true
    return true
  else: return false
proc idsVArgs(a: seq[string], c: var Collection): bool =
  var rest: seq[string]
  var i = 0
  c.group = 0
  while i < a.len:
    if a[i] == "--group":
      inc i
      if c.group != 0 or i == a.len or not unsigned(a[i],10,c.group) or c.group == 0: return false
    else:
      if rest.len == 3: return false
      rest.add(a[i])
      if a[i] == "--name" and i+1 < a.len:
        if rest.len == 3: return false
        inc i
        rest.add(a[i])
    inc i
  collectionVArgs(rest,c)

proc anyItCI(options: openArray[string], s: string): bool =
  for option in options:
    if equalCI(option,s): return true

proc configVArgs(a: seq[string]): array[4,uint32] =
  if a.len == 0: fail("wm config requires a configuration key")
  var key = a[0]
  case key
  of "border_width": key = "outer_border_width"
  of "color_focused": key = "outer_color_focused"
  of "color_unfocused": key = "outer_color_unfocused"
  of "internal_border_width": key = "inner_border_width"
  of "internal_color_focused": key = "inner_color_focused"
  of "internal_color_unfocused": key = "inner_color_unfocused"
  else: discard
  const keys = ["apply_settings","border_style","outer_border_width","click_to_focus","outer_color_focused","outer_color_unfocused","corner_mask","corner_percent","cursor_position","enable_borders","enable_last_window_focusing","enable_resize_hints","enable_sloppy_focus","gap_width","groups_nr","inner_border_width","inner_color_focused","inner_color_unfocused","pointer_actions","pointer_modifier","replay_click_on_focus","sticky_windows"]
  let index = keys.find(key)
  if index < 0: fail("no such config key")
  let arity = if index == 13: 2 elif index == 18: 3 else: 1
  if a.len-1 != arity: fail("too many or not enough arguments. Want: " & $arity)
  result[0] = uint32(index)
  var valid = true
  case index
  of 0,9,10,11,12,20,21:
    result[1] = uint32(["true","yes","t","y","1"].anyItCI(a[1]))
  of 4,5,16,17: valid = loose(a[1],16,result[1])
  of 3: valid = choice(a[1],["left","middle","right","none","any"],[1'u32,2,3,high(uint32),0],result[1])
  of 8: valid = position(a[1],result[1])
  of 13: valid = position(a[1],result[1]) and loose(a[2],10,result[2])
  of 18:
    for i in 1..3:
      if not choice(a[i],["nothing","focus","move","resize_corner","resize_side"],[0'u32,1,2,3,4],result[i]): valid = false; break
  of 19: valid = choice(a[1],["alt","super"],[8'u32,64],result[1])
  else: valid = loose(a[1],10,result[1])
  if not valid: fail("malformed input")

proc wmVArgs(a: seq[string]) =
  if a.len < 1: fail("invalid wm command")
  case a[0]
  of "config": sendIpc(IPCWMConfig,configVArgs(a[1..^1]))
  of "quit":
    if a.len != 2: fail("wm quit expects one exit status")
    var status: uint32
    if not unsigned(a[1],10,status): fail("malformed exit status")
    sendIpc(IPCWMQuit,[status,0'u32,0,0])
  of "restart":
    if a.len != 1: fail("wm restart expects no arguments")
    sendIpc(IPCWMRestart,[0'u32,0,0,0])
  else: fail("invalid wm command")
proc actionVArgs(domain: string, a: seq[string]) =
  if a.len < 1: invalid()
  let verb = a[0]
  var data: array[4,uint32]
  var command: uint32
  var w, g: uint32
  var status: cint
  if domain == "window":
    case verb
    of "move","resize":
      var first = 1
      let relative = a.len > 1 and a[1] == "--relative"
      if relative: inc first
      if a.len-first < 2 or a.len-first > 3: invalid()
      var x,y: int32
      if not signed(a[first],x) or not signed(a[first+1],y): fail("malformed numeric argument")
      if verb == "resize" and not relative and (x < 0 or y < 0): fail("malformed dimensions")
      w = optional(a[first+2..^1])
      command = if verb == "move": IPCActionWindowMove else: IPCActionWindowResize
      data = [uint32(not relative),cast[uint32](x),cast[uint32](y),w]
    of "layer":
      if a.len < 2 or a.len > 3: fail("window layer expects normal|above|overlay [winid]")
      var layer: uint32
      case a[1]
      of "Normal","normal": layer = 0
      of "Above","above": layer = 1
      of "Overlay","overlay": layer = 2
      else: fail("invalid window layer")
      w = optional(a[2..^1])
      status = query(IPCActionWindowLayer,scope=1,selectorType=layer,explicit=w != 0,window=w)
      if status != 0: cExit(status)
      return
    of "maximize":
      var first = 1
      var axis = 0'u32
      if a.len > 1:
        case a[1]
        of "--horizontal": axis = 1; inc first
        of "--vertical": axis = 2; inc first
        else: discard
      w = optional(a[first..^1])
      command = IPCActionWindowMaximize
      data[0] = axis; data[1] = w
    of "monocle","close","hide","reset":
      w = optional(a[1..^1])
      case verb
      of "monocle": command = IPCActionWindowMonocle
      of "close": command = IPCActionWindowClose
      else:
        command = if verb == "hide": IPCActionWindowHide else: IPCActionWindowReset
        status = query(command,explicit=w != 0,window=w)
        if status != 0: cExit(status)
        return
      data[0] = w
    of "cycle":
      var reverse, groupScope: bool
      for arg in a[1..^1]:
        case arg
        of "--reverse":
          if reverse: invalid()
          reverse = true
        of "--group":
          if groupScope: invalid()
          groupScope = true
        else: invalid()
      command = if groupScope: (if reverse: IPCWindowRevCycleInGroup else: IPCWindowCycleInGroup) else: (if reverse: IPCWindowRevCycle else: IPCWindowCycle)
    of "focus":
      if a.len == 2 and a[1] == "--last": command = IPCWindowFocusLast
      elif a.len == 3 and a[1] == "--cardinal":
        command = IPCWindowCardinalFocus
        if not direction(a[2],data[0]): fail("malformed direction")
      elif a.len == 2 and winid(a[1],w):
        command = IPCWindowFocus; data[0] = w
      else: invalid()
    else: invalid()
  else:
    case verb
    of "add":
      if a.len < 2 or a.len > 3: invalid()
      if not unsigned(a[1],10,g): fail("malformed groupid")
      w = optional(a[2..^1])
      command = IPCActionGroupAdd; data[0] = g; data[1] = w
    of "remove":
      command = IPCActionGroupRemove; data[0] = optional(a[1..^1])
    of "clear","activate","deactivate":
      if a.len != 2: invalid()
      if not unsigned(a[1],10,g): fail("malformed groupid")
      if verb != "clear":
        command = if verb == "activate": IPCActionGroupActivate else: IPCActionGroupDeactivate
        status = query(command,window=g)
        if status != 0: cExit(status)
        return
      command = IPCGroupRemoveAllWindows; data[0] = g
    else: invalid()
  sendIpc(command,data)
proc dispatch(a: seq[string]) =
  case a[0]
  of "wm": wmVArgs(a[1..^1])
  of "window","group": actionVArgs(a[0],a[1..^1])
  else: fail("no such command")

proc bulkVArgs(a: seq[string]) =
  if a.len < 5 or a.len mod 5 != 0: fail("window apply-geometries requires XID X Y WIDTH HEIGHT records")
  let records = csize_t(a.len div 5)
  if records > (high(csize_t)-1) div 64: fail("window apply-geometries request too large")
  let capacity = records*64+1
  let body = cast[cstring](calloc(capacity,1))
  if body == nil: fail("unable to allocate geometry request")
  var used = 0.csize_t
  var i = 0
  while i < a.len:
    var w: uint32
    var x,y,width,height: int32
    if not winid(a[i],w) or not signed(a[i+1],x) or not signed(a[i+2],y) or not signed(a[i+3],width) or not signed(a[i+4],height) or width < 0 or height < 0 or width > 65535 or height > 65535:
      fail("malformed geometry record")
    let written = snprintf(after(body,int(used)),capacity-used,"0x%08x %d %d %d %d\n",w,x,y,width,height)
    if written < 0 or csize_t(written) >= capacity-used: fail("geometry request too large")
    used += csize_t(written)
    i += 5
  bulkBody = body
proc raiseVArgs(a: seq[string]) =
  if a.len < 1 or csize_t(a.len) > (high(csize_t)-1) div 11: fail("window raise-many requires one or more XIDs")
  let capacity = csize_t(a.len)*11+1
  let body = cast[cstring](calloc(capacity,1))
  if body == nil: fail("unable to allocate raise request")
  var used = 0.csize_t
  for arg in a:
    var w: uint32
    if not winid(arg,w): fail("malformed winid")
    let written = snprintf(after(body,int(used)),capacity-used,"0x%08x\n",w)
    if written < 0 or csize_t(written) >= capacity-used: fail("raise request too large")
    used += csize_t(written)
  raiseBody = body

proc main(): cint =
  var a: seq[string]
  for i in 1..<int(cmdCount): a.add($cmdLine[i])
  if a.len == 0: usage(1)
  case a[0]
  of "-h": usage(0)
  of "-v":
    fprintf(stderr,"borealis %s\n",clientVersion.cstring)
    fprintf(stderr,"Copyright (c) 2016-2019 Tudor Ioan Roman\n")
    fprintf(stderr,"Released under the ISC License\n")
    cExit(0)
  else: discard
  let collectionQuery = a.len >= 2 and a[0] == "window" and a[1] in ["ids","count"]
  var c: Collection
  if collectionQuery:
    let valid = if a[1] == "ids": idsVArgs(a[2..^1],c) else: collectionVArgs(a[2..^1],c)
    if not valid: fail("invalid window collection query arguments")
  conn = connect(nil,nil)
  if hasError(conn) != 0: fail("unable to connect to X server")
  scr = firstScreen(conn)
  defer: disconnect(conn)
  if a.len == 2:
    if a[0] == "window":
      case a[1]
      of "classname": return query(IPCWindowClassname)
      of "focused": return query(IPCWindowFocused)
      of "snapshot": return query(IPCWindowSnapshot,scope=1)
      else: discard
    elif a[0] == "group":
      case a[1]
      of "current": return query(IPCGroupCurrent)
      of "count": return query(IPCGroupCount,scope=1)
      else: discard
  if a.len >= 2 and a[0] == "window":
    var w: uint32
    case a[1]
    of "group":
      if a.len != 3 or not winid(a[2],w): fail("malformed winid")
      return query(IPCWindowGroup,scope=1,explicit=true,window=w)
    of "groups":
      if a.len != 3 or a[2] != "--all": fail("window groups requires --all")
      return query(IPCWindowGroups,scope=1)
    of "geometry":
      if a.len > 3: fail("too many arguments")
      if a.len == 3 and not loose(a[2],16,w): fail("malformed input")
      return query(IPCWindowGeometry,explicit=a.len == 3,window=w)
    of "stack":
      let cycle = a.len >= 3 and a[2] == "cycle"
      let maximum = if cycle: 4 else: 3
      if a.len > maximum: fail("invalid window stack arguments")
      if a.len == maximum and not loose(a[^1],16,w): fail("malformed input")
      return query((if cycle: IPCActionWindowStackCycle else: IPCWindowStack),explicit=a.len == maximum,window=w)
    of "apply-geometries":
      bulkVArgs(a[2..^1])
      let status = query(IPCActionWindowApplyGeometries)
      freeMem(bulkBody)
      bulkBody = nil
      return status
    of "raise-many":
      raiseVArgs(a[2..^1])
      let status = query(IPCActionWindowRaiseMany)
      freeMem(raiseBody)
      raiseBody = nil
      return status
    of "stack-geometries":
      if a.len > 3 or (a.len == 3 and not winid(a[2],w)): fail("malformed winid")
      return query(IPCWindowStackGeometries,explicit=a.len == 3,window=w)
    else: discard
  if collectionQuery:
    return query((if a[1] == "ids": IPCWindowIds else: IPCWindowCount),c.selector,c.scope,c.kind,false,c.group,c.hasSelector)
  var start = 0
  for i,arg in a:
    if arg == ".":
      if i > start: dispatch(a[start..<i])
      start = i+1
  if start < a.len: dispatch(a[start..^1])
  0

cExit(main())
