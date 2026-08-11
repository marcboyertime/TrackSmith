# Known limitations

## Host and packaging

- Xcode 26.6 builds the AUv3/SwiftUI project. The current Release installer signed
  with Apple Development Team `KDV9RC892F`, staged, strict-verified, installed and
  registered the current bundle, and `auval` passed its out-of-process matrix through
  192 kHz. The product is not notarized. The current validator output retains a
  `CurrentPreset`/`PresentPreset` deprecation warning. An earlier run also emitted a
  non-failing transient
  1-input/2-output legacy-proxy warning, but it did not recur in the current run. The
  focused production-class HostProbe rejects actual 1→2 and 2→1 resource
  allocations; neither validator result establishes asymmetric render support.
- Historical Logic Pro 11.2.2 testing proved the 44.1 kHz stereo workflow. A
  separate Logic Pro 12.3/build 6674 lane proved installed-AU discovery/insertion,
  44.1 kHz mono playback/capture, three previews, locked-node revision, commit,
  internal bypass/restore, save/reload into a fresh runtime, unchanged external
  source bytes, and two-live-instance targeted command isolation. Exact installed
  app/AU fingerprints are recorded because the signed compatibility bundle and the
  later current-source regressions are separate evidence. Neither lane covered
  buses, stereo output in 12.3, freeze, bounce, low-latency mode, general automation,
  every rate/buffer combination, large projects, or sustained many-instance load.
- Logic displayed an instability alert during Computer Use/permission testing, then
  recovered. The test insert was undone, no plug-in crash report was present, and
  `SkyComputerUseService` did crash. An off-thread AU lifecycle/status race was fixed
  as a plausible code contributor, but the alert's root cause is not proven.
- Development bundle IDs use `com.marcboyer.logicaudioassistant`. The signed app and
  AU share `KDV9RC892F.com.marcboyer.logicaudioassistant`; manufacturer-code ownership,
  release signing, distribution provisioning and notarization remain release work.
- Logic project selection, source files, channel strips, plug-in insertion/reorder,
  arbitrary automation, tracks/regions and bounce are not stable capabilities.
- ARA 2 has not been licensed or integrated. A bounded read-only Accessibility
  observer now exists for visible Logic labels, values, roles, and frames. It is not
  a project DOM, cannot see hidden state reliably, and contains no setter/action
  path. Core MIDI and control-surface adapters are not implemented.

## Audio engine

- The AU callback uses borrowed noninterleaved Float32 host pointers and the same
  deterministic graph as offline rendering; parity is tested across irregular host
  blocks. The Swift-array `AudioBuffer` remains offline-only.
- Whole graphs can be published atomically during playback, but there is no click-
  free old/new graph crossfade. A graph with a different gain, filter history, or
  dynamics state can therefore create a discontinuity at the publication boundary.
- Retired graph boxes remain retained until render resources are deallocated so ARC
  never destroys one in the callback. This safety strategy permits at most 128 graph
  publications per render-resource allocation; further commits fail safely until
  the host reallocates resources.
- Render-resource allocation/deallocation, reset, plan publication and status
  snapshots are serialized by a lifecycle lock. This closes the observed off-thread
  status race. Custom-host Debug/Release/Thread-Sanitizer deadline probes pass, but
  callback timing and allocation under Logic load have not yet been measured.
- Companion commit is one lifecycle-locked AU transaction across captured-snapshot,
  allocated-resource and current-format checks, expected graph compare-and-swap,
  lock validation, graph publication and serialized current-plan state. The
  HostProbe proves snapshot mismatch, stale-CAS, changed-rate and deallocated commits
  preserve prior output/state, but Logic-host interruption timing is not yet measured.
- The callback contains no explicit allocation, blocking lock, file/network/database
  access, logging, UI operation, or unbounded loop after the host pull. A thread-local
  development interposer observed zero standard/aligned/macOS-zone heap operations
  across 4,000 representative callbacks. It ran in the production-class custom host,
  not inside Logic, and does not cover every possible VM/runtime entry point; a formal
  all-host allocation-free claim would therefore be premature.
- Host I/O uses preallocated, allocation-sized scratch. It supports null output
  `mData` and upstream pull-pointer replacement, and rejects malformed channel/byte/
  frame layouts. The current HostProbe completed these synthetic cases in Debug,
  Release and Thread Sanitizer runs. Ordinary Logic playback does not expose each
  synthetic layout, and this is not evidence that every third-party upstream Audio
  Unit obeys its own contract.
- Upstream `OutputIsSilence` is materialized as zero input. The AU always clears the
  outgoing silence hint after processing because an IIR may emit a tail. This is
  conservative for scheduling and can prevent a host from skipping work on a block
  that actually remains silent.
- `tailTime` is a static 180-second conservative scheduling bound against a declared
  -120 dB amplitude threshold because hosts can cache it and a live commit can later
  activate the maximum aggregate feedback-delay graph or longest supported
  low-frequency/high-Q IIR. A maximum-bound impulse regression couples that value to
  the validator and DSP. It is not a measured tail for the current graph, and dry/
  memoryless graphs therefore report substantially more tail than they generate.
- Limiting is zero-lookahead sample peak, not true peak. `lookaheadMS` is constrained
  to zero until a fixed-latency lookahead implementation exists. Activation rejects
  a final limiter ceiling above `maxTruePeakDB`, but that structural relationship
  does not guarantee live inter-sample dBTP compliance.
- Dynamic EQ, transient shaping, and M/S EQ remain schema placeholders and
  intentionally fail validation when enabled. Expander/gate, fixed-time feedback
  delay, and a bounded algorithmic room are now implemented as TrackSmith-owned
  algorithm-version-1 modules. They do not clone Logic algorithms. Their graph
  parameters are immutable within a compiled graph; a revised plan publishes a
  reset replacement graph at a callback boundary, without a click-free crossfade or
  sample-accurate general-node automation.
- Fixed and modulated delay share a bound of 1–2000 ms per node, 4000 ms aggregate
  delay storage per plan, feedback at most 0.5, and at most four instances. Reverb is a compact fixed topology with two
  unequal feedback-comb paths and one scalar allpass diffusion stage per channel;
  requested predelay shifts both comb-path offsets. It has a 0.1–8 second nominal
  decay and at most two instances. Expander/gate is linked stereo and bounded to
  four instances; its detector is amplitude-based rather than note-, phoneme-, or
  source-aware. These are safety/resource bounds and declared control semantics,
  not proof of excellent settings or musical usefulness.
- The implemented de-esser is a deterministic linked split-band processor: a simple
  one-pole crossover isolates the upper band, a shared envelope controls upper-band
  gain, and the lower band remains at unity. It is not a multi-band dynamic EQ,
  phoneme-aware detector, or ML de-esser, and can attenuate desirable high-frequency
  material when it overlaps the detected sibilant band.
- Programmatic output-gain changes are smoothed over 10 ms. Scheduled immediate/ramp
  events for output gain are sample-offset-aware, persist across callbacks and are
  bounded to 256 events per callback. General graph-node automation remains commit/
  block based; sample-accurate events and smoothing for every node are unfinished.
  Host reset cancels an in-flight scheduled ramp, while bypass intentionally advances
  it invisibly and resets only graph DSP state. This distinction is implemented but
  still awaits fresh direct Logic automation testing.
- A callback retains one graph for its complete block, so concurrent publication
  cannot activate halfway through a callback. Publication can still cause a
  discontinuity at the next callback boundary because there is no graph crossfade.
- Capture is single-producer with atomic Float32 payloads, release/acquire frame
  publication, reserved overwrite guard frames, and bounded snapshot retry. Sustained
  host-load performance and callback timing still require Logic measurement. If a
  coherent snapshot cannot be obtained within the retry bound, capture fails closed
  rather than returning a mixed-time buffer.
- Recent capture retains at most 30 seconds and 24 MiB. High-rate stereo formats can
  therefore expose a shorter recent window; consumers must use the artifact's actual
  frame count rather than assume 30 seconds.
- Deallocation destroys the capture ring. Direct and IPC capture then fail, no IPC
  WAV is published, and reallocation starts empty. This prevents old audio from
  reappearing but means capture never survives host resource teardown.
- Only “analyze recent playback” is wired. Explicitly arming “capture the next
  playback” is not implemented.

## Analysis and intelligence

- BS.1770 Integrated Loudness, EBU Mode Short-term Loudness, Tech 3342 LRA, and
  sample-rate-aware approximate true peak are implemented. Fourteen official
  BS.2217-2 mono/stereo Integrated Loudness files pass at their ±0.1 LKFS tolerance,
  and four synthetic Tech 3342 LRA descriptions pass at ±1 LU. This is subset,
  closest-available evidence, not product certification. The Annex 2 FIR is used
  only at 48 kHz; other rates use a bounded windowed-sinc approximation. The EBU
  audio test set and complete official true-peak/advanced-layout suites were not
  run. LRA under 60 seconds is explicitly unstable and no loudness metric proves
  dynamics, quality, or a preferred master.
- Source-aware analysis v1 exists for explicit vocal, drum/drum-bus, bass, guitar,
  synth/keys, and full-mix contexts. It exposes bounded descriptive evidence for
  the requested production families, not automatic source identification, note/
  event separation, room estimation, perceptual masking models, phoneme-aware
  sibilance/plosive recognition, learned quality, or reference matching. Source
  labels, role, arrangement, monitoring and listening remain external context.
- Spectrum is averaged over time with a deterministic FFT, but mono fold-down can
  hide anti-phase content and descriptive bands do not prove boxiness, harshness,
  or sibilance.
- The 200 ms RMS/crest-factor and spectral-flux timelines are bounded descriptive
  series. They do not identify notes, phrases, drum hits, pumping, or musical intent.
- A provenance-tagged vocabulary covering all 28 requested production descriptors
  plus four explicit preservation concepts, and a typed source-aware hypothesis
  engine, are implemented. The offline fallback remains bounded keyword/alias
  matching; the cloud path uses provider-neutral free-form interpretation but is
  constrained to the checked-in vocabulary and current capability set. OpenAI
  Responses (`gpt-5.6-sol`) and Gemini Interactions (`gemini-3.6-flash`) now have
  credential-backed live evidence: six cross-provider cases each, plus Gemini's
  30-case cloud lane. A complete direct Gemini/Logic Pro 12.3 session now covers
  free-form interpretation, competing hypotheses, three distinct previews, typed
  revision and lock, exact commit, bypass/restore, save/reload, provider-offline
  graph recovery, instance isolation and unchanged source bytes. One strong preview
  disclosed a 1.655 LU residual because the conservative gain bound limited exact
  compensation. The 420-case corpus and live/generated-audio lanes establish
  structural and pipeline behavior, not open-domain semantic accuracy, perceptual
  correctness, artistic superiority, or general mix judgment.
- A separate generated catalog now grounds 14 common abstract phrases such as
  *expensive*, *bedroom-recorded*, *alive*, *emotionally boring*, *glued*,
  *three-dimensional*, and *human*. It supplies source-scoped possible senses,
  contradictions, non-DSP causes and clarification policy only when an exact
  reviewed phrase/alias is present. This improves bounded provider context; it does
  not prove those meanings, infer utterance role by itself, cover arbitrary
  paraphrases, or authorize a plan. Additional frontier runs and musician listening
  are still required to evaluate open-ended understanding beyond the bounded live
  cases.
- The four Logic 12.3 primary manuals have complete every-page documentary coverage
  (2,686 pages), including every Effects-guide family, all 35 Pedalboard stompboxes,
  Bitcrusher, every Instruments-guide family, the full User Guide, and every Control
  Surfaces-guide profile. A later audit found that the Instruments PDF links but
  omits Quick Sampler's standalone chapter; 16 canonical live-guide pages now close
  that documentary gap without rewriting the source contradiction. Generated
  advisory catalogs cover 142 effects/tools, 28 instruments/utilities, and 30 editor
  tools. This establishes documented controls, routing, workflows, caveats, and
  Apple-authored practice language—not proprietary algorithms, exact transfer/alias/
  phase/latency behavior, current hardware/firmware state, universal meanings for
  production adjectives, or artistic correctness. The deterministic 18-fixture
  measurement suite and 200-identity campaign define how to acquire that evidence.
  The campaign ledger currently records 189 `not_run`, 11 `partial`, and zero `complete`.
  Bitcrusher's partial direct Logic 12.3 run covers only its observed Default Preset
  on one 48 kHz mono amplitude fixture. Channel EQ's partial run covers its settled
  unmodified default, header bypass, and one 1000 Hz/+6 dB/Q1 bell state on that
  fixture, including deterministic save/reload and the PCM24 clipping boundary.
  Compressor's partial run covers the observed default, source-exact header bypass,
  and one Platinum Digital Peak/hard-knee 4.1:1 static curve, including settling and
  save/reload. First-transition renders exposed a settling hazard in the native-
  effect campaign. Remaining modes, bands, parameter grids, timing, detector
  isolation, frequency/phase/alias behavior, stereo, other rates, musical sources,
  automation, and listening remain open. Documentary
  review also grants
  no project, plug-in, automation, Accessibility, MIDI, file, Environment, or
  control-surface authority. Those require capability-specific implementation and
  direct empirical evidence.
- Context selection is deterministic and bounded. It uses lexical relevance plus
  source defaults to choose at most 10 vocabulary entries and 12 measurements, and
  exact reviewed phrase matching to choose at most three abstract-language
  advisories; an otherwise useful paraphrase or long-tail knowledge item can
  therefore be omitted. The frontier model may still interpret novel language, but
  it receives no invented advisory. Provider reasoning sees only the selected typed
  context and cannot observe arrangement or multitrack relationships unavailable at
  the insert.
- Current typed revisions resolve exact preview/snapshot/request/node identities and
  a bounded set of attribute-family merges. They do not infer arbitrary graph
  surgery, unsupported processing, or every possible conversational reference.
- Analysis pre-sanitizes NaN and infinity before all metrics. This prevents invalid
  JSON/measurements but does not reconstruct the missing signal represented by those
  samples.
- Preview matching uses gated BS.1770 loudness when at least one complete block is
  available and explicitly falls back to RMS for shorter captures. It is not a
  substitute for synchronized blinded listening.
- The native companion provides synchronized original/variant playback, waveform,
  level-match labels and change cards, but it loads all variants into memory and
  supports rewind rather than arbitrary waveform seeking. Pairwise collapse checks
  are threshold guardrails, not proof that variants are perceptually distinct.
- Current change cards expose enable/bypass and lock controls plus parameters and
  rationale. Per-card reset, removal, effect solo and advanced parameter editors are
  still target UX; a few removals are possible only through the narrow revision
  engine.

## LLM-first Tutor

- TrackSmith can read a bounded subset of currently visible Logic Accessibility
  attributes after macOS permission is granted. It still cannot enumerate or verify
  the complete channel strip, hidden plug-in state, selection, automation, routing,
  regions, or project structure, and it cannot confirm that the user performed a
  suggested edit. A visible label/value is evidence of that UI instant only.
- The optional observer requires the directly distributed companion to run outside
  App Sandbox; Apple forbids assistive-app Accessibility APIs in sandboxed apps. The
  AU remains sandboxed, and TrackSmith deliberately exposes no setters or actions,
  but this packaging tradeoff still needs an external security review before broad
  distribution.
- The analyzer is descriptive and not phoneme-aware. It cannot detect vowels,
  consonants, or nasality; measured statements are worded as consistent-with
  evidence and never as proof of a perceived quality's cause.
- Optional model audio listening is a separate OpenAI Chat Completions request,
  not a capability of the default text/reasoning model. It requires separate
  settings consent plus a per-turn Listen toggle, a live hash-bound capture, and a
  12 MiB cap. No capture can exceed 30 seconds; high-rate stereo captures may be
  shorter or too large. Model listening does not reveal Logic tracks, routing,
  inserts, settings, or audio outside the supplied excerpt.
- Cloud text and audio provider calls have mocked wire/consent/failure coverage in
  the new focused suite, but no new live-provider conversation or live model-audio
  listening session is claimed by source tests alone.
- Manual UI navigation is Logic-version-scoped (12.3) and documentary unless
  marked directly verified; an Apple UI change can invalidate a navigation
  card. The tutor invites "Can't find it" and never asserts a control exists.
- The exact-instruction procedure catalog remains deliberately narrow (8
  vocal-focused procedures, 18 steps). General Tutor v2 can return reviewed
  strategy guidance for much broader questions, but it still reports an honest
  no-safe-exact-procedure limitation when no reviewed Logic procedure exists.
- Vowel-specific or otherwise time-varying resonances have no safe exact
  manual procedure in the current validated knowledge; the tutor says so and
  records the requirement for Vocal Module v1 instead of improvising.
- Tutor advice remains source- and listening-dependent; feedback is the
  user's subjective judgment under their monitoring conditions. Level matching
  is by ear, not measured through the monitoring path.
- The Tutor model never performs Logic-native or TrackSmith graph edits. Its tool
  allowlist is read-only except for a presentation-only experiment formatter.
  Create/Vocal retain their existing user-controlled mutation paths behind
  **Future / Legacy**, but those APIs are never passed to the Tutor executor.
- Tutor v1 gate T7 is **CLOSED BOUNDED, NOT PASSED**, not pending. Its partial
  Logic Pro 12.3 exercise covered the signed UI and deterministic step flow but
  did not include the owner's real-lesson/perceptual evidence. Broad-tutor owner
  sessions and direct Logic validation remain pending under General Tutor gate
  GP8. Restored tutor sessions demote audio-grounded claims to historical.

## General Production Tutor v2

- Domain coverage is uneven. 458 claims and 78 strategies come from reviewed
  in-repo artifacts, so vocal, mix, and effects domains are far better covered
  than arrangement, MIDI expression, and mastering delivery.
- **No external source has ever been ingested.** No web fetch, no YouTube, no
  course material. The review pipeline is built and its refusal paths are
  proven, but nothing has flowed through it: every shipped claim derives from
  artifacts already in this repository. Research This exists in the UI only as
  an explicitly labeled not-built control.
- Personalization is implemented as a bounded, checksummed, atomic 0600 local
  profile with credential redaction, corruption quarantine, per-item forget,
  delete-all, and a human-readable export. It has not been validated with a real
  confirmed outcome, so its bounded ranking preference has never affected a real
  owner session.
- Retrieval is lexical. It has no synonym expansion beyond the curated cue
  lists, so unusual phrasing can retrieve weakly; coverage is reported rather
  than hidden, but a weak-coverage answer is still less useful.
- Strategy cards are decision patterns, not measured results. Most carry
  professional-practice evidence class and none has been validated against the
  owner's own material.
- The evaluation corpus (518 cases, 58 independently answered turns grouped under
  10 conversation IDs, and 10 retrieval-precision cases) is authored by the same
  process that built the knowledge. It demonstrates routing consistency and honesty
  invariants—not stateful dialogue memory or usefulness to a producer. Stateful
  memory is covered separately by the focused muddy → thin Tutor regression.
- **No owner session and no in-host validation of the broad tutor exist.** The
  decisive question — whether this beats opening a browser — is unanswered.
  GP0-GP7 pass; GP8 and GP9 remain pending and owner-blocked.

## State and operations

- Companion conversation, snapshot ancestry, previews, revisions, lock history and
  provider metadata now persist in a bounded checksummed local store. The store is
  not cloud-synced or a permanent audit ledger; it retains at most 200 turns, 120
  snapshots, 120 previews, 240 revisions, 500 lock events, 20 history files and a
  4 MiB envelope. Restore deliberately makes all state references view-only unless
  the current AU instance/runtime, capture, committed graph and conversation match
  exactly. Thus historical context survives restart, but old edits may correctly be
  unavailable for live application after Logic creates a new runtime.
- Validated plans are bounded to 32 nodes, 32 goals and 4 KiB per rationale, with
  additional temporal-node counts and total-delay-time limits. These limits prevent
  unbounded model output and cap the newly allocated temporal state, but they are
  not proof that every legal 32-node combination meets every host's deadline. The
  checked-in JSON Schema mirrors the item/resource limits and uses the
  extension `x-maxUTF8Bytes: 4096` because standard `maxLength` counts Unicode code
  points rather than encoded bytes; non-Swift consumers must honor that extension.
- Message IDs are collision-safe and identical repeats are idempotent at the file
  layer. Schema 1.1 commands also carry a monotonic per-runtime sequence and a
  maximum 60-second TTL; terminal replies must match command instance, runtime and
  legal reply kind. Applied command/plan IDs in heartbeats reconcile a lost
  acknowledgement, but there is no durable cross-restart idempotency/audit ledger.
  The AU's in-memory processed-command set is intersected with visible mailbox files,
  so it is bounded by the 2,048-file quota; once retention removes an ID, it is no
  longer durable replay evidence.
- A matching acknowledgement or application heartbeat means validation, compilation,
  and pointer publication succeeded. It does not prove that an audio callback has
  observed or emitted the new graph.
- The companion has a confirmed **Delete Local Audio Cache** action that removes all
  contents beneath the App Group capture and preview cache roots while retaining the
  roots, protocol diagnostics and AU state. There is no automatic expiry policy yet
  for those audio caches. Protocol state is bounded separately: default quotas are
  2,048 message files/32 MiB and 512 instance files. Each live command reserves a
  32 KiB terminal-response allowance and has a five-minute filesystem-age cap.
  Completed expired transactions are retained at least 10 minutes, other diagnostics
  24 hours, and stale instance
  files 10 minutes. Active discovery filters at five seconds. Retention is based on
  modification time, not an untrusted JSON timestamp, and no unexpired command is
  evicted for quota relief. A full mailbox therefore rejects new work until entries
  become eligible or the condition is resolved.
- IPC currently polls files rather than using a wake-up channel. Its latency and I/O
  behavior under many Logic instances and heavy projects are unmeasured. Each AU
  checks maintenance on a 60-second cadence and uses a cross-process advisory
  `flock` with a 500 ms acquisition bound; lock contention and abrupt process exit
  still require Logic-load testing.
- Captures are bound to the selected instance/runtime and their WAV sample rate,
  channel count and frame count must match the signed descriptor in addition to the
  SHA-256 hash. Message/artifact reads use `O_NOFOLLOW`, descriptor-based regular-file
  checks and canonical mailbox filenames. Capture publication still does not use a
  fully descriptor-relative `openat` chain, so a formal end-to-end TOCTOU-hardening
  pass remains.
- Commit-time safety re-renders and measures the exact candidate against its source
  after verifying origin, hash, WAV metadata, source snapshot, canonical materialized
  plan and expected current plan. It fails closed if output is nonfinite or its
  approximate true peak exceeds the plan ceiling. Objective guardrails catch
  mistakes; they do not establish subjective audio quality.
- Global bypass is persisted separately from the graph in AU `fullState` and is
  sample-exact for finite input. NaN/infinity is intentionally replaced with zero,
  so bypass is not bit-exact for invalid floating-point input.
- The complete companion capture-to-preview-to-revision-to-commit UI workflow was
  manually completed on the current signed AU in a disposable Logic project. The
  proof is one host/version/format workflow run, not a perceptual-quality study or a
  substitute for the still-open host matrix above.
- The real-audio evidence fixture is user-supplied and intentionally untracked; the
  repository has a SHA-256/measurement ledger but no redistributable real-performance
  golden file.
- The milestone's required source families have a deep relevant-source synthesis,
  but the corpus is not exhaustive and a new source cannot settle a decision merely
  because it was indexed. The immutable ingestion tool validates payload/provenance
  mechanics; license classifications, canonical replacement decisions, relevance,
  scientific quality, and interpretation still require human review. A valid file
  hash is not evidence that its claims are true.
- The license is all-rights-reserved pending an owner decision.
## Logic-native knowledge priority

TrackSmith has complete documentary identity coverage for Logic Pro 12.3's
reviewed effects/tools, but only 11 bounded partial direct-host transfer records
(Bitcrusher, Channel EQ, Compressor, DeEsser 2, Noise Gate, ChromaVerb, Space
Designer, Stereo Delay, Tape Delay, Adaptive Limiter, and Direction Mixer),
each limited to the exact accepted scope in its run record.
The next measurement lane remains explicitly focused on common core production
roles—gain/metering, expanded Channel EQ/Compressor, DeEsser 2,
Noise Gate, reverb, delay, saturation, limiting,
stereo/phase, and pitch—not on finishing every Pedalboard effect first. The
priority is a product/research judgment supported by curated-case recurrence; it
is not global usage telemetry.
