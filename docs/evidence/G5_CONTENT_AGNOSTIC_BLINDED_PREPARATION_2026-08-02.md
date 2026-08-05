# G5 content-agnostic blinded preparation — 2026-08-02

## Status

`prepared_pending_human_participation`. This is preparation metadata and audio
delivery only. It is not listening evidence, contains no participant responses,
and G5 remains pending.

The package contains 24 unique source windows and 28 presentation trials: 24
unique trials plus four hidden duplicate presentations. Each trial has three
opaque A/B/C condition references. The participant-facing directory has 84
distinct WAV paths: 72 unique stimulus contents and 12 byte-identical duplicate
copies, with 84 WAV references in the 28 trial rows. Participant trial IDs are
assigned after the seeded presentation shuffle, so duplicate presentations are
interleaved and do not form a sequential tail; duplicate links remain
operator-only.

Evidence class: `SINGLE_LISTENER_FORMATIVE_EVIDENCE`.

The participant schema now has eight questions and is protocol-complete for the
target-success, preservation, naturalness, clarity, production-value,
excitement, preference, and confidence dimensions. This remains preparation
only: it still lacks captured monitoring context and human responses.

The participant-facing instructions explicitly state that identifying the source
or effect is not required. They provide identity-neutral audible cues only:
attack/sustain/decay, room or tail length, brightness/clarity, dynamics and
pumping, stereo placement/width/motion, and noise or artifacts between phrases.
No instrument, vocal, source class, processor, condition role, or answer-key
identity is disclosed, and the response state remains empty.

## Participant delivery boundary

Participant delivery is exactly the `participant/` subdirectory:

`research/evaluation/production-mastery-v1/perceptual-study-v1/generated/content-agnostic-real-audio-blinded/participant/`

That export contains only `README.md`, `participant-manifest.json`,
`participant-response-template.json`, and `audio/*.wav` (84 files). The package
root is operator-only; its `answer-key.json`, `inventory.json`, and
`operator-response-template.json` (as well as any other root-level files or
duplicate copies) are withheld from participants. Source identities, condition
roles/effects, and hashes remain in the operator root and are not part of the
participant delivery.

## Preparation lineage

- 21 source windows were cropped from the original candidate bundles with
  `ffmpeg`, preserving each source window's sample rate and channel count.
- Three source windows use the preserved byte-identical window render sets in
  `generated/excluded-window-rerenders-2026-08-02`.
- Each trial's operator mapping retains the original reference, the valid
  conservative target when present (balanced fallback for the four rejected
  conservative renders), and the strong anchor. Participant labels and audio
  paths do not expose these roles or source identities.
- The operator answer key and inventory retain source IDs, source windows,
  input/final SHA-256 values, fallback decisions, recovered/inherited render
  metadata, and duplicate links. All response arrays remain empty.

## Verification

The temporary atomic builder was run with `--force`. The resulting checks passed:

```text
COUNTS_PASS unique_trials=24 presentations=28 participant_refs=84 unique_paths=84 unique_contents=72 wav_files=84 questions=8
RESPONSES_PASS zero
HASHES_PASS (all refs resolve and duplicate-copy final hashes match their source stimuli)
EXPORT_HASHES_PASS (all 84 participant/audio WAV exports were checked byte-for-byte against the withheld operator-root expectations)
INPUT_HASH_SEMANTICS_PASS (recovered rendered-window input hashes equal expected hashes; historical source hashes retained separately)
DUPLICATE_INTERLEAVING_PASS (participant IDs assigned after shuffle; operator-only links retained)
LEAK_SCAN (no matches)
git diff --check -- docs/evidence/G5_CONTENT_AGNOSTIC_BLINDED_PREPARATION_2026-08-02.md (exit 0)
```

All 84 WAV files in the `participant/audio/` export exist, every participant
audio reference resolves, and the export hash check passed byte-for-byte against
the withheld operator-root expectations; duplicate-copy final hashes match
their source stimuli. For the three recovered original windows, `input.sha256`
and `input.expectedSHA256` refer to the rendered recovered-window bytes; the
historical full-source hash remains separately recorded under the trial source
hashes. The participant manifest, README, and participant response template
contain no source IDs, class labels, effect/strength names, plan tokens, or
SHA-256 strings.
