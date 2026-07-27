# Changelog

## 2026-07-27

- Completed the direct Logic Pro 12.3 frontier-AI acceptance lane with Gemini
  `gemini-3.6-flash`: a nonliteral vocal request produced validated typed intent,
  measured evidence, competing hypotheses, three distinct bounded-loudness-match
  previews, an identity-resolved natural revision, a locked EQ, capture-bound
  commit, bypass/restore, save/reload into a new AU runtime, provider-offline graph
  restoration, multiple-instance isolation, and unchanged source bytes.
- Fixed conversational revision persistence so a rejected working render cannot
  become successful history and an accepted revision records the exact
  post-render/recalibrated plan installed for audition and commit, rather than the
  pre-render proposal. The persisted snapshot, working preview, and live/reloaded
  AU graph now reconcile to the same canonical plan.
- Closed the current regression matrix: vector-backed `TestRunner` passed 68/68 in
  Debug, Release, and Thread Sanitizer; `AudioUnitHostProbe` passed Debug, Release,
  and Thread Sanitizer; the real-time heap interposer observed zero heap operations
  over 4,000 callbacks; the native Xcode build and installed strict signatures
  passed; and out-of-process `auval` succeeded through 192 kHz.
- Added dated direct-host and completion-audit evidence. Updated current
  architecture, capability, test, limitation, agent, data-flow, live-provider, and
  README status without rewriting historical Logic 11.2.2, deterministic Logic
  12.3, no-key sequencing, or earlier regression records.

## 2026-07-22

- Reconciled current Production Intelligence documentation with the credential-backed
  live evidence recorded on 2026-07-22: OpenAI `gpt-5.6-sol` and Gemini
  `gemini-3.6-flash` each passed six cross-provider source-aware cases, and Gemini
  passed the 30-case cloud lane. Historical no-key and pre-live-provider entries
  remain preserved as historical records. The remaining acceptance gap is the
  direct Logic Pro 12.3 frontier session through commit, save/reload, and offline
  playback, followed by the final regression checkpoint.
- Amended Production Intelligence v1 so no OpenAI, Gemini, or other cloud API key
  is required for completion. The required real semantic lane is now an on-device
  provider; cloud adapters and their Keychain/consent/privacy boundaries remain
  optional, fail-closed interoperability paths.
- Added an authoritative no-key milestone amendment that replaces only the former
  credential-backed provider and direct Logic acceptance clauses while preserving
  every deterministic DSP, semantic, state, host, safety, evaluation, and
  regression requirement.

## Unreleased - 2026-07-15

- Renamed the product TrackSmith while retaining the installed development app,
  AU display name, bundle identifiers, and component codes as explicit compatibility
  identities for this milestone.
- Added provider-neutral Production Intelligence contracts and adapters: deterministic
  offline `MockModelProvider`, OpenAI Responses, and Google Gemini Interactions. Both
  cloud adapters are companion-only, text/measurement-only, tool-free, stateless by
  request, explicitly consented, bounded for time/output/attempts, cancellation-aware,
  and locally tested against current official wire shapes. Credential-backed live
  provider evidence remains pending and is not inferred from mocked transports.
- Added a repeatable live-provider evaluation lane to
  `ProductionIntelligenceEvaluation`. Cloud runs require an explicit provider,
  consent flag and exactly one named case per process; use one attempt, read only the
  TrackSmith Keychain, and expose no CLI/environment credential path. Version 1.1
  evidence records bounded provider/model/response/usage metadata and all completed
  validation stages, while consent, credential, provider, validation, render and
  source-preservation failures exit nonzero with typed redacted categories. The
  offline ordinary one-case lane passes; consent-without-credential fails closed as
  expected. Added `VOC-FRONTIER-01`, whose nonliteral “intimate and expensive, but
  keep the breathiness” invariants deliberately expose the deterministic parser's
  missed semantic expansion and preservation constraint instead of scoring JSON
  validity as understanding.
- Added six ordered validation gates for untrusted provider output: decoding, schema,
  semantics, declared capabilities, typed state references, and constraints. Stale
  AU/capture results, invented metrics/capabilities, nonexistent identities, locked-
  node edits, contradictory preservation, malformed/oversized output, replayed
  response IDs, prompt injection, and implicit unlocks fail closed before planning.
- Separated the locally configured model alias from the bounded model identity
  reported by the authenticated provider response. The configured alias remains
  validation authority; the reported resolved/snapshot identity and response ID are
  retained only as evidence. Control-character identifiers, negative/unbounded token
  metadata and out-of-budget latency now fail schema validation. Durable turns and
  provider-evaluation cases also retain the complete six-stage validation audit.
- Expanded the compact companion rationale panel to show the validated desired,
  preserved and prohibited attributes; hypothesis outcome, strategy, first risk and
  listening boundary; relevant measured metric/value/unit/confidence/relationship;
  configured and provider-reported model identities; response/usage metadata; and
  completed validation gates. It exposes structured evidence, not hidden model
  reasoning.
- Added macOS Keychain provider credentials with when-unlocked, device-only
  accessibility; explicit cloud consent; ephemeral no-cache/no-cookie networking;
  typed missing/inaccessible/rejected credential failures; sanitized errors; and no
  credentials, raw audio, paths, file names, AU state, or executable plans in provider
  bodies or companion/AU persistence.
- Added bounded labeled context construction over relevant measurements, graph state,
  production knowledge, capabilities, limitations and prior revisions. Added durable
  versioned conversation state with atomic checksummed writes, redaction, bounded
  content-addressed history, corruption quarantine, explicit migration, and restore-
  time reconciliation that makes stale AU/runtime/capture history view-only.
- Deep-read six primary language/reference sources beyond their abstracts: the
  preference-role corpus, professional reference-song study, audio-effects ontology,
  word-to-EQ embedding experiment, electric-guitar semantic-timbre dataset, and
  MusicSem. Added a generated 14-entry abstract musician-language advisory catalog
  for phrases such as *expensive*, *bedroom-recorded*, *alive*, *emotionally boring*,
  *glued*, *three-dimensional*, and *blurry*. It supplies source-scoped competing
  senses, contradictions, non-DSP causes, preservation risks, and clarification
  policy as practice heuristics; it has explicit false node/host/measurement/
  constraint authority and remains behind the existing six validation gates.
- Added explicit preview/snapshot/request/node identities and typed multi-turn
  reference resolution, including bounded attribute merges, node lock/unlock/remove/
  restore, current-lock preservation, new plan identity, and ordinary validator/
  render/safety gates before any commit.
- Deep-read the relevant official Logic/AUv3 manuals, untouched ITU/EBU standards,
  compressor/intelligent-mixing papers, differentiable-DSP and automatic-EQ work,
  perceptual/listening-test methods, source-production practice, foundation/audio-
  language research, and the human-AI producer study. Added
  `TRACKSMITH_DEEP_SOURCE_SYNTHESIS.md` as a claim/contradiction/consequence record,
  including payload usability, hashes, exact sections, methods, assumptions,
  limitations, disputes, and prohibited overclaims.
- Completed an every-page review of the four immutable Logic 12.3 primary manuals:
  390 Effects pages, 752 Instruments pages, 1,324 User Guide pages, and 220 Control
  Surfaces pages (2,686 total). Added separate effects, instruments, workflow, and
  control-surface atlases covering every documented effect family, all 35 Pedalboard
  stompboxes, Bitcrusher, every instrument family, host workflow, Environment object,
  and supported control-surface profile. Manual contradictions and editorial defects
  are retained as provenance; native-tool knowledge is advisory and never grants the
  model plug-in, MIDI, automation, project, file, or control-surface authority.
- Closed a real source gap: Apple's 752-page Instruments PDF names and links Quick
  Sampler but omits its standalone chapter. Captured, quality-validated, uniquely
  hashed, and deeply read all 16 canonical Logic 12.3 Quick Sampler guide pages;
  retained the contradiction instead of treating PDF coverage as complete.
- Captured and deeply reviewed the complete Logic 12.3 section of Apple's mutable
  release-notes page through the fail-closed archive. Version-specific knowledge
  now includes Beat Breaker/Alchemy as well as AU scanning/UI, ARA, automation,
  bounce/export, Flex, routing, control-surface, sampler-state, and recording fixes.
- Added separate generated, source-hashed Production Intelligence catalogs for all
  142 reviewed Logic effects/pedals and 28 reviewed top-level instrument/utility
  identities. Bounded effect retrieval is source/intent aware; instrument retrieval
  requires an explicit name or alias so TrackSmith cannot infer an unobserved synth
  from recorded audio. Both catalogs expose only documented mechanisms, derived
  production consequences, listening limits, and `false` execution-authority flags.
- Replaced family-wide Pedalboard tie behavior with pedal-specific candidate
  semantics and musician aliases for all 35 pedals plus Mixer/Splitter. Regression
  cases now distinguish soft/full fuzz, tape echo, envelope filtering, ring
  modulation, and frequency-split parallel routing while retaining heuristic and
  listening-decisive evidence labels rather than fixed phrase-to-pedal presets.
- Propagated native empirical status into the typed provider context. Bitcrusher now
  carries its bounded partial run ID and claim-limited summary; the other effects
  remain explicitly `notRun`, exact implementation knowledge stays false, and no
  native tool gains processing-node, automation, or Logic-control authority.
- Added a generated 30-entry Logic editor-tool catalog covering every common and
  area-specific tool Apple lists, with focus, object, selection, snap/modifier,
  state-scope, conversion/destructive-file, and preservation risks. Retrieval
  requires explicit tool language and can never emit key commands, Accessibility
  actions, host mutations, or DSP.
- Added a fail-closed Logic knowledge coverage audit, an 18-file deterministic
  PCM24 measurement suite, a native-effect empirical protocol, and a 200-identity
  campaign ledger covering 142 effects/tools, 28 instruments/utilities, and 30
  editor tools. Every campaign entry begins `not_run` and can change only through a
  versioned, artifact-hash-validated direct-host run record; documentary completeness
  is explicitly not mislabeled as measured transfer or artistic proof.
- Added a reproducible, case-informed core-effect priority lane so deep mastery starts
  with the production operations most often needed in TrackSmith's 58 curated
  professional cases: gain/automation, EQ, dynamics/cleanup, ambience, saturation,
  limiting/metering, stereo/phase, pitch, and transient control. The first 20-effect
  queue and processor-specific empirical profiles are advisory—not global DAW usage
  telemetry or a fixed artistic order. Pedalboard, Bitcrusher, and other creative
  effects remain covered but no longer displace the common-production foundation.
  The same queue now generates a bounded semantic-match tie-breaker and provenance
  label for companion context. Typed source words and stopwords cannot masquerade
  as explicit effect identities, while a genuinely named effect or alias still wins.
  Evidence-specific repair/delivery tools now require sibilance, noise/gating,
  pitch, peak/delivery, or metering language rather than being inferred from broad
  descriptors such as *airy*, *controlled*, or *polished*.
  Added decision-level mastery cards for all 20 first-queue processors, including
  control consequences, source-specific hypotheses, competing strategies,
  contraindications, preservation/stopping rules, manual contradictions, and
  prohibited overclaims.
- Added an immutable local-course review ledger for eight legally held production
  videos, including complete file hashes, durations, rights boundaries, quarantine
  state, chapter routing, and a text-free transcript-index contract. Machine
  transcripts are navigation aids only; no course claim enters production knowledge
  until the relevant audiovisual section is reviewed and cross-checked against
  primary Logic 12.3 or DSP sources.
- Recorded the first partial native-effect run in Logic 12.3 build 6674: Bitcrusher's
  observed 48 kHz mono Default Preset. Three settled bypass renders match the fixture
  PCM exactly; three settled active renders plus a post-save/reload render share one
  decoded-PCM hash. Retained first-transition active/bypass artifacts showed that the
  first render can differ briefly, so the protocol now requires settled repeatability.
  Added a second partial direct-host run for the higher-priority Channel EQ lane.
  Three settled unmodified-default renders and three settled header-bypass renders
  match the 48 kHz mono fixture PCM exactly. A 1000 Hz/+6.0 dB/Q1 bell measured
  approximately +6 dB on every unclipped ladder step, repeated with identical PCM
  three times, and survived save/reload. A new segment-aware amplitude-ladder
  analysis prevents PCM24 export clipping from masquerading as reduced EQ gain.
  Added a third partial run for the higher-priority Compressor lane. Its exact
  observed default repeated but was not neutral because Auto Gain -12 dB was active;
  three header-bypass renders matched source PCM. One Platinum Digital Peak/hard-
  knee state at threshold -20 dB and ratio 4.1:1 matched the public static-curve
  relation within 0.000128 dB above threshold. Stabilized and post-reload renders
  matched exactly; the first controlled render differed only at samples 1-1022.
  Rejected wrong-rate/import-range and metronome-contaminated setup attempts now
  harden the protocol's baseline gate. The campaign is 197 `not_run`, three
  `partial`, and zero `complete`; remaining grids, modes, timing, rates, stereo,
  musical material, and listening dimensions are open.
- Added EBU Mode 3-second Short-term Loudness and Tech 3342 Loudness Range with the
  reference gates, power mean, percentile indexing, virtual tail, LU units, and an
  explicit `unstableBelowSixtySeconds`/insufficient-duration state. Four synthetic
  Tech 3342 minimum cases and 14 official BS.2217-2 Integrated Loudness vectors pass.
- Added typed, versioned source-aware analysis for vocal, drums/drum bus, bass,
  guitar, synth/keys, and full stereo mix. Metrics carry units/ranges, confidence,
  applicability, aggregation/window behavior, failure modes, version, and research
  or practice provenance instead of emitting single-metric semantic verdicts.
- Added all 28 requested provenance-tagged, source-conditioned production descriptors
  plus four explicit preservation concepts and a typed intent -> evidence ->
  competing hypothesis -> validated editable plan
  layer. Eight required source-specific workflows pass, including preservation and
  prohibited-change constraints; no LLM receives or emits raw DSP parameters.
- Expanded the semantic evaluation corpus to 420 cases across all six source classes,
  spanning ordinary and abstract musician language, ambiguity, contradictory and
  preservation constraints, unsupported/source-inappropriate requests, multi-turn
  references, named-style language, prompt injection, malicious context, and
  malformed provider output, with invariant-based assertions.
- Added a generated-audio Production Intelligence runner. Thirty locally synthesized,
  provenance-hashed cases (five per source class) produced 90/90 valid, pairwise-
  distinct, locally rendered, level-matched previews while preserving every source
  file byte-for-byte. This is offline-provider pipeline evidence, not proof of
  frontier semantics or artistic superiority.
- Replaced the unsafe archive-download pattern with an immutable research-ingestion
  contract/library/CLI: exact HTTP completion and media validation, file-quality and
  HTML-shell rejection, SHA-256 content addressing, duplicate reuse, quarantine,
  append-only history, explicit version/supersession, rights/local-use metadata, and
  clean pinned Git origin/commit validation. User-supplied artifacts are never
  overwritten.
- Completed a separate Logic Pro 12.3 (build 6674) real-host lane on macOS 26.3
  without changing the historical 11.2.2 evidence: discovery/insertion, playback,
  descriptor-bound recent capture, three previews, graph inspection, locked-EQ
  compression revision, commit, bypass/restore, save/reload, unchanged source hash,
  and two-live-instance targeted routing isolation all passed. Added an exact
  hash/ID/signing evidence ledger.
- Expanded `TestRunner` to 68/68 Debug and Release checks with the official vectors
  (67/67 without them); the ordinary Thread Sanitizer lane passes 67/67. Fresh AU
  host Debug/Release/TSan,
  `auval`, and 4,000-callback heap-interposer lanes pass; the Release host measured
  9.2 us mean, 9.4 us p99, and 37.0 us max, and the interposer observed zero heap
  operations across 4,000 callbacks (9.2 us mean, 10.0 us p99, 28.0 us max).
  Added an exact installed-bundle fingerprint/signing and closing regression report;
  the credential-backed direct Logic AI lane remains explicitly pending.

- Hardened App Group command/reply delivery with schema 1.1 bounded command TTLs,
  per-runtime monotonic command sequences, terminal-response capacity reservation,
  strict instance/runtime/kind correlation, hard command-file expiry, nonblocking
  bounded mailbox locking, canonical filenames, descriptor-based regular-file reads,
  and queued terminal-reply retry in the AU utility queue. Expanded the portable
  suite to 42 checks and fixed restart sequencing in the production host probe.
- Re-ran the current real-vocal vertical slice, Debug/Release/Thread Sanitizer
  suites, custom AU host probe, signed Release install, strict signature checks, and
  `auval`; then completed and recorded the current signed AU's full disposable-project
  MVP workflow in Logic Pro 11.2.2.
- Proved current-build Logic insertion/playback, hashed recent capture, three distinct
  level-matched previews, graph inspection, locked-EQ targeted revision, commit,
  internal bypass/restore, project save/reload, unchanged source files, companion
  reconnection, and two-instance command isolation. Added a hash- and ID-ledgered
  Logic evidence record without expanding the result to untested host modes.
- Added a thread-local development heap interposer covering standard, aligned, and
  macOS zone allocation/free entry points. The Release AU host probe now fails on any
  measured callback heap operation; 4,000 representative 128-frame callbacks passed
  with zero operations. It also exposed and moved AVFAudio's lazy host-side ABL
  wrapper allocation outside the measured callback boundary.

- Materialized preview loudness compensation into each saved graph so audition,
  offline re-render, AU commit, and project reload use the same deterministic plan.
- Added a real-audio vertical-slice runner and redacted evidence ledger proving
  three distinct level-matched vocal previews, exact selected/revised renders,
  locked-node preservation, typed undo/redo, sample-exact dry bypass, and unchanged
  external source bytes.
- Added capture-bound commit preflight: instance/runtime identity, source snapshot,
  SHA-256 and WAV metadata, canonical materialized plan, expected-current-plan
  compare-and-swap, fresh render, finite/peak validation, and post-apply heartbeat
  reconciliation.
- Added deterministic “use less compression” revision previews, editable node locks
  and bypass controls, exact commit, undo/redo, and a graph-independent global
  bypass persisted in AU `fullState`.
- Hardened the real-time path with verified lock-free atomics, bounded capture
  allocation, atomic graph publication, activation reset generations, finite-input
  sanitation before capture/bypass/DSP, typed infrastructure failures, and safe dry
  recovery for corrupt state or publication exhaustion.
- Expanded `AudioUnitHostProbe` to cover two isolated instances, revision commit,
  lock preservation, undo/redo, acknowledgement loss, full-state reload, global
  bypass/reconnect, nonfinite input, callback timing, and offline/AU sample parity.
- Expanded the portable harness to 42/42 checks in clean Debug and Release builds;
  both it and the expanded host probe also pass under Thread Sanitizer in the
  recorded development environment.
- Made companion commit an AU-lifecycle-locked compare-and-swap across expected
  captured snapshot, graph, locked-node validation, captured/current rate and
  channel format, graph publication, and serialized plan state. Added HostProbe
  controls for snapshot mismatch, stale-CAS, format-change and deallocated commit
  rejection.
- Made capture lifetime match render-resource lifetime: deallocation clears capture,
  deallocated IPC requests fail without publishing a WAV, and a new allocation
  starts empty so old playback cannot reappear.
- Bound a real-time graph's final sample-limiter ceiling to its declared
  `maxTruePeakDB` constraint, while retaining the explicit limitation that a sample-
  peak limiter cannot guarantee live inter-sample dBTP.
- Synchronized `processing-plan.schema.json` with the runtime 32-goal/32-node limits
  and normative 4,096-byte UTF-8 rationale bound; added an automated parity check.
- Audited all ten supplied research archives: 125/125 members match their extracted
  counterparts. Review depth is recorded honestly as 20 Core/full-text, 33
  Supporting, and 8 Peripheral among 61 unique PDFs; indexing is not represented as
  deep review.
- Made development installation remove Xcode's transient derived-data plug-in
  registration and explicitly register only the strict-verified installed AU.
- Kept companion bypass/restore bound to the captured AU runtime even when sidebar
  navigation changes, and prevented stale asynchronous operations from cancelling a
  newer capture or working-plan render.
- Rejected sample-rate-incompatible EQ frequencies instead of silently clamping the
  executed filter, and extended preview rejection to explicit general-harshness as
  well as cymbal-harshness constraints.
- Added a confirmed companion privacy action and tested exchange operation that
  deletes all App Group capture/preview audio while preserving protocol diagnostics
  and AU project state.
- Aligned the actual processing-plan wire format with the checked-in JSON Schema by
  encoding node parameters as keyed objects; legacy alternating-array state remains
  decodable for project and preview migration.

## 0.1.0 - 2026-07-12

- Created the native Swift package and generated Xcode project.
- Added a versioned plan schema and fail-closed validator.
- Added deterministic gain, polarity, high/low-pass, parametric EQ, compression,
  saturation, stereo width, and limiting kernels.
- Added a lock-free bounded capture ring and initial signal analysis.
- Added immutable snapshots, transactions, deterministic planning, revisions,
  three-way preview rendering, and level matching.
- Added WAV analysis/offline-render tools, IPC probes, and a release test runner.
- Added a transactional prompt-to-three-WAV preview workflow, PCM24/PCM32 input,
  per-variant plan/manifest export, and deterministic demo-audio generation.
- Fixed macOS hidden flags propagating from the preview staging directory.
- Added ITU-R BS.1770-5 gated programme loudness and Annex 2 true-peak analysis,
  with calibration, gating, inter-sample peak, and preview-matching tests.
- Replaced first-window spectral analysis with time-averaged FFT descriptors for
  rolloff, flatness, slope, bands, positive flux, and transient density.
- Made compressor recipes source-level- and crest-aware, widened preview strengths,
  and exported objective preview-difference warnings and matching provenance.
- Added a hash-deduplicated research workflow and disposition catalog for 61 unique
  supplied PDFs; archive/index coverage and full-text review depth are tracked
  separately.
- Added a directly buildable native audition app with synchronized AVAudioEngine
  A/B switching, waveform, keyboard control, measurements, and processing cards.
- Added a fail-closed preview-session loader that verifies artifact containment,
  saved plans, snapshot IDs, variant uniqueness, and WAV format consistency.
- Added initial AUv3 and SwiftUI scaffolds.
- Installed Xcode 26.6 support and compiled/locally signed the native containing app
  and AUv3 extension with metadata aligned to Apple’s current template.
- Added allocation-free borrowed host-buffer DSP with offline parity tests, dry
  failure behavior, format-aware capture, live input peak, and compact gain UI.
- Added atomic Float32 capture payloads plus overwrite guard storage for safe
  non-real-time snapshots during continuous playback.
- Added `AudioUnitHostProbe` covering 44.1 kHz mono and 96 kHz stereo render,
  serialized graph execution, dry capture, AU parameters, and `fullState` restore.
- Diagnosed failed system discovery as a Team-ID-less ad-hoc signature and changed
  development installation to require and verify matching Apple Development Team
  signatures for the containing app and extension.
