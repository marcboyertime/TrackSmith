# TrackSmith Level Balancing + EQ Q&A Corpus v1

A **separate second-stage package** for the TrackSmith LLM-first Tutor.

Integrate this package **only after** Codex has completed the earlier Vocal + Quantization package. It does not replace that package and should not be merged into it blindly.

## Contents

- 238 canonical Q&A records
  - 92 level-balancing records
  - 146 equalization records
- 4007 natural user phrasings
- 714 multi-turn Tutor scenarios
- 714 retrieval evaluation cases
- 81 registered sources
- 23 preserved disagreements
- 30 myths and anti-patterns
- SQLite FTS5 retrieval database
- candidate TrackSmith claims, strategies, and Logic procedures
- schemas, validator, query tool, source policy, coverage reports, and Codex handoff

## Truth boundary

This is a structured **candidate corpus**, not automatic trusted production truth.

Every knowledge record is marked `candidate_not_yet_human_reviewed`. Apple documentation may support current Logic behavior, but exact paths must still be verified against the installed Logic version before they receive exact-procedure authority. Practitioner sources are paraphrased and retained as context-dependent evidence, not consensus.

No raw Reddit dump, private audio, credentials, model weights, or long copied forum posts are included.

## Validate

```bash
python3 tools/validate_package.py
```

## Search

```bash
python3 tools/query_corpus.py 'vocal buried guitars'
python3 tools/query_corpus.py 'eq before compression' --domain equalization
python3 tools/query_corpus.py 'master clipping' --domain level_balancing
```

## Start here

Read `integration/START_HERE_FOR_CODEX.md`.
