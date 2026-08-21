# Start Here for Codex — Package 3

This is the separate **Compression + Arrangement + Frequency Allocation** package.
It follows Package 1 and Package 2. It must not replace, overwrite, or renumber them.

## First actions

1. Extract outside the TrackSmith repository.
2. Run `python3 tools/validate_package.py`.
3. Inspect `reports/stats.json`, `reports/SOURCE_COVERAGE.md`, and `reports/REDDIT_ACCESS_STATUS.md`.
4. Read `integration/TRACKSMITH_IMPORT_PLAN.md`.
5. Inspect the current TrackSmith repo and the prior two corpus migrations before changing code.
6. Preserve current reviewed knowledge, LLM-first Tutor, tool authority, and Future/Legacy boundaries.

## Intended use

Use the package for:

- natural production-language retrieval;
- targeted clarification;
- competing diagnoses;
- one-experiment tutoring;
- multi-turn continuity;
- candidate community/professional knowledge;
- compression, arrangement, and masking evaluation;
- Logic procedure review candidates.

Do not compile the complete corpus into `GeneralTutorKnowledge.generated.swift`.
Use the scalable retrieval layer established for earlier packages.

## Non-negotiable rules

- Preserve all `candidate_not_yet_human_reviewed` states.
- Preserve Package 1 and 2 IDs, DB migrations, source IDs, and evaluations.
- Keep reviewed and community/candidate evidence distinct.
- Do not convert common settings into presets.
- Do not let meters, spectra, model confidence, or forum popularity prove artistic quality.
- Keep exact Logic steps version-scoped and review-gated.
- Do not add Tutor mutation authority.
- Keep model-authored final prose natural and coherent; do not dump retrieved records.
