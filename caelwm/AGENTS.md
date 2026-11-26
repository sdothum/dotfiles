# CaelWM — Codex Engineering Instructions

## Project Identity

CaelWM is an X11 window-management system implemented primarily in Nim.

Components:

- **Aureole** — X11 window-manager core; successor to Cirrus.
- **Borealis** — client command-line interface; successor to Sirocco.
- **Aether / Aetherd** — controller and daemon; successors to Zephyr / Zephyrd.
- **Shared** — common interfaces, types and supporting modules.

The migration must preserve established behavior unless an explicitly authorized change requires otherwise.

Do not assume that a migrated component is complete, authoritative, or ready for activation merely because corresponding source files exist.

## 1. Primary Engineering Principles

1. Correctness before optimization.
2. Preserve observable behavior and compatibility.
3. Prefer minimal, localized changes.
4. Maintain explicit component boundaries.
5. Avoid introducing dependencies without justification.
6. Separate implementation, verification and operational activation.
7. Do not silently repair unrelated defects.
8. Never substitute plausible behavior for verified behavior.

Prefer idiomatic Nim where it does not compromise C ABI compatibility or established behavior.

## 2. Nim Toolchain

Target the repository's verified Nim 2.x toolchain.

- Preserve established compiler options and memory-management settings.
- Prefer ORC where already configured.
- Do not switch memory managers without explicit justification and authorization.
- Preserve existing formatting conventions.
- Use explicit types at FFI boundaries.
- Avoid unnecessary allocations in event-processing paths.
- Do not introduce hidden ownership or lifetime assumptions.

### Verification

After each coherent source modification:

1. Identify the affected component and its actual entrypoint.
2. Run the appropriate existing static checks.
3. Run `nim check --hints:off` where applicable.
4. Execute existing relevant tests only within authorized execution boundaries.
5. Record commands, exit status, warnings and failures.

Do not assume `src/main.nim` is the universal entrypoint.

Never describe a check as successful unless it was actually executed and its result observed.

Do not modify unrelated code merely to eliminate pre-existing warnings.

## 3. X11 and C FFI

### ABI correctness

- Match C declarations, calling conventions, field types, alignment and ownership semantics.
- Prefer existing verified bindings over creating duplicate declarations.
- Use `importc`, `header`, `bycopy`, `union` and related Nim pragmas as appropriate to the actual C declaration.
- Never guess struct offsets, union layouts or pointer widths.
- Verify platform-dependent representations against authoritative headers or existing ABI tests.
- Do not modify system headers.

### X11 resource identifiers

Treat Window, Atom, Pixmap, Drawable, Cursor and related identifiers as logically distinct types.

Use distinct Nim types where compatible with existing bindings and interfaces.

Do not introduce incompatible representations through broad refactoring.

### XEvent and unions

Preserve the C union's actual layout.

Use verified imported definitions or explicitly validated union wrappers.

Never infer variant offsets from apparent field ordering.

### Pointer ownership

Distinguish:

- Nim-managed memory.
- Caller-owned C memory.
- Xlib-owned allocations.
- Borrowed pointers.
- Data copied synchronously by Xlib.
- Data retained beyond the call.

Release Xlib-owned allocations with the appropriate Xlib function, commonly `XFree`.

Do not assume every Xlib call retains its input buffer.

Document ownership where it is not immediately evident.

### Callbacks

C callbacks must use the correct calling convention.

Never allow Nim exceptions to unwind through C callbacks.

Use controlled, explicitly managed state for callback communication.

Avoid allocations, blocking operations and complex side effects inside X11 error handlers.

### Asynchronous errors

X11 protocol errors may be delivered asynchronously.

Do not infer successful server execution merely from successful submission of an Xlib request.

Use synchronization and error observation where required by an authorized test.

Do not change process-global Xlib error handlers without considering existing users and restoration semantics.

## 4. Component Boundaries

### Aureole

Responsible for core X11 window management, including:

- Client management and lifecycle.
- Focus and stacking.
- Window geometry.
- EWMH/ICCCM integration.
- Desktop and group state exposed by the WM.

Preserve established focus, stacking, group and visibility invariants.

### Borealis

Responsible for exposing the supported client-facing command interface.

Preserve:

- Command grammar.
- Public argument semantics.
- Output and error contracts.
- Exit-status behavior.
- Public one-based group numbering where applicable.

Do not silently reinterpret existing commands.

### Aether / Aetherd

Responsible for controller behavior, orchestration and associated state.

Preserve:

- Established controller command semantics.
- State transitions and history.
- Snapshot and restore invariants.
- Daemon lifecycle behavior.
- Separation between WM mechanics and UI policy.

Avoid moving status-bar or presentation policy into the WM core.

### Shared

Shared modules must have clearly identified consumers.

Do not introduce circular dependencies or duplicate component-specific state.

## 5. Behavioral Invariants

Treat the following as regression-sensitive:

- Focused-window and focused-group consistency.
- EWMH active-window and current-desktop consistency.
- Group membership and visibility.
- Client stacking order.
- Hidden-window cleanup.
- Geometry and border semantics.
- Snapshot and restore correctness.
- Fold, unfold, explode and unexplode behavior.
- Window identity and lifecycle handling.

Do not alter these invariants as incidental cleanup.

Where historical behavior and proposed behavior differ, report the discrepancy rather than silently selecting one.

## 6. Evidence and Verification

Distinguish explicitly between:

- Source inspection.
- Static analysis.
- Compilation.
- Unit testing.
- Isolated runtime testing.
- Live X11 testing.
- Production activation.

A successful result at one level does not establish success at another.

For migration and parity work:

- Preserve authoritative baseline inputs.
- Record relevant versions and provenance.
- Keep independent reference and candidate observations separate.
- Report mismatches without automatically redefining acceptance criteria.
- Do not promote provisional findings to verified conclusions.

Do not modify historical evidence, frozen baselines or authenticated manifests.

## 7. Operational Safety

Repository access does not imply permission to perform arbitrary host operations.

Unless specifically authorized:

- Do not replace or activate the running window manager.
- Do not restart Xorg, the display manager or active desktop services.
- Do not modify installed system binaries.
- Do not alter system configuration or package state.
- Do not execute privileged operations.
- Do not access external networks.
- Do not pull images or create containers.
- Do not modify persistent container storage.
- Do not delete or overwrite historical evidence.
- Do not perform destructive cleanup.
- Do not commit, push or publish changes.

Host probes, runtime experiments, namespace operations and privileged actions require explicit authorization covering their scope.

Read-only source inspection does not authorize executing untrusted project code.

If a required action exceeds authorization, stop and report the boundary.

## 8. Change Scope

Follow the active assignment's authorized scope.

- Modify only permitted files.
- Preserve unrelated behavior.
- Avoid opportunistic refactoring.
- Do not broaden the task based on newly discovered defects.
- Do not treat a proposed future stage as already approved.
- Stop when a required prerequisite is absent or contradictory.

A more specific assignment may narrow these rules.

It may expand operational permissions only through explicit user authorization.

## 9. Reporting

At completion, report:

1. Work performed.
2. Files changed.
3. Verification actually executed.
4. Results and observed failures.
5. Remaining uncertainties.
6. Authorization boundaries respected.
7. Whether the work is ready for independent review.

Use precise status terminology:

- VERIFIED
- PARTIALLY_VERIFIED
- UNVERIFIED
- BLOCKED
- NOT_EXECUTED

Do not describe documentary analysis as runtime validation.

Do not claim a migration stage is complete merely because its deliverables were written.

## 10. Optimization Policy

Performance improvements must preserve correctness.

For event-driven X11 code:

- Avoid unnecessary X server round trips.
- Avoid repeated queries when valid cached state exists.
- Minimize allocations in hot paths.
- Preserve ordering and synchronization requirements.
- Measure before claiming performance improvements.

Do not trade correctness, deterministic behavior or traceability for speculative speed improvements.

## 11. Instruction Precedence

This file provides repository-wide engineering defaults.

The active assignment defines its specific objectives, inputs, outputs and permitted operations.

More restrictive safety or verification requirements remain in force.

If instructions conflict, identify the conflict and follow the applicable higher-priority instruction rather than guessing.

Do not interpret this document as blanket authorization for implementation, testing, deployment or host modification.


## 12. Source Documentation Style

CAELWM prioritizes human-readable source documentation over generated API documentation.

### Module-level procedures

- Introduce each named module-level procedure implementation with ordinary `#` commentary preceding its declaration.
- Use two blank lines before the commentary block and one blank line between the commentary and procedure declaration.
- Align commentary with the declaration indentation.
- Treat the commentary and procedure implementation as a single visual unit.
- Do not embed introductory `##` documentation within procedure bodies.
- Preserve existing meaningful module section headings without accumulating redundant whitespace.

### Commentary content

- Use concise, present-tense behavioural descriptions.
- Prefer one line for straightforward procedures.
- Add further lines when necessary to explain contracts, preconditions, invariants, side effects, ordering, failure behaviour or architectural boundaries.
- Describe what the procedure accomplishes rather than paraphrasing its implementation.
- Use approximately 90 characters per commentary line as a flexible readability target.
- Avoid redundant descriptions, decorative separators and unnecessary verbosity.

### Exceptions

- Nested procedures require introductory commentary only when it materially improves understanding. Use normal single-blank-line spacing rather than the module-level heading convention.
- Anonymous procedures and callbacks do not require introductory commentary.
- Forward declarations do not require duplicate commentary. Use normal single-blank-line spacing.
- Preserve meaningful internal comments explaining non-obvious implementation rationale, architectural constraints and invariants.
- Generated API documentation is not an objective of this convention.

### Documentation-only changes

- Preserve executable source text, significant indentation and behaviour.
- Verify non-comment compiler token equivalence against the immediate pre-edit source, accounting for intentional whitespace and source-location changes.
- Run appropriate compiler checks for affected components.
- Run scoped `git diff --check`.
- Do not introduce unrelated refactoring, formatting, renaming or behavioural corrections during documentation-only assignments.
