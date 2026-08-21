# TrackSmith Corpus Package 006 — Saturation / Harmonic Distortion + Transient Shaping

A standardized Package 006 corpus for the TrackSmith LLM-first Tutor.

## What is included

- **384 canonical Q&A records**
  - **204 saturation and harmonic-distortion records**
  - **180 transient-shaping records**
- **8,448 unique natural-language utterances**
- **1,152 multi-turn Tutor scenarios**
- **1,920 retrieval and response evaluations**
- **82 registered sources**
- **42 preserved disagreements**
- **50 myths and anti-patterns**
- **320 candidate claims, strategies, and Logic procedures**
- A package-local SQLite FTS5 database

## Package order

This package depends on Packages 001–005 and is intended to be integrated only after Automation Package 005 is stable.

## Start

```bash
python3 tools/validate_package.py
python3 tools/inspect_package.py
python3 tools/query_corpus.py "why does saturation make my vocal harsh"
python3 tools/query_corpus.py "transient shaper versus compressor"
```

Then read `integration/START_HERE_FOR_CODEX.md`.

## Knowledge boundary

Every synthesized record is `candidate_not_yet_human_reviewed`. Every Logic procedure is `candidate_unverified_on_installed_logic` and carries `execution_authority: false`. Starting values are orientations for reversible listening tests, never universal presets.
