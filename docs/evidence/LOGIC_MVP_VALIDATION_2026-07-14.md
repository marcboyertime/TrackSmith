# Logic-hosted MVP validation evidence — 2026-07-13/14

## Verdict

The current Apple Development-signed AUv3 completed the usable MVP workflow in
Logic Pro 11.2.2 on a disposable project. Logic instantiated the effect, played
audio through it, and exposed a live 44.1 kHz stereo runtime to the companion.
The companion captured recent playback, analyzed the immutable capture, rendered
three valid and level-matched previews, displayed the complete processing graphs,
preserved a locked EQ while revising only compression, committed the revised graph,
toggled global bypass without discarding that graph, and restored processing.

After saving, closing, and reopening the Logic project, the AU restored the exact
committed request, source-snapshot identity, locked EQ, compressor settings, and
global-bypass state when Logic reactivated render resources. Duplicating the track
created a second independent AU runtime; bypassing and restoring the first instance
did not change the second.

This is direct Logic evidence for the tested workflow. It is not inferred from
`auval`, the custom host, or the offline CLI. Those separate evidence sources are
identified below so their boundaries remain explicit.

## Environment and installed identity

| Property | Recorded value |
|---|---|
| Host | Logic Pro 11.2.2 |
| Platform | Apple Silicon, macOS 26.3 |
| Xcode / SDK | 26.6 / macOS 26.5 |
| Project | disposable local `.logicx` package |
| Host format observed | 44,100 Hz, stereo |
| AU component | `aufx` / `LgAA` / `ExAI`, version 1.0.0 |
| Signing team | `KDV9RC892F` |
| Containing-app executable SHA-256 | `e4b2c5bea7cf6c272b06388d88fae75c8b1b7a1eb08f46da932339dfd635b4e4` |
| AU executable SHA-256 | `9d954c9ad84eecaa3513e375e2f9336b282ddbb51981d0cc84b73e8bf62d6aa2` |

Both bundles passed strict code-signature verification. The installed component
passed `auval -v aufx LgAA ExAI` out of process before this Logic run. See
[`SIGNED_AU_VALIDATION_2026-07-13.md`](SIGNED_AU_VALIDATION_2026-07-13.md) for the
validator matrix and fingerprints.

## Direct Logic workflow evidence

### Insertion, playback, discovery, and capture

Logic loaded the installed AU and displayed its custom compact UI. During playback
the AU heartbeat reported changing finite input, including -20.24 dBFS, and the
companion discovered the 44.1 kHz stereo runtime. The relevant runtime for capture
was:

- instance: `76E2D2DA-3EBF-4FB7-BE0F-1E6CE9089FF4`
- runtime epoch: `1B5F7993-BEE7-4FA4-B36A-0E78DCB5B6F7`
- capture/source snapshot: `9AD2AE9F-5A77-422C-AA47-EA2029094539`

The bounded recent-playback request produced 309,248 stereo frames at 44,100 Hz,
or 7.012426 seconds. Its Float32 WAV SHA-256 was
`27eee232f653c0ac4d6a401366ccdb89d65a400a9db91f1a55b5546b449e2aad`.
The companion verified the instance/runtime binding, descriptor metadata, path
containment, and SHA-256 before accepting it.

No microphone permission was requested. Audio reached the capture ring from the AU
input bus, and the utility queue—not the render callback—published the WAV.

### Three previews

For the vocal request, all three candidates were accepted. Each saved graph contains
its loudness-match node, so audition, re-render, and AU commit execute the same plan.

| Variant | Match gain | Integrated loudness | Approx. true peak | Clipped samples | Difference RMS from original | Difference RMS from previous |
|---|---:|---:|---:|---:|---:|---:|
| Conservative | +0.089378 dB | -21.395285 LUFS | -9.112442 dBTP | 0 | -27.787656 dBFS | -27.787656 dBFS |
| Balanced | +0.930315 dB | -21.395285 LUFS | -8.885418 dBTP | 0 | -26.722341 dBFS | -39.970391 dBFS |
| Strong | +4.933964 dB | -21.395366 LUFS | -8.177410 dBTP | 0 | -24.961510 dBFS | -35.820082 dBFS |

The original measured -21.395285 LUFS, -8.719093 dBFS sample peak, and zero clipped
samples. The accepted preview loudness spread was about 0.000082 LU. All preview
WAVs were distinct:

- Conservative: `19b6c8520ae8d924abcda9abccacc265ad02aca6d8f18808116e3f63230ab26a`
- Balanced: `8ca540408e86a7ddeca470e6b24032bb79d962273a9cfbda5287812505e0ae43`
- Strong: `1340898af0bee3471cb9408c70bfa02971d5f84c778463dd357a7ffb0b41c1ac`

Nonidentity and objective guardrails do not prove that a listener will prefer every
variant. They do prove that the options did not collapse into the same render or win
through added loudness.

### Inspection, lock, and conversational revision

The companion exposed the plan as editable cards: high-pass, two parametric EQs,
saturation, compressor, loudness match, and limiter, with parameters, rationale,
confidence, enable/bypass, and lock state.

The 320 Hz parametric EQ was locked. The request `Use less compression` changed the
Balanced compressor from ratio **2.77:1** and threshold **-21.09 dBFS** to ratio
**2.0596:1** and threshold **-18.0901 dBFS**. The locked EQ remained exactly 320 Hz,
-1.92 dB, Q 1.1, and every unrelated production node remained present. The dependent
loudness-match stage was recalculated, as expected, rather than treated as an
unrequested creative change.

### Commit, bypass, restore, and save/reload

The companion sent a capture-bound compare-and-swap commit. The AU acknowledged
command `95F03E5D-0DB2-4BB6-AF81-604789418C90` and then advertised the exact applied
plan in its heartbeat:

- committed plan request: `E61EA6B8-D69F-43C9-8275-4022248FD5E4`
- committed source snapshot: `9AD2AE9F-5A77-422C-AA47-EA2029094539`
- acknowledgement: `56E6639C-652D-4C11-87D1-2FB23D7B43E0`

While Logic remained active, **Bypass All** changed the instance heartbeat to
`globalBypassEnabled=true` while retaining the same current plan. **Restore** changed
it back to `false`, again retaining the graph.

Logic then saved and reopened the project. On the first subsequent playback, a new
runtime epoch reported the exact request ID, source snapshot, locked EQ, revised
compressor, and `globalBypassEnabled=false`. Logic's serialized project data contains
the product keys `com.marcboyer.logicaudioassistant.processing-plan-v1` and
`com.marcboyer.logicaudioassistant.global-bypass-v1` plus the canonical plan. The
post-save/two-track `ProjectData` SHA-256 is
`75e8e84a41e5c505dbf9714c877836cbe1b057a982123183ea58a44c40509ce6`.

An idle heartbeat briefly precedes state restoration before Logic allocates render
resources; the authoritative restored state appeared on playback. This lifecycle
detail must not be mistaken for state loss.

### Multiple-instance isolation

Logic's **New Track With Duplicate Settings** produced two visible tracks with two
independent AU instances. After restarting the companion, both appeared as 44.1 kHz
stereo runtimes. The persisted graph initially matched in both, as expected from
duplicated channel-strip settings.

Bypassing instance `7350A5C8-B880-459D-A1B5-CF46F0A7D20F` changed only that
instance to `globalBypassEnabled=true`; peer
`A41AE974-3543-4A48-A93A-9DB10F522DFC` remained `false` and received no command.
Restoring the first returned it to `false`. This proves instance-scoped command
routing for the exercised operation in Logic.

## Source and recovery safety

The project source files were hashed before the workflow and again after capture,
commit, bypass, save/reload, and track duplication. The values remained identical:

| Source artifact | SHA-256 before and after |
|---|---|
| project audio file 1 | `61c6ef570965f74c38f29826c26f63606dd1bb0f0fb83a8b8a68e1a5f714b9db` |
| project audio file 2 | `41184ea57be830c682405e618b9faa55cadaeeaecbc46e56d67b81969fe1a4a9` |

The product wrote only its App Group capture/preview cache and its own AU state in
the Logic project. It did not overwrite either source file. The original remains
available through global bypass, graph revert, insert bypass/removal, and the
untouched project media.

## Adjacent evidence, kept separate

| Evidence source | What it proves |
|---|---|
| Logic Pro | The current installed AU completed the direct workflow recorded above. |
| `auval` | System discovery, instantiation, properties, state, callbacks, parameter scheduling, and equal-layout mono/stereo render probes through 192 kHz. |
| `AudioUnitHostProbe` | Deterministic output checks unavailable from Logic UI: sample parity, exact dry bypass, malformed host buffers, two-instance isolation, atomic failure paths, nonfinite input, reset, automation, state reload, capture teardown, deadline timing, lost-ack reconciliation, and zero observed heap operations across 4,000 interposed callbacks. |
| `VerticalSliceCLI` | A hash-ledgered real-vocal run with 18/18 assertions, deterministic revision/undo/redo, sample-exact decoded dry recovery, and unchanged external source bytes. |
| `TestRunner` | 42/42 DSP, analysis, schema, preview, state, IPC, and regression checks in Debug and Release. |
| Thread Sanitizer | `TestRunner` and `AudioUnitHostProbe` completed without a race report; the sanitized host probe measured 1,345.2 us mean, 1,423.5 us p99, and 1,494.8 us max against a 2,666.7 us callback deadline. |

The final Release host probe measured 9.1 us mean, 9.9 us p99, and 47.2 us maximum
at 48 kHz/128 frames against the same 2,666.7 us deadline. With the thread-local heap
interposer loaded it measured 9.3 us mean, 12.5 us p99, and 66.5 us maximum and
reported `RT_HEAP callback iterations=4000 operations=0`. The latest independent
offline real-vocal evidence is
[`MVP_VERTICAL_SLICE_2026-07-13.md`](MVP_VERTICAL_SLICE_2026-07-13.md).

## Reproduce the user workflow

From the repository root:

```sh
make native-install
auval -v aufx LgAA ExAI
open "$HOME/Applications/Logic Audio Assistant.app"
```

Then in a disposable Logic project:

1. Insert **Audio Units → Marc Boyer → Logic Audio Assistant** on an audio track.
2. Play 7–15 seconds and confirm the plug-in input meter changes.
3. In the companion, select that live instance and choose **Analyze Recent Playback**.
4. Set the source to Vocal and enter `make this clearer, warmer, and more controlled`.
5. Create three previews; compare Original, Conservative, Balanced, and Strong with
   level matching enabled, and inspect every graph card.
6. Lock an EQ, select Balanced, and enter `use less compression`. Confirm only the
   compressor and dependent loudness-match stage change.
7. Commit the revision. Toggle **Bypass All**, then **Restore**.
8. Save, close, and reopen the project; start playback and confirm the same plan,
   lock, and bypass state return.
9. Duplicate the track with its channel-strip settings and verify the companion
   lists two instances; bypass one and confirm the other remains active.

The full repeatable host matrix is in
[`MANUAL_LOGIC_TESTS.md`](../MANUAL_LOGIC_TESTS.md).

## Limitations not erased by this pass

- This run covered a 44.1 kHz stereo Logic runtime, not every rate, buffer size,
  track type, bus, stereo output, low-latency mode, freeze, or bounce combination.
- “Capture next playback” remains unimplemented; the proven mode is bounded recent
  playback.
- The parser is deterministic and keyword-based, not a general LLM conversation.
- Subjective listening remains required. Metrics reject unsafe or collapsed
  variants; they cannot certify artistic quality.
- Whole-graph activation is atomic but has no old/new graph crossfade, so a large
  graph transition can click at a callback boundary.
- Callback source contains no explicit allocation, file/network/database/log/UI
  work, blocking lock, or unbounded loop after the host pull; custom-host timing,
  Thread Sanitizer, and heap-interposer checks pass. The interposer was not injected
  into Logic and does not cover every possible VM/runtime entry point, so this is not
  a formal universal allocation-free certification.
- The product cannot identify a selected Logic region, read its source file, inspect
  arbitrary channel strips, insert other plug-ins, or perform general project edits
  through a stable public API.
