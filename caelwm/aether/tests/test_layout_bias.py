"""Bias tests; --offline selects geometry/source tests without the IPC fixture.

The resident fixture uses production IPC/state without starting Aetherd/X11.
Layout tests copy production policy/parser code into a temporary tree, replace
external effects, and extract production window arithmetic and placement's
explode calculation AND group/stack callers verbatim. Positional argv[1] is an
optional release CLI binary; argv[2] is an untouched pre-change layouts.nim for
before/after comparison. --offline never compiles or executes the IPC fixture.
"""
import os
from pathlib import Path
import re
import select
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
NIM = "/usr/lib/nim/bin/nim"
CLI = None
BASELINE = None


def run(args, **kwargs):
    result = subprocess.run(args, text=True, capture_output=True, timeout=60, **kwargs)
    if result.returncode:
        print(result.stdout + result.stderr, file=sys.stderr, end="")
    result.check_returncode()
    return result


def compile_nim(source, output):
    result = run([NIM, "c", "-d:release", "--hints:off", "--warnings:on",
                  f"--nimcache:{output}-cache", f"--out:{output}", str(source)])
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")


QUERY = '''import std/options
import types
type
  ClientToken* = string
  WmClient* = object
    winid*: string
    token*: Option[ClientToken]
    mapped*: bool
    group*: uint32
  WmSnapshot* = object
    clients*: seq[WmClient]
    focused*: Option[string]
  StackGeometryEntry* = object
    winid*: string
    geometry*: Geometry
var clientCount* = 7
proc wmSnapshot*(): WmSnapshot =
  for i in 1 .. clientCount:
    result.clients.add(WmClient(winid: $i, token: some($i), mapped: true, group: 1))
  result.focused = some("1")
proc focusedWinid*(): string = "1"
proc geometry*(id: string): Geometry =
  Geometry(width: 100 + id.len, height: 80 + id.len)
proc stackGeometries*(): seq[StackGeometryEntry] =
  for i in 1 .. clientCount:
    result.add(StackGeometryEntry(winid: $i,
      geometry: Geometry(width: 300 + i, height: 200 + i)))
'''

WINDOW = '''import std/options
import types
import window_query as query
import ../zephyr_errors
var calls*: seq[string]
var onScreen*: proc()
proc screenGeometry*(): ScreenGeometry =
  if onScreen != nil: onScreen()
  ScreenGeometry(width: 1919, height: 1079, gap: 7, margin: 11, top: 13)
proc wtpTarget(g: Geometry, id: string, token: Option[query.ClientToken]) =
  calls.add(id & ":" & $g)
proc saveOriginalForTarget(g, d: Geometry, id: string, t: query.ClientToken) = discard
proc saveOriginalIfChanged(g, d: Geometry, id: string) = discard
proc liveIds*(args: seq[string]): string = "1\\n2"
type
  GeometryApplication* = tuple[winid: string, geometry: Geometry]
  CheckedGeometryApplication* = tuple[winid: string,
    token: query.ClientToken, geometry: Geometry]
proc applyGeometries*(entries: seq[GeometryApplication]) =
  for entry in entries: calls.add(entry.winid & ":" & $entry.geometry)
proc applyGeometriesChecked*(entries: seq[CheckedGeometryApplication]) =
  for entry in entries: calls.add(entry.winid & ":" & $entry.geometry)
proc raiseMany*(ids: seq[string]) = discard
proc focus*(id: string) = discard
'''

WINDOW_WRAPPERS = '''
proc tileGrid*(columns, rows, column, row: int, winid: string,
    s: ScreenGeometry, g: Geometry) =
  applyTileGridGeometry(columns, rows, column, row, g, s, winid, none(query.ClientToken))
proc spreadGrid*(columns, column, rows, row: int, winid: string,
    s: ScreenGeometry, g: Geometry) =
  applySpreadGridGeometry(columns, column, rows, row,
    Geometry(width: 100, height: 80), s, winid, none(query.ClientToken))
'''

PLACEMENT = '''import std/[options, sequtils, strutils]
import types, window, state
import window_query as query
import ../zephyr_errors
'''

# Transaction/history effects only. The production explode callers below still
# compute their own destinations and pass actual application tuples to window.
STATE = '''import types, window_query
type
  IdentityHistoryUpdate* = tuple[winid: string, token: ClientToken, geometry: Geometry]
  IdentityExplodeStateRecord* = IdentityHistoryUpdate
proc recoverExplodeOperation*(root: string) = discard
proc beginExplodeOperationIdentity*(root: string,
    records: seq[IdentityExplodeStateRecord], history: seq[IdentityHistoryUpdate]): int = 0
proc markExplodeGeometryApplied*(operation: int) = discard
proc commitExplodeOperation*(operation: int) = discard
'''

PLACEMENT_WRAPPERS = '''
proc record(cells: seq[PlacementCell], columns, rows: int, spread = false) =
  let s = screenGeometry()
  for cell in cells:
    calls.add($cell & ":" & $foldDestination(cell, columns, rows, s,
      Geometry(width: 100, height: 80), spread))
proc applyFold*(clients: seq[PlacementClient], cells: seq[PlacementCell],
    columns, rows: int, spread: bool, root: Option[string], focused: string) =
  record(cells, columns, rows, spread)
proc restoreCheckpoint*(root, command: string, error = "") = discard
proc applyLevel*(clients: seq[PlacementClient]) = discard
proc recoverRestoreHistory*() = discard
proc applyRestore*(clients: seq[PlacementClient], focused: string, all: bool) = discard
'''

# The remote fixture deliberately changes its reply after each query. A single
# operation must never mix its first snapshot with the next policy value.
DAEMON = '''const
  RequestQueryLayoutBias* = 14'u8
  RequestSetLayoutBias* = 15'u8
type Reply = object
  ok*: bool
  responseKind*: uint8
  body*, error*: string
var side* = "left"
var reads* = 0
var changeAfterRead* = false
proc queryDaemon*(kind: uint8, argument = ""): Reply =
  result = Reply(ok: true, responseKind: kind)
  if kind == RequestSetLayoutBias:
    side = argument
  else:
    inc reads
  result.body = side
  if changeAfterRead and kind == RequestQueryLayoutBias:
    side = if side == "left": "right" else: "left"
'''

DRIVER = '''import std/strutils
import policy/layouts
import wm/[window, window_query]
SIDE_IMPORT
for sideValue in ["left", "right"]:
  SET_SIDE
  for columns in 1 .. 7:
    for rows in 1 .. 3:
      for position in 1 .. columns * rows * 2:
        echo "ORDER ", sideValue, " ", columns, " ", rows, " ", position, " ",
          ORDER_CALL
        for action in ["tile", "spread"]:
          calls.setLen(0)
          dispatch(action, @[$columns, "--rows", $rows, "--position", $position])
          echo action, " ", calls.join(";")
        calls.setLen(0)
        tile(@[$columns, $((position - 1) mod columns + 1), "--rows", $rows])
        echo "EXPLICIT ", calls.join(";")
      for count in [1, 2, 4, 7, 10, 16]:
        clientCount = count
        for extra in [newSeq[string](), @["--spread"]]:
          calls.setLen(0)
          fold(@[$columns, "--rows", $rows] & extra)
          echo "FOLD ", sideValue, " ", count, " ", calls.join(";")
  for count in 1 .. 17:
    clientCount = count
    for args in [newSeq[string](), @["--group", "1"]]:
      calls.setLen(0)
      explode(args)
      echo "EXPLODE ", sideValue, " ", count, " ",
        (if args.len == 0: "stack" else: "group"), " ", calls.join(";")
EXTRA_TESTS
'''

EXTRA_TESTS = '''
# Omitting the argument must fail to compile, and explicit calls never read
# remote or resident policy state.
static: doAssert not compiles(columnOrder(3, 2, 1))
reads = 0
discard columnOrder(3, 2, 1, LayoutBias.Left)
discard columnOrder(3, 2, 1, LayoutBias.Right)
doAssert reads == 0
echo "SNAPSHOT explicit-column-order"
for action in ["tile", "spread", "fold", "explode-stack", "explode-group"]:
  let args =
    if action == "explode-stack": newSeq[string]()
    elif action == "explode-group": @["--group", "1"]
    else: @["3", "--rows", "2"]
  let verb = if action.startsWith("explode-"): "explode" else: action
  side = "right"
  reads = 0
  changeAfterRead = true
  calls.setLen(0)
  dispatch(verb, args)
  doAssert reads == 1, action & " fetched multiple snapshots"
  let captured = calls
  calls.setLen(0)
  changeAfterRead = false
  side = "right"
  dispatch(verb, args)
  doAssert calls == captured, action & " mixed bias values"
  echo "SNAPSHOT ", action
# A state change during screen acquisition cannot alter the captured snapshot.
side = "right"
onScreen = proc() = side = "left"
calls.setLen(0)
tile(@["4", "--position", "1"])
let captured = calls
onScreen = nil
side = "right"
calls.setLen(0)
tile(@["4", "--position", "1"])
doAssert calls == captured
echo "SNAPSHOT screen-mutation"
# Daemon-internal execution reads resident state and never calls its own IPC.
initializeResidentBias()
doAssert bias() == LayoutBias.Left
reads = 0
calls.setLen(0)
setBias(LayoutBias.Right)
setBias(LayoutBias.Right)
doAssert calls.len == 0
doAssert bias() == LayoutBias.Right
fold(@["3", "--rows", "2"])
doAssert reads == 0
discard columnOrder(3, 2, 1, LayoutBias.Left)
doAssert reads == 0
echo "SNAPSHOT resident-no-ipc"
'''


def section(source, start, end):
    return source[source.rindex(start):source.index(end, source.rindex(start))]


class FixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="aether-bias-")
        cls.root = Path(cls.tmp.name)
        cls.env = dict(os.environ, XDG_RUNTIME_DIR=str(cls.root / "runtime"),
                       WME=str(cls.root / "wme"), SESSION=str(cls.root / "session"),
                       DISPLAY="", XAUTHORITY=str(cls.root / "no-xauthority"))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()


class BiasIPCTests(FixtureTests):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.server = cls.root / "resident"
        compile_nim(ROOT / "tests/layout_bias_ipc_fixture.nim", cls.server)
        cls.cli_binary = CLI or cls.root / "aether"
        if CLI is None:
            compile_nim(ROOT / "aether.nim", cls.cli_binary)
        cls.proc = None

    @classmethod
    def tearDownClass(cls):
        cls.stop()
        super().tearDownClass()

    @classmethod
    def stop(cls):
        if cls.proc is not None:
            cls.proc.terminate()
            cls.proc.communicate(timeout=5)
            cls.proc = None

    def start(self):
        self.stop()
        self.proc = type(self).proc = subprocess.Popen(
            [str(self.server)], env=self.env, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True)
        self.assertTrue(select.select([self.proc.stdout], [], [], 5)[0])
        line = self.proc.stdout.readline()
        if line != "READY\n":
            _, errors = self.proc.communicate(timeout=5)
            self.fail(f"resident failed to start: {errors}")

    def cli(self, *args, ok=True):
        result = subprocess.run([str(self.cli_binary), *args], env=self.env, text=True,
                                capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0 if ok else 1, result.stderr)
        return result.stdout

    def test_cross_process_commands_and_lifecycle(self):
        self.start()
        self.assertEqual(self.cli("layout", "bias"), "left\n")
        for side in ("right", "right", "left", "left", "right"):
            self.assertEqual(self.cli("layout", "bias", side), "")
            self.assertEqual(self.cli("layout", "bias"), side + "\n")
        for invalid in (("up",), ("Left",), ("",), ("left", "right"), ("--help",)):
            self.cli("layout", "bias", *invalid, ok=False)
            self.assertEqual(self.cli("layout", "bias"), "right\n")
        self.assertEqual(self.cli("layouts", "bias"), "right\n")
        self.assertEqual(self.cli("layout", "bias", "left", ".", "layout", "bias"), "left\n")
        # The resident never had a WM snapshot and setters produced no WME/session files.
        self.assertFalse(Path(self.env["WME"]).exists())
        self.assertFalse(Path(self.env["SESSION"]).exists())
        self.cli("layout", "bias", "right")
        self.start()
        self.assertEqual(self.cli("layout", "bias"), "left\n")
        self.stop()
        self.cli("layout", "bias", ok=False)
        self.cli("layout", "bias", "right", ok=False)

    def test_wire_validation_preserves_state(self):
        self.start()
        self.cli("layout", "bias", "right")
        path = Path(self.env["XDG_RUNTIME_DIR"]) / "zephyr/zephyrd.sock"
        for payload in (b"\0\1\x0f", b"\0\1\x0f\0\2up",
                        b"\0\1\x0f\0\4leftX", b"\0\1\x0eXX",
                        b"\0\2\x0f\0\4left"):
            with socket.socket(socket.AF_UNIX) as client:
                client.settimeout(5)
                client.connect(str(path))
                client.sendall(struct.pack("!I", len(payload)) + payload)
                header = client.recv(4, socket.MSG_WAITALL)
                size, = struct.unpack("!I", header)
                reply = client.recv(size, socket.MSG_WAITALL)
                self.assertEqual(reply[2], 1)
            self.assertEqual(self.cli("layout", "bias"), "right\n")


class LayoutTests(FixtureTests):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        output = cls.layout_tree("candidate", (ROOT / "policy/layouts.nim").read_text())
        cls.snapshots = [line for line in output.splitlines() if line.startswith("SNAPSHOT ")]
        cls.candidate = [line for line in output.splitlines() if not line.startswith("SNAPSHOT ")]
        cls.baseline = None
        if BASELINE:
            cls.baseline = cls.layout_tree("baseline", BASELINE.read_text(), baseline=True).splitlines()

    @classmethod
    def layout_tree(cls, name, source, baseline=False):
        tree = cls.root / name
        legacy = baseline and "layoutBias: LayoutBias" not in source
        (tree / "policy").mkdir(parents=True)
        (tree / "wm").mkdir()
        for file in ("zephyr_errors.nim", "policy/layout_bias.nim",
                     "policy/layout_bias_access.nim", "wm/cliargs.nim",
                     "wm/constants.nim", "wm/group_id.nim", "wm/layer_types.nim", "wm/types.nim"):
            shutil.copy2(ROOT / file, tree / file)
        (tree / "policy/layouts.nim").write_text(source)
        (tree / "wm/window_query.nim").write_text(QUERY)
        (tree / "wm/group.nim").write_text("proc count*(): int = 10\n")
        shutil.copy2(ROOT / "wm/compat.nim", tree / "wm/compat.nim")
        if legacy:
            # Replace the external recipe boundary only; policy stays unchanged.
            with (tree / "wm/compat.nim").open("a") as stream:
                stream.write('''\nvar side* = "left"
proc shvArgs*(cmd, verb: string, args: seq[string], minLen, maxLen: int): string = side
'''.replace("proc shvArgs*", "proc fixtureRecipe*"))
            compat = (tree / "wm/compat.nim").read_text()
            # Original shvArgs is renamed; the same signature now returns the fixture preference.
            compat = compat.replace("proc shvArgs*(", "proc externalShvArgs(")
            compat = compat.replace("proc fixtureRecipe*(", "proc shvArgs*(")
            (tree / "wm/compat.nim").write_text(compat)
        (tree / "wm/daemon_client.nim").write_text(DAEMON)
        (tree / "wm/state.nim").write_text(STATE)
        window = (ROOT / "wm/window.nim").read_text()
        math = section(window, "proc validateTileGridCell(", "proc tileTarget(")
        math += section(window, "proc applyTileGridGeometry(", "proc tileGridTarget(")
        math += section(window, "proc applySpreadGridGeometry(", "proc spreadTarget(")
        (tree / "wm/window.nim").write_text(WINDOW + math + WINDOW_WRAPPERS)
        placement = (ROOT / "wm/placement.nim").read_text()
        # These exact production types/calculations/callers are reused without
        # rewriting their inputs or substituting fold/spread geometry.
        math = section(placement, "type\n", "proc foldDestination(")
        math += section(placement, "proc foldDestination(", "proc applyFold*(")
        math += section(placement, "proc explodeDestination(", "proc restoreCheckpoint*(")
        (tree / "wm/placement.nim").write_text(PLACEMENT + math + PLACEMENT_WRAPPERS)
        driver = DRIVER.replace("SIDE_IMPORT", "import wm/compat" if legacy else
                                "import wm/daemon_client\nimport policy/layout_bias")
        driver = driver.replace("SET_SIDE", "side = sideValue")
        driver = driver.replace("ORDER_CALL", "columnOrder(columns, rows, position)" if legacy else
                                "columnOrder(columns, rows, position, parseLayoutBias(sideValue))")
        driver = driver.replace("EXTRA_TESTS", "" if baseline else EXTRA_TESTS)
        (tree / "driver.nim").write_text(driver)
        binary = tree / "driver"
        compile_nim(tree / "driver.nim", binary)
        return run([str(binary)], env=cls.env).stdout

    def test_layout_snapshot_and_geometry_parity(self):
        # Approved assignment contract: preserve left ordering and mirror right ordering.
        orders = {
            "left": {1: [1], 2: [2, 1], 3: [2, 3, 1],
                     4: [3, 4, 2, 1], 5: [3, 4, 5, 2, 1]},
            "right": {1: [1], 2: [1, 2], 3: [2, 1, 3],
                      4: [2, 1, 3, 4], 5: [3, 2, 1, 4, 5]},
        }
        order_records = 0
        for line in self.candidate:
            if line.startswith("ORDER "):
                _, side, columns, rows, position, actual = line.split()
                columns, rows, position = map(int, (columns, rows, position))
                order = orders[side].get(columns, list(range(1, columns + 1)) if side == "left"
                                         else list(range(columns, 0, -1)))
                expected = order[((position - 1) // rows) % columns]
                self.assertEqual(int(actual), expected, line)
                order_records += 1
        self.assertEqual(order_records, 672)
        if self.baseline is not None:
            self.assertEqual(len(self.candidate), len(self.baseline))
            compared = changed = 0
            side, columns = None, None
            for candidate, baseline in zip(self.candidate, self.baseline):
                if candidate.startswith("ORDER "):
                    _, side, columns, *_ = candidate.split()
                    columns = int(columns)
                # Approved deltas: right implicit tile loses the duplicate mirror;
                # right assignments >=6 reverse. Everything else remains identical.
                permitted = side == "right" and (
                    candidate.startswith("tile ") or columns >= 6 and
                    candidate.startswith(("ORDER ", "spread ", "FOLD ")))
                if not permitted:
                    self.assertEqual(candidate, baseline)
                    compared += 1
                elif candidate != baseline:
                    changed += 1
            print(f"Compared {compared} unaffected baseline records; "
                  f"{changed} records differ within approved correction scope")

    def test_independent_explode_geometry(self):
        # Independent contract: exact cell dimensions for the fixture's usable
        # 1919x1079 screen, gap=7, left=11, top=13. These are NOT derived from
        # explodeDestination or spreadGrid. A 100x80 centered substitute fails.
        grids = [(1, 1, 1919, 1079), (3, 1, 635, 1079),
                 (4, 1, 474, 1079), (3, 2, 635, 536),
                 (4, 3, 474, 355), (5, 3, 378, 355)]
        orders = {"left": {1: [1], 3: [2, 3, 1], 4: [3, 4, 2, 1], 5: [3, 4, 5, 2, 1]},
                  "right": {1: [1], 3: [2, 1, 3], 4: [2, 1, 3, 4], 5: [3, 2, 1, 4, 5]}}
        records = windows = 0
        coverage = set()
        for line in self.candidate:
            if not line.startswith("EXPLODE "):
                continue
            _, side, count, path, applications = line.split(" ", 4)
            count = int(count)
            columns, rows, width, height = grids[
                0 if count == 1 else 1 if count == 2 else 2 if count == 3 else
                3 if count == 4 else 4 if count <= 9 else 5]
            ids = [str(i) for i in range(1, count + 1)]
            if path == "group":
                ids.sort()  # production snapshotWinids sorts; stack retains its order
            entries = applications.split(";")
            self.assertEqual(len(entries), count)
            for index, (id, entry) in enumerate(zip(ids, entries)):
                column = orders[side][columns][(index // rows) % columns]
                row = index % rows + 1
                expected = (11 + (column - 1) * (width + 7),
                            13 + (row - 1) * (height + 7), width, height)
                actual_id, geometry = entry.split(":", 1)
                self.assertEqual(actual_id, id, line)
                self.assertEqual(tuple(map(int, re.findall(r"-?\d+", geometry))), expected, line)
                windows += 1
            coverage.add((side, path, count))
            records += 1
        self.assertEqual(coverage, {(side, path, count) for side in ("left", "right")
                                   for path in ("group", "stack") for count in range(1, 18)})
        self.assertEqual(records, 68)
        self.assertEqual(windows, 612)
        print(f"Independently checked {records} explode records / {windows} window geometries")

    def test_shared_assignment_reflection(self):
        records = {}
        fold_variants = {}
        context = None
        for line in self.candidate:
            if line.startswith("ORDER "):
                _, side, columns, rows, position, _ = line.split()
                context = side, int(columns), int(rows), int(position)
            elif line.startswith(("tile ", "spread ")):
                side, columns, rows, position = context
                action, geometry = line.split(" ", 1)
                records[side, action, columns, rows, position] = [
                    tuple(map(int, re.findall(r"-?\d+", geometry)))]
            elif line.startswith("FOLD "):
                _, side, count, applications = line.split(" ", 3)
                _, columns, rows, _ = context
                base = side, columns, rows, int(count)
                variant = fold_variants.get(base, 0)
                fold_variants[base] = variant + 1
                records[side, "fold" + str(variant), columns, rows, int(count)] = [
                    tuple(map(int, re.findall(r"-?\d+", entry)))
                    for entry in applications.split(";")]
        pairs = windows = 0
        for key, left_entries in records.items():
            side, action, columns, rows, position = key
            if side != "left":
                continue
            right_entries = records["right", action, columns, rows, position]
            self.assertEqual(len(left_entries), len(right_entries))
            cell_width = (1919 - (columns - 1) * 7) // columns
            for left, right in zip(left_entries, right_entries):
                if action.startswith("fold"):
                    self.assertEqual(left[0] + right[0], columns + 1)
                    self.assertEqual(left[1], right[1])
                    left, right = left[2:], right[2:]
                self.assertEqual(left[1:], right[1:])  # y, width, height
                inset = (cell_width - left[2]) // 2 if action in ("spread", "fold1") else 0
                self.assertEqual(left[0] + right[0],
                                 22 + (columns - 1) * (cell_width + 7) + 2 * inset)
                windows += 1
            pairs += 1
        self.assertEqual(pairs, 924)
        print(f"Checked {pairs} reflected tile/spread/fold plans / {windows} geometries")

    def test_single_snapshot_consumption(self):
        self.assertEqual(self.snapshots, ["SNAPSHOT " + name for name in
                         ("explicit-column-order", "tile", "spread", "fold", "explode-stack",
                          "explode-group", "screen-mutation", "resident-no-ipc")])
        print(f"Verified {len(self.snapshots)} snapshot/purity assertion scenarios")

    def test_column_order_source_contract(self):
        source = (ROOT / "policy/layouts.nim").read_text()
        declarations = re.findall(r"proc columnOrder\*\((.*?)\): int", source, re.S)
        self.assertEqual(len(declarations), 2)
        for declaration in declarations:
            self.assertEqual(" ".join(declaration.split()),
                             "columns, rows, position: int, layoutBias: LayoutBias")
        body = section(source, "proc columnOrder*(", "proc gridDimensions*(")
        for forbidden in ("bias()", "localBias", "queryDaemon", "setResidentBias"):
            self.assertNotIn(forbidden, body)
        self.assertIn("columnOrder(columns, rows, position, layoutBias)", source)
        self.assertEqual(source.count("let operationBias = bias()"), 4)

    def test_obsolete_dependency_removed(self):
        for path in (ROOT / "policy").glob("*.nim"):
            text = path.read_text()
            for obsolete in ("orientation()", "aureole/orientation", 'shvArgs("recipe"'):
                self.assertNotIn(obsolete, text)


if __name__ == "__main__":
    offline = "--offline" in sys.argv
    if offline:
        sys.argv.remove("--offline")
        # Explicit unittest selectors must not bypass the offline boundary.
        del BiasIPCTests
    if len(sys.argv) > 1 and not sys.argv[1].startswith("-"):
        CLI = Path(sys.argv.pop(1)).resolve()
    if len(sys.argv) > 1 and not sys.argv[1].startswith("-"):
        BASELINE = Path(sys.argv.pop(1)).resolve()
    unittest.main(defaultTest="LayoutTests" if offline else None)
