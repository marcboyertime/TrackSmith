# TrackSmith Corpus Package 010 — Flex Time & Manual Timing Correction

Package 010 teaches TrackSmith to diagnose and guide **Flex Time and manual timing correction in recorded audio** while preserving source tone, natural feel, adjacent material, stereo/multimic coherence, and rollback.

It uses the exact `tracksmith-corpus-package/1.0` structure and filenames established by the preceding standardized packages, plus the required machine-readable `integration/integration_manifest.json`.

## Counts

- 450 canonical Q&A records
- 10,350 unique natural-language utterances
- 1,350 multi-turn Tutor scenarios
- 2,250 retrieval fixtures
- 81 source records
- 48 preserved disagreements
- 56 myths and anti-patterns

## Core coverage

Flex enablement and scope; transient markers; flex markers and boundaries; Automatic, Monophonic, Polyphonic, Slicing, Rhythmic, Speed, and Tempophone modes; one-note/chord repair; vocals, doubles, bass, guitar, piano, percussion, and phase-locked multitrack drums; Q-Reference, Q-Strength, Q-Range, and audio quantization; Smart Tempo Keep/Adapt/Automatic and Flex & Follow; artifacts; adjacent-material protection; alternate takes, region moves, slicing/crossfades, and re-recording.

## Required first command

```bash
python3 tools/validate_package.py --full
```

For archive/prerequisite/target validation:

```bash
python3 tools/validate_package.py \
  --archive ../TrackSmith_Corpus_Package_010_Flex_Time_Manual_Timing_v1.0.0.zip \
  --prior-packages /path/to/prior/packages \
  --target /path/to/TrackSmith \
  --full
```

Every record remains candidate knowledge. Every candidate Logic procedure is unverified on the installed Logic build and has no execution authority.
