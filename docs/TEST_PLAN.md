# Test plan

## Automated command

```sh
swift run -c release TestRunner
```

On 2026-07-27 the frozen Production Intelligence v1 baseline passed 68/68 checks
in Debug, Release, and Thread Sanitizer when the 14 selected official BS.2217-2
vectors were supplied; the later 72/73- and 83-check results remain historical
evidence for their dated harnesses. The frozen pre-Vocal baseline at commit
`406b446` declares 91 ordinary checks plus one optional official-vector lane (92
possible when `TRACKSMITH_BS2217_VECTORS` is enabled).
Coverage
includes: plan
round-trip, keyed-object parameter wire format and legacy-state migration, bounds
and complexity rejection, locked-node protection, bypass identity,
sample-limiter release/reset, gain smoothing reset, soft-clip/nonfinite safety,
split-band de-esser high-band attenuation with low-band preservation,
versioned expander/gate hold/hysteresis/range/link/reset, exact feedback-delay
timing/crossfeed/reset, bounded algorithmic-reverb decay/tail/rate/reset, temporal
resource budgets, borrowed-pointer/offline parity including all three new nodes,
dry layout failure, five rates
by six buffer sizes, Float32/PCM24 WAV round-trip and malformed-rate rejection,
known sine/noise spectrum analysis, bounded level-invariant 200 ms dynamics
timelines, BS.1770 997 Hz calibration, relative gating, inter-sample true peak
detection across supported rates, nonfinite-input sanitation,
capture wrap chronology and fail-closed snapshots, three variants/revision,
targeted revision lock/unrelated-node preservation, adversarial prompt rejection,
level matching, exact persisted audition graph, structural peak safety, pairwise
sibling-preview difference, transactional audible export with source-byte
preservation, long-preview BS.1770 matching, snapshot undo/redo, idempotent IPC
message round-trip, capture/preview cache deletion with protocol-message retention,
corrupt-message/unsafe-artifact rejection, mailbox retention and fail-closed
message-file quota behavior, captured-instance
binding, artifact WAV metadata matching, commit preflight rejection before IPC,
lost-acknowledgement heartbeat reconciliation, correlated capture/commit with
fail-closed commit-time peak validation, final sample-limiter/declared-peak
consistency, and checked-in schema parity with runtime 32-goal/32-node/4,096-byte
UTF-8 rationale bounds. The same suite rejects an EQ frequency that cannot be
represented truthfully at the active sample rate and rejects excessive high-band
growth under an explicit general-harshness constraint.
The export check also validates safe session reload and rejects a manifest path-
traversal attempt.

The expanded checks add EBU Mode 3-second Short-term Loudness, Tech 3342 LRA and
short-content reliability, official Integrated Loudness vectors, typed source-aware
analysis across all six source classes, stereo/mono-direction evidence, all 28
requested production descriptors plus four explicit preservation concepts, eight
required evidence-to-editable-plan flows, planner
safety/source-boundary checks, expansion and assertion of the 420-case semantic/
adversarial corpus, provider-neutral OpenAI/Gemini wire contracts, six-stage model
validation, provider failure/cost/replay/staleness behavior, bounded context,
generated 14-entry abstract musician-language catalog integrity and exact bounded
retrieval, explicit no-node/no-host/no-measurement/no-constraint authority,
durable conversation migration/corruption/reconciliation, typed conversational
references, structurally distinct competing hypotheses, immutable research
publication/quarantine/version history, and clean pinned Git checkout enforcement.
General Tutor v2 additionally covers open-ended routing without an issue-enum
match, knowledge/provenance validation, grounded-answer and unsupported-authority
refusals, measurement-relevance honesty, bounded local personal-profile
persistence/deletion, and rejection of generalized personal results.

The 2026-08-08 frozen pre-Vocal Debug and Release ordinary runs pass 91/91.
An isolated Release/Thread Sanitizer run with
`TRACKSMITH_BS2217_VECTORS` set to the local directory containing the 14 official
BS.2217-2 vectors passes 92/92 with no sanitizer report. This is evidence for the
exercised paths, not proof that all possible races or real-time allocations are
absent. The older 2026-08-02 72/72 ordinary and 73/73 vector-enabled results remain
dated historical evidence rather than current harness counts.

The repository retains a dependency-free executable harness so the core can run in
CI and on Command Line Tools-only machines. `make native-verify` additionally builds
the Xcode targets and runs `AudioUnitHostProbe`; migrate appropriate checks into
XCTest without removing this release harness.

## Production Intelligence lanes

The common provider harness runs the same normalized typed input through any
`ModelProvider` and records structured-output validity, semantic expectations,
constraint preservation, ambiguity behavior, reference resolution, unsupported-
capability hallucination, latency, attempts, token metadata, and typed failure
category. It separately records the configured model alias, bounded provider-
reported resolved model identity and provider response ID. Unit transports cover
the current OpenAI Responses and Gemini
Interactions wire contracts without spending credentials or relying on network
availability. These tests are not a substitute for direct host evidence; record
the exact adapter/model and bounded usage metadata for every live run. Credential-
backed provider evidence now exists in the dated cross-provider and Gemini cloud-30
reports. The complete direct Logic Pro 12.3 host acceptance case now exists in
[`LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md`](evidence/LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md).

The context regression separately verifies that *expensive* can seed relevant
canonical term/evidence retrieval, *bedroom-recorded* and *clean without
sterilizing* retain separate preservation interpretations, and malicious language
beside an abstract phrase cannot create another `AVAILABLE_CAPABILITY` section.
The offline keyword provider is intentionally not credited with general abstract
language understanding.

The semantic corpus expands source templates into 420 cases and asserts invariants
rather than one wording. The generated-audio lane is reproducible with:

```sh
./scripts/run-production-intelligence-evaluation.sh \
  --provider mock \
  --output .build/evidence/production-intelligence-offline-30of30-2026-07-14
```

Use the runner even for local/offline evaluation. It signs the rebuilt SwiftPM
executable with TrackSmith's stable development identity before launch. Invoking
the raw `.build` executable bypasses that step; cloud runs would then present a
new ad-hoc Keychain identity after rebuild and can repeatedly ask for access.

The recorded offline run passed 30/30 cases (five per source class), with exactly
three valid pairwise-distinct previews per case and unchanged source bytes. Its
provider was `mock-offline-1 / deterministic-intent-v1`; therefore it proves local
pipeline coherence, not frontier semantics or artistic quality. The subsequent
live reports record OpenAI `gpt-5.6-sol` and Gemini `gemini-3.6-flash` results over
the same typed downstream path. See
[`evidence/PRODUCTION_INTELLIGENCE_GENERATED_AUDIO_2026-07-14.md`](evidence/PRODUCTION_INTELLIGENCE_GENERATED_AUDIO_2026-07-14.md).

The same executable now provides a fail-closed live-provider lane. Cloud mode
requires one explicit case per process, an explicit consent flag, one attempt, and a
credential already stored under TrackSmith's macOS Keychain service. It intentionally
has no API-key argument or environment-variable fallback:

```sh
./scripts/run-production-intelligence-evaluation.sh \
  --provider openai \
  --cloud-consent \
  --case VOC-FRONTIER-01 \
  --output .build/evidence/production-intelligence-openai-voc-frontier01-YYYY-MM-DD
```

The command exits nonzero for missing consent, missing/rejected credentials, provider
failure, validation rejection, or an unsafe/unrenderable case. Its version 1.1 evidence
records the provider descriptor, configured and provider-reported model identities,
response ID, attempts, latency, bounded token usage, six completed validation stages,
typed interpretation, hypotheses, preview measurements, and source hash—never a
credential, header, raw provider body, raw audio upload, filename context, or hidden
reasoning. A Gemini invocation uses the same downstream schema with `--provider gemini`.
`VOC-FRONTIER-01` uses “Make this vocal feel more intimate and expensive, but keep
the breathiness.” It requires `intimate`, preservation of `airy`, and at least one
bounded interpretation of “expensive” among `polished`, `clear`, `controlled`, or
`warm`. The deterministic parser currently fails this invariant: it finds `intimate`
but neither expands “expensive” nor preserves breathiness. That failure is the live
provider's semantic baseline, not a reason to weaken the expectation.

The closing milestone retains the live-provider reports and a separate direct
Logic 12.3 AI report covering a genuinely free-form request, typed interpretation/
evidence/hypotheses, three previews, natural typed revision, lock/constraint
preservation, commit, bypass/restore, save/reload, provider-offline graph playback,
multiple-instance isolation, and unchanged source hash. The strong preview's
loudness compensation was safety-limited and is explicitly reported rather than
called an exact match. Existing deterministic Logic 11.2.2/12.3 reports remain
historical and were not rewritten as frontier evidence.

## Logic-native documentary and empirical knowledge lane

Regenerate the abstract musician-language advisory catalog after changing its
reviewed ontology, then verify the checked-in Swift payload is exact:

```sh
python3 research/scripts/build-production-language-knowledge.py
make production-language-knowledge-check
```

The generator rejects unknown source types, executable terms, unsupported
strategies, missing source senses, duplicate identifiers, and malformed evidence
fields before publishing generated code.

Regenerate and fail closed on the complete source/catalog/campaign chain:

```sh
python3 research/scripts/build-logic-manual-index.py
python3 research/scripts/build-logic-effects-knowledge.py
python3 research/scripts/build-logic-instrument-knowledge.py
python3 research/scripts/build-logic-editor-tool-knowledge.py
python3 research/scripts/build-logic-native-empirical-campaign.py
python3 research/scripts/audit-logic-12.3-knowledge-coverage.py
```

The audit must retain four immutable manual hashes/2,686 pages, 142 effect/tool
identities, 35 Pedalboard effects plus Mixer/Splitter, 28 instrument identities,
16 unique accepted Quick Sampler supplement hashes, 30 editor tools, and the dated
Logic 12.3 release-notes hash. It must fail if an unexecuted empirical item is
marked complete.

Generate the 18-file PCM24 diagnostic suite twice and require byte identity:

```sh
swift build --product TestSignalGenerator
.build/debug/TestSignalGenerator --logic-measurement-suite tmp/logic-measurement-a
.build/debug/TestSignalGenerator --logic-measurement-suite tmp/logic-measurement-b
diff -rq tmp/logic-measurement-a tmp/logic-measurement-b
```

Native render evidence must follow
[`LOGIC_NATIVE_EMPIRICAL_MEASUREMENT_PROTOCOL.md`](LOGIC_NATIVE_EMPIRICAL_MEASUREMENT_PROTOCOL.md),
including exact host/build, channel format, preset/all parameters, sample rate,
tempo, routing/gain, render mode, repeated outputs, input/output hashes, unchanged
source proof, measurement method/uncertainty, and listening boundary. Documentation
or fixture generation alone must never change a campaign item from `not_run`.
For an amplitude-ladder render, rerun
`research/scripts/analyze-logic-native-render.py --amplitude-ladder` and verify
each declared input segment separately. A whole-file gain value must not be used
as a processor gain claim when any segment reaches the export ceiling. The
Channel EQ evidence lane is the regression fixture for transparent default/bypass,
three-repeat PCM identity, per-level +6 dB behavior, clipping counts, and post-reload
identity. The Compressor lane separately checks an exact same-path baseline,
source-exact header bypass, the non-neutral observed Auto-Gain default, one Peak/
hard-knee 4.1:1 static curve against the public relation, the first-transition
sample boundary, settled repeatability, split-channel equality, source preservation,
and post-reload PCM identity. Both run records carry bounded
`measurementAssertions`; the main coverage audit resolves those JSON paths against
hash-ledgered artifacts and fails closed on a missing artifact, changed value, or
out-of-range measurement.

## Required expansion

- DSP: analytic biquad response, impulse/sweep/noise, compressor transfer and time
  constants, smoothing/automation, repeated bypass/reset, denormal timing, latency,
  mono/stereo independence, randomized invalid/nonfinite plans.
- Analysis: remaining sample-rate loudness vectors, known hum/noise floor/envelopes/onsets,
  stereo frequency-dependent phase, tolerances for every declared metric.
- Golden audio: generated fixtures only, tolerant numeric comparisons, metric diff,
  documented intentional baseline updates.
- Agent: broader perceptual adjudication, long conversational sequences, multi-
  provider live semantic evaluation, locked-limiter edge cases, version-node merges,
  and prompt injection from every future metadata field.
- State: additional migration versions, branch-history UX, partial preview cleanup,
  IPC interruption at every transaction state, cross-restart command idempotency/
  audit ledger, acknowledgement after
  render observation, artifact/audio-cache expiry, retention-boundary clock tests,
  aggregate-byte and instance-quota saturation, concurrent multi-process lock
  contention, and abrupt-process-exit behavior while holding/waiting for the
  mailbox lock.
- Performance: broader heap/VM instrumentation, release callback percentiles and
  deadline misses at all formats under Logic load, module/graph CPU, memory stability,
  analysis/preview latency, app/UI responsiveness. The representative custom-host
  callback now has a standard/aligned/macOS-zone heap interposer gate.

## Native Audio Unit probe

```sh
make native-verify
```

`AudioUnitHostProbe` registers the production AU class in-process and tests 44.1 kHz
mono plus 96 kHz stereo noninterleaved rendering, serialized graph execution,
parameter gain, bounded dry capture, live atomic graph publication, `fullState`
restoration, and the explicit mono-to-mono/stereo-to-stereo capability declaration.
It additionally drives heartbeat discovery → recent capture → SHA-256-verified WAV
artifact → three previews → exact balanced commit → EQ lock → “use less compression”
revision → exact revision commit → undo/redo → `fullState` reload → independent
global bypass/reconnect/restore → bit-exact dry revert. It also tests two-instance
command/audio/state isolation, nonfinite bypass sanitation, graph reactivation reset,
publication exhaustion recovery, concurrent reset stress, and lost-acknowledgement
reconciliation. It additionally proves capture teardown/reallocation, IPC failure
without an artifact while deallocated, rejection of actual 1→2 and 2→1 resource
allocations, and lifecycle-locked commit controls for stale expected graph, changed
sample rate and deallocated resources. A separate control rejects a captured-
snapshot mismatch inside the same AU transaction. Each failed commit preserves the
live graph and serialized state. This proves the class and local session contracts.

Current probe source adds cases for the native `shouldBypassEffect` route, static
180-second/-120 dB `tailTime`, maximum-bound feedback decay, null output `mData`, upstream replacement of pull-input
pointers, undersized/oversized host layouts, maximum-frame validation, defensive
zero input for upstream silence, clearing a potentially false outgoing silence hint,
sample-offset output-gain events, ramps spanning callbacks, host-reset cancellation
of automation, bypass preservation of the automation timeline, programmatic takeover
through the de-zipper, and concurrent graph publication without a mid-block graph
split. Current Debug, Release and Thread Sanitizer HostProbe runs pass these cases.

The latest custom-host callback timing at 48 kHz/128 frames was 9.2 us mean, 10.0 us
p99 and 30.0 us maximum in Release against a 2,666.7 us deadline. The expanded probe
also exits cleanly under Thread Sanitizer. A separate thread-local DYLD interposer
run covered standard, aligned and macOS zone heap entry points and reported
`RT_HEAP callback iterations=4000 operations=0`; under instrumentation it measured
9.2 us mean, 9.9 us p99 and 78.4 us maximum. These are not Logic-load results.

Separately, the current Apple-development-signed sandboxed Release passed
`auval -v aufx LgAA ExAI` out of process across mono/stereo, 11.025–192 kHz and host
render sizes through 4096 frames. Its output retained only a `CurrentPreset`/
`PresentPreset` deprecation warning. An earlier run emitted a non-failing transient
1-input/2-output warning from the legacy proxy negotiation path; it did not recur in
the recorded run and was never evidence that asymmetric resources allocate. The
focused production-class probe rejects actual 1→2 and 2→1 allocations. Neither proof
establishes Logic project behavior; the `auval` proof is current source.

## Real-audio vertical slice

`VerticalSliceCLI` ran against an external user-owned 10.94-second vocal and wrote a
redacted, hash-verifiable proof directory. All 18 assertions passed: three valid and
pairwise-distinct loudness-matched previews, deterministic plan/audio equivalence,
locked-EQ and unrelated-node preservation during “use less compression,” exact
selected/revised application, typed undo/redo, sample-exact dry bypass and unchanged
source SHA-256. See
[`evidence/MVP_VERTICAL_SLICE_2026-07-13.md`](evidence/MVP_VERTICAL_SLICE_2026-07-13.md).
The user audio and generated WAVs are not committed and this offline runner does not
prove a live AU or Logic commit.

## Perceptual release tests

Follow ITU-R BS.1534-3 discipline where an impairment reference exists: listener
training, hidden reference, meaningful anchors, randomized conditions, identical
loops, documented reproduction, and power-aware statistics. Creative production
tests additionally rate target success, preservation, naturalness, clarity,
production value, and excitement separately. Use level-matched blinded conditions,
hidden duplicates, raw-distribution plots, medians/IQRs, effect sizes, confidence
intervals, and corrected pairwise comparisons. Full rationale is in the research
synthesis.

## Host matrix

Direct Logic testing on 2026-07-13/14 completed the current signed build's MVP on a
disposable 44.1 kHz stereo runtime: insertion/playback, companion discovery, verified
recent capture, three previews, graph inspection, locked-node targeted revision,
commit, internal bypass/restore, save/reload of the exact graph and lock, unchanged
source hashes, companion reconnect, and two-instance command isolation. The exact
record is
[`evidence/LOGIC_MVP_VALIDATION_2026-07-14.md`](evidence/LOGIC_MVP_VALIDATION_2026-07-14.md).
A separate Logic Pro 12.3/build 6674 lane on 2026-07-14 repeated the required
workflow at 44.1 kHz mono using an exactly fingerprinted installed AU: direct
discovery/insertion/playback, a 661,500-frame descriptor-bound capture, three
distinct previews, graph inspection, locked-EQ compression revision, commit,
internal bypass/restore, save/reload into a new instance/runtime, reloaded playback,
unchanged external-source SHA-256, and targeted bypass/restore isolation between
two live AU instances. See
[`evidence/LOGIC_12_3_VALIDATION_2026-07-14.md`](evidence/LOGIC_12_3_VALIDATION_2026-07-14.md).

On 2026-07-27 a separate frontier-AI Logic Pro 12.3 lane used Gemini
`gemini-3.6-flash` for a free-form vocal request, retained typed evidence and two
competing hypotheses, rendered three distinct bounded-loudness-match previews,
resolved a natural preview/node-lock revision, committed the exact post-render
graph, bypassed/restored it, and saved/reopened it into a new AU runtime without
provider availability. The source hash was unchanged and a second instance
retained its independent graph. See
[`evidence/LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md`](evidence/LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md)
and the final matrix in
[`evidence/PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md`](evidence/PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md).

This does not mark buses/stereo output, freeze/bounce, low-latency mode, general
automation, every sample-rate/buffer combination, large-project load, or sustained
many-instance stress as passed. Track macOS, Logic, hardware, app version, signing
identity, format, buffer, channel, insertion scope, low-latency/offline mode,
instances, result, logs, and saved-project fixture hash for every additional case.

During earlier permission/Computer Use testing, Logic displayed an instability alert
but recovered; the test insert was undone and no plug-in crash report was present.
`SkyComputerUseService` did crash. The subsequently fixed off-thread AU lifecycle/
status race was a plausible contributor, not a proven root cause. The current MVP
rerun completed without recurrence, but any future recurrence remains a failed case.

Exact procedures are in `MANUAL_LOGIC_TESTS.md`. A generated Xcode project is not a
host test, and `auval` success is not equivalent to Logic workflow success.
