# TrackSmith Production Intelligence v1 baseline

Date: 2026-07-14  
Purpose: freeze the proven repository and verification state before adding cloud-
assisted Production Intelligence. This is a new evidence lane and does not replace
the Logic Pro 11.2.2 or 12.3 host records.

## Repository identity

| Item | Value |
|---|---|
| Repository | `/Users/marcboyer/LogicAudioAssistant` |
| Branch | `main` |
| HEAD | `c91cdc1c1c0129adaac890369c8e70901f0cd248` |
| Tracked modified paths | 52 |
| Untracked top-level status entries | 23 |
| Staged diff | empty |
| Porcelain status SHA-256 | `e41caac3b0737b264af2a3d2028632a29d4dfa55497e9d4d64d8b6ebb39a8274` |
| Tracked binary-diff SHA-256 | `eecc747939d43ab27d6c94261fb7799bbca32b3df210a2c68e05cad87a8c8c40` |
| Untracked path/content-manifest SHA-256 | `7b4c15a7b4a4f59a00c9e7cae011dfff522dfef1b19a8c340a344e2b72c4e534` |

The dirty tree is intentional prior TrackSmith work and was preserved. No reset,
checkout, stash, or cleanup was performed. `xcodegen generate` ran as part of the
documented native baseline and produced project file SHA-256
`5fd9826a685539fa0fbaaf7b26698a6559ec4b8d9aa0235a5aec7534eb3780f9`.

Selected pre-change file hashes captured before the native baseline command:

| File | SHA-256 |
|---|---|
| `Package.swift` | `2ffe5f53952c582e52fadbefff82b5d0fc9404d45ee9a99e6e5707f9e709b1ee` |
| `Makefile` | `2ac0c4c2d4d8e498e53c67e25cfddd5470f9a93746a89061cd58e3bbb87f4470` |
| `tests/TestRunner/main.swift` | `89600acc78cdf9f00dda246a64cee1ccd41322a0b2f1802f7f6d6534a5bf4d01` |
| `AudioUnitHostProbe/main.swift` | `10148d627ba16b9d5deac6b0c532fadb6caed4bb6a8e8c1b120c12445f1cea66` |

## Baseline verification

The official-vector directory was
`tmp/standards-vectors/itu-bs2217/extracted`; it contains the same 14 selected
BS.2217-2 WAV payloads used by the preceding milestone.

| Lane | Result |
|---|---|
| Debug `TestRunner` with official vectors | 55/55 passed |
| Release `TestRunner` with official vectors | 55/55 passed |
| Unsigned native Debug app/AU build | `BUILD SUCCEEDED` |
| Release `AudioUnitHostProbe` | passed |
| Release callback timing | 128 frames at 48 kHz: 9.2 us mean, 10.1 us p99, 43.6 us max, 2,666.7 us deadline |
| Real-time heap interposer | passed; 4,000 callbacks, zero observed heap operations |
| Heap-probe callback timing | 9.2 us mean, 10.5 us p99, 42.3 us max |

Commands:

```sh
TRACKSMITH_BS2217_VECTORS="$PWD/tmp/standards-vectors/itu-bs2217/extracted" swift run TestRunner
TRACKSMITH_BS2217_VECTORS="$PWD/tmp/standards-vectors/itu-bs2217/extracted" swift run -c release TestRunner
make native-verify
```

This baseline does not rerun or rewrite the direct Logic evidence. The historical
records remain:

- `docs/evidence/LOGIC_MVP_VALIDATION_2026-07-14.md` for Logic Pro 11.2.2.
- `docs/evidence/LOGIC_12_3_VALIDATION_2026-07-14.md` for the separate Logic Pro
  12.3 installed-binary lane.

## Provider starting boundary

At baseline, `ModelProvider` returns only `[ProcessingGoal]` and its only concrete
implementation is deterministic `MockModelProvider`. No OpenAI or Gemini environment
credential was present, and no TrackSmith OpenAI Keychain item existed. No network
provider, durable conversational store, model-output schema validator, or free-form
frontier interpretation path was therefore claimed at baseline.
