# TrackSmith import plan

## Data lanes

- `canonical_qa.jsonl`: structured candidate reasoning patterns.
- `user_utterances.jsonl`: real-world retrieval language and misspellings.
- `multiturn_scenarios.jsonl`: continuity and teaching evaluations.
- `retrieval_evaluation.jsonl`: expected retrieval targets.
- `source_registry.jsonl`: provenance and evidence-tier metadata.
- `contradictions.jsonl`: context-dependent disagreements.
- `myths_and_antipatterns.jsonl`: unsafe or misleading universal rules.
- candidate claims/strategies/procedures: manual review queue only.

## Retrieval

Use hybrid lexical + semantic retrieval with domain, category, source-type, evidence-class, Logic-version, and current-context filters. Include contradictions when material. Deduplicate near-equivalent records. Return compact synthesis rather than raw corpus text.

## Evidence

Recommended evidence label: `Community/Corpus candidate` until promoted through TrackSmith review. Official Apple behavior may be labeled documentary only after source/version validation.

## Migration

Give this package its own corpus version and migration. Preserve package-1 data. A single CommunityKnowledge database may host both packages as independent manifests.
