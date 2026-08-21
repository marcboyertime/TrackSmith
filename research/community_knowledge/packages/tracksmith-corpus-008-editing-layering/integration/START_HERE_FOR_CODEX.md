# Start here for Codex — Package 008

This is **Package 008: Editing + Layering**. Integrate it only after Packages 001–007 are stable.

1. Run `python3 tools/validate_package.py`.
2. Run `python3 tools/inspect_package.py`.
3. Test retrieval with the commands in `examples/example_queries.md`.
4. Run `python3 tools/import_to_tracksmith.py --target /path/to/TrackSmith --dry-run`.
5. Preserve package namespaces, review states, source classes, and the current read-only LLM-first Tutor authority boundary.

Do not compile this corpus into `GeneralTutorKnowledge.generated.swift`. Import it through the scalable package retrieval layer.

## Product behavior

The Tutor should distinguish source/performance problems from edit problems, and should distinguish a missing layer role from redundant overstacking. It should recommend one reversible experiment, preserve the original source, state what to listen for, provide a stop rule and undo, and adapt to nuanced feedback such as “cleaner, but unnatural” or “bigger, but smaller in the mix.”
