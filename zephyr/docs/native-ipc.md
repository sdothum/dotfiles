# Native cirrus IPC

Zephyr uses `wm/native_ipc.nim` for synchronous, typed commands. It shares the
existing minimal libxcb interop in `wm/x11_snapshot.nim` with zephyrd. No protocol,
WM policy, layout algorithm, cache selector, or transaction format changed.
The obsolete command-side `wm/x11_ipc.nim` wrapper was replaced by this API.
No additional package is required: Zephyr already links libxcb.

## Source audit and migration inventory

Contract sources: cirrus `ipc.h`, `client.c` (`send_ipc`,
`query_window`, `send_normalized_action`, collection/action parsers), and
`ipc_handlers.c` (dispatch, response writers, individual handlers).

| Zephyr module / call sites | Native operations |
| --- | --- |
| `window_query`: focusedWinid, wmSnapshot/tryWmSnapshot, geometry, stack, stackGeometries, bulk geometry | live focus/snapshot/geometry/overlap queries; identity-checked and unchecked geometry |
| `window`: liveIds, toggle | live mapped/all class/name IDs; hide/focus |
| `window`: focus, layer, hide, await, swap | explicit/last/cardinal focus; layer; acknowledged hide; status-returning focus/hide |
| `window`: wtp, move, shift, snap | absolute/relative move and resize; wtp still sends move followed by resize |
| `window`: raiseMany, group | acknowledged ordered raise set; group remove/add |
| `group`: count, current/currentLive, remove/close, desktop/focus/restore/toggle | count/current; close, clear, activate/deactivate, focus |
| `display`: dimensions | existing X root-geometry query, now sharing the command session |
| `layout` / `state` | no algorithm or transaction edits; existing window/query calls inherit the transport |

The public daemon-cached queries (`window ids`, count/class/name/group queries,
public snapshot/current queries) still use zephyrd. Live identity snapshots still
query cirrus. No independent group cache or bypass was added. The daemon's
snapshot session remains owned by the daemon; its existing read-only recovery
retry remains read-only.

A search of production Nim sources finds **no remaining sirocco subprocess
invocations**. `compat.nim` keeps its generic subprocess helpers for external
commands. Remaining sirocco references are explanatory comments, manual links,
and integration-test oracle/setup calls. Tests intentionally run the independent
C client to compare results and manipulate test fixtures. The previous shell
mocks in layer/reconciliation tests were replaced with real private-WM tests.

## Wire contract

The connection selects the screen from DISPLAY. Atoms are interned on connection
initialization: `__WM_IPC_COMMAND`, `__WM_IPC_RESPONSE`, `__WM_IPC_REQUEST`.
Commands are format-32 ClientMessages sent to the root with
SubstructureRedirectMask using `xcb_send_event_checked` + `xcb_request_check`,
then flushed. Five uint32 words carry the command ID and four arguments.
Signed coordinates use the same int32-to-uint32 representation as C.

For reply commands, word 1 is an InputOnly reply-window XID, subscribed to
PropertyChange. The response is a STRING/8 property on that window. Its envelope
is `OK`, `OK <scalar>`, `OK\n<records>`, or `ERROR <reason>` according to the
command. ID queries are sorted as in C; overlapping-stack order is retained.
Whitespace normalization matches the former subprocess capture. Snapshot and
geometry parsers and identity validation remain in their existing modules.

The enum values are fixed by `ipc.h` (not inferred from CLI strings):

| IDs | Payload after command word / response |
| --- | --- |
| 0/1 activate/deactivate | reply window, public group; OK/error |
| 2 clear group | group; no WM reply |
| 3 cardinal focus | direction N=0,E=1,S=2,W=3; no WM reply |
| 4/5/8/9 focus cycles | no arguments; no WM reply (standalone CLI only) |
| 6/7 focus/last | target XID / no arguments; no WM reply |
| 10 configure | existing config key/arguments; no WM reply (standalone CLI only) |
| 11/37 quit/restart | no arguments; no WM reply (standalone CLI only) |
| 12 focused | reply window; scalar XID or error if none |
| 13/14 IDs/count | reply window, selector atom, mapped=0/all=1, none=0/class=1/name=2; list/scalar |
| 15 classname | reply window; scalar class or empty OK (standalone CLI only) |
| 16 geometry | reply window, explicit flag, XID; X/Y/WIDTH/HEIGHT records |
| 17/18 move/resize | absolute=1/relative=0, x/width, y/height, target (0 means focused); no WM reply |
| 19/20 maximize/monocle | axis and target / target; no WM reply (standalone CLI only) |
| 21 close | target (0 means focused); no WM reply |
| 22/23 hide/reset | reply window, explicit flag, XID; OK/error |
| 24 stack cycle | reply window, explicit flag, XID; OK/error |
| 25/26 group add/remove | group and target / target; no WM reply |
| 27/32 stack/stack-geometries | reply window, explicit flag, XID; ordered IDs/geometry records |
| 28/36 group current/count | reply window; scalar |
| 29/30 window group/groups | reply window plus explicit flag and XID / reply window; scalar/records |
| 31 snapshot | reply window, 0, all=1, none=0; existing SNAPSHOT 1/2 records |
| 33/34/35 geometry/raise-many/checked-geometry | reply window plus STRING/8 request property; OK/error |
| 38 layer | reply window, explicit flag, XID, normal=0/above=1/overlay=2; OK/error |

IDs optionally carry one CARDINAL/32 public group number in the request property;
no zero-based translation is performed. Geometry payloads contain newline-delimited
`XID x y width height` records; checked geometry additionally includes the token
after XID. Raise-many contains newline-delimited XIDs in caller order. Request
properties are cleared before reuse so a group filter or payload cannot leak.

## Lifecycle, ordering, and limitations

One lazy, process-global command connection and one reusable reply window live for the duration
of each Zephyr invocation, including `.` chains. Calls are synchronous and never
pipelined. This API is not thread-safe or reentrant: the existing CLI and daemon
event loops serialize access. No concurrency support was added. The XCB queue is drained before polling (the checked send may already
have buffered the property notification). A monotonic two-second reply deadline
matches C's timeout; interrupted polls resume against the same deadline. Matching
PropertyNewValue notifications are decoded; deletion notifications are ignored.
Reply/property/error/event allocations are freed. Process exit disconnects XCB,
which destroys its reply window; no resident service was introduced.

The protocol has **no request identifiers**. A timeout or transport failure
closes the connection, destroying its reply window and releasing XCB's event and
reply queues. Reset clears the connection pointer, root, reply-window XID, all
three atom IDs and last response text, even after partial initialization. Failed
initialization uses this same cleanup path. `lastFailure` retains a diagnostic
only; it is not connection-validity state. `isOpen()` checks the pointer and XCB
connection error state. Explicit WM errors have already consumed/deleted their
response and leave the session usable.

**XID reuse matters even after disconnect.** Verification reproduced an old hide
reply completing a new snapshot request when cirrus was stopped, Zephyr timed
out, and XCB reused the old connection's reply-window XID before cirrus resumed.
The allocator now skips reply XIDs retired by ambiguous failures. This small
process-owned retirement list survives session reset and is released at process
exit; it owns no X resources. It can grow by one uint32 per distinct failed reply
window. It deliberately survives X-server restart too (harmless conservative
skipping). No request identifiers or extra X synchronization round trips were
added. Merely destroying the old window was insufficient.

A subsequent independent operation reconnects and re-interns atoms, with a fresh
reply window that cannot alias any retired request in this process. Mutations
are never automatically replayed. A WM restart alone leaves the X connection
valid, so requests reach the new WM; X-server disconnection causes invalidation
and reconnection.

**Existing completion ambiguity:** move, resize, focus, last/cardinal focus,
close, group add/remove/clear have no WM acknowledgement. Success means checked
X-server submission, exactly as in sirocco, not confirmed application by cirrus.
They can report submission success with no WM running. Acknowledged commands
wait for the WM's response, but a timeout cannot establish whether mutation
occurred. Zephyr preserves these distinctions rather than adding round trips or
changing protocol semantics. The C fire-and-forget send routine also only logs X request errors; native
transport failures are reported as errors rather than leaving a failed session
reusable. Native errors use `cirrus IPC: <reason>` and
nonzero exit status; callers that intentionally inspect status retain that path.

## Verification and measurements

Builds: Zephyr, zephyrd, test probe, and both cirrus/sirocco from a clean source
copy in `/tmp`; no cirrus source edits. Final builds produced no compiler errors
or warnings. The first staging build omitted VERSION (make's cat diagnostics);
VERSION was copied and the full build repeated successfully.

`tests/test_native_ipc.py` compares C/native queries and mutations on Xvfb,
including group/class/name filters, absent filter after grouped request, hidden
clients, tokens, geometry, focus, raises, group transitions, layer CLI validation,
100 requests using one reply window, cleanup after process exit, a chained
query/move/query, stopped-WM mutation timeout and late reply, absent/restarted WM,
and X-server loss/reconnect. Build its driver with:

```sh
nim c -o:/tmp/native-ipc-probe tests/native_ipc_probe.nim
python3 tests/test_native_ipc.py /path/to/cirrus ./zephyr ./zephyrd /tmp/native-ipc-probe
```

An optional fifth argument supplies the pre-migration Zephyr binary for benchmarks.
The recorded run used identically compiled Nim debug builds, an isolated 1024x768
Xvfb server, six managed clients, a warmed daemon cache, one warm-up per binary,
and alternating before/after invocations. Wall time includes process launch.

| Operation | Samples per binary | Before median | After median |
| --- | ---: | ---: | ---: |
| `group count` | 40 | 1.713 ms | 0.910 ms |
| `layout fold 3 --rows 2 --group 2` (six clients) | 20 | 7.517 ms | 3.548 ms |

These are local measurements, not general latency guarantees. The architectural
result is removal of subprocess command construction and repeated X connections.

Regression results: all 14 Nim suites passed (checked geometry, class/group
state, identities, daemon IPC, panel notifications, restore transactions,
snapshot diff/publication/framing, stack geometries, reconciliation, lifecycle
cleanup, WM_CLASS). All six Zephyr Xvfb suites passed (native IPC, cached group
IDs, lifecycle, fold stacking, group explode, class fold), as did both cirrus
suites (layers and group IDs). Expected invalid-input diagnostics in the C tests
are assertions, not compiler warnings. Xvfb reports nonfatal host keyboard-map
warnings. Reconciliation now runs only through the private-WM fixture described
below because its group-count query is native rather than a fake executable.

## Final lifecycle verification

Run the complete suite, including builds, with:

```sh
python3 tests/run_native_regressions.py /path/to/cirrus/source
```

The runner builds into a printed temporary directory and retains logs. It stages
cirrus sources, leaving the source repository untouched. Pure Nim suites run with
an invalid DISPLAY. All ten reconciliation cases call `reconcileSnapshot()`,
which obtains the real WM group count; the entire suite is therefore classified
as integration rather than pretending these are pure filesystem tests.
`tests/private_wm.py` uses the existing integration suites' private-display
pattern (`Xvfb -displayfd`, temporary environment roots, `cirrus -c /bin/true`).
The reconciliation binary refuses to run unless the fixture marker matches
DISPLAY; the runner also tests this refusal. It cannot accidentally inherit the
user's desktop WM. No fake sirocco executable is involved.

The strengthened native test probe and `test_native_ipc.py` check:

* Consecutive snapshot successes and invalid-XID hide errors use exactly the
  same reply window. After **each** response, xprop verifies that
  `__WM_IPC_RESPONSE` is absent. `xcb_get_property` uses delete=1, STRING type,
  and a full-length read; its PropertyDelete event may remain queued but cannot
  satisfy the next request. Explicit WM errors do not invalidate the session.
* **Stopped WM, unacknowledged mutation:** SIGSTOP plus waitpid/WUNTRACED ensures
  cirrus is stopped while Xvfb remains live. Native `focus` returns submission
  success promptly (under 1.5 seconds), without waiting for a WM reply.
* **Stopped WM, acknowledged mutation:** native `hide` reaches its two-second
  reply deadline (asserted 1.8–5 seconds) and reports `TIMEOUT (completion
  unknown)`. A real unrelated PropertyNewValue event and a synthetic matching
  PropertyDelete event are delivered while it waits; neither completes it.
* **Immediate post-timeout operation:** a snapshot is submitted while cirrus is
  still stopped. The test observes destruction of the old reply window and
  creation of a different one, then resumes cirrus. Its queued hide response
  cannot complete the snapshot. The hide is subsequently observed as applied.
  This test failed before the allocator fix with identical old/new XIDs and
  `malformed WM response`.
* **Absent WM:** after terminating cirrus, snapshot times out while native/C
  focus still report X submission success. This is separate from SIGSTOP tests.
* **Initialization and recovery:** the probe explicitly closes its session,
  attempts connection to an unavailable display, returns CONNECT, restores
  DISPLAY, and successfully queries again. WM restart and actual X-server
  termination/restart also recover. Before starting the new WM, the test seeds
  dummy atoms and asserts all three protocol atom IDs differ from the old
  server's IDs; the subsequent successful query proves re-interning, rather
  than coincidental validity of stale identifiers. The private-state unit test
  `test_x11_session.nim` verifies unconditional reset, idempotent close, and
  failed-connect cleanup without exposing production introspection APIs.

Limitations: the tests do not deliberately drop a reply after a mutation has
already been applied **before** its deadline. The current real-WM fixture has no
selective response-drop hook; adding a proxy or instrumenting cirrus would
expand this verification task. The stopped-WM test covers a queued mutation
applied after timeout with its response sent to a retired window. No automatic
mutation replay is present in the inspected command path. Individual atom-intern
allocation failures are not fault-injected; their common cleanup path is reviewed
and partial-state cleanup is unit-tested. Retirement protects requests from this
process, not forged responses or XID reuse by an unrelated process after exit;
the unchanged protocol is not authenticated.

Final verification results: all **15 current Nim suites**, all six Zephyr Xvfb
integration suites (including the layer CLI checks), and both cirrus suites
passed. Zephyr, zephyrd, the probe, and cirrus/sirocco were rebuilt from source;
no compiler warnings or errors were reported. The full runner also verified
that an unguarded reconciliation invocation is rejected. No commits or wire
protocol changes were made.
