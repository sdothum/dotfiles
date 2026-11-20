# Stage 22AL HTTP 504 recovery assessment

Verdict: **STAGE22AL_TRANSIENT_HTTP504_RETRY_ELIGIBLE**

This means technically eligible for consideration of a separately authorized new attempt. It is **not authorization to retry**. No source correction is necessary for this failure. “Transient” describes the potentially temporary HTTP service failure class; recovery or future availability has not been demonstrated.

## Scope and evidence

Offline assessment on 2026-11-12. Evidence root: `/home/shum/tmp/caelwm-stage22/ca-stage22ak-provisional-bootstrap-001` (hereafter E). E was treated as immutable: no changes, permission changes, repair, resume, deletion or finalization were performed. Only this report is a retained assessment output. Signature rechecks used an isolated temporary GnuPG home outside E; plaintext and decompression comparisons were in memory. No acquisition/verifier entry point, network request, installation, build, container, gate, production change or commit was executed.

Reviewed E's stderr, headers, writeout, 28 journal events, result, manifests, owner records, source snapshots, signed metadata and retained indexes; compared the current Stage22AK source and owner instructions in `experiments/stage22-fixture-recovery/replacement`.

## Exact failure classification

The sixth and final request was GET
`https://snapshot.ubuntu.com/ubuntu/20260701T000000Z/dists/jammy-updates/main/binary-amd64/Packages.xz`.

- Stderr: `curl: (22) The requested URL returned error: 504`.
- Headers: one `HTTP/2 504` block, `cache-control: no-cache`, `content-type: text/html`.
- Writeout: `exitcode=22`, `http_code=response_code=504`, `ssl_verify_result=0`, `scheme=https`, exact expected effective URL, `num_redirects=0`, `num_retries=0`, `proxy_used=0`, `num_connects=1`, remote `185.125.189.69:443`, `size_download=size_delivered=0`.
- Timing in seconds: DNS 0.013455, TCP connection 0.115352, TLS completion 0.239234, first response 50.347774, total 50.347844. This is below the 300-second client limit. The failed response body file does not exist; the three diagnostic sidecars remain.
- Journal sequence 26 starts that request at 15:00:13.947511 UTC; sequence 27 records return code 22 at 15:01:04.305062; sequence 28 records failure at 15:01:04.314099. No later transfer occurs.
- Result: `FAILED_PROVISIONAL_ACQUISITION`, stage `authenticated-indexes`, with five `requests_completed` records. That list contains validated successful requests, not every initiated request; the failed sixth request is retained in the journal and sidecars.

The sole observed immediate failure is an HTTP 504 Gateway Timeout response received over the configured HTTPS connection, rejected by curl's `--fail`. There is no observed DNS-resolution, TCP-connection, TLS/hostname verification, client timeout, local write, resource-cap, hash or signature failure. Curl's nonzero exit is the intended local reaction to the HTTP error. The response does not establish which remote gateway/origin component timed out, its underlying cause, or that it will recover. Transport remains provisionally trusted under the existing policy.

`result.json` and the journal say `TLS/hostname/client transfer failure` because `Acquisition.download()` uses that single generic message for any nonzero curl return before parsing writeout. It is an imprecise umbrella diagnostic, not affirmative evidence of a TLS failure. The detailed retained evidence resolves the classification without editing the result.

## Transfer and validation chronology

All times below are UTC on 2026-11-12. Successful rows have HTTP 200, curl exit 0 and TLS verification result 0; their writeout objects exactly match the response objects in result.json.

| Download | Start | Validated transfer finish | curl seconds | Bytes |
| --- | --- | --- | ---: | ---: |
| jammy.InRelease | 14:57:55.333961+00:00 | 14:58:30.977097+00:00 | 35.628525 | 270087 |
| jammy-updates.InRelease | 14:58:30.996736+00:00 | 14:58:53.797202+00:00 | 22.783562 | 128049 |
| jammy-security.InRelease | 14:58:53.818447+00:00 | 14:59:06.492375+00:00 | 12.656168 | 128927 |
| jammy-main-Packages.xz | 14:59:06.512520+00:00 | 14:59:31.358100+00:00 | 24.826798 | 1394768 |
| jammy-universe-Packages.xz | 14:59:31.535952+00:00 | 15:00:12.880748+00:00 | 41.313264 | 14090084 |

Local trust-chain work began at 14:57:55.233619; curl/gpgv/OpenSSL preflight tools returned 0. Each InRelease was followed by successful gpgv verification (14:58:30.987217, 14:58:53.809836, 14:59:06.500760). Authenticated-index processing began at 14:59:06.507045. Both jammy indexes passed signed compressed hash/size validation, decompression and index parsing before the jammy-updates/main request. The remaining four indexes were not completed; package selection across six indexes, .deb acquisition, control checks and bundle derivation were never reached.

## Evidence integrity and independent offline rechecks

All 71 files in E/manifest.json match their recorded sizes and SHA-256 values. The complete file inventory matches, with no extra payload files. All 72 SHA256SUMS entries (including manifest.json) match and correspond exactly to that inventory plus the manifest. No symlinks were found. Every file is mode 0400 and every directory, including E, mode 0500. Manifest status is `failure`; SUCCESS is absent.

Manifest SHA-256: `0c283ba50b1ab7527cdee627f8bb9c66f2cf55e07cfa01540eb88dd69a5b7b13`.

The exact authorization bytes match execution-intent.json's authorization_sha256. Authorization ID is `stage22ak-cfd827c98b13472faedd10728269a4a2`; its window was 14:57:22–16:57:22 UTC. All transfers and recorded completion fall within that window, with at least 300 seconds remaining at each request. The authorization remains consumed regardless of its original expiry.

All entries in the current STAGE22AK_SHA256SUMS.txt were rehashed successfully. The three current executable source files equal their retained snapshots and owner-authorized hashes:

| Source | SHA-256 |
| --- | --- |
| stage22ak_acquisition.py | 93399aac84e2a4295d7faa3756175c8e3750ac687a7c08c4c638bafc2ed63a27 |
| stage22ak-acquire-ca-provisional.sh | 770fca840f989139e3bac3523acd268e0f93f604e7608780392746a7c438af22 |
| stage22ak-verify-acquisition.py | 1bf20db3f8fc154074c20afba3c3540dbd8cc61b9346fbd1d44468fa292ea703 |

Retained TLS CAfile and Ubuntu keyring match the respective policy pins. Fresh offline gpgv checks returned 0 for all three InReleases, with signer `F6ECB3762474EDA9D21B7022871920D1991BC93C`. Their recovered plaintext bytes exactly equal the retained Release files:

| Release | Plaintext SHA-256 |
| --- | --- |
| jammy | 6883c1cb0fcfeefc2ad2e99746fcbb28cf8b2df66ce49904765d883dbf94a1ca |
| jammy-updates | 20cc94f8c5244daaed16bfd986e7eb9b79b3f4d23fc9a3b33ff09642c827dc7f |
| jammy-security | 81fecc3a23f6947bca55d1be6e541c509dfdfb00401d8f32fa1228c307da080a |

All five successful download bodies match their result-record hashes and sizes:

| Body | SHA-256 |
| --- | --- |
| jammy.InRelease | c14060cd8c6d625874dfcb9523a35a395bf4865c28b6b6a82569ef326fe92dc6 |
| jammy-updates.InRelease | 35141a3df1c02c8ee20812bac8ee7ebdf307507c7acda6dde995e44e5ca00e9e |
| jammy-security.InRelease | a45c20471c81d8bd7d31cd69a7b2311a5f3e5849444db0cf6c40b9aae5253a16 |
| jammy-main-Packages.xz | 37cb57f1554cbfa71c5a29ee9ffee18a9a8c1782bb0568e0874b7ff4ce8f9c11 |
| jammy-universe-Packages.xz | d29cb24c93fec5f43255706bce7eb46d4779952039d8c68ac1bb14a6f3655ce2 |

Both compressed indexes also match their SHA256 hash and size entries in the newly signature-verified jammy Release. In-memory decompression equals the retained plaintext indexes; those plaintexts additionally match the Release's uncompressed hash and size entries:

| Plain index | Bytes | SHA-256 |
| --- | ---: | --- |
| main | 6779186 | 12ce0797a6ed39a1fee1321985976c6b78872a8fe4c7ef2fb712f2364c9839a3 |
| universe | 64332414 | 6b8cc68643d18250ab297c4f6d427a8778b1d1534e1a3033fff0f221fa20a419 |

These checks support retained-byte consistency and authentication relative to the pinned archive anchor. Adjacent manifests do not establish independent custody or prove absence of coordinated historical tampering. This assessment does not certify the failed attempt as a complete bootstrap artifact or rerun the full current local-publication trust reconstruction. The normal offline verifier explicitly rejects a failure manifest before completion verification; bypassing that condition would be incorrect.

## Approximately 13-minute terminal display

The acquisition's started_at is 14:57:55.223189 UTC and finished_at is 15:01:04.319964 UTC: **189.096775 seconds (3 minutes 9.096775 seconds)**, or 09:57:55–10:01:04 Toronto local time. Its six curl totals sum to approximately 187.556 seconds, consistent with serial transfers plus local processing. Source inspection shows started_at is recorded after authorization checks and exclusive destination creation, and finished_at on the failure path before sealing. Thus this interval is not a measurement of the entire surrounding terminal session or every wrapper/preflight/final-sealing operation.

No retained tmux timer provenance, timer start/end record or shell-wide process-runtime measurement was identified in E. The reported approximately 13-minute display cannot be attributed to this process from the available evidence. It may include surrounding session/tool waiting or other lifecycle time, but that is a hypothesis, not a finding. If the display were exactly 13 minutes, its difference from the recorded interval would be about 9 minutes 51 seconds; that difference cannot be assigned to a specific activity here. It provides no evidence of an extra transfer, hidden retry or 13-minute curl runtime. The exact display semantics remain unresolved; the recorded acquisition interval is internally consistent.

## Implementation assessment

Stage22AK behaved correctly for the observed failure under its fail-closed, no-retry policy. Exclusive directory creation consumed the attempt. The first nonzero curl return raised immediately, retained diagnostics, wrote a failure result and failure manifest, sealed the evidence and returned failure without a success marker. No automatic retry, resume, alternate endpoint or trust-check bypass appears in the request arguments or execution chronology. The successful response list is intentionally populated only after transfer/response validation; omission of the failed request there is reconciled by the journal.

The unchanged implementation can be reused for a separately authorized fresh attempt, subject to its normal offline prerequisites and fresh preflight. No correction is needed to handle HTTP 504 safely. Improving the generic diagnostic could be a separate future change, but is unnecessary for this recovery decision and would alter qualified source hashes and require its own review. No such change was made or proposed as a prerequisite.

## Minimum requirements for a separately authorized new attempt

1. Preserve E unchanged and record the consumed failure in the owner's decision context. Obtain a new explicit purpose-specific owner decision; this report and the consumed grant confer no execution authority.
2. Create new public owner authorization and execution-intent records with a new unique authorization ID and actual owner approval/execution references. Bind the exact unchanged reviewed source hashes, policy, owner identity and a **fresh, nonexistent destination** under the private owner-controlled Stage22 parent. Do not reuse, rename or delete E to satisfy destination checks.
3. Use zoned approval/expiry timestamps with a positive window no longer than 24 hours, enough time for up to ten serial bounded transfers and validation. Each request requires at least 300 seconds remaining and completion must precede expiry. Bind execution intent to the exact final authorization-file bytes by SHA-256, with actual owner-controlled execution and authenticated owner custody.
4. Explicitly accept the existing provisional transport and signed-metadata replay risk. Keep all independence flags false, the fixed HTTPS snapshot, exact six-index maximum Debian-version rule and any genuine additional version/digest constraints. Optional complete Release checkpoints require independently justified provenance; hashes learned only from this provisional attempt do not become independent checkpoints.
5. Before execution, recheck qualified/historical source manifests and all required local trust, capture/custody, CAfile, base-manifest and Ubuntu-keyring inputs with existing tools. Changed prerequisites must fail rather than be repaired by weakening policy. Use the established nonroot, clean-environment owner procedure, not an execution command supplied by this assessment.
6. Start the complete acquisition afresh: three InReleases, six authenticated indexes, then at most one selected .deb and local derivation. Preserve existing bounds, normal TLS/hostname verification, signature/hash/size/identity checks, disabled proxy/netrc/native trust, zero redirects, no retries and no resume. A new failure consumes the new attempt too.
7. Preserve and review the new result. Only a successful complete artifact plus separately invoked offline verification against an owner-custodied manifest hash can support later consideration. Neither acquisition success nor verification authorizes installation, image correction/build, container execution, Gate L1/L2 or production use.

## Reuse of prior signed metadata and remaining restrictions

Default and recommendation: **completely fresh acquisition**. Existing signed metadata remains useful as immutable comparison evidence. Signature validity authenticates signed bytes relative to the pinned keyring; it does not establish freshness, exact historical snapshot identity or new owner authorization. Partial indexes also cannot establish selection across all six approved indexes.

The unchanged Stage22AK path has no import/cache/resume mechanism and requires an empty fresh destination. Copying old metadata into a new run would introduce an unqualified mechanism and blur new transfer/custody claims. Any future reuse proposal would require separate justification and explicit authorization, retained original custody, revalidation of signatures, Release policy and every hash/size link, replay/checkpoint analysis, consistent complete index selection and explicit provenance distinguishing reused from newly transferred bytes. None exists or is authorized here. Do not implement reuse for this failure.

The remote cause and duration of the 504 remain unknown, and another fresh attempt may fail identically. Owner-origin assertions and provisional transport risks remain; all three independence flags stay false. The failed attempt supplies no usable completed bootstrap artifact. All task restrictions remain in force: no network access, retry, new acquisition, source modification, package installation, image build, container execution, gates, production change or commit. Assessment stops with this report.
