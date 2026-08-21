# Start Here for Codex

This is **TrackSmith Corpus Package 005: Automation**.

It uses stable package contract `tracksmith-corpus-package/1.0`. Treat the archive as a read-only, candidate-knowledge package that extends the scalable community/retrieval layer. Do not compile the complete corpus into `GeneralTutorKnowledge.generated.swift`.

## Required order

This package is intended after Packages 1–4. Read `PACKAGE_SEQUENCE.md` before importing.

## 1. Validate the untouched package

From the extracted package root:

```bash
python3 tools/validate_package.py
python3 tools/inspect_package.py
python3 tools/query_corpus.py "why does my fader snap back"
python3 tools/query_corpus.py "delay throw send automation"
```

Do not edit data before the validator passes.

## 2. Inspect TrackSmith before integrating

Identify the current implementation of:

- the LLM-first Tutor tool registry;
- the scalable retrieval/database layer established by earlier corpus packages;
- package registry and migrations;
- evidence classes and receipts;
- source/evidence UI;
- current Logic procedure review workflow.

Reuse the existing system. Do not create another parallel retrieval architecture.

## 3. Dry-run the package staging tool

```bash
python3 tools/import_to_tracksmith.py   --target /path/to/TrackSmith   --dry-run
```

If Packages 1–4 were integrated under legacy IDs rather than the standardized dependency IDs, inspect `PACKAGE_SEQUENCE.md` and map them deliberately. Do not bypass a dependency warning without documenting the mapping.

## 4. Integrate through the unified retrieval layer

The target behavior is a bounded, read-only Tutor retrieval capability for automation questions. Preserve the distinction among:

- reviewed official/documentary knowledge;
- candidate professional-practice synthesis;
- specialist/community patterns;
- current Logic observation;
- local measurements;
- model listening;
- user-confirmed outcomes;
- Tutor inference.

The model should receive compact synthesized records, not thousands of raw utterances or whole forum pages.

## 5. Keep exact Logic instructions version-gated

Every procedure in `knowledge_candidates/logic_procedures.jsonl` is a **candidate**. Before promotion:

1. resolve all source IDs;
2. compare against current Apple documentation;
3. verify exact labels in the installed Logic version;
4. confirm stop, undo, and user-performed boundaries;
5. retain no Accessibility, MIDI, key-command, or host mutation authority;
6. record review evidence.

## 6. Add retrieval and response regressions

Use:

- `corpus/retrieval_evaluations.jsonl`
- `corpus/multiturn_scenarios.jsonl`
- `tests/retrieval_cases.jsonl`
- `tests/integrity_cases.jsonl`

Important behaviors include:

- diagnosing fader snap-back as possible Read-mode playback rather than a bug;
- distinguishing track from region automation;
- selecting Touch versus Latch based on whether the new value should return or persist;
- separating automation from compression, arrangement, or static-balance problems;
- preserving delay/reverb tails when choosing send versus return automation;
- remembering nuanced outcomes such as “better, but too obvious”;
- providing one reversible experiment at a time.

## 7. Preserve package immutability

Do not rewrite package source files during import. Store promotions, rejections, installed-version verification, and user-specific outcomes in TrackSmith-owned review/migration state.

## Completion evidence

Report:

- starting TrackSmith HEAD;
- package SHA-256 and validator result;
- package dependency mapping;
- database/import migration;
- tool changes;
- retrieval results;
- candidate review states preserved;
- Logic procedures promoted, rejected, or left pending;
- tests and direct Tutor transcripts;
- limitations.
