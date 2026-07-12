# Manual Logic test protocol

No case below has passed yet. Record exact macOS, Logic, commit, signing identity,
sample rate, I/O buffer, channel count, low-latency mode, and result for every run.

## Prerequisites

1. Install full Xcode, run first-launch components, and select it with `xcode-select`.
2. Replace example bundle/App Group IDs and select an Apple Development team.
3. `xcodegen generate`, open the project, build the companion app and extension.
4. Confirm extension registration with `pluginkit`; run
   `auval -v aufx LgAA ExAI`. Save complete output.
5. Create a new disposable Logic test project. Never use unreleased/user work for
   experimental automation tests.

## Stable AU cases

- **AU-01 discovery/instantiate:** open Plug-in Manager, locate the AU3 label, insert
  on mono audio, stereo audio, bus and stereo output; verify audio and UI status.
- **AU-02 pass-through/bypass:** empty graph must be bit-equivalent in offline host
  test and audibly transparent; toggle Logic bypass repeatedly without glitches.
- **AU-03 parameter automation:** automate output gain, inspect ramps/clicks, save,
  close Logic, reopen, verify values and automation.
- **AU-04 formats:** repeat 44.1/48/88.2/96/192 kHz and 32...1024 frame settings
  where Logic exposes them; change rate/buffer while stopped and during playback.
- **AU-05 transport context:** log non-real-time snapshots of transport/musical
  callbacks and `contextName`; test cycle, tempo/time-signature change, offline bounce.
  Do not log on render.
- **AU-06 capture:** arm “next playback,” play known generated signal longer than ring
  capacity, stop, snapshot outside render, compare chronology/hash and ensure no
  microphone permission prompt or disk I/O on callback.
- **AU-07 persistence:** commit a graph with locks/history, save project, quit/reopen,
  compare canonical serialized state and output hash.
- **AU-08 stress/failure:** 1/8/32 instances, companion absent/crashed, network off,
  malformed IPC, corrupt state, rapid UI closure, freeze and offline bounce. Logic
  must remain running and the last committed graph must remain available.

## Companion communication

- **IPC-01:** verify both signed processes resolve the same App Group URL.
- **IPC-02:** distinguish simultaneous instance UUIDs and reconnect after app quit.
- **IPC-03:** interrupt writes and verify partial files are ignored; test stale plan,
  wrong instance, wrong snapshot, schema version and oversized payload rejection.
- **IPC-04:** measure message notification and plan-commit latency under Logic load.

## Control adapters (separate experimental build only)

- **MIDI-01:** create virtual endpoints, configure an explicit disposable Logic
  controller assignment, verify transport/parameter feedback and teardown.
- **CS-01:** test built-in Mackie/HUI mapping without inferring a stable track ID from
  a display string. Record every message and ambiguous state.
- **AX-01:** after user enables the feature and permission, dump semantic roles/
  labels/actions for the disposable project. Reject any workflow requiring screen
  coordinates. Change window layout and repeat.
- **AX-02:** for any action, capture precondition, perform one action, read and verify
  postcondition. On mismatch stop immediately. Bounce/replace-track is excluded until
  a recovery proof exists.

## Pass criteria

No crash, hang, glitch, unsafe output, unexplained state loss, stale commit, source
overwrite, or unverifiable project mutation. A failure is a failed case, not a reason
to relax verification or silently fall back to coordinates.
