# TrackSmith Production Mastery v1 pre-expansion baseline

Status: **passed for the frozen Production Intelligence v1 scope**  
Recorded: 2026-07-27  
Milestone plan:
[`../PRODUCTION_MASTERY_PERCEPTUAL_EVALUATION_V1.md`](../PRODUCTION_MASTERY_PERCEPTUAL_EVALUATION_V1.md)

## Source and predecessor identity

| Item | Recorded value |
|---|---|
| Repository HEAD | `a19c0b7e9dbee7909552feb3547fa607a312f2db` |
| HEAD subject | `docs: close Production Intelligence v1 evidence` |
| Frozen implementation commit named by closure | `97d52ea6023af2b79188b966f4f0b77211f5c557` |
| Branch/upstream | `main`; exactly even with `origin/main` |
| Worktree before baseline | clean |
| Tracked files | 900 |
| Aggregate digest of sorted per-file SHA-256 records | `f70632a25e81487b4c9f33f6c39fd7fbd8a05601770aeda1214710016bc28c8e` |
| Toolchain | macOS 26.3 build 25D125 arm64; Xcode 26.6 build 17F113; SDK 26.5 |

The documentation closure commit contains the final criterion audit and synchronized
documentation after implementation commit `97d52ea`; it is the exact pre-expansion
source state. No user-owned or uncommitted source change was present.

`git fsck --full` reported an existing untracked Git-metadata file,
`.git/refs/.DS_Store`, as an invalid ref name, plus two dangling blobs. This does not
change HEAD, the index, the clean worktree, the tracked digest, or any baseline lane.
The file was preserved rather than deleted. This record does not call that metadata
a source or product regression.

## Frozen installed identity

The installed development artifact exactly matches the 2026-07-27 direct-Logic
evidence record.

| Item | Recorded value |
|---|---|
| Installed app | `~/Applications/Logic Audio Assistant.app` |
| App bundle / CDHash | `com.marcboyer.logicaudioassistant` / `101e92d95f966323a74baddadb96b06a458db9b2` |
| App executable SHA-256 | `81166dd7de58a84238cfd5baef74767f78dd192b2b4db56479b4f445a6803d1d` |
| AU bundle / CDHash | `com.marcboyer.logicaudioassistant.AudioUnit` / `725738350f681915a68388c8d36c4b07ae3a09fe` |
| AU executable SHA-256 | `0783992c6e9533e76820553a3a62b349e85db7531a57c923c4d616f00aa5893f` |
| Component | `aufx` / `LgAA` / `ExAI`, version `0x10000` |
| Team / App Group | `KDV9RC892F` / `KDV9RC892F.com.marcboyer.logicaudioassistant` |
| App network entitlement | present |
| AU network entitlement | absent |
| Exchange root | resolved; `Exchange-v1` is user-only mode `0700` |

`codesign --verify --deep --strict` passed. App and AU carry the same signed App
Group; only the companion carries client networking.

## Regression lanes

All commands used the exact source above. The TestRunner lanes supplied the 14
selected official BS.2217-2 WAV vectors from the pre-existing local standards
fixture directory.

| Lane | Current result |
|---|---|
| `TestRunner` Debug | 68/68 passed |
| `TestRunner` Release | 68/68 passed |
| `TestRunner` Thread Sanitizer | 68/68 passed; no race report |
| `AudioUnitHostProbe` Debug | passed; 311.2 µs mean, 343.5 µs p99, 919.2 µs max |
| `AudioUnitHostProbe` Release | passed; 9.2 µs mean, 9.5 µs p99, 66.9 µs max |
| `AudioUnitHostProbe` Thread Sanitizer, first run | passed; no race report; 1,389.8 µs mean, 1,457.0 µs p99; one 30,164.4 µs scheduling outlier |
| `AudioUnitHostProbe` Thread Sanitizer, immediate repeat | passed; no race report; 1,378.8 µs mean, 1,459.6 µs p99, 2,084.6 µs max |
| Callback deadline | 2,666.7 µs at 48 kHz / 128 frames |
| Real-time heap interposer | passed; 4,000 callbacks, zero observed heap operations; 9.2 µs mean, 9.5 µs p99, 32.8 µs max |
| Xcode native Debug build | `BUILD SUCCEEDED` |
| Installed `auval -v aufx LgAA ExAI` | `AU VALIDATION SUCCEEDED`; current-preset deprecation warning only |
| Production-language generated check | 14/14 exact |
| Logic 12.3 knowledge audit | four manuals; 142 effects/tools; 27 PDF instruments plus 16 Quick Sampler pages; 30 editor tools |
| Empirical campaign | 197 `not_run`; three `partial`; zero `complete` |
| Deterministic Logic fixture suite | two independent 18-file PCM24 suites were byte-identical |
| Research corpus audit | ten archives; 125/125 members hash-matched; source/index/quarantine integrity passed |

The first TSan host timing run passed every functional/state/IPC assertion and emitted
no sanitizer report, but its single scheduling outlier is retained because a
sanitizer-timing maximum is not deterministic. The immediate repeat remained below
the callback deadline. Neither run is a Logic-load timing claim.

## Executable DSP checkpoint

Enabled plans compile only:

- input/output trim and loudness match;
- polarity;
- high-pass, low-pass, and one-band parametric EQ;
- compressor and split-band de-esser;
- soft clipper and saturation;
- stereo width;
- zero-lookahead sample limiter;
- meter/no-audio node.

Serialized placeholder nodes for expander, transient shaping, M/S EQ, delay, and
reverb fail closed when enabled. The checked-in JSON Schema and runtime validator
agree on that allowlist.

## Baseline verdict

The frozen Production Intelligence v1 source, installed AU, security/authority
boundary, deterministic processing, App Group IPC, state, preview, revision, commit,
rollback, save/reload, source-preservation, corpus, and host-probe lanes are healthy
for their declared scope. Expansion may begin. This record does not upgrade custom
host or objective measurements into Logic-host or artistic-quality proof.
