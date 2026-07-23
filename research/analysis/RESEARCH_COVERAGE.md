# TrackSmith research coverage

Status: living coverage ledger  
Baseline date: 2026-07-16  
Scope: local-corpus audit before the comprehensive research expansion

Current-note (2026-07-19): this table intentionally preserves the dated baseline.
The living unified ledger now contains 195 records, including 104 byte-unique PDF
payloads and 79 unique non-quarantined HTML hashes. Use `SOURCE_INDEX.jsonl` and
`BIBLIOGRAPHY.json` for current totals; do not rewrite the baseline as if those
sources were present on 2026-07-16.

## Purpose and evidence boundary

This file records what TrackSmith's local research corpus actually covers, what
has merely been indexed, and what has not yet been searched. It is not a claim
that the research mission is complete. In particular, archive integrity,
successful ingestion, source disposition, full-text review, category coverage,
and search saturation are separate states.

The 2026-07-16 baseline is a local audit only. No comprehensive web, citation,
patent, product, practitioner, repository, or user-feedback search has yet been
performed for the broader research mission, so **no major source category is
claimed saturated**.

## Dated local baseline

The established audit and ingestion tools remain authoritative:

```sh
research/scripts/build-corpus-index.sh
python3 research/scripts/audit-corpus.py
```

The baseline counts deliberately distinguish the established non-Logic paper
corpus from every currently visible PDF path:

| Measure | 2026-07-16 baseline | Meaning and boundary |
|---|---:|---|
| Non-Logic PDF paths represented by the research indexes | 97 | Supplied, extracted, standalone, and producer-expansion paths; duplicate paths are retained. |
| Byte-unique non-Logic PDFs | 70 | The review-depth denominator used by `CORPUS_REVIEW.md`; excludes the four Logic manual payloads. |
| Core/full-text non-Logic PDFs | 26 | Full engineering review within the stated product question. |
| Supporting non-Logic PDFs | 36 | Methods/results/limitations review, not exhaustive full-text review. |
| Peripheral non-Logic PDFs | 8 | Systematic relevance screening only. |
| Live PDF paths seen by `audit-corpus.py` | 103 | Includes the non-Logic paths plus Logic archive object/quarantine paths. |
| Live byte-unique PDFs | 74 | The 70 non-Logic payloads plus four unique Logic 12.3 manuals. |
| Logic manual pages fully read | 2,686 | Effects 390; Instruments 752; User Guide 1,324; Control Surfaces 220. |
| HTML paths / unique hashes / usable hashes | 25 / 23 / 22 | Two empty HTML slots share the empty-file hash. |
| Supplied TXT source payloads | 2 | One recovered fallback and one secondary synthesis that is not independent evidence. |
| Supplied ZIP archives / members verified | 10 / 125 | All 125 non-directory members pass CRC and hash-match their extracted counterparts. |
| TTA source slots | 82 | Includes duplicate publication copies and two empty HTML slots. |
| Immutable current source manifests | 13 | Nine producer/semantic papers plus four Logic manuals. This is not yet a global source index. |
| Production-language templates / expanded cases | 70 / 420 | Six source contexts per template; 44 templates are catalog-only and 26 enter the interpreted assertion lane. |

The 70-PDF review ledger and the four-manual archive must not be combined into a
claim that all 74 unique PDFs have equivalent review semantics. The four Logic
manuals have separate every-page atlases; the 70-paper corpus uses Core,
Supporting, and Peripheral dispositions.

## Existing source families

### Standards and normative material

- ITU-R BS.1770-5 programme loudness and true peak.
- ITU-R BS.1771-1 loudness-meter display requirements.
- ITU-R BS.2217-2 compliance report and selected publisher-hosted vectors.
- ITU-R BS.1534-3 MUSHRA.
- EBU R 128 v5 and EBU Tech 3341 v4, 3342 v4, and 3343 v4.

The standards synthesis is technically deep and already distinguishes normative
algorithms from broadcast profiles and artistic preference. Several official
payloads reviewed during prior work are not yet normalized as immutable objects
in the research archive; retained extracted text or a synthesis hash is not a
substitute for preserving the original publisher bytes.

### Logic Pro and Audio Unit material

- Immutable Logic Pro 12.3 Effects, Instruments, User, and Control Surfaces PDFs.
- Complete tool, instrument, workflow, and control-surface atlases.
- Apple's `AUAudioUnit`, Audio Unit v3, and App Groups documentation.
- Logic release notes, Selection-Based Processing, and the available ARA workflow
  documentation.

This is the strongest current documentary area. It establishes host contracts,
available controls, workflow/state boundaries, and safety analogues. It does not
establish undocumented algorithms, arbitrary Logic project authority, or
permission for an AU to control Logic's native effects or region model.

### Academic DSP, intelligent production, and analysis

- Compressor design, detector topology, parameter automation, and intelligent
  multitrack compression.
- Best-practice-informed intelligent production and early deep-mixing work.
- Differentiable mixing consoles, differentiable effect style transfer, ST-ITO,
  and instrument-aware automatic EQ.
- Essentia, YIN, production-quality perception, SRMR, automatic mixing with
  out-of-domain data, and limited automatic-mastering evidence.

Coverage is strongest for EQ, compression, loudness, descriptors, and explicit
effect-chain optimization. It is not broad enough to settle limiting, dynamic
EQ, transient shaping, de-essing, reverb, stereo imaging, saturation, restoration,
vocal/drum enhancement, or complete multitrack production reasoning.

### Semantic control, human-AI workflow, and future models

- Word embeddings for automatic EQ, preference-bearing intent, MusicSem,
  source-specific guitar timbre, reference/rough-mix communication, MixAssist,
  and two small professional/producer workflow studies.
- Foundation-model editing surveys and examples including AUDIT, SemanticAudio,
  Audio ControlNet, AUDEDIT, and token inpainting.
- Audio-language/model families including AIR-Bench, AudioDER, CLAP, SALMONN,
  Qwen Audio/Omni, Moshi, AudioLDM, MusicGen, and codec work.

This material supports typed intent, scoped references, preservation constraints,
provider abstraction, and model calibration. Much of it remains Supporting or
survey-level evidence, uses short clips or proxy metrics, and does not demonstrate
expert music-production judgment.

### Professional practice

- One professional mixing communication/reference study.
- The MixAssist session/dialogue study.
- iZotope's 2014 mixing guide and a 2025 vocal-EQ article.
- Practitioner source families identified for later review, including Sound On
  Sound, Tape Op, Pensado's Place, Mix With The Masters, Puremix, and AES material.

The current sources provide useful hypotheses but do not constitute the requested
case-level Producer Judgment Corpus.

### Repositories and implementation references

The local corpus contains pages or pointers for projects such as AuditEval,
ViSQOL, DAC, AudioLDM, SALMONN, Essentia, ST-ITO, `pymixconsole`, AudioKit, and
Spotify Pedalboard. It does not yet contain the required clean, commit-pinned,
license-preserving repository inspections. `research/code-and-supplements/` and
`research/datasets/` do not yet carry a reviewed implementation library.

## Coverage matrix

| Required area | Current depth | Strongest local evidence | Material deficiency | Saturation status |
|---|---|---|---|---|
| Standards and normative measurement | Strong foundation | ITU/EBU loudness, true peak, MUSHRA | Broader perceptual/listening-room standards; immutable normalization of every reviewed original | Not tested |
| Logic Pro and Audio Unit integration | Strong documentary coverage | Four complete Logic 12.3 manuals; Apple AU/App Group docs | Mutable web-source preservation; empirical host/version matrix remains bounded | Not tested |
| Real-time/offline DSP | Moderate-strong | Compression, EQ, differentiable DSP, explicit console, loudness | Limiting, dynamic EQ, reverb, imaging, saturation, restoration, source-specialized effects | Not searched comprehensively |
| Intelligent mixing/mastering | Moderate | Multitrack compression/mixing, automatic EQ, one mastering comparison, MixCheck trends | Modern automatic mastering, long-form/multitrack context, preference learning, production-grade evaluation | Not searched comprehensively |
| Semantic/conversational effect control | Moderate | Semantic EQ, preference roles, MixAssist, MusicSem, typed regression corpus | Broader source vocabularies, dialogue repair, personalization, production-grounded listening studies | Not searched comprehensively |
| Reference matching/effect optimization | Moderate-narrow | Differentiable effect transfer and ST-ITO | Multiple effects/sources, preservation, whole-mix reference scope, perceptual ranking | Not searched comprehensively |
| Perceptual/human evaluation | Moderate foundation | MUSHRA, production-quality study, metric limitations | TrackSmith-specific panels, preference ranking, expert/genre stratification, longitudinal evaluation | Not searched comprehensively |
| Human-AI creative collaboration | Early | MixAssist and two small workflow studies | Longitudinal professional use, agency/trust/revision evidence, comparative interaction designs | Not searched comprehensively |
| Future audio-capable models | Moderate orientation | Surveys, technical reports, broad benchmarks | Current official capability/privacy/latency evidence and production-specific black-box tests | Not searched comprehensively |
| Commercial competitors | Minimal | Logic Mastering Assistant from Apple's manual | Nearly all named current/historical products, versions, manuals, workflows, and independent tests | Not started |
| Patents and prior art | None | None | Family records, claims, status, citations, assignee/inventor networks | Not started |
| Producer/mix-engineer judgment | Early | Communication study, MixAssist, two vendor-practice sources | Substantial structured case corpus with rejected alternatives and stopping criteria | Not started systematically |
| Genre/aesthetic practice | Incidental | Source qualifications and a cross-genre reference case | Structured maps for every requested genre and desirable imperfections | Not started |
| Open-source implementations | Pointer-level | Project pages and license notes | Exact commits, clean checkouts, algorithm/test/license reviews | Not started systematically |
| User feedback and unmet needs | Incidental | Reddit-derived language dataset and aggregate MixCheck submissions | Product-specific complaints, praise, abandonment, privacy, control, and failure patterns | Not started |

## Required-output status

Names may be adapted to the repository, but each information function still
needs an explicit home.

| Required information product | Current status on 2026-07-16 |
|---|---|
| Unified source index | Missing. `corpus-index.tsv`, HTML/TXT indexes, and 13 immutable manifests are partial inputs, not a unified evidence-aware index. |
| Bibliography | Missing. |
| Research coverage | This file establishes the baseline; search history and saturation evidence remain to be appended. |
| Deep source synthesis | Existing `TRACKSMITH_DEEP_SOURCE_SYNTHESIS.md` is strong but covers a narrower milestone and must be extended. |
| Patent landscape and matrix | Missing. |
| Competitor landscape and matrix | Missing. |
| Producer Judgment Corpus | Missing as case-level JSONL; an expansion-paper synthesis and recommended schema exist. |
| Genre/aesthetic map | Missing. |
| User pain-point corpus | Missing. |
| Production-language ontology | Partial in product vocabulary code and the semantic evaluation corpus; no standalone evidence-indexed ontology artifact. |
| Implementation patterns | Scattered through synthesis/design documents; no consolidated research artifact. |
| Evaluation patterns | Partial in MUSHRA/loudness synthesis and test plans; no cross-task evaluation-pattern artifact. |
| Product opportunity map | Missing. |
| Differentiation strategy | Missing as a source-grounded comparative artifact. |
| Knowledge gaps | Established in `KNOWLEDGE_GAPS.md`; it must remain live as research closes or exposes gaps. |
| Roadmap implications | Scattered through synthesis and product documents; no complete source-to-requirement-to-test roadmap artifact. |

One internal ledger is stale: `TRACKSMITH_DEEP_SOURCE_SYNTHESIS.md` still reports
38 templates and 228 cases, while the current workspace evaluation corpus and
test plan report 70 templates and 420 expanded cases. The newer count governs
this baseline; the older synthesis statement requires later reconciliation.

## Known unavailable, empty, or noncanonical evidence

| Source or payload | Current state | Consequence |
|---|---|---|
| TTA slot 074, *Deep Learning and Intelligent Audio Mixing* HTML | Empty capture | The same work is recovered by the standalone WIMP 2017 PDF and fallback text; do not count the empty page as evidence. |
| TTA slot 075, *Hybrid Transformers for Music Source Separation* | Empty capture; no usable supplied payload | Record citation only until a lawful complete payload is acquired; no content-review claim is permitted. |
| EBU v5 audio test set | Direct retrieval returned HTTP 403 | Not acquired; only the explicitly documented synthetic Tech 3342 cases were run. |
| User-supplied BS.1770-5 PDF | Regenerated copy with corrupted equation glyphs | Preserve unchanged but treat as non-normative; the official publisher payload governed the deep review. |
| iZotope vocal-EQ embedded before/after audio | Not present in retained text payload | No independent audible-result claim. |
| Apple DocC pages | Mutable publisher endpoints; local representation hashes exist | Record exact retrieval endpoints and bytes; do not describe a representation hash as a stable document version. |
| Logic ARA workflow page | Available version belongs to the Logic 11.x documentation family | Current 12.3 release notes show continuing maintenance, but a versioned 12.3 workflow/API document remains a gap. |
| Pensado's Place source URL in the prior review | Not reliably resolvable in that pass | Retry through canonical current locations and retain timestamped notes/transcripts only when lawfully accessible. |

## Search program and saturation evidence

Every search log added later should record date, service/index, exact query,
filters, result count, new candidate count, accepted source count, duplicate or
weak-derivative count, and the next citation/author/inventor/assignee branch.

| Category | Required query families | Minimum saturation evidence |
|---|---|---|
| Academic research | Current and historical terminology; title/abstract search; backward and forward citations; related-paper graphs; author/lab search; AES, JAES, DAFx, ISMIR, WIMP/IMP, ICASSP, CHI/NIME and relevant theses | Major subtopics each searched in multiple scholarly indexes; citation frontiers followed at least two useful layers; repeated new query variants mostly yield duplicates, weaker derivatives, or already represented methods. |
| Patents | Technology terms; CPC/IPC classes; assignee subsidiaries and prior names; inventors; family members; backward/forward patent citations; non-patent literature | Seed and discovered assignees searched; families consolidated by priority; at least two citation-network layers inspected for high-relevance families; new queries mostly add family copies or low-relevance claims. |
| Competitors | Current and discontinued products; product/version/manual/release-note terms; workflow and feature terms; demos; privacy; pricing; reviews; comparisons; complaints | Each major product has current official documentation plus independent observable evidence and feedback; historical systems represented; discovery searches mostly return already cataloged products or marketing-only derivatives. |
| Producer practice | Engineer, artist, song, source, genre, breakdown, before/after, rejected choice, reference, revision, stopping; archive and conference searches | Major practitioner archives sampled across source types and genres; decision-chain records show repeated patterns and disagreements; additional searches mostly repeat known practices or lack usable provenance. |
| Genre/aesthetic practice | Genre plus mix/master/production/breakdown; subgenre and era; engineer/producer; desired imperfection; translation and reference language | Every requested genre has multiple independent, provenance-tagged cases and explicit disagreement/era notes; new searches mostly reinforce existing contextual patterns. |
| Open source | Paper-title code; algorithm/library terms; GitHub/GitLab topics; package registries; issues/benchmarks; license and dependency searches | Strong candidate families have exact-commit inspections, licenses, tests, and hazards recorded; new repositories are forks, wrappers, abandoned duplicates, or weaker implementations. |
| User feedback | Product plus trust, generic, bright, loud, dynamics, control, explanation, revision, reference, cloud/privacy, abandon/uninstall; forum/review/community searches | Repeated themes recur across products and independent communities; isolated reports remain separated; new searches mainly repeat coded themes without adding a materially new failure class. |
| Standards/host integration | Standards-body catalogs, revision histories, normative references, Apple version/release notes, AU lifecycle/state/render terms | Current applicable versions and superseded documents are identified; normative dependency chains are closed; remaining gaps are documented access or empirical questions rather than unsearched references. |
| Future models | Official technical reports/model cards/docs; audio-input limits; latency/cost/privacy; production/editing benchmarks; direct model-family and citation searches | Current major model families have primary documentation and production-relevant limitations; generic benchmark leadership no longer adds a distinct TrackSmith capability claim. |

Saturation is category-specific, not a global file count. A category remains open
when a high-value source family, conflicting evidence branch, major product,
important patent assignee, practitioner archive, or required genre has not been
searched deeply enough, even if many files have already been collected.

## Architecture constraints for all research conclusions

Research starts from the established TrackSmith architecture:

- AUv3 effect hosted in Logic Pro.
- Native macOS companion application.
- Signed App Group communication.
- Source-aware audio analysis.
- Provenance-tagged production vocabulary.
- Typed intent and production-hypothesis layers.
- Deterministic, editable DSP execution.
- Validated preview, revision, commit, bypass, and project-persistence workflows.
- Provider-neutral frontier-model reasoning as a future, bounded layer.

Consequently:

1. A recommendation must map onto an existing module and explain why extension,
   replacement, or a new experimental boundary is justified.
2. No AI model or network operation enters the real-time audio thread.
3. Model output never obtains direct, unvalidated DSP, file, MIDI, control-surface,
   or Logic project authority.
4. TrackSmith keeps original audio and accepted decisions recoverable; edits,
   previews, revisions, and bypass remain deterministic and reversible.
5. An ordinary AU does not gain Logic selection, region, project, native-effect,
   or undo authority merely because a workflow is documented in Logic.
6. References are negotiated and scoped evidence, not universal target vectors.
7. Low-level measurements support competing hypotheses; they do not prove
   adjectives, artistic quality, genre correctness, or listener preference.
8. Standards-derived targets remain profile-specific unless a delivery
   specification explicitly applies.
9. Learned waveform editing, separation, personalization, and optimization remain
   experimental until preservation, latency, provenance, and listening evidence
   satisfy their own acceptance criteria.
10. This research milestone may improve ingestion, indexing, and validation tools,
    but it does not authorize unrequested core product feature work.
