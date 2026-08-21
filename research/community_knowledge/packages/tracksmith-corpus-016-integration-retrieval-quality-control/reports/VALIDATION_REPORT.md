# Package 016 Validation Report

**Status:** PASS  
**Validation date:** 2026-08-12  
**Package:** `tracksmith-corpus-016-integration-retrieval-quality-control` v1.0.0

## Scope

Package 016 is infrastructure-only. Its own Q&A, utterance, scenario, evaluation,
claim, strategy, procedure, contradiction, myth and provenance files are empty by
design. It migrates and indexes Packages 001–015 without changing their archives.

## Audited prerequisite result

The complete validator and importer were exercised against the exact fifteen archive
hashes recorded in `package_manifest.json`.

- Packages selected: **15**
- Canonical Q&A records: **6,134**
- User utterances: **135,369**
- Multi-turn scenarios: **18,188**
- Retrieval evaluations after legacy exact-fixture generation: **30,304**
- Contradictions: **677**
- Myths and anti-patterns: **795**
- Claim candidates: **6,134**
- Strategy candidates: **6,134**
- Candidate Logic procedures: **6,134**
- Sources: **1,221**
- Provenance records after legacy migration: **6,134**

## Migration and status preservation

- Packages 001–004 passed explicit legacy migration.
- Packages 005–009 retained their native IDs and were enriched only where their
  older schema did not yet expose the separate native/original/verification/runtime
  fields.
- Packages 010–015 retained their native stable contract fields.
- Legacy ID mappings written: **20,733** across supported record types.
- No unresolved ID collision remained after migration.
- Original archive hashes, package IDs, original record IDs and source references
  were preserved.

## Retrieval validation

- Exact identity fixtures: **6,134**
- Exact fixture aliases unique: **6,134 / 6,134**
- Exact fixture target IDs unique: **6,134 / 6,134**
- Natural normalized-alias collisions found: **179**
- Collision handling: **diagnostic-only; require context**
- Runtime retrieval budget:
  - canonical results: at most 4
  - per package: at most 2
  - per domain: at most 2
  - material contradiction: at most 1
  - myths/anti-patterns: at most 2
- Representative bounded FTS retrieval cases passed.
- A machine-readable `retrieval_quality_report.json` is produced by the unified
  importer.

## Runtime projection

Generated runtime projection:

- canonical records: **6,134**
- natural runtime utterances: **132,121**

Recursive runtime-purity validation found no candidate procedures, Logic navigation,
menu paths, click sequences, evaluation answers, multi-turn test scenarios, exact
fixture aliases, SQLite paths/data or execution authority.

## Database and importer

- Package database integrity: **OK**
- Unified SQLite FTS5 database integrity: **OK**
- Unified canonical rows: **6,134**
- Unified exact-fixture rows: **6,134**
- Unified alias-collision rows: **179**
- Importer dry-run with a prebuilt validated bundle: **PASS**
- Actual additive import into a clean simulated Git checkout: **PASS**
- Registered package entries after actual import: **Packages 001–016**
- Actual import elapsed in the packaging environment: approximately **23 seconds**
- Peak importer memory in the packaging environment: approximately **1.1 GB**

Performance observations are environmental measurements, not universal requirements.

## Public audio evaluation sources

- Registered evaluation datasets: **17**
- Profiles: `smoke`, `standard`, `full`, `request_required`
- Smoke plan contains both waveform and expressive MIDI material.
- Smoke acquisition planning: **PASS**
- Request-gated sources do not block independent work.
- No third-party audio or MIDI asset is bundled in this ZIP.
- Actual download remains an explicit Codex execution step so source terms, free
  space, checksums and local cache location can be recorded on the target machine.

## Full command exercised

```bash
python3 tools/validate_package.py \
  --archive ../TrackSmith_Corpus_Package_016_Integration_Retrieval_Quality_Control_v1.0.0.zip \
  --prior-packages /path/to/Packages_001_015 \
  --target /path/to/TrackSmith \
  --full
```

The final archive must be revalidated after any file change. Validation fails closed
on archive/hash drift, missing prerequisites, count drift, status loss, unresolved
identity collisions, exact-fixture ambiguity, importer failure or runtime leakage.
