# Logic integration spike

## Environment and commands

Observed 2026-07-12:

```text
macOS 26.3 (25D125), arm64
Logic Pro 11.2.2, bundle id com.apple.logic10, x86_64 + arm64
Swift 6.2.1
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
3. `swift run -c release TestRunner` passes 22/22 deterministic checks.
4. `swift run -c release CompanionApp make this clearer and more controlled`
   renders conservative/balanced/strong plans and reports all three valid and
   level matched for the generated signal.
5. `PluginProbe` wrote an atomic heartbeat; `CompanionApp --ipc-status` read the
   same UUID/kind/text from another release-built process.
6. Xcode builds and locally signs the native SwiftUI containing app and AUv3.
7. `AudioUnitHostProbe` registers and instantiates `AssistantAudioUnit`, negotiates
   noninterleaved Float32 mono at 44.1 kHz and stereo at 96 kHz, renders a serialized
   polarity graph plus AU output gain, verifies dry capture, and restores the plan
   through `fullState`.
8. LaunchServices records the corrected AU extension metadata and factory. Because
   Logic and AudioComponentRegistrar were already running, `auval` did not refresh
   to the new component during the session; Logic-host validation remains open.

The IPC proof uses `/tmp` because unsigned command-line processes cannot resolve a
production App Group. The shipped target must substitute the signed group container.

## AU experiment status

The extension declares an `aufx` component, validated mono/stereo buses, parameter
tree, atomic output-gain publication, pull-input render block, deterministic borrowed-
buffer graph processing, bounded dry capture, full-state graph serialization, and a
compact UI with input activity and gain. Plan validation/compilation and capture
allocation occur before rendering; the callback performs no file/network work.

It is **compiled and class-host tested, not yet Logic validated**. `auval`, Plug-in
Manager, Logic insertion, automation ramps, bounce, low-latency, multiple instances,
and save/reload still require a clean host test. Graph changes are staged only while
render resources are deallocated; atomic whole-graph publication during playback and
sample-accurate AU render-event handling remain future work.

## Recommended architecture

Proceed with AUv3 + companion + App Group. Keep import/offline rendering as a full
fallback. Add Core MIDI virtual endpoints only for explicit user assignments. Treat
control-surface protocols as state-limited adapters, Accessibility as experimental,
and ARA 2 as a separately licensed future investigation. Do not invest in AUv2
unless Logic-host measurements reveal an AUv3-specific blocker.

## Highest-risk next experiment

Quit Logic, install and launch the signed development containing app, validate with
`auval -v aufx LgAA ExAI`, then run Manual Tests AU-01 through AU-08. The key evidence
is whether Logic instantiates the AUv3, supplies the
expected noninterleaved formats/transport callbacks, persists state, and permits the
signed companion/extension exchange reliably across multiple instances.
