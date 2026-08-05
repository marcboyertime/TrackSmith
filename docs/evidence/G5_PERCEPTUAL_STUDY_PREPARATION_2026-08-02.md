# G5 perceptual-study preparation — 2026-08-02

## Status

**Prepared; G5 remains pending.** This note records protocol and manifest
preparation only. It contains no participant, preference, or perceptual-success
result.

## Bounded preparation

`research/evaluation/production-mastery-v1/perceptual-study-v1/` adds a standard-
library generator and analyzer for a blinded, randomized, level-matched A/B/C
formative study. The package selects 24 accepted natural-audio index entries,
four each from vocals, drums, bass, guitars, keys, and overall mix. It preserves
each selected artifact SHA-256, byte count, source-capture ID/SHA-256, member
path, PCM metadata, and a deterministic excerpt window. It also records the six
existing DSP listening fixtures and their source/candidate/plan/analysis hashes
and existing `bs1770Integrated` metadata. No dataset was downloaded or changed.

The participant manifest exposes only anonymous trial and condition labels. The
operator answer key stores the randomization seed, source identity, condition
roles, four hidden duplicate links, and hidden anchors separately. Eight
plain-language questions keep target success, preservation, naturalness,
clarity, production value, excitement, preference, and confidence distinct.

The package intentionally does not claim MUSHRA. Natural-audio condition renders
and their measured loudness gains are still pending; the generated metadata uses
`pending_real_audio_condition_render` and never invents a response or a gain.
Human participation, response export, predeclared exclusions, and any later
summary statistics remain open G5 gates.

## Reproduction evidence

```text
python3 .../generate_study.py
  unique_natural_excerpts=24
  presentation_trials=28
  participant_responses=0

python3 .../analyze_study.py --write-report
  ANALYSIS_PASS
  sourceClasses={bass: 4, drums: 4, guitars: 4, keys: 4,
                 overall_mix: 4, vocals: 4}
  hiddenDuplicates=4 hiddenAnchors=28 participantIdentityLeaks=0
  participantResponses=0 deterministic=true
```

These are preparation checks, not human listening evidence.
