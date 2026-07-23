# TrackSmith Patent and Technical Prior-Art Landscape

**Review date:** 2026-07-16  
**Scope:** Patent landscape batch 1 - automatic mixing, semantic control, source-aware processing, mastering, effect recommendation, preservation, and counterfactual mix analysis  
**Evidence class:** Patent disclosure or claimed invention  
**Legal boundary:** Technical prior-art analysis only. This document is not a legal opinion, claim chart, validity analysis, infringement analysis, or freedom-to-operate conclusion.

## Outcome

This batch converts the strongest first-wave patent material into a family-level technical map tied to TrackSmith's existing architecture. It contains 15 invention families represented by 16 resource records: 14 validated, content-addressed PDFs and two link-only records retained after immutable retrieval returned HTTP 503. Every family was reviewed at the independent-claim and core-embodiment level. Four image-only PDFs were navigated with derived OCR and verified against rendered original pages; OCR was not substituted for the preserved source bytes.

The central result is not that conversational production or intelligent mixing is unoccupied. Foundational disclosures already cover semantic commands conditioned on track analysis, semantic rules backed by production data, source recognition that controls effects, rule-driven multitrack processing, cross-adaptive EQ, reference spectra, learned recommendations from engineer examples, and learned multitrack controllers. The defensible product opportunity is the combination those families generally do not establish:

1. provenance-bearing production language;
2. typed intent separated from diagnosis and from executable plans;
3. calibrated uncertainty, abstention, clarification, and multiple interpretations;
4. exact deterministic DSP rather than hidden audio transformation;
5. durable preview, revision, commit, bypass, and project-persistence semantics;
6. explicit preservation constraints and no-change alternatives;
7. evaluation that controls loudness and measures preference, context, and downstream harm.

The most important technical contradiction is unusually concrete. The MixGenius automatic-mixing disclosure includes small listening studies in which heavy automatic compression performed poorly, no compression was often among the best conditions, and an automatic panning rule failed on an alternative-pop excerpt where listeners preferred a narrower presentation. This directly rejects the premise that cleaner metrics, wider images, or stronger normalization are safe universal goals. It supports TrackSmith's existing hypothesis-and-preview architecture: diagnose, expose alternatives, preserve character, and know when not to act.

## What this batch does and does not establish

Patent documents establish that concepts were disclosed or claimed. They can establish claim wording, priority chains, concrete embodiments, equations, and what an applicant chose to teach. They do not establish that:

- a claimed system was built;
- a product uses the claimed embodiment;
- an algorithm sounds good;
- a semantic label is perceptually grounded;
- a patent is valid, enforceable, or currently in force in every jurisdiction;
- an unclaimed implementation is safe from other rights;
- TrackSmith infringes or avoids any claim.

Status notes in this document are snapshots from Google Patents or an accessible patent record. Google explicitly treats legal-status and assignee fields as assumptions. PCT cessation does not decide national-stage rights. Maintenance-fee signals and anticipated expiration dates require official-register verification before legal reliance.

## Corpus and review accounting

| Measure | Result |
|---|---:|
| Resource-level patent records reviewed | 16 |
| Consolidated invention families | 15 |
| Validated retained PDFs | 14 |
| Link-only records after HTTP 503 | 2 |
| Image-only originals requiring OCR navigation | 4 |
| Family-level matrix rows | 15 |
| Deep-review metadata records | 16 |

The resource/family mismatch is intentional. The Dolby automated-multitrack family has a retained WO specification and a separate link-only current US grant record. They are two resources but one intellectual-work family. Continuations in the iZotope masking family are likewise one family, not four separate inventions.

Authoritative local outputs for this batch are:

- `research/analysis/PATENT_MATRIX.csv` - one row per consolidated family;
- `research/metadata/deep-review-batch-1-patents.jsonl` - one review record per resource so the deterministic source index can enrich review depth;
- `research/metadata/source-manifest-patents-v1.jsonl` - immutable-ingestion declarations;
- `research/library/tracksmith-research-archive/objects/` - preserved content-addressed source bytes.

## Family consolidation method

Counting publications would materially overstate coverage. This batch used the following family rules:

1. Normalize the earliest claimed priority date and inspect the priority chain.
2. Merge national-stage copies, grants, applications, and continuations when they share substantially the same specification, inventors, assignee lineage, and core technical concept.
3. Preserve publication-level claim differences inside one family record. A continuation with a different independent-claim focus is noted, not silently flattened.
4. Treat payload identity and intellectual-work identity separately. SHA-256 removes byte duplicates; family analysis removes duplicate disclosures in different bytes.
5. Retain a separate resource record when it supplies materially current claims, status, or a better payload, while linking it to the same `work_family_id`.
6. Do not merge merely because titles or assignees resemble one another. The two 2017 iZotope families share a priority date but have distinct specifications and claim focuses, so they remain separate.

Examples:

- `WO2021259725A1` and `US12456493B2` are one Dolby learned-mixing family. The WO file supplies the specification and figures; the US record supplies materially narrower current independent claims.
- `US10396744B2`, `US10763812B2`, `US10972065B2`, and `US11469731B2` are consolidated into one iZotope masking family.
- `WO2015035492A1` and `CA2919662A1` represent one MixGenius automatic-multitrack family, not two inventions.

## Deep-reading protocol

For each core family, review covered the bibliographic front matter, earliest priority, independent and material dependent claims, concrete algorithms and system diagrams, evaluation passages, limitations, cited technical prior art, and family/status signals. Claim scope was kept separate from specification breadth.

For native-text PDFs, the preserved file was read through extracted text and important claims, equations, and figures were visually checked on rendered pages. For image-only PDFs:

- the original PDF remained immutable;
- OCR was generated only as a derived navigation aid under `tmp/pdfs/patents/`;
- claims, evaluation text, equations, and diagrams used in conclusions were checked against rendered original pages;
- review metadata names the rendered pages;
- the OCR derivative is not represented as the original publisher text layer.

The two link-only records are explicitly limited:

- `US12456493B2` current claims were reviewed alongside the retained WO family specification, but no separate US payload is claimed;
- `WO2025195953A1` was reviewed from the accessible patent record, but no local payload is claimed.

## Search strategy and coverage

### Technology query families

Searches used current and historical language, including:

- automatic mixing, intelligent mixing, autonomous multitrack processing;
- automatic mastering, target-spectrum mastering, reference matching;
- semantic audio editing, semantic mixer, natural-language effects, conversational production;
- audio-effect recommendation, algorithm selection, preset recommendation;
- source-aware processing, source recognition, instrument classification;
- automatic EQ, de-masking, masking remediation, high-pass selection;
- automatic compression, dynamics initialization, intelligent limiting;
- multitrack optimization, differentiable mixing, learned effect control;
- presentation-independent mastering, spatial and object-audio preservation;
- perceptual contribution, counterfactual track removal, redundant-track detection.

Searches were repeated through technology terms, inventors, assignees, cited patents, cited non-patent literature, international search reports, backward citations, and selected forward-citation paths. The terminology was deliberately broader than TrackSmith's repository vocabulary.

### Assignee and entity coverage

Deeply represented in batch 1:

- Adobe;
- Apple;
- Dolby;
- DTS;
- Fraunhofer;
- iZotope and current Native Instruments assignment records;
- LANDR and MixGenius;
- Sony;
- Waves.

Scoped searches also covered Avid, Yamaha, Steinberg, Focusrite, Sonible, Google, Spotify, Microsoft, Amazon, Meta, ByteDance, and Tencent. A scoped Sonible assignee query returned no qualifying family; that is not evidence that Sonible has no relevant patents because assignments, corporate names, translations, and query syntax can hide results.

Coverage is not yet saturated for BandLab, RoEx, Soundtheory, Universal Audio, startup assignee aliases, Asian-language filings, prosecution histories, and global national-stage status. These are explicit next-batch gaps, not negative findings.

### Saturation result

The strongest first-order clusters reached initial duplicate saturation: repeated searches mostly returned the same Fraunhofer semantic family, LANDR/MixGenius families, iZotope recognition/masking/enhancement families, Waves recommendation/semantic-control families, and Dolby learned-mixing family. The landscape as a whole has not reached the user's completion standard. Recent filings, assignee aliases, non-US prosecution, and specialist subdomains remain open.

## Family map

| Earliest priority | Family | Primary concept | Technical relevance | Review confidence |
|---|---|---|---|---|
| 2009-09-28 | iZotope audio recognition | Source label to application control | Classification uncertainty and downstream harm | High claims; no performance evidence |
| 2011-02-03 | Fraunhofer semantic mixer | Semantic command plus track analysis to mix parameters | Foundational conversational prior art | High claims and architecture |
| 2012-05-08 | LANDR autonomous multitrack | Feature/rule-controlled multitrack processing | Source-aware deterministic processing | High claims and algorithms |
| 2013-03-15 | DTS stem mix | Metadata-selected rules and surround matrix | Rule selection from source metadata | High claims; partial stereo transfer |
| 2013-08-28 | LANDR semantic production | Semantic rules, production data, reference matching | Intent-to-DSP and semantic retrieval | High claims; no efficacy evidence |
| 2013-09-13 | MixGenius automatic multitrack | De-masking, target EQ, gain compensation, panning, DRC | Concrete algorithms plus negative evaluation | High disclosure; moderate family completeness |
| 2013-10-18 | Apple content-aware ducking | Minimum loudness-separation constraint | Exact reversible interaction envelope | High claims; limited music transfer |
| 2016-08-01 | Adobe threshold | Average-derived dynamics threshold | Transparent initializer baseline | High claims; no preference evidence |
| 2017-06-07 | iZotope masking | Loudness-loss masking diagnosis and remedies | Observation/action separation | High reviewed continuations |
| 2017-06-07 | iZotope enhanced audio | Source-aware EQ and multiband dynamics | Bounded source templates and user control | High claims; no efficacy evidence |
| 2019-07-09 | Dolby presentation-independent mastering | Transfer mastered attributes across object renderings | Multi-context preservation evaluation | High claims/equations; partial stereo transfer |
| 2020-05-18 | Waves DAW recommendations | Learn operations from before/after engineer examples | Producer-corpus and ranking design | High claims; no performance evidence |
| 2020-06-22 | Waves Color Slider | Semantic macro through coordinated source gains | Mechanism ambiguity of production adjectives | High claims/equations |
| 2020-06-22 | Dolby automated multitrack | Learned controller plus transformation network | Future model boundary and exact-DSP differentiation | High family contrast; status moderate |
| 2024-03-18 | Sony mix assistance | Perceptual loss from source removal | Counterfactual preservation signal | Moderate link-only review |

## Technical cluster synthesis

### Semantic and conversational control is established prior art, but semantic certainty is not

The Fraunhofer and LANDR semantic families make natural-language or semantic control alone an insufficient differentiation claim. Fraunhofer discloses semantic commands converted to crisp mix parameters using track and time-section information, vocabulary, grammar, perceptual mapping, examples, and confidence. LANDR discloses semantic rules backed by production data and semantic matching to reference records. Waves later shows that one word such as bright can coordinate gains across sources rather than merely drive a master EQ.

The unresolved technical problem is meaning under context. A request for a brighter vocal can imply presence EQ, less low-mid density, more air, a drier ambience, stronger articulation, or a different balance against guitars. The same word at mix scope can imply source rebalance rather than a master-bus filter. None of the reviewed patents establishes a reliable universal mapping or a sufficient evaluation method for ambiguous creative language.

TrackSmith consequence: preserve the current boundary

    intent -> source-aware evidence -> competing production hypotheses
           -> bounded deterministic editable plans

The semantic record must carry source, musical role, section, genre/aesthetic context, desired attributes, preserved attributes, prohibited changes, evidence for and against, confidence, provenance, and clarification conditions. The executable plan is a consequence of a selected hypothesis, not of the text label itself.

### Source recognition is useful evidence and dangerous control authority

The iZotope recognition family explicitly connects windowed audio classification to control events, chain selection, presets, and console parameters. LANDR, DTS, and iZotope enhancement disclosures also condition processing on detected source or genre. This is technically useful but exposes a recurring failure boundary: none of these families establishes calibrated abstention, unknown or mixed-source representation, role inference, or the cost of a wrong label after processing.

TrackSmith should therefore propagate at least:

- class probabilities or ranked alternatives;
- calibration version and validity conditions;
- unknown and mixed-source states;
- observed evidence versus inferred musical role;
- downstream hypotheses affected by the label;
- a harm estimate or conservative fallback when the label is uncertain.

The source classifier should never write a DSP plan directly.

### Cross-adaptive processing is measurable, but the objective is not the preference

The MixGenius and iZotope masking families provide concrete pairwise analysis patterns. They compare frequency bands or loudness loss across sources, derive masking evidence, assign source priority, and propose filtering, EQ, level, panning, compression, or phase changes. These patterns can help answer where sources interact and how a bounded operation changes that interaction.

They do not answer whether the overlap is bad. Unison blend, dense guitars, shoegaze layers, stacked vocals, distorted bass, and orchestral doubling can depend on overlap. A masking metric should produce an observation such as:

    source A loses partial loudness in region R when source B is present

It should not silently become:

    cut source B in region R

The intervention additionally requires artistic priority, role, section, arrangement, preservation, and listening evidence. TrackSmith's no-change candidate is technically essential, not a UX nicety.

### Automatic mastering and reference matching are underdetermined

LANDR and MixGenius disclose target-spectrum processing, smoothing, filter design, dynamics heuristics, and reference-derived targets. Dolby presentation-independent mastering transfers attributes from a mastered rendering to object signals so alternate presentations remain compatible. These show useful mechanisms, but not that a reference identifies the intended transformation.

For same-content or related-content analysis, a target can constrain measurable attributes. It cannot reveal the original processor order, nonlinear history, phase behavior, automation, monitoring decisions, arrangement intent, or which differences should be preserved. The appropriate TrackSmith representation is a set of feature-scoped objectives with provenance and tolerance, not a single instruction to match the reference.

### Learned control is newer, but exact execution remains a strong boundary

The Waves recommendation family learns from original and human-processed examples and retrieves operations conditioned on target features or tags. The Dolby family trains a controller with a learned transformation model and describes interpretable effect parameters, whole-mix context, routing, and modern neural architectures.

Neither family supplies the evidence needed to move a learned audio transformation into TrackSmith's real-time path. The disclosures do not establish broad dataset coverage, preference across valid alternatives, out-of-distribution behavior, uncertainty, long-form coherence, or preservation. The current TrackSmith boundary is technically sound:

- model reasoning and candidate generation outside the real-time thread;
- a versioned, bounded plan schema;
- exact deterministic DSP in the AUv3;
- replayable preview and revision history;
- independent evaluation of the plan and of the rendered audio.

### Preservation is a first-class objective, not a final safety check

Apple's ducking family expresses an interaction as a declarative minimum separation. Dolby evaluates transferred mastering attributes across alternate presentations. Sony compares a mix against a counterfactual mix with one track removed. Together they support a broader pattern: every proposed change should be evaluated against what the user intends to preserve and across every context that the edit affects.

For TrackSmith, a candidate should carry explicit invariants such as:

- source identity and source bytes unchanged;
- protected transient, dynamic, spatial, or timbral attributes;
- locked nodes and prior accepted choices unchanged;
- peak, loudness, phase, and mono-compatibility bounds;
- section-local versus whole-song scope;
- alternate stem, bus, bypass, and export render checks;
- exact restoration and deterministic replay.

## Family deep profiles

### 1. iZotope - Automatic Labeling and Control of Audio Algorithms by Audio Recognition

**Family:** US20110075851A1 / [US9031243B2](https://patents.google.com/patent/US9031243B2/en)  
**Priority:** 2009-09-28  
**Core claimed concept:** Window audio, form and reduce a feature vector, classify a sound object, and emit control events that configure an audio application.

The specification lists conventional spectral and cepstral features, statistical reduction, and multiple classifier families. The output can select tools, chains, presets, or parameters in real time. The important technical lesson is the separation between feature extraction, dimensionality reduction, labeling, and application control.

What it does not establish is more important for TrackSmith: no accuracy, calibration, rejection, mixed-source, role, or downstream-harm evaluation was found. Instrument identity is not musical role. A vocal double, lead vocal, ad-lib, and choir stem can share a label while needing opposite interventions. The safe design is to preserve every recognition result as evidence with confidence and provenance, then require contextual hypothesis reasoning before any plan.

### 2. Fraunhofer - Semantic Audio Track Mixer

**Family:** EP2485213A1 / WO2012104119A1 / [US9532136B2](https://patents.google.com/patent/US9532136B2/en)  
**Priority:** 2011-02-03  
**Core claimed concept:** Analyze tracks, interpret a semantic command in light of track information, convert semantic meaning to crisp parameters, process, and combine.

This is the closest foundational semantic prior art in the batch. The architecture includes vocabulary and grammar, semantic audio analysis, target descriptors, perceptual processing, signal processing, example mixes, multidimensional controls, and speech. Track identification can use templates, timbre, rhythm, frequency content, sample features, or harmonic density; commands can be section-specific. A representative example is the equivalent of making a guitar prominent during its solo while moving keyboards into the background.

The disclosure anticipates source-aware semantic control, but not TrackSmith's full state machine. It does not establish durable conversational revision, typed evidence for and against a hypothesis, locked-node preservation, exact plan replay, or project persistence. TrackSmith should distinguish itself through those verified workflow semantics and by treating ambiguity as a first-class state.

### 3. LANDR and Queen Mary - System and Method for Autonomous Multi-Track Audio Processing

**Family:** WO2013159219A1 / [US9654869B2](https://patents.google.com/patent/US9654869B2/en)  
**Priority:** 2012-05-08  
**Core claimed concept:** Extract features from one or more tracks, define control functions, and process under multiple rules that include per-track and multitrack relationships.

The specification describes a complete pipeline: source recognition, subgroup and genre settings, loudness, compression, EQ, panning, and mastering. Concrete embodiments include target-spectrum division and smoothing, high-order Yule-Walker filter design, compressor thresholds from RMS, attack/release or knee from crest behavior, and spectral-centroid panning with activity gates. One disclosed compression estimate has the form c times T times (1 - 1/R), with c described as approximately 0.5 in an embodiment; the specification also places a limiter threshold above the compressor threshold.

These are valuable deterministic baselines, not evidence of a good mix. The claim does not require TrackSmith's typed intent, explicit alternatives, preservation constraints, or preview and revision lineage. The engineering use is to benchmark transparent heuristics against no-change and expert choices, not to inherit a fixed chain.

### 4. DTS - Automatic Multi-Channel Music Mix from Multiple Audio Stems

**Family:** WO2014151092A1 / US9640163B2 / [US11132984B2](https://patents.google.com/patent/US11132984B2/en)  
**Priority:** 2013-03-15  
**Core claimed concept:** Select rule subsets using stem metadata and generate a multichannel mix from stems and an artistic stereo mix under genre and surround configurations.

The specification uses condition/action rules, genre and voice metadata, stem effects, virtual-stage or listener coordinates, and a mixing matrix. A representative rendering equation is a weighted, delayed sum of stems for each output channel: C_j(t) = sum_i a_ij S_i(t - d_ij).

This family is primarily about surround conversion, not a general stereo producer. Its transferable lesson is that metadata changes which rules are applicable. Its failure risk is treating genre and source labels as final truth. TrackSmith should preserve rule applicability and confidence in the hypothesis record and validate spatial candidates against musical role and user intent.

### 5. LANDR and MixGenius - System and Method for Performing Automatic Audio Production Using Semantic Data

**Family:** US20150066481A1 / [US9304988B2](https://patents.google.com/patent/US9304988B2/en)  
**Priority:** 2013-08-28  
**Core claimed concept:** Combine semantic information, semantic rules, production data, and a semantically matched reference-record database to assign processing values.

The disclosure defines classifications such as genre, instrument, artist, style, and emotion; chromosomal or MIR features such as MFCCs, sub-band flux, tempo, and statistics; and production data such as processing actions, configurations, static characteristics, and target features. It also describes per-region processing, iterative mapping, multiple production alternatives, A/B or MUSHRA-style evaluation, and preference learning.

This breadth makes natural-language plus reference retrieval a crowded product idea. It still does not demonstrate that semantic similarity predicts the intended engineering action. TrackSmith should store reference scope, semantic provenance, competing mechanisms, and preservation constraints, and should ask for clarification when two plausible candidates have materially different effects.

### 6. MixGenius - System and Method for Performing Automatic Multi-Track Audio Mixing

**Family:** [WO2015035492A1](https://patentscope.wipo.int/search/en/detail.jsf?docId=WO2015035492) / CA2919662A1  
**Priority:** 2013-09-13  
**Core claimed concepts:** Multiple independent claims cover bandwise automatic EQ, target-spectrum mastering, iterative gain compensation, target generation, pairwise multitrack EQ, source-recognition high-pass filtering, semantic rules, and integrated de-masking or cleanup.

Concrete embodiments compare source pairs by band, apply priority rules, include adjacent bands, select the largest differences, place bounded filters, construct target profiles from normalized reference material, and iterate to compensate for overlapping filters. Panning uses spectral centroid and activity gates around -25 or -30 LUFS in examples. DRC examples target 3, 6, or 9 LU reductions.

This is the rare patent in the batch with directly relevant listening results. The panning study used six 20-second excerpts, three engineers, and eleven listeners. Automatic output was near professional output on some material and best on a reggae case, but performed poorly on an alternative-pop case where a narrower presentation was preferred. The DRC study used seven 20-second recordings and fifteen screened listeners. Heavy automatic compression was poor; no compression was often among the best conditions; and expert or light processing was stronger. No average mix exceeded fair.

The conclusion is not that the algorithms never work. It is that objective cleanup and rule allocation are source-, genre-, and goal-dependent, and that no-change is a serious candidate. TrackSmith should reproduce the task with longer material, whole-mix context, loudness matching, expert and target-user panels, and explicit preservation criteria.

The international search report marked WO2013167884 and US20120130516 as X or E against portions of the claim set and cited Perez-Gonzalez automatic-mixing work. Those classifications are search opinions, not legal conclusions.

### 7. Apple - Content Aware Audio Ducking

**Family:** [US9536541B2](https://patents.google.com/patent/US9536541B2/en)  
**Priority:** 2013-10-18  
**Core claimed concept:** Enforce a minimum loudness separation between two clips by reducing one during playback.

Embodiments use master/slave relationships, worst-case analysis windows, program loudness bounds, multiple pairings, and silence handling. The useful pattern is a declarative relationship that compiles to an exact gain envelope. The transfer limit is equally clear: this arose from multimedia or voice ducking, not evidence that music sources should maintain a fixed separation.

TrackSmith can use the pattern when a priority relationship is explicit, but must test pumping, transient triggers, silence recovery, intentional overlap, and genre-dependent blend. Static balance, sidechain compression, dynamic EQ, arrangement advice, and no-change should remain separate alternatives.

### 8. Adobe - Using Averaged Audio Measurements to Automatically Set Audio Compressor Threshold Levels

**Family:** [US10050596B2](https://patents.google.com/patent/US10050596B2/en)  
**Priority:** 2016-08-01  
**Core claimed concept:** Derive threshold behavior from averaged amplitude measurements; the issued independent claims include gate-like and ratio-selection variants.

The title suggests automatic compressor threshold setting, but issued claim 1 is narrower and gates below an average-derived threshold without scaling above it. Other claims discard extrema, average channels, map ranges to ratios, or use whole-file and RMS measurements. This title/claim mismatch is a useful warning against summarizing patents from titles or abstracts.

The implementation value is a transparent baseline initializer. It is not producer judgment. TrackSmith should compare mean, percentile, crest-aware, section-aware, and role-conditioned initializers, retain bounded adjustment, and test transient preservation and loudness bias.

### 9. iZotope - Systems and Methods for Identifying and Remediating Sound Masking

**Family:** WO2018226418A1 / US10396744B2 / US10763812B2 / US10972065B2 / [US11469731B2](https://patents.google.com/patent/US11469731B2/en)  
**Priority:** 2017-06-07  
**Core claimed concept:** Compare a first instrument's loudness without and with another instrument in a selected time-frequency region and apply measures based on the difference.

The reviewed continuation describes excitation patterns, partial loudness, loudness loss, audibility and extreme thresholds, GUI presentation, and remedies including filtering, level, EQ, panning, compression, and phase changes. The important family-level distinction is observation versus action: continuations and dependent claims vary in whether they identify, display, solicit user measures, or modify audio.

The family does not establish that less masking is artistically better. TrackSmith should model a masking observation independently from a remediation hypothesis. The hypothesis must name the assumed priority, affected section, audible evidence, alternatives considered, preservation tradeoff, and uncertainty. An overlap display may correctly lead to no change.

### 10. iZotope - Systems and Methods for Automatically Generating Enhanced Audio Output

**Family:** WO2018226419A1 / [US10635389B2](https://patents.google.com/patent/US10635389B2/en)  
**Priority:** 2017-06-07  
**Core claimed concept:** Identify a source, determine settings, analyze spectral and dynamic behavior, modify audio, and permit user adjustment; claim 1 includes different compression behavior inside and outside a detected peak-frequency band.

The source-to-template-to-analysis-to-adjustment architecture is close to commercial intelligent-assistant workflows. It supports a useful product pattern: source-aware defaults should be visible, strength-adjustable, and auditionable. But enhanced is a label, not a result. A detected peak band can be intentional, and a correct source class does not identify the goal.

TrackSmith's typed layers can make the missing distinctions explicit: source-confidence evidence, diagnostic observation, artistic goal, proposed mechanism, exact parameters, expected measurable direction, preservation constraints, and listening dependence.

### 11. Dolby - Presentation Independent Mastering of Audio Content

**Family:** WO2021005803A1 / EP3997700A1 / [US12069464B2](https://patents.google.com/patent/US12069464B2/en)  
**Priority:** 2019-07-09  
**Core claimed concept:** Compare mastered and unmastered rendered signals in time-frequency tiles and superimpose the attribute differences onto underlying input signals.

The specification calculates tile energy, a squared mastered/unmastered gain ratio, spatial-zone gains, and contribution-weighted object gains. It describes long and short analysis, CQMF/HCQMF/DFT alternatives, histograms, quantiles, spatial zones, and audition across renderings. Automatic mastering is a dependent embodiment; the independent claim is fundamentally attribute transfer.

The algorithm does not reconstruct phase, nonlinear history, interchannel compressor causality, or artistic intent. Its strongest TrackSmith implication is evaluative: a candidate that improves one rendering can fail another. TrackSmith should run preservation checks across declared source, bus, bypass, mono, alternate-render, and export contexts before presenting a candidate as safe.

### 12. Waves - Digital Audio Workstation with Audio Processing Recommendations

**Family:** GB2595222A / US20210357174A1 / [US11687314B2](https://patents.google.com/patent/US11687314B2/en) / CN113691909B  
**Priority:** 2020-05-18  
**Core claimed concept:** Learn from original and human-processed track pairs, condition on a target feature, retrieve a recommendation, and output operations intended to emulate human processing.

The disclosure uses tags such as instrument, genre, style, mood, bright, dark, and free text; STFT, MFCC, or raw features; a database of operations; similarity retrieval; and iterative processing and re-analysis. It anticipates demonstration-based recommendations inside a DAW.

The missing information is decisive: dataset size and coverage, engineer diversity, train/test leakage, target grounding, model architecture, privacy, uncertainty, alternatives, preservation, and listening evaluation are not established. A before/after pair records what happened, not why it happened, what was rejected, or what needed to remain unchanged.

TrackSmith's Producer Judgment Corpus should therefore store the complete decision structure: problem, listening diagnosis, contextual interpretation, alternatives, intervention, result, tradeoff, stopping criterion, provenance, and confidence. Any learned component should rank explicit candidates; it should not infer a hidden transformation and write audio in the real-time thread.

### 13. Waves - Color Slider

**Family:** GB2596287A / US20210397409A1 / [US11531519B2](https://patents.google.com/patent/US11531519B2/en)  
**Priority:** 2020-06-22  
**Core claimed concept:** Compute a mix frequency-content metric from source gains and collectively adjust gains so the mix approaches a user-selected metric.

The specification uses two emphasis filters per track, combines log gains, interpolates along a dark-to-bright control, and normalizes loudness. This is an important semantic counterexample: brighter can mean changing which sources dominate rather than adding high-frequency gain to the master.

TrackSmith should generate mechanism-distinct candidates when language permits them. For brighter, those may include source rebalance, master EQ, source-local presence or air, transient emphasis, ambience change, arrangement advice, and no change. The candidate UI should expose affected sources and make loudness matching mandatory.

### 14. Dolby - System for Automated Multitrack Mixing

**Family:** [WO2021259725A1](https://patentscope.wipo.int/search/en/detail.jsf?docId=WO2021259725) / US20230352058A1 / [US12456493B2](https://patents.google.com/patent/US12456493B2/en) / EP4169020A1  
**Priority:** 2020-06-22  
**Core current-US claim concept:** Use a controller network and a transformation network with processing and gain parameters, train them separately, and train the controller using the pretrained transformation network.

The PCT specification is broader than the current issued US claim. It describes learned proxies for conventional channel processing such as gain, pan, EQ, compression, and reverb; controller access to whole-mix context; human or machine parameters; weight sharing; routing, bus, and master processing; and TCN, FiLM, PReLU, or Wave-U-Net implementations. A stereo loss can be invariant to left-right exchange.

The PCT international search report identified Harman WO2014183879 and Scott Jeffrey's Automatic Multi-Track Mixing Using Linear Dynamical Systems as X references against portions of the claim set and also cited SignalTrain. Those search classifications are not legal conclusions.

No controlled evidence was found for preference, genre breadth, alternative valid mixes, uncertainty, long-form behavior, or preservation. The current claim's separate-training requirement is materially narrower than a casual summary of two neural networks. TrackSmith should preserve exact DSP and use future models only for offline, bounded candidate generation or ranking. Before exploring a learned effect proxy/controller training pattern, obtain claim-specific specialist review.

### 15. Sony - Techniques for Assisting Audio Mixing of Audio Tracks

**Family:** [WO2025195953A1](https://patentscope.wipo.int/search/en/detail.jsf?docId=WO2025195953)  
**Priority:** 2024-03-18  
**Core claimed concept:** Determine perceptual information loss when a selected track is removed; related claims cover a method and AI mute inference.

The accessible record describes full-versus-query mix comparisons, MP3-encoder or PEMO-Q-like measures, mute recommendations, UI restoration, and learning from project mute history. The family is recent and the record was retained link-only after HTTP 503, so interpretation confidence is moderate.

The idea is promising as a counterfactual preservation signal but unsafe as an automatic deletion rule. Sparse entrances, quiet hooks, momentary texture, masked doubles, and genre-defining noise can be artistically essential while contributing little to a global perceptual metric. TrackSmith should show what is predicted to be lost, generate mute/attenuation/arrangement/spectral/no-change alternatives, and never destroy the source.

## Technical prior-art relationships

The reviewed families form several visible chains:

1. **Semantic control:** Fraunhofer semantic mixer (2011 priority) precedes LANDR semantic production (2013), which adds semantic production data and reference matching. Waves Color Slider (2020) narrows one semantic dimension to coordinated multitrack gain behavior.
2. **Rule-based automatic mixing:** LANDR autonomous multitrack (2012) precedes MixGenius automatic multitrack (2013), with concrete cross-adaptive EQ, target-spectrum, panning, and DRC embodiments. DTS (2013) applies metadata-selected rules to surround stem mixing.
3. **Recognition to processing:** iZotope recognition (2009) connects classification directly to application control; later iZotope source-aware enhancement and masking families refine diagnosis and processing relationships.
4. **Learning from target behavior:** Waves recommendation (2020) learns/retrieves engineer operations from examples; Dolby learned mixing (2020) trains a controller through an effect transformation model.
5. **Preservation and interaction:** Apple formulates source priority as a loudness-separation constraint; Dolby preserves mastering attributes across renderings; Sony estimates the counterfactual loss from removing a source.

Important cited connections include:

- Waves Color Slider cites De Man et al.'s automatic-mixing review, WO2015035492, and iZotope Mix Assistant-related material.
- Dolby presentation-independent mastering cites LANDR US9654869, WO2015035492, and Bob Katz mastering literature.
- Sony cites Fraunhofer semantic mixing, Dolby automated mixing, and Ajin et al. AES 2019.
- The Dolby learned-mixing international search report cites Harman's automatic-mixing disclosure and Scott Jeffrey's linear dynamical system work.
- The MixGenius international search report identifies earlier references against portions of its claim set.

This network reinforces the need to search papers and patents together. Some of the strongest technical prior art is non-patent literature incorporated into examination records.

## Engineering traceability

| Source-grounded finding | Reliability | TrackSmith module | Consequence | Disposition | Acceptance test | Must not infer |
|---|---|---|---|---|---|---|
| Semantic commands must be grounded in track and section information | Strong patent disclosure; no efficacy proof | AgentCore/ProductionIntentVocabulary; AgentCore/ProductionHypothesisEngine | Carry source, role, section, context, provenance and confidence into every interpretation | Production-ready principle | Same term across source/genre/section yields traceable alternatives or clarification | A parse recovers intended sound |
| A source classifier can drive algorithm control | Strong patent disclosure; no accuracy proof | AudioAnalysis/SourceAwareAnalysis | Propagate alternatives, calibration, unknown state and downstream dependencies | Production-ready principle | Clean, bleed, layered and OOD calibration plus downstream-harm tests | Source class equals role or action |
| Pairwise loudness loss can localize masking | Strong disclosed mechanism; artistic meaning unresolved | AudioAnalysis; AgentCore/ProductionHypothesisEngine | Store masking as an observation separate from remedy | Prototype-worthy | Detection calibration plus expert preference in mix context | Overlap is harmful |
| Target-spectrum and feature differences can define measurable objectives | Strong disclosed mechanism; preference weak | AudioAnalysis; PreviewRenderer | Keep feature objectives separate, scoped and provenance-tagged; retain Pareto candidates | Prototype-worthy | Loudness-matched cross-reference tests with no-change and mismatch cases | Metric improvement is artistic improvement |
| Heavy automatic DRC can be worse than no change | Limited but direct listening evidence | DSPCore; PreviewRenderer; evaluation tooling | Always include no-change and bounded-strength alternatives | Production-ready principle | Light, heavy, expert and no-change listening tests at matched loudness | More normalization is better |
| A semantic adjective can imply source rebalance, not master processing | Strong patent embodiment; generality untested | AgentCore/ProductionIntentVocabulary | Generate mechanism-distinct interpretations | Prototype-worthy | Compare source balance, master EQ and no-change across genres | One metric defines the adjective |
| Engineer before/after pairs omit diagnosis and rejected alternatives | Strong structural inference from disclosed training format | Research corpus; ProductionIntelligence/ProviderEvaluationHarness | Train/rank from decision structures rather than transformation pairs alone | Experimental | Hold out engineers, genres and source roles; score ranking independently from render | Human-processed target is unique truth |
| Learned controller/effect proxies can use whole-mix context | Strong disclosure; no quality evidence | ProductionIntelligence; PlanSchema; DSPCore | Models may propose bounded plans offline; deterministic DSP remains authoritative | Experimental/deferred | OOD abstention, exact replay, routing, track-count and preservation stress | Low learned loss means good mix |
| One edit can damage alternate render contexts | Strong mechanism; partial stereo transfer | PreviewRenderer; PreviewWorkflow | Validate candidates across stems, buses, mono, bypass and export contexts | Prototype-worthy | Multi-render invariants and round-trip tests | One improved render is globally safe |
| Minimum source separation compiles to an exact envelope | Strong patent disclosure; limited music transfer | AgentCore/ProductionHypothesisEngine; DSPCore | Use only when priority is explicit; expose envelope and tradeoff | Prototype-worthy | Pumping, silence, transient and preference tests | Overlap determines priority |
| Counterfactual removal can estimate contribution | Recent patent disclosure; no artistic validation | AudioAnalysis; PreviewRenderer | Use only as advisory evidence with reversible audition | Experimental | Low-energy but indispensable source cases and restoration | Low information loss means redundancy |

## What is crowded and where TrackSmith can differentiate

### Crowded concepts

The following concepts are represented by multiple early or concrete disclosures and should not be positioned as novel merely by naming them:

- natural-language or semantic mix control;
- source classification used to choose effects or presets;
- genre-conditioned automatic processing;
- automatic multitrack gain, EQ, compression, panning, and mastering chains;
- target-spectrum or reference-derived EQ;
- cross-adaptive de-masking;
- learned recommendations from human before/after examples;
- neural control of interpretable mixing parameters;
- single semantic macro controls;
- perceptual source-interaction constraints.

### Stronger differentiation territory

The reviewed families do not, in combination, establish the full TrackSmith behavior already present or planned:

- a signed AUv3 effect and native companion communicating through a signed App Group;
- source-aware evidence with stated units, validity, confidence, provenance, and failure modes;
- a production vocabulary that stores competing interpretations and contradictory evidence;
- typed separation of user intent, listening observation, production hypothesis, and executable plan;
- multiple candidates, clarification, abstention, and no-change as first-class outcomes;
- exact deterministic and editable DSP with bounded parameters;
- locked-node targeted revision and durable candidate lineage;
- validated preview, revision, commit, bypass, save/reload, and multi-instance isolation;
- explicit preservation objectives and multi-context acceptance tests;
- provider-neutral future reasoning that cannot write directly into the real-time audio thread;
- evaluation that separates objective guardrails, semantic correctness, rendering correctness, and human preference.

These are product and engineering differentiators, not assertions of patentability. Specialist prior-art and claim review remains appropriate before any patent filing or close implementation.

## Strongest contradictions and negative knowledge

1. **Automatic does not mean more processed.** The MixGenius DRC study makes no-change a credible winner and heavy automatic compression a recurring loser.
2. **Wider is not universally better.** Automatic panning that performed well on some genres failed where the aesthetic called for a narrower alternative-pop image.
3. **Reduced masking is not preferred mixing.** Masking metrics describe audibility interaction but do not encode artistic blend or hierarchy.
4. **Reference similarity does not recover process.** Spectral or feature targets cannot reconstruct phase, nonlinear history, automation, or intent.
5. **Source identity does not determine role.** Recognition-to-control patents omit the distinction between what produced the sound and what the sound is doing musically.
6. **One target does not represent the solution set.** Learned systems trained on one human mix can punish different but equally valid choices.
7. **Semantic labels do not ground themselves.** Bright, warm, punchy, intimate, and wide can point to different mechanisms across source, genre, and context.
8. **Patent breadth is not current claim breadth.** Dolby's current US claim requires a particular separate-training relationship that a PCT-level summary can miss.
9. **A patent title can overstate the issued claim.** Adobe's compressor-threshold title masks a narrower gate-like independent claim.
10. **Perceptual smallness is not artistic dispensability.** A source can have low global information contribution and still define a hook, transition, or aesthetic.

## Search watchlist and next patent batch

The following families or records were found during expansion but were not retained and deeply reviewed in this batch. They should be treated as a prioritized watchlist, not as characterized evidence:

- Queen Mary University of London WO2024134196, Audio Techniques - described in search results as real-time automatic mixing using psychoacoustic masking and search/optimization methods;
- ByteDance WO2025185244, recent audio-mixing disclosure;
- Yamaha EP4303865 and US12598441, recent audio-signal-processing family citing related automatic-mixing work;
- US20230113072, affective music composition with reinforcement-learning and mastering language;
- Avid US10466960, augmented-reality mixing workflow;
- Apple US8699727, visually assisted audio mixing;
- additional iZotope families including US10248381, US9225310, and US9350312;
- Adobe US8965756, speech-coloration processing, for carefully bounded transfer analysis;
- Waves US7391875, peak limiting;
- US11929098, template or AI-assisted automated mixing.

Before promotion to the core matrix, each watchlist item needs canonical-family consolidation, retained primary payload where available, independent-claim review, concrete embodiment review, citation-network tracing, and an explicit transfer assessment. Speech-only families should remain separate unless a music-production consequence is directly justified.

## Remaining search gaps

### High priority

- Complete assignee and inventor searches for BandLab, RoEx, Soundtheory, Universal Audio, Sonible corporate-name variants, Focusrite/FAST acquisition lineages, Yamaha/Steinberg lineages, and newly discovered startups.
- Trace forward citations from Fraunhofer US9532136, LANDR US9304988 and US9654869, MixGenius WO2015035492, iZotope US9031243 and US11469731, and Dolby WO2021259725.
- Retrieve and review national-stage claims and prosecution for the closest semantic, cross-adaptive, and learned-controller families where implementation becomes concrete.
- Search non-English titles and Asian patent-office records by inventor and classification, not only English keywords.
- Expand automatic limiting, transient shaping, de-essing, intelligent reverb, stereo imaging, restoration, vocal and drum enhancement, and learned audio-quality-assessment clusters.
- Search product-to-patent connections for current competitor features without inferring proprietary implementation from ownership alone.

### Medium priority

- Consolidate family citation graphs and examiner non-patent literature into the academic source index.
- Review abandoned, expired, discontinued-product, and pre-neural historical families for useful design patterns.
- Track post-2024 applications for conversational agents, audio-capable language models, revision-aware DAW agents, and user-personalized production systems.
- Add official-register status snapshots only when a concrete implementation decision makes the legal status operationally relevant.

### Saturation statement

Batch 1 is a defensible first landscape, not completion of the patent mission. Semantic mixing, rule-driven automatic mixing, source recognition, cross-adaptive EQ/masking, learned recommendation, and learned-controller clusters reached initial first-order saturation. Assignee breadth, recent applications, international status, prosecution, and specialized processor categories remain materially incomplete. The next action should be a citation-led and inventor-led expansion from the 15 core families rather than more unstructured keyword collection.

## Product decision summary

1. Preserve the current architecture. Nothing in the reviewed patent evidence justifies moving model reasoning into the real-time audio thread or replacing exact DSP with a learned renderer.
2. Treat language, source class, masking, reference distance, and counterfactual loss as evidence, not commands.
3. Make no-change, clarification, and multiple interpretations mandatory outcomes in the hypothesis engine.
4. Add preservation objectives at plan creation time and validate them across every affected render context.
5. Build listening evaluation around loudness-matched alternatives, genre and source context, longer sections, expert and target-user populations, and deliberate imperfection.
6. Learn from producer decision structures, not only before/after waveforms or preset histories.
7. Keep a family-level prior-art watch for implementation-adjacent semantic mapping, cross-adaptive EQ/masking, example-based recommendations, and learned controller/effect-proxy patterns.
8. Seek specialist patent review before implementing materially adjacent independent-claim combinations. Do not infer clearance from a design difference listed here.

The patent evidence therefore reinforces TrackSmith's central product thesis: excellent production assistance is not the act of choosing an effect automatically. It is the disciplined management of uncertain meaning, source and whole-mix evidence, competing interventions, preservation tradeoffs, exact execution, revision, and human preference.
