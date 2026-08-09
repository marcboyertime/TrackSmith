# TrackSmith

A native, reversible audio-production assistant designed around a reliable Audio
Unit effect for Logic Pro. The current build combines a deterministic offline
fallback with provider-neutral OpenAI Responses and Google Gemini Interactions
adapters. Every model result remains untrusted semantic input to six local
validation gates; only TrackSmith constructs, renders, measures, and commits bounded
DSP graphs. The user remains in control of preview selection, revision, locks,
commit, bypass, and restoration.

The product name is TrackSmith. The development app/AU still use the earlier
`Logic Audio Assistant` display name and bundle identifiers for compatibility;
that identity is not silently changed by this research milestone.

## Product modes

TrackSmith has two permanent top-level modes in the native companion:

- **Guide Me** — a user-mediated Logic production tutor. You describe a problem
  ("I sound nasal") or a goal; TrackSmith presents competing possible causes
  with visible uncertainty, then exactly one reversible manual experiment at a
  time: what to do, where in Logic Pro 12.3, a validated bounded starting
  value when one applies, what to listen for, why, when to stop, what could go
  wrong, and exactly how to undo it. You report Better / Worse / No change /
  Not sure / Not applicable / Can't find it / Done / Undo and a deterministic
  reducer picks the next validated step. Every exact instruction comes from a
  reviewed, versioned local procedure catalog — never from model prose — and
  TrackSmith never operates Logic itself: no Accessibility, coordinates,
  AppleScript, key-command injection, or host control of any kind. Tutor mode
  cannot mutate the AU processing graph.
- **Create For Me** — the existing workflow: capture recent playback, analyze
  locally, render three bounded level-matched previews, audition, revise,
  and commit explicitly.

**Guide Me now accepts open-ended production questions.** You are not limited
to a fixed list of problems: ask "Why does my chorus feel smaller than the
verse?", "How do I tighten my MIDI piano without making it robotic?", or "What
is pre-delay actually doing?" and TrackSmith routes the question across 9
question kinds and 100+ production domains, retrieves reviewed knowledge
cards, and returns a grounded answer with assumptions, one recommended first
move, strategy options and their tradeoffs, what to listen for, what to
preserve, when to stop, sources, and explicit limitations. Answers distinguish
documented behavior, measured behavior, inference, professional-practice
heuristic, subjective preference, personal result, and provisional research —
they are never flattened into one confidence score. Where credible sources
disagree, the disagreement is disclosed rather than resolved silently.

Exact Logic instructions still come only from the reviewed procedure catalog,
and any numeric recommendation must be quoted from a cited reviewed source or
carried by a validated procedure — the answer validator rejects the
alternative. TrackSmith will also tell you plainly when its reviewed knowledge
does not cover your question.

The active engineering focus is [TrackSmith Vocal v1](docs/TRACKSMITH_VOCAL_V1.md),
which is **in progress**; this is not a claim that its implementation, installed
build, Logic validation, or listening evidence is complete. See
[`docs/CURRENT_PRODUCT_FOCUS.md`](docs/CURRENT_PRODUCT_FOCUS.md) for the exact
sequencing and evidence boundary, and the dated
[automated-verification record](docs/evidence/TRACKSMITH_VOCAL_V1_AUTOMATED_VERIFICATION_2026-08-08.md)
for the bounded post-baseline results. General Production Tutor v2 remains open:
its engine passes 518/518 corpus cases offline across 99 evaluated domains, including
10 multi-turn conversations and 10 retrieval-precision cases, and its native Ask
surface is implemented. The reviewed catalog contains 458 claims and 78 strategies.
What TrackSmith remembers about you is local, explicit, and deletable. Gates
GP0-GP7 pass; GP8 and GP9 remain pending and owner-blocked. **No external or
YouTube source has been ingested** — the review pipeline is built and its refusal
paths proven, but every shipped claim derives from artifacts already in this
repository, and Research This is present only as an explicitly labeled not-built
control. No real production-question session and no in-host validation of the
broad tutor has been run, so whether these answers are useful is not established.
Logic Production Tutor v1 remains closed at an explicitly
[bounded scope](docs/evidence/LOGIC_PRODUCTION_TUTOR_V1_BOUNDED_CLOSURE_2026-08-05.md),
with T7 recorded as **CLOSED BOUNDED, NOT PASSED**.

## Current status

The capability spike, deterministic DSP/analysis foundation, and first functional
AU/companion session slice are implemented. The portable core builds and runs:

- Typed processing-plan schema with bounded parameters, at most 32 nodes and goals,
  4 KiB rationales, locked-node protection, stale-snapshot rejection, gain limits,
  and deterministic Codable state. Node parameters use the schema's keyed-object
  JSON form while legacy development-state arrays remain readable. The checked-in
  JSON Schema is CI-checked against the runtime enum vocabulary, implemented-node
  set, node-specific parameter allowlists, numeric ranges and both 32-item limits;
  it also records the normative 4,096-byte UTF-8 rationale limit.
- In-place mono/stereo DSP for trim, polarity, high/low-pass and peaking EQ,
  linked compression, linked split-band de-essing, linked expander/gate,
  saturation, width, fixed-time feedback delay, bounded algorithmic room,
  limiting, bypass, and finite-value safety. The three new modules are
  validator-gated TrackSmith-owned algorithm-version-1 candidates; they do not
  claim Logic equivalence or perceptual superiority.
- Bounded single-producer capture ring with C11 atomic publication and no render-
  side allocation; capture payloads are atomic and the ring reserves an overwrite
  guard so analysis can safely copy while playback continues, or fail closed if a
  coherent snapshot cannot be obtained.
- BS.1770 gated loudness, EBU Mode 3-second Short-term Loudness, EBU Tech 3342
  Loudness Range with explicit short-content reliability, and sample-rate-aware
  approximate true-peak measurement;
  peak/RMS/DC/clipping/crest; time-averaged
  spectral centroid, rolloff, slope, flatness, bands and flux; stereo correlation,
  plus bounded 200 ms RMS/crest-factor dynamics timelines, all with units,
  confidence, version, window, and limitations.
- Typed, versioned source-aware analysis for vocal, drums/drum bus, bass, guitar,
  synth/keys, and full stereo mix. Each evidence item declares applicability,
  aggregation, confidence, failure modes, and provenance; descriptive evidence is
  never promoted directly to `muddy`, `warm`, `punchy`, or another perceptual verdict.
- A provenance-tagged vocabulary covering all 28 requested production descriptors
  plus four explicit preservation concepts and a typed intermediate
  path from user intent to source-aware interpretation, supporting/contradicting
  evidence, competing production hypotheses, preservation constraints, risk, and
  validated deterministic DSP plans. Eight representative source-specific flows
  and a 420-case semantic/adversarial corpus are executable regressions.
- A generated 14-entry abstract musician-language advisory catalog covers phrases
  such as *expensive*, *bedroom-recorded*, *alive*, *emotionally boring*, *glued*,
  *three-dimensional*, *blurry*, and *clean without sterilizing*. It preserves
  source-dependent alternate senses, contradictions, unsupported/non-DSP causes,
  risks, and clarification policy. Entries are professional-practice heuristics
  with explicit false execution authority; they can retrieve bounded evidence but
  cannot create a DSP node, parameter, measurement, host action, or capability.
- Signal-relative conservative, balanced, and strong recipes; labeled BS.1770/RMS
  preview matching, objective preview-difference measurements, and pairwise
  rejection when any two strengths collapse after level matching;
  immutable snapshot history; typed cross-preview/snapshot/node revision; and a
  provider-neutral `ModelProvider` boundary. Production Intelligence v1 now has
  credential-backed live evidence for both OpenAI Responses (`gpt-5.6-sol`) and
  Gemini Interactions (`gemini-3.6-flash`), while retaining the deterministic
  offline provider as the no-network fallback. The Apple on-device lane remains
  optional compatibility work; cloud evidence is recorded separately from
  historical no-key documentation.
- Bounded deterministic context construction, strict typed intent/reference/
  hypothesis contracts, six-stage model-output validation, exact asynchronous AU/
  capture authority, bounded retry/cost policy, replay rejection, companion-only
  ephemeral networking, explicit cloud consent, and macOS Keychain credentials.
  Raw audio, file names/paths, AU state and executable tools are not provider input.
- Durable versioned companion conversation state with atomic checksummed writes,
  bounded history, credential redaction, corruption quarantine, an explicit 0.9→1.0
  migration, complete accepted-result validation audits, configured-versus-provider-
  reported model identity, and restore-time reconciliation that makes stale AU
  history view-only.
- PCM16/24/32 and Float32 WAV input, Float32 WAV output, analysis, three-preview,
  test-signal, and offline-render CLIs.
- Native SwiftUI/AVFoundation audition engine with synchronized sample-position A/B,
  waveform, measurements, warnings, and inspectable plan cards.
- Versioned, atomic App Group IPC with one-second plug-in heartbeats, per-instance
  runtime epochs, command expiry, bounded messages/artifacts, 0700 directories,
  0600 files, captured-instance binding, SHA-256 verification, and WAV metadata
  matching for captured artifacts. A cross-process `flock` protects mailbox
  maintenance and publication; the mailbox admits at most 2,048 message files/
  32 MiB and 512 instance files, never evicts a live command to make room, and
  fails closed when maintenance cannot bring it below quota.
- Compiled native SwiftUI companion plus AUv3 effect with borrowed host-buffer DSP,
  dry-input capture, live input status, automatable output gain, serialized plan
  state, safe mono/stereo format validation, and an off-render bridge that handles
  capture and graph commands while the compact plug-in UI is closed. Preallocated
  host-I/O scratch accepts null output `mData`, preserves host output pointers when
  upstream replaces its pull pointers, and rejects undersized or malformed layouts.
  Output-gain AU events are bounded and sample-accurate, including ramps that span
  callbacks, while one complete processing graph remains selected per callback.
- The native companion now performs the functional local path: discover an AU
  instance, capture recent playback, show a waveform, analyze it, render three
  synchronized level-matched previews, inspect every change card, and commit or
  revert the complete processing graph. Graph commit is bound to the immutable
  capture and expected current plan, and global bypass is independent of the graph.
- A confirmed privacy action removes all locally cached capture WAVs and preview
  directories without touching Logic source files, AU project state, heartbeats, or
  protocol diagnostics.
- An immutable research-ingestion library/CLI validates HTTP status, content type,
  length, signatures, PDF/text usability, HTML shells, hashes, duplicate payloads,
  Git cleanliness/origin/commit identity, rights metadata, quarantine, append-only
  history, and explicit version/supersession policy before publication.

On the development Mac, the frozen Production Intelligence v1 68/68 result, the
2026-08-02 72/72 ordinary and 73/73 vector-enabled results, and the 2026-08-05
Tutor v1 83/83 result remain dated historical evidence for their respective
harnesses. The frozen pre-Vocal baseline at commit `406b446` declares 91 ordinary
checks plus one optional official-vector lane. On 2026-08-08, Debug and Release
ordinary runs passed 91/91; an isolated Release/Thread Sanitizer run with the 14
local BS.2217-2 vectors passed 92/92 with no sanitizer report. Those baseline
ordinary checks include the Tutor v1 lanes plus General Tutor v2 routing,
knowledge/provenance, answer-honesty, unsupported-authority,
measurement-relevance, local profile persistence/deletion, and non-generalization
regressions. They also cover mailbox retention, fail-closed quota behavior,
command ordering, runtime-bound terminal replies, hard command-file expiry,
Short-term/LRA behavior, six source classes, the 28 requested descriptors plus
four explicit preservation concepts, eight production flows, the 420-case
semantic/adversarial corpus, provider failure and state-reference validation,
durable conversation reconciliation, competing hypotheses, and immutable research
ingestion. `AudioUnitHostProbe`
instantiates the real `AUAudioUnit` class and exercises the full local round trip:
render input, discover the instance heartbeat, request a recent capture, publish and
hash its WAV artifact, render three previews, commit the exact balanced audition,
lock an EQ, render and commit “use less compression,” undo/redo the graph, persist
and reload it, bypass without discarding it, and revert to bit-exact dry audio. The
probe also covers two isolated AU instances, lost-acknowledgement reconciliation,
invalid-state recovery, nonfinite-input sanitation, publication reset behavior,
capture teardown/reallocation, atomic commit guards, and AU/offline sample parity.
The current `AudioUnitHostProbe` also covers native `shouldBypassEffect`, conservative
180-second/-120 dB tail reporting, null-output/upstream-pointer host layouts, scheduled
output-gain events, cross-block ramps, distinct reset-versus-bypass automation
semantics, and conservative output-silence-flag handling. The final combined-tree
Release probe passed at 14.7 us mean, 16.9 us p99, and 46.0 us maximum against its
2,666.7 us deadline; the thread-local heap interposer observed zero heap operations
across 4,000 callbacks (14.8 us mean, 16.8 us p99, 57.8 us maximum). The
instrumented Thread Sanitizer probe passed at 550.1 us mean, 611.0 us p99, and
680.4 us maximum against the same deadline with no race report. The dated
[Vocal automated-verification record](docs/evidence/TRACKSMITH_VOCAL_V1_AUTOMATED_VERIFICATION_2026-08-08.md)
also records final development-tree Debug and Release runs of 104/104 and a
Release/Thread Sanitizer vector run of 105/105. The exact signed arm64 app/AU was
installed and byte-matched to the signed build; Team ID and App Group
entitlements matched, PlugInKit exposed exactly the installed extension, and
out-of-process `auval` succeeded. See the
[signed-install record](docs/evidence/TRACKSMITH_VOCAL_V1_SIGNED_INSTALL_2026-08-08.md).
These remain development guardrails, not direct Logic-host, real-vocal listening,
or release-completion proof.
The AU commit transaction checks the captured snapshot identity, expected graph,
locked nodes and captured sample-rate/channel format, then publishes the graph and
advances serialized state under one lifecycle lock. Current host controls prove
snapshot mismatch, stale-CAS, changed-format and deallocated commits fail without
changing graph or saved state. Those custom-host checks do not by themselves prove
Logic behavior; the independent Logic-hosted run below supplies that evidence for
the exercised workflow.

An independent real-audio run used an external 10.94-second, 44.1 kHz mono vocal and
passed all 18 vertical-slice assertions: three safe and measurably distinct
loudness-matched options, exact audition/graph equivalence, targeted revision with a
locked EQ preserved, typed undo/redo, sample-exact dry bypass, and unchanged source
SHA-256. The audio is user-owned and is not committed. Reproducible commands,
redacted measurements, and proof boundaries are recorded in
[`MVP_VERTICAL_SLICE_2026-07-13.md`](docs/evidence/MVP_VERTICAL_SLICE_2026-07-13.md).

Xcode 26.6 built the companion and extension as a current Apple Development-signed
Release, installed it at `~/Applications/Logic Audio Assistant.app`, strict-verified
both bundles, and passed `auval -v aufx LgAA ExAI` out of process for equal-layout
mono/stereo rendering through 192 kHz. The only validator warning was Apple's
`CurrentPreset`/`PresentPreset` deprecation. Direct Logic testing is not inferred
from `auval`. The development
environment is Apple Silicon, macOS 26.3, Logic Pro 12.3, and Swift 6.3.3. Exact
signing and executable fingerprints are recorded in
[`SIGNED_AU_VALIDATION_2026-07-13.md`](docs/evidence/SIGNED_AU_VALIDATION_2026-07-13.md).

The first ad-hoc build did not register. The installer now supports Xcode
account-managed Apple Development certificates, derives the actual Team ID from
the certificate, and verifies matching app/extension signatures. System AU
validation passed for that signed build. A fresh 2026-07-13/14 Logic Pro 11.2.2 run
then proved the current signed AU's insertion, playback, 44.1 kHz stereo companion
discovery, a hashed 7.01-second recent capture, three distinct level-matched previews,
graph inspection, locked-EQ compression revision, exact plan commit, internal
bypass/restore, project save/reload, unchanged source hashes, and two-instance
command isolation. Exact IDs, measurements, hashes, proof boundaries, and manual
reproduction steps are recorded in
[`LOGIC_MVP_VALIDATION_2026-07-14.md`](docs/evidence/LOGIC_MVP_VALIDATION_2026-07-14.md).
That historical Logic 11.2.2 record remains intact.

A separate Logic Pro 12.3 lane then repeated the production workflow at 44.1 kHz
mono: discovery/insertion, playback, a descriptor-bound 15-second recent capture,
three distinct previews, graph inspection, locked 320 Hz EQ, targeted compression
revision, exact commit, bypass/restore, save/reload into a new AU runtime, unchanged
external source SHA-256, and two-live-instance targeted bypass isolation. The exact
host, OS, signing/CDHashes, instance/runtime IDs, artifact/preview hashes, plan
values, project hashes, source hash, and test-driver boundary are recorded in
[`LOGIC_12_3_VALIDATION_2026-07-14.md`](docs/evidence/LOGIC_12_3_VALIDATION_2026-07-14.md).
Bus/output, freeze/bounce, low-latency, full rate/buffer, general automation, and
subjective-quality matrices remain open; see
[`KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md).

The live frontier-provider lane is also recorded separately from the historical
deterministic host reports. OpenAI and Gemini each completed six free-form,
source-aware cases across vocal, drums, bass, guitar, synth/keys, and full mix;
Gemini additionally completed 30/30 cloud-assisted cases with three valid
level-matched previews per case and unchanged source bytes. See the
[cross-provider report](research/evaluation/production-intelligence-frontier-cross-provider-2026-07-22/README.md)
and [Gemini cloud-30 report](research/evaluation/production-intelligence-gemini-3-6-flash-cloud30-2026-07-22/README.md).

The direct frontier-AI host lane is now complete. In Logic Pro 12.3, Gemini
interpreted “Make this vocal feel more intimate and expensive, but keep the
breathiness” into typed source-aware goals and two competing hypotheses. TrackSmith
rendered three distinct bounded-loudness-match previews, resolved a natural
preview/node-lock revision, committed the exact post-render graph, bypassed and
restored it, then recovered the same five-node graph and locked EQ after Logic
save/reload with the provider unavailable. The source SHA-256 remained unchanged
and a second AU instance retained its independent graph. Two previews matched the
source essentially exactly; the strong third candidate disclosed that compensation
was safety-limited rather than silently exceeding the added-gain bound. See the
[direct Logic report](docs/evidence/LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md)
and [v1 closure audit](docs/evidence/PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md).

## Build and test

Requirements for the portable core: macOS 14+, Apple Swift 6.1+, and XcodeGen.
Full Xcode is required for the app extension.

```sh
make verify
make native-verify
make native-install
make realtime-heap-probe
make demo
make preview-demo
```

Direct commands:

```sh
swift build -c release
swift run -c release TestRunner
swift run AnalysisCLI input.wav
swift run PreviewCLI input.wav --source vocal --prompt "make this clearer and more controlled"
swift run -c release AuditionApp "/path/to/preview folder"
swift run -c release AudioUnitHostProbe
swift run -c release VerticalSliceCLI input.wav --output "/path/to/new proof folder"
swift run OfflineRenderer input.wav processing-plan.json output.wav
xcodegen generate
```

Before the first Logic insertion test, add an Apple Account in Xcode Settings →
Accounts and create an Apple Development certificate under Manage Certificates.
Then run `make native-install`, close Logic if it is open, launch
`~/Applications/Logic Audio Assistant.app` once, and reopen Logic.
Then follow [`MANUAL_LOGIC_TESTS.md`](docs/MANUAL_LOGIC_TESTS.md). A successful
Xcode build, App Group proof, host probe, or `auval` run is not the same as manual
Logic-host validation.

## Try audible previews now

On this development checkout, a verified demo session is available at
`fixtures/generated/demo-vocal-previews`. If generated files are absent in a fresh
clone, run `make preview-demo`. Open the resulting directory and audition
`00-original.wav`, then the three numbered variants.

To process your own Logic-exported WAV:

```sh
swift run -c release PreviewCLI "/path/to/My Vocal.wav" \
  --source vocal \
  --prompt "make this clearer, warmer, and more controlled" \
  --output "/Users/marcboyer/Desktop/My Vocal Preview 1"
```

The output directory must be new. It contains four audible WAVs, one plan per
variant, `manifest.json` with measurements and parameters, and `AUDITION.txt`.
The input is never modified. See [`HANDS_ON_TESTING.md`](docs/HANDS_ON_TESTING.md)
for drum/full-mix examples, supported prompt vocabulary, and verification steps.

For sample-position-synchronized comparison, open that folder in the native app:

```sh
make audition SESSION="/Users/marcboyer/Desktop/My Vocal Research Preview 3"
```

Press Space to play/pause, `0`–`3` to select a version, and `A` to toggle the
selected result against the original. The loader validates file containment,
audio formats, snapshot identity, and saved plans before playback.

## Repository map

- `packages/`: host-independent schema, DSP, source-aware analysis, production
  intent/hypotheses, state, preview, IPC, research ingestion, and Logic adapter
  boundaries. `packages/ProductionTutor/` is the user-mediated Guide Me tutor:
  typed issue/cause/step/feedback contracts, the generated reviewed procedure
  catalog with fail-closed validation, a deterministic planner and feedback
  reducer, staged lesson/proposal validators, and a bounded checksummed
  tutor session store. Its reviewed source artifact is
  `research/knowledge/logic-pro-12.3-tutor-procedures.json` with generator and
  audit scripts under `research/scripts/`, and its 77-case corpus is
  `research/evaluation/TRACKSMITH_TUTOR_INTENT_CORPUS_V1.json` (run via
  `swift run ProductionTutorEvaluation`).
- `plugins/AudioUnit/`: compiled AUv3 extension and reusable host-probe core.
- `apps/CompanionMacApp/`: native SwiftUI application scaffold.
- `apps/CompanionApp/`: buildable command-line product slice.
- `tools/`: preview/audio generation, offline renderer, analysis CLI, and integration probes.
- `tools/AuditionApp/`: directly buildable native preview player for blinded-style A/B work.
- `tests/TestRunner/`: dependency-free executable verification harness used because
  it runs consistently under both CI/Command Line Tools and full Xcode.
- `docs/`: product, architecture, capability, safety, test, and integration records.
- `research/analysis/`: corpus audit plus the deep primary-source synthesis that
  separates standards, research evidence, professional heuristics, disputes,
  perceptual limits, implementation consequences, and non-claims.
- Logic 12.3's four primary manuals have an every-page, 2,686-page review in the
  [effects/tool](research/analysis/TRACKSMITH_LOGIC_PRO_12_3_TOOL_ATLAS.md),
  [instrument](research/analysis/TRACKSMITH_LOGIC_PRO_12_3_INSTRUMENT_ATLAS.md),
  [workflow](research/analysis/TRACKSMITH_LOGIC_PRO_12_3_WORKFLOW_ATLAS.md), and
  [control-surface](research/analysis/TRACKSMITH_LOGIC_PRO_CONTROL_SURFACES_ATLAS.md)
  atlases. The Production Intelligence context builder can retrieve 142 reviewed
  effects/pedals, 28 reviewed instruments (including the 16-source canonical Quick
  Sampler supplement), and explicitly named entries from a 30-tool editor catalog.
  A fail-closed coverage audit verifies all catalog identities against their
  declared primary-source pages and the dated Logic 12.3 release-notes capture.
  Instrument retrieval requires an explicit instrument name or reviewed alias so a
  generic recorded source never causes TrackSmith to invent what created it. This
  knowledge is advisory; it does not give the AU authority to insert or control
  Logic-native tools, MIDI, automation, Accessibility, or project state. The
  [native measurement protocol](docs/LOGIC_NATIVE_EMPIRICAL_MEASUREMENT_PROTOCOL.md)
  and deterministic 18-fixture generator enumerate a 200-identity empirical
  campaign separately; every native identity remains `not_run`, `partial`, or
  `complete` only when a versioned Logic render actually exists. The current
  campaign ledger records 189 `not_run`, 11 `partial`, and zero `complete`,
  including partial profiles for DeEsser 2, Noise Gate, ChromaVerb, Space
  Designer, Stereo Delay, Tape Delay, Adaptive Limiter, and Direction Mixer in
  addition to Bitcrusher, Channel EQ, and Compressor.
- `research/evaluation/`: the versioned 420-case semantic/adversarial
  production-intent corpus.

## Product workflow target

The implemented companion slice supports recent-playback capture, local analysis,
three level-matched previews, synchronized audition, graph inspection, exact commit,
typed multi-turn revision with preview/snapshot/node references and locks,
undo/redo, non-destructive global bypass, and restore. The installed signed
compatibility build completed the deterministic workflow in Logic 11.2.2 and again
in Logic 12.3; Logic project save/reload restored
the committed graph, lock and bypass state, and two simultaneous instances remained
isolated. Companion conversation/revision history now persists locally, but restored
references are view-only unless the live AU runtime, capture, conversation, and
committed graph reconcile exactly. “Capture next playback” remains open;
the proven mode is bounded recent playback. Project-wide Logic editing remains an
optional adapter and never a dependency of the audio product.

## Privacy default

Core measurement, recipes, graph execution, preview rendering, and manual editing
are local. No audio upload path or telemetry is implemented. The required semantic
path is also local and uses no API key. Optional cloud text/measurement reasoning
requires provider selection, a Keychain credential, and explicit consent; all
responses remain untrusted typed proposals. See
[`PRODUCTION_INTELLIGENCE.md`](docs/PRODUCTION_INTELLIGENCE.md) for the implemented
boundary and [`PRODUCTION_INTELLIGENCE_NO_KEY_MILESTONE.md`](docs/PRODUCTION_INTELLIGENCE_NO_KEY_MILESTONE.md)
for the amended completion standard.
