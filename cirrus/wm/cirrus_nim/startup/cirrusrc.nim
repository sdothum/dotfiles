## Asynchronous, source-compatible startup execution for cirrusrc.
import std/[os, osproc, strformat, times, monotimes, posix]

type CirrusrcChild* = ref object
  process: Process
  scriptPath: string

proc resolveCirrusrcPath*(explicitPath: string): string =
  if explicitPath.len > 0:
    return explicitPath
  if existsEnv("XDG_CONFIG_HOME"):
    return getEnv("XDG_CONFIG_HOME") & "/cirrus/cirrusrc"
  if not existsEnv("HOME"):
    return ""
  getEnv("HOME") & "/.config/cirrus/cirrusrc"

proc protectXcbDescriptor(fd: cint) =
  if fd < 0:
    raise newException(IOError, "cannot isolate invalid XCB descriptor")
  let currentFlags = posix.fcntl(fd, posix.F_GETFD)
  if currentFlags < 0:
    raise newException(IOError, "cannot inspect XCB descriptor flags")
  if posix.fcntl(fd, posix.F_SETFD, currentFlags or posix.FD_CLOEXEC) < 0:
    raise newException(IOError, "cannot mark XCB descriptor close-on-exec")

proc launchCirrusrc*(explicitPath: string; xcbFd: cint): CirrusrcChild =
  let scriptPath = resolveCirrusrcPath(explicitPath)
  if scriptPath.len == 0:
    stderr.writeLine("cirrus-nim: HOME is unset; skipping cirrusrc")
    return nil
  if not fileExists(scriptPath):
    stderr.writeLine(&"cirrus-nim: no startup script at {scriptPath}; continuing")
    return nil
  let permissions = getFilePermissions(scriptPath)
  if fpUserExec notin permissions and fpGroupExec notin permissions and
      fpOthersExec notin permissions:
    stderr.writeLine(&"cirrus-nim: startup script is not executable: {scriptPath}")
    return nil
  let setsidPath = findExe("setsid")
  if setsidPath.len == 0:
    stderr.writeLine("cirrus-nim: setsid is unavailable; skipping startup script")
    return nil

  protectXcbDescriptor(xcbFd)
  var execPath = scriptPath
  # C execl resolves a relative name from cwd; setsid uses execvp, which would
  # search PATH for a slashless name. Make that case explicitly cwd-relative.
  if not isAbsolute(execPath) and '/' notin execPath:
    execPath = "./" & execPath

  result = CirrusrcChild(scriptPath: scriptPath,
      process: startProcess(setsidPath, args = ["--", execPath],
          options = {poParentStreams}))
  stderr.writeLine(&"cirrus-nim: started cirrusrc pid={result.process.processID} path={scriptPath}")

proc pollExit*(child: CirrusrcChild): bool =
  if child == nil or child.process == nil:
    return false
  let code = child.process.peekExitCode()
  if code == -1:
    return true
  if code != -1:
    stderr.writeLine(&"cirrus-nim: cirrusrc exited status={code}")
    child.process.close()
    child.process = nil
  false

proc stop*(child: CirrusrcChild) =
  if child == nil or child.process == nil:
    return
  let process = child.process
  let initial = process.peekExitCode()
  if initial != -1:
    process.close()
    child.process = nil
    return

  let processGroup = cast[Pid](-process.processID)
  discard posix.kill(processGroup, SIGTERM)
  let deadline = getMonoTime() + initDuration(milliseconds = 750)
  while process.peekExitCode() == -1 and getMonoTime() < deadline:
    sleep(20)
  if process.peekExitCode() == -1:
    discard posix.kill(processGroup, SIGKILL)
    discard process.waitForExit()
  process.close()
  child.process = nil
