# Codex integration handoff

## Deliverable identity

This folder is a finished **candidate corpus package** containing:

- 147 vocal-production canonical Q&A records;
- 67 quantization/timing canonical Q&A records;
- 3290 user-language examples;
- 428 multi-turn scenarios;
- source, contradiction, schema, QA, and candidate-import artifacts.

The owner already sent the larger Tutor-development prompt. Do not replace it with another plan. Integrate this package into the current result of that work.

## Required first actions

1. Inspect the latest TrackSmith repository and identify its current knowledge, retrieval, Tutor-provider, procedure, and evaluation paths.
2. Run:
   `python3 tools/validate_package.py`
3. Read:
   - `README.md`
   - `research/SOURCE_POLICY.md`
   - `integration/TRACKSMITH_IMPORT_PLAN.md`
4. Preserve every row’s review status. Nothing in this package begins as trusted exact instruction authority.
5. Reuse the current TrackSmith source registry and review pipeline rather than creating a parallel truth system.

## Recommended mapping

### Retrieval/evaluation immediately usable

- `corpus/user_utterances.jsonl`
  - use as query/paraphrase cases;
  - map to `canonical_id`;
  - do not count paraphrases as independent evidence.

- `corpus/multiturn_scenarios.jsonl`
  - use for Tutor response-quality and continuity evaluation;
  - especially test “better but tradeoff,” “no change,” “worse,” “can’t find,” and “why.”

- `research/contradictions.jsonl`
  - retrieve when both positions are relevant;
  - never silently collapse disagreement.

### Candidate knowledge requiring review

- `integration/tracksmith_claim_candidates.jsonl`
- `integration/tracksmith_strategy_candidates.jsonl`
- `integration/logic_procedure_candidates.jsonl`

Stage these through the existing review pipeline.

## Non-negotiable behavior

- Community advice remains candidate evidence.
- The model may reason broadly but must not claim it heard or saw evidence it did not receive.
- Numeric settings remain starting guidance, not presets.
- One reversible experiment should be preferred over a list of ten guesses.
- Exact Logic instructions require version-scoped verification.
- The Tutor must remember previous experiments and respond coherently to follow-up tradeoffs.
- Create For Me remains outside this corpus’s scope.

## Suggested implementation order

1. Add package manifest/source registry adapters.
2. Import utterances into retrieval/evaluation.
3. Import multi-turn scenarios into the Tutor QA harness.
4. Build a review queue for strategy candidates.
5. Verify the highest-value Logic procedures against the installed Logic version.
6. Promote only reviewed records.
7. Run real Tutor sessions and record gaps rather than generating more synthetic volume by default.

## Acceptance checks

- Existing TrackSmith tests remain green.
- Corpus validator passes.
- No duplicate source IDs or canonical IDs.
- No candidate row is marked reviewed without a named review event.
- Retrieval returns one coherent canonical card, not a pile of paraphrases.
- The muddy-vocal path asks whether the issue exists solo or only in the mix when context is absent.
- “That is clearer, but now it sounds thin” modifies the prior experiment instead of restarting.
- Quantization guidance first decides whether the grid or performance should lead.
