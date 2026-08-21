# TrackSmith Import Plan

- Validate archive, package structure, source links, status fields, exact retrieval fixtures, diagnostic collision labels, prior-package compatibility, target prerequisites, and runtime projection purity.
- Stage the complete package under `research/community_knowledge/packages/` for development and review.
- Generate a separate bounded runtime JSONL projection under `research/community_knowledge/runtime/`.
- Exclude procedures, Logic navigation, evaluations, scenarios, SQLite databases, and test fixtures from runtime.
- Register the package additively; never modify earlier package source files.
