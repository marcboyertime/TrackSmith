# Research analysis workspace

This directory contains the reproducible analysis of the user-supplied research corpus.

The original PDFs and ZIP files are never modified. Each archive is extracted into its own directory under `research/extracted/`. `research/scripts/build-corpus-index.sh` hashes every PDF, chooses one canonical copy per SHA-256 digest, extracts searchable text with Poppler, and builds local TSV indexes. HTML rows also record extracted-text size and a `content_status` of `usable`, `empty`, or `unusable`; this prevents two empty captures with the same hash from being mistaken for a usable duplicate source. Supplied TXT evidence is recorded separately in `source-text-index.tsv` so it cannot disappear among generated extraction files and archive README metadata. Generated text and indexes are intentionally ignored by Git; the human-authored synthesis and [source/archive audit](SOURCE_AUDIT.md) are tracked.

Run:

```bash
research/scripts/build-corpus-index.sh
python3 research/scripts/audit-corpus.py
```

Current local corpus snapshot (2026-07-19):

- 131 non-quarantined searchable PDF paths, 104 byte-unique PDF payloads
- 7 quarantined PDF paths retained as forensic history, not additional evidence
- 81 non-quarantined searchable HTML paths, 79 unique hashes: 78 usable and one
  empty; two non-usable paths resolve to that one empty digest
- 3 quarantined HTML paths retained outside the searchable evidence set
- 2 zero-byte HTML captures (TTA-Bench items 074 and 075) represented by one explicitly `empty` digest
- 2 supplied TXT source payloads, both unique and usable; item 036 is a secondary synthesis, not independent evidence
- 15 curated audio-production papers and standards, all duplicated in one supplied ZIP
- 9 validated producer-judgment papers retained in the content-addressed local archive and reviewed in [TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md](TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md)
- 82 indexed TTA-Bench source records, including duplicate formats and copies
- 10 ZIP archives with 125 non-directory members; all 125 members pass CRC and hash-match their extracted counterpart
- 195 unified source-index records: 184 payload records and 11 metadata-only link
  or unavailable records; archive containers are not double-counted as sources

Recovery and provenance notes:

- Item 074 points to the same *Deep Learning and Intelligent Audio Mixing* work as item 023. Its missing payload is covered by the supplied WIMP 2017 PDF and the item-023 fallback extraction, so the core review is complete despite the empty capture.
- Item 075 has no recoverable payload in the supplied corpus. It concerns hybrid-transformer music source separation, which is outside the stable MVP and therefore does not block current engineering conclusions.
- The live counts include a newly discovered untracked `research/papers/TTA-Bench-sources-part-02-items-016-to-017/` copy. Its PDF and HTML payloads are byte duplicates of already indexed extracted sources; it is preserved as user research and intentionally not committed.

Review protocol:

1. Integrity-check and path-check every archive before extraction.
2. Deduplicate PDFs by content hash, never by filename.
3. Read the full text of standards and directly relevant DSP, analysis, intelligent-production, style-transfer, and evaluation papers.
4. Screen the abstract, method, evaluation, limitations, and conclusion of peripheral model papers.
5. Visually render pages containing critical equations, tables, and listening-test results to verify text extraction.
6. Separate standards, peer-reviewed evidence, preprints, and web documentation in conclusions.
7. Translate findings into an explicit engineering decision or mark them as deferred.
8. Count usable HTML payloads separately from paths and hashes; record empty and extraction-failed sources explicitly.

## Logic Pro 12.3 primary-manual coverage

The fail-closed Logic manual archive contributes four of the 74 byte-unique searchable
PDFs counted above. It remains a separately governed source set from the 70 pre-Logic
payloads. All 2,686 pages in its four immutable Apple payloads have now been read in
full; the generated outline index was used only for navigation and is explicitly labeled
`source_index_only_not_deep_review_evidence`.

- [Logic Pro 12.3 Tool and Effect Atlas](TRACKSMITH_LOGIC_PRO_12_3_TOOL_ATLAS.md) —
  all 390 Effects-guide pages, including every effect family, amp/cabinet, all 35
  Pedalboard stompboxes, MIDI processor, meter, utility, and legacy processor.
- [Logic Pro 12.3 Instrument Atlas](TRACKSMITH_LOGIC_PRO_12_3_INSTRUMENT_ATLAS.md) —
  all 752 Instruments-guide pages, including synthesis, sampling, drum instruments,
  modeled keyboards/organs, performance state, modulation, routing, and internal effects.
- [Logic Pro 12.3 Workflow and Tool Atlas](TRACKSMITH_LOGIC_PRO_12_3_WORKFLOW_ATLAS.md) —
  all 1,324 User-Guide pages, including recording/editing, mixing/routing, automation,
  bounce/export, Spatial Audio, MIDI, Environment, synchronization, settings, and glossary.
- [Logic Pro Control Surfaces Atlas](TRACKSMITH_LOGIC_PRO_CONTROL_SURFACES_ATLAS.md) —
  all 220 pages and every documented device/profile family, with mode-dependent identity,
  destructive-operation risks, source copy errors, and rendered-page verification.
- [TrackSmith Deep Source Synthesis](TRACKSMITH_DEEP_SOURCE_SYNTHESIS.md) — the
  cross-source claim, contradiction, uncertainty, consequence, and prohibited-overclaim
  record used by the product architecture.
- [Local production-course deep-review lane](TRACKSMITH_LOCAL_PRODUCTION_COURSE_REVIEW.md) —
  exact identities, rights boundaries, review protocol, and claim-admission rules for
  eight user-supplied long-form videos. Transcripts are navigation indexes and do not
  count as deep review.
- [Logic core-effect mastery priority](TRACKSMITH_LOGIC_CORE_EFFECT_PRIORITY.md) —
  source-grounded sequencing that puts gain, EQ, compression, cleanup, ambience,
  delay, saturation, limiting, stereo/phase, and pitch ahead of creative pedal color.
- [Core-effect decision atlas](TRACKSMITH_CORE_EFFECT_DECISION_ATLAS.md) —
  all 20 first-queue operational, source-aware deep cards spanning gain, EQ, compression,
  de-essing/gating, algorithmic/convolution reverb, stereo/tape delay,
  saturation, limiting/metering, stereo/phase, pitch, and explicit envelope
  shaping, with documented facts, research limits, hypotheses, contraindications,
  and listening/stopping rules separated.
- [`deep-review-production-language-2026-07-19.json`](../metadata/deep-review-production-language-2026-07-19.json) —
  machine-readable full-source evidence for six primary language/reference sources,
  including actual methods, equations/metrics, samples, limitations, TrackSmith
  consequences, and prohibited inferences. The generated 14-entry abstract-language
  catalog remains advisory-only.

The reviewed effects and instrument syntheses are compiled into separate immutable-
source-hashed advisory catalogs: 142 effects/pedals and 28 instrument identities.
See [`LOGIC_12_3_KNOWLEDGE_GROUNDING_2026-07-16.md`](../../docs/evidence/LOGIC_12_3_KNOWLEDGE_GROUNDING_2026-07-16.md)
for generation hashes, retrieval limits, authority boundaries, and regression evidence.

This is complete documentary coverage, not proof of undocumented algorithms, attached
hardware, exact transfer functions, artistic superiority, or TrackSmith authority over
Logic project state. Those claims remain in empirical host, measurement, and controlled-
listening lanes.

Review depth is now tracked per immutable payload in `SOURCE_INDEX.jsonl` and the
deterministic `BIBLIOGRAPHY.json` generation summary. The 195-record ledger contains
scope-specific labels—full source, full relevant source, core, supporting,
peripheral, targeted patent/thread review, official documentation, unavailable,
and unknown—that cannot truthfully be collapsed into one “fully read” number. The
four Logic manuals and the six production-language/reference sources reviewed on
2026-07-19 have explicit full-read records. Archive integrity and index coverage are
complete, but a claim that every one of the 104 unique PDFs has received a deep
full-text review would still be false. `SOURCE_AUDIT.md` remains intentionally scoped
to the original numbered snapshot; use the unified ledger for current totals and
remaining review-depth work.
