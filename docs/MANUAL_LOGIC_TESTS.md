# Manual Logic test protocol

Direct Logic testing now has two versioned lanes. The 2026-07-13/14 Logic 11.2.2
lane completed the then-current signed build's MVP workflow; the separate 2026-07-14
Logic 12.3 lane repeated the critical workflow against an exactly hashed installed
compatibility build without rewriting the 11.2.2 record. Evidence and proof boundaries
are in
[`evidence/LOGIC_MVP_VALIDATION_2026-07-14.md`](evidence/LOGIC_MVP_VALIDATION_2026-07-14.md)
and
[`evidence/LOGIC_12_3_VALIDATION_2026-07-14.md`](evidence/LOGIC_12_3_VALIDATION_2026-07-14.md).
This protocol remains the source for the broader unpassed host matrix. Record exact
macOS, Logic, commit, signing identity, sample rate, I/O buffer, channel count,
low-latency mode, and result for every run.

## Prerequisites

1. In Xcode Settings → Accounts, add an Apple Account and create an Apple Development
   certificate under Manage Certificates. Ad-hoc and Configurator signatures have
   no Team ID and failed system registration on this machine.
2. Save and quit Logic so it does not retain a pre-install Audio Unit registry.
3. Run `make native-verify`; require the current portable suite to pass (68/68 when
   the selected official vectors are supplied), a native build, and a passing
   `AudioUnitHostProbe` full capture/preview/commit/revert round trip, including its
   host-buffer, scheduled-automation, reset/bypass, silence and tail-time cases.
4. Run `make native-install`; it must build Release, strict-verify a fresh staged
   bundle, replace the installed bundle exactly, and report the same nonempty Team ID
   for the app and extension. Then launch
   `~/Applications/Logic Audio Assistant.app` once.
5. Run `auval -v aufx LgAA ExAI`; require `AU VALIDATION SUCCEEDED` or a zero exit
   with every section passing. The last recorded signed build has only a preset deprecation
   warning. An earlier run also emitted a non-failing transient mono-input/stereo-
   output negotiation warning; record rather than assume future output.
6. Create a new disposable Logic test project. Never use unreleased/user work for
   experimental automation tests.
7. If macOS presents a data-access trust prompt, the user must decide it physically.
   Do not automate or bypass a system trust decision. Record repeated prompts as a
   failed packaging case rather than repeatedly clicking through them.
8. On this development Mac, any prompt requesting an administrator name or password
   is subject to the SafeSight maintenance-window policy. Do not enter credentials,
   bypass the delay, disable protection, or alter SafeSight. Defer that step until
   the user opens the authorized maintenance window; all non-admin tests may continue.

## Recorded Logic 12.3 evidence — 2026-07-14

- **Passed:** AU discovery/insertion, 44.1 kHz mono playback, and live instance
  discovery in Logic Pro 12.3 build 6674 on macOS 26.3 build 25D125.
- **Passed:** 15-second, 661,500-frame recent capture and three distinct previews,
  each with recorded SHA-256 and loudness-match gain.
- **Passed:** graph inspection, locked 320 Hz EQ preservation, targeted “Use less
  compression” revision, capture-bound commit, bypass/restore, save/reload, and
  two-live-instance targeted routing isolation.
- **Passed:** the PCM24 fixture SHA-256 was unchanged after the complete lane.
- **Proof boundary:** the installed AU's signing and executable hashes are recorded
  in the evidence ledger. This validates that compatibility binary in Logic 12.3;
  the working-tree regression suite is separate evidence.

## Recorded Logic 11.2.2 current-build evidence — 2026-07-13/14

- **Passed:** signed AU insertion, custom UI, changing input peak, and companion
  discovery on a 44.1 kHz stereo Logic runtime.
- **Passed:** 7.012-second instance-bound capture with verified SHA-256, rate,
  channels, frame count, and App Group containment.
- **Passed:** three valid, distinct previews matched within 0.000082 LU, with zero
  clipped samples and complete inspectable graph cards.
- **Passed:** locked 320 Hz EQ remained exact while `Use less compression` changed
  only the compressor and dependent loudness-match stage.
- **Passed:** capture-bound commit acknowledgement and applied-plan heartbeat,
  global bypass/restore with the graph retained, and project save/reload of the exact
  plan, lock, and bypass state.
- **Passed:** two instances appeared after track duplication; bypass/restore routed
  to one instance without changing its peer.
- **Passed:** both project-audio SHA-256 values remained unchanged.
- **Still open:** buses/stereo output, freeze/bounce, low-latency mode, general
  automation, complete rate/buffer coverage, large-project load, and sustained
  many-instance stress.

## Historical 2026-07-12 evidence

- **Passed observation:** Logic's insert menu listed Audio Units → Marc Boyer →
  Logic Audio Assistant and instantiated it on a mono audio track.
- **Passed observation:** the custom compact UI displayed and reported live input at
  -19.6 dBFS while the disposable region played.
- **Passed observation:** the companion discovered the Logic-hosted instance as
  44.1 kHz mono on the earlier signed Release iteration.
- **Passed observation:** undo removed the disposable insert and left the test
  project without the plug-in.
- **Historical boundary:** this earlier run predated the current source and did not
  prove capture or commit; the current-build run above supersedes that boundary.
- **Incident:** Logic displayed an instability alert during Computer Use/permission
  testing, recovered, and had no plug-in crash report; `SkyComputerUseService` did
  crash. An off-thread AU lifecycle/status race was fixed afterward as a plausible
  contributor, not a proven root cause. Any recurrence is a failed host case.

## Stable AU cases

- **AU-01 discovery/instantiate (partial):** mono and current-build stereo insertion,
  UI and live input passed. A manual Plug-in Manager row, bus, and stereo-output
  insertion remain open.
- **AU-02 pass-through/bypass:** empty graph must be bit-equivalent in offline host
  test and audibly transparent; confirm the live input peak changes, move output
  gain to -12 dB and back, then toggle Logic bypass repeatedly without glitches.
  A bypass transition must pass finite dry audio while the scheduled output-gain
  timeline continues; it must not replay a one-shot event after un-bypass.
- **AU-03 parameter automation:** automate output gain with immediate points and a
  ramp crossing at least two host callbacks; inspect timing/clicks, save, close
  Logic, reopen, verify values and automation. Trigger a host transport/reset
  discontinuity and require any in-flight ramp to reset; contrast that with bypass,
  which preserves and advances the ramp. General graph-node automation is not
  implemented and must not be recorded as passed.
- **AU-04 formats:** repeat 44.1/48/88.2/96/192 kHz and 32...1024 frame settings
  where Logic exposes them; change rate/buffer while stopped and during playback.
- **AU-05 transport context:** log non-real-time snapshots of transport/musical
  callbacks and `contextName`; test cycle, tempo/time-signature change, offline bounce.
  Do not log on render.
- **AU-06 capture:** play a known generated signal, request recent playback from the
  companion, compare chronology/WAV SHA-256 and ensure no microphone permission
  prompt or disk I/O on callback. “Capture next playback” is not implemented and
  must not be recorded as a pass.
- **AU-07 persistence:** commit a graph with locks and global bypass state, save the
  project, quit/reopen, and compare canonical serialized graph/bypass state and
  output hash. Companion undo history is expected to be in-memory only and must not
  be reported as project persistence.
- **AU-08 stress/failure:** 1/8/32 instances, companion absent/crashed, network off,
  malformed IPC, corrupt state, rapid UI closure, freeze and offline bounce. Logic
  must remain running and the last committed graph must remain available.
- **AU-09 host buffer/tail contract:** require the production-class probe to pass
  null output `mData`, upstream pull-pointer replacement, undersized byte counts,
  allocation-time maximum-frame enforcement, zero materialization for upstream
  silence, outgoing silence-hint clearing, and a static 180-second/-120 dB `tailTime` before
  treating the build as safe for Logic. Logic need not expose each synthetic host
  shape directly; do not infer this row from ordinary playback alone.

## Companion communication

- **IPC-01 (passed for current MVP):** both signed processes resolved the same App
  Group, and the companion discovered and exchanged capture/commit/bypass messages
  with the current Logic-hosted AU without a recurring trust prompt.
- **IPC-02 (passed for two instances):** the companion reconnected after restart,
  distinguished two simultaneous instance UUIDs, and routed bypass to only one.
- **IPC-03:** interrupt writes and verify partial files are ignored; test wrong
  instance/runtime epoch, expired commands, schema version, corrupt JSON, unsafe
  artifact paths, hash mismatch, oversized payload, stale expected-current plan, and
  locked-node rejection. No failed preflight may publish a commit command.
- **IPC-04:** measure message notification and plan-commit latency under Logic load.
- **IPC-05:** fill a disposable mailbox to each 2,048-file/32 MiB message limit and
  the 512-instance limit. Require one cross-process `flock`, fail-closed admission,
  and preservation of every unexpired command. With controlled file modification
  times, verify completed expired transactions become eligible after 10 minutes,
  diagnostics after 24 hours, and stale instance files after 10 minutes. Verify the
  AU performs maintenance no more often than every 60 seconds and its processed-ID
  set shrinks with the visible message set. Never run this quota test against a live
  user session.

## Companion end-to-end workflow

- **UI-01 discovery (passed for current MVP):** the current signed Release appeared
  as 44.1 kHz stereo with a changing input peak; capture/command communication
  continued through the AU-owned utility bridge independently of compact-UI work.
- **UI-02 recent capture:** play a known 10–20 second signal, stop, request recent
  playback, and verify waveform, duration, rate and channels. Confirm the exported
  artifact is immutable, inside the App Group root, mode 0600 and SHA-256 verified.
- **UI-03 previews:** request “make this clearer and more controlled.” Require three
  distinct valid level-matched previews, or an explicit rejected card when pairwise
  collapse/constraints fail. Switching during playback must remain synchronized.
- **UI-04 inspection:** compare every visible card with the serialized plan: type,
  parameters, rationale, confidence and category must agree.
- **UI-05 commit/revert:** commit Balanced while Logic is playing, then verify the AU
  output against an offline render of the same graph. Revert and require restoration
  of the pre-capture graph. Listen specifically for the known missing graph-crossfade
  click and record it rather than excusing it.
- **UI-06 revision/bypass:** lock an EQ, render “use less compression,” verify locked
  and unrelated nodes, commit it, then undo/redo. Toggle global bypass, save/reload,
  and require the graph to remain stored while finite audio is dry/sample-exact.
- **UI-07 acknowledgement semantics:** accept either a matching acknowledgement or
  applied-command heartbeat as proof of application/publication. Independently
  verify audio output; neither proves render-thread observation. Simulate a lost
  acknowledgement and verify there is no blind automatic retry.
- **UI-08 stale/runtime safety:** relaunch the AU so its runtime epoch changes, then
  verify an old command fails. Let its heartbeat age beyond five seconds and verify
  it disappears from the active list. If its file modification age reaches 10
  minutes, verify maintenance removes it; do not confuse five-second discovery
  filtering with durable-file retention.
- **UI-09 publication bound:** in a disposable run, exercise rapid commits without
  exceeding 128 publications per render allocation. The 129th must fail safely and
  leave the last graph active; normal use should never depend on this test limit.
- **UI-10 privacy deletion:** confirm **Delete Local Audio Cache**, then verify both
  App Group cache roots still exist but are empty while the Logic source, AU insert,
  committed `fullState`, active heartbeat and protocol messages remain intact.
  Protocol messages may later expire under mailbox maintenance; the delete-audio
  action itself must not interrupt them.

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
