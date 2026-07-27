# TrackSmith direct Logic Pro 12.3 frontier-AI validation

Status: **passed for the exercised workflow**
Session date: 2026-07-27
Historical host evidence preserved:
[`LOGIC_MVP_VALIDATION_2026-07-14.md`](LOGIC_MVP_VALIDATION_2026-07-14.md)
and
[`LOGIC_12_3_VALIDATION_2026-07-14.md`](LOGIC_12_3_VALIDATION_2026-07-14.md)

## Claim boundary

This record proves one direct, credential-backed, free-form Production
Intelligence session inside Logic Pro 12.3. It proves that TrackSmith converted a
frontier-model semantic proposal into validated typed intent, local measured
evidence, competing hypotheses, deterministic editable plans, bounded previews, a
natural identity-resolved revision, and a capture-bound AU commit. It also proves
that the exact committed graph survived Logic save/reload and remained usable
without a provider.

It does **not** prove that the selected result is artistically better, that the
provider always understands subjective production language, that every Logic
configuration works, or that a metric establishes intimacy, polish, breathiness,
or quality. Listening remained decisive.

## Environment and installed identity

| Item | Observed value |
|---|---|
| macOS | 26.3, build 25D125, arm64 |
| Logic Pro | 12.3, build 6674 |
| Xcode / Swift | Xcode 26.6 build 17F113 / Apple Swift 6.3.3 |
| Repository source under test | `97d52ea6023af2b79188b966f4f0b77211f5c557` |
| Installed app | `~/Applications/Logic Audio Assistant.app` |
| App bundle / CDHash | `com.marcboyer.logicaudioassistant` / `101e92d95f966323a74baddadb96b06a458db9b2` |
| App executable SHA-256 | `81166dd7de58a84238cfd5baef74767f78dd192b2b4db56479b4f445a6803d1d` |
| AU bundle / CDHash | `com.marcboyer.logicaudioassistant.AudioUnit` / `725738350f681915a68388c8d36c4b07ae3a09fe` |
| AU executable SHA-256 | `0783992c6e9533e76820553a3a62b349e85db7531a57c923c4d616f00aa5893f` |
| Team / App Group | `KDV9RC892F` / `KDV9RC892F.com.marcboyer.logicaudioassistant` |

Strict nested signature verification passed. The companion entitlement contains
`com.apple.security.network.client`; the AU entitlement does not. Both contain the
sandbox and the same App Group. This is an Apple Development build, not a
distribution/notarization claim.

## Logic project, source, and capture

The disposable project is machine-local and intentionally ignored by Git:

`tmp/logic-validation-12.3/TrackSmith Production Intelligence Frontier AI 2026-07-22.logicx`

| Artifact | Identity |
|---|---|
| Project source | PCM24 mono, 44,100 Hz, 8.000 s |
| Source SHA-256 before session | `fb61fc24468af8b852717e459c63d1a495281583265221ebbe7bafdfe2dd8192` |
| Source SHA-256 after save/reload | `fb61fc24468af8b852717e459c63d1a495281583265221ebbe7bafdfe2dd8192` |
| Initial live AU instance | `A2ED5A3D-9B7E-4272-BE64-AC49BDDFB48C` |
| Initial runtime epoch | `B4E808CC-106A-4142-BD35-A795FBC571C3` |
| Capture snapshot | `1B549866-8A50-49D9-A6F1-DFA664EC794D` |
| Capture format | Float32 mono, 44,100 Hz, 545,792 frames, 12.376236 s |
| Capture SHA-256 | `d93b7d2826e5654648f0353fec0c0d893ff7d34c75ba1cc777de659f0b4ee199` |
| Capture command / response | `E25E4C6F-B526-424A-9A2E-7751E547F7CF` / `67B52B0C-4C71-4994-8AB8-F67FD910DD99` |

Logic played the source through the inserted AU. The companion discovered that
specific live instance and requested the recent capture through the signed App
Group exchange. The descriptor, WAV metadata, frame count, source snapshot, and
SHA-256 were bound to the subsequent preview and commit flow.

## Free-form provider turn

User request:

> Make this vocal feel more intimate and expensive, but keep the breathiness.

This request is outside the deterministic fallback's reliable literal coverage:
the fallback can find `intimate`, but does not reliably expand `expensive` or map
`breathiness` to an explicit air-preservation constraint.

| Provider evidence | Value |
|---|---|
| Adapter | `gemini-interactions-v1` |
| Configured / reported model | `gemini-3.6-flash` / `gemini-3.6-flash` |
| Response identity | `local-body-sha256:b0977c84d433da115cb0a294519a6037bb6a76b1c9dc9c22aa5d8166f2d2497c` |
| Attempts / latency | 1 / 3,762 ms |
| Bounded usage | 7,461 input tokens / 720 output tokens |
| Validation | decoding, schema, semantic, capability, state-reference, and constraint gates passed |
| Provider payload boundary | user language plus bounded typed context and measurements; no raw audio upload |

The validated TrackSmith interpretation was:

- increase `intimate`, confidence 0.58, professional-practice heuristic;
- increase `polished`, confidence 0.42, product heuristic;
- preserve `airy`, confidence 0.58, professional-practice heuristic;
- source class `vocal`;
- no invented measured fact and no provider-authored DSP parameter authority.

The original capture measured -19.0301 LUFS integrated, -7.9404 dBTP,
crest-factor ratio 3.3507, 459.51 Hz spectral centroid, -7.3744 dB/octave spectral
slope, and a 5–10 kHz energy ratio of 0.000335. The 12.38-second capture also
reported LRA 3.8157 LU with confidence 0.2063 and the explicit warning that EBU
does not recommend programme LRA interpretation below one minute. These
measurements were treated as context and preservation evidence, not semantic
proof of intimacy, polish, or breathiness.

Two competing hypotheses were retained:

1. greater direct-source salience and controlled tonal/dynamic refinement while
   preserving air and natural dynamics; options included restrained EQ and gentle
   compression;
2. a brighter-consonant/air-preserving interpretation whose risks included
   excessive high-frequency emphasis or over-de-essing.

Both retained supporting and contradictory evidence, source context, risks,
uncertainty, provenance, expected measurable direction, and
`subjectiveListeningRemainsDecisive = true`.

## Three bounded preview candidates

| Preview | Hypothesis / candidate | Graph | Match/result | Status |
|---|---|---|---|---|
| `38AE474F-407A-4855-8C1A-D8D8F557ED55` | `tracksmith-hypothesis-1` / `source-aware-v1-h1-balanced` | EQ, output trim, compression, loudness match, limiter | +2.1608 dB; -19.0301 LUFS; -7.9084 dBTP | valid, no warning |
| `D72A90D0-26C7-49A6-B894-7FC43D64B25B` | `tracksmith-hypothesis-2` / `source-aware-v1-h2-balanced` | EQ, output trim, loudness match, limiter | -0.7725 dB; -19.0301 LUFS; -7.9978 dBTP | valid, no warning |
| `85C71DB6-B319-4F2D-B70E-23BF0318D68C` | `tracksmith-hypothesis-1` / `source-aware-v1-h1-strong` | stronger EQ, output trim, compression, loudness match, limiter | +2.25 dB; -20.6851 LUFS; -9.0875 dBTP | valid; compensation safety-limited |

Every preview was finite, below the declared true-peak ceiling, structurally
editable, source-bound, and measurably distinct. The first two matched the source
within 0.00003 LU. The strong candidate remained 1.655 LU quieter because
TrackSmith's conservative added-gain accounting capped compensation; the UI and
manifest explicitly warned that matching was limited by the true-peak or
added-gain bound. This is bounded loudness matching, not a claim that all three
were numerically exact. TrackSmith correctly preferred the safety bound over
silently adding unrestricted gain.

## Natural multi-turn revision

An exploratory request referencing version two exposed a real ambiguity: that
preview had no compressor, while the user also asked for less compression.
TrackSmith preserved the typed identities, but the resulting composite was not
used as acceptance evidence.

The accepted revision was:

> Version one was closest. Keep its EQ locked, use less compression, and bring
> the vocal slightly forward while preserving the breathiness.

Provider evidence:

- response
  `local-body-sha256:a126cf4b925dfe8a6fec5542c6c302b1cc5fac3a916dd0a9b2840d8ea5576024`;
- one attempt, 4,422 ms, 9,090 input and 871 output tokens;
- typed preview reference
  `38AE474F-407A-4855-8C1A-D8D8F557ED55` with replace behavior;
- typed node reference
  `AC356973-D2A7-492F-BD64-58F4AD35C036` with lock behavior;
- desired `controlled` decrease and `forward` increase;
- explicit `airy` preservation;
- six validation gates passed.

The resulting plan request was
`D1FBF3F8-769E-4479-ABCA-B9BF7ACCDD50`. Its locked EQ retained exactly 2,200 Hz,
+1.35 dB, Q 0.75. The compressor mix fell from 0.6525 to 0.32625 and ratio from
2.925:1 to 1.9625:1 while attack, release, threshold, and bounded node identity
remained explicit. Output trim became +0.525 dB; measured loudness compensation
became +0.264434 dB; the -3 dBFS sample limiter remained last.

## Exact preview, persisted conversation, and committed graph

During this session, preview validation recalibrated the loudness-match node after
the initial revision plan was proposed. Inspection found that the companion had
previously persisted the pre-render proposal instead of the exact post-render
working graph. That could make a restored conversational snapshot disagree with
the audition and AU state.

The production fix in commit `97d52ea` makes `installWorkingPreview` return the
accepted rendered plan, refuses to record a rejected render as a successful
revision, and records the exact installed plan. Current evidence proves:

- canonical working-preview plan SHA-256:
  `3aa6755bd17477b969047f46c8f5a7223233409a634576e35b7fbfd7e2483302`;
- canonical persisted result-snapshot plan SHA-256:
  `3aa6755bd17477b969047f46c8f5a7223233409a634576e35b7fbfd7e2483302`;
- the live AU heartbeat exposed that same node graph and request identity.

The bounded, checksummed conversation envelope
`97936BEF-DF85-439F-B172-73F17E12B213` retained four turns, three snapshots, three
previews, two revision records, two lock-history records, provider/model metadata,
typed references, and the exact validation audit. It contains no credential.

## Commit, bypass, save/reload, and offline behavior

The companion committed the capture-bound plan through the existing compare-and-
swap protocol. The AU heartbeat reported request
`D1FBF3F8-769E-4479-ABCA-B9BF7ACCDD50` after commit command
`06910DF3-B01E-400A-9947-CBBB1BB8695C`. Global bypass was toggled on with command
`63D8B3D6-4EEE-45B8-B0DB-825A31106730` and then off with
`2A184385-964E-4969-8948-54F72BB269BF` without discarding that plan.

Logic saved the project, the companion and Logic were quit, and the project was
reopened with the companion initially unavailable. The restored insert published:

| Restored state | Value |
|---|---|
| New instance | `D9A22051-9565-4D6C-99EA-444B9916B24B` |
| New runtime epoch | `350E4A64-5D04-4098-BE1D-0F46FE936FB3` |
| Restored request | `D1FBF3F8-769E-4479-ABCA-B9BF7ACCDD50` |
| Restored graph | same five nodes, exact parameters and locked EQ |
| Global bypass | false |
| Provider dependency | none for saved graph execution |

A second live instance,
`FF5E071D-787E-459D-A02E-12F365F35E4B`, retained a different older graph and
runtime epoch. Its state did not change when the validated instance was committed,
bypassed, restored, saved, or reopened, preserving multiple-instance isolation.

When the companion relaunched, it restored the conversation as historical,
view-only state because the AU runtime epoch had changed. It did not silently apply
a stale command to the new runtime. This is the required distinction between
historical conversation, working state, and current AU authority.

The project source SHA-256 remained byte-identical after the complete workflow.
The provider was not required for playback or restoration of the committed
deterministic graph.

## Remaining limitations

- The strong preview's exact loudness match was safety-limited and disclosed.
- The session covered a mono vocal at 44.1 kHz, not every source class, bus,
  sample rate, buffer size, Logic mode, or project load.
- The exploratory version-two/less-compression request demonstrated that a
  semantically conflicting reference can still require a clarification or a more
  explicit merge rule.
- No raw audio was uploaded; future audio-capable provider work requires a separate
  consent and disclosure architecture.
- This evidence does not validate arbitrary Logic project editing, third-party
  plug-in insertion, ARA, Accessibility automation, source separation, generative
  replacement, or exact named-style replication.
