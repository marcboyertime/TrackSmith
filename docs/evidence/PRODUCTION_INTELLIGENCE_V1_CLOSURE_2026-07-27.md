# TrackSmith Production Intelligence v1 closure audit

Status: **all milestone implementation and proof gates passed for their declared
scope**
Audit date: 2026-07-27
Source commit before documentation-only closure:
`97d52ea6023af2b79188b966f4f0b77211f5c557`

## Proof boundary

This audit maps the Production Intelligence v1 completion criteria to direct
current evidence. “Passed” means the named implementation and exercised proof
exist; it does not expand a narrow test into a general artistic, provider,
real-time, or Logic compatibility claim.

Historical Logic 11.2.2, deterministic Logic 12.3, earlier automated regression,
and no-key sequencing records remain unchanged. The current credential-backed
provider and direct Logic evidence supersede only their earlier “pending” status.

## Final regression checkpoint

| Lane | Current result |
|---|---|
| `TestRunner` Debug + 14 selected official BS.2217-2 vectors | 68/68 passed |
| `TestRunner` Release + the same vectors | 68/68 passed |
| `TestRunner` Thread Sanitizer + the same vectors | 68/68 passed; no race report |
| `AudioUnitHostProbe` Debug | passed; 310.5 µs mean, 333.5 µs p99, 393.7 µs max |
| `AudioUnitHostProbe` Release | passed; 9.2 µs mean, 10.0 µs p99, 30.0 µs max |
| `AudioUnitHostProbe` Thread Sanitizer | passed; no race report; 1,379.1 µs mean, 1,431.8 µs p99, 1,520.4 µs max |
| Callback deadline | 2,666.7 µs at 48 kHz / 128 frames |
| Real-time heap interposer | passed; 4,000 callbacks, zero observed heap operations; 9.2 µs mean, 9.9 µs p99, 78.4 µs max |
| Xcode native Debug build | `BUILD SUCCEEDED` |
| Installed `auval -v aufx LgAA ExAI` | `AU VALIDATION SUCCEEDED` |
| Installed signatures | strict nested verification passed |
| Production-language generated check | 14/14 entries exact |
| Logic 12.3 knowledge audit | four manuals; 142 effects/tools; 27 PDF instruments plus 16 Quick Sampler pages; 30 editor tools; empirical ledger 197 `not_run`, three `partial`, zero `complete` |
| Research corpus audit | ten archives; 125/125 members hash-matched; source/index/quarantine integrity passed |

`auval` exercised the installed AUv3 out of process across mono/stereo, 11.025–
192 kHz, render sizes through 4,096 frames, parameters, scheduled/ramped events,
reset, callbacks, state, and connection semantics. Its only warning was Apple's
`CurrentPreset`/`PresentPreset` deprecation.

These tests cover the named paths. They do not prove absence of every possible
race/allocation, performance under a large Logic project, or subjective quality.

## Completion-criterion audit

| # | Requirement | Evidence | Verdict |
|---:|---|---|---|
| 1 | At least one real frontier provider works end to end | OpenAI `gpt-5.6-sol` and Gemini `gemini-3.6-flash` each passed six cross-provider cases; Gemini passed 30/30; Gemini completed the direct Logic session | Passed |
| 2 | Vendor-neutral architecture plus deterministic mock/offline behavior | Shared `ModelProvider` contract, OpenAI/Gemini adapters, deterministic `MockModelProvider`, common evaluation harness, provider-neutral downstream schema | Passed |
| 3 | Secure credential and network boundary | When-unlocked device-only Keychain storage; companion/evaluator-only ephemeral networking; AU has no network entitlement; explicit consent, budget, timeout, cancellation, retry, redaction; no raw-audio upload | Passed for current text/measurement-only path |
| 4 | No unvalidated provider output can affect DSP or AU state | Ordered decoding, schema, semantic, capability, state-reference, and constraint gates; local hypothesis/planning; `PlanValidator`; offline render/safety; capture-bound commit | Passed |
| 5 | Free-form requests across six source classes | Both providers completed the same vocal, drums, bass, guitar, synth/keys, and full-mix suite | Passed |
| 6 | Desired, preserved, prohibited, ambiguous, and uncertain meaning is explicit | Versioned typed contract, bounded context, vocabulary/abstract-language retrieval, corpus invariants, direct Logic typed `intimate`/`polished`/preserve-`airy` result | Passed |
| 7 | Multi-turn revisions resolve explicit prior objects and locks | Typed preview/snapshot/request/node identities and merge behaviors; reference/lock regression; direct Logic preview-one replace plus exact EQ lock | Passed |
| 8 | Companion conversation survives restart and reconciles authority safely | Bounded checksummed persistence, migration and corrupt-state tests; direct session restored four turns and history view-only after runtime-epoch change | Passed |
| 9 | Complex requests create evidence-aware competing hypotheses | Typed supporting/contradictory evidence, risks, provenance, preservation, uncertainty, listening flag; multiple deterministic candidates in tests and direct session | Passed |
| 10 | At least 400 semantic/adversarial cases | Checked-in generator and test assert 420 cases across all six sources and required adversarial categories | Passed |
| 11 | At least 30 real-audio AI-to-preview cases | Gemini cloud-30 contains 30 generated-audio cases, five per source class, 90 valid previews, exact hashes/provenance, unchanged sources | Passed for legally usable generated fixtures |
| 12 | Any blocking new DSP meets deterministic/realtime standards | No extra unvalidated DSP was required; current nodes retain offline/realtime parity, bounds, state, sample-rate/layout, reset/bypass, nonfinite, performance, TSan and heap gates | Passed |
| 13 | Malformed, stale, unsafe, adversarial, contradictory, unsupported output fails closed | Provider timeout/cancel/network/credential/replay/stale tests; malformed/oversized/invented reference/capability/measurement/lock/prompt-injection tests; corpus invariants | Passed for covered cases |
| 14 | Existing AU, Logic, App Group, state, loudness, source and realtime guarantees do not regress | Final 68/68 Debug/Release/TSan; HostProbe three modes; heap interposer; `auval`; unchanged historical Logic evidence | Passed |
| 15 | One genuine frontier-AI session runs directly in Logic | `LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md` records insertion/playback/capture, Gemini turn, evidence/hypotheses, previews, natural revision, lock, commit and isolation | Passed |
| 16 | Committed graph survives save/reload and provider unavailability | Reopened Logic runtime restored request `D1FBF3F8-...`, exact five-node graph/lock and bypass state before companion/provider availability | Passed |
| 17 | Source audio remains unchanged | Direct Logic source SHA-256 remained `fb61fc...192`; all cross-provider/cloud-30 cases also record byte preservation | Passed |
| 18 | Documentation distinguishes proof, inference, heuristic, experiment and future work | Deep synthesis/evidence classes, capability/limitation docs, live provider reports, direct Logic record, this audit, and explicit artistic/host claim boundaries | Passed |

## Security and stale-result matrix

Current automated coverage includes:

- missing, inaccessible, and rejected credentials;
- consent absence;
- timeout, cancellation, network loss, bounded retry/no-retry, and rate limit;
- malformed and oversized responses;
- duplicate response identity and replay;
- stale AU runtime, capture, plan, conversation, and asynchronous result;
- nonexistent snapshots, previews and nodes;
- locked-node modification and implicit unlock;
- invented measurements, capabilities and unsupported DSP;
- prompt injection from user text, metadata, prior output, and imported context;
- corrupt persisted state and migration;
- instance switching and capture replacement while inference is in flight.

All covered failures preserve deterministic processing and saved-project playback.
No provider result is direct execution authority.

## Evaluation evidence

- [`PRODUCTION_INTELLIGENCE_LIVE_PROVIDER_2026-07-22.md`](PRODUCTION_INTELLIGENCE_LIVE_PROVIDER_2026-07-22.md)
- [`../../research/evaluation/production-intelligence-frontier-cross-provider-2026-07-22/README.md`](../../research/evaluation/production-intelligence-frontier-cross-provider-2026-07-22/README.md)
- [`../../research/evaluation/production-intelligence-gemini-3-6-flash-cloud30-2026-07-22/README.md`](../../research/evaluation/production-intelligence-gemini-3-6-flash-cloud30-2026-07-22/README.md)
- [`PRODUCTION_INTELLIGENCE_GENERATED_AUDIO_2026-07-14.md`](PRODUCTION_INTELLIGENCE_GENERATED_AUDIO_2026-07-14.md)
- [`LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md`](LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md)

## What remains outside v1

The closure does not claim:

- universal understanding of musician language or expert preference;
- objective proof that previews sound better;
- raw-audio cloud reasoning;
- arbitrary multitrack/project context;
- Logic region/channel-strip/project editing;
- third-party plug-in insertion;
- source separation or generative waveform replacement;
- ARA, Accessibility, broad MIDI/control-surface automation;
- full reference matching or ST-ITO deployment;
- every Logic format/mode/load or distribution/notarization readiness.

Those remain explicit future work or separate validation lanes.
