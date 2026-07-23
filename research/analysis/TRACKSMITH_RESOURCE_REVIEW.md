# TrackSmith resource review and engineering decisions

Date: 2026-07-14  
Corpus counts refreshed: 2026-07-19  
Scope: the supplied Resource Briefing Pack, the current repository, the local
research corpus, live official documentation, public paper/repository metadata,
and the proposed archive script. The suggested multi-week schedule is
intentionally ignored.

## Executive verdict

The briefing has the correct evidence hierarchy, but it describes an earlier
phase of the product. TrackSmith is no longer deciding whether an AUv3 plus a
companion app and deterministic DSP graph are viable. That architecture is
implemented, signed, registered, `auval`-validated, custom-host tested, and has
completed the current capture-to-preview-to-commit workflow in Logic Pro 11.2.2.
The repository also already contains the briefing's principal standards and DSP
papers and a substantially deeper synthesis than the proposed reading plan.

The useful result of this review is therefore a set of corrections and next
decisions:

1. Keep AUv3 plus companion plus App Group as the production integration.
2. Treat Selection-Based Processing as a user-workflow benchmark, not an API.
3. Do not make ARA the default deep-integration roadmap. On Apple silicon,
   third-party ARA still requires Logic to run under Rosetta, and Apple has now
   announced a sharply limited Rosetta future beginning with macOS 28.
4. Close the metering gap with EBU Mode short-term loudness, LRA, and formal
   test vectors before expanding mastering claims.
5. Build source-aware analysis and constrained parametric EQ fitting before any
   opaque or generative editing feature.
6. Mine production tutorials for language and workflow vocabulary only. They
   are not standards, validated parameter targets, or universal recipes.
7. Replace the proposed downloader with a provenance- and license-aware capture
   pipeline. The supplied script can save unusable JavaScript shells, unpinned
   repositories, and mislabeled artifacts while still reporting success.
8. Use TrackSmith in all new product-facing work, but do not bulk-rename bundle
   identifiers, the App Group, the AU component identity, persisted state keys,
   or historical validation records without an explicit migration design.

## What was actually reviewed

### Repository state

- The current local index contains 131 non-quarantined searchable PDF paths
  representing 104 byte-unique PDF payloads, plus seven quarantined PDF paths that
  do not add evidence. It also contains 81 non-quarantined searchable HTML paths
  representing 79 hashes (78 usable and one empty), three quarantined HTML paths,
  and two supplied text sources. The deterministic unified ledger contains 195
  records: 184 payloads and 11 metadata-only links/unavailable sources.
- All ten supplied ZIP archives pass integrity checks; all 125 archive members
  hash-match their extracted counterparts.
- The original 70-PDF review cohort remains auditable rather than being silently
  rewritten as the archive expands. Its current dispositions are 27 full/Core,
  35 Supporting, and eight Peripheral after the MusicSem deep-review upgrade. The
  four Logic manuals have separate complete every-page records, and six primary
  production-language/reference sources now have immutable full-read scope records.
  The unified 195-record ledger retains heterogeneous scope-specific labels instead
  of pretending every indexed payload received equivalent review.
- The core production archive already contains BS.1770-5, EBU R 128, the
  compressor papers, differentiable effect transfer, ST-ITO, differentiable
  mixing, automatic EQ, Essentia, YIN, and MUSHRA.
- TrackSmith's current source passes 67/67 portable checks in Debug and Release
  without the optional external loudness vectors. The signed AUv3 and companion
  retain separate direct Logic Pro 11.2.2 and 12.3 workflow evidence. This evidence
  is version- and workflow-specific, not a claim about every Logic host mode or a
  credential-backed frontier-AI session.

The detailed existing ledgers remain authoritative for corpus coverage and
implementation state:

- [`SOURCE_AUDIT.md`](SOURCE_AUDIT.md)
- [`CORPUS_REVIEW.md`](CORPUS_REVIEW.md)
- [`RESEARCH_SYNTHESIS.md`](RESEARCH_SYNTHESIS.md)
- [`TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md`](TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md)
- [`CAPABILITY_MATRIX.md`](../../docs/CAPABILITY_MATRIX.md)
- [`KNOWN_LIMITATIONS.md`](../../docs/KNOWN_LIMITATIONS.md)
- [`LOGIC_MVP_VALIDATION_2026-07-14.md`](../../docs/evidence/LOGIC_MVP_VALIDATION_2026-07-14.md)

### External-source verification

The live-source pass checked current Apple host documentation, current Apple
compatibility statements, the official ITU/EBU PDFs, the cited papers and code
repositories, and the behavior of representative tutorial pages. PDF pages with
equations, standards requirements, effects controls, and paper limitations were
rendered and visually inspected rather than trusting text extraction alone.

## Corrections to the briefing

### 1. Logic documentation is now versioned at 12.3

The current Logic User Guide presents Logic Pro 12.3, while TrackSmith's direct
host evidence is for Logic 11.2.2. Those are two separate facts. All host claims
and screenshots must carry the Logic version used, and the host matrix now needs
a 12.3 validation lane rather than silently treating a mutable `/mac` URL as the
same document forever.

The [current Logic Audio Units page](https://support.apple.com/guide/logicpro/work-with-audio-units-in-logic-pro-for-mac-lgcp22a0dab0/mac)
still documents AUv2 and AUv3 in Logic. This supports the existing AUv3 decision;
it does not expose a project object model, region selection, native plug-in
insertion, or arbitrary track mutation.

### 2. Selection-Based Processing is a UX benchmark, not integration authority

Apple's [Selection-Based Processing workflow](https://support.apple.com/guide/logicpro/use-selection-based-processing-lgcp58245be1/mac)
allows a user to select regions or marquee ranges, preview A/B processing,
choose loudness compensation or overload protection, add effect tails, and
create a processed take. That is an excellent reference for TrackSmith's
preview/compare/commit language and for a documented user-mediated bake flow.

It is not an AU or companion API. TrackSmith cannot infer the selected region or
invoke that transaction through public AUv3 interfaces. Any product text must
say "use Logic's Selection-Based Processing" rather than imply that TrackSmith
controls it.

### 3. ARA is useful but is a poor production-core dependency

ARA is the public route for richer region/audio/analysis exchange, and Logic
12.3 release notes still include ARA fixes. It remains a legitimate licensed
research spike for source-aware, offline workflows.

It should not replace the AUv3 core:

- Apple says third-party ARA use on Apple-silicon Macs requires running Logic
  under Rosetta. See [Apple's Audio Unit compatibility note](https://support.apple.com/en-us/102082).
- Apple says general Rosetta availability continues through macOS 27, with only
  limited old-game functionality beginning in macOS 28. See
  [Using Intel-based apps on a Mac with Apple silicon](https://support.apple.com/en-us/102527).
- ARA has host workflow constraints and licensing/vendor approval work; it does
  not become a general Logic project-control API.

Decision: retain ARA as a capability-gated experiment. Revisit only if Apple
ships a native Apple-silicon path and the resulting product capability justifies
the SDK, licensing, host-mode, and compatibility costs.

### 4. App Groups do not provide Logic project access

App Groups are the correct supported boundary for data shared by TrackSmith's
same-team app and extension. Logic is not a member of TrackSmith's App Group.
The group can carry heartbeats, commands, validated graphs, capture artifacts,
and preview/cache state; it cannot expose Logic's selection, project database,
channel strips, or undo stack.

The authoritative AU document state should continue to live in the AU's full
state. App Group files are transport, discovery, cache, and reconciliation
evidence, not a substitute for host document persistence.

### 5. EBU Tech 3341 is 2023 version 4.0, not “2016 current”

The current direct publication is
[EBU Tech 3341 v4.0 (2023)](https://tech.ebu.ch/docs/tech/tech3341.pdf).
It specifies 0.4-second ungated Momentary loudness, 3-second ungated Short-term
loudness, gated Integrated loudness, display/update behavior, tolerances, and a
minimum requirements test set. It also says meters should be tested with the
ITU-R BS.2217 test signals.

This identifies a concrete TrackSmith gap: the current analyzer reports
integrated LUFS, maximum momentary LUFS, and approximate dBTP, but not Short-term
loudness or LRA. It also lacks formal external conformance vectors across all
supported sample rates.

### 6. EBU R 128's -23 LUFS is not a universal mastering target

EBU R 128 is a broadcast loudness-normalization recommendation. Its -23 LUFS
programme target should not become TrackSmith's default for streaming masters,
individual stems, or every user request. BS.1770 supplies measurement algorithms;
R 128 supplies a broadcast operating profile. Product targets must be explicit
profiles, not one magic number.

Marketing/tutorial references to platform normalization values can be used in
help text only after current platform verification. They must never be compiled
into permanent mastering constants.

### 7. The canonical differentiable-mixing publication is 2021

“Automatic Multitrack Mixing with a Differentiable Mixing Console of Neural
Audio Effects” appeared as a 2020 preprint and a 2021 ICASSP publication. Both
dates can be recorded, but bibliographic output should label the canonical
publication correctly. Add the permissively licensed
[pymixconsole implementation](https://github.com/csteinmetz1/pymixconsole) as
the most direct code companion before adding a general audio framework.

### 8. Some stated resource years are page-update guesses

Several tutorial entries labeled 2026 do not have stable publication metadata
supporting that date. Record `published_at` and `updated_at` only when exposed by
the source, and keep `retrieved_at` separate. A current page retrieval date is
not its publication year.

### 9. Public access is not the same as redistribution or AI-ingestion permission

The briefing's Yes/Conditional/No column is too coarse and occasionally too
confident. A publicly downloadable paper can still be copyrighted. An open-source
repository license does not automatically cover model weights, datasets,
generated assets, documentation, bundled binaries, or transitive dependencies.

Use operational handling classes instead:

| Class | Meaning |
|---|---|
| `redistributable` | The captured artifact has a documented license permitting the intended storage and redistribution. Preserve notices and provenance. |
| `internal_reference` | A lawful local copy may be retained for internal research; do not redistribute it or assume model-training rights. |
| `link_and_notes` | Store metadata, a stable URL, and original notes; do not mirror the source asset. |
| `license_review_required` | Intended product use, artifact type, or dependency chain needs explicit review before ingestion or distribution. |

This is an engineering handling policy, not legal advice.

## Source-by-source disposition

### Official Apple and Logic resources

| Resource | Disposition | TrackSmith use |
|---|---|---|
| Logic Pro User Guide | Keep, versioned | Host vocabulary, user workflows, manual QA, and version-specific capability checks. Do not treat the mutable page as a frozen specification. |
| Logic Pro Effects Guide | Keep, versioned PDF | Native effect terminology, parameter vocabulary, and UX parity. It is descriptive documentation, not permission to control Logic's native effects. |
| Work with Audio Units | Core | Confirms AUv2/AUv3 presentation and packaging. Supports the current AUv3 production core. |
| Selection-Based Processing | Core UX reference | Model preview, A/B, loudness-compensation, tail, and create-new-take language. User-mediated only. |
| ARA support | Conditional experiment | Richer source/region access if native host support, SDK/license, and product value align. Not a stable project API. |
| Project alternatives and backups | Safety benchmark | Align TrackSmith's reversible language with Logic's mental model. TrackSmith cannot invoke these workflows through AUv3. |
| Control Surfaces Guide | Experimental adapter reference | Explicit user mappings and bounded transport/mixer operations only. Never infer a complete or transactional project model. |
| `AUAudioUnit` | Core implementation source | Render resources, buses, parameters, state, latency/tail, presets, transport, and musical context. |
| AUv3 documentation | Core implementation source | Extension architecture, packaging, host contracts, and lifecycle. |
| Configuring App Groups | Core implementation source | Supported companion/extension sharing boundary and entitlements. |

Apple Developer pages are JavaScript applications. A plain `requests.get()`
snapshot can contain only a shell. For archival text, prefer Apple's documented
page plus the corresponding Apple documentation Markdown endpoint when
available, and save both the canonical URL and the exact retrieval URL:

- `https://docs.developer.apple.com/tutorials/data/documentation/audiotoolbox/auaudiounit.md`
- `https://docs.developer.apple.com/tutorials/data/documentation/audiotoolbox/audio-unit-v3-plug-ins.md`
- `https://docs.developer.apple.com/tutorials/data/documentation/xcode/configuring-app-groups.md`

### Standards and deterministic DSP

| Resource | Disposition | TrackSmith use |
|---|---|---|
| ITU-R BS.1770-5 | Normative core | Integrated loudness and true-peak implementation and conformance tests. Use the official original PDF. |
| EBU R 128 v5 (2023) | Core profile | Broadcast profile, terminology, and user education; not a universal output target. |
| EBU Tech 3341 v4.0 (2023) | Add as core | Momentary/Short-term/Integrated meter behavior and minimum test requirements. |
| ITU-R BS.2217 test material | Add as core validation | External test signals and tolerances for loudness-meter validation. |
| EBU Tech 3342 | Add for LRA | Normative operational detail for Loudness Range when LRA is implemented. |
| Compressor tutorial | Keep as core | Detector topology, static curve, time constants, and artifact-aware implementation. The current branching detector aligns with it. |
| YIN | Keep as baseline | Monophonic pitch tracking and confidence only. Replace the failing legacy PDF URL with DOI `10.1121/1.1458024` plus a lawful local copy. |
| Logic Effects Guide | Supporting implementation/UX reference | Compare TrackSmith controls and labels to Logic vocabulary; do not copy proprietary UI or text. |

#### Source-fidelity defect found in the local corpus

`research/papers/13_ITU-R_BS.1770-5_Loudness_True_Peak.pdf` is not byte-identical
to the official ITU PDF. The local file reports Ghostscript 10.02.1 as producer,
was regenerated on 2026-07-12, and has SHA-256:

`ce14d02196af55b7724781678c56c2d9e5c6795424f8d93617163b7bb97facc0`

The [official ITU original](https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.1770-5-202311-I%21%21PDF-E.pdf)
reports the ITU/Word production metadata and has SHA-256:

`eefb926f72f72a96b96f251067bfee0650a0f29a26f60661d354162038b041ad`

Visual comparison found corrupted equation glyphs in the regenerated local
copy. Archive integrity correctly proves that the ZIP and extraction match, but
not that the source is a faithful publisher original. Do not silently overwrite
the user-supplied artifact. Add the official original as a separately identified
source, update the provenance ledger, and use it as the normative review copy.

The local EBU R 128 PDF does match the official file byte-for-byte at SHA-256
`4292cd2396e4cb386c3a6c1412cb4370fc108ef50956e78a24fbd8657ce2ca28`.

### Controllable-audio research

| Resource | Disposition | TrackSmith use |
|---|---|---|
| Automatic EQ for individual instrument tracks | High-priority research | Source-conditioned tonal targets and constrained parametric EQ fitting. Validate on real session stems and expose every band. |
| Style Transfer of Audio Effects with DSP | Core design evidence | Supports interpretable effect-parameter prediction rather than opaque waveform replacement. Audit paper/code/model licenses independently. |
| ST-ITO | Offline experiment | Useful for bounded reference matching when a suitable chain exists. It is far too expensive and chain-dependent for the render path. |
| Differentiable Mixing Console | Core design evidence | Supports a shared, human-readable multitrack graph as an inductive bias. Add `pymixconsole` as implementation reference. |
| Audio Editing in the Era of Foundation Models | Roadmap-only preprint | Useful taxonomy for future editing/evaluation. It is a fresh preprint, not stable architecture authority, and does not replace detailed DSP/spatial literature. |
| Essentia | Prototype/evaluation candidate | Valuable descriptor and baseline toolkit. Product integration requires license, model, dependency, and deployment review. |
| YIN | Deterministic baseline | Confidence-aware monophonic analysis, not automatic vocal correction. |

The research corpus supports the current split:

- deterministic, inspectable DSP renders the product edit;
- analysis and learned representations describe sources, enforce constraints,
  and rank bounded candidates;
- language resolves intent and produces a validated structured plan;
- offline optimization may search visible parameters behind an experimental
  boundary;
- no model writes unbounded audio or render-thread parameters directly.

ST-ITO's own evaluation reinforces the boundary: inference is orders of
magnitude slower than a direct network, requires an appropriate effect chain,
and can struggle on source/effect combinations such as guitar tone. It is a
research branch, not a prerequisite for a useful TrackSmith.

### Production tutorials and interview hubs

| Resource | Disposition | TrackSmith use |
|---|---|---|
| iZotope mixing guide | Language corpus | Common sequence and user-intent vocabulary. Strip product promotion and avoid turning examples into defaults. |
| iZotope vocal EQ guide | High-value language corpus | Terms such as mud, presence, harshness, sibilance, sparkle, and air; map them to measured hypotheses and bounded EQ strategies. |
| iZotope streaming/mastering guide | Help-text source only | Explain normalization and loudness tradeoffs. Re-verify platform policies; never encode a single streaming target from a marketing article. |
| Waves Vocal Compression 101 | Manual capture / language corpus | Attack, release, ratio, serial/parallel, and revision phrases. Dynamic/bot rendering makes automated snapshots unreliable. |
| Waves Vocal Production guide | Language/workflow corpus | End-to-end vocabulary and ordering alternatives. Treat product-specific claims and genre recipes as unvalidated. |
| Sound On Sound Techniques | Curated links and notes | Select case studies with provenance; do not bulk mirror the archive. |
| Pensado's Place | Curated notes/timestamps | Engineer decision language and workflow framing. Do not bulk download or redistribute video. The supplied site URL was not reliably resolvable during this pass. |

These sources should produce a provenance-tagged intent ontology, not a pile of
raw pages. Each entry should distinguish:

- the user's phrase;
- likely target attribute;
- required source evidence;
- permitted graph operations and bounded parameter ranges;
- preservation constraints;
- ambiguity/clarification rule;
- explanation language;
- source URL and retrieval date;
- whether the phrase came from a standard, research paper, manufacturer tutorial,
  interview, or TrackSmith listening study.

### Code repositories

| Repository | License-level disposition | Recommended use |
|---|---|---|
| [AudioKit](https://github.com/AudioKit/AudioKit) | MIT repository | Reference Apple-platform idioms only if a concrete need appears. TrackSmith's current native Swift core does not justify adding a large dependency by default. |
| [Pedalboard](https://github.com/spotify/pedalboard) | GPL-3.0 repository with bundled/dependency obligations to inspect | Isolated offline experiments or evaluator prototypes only until distribution implications are reviewed. Do not link it into the shipped product casually. |
| [Essentia](https://github.com/MTG/essentia) | AGPL-3.0 repository; separate commercial path and separately licensed models may apply | Benchmark/prototype in an isolated research environment. Audit exact library, models, dependencies, and deployment architecture before product use. |
| [st-ito](https://github.com/csteinmetz1/st-ito) | Apache-2.0 repository | Pinned offline experiment. Audit checkpoints, embeddings, datasets, and dependencies separately from repository code. |
| [pymixconsole](https://github.com/csteinmetz1/pymixconsole) | MIT repository | Preferred small implementation companion for differentiable-console research. |

Do not clone these repositories wholesale into the already large research tree.
Record the upstream URL and immutable commit, inspect a temporary checkout, and
vendor only a justified component after dependency and license review.

## Review of the proposed archive script

The proposed folder taxonomy is sensible. The script is not suitable as the
authoritative archive builder without substantial changes.

### Failure modes in the supplied script

1. `requests.get()` captures JavaScript shells for Apple Developer pages. The
   file exists, so the script reports success even though the content is unusable.
2. It does not validate `Content-Type`, file signatures, minimum useful text,
   PDF page count, or whether an HTML response is an error/bot page.
3. Downloads write directly to the destination. An interruption can leave a
   partial file looking final; use a temporary file, validate it, `fsync`, then
   atomically rename it.
4. No SHA-256, byte count, final redirect URL, status, ETag, Last-Modified,
   retrieval timestamp, or source version is recorded.
5. Git clones pin only the moving default-branch tip at fetch time. The manifest
   records no commit, tag, tree hash, submodule state, or lockfile/dependency audit.
6. Existing repository directories are silently accepted without confirming
   their origin, commit, cleanliness, completeness, or license.
7. `allow_download` is not a rights determination. The manifest makes legal
   conclusions without recording a rights basis, license version, notices, or
   intended use.
8. Model weights, datasets, example audio, documentation, and transitive
   dependencies are not separated from repository code.
9. The YIN URL currently fails. The Tech 3341 publication page blocks simple
   automation while the direct current PDF works. Pensado's URL was unreliable.
10. There are no retries/backoff, size limits, timeouts per artifact class,
    resumable downloads, or global failure summary suitable for CI.
11. The fallback `.url` file records a transient exception but no structured
    status. A failed required source does not fail the overall run.
12. Filename years are hard-coded and can become false metadata as mutable pages
    update.
13. There is no capture-quality gate. The regenerated local BS.1770 PDF proves
    why byte integrity alone is insufficient for equation-heavy sources.

### Required manifest contract

Every captured resource should have at least:

```text
resource_id
title
publisher_or_authors
evidence_role
canonical_url
retrieval_url
source_version
published_at
updated_at
retrieved_at_utc
capture_mode
handling_class
rights_basis
local_path
http_status
final_url
media_type
byte_count
sha256
etag
last_modified
git_commit
license_spdx
notices_path
dependency_review_status
capture_status
quality_status
review_depth
notes
```

The capture process should:

1. fetch to a temporary path;
2. record redirect/provenance metadata;
3. verify the media signature and expected type;
4. validate PDF page count/text and visually inspect sampled equation/UI pages;
5. validate HTML useful-text thresholds and detect error/bot shells;
6. hash the exact artifact;
7. atomically publish only a valid capture;
8. pin Git resources to immutable commits and capture license/notices at that
   commit;
9. fail the run when a required Core source is missing or invalid;
10. retain link-and-notes records for resources that should not be mirrored.

## Current TrackSmith capability map against the briefing

| Briefing area | Current TrackSmith state | Decision/gap |
|---|---|---|
| AUv3 production core | Implemented, signed, registered, `auval` and direct Logic 11.2.2 workflow evidence | Keep; extend the versioned Logic host matrix. |
| Companion/App Group transport | Implemented with instance binding, hashes, quotas, expiry, and reconciliation | Keep; measure load/polling and preserve AU full state as document authority. |
| Deterministic DSP graph | Implemented EQ, compression, de-essing, saturation, width, output, and limiting subset | Keep inspectable graph. Add click-free graph transitions and finish only validated modules. |
| Capture and preview | Recent insert-stream capture, three loudness-matched previews, distinctness gate, exact commit | Add explicit “capture next,” longer-session memory strategy, and listening calibration. |
| Undo/reversibility | Product undo/redo and AU full-state restore exist | Persist named history across companion restarts; do not claim integration with arbitrary Logic undo. |
| Loudness/true peak | Integrated LUFS, max Momentary, Annex 2 at 48 kHz, bounded approximation elsewhere | Add Short-term, LRA, BS.2217/Tech 3341 tests, and sample-rate conformance. Limiter is still sample peak. |
| General analysis | Averaged spectrum plus bounded RMS/crest/flux timelines | Add source-aware vocal/drum features, masking/room/noise evidence, and confidence/calibration. |
| Conversational planning | Deterministic keyword/revision layer; no general LLM adapter | Build provenance-tagged intent ontology, typed ambiguity handling, and evaluation before provider breadth. |
| Automatic/source-aware EQ | Not implemented | Highest-value research-to-product feature after standards/host closure. Output visible bounded bands. |
| Reference style transfer | Not implemented | Offline experimental branch only; preserve visible graphs and source attributes. |
| ARA/control surface | Not implemented | Correctly excluded from core. Re-evaluate only against a specific user capability and current host constraints. |

## Prioritized engineering sequence

This is deliberately outcome-ordered, not calendar-ordered.

### Priority 0: evidence and product-truth closure

1. Add the official original BS.1770-5 PDF as a distinct, hashed artifact and
   mark the Ghostscript copy non-normative. Do not destroy the supplied evidence.
2. Add EBU Tech 3341 v4.0, EBU Tech 3342, and ITU-R BS.2217 test material to the
   source ledger.
3. Implement and externally validate Short-term loudness and LRA; document which
   metrics are conformant at which sample rates.
4. Run the existing signed workflow and focused host matrix on Logic 12.3 while
   retaining 11.2.2 evidence. Cover buses, stereo output, freeze, bounce/offline,
   low-latency mode, automation, rate/buffer changes, and multi-instance load.
5. Freeze the revised resource manifest/handling policy before adding more raw
   downloads or repository clones.

### Priority 1: product-quality leverage

1. Implement source-aware analysis with confidence and bounded evidence windows.
2. Build constrained parametric EQ fitting that produces inspectable bands and
   compares against deterministic heuristics.
3. Create the production-language ontology and prompt/revision evaluation set
   from curated tutorials, interviews, real user language, and listening tests.
4. Add durable named snapshots/history and complete change-card reset/remove/solo
   and advanced parameter editing.
5. Add click-free graph transitions and measure callback timing/allocation under
   actual Logic load.

### Priority 2: bounded intelligence experiments

1. Reproduce `pymixconsole` and ST-ITO results in isolated, pinned environments.
2. Define preservation, naturalness, target-success, and parameter-plausibility
   evaluations before integrating any learned ranker or optimizer.
3. Test offline reference matching only on visible, allow-listed effect graphs
   with hard render/time/candidate budgets.
4. Consider ARA only through a new native Apple-silicon feasibility gate and a
   concrete capability that AUv3 plus user-mediated import/capture cannot meet.

## TrackSmith naming decision

Use **TrackSmith** in all new conversation, research, product copy, UI plans, and
new evidence records.

Do not perform a blind repository-wide rename. The current development bundle
IDs, App Group entitlement, AU manufacturer/type/subtype identity, persisted
state, mailbox schemas, install paths, and signed Logic project evidence form a
compatibility boundary. Historical documents also need to preserve the product
name and identifiers that were true when the evidence was captured.

A safe future rename should be a migration with separate decisions for:

1. user-visible app and plug-in display names;
2. Xcode target/product names and repository directory;
3. bundle identifiers and signing/provisioning;
4. App Group identifier and cache/state migration;
5. AU component identity and old Logic project compatibility;
6. persisted plan/full-state schema compatibility;
7. documentation history versus current branding.

Until that migration is approved and tested, **TrackSmith** is the product name
and the existing technical identifiers remain compatibility identifiers.

## Final decision record

Accepted:

- layered source hierarchy with official host docs and standards first;
- deterministic, explicit DSP graphs as the product edit representation;
- AUv3 plus companion plus App Group as the production architecture;
- standards-backed loudness/true-peak analysis;
- source-aware, parameterized EQ as a high-value next intelligence feature;
- offline, bounded style-transfer research behind an experimental boundary;
- production tutorials as a user-language corpus;
- a rights/provenance manifest and selective archival.

Rejected or corrected:

- treating the project as pre-integration or pre-DSP-core;
- treating Selection-Based Processing as callable host integration;
- making ARA/Rosetta a default future core;
- treating App Groups as Logic project access;
- labeling Tech 3341 as 2016-current;
- using -23 LUFS or -14 LUFS as a universal mastering target;
- equating a public URL with redistribution or AI-ingestion permission;
- bulk cloning repositories into the research archive;
- accepting unvalidated HTML/PDF downloads as successful captures;
- bulk-renaming compatibility identifiers to TrackSmith without migration.

The product direction is sound. The fastest path to a stronger TrackSmith is
not more general reading: it is standards conformance, current-host evidence,
source-aware analysis, durable inspectable UX, and a small carefully curated
intent/evaluation corpus.
