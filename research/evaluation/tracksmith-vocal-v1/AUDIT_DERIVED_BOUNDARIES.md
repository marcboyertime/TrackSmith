# TrackSmith Vocal v1 — audit-derived boundaries

This milestone applies four narrow capability slices plus retained architecture lessons from the 16-repository audit without importing a
third-party framework, runtime, model, weight, dataset, fixture, server, or source file.

## Offline audio-to-MIDI proposal boundary

`VocalAudioToMIDI` is independently authored Swift/Foundation code. It defines bounded note
proposals, capture/source/MIDI identities and hashes, algorithm identity, local offline or companion
off-render execution, preservation declarations, strict untrusted JSON keys, stale-result rejection,
and deterministic mock replay. The mock does not inspect audio and makes no transcription-quality
claim. Basic Pitch remains `STUDY_ONLY`; neither its Python code, runtime dependencies, pretrained
serializations, training data, Vocadito audio, nor output is integrated.

## Speech-cleanup study boundary

The RNNoise lesson is limited to a written speech-only research protocol. It adds the missing
noise-floor gate and retained-frame confidence adjustment to the dynamics experiment, specifies a
48 kHz/off-render study boundary, and requires model/data/license, allocation, sanitizer, parity,
replay, preservation, rollback, and stale-result gates. No RNNoise material is integrated.

## TrackSmith-owned blinded listening runner

`VocalEvaluation` is independently authored Swift/Foundation code. A deterministic seed binds a
reproducible blind order; participant packages omit candidate identities; a separate answer key is
consumed only after a finalized judgment; source/candidate/render hashes bind the artifacts; export
size is bounded; and the result is labeled exactly `SINGLE_LISTENER_FORMATIVE_EVIDENCE`. Scores
cover target relevance, source preservation, naturalness, intelligibility, temporal coherence, and
usefulness, with preference, none, no-preference, confidence, listening conditions, and fatigue.

The design addresses general evaluation requirements identified while studying webMUSHRA and
akoúste, but copies neither repository’s code, assets, layouts, text, configuration, server logic,
nor randomization implementation. webMUSHRA remains `LICENSE_BLOCKED` under its custom license;
akoúste remains `LICENSE_BLOCKED` under AGPL-3.0.

## Native DSP and hostile-host proof

The audit's useful native lesson is narrower than adopting another plug-in framework. The
fixed-capacity utilities studied in chowdsp_utils reinforced the requirement that delay storage be
allocated off-render, bounded from validated sample-rate/parameter limits, and reset without a
callback-time clear. TrackSmith's independently authored `FractionalDelayLine` and modulated-delay
processor use preallocated storage and a constant-time `validSampleCount` reset that does not clear
the allocated delay buffer in the callback; no chowdsp_utils/JUCE source,
module, symbol, template, build system, or dependency is present.

pluginval, JUCE, and iPlug2 reinforced the value of hostile-host lifecycle scenarios, not a reason
to replace TrackSmith's host or AU architecture. `AudioUnitHostProbe` now exercises the Vocal
modulated-delay graph through exact `fullState` restoration, reset replay, global bypass and restore,
deallocate/reallocate, finite bounded output, and tail declaration in addition to the existing format,
buffer, publication, nonfinite, automation, isolation, and persistence cases. The test is independently
authored and invokes none of those repositories. pluginval and JUCE remain `LICENSE_BLOCKED`; iPlug2
remains only a selectively portable reference and is not imported.

## Other audit decisions retained for Vocal v1

| Repositories | Lesson retained | Vocal v1 decision |
|---|---|---|
| AudioKit | A native Swift-facing utility should remain small and fit existing SwiftPM ownership. | No framework adoption and no copied utility; the current TrackSmith contracts already satisfy the needed native boundary. |
| NeuralNote | Audio-to-MIDI behavior does not clear model, ONNX/manual-conversion, JUCE, dependency, or content rights. | `STUDY_ONLY`; no code, model, weights, runtime, fixture, or output. |
| noise-suppression-for-voice | A convenient RNNoise wrapper does not erase GPL/JUCE or retroactive-VAD latency constraints. | `LICENSE_BLOCKED`; no link, import, distribution, or derivative implementation. |
| DDSP | Harmonic/noise decomposition is useful vocabulary for an honest future resynthesis boundary. | `STUDY_ONLY`; no TensorFlow/Python code, checkpoint, dataset, output, or production-quality claim. Vocal v1's brass options are editable coloration/hybrid DSP, not DDSP reconstruction. |
| librosa | Independent descriptor comparison can be useful when pinned and run against rights-cleared copied fixtures. | `SAFE_AS_OFFLINE_TOOL` only; it is not a shipping dependency, companion runtime, or AU path, and Vocal v1 currently invokes no Python tool. |
| Essentia | Descriptor breadth is not worth an AGPL production dependency. | `LICENSE_BLOCKED`; research comparison only after a separate licensing decision. |
| madmom | Tempo/onset ideas cannot be separated casually from noncommercial model/data rights and Python worker behavior. | `STUDY_ONLY`; no commercial embedding, model/data reuse, or runtime. |
| Demucs | Source-separation UX should preserve immutable input, model/config hashes, and derivative provenance. | `STUDY_ONLY`; no PyTorch, weights, first-run download, output, or source-separation claim in Vocal v1. |

These retained decisions deliberately separate an abstract engineering lesson from code reuse,
pretrained-model reuse, retraining, evaluation, and permission to ship. The complete pinned audit,
not this milestone summary, remains authoritative for each repository's dependency and rights record.

## Architectural invariants

- TrackSmith remains native SwiftPM/macOS/AUv3.
- Original audio and MIDI are immutable; outputs are isolated proposals or derivative assets.
- Capture identity, source revision, typed provenance, hashes, and deterministic replay survive.
- Model inference and evaluation run outside the render callback and require no runtime network.
- External output cannot select arbitrary code, DSP graphs, or unbounded parameters.
- A dependency is not approved merely because an abstract lesson informed TrackSmith-owned code.
- Code reuse, algorithmic inspiration, pretrained-model reuse, retraining, research evaluation, and
  commercial shipping remain separate decisions.
