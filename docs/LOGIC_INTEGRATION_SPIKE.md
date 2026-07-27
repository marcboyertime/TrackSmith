# Logic integration spike

## Environment and commands

Observed through 2026-07-16:

```text
macOS 26.3 (25D125), arm64
Logic Pro 12.3 (build 6674), bundle id com.apple.logic10, x86_64 + arm64
Historical validated host: Logic Pro 11.2.2
Swift 6.3.3
xcode-select: /Applications/Xcode.app/Contents/Developer
Xcode 26.6 (17F113), macOS SDK 26.5
auval: present
XcodeGen: /opt/homebrew/bin/xcodegen
```

`codesign -dv` confirms the installed Logic bundle is Apple-signed and universal.
No useful public Logic project scripting interface has been proven. No AppleScript
capability is therefore claimed.

## Runnable proofs

1. `xcodegen generate` produced `LogicAudioAssistant.xcodeproj` with a macOS app,
   AUv3 effect extension, local package dependencies, sandbox, and App Group files.
2. `swift build` and `swift build -c release` build the portable products.
3. The current source passes 68/68 deterministic `TestRunner` checks in clean
   Debug build, including
   split-band de-esser selectivity, real-time/offline parity with de-essing active,
   nonfinite-input sanitation, plan-complexity bounds, captured-instance binding,
   artifact WAV metadata matching, fail-closed ring snapshots, locked-node commit
   protection, exact materialized preview graphs, commit preflight before IPC,
   lost-acknowledgement reconciliation, final-limiter/declared-peak consistency,
   checked-in schema/runtime-bound parity, fail-closed commit-time peak validation,
   and bounded mailbox retention/message-file quota behavior. Current Debug,
   Release, and Thread Sanitizer runs pass 68/68 with 14 official BS.2217-2 vectors;
   the sanitizer exits without a report.
4. `swift run -c release CompanionApp make this clearer and more controlled`
   renders conservative/balanced/strong plans and reports all three valid and
   level matched for the generated signal.
5. The containing app and extension have matching signed
   `KDV9RC892F.com.marcboyer.logicaudioassistant` entitlements and resolve the shared
   container. The current exchange uses versioned atomic messages, heartbeat-based
   instance discovery, runtime epochs, command expiry, 0700 directories, 0600 files,
   bounded payloads and SHA-256-verified capture artifacts. Current source adds a
   bounded cross-process `flock`, 2,048-file/32 MiB message and 512-instance quotas,
   per-runtime command sequences, terminal-response reservation, strict reply
   correlation, live-command protection, fail-closed admission, and timed retention.
6. Xcode builds the native SwiftUI containing app and AUv3. Its first automatic
   local signature was ad-hoc, with no Team ID.
7. `AudioUnitHostProbe` registers and instantiates `AssistantAudioUnit`, negotiates
   noninterleaved Float32 mono at 44.1 kHz and stereo at 96 kHz, verifies dry capture,
   live graph publication and `fullState`, then exercises the session round trip:
   heartbeat discovery, recent capture, immutable hashed WAV publication, three
   locally rendered previews, exact balanced commit, locked-EQ “use less compression”
   revision, undo/redo, graph/global-bypass reload, two-instance isolation,
   AU/offline output parity, and a bit-exact dry revert. It also proves capture is
   destroyed on deallocation, deallocated IPC capture publishes no artifact, and a
   reallocated ring contains only new playback. Lifecycle-locked commit controls
   reject a mismatched captured snapshot, stale expected graph, changed sample rate
   and deallocated resources without changing live or serialized state. Its recorded
   Release callback timing for a representative 128-frame/48 kHz graph is 9.6 us
   mean, 11.2 us p99, and 44.5 us maximum against a 2,666.7 us deadline; the expanded
   probe also exits cleanly under Thread Sanitizer. A development heap interposer
   observed zero standard/aligned/zone heap operations across 4,000 callbacks. Those
   are current custom-host
   results, not Logic-load certification. Current probe coverage includes null-output/upstream-
   pointer layouts, bounded scheduled output-gain ramps, native bypass, reset/bypass
   timeline semantics, conservative silence/tail behavior, and one graph per
   callback.
8. The first ad-hoc build had no Team ID and did not register. After creating an
   Xcode-managed Apple Development certificate, the installer derived Team ID
   `KDV9RC892F` from the certificate OU, built a Release app and extension with
   matching signatures, enabled App Sandbox, strict-verified a fresh staging bundle,
   and replaced the destination bundle exactly. This prevents obsolete files from a
   prior build from surviving and invalidating the code seal.
9. The current 2026-07-13 Apple Development-signed Release is installed and
   strict-verified. `pluginkit` reports its extension identifier. `auval -v aufx LgAA ExAI`
   discovered version 1.0.0 as an
   out-of-process AUv3 and
   passed open, required/recommended properties, class state, host callbacks,
   parameter persistence/scheduling, mono and stereo render, 11.025–192 kHz sample
   rates, 64–4096-frame render probes, connection semantics and maximum-frame error.
   Explicit format validation rejects all probed asymmetric and 4–8-channel layouts.
   The recorded run retained only the `CurrentPreset`/`PresentPreset` deprecation
   warning. An earlier validator run emitted a non-failing transient 1-in/2-out
   legacy-proxy negotiation warning; it did not recur in that signed run. A
   focused production-class HostProbe rejects actual 1→2 and 2→1 resource
   allocations, confirming allocation requires equal mono or stereo channel counts.
   The result is current-source packaging/validator evidence, not a Logic workflow test.
10. `xcrun sdef /Applications/Logic Pro.app` returns only generic application,
    document, window, text and printing suites. It provides no Logic track/region/
    mixer/plug-in/automation project model.
11. A direct Logic Pro 11.2.2 test on 2026-07-12 proved insert-menu discovery under
    Audio Units → Marc Boyer, insertion on a mono audio track, display of the custom
    compact AU UI, live input status at -19.6 dBFS while the region played, companion
    discovery at 44.1 kHz mono, and undo/removal of the disposable insert.
12. A fresh current-build Logic Pro 11.2.2 run on 2026-07-13/14 proved the signed AU's
    insertion, 44.1 kHz stereo playback/discovery, verified recent capture, three
    previews, graph inspection, locked-node revision, compare-and-swap commit,
    bypass/restore, save/reload of the exact committed state, and isolation between
    two instances. Source-file hashes remained unchanged. The auditable record is
    [`evidence/LOGIC_MVP_VALIDATION_2026-07-14.md`](evidence/LOGIC_MVP_VALIDATION_2026-07-14.md).
13. Logic displayed an instability alert during Computer Use and permission testing.
    Logic recovered, the disposable insert was undone, and no plug-in crash report
    was present. `SkyComputerUseService` did crash. An off-thread AU lifecycle/status
    data race was fixed afterward as a plausible code contributor, but there is not
    enough evidence to identify it as the alert's root cause.
14. A separate Logic Pro 12.3 run on 2026-07-14 proved AU discovery/insertion,
    playback, live instance discovery, recent capture, three distinct previews,
    graph inspection, locked-node targeted revision, commit, bypass/restore,
    save/reload, two-live-instance command isolation, and unchanged fixture bytes.
    The installed AU was identified by exact signing and executable hashes; it is a
    compatibility build and is not silently equated with the uninstalled working
    tree. The versioned record is
    [`evidence/LOGIC_12_3_VALIDATION_2026-07-14.md`](evidence/LOGIC_12_3_VALIDATION_2026-07-14.md).

Portable command-line tests use temporary directories so they do not require signed
entitlements. The signed app/AU path uses the shared App Group container. Both paths
run the same `FileExchange` validation and atomic publication code.

## AU experiment status

The extension declares an `aufx` component, validated mono/stereo buses, parameter
tree, atomic output-gain publication, pull-input render block, deterministic borrowed-
buffer graph processing, bounded dry capture, full-state graph serialization, and a
compact UI with input activity and gain. Its AU-owned bridge runs on a utility queue
even when the view is closed. Plan validation/compilation, capture snapshots, WAV
writing and IPC occur off render; the callback performs no file/network work.

The current source is **compiled, class-host tested, development-signed,
system-registered, `auval` validated, and Logic workflow tested**. It has 68/68
Debug, Release, and Thread Sanitizer portable passes with the official vector
subset, plus clean HostProbe lanes. Logic 11.2.2 directly proved
the then-current-build MVP; Logic 12.3 separately proved the same critical workflow
against the exact installed compatibility binary recorded in its evidence ledger
and later completed the credential-backed frontier-AI workflow through save/reload
and provider-offline graph restoration.
The latter is host-compatibility evidence, not proof that every uninstalled working-
tree change ran inside Logic. Automation, bounce, freeze, low-latency mode, buses,
stereo output, and the complete rate/buffer matrix remain open. A complete graph can
be atomically published during
playback and becomes eligible for the next callback. Render-resource lifecycle and
status snapshots are serialized by the lifecycle lock. Retired graphs remain alive
until resource deallocation, with a 128-publication cap per allocation. Click-free
old/new graph crossfading and general graph-node render-event handling remain future
work. Output gain now handles bounded sample-offset immediate/ramp events while one
graph remains selected for the complete callback. Host reset cancels the scheduled
timeline; bypass preserves and advances it. Acknowledgement means “published,” not
“observed by a render callback.”

Companion commit now uses the same lifecycle lock for captured snapshot identity,
current format, expected graph, locked-node validation, graph publication and
serialized state advance, excluding host deallocation and `fullState` restoration
from the transaction. Capture storage is cleared during deallocation and recreated
empty; the class host proves stale audio cannot be returned directly or through IPC
across that boundary.

## Recommended architecture

Proceed with AUv3 + companion + App Group. Keep import/offline rendering as a full
fallback. Add Core MIDI virtual endpoints only for explicit user assignments. Treat
control-surface protocols as state-limited adapters, Accessibility as experimental,
and ARA 2 as a separately licensed future investigation. Do not invest in AUv2
unless Logic-host measurements reveal an AUv3-specific blocker.

## Highest-risk remaining experiments

The fresh native HostProbe, signed `auval`, Logic 11.2.2 workflow, and separate Logic
12.3 workflow are complete. Next, complete the unpassed portions of Manual Tests
AU-01 through AU-08: stereo/bus/output insertion,
automation, transport callbacks, persistence, bounce, low-latency and multiple
instances. Record each case independently; the proven mono insertion and input path
must not be generalized to an untested host mode.
