# G5 real-audio pilot preparation — 2026-08-02

## Status

The six-fixture real-audio pilot is verified and ready for blinded formative
listening. G5 remains pending: no participant responses have been collected,
and this pilot does not close the original 24-excerpt natural-audio study.

Evidence class: `SINGLE_LISTENER_FORMATIVE_EVIDENCE`.

## Fresh commands

```text
python3 research/evaluation/production-mastery-v1/perceptual-study-v1/generate_real_audio.py
GENERATE_REAL_AUDIO_PASS pilot=tracksmith-g5-real-audio-six-fixture-pilot seed=20260802 trials=6 conditions=18 participant_responses=0

python3 research/evaluation/production-mastery-v1/perceptual-study-v1/analyze_real_audio.py --analysis-cli .build/debug/AnalysisCLI
REAL_AUDIO_ANALYSIS_PASS {"boundedFailureCount": 0, "generatedAudioCount": 18, "participantIdentityLeaks": 0, "participantResponses": 0, "status": "verified"}
```

The analyzer measured all 18 generated WAVs. The TrackSmith AudioAnalysis
BS1770Meter handled 6 conditions; the remaining 12 used the explicitly reported
`ffmpeg ebur128` fallback after the local AnalysisCLI subprocess terminated with
SIGTRAP. This is a bounded measurement fallback, not a claim that all 18 used
the native meter. There are 11 unique byte-identical files after concealed
reference/anchor duplication. All six trials passed the 0.5 LU tolerance and
the -1 dBTP ceiling.
The reverb-short-drum-room target is a generated candidate copy with a declared
deterministic +0.9 dB gain correction; the checked-in source and candidate
fixtures remain unchanged. The correction is retained in the operator answer
key and generation report.

## Blinding and response boundary

The participant manifest exposes only `Trial NNN`, `A/B/C`, opaque stimulus
references, the eight plain-language questions, and monitoring-context prompts.
The operator answer key retains roles, fixture identities, input hashes, and
correction metadata separately. The participant and operator response templates
contain zero responses. No preference, perceptual-success, population, or MUSHRA
claim is made.

## Artifacts

- `research/evaluation/production-mastery-v1/perceptual-study-v1/generated/real-audio-pilot/audio/`
- `research/evaluation/production-mastery-v1/perceptual-study-v1/generated/real-audio-pilot-participant-manifest.json`
- `research/evaluation/production-mastery-v1/perceptual-study-v1/generated/real-audio-pilot-answer-key.json`
- `research/evaluation/production-mastery-v1/perceptual-study-v1/generated/real-audio-pilot-analysis.json`
- `research/evaluation/production-mastery-v1/perceptual-study-v1/generated/real-audio-pilot-participant-response-template.json`
- `research/evaluation/production-mastery-v1/perceptual-study-v1/generated/real-audio-pilot-operator-response-template.json`

Remaining G5 gate: the user must listen under documented monitoring context and
submit the blinded responses before any subjective evidence or G5 promotion.
