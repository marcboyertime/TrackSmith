# TrackSmith Production Intelligence v1

Status date: 2026-07-30
Contract version: `1.0`

The current milestone prioritizes the credential-backed, provider-neutral OpenAI
and Gemini lanes. The no-key/on-device amendment remains historical compatibility
documentation and is not the active completion gate. Credentials are read from
TrackSmith's Keychain; no credential values are stored in the repository or
evidence artifacts.

## Proof boundary

TrackSmith has a provider-neutral, typed Production Intelligence layer with
credential-backed live evidence for both cloud adapters. The deterministic offline
provider remains the no-network fallback and regression oracle. The live
cross-provider report covers six free-form source-aware cases per provider, and the
Gemini cloud-30 report covers five cases per source class. These reports prove the
provider-to-typed-contract-to-deterministic-preview path; they do not claim that
objective metrics establish artistic superiority.

The direct Logic Pro 12.3 frontier session is now recorded as passed for its
exercised workflow: credential-backed free-form request, natural revision,
capture-bound commit, save/reload, provider-offline playback, lock preservation,
instance isolation, and source-byte preservation. Historical Logic evidence
remains unchanged. This closes the declared Production Intelligence v1 scope;
the separate Production Mastery v1 milestone now owns the open Logic-profile,
DSP, perceptual, and installed-host gates.

## Authority architecture

```text
free-form musician request
  -> companion-only provider adapter (untrusted semantics)
  -> ModelIntentContract v1
  -> decoding + schema + semantic + capability + reference + constraint gates
  -> TrackSmith-owned vocabulary and source-aware evidence
  -> competing ProductionHypothesis values
  -> bounded deterministic ProcessingPlan candidates
  -> PlanValidator
  -> local offline render, constraint measurement and level matching
  -> user selection/revision
  -> capture-bound App Group commit
  -> AU validates, compiles and atomically publishes the deterministic graph
```

The model is never an audio-execution authority. It receives no tool definitions,
shell, filesystem, Logic project, Audio Unit, or arbitrary-network capability. It
does not emit raw DSP parameters or executable actions. The real-time Audio Unit
has no dependency on this package, no credential access, and no provider network
path. A provider failure cannot alter the committed graph or prevent saved-project
playback.

## Provider boundary

All providers implement the same `ModelProvider` interface and declare a
`ModelProviderDescriptor`: stable adapter identity, displayed provider, exact model
identifier, capability set, network use, and whether raw audio is accepted.

| Adapter | Default model | Current status | Data path |
|---|---|---|---|
| `MockModelProvider` | `deterministic-intent-v1` | Implemented; Debug/Release/TSan regression oracle | Local only; bounded legacy vocabulary parser |
| `OpenAIResponsesProvider` | `gpt-5.6-sol` | Implemented; live six-case cross-provider evidence passed on 2026-07-22; failure and privacy matrix pass | Companion sends labeled text/JSON context to `POST /v1/responses` |
| `GeminiInteractionsProvider` | `gemini-3.6-flash` | Implemented; live six-case cross-provider and 30-case cloud evidence passed on 2026-07-22; failure and privacy matrix pass | Companion sends labeled text/JSON context to `POST /v1beta/interactions` |
| Offline/no provider | n/a | Implemented | Existing deterministic capture, analysis, preview, manual edit and AU playback continue without network |

The OpenAI request shape and selected model were rechecked on 2026-07-22 against the
current official model guidance, Responses reference, and Structured Outputs guide;
`gpt-5.6-sol`, `text.format` JSON Schema output, `store:false`, and bounded
`max_output_tokens` remain documented. The provider references are:
[OpenAI Responses create reference](https://developers.openai.com/api/reference/resources/responses/methods/create),
[OpenAI Structured Outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs),
[OpenAI current model guidance](https://developers.openai.com/api/docs/guides/latest-model),
[Gemini Interactions reference](https://ai.google.dev/api/interactions-api-v1), and
[May 2026 Gemini Interactions migration](https://ai.google.dev/gemini-api/docs/interactions-breaking-changes-may-2026).
Provider/model identifiers are recorded with every accepted result; no permanent
"best model" is hard-coded into downstream semantics.

`ProviderExecutionMetadata` deliberately distinguishes the configured model alias
from the model identity reported by the authenticated provider envelope. Only the
configured alias bound to the selected adapter participates in capability validation;
the reported identity is bounded visible-ASCII evidence and may name a dated or
resolved snapshot. The provider response ID, token counts, attempts and latency are
also bounded before persistence. This avoids both rejecting a legitimate alias
resolution and granting authority to provider-returned metadata.

### Cost, timeout, cancellation, and retries

`ProviderRequestBudget` defaults to 48,000 UTF-8 context bytes, 2,500 output
tokens, one attempt, and 25 seconds. Local enforcement caps output at 8,192 tokens,
attempts at two, and timeout at 60 seconds. Automatic retry is off by default.
When explicitly enabled, only rate-limit and server failures may consume one extra
attempt, with a local two-second delay ceiling. The adapters never silently launch
background work (`background=false` where the API exposes it), and local task
cancellation produces a typed cancellation failure.

### Credentials and consent

- The signed companion stores provider credentials in macOS Keychain service
  `com.marcboyer.tracksmith.provider-credentials`, with provider-specific accounts
  and `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Credentials are absent from request bodies, prompts, App Group messages, AU
  state, Logic project state, conversation state, and diagnostic-safe errors.
- A Keychain failure becomes `credentialStoreUnavailable`; platform status and
  underlying error text do not escape into provider evaluation or UI state.
- Selecting a cloud provider is insufficient: the request also requires explicit
  cloud-reasoning consent. Missing consent or credentials fail before networking.
- Networking uses an ephemeral `URLSession` with no URL cache, cookie store,
  connectivity waiting, or shared provider session state.
- `store=false` is requested from both providers. This limits provider application
  state but is not evidence of zero provider-side safety or abuse retention; the
  product must not make that stronger claim.

No current adapter accepts raw audio. Captured samples, rendered previews, source
paths, file names, project names, App Group paths, and AU state blobs are excluded
from the provider input type. Future audio-capable reasoning requires a separate
interface, consent, disclosure, and evidence lane.

### Repeatable provider evidence command

`ProductionIntelligenceEvaluation` now runs either the deterministic provider or one
bounded cloud case through the same context, six validation gates, hypothesis engine,
offline rendering, preview safety, and source-preservation path. Cloud invocation
requires `--provider openai|gemini`, `--cloud-consent`, and exactly one `--case`;
automatic retry is disabled and credentials are read only from the TrackSmith Keychain
service. No command-line or environment credential path exists. Evidence schema 1.1
retains provider/model/response/usage metadata and validation stages without retaining
secrets, request headers, raw response envelopes, or hidden reasoning. Missing consent
fails before creating an evidence directory; a missing credential produces a typed,
nonzero `credential_missing` run without networking.

Always launch this executable through the stable-signing runner:

```sh
./scripts/run-production-intelligence-evaluation.sh \
  --provider openai \
  --cloud-consent \
  --case VOC-FRONTIER-01 \
  --output .build/evidence/production-intelligence-openai-voc-frontier01-YYYY-MM-DD
```

The macOS Keychain authorization is attached to a caller's signed code
requirement, not merely its path or process name. Directly running the raw
SwiftPM product after a rebuild gives it a changing ad-hoc identity and can
therefore cause repeated authorization prompts. OpenAI and Gemini are separate
Keychain items, so the stable evaluator may still require one authorization for
each item on its first access.

## Typed model contract and six validation gates

`ModelIntentContract` contains only bounded semantic data:

- explicit source type;
- desired, preserved, and prohibited production attributes with direction,
  strength, confidence, and a non-authoritative interpretation;
- uncertainty, ambiguities, clarification need/question, explicit assumptions,
  and optional temporal scope;
- typed references to previews, snapshots, prior requests, production attributes,
  and processing nodes plus a bounded merge behavior;
- bounded production-hypothesis proposals using allow-listed strategy categories
  and existing metric identifiers.

Every response passes, in order:

1. **Decoding** — provider envelope and contract JSON decode within 128,000 bytes.
2. **Schema** — version, request identity, complete authority identity, provider and
   model identity, source class, budgets, and array bounds match the request.
3. **Semantic** — directions, strengths, confidences, text, applicability, and
   temporal scope are valid; an actionless response must request clarification.
4. **Capability** — the adapter declared every used capability; strategies are
   allow-listed and measurements actually exist in the current analysis.
5. **State reference** — UUIDs resolve in the explicit request registry; locked
   nodes cannot be replaced/removed/reverted; unlock must be explicit user text.
6. **Constraint** — no attribute is simultaneously changed and preserved or
   prohibited, no contradictory increase/decrease is accepted, and clarification
   and unlock behavior is internally consistent.

The validator then reconstructs trusted TrackSmith interpretations from the local
vocabulary. Provider prose is not converted to DSP. The implementation currently
performs no model-driven repair loop; rejected output fails closed and is auditable
by validation stage.

## Deterministic grounding and context construction

`DeterministicContextBuilder` admits only typed local inputs and never filenames,
arbitrary imported metadata, raw audio, secrets, or an unbounded chat transcript.
It selects at most 32 sections, 12 source-aware metrics, 10 vocabulary terms, and
eight prior revision summaries. It also selects at most four entries from the
142-entry reviewed Logic effects/pedals catalog, two from the separate 28-entry
instrument catalog, two from the 30-entry editor-tool catalog, and three from the
14-entry abstract musician-language catalog. Instrument advice is admitted only
when the request explicitly
names an instrument or reviewed alias; recorded audio never establishes its generating
instrument. Editor-tool advice requires explicit constructions such as “Scissors
tool” or “use the Scissors”; ordinary words such as *gain*, *move*, or *volume*
do not imply a host edit. Explicit instrument/tool identity outranks generic
semantic/effect background during bounded pruning. Mandatory request, scope,
evidence, capability, and limitation sections remain preserved.

The abstract-language catalog is intentionally not another executable vocabulary.
It recognizes only reviewed exact phrases/aliases such as *expensive*,
*bedroom-recorded*, *emotionally boring*, *three-dimensional*, or *blurry*, then
supplies source-scoped alternate senses, contradictions, non-DSP causes,
preservation risks, and clarification/multiple-hypothesis policy. Primary research
supports the role/scope/ambiguity architecture; the proposed production senses are
still labeled `PROFESSIONAL_PRACTICE_HEURISTIC`. These sections expose explicit
false authority fields and contain no DSP node, parameter map, measurement, host
action, or constraint override. Candidate canonical terms may improve bounded
metric retrieval, but provider output still has to pass all six local validation
gates before influencing a hypothesis.

For effects, a generated 20-identity core-production rank acts only as a
semantic-match tie-breaker. It is derived from role recurrence in 58 curated cases,
not global Logic usage telemetry and not a fixed processing order; that boundary is
included in the typed model context beside any core rank. Explicit names/aliases
still dominate. Typed source words and ordinary stopwords are excluded from
single-token effect-identity matching, preventing phrases such as “this guitar”
from becoming an implicit Guitar Amp/Pedalboard request or “the” from selecting
*The Vibe*. Evidence-specific repair/delivery tools are additionally gated by
their production concept: broad words such as *airy*, *controlled*, or *polished*
cannot implicitly select de-essing, gating, pitch correction, limiting, or a
loudness meter without sibilance/noise/pitch/peak-delivery language. Explicit
reviewed names and aliases remain available.

Every section is labeled as one of:

`USER_REQUEST`, `MEASURED_EVIDENCE`, `DERIVED_INTERPRETATION`,
`RESEARCH_BACKED_KNOWLEDGE`, `PROFESSIONAL_PRACTICE_HEURISTIC`,
`PRODUCT_HEURISTIC`, `CURRENT_STATE`, `AVAILABLE_CAPABILITY`, or
`KNOWN_LIMITATION`.

The current source class is explicit, not model-inferred from a Logic project.
Available metrics include confidence, units, valid conditions, windowing,
aggregation, and failure modes. Implemented and unsupported DSP/host capabilities
are separate context sections. Tests prove malicious/irrelevant metadata and file
names are not admitted and provider output cannot invent a measurement or override
state authority.

## Hypotheses, candidates, and user control

For each accepted nontrivial intent, TrackSmith constructs one or more typed
`ProductionHypothesis` values. These retain the intended perceptual change,
supporting and contradictory measured evidence, source context, considered and
selected strategy, preservation constraints, risks, uncertainty, provenance class,
expected measurable direction, and whether listening remains decisive.

Candidate graphs are local deterministic products. Three accepted previews must
retain hypothesis and candidate identities, survive `PlanValidator`, render
offline, remain finite and below safety bounds, satisfy measurable preservation
constraints, be level-matched, and avoid pairwise sibling collapse. Objective
checks can reject unsafe or irrelevant candidates; they do not prove artistic
superiority.

The companion presents the accepted structured rationale directly: desired,
preserved and prohibited attributes; hypothesis outcome/strategy/risk; relevant
measured metric identifiers with values, units, confidence and relationship; both
model identities, response/usage metadata; and the completed validation gates. It
does not display or request hidden chain-of-thought.

## Conversational identities and durable state

Conversation prose is never state authority. Requests carry an exact tuple of AU
instance, runtime epoch, capture snapshot, current plan, conversation, and turn
identity. A result is discarded if that tuple changes during inference.

The versioned local store persists bounded conversation turns, typed
interpretations, hypothesis summaries, preview identities and plans, snapshot
ancestry, revisions, lock history, and provider/model metadata. Limits are 200
turns, 120 snapshots, 120 previews, 240 revisions, 500 lock events, a 4 MiB envelope,
and 20 content-addressed history files. Writes are atomic, directories/files are
0700/0600, payloads are checksummed, credential-like strings are redacted, corrupt
state is quarantined, and direct `0.9` state has an explicit migration to envelope
`1.0`.

On restore, historical state becomes live-authoritative only when instance,
runtime, capture, committed plan, and conversation identities match the discovered
AU and current graph. Otherwise it remains view-only with an empty live reference
registry. This prevents a stale conversation from commanding a different insert.

Each accepted provider turn also persists the exact completed six-stage validation
audit, configured model alias, provider-reported model identity, response ID,
attempts, latency and bounded usage metadata. These fields make a live evidence run
auditable after restart without retaining credentials, headers or hidden reasoning.

Typed revisions support exact preview/snapshot/request replacement, attribute-level
preview merges for supported processing families, explicit node preserve/lock,
explicit unlock, remove, and prior-node restore. Every resolution preserves current
locked nodes, remains capture-bound, receives a new plan identity, and re-enters
ordinary plan/render/safety gates before commit.

## Evidence

- `TestRunner`: the frozen Production Intelligence v1 closure passed 68/68 in
  Debug, Release, and Thread Sanitizer with the selected official BS.2217-2
  vectors; that dated closure is historical. The frozen pre-Vocal repository
  baseline at commit `406b446` declares 91 ordinary checks plus one optional
  official-vector lane. Its 2026-08-08 Debug and Release ordinary runs pass
  91/91; an isolated Release/Thread Sanitizer run with the 14 local vectors
  passes 92/92 with no sanitizer report. The 2026-08-02 72/72 ordinary and
  73/73 vector-enabled results remain dated evidence for that earlier harness.
- Provider tests: OpenAI/Gemini request shape, no tools/audio/file names/credentials,
  strict output, consent, missing/inaccessible/rejected credential, timeout,
  cancellation, network loss, malformed/oversized response, rate limit, bounded
  retry/no-retry cost behavior, duplicate response, and stale AU/capture result.
- Live frontier-provider evidence: OpenAI `gpt-5.6-sol` and Gemini
  `gemini-3.6-flash` each completed six free-form source-aware cases across vocal,
  drums, bass, guitar, synth/keys, and full stereo mix. Gemini additionally
  completed 30/30 cloud-assisted cases (five per source class). Every accepted
  case passed typed validation, deterministic planning, three valid previews, and
  source-byte preservation. See
  [`production-intelligence-frontier-cross-provider-2026-07-22`](../research/evaluation/production-intelligence-frontier-cross-provider-2026-07-22/README.md)
  and
  [`production-intelligence-gemini-3-6-flash-cloud30-2026-07-22`](../research/evaluation/production-intelligence-gemini-3-6-flash-cloud30-2026-07-22/README.md).
- Semantic/adversarial corpus: 420 generated structured cases across six sources,
  including ambiguity, contradiction, preservation, unsupported/source-inappropriate
  requests, multi-turn references, prompt injection, and malformed provider output.
- Generated-audio evaluation: 30/30 cases and 90/90 valid, pairwise-distinct,
  source-preserving previews using `mock-offline-1`; see
  [`PRODUCTION_INTELLIGENCE_GENERATED_AUDIO_2026-07-14.md`](evidence/PRODUCTION_INTELLIGENCE_GENERATED_AUDIO_2026-07-14.md).
- Direct Logic frontier evidence: Logic Pro 12.3 completed a free-form Gemini turn,
  source-aware evidence and competing hypotheses, three distinct bounded-loudness-
  match previews, natural preview/node revision, lock preservation, capture-bound
  commit, bypass/restore, save/reload, provider-offline graph restoration,
  multiple-instance isolation, and unchanged source bytes. See
  [`LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md`](evidence/LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md).
- Closing native/AU regression: vector-backed 68/68 Debug/Release/TSan,
  Debug/Release/TSan host probes, native Xcode build, zero observed callback heap
  operations, strict installed signatures, `auval`, knowledge/corpus audits, and a
  criterion-by-criterion milestone review are recorded in
  [`PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md`](evidence/PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md).

The milestone proof is complete for the declared v1 scope. The strong direct-Logic
preview disclosed a safety-limited loudness match rather than silently exceeding
the plan's gain bound, and neither that workflow nor the larger evaluation suite
claims objective artistic superiority.

## Supported and unsupported request boundary

The cloud-assisted semantic path may interpret free-form language, ambiguity,
preservation/prohibition, references, and hypothesis categories for the six explicit
source classes. TrackSmith can execute only its current deterministic node allowlist.
It cannot infer arbitrary multitrack context, inspect/edit Logic regions or channel
strips, insert third-party plug-ins, perform source separation or generative
replacement, upload raw audio, or promise exact named-style replication. Supported
parts may proceed while unsupported parts are disclosed; the model must never
hallucinate completion.
