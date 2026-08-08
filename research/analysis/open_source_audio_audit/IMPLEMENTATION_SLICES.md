# First gated implementation slices

These are TrackSmith-owned, source-preserving, reversible, **non-shipping** slices. They add no third-party dependency, source, model, checkpoint, asset, runtime, or download. They preserve native SwiftPM macOS/AUv3 architecture and are not permission to treat any upstream repository as cleared.

## Reconciliation of the likely preferred order

The likely desired sequence is Basic Pitch, RNNoise, then a TrackSmith-owned listening runner. The shards do not clear Basic Pitch weights/training data or its Python/ML runtime, and classify both Basic Pitch and RNNoise `STUDY_ONLY`; RNNoise is speech-only and its model/data rights remain unresolved. Therefore the safe version of that order is: (1) a TrackSmith-owned **offline audio-to-MIDI proposal boundary and deterministic adapter/fixture harness** that initially uses a mock/recorded fixture and copies no Basic Pitch code/model, (2) an RNNoise research protocol with no source/model import, and (3) a TrackSmith-owned listening runner built independently. None may ship until all listed gates pass.

## Slice 1 — TrackSmith-owned offline audio-to-MIDI proposal adapter and fixture harness

**Exact highest-value safe capability:** `TrackSmith-owned offline audio-to-MIDI proposal boundary with a deterministic mock/recorded-fixture adapter and provenance harness.`

Create a typed offline-only interface that accepts an explicitly selected immutable copied audio snapshot and returns a non-authoritative MIDI *proposal* plus complete provenance. Initial adapter behavior must be mock/recorded fixture data owned by TrackSmith; it must not invoke, copy, download, embed, or claim clearance for Basic Pitch. It may later host a separately licensed external adapter only behind an explicit rights/runtime decision. The AU never receives model inference; it only receives a user-approved, validated typed plan if a later product decision permits one.

Gates: deterministic replay fixture and adapter-version hash; input/source/output hashes; save/reload; source preservation; preview/revision/explicit commit; exact rollback; stale-snapshot/result rejection; typed parameter bounds; license-notice and third-party-manifest records (even when empty); allocation/sanitizer tests for any AU-facing plan handoff; and offline/realtime parity assertion as **not applicable** to the external offline proposal generation. No shipping until a separately selected adapter has written code, dependency, model/checkpoint, training-data, content, security, local-audio, performance, and commercial-rights approvals.

## Slice 2 — RNNoise speech-denoising research evidence protocol

Create a research-only protocol and TrackSmith-owned fixture/evidence schema for a speech-only 48 kHz denoising baseline. It is a comparison plan, not an integration: do not clone RNNoise, fetch its model, include its training data, or apply its output to a TrackSmith commit. It must state that no general-music-denoising claim is supported.

Gates: written model/training-data and patent/usage-rights determination before any external experiment; a separately resolved dependency/notice manifest; rights-cleared TrackSmith fixtures; offline local copied input only; deterministic fixed-frame/configuration replay; source/output/environment hashes; save/reload; source preservation; stale-result/rollback tests; and a future native implementation only after allocation, TSAN/sanitizer, CPU/latency, sample-rate/frame/channel, and offline/realtime parity evidence. Model inference is never allowed in the render callback.

## Slice 3 — TrackSmith-owned blinded listening runner

Implement an independent native listening-evaluation runner from TrackSmith requirements, not webMUSHRA or akouste source/assets. It should create level-matched, synchronized, blinded candidate auditions with source, preview, graph, measurement, configuration, environment, order/seed, and response hashes; preserve identity blindness until judgment; and label evidence `SINGLE_LISTENER_FORMATIVE_EVIDENCE`.

Gates: TrackSmith-owned or explicitly licensed audio; deterministic random seed/order; locally retained consent/retention/export policy; save/reload; source-preservation and preview identity checks; revision/commit/rollback/stale-result tests; third-party manifest and notice checks; and later AU integration only after offline/realtime parity plus render allocation/sanitizer evidence. It must never put model inference in the callback or let provider output select arbitrary code/DSP/files/AU state.

## Gates that apply to every future proposal

For every proposed integration, separately decide and record **code reuse**, **algorithmic inspiration**, **pretrained model reuse**, **model retraining**, **research-only evaluation**, and **commercial shipping**. Require deterministic replay fixtures; save/reload and offline/realtime parity where applicable; allocation/sanitizer tests; source-preservation; rollback/stale-result tests; license notices; and a third-party manifest. No tool or provider can select arbitrary executable code, DSP, model, file, or AU state; it can propose only values in a predeclared typed schema. Keep output as a preview/revision candidate until explicit human commit validates current snapshot, locks, format, and source identity.

## Exact next implementation prompt

```text
Objective
Implement TrackSmith-owned offline audio-to-MIDI proposal boundary with a deterministic mock/recorded-fixture adapter and provenance harness. This is a non-shipping preparation slice only; it must not integrate Basic Pitch or any other third-party source, model, checkpoint, asset, package, executable, or network call.

Inspect first
Inspect the current Package.swift/package layout, AUv3 plug-in and companion targets, typed plan/revision/commit models, App Group IPC schemas, snapshot/source-hash and rollback/stale-result logic, existing fixture conventions, tests, and architecture documents. Do not assume a current path or type name exists. Add files only in the existing TrackSmith-owned module/test locations that inspection shows are appropriate; preserve legacy identifiers and the native SwiftPM macOS/AUv3 architecture.

Interfaces to create or extend
Define a typed offline-only audio-to-MIDI proposal request/result boundary. A request must bind an explicitly selected immutable copied source snapshot, source hash, audio format identity, adapter identifier/version hash, and deterministic fixture/configuration identity. A result must carry candidate MIDI/proposal data, output hash, provenance, and a non-authoritative status. Provide a deterministic mock or recorded TrackSmith-owned fixture adapter only. Require an explicit validation step before a proposal can become a preview/revision candidate; do not allow it to mutate source audio, bypass locks, or commit automatically.

Constraints
No third-party code/model/data/assets/dependencies; no downloads; no Python process; no network; no external adapter execution. Do not claim Basic Pitch is licensed or cleared. Never perform inference, file I/O, allocation, blocking work, or provider work in the AU render callback. Do not let a provider or adapter choose arbitrary code, DSP, files, or AU state. Preserve source identity/hashes, typed plans, App Group instance/runtime/capture binding, preview/revision/explicit commit, locks/snapshots/stale protection, and exact rollback. Keep user audio local; work from explicitly selected copied snapshots only.

Tests
Add deterministic replay tests that compare fixture/request/result hashes and serialized provenance; save/reload tests; stale snapshot, changed format, lock, and rollback rejection tests; source-preservation tests; typed-boundary validation tests; and tests proving no automatic commit. If the new boundary crosses any AU-facing handoff, add allocation instrumentation and sanitizer-compatible coverage there; otherwise state why offline/realtime parity is not applicable to offline proposal generation and test that the AU callback is never invoked by the adapter. Add or update a TrackSmith-owned third-party manifest/notice record showing no third-party material is integrated.

Acceptance evidence
Run the focused Swift tests and the repository's appropriate package/build checks discovered during inspection. Report exact commands and output, changed files, fixture/source/result hashes or stable test assertions, and git diff --check. Demonstrate that the mock adapter is deterministic, source audio remains unchanged, stale/locked/mismatched requests fail closed, save/reload preserves provenance, and no third-party source/model/dependency was added.

Explicit exclusions
Do not download, execute, vendor, wrap, or reproduce Basic Pitch, RNNoise, NeuralNote, librosa, or any other third-party implementation. Do not add audio-to-MIDI model inference, realtime transcription, provider-controlled DSP, automatic commit, cloud upload, JUCE/Python/Electron/iPlug2/AudioKit architecture changes, or commercial-shipping claims.
```
