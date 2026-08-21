# TrackSmith Import Plan

## Goal

Add Package 5 to the existing scalable retrieval layer so the LLM-first Tutor can retrieve automation knowledge without changing its read-only authority model.

## Import phases

### Phase A — preflight

- Verify package checksum and run `tools/validate_package.py`.
- Confirm current TrackSmith Git state and create a dedicated branch.
- Inspect the existing package registry and unified retrieval store.
- Resolve all declared dependencies, including explicit legacy-ID mappings.
- Dry-run the included importer.
- Reject duplicate `pkg005.*` IDs.

### Phase B — immutable staging

Stage the extracted package under a TrackSmith-owned package directory such as:

```text
research/community_knowledge/packages/tracksmith-corpus-005-automation/
```

Keep package source files unchanged. TrackSmith-generated indexes, migrations, review decisions, and runtime caches should live outside the immutable package source.

### Phase C — database integration

Merge or attach the package into the existing unified retrieval database using the stable table mapping:

- `packages`
- `canonical_qa`
- `user_utterances`
- `multiturn_scenarios`
- `retrieval_evaluations`
- `contradictions`
- `myths_and_antipatterns`
- `claim_candidates`
- `strategy_candidates`
- `logic_procedure_candidates`
- `sources`
- `provenance`
- `canonical_qa_fts`

Do not rely only on FTS in production. Preserve the earlier package layer’s hybrid retrieval/reranking and source-diversity rules.

### Phase D — Tutor tool integration

Extend the existing community/corpus retrieval tool rather than adding a separate automation-only tool unless the current architecture clearly requires domain-specific tools.

Return compact results containing:

- canonical record ID;
- title and interpreted question;
- direct candidate answer;
- one first experiment;
- clarification questions;
- key distinction;
- tradeoffs;
- disagreement IDs;
- source IDs and evidence classes;
- Logic candidate procedure ID/status;
- package and corpus version.

Never return a huge raw utterance list to the model.

### Phase E — review boundary

Keep every imported record as `candidate_not_yet_human_reviewed` until an explicit TrackSmith review action promotes or rejects it.

Official Apple source records may be documentary candidates, but exact menu/control guidance still requires current installed-version verification.

### Phase F — evaluation

Run:

- exact and paraphrase retrieval;
- forbidden-neighbor retrieval;
- fader snap-back troubleshooting;
- track/region ownership;
- Touch/Latch/Write mode selection;
- send versus return automation;
- vocal ride continuity;
- plug-in parameter discovery;
- controller/MIDI automation;
- automation timing and latency;
- multi-turn “better but too obvious” adaptation;
- myth and disagreement behavior.

### Phase G — evidence

Record a deterministic import report with:

- TrackSmith starting and ending commits;
- package hash;
- package ID/version;
- dependency mapping;
- records imported;
- duplicates rejected;
- migrations run;
- review states;
- retrieval/evaluation results;
- procedures verified/promoted/rejected;
- known limitations.

## Prohibited shortcuts

- No automatic promotion from candidate to reviewed.
- No compilation of the large corpus into `GeneralTutorKnowledge.generated.swift`.
- No replacement of Packages 1–4.
- No raw community prose in the system prompt.
- No model-facing usernames.
- No autonomous Logic actions.
- No claim that popular advice is correct merely because it is common.
