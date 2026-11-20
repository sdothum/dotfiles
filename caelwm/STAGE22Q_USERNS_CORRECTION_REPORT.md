# Stage 22Q user namespace correction report

Status: **BLOCKED_USERNS_CONFIGURATION**

No fixture correction was applied. The Stage 22M fixture and Gate L1 evidence are absent from the supplied workspace `/home/shum/stow/caelwm`. A safe fixture-level replacement, including its pre-start assertions, cannot be established from the available files. This is a missing-input blocker, not a finding that the candidate is unsupported by Podman.

## Evidence and candidate assessment

The attempt-003 exit 125, error text, `--userns=private`, and absence of a CID are owner-supplied observations; the original evidence was not available for independent inspection.

Version-pinned upstream evidence was read as text only:

1. [Podman v6.1.4 userns documentation](https://raw.githubusercontent.com/containers/podman/v6.1.4/docs/source/markdown/options/userns.container.md), lines 20–26 and 49–57: keep-id supports explicit container UID/GID targets, creates a user namespace, and selects the init user unless explicitly overridden. Thus `--userns=keep-id:uid=0,gid=0` is a supported candidate for mapping the rootless caller to container root. Plain keep-id would retain the caller's numeric IDs instead. An explicit conflicting `--user` must be excluded or corrected after inspecting the fixture.
2. [Podman v6.1.4 namespace implementation](https://raw.githubusercontent.com/containers/podman/v6.1.4/pkg/specgen/namespaces.go), lines 470–519: keep-id generates mappings, selects the process UID/GID, and invokes private namespace setup. The private branch alone uses supplied mappings; missing mappings produce the exact reported error. This explains the failure and supports replacing the mode rather than merely suppressing the error.
3. [Podman v6.1.4 mapping implementation](https://raw.githubusercontent.com/containers/podman/v6.1.4/pkg/util/utils.go), lines 169–246: rootless keep-id applies UID/GID overrides and maps each chosen container ID to intermediate namespace ID 0, with size 1. With both overrides zero, container 0:0 maps through the rootless namespace to the invoking host user/group, not initial-host root. Intermediate ID 0 must not be mistaken for host UID 0.

Conclusion: the candidate has documentary and implementation support for the requested identity semantics. This does not establish that it preserves all invariants in an unavailable fixture. Omitting userns would permit environment/configuration defaults; no such fallback was applied.

## Exact diff and scope

Fixture diff: **empty**. No fixture, assertion, source, application configuration, or Gate L1 evidence file was changed. The sole added artifact is this report. No executable patch is proposed against an invented filename or unknown inspection schema.

The prospective mode substitution is `--userns=private` → `--userns=keep-id:uid=0,gid=0`; it is **not applied or approved as a complete fixture correction**.

Before a correction can be accepted, the actual fixture must be inspected and its existing pre-start validation narrowly updated to verify the selected mode and effective user 0:0, nonempty UID/GID mappings with the intended rootless translation, and rejection before start on mismatch. Assertions must use the real inspect representation rather than an assumed schema. Existing CID/name/label identity checks and cleanup guards must remain intact.

The private X11 socket directory must resolve to namespace owner 0:0 with its existing restrictive permissions. Whether it is a bind mount, tmpfs, or created in the image is unknown. Host X11 sockets/authority, production paths, privilege elevation, and unrelated mounts must remain excluded. The userns flag alone does not prove those properties.

## Offline checks and results

- `find /home/shum/stow/caelwm -type f -print`: succeeded; 75 existing files, comprising application sources, two navigation tests, licenses, README, BUILDING, and Makefile. No Stage 22 fixture or evidence directory was present.
- `rg -n -i 'stage.?22|podman|gate.?l1|userns' /home/shum/stow/caelwm` before adding this report: exit 1, no matches.
- Candidate syntax/configuration: reviewed against the pinned v6.1.4 documentation, parser, namespace setup, and mapping implementation above. Supported at source level; not a local Podman parser test.
- Fixture syntax tests: **NOT RUN — fixture unavailable**. No claim of passing shell/Python syntax or configuration regression tests is made.
- Runtime tests: **NOT RUN — prohibited by this assignment**. No Podman, Docker, container, Xvfb, or CaelWM execution occurred. No Gate L1 evidence directory was modified.

## Remaining uncertainties and boundary

Unverified: actual fixture arguments and inspect schema; effective user overrides; subordinate-ID availability and host policy; installed build behavior; mapping inspection representation; private socket ownership and access; mount/authority isolation; create/start success; existing identity and cleanup behavior. No runtime success or Gate L1 pass is claimed.

Any subsequent owner-run attempt must use fresh evidence, for example `gate-l1-run-004`, after the actual fixture and assertions have been corrected and validated. Owner authorization for Gate L1 host execution does not authorize Codex to execute it here. Stage 22K Gate L2 remains unauthorized. Stage 21 remains CLOSED WITH DOCUMENTED EXCLUSIONS, including N40/N41 and the historical geometry limitation.

Work stops with this report.
