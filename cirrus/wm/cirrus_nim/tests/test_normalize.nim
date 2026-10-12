import std/unittest
import ../x11/events
import ../runtime/[event_types, normalize]

suite "Stage 1 event normalization":
  test "unrecognized event type is harmless and preserved as unknown":
    let raw = XEventData(responseType: 117)
    let event = normalizeEvent(raw)
    check event.kind == xeUnknown
    check event.rawType == 117

  test "send-event bit is separated from event type":
    let raw = XEventData(responseType: 0x80'u8 or EventPropertyNotify)
    let event = normalizeEvent(raw)
    check event.kind == xePropertyNotify
    check event.sendEvent

  test "CirculateRequest normalizes the chosen child and incoming place":
    let raw = XEventData(responseType: EventCirculateRequest,
        eventWindow: 0x42, window: 0x00400000, circulatePlace: 1)
    let event = normalizeEvent(raw)
    check event.kind == xeCirculateRequest
    check event.eventWindow == 0x42
    check event.window == 0x00400000
    check event.circulatePlace == 1

  test "ButtonPress preserves event target, child, state, time and coordinates":
    let raw = XEventData(responseType: EventButtonPress,
        eventWindow: 0x00400000, window: 0x00400000,
        root: 0x42, child: 0x00600000, detail: 2, state: 0x50,
        time: 1234, rootX: 321, rootY: 222, eventX: 31, eventY: 22)
    let event = normalizeEvent(raw)
    check event.kind == xeButtonPress
    check event.eventWindow == 0x00400000
    check event.child == 0x00600000
    check event.root == 0x42
    check event.detail == 2
    check event.state == 0x50
    check event.time == 1234
    check event.rootX == 321 and event.rootY == 222
    check event.eventX == 31 and event.eventY == 22
