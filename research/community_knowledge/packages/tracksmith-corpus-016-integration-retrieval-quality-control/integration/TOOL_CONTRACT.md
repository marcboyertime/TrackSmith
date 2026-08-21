# Unified Corpus Tool Contract

Recommended model-facing tool:

`search_community_production_knowledge`

Input:

- query
- current source type/scope
- optional package/domain hints
- maximum canonical results (hard cap 4)
- whether a disagreement is relevant

Output:

- interpreted query
- up to four compact canonical patterns
- package/domain/evidence/review labels
- high-value clarification questions
- one or two common failure modes
- at most one material disagreement
- bounded myths/anti-patterns
- source-reference IDs
- corpus version and retrieval receipt ID

Never return:

- raw full posts
- exact test aliases
- expected evaluation answers
- candidate Logic procedures
- menu paths or click sequences
- SQLite paths or blobs
- execution authority
- arbitrary filesystem or web access

The tool is read-only. The frontier Tutor writes the final prose and remains responsible for one-experiment discipline.
