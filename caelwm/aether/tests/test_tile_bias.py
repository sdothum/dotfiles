"""Offline tile qualification using production resolution and routing code.

Copies policy, rules, parser and bias modules unchanged. Extracts the complete
production tile block and captured-target validation, plus the production CLI
router and window tile dispatch arm. Replaces X11, daemon transport, geometry
submission and history persistence with in-memory effects. No socket, X server,
resident daemon, desktop operation or installation is used. These fixtures do
not qualify real X11 execution or transaction persistence.
"""
import os
from pathlib import Path
import shutil
import tempfile
import unittest

from test_layout_bias import (ROOT, QUERY, WINDOW, PLACEMENT, STATE,
                              PLACEMENT_WRAPPERS, DAEMON, compile_nim, run, section)


EFFECTS = '''
var calls*: seq[string]
var destinations*: seq[Geometry]
var targets*: seq[string]
var histories*, checkedHistories*: int
proc validateEffect(token: Option[query.ClientToken]) =
  if token.isSome and token.get != query.identity:
    raiseZephyrError("fixture: stale identity")
proc wtpTarget(g: Geometry, id: string, token: Option[query.ClientToken]) =
  validateEffect(token)
  destinations.add(g)
  targets.add(id)
  query.focused = id
proc saveOriginalForTarget(g, d: Geometry, id: string, t: query.ClientToken) =
  inc histories
  inc checkedHistories
proc saveOriginalIfChanged(g, d: Geometry, id: string) = inc histories
proc group*(chain: WindowChain, name: string): WindowChain = chain
proc size*(chain: WindowChain, args: varargs[string]): WindowChain = chain
proc snap*(chain: WindowChain, args: varargs[string]): WindowChain = chain
proc spread*(chain: WindowChain, args: varargs[string]): WindowChain = chain
proc stackCycle*(chain: WindowChain): WindowChain = chain
proc close*(chain: WindowChain): WindowChain = chain
proc liveIds*(args: seq[string]): string =
  case args[0]
  of "kak": "0x00000001"
  of "firefox": "0x00000002"
  of "qutebrowser": ""
  else: "0x00000001"
'''

DRIVER = '''import std/strutils
import wm/[window, window_query, daemon_client, types, display, group, screen, state]
import policy/[layouts, layout_bias, rules]
import zephyr_errors
CLI_ROUTER

var checks = 0
const id = "0x00000001"
const grids = [1, 2, 3, 4, 5, 6, 7, 8, 12, 17]

# Checks independently specified geometry, reflection, effects and remote reads.
proc placed(mode: string, args: seq[string], right: bool,
    resident = false): Geometry =
  let value = if right: LayoutBias.Right else: LayoutBias.Left
  if resident: setResidentBias(value)
  else: side = $value
  reads = 0
  destinations.setLen(0)
  targets.setLen(0)
  histories = 0
  checkedHistories = 0
  focused = "0x00000002"
  case mode
  of "cli-window": dispatchCommand(@["window", "tile"] & args & @[id])
  of "cli-layout": dispatchCommand(@["layout", "tile"] & args)
  of "layout-spread": layouts.spread(args)
  of "fluent": discard target(id).tile(args)
  of "public-pair": window.tile(args[0], args[1])
  of "public-single": window.tile(args[0])
  of "internal": window.tile(args,
    ScreenGeometry(width: 1919, height: 1079, gap: 7, margin: 11, top: 13),
    Geometry(x: 101, y: 103, width: 307, height: 211))
  of "physical": tileGrid(parseInt(args[0]), parseInt(args[2]),
    parseInt(args[1]), parseInt(args[3]), id)
  of "kak", "surf", "xftp", "cbftp", "pcmanfm", "compose", "email":
    rules.applyRule(mode, id)
  else: doAssert false, mode
  doAssert destinations.len == 1, mode
  doAssert histories == 1, mode
  doAssert targets[0] == (if mode in ["public-pair", "public-single", "internal", "cli-layout", "layout-spread"]:
    "0x00000002" else: id), mode
  if mode in ["fluent", "kak", "surf", "xftp", "cbftp", "pcmanfm", "compose", "email"]:
    doAssert checkedHistories == 1
    doAssert focused == "0x00000002", "captured tile changed focus"
  let numeric = args.len > 0 and args[0] notin ["left", "right"]
  let usesBias = mode != "physical" and (numeric or
    mode in ["kak", "surf", "xftp", "cbftp", "pcmanfm", "compose", "email"])
  doAssert reads == (if usesBias and not resident: 1 else: 0),
    mode & " bias acquisition count " & $reads
  inc checks
  destinations[0]

# Verifies reflection against the grid's rounded physical envelope.
proc reflection(left, right: Geometry, columns, rows, column, row: int) =
  let width = (1919 - (columns - 1) * 7) div columns
  let height = (1079 - (rows - 1) * 7) div rows
  doAssert left == Geometry(x: 11 + (column - 1) * (width + 7),
    y: 13 + (row - 1) * (height + 7), width: width, height: height)
  doAssert right.x + left.x == 22 + (columns - 1) * (width + 7)
  doAssert right.y == left.y
  doAssert right.width == left.width and right.height == left.height

# Preserves independently recorded left-bias assignment preference.
proc leftOrder(columns: int): seq[int] =
  case columns
  of 1: @[1]
  of 2: @[2, 1]
  of 3: @[2, 3, 1]
  of 4: @[3, 4, 2, 1]
  of 5: @[3, 4, 5, 2, 1]
  else:
    var order: seq[int]
    for i in 1 .. columns: order.add(i)
    order

for columns in grids:
  for rows in 1 .. 3:
    for row in 1 .. rows:
      for column in 1 .. columns:
        let args = @[$columns, $column, "--rows", $rows, "--row", $row]
        for mode in ["cli-window", "fluent", "internal"]:
          reflection(placed(mode, args, false), placed(mode, args, true),
            columns, rows, column, row)
        let layoutArgs = @[$columns, $column, "--rows", $rows, "--position", $row]
        reflection(placed("cli-layout", layoutArgs, false),
          placed("cli-layout", layoutArgs, true), columns, rows, column, row)
        let physicalArgs = @[$columns, $column, $rows, $row]
        doAssert placed("physical", physicalArgs, false) == placed("physical", physicalArgs, true)
      let defaults = @[$columns, "--rows", $rows, "--row", $row]
      for mode in ["cli-window", "fluent", "internal"]:
        reflection(placed(mode, defaults, false), placed(mode, defaults, true),
          columns, rows, columns, row)
    for position in 1 .. columns * rows * 2:
      let args = @[$columns, "--rows", $rows, "--position", $position]
      let column = leftOrder(columns)[((position - 1) div rows) mod columns]
      let row = (position - 1) mod rows + 1
      reflection(placed("cli-layout", args, false), placed("cli-layout", args, true),
        columns, rows, column, row)
      doAssert columnOrder(columns, rows, position, LayoutBias.Left) == column
      doAssert columnOrder(columns, rows, position, LayoutBias.Right) == columns - column + 1
    reflection(placed("cli-layout", @[$columns, "--rows", $rows], false),
      placed("cli-layout", @[$columns, "--rows", $rows], true),
      columns, rows, leftOrder(columns)[0], 1)
  for column in 1 .. columns:
    reflection(placed("public-pair", @[$columns, $column], false),
      placed("public-pair", @[$columns, $column], true), columns, 1, column, 1)
  reflection(placed("public-single", @[$columns], false),
    placed("public-single", @[$columns], true), columns, 1, columns, 1)

# Cardinal window edges remain literal physical operations and require no bias read.
for mode in ["cli-window", "fluent", "public-single", "internal"]:
  for direction in ["left", "right"]:
    let l = placed(mode, @[direction], false)
    let r = placed(mode, @[direction], true)
    doAssert l == r
    doAssert l == (if direction == "left":
      Geometry(x: 11, y: 13, width: 397, height: 1079)
      else: Geometry(x: 101, y: 13, width: 1829, height: 1079))

# Explicit layout spread columns keep their established physical semantics.
# The fixture source width permits at most six size-preserving columns.
for columns in 1 .. 6:
  for column in 1 .. columns:
    doAssert placed("layout-spread", @[$columns, $column], false) ==
      placed("layout-spread", @[$columns, $column], true)

# Exact public diagnostics remain independent of authoritative-query availability.
# Expected messages are fixed contracts; validation and resolution run in production code.
var rejectionChecks = 0
for failure in ["", "transport", "kind", "body"]:
  biasFailure = failure
  for mode in ["cli-window", "fluent"]:
    for right in [false, true]:
      for entry in [
          (@["3", "4"], "column out of range"),
          (@["3", "1", "--rows", "2", "--row", "3"], "row out of range"),
          (@["3", "--rows", "2", "--row", "3"], "row out of range"),
          (@["3", "4", "--rows", "2", "--row", "3"], "column out of range"),
          (@["3", "4", "--rows", "0"], "--rows must be > 0"),
          (@["3", "4", "--row", "0"], "--row must be > 0"),
          (@["0", "0"], "columns must be > 0"),
          (@["-1", "0"], "columns must be > 0"),
          (@["0"], "columns must be > 0"),
          (@["-1"], "columns must be > 0"),
          (@["3", "0", "--rows", "0"], "column must be > 0"),
          (@["3", "-1"], "column must be > 0"),
          (@["3", "1", "--rows", "0"], "--rows must be > 0"),
          (@["3", "1", "--rows", "-1"], "--rows must be > 0"),
          (@["3", "--rows", "0"], "--rows must be > 0"),
          (@["3", "--rows", "-1"], "--rows must be > 0"),
          (@["3", "1", "--row", "0"], "--row must be > 0"),
          (@["3", "1", "--row", "-1"], "--row must be > 0"),
          (@["3", "--row", "0"], "--row must be > 0"),
          (@["3", "--row", "-1"], "--row must be > 0"),
          (@["3", "--rows", "0", "--row", "0"], "--rows must be > 0"),
          (@["3", "--row", "0", "--rows", "0"], "--row must be > 0")]:
        try:
          discard placed(mode, entry[0], right)
          doAssert false, "invalid logical cell accepted"
        except ZephyrError as error:
          doAssert error.msg == "window tile: " & entry[1], error.msg
          doAssert reads == 0, "invalid logical cell acquired bias"
          doAssert destinations.len == 0 and targets.len == 0
          doAssert histories == 0 and checkedHistories == 0
          inc rejectionChecks
biasFailure = ""
echo "VERIFIED ", rejectionChecks,
  " invalid logical-cell cases: exact diagnostics; zero bias reads, geometry and history"

# Invalid cells fail through production parsing/geometry validation before submission.
for mode in ["cli-window", "cli-layout", "fluent", "physical"]:
  for right in [false, true]:
    for bad in ["0", "-1", "4"]:
      try:
        discard placed(mode,
          (if mode == "physical": @["3", bad, "2", "1"] else: @["3", bad]), right)
        doAssert false, "invalid column accepted"
      except ZephyrError: doAssert destinations.len == 0
    if mode != "cli-layout":
      for bad in ["0", "-1", "3"]:
        try:
          discard placed(mode,
            (if mode == "physical": @["3", "1", "2", bad]
             else: @["3", "1", "--rows", "2", "--row", bad]), right)
          doAssert false, "invalid row accepted"
        except ZephyrError: doAssert destinations.len == 0
    for bad in ["0", "-1"]:
      try:
        discard placed(mode,
          (if mode == "physical": @[bad, "1", "1", "1"] else: @[bad, "1"]), right)
        doAssert false, "invalid grid accepted"
      except ZephyrError: doAssert destinations.len == 0
      try:
        discard placed(mode,
          (if mode == "physical": @["3", "1", bad, "1"]
           else: @["3", "1", "--rows", bad]), right)
        doAssert false, "invalid rows accepted"
      except ZephyrError: doAssert destinations.len == 0

# Layout positions are positive assignment indices; values beyond capacity wrap.
for right in [false, true]:
  for bad in ["0", "-1", "invalid"]:
    try:
      discard placed("cli-layout", @["3", "--position", bad], right)
      doAssert false, "invalid position accepted"
    except ZephyrError: doAssert destinations.len == 0

# Valid numeric operations acquire once and propagate each authoritative-query error.
var failureChecks = 0
for failure in ["transport", "kind", "body"]:
  biasFailure = failure
  let expected = case failure
    of "transport": "layout bias: fixture unavailable"
    of "kind": "layout bias: unexpected response"
    else: "layout bias: expected left or right"
  for mode in ["cli-window", "cli-layout", "fluent"]:
    for args in [@["4", "4"], @["4"]]:
      try:
        discard placed(mode, args, true)
        doAssert false, "bias error ignored"
      except ZephyrError as error:
        doAssert error.msg == expected, error.msg
        doAssert destinations.len == 0 and targets.len == 0
        doAssert histories == 0 and checkedHistories == 0
        doAssert reads == 1
        inc failureChecks
biasFailure = ""
echo "VERIFIED ", failureChecks,
  " valid numeric query failures: exact diagnostics; one bias read; zero geometry and history"

# A remote reply mutation and later screen mutation cannot change this operation's bias.
changeAfterRead = true
reflection(placed("cli-window", @["4", "4"], false),
  placed("cli-window", @["4", "4"], true), 4, 1, 4, 1)
changeAfterRead = false
onScreen = proc() = side = "left"
reflection(placed("fluent", @["4", "4"], false),
  placed("fluent", @["4", "4"], true), 4, 1, 4, 1)
onScreen = nil

# Captured target replacement and stale identities still reject without applying geometry.
let chain = target(id)
destinations.setLen(0)
try:
  discard chain.tile("4", "4", "0x00000002")
  doAssert false, "captured target replaced"
except ZephyrError: doAssert destinations.len == 0
identity = "replaced"
try:
  discard chain.tile("4", "4")
  doAssert false, "stale identity accepted"
except ZephyrError: doAssert destinations.len == 0
identity = "original"

# The full unchanged application-rule module executes against initialized resident state.
initializeResidentBias()
for entry in [("kak", 4, 4), ("surf", 4, 1), ("xftp", 3, 3),
    ("cbftp", 3, 2), ("pcmanfm", 3, 3), ("compose", 3, 2), ("email", 3, 2)]:
  reflection(placed(entry[0], @[], false, true), placed(entry[0], @[], true, true),
    entry[1], 1, entry[2], 1)
for mode in ["cli-window", "cli-layout", "fluent"]:
  onScreen = proc() = setResidentBias(LayoutBias.Left)
  reflection(placed(mode, @["4", "4"], false, true),
    placed(mode, @["4", "4"], true, true), 4, 1, 4, 1)
  onScreen = nil
for direction in ["left", "right"]:
  doAssert placed("fluent", @[direction], false, true) ==
    placed("fluent", @[direction], true, true)
doAssert placed("physical", @["4", "4", "2", "2"], false, true) ==
  placed("physical", @["4", "4", "2", "2"], true, true)
echo "VERIFIED ", checks, " offline production-path placements"
'''


class TileBiasTests(unittest.TestCase):
    def test_production_tile_paths(self):
        with tempfile.TemporaryDirectory(prefix="aether-tile-bias-") as temp:
            tree = Path(temp)
            (tree / "wm").mkdir()
            (tree / "policy").mkdir()
            for file in ("zephyr_errors.nim", "wm/types.nim", "wm/cliargs.nim",
                         "wm/constants.nim", "wm/compat.nim", "wm/group_id.nim",
                         "wm/layer_types.nim", "policy/layouts.nim", "policy/layout_bias.nim",
                         "policy/layout_bias_access.nim", "policy/rules.nim", "policy/types.nim"):
                shutil.copy2(ROOT / file, tree / file)
            query = QUERY.replace('var clientCount* = 7', '''var clientCount* = 2
var focused* = "0x00000002"
var identity* = "original"''').replace('winid: $i, token: some($i)',
                    'winid: "0x0000000" & $i, token: some(identity)')
            query = query.replace('result.focused = some("1")', 'result.focused = some(focused)')
            query = query.replace('proc focusedWinid*(): string = "1"',
                                  'proc focusedWinid*(): string = focused')
            query = query.replace('Geometry(width: 100 + id.len, height: 80 + id.len)',
                                  'Geometry(x: 101, y: 103, width: 307, height: 211)')
            query += '\nproc tryWmSnapshot*(snapshot: var WmSnapshot): bool =\n  snapshot = wmSnapshot()\n  true\n'
            (tree / "wm/window_query.nim").write_text(query)
            daemon = DAEMON.replace('var side*', 'var biasFailure* = ""\nvar side*')
            daemon = daemon.replace('  result.body = side', '''  result.body = side
  if biasFailure == "transport":
    result.ok = false
    result.error = "fixture unavailable"
  if biasFailure == "kind": result.responseKind = 0
  if biasFailure == "body": result.body = "invalid"''')
            (tree / "wm/daemon_client.nim").write_text(daemon + '\nproc awaitReady*() = discard\n')
            (tree / "wm/native_ipc.nim").write_text('''import window_query
proc windowId*(id: string): string = id
proc focus*(id: string): int =
  window_query.focused = id
  0
proc require*(status: int) = doAssert status == 0
''')
            (tree / "wm/group.nim").write_text('''proc count*(): int = 10
proc name*(): string = "code"
proc focus*(name: string) = discard
proc dispatch*(verb: string, rest: seq[string]) = doAssert false
''')
            for name in ("display", "screen"):
                (tree / f"wm/{name}.nim").write_text(
                    'proc dispatch*(verb: string, rest: seq[string]) = doAssert false\n')
            (tree / "wm/state.nim").write_text(STATE + '''
proc snapshot*() = discard
proc restore*() = discard
proc dispatch*(verb: string, rest: seq[string]) = doAssert false
''')
            window = (ROOT / "wm/window.nim").read_text()
            prefix = '''import std/[options, strutils]
import types, cliargs, compat, constants
import native_ipc as ipc
import window_query as query
import ../policy/[layout_bias, layout_bias_access]
import ../zephyr_errors
'''
            chain = section(window, 'type\n  WindowChain*', '#\n# Queries')
            screen = section(WINDOW, 'var onScreen*', 'proc wtpTarget(')
            tile = window[window.index('proc applyTileGridGeometry('):
                          window.index('# Attempts to hide every matching client')]
            # Only non-tile dispatcher arms are excluded; the selected arm is verbatim.
            arm = section(window, '  of "tile":', '  of "swap":')
            dispatcher = 'proc dispatch*(verb: string, rest: seq[string]) =\n  case verb\n' + arm + \
                         '  else: raiseZephyrError("unsupported fixture window action")\n'
            math = section(window, 'proc applySpreadGridGeometry(', 'proc spreadTarget(')
            math += section(window, 'proc spreadGridTarget(', 'proc swap*(')
            (tree / "wm/window.nim").write_text(prefix + chain + screen + EFFECTS +
                WINDOW[WINDOW.index("type\n  GeometryApplication"):] + tile + math + dispatcher)
            placement = (ROOT / "wm/placement.nim").read_text()
            math = section(placement, 'type\n', 'proc foldDestination(')
            math += section(placement, 'proc foldDestination(', 'proc applyFold*(')
            math += section(placement, 'proc explodeDestination(', 'proc restoreCheckpoint*(')
            (tree / "wm/placement.nim").write_text(PLACEMENT + math + PLACEMENT_WRAPPERS)
            router = section((ROOT / "aether.nim").read_text(), 'proc splitCommands(', 'proc usage(')
            (tree / "driver.nim").write_text(DRIVER.replace('CLI_ROUTER', router))
            binary = tree / "driver"
            compile_nim(tree / "driver.nim", binary)
            env = dict(os.environ, DISPLAY="", XAUTHORITY=str(tree / "no-auth"),
                       WME=str(tree / "wme"), XDG_RUNTIME_DIR=str(tree / "runtime"))
            result = run([str(binary)], env=env)
            print(result.stdout, end="")
            self.assertRegex(result.stdout, r"VERIFIED \d+ offline production-path placements")
            self.assertFalse((tree / "wme").exists())
            self.assertFalse((tree / "runtime").exists())

    def test_physical_boundary_and_snapshot_source_contract(self):
        window = (ROOT / "wm/window.nim").read_text()
        geometry = section(window, 'proc applyTileGridGeometry(', 'proc tileGridTarget(')
        for forbidden in ('bias()', 'localBias', 'queryDaemon', 'physicalColumn', 'getEnv'):
            self.assertNotIn(forbidden, geometry)
        tile = section(window, 'proc tileTarget(', 'proc tile*(\n')
        self.assertEqual(tile.count('bias()'), 1)
        self.assertEqual(tile.count('physicalColumn('), 1)
        self.assertLess(tile.index('validateTileGridCell('), tile.index('bias()'))
        self.assertIn('validateTileGridCell(columns, rows, column, row)', geometry)
        layouts = (ROOT / "policy/layouts.nim").read_text()
        tile = section(layouts, 'proc tile*(', 'proc spread*(')
        self.assertEqual(tile.count('bias()'), 1)
        self.assertNotIn('columns - column', tile)
        self.assertIn('biasRelativeColumn = true', tile)


if __name__ == '__main__':
    unittest.main()
