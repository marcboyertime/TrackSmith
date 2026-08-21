# TrackSmith Corpus Package 007 — Phase and Polarity + Stereo Imaging + Panning

Package 007 adds a large, structured candidate corpus for **phase and polarity**, **stereo imaging**, and **panning** to TrackSmith's scalable community/practitioner retrieval layer.

It follows the exact `tracksmith-corpus-package/1.0` folder, file, schema, database, review-state, and import contract established by Packages 005 and 006.

## Contents

- 396 canonical Q&A records
  - 144 phase/polarity
  - 132 stereo imaging
  - 120 panning
- 8,712 unique natural-language user phrasings
- 1,188 multi-turn Tutor scenarios
- 1,980 retrieval and response-evaluation records
- 82 registered sources
- 42 preserved disagreements
- 50 myths and anti-patterns
- 396 candidate claims, strategies, Logic procedures, and provenance records
- SQLite FTS5 retrieval database

## Use boundary

Every synthesized knowledge item remains `candidate_not_yet_human_reviewed`.
Every Logic procedure remains `candidate_unverified_on_installed_logic` and has `execution_authority: false`.
The package provides candidate retrieval/evaluation material, not automatic Logic control, universal pan positions, correlation targets, phase-alignment values, or widening presets.

## Start

```bash
python3 tools/validate_package.py
python3 tools/inspect_package.py
python3 tools/query_corpus.py "Balance versus Stereo Pan"
```

Read `integration/START_HERE_FOR_CODEX.md` before importing.
