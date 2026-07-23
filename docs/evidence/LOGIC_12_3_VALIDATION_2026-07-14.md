# TrackSmith Logic Pro 12.3 validation — 2026-07-14

## Verdict and scope

TrackSmith's installed compatibility AU completed the exercised production
workflow in **Logic Pro 12.3 (build 6674)** on **macOS 26.3 (25D125), arm64**.
The run directly proved AU discovery and insertion, playback, live instance
discovery, bounded recent capture, three level-matched previews, graph inspection,
a locked-node targeted revision, commit, internal bypass/restore, project
save/reload, two-instance routing isolation, and unchanged external source bytes.

This is a versioned Logic 12.3 lane. It does not replace or reinterpret the
historical Logic 11.2.2 evidence in
[`LOGIC_MVP_VALIDATION_2026-07-14.md`](LOGIC_MVP_VALIDATION_2026-07-14.md).

The product is now named **TrackSmith**. The installed development app, AU display
name, bundle identifiers, and manufacturer/subtype codes retain the earlier
`Logic Audio Assistant` compatibility identity in this run.

## Exact environment and installed binaries

| Item | Evidence |
|---|---|
| Host | `/Applications/Logic Pro.app`, version 12.3, build 6674, bundle `com.apple.logic10` |
| Host binary/signature | Universal x86_64/arm64; Apple Team `F3LWYJ7GM7`; CDHash `be60f7ec31ed955307f7021641d763c26ce4988e` |
| OS | macOS 26.3, build `25D125`, arm64 |
| Toolchain used for source regressions | Xcode 26.6 (`17F113`), Swift 6.3.3 |
| Installed containing app | `~/Applications/Logic Audio Assistant.app`; bundle `com.marcboyer.logicaudioassistant`; Apple Development Team `KDV9RC892F`; CDHash `14d484cc3b52db2cd71acecdcfa0fd0fe3a6508d`; executable SHA-256 `e4b2c5bea7cf6c272b06388d88fae75c8b1b7a1eb08f46da932339dfd635b4e4` |
| Installed AUv3 | bundle `com.marcboyer.logicaudioassistant.AudioUnit`; version 1.0; `aufx` / `LgAA` / `ExAI`; Team `KDV9RC892F`; CDHash `e714e243969cbf0f1b0e0d5371db556cbeab9639`; executable SHA-256 `9d954c9ad84eecaa3513e375e2f9336b282ddbb51981d0cc84b73e8bf62d6aa2` |
| IPC container | `~/Library/Group Containers/KDV9RC892F.com.marcboyer.logicaudioassistant/LogicAudioAssistant/Exchange-v1` |
| Logic project runtime | 44,100 Hz, mono AU layout |

`pluginkit -m -A -D -i com.marcboyer.logicaudioassistant.AudioUnit` returned
the registered 1.0 extension. A fresh `auval -v aufx LgAA ExAI` exited zero with
`AU VALIDATION SUCCEEDED`; its only warning was Apple's deprecated
`CurrentPreset`/`PresentPreset` notice.

The installed bundle fingerprints above are the authority for the Logic run.
The later Swift package regressions and custom host probe exercised the current
working-tree source separately. This record does not pretend that an uninstalled
working-tree change was inside the signed AU.

## Disposable source and project

The generated source fixture was:

- path: `tmp/logic-validation-12.3/source-vocal-48k-mono.wav`;
- 8.000 s, 48,000 Hz, mono, PCM24, 1,152,044 bytes;
- SHA-256 before Logic work:
  `ad289bb28f37fd2bef753b176e7a371bf08fbb7b4c5c76adb5e83db2a694e2c0`;
- SHA-256 after capture, preview, commit, save/reload, duplication, targeted
  bypass/restore, and final save: the same value.

Logic copied/converted project media as expected; the external source was never
opened for writing. The disposable saved project is
`tmp/logic-validation-12.3/TrackSmith Logic 12.3 Validation 2026-07-14.logicx`.
Its first one-track `ProjectData` SHA-256 was
`e9da3e905c1005fc77074f0e8844a807380ac87459abb023d7c10899b3d0d313`;
after the explicit second-track isolation setup and final save it was
`cd2f65e208f7cf684f8c9606202727c5faeb02083032e01a3efeb4994d04bcce`.

## Real-host workflow ledger

### Discovery, insertion, and playback

Logic's Audio FX menu exposed both the recent `Logic Audio Assistant` entry and
`Audio Units > Marc Boyer > Logic Audio Assistant > Mono`. The AU was inserted on
the disposable audio track. During playback, its editor reported arriving audio
near -9.9 dBFS and Logic's track/output meters responded. The companion discovered:

- instance `6BD68072-166D-4927-9ED7-B35DEBA3B05B`;
- runtime epoch `057F8EBD-5318-4C33-994A-D62D51A3EE41`;
- 44,100 Hz, one channel, plug-in 1.0.0, global bypass false.

### Recent capture and three previews

After resetting to bar 1 and playing the complete fixture once, the companion sent
capture command sequence 1. The AU returned a descriptor-bound artifact:

- artifact `A0DDC21D-6C23-4449-A6CA-6809BB72BEBC`;
- 661,500 Float32 frames, 44,100 Hz, mono, 15.000 s;
- SHA-256 `376d4759107a068f03cf37ce422b3af4cf1ab40780c0362bf3ec3c8e89519261`;
- descriptor instance and runtime matched the selected live AU exactly.

Preview session `B5E7E05A-B7B2-4E54-9CD3-6A787E6D8068` produced three distinct
WAV payloads plus the bit-identical original:

| Variant | Measured match gain | SHA-256 |
|---|---:|---|
| Original | 0 dB | `376d4759107a068f03cf37ce422b3af4cf1ab40780c0362bf3ec3c8e89519261` |
| Conservative | +0.4820756 dB | `1cf333100e3fc7590a70a6d271bd6205b7a9fb488673a3744a4765029c7756c6` |
| Balanced | +2.3774343 dB | `6e9a26eaaf3954ed4862af2e7d54acea6a982c54c0be26a49f2bf3b369e319ef` |
| Strong | +7.0384287 dB | `19982b3743d4a17f249c992c520acb3701fb7fbced3887f7d731ca73510d3f19` |

The companion showed the waveform, local/no-upload status, match values, warnings,
and all editable graph cards. The strong preview's large compensation was visible
rather than hidden.

### Locked-node revision and exact commit

Balanced was selected as the working plan. Its 320 Hz parametric EQ was locked,
then the request `Use less compression` was rendered. The revision left the locked
EQ exactly at 320 Hz, -1.92 dB, Q 1.10 and changed only the intended compression
behavior plus the derived loudness-match node:

| Parameter | Balanced | Revision |
|---|---:|---:|
| Compressor ratio | 2.766 | 2.0596 |
| Compressor threshold | -18.9463 dB | -15.9463 dB |
| Compressor attack/release | 14 / 90 ms | 14 / 90 ms |
| Persisted loudness match | +2.3774 dB | +0.573109 dB |

High-pass 88 Hz, presence EQ 3.2 kHz/+1.5 dB, saturation 3 dB/0.264 mix,
the locked 320 Hz EQ, and the -1 dB limiter remained intact. Commit request
`138DB15A-B776-4E95-972D-40E0200D5D05` used command sequence 2 and received
acknowledgement `66150FD5-480E-41CB-98D0-F14AAAFFE563`. The next heartbeat carried
the exact seven-node graph, locked bit, source-snapshot ID, and revised values.

### Bypass and restore

The companion then exercised TrackSmith's graph-independent bypass:

- bypass command `D494C62A-204E-4FCE-865A-665B85B3323A`, sequence 3:
  heartbeat `globalBypassEnabled=true`, graph retained;
- restore command `84F90989-4835-4344-9A0C-5980DFC5F244`, sequence 4:
  heartbeat `globalBypassEnabled=false`, the same request ID and locked EQ retained.

This was TrackSmith's internal global bypass, not Logic's insert-slot bypass.

### Save and reload

The project was saved as a Logic package, closed, and reopened from disk. Logic
restored the AU and created a new live identity as expected:

- instance `A686A1F7-3B2F-49B2-AB1C-04EAF2FB68E1`;
- runtime epoch `86C86E82-8FCA-4920-8450-36C44CE0E98B`.

The reloaded heartbeat contained request
`E7B5526D-BC42-4E9C-9CCA-B294F8A0B578`, all seven nodes, the locked 320 Hz EQ,
compressor ratio 2.0596/threshold -15.9463 dB, and bypass false. A bounded live
poll during reloaded playback observed input peaks from -16.09 to -9.39 dBFS.
That is state-and-render evidence, not merely the presence of a plug-in slot.

### Multiple-instance isolation

Logic created a second track with the same AU settings, producing a separate live
identity:

- instance `E5DA0770-1F82-46C3-A586-B1092057BF50`;
- runtime epoch `489C7F87-784B-4D46-88E8-28E3B555B654`.

Both instances published independent fresh heartbeats at 44,100 Hz mono and held
their own serialized plan state. A new instance-bound capture/preview session made
the reloaded first instance controllable. Targeted bypass command
`E7C6A5D2-1D64-43AD-BB05-69F2B4DE3337` changed only instance `A686...` to
`globalBypassEnabled=true` and advanced only its sequence to 2. Instance `E5DA...`
remained false with no processed command. Restore command
`6E11FF72-5A2A-411A-B46D-79E22EEF58A3` advanced only `A686...` to sequence 3 and
returned it to false. This is direct routing/state isolation between two live Logic
AU instances.

## Current-source regression evidence adjacent to the host run

These are separate from the installed-binary Logic proof but close the relevant
working-tree regression lanes:

| Lane | Result |
|---|---|
| `TestRunner` Debug with 14 official BS.2217-2 vectors | 55/55 |
| `TestRunner` Release with the same vectors | 55/55 |
| `TestRunner` Thread Sanitizer (optional external vectors omitted) | 54/54; no race report |
| `AudioUnitHostProbe` Debug | pass; 288.8 us mean, 322.5 us p99, 1,531.6 us max at 48 kHz/128 frames |
| `AudioUnitHostProbe` Release | pass; 9.6 us mean, 11.2 us p99, 44.5 us max against a 2,666.7 us callback deadline |
| `AudioUnitHostProbe` Thread Sanitizer | pass; no race report; instrumented timing is not a release deadline claim |
| Real-time heap interposer | 4,000 callbacks, 0 observed allocation/free operations; 9.2 us mean, 10.0 us p99, 37.5 us max |
| Installed AU `auval` | `AU VALIDATION SUCCEEDED` |

## Test-driver and proof boundaries

The companion SwiftUI window was not attachable through the Computer Use service,
so this acceptance run used narrowly scoped macOS Accessibility actions to press
the companion's already-exposed controls and inspect values. Logic itself was
observed through its accessibility tree and screenshots. This is a **test driver**,
not a TrackSmith Accessibility feature, project-editing adapter, or supported
automation product path. No Accessibility implementation was added to TrackSmith.

This run does not prove subjective mix quality, buses, stereo output, freeze,
bounce, low-latency mode, general automation, every rate/buffer combination,
large-project load, or sustained many-instance performance. It also does not turn
Logic's UI into a public project API. Those remain open in
[`KNOWN_LIMITATIONS.md`](../KNOWN_LIMITATIONS.md) and the repeatable manual lane is
[`MANUAL_LOGIC_TESTS.md`](../MANUAL_LOGIC_TESTS.md).
