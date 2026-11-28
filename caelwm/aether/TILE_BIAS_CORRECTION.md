# Unified numeric tile bias correction

Status: **VERIFIED for offline production-path fixtures, static checks and compilation**.
Live X11 execution, real daemon transport for placement and operational activation are
**NOT_EXECUTED**. The implementation is ready for independent review within this scope.

## Root causes corrected

1. `window.tileTarget()` passed explicit numeric columns and its omitted-column default
   directly to physical geometry. It never read authoritative LayoutBias. Every public
   overload and fluent numeric rule inherited that omission.
2. `layouts.tile()` mirrored the result of `columnOrder()` again, although implicit
   assignment positions were already oriented. Right-bias implicit placement therefore
   undid the intended reflection for two through five columns.
3. `columnOrder()` used ascending fallback sequences for both biases at six or more
   columns. These assignments were not horizontal reflections.

The correction treats LayoutBias as one global preference. It adds no application
exceptions, alternative state owner or environment orientation mechanism.

## Files and responsibilities

| File | Responsibility and change |
| --- | --- |
| `policy/layout_bias.nim` | Retains Aetherd-owned resident state; adds a pure logical-to-physical column conversion requiring an explicit bias argument. |
| `policy/layout_bias_access.nim` | Relocates the existing authoritative getter unchanged in behavior, allowing window and layout entrypoints to share it without importing layout execution. |
| `policy/layouts.nim` | Re-exports the getter for compatibility; preserves left assignment order and derives right assignments by reflection; distinguishes implicit physical assignments from explicit logical tile columns. |
| `wm/window.nim` | Captures bias once after parsing and captured-target validation, before source/screen acquisition; resolves numeric columns once; documents physical geometry and literal cardinal edges. |
| `tests/test_tile_bias.py` | Adds offline production-path placement, routing, rule, validation, identity, focus and snapshot regression fixtures. |
| `tests/test_layout_bias.py` | Updates the approved larger-grid assignment expectation, checks shared consumer geometry reflection and compares unaffected observations with the immediate pre-edit source. |
| `aether.nim` | Clarifies numeric tile and cardinal semantics in command usage text. |
| `man/aether.1` | Documents numeric columns, defaults, implicit assignments, global ownership, operation snapshots and the physical geometry boundary. |
| `TILE_BIAS_CORRECTION.md` | Records the contract, effects, verification and qualification limits. |

All paths in this table are relative to `aether/`. Application-rule definitions,
Aureole, Borealis, daemon lifecycle, parser grammar, placement transactions and history
implementations are unchanged.

## Final bias propagation

Remote numeric window command → production CLI/window dispatch → `tileTarget()` →
`layout_bias_access.bias()` → established `RequestQueryLayoutBias` daemon query →
captured value → `physicalColumn()` → `applyTileGridGeometry()`.

Fluent or internal numeric window operation → the same `tileTarget()` boundary.
A resident application rule follows that path, but the getter returns initialized
resident state directly, without querying its own daemon socket. Rules require no
bias argument and no modification.

Remote or resident layout tile → `layouts.tile()` captures bias once →
`gridOperation()` resolves either an explicit logical column with `physicalColumn()`
or an implicit position with `columnOrder()` → `window.tileGrid()` receives a physical
cell → deterministic geometry application. The layout path never calls the public
numeric window tile operation, so it does not reacquire or reapply bias.

`columnOrder()` and `physicalColumn()` never acquire state. `tileGrid()`,
`tileGridTarget()` and `applyTileGridGeometry()` retain their executable source.
Placement calculations remain physical and perform no bias acquisition or conversion.
Existing target validation, source capture, geometry submission, history calls and
captured-focus restoration retain their relative ordering. The new window bias read
occurs after captured-target validation and before source/screen acquisition.

## Explicit numeric columns

For valid logical C in an N-column grid: left physical = C; right physical = N − C + 1.
Physical column numbers increase from left to right. Each vector below lists the
physical result for logical columns 1 through N.

| N | Left physical columns | Right physical columns |
| --- | --- | --- |
| 1 | 1 | 1 |
| 2 | 1, 2 | 2, 1 |
| 3 | 1, 2, 3 | 3, 2, 1 |
| 4 | 1, 2, 3, 4 | 4, 3, 2, 1 |
| 5 | 1, 2, 3, 4, 5 | 5, 4, 3, 2, 1 |
| 6 | 1, 2, 3, 4, 5, 6 | 6, 5, 4, 3, 2, 1 |
| N ≥ 7 | 1, 2, …, N | N, N−1, …, 1 |

The window command's omitted column remains logical N: physically N for left bias,
physically 1 for right bias. Rows and row defaults are unchanged.

## Implicit assignment positions

The vectors list physical columns in assignment preference order for one row.

| N | Left assignment sequence | Right assignment sequence |
| --- | --- | --- |
| 1 | 1 | 1 |
| 2 | 2, 1 | 1, 2 |
| 3 | 2, 3, 1 | 2, 1, 3 |
| 4 | 3, 4, 2, 1 | 2, 1, 3, 4 |
| 5 | 3, 4, 5, 2, 1 | 3, 2, 1, 4, 5 |
| 6 | 1, 2, 3, 4, 5, 6 | 6, 5, 4, 3, 2, 1 |
| N ≥ 7 | 1, 2, …, N | N, N−1, …, 1 |

For R rows and one-based position P, the sequence index is
`((P - 1) div R) mod N`, and the row remains `(P - 1) mod R + 1`.
Each column fills top to bottom before advancing, and assignments wrap after capacity.
An omitted layout tile column uses this sequence, defaulting to P=1; it does not use
the window command's logical-last-column default. For example, N=4, R=2 gives left
cells `(3,1), (3,2), (4,1), (4,2), (2,1), (2,2), (1,1), (1,2)`; right cells use
columns `2,2,1,1,3,3,4,4` with the identical row sequence.

## Application rules and shared consumers

The unchanged kak single-editor branch with Firefox present and no qutebrowser executes
`discard w.tile("4", "4")`. It now selects physical column 4 under left bias and 1
under right bias. The fixture executes the complete production rule module, including
its actual live-count branching, using controlled class observations. Other numeric
rules inherit the same correction: xftp's 3/3 becomes physical 3/1; surf's 4/1 becomes
1/4; pcmanfm's omitted 3-column argument becomes 3/1. Center columns in odd grids
remain centered. No rule definition was edited.

Shared `columnOrder()` effects are limited to horizontal assignment symmetry:

- Left assignments are unchanged for every column count.
- Right assignments for one through five columns are unchanged in spread, fold and
  explode. Layout tile now consumes those assignments without the erroneous second mirror.
- Right implicit spread and fold assignments, including fold with `--spread`, reverse
  for six or more columns. Row ordering, window sizing and assignment wrapping remain.
- Current explode policies select at most five columns, so their assignments and
  geometry are unchanged. Their production group/stack callers are checked separately.
- Explicit layout spread columns keep their previous physical semantics. Window spread,
  snap, move, resize, focus and explicit cardinal directions are unchanged.

CENTER_BIAS remains independent and unchanged. The separate manpage rule target-selection
issue is deliberately unchanged. No unrelated defect was repaired.

## Verification actually executed

Toolchain: `/usr/lib/nim/bin/nim`, Nim 2.4.2, Linux amd64. Production Makefile builds
retain release options, configured ORC memory management and threads. All final commands
below exited **0**, without observed warnings or errors.

| Command | Evidence and result |
| --- | --- |
| `python3 aether/tests/test_tile_bias.py` | 2 tests; 6,118 successful offline placements, plus rejection/error assertions. |
| `python3 aether/tests/test_layout_bias.py --offline build/aether build/tile-bias-correction/before/aether/policy/layouts.nim` | 6 tests; 672 assignment-order records; 924 reflected tile/spread/fold plans covering 2,352 geometry pairs; 68 explode observations covering 612 window geometries; 8 snapshot/purity scenarios. 2,540 unaffected baseline records match; 504 changed records fall within the authorized correction scope. `build/aether` is an unused positional CLI argument in offline mode and is not executed. |
| `/usr/lib/nim/bin/nim check --hints:off --path:aether --nimcache:build/tile-bias-correction/check-aether aether/aether.nim` | Aether static/compiler check passes. |
| `/usr/lib/nim/bin/nim check --hints:off --path:aether --nimcache:build/tile-bias-correction/check-aetherd aether/aetherd.nim` | Aetherd static/compiler check passes. |
| `make aether BUILD_DIR=build/tile-bias-correction/compiled CACHE_DIR=build/tile-bias-correction/nimcache` | Aether compiles and links into an isolated evidence build directory. |
| `make aetherd BUILD_DIR=build/tile-bias-correction/compiled CACHE_DIR=build/tile-bias-correction/nimcache` | Aetherd compiles and links into that directory. |
| `git diff --check -- aether` | Scoped tracked-file whitespace check passes. New files receive separate checks recorded with the retained diff. |
| `groff -ww -Tutf8 -man aether/man/aether.1` | Manual renders without diagnostics; rendered text is retained. |

Tile fixtures cover columns 1–6, 7, 8, 12 and 17; every valid explicit column;
rows 1–3 and every valid row; defaults; implicit assignments through two grid capacities;
CLI routing; both public string overloads; fluent chains; provided-geometry internal
calls; initialized resident rules; physical grids; literal edges; invalid columns,
rows, dimensions and positions; remote error handling; captured target replacement;
stale identity; history call counts; and focus restoration. They count exactly one
remote bias query for numeric operations and zero for resident, cardinal and physical
operations. Remote reply changes and resident/screen-time preference changes cannot
alter an already captured operation. Source checks also verify one acquisition site
and no bias handling in physical tile geometry.

These are production-path **offline fixture observations**, not live runtime results.
X11 submission, daemon transport, group changes, unrelated fluent methods and history
persistence are replaced by explicit fixture effects. Full application-rule code and
numeric placement resolution execute; daemon event scheduling and persistence do not.

During fixture construction, temporary runs failed on missing fixture APIs/types/imports,
a test invocation exceeding the existing layout argument limit, and a spread target
expectation based on an incomplete fixture boundary. The fixture was corrected to use
the production spread-grid target path and valid existing argument forms. One temporary
fixture compile reported an unused import, removed before final verification. These
were fixture failures; no production compiler failure was observed. Final logs contain
all clean qualification commands and results.

## Retained evidence and limits

`build/tile-bias-correction/` retains immediate pre-edit source copies and SHA-256
provenance, initial working-tree status, complete assignment patch including new files,
verification command/exit-status JSON, stdout/stderr logs, manual rendering and isolated
compiled binaries. Final source/diff hashes and source-boundary equivalence checks are
recorded there. Historical evidence and frozen baselines were not modified.

Live X11 placement, real remote placement IPC, resident event-loop integration,
asynchronous X11 errors and persistent history transactions still require separately
authorized runtime qualification. The existing IPC test class was **NOT_EXECUTED**;
only the suite's explicit `--offline` selection ran. Pixel rounding, gaps, margins and
geometry formulas remain unchanged: reflection is checked within the rounded physical
grid envelope, preserving any existing unused remainder pixels.

No live desktop interaction, daemon restart, installation, deployment, network access,
privileged operation, commit or push occurred. Existing unrelated working-tree changes
were preserved. The complete assignment diff is ready for independent review.

**TILE_BIAS_CORRECTION_COMPLETE**
