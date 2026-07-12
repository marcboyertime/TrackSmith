# AI agent design

## Authority model

AI interprets requests; deterministic tools own state and audio. No shipped model
provider receives arbitrary shell, filesystem, Logic host, plug-in host, or project-
editing authority. External text, names, tags, metadata, presets, model output, and
reference labels are untrusted data and never become instructions automatically.

## Planning sequence

Parse goals and prohibitions; resolve structured snapshot/node references; verify
source and analysis freshness; request missing local analysis; propose variants;
validate schema, snapshot identity, locks, bounds and gain; render; measure; reject
constraint violations; explain survivors; wait for commit.

The current deterministic parser supports clarity, warmth, control, punch,
harshness/cymbal constraints, sibilance, mud/boxiness and width keywords. It rejects
contradictory loudness and requests for shell execution, deletion, or unapproved
upload. The mock provider exercises the same interface. It is intentionally not
represented as general language understanding.

## Planned tool contracts

Each tool request includes `request_id`, `session_id`, `expected_snapshot_id`, a
deadline, and an idempotency key. Success returns the resulting snapshot/preview ID
and audit event ID; failure is typed and does not change current state.

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

`ModelProvider` currently maps prompt/source to typed goals asynchronously;
`MockModelProvider` is local. Production adapters will declare text/audio disclosure,
network need, timeout, retention policy, model/version, and cancellation behavior.
Credentials live in Keychain and never enter AU document state. All providers feed
the same validator; offline recipes and manual graph editing remain functional.

## Conversational references

Pronouns are resolved against structured objects: current snapshot, last proposed
preview, explicit variant IDs, node types/IDs, and user locks. “Undo only the new
compression” removes only unlocked compressor nodes introduced by the referenced
transaction. “Version two's EQ with version one's compression” will construct a new
snapshot from referenced node IDs; chat text is not sufficient evidence by itself.

## Self-evaluation

Metrics catch clipping, peak, phase, loudness-bias and explicit spectral/dynamic
guardrail mistakes. They do not establish subjective quality. A preview that cannot
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
