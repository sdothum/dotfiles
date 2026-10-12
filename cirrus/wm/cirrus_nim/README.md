# Cirrus Nim candidate: Stage 3 managed lifecycle

The separate `cirrus-nim` candidate now manages newly arriving ordinary
clients through a runtime coordinator. Startup-adopted Stage 2 identities stay
observation-only. Runtime `MapRequest` creates an authoritative identity and
ordered model effects; X11 realizes those effects. Only a later client
`MapNotify` changes confirmed `mapped` state. Client `UnmapNotify` confirms
false, while sibling-decoration notifications never change client mapping.

The model lifecycle inputs and effects contain no XCB values. `model/` owns
client identity, generation/token allocation, ordered transitions, and the
minimal client/decor relation. `runtime/coordinator.nim` inspects pointer-free
X11 observations, feeds model inputs, and realizes the returned effects through
`x11/realize.nim`. Startup adoption remains under `startup/`. Raw XCB structs,
reply/event allocation and freeing, checked requests, root queries, property
copies, and decoration creation stay inside `x11/`.

The minimum management effects follow this order:

```text
select client events
add client to save-set
publish _NET_WM_DESKTOP=NULL_GROUP, then the initial raw group (1)
request client map
create root-sibling override-redirect decoration
request decoration map
publish WM_STATE=Normal
publish _NET_CLIENT_LIST and _NET_CLIENT_LIST_STACKING
```

With the frozen default outer border width of five and no inner gap, a client
at `(x,y,w,h)` receives a sibling decoration at `(x-5,y-5,w+10,h+10)`.
The candidate centers an initial runtime request at the root pointer when
`USPosition` is absent and applies Stage 5 ordinary screen fitting. It does
not implement focus, group activation, stacking/layers, snapshots,
invalidation, IPC, or configuration. It initializes a runtime client to raw group 1 when
there is no Stage 4 group/focus policy; special window types are mapped without
managed identity and override-redirect windows remain unmanaged.

Build the separate candidate from the C Cirrus repository root:

```sh
make -f Makefile.nim cirrus-nim
```

This writes `/tmp/cirrus-nim` by default. Override `NIM_OUT` and `NIMCACHE` to
choose other paths. The existing C Makefile and `cirrus` target are untouched.
The installed Nim compiler and `libxcb` development headers/library are
required; no Nim package dependencies are used.

Stage 1, 2, and 3 private-Xvfb tests:

```sh
python3 -B experiments/nim-cirrus/stage1/run_stage1.py --candidate cirrus_nim
python3 -B experiments/nim-cirrus/stage2/run_stage2.py --candidate cirrus_nim
python3 -B experiments/nim-cirrus/stage3/run_stage3.py --candidate cirrus_nim
```

`--test-events` retains a Stage 1 event-normalization-only path. `--test-state`
emits a test-only JSON model dump before entering the loop. `--test-lifecycle`
prints lifecycle milestones. The Stage 3 harness also uses
`--test-pause-before-effects`, a test-only SIGSTOP seam that allows a fixture to
destroy a client after the model transition and before realization. `--abi`
reports manually declared XCB sizes/offsets. `_NET_SUPPORTING_WM_CHECK` uses the
root as its support window and root identity properties match Stage 0;
`_NET_SUPPORTED` remains absent while the candidate implements only a subset
of the advertised EWMH mechanisms.

## Stage 5 geometry boundary

`model/geometry.nim` contains X-free arithmetic; `ClientState` stores client
and original geometry, setup-time minimum/increment hints, and independent
maximize/monocle flags. Typed geometry effects are realized in `x11/realize.nim`.
New runtime clients without `USPosition` are centered using an XQueryPointer
observation before ordinary fitting. ConfigureNotify does not overwrite model
geometry, and runtime WM_NORMAL_HINTS changes do not refresh the setup cache.

Stage 5 remains incomplete: the private-Xvfb differential matches centered
initial placement but shows a direct off-screen move leaves the C decoration
at its previous geometry while Nim reconfigures it. See the experiment
README for the normalized observation.

## Stage 5 geometry boundary

`model/geometry.nim` contains X-free geometry arithmetic and `ClientState`
stores client/original geometry, setup-time minimum/increment hints, and the
independent maximize/monocle flags. `wiMove*`, resize, ConfigureRequest,
maximize, monocle, and reset transitions update model state and emit ordered
typed geometry effects; `x11/realize.nim` performs checked ConfigureWindow
requests. ConfigureNotify remains an observation and does not overwrite the
authoritative geometry. WM_NORMAL_HINTS are captured during startup/runtime
setup; runtime property changes do not refresh the cache.

Stage 5 focused tests live in the Zephyr experiment tree. Current unresolved
private-Xvfb C differential: direct off-screen client movement leaves the C
decoration at its previous position in the sampled run, while the Nim
candidate synchronizes/clips it. Stage 5 remains incomplete until this
decoration behavior is reconciled against the source/runtime mechanism.
