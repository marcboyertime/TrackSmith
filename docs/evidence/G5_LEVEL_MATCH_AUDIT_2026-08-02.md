# G5 post-extraction level-match audit — 2026-08-02

## Status

**Preparation gate complete; G5 remains pending.** This append-only note records
the post-extraction level audit for the 24 selected real-audio source windows.
It is readiness evidence only: it contains no participant package, participant
response, preference result, or perceptual-success claim.

## Audit scope and method

- The audit used the excerpt windows from the selected source manifest together
  with the existing original renders and valid candidate renders from the
  24-real-audio candidate-preparation record.
- Four conservative-to-balanced operator-only fallbacks were required because
  the conservative candidate was rejected. No source bytes, prior audit record,
  or candidate-preparation record was rewritten.
- Loudness matching was checked after extraction for each selected source window;
  the reported difference is the absolute LU difference between the original
  and audited render. The -1 dBTP ceiling was checked for every audited output.

## Result

| Audit population | Count |
| --- | ---: |
| Selected unique source windows | 24 |
| Passed post-extraction audit | 21 |
| Excluded after audit | 3 |
| Conservative-to-balanced operator-only fallbacks | 4 |
| Audited outputs above -1 dBTP | 0 |

The 21 passing source windows are the only source windows currently eligible for
any future package. The following three were excluded:

| Source window | Ordinal | LU difference | Disposition |
| --- | ---: | ---: | --- |
| `mixassist:Group6:cut_16.wav` | 3 | 4.3 LU | Excluded; re-render and re-audit required |
| `mixassist:Group1:cut_64.wav` | 18 | 6.0 LU | Excluded; re-render and re-audit required |
| `mixassist:Group3:cut_37.wav` | 20 | 1.5 LU | Excluded; re-render and re-audit required |

## Package and claim boundary

The intended 24-source/28-presentation participant package was not generated.
This note must not be read as 24/28 participant coverage. A future package may
contain only the 21 passing sources unless the three exclusions are re-rendered
and pass a new post-extraction audit. That package must expose only opaque
participant labels; source identities and condition mappings remain operator-only.

No participant responses exist. G5 remains pending, and this preparation gate
does not establish perceptual success, listener preference, or workflow benefit.

## Preserved records

This note supplements, and does not replace, the prior append-only preparation
and source-content records:

- [G5 source-content audit](G5_SOURCE_CONTENT_AUDIT_2026-08-02.md)
- [G5 24-real-audio candidate preparation](G5_24_REAL_AUDIO_CANDIDATE_PREPARATION_2026-08-02.md)
- [G5 perceptual-study preparation](G5_PERCEPTUAL_STUDY_PREPARATION_2026-08-02.md)
- [selected source manifest](../../research/evaluation/production-mastery-v1/perceptual-study-v1/source-manifest.json)

No ledger change, participant package, fabricated response, or fabricated content
label was created by this audit.

## Window rerender recovery

The initial full-file post-extraction exclusions are preserved. As an append-only
recovery record, the three cropped study-window rerenders now pass PreviewCLI
validity and the -1 dBTP checks for all three strengths per source (nine valid
outputs total):

| Source window | Window | Valid outputs | Conservative / balanced / strong LUFS | Conservative / balanced / strong true peak |
| --- | --- | ---: | --- | --- |
| `mixassist:Group6:cut_16.wav` | 4.11–12.11 s | 3 | -12.728575 / -13.739970 / -14.889404 | -1.000299 / -1.000000 / -1.000000 dBTP |
| `mixassist:Group1:cut_64.wav` | 24.66–32.66 s | 3 | -42.132425 / -42.132426 / -42.132426 | -25.785496 / -26.891076 / -26.295594 dBTP |
| `mixassist:Group3:cut_37.wav` | 8.40–16.40 s | 3 | -34.627653 / -34.629654 / -34.633960 | -17.099283 / -18.693231 / -19.676680 dBTP |

The copied inputs, valid renders, plans, manifests, and hashes are recorded in
[the excluded-window rerender inventory](../../research/evaluation/production-mastery-v1/perceptual-study-v1/generated/excluded-window-rerenders-2026-08-02/inventory.json).
This supports a future 24-source package only after opaque packaging and a fresh
final audit. It does not establish participant coverage, listening evidence, a
perceptual result, or G5 promotion.
