## Compile-time diagnostic only; never issues X requests or synchronizes XCB.
when defined(stage1cFocusDiagnostics):
  import std/[os, json]
  var dispatchCounter, queryCounter, orderCounter: uint64
  var currentDispatch*: uint64

  proc record*(row: JsonNode) =
    inc orderCounter
    row["relative_order"] = %orderCounter
    let path = getEnv("CIRRUS_STAGE1C_FOCUS_TRACE")
    if path.len > 0:
      let stream = open(path, fmAppend)
      stream.writeLine($row)
      stream.close()

  proc beginDispatch*(eventType: string; sequence, window: uint32;
      detail, mode: uint8): uint64 =
    result = currentDispatch
    inc dispatchCounter
    currentDispatch = dispatchCounter
    record(%*{"dispatch_id": currentDispatch, "event_type": eventType,
      "event_sequence": sequence, "event_window": window,
      "event_detail": detail, "event_mode": mode, "handler_entry": true})

  proc endDispatch*(previous: uint64) =
    record(%*{"dispatch_id": currentDispatch, "handler_exit": true})
    currentDispatch = previous

  proc queryRecord*(callSite: string; sequence, focus: uint32;
      revert: uint8; status: string) =
    inc queryCounter
    record(%*{"query_id": queryCounter, "dispatch_id": currentDispatch,
      "non_event_context": (if currentDispatch == 0: "startup" else: ""),
      "call_site": callSite, "actual_cookie_sequence": sequence,
      "reply_focus_xid": focus, "reply_revert_to": revert,
      "request_status": status})
