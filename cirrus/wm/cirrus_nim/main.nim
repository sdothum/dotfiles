## Stage 3 production candidate: X runtime, authoritative startup identities
## and minimum runtime client lifecycle. Higher WM policy remains deferred.

import std/[os, json, strformat, options, sequtils]
import x11/abi
import x11/connection
import x11/pointer_modifiers
import x11/bindings
import runtime/event_loop
import runtime/coordinator
import runtime/event_types
import x11/realize
import model/[identity, state, types]
import model/lifecycle
import model/pointer
import startup/[adoption, identity_service, legacy_cli]
import startup/cirrusrc

proc usage() =
  stderr.writeLine("usage: cirrus-nim [-c CONFIG_PATH] [--test-events | --test-state | --test-lifecycle [--test-pause-before-effects]] | --abi")

proc stateJson(state: WmState): string =
  var clients = newJArray()
  for client in state.clientsInManagedOrder():
    clients.add(%*{
      "window": &"0x{client.window.raw:08x}",
      "client_id": client.id.raw,
      "mapped": client.mapped,
      "group": client.group.raw,
      "wm_state": $client.startupWmState,
      "token": client.token.formatToken(),
      "runtime_managed": client.runtimeManaged,
      "geometry": %*{"x": client.geometry.x, "y": client.geometry.y,
          "width": client.geometry.width, "height": client.geometry.height},
      "orig_geometry": %*{"x": client.origGeometry.x, "y": client.origGeometry.y,
          "width": client.origGeometry.width, "height": client.origGeometry.height},
      "hints": %*{"min_width": client.resizeHints.minWidth,
          "min_height": client.resizeHints.minHeight,
          "width_inc": client.resizeHints.widthIncrement,
          "height_inc": client.resizeHints.heightIncrement},
      "geometry_flags": %*{"maxed": client.maxed, "hmaxed": client.hmaxed,
          "vmaxed": client.vmaxed, "monocled": client.monocled},
      "decoration": (if client.decoration.isSome:
          %(&"0x{client.decoration.get.raw:08x}") else: newJNull())
    })
  let focused = state.focusedClient
  var focusOrder = newJArray()
  for client in state.focusOrderClients():
    focusOrder.add(%(&"0x{client.window.raw:08x}"))
  var activeGroups = newJArray()
  for index, active in state.activeGroups:
    if active: activeGroups.add(%index)
  $(%*{"clients": clients,
       "focused": (if focused.isSome: %(&"0x{focused.get.window.raw:08x}") else: newJNull()),
       "focus_order": focusOrder, "current_group": state.currentGroup.raw,
       "active_groups": activeGroups})

proc legacyStateJson(state: WmState): string =
  var clients = newJArray()
  for client in state.clientsInManagedOrder():
    clients.add(%*{
      "window": &"0x{client.window.raw:08x}",
      "client_id": client.id.raw,
      "mapped": client.mapped,
      "group": client.group.raw,
      "wm_state": $client.startupWmState,
      "token": client.token.formatToken(),
      "runtime_managed": client.runtimeManaged,
      "decoration": (if client.decoration.isSome:
          %(&"0x{client.decoration.get.raw:08x}") else: newJNull())
    })
  $(%*{"clients": clients})

proc main(): int =
  let startupOptions = parseLegacyStartupOptions(commandLineParams(), paramStr(0))
  for diagnostic in startupOptions.diagnostics:
    stderr.writeLine(diagnostic)
  case startupOptions.action
  of lsaHelp, lsaVersion:
    stderr.write(startupOptions.earlyOutput)
    return 0
  of lsaContinue:
    discard
  var configPath = startupOptions.configPath
  var logEvents = false
  var dumpState = false
  var testLifecycle = false
  var pauseBeforeEffects = false
  var testStage4 = false
  var testStage5 = false
  var testStage6 = false
  var testPrivateEffects = false
  let params = startupOptions.remainingArgs
  var paramIndex = 0
  while paramIndex < params.len:
    let arg = params[paramIndex]
    case arg
    of "--test-events": logEvents = true
    of "--test-state": dumpState = true
    of "--test-lifecycle": testLifecycle = true
    of "--test-pause-before-effects":
      testLifecycle = true
      pauseBeforeEffects = true
    of "--test-stage4":
      testStage4 = true
      testLifecycle = true
    of "--test-stage5":
      testStage5 = true
      testLifecycle = true
      dumpState = true
    of "--test-stage6":
      testStage6 = true
      testLifecycle = true
    of "--test-private-effects":
      testPrivateEffects = true
      testLifecycle = true
    of "--abi":
      stdout.write(eventAbiReport())
      return 0
    else:
      usage()
      return 2
    inc paramIndex

  when not defined(stage7d3cPrivateExecution):
    if testPrivateEffects:
      usage()
      return 2

  var connection: XConnection
  var cirrusrcChild: CirrusrcChild
  try:
    connection = connect()
    connection.claimWindowManager()
    connection.publishIdentity(uint32(getCurrentProcessId()))
    let epoch = newProcessEpoch()
    var state = newWmState()
    let discoveredPointerMasks = discoverPointerLockMasks(connection.rawHandleForX11())
    let pointerMasks = normalizeLockMasks(discoveredPointerMasks, ModMaskLock)
    state.setPointerModifiers(defaultPointerModifier(), pointerMasks[0], pointerMasks[1], pointerMasks[2])
    let normalStartup = not (logEvents or dumpState or testLifecycle or testStage4 or
        testStage5 or testStage6 or testPrivateEffects)
    when not defined(stage7d2PrivateTransport) and
        not defined(stage7d3cPrivateExecution):
      if normalStartup:
        let initialEwmh = state.transition(epoch,
            WmInput(kind: wiInitializeEwmh))
        for effect in initialEwmh.effects:
          connection.realize(effect,
              state.clientsInManagedOrder().mapIt(it.window.raw))
        connection.publishEwmhStartup()
        connection.initializeRandr()
        try:
          cirrusrcChild = launchCirrusrc(configPath,
              connection.fileDescriptor())
        except CatchableError as error:
          stderr.writeLine("cirrus-nim: could not start cirrusrc: " & error.msg)
      else:
        connection.initializeRandr()
    else:
      connection.initializeRandr()
    connection.adoptStartup(state, epoch)
    for client in state.clientsInManagedOrder():
      connection.assignMonitor(client.window.raw, client.geometry.x,
          client.geometry.y, fallback = true)
    # Stage 2's legacy --test-state seam remains observation-only. Production
    # startup and Stage 4 tests complete management without replacing IDs.
    let observationOnlyTest = (dumpState and not testStage4 and not testStage5 and not testStage6) or
        (logEvents and not testLifecycle and not testStage4 and not testStage5 and not testStage6)
    if not observationOnlyTest:
      # Adoption prepends each identity to managed order, while C completes
      # startup setup in the original bottom-to-top QueryTree scan order.
      let startupClients = state.clientsInManagedOrder()
      for offset in 0 ..< startupClients.len:
        let client = startupClients[startupClients.len - offset - 1]
        let decoration = WindowId(connection.allocateWindowId())
        let setup = state.transition(epoch, WmInput(kind: wiCompleteStartupClient,
            window: client.window, decoration: decoration,
            x: client.x, y: client.y, width: client.width, height: client.height,
            setByUser: client.setByUser))
        for effect in setup.effects:
          connection.realize(effect, state.clientsInManagedOrder().mapIt(it.window.raw))
      var groupsEffect = WmEffect(kind: wePublishActiveGroups)
      for index, active in state.activeGroups:
        if active: groupsEffect.groups.add(RawGroup(index))
      connection.realize(groupsEffect, state.clientsInManagedOrder().mapIt(it.window.raw))
      let startupFocus = state.transition(epoch, WmInput(kind: wiStartupFocus,
          actualFocus: WindowId(connection.inputFocus())))
      for effect in startupFocus.effects:
        connection.realize(effect, state.clientsInManagedOrder().mapIt(it.window.raw))
    var adoptedWindows: seq[uint32]
    for client in state.clientsInManagedOrder():
      adoptedWindows.add(client.window.raw)
    if not observationOnlyTest:
      connection.publishClientLists(adoptedWindows)
      connection.publishClientListStacking(adoptedWindows)
    if dumpState:
      echo "STATE " & (if testStage4 or testStage5: state.stateJson else: state.legacyStateJson)
      stdout.flushFile()
    if logEvents and not testLifecycle:
      # Stage 1-only seam: keep normalized-event observation without lifecycle
      # dispatch so the earlier runtime-boundary test remains meaningful.
      runEventLoop(connection, true)
    else:
      var coordinator = LifecycleCoordinator(connection: connection,
          state: addr state, epoch: epoch, trace: testLifecycle,
          pauseBeforeEffects: pauseBeforeEffects, testControls: testStage4 or testStage5 or testStage6,
          testGeometry: testStage5, testStacking: testStage6,
          privateExecution: testPrivateEffects)
      let handler: EventHandler = proc(event: XEvent) = coordinator.handle(event)
      let terminationHandler: StopHandler = proc(): bool =
        coordinator.terminationRequested
      var idleHandler: IdleHandler
      if cirrusrcChild != nil:
        idleHandler = proc(): bool = cirrusrcChild.pollExit()
      runEventLoop(connection, testLifecycle, handler, idleHandler,
          terminationHandler)
      if coordinator.terminationRequested:
        connection.prepareForTermination(state.clientsInManagedOrder(),
            coordinator.restartRequested)
        result = int(coordinator.terminationStatus)
      else:
        result = 0
  except CatchableError as error:
    stderr.writeLine("cirrus-nim: " & error.msg)
    result = 1
  finally:
    cirrusrcChild.stop()
    connection.close()

when isMainModule:
  quit(main())
