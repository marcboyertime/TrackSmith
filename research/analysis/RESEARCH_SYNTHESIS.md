# Research synthesis for Logic Audio Assistant

Date: 2026-07-12  
Corpus: 61 unique PDFs plus 23 unique HTML snapshots and supplied text sources  
Status: systematic corpus review complete; implementation consequences are active

## Executive conclusions

The strongest overall conclusion is that this product should combine three systems with sharply different responsibilities:

1. A deterministic, inspectable DSP graph performs production edits.
2. Signal analysis and learned representations describe the source, detect violations, and rank candidates.
3. A language model resolves intent and structured references, but cannot directly write unbounded parameters or audio.

This is not merely a safety preference. It is the architecture best supported by the corpus. Rule-only systems are too rigid for artistic work; end-to-end generative editors often lack parameter visibility and reliable non-target preservation; differentiable or inference-time parameter search can be effective precisely because the final sound is still produced by a conventional effect graph.

The research also explains why the first preview implementation sounded too similar:

- It matched whole-file RMS rather than gated perceptual loudness.
- It used the same absolute compressor threshold for every recording.
- Its three strengths were linearly and narrowly spaced.
- Its spectral analysis described only the first window.
- It did not measure whether a rendered option was audibly distinct.

Those are now explicit engineering defects, not matters of taste.

## Evidence hierarchy

Evidence is weighted in this order:

1. Normative standards: ITU-R BS.1770-5, EBU R 128, ITU-R BS.1534-3.
2. Peer-reviewed DSP and production research with equations and listening tests.
3. Peer-reviewed or well-specified model work with reproducible evaluations.
4. Preprints, including several 2025-2026 sources, treated as promising but not settled evidence.
5. Project pages, repositories, model cards, and blogs, used for implementation context only.

No objective metric in this corpus establishes subjective production quality by itself. Metrics are appropriate for calibration, constraint checking, regression detection, and candidate triage. Listening remains the final judge.

## 1. Dynamics processing

### What the compressor literature establishes

Giannoulis, Massberg, and Reiss decompose a digital compressor into gain computer, level detector, gain smoothing, and makeup gain. Their tutorial shows that nominally similar compressors can behave differently because detector topology and attack/release implementation interact. A standard analog-style peak detector can miss the intended peak and distort its time constants when release is not much longer than attack. A branching detector produces the intended attack/release behavior more predictably. Feed-forward designs are more stable and predictable than feedback designs for a transparent digital implementation.

The static curve should be continuous through a soft knee. The one-pole coefficient for a time constant defined at `1 - 1/e` is `exp(-1 / (tau * sampleRate))`; labels such as “10 ms attack” are otherwise ambiguous across products. Extremely short ballistics can create modulation distortion, pumping, breathing, and low-frequency distortion. Extremely long release can cause dropouts after transients.

The parameter-automation paper demonstrates two useful program descriptors:

- Short-term crest factor separates brief peaks from sustained energy.
- Positive spectral flux detects changing/transient spectra and can be more sensitive than crest factor.

It derives attack and release from `2 * maximumTime / crestFactor^2`, with practical maximums of 80 ms attack and 1 s release, then subtracts attack from release for the detector topology studied. This is evidence for program-dependent timing, not a universal preset law. Whole-file crest factor is too coarse to reproduce the paper’s short-term automation exactly.

Makeup gain based only on mean gain reduction failed for percussive material. Loudness-based makeup agreed better with listeners, while still slightly misestimating drums because broadcast programme loudness is not a complete perceptual model for isolated transients.

The intelligent multitrack compressor adds a crucial qualification: compression decisions depend on both dynamic and spectral content. Percussivity, low-frequency weighting, spectral centroid, and spectral spread helped explain human threshold and ratio choices. Its listening test favored the automatic system overall, but preference was song-dependent; one competing automatic method performed poorly after equalizing isolated tracks by loudness. That is a warning against blindly normalizing stems before cross-adaptive processing.

### Product decisions

- Use a feed-forward branching peak detector in the transparent compressor.
- Define and test the time-constant convention.
- Base initial threshold on measured source level, not a fixed dBFS value.
- Use source type plus short-term crest/flux in the future program-dependent controller.
- Preserve a user-facing strength/meta control; do not hide adaptation.
- Treat loudness makeup as a separate, inspectable stage.
- Measure gain-reduction distribution, not only its maximum.
- Do not infer that lower crest factor is always better.

### Current implementation versus research target

The current compressor uses a branching peak envelope and a continuous soft knee. This pass changed recipe thresholds to be relative to measured RMS and changed timing based on measured crest factor with musical clamps. It is still a first approximation because the feature is whole-interval rather than the paper’s time-varying 200 ms crest factor. The next compressor revision should calculate a bounded side-chain feature envelope outside or alongside the DSP graph, expose gain-reduction statistics, and add tempo-aware release only when tempo confidence is adequate.

## 2. Loudness, true peak, and unbiased previewing

ITU-R BS.1770-5 specifies:

- A two-stage K-weighting filter.
- Channel-weighted mean-square energy.
- 400 ms blocks with 75% overlap.
- An absolute gate at -70 LKFS.
- A second gate 10 dB below the absolute-gated result.
- A four-phase 48-tap FIR guideline for estimating inter-sample true peaks at 48 kHz.

EBU R 128 adopts programme loudness and recommends -23 LUFS for broadcast normalization and a maximum production level of -1 dBTP. Those are broadcast delivery recommendations, not universal mastering targets for every genre or platform. For this application, the algorithm is valuable for level-matched comparison; the -23 LUFS target is not imposed on user material.

The standards also clarify why sample peak is inadequate: the reconstructed waveform can peak between samples. A preview can pass a sample-peak ceiling and still exceed it after conversion or encoding.

### Product decisions

- Compare viable previews using gated K-weighted loudness when the capture is long enough.
- Fall back to RMS only for captures too short to form a 400 ms block, and label the fallback.
- Protect true peak after applying level-match gain.
- Keep delivery loudness, creative loudness, and A/B matching as three separate concepts.
- Never call sample peak “true peak.”

### Implemented in this pass

- `BS1770Meter` implements K-weighting, two-stage gating, and the Annex 2 polyphase FIR.
- Analysis reports integrated LUFS, maximum momentary loudness, and dBTP with units and limitations.
- Preview rendering prefers BS.1770 matching and records the method used.
- Tests verify the standard’s -3.01 LKFS result for a full-scale 997 Hz sine, relative-gate behavior, inter-sample peak detection, and long-preview matching.

## 3. Spectrum, timbre, and the danger of pseudo-scientific labels

Essentia supports the value of modular descriptors, explicit aggregation, and separate low-level versus semantic features. Its broad catalog is not evidence that every descriptor predicts production quality. The production-quality study found correlations involving crest factor, width, rolloff, selected band energies, and signal-amplitude distribution, but also found strong influence from emotion and listener context. The bands selected as “harsh” or “low-frequency” were empirically tuned to one commercial-music dataset. They must not become universal truths.

Automatic EQ research provides stronger guidance for parameter selection:

- Optimize the response produced by an EQ, rather than minimizing distance between non-unique parameter vectors.
- Use band-specific parameter bounds and stable parameterizations.
- Training solely on random effect settings creates a domain mismatch.
- Fine-tuning with real-world source/target spectra improved spectral error.
- Source/instrument context materially changes appropriate targets.
- Loudness-normalized blind A/B evaluation is necessary; in the reported study the automatic treatment was preferred nearly 2:1, with 14% no preference.

The best-practices paper warns that apparently obvious mixing rules can be false. Mixing is dominated by masking and context, not isolated “ideal” curves. It found evidence for long-term target contours and quantifiable loudness balance, but also frequency dependence in compression choices and a need for hindsight over the whole piece.

### Product decisions

- Report “energy in 2-5 kHz,” not “harshness detected,” until source-aware temporal evidence supports the interpretation.
- Aggregate spectra over the selected interval, not only its first frame.
- Retain time variation for later phrase/section analysis.
- Use log-frequency response error when fitting parametric EQ.
- Penalize excessive gain, narrow Q, redundant bands, and out-of-range parameters.
- Compare a track to source-aware distributions or a user reference, not a universal average curve.
- Distinguish correction of a resonance from wholesale tonal matching.

### Implemented in this pass

The analyzer now uses a deterministic radix-2 FFT over Hann-windowed frames distributed through the capture. It reports centroid, 85% rolloff, flatness, spectral slope, positive flux, transient density, and descriptive low/mid/high, boxiness, harshness, and sibilance band ratios. Every perceptual-sounding band metric explicitly states that it is descriptive rather than a diagnosis.

## 4. Pitch and vocal analysis

YIN is an appropriate baseline for monophonic fundamental-frequency estimation. Its important components are the difference function, cumulative-mean normalized difference, absolute threshold, and parabolic interpolation. The normalized minimum doubles as an aperiodicity/confidence cue. Search range, window length, voicing, noise, and octave errors must all be exposed in tests and limitations.

YIN does not justify pitch correction by default. It estimates periodicity; it does not determine musical intention, scale, expressive inflection, or whether correction would improve a performance. Polyphonic buses and full mixes require a different model.

### Product decisions

- Implement YIN only for explicitly monophonic vocal/bass sources in the first source-aware analyzer.
- Return F0, confidence/aperiodicity, search range, and voiced coverage.
- Never auto-enable pitch correction from low confidence or pitch variation alone.
- Keep pitch correction outside the stable MVP DSP until a reversible, quality-tested engine exists.

## 5. Room sound and dereverberation

SRMR and its variants estimate reverberation or room effects without a clean reference by comparing modulation-energy regions. The paper shows useful correlations for speech and variants designed to reduce dependence on speaker and reverberation time. It does not prove reliable dereverberation severity for arbitrary singing, dense music, or effected vocals.

### Product decisions

- Treat SRMR as an optional vocal/speech room indicator with calibrated confidence.
- Do not map one SRMR value directly to a dereverberation amount.
- Combine it with direct-to-reverberant cues, decay behavior, source classification, and listening.
- State when room sound is inseparable from the performance or deliberately creative.

## 6. Reference matching and effect-parameter search

Differentiable style-transfer work shows a productive middle ground between rules and opaque waveform generation: predict conventional effect parameters and optimize an audio-domain loss. This produces editable settings and constrains the output to the capabilities of the effect chain. It also shows that parameter-domain error is often a poor objective because many settings can sound similar.

ST-ITO generalizes the idea to arbitrary and non-differentiable effects. It learns an effect-sensitive representation and uses CMA-ES at inference time. The reported configuration used a population of 64 and up to 25 steps for roughly 100 parameters. It could optimize unseen effect chains and performed competitively in a 23-participant engineering-oriented study. Its own limitations are directly relevant: it requires a suitable graph, renders many candidates, takes about a minute rather than about a second, and struggled with difficult cases such as guitar-tone matching.

General-purpose CLAP and audio embeddings were less sensitive to production effects than the specialized AFx-Rep representation. This is a decisive warning: semantic similarity is not production-style similarity.

### Product decisions

- Add offline constrained search as a preview optimizer, never in the real-time thread.
- Search only within a graph selected by rules/planner and accepted by validation.
- Start with low-dimensional coordinate/CMA-style search over bounded perceptually meaningful macros.
- Cache deterministic renders and support cancellation.
- Use separate objectives for tonal response, dynamics, width, ambience, and penalties.
- Research an effect-sensitive representation before using a generic CLAP score for style.
- Present “toward these measured traits,” never “identical to the reference.”

## 7. Generative audio editing

AUDIT, non-rigid prompt editing, token inpainting, SemanticAudio, Audio ControlNet, and newer flow-based editors demonstrate rapid progress in instruction-driven insertion, deletion, replacement, inpainting, and semantic attribute change. The 2026 foundation-model survey identifies the central evaluation problem: edit success and non-target preservation are different axes. CLAP-like similarity can measure semantic alignment while missing collateral changes; quality predictors can detect artifacts while missing whether the requested edit happened.

The survey’s recommended evaluation dimensions map directly to this product:

- Instruction following.
- Target modification.
- Preservation of non-target content.
- Acoustic naturalness.
- Temporal/perceptual coherence.

The same survey calls for explicit target regions, preservation regions, iterative refinement, self-verification, and human calibration. These reinforce immutable snapshots and structured edit references already in the architecture.

### Product decisions

- Keep generative editing out of the stable MVP signal path.
- Introduce it later as an offline, opt-in module that creates a new audio asset and snapshot.
- Require explicit region/scope, model/provider disclosure, and source preservation.
- Evaluate target success and preservation separately.
- Never let a generative result silently replace the source file or deterministic graph.

## 8. Audio-language models and conversational control

AIR-Bench, SALMONN, Qwen2-Audio/Qwen2.5-Omni, audio-language surveys, and music-perception benchmarks demonstrate increasing general audio comprehension. They also expose domain gaps, hallucination, weak calibration, prompt sensitivity, and differences between expert and non-expert judgments. Strong benchmark performance on captioning or question answering does not establish competence at mix decisions.

The user study of AI-assisted music production is more actionable for product design than raw model scores. Users valued ideation but asked for tempo/key/beat control, partial revision, preservation of prior results, fine-grained editing, and DAW integration. The desired behavior is “remember this result and change only part of it,” which is exactly a structured snapshot/lock operation—not chat-history improvisation.

### Product decisions

- Use language models for intent parsing and explanation, behind typed tools.
- Resolve “that,” “version two,” and “only the compressor” against explicit object IDs.
- Make deterministic offline recipes fully usable without any model.
- Do not send audio to a language model merely because it accepts audio.
- Evaluate planners on contradictions, locks, scope, stale snapshots, injection, and provider failure.

## 9. Evaluation methodology

ITU-R BS.1534-3 MUSHRA requires a known reference, hidden reference, anchors, randomized presentation, listener training, documented reproduction conditions, and statistically defensible analysis. It recommends raw-data visualization, medians and interquartile ranges for non-normal data, confidence reporting, and attention to statistical power. A failed significance test is not evidence of equivalence when the study is underpowered.

Production evaluation differs from codec impairment testing because there may be no single correct reference and creative preference matters. Still, MUSHRA contributes useful discipline. The automatic-mixing studies show that experienced engineers can distinguish criteria such as production value, clarity, and excitement, and that a model may improve one while leaving another unchanged. “Better” must be decomposed.

FAD research shows sample-size, embedding, reference-set, genre, and quality bias. VGGish FAD did not reliably correlate with all human judgments; better choices and infinite-sample extrapolation helped. Speech metrics such as PESQ, POLQA, and ViSQOL are task- and degradation-dependent and cannot be assumed valid for music production edits. General CLAP measures prompt/audio semantics, not transparent preservation or mastering quality.

### Product decisions

Automated preview evaluation must have independent gates:

1. Safety: finite samples, graph validity, peak ceiling, channel/latency integrity.
2. Constraint adherence: locked nodes, loudness request, mono compatibility, prohibited spectral/dynamic changes.
3. Intended delta: did the requested attribute measurably move?
4. Preservation: did unrelated bands, channels, timing, and source identity remain stable?
5. Distinctness: is this option materially different from its parent and sibling options?
6. Subjective validation: formal listening tests for release claims.

No weighted sum should hide a hard failure in one axis.

### Listening-test plan

- Begin with blinded, loudness-matched original/conservative/balanced/strong comparisons.
- Include a hidden duplicate to estimate listener consistency.
- For impairment-oriented DSP tests, include a clean reference and meaningful anchors.
- Randomize labels and order; permit looping over identical excerpts.
- Train participants on the attributes being judged.
- Record expertise and analyze experts separately.
- Report raw distributions, medians/IQRs, effect sizes, confidence intervals, and corrected pairwise tests.
- Pre-register primary outcomes for acceptance scenarios.

## 10. Research-informed engineering backlog

### P0: stable MVP

- Finish BS.1770 regression vectors at all supported sample rates.
- Add short-term loudness, loudness range, and gain-reduction statistics.
- Implement time-varying 200 ms crest factor and normalized spectral flux.
- Add deterministic preview distinctness checks between siblings.
- Add source-aware vocal/drum/full-mix analysis confidence.
- Implement log-frequency EQ fitting with gain/Q/complexity penalties.
- Add section-aware measurements so chorus/verse requests have explicit time scopes.

### P1: higher-quality intelligent processing

- YIN monophonic F0/confidence.
- Onset/transient strength and tempo-conditioned release.
- Frequency-dependent stereo width and mono-risk analysis.
- SRMR vocal-room indicator with calibration fixtures.
- Dynamic EQ and de-esser driven by event-specific side-chain features.
- Offline bounded parameter optimization with deterministic cache and cancellation.

### P2: learned systems

- Effect-sensitive representation trained on the exact production graph.
- Learned candidate ranking calibrated against project listening tests.
- Reference matching via trait-specific objectives.
- Optional generative editing in a separate immutable-asset workflow.

## 11. Claims the corpus does not justify

- A universal ideal tonal balance for every song.
- That a lower crest factor, higher loudness, wider stereo image, or flatter spectrum is inherently better.
- That CLAP, FAD, PESQ, POLQA, ViSQOL, or any single embedding predicts production quality across this product.
- That an artist or record can be reproduced exactly from a name or short reference.
- That a room-damaged, clipped, noisy, or source-overlapped recording can always be reconstructed.
- That a model trained on generated or randomly effected audio generalizes to real sessions without domain testing.
- That indistinguishable listening-test results prove equivalence without adequate power.
- That an audio-capable language model can safely replace typed analysis and deterministic execution.

## Key supplied sources

- Giannoulis, Massberg, Reiss, *Digital Dynamic Range Compressor Design—A Tutorial and Analysis*.
- Giannoulis, Massberg, Reiss, *Parameter Automation in a Dynamic Range Compressor*.
- Ma et al., *Intelligent Multitrack Dynamic Range Compression*.
- Pestana and Reiss, *Intelligent Audio Production Strategies Informed by Best Practices*.
- Steinmetz, Bryan, Reiss, *Style Transfer of Audio Effects with Differentiable Signal Processing*.
- Steinmetz et al., *ST-ITO: Controlling Audio Effects for Style Transfer with Inference-Time Optimization*.
- Martínez-Ramírez et al., *Automatic Music Mixing with Deep Learning and Out-of-Domain Data*.
- Mockenhaupt et al., *Automatic Equalization for Individual Instrument Tracks Using Convolutional Neural Networks*.
- Bogdanov et al., *Essentia: An Audio Analysis Library for Music Information Retrieval*.
- de Cheveigné and Kawahara, *YIN, a Fundamental Frequency Estimator for Speech and Music*.
- Wilson and Fazenda, *Perception & Evaluation of Audio Quality in Music Production*.
- Falk et al., *SRMR Variants for Improved Blind Room Acoustics Characterization*.
- ITU-R BS.1770-5, EBU R 128, and ITU-R BS.1534-3.
- Pan et al., *Audio Editing in the Era of Foundation Models: A Survey*.
- Gui et al., *Adapting Fréchet Audio Distance for Generative Music Evaluation*.

