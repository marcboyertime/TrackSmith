# Start Here for Codex — Package 012

This is a separate additive package. Integrate it only after Packages 001–011 are stable and registered.

## Required order

1. Run the full validator.
2. Inspect `integration/integration_manifest.json`.
3. Query representative user language.
4. Run the importer in `--dry-run` mode.
5. Review collision mappings and preserved statuses.
6. Import into the scalable community/retrieval layer.
7. Do not compile this corpus into `GeneralTutorKnowledge.generated.swift`.

## Full validation

```bash
python3 tools/validate_package.py \
  --archive ../TrackSmith_Corpus_Package_012_Recording_Latency_Monitoring_Comping_Punch_v1.0.0.zip \
  --prior-packages /path/to/prior/package/archives \
  --target /path/to/TrackSmith \
  --full
```

## Representative queries

```bash
python3 tools/query_corpus.py "My voice comes back half a second late"
python3 tools/query_corpus.py "Why do I hear my voice twice"
python3 tools/query_corpus.py "I sang this chorus six times"
python3 tools/query_corpus.py "I only need to rerecord this one word"
```

Only `exact_unique` fixtures are expected top-1 tests. Every semantic, ambiguous, multi-intent, low-margin, or cross-domain fixture is diagnostic-only.
