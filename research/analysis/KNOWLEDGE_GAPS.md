# TrackSmith knowledge gaps and prioritized research program

Status: living gap ledger  
Baseline date: 2026-07-16  
Companion coverage record: `RESEARCH_COVERAGE.md`

## Purpose

This file converts the local-corpus audit into an ordered research program. A gap
is closed only when the relevant primary evidence has been retrieved or its
inaccessibility recorded, reviewed to the required depth, synthesized against
conflicting evidence, traced to a TrackSmith consequence, and assigned a testable
status. A folder, citation, abstract, marketing claim, repository URL, or patent
search result does not close a gap by itself.

No category below is currently claimed web-saturated.

## Priority model

Priority considers user value, competitor weakness, evidence strength, fit with
the current architecture, technical feasibility, dependency order, evaluation
difficulty, and differentiation potential.

| Priority | Program | Why it comes now |
|---|---|---|
| P0 | Unified provenance and traceability | Every later conclusion needs one source identity, review-depth, evidence-class, rights, duplicate, and conclusion chain. |
| P1 | Patent/prior-art landscape | Completely absent and important before product concepts are treated as differentiators. |
| P1 | Competitors plus user pain | Completely underrepresented and required to distinguish real workflow value from marketing parity. |
| P1 | Producer Judgment Corpus | Central to behaving like an excellent producer rather than a preset system; current evidence is too small and abstract. |
| P2 | Academic/effect-specific deepening | Current strength is concentrated in EQ/compression/loudness; key processors and reasoning scopes remain weak. |
| P2 | Genre and aesthetic maps | Required to prevent generic-cleanup behavior and source/genre overgeneralization. |
| P2 | Open-source implementation review | Needed to turn research ideas into realistic architecture, licensing, performance, and test consequences. |
| P2 | Perceptual and human evaluation system | Objective direction checks exist, but artistic success and preference remain largely unvalidated. |
| P3 | Future audio-capable model watch and experiments | Valuable only behind the typed/provider-neutral boundary and after production-specific evaluation tasks exist. |

## P0 — Unified provenance, evidence, and traceability

### Gap

The local corpus has strong ingestion components but no unified source index or
bibliography. The 70 non-Logic unique PDFs, four Logic manuals, HTML/TXT sources,
official standards used from temporary captures, Apple web documentation, and
professional-practice material do not yet share one complete metadata model.

### Required work

- Build a source record for every intellectual work and every retained payload.
- Separate work-level deduplication from byte-level deduplication.
- Record authors/inventors, organization/assignee, publication/priority date,
  canonical and retrieval URLs, document version, local path, SHA-256, retrieval
  date, evidence class, rights, review depth, reliability, relevance, topics,
  family/duplicate/superseded relationships, and accessibility status.
- Link source to bounded conclusion, affected TrackSmith module, product
  requirement, candidate implementation, prohibited inference, and acceptance
  test.
- Normalize official standards, Apple developer pages, and professional-practice
  payloads that were deeply reviewed but are not immutable research objects.
- Reconcile the stale 38-template/228-case statement with the current
  70-template/420-case corpus.

### Exit criteria

- Every material claim in the deep synthesis resolves to an indexed source and
  exact retained representation or explicit link-only record.
- Archive acceptance and deep-review state are separate fields.
- Missing or mutable payloads cannot silently appear as full evidence.
- Automated validation detects missing files, hash drift, duplicate works,
  dangling conclusions, and invalid evidence-class transitions.

## P1 — Patent and prior-art landscape

### Gap

There are no patent-family records, claim summaries, inventor/assignee networks,
status checks, or patent citation maps.

### Search program

- Search current and historical terminology for automatic/intelligent mixing,
  mastering, EQ, compression, limiting, spectral balance, dynamic processing,
  reference matching, source-aware effects, perceptual optimization, restoration,
  vocal/drum enhancement, reverb, stereo imaging, learned quality, multitrack
  prediction, semantic/text control, conversational plug-in agents, DAW agents,
  and personalization.
- Search the named seed companies and all discovered predecessors, subsidiaries,
  acquired entities, inventors, and music-AI startups.
- Expand through CPC/IPC classes, backward/forward patent citations, cited
  non-patent literature, inventor histories, and family equivalents.
- Consolidate by earliest priority rather than country publication count.

### Deep-review questions

- What do the independent claims actually require?
- Which embodiments are concrete enough to inform engineering?
- What is broad concept language versus a specific signal flow, model, objective,
  dataset, UI, or host integration?
- Which design patterns overlap TrackSmith, and which established TrackSmith
  boundaries provide meaningful technical differentiation?
- What earlier patents or non-patent work materially narrow the disclosure?

### Exit criteria

- High-relevance families have priority, filing, status, assignee, inventor,
  independent/dependent claim, embodiment, citation, TrackSmith relationship, and
  confidence records.
- Family copies are not counted as separate inventions.
- The record avoids legal conclusions and flags where later specialist review may
  be useful.
- Query, assignee, inventor, class, and citation-network logs meet the saturation
  rule in `RESEARCH_COVERAGE.md`.

## P1 — Commercial landscape and user pain

### Gap

Logic Mastering Assistant is the only competitor with meaningful current official
behavior represented locally. iZotope material is educational rather than a
current Ozone/Neutron/Nectar product evaluation. There is no systematic user-pain
corpus.

### Required product coverage

- BandLab AI Mastering; Logic Mastering Assistant; iZotope Ozone, Neutron, Nectar,
  and relevant RX; Sonible smart family; LANDR; RoEx Automix; Masterchannel;
  Auphonic; Focusrite FAST; Gullfoss; TEOTE; relevant Waves tools; Adobe Enhance
  Speech/Podcast; SpectraLayers; and additional current or discontinued systems
  discovered during search.
- For each version/date: inputs, analysis, controls, source/genre awareness,
  reference handling, alternatives, editability, A/B, revision, persistence,
  local/cloud behavior, privacy, export, latency, pricing, failure behavior, and
  observable versus claimed capability.

### User-evidence program

- Search Reddit, Gearspace, KVR, VI-Control where relevant, professional forums,
  substantive YouTube demonstrations/comments, reviews, stores/marketplaces, and
  issue trackers.
- Code recurring distrust of automatic mastering, generic sound, excessive
  brightness/loudness, dynamic loss, poor classification, genre mismatch, weak
  explanation, insufficient control, inability to revise one element, lost prior
  choices, reference failure, latency, and cloud/privacy objections.
- Keep repeated cross-source patterns, plausible weak patterns, isolated reports,
  likely user error, and documented limitations separate.

### Exit criteria

- Each major competitor has official evidence, independent observable evidence,
  and recurring user feedback where available.
- Marketing claims are never promoted to implementation facts.
- Reproducible black-box protocols exist for products lawfully available for
  hands-on testing.
- Competitor weakness and user pain connect to a TrackSmith opportunity without
  recommending proprietary imitation.

## P1 — Producer Judgment Corpus

### Gap

The current corpus has one professional communication study, MixAssist, one
workflow ethnography, one vendor mixing guide, and one vocal-EQ article. It lacks
a substantial machine-readable set of real production decisions, rejected
alternatives, interactions, preservation choices, and stopping criteria.

### Source program

- Sound On Sound Inside Track, Secrets of the Mix Engineers, Classic Tracks, and
  Mix Rescue.
- Tape Op interviews; Pensado's Place/Into The Lair; AES interviews and talks;
  DAFx/ISMIR/intelligent-production workshops.
- Lawfully accessible Mix With The Masters and Puremix cases, manufacturer
  masterclasses with substantive demonstrations, and detailed public producer
  breakdowns.
- Search by engineer, producer, artist, song, genre, source, intervention,
  rejected alternative, reference, revision, and before/after availability.

### Required record

Each case must encode:

```text
problem
-> listening diagnosis
-> contextual interpretation
-> alternatives considered
-> intervention
-> audible result
-> preservation tradeoff
-> stopping criterion
```

Also record musical role, arrangement interaction, processing order, parameter
ranges when disclosed, confidence, exact provenance, evidence class, and whether
before/after audio was actually heard. A case generates hypotheses, not a universal
preset.

### Exit criteria

- Cases cover all TrackSmith source classes, multiple workflow stages, and the
  requested genre/aesthetic range.
- Rejected actions, intentional imperfections, arrangement-versus-mix decisions,
  and client/artist negotiation are materially represented.
- Recurring patterns and genuine professional disagreements are both preserved.
- Every product rule derived from practice remains contextual and listening-led.

## P2 — Academic and effect-specific research

### Gap clusters

1. **Processing breadth:** limiting, dynamic EQ, multiband dynamics, transient
   shaping, de-essing, reverb, delay, saturation, stereo imaging, restoration,
   vocal enhancement, and drum enhancement.
2. **Context:** whole-mix and multitrack reasoning, arrangement awareness,
   temporal structure, long-form coherence, automation, and interaction effects.
3. **Optimization:** reference matching, differentiable/non-differentiable
   parameter search, multi-objective preservation, candidate ranking, uncertainty,
   and personalization.
4. **Data validity:** professionally mixed targets, multiple valid mixes, dataset
   leakage, source/genre imbalance, short clips, synthetic effects, isolated stems,
   speech-to-music transfer, and proxy-metric dependence.
5. **Human-AI collaboration:** longitudinal professional use, correction cost,
   trust calibration, mixed initiative, education versus automation, and evolving
   intent across revisions.

### Exit criteria

- Each essential processing family has primary algorithm, real-time/offline
  implementation, perceptual evaluation, failure, and production-practice evidence.
- Claims specify source type, clip/session duration, dataset, listener population,
  metrics, and ecological limits.
- Conflicting results are reconciled by source, genre, scope, objective, listener,
  and time period rather than averaged into a false universal rule.
- Candidate engineering consequences are labeled production-ready,
  prototype-worthy, experimental, deferred, or rejected.

## P2 — Genre and aesthetic maps

### Gap

Genre appears only as incidental qualification. There is no structured knowledge
for pop, rock and its requested subgenres, metal, punk, folk, singer-songwriter,
jazz, classical, soul, funk, R&B, hip-hop, trap, EDM, house, techno, ambient,
shoegaze, hyperpop, lo-fi, cinematic, or acoustic music.

### Required knowledge

- Production goal and historical/era context.
- Desirable and acceptable imperfections.
- Transient and dynamic expectations.
- Spectral, vocal-placement, ambience, stereo, and low-end tendencies.
- Common reference language and source roles.
- Choices that generic metrics may label cleaner but that would harm the intended
  aesthetic.
- Internal disagreements, subgenre boundaries, and exceptions.

### Exit criteria

- Every requested genre has multiple independent professional cases and, where
  available, empirical evidence.
- No genre profile is encoded as an immutable target curve, loudness value,
  dynamics range, or preset.
- The semantic layer can express when the same adjective implies different
  hypotheses across source role, genre, era, and artist intent.

## P2 — Open-source implementation review

### Gap

Current repository evidence is mostly web captures and recommendations. There are
no durable exact-commit reviews covering architecture, algorithms, licenses,
dependencies, tests, benchmarks, and production hazards.

### Required families

- Audio Units and JUCE host/plug-in examples.
- Real-time-safe EQ, dynamic EQ, compression, limiting, transient shaping,
  de-essing, saturation, reverb, delay, stereo, loudness, and true peak.
- MIR, source separation, embeddings, audio-language models, differentiable DSP,
  automatic mixing, parameter optimization, and listening-test infrastructure.

### Review protocol

- Record canonical origin and exact commit.
- Require a clean checkout and preserve license/notices.
- Identify the specific files, algorithms, tests, benchmarks, model weights,
  datasets, and dependency obligations reviewed.
- Separate reusable concepts, research reference code, and production-ready code.
- Do not copy or link incompatible code into TrackSmith.

### Exit criteria

- Strong candidates have reproducible commit-level records and concrete
  TrackSmith implementation/hazard notes.
- Real-time candidates have allocation, lock, denormal, vectorization, latency,
  state, channel-layout, and sample-rate considerations.
- Model/checkpoint/data licenses are reviewed separately from repository code.

## P2 — Perceptual and human evaluation

### Gap

TrackSmith has standards-correct measurement work, semantic structure tests, and
generated-audio direction checks, but no broad expert listening program proving
production preference, adjective success, preservation, or long-form coherence.

### Required evaluation layers

- DSP conformance and numerical regression.
- Objective direction and preservation checks.
- Attribute-specific blinded comparisons.
- Preference ranking among multiple valid edits.
- MUSHRA-style tests where anchors/reference are meaningful.
- Expert versus non-expert, genre familiarity, monitoring, playback system, and
  listening-level stratification.
- Long-form and multitrack tasks, revision cost, explanation usefulness, trust,
  and calibration.

### Exit criteria

- Every product claim declares which layer supports it.
- Loudness is controlled in comparisons and never substituted for preference.
- Model-based judges are calibrated against human listening on the exact task and
  receive an explicit record of what audio/text/context they saw.
- Target success, non-target preservation, naturalness, coherence, explanation,
  and user preference remain separate outcomes.

## P3 — Future audio-capable models

### Gap

The corpus offers good architectural caution and broad model-family orientation,
but limited current, production-specific proof. Generic captioning, speech,
generation, or benchmark scores do not establish mix diagnosis or edit judgment.

### Required work

- Track official technical reports, model cards, APIs, context/input limits,
  output schemas, latency, cost, privacy, retention, regional availability, and
  model/version changes.
- Build TrackSmith-specific black-box tasks for source diagnosis, ambiguity,
  reference scope, competing hypotheses, preservation, revision, explanation,
  uncertainty, and rejection of unsupported operations.
- Compare audio-capable reasoning with text plus deterministic TrackSmith analysis,
  embeddings/rankers, and non-audio language models.
- Record contamination, evaluator bias, order bias, hallucination, privacy, and
  provider drift.

### Exit criteria

- No provider earns direct DSP or render authority.
- A model is adopted only for a bounded task where it materially beats simpler
  baselines under production-specific evaluation.
- Provider-neutral typed contracts, deterministic validation, local fallbacks,
  provenance, cost ceilings, and explicit audio-upload consent remain intact.

## Cross-cutting unresolved questions

1. Which acoustic properties can TrackSmith measure reliably on isolated captures,
   and which require multitrack, arrangement, project-state, or listener context?
2. How should adjective meaning factor source, role, genre, era, reference scope,
   requested strength, preservation, and prior accepted revisions?
3. When should ambiguity yield clarification, multiple interpretations, a bounded
   preview set, or rejection?
4. How can TrackSmith recognize what should not change, including artistically
   useful distortion, dynamics, timing, noise, asymmetry, or imbalance?
5. Which deterministic processors are essential before learned ranking or offline
   optimization can add real value?
6. How should reference matching separate level, spectrum, dynamics, stereo,
   ambience, performance, arrangement, emotion, and literal identity?
7. What professional preference data can be collected without collapsing multiple
   valid mixes into one target?
8. Which user complaints reflect product limitations, expectation mismatch,
   loudness bias, genre mismatch, weak control, or user error?
9. Which commercially crowded ideas offer little differentiation, and which
   unsolved workflow problems fit the existing TrackSmith architecture unusually
   well?
10. What evidence would justify personalization, and how can it remain reversible,
    private, inspectable, and resistant to preference drift?

## Architecture and overclaim guardrails

All gap-closing work must preserve the established AUv3 effect, native companion,
signed App Group, source-aware analysis, provenance-tagged vocabulary, typed
intent/hypothesis, deterministic editable DSP, and preview/revision/commit/bypass/
persistence architecture.

The research may recommend an extension or experimental module, but it must not:

- infer undocumented Logic project or native-effect authority;
- put AI, networking, allocation, blocking work, or mutable provider state in the
  real-time audio thread;
- turn a patent into proof of efficacy or a legal conclusion;
- turn marketing into documented behavior;
- turn a tutorial, genre average, source-class spectrum, or practitioner quote
  into a universal preset;
- turn speech enhancement or semantic similarity into music-production quality;
- treat loudness, objective guardrails, or one model-based score as preference;
- claim full-text review, payload availability, or saturation without the
  corresponding record;
- redesign proven TrackSmith architecture merely because a paper or competitor
  uses a different system;
- directly modify core product behavior during this research milestone unless an
  ingestion/indexing/validation need or explicit approval requires it.

## Gap-closing record template

Every material closure should answer:

1. What exact evidence was inspected?
2. What does it directly show, and with what evidence class?
3. How reliable is it and under what conditions?
4. What does it not establish?
5. What conflicts with it, and why might the evidence differ?
6. What does it imply for TrackSmith's existing modules?
7. What implementation pattern is suggested?
8. What inference or product claim is prohibited?
9. How can the consequence be tested?
10. Is it production-ready, prototype-worthy, experimental, deferred, or rejected?

Until those questions are answered and traced to retained sources, a gap remains
open even when relevant material has been downloaded.

