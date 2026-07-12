# Logic integration spike

## Environment and commands

Observed 2026-07-12:

```text
macOS 26.3 (25D125), arm64
Logic Pro 11.2.2, bundle id com.apple.logic10, x86_64 + arm64
Swift 6.2.1
xcode-select: /Library/Developer/CommandLineTools
Xcode.app: absent
auval: present
XcodeGen: /opt/homebrew/bin/xcodegen
```

`codesign -dv` confirms the installed Logic bundle is Apple-signed and universal.
`sdef Logic Pro.app` could not inspect a scripting dictionary because `sdef` in
this environment refuses to run without full Xcode. No AppleScript capability is
therefore claimed.

## Runnable proofs

1. `xcodegen generate` produced `LogicAudioAssistant.xcodeproj` with a macOS app,
   AUv3 effect extension, local package dependencies, sandbox, and App Group files.
2. `swift build` and `swift build -c release` build the portable products.
3. `swift run -c release TestRunner` passes 13/13 deterministic checks.
4. `swift run -c release CompanionApp make this clearer and more controlled`
   renders conservative/balanced/strong plans and reports all three valid and
   level matched for the generated signal.
5. `PluginProbe` wrote an atomic heartbeat; `CompanionApp --ipc-status` read the
   same UUID/kind/text from another release-built process.

The IPC proof uses `/tmp` because unsigned command-line processes cannot resolve a
production App Group. The shipped target must substitute the signed group container.

## AU experiment status

The extension source declares an `aufx` component, input/output buses, parameter
tree, atomic output-gain publication, pull-input render block, in-place sample
processing, sandbox entitlements, and a compact UI. It is **source-complete as a
scaffold, not a validated Audio Unit**. Full Xcode is required to compile/sign the
extension. Only then can `auval`, Plug-in Manager, Logic insertion, save/reload,
automation, bounce, low-latency, and multi-instance tests run.

The current render block applies only output gain. `DSPCore` and the capture ring
are tested independently; a no-allocation host-buffer adapter, prepared graph swap,
format-change capture reconstruction, and sample-accurate automation event handling
must be added before calling the shared graph production real-time safe.

## Recommended architecture

Proceed with AUv3 + companion + App Group. Keep import/offline rendering as a full
fallback. Add Core MIDI virtual endpoints only for explicit user assignments. Treat
control-surface protocols as state-limited adapters, Accessibility as experimental,
and ARA 2 as a separately licensed future investigation. Do not invest in AUv2
unless Logic-host measurements reveal an AUv3-specific blocker.

## Highest-risk next experiment

Install/select full Xcode, replace example signing identifiers/team, build the app
and extension, validate with `auval -v aufx LgAA ExAI`, then run Manual Tests AU-01
through AU-08. The key evidence is whether Logic instantiates the AUv3, supplies the
expected noninterleaved formats/transport callbacks, persists state, and permits the
signed companion/extension exchange reliably across multiple instances.
