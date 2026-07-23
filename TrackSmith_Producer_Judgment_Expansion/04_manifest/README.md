# TrackSmith Producer Judgment Expansion Pack

Purpose: augment TrackSmith's already-strong DSP/standards corpus with sources about professional intent, co-creative mixing dialogue, semantic production language, taste, workflow, and evaluation.

## Local integration status

All nine manifest papers were downloaded and validated on 2026-07-14. Readable
copies are organized in the three numbered sibling directories. Immutable source
objects and append-only retrieval manifests are retained under
`research/papers/tracksmith-producer-judgment-archive/`; searchable text is included
by the normal `research/scripts/build-corpus-index.sh` pipeline.

- Exact retrieval ledger: `ingestion_results.json`
- Reproducible importer: `research/scripts/ingest-producer-judgment-manifest.py`
- Evidence synthesis: `research/analysis/TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md`

Re-running the importer revalidates the manifest and payload hashes, refuses to
overwrite a changed categorized copy, and records an exact duplicate audit event
without rewriting accepted object bytes.

## Deep-read first

1. The Role of Communication and Reference Songs in the Mixing Process: Insights from Professional Mix Engineers
   - Why: directly studies how professional mix engineers infer client intent, use reference songs/demo mixes, communicate, and decide when a mix is finished.
   - URL: https://arxiv.org/abs/2309.03404
   - PDF: https://arxiv.org/pdf/2309.03404.pdf

2. MixAssist: An Audio-Language Dataset for Co-Creative AI Assistance in Music Mixing
   - Why: unusually close to TrackSmith's target interaction: situated, multi-turn, audio-grounded dialogue between producers during real mixing sessions.
   - URL: https://arxiv.org/abs/2507.06329
   - PDF: https://arxiv.org/pdf/2507.06329.pdf

3. It's All About Speed: AI's Impact on Workflow in Music Production
   - Why: 2026 ethnographic evidence from professional producers/engineers about automation, speed, controllability, and creative agency.
   - URL: https://arxiv.org/abs/2605.29931
   - PDF: https://arxiv.org/pdf/2605.29931.pdf

4. Word Embeddings for Automatic Equalization in Audio Mixing
   - Why: directly explores semantic descriptors as controls for EQ; useful evidence for why words should map to context-dependent hypotheses rather than fixed presets.
   - URL: https://arxiv.org/abs/2202.08898
   - PDF: https://arxiv.org/pdf/2202.08898.pdf

5. Beyond Musical Descriptors: Extracting Preference-Bearing Intent in Music Queries
   - Why: separates descriptors from whether users want, reject, or merely reference a quality; highly relevant to TrackSmith's desired/preserved/prohibited intent representation.
   - URL: https://arxiv.org/abs/2602.12301
   - PDF: https://arxiv.org/pdf/2602.12301.pdf

6. MusicSem: A Semantically Rich Language--Audio Dataset of Natural Music Descriptions
   - Why: captures broad, organic human language about music rather than laboratory adjective lists; useful for vocabulary breadth and ambiguity modeling.
   - URL: https://arxiv.org/abs/2602.17769
   - PDF: https://arxiv.org/pdf/2602.17769.pdf

7. A Semantic Timbre Dataset for the Electric Guitar
   - Why: source-specific semantic timbre descriptors and magnitudes; useful as a model for building source-aware vocabulary rather than universal adjective mappings.
   - URL: https://arxiv.org/abs/2603.16682
   - PDF: https://arxiv.org/pdf/2603.16682.pdf

8. Exploring Trends in Audio Mixes and Masters: Insights from a Dataset Analysis
   - Why: empirical real-world patterns across mixes/masters and genres; useful for priors and diagnostics, not hard-coded targets.
   - URL: https://arxiv.org/abs/2412.03373
   - PDF: https://arxiv.org/pdf/2412.03373.pdf

9. An Empirical Approach to the Relationship Between Emotion and Music Production Quality
   - Why: forces TrackSmith to consider emotional communication and listener expertise rather than reducing production quality to technical cleanliness.
   - URL: https://arxiv.org/abs/1803.11154
   - PDF: https://arxiv.org/pdf/1803.11154.pdf

## Professional-practice corpora to mine carefully

These are valuable as expert-practice evidence and vocabulary sources, not universal engineering truth.

- Sound On Sound: Inside Track, Secrets of the Mix Engineers, Classic Tracks, Mix Rescue.
  Focus extraction on: initial diagnosis, artistic priority, what was deliberately left imperfect, processing sequence, rejected alternatives, reference use, and stopping criteria.
  Site: https://www.soundonsound.com/

- Tape Op interview archive.
  Focus extraction on: producer philosophy, unconventional choices, recording context, arrangement decisions, failure/revision stories, and artist-specific intent.
  Site: https://tapeop.com/interviews/

- Pensado's Place / Into The Lair.
  Focus extraction on: audible problem -> intervention -> rationale demonstrations and vocabulary used by working mixers.
  Site: https://www.pensadosplace.tv/

- Mix With The Masters.
  Focus extraction on complete deconstructions where legally accessible. Treat premium material as licensed viewing material, not redistributable corpus data.
  Site: https://mixwiththemasters.com/

- Puremix.
  Focus extraction on complete workflow demonstrations and before/after reasoning. Treat premium material as licensed viewing material, not redistributable corpus data.
  Site: https://www.puremix.com/

## Evaluation/data sources to investigate

- MixAssist dataset/repository associated with the paper above.
- MusicSem dataset/repository associated with the paper above.
- MusicRecoIntent corpus associated with Beyond Musical Descriptors.
- Song Describer Dataset: https://arxiv.org/abs/2311.10057
- Cambridge Music Technology multitrack resources: https://www.cambridge-mt.com/ms/mtk/
- MedleyDB: https://medleydb.weebly.com/

Use rights/provenance checks before ingesting any audio or transcripts.

## Recommended extraction schema

For each high-value source example, extract structured evidence like:

- source_id
- source_type: paper / interview / tutorial / manual / dataset
- expert_or_author
- musical_context
- source_class
- genre_or_aesthetic
- user_or_artist_goal
- initial_audio_problem
- perceptual_language_used
- evidence_or_listening_cue
- production_hypotheses_considered
- chosen_intervention
- parameters_or_signal_path_if_given
- rejected_alternatives
- preservation_constraint
- before_after_available
- outcome
- stopping_criterion
- confidence
- evidence_class
- exact_provenance
- rights_status

The goal is not to memorize recipes. It is to learn decision patterns conditioned on source, context, intent, and evidence.
