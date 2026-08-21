# Start Here for Codex — Package 011

This is `tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping`. Integrate it only after Packages 001–010 are stable and registered.

1. Read `integration/integration_manifest.json`.
2. Run the single full validator.
3. Inspect exact and diagnostic retrieval classifications.
4. Run the importer in dry-run mode.
5. Integrate only through the scalable community/retrieval layer; do not compile this corpus into `GeneralTutorKnowledge.generated.swift`.
6. Preserve every native, original-review, original-verification, Logic-verification, and runtime-eligibility status separately.
7. Keep candidate procedures, Logic navigation, evaluations, scenarios, databases, and test fixtures outside the live runtime projection.

```bash
python3 tools/validate_package.py   --archive ../TrackSmith_Corpus_Package_011_Smart_Tempo_BPM_Detection_Tempo_Mapping_v1.0.0.zip   --prior-packages /path/to/prior/package/archives   --target /path/to/TrackSmith   --full

python3 tools/import_to_tracksmith.py --target /path/to/TrackSmith --dry-run
python3 tools/import_to_tracksmith.py --target /path/to/TrackSmith
```
