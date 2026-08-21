# TrackSmith Corpus Package 008 — Editing + Layering

Package 008 extends the stable `tracksmith-corpus-package/1.0` contract used by Packages 005–007. It contains original, source-traceable candidate knowledge for two closely related production domains:

- **Editing** — noise and artifact cleanup, comping, timing, crossfades, breaths, guitar/piano cleanup, vocal alignment, clicks/pops, Flex Time, multitrack editing, and final consolidation.
- **Layering** — building one perceived instrument from complementary transient, body, sub, texture, width, and atmosphere roles without overstacking.

## Counts

- 420 canonical Q&A records (220 editing, 200 layering)
- 9,240 unique user utterances
- 1,260 multi-turn scenarios
- 2,100 retrieval/response evaluations
- 95 registered sources
- 46 preserved disagreements
- 54 myths and anti-patterns
- SQLite FTS5 retrieval database

## Critical boundary

All synthesized knowledge remains `candidate_not_yet_human_reviewed`. Exact Logic steps remain `candidate_unverified_on_installed_logic` and have `execution_authority: false`. The package is for read-only retrieval, evaluation, and candidate review—not autonomous editing or model fine-tuning.

## Start

```bash
python3 tools/validate_package.py
python3 tools/inspect_package.py
python3 tools/query_corpus.py "fix clicks and pops at edits"
python3 tools/query_corpus.py "what does each layer contribute"
```

Then read `integration/START_HERE_FOR_CODEX.md`.
