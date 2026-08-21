# Validation Report

Status: **PASS**

Package: `tracksmith-corpus-013-sends-buses-auxes-track-stacks-groups-submixes`
Namespace: `pkg013`
Sequence: `13`
Contract: `tracksmith-corpus-package/1.0`

## Validated counts

- Canonical Q&A: 480
- User utterances: 11,040
- Multi-turn scenarios: 1,440
- Retrieval evaluations: 2,400
- Exact unique expected-top-1 fixtures: 480
- Diagnostic-only fixtures: 1,920
- Candidate claims: 480
- Candidate strategies: 480
- Candidate Logic procedures: 480
- Provenance records: 480
- Sources: 88
- Contradictions: 52
- Myths and anti-patterns: 64
- Runtime projection records: 480

## Passed checks

- Exact 47-file structural parity with Package 012
- ZIP CRC integrity and external SHA-256 verification
- Complete internal SHA-256 manifest coverage
- Required folders, files, schemas, and integration manifest
- Unique namespaced IDs across all record families
- Source and provenance-link resolution
- Native, original-review, original-verification, Logic-verification, and runtime-eligibility status preservation
- 11,040 unique normalized utterances with no opaque duplicate suffixes
- 480 exact fixtures uniquely mapping to one canonical ID and retrieving it at top-1
- 1,920 non-exact fixtures labeled diagnostic-only
- Within-package and cross-package collision validation
- Additive compatibility and prerequisite resolution against Packages 001–012
- SQLite integrity and table-count parity
- Importer dry run and staging in a clean simulated TrackSmith Git checkout
- 480-record runtime projection generation
- Recursive runtime-projection purity scan excluding procedures, Logic navigation, evaluations, scenarios, tests, expected answers, execution authority, and SQLite content
- Zero unresolved cross-package ID collisions

## Evidence boundary

All synthesized knowledge remains `candidate_not_yet_human_reviewed`.
All Logic procedure candidates remain `candidate_unverified_on_installed_logic` and `execution_authority: false`.
The runtime projection contains retrieval-oriented concepts and diagnostic patterns only; it does not contain executable procedures or Logic navigation.
