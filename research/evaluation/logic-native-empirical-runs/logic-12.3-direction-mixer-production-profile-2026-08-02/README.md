# Logic Pro 12.3 Direction Mixer capture package

Status: **partial_bounded_profile_pending_review**. This directory contains a
bounded manual Logic 12.3 capture for campaign identity
`logic-pro-12.3:direction-mixer`. Only the fresh header-bypass stereo-left-only
transition plus three settled repeats are retained as accepted evidence; the full
LR/MS/Split campaign remains open. The machine-readable authority is
[run.json](run.json), with the original preparation authority preserved in
[capture-plan.json](capture-plan.json).

## Prepare and verify the fixtures

Run the exact generator command from the repository root:

```bash
swift run TestSignalGenerator --logic-measurement-suite research/evaluation/logic-native-empirical-runs/logic-12.3-direction-mixer-production-profile-2026-08-02/fixtures --sample-rate 48000
python3 -m json.tool research/evaluation/logic-native-empirical-runs/logic-12.3-direction-mixer-production-profile-2026-08-02/fixtures/manifest.json >/dev/null
python3 -m json.tool research/evaluation/logic-native-empirical-runs/logic-12.3-direction-mixer-production-profile-2026-08-02/capture-plan.json >/dev/null
```

The manifest is authoritative for hashes, frame counts, channels, duration, and
purpose. The required Direction Mixer set is:

`silence_mono.wav`, `single_impulse_mono.wav`,
`log_sweep_20hz_20khz_mono.wav`, `multitone_mono.wav`,
`amplitude_ladder_1khz_mono.wav`, `stereo_in_phase.wav`,
`stereo_left_only.wav`, `stereo_right_only.wav`, `stereo_anti_phase.wav`,
`stereo_one_sample_offset.wav`, and `stereo_mid_low_side_high.wav`.

The generator retains eight supplemental probes (impulse level ladder, DC offset,
two IMD pairs, noise bursts, guitar-like, bass-like, and vocal-like). They are
listed separately in `capture-plan.json`; none is real source or perceptual proof.

## Operator checklist for the later manual capture

1. Record the exact macOS, hardware, Logic 12.3 build 6674, Direction Mixer component,
   audio device, buffer, plug-in delay compensation, and low-latency state before
   importing anything. A missing observed value is `null` with an evidence note;
   do not infer it.
2. Copy generated WAVs into the disposable Logic project's `sources/` directory.
   Hash the original and copy before import and after every render. Never use the
   only copy of user audio and never edit a fixture.
3. Set the project to 48 kHz first. Use 24-bit WAV, 120 BPM, stereo only for the
   Direction Mixer instance, neutral fader/pan, Stereo Out, no sends/inserts/
   automation, metronome/count-in off, normalization/dither off. Record all
   visible project settings and the exact cycle range.
4. Bounce a same-path unprocessed baseline, then capture header bypass and the
   freshly inserted documented default. The cycle must equal each fixture's
   manifest duration; frame/channel/rate/alignment errors reject the artifact.
5. Capture LR and MS. For each mode record center Direction, left/right quarter
   turns, both extremes, and Spread minimum, unity, first supported value above
   unity, and maximum. Local reviewed documentation gives LR Spread 0/1 and MS
   Spread 2 as semantic references, but every actual visible UI value is recorded.
6. Use the required in-phase, left-only, right-only, anti-phase, one-sample-offset,
   and mid-low/side-high fixtures. Measure the channel matrix, polarity, gain,
   peaks, correlation, mid/side energy, low-band side, and mono sum.
7. Capture Split disabled, then Split enabled at two evidence-led crossovers:
   choose the visible values nearest 500 Hz and 2 kHz (between the fixture's
   100 Hz and 5 kHz components) and record the exact displayed values. Record
   low and high Direction/Spread independently for neutral, low-narrow/high-wide,
   and opposite-quarter-turn branch states.
8. Keep the first render after every insert, bypass/mode/split/crossover/branch
   transition and reload as `transition`. After controls settle, acquire three
   unchanged settled repeats for every decisive state. Hash equality is evidence
   only for that exact state.
9. Save normally, close normally, reopen, and verify the full visible state. Take
   after-reload screenshots, then render one bypass/default and one complex split
   state again. A displayed value without matching hashes is not reload evidence.
10. Store files using the patterns in `capture-plan.json`: state/fixture/repeat/
    transition-or-settled renders, state screenshots, analysis JSON, source and
    render hashes, and the closed project archive. For a full campaign run, do not
    create `run.json` until native evidence is complete and audited; this bounded
    partial profile is an explicit exception and records its incomplete scope.

## Acceptance boundary

This package records a bounded native Logic profile: one documented host-bypass
state, one stereo left-only fixture, and three settled repeats with exact decoded
PCM. It does not establish the full Direction Mixer transfer function, LR/MS/Split
coverage, installed/native TrackSmith control authority, mono compatibility, artistic
quality, or superiority. Source-specific listening remains a separate future human
boundary requiring legally usable real drums, guitar, keyboard/piano, synth, and mix
material with level matching, identity-blind judgment, and provenance. TrackSmith
remains advisory-only for the Logic-native effect.
