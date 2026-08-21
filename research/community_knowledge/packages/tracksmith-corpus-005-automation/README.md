# TrackSmith Corpus Package 005 — Automation

A standalone, read-only knowledge and evaluation package for the **TrackSmith LLM-first Tutor**.

This is the first package released under the stable `tracksmith-corpus-package` contract, version **1.0**. Future packages should preserve this exact folder layout, schema naming, database table names, review states, ID rules, and Codex workflow.

## What this package contains

- **240** canonical automation Q&A records
- **5,280** natural user utterances
- **720** multi-turn Tutor scenarios
- **1,200** retrieval and response evaluations
- **36** preserved disagreements
- **44** myths and anti-patterns
- **63** registered sources
- **240** candidate claims
- **240** candidate strategies
- **240** candidate Logic procedures
- A queryable SQLite FTS5 database
- Stable schemas, validation, inspection, query, database-build, and import tools

## Coverage

| Subdomain | Canonical records |
|---|---:|
| `automation_modes` | 24 |
| `buses_groups` | 16 |
| `editing` | 28 |
| `fundamentals` | 24 |
| `level_rides` | 28 |
| `midi_controllers` | 20 |
| `plugin_parameters` | 24 |
| `sends_effects` | 28 |
| `track_region` | 30 |
| `troubleshooting` | 18 |


Coverage includes automation fundamentals; Read/Touch/Latch/Write/Trim/Relative modes; track versus region automation; editing, snapping, points, curves, and Event List workflows; vocal and instrument rides; sends, returns, delay throws, and effect automation; plug-in parameters and Smart Controls; MIDI controllers; buses, groups, VCAs, and output automation; and common Logic troubleshooting.

## Knowledge boundary

Every canonical record and candidate remains:

```text
candidate_not_yet_human_reviewed
```

Every candidate Logic procedure remains:

```text
candidate_unverified_on_installed_logic
```

This package supplies retrieval language, candidate teaching material, disagreement records, and evaluation cases. It does **not** grant execution authority, modify Logic, or promote forum/professional-practice advice into universal truth.

## Quick start

```bash
python3 tools/validate_package.py
python3 tools/inspect_package.py
python3 tools/query_corpus.py "why does my fader snap back"
python3 tools/import_to_tracksmith.py --target /path/to/TrackSmith --dry-run
```

Codex should begin with:

```text
integration/START_HERE_FOR_CODEX.md
```

## Package identity

```text
package_id: tracksmith-corpus-005-automation
namespace: pkg005
contract: tracksmith-corpus-package/1.0
database: SQLite FTS5
sequence: Package 5, after Packages 1–4
```

## Source policy

No raw forum archive or long copied forum text is included. Records are original, source-informed TrackSmith synthesis with source IDs and URLs. Reddit was limited to bounded public discovery seeds because no approved bulk API route was available; the package does not claim exhaustive Reddit coverage.
