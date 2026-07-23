# TrackSmith Production Intelligence v1 closing regression

Status: **code, native, AU and deterministic regression lanes pass; live frontier/Logic lane remains pending**  
Date: 2026-07-15

## Proof boundary

This report records the closing automated and installed-artifact evidence for the
Production Intelligence implementation. It does not claim that a frontier provider
worked live or that the new conversational path completed inside Logic. No OpenAI or
Gemini credential was present, so those acceptance cases remain explicitly open in
[`LOGIC_12_3_PRODUCTION_INTELLIGENCE_2026-07-15.md`](LOGIC_12_3_PRODUCTION_INTELLIGENCE_2026-07-15.md).

The historical Logic Pro 11.2.2 and deterministic Logic Pro 12.3 records were not
rewritten. The repository began and ended this lane with a large intentional dirty
tree. No reset, checkout, stash, clean, or deletion of user material was performed.

## Repository and environment identity

| Item | Closing value |
|---|---|
| Repository | `/Users/marcboyer/LogicAudioAssistant` |
| Branch/HEAD | `main` / `c91cdc1c1c0129adaac890369c8e70901f0cd248` |
| Host | Logic Pro 12.3, build 6674 |
| OS | macOS 26.3, build 25D125, arm64 |
| Xcode | 26.6, build 17F113 |
| Installed app | `/Users/marcboyer/Applications/Logic Audio Assistant.app` |
| Install command | `make native-install` |
| Install result | signed Release `BUILD SUCCEEDED`; atomic install and strict signature checks passed |

## Installed artifact identity

| Artifact | Bundle/version | Executable SHA-256 | CDHash |
|---|---|---|---|
| Containing app | `com.marcboyer.logicaudioassistant`, 1.0 (1) | `2dde43f9cde903a18835619b517b70898db3b58989a7a29ce77320a01433cda8` | `719c1e0d819c1af7a0b1125e72f14379628203a8` |
| AUv3 extension | `com.marcboyer.logicaudioassistant.AudioUnit`, 1.0 (1) | `ff731ee2ba4803466296e81d07ecc7b4557520f67288374d0bbb722e747560c0` | `725738350f681915a68388c8d36c4b07ae3a09fe` |

Both artifacts are arm64 Apple Development builds signed by Team
`KDV9RC892F`. `codesign --verify --deep --strict --verbose=2` passed for the
installed app, and strict verification passed independently for the extension.
Both entitlements contain:

- `com.apple.security.app-sandbox = true`
- `com.apple.security.application-groups = [KDV9RC892F.com.marcboyer.logicaudioassistant]`
- `com.apple.security.get-task-allow = true`

The last entitlement is expected for this Apple Development evidence build and is
not a distribution/notarization claim. `pluginkit` reports
`com.marcboyer.logicaudioassistant.AudioUnit(1.0)`, and the installed companion was
launched successfully from the recorded path.

## Closing validation matrix

| Lane | Exact closing result |
|---|---|
| Debug `TestRunner` + 14 selected official BS.2217-2 vectors | 65/65 passed |
| Release `TestRunner` + the same vectors | 65/65 passed |
| Thread Sanitizer `TestRunner`, external vectors omitted | 64/64 passed; no race report |
| `AudioUnitHostProbe` Debug | pass; 288.6 us mean, 311.3 us p99, 393.8 us max |
| `AudioUnitHostProbe` Release | pass; 9.2 us mean, 9.4 us p99, 37.0 us max |
| `AudioUnitHostProbe` Thread Sanitizer | pass; no race report; 1,359.2 us mean, 1,430.9 us p99, 1,508.1 us max |
| Callback deadline used by all host timings | 2,666.7 us at 48 kHz / 128 frames |
| Real-time heap interposer | pass; 4,000 callbacks, zero observed heap operations; 9.2 us mean, 10.0 us p99, 28.0 us max |
| Installed `auval -v aufx LgAA ExAI` | `AU VALIDATION SUCCEEDED` |
| Installed app and extension strict signatures | pass |
| AU registration | pass; AUv3 extension visible to `pluginkit` |

`auval` instantiated the extension out of process and passed open, initialization,
default format, required/recommended properties, class state, callbacks, parameter,
reset, mono/stereo, 11.025–192 kHz, render-size, connection, scheduling and ramping
tests. Its only warning was the legacy `CurrentPreset`/`PresentPreset` deprecation.

The 65-test vector-backed lanes include the six-stage provider validation path,
provider timeout/cancellation/network/credential/replay/staleness failures, bounded
context and exact natural-reference catalog, durable checksummed conversation
reconciliation, competing hypotheses, all six source classes, the 420-case semantic
and adversarial corpus, standards measurements, IPC/commit safety, preview
distinctness, locks, bypass and source preservation. Passing tests are evidence for
the exercised paths, not proof against every race, adversarial input, provider
behavior, Logic configuration, or artistic failure.

After the original closing run, the provider evidence boundary was tightened without
changing AU/DSP code: TrackSmith now distinguishes configured model authority from a
bounded provider-reported resolved model, rejects malformed metadata, retains
provider response identity in evaluation results, and persists the complete accepted
validation audit. The companion now also renders the exact measured evidence values,
confidence/relationship, hypothesis outcomes/risks, provider identities and
completed validation gates instead of showing strategy labels alone. The refreshed
containing-app fingerprint above includes these changes; the AU fingerprint is
unchanged. Debug and Release passed 64/64 without external vectors after the provider
change, the closing post-change TSan result is recorded in the matrix above, and the
native evidence-panel build and strict signed install passed.

## Generated-audio evidence retained

The previously recorded deterministic run remains 30/30 successful across five
cases for each of vocal, drums, bass, guitar, synth and full mix. All 30 cases have
exactly three candidates and unchanged source bytes. Its manifest is:

`.build/evidence/production-intelligence-offline-30of30-2026-07-14/run.json`

with SHA-256
`adc0e926fdf5ba7dc400ff2aecc63fa3fff89e61f5cedcc53f64a29be80d071b`.
This remains `mock-offline-1 / deterministic-intent-v1` evidence; it is not
frontier-model or subjective listening proof.

## Prepared direct-Logic fixture

| Item | Value |
|---|---|
| Source | `tmp/logic-validation-12.3/source-vocal-48k-mono.wav` |
| Format | PCM24 mono, 48,000 Hz, 8.000 s |
| SHA-256 before live lane | `ad289bb28f37fd2bef753b176e7a371bf08fbb7b4c5c76adb5e83db2a694e2c0` |
| New project target | `tmp/logic-validation-12.3/TrackSmith Production Intelligence 2026-07-15.logicx` |

No direct frontier session has mutated this fixture or created the new project yet.
The hash is therefore a prepared precondition, not a before/after host result.

## Credential and live-provider state

At closure of this automated lane, Keychain service
`com.marcboyer.tracksmith.provider-credentials` contained neither the `openAI` nor
the `gemini` account, and `OPENAI_API_KEY`, `GEMINI_API_KEY`, and `GOOGLE_API_KEY`
were absent from the process environment. No network request was attempted and no
credential was copied into a command, log, prompt, App Group payload, evidence file,
or project.

The implementation is therefore accurately described as provider-neutral,
signed/native, wire-contract tested and fail-closed, but not yet credential-backed
or directly frontier-proven. The milestone remains incomplete until the prepared
Logic lane records a real provider/model response, free-form interpretation, three
previews, typed natural revision, lock/constraint preservation, capture-bound
commit, bypass/restore, save/reload, provider-offline deterministic playback,
instance isolation and unchanged source hash.

## Commands

```sh
TRACKSMITH_BS2217_VECTORS="$PWD/tmp/standards-vectors/itu-bs2217/extracted" swift run TestRunner
TRACKSMITH_BS2217_VECTORS="$PWD/tmp/standards-vectors/itu-bs2217/extracted" swift run -c release TestRunner
swift run --sanitize=thread TestRunner
swift run AudioUnitHostProbe
swift run -c release AudioUnitHostProbe
swift run --sanitize=thread AudioUnitHostProbe
./scripts/run-realtime-heap-probe.sh
make native-install
auval -v aufx LgAA ExAI
```
