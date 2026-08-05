# G5 source-content audit (2026-08-02)

Status: `content_screen_complete_package_generation_paused_g5_pending`

This append-only note records a fresh automated content screen of all 24 unique
MixAssist source clips selected for the G5 preparation records. It corrects the
study design boundary before any instrument-specific full-real-audio package is
issued.

## Audit method and limits

- Each source asset was given a unique temporary filename for the audit. The
  repository audio and source manifests were not rewritten.
- The first 12 seconds of each source were analyzed with the locally cached
  Whisper `base` model.
- This was an automated content screen, not human listening, transcription
  certification, or ground truth. Whisper is an imperfect screen: it cannot
  identify instruments and cannot prove that a clip is musical. Observations
  below are therefore deliberately qualitative and do not claim exact
  transcription.

## Selected corpus covered

The selected corpus contains 24 assets, four in each of six corpus metadata
classes. Every selected entry has the role
`conversation_aligned_music_excerpt` in the source manifest. The class labels
remain metadata labels; they are not verified isolated-instrument identities.

| Metadata `sourceClass` | Count | Selected source assets |
| --- | ---: | --- |
| `vocals` | 4 | `mixassist:Group1:cut_47.wav`, `mixassist:Group1:cut_48.wav`, `mixassist:Group6:cut_16.wav`, `mixassist:Group6:cut_17.wav` |
| `drums` | 4 | `mixassist:Group1:cut_10.wav`, `mixassist:Group1:cut_11.wav`, `mixassist:Group6:cut_22.wav`, `mixassist:Group6:cut_23.wav` |
| `bass` | 4 | `mixassist:Group1:cut_80.wav`, `mixassist:Group1:cut_81.wav`, `mixassist:Group7:cut_26.wav`, `mixassist:Group7:cut_27.wav` |
| `guitars` | 4 | `mixassist:Group1:cut_26.wav`, `mixassist:Group1:cut_27.wav`, `mixassist:Group6:cut_10.wav`, `mixassist:Group6:cut_11.wav` |
| `keys` | 4 | `mixassist:Group1:cut_63.wav`, `mixassist:Group1:cut_64.wav`, `mixassist:Group3:cut_36.wav`, `mixassist:Group3:cut_37.wav` |
| `overall_mix` | 4 | `mixassist:Group1:cut_14.wav`, `mixassist:Group1:cut_15.wav`, `mixassist:Group6:cut_1.wav`, `mixassist:Group6:cut_14.wav` |

## Observed label/content conflicts

The screen found conflicts between metadata labels and what the first-12-second
Whisper pass appeared to contain. Vocal-labeled clips yielded voice-like
speech/song fragments. Non-vocal-labeled examples also yielded
speech/song/music-like detections, including:

- `drums`: `mixassist:Group1:cut_11.wav`
- `guitars`: `mixassist:Group1:cut_27.wav`
- `bass`: `mixassist:Group1:cut_80.wav`
- `overall_mix`: `mixassist:Group6:cut_1.wav`

These examples are screening observations, not relabeling decisions. A
speech-like Whisper result may reflect vocals, conversation, bleed, or model
error; it does not establish an instrument identity or verify musical content.

## G5 study-design correction

`sourceClass` is corpus metadata, not verified isolated-instrument truth. Do not
generate, or ask a participant to judge, an instrument-specific 24-trial
full-real-audio package from these labels.

The proposed full-real-audio blinded package generator was paused before it
created package files. The package is therefore **absent** for this audit: no
participant identities and no participant responses exist. Earlier G5
preparation records and source manifests are preserved as preparation evidence
only; this audit does not turn them into content verification or listening
evidence.

## Required next step

Before any replacement package is built, the operator must choose one of these
bounded paths:

1. Curate and verify the content categories from actual listening, recording
   the operator evidence and any corrected category mapping; or
2. Redesign the questions and trials around content-agnostic production
   judgments that do not depend on an instrument label.

Any future package must retain opaque participant labels and keep the
participant-to-source/condition mappings operator-only until judgment is
complete.

## Claim boundary and preserved records

G5 remains pending. This audit makes no perceptual claim, provides no preference
result, and does not promote G5. The prior G5 preparation records and the
authoritative source manifest remain unchanged:

- [G5 perceptual-study preparation](G5_PERCEPTUAL_STUDY_PREPARATION_2026-08-02.md)
- [G5 real-audio preparation](G5_REAL_AUDIO_PREPARATION_2026-08-02.md)
- [G5 24-real-audio candidate preparation](G5_24_REAL_AUDIO_CANDIDATE_PREPARATION_2026-08-02.md)
- [selected source manifest](../../research/evaluation/production-mastery-v1/perceptual-study-v1/source-manifest.json)

No ledger edit, participant package, fabricated content label, or participant
response was created by this audit.
