# G3 blinded listening preparation — 2026-08-02

## Status and claim boundary

This package is prepared for `SINGLE_LISTENER_FORMATIVE_EVIDENCE` only. It is a
six-trial, G3-only listening package built from the six fixtures whose status is
`valid` in the parent DSP fixture manifest. It records no participant response,
preference, or perceptual outcome and makes **no perceptual-success claim**. G3
remains pending until a listener completes the blinded session and the resulting
responses are reviewed under the stated boundary.

The participant-facing manifest contains only opaque trial references, A/B labels,
opaque audio paths, monitoring instructions, and five plain-language questions.
Source/candidate roles, fixture identities, processors, and SHA-256 hashes are kept
only in the separate operator answer key. The A/B role assignment is recorded in the
operator answer key; seed `20260802` is retained as metadata only, and this package
makes no claim that the assignment can be replayed from the seed without a specified
algorithm and tool identity.

## Package artifacts

- `research/evaluation/production-mastery-v1/dsp-listening-fixtures/generated/g3-blinded/participant-manifest.json`
- `research/evaluation/production-mastery-v1/dsp-listening-fixtures/generated/g3-blinded/operator-answer-key.json`
- `research/evaluation/production-mastery-v1/dsp-listening-fixtures/generated/g3-blinded/participant-response-template.json`
- `research/evaluation/production-mastery-v1/dsp-listening-fixtures/generated/g3-blinded/audio/trial-001-A.wav` through `trial-006-B.wav`

The original source and candidate fixture files remain in the parent directory and
were copied byte-for-byte; no ledger, source code, or original fixture was modified.

## Verification evidence

```text
Copied-artifact SHA-256 verification: 12/12 copied files match the operator key
and each copied hash matches its original fixture.
JSON parse verification: participant-manifest.json, operator-answer-key.json,
and participant-response-template.json parse successfully.
Opaque participant-path scan: 0 processor/effect identity tokens in participant
paths or participant metadata.
git diff --check: exit 0 for this package and evidence note.
```

These are package-integrity checks only. They do not constitute human listening
evidence, installed-host evidence, Logic equivalence, or a G3 promotion.
