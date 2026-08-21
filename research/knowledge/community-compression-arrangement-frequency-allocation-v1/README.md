# TrackSmith Compression + Arrangement + Frequency Allocation Q&A Corpus v1

This is **Package 3**, a separate Codex-ready knowledge and evaluation package for
TrackSmith Tutor. Integrate it only after:

1. `TrackSmith_Vocal_Quantization_QA_Corpus_v1`
2. `TrackSmith_Level_Balancing_EQ_QA_Corpus_v1`

It contains original, source-informed, review-candidate teaching records for three
connected production domains:

- compression and dynamic-envelope control;
- arrangement, form, role, density, and contrast;
- frequency allocation, masking, register, and time-frequency interaction.

## Counts

- 350 canonical Q&A records
  - 130 compression
  - 110 arrangement
  - 110 frequency allocation
- 7700 natural-language retrieval utterances
- 1050 multi-turn Tutor scenarios
- 1750 retrieval/response evaluation cases
- 91 registered sources
- 36 preserved disagreements
- 48 myths and anti-patterns
- SQLite FTS5 retrieval database
- 350 claim candidates, 350 strategy candidates, and 350 Logic procedure candidates

## Critical boundary

Every production record remains:

`candidate_not_yet_human_reviewed`

This package is not a trusted preset catalog. Numeric settings are starting points
for reversible listening tests, not universal answers. Exact Logic procedures remain
version-scoped and must be directly verified before trusted-instruction promotion.

## Start

```bash
python3 tools/validate_package.py
python3 tools/query_corpus.py "vocal compression sibilance" --domain compression
python3 tools/query_corpus.py "chorus feels smaller" --domain arrangement
python3 tools/query_corpus.py "kick bass masking" --domain frequency_allocation
```

Then read `integration/START_HERE_FOR_CODEX.md`.
