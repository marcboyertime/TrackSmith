# TrackSmith Import Plan

- Validate archive, dependencies, source links, exact retrieval, collisions, and runtime purity.
- Dry-run against the current TrackSmith Git checkout.
- Stage the complete development package under `research/community_knowledge/packages/`.
- Emit only the bounded runtime projection under `research/community_knowledge/runtime/`.
- Update the package registry additively.
- Do not overwrite prior IDs, migrations, source records, or runtime projections.
- Do not expose procedures, Logic paths, scenarios, evaluations, exact fixtures, or SQLite to live Tutor retrieval.
