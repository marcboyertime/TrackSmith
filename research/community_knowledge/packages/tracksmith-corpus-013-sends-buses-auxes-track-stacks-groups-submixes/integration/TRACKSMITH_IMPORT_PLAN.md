# TrackSmith Import Plan

- Validate archive, prior dependencies, source links, exact retrieval, collisions, and runtime purity.
- Dry-run the importer against the current TrackSmith Git checkout.
- Stage the complete development package under `research/community_knowledge/packages/`.
- Emit only the bounded runtime projection under `research/community_knowledge/runtime/`.
- Update the package registry additively.
- Do not overwrite earlier IDs, migrations, or source records.
- Do not add procedures, Logic paths, scenarios, evaluations, or SQLite data to the live Tutor projection.
