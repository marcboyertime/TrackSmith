# TrackSmith Import Plan

## Storage

Import into the scalable local CommunityKnowledge/retrieval system used for previous packages. Keep the source JSONL files immutable and record the package manifest and SHA-256.

## Suggested tables or collections

- canonical Q&A
- utterances
- multi-turn scenarios
- retrieval evaluations
- sources
- contradictions
- myths
- candidate claims
- candidate strategies
- candidate procedures

## Retrieval

Use hybrid lexical + semantic retrieval with metadata filters for:

- domain: reverb or delay
- category and source type
- Logic version
- source/bus role
- vocal/instrument/full-mix context
- routing, timing, stereo, phase, depth, masking, or creative intent
- evidence tier
- contradiction inclusion

Rerank, deduplicate, and preserve source diversity. Return bounded distilled records, not raw pages.

## Evidence

Keep separate:

- Reviewed official knowledge
- Research
- Professional-practice pattern
- Community discovery
- Model listening
- Local measurements
- User report
- User confirmation
- Tutor inference

## Procedures

Candidate Logic procedures may be used for evaluation and review queues. Do not expose them as trusted exact instructions until current-version verification succeeds.
