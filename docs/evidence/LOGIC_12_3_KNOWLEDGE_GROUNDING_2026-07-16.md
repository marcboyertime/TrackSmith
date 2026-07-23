# TrackSmith Logic Pro 12.3 knowledge-grounding evidence

Date: 2026-07-16  
Status: **implemented and locally verified; advisory knowledge only**

Regression verification refreshed: 2026-07-18.

## Claim boundary

TrackSmith now has bounded typed retrieval over the deeply reviewed Logic 12.3
Effects and Instruments identities needed for production explanation and over
explicitly named editor tools needed for scope/risk explanation. A coverage audit
also closes the Quick Sampler chapter omitted from Apple's Instruments PDF and
pins the mutable 12.3 release-notes payload. This proves catalog integrity,
documentary identity coverage, provenance, selection behavior, and authority
separation. It does **not** prove Apple's undocumented algorithms, exact transfer
curves, perceptual superiority, or an ability to insert/control Logic-native
plug-ins, instruments, tools, MIDI, automation, regions, files, or project state.

## Immutable primary sources

| Source | Pages | SHA-256 | Full relevant content read |
|---|---:|---|---|
| Apple, *Logic Pro Effects for Mac* | 390 | `b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819` | yes |
| Apple, *Logic Pro Instruments for Mac* | 752 | `fc867e61b1bbcfc16d4ba98058f7cde104ec17e0649026769c308cff07049ab4` | yes |
| Apple, *Logic Pro User Guide for Mac* | 1,324 | `aa016d18d7e4f3559cdec54a99937d00b379617fee87510db1ec9853a4996cff` | yes |
| Apple, *Control Surfaces Support Guide for Logic Pro* | 220 | `5ab5e4ef38e9c8e9279a0a2d36dcaabd1a9471942843d0162a3016f6ebf9322c` | yes |

The Instruments PDF repeatedly links Quick Sampler but omits its standalone
chapter. Sixteen canonical Logic 12.3 Quick Sampler web sections were therefore
captured, validated, uniquely hashed, and read in full. Apple's mutable release-
notes page was captured as validated HTML at SHA-256
`854fd08c8e38351d521a9feed35a77fc2ce5969baab473e270decd2425f0dcb0`;
the complete 12.3 section was read. These are local-use-only Apple documents.

The local payloads remain internal-reference/local-use-only objects under the
research-ingestion contract. The catalogs contain TrackSmith-authored synthesis,
not copied manual chapters.

## Generated knowledge artifacts

| Artifact | Entries | SHA-256 |
|---|---:|---|
| `research/knowledge/logic-pro-12.3-manual-index.json` | 4 manuals / 2,686 pages | `ce1d622925e7e7768a8fa352a8d265b3ac118561716bb37db08c25d8a0c3de21` |
| `research/knowledge/logic-pro-12.3-effects-knowledge.json` | 142 | `af0d36f9a2c0f4da5d0e6e908c2c17d8533c2367386a262cd8a16b3efb799a21` |
| `LogicNativeToolKnowledge.generated.swift` | 142 | `b9185a04fab88adcd9eaa3c6afedbef6d259a4929bb8c66371fc6b0e409f43e3` |
| `research/knowledge/logic-pro-12.3-instrument-knowledge.json` | 28 + 16 supplement sources | `d5e2cab3b5447e39156d7cdf71c67d2c68624096ef294308c52d758888507c18` |
| `LogicNativeInstrumentKnowledge.generated.swift` | 28 | `45b60da15bf8fcf9a7e2714d273046ac9af08d08900ad3da7875e166e0df4311` |
| `research/knowledge/logic-pro-12.3-editor-tool-knowledge.json` | 30 | `25fc2fdfe1f5756702f9f4a9043a1e75d3eb186808e396669c4fa4a329b0a226` |
| `LogicEditorToolKnowledge.generated.swift` | 30 | `315c2f52a2bd9087801bd3fa3db4163848aad3b6894f18a19a0989dd1bd7a7ae` |
| `research/knowledge/logic-pro-12.3-empirical-campaign.json` | 200 identities, all `not_run` | `8ec83d84ad29f05f69333387a6113af1ab435408b1966ba44f81eecd8f364e24` |
| `research/knowledge/logic-pro-12.3-knowledge-coverage.json` | fail-closed audit | `e1cf84f818413733cdab629cd3f196ec2755dc4c9f1203a863ffeec350be7d63` |

The 142 effects entries include all documented top-level effect/utility/MIDI
processor identities plus Pedalboard, all 35 named stompboxes, and its Splitter
and Mixer utilities. The 28 instrument entries cover the PDF identities plus the
canonical Quick Sampler supplement. The 30 editor entries cover every common and
area-specific tool Apple lists on User Guide pages 54-60 and retain focus,
selection, state-scope, conversion, destructive-file, and source-preservation
risks.

Regeneration commands:

```sh
python3 research/scripts/build-logic-effects-knowledge.py
python3 research/scripts/build-logic-instrument-knowledge.py
python3 research/scripts/build-logic-editor-tool-knowledge.py
python3 research/scripts/build-logic-native-empirical-campaign.py
python3 research/scripts/audit-logic-12.3-knowledge-coverage.py
```

Both generators fail closed on missing atlases, unexpected entry counts, or
duplicate identities. Runtime validation additionally rejects malformed,
duplicate, unsupported-source, or authority-violating entries.

## Retrieval and authority behavior

- Effects/pedals: explicit names and aliases dominate; source family and typed
  semantic terms rank a maximum of four reviewed entries.
- Instruments: a maximum of two entries can be returned, and only if the request
  explicitly names the instrument or a reviewed alias. “Make this recorded synth
  warmer” cannot infer Alchemy, ES2, Sampler, Sculpture, or another generator.
  Ambiguous source/style words such as *retro*, *Hammond*, *Rhodes*, and *acoustic
  drum kit* are deliberately not Logic-instrument aliases.
- Editor tools: a maximum of two entries can be returned, and only for explicit
  constructions such as “Scissors tool” or “use the Scissors.” Generic words such
  as *gain*, *move*, *line*, and *volume* cannot silently become host-tool
  requests. Context contains the relevant state scope and risk but no key command,
  UI action, Accessibility action, or host mutation.
- Explicit instrument identity is retained ahead of generic semantic/effect
  background when the provider context must be pruned to its byte bound.
- Every returned entry is labeled `PROFESSIONAL_PRACTICE_HEURISTIC`, separates
  Apple-documented mechanism from derived production consequence, requires
  subjective listening, and serializes both `mayBecomeProcessingNode: false` and
  `mayControlLogicOrAutomation: false`. It also serializes
  `exactImplementationInternalsKnown: false` and the explicit status
  `DOCUMENTED_BEHAVIOR_REVIEWED_EXACT_TRANSFER_NOT_YET_MEASURED`.
- No catalog entry carries a `NodeType`, DSP parameter map, preset, MIDI event,
  automation target, script, filesystem path, or host action.

## Verification

| Lane | Result |
|---|---|
| Debug `TestRunner` with selected official BS.2217-2 vectors | 68/68 passed |
| Release `TestRunner` with the same vectors | 68/68 passed |
| Thread Sanitizer `TestRunner`, external vectors omitted | 67/67 passed; no race report |
| Generator rerun plus `jq` count/status checks | passed |
| Xcode Debug companion + embedded AUv3 build, unsigned verification target | passed |
| Release `AudioUnitHostProbe` | passed; 9.3 us mean, 10.3 us p99, 38.5 us max at 128/48 kHz |
| 4,000-callback heap-interposer host probe | passed; 0 observed heap operations; 9.2 us mean, 10.2 us p99, 59.7 us max |
| Thread Sanitizer `AudioUnitHostProbe` | passed; no race report; 1,363.3 us mean, 1,472.0 us p99, 1,797.8 us max against 2,666.7 us deadline |
| Installed AU `auval -v aufx LgAA ExAI` | `AU VALIDATION SUCCEEDED` |
| `git diff --check` | passed |

The added regression proves immutable source hashes, exact catalog counts,
explicit Bitcrusher, Alchemy, Quick Sampler, Scissors, and Voice Separation
grounding, Scripter's no-code/no-authority boundary, the empty instrument result
for generic recorded-synth and ambiguous retro/Hammond/Rhodes/acoustic-kit
language, the empty editor result for generic gain/move language, and bounded
context inclusion without DSP, Logic-control, or Accessibility authority.

## Remaining empirical boundary

Apple's manuals document exposed controls and intended behavior but do not publish
exact nonlinear transfer functions, oversampling, filter coefficients, phase and
latency response, aliasing, stochastic state, or every automation transition.
Those claims remain in the separate calibrated Logic-render measurement queue.
`TestSignalGenerator --logic-measurement-suite` now writes 18 deterministic PCM24
fixtures plus an input-hash manifest; two independently generated suites compared
byte-for-byte. `LOGIC_NATIVE_EMPIRICAL_MEASUREMENT_PROTOCOL.md` defines exact run
identity, parameter, level, sample-rate, stereo, nonlinear, time-varying,
Pedalboard-topology, Bitcrusher, repeated-render, source-hash, and listening
requirements. The 200-identity campaign ledger deliberately marks every item
`not_run`; documentary completeness has not been relabeled empirical closure.
Artistic terms such as *warm*, *expensive*, *punchy*, *vintage*, and *professional*
remain context-dependent hypotheses; neither a catalog entry nor one metric makes
them measured facts.
