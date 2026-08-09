# TrackSmith Vocal v1

**Milestone state:** implementation in progress
**Baseline:** [`docs/evidence/TRACKSMITH_VOCAL_V1_BASELINE_2026-08-08.md`](evidence/TRACKSMITH_VOCAL_V1_BASELINE_2026-08-08.md)
**Authority:** the machine-readable Vocal ledger is authoritative for gate state

TrackSmith Vocal v1 is the focused capture-to-finish path from an ordinary
description of a wanted vocal to recording guidance, diagnosis, distinct
creative options, revision, recovery, and—only after explicit approval—a
validated deterministic AU graph or a separately identified rendered asset.

This milestone supersedes the earlier handoff's proposed 20-session prerequisite
as a sequencing rule. It does not rewrite that historical handoff or manufacture
the owner evidence that was missing when it was written. The owner is the only
available listener, so subjective evidence is labeled
`SINGLE_LISTENER_FORMATIVE_EVIDENCE` and remains separate from automated proof.

## One connected workflow

1. **Describe** — the musician states the desired result, room, available gear,
   constraints, and qualities that must survive.
2. **Prepare** — TrackSmith offers bounded capture hypotheses with assumptions,
   tradeoffs, exact test steps, listen-for cues, stop rules, and rollback.
3. **Test** — a short immutable capture is analyzed locally. Measurements can
   flag clipping, low level, silence, unstable level, and supported noise risk;
   they cannot decide whether the performance or timbre is artistically right.
4. **Revise capture** — measurement evidence and compact owner feedback update
   the plan without pretending there is one universal microphone setup.
5. **Guide or create** — the same typed intent can remain a user-mediated lesson
   or cross an explicit handoff into locally planned processing or asset work.
6. **Compare** — three structurally differentiated hypotheses enter the
   synchronized, loudness-aware preview validator. The valid render count and
   perceptual distinction remain fixture- and listening-dependent; accepted
   previews retain source identity, preview identity, ancestry, and limitations.
7. **Refine** — typed scope and aspect references preserve accepted qualities,
   enforce locks, reject contradictions, and branch without overwriting history.
8. **Approve** — editable graphs commit through the existing AU compare-and-swap
   protocol. Rendered/resynthesized audio remains a new provenance-bearing asset.
9. **Recover** — original audio and typed preview/asset ancestry persist with
   committed state, undo, redo, bypass, restore, and provider-offline replay.
   Operational preview or asset audio is available after relaunch only when its
   exact source and local cache are re-established; history never fabricates it.

## Authority and execution boundaries

| Boundary | May do | Must not do |
|---|---|---|
| Frontier or on-device language model | Interpret language, expose ambiguity, retrieve reviewed knowledge, and propose bounded semantic hypotheses | Select arbitrary code, parameters, DSP graphs, files, assets, AU state, or commit authority |
| TrackSmith companion/off-render worker | Analyze immutable captures, validate semantic state, construct plans, render previews/assets, hash provenance, and reject stale work | Imply Logic project/region/automation control or mutate source audio |
| AU render callback | Execute only preallocated, validated, bounded TrackSmith DSP from the active typed plan | Allocate, block, access the network or filesystem, run inference, or accept prose/model output |
| Guide Me | Teach a reversible user-performed experiment and record explicit feedback | Claim the experiment was performed, operate Logic, or mutate the AU graph |
| Create For Me | Render inspectable alternatives and commit only an explicitly approved valid graph | Turn a lesson into processing without an explicit handoff and current capture authority |
| Rendered-asset workflow | Create a new scoped artifact with hashes, engine version, intent, preservation contract, parent, and limitations | Disguise resynthesis or waveform generation as editable EQ/compression or overwrite the original |

## Typed Vocal state

The Vocal domain owns versioned, bounded representations for:

- capture context, assumptions, equipment, constraints, setup alternatives,
  test procedure, evidence, owner feedback, and plan revision;
- ordinary/sensory/emotional/material/motion/metaphorical intent;
- corrective versus creative purpose, strength, time/section scope, motion,
  preservation, allowed changes, prohibitions, ambiguity, and uncertainty;
- editability class: deterministic DSP, time-varying modulation,
  analysis-driven transformation/resynthesis, or rendered asset;
- source, capture, plan, preview, and asset identities and hashes;
- parent/branch ancestry, selected aspects, aspect locks, and conflict reasons;
- Guide Me to Create For Me handoff authority;
- engine/pipeline identity, algorithm/model version, parameters or seed,
  creation time, output hash, and known limitations for every new asset.

Chat text is descriptive input, never mutation authority. Every executable value
comes from a TrackSmith-owned allowlist and passes local validation.

## Demonstration transformations

### Intelligible underwater vocal

The required candidates are different hypotheses rather than one wet/dry ladder:
one may prioritize dry articulation through filtered space, one may prioritize
bounded pitch/time movement with controlled ambience, and one may prioritize a
stranger saturated depth cue while retaining a direct intelligibility anchor.
The native time-varying lane uses a versioned, preallocated modulated delay under
the same node-count and memory budget as fixed delay.

Section-only requests are not silently treated as full-capture AU processing. If
the supported AU graph cannot express the requested region authority, TrackSmith
uses an explicitly scoped asset render with crossfades and provenance, or gives a
user-mediated Logic procedure.

### Vocal-to-brass

“Sound like a trumpet” is represented as ambiguous. Vocal-colored brass,
muted-brass hybrid, and animated ensemble-colored vocal are the three shipped
editable interpretations. They use bounded EQ, saturation, dynamics, delay, and
modulation; all retain the vocal source. Analysis-driven harmonic reconstruction,
resynthesis, vocoding, and acoustic-instrument replacement are not implemented in
Vocal v1. Any future implementation must be labeled as resynthesis or a rendered
asset and keep timing/dynamics/pitch-contour preservation as a contract rather
than an unproven success claim.

No candidate is described as a realistic acoustic trumpet until owner listening
supports that narrower claim.

## Analysis truth

Objective metrics are guardrails. They do not prove naturalness,
intelligibility, emotional success, or preference. In particular, level
variability is computed only from finite, noise-floor-gated frames; when gating
discards most frames, confidence is reduced and the result cannot be presented
as a confident performance-dynamics measurement.

Pitch, phoneme, consonant, plosive, sibilance, room, and performance claims are
made only when a specifically validated implementation supports them. Otherwise
the UI asks the musician to listen or presents a reversible experiment.

## Selective use of the 16-repository audit

The audit informs boundaries without importing a new framework:

- **Audio-to-MIDI:** a TrackSmith-owned offline/companion proposal contract,
  deterministic mock fixture, declared source/MIDI identity validation, stale-result
  rejection, and strict untrusted-output validation prepare a future experiment.
  Basic Pitch code, models, weights, and data are not embedded.
- **Capture cleanup:** RNNoise informs a speech-only research protocol for
  noise-floor gating and confidence behavior. No RNNoise code or model is
  shipped, and inference remains outside the render callback.
- **Listening:** TrackSmith independently authors its blinded owner-study runner
  with deterministic order, hashes, “no preference”/“none acceptable,” fatigue
  limits, conditions, confidence, and replay. webMUSHRA and akoúste code are not
  copied while their licensing constraints remain unresolved.
- **Architecture:** JUCE, Python, Electron, and alternate plug-in frameworks are
  not introduced. The native SwiftPM/macOS/AUv3 architecture remains intact.

The third-party manifest records inspirations and classifications. A future
prototype is not permission to ship a dependency, model, checkpoint, dataset,
or bundled content.

## Listening and evidence

The owner-study contract hides candidate, processing-plan, preview, and optional
asset identities until judgment, randomizes deterministically, binds exact source
and render hashes, records listening conditions and fatigue, and scores target
relevance, source preservation, naturalness, intelligibility, temporal coherence,
usefulness, preference, and confidence. The CLI only validates and exports local
JSON contracts; it does not render, play, synchronize, level-match, or inspect
audio. Playback remains an explicit owner-operated step using already-validated
candidate renders.

An automated test may prove that this infrastructure is deterministic and
source-preserving. Only a completed owner response may become
`SINGLE_LISTENER_FORMATIVE_EVIDENCE`; it is never generalized to professional
consensus or population preference.

## Release gates

Vocal v1 cannot be reported complete until the ledger links every material claim
to code, a deterministic test, an audio fixture, a measurement, a current signed
AU/Logic record, an owner response, or an explicit limitation. Required lanes
include semantic/adversarial coverage, capture-plan relevance, test-take
revision, candidate diversity, scope/lock/ancestry precision, source and asset
preservation, stale and rollback behavior, persistence/corruption/privacy,
offline/realtime parity, allocation and sanitizer checks, performance, `auval`,
signing/entitlements/installed identity, provider-offline recovery, and the full
existing Production Intelligence and Tutor regressions.

Automatable work is completed first. The final owner procedure is kept compact,
and any unperformed Logic or listening step remains explicitly open.
