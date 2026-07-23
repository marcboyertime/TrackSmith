# TrackSmith producer-judgment research expansion

Initial archive pass: 2026-07-14  
Deep language-source review update: 2026-07-19
Scope: professional intent, co-creative dialogue, semantic production language,
workflow, production-quality priors, and evaluation boundaries

## Integration status and evidence boundary

All nine papers in
`TrackSmith_Producer_Judgment_Expansion/04_manifest/source_manifest.csv` were
retrieved through `ResearchIngestCLI`. Each payload passed HTTP-completion,
media-type, minimum-size, PDF-signature, EOF, PDFKit parsing, page-count, and
sampled extractable-text checks before content-addressed publication. The first
page of every categorized copy was also rendered and visually checked for title,
author, and readable body text.

The payloads are retained as `internalReference` and `local_use_only`. Public
availability on arXiv is not treated as redistribution, dataset-training, or
product-use permission. Associated datasets, model weights, session audio, and
repositories were not downloaded; each requires its own identity, dependency,
privacy, and license review.

Review labels below mean:

- **Full relevant read:** the actual payload's relevant body, equations/method,
  experiments/results, discussion, limitations, conclusion, and applicable
  appendices/prompts were reviewed. This does not mean cited works or external
  datasets were independently validated.
- **Initial supporting read:** the initial pass covered method, principal results,
  discussion, and limitations; it is not relabeled as a deep read here unless the
  2026-07-19 source-level record below says so.

| Priority | Source | Version / pages | SHA-256 | Review |
|---:|---|---|---|---|
| 1 | [Communication and Reference Songs](https://arxiv.org/abs/2309.03404) | v3 / 12 | `ff21c74540262cac4828eb9d1e00674466ab04f7e90e76c31e3f32f555d15f55` | Full relevant read |
| 2 | [MixAssist](https://arxiv.org/abs/2507.06329) | v1 / 39 | `7fc296957a8c513746952da8bb8be3f8b294866d94c8b5b824b35cf1e3338498` | Initial supporting read |
| 3 | [AI's Impact on Workflow](https://arxiv.org/abs/2605.29931) | v1 / 10 | `d3d7c6a60b2bd28dd03c7f5926d3b952804c7dcb5a8a33240c0ef224ee6fdd45` | Full relevant read |
| 4 | [Word Embeddings for Automatic EQ](https://arxiv.org/abs/2202.08898) | v2 / 10 | `76d2cf38a375a5bd0d8767cd5e33478341d31c4a0c1bf3b551b43ae34a4a7b8a` | Full source read |
| 5 | [Preference-Bearing Intent](https://arxiv.org/abs/2602.12301) | v1 / 7 | `f101bea39906f4731d657966a975b54531e0089a2bd84f5c96138db8c9eed652` | Full source read |
| 6 | [MusicSem](https://arxiv.org/abs/2602.17769) | v1 / 51 | `7961b2d2faf59b93f4ae37650bc1ce7781b74e238b1c733b965203d7dfe829d7` | Full relevant source read, including appendices/prompts |
| 7 | [Semantic Timbre Dataset for Electric Guitar](https://arxiv.org/abs/2603.16682) | v1 / 5 | `4cbd805767a2934a9d50e9e59bd83a602fa8ab172fa4ae60c9c070ba3e5752e0` | Full source read |
| 8 | [Trends in Audio Mixes and Masters](https://arxiv.org/abs/2412.03373) | v1 / 11 | `71af81e91f2ee32613f38c37744b62929949b09d32cc6a93f89ebf876c427f3d` | Full relevant read |
| 9 | [Emotion and Music Production Quality](https://arxiv.org/abs/1803.11154) | v1 / 12 | `e1c9773e1f42944281a61a5331dfb047eb6f27d4cb7051f5597a49f4916bfb42` | Initial supporting read |

Exact retrieval records, categorized paths, byte counts, and handling metadata
are in
`TrackSmith_Producer_Judgment_Expansion/04_manifest/ingestion_results.json`.

## Professional intent is negotiated, scoped, and revised

The communication study combines five professional interviews with a questionnaire
of 22 additional engineers. In that sample, clients conveyed direction through
conversation, semantic terms, rough mixes, and reference songs. Rough mixes often
carried preservation constraints such as keeping balance or the treatment of a
particular element. References could specify the whole mix, one instrument, an
emotion, general dynamics, spectral balance, or a small interaction between sounds.
Engineers commonly used more than one reference and often asked the client to
confirm what a reference meant.

The product consequence is that a reference is not a target vector. TrackSmith must
record the reference's intended scope and the attributes to borrow, preserve, and
avoid. It should ask for clarification when a reference could mean overall feel,
one source, arrangement, processing, or literal similarity. Cross-genre references
are legitimate when the scope is a particular element or emotion. The safe promise
is movement toward agreed traits, never exact replication.

Completion is also multi-part rather than metric-only: the engineer's judgment,
the client's acceptance, absence of distracting defects, relation to the agreed
direction, balance, and translation across playback contexts all matter. TrackSmith
therefore needs iterative preview and revision, not a one-shot autonomous verdict.

## Co-creative assistance must be explanatory and genuinely audio-grounded

MixAssist contains 431 selected audio-grounded instructional turns derived from
seven sessions involving 12 producers. Its strongest contribution is the task
shape: recent audio, prior-session context, multi-turn dialogue, an amateur's latest
request, and an expert response. Topic distribution is dominated by drums and the
overall mix, so it is not broad proof of every source or genre.

Fine-tuned model responses were preferred in 40% of 100 comparisons versus 33% for
the human response, with 12% judged both good and 15% both bad. The small comparison
set, generated summaries, manually filtered expert turns, and limited producer/session
diversity prevent a general superiority claim. More importantly, the ten-user live
study found fluent conversation but weak audio analysis and limited creative depth.

TrackSmith should use this as a design and evaluation blueprint:

- ground every recommendation in typed, source-aware measurements or explicitly
  mark it as a listening hypothesis;
- explain why an action is proposed and keep its editable parameters visible;
- retain dialogue context without silently turning a prior suggestion into a lock;
- use the model as teacher, collaborator, and option generator, not as an opaque
  authority over the deterministic DSP graph;
- evaluate audio grounding separately from conversational fluency and helpfulness.

## Semantic language needs roles, context, and source conditioning

The automatic-EQ study used 918 English examples covering 388 unique descriptors,
three audio sources, and 40 EQ bands, and held test words out of training. Its
frozen 300-dimensional embeddings feed dense layers to a bounded -4 to +4 dB
output. Tok2Vec improves MAE from .836 without embeddings to .760. The paper's
separate Perceptual Centroid Metric reports human 2.9, GloVe 9.3, Tok2Vec 10.5,
and no embedding 35.4, but the authors explicitly call that metric imperfect.
There is no listening test of the generated EQ. Some descriptors map plausibly;
others fail or disagree, and the authors explicitly identify source dependence
such as vocals versus drums.

This supports semantic generalization as a hypothesis generator, not a fixed
word-to-EQ dictionary. `warm`, `bright`, `punchy`, or `smooth` must still be resolved
against source, role, current evidence, arrangement, and preservation constraints.
The paper did not perform the listening study needed to claim that its predicted EQ
was perceptually correct.

The preference-bearing-intent study adds a second missing dimension. Its 2,291
queries contain 3,935 annotations whose descriptors have positive, negative, or
referential roles. Descriptor-span agreement is 77.1%, while role agreement on
commonly extracted descriptors is Cohen's kappa .927. Those figures do not measure
the same task. The strongest reported model reaches .69 exact and .76 partial F1;
its evaluated negative class has only 31 examples, and 231 true referential cases
are predicted positive. For TrackSmith, "like Reference A, but not its brightness"
must not collapse into two positive descriptors. Desired, prohibited, preserved,
and referential evidence remain separate typed fields.

MusicSem shows that natural music language extends beyond acoustic descriptors. Its
five categories are descriptive, atmospheric, situational, contextual, and
metadata-based. The dataset contains 32,493 language-audio pairs for 11,842 songs
and 4,430 artists from five English-language subreddits, plus a 480-entry human-
validated test set. GPT-4o performs extraction/summarization and Claude 3.7 provides
a binary hallucination check. Its 50-pair counterfactual sensitivity test measures
representation or retrieval change—not production correctness. Retrieval remains
difficult (reported CLaMP3 Recall@10 26.84%); captions hallucinate; FAD rankings are
embedding/reference dependent; and CLAP scores weakly capture contextual meaning.
These categories are useful for coverage and clarification tests, but not every
category is an executable instruction. TrackSmith can learn the breadth of natural
music language without treating it as authoritative acoustic labels.

The electric-guitar study provides a useful source-specific counterexample to a
universal vocabulary. Its 275,310 monophonic notes and 19 descriptors were produced
from 72 pedals and two software suites; the VAE uses only 1,771 E4-D6 examples and
Griffin-Lim reconstruction. A 20-listener panel gives several weak descriptor MOS
results (*Tight* 2.91, *Stutter* 2.74, *Wah* 2.95), while selected interpolation
rankings reach Kendall's tau .879. The classifier is trained within the same
constructed descriptor universe. This supports coherence within a controlled
domain, not transfer to vocals, drums, bass, polyphonic guitar, or full mixes. The
dataset is a model for source-aware evaluation, not a global semantic control map.

## Workflow evidence favors speed with controllable appropriation

The workflow paper is an ethnographic study of five professionals, so its findings
are design evidence rather than population estimates. Participants consistently
valued tools that removed slow technical work, yet the acceptable trade between
speed, transparency, and control depended on task and user. Opaque processing could
be tolerated when results were fast and reliable, but it became a liability when
the result needed correction. Professionals also repurposed tools beyond their
nominal function and emphasized taste as the value they contribute.

TrackSmith should therefore optimize time to an audible, reversible preview while
preserving an inspectable path to correction. Session organization, diagnosis,
comparison, and bounded starting points are good automation targets. Final taste,
creative direction, and approval remain with the user.

## Quality distributions are priors, not targets

The MixCheck analysis covers 218,109 user-submitted mixes and masters, but mix/master
status and genre are self-reported. Several labels use heuristic thresholds or
empirical genre averages, and the authors explicitly describe their measures as
informed estimates rather than absolutes. The dataset is useful for identifying
frequent QA topics such as loudness, clipping, dynamics, stereo/phase, mono
compatibility, and broad tonal balance. It does not justify a universal target curve,
compression amount, width, or streaming loudness target.

TrackSmith may use these distributions to prioritize checks or decide what to show,
but any action must still use standards-correct measurements, source-aware evidence,
the user's goal, and listening verification. Correlations in this dataset do not
establish that mastering caused an observed difference.

The emotion study used 20 university participants, split evenly between listeners
with and without critical-listening experience, and ten songs with high- and
low-quality mixes. Self-reported perceived emotion provided the clearest support for
an expertise-dependent effect; physiological, facial, and movement results were
noisy or inconclusive for the direct high-versus-low comparison. Genre preference,
lyrics/language, limited song diversity, sensor reliability, and sample size constrain
the result.

This paper supports stratifying evaluation by listener expertise and measuring
emotional/creative outcomes separately from defect detection. It does not support
an automated emotion score, a claim that lay listeners do not care about production,
or optimization toward facial or physiological proxies.

## Accepted TrackSmith knowledge and implementation hooks

1. Add an explicit reference interpretation before reference-conditioned planning:
   target scope, desired traits, preserved traits, prohibited traits, and whether
   the reference is sonic, emotional, structural, or merely contextual.
2. Keep referential descriptors distinct from desired change. A named artist or
   track is evidence to discuss, not permission to clone a style or infer a full
   processing target.
3. Evaluate conversational assistance on separate axes: intent-role extraction,
   source grounding, technical correctness, explanation, creative usefulness,
   preservation, and calibration/clarification behavior.
4. The semantic regression corpus now includes catalog cases for negation, soft
   similarity, mixed roles, reference scope, rough-mix locks, cross-genre element
   references, and evolving feedback. They remain catalog-only where the current
   engine lacks a safe executable representation rather than fabricating support.
5. Treat dataset-derived vocabulary as candidate language coverage. Do not add a
   descriptor-to-parameter rule unless source-conditioned listening evidence and
   deterministic safety limits justify it.
6. Rank workflow improvements by time saved without loss of agency: fast diagnosis,
   reversible previews, A/B comparison, scoped revision, and visible bounded plans.
7. Keep expertise and musical context as recorded factors in listening tests rather
   than averaging them away.
8. Keep open-ended phrases outside the executable term enum. The generated
   14-entry `AbstractMusicianLanguageKnowledgeCatalog` retrieves only exact reviewed
   phrases/aliases and supplies source-specific alternate senses, contradictions,
   unsupported causes, preservation risks, and clarification policy. It is labeled
   professional-practice heuristic and cannot emit DSP, host actions, measurements,
   or constraint changes.

## Claims these sources do not justify

- a universal mapping from a production adjective to EQ, compression, or another
  processor;
- exact imitation of a reference song, artist, mix engineer, or genre;
- general music-mixing competence from language fluency or generic audio-model
  performance;
- a universal definition of a good mix or master from population distributions;
- an automated measure of emotional success;
- redistribution, training, or product-use rights for any associated dataset merely
  because its paper or landing page is public.
