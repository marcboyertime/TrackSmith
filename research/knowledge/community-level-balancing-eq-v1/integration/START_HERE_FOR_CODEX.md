# START HERE FOR CODEX

This ZIP is the **second standalone TrackSmith corpus package**. Integrate it after the earlier Vocal + Quantization package is already stable.

## First actions

1. Extract to a clean temporary directory.
2. Run `python3 tools/validate_package.py`.
3. Read `integration/PACKAGE_SEQUENCE.md` and `integration/TRACKSMITH_IMPORT_PLAN.md`.
4. Inspect the current TrackSmith repository before choosing paths or migrations.
5. Preserve the existing LLM-first Tutor, tool authority boundary, reviewed knowledge tool, and any corpus work installed from package 1.

## Recommended integration order

1. Import `research/source_registry.jsonl` through a versioned source registry.
2. Import `corpus/canonical_qa.jsonl` as candidate community/research knowledge—not trusted reviewed claims.
3. Import `corpus/user_utterances.jsonl` for retrieval and language coverage.
4. Add `corpus/multiturn_scenarios.jsonl` and `corpus/retrieval_evaluation.jsonl` to Tutor evaluations.
5. Review `research/contradictions.jsonl` and `research/myths_and_antipatterns.jsonl`.
6. Review and selectively promote candidate claims/strategies/procedures. Do **not** bulk-promote.
7. Keep exact Logic procedure authority tied to current official documentation and installed-version verification.

## Important architecture note

Do not compile this large corpus into `GeneralTutorKnowledge.generated.swift`.
Use the scalable retrieval layer established for package 1, with domain/version metadata and bounded tool output.

## Required Tutor behavior

- Distinguish level balance from gain staging, loudness, dynamics, masking, and mastering.
- Treat frequency ranges as search orientations, never presets.
- Ask whether a problem exists solo, in context, or only at certain moments.
- Prefer level/arrangement tests before unnecessary EQ.
- Gain-match EQ and plug-in comparisons.
- Preserve practitioner disagreement.
- Give one reversible experiment and a clear undo.
- Adapt to “better but thin,” “no change,” and “can’t find it” without restarting.

## Acceptance checks

- All package validation passes.
- No existing corpus IDs or migrations are overwritten.
- Corpus evidence remains candidate/community evidence.
- Retrieval can find both level and EQ questions.
- Final Tutor answers remain natural model-authored prose, not concatenated corpus fields.
- No Tutor mutation authority is introduced.
