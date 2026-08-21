# TrackSmith Import Plan

1. Verify all prerequisites in the target package registry.
2. Validate namespace `pkg012`, all counts, source links, statuses, hashes, exact fixtures, and runtime purity.
3. Run `tools/import_to_tracksmith.py --target /path/to/TrackSmith --dry-run`.
4. Stage the complete development package under `research/community_knowledge/packages/tracksmith-corpus-012-recording-latency-monitoring-comping-punch`.
5. Generate only the bounded runtime projection under `research/community_knowledge/runtime/`.
6. Keep procedures, Logic navigation, scenarios, evaluations, SQLite, and test fixtures out of runtime.
7. Rebuild the unified retrieval index without changing earlier package IDs.
8. Record a deterministic import report and package-registry entry.
