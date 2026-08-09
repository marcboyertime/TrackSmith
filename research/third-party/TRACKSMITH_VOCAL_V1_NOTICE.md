# TrackSmith Vocal v1 third-party notice

No third-party code, models, weights, datasets, audio, samples, images, configuration, server logic,
or other content were copied or integrated by the audit-derived Vocal v1 slices.

The associated manifest records the pinned repositories whose abstract lessons directly influenced
Vocal v1. Basic Pitch and RNNoise remain `STUDY_ONLY`; webMUSHRA, akoúste, pluginval, and JUCE remain
`LICENSE_BLOCKED`; chowdsp_utils and iPlug2 remain selectively portable references from which no
material was selected. Their names and links are diligence references and acknowledgments of abstract
research inspiration, not a declaration that their licenses cover TrackSmith-owned code and not an
approval to ship their materials. The complete 16-repository audit retains the decisions for AudioKit,
NeuralNote, noise-suppression-for-voice, DDSP, librosa, Essentia, madmom, and Demucs as well.

The new audio-to-MIDI contract, speech-cleanup study protocol, deterministic randomization,
validation rules, persistence format, blinded listening runner, fixed-capacity delay/reset behavior,
and hostile-host Vocal lifecycle tests are independently authored for TrackSmith. If future work
copies or links third-party material, this no-material declaration must
be replaced by a complete reviewed bill of materials, exact file and artifact hashes, license and
notice texts, model/data/content rights, patent or usage decisions, and shipping approval.

Authoritative details: `research/third-party/TRACKSMITH_VOCAL_V1_MANIFEST.json` and
`research/analysis/open_source_audio_audit/`.
