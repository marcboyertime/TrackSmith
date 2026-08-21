# TrackSmith Corpus Package 016 — Integration, Retrieval & Quality Control

Package 016 adds **no new Tutor knowledge records**. It is the integration and quality-control layer for Packages 001–015.

It normalizes the four legacy archives, preserves every original status, validates the standardized packages, builds a single package registry and development index, generates a strictly filtered runtime projection, and prevents the growing corpus from making the Tutor slower, noisier, or less decisive.

## Audited input corpus

The package was built against the actual 15 archives supplied with TrackSmith:

- 6,134 canonical Q&A records
- 135,369 utterances
- 18,188 multi-turn scenarios
- 29,280 retrieval evaluations
- 677 contradiction records
- 795 myths/anti-patterns
- 6,134 claim candidates
- 6,134 strategy candidates
- 6,134 candidate procedures

## The key retrieval contract

A normal Tutor retrieval receives at most:

- 4 canonical records total
- 2 records from one package
- 2 records from one domain
- 1 contradiction when material
- 2 myths/anti-patterns when material
- bounded source references

Exact test aliases are stored in a test-only table and never emitted to the runtime projection. Ambiguous or cross-domain aliases are diagnostic-only.

## Start

Read `integration/START_HERE_FOR_CODEX.md`, then run:

```bash
python3 tools/validate_package.py \
  --archive ../TrackSmith_Corpus_Package_016_Integration_Retrieval_Quality_Control_v1.0.0.zip \
  --prior-packages /path/to/Packages_001_015 \
  --target /path/to/TrackSmith \
  --full
```

Dry-run the import:

```bash
python3 tools/import_to_tracksmith.py \
  --target /path/to/TrackSmith \
  --prior-packages /path/to/Packages_001_015 \
  --dry-run
```

Acquire public real-audio smoke fixtures without waiting for owner audio:

```bash
python3 tools/import_to_tracksmith.py \
  --target /path/to/TrackSmith \
  --prior-packages /path/to/Packages_001_015 \
  --prepare-audio-assets \
  --audio-profile smoke
```

The smoke profile includes real multitrack musical audio through BabySlakh, official EBU audio tests, and small aligned expressive MIDI datasets. Standard and full profiles are available but remain bounded by free-space and download-size checks.
