# TrackSmith G5 perceptual-study-v1

This is a preparation package for `SINGLE_LISTENER_FORMATIVE_EVIDENCE`. It does
not contain participant responses, does not claim perceptual success, and does
not promote G5. The package reads only the accepted natural-audio index and the
existing six-fixture DSP listening suite; it never downloads, copies, or renders
audio.

The selected corpus material is 24 indexed MixAssist excerpts: four each from
vocals, drums, bass, guitars, keys, and overall mix. `source-manifest.json`
retains the exact asset IDs, member paths, source-capture hashes, artifact
hashes, byte counts, PCM descriptors, and deterministic excerpt windows. The
fixture records retain source/candidate/plan/analysis hashes and their existing
`bs1770Integrated` level-match metadata.

`generated/participant-manifest.json` is the participant-facing artifact. It
contains only `Trial NNN`, `A/B/C`, opaque `stimulus-NNN-X` references, playback
and level-match requirements, and eight plain-language questions. It does not
contain source, dataset, track, fixture, candidate, or plan identities.
`generated/answer-key.json` is operator-only and keeps the seed, source mapping,
condition roles, hidden duplicate links, and hidden anchors separate from those
labels. `generated/level-match-metadata.json` records the planned method and
leaves natural-audio condition gains as `null` until real-audio renders exist.

The protocol is deliberately auditable A/B/C, not MUSHRA. MUSHRA terminology is
not claimed because this package has no scored training/reproduction session,
real-audio condition renders, human responses, or power-aware statistical result.
G5 remains pending until the user participates after the real-audio conditions
are rendered and verified at matched loudness.

## Generate and audit

From the repository root:

```sh
python3 research/evaluation/production-mastery-v1/perceptual-study-v1/generate_study.py
python3 research/evaluation/production-mastery-v1/perceptual-study-v1/analyze_study.py --write-report
```

The generator uses seed `20260802` by default and writes deterministic JSON.
The analyzer verifies 24 unique excerpts, six classes at four excerpts each, 28
presentation trials (including four concealed duplicate presentations), one
concealed anchor per trial, exact source/fixture hashes, anonymous participant
labels, and zero responses. Re-run with another `--seed` only when a new study
session is intentionally prepared; keep the resulting answer key with the
participant manifest.

Before a real session, an operator must prepare and hash real-audio reference,
target, and anchor renders for every excerpt, verify BS.1770 integrated
loudness within the stated tolerance and true-peak ceiling, document monitoring
context, and keep identities hidden until judgment. No response file belongs in
this preparation package.
