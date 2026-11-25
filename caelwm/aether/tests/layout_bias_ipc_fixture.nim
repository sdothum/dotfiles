## Offline resident: the production IPC loop and policy state, without X11.
import std/[options, oserrors]
import ../wm/daemon_ipc
import ../policy/layout_bias

proc main() =
  initializeResidentBias()
  doAssert localBias().get == LayoutBias.Left
  var ipc: IpcServer
  doAssert ipc.open(), $osLastError()
  defer: ipc.close()
  echo "READY"
  stdout.flushFile()
  while true:
    discard ipc.service(-1)
    # Exercise the same resident accessor used by rules after every IPC pass.
    doAssert localBias().isSome

main()
