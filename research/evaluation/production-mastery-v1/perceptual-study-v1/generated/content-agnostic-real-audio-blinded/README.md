# Opaque formative listening package

Evidence class: `SINGLE_LISTENER_FORMATIVE_EVIDENCE`.

> **Delivery boundary:** This root directory is operator-only and is not
> participant-distributable. Participant delivery is restricted to the
> `participant/` subdirectory. Do not send the root package or any root-level
> operator files to participants.

## Participant delivery allowlist

The complete participant package is the `participant/` subdirectory and only
the following paths within it are allowlisted for delivery:

- `participant/README.md`
- `participant/participant-manifest.json`
- `participant/participant-response-template.json`
- `participant/audio/*.wav` (84 opaque WAV files)

The parent directory retains operator-only answer-key, inventory, and response
template material for audit. Those files must stay outside participant delivery.

This directory is preparation only. It contains opaque presentations of
real-audio excerpts from the prepared audio set. Each trial is presented only
as anonymous A/B/C conditions, using distinct opaque WAV references. No
participant responses or listening judgments are included. G5 remains pending.

## Participant instructions

- No instrument, vocal, source class, effect, or condition role is provided or
  verified for participants. Do not infer an expected effect from an A, B, or C
  label.
- Source or effect identification is not required. Judge the audible result
  without naming what produced it or which processing may be present.
- If useful, use identity-neutral cues while comparing conditions: changes in
  attack, sustain, and decay; the length or character of a room or other tail;
  brightness, clarity, harshness, or muddiness; level movement, punch,
  pumping, or other dynamics; stereo placement, width, or motion; and noise,
  clicks, or other artifacts between phrases.
- Judge only what is audibly present. Across the eight questions, rate whether
  a change succeeds, what important content is preserved, naturalness, clarity,
  production value, excitement, preference, and confidence.
- Do not try to identify the source or guess which condition is reference,
  target, or anchor.

Before listening, record the monitoring context separately: listener code, room
or headphone path, interface, sample rate, bit depth, playback level, and date.
Use synchronized looping and matched playback gain. For every trial, listen to
the presented A/B/C conditions and answer the eight content-agnostic questions.
Keep identity and monitoring notes outside the participant response template.
