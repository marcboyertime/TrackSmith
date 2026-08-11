# LLM-first Tutor architecture

Status date: 2026-08-09

## Components

```text
SwiftUI transcript / composer / evidence chips / experiment card
        │
        ▼
TutorConversationSessionModel (owns one cancellable turn)
        │
        ├── narrow capture projection ── CompanionSessionModel
        │                                  └─ validated immutable AU WAV + local analysis
        ├── optional audio listener ─── OpenAI Chat Completions audio model
        ├── text provider ───────────── OpenAI Responses SSE
        └── no consent/key/network ───── deterministic General Tutor fallback
        │
        ▼
TutorConversationEngine actor
        ├── bounded transcript and one-turn exclusion
        ├── strict tool loop (at most 6 calls / 5 rounds)
        ├── experiments and explicit outcomes
        └── checksummed state + exclusive-create evidence receipts
                 │
                 └── TutorToolExecutor
                       ├─ reviewed production knowledge
                       ├─ reviewed Logic procedures
                       ├─ capture identity + local measurements
                       ├─ prior personal experiments
                       ├─ read-only visible Logic attributes
                       └─ presentation-only experiment card
```

`packages/ProductionTutor` remains the validated knowledge/procedure and offline
fallback foundation. The existing Create-specific `OpenAIResponsesProvider` remains
unchanged: it still produces strict Production Intelligence JSON with no tools.
Tutor uses a separate provider so chat/tool semantics cannot weaken Create's gates.

## Conversation provider

`OpenAITutorProvider` sends a bounded locally managed transcript to `/v1/responses`
with SSE streaming, `store:false`, strict function schemas, disabled parallel calls,
configured model/reasoning, token/body bounds, timeout, cancellation, and sanitized
failures. Local state is authoritative; provider-retained conversation state is not
required. Within one tool turn, the adapter replays every bounded Responses output
item—including stateless encrypted reasoning continuity—and appends tool outputs in
wire order, as required for reasoning-model function calls. Those opaque items exist
only in the active turn and never enter transcript state, receipts, or logs.

The default output/reasoning budget is 25,000 tokens with a 32,768 hard ceiling so
high-effort reasoning has room to produce visible output; the bound caps cost and
prevents unbounded responses.

The system instruction treats transcript, context, tool output, and retrieved text
as untrusted data. It explicitly denies every Logic/AU/file mutation capability and
requires evidence-honest Heard/Measured/Saw language.

## Tool authority

| Tool | Kind | Returns | Never returns or does |
|---|---|---|---|
| `get_current_capture_context` | read-only | immutable IDs, scope, metrics, limitations, listening status | paths, audio bytes, AU commands |
| `search_production_knowledge` | read-only | up to six reviewed claims/strategies/concepts with source IDs | unreviewed claims, arbitrary web content |
| `get_logic_procedure` | read-only | one validated Logic 12.3 procedure with stop/undo | invented paths, execution authority |
| `retrieve_prior_experiments` | read-only | up to ten local experiments/outcomes | generalization to other users |
| `inspect_logic` | read-only | visible label/value/role or honest unavailable state | window/project titles, screen coordinates, AX actions/setters, clicks, keystrokes, project DOM |
| `present_experiment` | presentation-only | one bounded advice card | any computer-side mutation |

The executor rejects every other tool name. It has no reference to the session
client that contains Create commit, bypass, rendering, or cache operations.

## Capture and listening

The AU snapshots dry input arriving at that exact insert before TrackSmith DSP. A
capture is not a whole-mix observation unless the insert is placed on that scope.
The Tutor projection includes capture/instance/runtime UUIDs, SHA-256, rate-derived
duration, explicit musician-selected source role, at most 16 descriptive metrics,
and limitations. It includes no relative path.

Local analysis is always labeled Measured. Optional model listening is isolated in
`OpenAITutorAudioListener` because the configured reasoning model does not accept
audio. The current default is the configurable `gpt-audio-1.5` Chat Completions
route. It requires:

1. independent persistent audio-consent toggle;
2. explicit per-turn Listen toggle;
3. exact live capture authority before and after the actor hop;
4. same-byte SHA-256 and WAV metadata validation;
5. 12 MiB product cap (24 MiB hard library ceiling);
6. an audio-capable model identifier and Keychain credential.

The result is bounded text linked to the capture ID. It cannot prescribe processing
or claim knowledge of Logic state, and the WAV is not copied into Tutor history.

## Persistence and receipts

`TutorConversationStore` applies hard ceilings of 240 messages and 120 experiments,
then evicts the oldest records as needed to remain inside the 1 MiB canonical state
body budget. Atomic, checksummed, owner-only snapshots apply credential-pattern
redaction before the in-memory transcript and evidence hash are finalized. User
feedback is stored as an explicit outcome and note; it does not become reviewed
general knowledge.

Every successful turn creates a separate owner-only receipt with POSIX
`O_CREAT|O_EXCL|O_NOFOLLOW`. The public API cannot overwrite an ID. The receipt
contains answer hash, capture ID/hash, evidence references, provider/model/usage,
tool name and argument/output hashes, and text/audio/Logic consent records. An
explicit Delete All Tutor History action removes both transcripts and receipts.

## Logic observer and Show Me

`TutorLogicObserver` uses only `AXUIElementCopyAttributeValue`. It traverses a
bounded number of visible nodes, ranks semantic query matches, and reports permission
denied, Logic absent, control absent, or unavailable without prompting. Permission
prompting is a separate explicit UI action. The companion overlay is borderless,
mouse-transparent, and non-activating; it marks one observed frame and never clicks
it. Textual reviewed directions remain the fallback.

Frames and window titles remain inside the local companion. The model-facing
`inspect_logic` projection omits both; `Show Me` resolves the frame again locally
from the experiment's semantic target.

The companion is directly distributed and intentionally not App-Sandboxed because
Apple documents assistive-app Accessibility APIs as forbidden inside App Sandbox.
This is a packaging requirement for the optional, user-authorized observer, not an
expansion of Tutor authority: the AU extension remains sandboxed, the companion keeps
its existing App Group identifier, and the observer module contains no AX setter,
action, input-event, Apple Event, or Audio Unit command API.

This is intentionally not screenshot understanding or stable project introspection.
It cannot prove hidden controls, routing, selected regions, plug-in order, or that a
musician made the suggested change.

## Offline behavior and failure containment

Missing consent, credentials, network, malformed events, timeouts, or provider
failure activate `OfflineTutorProvider`, which reuses the validated deterministic
General Tutor and discloses that it did not listen or inspect Logic. Cancellation
persists any partial assistant text as Cancelled. The engine permits one turn at a
time, bounds messages/tools/output, and never automatically retries a mutation—there
is no Tutor mutation to retry.
