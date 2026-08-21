# TrackSmith Corpus Package 011 — Smart Tempo, BPM Detection & Tempo Mapping

Package 011 is a read-only TrackSmith Tutor corpus for **Smart Tempo, BPM detection, and tempo mapping in Logic Pro**.

It uses the exact prior-package `tracksmith-corpus-package/1.0` filenames, schemas, SQLite table names, tools, review states, and import workflow. The required machine-readable integration contract is `integration/integration_manifest.json`.

## Counts

- 450 canonical Q&A records across 45 subdomains
- 10,350 unique user utterances
- 1,350 multi-turn scenarios
- 2,250 retrieval/evaluation fixtures
- 50 preserved disagreements
- 60 myths and anti-patterns
- 79 source records
- 450 candidate claims, strategies, procedures, and provenance records

## Core coverage

- Keep, Adapt, and Automatic Project Tempo modes
- musical tempo references and why Auto chooses unexpectedly
- Free Tempo Recording
- applying region tempo to project or project tempo to region
- detecting BPM from existing recordings
- file-tempo metadata and wrong-speed imports
- Smart Tempo Off, On, Bars, and Beats
- Smart Tempo Editor preview, hints, beat markers, downbeats, signatures, x2 and /2
- local marker edits, range scaling, locked ranges, and reanalysis
- half/double-time ambiguity and compound meter
- rubato, drift, average tempo, gradual and abrupt changes
- Tempo track, Tempo List, Tempo Operations, Tempo Sets, and Beat Mapping
- loops and full songs recorded at other or variable tempos
- multitrack Smart Tempo downmixes and contributing tracks
- MIDI, Drummer, Apple Loops, and tempo-synced effects following the map

## Knowledge boundary

Every synthesized record remains `candidate_not_yet_human_reviewed`. Every Logic procedure remains `candidate_unverified_on_installed_logic` with `execution_authority: false` and is excluded from the live runtime projection.

The runtime projection contains no procedures, Logic navigation, scenarios, evaluations, SQLite data, test fixtures, or expected retrieval answers.

## Start

Read `integration/START_HERE_FOR_CODEX.md`, then run:

```bash
python3 tools/validate_package.py --full
python3 tools/inspect_package.py
python3 tools/query_corpus.py "Why did this imported recording suddenly change speed?"
```
