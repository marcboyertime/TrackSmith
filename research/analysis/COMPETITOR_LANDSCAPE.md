# TrackSmith competitor landscape

Status: batch 1 source-grounded landscape; living document  
Evidence cutoff: 2026-07-16  
Scope: intelligent mixing, mastering, vocal processing, restoration, and adjacent automatic post-production products

## Decision summary

The mature competitor baseline is already beyond a one-click preset. Ozone,
Neutron, Nectar, RX, and the sonible smart series analyze audio and then expose
editable deterministic controls, multiple states, bypass, or detailed modules.
TrackSmith therefore cannot differentiate merely by calling analysis “AI,” by
mapping adjectives to effects, or by showing the generated plug-in chain.

The defensible opportunity is the reasoning and collaboration layer around that
chain:

1. expose the observation, source scope, production hypothesis, uncertainty,
   preservation constraint, and expected audible consequence separately;
2. return “no material issue” when the evidence does not justify a change;
3. generate simultaneous bounded interpretations instead of making the user
   destroy and relearn one opaque recommendation;
4. keep every proposal revision-addressable and compare it at controlled
   loudness, with delta or removed-signal audition where appropriate;
5. distinguish original stems, estimated stems, references, sidechains, and
   whole-mix evidence rather than treating all context as interchangeable; and
6. keep deterministic effect execution local and editable while treating any
   future generative asset or cloud-model call as a separate, disclosed action.

These are **TrackSmith product hypotheses** grounded in documented competitor
workflow gaps. The manuals establish behavior and controls; they do not establish
comparative sound quality, user preference, market success, or undisclosed model
architecture.

## Evidence discipline

The corresponding row-level facts are in `COMPETITOR_MATRIX.csv`; review records
with payload hashes, exact sections, limitations, and test consequences are in
`../metadata/deep-review-batch-1-competitors.jsonl`. Source IDs resolve through
`../metadata/SOURCE_INDEX.jsonl`.

Evidence labels in this document mean:

- **official documented behavior**: a retained official manual or support page;
- **official behavior, payload unavailable**: the official page was inspected,
  but bot protection, a JavaScript shell, or a post-discontinuation redirect
  prevented preservation of usable bytes;
- **historical official behavior**: the product or documented version is no
  longer current;
- **TrackSmith hypothesis**: a proposed design or experiment, not a proven fact.

No batch-1 product has yet received a controlled hands-on listening comparison.
User praise and complaints remain `not yet systematically reviewed` unless a row
explicitly identifies a bounded source. Marketing adjectives such as
“professional,” “transparent,” or “intelligent” are not treated as quality
evidence.

## What the landscape establishes

### 1. Analysis plus editable DSP is the competitive floor

Ozone 12's Master Assistant creates a visible module chain; Neutron 5 maps broad
assistant controls into detailed EQ, compression, excitation, width, and other
modules; Nectar 4 exposes its Vocal Assistant results as a reorderable module
chain; the sonible processors preserve conventional controls around learned
regions or semantic macro controls. RX 12 exposes repair chains and allows the
user to open modules, compare candidates, and audition removed signal.

Consequently, TrackSmith's established typed-intent -> production-hypothesis ->
deterministic-plan architecture is aligned with the strongest documented
workflows. The differentiator should be *why this intervention is justified,
what it must preserve, and how it can be revised*, not a hidden replacement for
the editable graph.

### 2. Source and analysis scope are causal inputs, not UI decoration

Across the reviewed systems, results depend on the material and window supplied:

- Ozone requires at least eight seconds and recommends the loudest section.
- Neutron's Visual Mixer asks for a full-song listen, raw stems, unity faders,
  centered pans, one instance per track, and a chosen focus source.
- Nectar recommends looping vocal material shorter than twenty seconds.
- smart:EQ learns for at least about six seconds and requires a source profile;
  a custom reference profile is conditioned by the nearest factory profile.
- RX changes behavior by content mode, selection, module, and offline versus
  real-time quality; some algorithms impose explicit selection-duration limits.

These are official workflow constraints, not proof that the algorithms are
optimal. They nonetheless imply that TrackSmith must preserve `analysis_scope`,
`source_role`, `window_representativeness`, and `context_preconditions` in the
hypothesis provenance. Re-analysis after a materially changed mix must create a
new evidence version rather than silently mutating the old one.

### 3. Reference audio does not identify a unique effect chain

Ozone compares tonal balance, vocal balance, width, dynamics, and loudness with
genre or custom targets. Nectar uses reference-derived targets for vocal
character EQ. smart:EQ conditions a custom reference on a source profile. LANDR
documents reference-track and revision workflows, but the retained evidence is
metadata-only in this batch.

The common pattern supports reference-derived *feature targets* or ranked
candidate directions. It does not show that a mixed reference reveals its
original EQ curve, compressor settings, stems, monitoring context, or artistic
intent. TrackSmith should record which dimensions a reference is allowed to
influence, state incompatible scope explicitly, and reject “copy this master” as
an identifiable deterministic inverse problem.

### 4. Trust is built by controlled audition, not confidence language

Strong documented trust patterns include:

- Ozone: gain match, global bypass, reference audition, codec preview, and
  A/B/C/D snapshots;
- Neutron: gain-matched bypass in the Visual Mixer flow;
- smart:limit: constant-gain comparison and delta audition;
- Nectar: level-matched bypass and audible detection/sidechain checks;
- RX: bypass, Compare candidates, and “Listen” to the removed signal;
- Logic Mastering Assistant: loudness compensation and bypass.

These are more actionable than an unexplained numerical “confidence.” TrackSmith
should require loudness-controlled preview for quality judgments, preserve raw
and gain-matched modes, and offer operation-specific evidence audition: delta for
limiting/compression, removed signal for repair or de-essing, sidechain influence
for masking, and isolated affected bands only when that audition is meaningful.

### 5. Cross-track awareness has several non-equivalent meanings

Neutron's Visual Mixer communicates with Neutron or Relay instances and writes
static gains after a grouped analysis. Its masking meter is diagnostic. smart:EQ
can perform group-aware spectral balancing across a hierarchy. smart:reverb can
share learned information among instances to reduce overlapping tails.
smart:comp's group mode, by contrast, is documented as remote/batch control;
instances still process independently.

The phrase “group aware” therefore cannot be a single TrackSmith capability
flag. The plan and UI must distinguish:

1. shared metering;
2. remote parameter control;
3. pairwise sidechain interaction;
4. group optimization with an explicit objective;
5. sequential recommendations conditioned on prior accepted plans; and
6. actual multitrack rendering or learned prediction.

Each mode needs different latency, evidence, reversibility, and acceptance tests.

### 6. A valid result can be “do nothing”

Nectar's Vocal Unmask can report that no significant masking was detected and
produce no curve. RX and the sonible manuals repeatedly expose conditions in
which the analysis must be rerun, the signal mode must change, or the input is
not appropriate. This is important counterevidence to engagement-driven systems
that always produce a treatment.

TrackSmith should make abstention a first-class plan result containing the tested
hypothesis, evidence window, detection threshold, uncertainty, and a useful next
observation. It must not invent an audible defect because a user asked for an
effect name.

### 7. One-result learning creates a revision dead end

Several assistants let the user edit the result but require a restart or relearn
to revisit the assistant's earlier grouped decision. Neutron cannot return to the
same Visual Mixer group-result screen after it closes. Moving smart:comp's
Compression Matrix can overwrite manually edited parameter values. Logic asks
the user to reanalyze after mix changes.

TrackSmith already has a stronger foundation: immutable proposals, preview,
revision, commit, bypass, and project persistence. The product should preserve
the parent proposal and evidence version, explain which detailed edits a macro
revision will supersede, and allow parallel candidates to coexist. A semantic
revision must not silently erase a manual change.

### 8. Separation and generation require a different contract from effects

RX's Music Rebalance and Stem Split are useful when original stems are missing,
but their sensitivity controls explicitly trade preservation against leakage and
their estimated stems remain processed assets. Nectar's Backer generates a new
vocal character and documents artifact-sensitive register choices. SpectraLayers
13 positions layer extraction and spectral repair as editable content operations,
but the retained batch-1 source is only an inspected feature page.

TrackSmith should treat estimated stems and generated parts as new, provenance-
tagged assets with source audio, model/version, parameters, rights state, and
audition history. They must never masquerade as the original stem or as a
deterministic effect node. The existing execution architecture need not be
redesigned to accommodate this boundary.

### 9. Speech automation is useful negative-transfer evidence

Auphonic documents segmentation, speaker/music classification, adaptive level,
noise reduction, gating, crosstalk removal, and ducking for spoken-word
production. Adobe Podcast documents cloud speech enhancement whose result
depends on the speech/noise/input conditions. Those products demonstrate useful
workflow patterns—segment awareness, explicit input limits, and fast preview—but
not music-production quality or producer judgment.

TrackSmith may reuse the *contract patterns* while requiring music-specific
evidence for the acoustic intervention. Speech intelligibility is not a proxy for
preserving vocal character, musical noise, groove, ambience, or mix depth.

## Product profiles and TrackSmith consequences

### Ozone 12 — editable automatic mastering

**Evidence:** complete retained 156-page official manual; relevant workflow,
assistant, target, general-control, reference, performance, and audition sections
were reviewed and representative pages rendered.

Master Assistant analyzes at least eight seconds—preferably the loudest section—
and targets genre or custom-reference averages for tonal balance, vocal balance,
width, dynamics, and loudness. It builds a visible, reorderable/bypassable module
chain. The user can constrain assistant modules and adjust intensity and output.
Global bypass, gain match, mono, reference, codec preview, undo history, and four
snapshots support evaluation and revision.

**Boundary:** the manual documents workflow, not target construction, inference
accuracy, comparative preference, or robustness outside the recommended section.

**TrackSmith consequence:** visible editable DSP is table stakes. Preserve
feature-level reference scope, representativeness of the analyzed window, and
candidate lineage. Test whether a proposal remains directionally stable across
loud/quiet sections and whether its benefit survives gain-matched listening.

### Neutron 5 — source-aware mixing and inter-plug-in context

**Evidence:** complete retained 143-page official manual; Assistant, target
library, Visual Mixer, masking, IPC, and general-control sections were reviewed
and representative pages rendered.

Assistant controls map into detailed deterministic modules. Custom targets can
derive from reference material, and the UI marks a target “dirty” after detailed
edits depart from the learned recommendation. Visual Mixer performs a static
level analysis across compatible instances, then sends gains through inter-
plug-in communication. It requires a carefully prepared session and a meaningful
focus source.

**Boundary:** the masking meter and classification cannot prove the correct
artistic hierarchy. The group-level result is not a durable branch once closed.

**TrackSmith consequence:** encode session preconditions, distinguish diagnostics
from recommendations, and retain group hypotheses as durable, revisable objects.
Never equate “spectral overlap” with “masking that should be removed.”

### Nectar 4 — broad intent mapped into an editable vocal chain

**Evidence:** retained complete print-manual HTML; Vocal Assistant, target,
Intent, Auto-Level, Voices, Backer, Vocal Unmask, module-chain, audition, and
preset sections were reviewed.

The assistant inspects RMS, vocal characteristics, register, EQ/dynamics,
sibilance, compression, and ambience, then maps high-level controls into detailed
modules. Auto-Level can follow an arrangement sidechain. Vocal Unmask compares
the vocal and competing source, can abstain, and exposes the resulting curve.
Voices and Backer create new vocal content with separate artifact and musical-
context concerns.

**Boundary:** documented feature behavior is not evidence that source
classification, reference targets, or generated voices are preferred. Generative
Backer behavior is categorically different from reversible DSP.

**TrackSmith consequence:** semantic macros should disclose their low-level
mapping and invalidation behavior. Arrangement-following level should be a
bounded, auditable modulation plan. Generative output must be a new asset.

### RX 12 — selection-scoped repair with evidence audition

**Evidence:** retained 292-page official manual; document persistence, Repair
Assistant, comparison/audition, Music Rebalance, Stem Split, Spectral Repair,
Voice De-noise, and processing-limit sections were reviewed and pages rendered.

RX documents non-destructive document history, selection-scoped/offline repair,
several candidate comparison, removed-signal audition, and advanced access to a
generated repair chain. Music Rebalance is explicitly useful when original stems
are unavailable; separation sensitivity trades subtle preservation against
leakage. Some high-quality modes have duration limits, and more bands are not
always better.

**Boundary:** restoration success is defect- and selection-dependent. Estimated
stems are not originals; dialogue denoising evidence does not establish musical
vocal quality.

**TrackSmith consequence:** add selection/time scope, rejected alternatives,
delta audition, processing-budget warnings, and candidate comparison to repair
hypotheses. Represent separation confidence and leakage/artifact checks.

### Logic Pro Mastering Assistant — host-native minimum-friction benchmark

**Evidence:** retained Apple support article, cross-checked against the existing
Logic documentation. It is authoritative for documented workflow, not internal
algorithms.

The assistant sits on the stereo output, analyzes the project or locator section,
applies corrective EQ/loudness/width, and offers four characters plus bounded
manual controls. It supports loudness compensation, bypass, reanalysis, and
bounce. Apple warns that added loudness can reduce dynamics.

**TrackSmith consequence:** coexist with the host-native feature and avoid
duplicating its one-shot convenience story. Differentiate through mix/stem
context, explicit evidence, preservation, alternatives, conversational revision,
and persistent provenance. Never imply authority over undocumented Logic state.

### sonible smart series — source-adapted effect spaces

**smart:EQ 4** learns a source profile and can operate in cross-track groups with
front/middle/back hierarchy. A custom reference remains source-conditioned. It
offers manual filters, dynamic behavior, phase modes, and states. Group impact
can be negative to preserve heterogeneity.

**smart:comp 3** produces a learned compression region rather than one immutable
setting. The Dynamic–Dense and Snappy–Punchy axes expose an interpretable space
over familiar compressor controls. Moving the macro region can overwrite manual
detail. Group mode is remote control, not shared optimization.

**smart:reverb 2** learns source information but leaves style and parameters to
the user. Its semantic matrix blends room/hall/plate/spring; group sharing is
intended to reduce overlap among tails. “Clarity” is implemented by internal
sidechain ducking, illustrating why semantic labels must disclose mechanism.

**smart:limit** sets limiter behavior from genre/reference analysis while
providing constant-gain and delta audition, publishing targets, distortion
monitoring, and a dynamics/loudness grid. Its manual advises long observation for
valid integrated measurement and does not make its quality grid an artistic
verdict. The retained manual is dated 2023; current product/version status needs
a separate refresh.

**TrackSmith consequence:** expose bounded semantic spaces when more than one
interpretation is plausible, preserve manual edits when macros move, type group
semantics, and make loudness-compensated/delta comparison standard. A semantic
name must never hide the actual processing mechanism.

### LANDR, BandLab, and RoEx — cloud-outcome competitors with bounded evidence

The official LANDR help index documents mastering revisions and reference
workflows; BandLab documents eight styles plus intensity and three-band EQ and
states that mastering cannot repair a bad mix; RoEx positions a cloud multitrack
mix/master workflow with processed-stem export and API access. The usable pages
could not be retained in this batch, so these are bounded official-page
observations rather than complete workflow reviews.

**TrackSmith consequence:** outcome speed, alternative versions, and easy export
matter, but TrackSmith should not imitate opacity. The next research batch must
capture full current documentation, independent controlled tests, privacy/data-
retention terms, pricing tiers, and recurring user experience before comparative
quality or trust conclusions are made.

### SpectraLayers 13 — adjacent layer/spectral-editing workflow

The official new-features page was inspected but its JavaScript shell was
rejected as a payload. It documents current AI-assisted unmixing, repair,
reconstruction, layer-preserving edits, ARA use, and new selection/loudness tools.
This is an adjacent content-editing workflow, not simply an effect configurator.

**TrackSmith consequence:** explicit selection and layer provenance are useful
for future editing actions. Full manual ingestion, hands-on testing, and
systematic user evidence are still required; no model architecture or quality
claim is inferred.

### Focusrite FAST — historical lifecycle and compact intelligent controls

Focusrite's official support page states that the FAST plug-ins are discontinued,
cannot be purchased, will receive no further updates, and are no longer
supported. The historical FAST Reveal and Balancer manuals were inspectable via
indexed official text but direct retrieval now redirects; no local PDF is
claimed. Reveal documented a foreground/background masking workflow with
audition and detailed controls. Balancer documented source-profile learning with
intensity/flavor macros.

**TrackSmith consequence:** do not list FAST as a current competitor. Its compact
workflow remains useful historical evidence, while discontinuation alone does
not establish why the product failed or what users disliked.

### Auphonic and Adobe Podcast — adjacent speech automation

Auphonic's retained official algorithm documentation describes segmentation,
adaptive leveling, filtering, denoise, gating, ducking, and multitrack speech
workflows. Adobe's retained FAQ documents cloud Enhance Speech behavior and
input-dependent results.

**TrackSmith consequence:** borrow explicit scope/failure contracts and segment-
aware workflow ideas only. Require independent music evidence before applying a
speech restoration strategy to expressive singing or a full mix.

## Traceable engineering consequences

| Evidence-backed finding | Affected TrackSmith boundary | Candidate implementation | Acceptance test | Disposition |
|---|---|---|---|---|
| Results depend on source, section, role, and reference profile | Audio analysis; production hypotheses | Persist typed scope, capture interval, source role, profile, and evidence version | Reanalyzing a different section creates a distinct hypothesis and never silently reuses stale measurements | Production-ready |
| Editable DSP is a mature competitor baseline | Intent; planner; DSP graph | Keep semantic macro and compiled nodes bidirectionally traceable | Every macro preview identifies affected nodes and every detailed edit marks which macro assumptions became stale | Production-ready |
| Loudness bias can invalidate A/B judgments | Preview workflow; evaluation | Raw and level-matched preview; short-term alignment with stated limits | A gain-only candidate becomes indistinguishable in the level-matched path within meter tolerance | Production-ready |
| Removed-signal or delta audition reveals collateral damage | Preview; repair/dynamics modules | Operation-specific residual audition modes | Residual equals input minus time-aligned output within numerical tolerance and is labelled by scope | Prototype-worthy |
| “Group-aware” products implement different mechanisms | IPC; hypothesis schema | Enumerated context mode rather than Boolean group-awareness | Schema rejects a group claim without shared-meter, remote-control, sidechain, joint-objective, sequential-context, or multitrack-render mode | Production-ready |
| Reference features do not identify the original chain | Intent; reference analysis | Scope references to allowed features and candidate ranking | Unsupported “recover settings” requests trigger clarification or bounded alternatives, never fabricated exact parameters | Production-ready |
| No detected issue can be a correct result | Reasoning; conversational UX | Abstention proposal with tested hypothesis and next observation | Clean and intentionally overlapping fixtures can produce an auditable no-change result | Production-ready |
| Macro movement can overwrite detailed edits in competing tools | Revision engine | Parent/child proposal lineage and explicit conflict resolution | A semantic revision cannot overwrite a committed manual node edit without a surfaced conflict | Production-ready |
| Separation trades leakage against preservation | Future editing; asset provenance | Estimated-stem asset type with model/version/sensitivity and leakage checks | Exported asset cannot be labelled original stem; preview includes mixture reconstruction and leakage probes | Prototype-worthy |
| Generative vocal output is not deterministic DSP | Provider-neutral future-model layer | Separate generated-asset transaction from processing plan | Generated media never enters the deterministic graph without an explicit import/commit action | Deferred |
| Speech workflows do not prove music aesthetics | Evidence policy; evaluation | Domain and material-scope gates on transferable conclusions | A speech-only source cannot raise a music-production requirement above experimental without music evidence | Production-ready research control |

## Gaps before a mature competitive verdict

1. Controlled hands-on black-box tests are still absent. A reproducible protocol
   must use the same stems, references, gain-matched exports, blind ordering,
   null/delta checks, latency/CPU observations, and preserved raw outputs.
2. Current pricing, trial limitations, privacy, upload retention, and local/cloud
   execution need official per-product records rather than memory or marketing.
3. Independent evidence and recurring user patterns are not yet systematic. The
   next user-feedback batch must separate repeated complaints, likely setup error,
   isolated reports, and documented product limits.
4. LANDR, BandLab, RoEx, SpectraLayers, and historical FAST manuals need stronger
   retained payloads or alternate lawful copies.
5. Major competitors still missing from deep review include Gullfoss, TEOTE,
   Waves adaptive/intelligent processors, Soundtheory products, Masterchannel,
   Steinberg's full current manual, and current native DAW assistants outside
   Logic where relevant.
6. No category is saturated. Current records are a high-value first batch, not a
   complete market census.

## Prohibited overclaims

- A documented assistant feature is not proof of better sound.
- A target curve or dynamics grid is not a universal aesthetic norm.
- Spectral overlap is not proof of harmful masking.
- A learned source class is not the artistic role of that source.
- Reference similarity is not reconstruction of the original processing chain.
- An estimated stem is not the original multitrack source.
- Speech intelligibility improvement is not evidence of musical-vocal quality.
- Product discontinuation is not evidence of technical failure or user rejection.
- “Local,” “cloud,” and privacy properties must not be inferred when the reviewed
  source does not explicitly document them.
- This landscape is technical product research, not a patent, market-share, or
  legal conclusion.
