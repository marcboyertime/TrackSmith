# G4 production-language evaluation v2 — 2026-08-02

## Verdict

**G4 passed; G5 remains pending.** This record closes the machine-audited
production-language v2 gate only. It makes no perceptual, human-listening, or
artistic-superiority claim.

## Fresh Release evidence

The command below was run from the current TrackSmith worktree at source revision
`53376bca425eadb7d99a60982aeb68d4199ee6a3`:

```text
swift run -c release TestRunner
  PASS production-mastery language v2 audits 1,000 plus meaningful cases without inflating human evidence
  SUMMARY passed=72 failed=0
```

The Release executable exited 0. The passing language-v2 check validates the
expanded corpus count, executable semantic assertions, provenance boundaries,
coverage minima, multi-turn structure, frozen-foundation hash, and the explicit
zero-human-evidence boundary.

## Corpus facts

The authoritative corpus artifacts are:

- `research/evaluation/TRACKSMITH_PRODUCTION_INTENT_CORPUS_V2.json`
- `research/evaluation/production-mastery-v1/language-corpus-summary.json`

Their accepted values are:

| Field | Value |
| --- | ---: |
| Expanded v2 cases | `1,074` |
| Frozen foundation cases | `420` |
| Generated structured augmentation | `654` |
| Multi-turn sequence cases | `120` |
| Independent human evidence | `0` |
| Frozen foundation SHA-256 | `622c4214cf8099dd7b75eb6ba7ae57fc071326ef36d136eb8199059acf574035` |

The v2 artifact declares the foundation path as
`research/evaluation/TRACKSMITH_PRODUCTION_INTENT_CORPUS_V1.json` and
`historicalArtifactModified: false`. The v2 corpus SHA-256 is
`db4b7c45a37229bf925aa90dfd7d0b9659a7ce8d31e1bb9df68dbeb470826af3`.

Coverage minima are met, including 354 preservation/prohibited-change cases,
114 genuinely ambiguous cases, 78 genre/era/role-dependent cases, 78
metaphorical/emotional/nontechnical cases, 126 non-DSP arrangement/recording/
performance cases, and 72 unsupported/unsafe cases. Generated augmentation is
structured regression coverage; it is not independent human evidence.

## Boundary and remaining work

This gate exercises semantic interpretation, clarification, safety rejection,
provenance, revision, and corpus-structure checks. It does not establish that a
response sounds better, that a plan is musically preferred, or that any listener
would endorse a result. Human participation, level-matched listening, and
perceptual/workflow analysis remain G5 work.
