import compat

proc name*(args: seq[string]): string =
  shvArgs("group", "name", args, 0, 1)
