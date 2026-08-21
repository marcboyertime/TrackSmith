# Validation Report

Package: `tracksmith-corpus-005-automation`  
Contract: `tracksmith-corpus-package/1.0`  
Generated: 2026-08-11

The finished package is designed to pass `python3 tools/validate_package.py` after clean extraction. The validation covers:

- required standardized directory/file structure;
- package contract, number, and namespace;
- exact record counts;
- unique IDs;
- canonical cross-links;
- source-reference resolution;
- candidate review-state preservation;
- procedure execution-authority prohibition;
- SQLite integrity and per-table counts;
- representative FTS queries;
- per-file SHA-256 checksums.

## Expected statistics

```json
{
  "canonical_qa": 240,
  "claim_candidates": 240,
  "contradictions": 36,
  "logic_procedure_candidates": 240,
  "multiturn_scenarios": 720,
  "myths_and_antipatterns": 44,
  "provenance": 240,
  "retrieval_evaluations": 1200,
  "sources": 63,
  "strategy_candidates": 240,
  "user_utterances": 5280
}
```

## Expected final result

```text
PASS
package_id: tracksmith-corpus-005-automation
database_integrity: ok
reddit_status: MANUAL_PUBLIC_SEEDS_ONLY
```

This report documents the validation contract. It does not promote candidate knowledge or constitute direct installed-Logic or listening evidence.
