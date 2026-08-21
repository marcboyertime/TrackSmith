# TrackSmith Import Plan

## Outputs in the target checkout

```text
research/community_knowledge/
├── package_registry.json
├── packages/tracksmith-corpus-016-integration-retrieval-quality-control/
├── unified/
│   ├── unified_corpus.sqlite
│   ├── unified_manifest.json
│   ├── alias_collisions.jsonl
│   ├── legacy_id_mappings.jsonl
│   └── retrieval_quality_report.json
├── runtime/
│   ├── unified_canonical.runtime.jsonl
│   └── unified_utterances.runtime.jsonl
├── audio_assets/
│   ├── audio_asset_manifest.json
│   ├── pending_access_requests.json
│   └── <downloaded datasets>
└── import_report_tracksmith-corpus-016-integration-retrieval-quality-control.json
```

## Runtime boundary

The runtime canonical projection excludes Logic navigation, candidate procedures, evaluations, scenarios, exact-test aliases, database paths and execution authority. The runtime utterance projection excludes all exact test fixtures and diagnostic expected-answer metadata.

## Retrieval priority

1. Existing reviewed TrackSmith knowledge remains separate and highest priority for documented facts and exact verified procedures.
2. Unified corpus results are candidate/practitioner evidence.
3. Current capture, model listening, Logic observation and user confirmation remain separate evidence classes.
4. The frontier Tutor synthesizes; retrieved text does not author the final answer.

## Aggregate input counts expected from the audited archives

```json
{
  "canonical_qa": 6134,
  "claim_candidates": 6134,
  "contradictions": 677,
  "logic_procedure_candidates": 6134,
  "multiturn_scenarios": 18188,
  "myths_and_antipatterns": 795,
  "provenance": 5110,
  "retrieval_evaluations": 29280,
  "sources": 1221,
  "strategy_candidates": 6134,
  "user_utterances": 135369
}
```
