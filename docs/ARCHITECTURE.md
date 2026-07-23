# Architecture

## Decision summary

The production core is an AUv3 effect plus a native companion app. A linear,
versioned graph is shared by real-time and offline renderers. Logic control is a
separate capability-gated adapter. AUv2 is not the starting point: Apple describes
AUv2 as maintenance mode and recommends AUv3 for new development.

```text
Logic Pro host process                 Companion app process
┌───────────────────────────┐          ┌─────────────────────────────┐
│ AUv3 extension            │          │ Conversation / waveform     │
│ ┌───────────────────────┐ │ signed   │ local waveform / audition   │
│ │ RT: atomic graph ptr  │ │ App      │                             │
│ │ + bounded ring writer │◄├─────────►│ planner + preview service   │
│ └──────────┬────────────┘ │ Group    │ session state + providers   │
│ non-RT: snapshot reader   │          └─────────────┬───────────────┘
└────────────┼──────────────┘                        │ optional
             │ audio passing through insert          ▼
             │                           ┌─────────────────────────────┐
             └──────────────────────────►│ Logic adapter               │
                                         │ MIDI stable-ish / AX exp.  │
                                         └─────────────────────────────┘

Offline tools use the same PlanSchema + DSPCore + AudioAnalysis modules.
```

The native companion is now a functional session slice. It discovers active AU
instances, requests recent dry-input capture, displays the waveform, performs local
analysis/planning/rendering, and runs the original plus valid variants simultaneously
through one `AVAudioEngine`; gain selection makes A/B changes without losing sample
position. Its cards expose parameters, rationale, category, and confidence before a
complete graph is committed or reverted. The package-built `AuditionApp` remains a
useful standalone folder-based tester using the same audition engine.

The research-grounded interpretation path is deliberately outside the render
thread and between language and plan parameters:

```text
free-form user request
  -> provider-neutral semantic interpretation (untrusted; offline fallback available)
  -> six local contract-validation gates
  -> typed intent + preservation/prohibited-change contract
  -> explicit source context
  -> source-aware evidence with validity/confidence/failure modes
  -> one or more production hypotheses with contrary evidence and uncertainty
  -> bounded deterministic DSP plans
  -> PlanValidator + render/measurement guardrails + human listening
```

Logic-native documentary knowledge is a separate advisory input to this path. The
four immutable Logic 12.3 manuals have complete 2,686-page review coverage; 16
canonical Quick Sampler web sections close the chapter omitted from the Instruments
PDF, and a dated immutable hash pins the mutable 12.3 release-notes payload. Bounded
runtime catalogs contain 142 effects/tools, 28 instruments/utilities, and 30 editor
tools, but no entry becomes an executable node or host command. Retrieval may explain
an effect, instrument, workflow, or control-surface mapping and its risks; only an
implemented `ProcessingNode` can enter a TrackSmith graph, and only a separately
proven capability adapter can request host state. A deterministic 18-fixture suite
and 200-identity campaign ledger define the empirical lane. Direct runs are
versioned, artifact-hash-audited records; generated provider context exposes only
their bounded status, run IDs, and claim-limited summary. The current campaign is
197 `not_run`, three `partial` runs (Bitcrusher Default Preset, Channel EQ
default/bypass plus one 1 kHz bell state, and Compressor default/bypass plus one
controlled static curve), and zero `complete`.
Even the partial entry keeps exact implementation internals false and retains the
advisory-only execution boundary. Undocumented transfer behavior and perceptual
preference remain measurement/listening questions.

`SourceAwareAnalyzer` supports vocal, drums/drum bus, bass, guitar, synth/keys,
and full stereo mix. `ProductionIntentVocabulary` stores all 28 requested production
descriptors plus four explicit preservation concepts, with aliases, evidence class,
context dependence, candidate strategies, risks, failure cases, and source provenance.
`AbstractMusicianLanguageKnowledgeCatalog` remains a separate advisory layer for
14 common nonliteral phrases so alternate source-conditioned meanings and non-DSP
causes do not become executable enum values or presets.
`ProductionHypothesisEngine` owns the typed intermediate
objects and can only emit plans that pass the existing realtime validator. No
model is connected directly to raw DSP parameters, and no individual descriptor
is promoted to a perceptual adjective. The detailed provider, context, validation,
credential and persistent-conversation architecture is authoritative in
[`PRODUCTION_INTELLIGENCE.md`](PRODUCTION_INTELLIGENCE.md).

## Process and trust boundaries

- The AU extension receives only its buses and host-supplied callbacks. It does not
  receive a Logic project object model.
- The companion owns network/provider access, secrets, disk cache, UI, and heavy
  analysis. No provider is trusted to produce executable actions.
- The containing app and AU extension carry the same signed App Group entitlement
  and have resolved the same container. `FileExchange` publishes versioned JSON and
  WAV artifacts with temporary-file-plus-rename atomicity, 0700 directories, 0600
  files, bounded sizes, path containment, captured-instance binding, SHA-256
  verification, and sample-rate/channel/frame metadata matching. Regular-file reads
  use `O_NOFOLLOW` and descriptor validation; canonical filenames bind a payload to
  its UUID. One advisory, bounded-acquisition `flock` serializes publication and
  maintenance across companion/AU processes.
  The default protocol quotas are 2,048 message entries/32 MiB aggregate and 512
  instance entries. A send runs retention maintenance before admission and fails
  with `mailboxFull` if the limits still cannot safely admit it; quota pressure
  never authorizes eviction of an unexpired command. Each unresponded command
  reserves a bounded terminal-response slot and expires by both its 60-second
  protocol TTL and a five-minute filesystem-age cap.
- The AU-owned `PluginSessionBridge` polls on a utility queue, publishes a heartbeat
  every second, and performs capture snapshots, WAV writing, plan validation, and
  graph compilation outside the render callback. Instance activity is filtered to
  heartbeats newer than five seconds. Commands name the instance and runtime epoch,
  carry a monotonic per-runtime sequence, and expire after a deadline. Terminal
  replies are correlated by command kind, instance and runtime; the bridge retries
  an in-memory terminal response on its utility queue. It runs maintenance at most once per
  60 seconds. Its processed-command ID set is intersected with the currently visible
  mailbox on each scan, so the file quota bounds deduplication memory without
  forgetting any command that could still be rescanned.
- Accessibility and control-surface actions are separate transactions with explicit
  preconditions and postcondition verification. They never mutate the DSP core.
- Research sources cross a separate ingestion boundary. `ResearchIngestion`
  validates exact HTTP completion, declared/observed media type, length, minimum
  quality, PDF structure/text, HTML-shell indicators, immutable SHA-256 identity,
  duplicates, Git cleanliness/origin/commit, and rights/local-use metadata before
  creating a content-addressed object. Invalid bytes go to quarantine, accepted
  history is append-only, changed payloads require an explicit new version or named
  canonical supersession, and user-supplied artifacts are never overwritten.
  Passing ingestion proves file/provenance mechanics, not scientific validity.

## Render-thread contract

The render callback may read atomically published scalar parameters, pull audio,
process a precompiled graph in preallocated storage, and copy bounded samples to a
preallocated ring. It must not allocate, lock, log, access files, call a model,
perform IPC, or touch UI. Plan compilation, ring snapshots, FFT/DFT analysis,
preview rendering, serialization, and graph swaps are non-real-time work.

`CompiledGraph.processRealtime` binds directly to borrowed noninterleaved Float32
host pointers; it never constructs the Swift-array `AudioBuffer`. The same graph is
tested for sample parity offline and across irregular host block boundaries. The AU
prepares graph state, format-specific atomic capture storage, and separate input/
null-output scratch before rendering. Every callback resets the pull ABL because an
upstream unit may replace its `mData` pointers. Pulled input is then copied into the
original size-validated host output or preallocated owned output when the host
supplies null `mData`; malformed channel counts, byte sizes, sample rates, or frame
counts fail without out-of-bounds access.
Mutable mono/stereo DSP state uses fixed scalar fields, avoiding Swift Array
copy-on-write allocation in the callback. Lifecycle operations and non-render status
snapshots share a lock; the render callback never takes it.

A complete replacement graph is validated, compiled, and retained off render, then
published with one release-store of a stable pointer. A callback acquires either the
old complete graph or the new complete graph. Retired graph boxes remain retained
until render resources are deallocated so ARC cannot destroy DSP state on the audio
thread. A per-graph activation generation resets state before a previously retained
graph is made active again. This deliberately caps one allocation lifecycle at 128
publications. The callback acquires the graph pointer/reset state once and processes
that graph exactly once for the entire block, so a concurrent publication can take
effect only on a later callback. Post-graph output gain consumes at most 256 AU
parameter/immediate-ramp events per callback at sample offsets; ramp state persists
across callbacks. Programmatic parameter writes cancel scheduled ownership and
continue from the instantaneous value through the 10 ms de-zipper. General graph-
node automation and a click-free old/new graph crossfade remain open. Source
inspection and custom-host tests find no explicit allocation, blocking lock,
file/network/database/log/UI work, or unbounded loop in the callback. Swift ARC/libm
behavior is also exercised by a thread-local development interposer: 4,000 complete
representative callbacks performed zero standard, aligned, or macOS zone heap
operations. The interposer runs in the custom host rather than Logic, so the stronger
claim “formally malloc-free under every host/runtime path” is not made.

Host `reset()` and bypass are deliberately different. A host reset marks graph DSP
history and in-flight scheduled output-gain automation for reset at the next block
boundary. A bypass transition resets graph history but preserves and advances the
host automation timeline invisibly while dry audio passes, so un-bypass does not
replay a stale one-shot ramp. Upstream `OutputIsSilence` means zero pulled input; the
AU explicitly zeroes that input, processes any IIR tail, and conservatively clears
the output-silence hint because the effect may still emit finite audio. `tailTime`
is a static 60-second conservative bound: hosts may cache it, and live graph commits
can activate the longest supported low-frequency/high-Q IIR after instantiation.

## State flow

```text
request → untrusted interpretation → six validation gates
        → goals/prohibitions → current analysis → competing hypotheses/plans
        → validation → offline render → measurements/guardrails
        → preview snapshot → user commit → off-render compilation
        → atomic complete-graph publication for the next callback
```

Portable snapshots are immutable and parent-linked. The live companion binds every
commit to an immutable capture, originating instance/runtime epoch, source hash/WAV
metadata, and the exact current plan it expects. Before IPC publication it freshly
renders and measures the canonical materialized graph; the plug-in repeats artifact,
lock and activation checks before entering the AU transaction. The AU then holds one
lifecycle lock while it verifies render resources are allocated, captured sample
snapshot identity and rate/channels still match the plan and both buses, compares
the exact expected graph, revalidates locked nodes, publishes the compiled graph,
and advances serialized plan state. Host deallocation and `fullState` restoration
cannot interleave with that sequence. The HostProbe proves a wrong snapshot, stale
expected graph, changed rate and deallocated resources all reject without changing
live output or serialized state. This is a plan-level compare-and-swap, not a
persistent cross-restart snapshot transaction.

After applying a graph, the bridge records the command and plan request IDs in its
heartbeat before best-effort acknowledgement. The companion can therefore reconcile
a lost acknowledgement without blindly retrying. Acknowledgement/heartbeat confirms
application and publication, not that a render callback has emitted audio from the
new graph. AU `fullState` persists the validated processing plan and independent
global-bypass flag. Companion conversation turns, typed interpretations,
hypotheses, snapshot ancestry, preview/revision identities, and lock history now
persist in a bounded checksummed local store. Restore does not revive old AU
authority: references are live only when the current instance, runtime epoch,
capture, committed plan, and conversation identities reconcile exactly; otherwise
the history is view-only. The App Group protocol still has bounded retention rather
than a permanent cross-restart command-idempotency ledger.

## Failure recovery

- Invalid or stale plans are rejected before compilation.
- Plans exceeding 32 nodes, 32 goals, or 4 KiB per rationale are rejected.
- Unsupported DSP nodes produce typed errors; the committed graph remains active.
- Nonfinite host input is replaced with zero before metering, capture, global bypass,
  or DSP, preventing invalid samples from escaping or poisoning state. A production
  build will add an atomic fault counter visible outside render.
- IPC messages are immutable files written temp-then-rename; partial files are not
  presented as valid messages. Corrupt, oversized, expired, wrong-runtime, unsafe-
  path, wrong-instance, hash-mismatched, and WAV-metadata-mismatched inputs fail closed.
- Capture returns no artifact if bounded retries cannot obtain a coherent ring
  snapshot. Commit rehashes the bound source, checks metadata and canonical plan
  identity, re-renders and measures the exact candidate, and fails closed when
  nonfinite output or approximate true peak exceeds the plan ceiling. The currently
  committed graph remains active on any pre-publication failure.
- Capture belongs to the current render-resource allocation. Deallocation clears the
  ring; direct and IPC reads then return failure and publish no WAV. Reallocation
  creates an empty ring, and the HostProbe verifies only newly rendered playback can
  appear afterward.
- The companion can explicitly purge every file beneath the App Group capture and
  preview cache roots while retaining the roots, protocol diagnostics and AU state.
  Automatic audio-cache expiry is not implemented. Protocol maintenance is
  implemented separately: an expired completed command/reply transaction is retained
  for at least 10 minutes after completion; orphaned/uncompleted diagnostics and
  malformed entries remain for 24 hours; and instance records are removed after 10
  minutes without modification. Active discovery still excludes a heartbeat after
  five seconds. Retention is based on filesystem modification time rather than an
  untrusted sender timestamp.
- Experimental Logic actions stop at the first unverifiable postcondition and
  record observed before/after state plus the recovery attempt.

## Provider path

The provider interface has deterministic offline, OpenAI Responses, and Google
Gemini Interactions implementations. Both cloud adapters share the same versioned
intent/reference/hypothesis contract and the same six-stage validator; no vendor
type enters `AgentCore`, plan generation, preview, IPC, or AU execution. The
production-intent vocabulary and hypothesis engine remain deterministic and retain
supporting and contradictory evidence, uncertainty, preservation risks, provenance,
and the flag that listening remains decisive.

Abstract language is grounded through a separate generated advisory catalog rather
than expanding executable intent or DSP authority. Exact reviewed phrases select at
most three source-scoped entries containing alternate senses, contradictions,
non-DSP causes, preservation risks, candidate canonical terms, and an ambiguity
policy. They are labeled professional-practice heuristics and expose explicit false
authority fields. They can improve bounded evidence retrieval, but only the existing
typed provider contract and six-stage validator can produce a trusted interpretation.

The companion alone can read a provider Keychain item or create an ephemeral network
session, and only after explicit consent. Providers receive bounded labeled text and
measurements—not raw audio, paths, filenames, AU state, DSP parameters, shell,
filesystem, host, plug-in, or executable tools. Exact asynchronous AU/runtime/
capture/plan/conversation/turn identity is rechecked after inference; stale output is
discarded. Audio-capable reasoning, if later implemented, requires a separate
interface, explicit consent transaction, disclosure, and test lane. Provider output
remains an untrusted semantic proposal. Current adapters pass mocked wire/failure
tests; credential-backed live-provider and direct Logic AI evidence remain pending.

## Research-informed optimization boundary

Reference matching and candidate refinement may later run a bounded gradient-free
search over the same deterministic graph. It is companion/offline work: choose a
validated graph, render candidates, measure independent trait/penalty objectives,
cache by graph/source hash, and return previews. An effect-sensitive representation
must be calibrated against listening tests; a generic semantic embedding is not a
production-quality oracle. Generative waveform editing remains a separate opt-in
new-asset transaction, never a hidden graph node.
