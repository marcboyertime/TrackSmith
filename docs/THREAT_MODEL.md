# Threat model

## Assets

Unreleased audio, references, project identity/path, prompts, provider credentials,
processing state, Logic project integrity, speaker/listener safety, and DAW uptime.

## Trust boundaries and threats

| Boundary | Threat | Required control |
|---|---|---|
| model response → planner | prompt injection, extreme gain, invented measurements/nodes/actions, false authority | bounded decode; six ordered schema/semantic/capability/reference/constraint gates; local vocabulary reconstruction; no executable tools or raw DSP |
| asynchronous provider result → current session | result from old AU, capture, graph, conversation or turn applies after state changes | bind request/response to exact typed authority; re-read authority after inference; reject stale result before planning |
| audio metadata/name → prompt | malicious instructions disguised as metadata | context builder accepts no filenames or arbitrary imported metadata; typed evidence labels never become system authority |
| companion → AU | spoofed/stale/corrupt plan, mailbox exhaustion/replay | signed App Group; version/hash/instance/snapshot IDs; monotonic runtime sequence; strict terminal correlation; canonical names; descriptor reads; bounded `flock`; 2,048-file/32 MiB quota with reply reservation; TTL and hard-age retention; bounded visible-ID deduplication; fail-closed admission |
| render callback | blocking, allocation, crash, NaN, runaway gain, hostile host buffer/event shape | precompile/preallocate; separate pull/output scratch; channel/byte/frame validation; one graph per callback; 256-event bound; atomic publication; finite/ceiling guards; prior graph retained |
| provider/network | audio exfiltration, secret leakage, uncontrolled cost/retry, replay, retention | companion-only text/measurement adapters; no raw audio/path types; explicit consent; when-unlocked device-only Keychain; ephemeral TLS session; bounded timeout/output/attempts; retry off by default; cancellation; response-ID replay guard; sanitized failures; local fallback; provider disclosure |
| provider envelope metadata → evidence/state | resolved model or response identity injects controls, impersonates configured authority, or supplies negative/unbounded usage | configured alias remains local validation authority; provider-reported identity is separate evidence; visible-ASCII/byte bounds; nonnegative bounded token counts; latency/attempt budget validation; complete accepted-stage audit |
| persisted conversation | secret leakage, corrupt or stale identities controlling another insert, unbounded disk | credential-pattern redaction; checksum/version/size/count bounds; 0600 atomic writes; bounded content-addressed history; quarantine/migration; exact live-AU reconciliation or historical-only references |
| model download/cache | substitution or path traversal | signed manifest/hash, fixed cache root, safe extraction, quarantine and version pinning |
| tutor provider proposal → lesson | invented control/menu path/value/key command, invented procedure or issue ID, claim that an action occurred or Logic state was observed, prose bypassing the local lesson validator | staged tutor proposal validator (decoding/schema/semantic/capability/knowledgeReference/stateReference/instructionConstraint); forbidden-key and claimed-action scans; only canonical local IDs survive; exact steps materialize solely from the reviewed catalog |
| tutor knowledge catalog | destructive instruction, coordinates, key commands, missing rollback/stop rule, false execution authority, out-of-range value, unregistered processor identity | Python audit on the reviewed artifact plus fail-closed runtime `TutorKnowledgeValidator` on the SHA-256-verified generated payload |
| tutor lesson → user | stale-capture diagnosis presented as live, misleading certainty, metric presented as proof of a subjective quality, loudness-biased comparison | explicit evidence mode with historical demotion on authority mismatch; forbidden-claim scan on every user-visible string; every comparison step carries a level-match reminder; hypotheses stay plural with visible uncertainty |
| tutor persistence | secret leakage, corrupt state, unbounded growth, raw provider retention | credential-pattern redaction, checksummed atomic 0600 files, size/count bounds, quarantine, version rejection; raw audio/paths/provider responses excluded by type |
| Accessibility/MIDI → Logic | wrong selection, unintended project mutation | feature flag; permission; pre/postcondition verification; transaction stop/recovery; user approval |
| diagnostic export | unreleased audio/path/prompt leakage | preview and redact by default; never include audio without separate opt-in |
| cache/state | other app access, tamper, disk growth | App Group/SIP boundary, integrity hashes, message/instance quotas, 10-minute completed/24-hour diagnostic/10-minute stale-instance retention, implemented delete-all-audio control; automatic audio-cache expiry remains open |

## Safety behavior

Invalid plans never replace committed audio. IPC/provider/preview failure leaves the
prior graph active. Experimental project action failure stops the sequence; no
follow-on clicks occur. The system never overwrites the sole source. Output must be
bounded and a production fault counter must trigger safe bypass after repeated DSP
faults. Availability attacks must not move AI/network/database work onto render.
Mailbox maintenance never evicts a still-deliverable command merely to admit newer
work; a five-minute file-age cap prevents a forged far-future expiry from retaining
one forever. Every command reserves terminal-response capacity. When retained state
still fills a quota, the sender receives a typed full-mailbox failure.
Protocol retention is not a permanent audit trail, so removal after the documented
window also removes cross-restart replay evidence.

Provider output can describe semantics but cannot perform a state transition. A
missing/inaccessible/rejected credential, missing consent, network loss, timeout,
cancellation, malformed/oversized output, duplicate response, invented reference,
or stale authority produces a typed failure while the committed AU graph continues
unchanged. Automatic retry is disabled unless explicitly configured and is bounded
to two total attempts. `store=false` is requested but is not treated as proof of
zero provider-side retention.

The model identity returned by a provider is not accepted as capability authority.
It is retained separately from the locally configured adapter alias so a legitimate
dated resolution can be audited without either causing a false rejection or allowing
provider-returned metadata to select a different model contract.

Host reset discards in-flight scheduled output-gain automation, while bypass retains
and advances it invisibly; this prevents a bypass toggle from replaying a one-shot
event or a transport discontinuity from retaining a stale ramp. Null output buffers,
upstream pull-pointer replacement, undersized byte counts, and excessive frame/event
counts are handled through preallocated scratch and bounded validation. Upstream
silence is materialized as zero input, and the outgoing silence hint is cleared
conservatively because a stateful IIR tail may remain.

## Out of scope but tracked

Formal third-party DSP audit, sandbox penetration testing, notarization pipeline,
signed-app Keychain access/revocation UI testing, credential-backed provider
penetration/adversarial evaluation, cloud-provider contractual review, and supply-
chain SBOM/signing are required before external beta.
