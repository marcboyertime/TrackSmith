# AI agent design

## Authority model

The current build has a deterministic keyword/alias fallback plus provider-neutral
OpenAI Responses and Google Gemini Interactions adapters for free-form semantic
interpretation. The adapters are implemented and mocked-wire/failure tested; a
credential-backed frontier evidence run is still pending.
Deterministic tools own state and audio. No shipped model provider receives
arbitrary shell, filesystem, Logic host, plug-in host, or project-editing authority.
External text, names, tags, metadata, presets, model output, and reference labels
are untrusted data and never become instructions automatically.

## Planning sequence

Build bounded labeled context; ask the selected provider for a versioned semantic
contract; run decoding, schema, semantic, capability, state-reference and constraint
validation; reconstruct TrackSmith-owned goals and prohibitions; resolve typed
snapshot/preview/request/node references; verify source and analysis freshness;
propose competing hypotheses and variants; validate snapshot identity, locks,
32-node/32-goal/4-KiB rationale bounds and gain; render; measure; reject
constraint violations; explain survivors; wait for commit.

Context construction includes a separate 14-entry abstract musician-language
advisory catalog. It recognizes only reviewed exact phrases/aliases and supplies
source-scoped alternative senses, contradictions, non-DSP causes, risks, and an
ambiguity policy. Primary language research supports the role/scope separation;
the acoustic senses remain professional-practice heuristics. The catalog can seed
existing typed term/measurement retrieval but cannot emit nodes, parameters,
measurements, capabilities, host actions, or constraint changes.

The offline deterministic parser supports the checked-in production vocabulary. It rejects
contradictory loudness and requests for shell execution, deletion, or unapproved
upload. `MockModelProvider` exercises the same typed interface and remains the
no-network regression oracle; it is intentionally not represented as general
language understanding. Cloud output cannot invent new TrackSmith capabilities.

The implemented companion pipeline uses that parser locally: a recent AU capture is
analyzed, converted into conservative/balanced/strong validated plans, rendered and
level matched, checked for objective violations and pairwise collapse, then shown for
explicit commit. The AU receives only the chosen typed `ProcessingPlan`; it never
receives the free-form prompt or authority to call a model.

## State and action contracts

The broader target tool contract requires `request_id`, `session_id`,
`expected_snapshot_id`, a deadline, and an idempotency key. Success should return the
resulting snapshot/preview ID and audit event ID; failure is typed and does not change
current state. This full contract is not implemented at runtime yet.

The current AU exchange implements versioned message/request IDs, correlation IDs,
instance IDs, runtime epochs, captured-instance binding, 30-second command expiry,
and monotonic per-runtime command sequences.
Commit requests carry an explicit expected current plan and fail closed on mismatch.
The companion verifies the source hash/WAV descriptor, canonical materialized plan,
activation safety and a fresh measured render; the plug-in independently repeats the
artifact/current-plan/lock/activation checks before publication. Applied command and
plan IDs appear in heartbeat state before acknowledgement delivery, allowing a lost
reply to be reconciled without blind retry. Terminal replies are accepted only when
their kind, instance, runtime epoch and correlation match the original command;
transient writes are retried on the AU utility queue. Identical message-file retries
are collision-safe. A bounded `flock` serializes the mailbox, which is limited to
2,048 files/32 MiB and 512 instances, retains still-deliverable commands under
pressure, and fails closed when
full. Every unresponded command reserves bounded terminal-response space and has a
five-minute filesystem-age cap. Completed expired transactions remain at least 10
minutes, other diagnostics
24 hours, and stale instance files 10 minutes; the AU runs maintenance at a 60-second
cadence. Processed-command memory is intersected with visible files, so it is bounded
without forgetting a command that remains eligible for scanning. There is still no
durable cross-restart idempotency/audit ledger: retention removal also removes that
replay history. A terminal result proves validated graph publication, not render-
thread observation.

| Tool | Input core | Output core | Permission / idempotency |
|---|---|---|---|
| `get_session_state` | session ID | current IDs, locks, connection | read-only |
| `get_audio_analysis` | snapshot, analysis version | typed report | read-only; local by default |
| `create_snapshot` | expected parent, label | immutable snapshot | same key returns same ID |
| `list_processing_nodes` | snapshot | typed nodes | read-only |
| `add/update/remove/reorder/lock_processing_node` | expected snapshot plus bounded mutation | candidate snapshot | rejects stale/locked references |
| `render_preview` | candidate snapshot, source, variant | preview transaction | cancellable; cache by content hash |
| `measure_preview` | completed preview | typed report | rejects partial render |
| `compare_previews` | preview IDs, constraints | measured differences | read-only |
| `commit_preview` | preview ID, expected current snapshot | committed snapshot | requires explicit user approval |
| `revert_to_snapshot` | target and current IDs | committed target | explicit user action |
| `explain_change` | node/snapshot ID | facts and limitations | cannot alter state |
| `report_limitation` | capability and context | user-facing limitation | required when no safe tool exists |

## Provider abstraction

`ModelProvider` maps the same normalized request to a versioned semantic contract.
`MockModelProvider` is local; OpenAI Responses and Gemini Interactions are companion-
only text/measurement adapters. Their descriptors declare capabilities, network use,
exact model identity, and that raw audio is not accepted. Requests require explicit
consent and a when-unlocked, device-only Keychain credential; use an ephemeral
session, bounded timeout/output/attempts, retry off by default, and cancellation.
Credentials never enter requests, AU/App Group/document/conversation state, or logs.
All responses feed the same six-stage validator; offline recipes, saved-project AU
playback, and manual graph editing remain functional. See
[`PRODUCTION_INTELLIGENCE.md`](PRODUCTION_INTELLIGENCE.md).

## Conversational references

Provider language may identify a current snapshot, preview, prior request,
production attribute, processing node, or user lock, but the reference must resolve
against an explicit local ID registry. The implemented resolver can replace from an
exact preview/snapshot/request, merge supported attribute processing families,
preserve/lock/unlock/remove a node, or restore its prior version while retaining all
current locks. The candidate receives a new plan ID and re-enters plan/render/safety
validation. Arbitrary graph surgery and every possible pronoun are not supported.
Chat text alone is never mutation authority.

Conversation turns, typed interpretations, hypothesis summaries, snapshot ancestry,
preview/revision identities, locks and provider metadata persist in a bounded,
checksummed local store. After restart they are live only when the current AU
instance/runtime/capture/graph/conversation reconcile exactly; otherwise references
are historical and view-only.

## Self-evaluation

Metrics catch clipping, peak, phase, loudness-bias and explicit spectral/dynamic
guardrail mistakes. Adjacent level-matched strengths are compared pairwise and a
candidate below the collapse threshold is rejected rather than presented as a
meaningfully distinct option. The analysis report also carries bounded 200 ms RMS
and crest-factor timelines plus normalized positive spectral-flux timelines. These
measures do not establish subjective quality or event identity. A preview that cannot
be measured against a requested prohibition is labeled uncertain, not silently
accepted.

Research review requires five independent evaluation axes: instruction adherence,
intended target change, non-target preservation, acoustic naturalness, and temporal
coherence. Safety and locked constraints remain hard gates rather than terms in a
weighted quality score. Generic audio-language/CLAP similarity is not accepted as a
production-style or preservation metric without project-specific human calibration.

Future reference matching may use offline inference-time optimization over the
validated deterministic graph. The optimizer receives bounded parameters and a
cancellable render budget; it never selects arbitrary plug-ins, executes in the AU
callback, or commits without approval. See
[`RESEARCH_SYNTHESIS.md`](../research/analysis/RESEARCH_SYNTHESIS.md).
