# TrackSmith Corpus Package 012 — Recording Latency, Monitoring & Signal Flow, Take Folders & Comping, Cycle & Punch Recording

Package 012 teaches TrackSmith the Logic Pro recording workflows that determine whether a performer hears the right cue, whether the intended signal reaches the track, how repeated takes become a final performance, and how a small passage can be rerecorded without destroying adjacent material.

## Domains

- Recording latency and monitoring delay
- Input monitoring, record enable, and recording signal flow
- Take folders, Quick Swipe Comping, and multiple performances
- Cycle recording, Auto Punch, manual punch, count-in, pre-roll, and replacement workflows

The package uses `tracksmith-corpus-package/1.0`, preserves the exact Package 011 filenames and schemas, and adds no runtime execution authority. Candidate Logic procedures remain development/test-only and unverified on the installed Logic version.

## Counts

- 480 canonical Q&A records
- 11040 utterances
- 1440 multi-turn scenarios
- 2400 retrieval evaluations
- 52 disagreements
- 64 myths and anti-patterns
- 84 registered sources

## Start

Read `integration/START_HERE_FOR_CODEX.md`, then run:

```bash
python3 tools/validate_package.py \
  --archive ../TrackSmith_Corpus_Package_012_Recording_Latency_Monitoring_Comping_Punch_v1.0.0.zip \
  --prior-packages /path/to/prior/package/archives \
  --target /path/to/TrackSmith \
  --full
```

The live runtime projection excludes candidate procedures, Logic navigation, evaluations, scenarios, SQLite files, expected retrieval answers, and execution authority.
