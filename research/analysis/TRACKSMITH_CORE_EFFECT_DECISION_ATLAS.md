# TrackSmith core-effect decision atlas

Version: 2026-07-18.4  
Current deep cards: all 20 first-queue processors spanning gain, equalization, dynamics,
cleanup, ambience, delay, saturation, limiting, stereo/phase, and pitch  
Empirical state: processor-specific campaign defined; direct transfer runs not yet completed

## Evidence boundary

This atlas is the operational layer between source material and production
hypotheses. It does not tell TrackSmith to insert a Logic plug-in, and it does not
turn an adjective into a preset. Each card separates:

- documented controls and signal behavior;
- peer-reviewed DSP or intelligent-production evidence;
- contextual professional-practice heuristics;
- measured TrackSmith evidence;
- source- and arrangement-dependent listening decisions.

The Apple Effects guide establishes exposed Logic behavior, not private transfer
functions. The compressor papers establish algorithms and bounded experiments,
not production settings. The automatic-EQ paper establishes that source identity
can improve an interpretable prediction task, not a canonical spectrum. The 58
professional cases establish contextual decisions for those records, not universal
frequency or time-constant rules.

## Gain

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload SHA-256
  `b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819`;
  Gain section on page 360 and related signal-path material reviewed in the
  complete manual read.
- TrackSmith professional-decision corpus: gain, balance, level, or automation
  language recurs in 46 of 58 curated cases. This is a broad text-recurrence
  signal, not a count of Gain plug-in insertions or global DAW telemetry.

### Strongly established

Logic Gain exposes level, independent left/right polarity inversion, stereo
balance, left/right swapping, and mono summing. Apple explicitly places Swap L/R
after Balance and disables Swap when Mono is active. Channel-format behavior is
different: stereo exposes all controls; mono and mono-to-stereo expose one polarity
control; mono disables Balance, Swap, and Mono. Multichannel Gain is a separate
surround processor.

Ideal gain is amplitude scaling. For a decibel change `d`, the linear amplitude
factor is `10^(d/20)`. It does not by itself change relative spectrum or envelope,
but its position can materially change every downstream level-dependent or
nonlinear processor. Polarity inversion is multiplication by `-1`; it is not a
fractional-delay or broadband phase-alignment tool. Apple correctly notes that an
isolated polarity-inverted signal sounds the same, while combination with another
signal can improve or damage the result through cancellation/reinforcement.

### What each decision dimension changes

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| Gain amount | Changes level and downstream headroom/operating point | Peak/nonfinite safety, loudness-matched comparison, noise floor, and downstream detector/drive response |
| Plug-in position | Changes the level entering or leaving later processors | Compression threshold crossings, saturation harmonics/aliasing, gate triggers, send level, and output headroom |
| Left/right polarity | Reverses one or both channel polarities | Multimicrophone combination, low-frequency sum, stereo image, correlation, and sample/time alignment; never call this automatic phase correction |
| Balance | Changes relative left/right level before Swap | Center image, source asymmetry, pan intent, peak per channel, and mono sum |
| Swap L/R | Exchanges channels after Balance | Whether channel identity or recording perspective must be preserved |
| Mono | Sums the stereo input to a dual-mono output | Cancellation, low-end loss/gain, overload, width loss, and whether mono audition—not permanent conversion—was requested |

### Strategy selection and stopping

Gain competes with region gain, clip gain, track automation, channel fader moves,
processor output controls, bus/send balance, and source editing. TrackSmith must
name which level relationship it is changing and why. Use pre-processing gain to
change operating point only deliberately; use post-processing gain for matched
comparison or headroom without pretending it is tonal processing. Stop when the
target relationship is achieved and downstream processors remain inside their
validated ranges. Reject any candidate that wins through level alone or creates a
stale threshold/side-chain assumption elsewhere in the graph.

### TrackSmith must not say

- “Gain staging has one correct target level.”
- “Polarity invert phase-aligns two microphones.”
- “Mono compatibility is proven because the stereo correlation is positive.”
- “A louder matched preset sounds better.”
- “The Gain plug-in and every Logic level control are interchangeable.”

## Channel EQ

### Source record

- Apple, *Logic Pro Effects for Mac*, 390-page payload SHA-256
  `b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819`;
  pages 112-138 and related workflows reviewed as part of the complete manual read.
- Mockenhaupt, Rieber, and Nercessian, *Automatic Equalization for Individual
  Instrument Tracks Using Convolutional Neural Networks*, DAFx-24/arXiv v1,
  SHA-256 `b4926354e71ad2d620107f69dbfbf9227f84cef567bc6049fd9bc67247370a06`;
  all eight pages, method, constraints, real/synthetic data, evaluation, and
  limitations read.
- TrackSmith professional-decision corpus, 58 full relevant production-case
  records; EQ/tone/filter/spectrum language recurs in 26 records, with the explicit
  caveat that keyword presence is not an EQ-insertion count.

### Strongly established

Channel EQ exposes high- and low-pass filters, low/high shelves, four bell bands,
output gain, pre/post spectrum analysis, oversampling, and Stereo/L/R/Mid/Side
operation. Filter type, frequency, gain, Q/slope, channel mode, band interaction,
and processor position all matter. EQ before a nonlinear stage changes the energy
driving that stage; EQ after it shapes both source and generated components. Mid/
Side processing changes center versus lateral content and can damage mono or focal
stability.

The analyzer is observation, not diagnosis. A stable peak may be a note, formant,
instrument identity, room mode, resonance, masking contributor, or wanted emphasis.
The Apple workflow itself makes action depend on material and intent. Automatic-EQ
research supports conditioning on source identity and retaining parametric controls,
but its 35-class mean targets, four-band ranges, Q limits, and isolated-track
listening task do not define a universally correct spectrum.

### Direct Logic evidence boundary

The partial Logic 12.3 build-6674 run
`logic-12.3-channel-eq-default-bell-48k-2026-07-18` directly measured one 48 kHz
mono amplitude fixture. Three settled unmodified-default renders and three settled
header-bypass renders were sample-identical to the source. Peak 3 at 1000 Hz,
+6.0 dB, Q1 measured approximately +6 dB on every unclipped ladder segment,
repeated with identical decoded PCM, and survived save/reload. Input peaks at
-6 dBFS and above reached the PCM24 export ceiling; per-level analysis, not the
clipped whole-file regression coefficient, supports the gain claim. First exports
after default insertion and bypass differed only in samples 1-1023, reinforcing the
settled-repeat rule. This does not establish other bands, grids, slopes, modes, HQ,
phase/group delay, stereo, other rates, musical preference, or Apple's private
filter topology.

### What each decision dimension changes

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| High/low pass | Removes energy outside a chosen range and changes phase near the transition | Fundamental/body loss, transient change, slope, project rate, and whether the energy was actually harmful |
| Bell frequency/gain/Q | Changes a localized spectral region; Q controls breadth | Note dependence, ringing, audibility in context, gain bias, and whether dynamic/event-specific control is better |
| Shelf | Changes a broad end of the spectrum | Loudness/brightness bias, noise/air or sub/body preservation, and downstream headroom |
| Output gain | Restores or changes level after filtering | Level-matched bypass; output gain must not make a curve appear preferable |
| Oversampling | May change high-frequency processing behavior and cost | Direct host render and alias/residual comparison; no undocumented algorithm claim |
| L/R | Treats physical channels independently | Image shift, asymmetric source content, and mono sum |
| Mid/Side | Treats center and lateral components independently | Vocal/kick/bass center preservation, low-side energy, width, correlation, and mono translation |
| Analyzer position | Shows energy before or after EQ | Analyzer on/off audio null; a display is not processing authority |

### Source-aware hypotheses

| Source | Intervention may be justified by | Evidence against intervention / preserve |
|---|---|---|
| Vocal | Repeated plosive/rumble evidence; proximity buildup; a contextual formant or masking problem; insufficient presence/air after level and arrangement checks | Preserve intelligibility, vowel identity, consonants, breath, air, intimacy, and the singer's tonal character. Static cutting is not de-essing. |
| Drums or drum bus | Whole-kit low-frequency allocation, shell/cymbal balance, persistent resonance, room/close relationship, or arrangement masking | Preserve kick/snare body, attacks, cymbal smoothness, room coherence, and multi-microphone phase. A bus cannot diagnose individual microphones. |
| Bass | Sub/fundamental allocation, low-mid congestion, note definition, or kick relationship | Preserve weight, pitch audibility, note consistency, transient role, and translation. Do not high-pass a bass from a generic cutoff. |
| Guitar | Amp/pedal spectral identity, pick edge, body, density, persistent painful concentration, or clash with focal parts | Preserve articulation, aggression where requested, cabinet character, note separation, and arrangement role. Solo harshness may be useful presence in the mix. |
| Synth/keys | Layer density, filter/envelope motion, low-end role, center/side allocation, or conflict with the vocal | Preserve programmed filter movement, stereo animation, fundamental role, and mono compatibility. Static EQ may fight a time-varying patch. |
| Full mix | Broad translation issue confirmed across references/monitoring, tonal imbalance, side-specific buildup, or delivery headroom | Preserve source balance, contrast, transients, vocal focus, low-end center, and mix identity. Prefer source correction when available and clearly causal. |

### Strategy selection and stopping

Channel EQ competes with level balance, arrangement change, panning, source choice,
dynamic EQ/de-essing, automation, multiband dynamics, saturation, and no processing.
Choose the smallest strategy that addresses the stated problem while satisfying
preservation constraints. Stop when the contextual distraction is removed or the
requested tonal move is audible at matched level; do not keep moving toward a
generic target. If the change only sounds better louder, or it creates thinness,
harshness, lost attack, unstable center, or mono loss, reject or revise it.

### TrackSmith must not say

- “The analyzer found mud/harshness/boxiness.”
- “This instrument should match its class-average spectrum.”
- “Mid/Side EQ makes a mix wider/professional.”
- “Linear Phase EQ is higher quality.”
- “A familiar frequency chart establishes the correct band.”

## Compressor

### Source record

- Apple, *Logic Pro Effects for Mac*, same immutable payload above; pages 87-111
  and related side-chain/dynamics workflows reviewed in the complete manual read.
- Giannoulis, Massberg, and Reiss, *Digital Dynamic Range Compressor Design—A
  Tutorial and Analysis*, JAES 60(6), 2012, pp. 399-408, SHA-256
  `dd65e1f91e8fafd855cc994246bfe957d671254a271b83ba8fab2239f7b23b44`;
  equations (1)-(24), figures, experiments, Table 1, limitations, and conclusion
  fully reviewed.
- Giannoulis, Massberg, and Reiss, *Parameter Automation in a Dynamic Range
  Compressor*, JAES 61(10), 2013, pp. 716-726, SHA-256
  `d1ac2af3fb7238bafa8c861edc5a907a286983dabffcdbc2e4cbb2f4a29d9bb8`;
  automation equations, constants, evaluation, disagreements, and limitations
  fully reviewed.
- TrackSmith professional-decision corpus: dynamics/compression language recurs
  in 29 of 58 curated cases; transient/envelope language in 18. These are case
  recurrence signals, not universal compressor-use rates.

### Strongly established

A compressor is a level-dependent, time-varying gain system, not one sound. The
static hard-knee threshold/ratio relation and continuous quadratic soft knee are
explicit in the 2012 paper. A one-pole coefficient using the `1 - 1/e` definition
is `exp(-1 / (tau * sampleRate))`; other products can define displayed attack and
release differently. Feedforward/feedback topology, Peak/RMS detection, detector
placement, branching/decoupling, knee, smoothing, channel linking, side-chain
filtering, makeup, dry/wet, and optional coloration all alter behavior.

Logic Compressor exposes seven circuit models plus threshold, ratio, knee,
attack/release, Peak/RMS, stereo Max/Sum linking, side-chain filtering, makeup/
Auto Gain, dry/wet, output limiter, and distortion. Apple's model labels establish
available choices, not exact circuit equivalence. The compressor paper's preferred
predictable feedforward/log-gain-reduction detector is a technical recommendation
under its experiments, not a universally better musical model.

### Logic circuit-model and control boundary

Apple exposes seven named choices: Platinum Digital, Studio VCA, Studio FET,
Classic VCA, Vintage VCA, Vintage FET, and Vintage Opto. The manual explicitly
describes Platinum Digital as clean with fast transient response, then gives
family-level—not per-model—descriptions: FET can be clean or midrange-warm and
driven toward transient crunch; VCA tends clean and can respond slowly or quickly;
Opto is described as clean with fast transient response and nonlinear release.
Those are Apple product descriptions and practice suggestions, not measured
equivalence to particular hardware. The Opto wording also conflicts with broad
professional shorthand that often associates optical gain cells with slower or
program-dependent attack; TrackSmith must preserve that contradiction and measure
Logic's actual state rather than silently universalizing either description.

The shared documented surface is input gain, threshold, ratio, makeup, Auto Gain
off/0 dB/-12 dB, knee, attack, release/Auto Release, output gain, optional output
limiter/threshold, Soft/Hard/Clip distortion, dry/wet Mix, stereo Max/Sum detection,
Peak/RMS detection, and LP/BP/HP/parametric/high-shelf side-chain filtering with
frequency/Q/gain and Listen. Apple warns that not every parameter is available in
every model, that the internal program signal remains the normalized side chain
when no external source is selected, and that Auto Gain plus RMS can oversaturate.
The manual does not publish the seven models' coefficients, time-constant
definitions, detector windows, nonlinear curves, parameter-availability matrix,
or hardware tolerances. Those require a versioned direct-host grid before
TrackSmith can claim model-specific mastery.

### What each decision dimension changes

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| Threshold/ratio/knee | Amount and shape of level-dependent gain | Input level, effective curve, crest, audibility, and whether automation is more local |
| Attack | How much onset passes before gain reduction develops | Displayed-time definition, source transient duration, overshoot, clicks/distortion, and requested attack preservation |
| Release | Recovery, sustain relationship, groove, pumping, and distortion | Event spacing, low-frequency period, auto mode, room/noise lift, and section dynamics |
| Peak/RMS | Sensitivity to fast peaks versus energy-like level evidence | Source crest, detector window/implementation, and response to brief consonants or percussion |
| Side-chain filter | Which frequencies drive gain reduction | Audible full-band result, low-frequency pumping, sibilance/harshness triggers, and false nontrigger |
| Stereo Max/Sum | How channels jointly control gain | Center stability, one-sided events, width breathing, and mono translation |
| Makeup/Auto Gain | Changes comparison level and downstream operating point | Loudness-matched bypass and peak/headroom safety |
| Dry/wet | Blends compressed and original paths | Latency/phase, transient retention, peak reconstruction, and whether parallel density masks detail |
| Model/distortion/limiter | Changes transfer, timing, nonlinear color, or peak boundary | Matched settings cannot be assumed equivalent; measure harmonics/IMD/alias/noise and source identity |

### Source-aware hypotheses

| Source | Intervention may be justified by | Evidence against intervention / preserve |
|---|---|---|
| Vocal | Distracting level contour, occasional peaks, inconsistent word audibility, desired density, or section-specific energy | Preserve emotional movement, consonants, breath, intimacy, vibrato, and natural word-to-word emphasis. Clip gain/automation, serial light stages, or parallel section rides may be better. |
| Drums or drum bus | Peak control, attack/sustain rebalance, room emphasis, density, cohesion, or intentional pumping | Preserve groove, leading attacks, kick/snare body, cymbal smoothness, room coherence, and macro contrast. “Slow attack = punch” is only a candidate relative to event duration. |
| Bass | Note-to-note control, transient/sustain relationship, added sustain, or kick interaction | Preserve low-end weight, pitch, articulation, groove, and intentional dynamics. Distorted/synth bass may already be highly compressed. |
| Guitar | Pick/transient control, sustain, clean-part consistency, or rhythmic density | Preserve attack, chord articulation, amp/pedal dynamics, noise floor, and aggression. High-gain guitar may need no additional compression. |
| Synth/keys | Envelope reshaping, programmed dynamics control, side-chain rhythm, or layer density | Preserve designed ADSR/filter motion, velocity response, stereo modulation, bass focus, and musical phrasing. Edit the patch envelope when that is the real source. |
| Full mix | Bounded peak/density change, movement, or section cohesion confirmed in context | Preserve macro dynamics, transients, low-end stability, vocal priority, stereo image, and headroom. Fix one source instead when it alone drives the problem. |

### Adaptive timing and makeup evidence

The 2013 automation paper shows that crest factor and positive spectral flux can
generate bounded timing candidates; spectral flux generally matched panel timing
choices better for four isolated test signals. Loudness-based makeup matched panel
medians better for most of those signals but overestimated the drum example by
about 3 dB. Nine professionals, seven amateurs, four short isolated sources, user-
specific environments, empirical constants, and disagreement about transient
versus sustain equality sharply limit generalization. TrackSmith may offer adaptive
timing as one hypothesis with uncertainty; it must not present it as the correct
attack/release or trust broadcast loudness to equalize a transformed drum.

### Direct Logic 12.3 empirical boundary

The 2026-07-20 direct-host run closes a narrow but useful part of the Logic
Compressor knowledge gap. The observed default repeated exactly but was not
neutral: `Auto Gain -12 dB` was active and the four quietest 1 kHz ladder steps
gained approximately `3.4055 dB`. Header bypass was source-PCM exact. A controlled
Platinum Digital Peak/hard-knee state at threshold -20 dB and ratio 4.1:1 matched
the public hard-knee equation within `0.000128 dB` at the five above-threshold
steady levels. Stabilized and post-reload renders matched exactly, while the first
controlled render differed only in samples 1-1022. This supports static-curve,
bypass, settling, and save/reload decisions for the exact state; it leaves timing,
detector isolation, six circuit models, stereo linking, side-chain filters,
distortion, limiter, parallel mix, sample-rate dependence, and listening open.

Product consequence: never present the native default as a level-matched baseline;
separate first-transition diagnostics from settled candidates; and do not transfer
the controlled curve into a universal setting. Full evidence is in
`docs/evidence/LOGIC_NATIVE_COMPRESSOR_EMPIRICAL_2026-07-20.md`.

### Strategy selection and stopping

Compressor competes with clip gain, fader automation, limiter, transient shaping,
dynamic EQ/de-essing, saturation, source/arrangement change, parallel processing,
and no processing. State the intended envelope change before selecting settings.
Level-match. Stop when the distracting contour or requested density/shape is
resolved without violating the preserved performance. Reject or revise a candidate
that wins mainly through makeup gain, dulls defining attacks, lifts room/noise,
causes low-frequency distortion/pumping, shifts the stereo image, or erases section
contrast.

### TrackSmith must not say

- “Compression makes this polished/glued/punchy.”
- “Use slow attack and fast release on drums” without event, detector, and goal context.
- “This source needs 3 dB of gain reduction.”
- “Auto Gain is a fair bypass comparison.”
- “One circuit model exactly recreates named hardware.”
- “Objective envelope fidelity or THD proves the preferred sound.”

## DeEsser 2

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; complete DeEsser 2
  section, pages 95-97, reviewed. The distinction among Relative/Absolute,
  Split/Wide, detector filter shape, threshold, and maximum reduction is explicit.
- TrackSmith source-aware vocal analysis v1 supplies bounded sibilance evidence,
  spectral balance, air/brightness evidence, confidence, windowing, and failure
  conditions. Those measurements are evidence inputs, not phoneme labels.
- Professional-practice sources support event-specific de-essing and intelligibility/
  air preservation, but no reviewed source establishes a universal band or reduction
  amount for every singer, microphone, or language.

### Strongly established

DeEsser 2 is a fast dynamics processor whose detector is restricted by its filter.
In Relative mode, filtered-band level is compared with full-band input level; in
Absolute mode, filtered-band level is compared with a fixed threshold. Split mode
attenuates only the selected band, while Wide mode applies reduction across the
full frequency range when the detector triggers. Max Reduction bounds attenuation.
The filter is before detection, and Filter Solo is an identification aid—not the
audible program output.

Apple's 5-10 kHz vocal-sibilance range is explicitly a typical workflow heuristic.
It is neither a phoneme detector nor a safe fixed target. The guide also warns that
sibilance is natural speech information and excessive removal sounds strange.

### What each decision dimension changes

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| Relative versus Absolute | Relative responds to band prominence compared with current full-band level; Absolute responds to detector level | Quiet/loud passages, accompaniment leakage, changing vowel spectrum, and false triggers |
| Frequency/filter shape | Chooses the detector evidence: broad high-frequency region or narrower peak | Actual consonant events, singer/microphone variation, breath/air, cymbal bleed, and analyzer resolution |
| Split versus Wide | Split changes the detected band; Wide turns the event into broadband attenuation | Lateral tonal holes versus whole-vocal dips, consonant clarity, level motion, and image stability |
| Threshold | Chooses which detector events trigger | Event recall/false positives across sections; do not tune on a single loud `s` |
| Max Reduction | Bounds the audible intervention | Lisping, dullness, breath loss, intelligibility, and gain-biased comparisons |
| Position | Changes what creates and what follows sibilance | Compression or saturation can reveal/create high-band energy; later EQ can restore both wanted air and unwanted events |

### Source-aware hypotheses

For vocals, intervention requires repeated short-duration high-band evidence that
aligns with audible sibilant events. Evidence against intervention includes stable
brightness, wanted breath, fricative intelligibility, cymbal/headphone bleed, or a
single analyzer peak without event correspondence. For drums or a full mix, a
de-esser-like strategy may control isolated cymbal/harsh events, but source leakage
and collateral band attenuation make dynamic EQ, automation, source-level repair,
or no processing competing hypotheses. Bass, most guitars, and most synths do not
become de-essing targets solely because high-band energy exists.

### Strategy selection and stopping

Compare DeEsser 2 with clip/word automation, microphone/source repair, dynamic EQ,
multiband compression, a narrow static cut, and no action. Prefer the least broad
intervention that resolves the distracting events. Stop when the target consonants
sit naturally at matched level. Reject candidates that reduce air continuously,
soften wanted articulation, produce broadband level dips, or solve a monitoring/
arrangement problem by altering the singer.

### TrackSmith must not say

- “Energy from 5-10 kHz is sibilance.”
- “Relative mode is always more natural.”
- “Wide mode is stronger Split mode.”
- “A fixed amount of gain reduction is transparent.”
- “Less detector activity means a better vocal.”

## Noise Gate

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; complete Noise Gate
  section, pages 105-107, reviewed, including Gate/Ducker routing, hysteresis,
  ballistics, lookahead, detector filtering, and the side-chain-monitor workflow.
- Giannoulis, Massberg, and Reiss compressor theory supplies general detector and
  smoothing context, but does not validate Logic Noise Gate's private transfer or
  timing implementation.
- Professional-practice cases support cleanup and envelope hypotheses. They do not
  establish a universal noise-floor threshold or require gating on a source class.

### Strongly established

In Gate mode, signals below Threshold are reduced by a bounded Reduction amount;
signals above it pass. Hysteresis separates opening and closing thresholds to
reduce chatter. Attack controls opening, Hold the minimum open interval, Release
the transition to maximum attenuation, and Lookahead lets the detector inspect
ahead of the audible event. Detector high/low cuts affect only the trigger path,
not the gated audio. With no external side chain, the input is the detector.

Ducker mode reverses the production goal: a side-chain event reduces the program
path. Apple's documented aux workflow also mixes the selected voiceover side-chain
into the post-plug-in output; TrackSmith must treat that as a specific Logic routing
workflow, not a universal property of duckers or a capability of its inserted AU.

### What each decision dimension changes

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| Threshold/reduction | Chooses what is attenuated and by how much | Noise/signal overlap, quiet wanted notes, room tone continuity, and false closes |
| Hysteresis | Separates open and close decisions | Chatter versus sluggish closure and low-level event retention |
| Attack/lookahead | Controls onset capture and anticipatory opening | Leading transient loss, latency, false triggers, and source envelope |
| Hold/release | Controls minimum exposure and tail closure | Chopped syllables/notes, breathing, cymbal/reverb decay, groove, and noise pumping |
| Detector filter | Makes selected frequencies more or less likely to trigger | Monitor the detector; confirm it discriminates the wanted event without filtering the audible path |
| Gate versus Ducker | Either suppresses low-level program or reduces program during an external event | Routing identity, side-chain availability, source audibility, and whether simple automation is safer |

### Source-aware hypotheses

| Source | Intervention may be justified by | Evidence against intervention / preserve |
|---|---|---|
| Vocal | Stable room/noise between phrases, headphone bleed, or an effect return that should follow phrasing | Preserve breaths, word onsets/ends, vulnerability, consonants, and continuous room tone; editing or expansion may sound less mechanical |
| Drums or drum bus | Close-mic bleed, intentional envelope shortening, or side-chain isolation of a drum trigger | Preserve ghost notes, cymbal/room decays, flam timing, multimic blend, and groove; a bus gate can erase the whole kit's low-level information |
| Bass | Sustained amp/noise between notes or deliberate rhythmic truncation | Preserve note tails, slides, fret/finger detail, legato, and low-level pickup; low-frequency periods demand careful timing |
| Guitar | Amp/pedal noise in genuine gaps or creative chopping | Preserve sustain, feedback, pick lead-ins, room, and musical rests; high-gain noise may overlap the wanted decay |
| Synth/keys | Programmed rhythmic gating/ducking or idle noise | Preserve pads, release envelopes, modulation tails, velocity detail, and tempo feel; the patch envelope may be the correct control |
| Full mix | Rarely a direct cleanup target; bounded side-chain ducking may support an explicitly requested foreground event | Preserve ambience, fades, macro dynamics, and mix continuity; source or automation correction is usually more attributable |

### Strategy selection and stopping

Gate competes with downward expansion, strip silence/manual editing, spectral noise
reduction, clip/fader automation, source repair, transient shaping, ducking, and no
action. Use partial reduction when continuity matters; use full closure only when
the wanted and unwanted states are separable. Audition the quietest wanted events,
transitions, and tails—not just the loud phrase used to set Threshold. Stop when
noise is no longer distracting in context. Reject chatter, missing leading edges,
abrupt ambience, false side-chain triggers, or rhythmically obvious pumping unless
the user explicitly chose the effect.

### TrackSmith must not say

- “Everything below the noise floor is unwanted.”
- “A gate cleans a recording without changing the performance.”
- “Lookahead is free or latency-neutral.”
- “Hysteresis and Hold solve the same problem.”
- “A detector filter removes those frequencies from the audio.”

## ChromaVerb and Space Designer

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; full ChromaVerb
  section, pages 310-316, and full Space Designer section, pages 331-350,
  reviewed. This includes every room type, damping/output EQ, modulation, early/
  late and distance controls, sampled/synthesized IR behavior, envelopes, quality,
  latency/volume compensation, automation limits, channel formats, and output
  topology.
- Senoussaoui, Santos, and Falk, *SRMR Variants for Improved Blind Room Acoustics
  Characterization*, arXiv:1510.04707v1, SHA-256
  `777ca8c75e33fc645410e20951d2c52d0c1aeac70484af7fce0a6274bc0579a4`;
  fully read. Its speech/RIR/noise results do not validate an ambience amount or
  distance metric for produced music.
- TrackSmith professional-decision corpus: ambience/reverb/delay language recurs
  in 16 of 58 cases. This is contextual evidence, not a prescription to add reverb.

### Strongly established and processor-specific

ChromaVerb is an algorithmic reverb with 14 room algorithms. Its Attack can mean
volume rise or density build depending on room type; Size, Density, Predelay,
Decay, Distance, early/late balance, frequency-dependent damping, output EQ,
modulation, Width, Mono Maker, and dry/wet are separate decisions. Consequently,
the same numerical move need not have the same perceptual meaning across room
types. Apple's quality labels and adjectives describe product modes; they are not
listening-test evidence that one mode is “expensive” or superior.

Space Designer convolves input with a sampled or synthesized impulse response and
supports mono, stereo, true-stereo, and surround operation. IR identity is part of
the processor state. Length and Size interact; Quality changes IR sample rate and
therefore bandwidth, duration, CPU cost, and sometimes latency. Sampled IR edits
and synthesized-IR regeneration require convolution recalculation. Only X-Over,
direct/reverb level, and Output EQ are fully documented as automatable; a plan must
not assume every IR/envelope control can follow ordinary automation.

### What each decision dimension changes

| Dimension | ChromaVerb | Space Designer | Required counter-check |
|---|---|---|---|
| Space identity | One of 14 algorithms sets control behavior and absorption/color | Sampled or synthesized IR defines reflections, channel format, and character | Source role, realism versus effect, IR provenance, preset state, and exact host version |
| Predelay | Separates dry onset and early reflections; extremes can color, echo, or detach | Same temporal separation, adjustable beyond natural values | Transient envelope, tempo, intelligibility, audible gap, and foreground/background intent |
| Early/late structure | Distance and Early/Late Mix alter early/late energy | IR Offset, volume envelope, and IR itself alter onset/decay structure | Direct-to-reverberant balance, localization, onset preservation, and whether the change is an effect rather than correction |
| Decay/length/size | Decay and frequency-dependent damping vary by algorithm | Length multiplied by Size, bounded by sampled IR length; envelopes stretch/shrink | Section tempo/density, masking, tail truncation, low-frequency buildup, and CPU/latency |
| Spectrum over time | Four-band Damping EQ changes decay ratios; six-band Output EQ shapes combined output | Filter envelope recalculates the IR; six-band Output EQ shapes combined output | Dry signal may also be affected by Output EQ, air/body preservation, and event-versus-static need |
| Modulation/density | LFO source/speed/depth/smoothing and Density alter smoothness/motion | Synthesized IR density/ramp/reflection shape control discrete echoes versus smooth tail | Pitch/chorus movement, grain, stereo stability, source modulation, and listening context |
| Stereo/mono | Width plus low-frequency Mono Maker | Stereo/mono/cross-stereo input; frequency-split Lo/Hi Spread | Center focus, low-side energy, correlation, mono sum, channel format, and output level |
| Dry/wet and routing | Independent dry/wet | Dry should be muted on an aux return; internal latency/volume compensation alter comparison | Insert versus send topology, double-dry paths, send automation, latency, and level-matched audition |
| Quality | Low/grainy through Ultra product modes | Lo-Fi/Low/Medium/High changes IR rate and behavior | CPU, project rate, bandwidth, duration, latency, and undocumented superiority claims |

### Source-aware hypotheses

| Source | Intervention may be justified by | Evidence against intervention / preserve |
|---|---|---|
| Vocal | Requested intimacy/depth/space, dry capture needing contextual placement, or a contrast between sections | Preserve consonants, breath, front-edge clarity, word tails, pitch focus, and lyric priority. “Intimate” can mean less ambience, short early space, audible breath, level, or performance—not one reverb preset. |
| Drums or drum bus | Room reinforcement, snare depth, kit cohesion, gated/creative tail, or dry close-mic context | Preserve leading attacks, cymbal smoothness, groove, kick low-end definition, and existing room microphones. Reverb may enlarge sustain while reducing perceived punch. |
| Bass | Explicit ambience/effect, short room placement, or upper-band depth | Preserve sub focus, note definition, center stability, and mono translation. Full-band long tails commonly compete with the next note; filtered/parallel or no reverb is a competing strategy. |
| Guitar | Amp-space recreation, depth, sustain, or tempo/genre-specific ambience | Preserve pick attack, chord separation, distortion texture, feedback, and arrangement role. The recorded amp/room may already contain the intended space. |
| Synth/keys | Designed depth, width, tail movement, or placement around a focal source | Preserve programmed envelope/modulation, harmonic rhythm, vocal space, low-end role, and mono compatibility. Patch release and reverb tail can duplicate each other. |
| Full mix | Deliberate common-room cohesion, transition effect, or tiny bounded depth change | Preserve center, low-end clarity, transient contrast, existing source spaces, delivery headroom, and section separation. A master reverb cannot observe or repair individual send relationships. |

### Choosing between them and stopping

Use ChromaVerb when editable algorithmic structure, modulation, early/late control,
and quick tonal/depth variation are central. Use Space Designer when a specific
captured/modelled space or IR-defined response is central. Either competes with
delay, source/room microphones, early-reflection-only processing, track volume,
spectral balance, stereo placement, arrangement change, or no effect. That is a
candidate distinction, not a quality ranking.

Level-match the direct path, audition in arrangement and through the tail, and
test mono and section boundaries. Stop when the source occupies the requested
depth without obscuring the next event or focal material. Reject candidates whose
appeal is mostly a louder wet path, whose low end spreads or accumulates, whose
tail masks consonants/transients, whose modulation destabilizes pitch/image, or
whose IR/automation state cannot survive the intended host workflow.

### TrackSmith must not say

- “More reverb means farther away” or “less reverb means intimate.”
- “RT60/SRMR proves the correct ambience for produced music.”
- “A real-space IR is more realistic or better for this source.”
- “ChromaVerb Ultra sounds objectively expensive.”
- “Predelay has one correct tempo-derived value.”
- “Width or correlation alone proves mono-safe depth.”
- “Every Space Designer parameter can be automated like a normal plug-in.”

## Stereo Delay and Tape Delay

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; complete Stereo
  Delay section, pages 74-76, and Tape Delay section, pages 76-77, reviewed.
- Professional-case ambience/delay language recurs in 16 of 58 records. The cases
  support context-sensitive depth, rhythm, filtering, automation, and focal-space
  decisions; they do not establish a default delay time or feedback amount.
- Exact filters, feedback topology beyond documented routing, tape nonlinearity,
  interpolation, modulation waveforms, and alias behavior remain unmeasured.

### Strongly established and processor-specific

Stereo Delay is two independently configurable delay paths. Each side can derive
from Off, Left, Right, L+R, or L-R; has time, grid deviation, filtering, feedback,
feedback polarity, crossfeed, and crossfeed polarity; and participates in global
routing/link/output controls. Inserting it on mono makes the strip stereo from that
slot onward. This is a graph/channel-format consequence, not merely “a wider echo.”

Tape Delay exposes free or tempo-synced time, deviation/smoothing, feedback-loop
high/low cuts, clip threshold, Clean/Diffuse head mode, LFO, flutter, feedback,
freeze, spread, and dry/wet. The feedback filters act repeatedly, so spectral
change compounds across echoes. At 100% feedback Apple documents endless repeats;
levels can accumulate and distort. Freeze sustains the current repeat state. Exact
stability, limiting, and nonlinear behavior require direct-host measurement.

### Decision dimensions and preservation checks

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| Time/sync/deviation | Rhythmic placement, slap, doubling, separation, or off-grid motion | Tempo changes, phrase rhythm, transient masking, combing at short times, and whether free time serves feel better |
| Feedback | Repeat count/density and cumulative energy | Runaway level, tail overlap, nonlinear buildup, section boundaries, and capture duration |
| Feedback filtering | Successive repeats become progressively band-limited | Vocal consonant space, low-end accumulation, noise/resonance, and whether the dry path remains unchanged |
| Stereo input/routing/crossfeed | Independent, ping-pong, rotated, or cross-coupled motion | Source channel identity, center stability, one-sided peaks, correlation, mono sum, and mono-to-stereo format change |
| Feedback/crossfeed polarity | Changes repeat combination/cancellation | Frequency-dependent nulls, headphones/speakers, mono, and no claim of general phase correction |
| Tape clip/head/LFO/flutter | Adds level-dependent color and time modulation | Pitch stability, transient integrity, intermodulation/aliasing, feedback escalation, and matched output |
| Spread | Changes wet-field width | Low-side energy, center/focal stability, mono translation, and mono-instance absence |
| Dry/wet/output | Sets direct/effect relationship | Insert versus aux topology, double-dry paths, loudness bias, and send return level |

### Source-aware hypotheses

Delay can provide vocal depth without the continuous density of a long reverb,
rhythmic drum movement, bass upper-band ambience, guitar slap/echo, synth motion,
or a bounded mix transition. Against intervention: syllable masking, kick/bass tail
overlap, cymbal clutter, already-wide modulation, arrangement density, or a request
for closeness/dryness. For “wider,” Stereo Delay competes with panning, independent
parts, modulation, reverb, M/S balance, and no change. For “more intimate,” a quiet
filtered delay may preserve dry onset—or may make the singer feel farther away.
Neither result follows from the word alone.

Stop when the repeats serve the phrase and disappear appropriately around focal
events. Reject candidates that create level-biased energy, runaway/uncaptured
tails, low-end blur, consonant masking, image wandering, pitch nausea, or mono
cancellation. User listening remains decisive across the complete tail.

### TrackSmith must not say

- “Tempo sync is always more musical.”
- “Ping-pong delay makes a source safely wider.”
- “Tape Delay sounds analog/vintage because Apple named it tape.”
- “Filtered repeats cannot make a mix harsh or muddy.”
- “100% feedback is bounded without a direct safety test.”

## ChromaGlow and Overdrive

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; complete ChromaGlow
  section, pages 80-81, and Overdrive section, pages 84-85, reviewed.
- Professional-case saturation/distortion language recurs in 10 of 58 records.
  These are contextual uses, not evidence that saturation improves every source.
- Apple's *warm*, *vintage*, *punchy*, *muddiness*, *polished*, and *professional*
  model descriptions have no disclosed listening method and remain product/practice
  heuristics. No exact emulated circuit transfer is claimed.

### Strongly established and processor-specific

ChromaGlow is Apple-silicon-only and exposes five model families, model-specific
styles, input/output level, Drive, Bypass Below, Mix, and pre/post low/high-cut
filtering. Bypass Below can keep frequencies below a threshold out of the nonlinear
path. Moving a filter from pre to post changes the excitation of the nonlinearity
versus the spectrum of its output; these are not interchangeable tone controls.

The manual contains an apparent editorial contradiction: the **Low Cut** Frequency
description calls its filter a lowpass, while **High Cut** calls its filter a
highpass. TrackSmith preserves the discrepancy and uses control names plus direct
Logic/UI/render evidence before making an exact transfer claim.

Overdrive exposes a simpler documented FET-emulation path: Drive, a high-cut Tone,
Output, and Level Compensation. Level Compensation is an operating aid, not a
validated loudness-matched bypass. Both processors are level-dependent nonlinear
systems; generated harmonics, intermodulation, envelope change, aliasing, and
apparent loudness depend on the source spectrum and input level.

### Decision dimensions and source context

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| Input/Drive/model/style | Changes nonlinear operating point and transfer family | Source level, harmonic/IMD/alias spectrum, transient crest, noise, and model-specific direct evidence |
| Bypass Below | Preserves low frequencies from ChromaGlow processing | Crossover transition, upper-bass consistency, phase/latency, and whether unprocessed lows feel detached |
| Pre/post cuts | Pre changes what drives saturation; post shapes source plus generated components | Apparent warmth/brightness, resonance, headroom, and the manual's filter-label defect |
| Mix | Blends dry and nonlinear paths | Latency/phase, peak reconstruction, transient retention, and loudness |
| Output/compensation | Sets final level | LUFS/peak-matched bypass and downstream headroom; never score the louder candidate as better |
| Overdrive Tone | High-cuts the harmonically rich result | Pick/consonant/cymbal preservation, audibility on small speakers, and unwanted dullness |

On vocal, saturation may add audibility/density but can exaggerate sibilance,
breath, plosives, and noise. On drums it may thicken or shave transients but can
make cymbals brittle. On bass it may create upper harmonics for translation while
preserving sub weight, yet intermodulation can blur pitch. On guitar it interacts
with an already nonlinear amp/pedal chain. On synth it can change programmed
envelopes and stereo modulation. On a full mix, every source and intermodulation
product is coupled; a source-level move is often more attributable.

Saturation competes with EQ, compression, clipping/limiting, parallel processing,
level/arrangement balance, source sound design, and no action. Stop when the
requested density/color/audibility is achieved at matched level without losing
identity. Reject alias-like high-frequency growth, low-end blur, consonant/cymbal
harshness, transient flattening, stereo instability, or a “warmth” result that is
actually darker or merely louder.

### TrackSmith must not say

- “Even harmonics are warm and odd harmonics are harsh.”
- “A tube/tape/preamp label proves the circuit or period it emulates.”
- “Saturation always compresses musically.”
- “Level Compensation makes the comparison fair.”
- “Warm, vintage, polished, or expensive is one ChromaGlow model.”

## Limiter and Adaptive Limiter

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; Adaptive Limiter
  pages 88-89 and Limiter pages 100-101 reviewed.
- ITU-R BS.1770-5 (11/2023), official payload SHA-256
  `eefb926f72f72a96b96f251067bfee0650a0f29a26f60661d354162038b041ad`,
  full-read. It defines programme loudness and true-peak measurement, not how a
  limiter should sound or how much limiting is artistically correct.
- ITU-R BS.2217-2 (11/2016), official report SHA-256
  `0ae77dc00c1528198ab6acf61620b70f82c5f3c521f8a6918bb3a24281f98376`;
  14 selected publisher-hosted integrated-loudness vectors passed TrackSmith's
  external lane. This validates supported measurement behavior, not Logic's
  limiter transfer.

### Strongly established and processor-specific

Logic Limiter exposes input Gain, Release, Output Level, and Lookahead plus input,
reduction, and output meters. It cannot repair clipping already present in a
recording. Adaptive Limiter exposes Gain, output ceiling, Lookahead/Optimal
Lookahead, DC removal, and True Peak Detection; Apple documents added latency with
lookahead and advises bypass while recording.

Apple describes Adaptive Limiter as peak rounding/smoothing with possible color,
not a transparent hard ceiling. Statements about achieving maximum loudness
without unwanted distortion and a signal never exceeding the selected ceiling are
product claims until tested across rates, formats, overs, resets, and render paths.
True Peak Detection being present does not prove BS.1770 Annex 2 conformance or a
safe delivery margin under every codec/sample-rate conversion.

### Decision dimensions and preservation checks

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| Input Gain | Drives more peaks into reduction and raises density/loudness | Integrated/short-term loudness, crest, transient loss, distortion, pumping, and matched comparison |
| Ceiling/output | Bounds reported output target | Independent sample/true-peak measurement, downstream gain, codec/SRC margin, and unit interpretation |
| Release | Controls recovery and repeated-event interaction | Low-frequency distortion, pumping, groove, sustain, section contrast, and exact displayed-time behavior |
| Lookahead | Anticipates peaks | Latency, recording/monitoring path, transient shape, reset, and offline/realtime parity |
| Adaptive behavior | Rounds/smooths peaks with implementation-dependent color | Harmonics/IMD/aliasing, source identity, stereo linking, and undocumented transfer |
| DC removal | High-passes DC before/within the limiting workflow | Legitimate sub energy, phase/settling, and whether DC was actually present |
| True Peak Detection | Changes peak detection target | Independent BS.1770-style estimate, sample rate, oversampling residual, and complete vector evidence |

Limiter hypotheses are appropriate for bounded peak safety, delivery headroom, or
an explicitly requested density/loudness change. They compete with source/clip
repair, fader/clip automation, compression, saturation/clipping, mix rebalance,
and lower target loudness. On individual vocals, drums, bass, guitars, or synths,
limiting can be a local peak strategy but must preserve articulation and feed the
mix safely. On a full mix, macro dynamics, kick/snare shape, vocal movement,
low-end stability, stereo image, codec margin, and loudness target all constrain it.

Stop at the least reduction that meets the explicit peak/delivery goal. Reject a
candidate that appears better through loudness, loses event hierarchy, distorts
low frequencies, creates brittle overs, or makes the desired loudness incompatible
with preserved dynamics. Listening and downstream delivery checks remain decisive.

### TrackSmith must not say

- “0 dBFS sample ceiling is true-peak safe.”
- “True Peak Detection proves standards conformance.”
- “Adaptive Limiter is transparent or distortion-free.”
- “Mastering means making the mix as loud as possible.”
- “A measured LUFS or LRA value determines how much limiting is needed.”

## Direction Mixer and Correlation Meter

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; Direction Mixer
  pages 169-170 and Correlation Meter pages 179-180 reviewed.
- Stereo/pan/phase language recurs in 8 of 58 professional cases. This supports
  mandatory translation checks, not a universal preference for wider audio.
- Wilson and Fazenda's 2013 perceptual study was fully reviewed and found only
  weak-to-moderate single-feature relationships under a small, content-confounded
  listening design. A zero-lag width proxy is not a quality target.

### Strongly established and processor-specific

Direction Mixer must be told whether input is LR or encoded MS. In LR mode,
Spread 1 is neutral, 0 routes the summed mono signal to both outputs, and values
above 1 extend the base. In MS mode, Spread changes Side level and 2 yields Side
only. Direction rotates the center/middle; extreme angles can swap sides. Split
mode provides separate high/low Direction and Spread around a crossover.

Correlation Meter displays a time-varying value from -1 to +1. Apple documents +1
as identical/in-phase mono, negative values as possible mono-cancellation risk,
and -1 as identical opposite polarity that cancels completely in mono. Its reaction
time changes display update behavior. The manual's statement that 0 is the “widest
permissible” divergence is an overgeneralization: correlation depends on content,
window, frequency, delay, and level and cannot substitute for the actual mono sum.

### Decision dimensions and preservation checks

| Dimension | Plausible consequence | Required counter-check |
|---|---|---|
| LR versus MS mode | Interprets the same two channels under different matrices | Confirm encoding; wrong mode changes image and level rather than “fixing” it |
| Spread | Narrows/widens LR or changes Side gain in MS | Mono render, center level, low-side energy, peak/loudness, image stability, and headphones/speakers |
| Direction | Rotates the stereo base/middle and can swap sides | Perspective/channel identity, focal position, edge clipping, and automation |
| Frequency split | Applies different width/direction above/below crossover | Crossover artifacts, low-end center, moving notes, and mono translation by band |
| Correlation reaction | Changes how quickly risk is displayed | Transient versus sustained behavior; never treat meter persistence as processing |

For synth width, Direction Mixer competes with patch unison/modulation, panning,
independent layers, delay/reverb, M/S EQ, and no action. For drum overheads, piano,
or stereo guitar, microphone spacing/timing and channel balance may be causal. For
bass/full mix, protect the low center but do not impose a fixed mono cutoff. A
negative moment may be intentional; a positive average may still hide narrow-band
or delayed mono cancellation.

Stop when the requested image change survives actual mono audition and preserves
the focal source and low end. Reject level-biased width, center loss, swapped
perspective, unstable localization, low-frequency cancellation, or a plan justified
only by making the correlation number “better.”

### TrackSmith must not say

- “Positive correlation means mono compatible.”
- “Zero is the ideal or maximum safe width.”
- “Spread above 1 is automatically bad.”
- “Direction Mixer corrects microphone phase.”
- “A mono sum and a correlation meter are the same test.”

## Pitch Correction

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; complete Pitch
  Correction section, pages 300-304, reviewed, including scale grids, excluded/
  bypassed notes, neural/manual pitch range, response, tolerance, reference tuning,
  detune, automation, and unsupported source conditions.
- de Cheveigne and Kawahara, *YIN, a Fundamental Frequency Estimator for Speech
  and Music*, JASA 111(4), 2002, SHA-256
  `0055503a04be6b1453eaf0a768c90d123adb004643a1421e0a542155c6778344`;
  full-read. It supports qualified monophonic periodicity/pitch evidence but does
  not define desired intonation or Logic's correction algorithm.

### Strongly established and processor-specific

Pitch Correction quantizes detected input pitch to an allowed scale/chord grid.
Root, scale, edit-scale exclusions, bypassed notes, Response, Tolerance, pitch
range/neural detection, global/reference tuning, and output Detune are distinct
decisions. Scale and Root can be automated. Polyphonic choirs and strongly noisy/
percussive material are explicitly outside normal corrective use.

Response trades correction speed against preservation of portamento/glides;
Tolerance defines a no-correction zone that can preserve vibrato and local pitch
variation. Excluding a pitch from the grid forces nearby input elsewhere; bypassing
that pitch leaves it uncorrected. They are not the same operation. Apple's claim
that moderate corrections are nearly artifact-free and preserve breath is not a
guarantee across singers, rates, consonants, vibrato, or material until measured
and heard.

### Source-aware hypotheses and preservation

| Evidence/decision | Required interpretation |
|---|---|
| Reliable monophonic pitch track | Candidate evidence only; confirm source is sufficiently periodic and the intended note/key is known |
| Scale/root | Musical context, borrowed notes, modulation, blue notes, harmony, and project tuning can invalidate a simple key label |
| Response | Preserve or intentionally quantize scoop, portamento, note transitions, and rhythmic onset |
| Tolerance | Preserve vibrato, expressive drift, and human variation while addressing distracting sustained offsets |
| Note exclusion/bypass | Decide whether a pitch is forbidden as a target or intentionally untouched |
| Reference/detune | Distinguish global source offset, alternate tuning, choir spread, and creative detune |

Vocal correction competes with comping, a better performance, region/Flex Pitch
editing, selective automation/bypass, reference-tuning change, harmonization, and
no action. Monophonic bass, guitar, or synth may be candidates when pitch confidence
and musical intent are reliable; polyphony, distortion, pitch bends, unpitched
attacks, and layered modulation weaken the evidence. Full mixes and drum buses are
not corrective pitch targets.

Stop when the distracting intonation is resolved while the performance still
phrases like the performer. Reject wrong-note snaps, stepped glides, flattened
vibrato, consonant artifacts, formant/identity damage, unstable octave errors, or a
plan that treats detected frequency as intended harmony.

### TrackSmith must not say

- “The pitch detector knows what note the singer intended.”
- “The project key defines every valid note.”
- “Neural Pitch Detection is always more accurate.”
- “Perfectly centered pitch is more professional.”
- “Moderate correction is artifact-free or always preserves breath.”

## Enveloper

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; complete Enveloper
  section, pages 97-99, reviewed.
- Giannoulis, Massberg, and Reiss compressor sources establish the importance of
  detector and time-constant definitions but do not characterize Enveloper's
  private envelope detector.
- Transient/envelope language recurs in 18 of 58 professional cases. The examples
  support attack and sustain as separate perceptual dimensions, not a universal
  “punch” setting.

### Strongly established

Enveloper separately boosts or attenuates detected Attack and Release phases with
independent Gain and Time controls, plus Threshold, Lookahead, and Out Level.
Apple says operation is independent of absolute input level only when Threshold is
at its minimum; raising Threshold restricts processing to events above it. Release
boost also raises recorded room/reverb and noise. Lookahead pre-reads events and
can require compensating the Attack time.

Apple's suggested 20 ms Attack and 1500 ms Release are starting-point practice,
not definitions or defaults for every source. The suggestion that attack removal
can mask bad timing is a creative use, not timing correction or performance repair.

### Source-aware hypotheses and checks

Attack boost may support drum snap, bass/guitar pick definition, or a synth onset;
attack attenuation may soften percussion or a hard consonant. Release boost may
expose body, room, sustain, or noise; release attenuation may tighten a loop or dry
an already reverberant source. On full mixes, event overlap makes attribution weak
and local source processing is normally a competing strategy.

Every candidate must check leading-edge overshoot, crest/peak, low-frequency
periods, cymbal/consonant harshness, groove, room/noise lift, tail truncation,
polyphonic overlap, output compensation, and level-matched bypass. Enveloper
competes with compressor timing, transient shaping, gate/expander, clip automation,
source ADSR/editing, saturation, and no action. Stop when the intended attack or
sustain relationship is audible without changing the other preserved dimension.

### TrackSmith must not say

- “More attack equals more punch.”
- “Enveloper is input-level independent” without the Threshold condition.
- “Release means the same thing as reverb time.”
- “Lookahead improves transients without latency or shape consequences.”
- “20 ms/1500 ms is the correct starting point for all material.”

## Linear Phase EQ

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; complete Linear
  Phase EQ section, pages 119-125, and shared Channel EQ parameters reviewed.
- Automatic-EQ research and the Channel EQ source record above apply only to the
  bounded question of source-conditioned parametric control; they do not establish
  that linear phase is preferred.

### Strongly established and disputed language

Linear Phase EQ shares Channel EQ's eight bands and can transfer settings to/from
Channel EQ. Apple documents fixed CPU use regardless of active bands, greater
latency, phase preservation, and altered transient onset—especially for steep cuts
or large, narrow boosts/cuts. Thus “preserves phase” does not mean “preserves the
waveform” or “preserves transients.” Apple's “high-quality” label is product
language, not comparative perceptual evidence.

Linear phase can be a candidate when relative phase among parallel/multimicrophone
paths is an explicit constraint, or when a mastering move needs comparison against
minimum-phase behavior. Channel EQ may be preferable when latency, onset behavior,
or the phase coloration itself serves the source. Settings copied between them
match exposed parameters, not audible output or temporal behavior.

Test impulse/onset response, pre-event energy, latency/compensation, steep/narrow
curves, linked tracks, parallel paths, bypass, mono/stereo/M/S behavior, and project
rate. Stop at the smallest curve meeting the tonal goal. Reject a candidate whose
phase plot looks tidy but whose attack smears/rings, whose latency breaks monitoring
or parallel alignment, or whose appeal is output gain.

### TrackSmith must not say

- “Linear phase is higher quality, transparent, or mastering-grade by definition.”
- “No phase shift means no temporal artifact.”
- “Copied Channel EQ settings sound identical.”
- “Linear Phase EQ fixes multimicrophone timing.”
- “Mastering should use linear phase.”

## Loudness Meter and MultiMeter

### Source record

- Apple, *Logic Pro Effects for Mac*, immutable payload above; Loudness Meter
  pages 181-182 and complete MultiMeter pages 182-188 reviewed.
- ITU-R BS.1770-5, EBU R 128 s2 (06/2023), EBU Tech 3341 v4 (11/2023), and EBU
  Tech 3342 v2.0 (01/2016) were read from untouched official payloads. TrackSmith's
  own implementation traceability remains in `docs/LOUDNESS_STANDARDS_TRACEABILITY.md`.
- Logic-native meter transfer/update/reset behavior has not completed the direct-
  host campaign; documentary claims are not silently promoted to conformance.

### Strongly established and documentary contradiction

Logic Loudness Meter exposes Momentary, Short-term, Integrated, a target line,
LU Range, Start/Pause, Reset, and resizable views. Apple says it conforms to EBU
R 128. The manual does not supply its exact gating, window alignment, channel
scope, percentile, true-peak, or conformance vectors, so TrackSmith records the
claim but does not independently certify the plug-in.

MultiMeter combines a 31-band third-octave or 63-band major-second Analyzer,
Peak/Slow RMS/Fast RMS display modes, LR/mono/max views, a goniometer, level/RMS/
interpolated True Peak displays, short-term/integrated loudness fields, correlation,
peak hold/reset, and display reaction controls. Its goniometer Auto Gain changes
only the display, never audio.

The manual twice says MultiMeter loudness conforms to **AES 128** while the
dedicated meter says **EBU R 128**. No normative AES 128 loudness specification
was identified. This is retained as an apparent Apple editorial error; normative
behavior comes from ITU/EBU primary sources and direct vectors, not the label.

### Measurement interpretation and stopping

| Readout | What it can support | What it cannot decide |
|---|---|---|
| Momentary/Short-term/Integrated | Level trajectory at different aggregation scales when the implementation is known | Artistic balance, “professional” loudness, or how much compression/limiting to apply |
| LU Range/LRA | Distributional programme-loudness variation under its specified method | Microdynamics, punch, crest, emotion, or quality; short material is unstable |
| True Peak | Estimated inter-sample peak under the meter's interpolation | Guaranteed codec/SRC margin or standards conformance without vector evidence |
| RMS/Peak | Energy-like and sample/level evidence | Human loudness by itself; the manual's “RMS ears” shorthand is not BS.1770 |
| Analyzer | Coarse band-level distribution and changes | Mud, harshness, masking, resonance, or correct EQ without context |
| Goniometer/correlation | Stereo relationship and possible mono risk | Desirable width or actual mono translation without rendering/listening |

Use meters to verify an explicit question: level-matched A/B, headroom, delivery,
section trajectory, stereo risk, or a measured constraint. Reset/start/pause scope
and the observation interval are part of the evidence. Cross-check Logic readouts
against TrackSmith's supported standards path before citing compliance. Stop
measuring when the defined question is answered; do not optimize the song toward a
display target that the user never requested.

### TrackSmith must not say

- “Logic's meter is independently proven EBU/ITU conformant.”
- “AES 128 is the governing loudness standard.”
- “RMS is perceived loudness.”
- “LRA measures punch or preserved musical dynamics.”
- “A spectrum, goniometer, correlation, LUFS, or true-peak number proves quality.”

## Channel EQ and Compressor interaction

EQ before compression changes the detector input and can cause one band to drive
gain reduction; EQ after compression changes the result without changing what the
detector saw. A filtered side chain can alter detection while leaving the audible
path full-band. Compression before EQ can stabilize a moving tone but may also make
a static curve seem more consistent than the original performance. Neither order is
universally correct.

TrackSmith hypotheses must record order and reason. Examples:

- “Clearer without brighter” may favor level/arrangement, a bounded contextual
  low-mid cut, or dynamic control of a masking event—not a high shelf.
- “Punchier, not louder” may compare transient-preserving compression, Enveloper,
  saturation, or no action, all output-matched.
- “Controlled but keep the dynamics” may use local rides, a low-ratio/soft-knee
  candidate, parallel/serial bounded stages, or clarification about macro versus
  micro dynamics.
- “Warm but not dark” may compare low-mid balance and harmonic density while
  prohibiting air loss; neither EQ nor compression is automatically required.

Those are competing production hypotheses. Listening remains decisive, and only
TrackSmith's validated deterministic graph may execute audio changes.
