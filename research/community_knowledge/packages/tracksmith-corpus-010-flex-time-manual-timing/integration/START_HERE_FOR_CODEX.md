# Start Here for Codex

1. Read `integration/integration_manifest.json`.
2. Run the single full validator command described in `README.md`.
3. Inspect the package with `python3 tools/inspect_package.py`.
4. Run representative searches with `python3 tools/query_corpus.py`.
5. Run `tools/import_to_tracksmith.py --target ... --dry-run` before changing TrackSmith.
6. Import only after prerequisites 001–009 are registered and collision/status/runtime checks pass.

Do not compile this corpus into `GeneralTutorKnowledge.generated.swift`. Use the scalable community/retrieval layer. Do not promote candidate procedures or navigation instructions into runtime Tutor data.
