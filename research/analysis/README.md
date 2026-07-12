# Research analysis workspace

This directory contains the reproducible analysis of the user-supplied research corpus.

The original PDFs and ZIP files are never modified. Each archive is extracted into its own directory under `research/extracted/`. `research/scripts/build-corpus-index.sh` hashes every PDF, chooses one canonical copy per SHA-256 digest, extracts searchable text with Poppler, and builds local TSV indexes. Generated text and indexes are intentionally ignored by Git; the human-authored synthesis is tracked.

Run:

```bash
research/scripts/build-corpus-index.sh
```

Current local corpus snapshot (2026-07-12):

- 87 PDF files, 61 byte-unique PDFs
- 24 HTML snapshots, 23 byte-unique snapshots
- 11 text/readme/manifest sources
- 15 curated audio-production papers and standards, all duplicated in one supplied ZIP
- 82 indexed TTA-Bench source records, including duplicate formats and copies

Review protocol:

1. Integrity-check and path-check every archive before extraction.
2. Deduplicate PDFs by content hash, never by filename.
3. Read the full text of standards and directly relevant DSP, analysis, intelligent-production, style-transfer, and evaluation papers.
4. Screen the abstract, method, evaluation, limitations, and conclusion of peripheral model papers.
5. Visually render pages containing critical equations, tables, and listening-test results to verify text extraction.
6. Separate standards, peer-reviewed evidence, preprints, and web documentation in conclusions.
7. Translate findings into an explicit engineering decision or mark them as deferred.

