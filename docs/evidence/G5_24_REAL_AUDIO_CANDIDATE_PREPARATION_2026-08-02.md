# G5 24 Real-Audio Candidate Preparation (2026-08-02)

Status: `candidate_render_preparation_only`

This record covers local PreviewCLI preparation for the 24 sorted unique
`sourceAssetID` values in `generated/answer-key.json`. Render-time BS.1770
loudness matching was performed per render, with `loudnessMatchGainDB`
recorded in the manifests; no additional study-level matching, listening,
perceptual judgment, or study analysis was performed.

## Render inputs

- CLI: `.build/arm64-apple-macosx/release/PreviewCLI`
- Prompt: `make this more musical and controlled without sounding overprocessed`
- Source WAV root: `.build/research-source-candidates/2026-07-22-production-intelligence-gap/extracted/audio/mixassist_by_group/`
- Source-class mapping: `vocals -> vocal`, `guitars -> guitar`, `keys -> keyboard`,
  `overall_mix -> fullMix`; `drums` and `bass` map directly.
- Each source was retained in a dedicated bundle directory under
  `research/evaluation/production-mastery-v1/perceptual-study-v1/generated/full-real-audio-candidate-bundles/`.

## Integrity counts

The generated `index.json` records source and candidate SHA-256 hashes for all
24 entries.

| Artifact | Expected | Observed |
| --- | ---: | ---: |
| Source bundle directories | 24 | 24 |
| Original WAVs (`00-original.wav`) | 24 | 24 |
| Valid candidate WAVs | 72 | 68 |

Four conservative candidates were rejected by PreviewCLI's source-relative
audibility-floor gate and therefore have plans/manifest records but no WAV:

- `mixassist:Group6:cut_1.wav`
- `mixassist:Group6:cut_11.wav`
- `mixassist:Group6:cut_23.wav`
- `mixassist:Group7:cut_26.wav`

The missing candidates are render failures for this preparation slice; no WAV
was fabricated or relabeled. The complete per-source hash and rejection record
is [full-real-audio-candidate-bundles/index.json](../../research/evaluation/production-mastery-v1/perceptual-study-v1/generated/full-real-audio-candidate-bundles/index.json).
