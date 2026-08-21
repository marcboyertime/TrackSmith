# Start Here for Codex — Package 013

1. Read `package_manifest.json` and `integration/integration_manifest.json`.
2. Run the single full validator before inspecting or importing data.
3. Use only `exact_unique` fixtures as expected top-1 tests.
4. Preserve all native, original-review, original-verification, Logic-verification, and runtime-eligibility states separately.
5. Integrate through the scalable community/retrieval layer; do not compile this corpus into `GeneralTutorKnowledge.generated.swift`.
6. Import only the purified runtime projection into live Tutor retrieval.
7. Keep candidate Logic procedures development/test-only until verified against the installed Logic Pro version.

```bash
python3 tools/validate_package.py \
  --archive ../TrackSmith_Corpus_Package_013_Sends_Buses_Auxes_Track_Stacks_Groups_Submixes_v1.0.0.zip \
  --prior-packages /path/to/prior/package/archives \
  --target /path/to/TrackSmith \
  --full
```

Representative queries:

```bash
python3 tools/query_corpus.py "Put the same reverb on all my vocals"
python3 tools/query_corpus.py "Folder Stack versus Summing Stack"
python3 tools/query_corpus.py "VCA versus aux subgroup"
python3 tools/query_corpus.py "Why can I hear reverb when the track is quiet"
```
