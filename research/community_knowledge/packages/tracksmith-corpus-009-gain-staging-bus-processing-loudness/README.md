# TrackSmith Corpus Package 009 — Gain Staging + Bus Processing + Clipping, Limiting & Loudness

A standardized `tracksmith-corpus-package/1.0` package for the LLM-first TrackSmith Tutor. It contains original, source-linked candidate synthesis rather than raw forum dumps or universal presets.

## Contents

- 430 canonical Q&A records
  - 140 gain staging
  - 130 bus processing
  - 160 clipping, limiting, and loudness
- 9,460 unique natural-language utterances
- 1,290 multi-turn scenarios
- 2,150 retrieval evaluations
- 95 registered sources
- 48 preserved disagreements
- 56 myths and anti-patterns
- one claim, strategy, Logic-procedure candidate, and provenance record per canonical case
- SQLite FTS5 retrieval database

## Boundaries

Every knowledge record is `candidate_not_yet_human_reviewed`. Every Logic procedure is `candidate_unverified_on_installed_logic` and has `execution_authority: false`. Numeric gain values, headroom, bus settings, ceilings, and LUFS values are context—not universal presets.

Start with `integration/START_HERE_FOR_CODEX.md`.
