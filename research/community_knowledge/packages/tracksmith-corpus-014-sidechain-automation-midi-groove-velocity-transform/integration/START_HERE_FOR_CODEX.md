# Start Here for Codex — Package 014

1. Read `package_manifest.json` and `integration/integration_manifest.json`.
2. Run the full validator before importing.
3. Use only `exact_unique` fixtures as expected top-1 tests.
4. Preserve native, original-review, original-verification, Logic-verification, and runtime-eligibility states separately.
5. Integrate through the scalable retrieval layer; do not compile this corpus into `GeneralTutorKnowledge.generated.swift`.
6. Import only the purified runtime projection into live Tutor retrieval.
7. Keep candidate Logic procedures development/test-only until verified against the installed Logic version.

```bash
python3 tools/validate_package.py \
  --archive ../TrackSmith_Corpus_Package_014_Sidechain_Automation_MIDI_Groove_Velocity_Transform_v1.0.0.zip \
  --prior-packages /path/to/prior/package/archives \
  --target /path/to/TrackSmith \
  --full
```

Representative queries:

```bash
python3 tools/query_corpus.py "Make the bass get out of the way every time the kick hits"
python3 tools/query_corpus.py "I move the fader and it immediately jumps back"
python3 tools/query_corpus.py "Tighten this piano but don't make it robotic"
python3 tools/query_corpus.py "Change only the quiet notes"
```
