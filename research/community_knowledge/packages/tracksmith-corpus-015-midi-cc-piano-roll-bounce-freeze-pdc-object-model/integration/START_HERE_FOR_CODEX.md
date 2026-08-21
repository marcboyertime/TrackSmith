# Start Here for Codex — Package 015

1. Keep Packages 001–014 registered and stable.
2. Run the full validator before importing.
3. Inspect exact and diagnostic retrieval separately.
4. Import through the scalable community-knowledge/runtime projection layer; do not compile this corpus into `GeneralTutorKnowledge.generated.swift`.
5. Preserve every native/original/Logic verification status and `execution_authority: false`.

```bash
python3 tools/validate_package.py \
  --archive ../TrackSmith_Corpus_Package_015_MIDI_CC_Piano_Roll_Bounce_Freeze_PDC_Object_Model_v1.0.0.zip \
  --prior-packages /path/to/prior/package/archives \
  --target /path/to/TrackSmith \
  --full

python3 tools/import_to_tracksmith.py --target /path/to/TrackSmith --dry-run
python3 tools/import_to_tracksmith.py --target /path/to/TrackSmith
```

Only `exact_unique` fixtures are expected top-1 regressions. Every other retrieval case is diagnostic-only.
