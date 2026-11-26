## Asynchronous, source-compatible startup execution for aureolerc.
import std/[os, osproc, strformat, times, monotimes, posix]

type AureolercChild* = ref object
  process: Process
  scriptPath: string


# Resolves an explicit startup path before XDG_CONFIG_HOME and HOME defaults.

proc resolveAureolercPath*(explicitPath: string): string =
  if explicitPath.len > 0:
    return explicitPath
  if existsEnv("XDG_CONFIG_HOME"):
    return getEnv("XDG_CONFIG_HOME") & "/aureole/aureolerc"
  if not existsEnv("HOME"):
    return ""
  getEnv("HOME") & "/.config/aureole/aureolerc"


# Marks the XCB descriptor close-on-exec, raising IOError if isolation fails.

proc protectXcbDescriptor(fd: cint) =
  if fd < 0:
    raise newException(IOError, "cannot isolate invalid XCB descriptor")
  let currentFlags = posix.fcntl(fd, posix.F_GETFD)
  if currentFlags < 0:
    raise newException(IOError, "cannot inspect XCB descriptor flags")
  if posix.fcntl(fd, posix.F_SETFD, currentFlags or posix.FD_CLOEXEC) < 0:
    raise newException(IOError, "cannot mark XCB descriptor close-on-exec")


# Starts an eligible startup script in a separate session after protecting the XCB descriptor.
# Missing prerequisites are diagnosed and skipped without launching a child.

proc launchAureolerc*(explicitPath: string; xcbFd: cint): AureolercChild =
  let scriptPath = resolveAureolercPath(explicitPath)
  if scriptPath.len == 0:
    stderr.writeLine("aureole: HOME is unset; skipping aureolerc")
    return nil
  if not fileExists(scriptPath):
    stderr.writeLine(&"aureole: no startup script at {scriptPath}; continuing")
    return nil
  let permissions = getFilePermissions(scriptPath)
  if fpUserExec notin permissions and fpGroupExec notin permissions and
      fpOthersExec notin permissions:
    stderr.writeLine(&"aureole: startup script is not executable: {scriptPath}")
    return nil
  let setsidPath = findExe("setsid")
  if setsidPath.len == 0:
    stderr.writeLine("aureole: setsid is unavailable; skipping startup script")
    return nil

  protectXcbDescriptor(xcbFd)
  var execPath = scriptPath
  # C execl resolves a relative name from cwd; setsid uses execvp, which would
  # search PATH for a slashless name. Make that case explicitly cwd-relative.
  if not isAbsolute(execPath) and '/' notin execPath:
    execPath = "./" & execPath

  result = AureolercChild(scriptPath: scriptPath,
      process: startProcess(setsidPath, args = ["--", execPath],
          options = {poParentStreams}))
  stderr.writeLine(&"aureole: started aureolerc pid={result.process.processID} path={scriptPath}")


# Reaps a finished startup child and reports whether its process is still running.

proc pollExit*(child: AureolercChild): bool =
  if child == nil or child.process == nil:
    return false
  let code = child.process.peekExitCode()
  if code == -1:
    return true
  if code != -1:
    stderr.writeLine(&"aureole: aureolerc exited status={code}")
    child.process.close()
    child.process = nil
  false


# Terminates the startup process group, escalating to SIGKILL after the bounded grace period.

proc stop*(child: AureolercChild) =
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
