# TrackSmith Vocal Production + Quantization Q&A Corpus v1

A Codex-ready candidate knowledge package for the **TrackSmith Tutor**.

This is the actual corpus package—not another implementation prompt. It is designed to be unzipped and placed beside the TrackSmith repository so a Codex agent can review and integrate it deliberately.

## Scale

- **214 canonical Q&A records**
  - **147 vocal-production records**
  - **67 quantization/timing records**
- **3290 natural user utterances**
- **428 multi-turn Tutor scenarios**
- **17 explicit disagreement records**
- **34 source-registry entries**
- **214 TrackSmith claim candidates**
- **214 TrackSmith strategy candidates**
- **214 Logic procedure candidates**

The vocal corpus is intentionally much larger. Quantization/timing is the second completed domain.

## What this package is

It captures:

- how musicians actually describe vocal and timing problems;
- useful clarification questions;
- competing causes;
- one controlled first experiment;
- Logic Pro steps;
- starting guidance;
- what to listen for;
- stop and undo rules;
- common mistakes;
- tradeoffs;
- transferable teaching principles;
- community disagreements;
- multi-turn outcomes such as “better, but now thin,” “no change,” “worse,” “can’t find it,” and “why?”

## What this package is not

It is **not**:

- a raw scrape of Reddit or forum bodies;
- a set of universal vocal presets;
- a replacement for TrackSmith’s existing reviewed knowledge;
- an authorization for provider prose to control Logic;
- proof that a popular answer is correct;
- a completed review of every exact Logic step on the installed Logic version.

All forum-derived material is paraphrased synthesis. Every canonical record is marked:

`candidate_not_yet_human_reviewed`

That state should be preserved until TrackSmith’s review pipeline promotes it.

## Directory map

```text
corpus/
  canonical_qa.jsonl
  vocal_production_canonical.jsonl
  quantization_timing_canonical.jsonl
  user_utterances.jsonl
  vocal_user_utterances.jsonl
  quantization_user_utterances.jsonl
  multiturn_scenarios.jsonl

research/
  source_registry.jsonl
  taxonomy.json
  contradictions.jsonl
  SOURCE_POLICY.md

integration/
  CODEX_HANDOFF.md
  TRACKSMITH_IMPORT_PLAN.md
  tracksmith_claim_candidates.jsonl
  tracksmith_strategy_candidates.jsonl
  logic_procedure_candidates.jsonl
  REVIEW_CHECKLIST.md

schemas/
  canonical_qa.schema.json
  utterance.schema.json
  multiturn_scenario.schema.json
  source_registry.schema.json

reports/
  stats.json
  QA_REPORT.md
  SOURCE_COVERAGE.md

tools/
  validate_package.py

examples/
  sample_vocal_record.json
  sample_quantization_record.json
  sample_multiturn_scenario.json
```

## Recommended use inside TrackSmith

Use the files for four separate purposes:

1. **Retrieval language**
   - Index `user_utterances.jsonl`.
   - Map each utterance to its `canonical_id`.
   - Preserve the canonical card rather than treating each paraphrase as new truth.

2. **Candidate strategy knowledge**
   - Stage `tracksmith_strategy_candidates.jsonl` through TrackSmith’s existing source-review process.
   - Do not automatically mark these reviewed.

3. **Logic procedure candidates**
   - Check each procedure against the installed Logic version and Apple documentation.
   - Promote only verified steps into exact-instruction authority.

4. **Tutor evaluation**
   - Use `multiturn_scenarios.jsonl` to test continuity, tradeoff reasoning, “no change,” rollback, Show Me fallback, and teaching quality.

## Evidence policy

- **Tier A**: official Apple documentation. Supports product behavior and version-scoped navigation.
- **Tier B**: retrieved specialist forum/expert practice. Supports candidate strategies and troubleshooting branches.
- **Tier C**: community anecdote/discussion. Supports real phrasing, hypothesis generation, disagreements, and adversarial evaluation.

Community popularity never upgrades a claim to Tier A.

## Reddit access note

Direct Reddit access/search was inconsistent during collection. One large high-signal vocal-production thread was retrievable through an indexed mirror. Reddit-informed patterns are labeled Tier C and paraphrased. The package does not pretend Reddit coverage was exhaustive.

## Validate

```bash
python3 tools/validate_package.py
```

The validator checks:

- unique IDs;
- required fields;
- source-reference integrity;
- canonical/utterance/scenario links;
- minimum counts;
- review-state preservation;
- absence of suspiciously long copied text;
- package hashes when generated.

## First Codex instruction

Point Codex to:

`integration/CODEX_HANDOFF.md`

That file is an integration handoff, not a replacement for the Tutor-development prompt already sent.
