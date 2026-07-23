# TrackSmith Logic Pro 12.3 Tool and Effect Atlas

Status: living deep-review synthesis, started 2026-07-15; complete technical
pass of the 390-page Effects guide finished 2026-07-15. This document is an
engineering and production-decision atlas, not a replacement for Apple's
manuals and not evidence that TrackSmith can directly control Logic's native
plug-ins. The machine-readable source index explicitly labels indexing as
different from deep review.

## Epistemic rules

1. Apple documentation is authoritative for exposed Logic behavior, parameter
   names, routing, and documented constraints. Apple's descriptive adjectives
   and suggested genres are professional-practice heuristics, not acoustic laws
   or controlled perceptual findings.
2. A documented model name does not reveal Apple's internal implementation.
   Claims such as exact transfer curve, filter order, oversampling, alias level,
   phase response, or component emulation require measurement or an additional
   primary source.
3. Signal-flow consequences derived from established DSP are labeled **derived
   technical interpretation**. They are not quoted Apple behavior.
4. A tool can support several opposing outcomes. For example, a delay can make a
   source feel wider, more distant, denser, more rhythmic, or less intelligible.
   Source, routing, time, spectrum, feedback, level, and context decide which.
5. TrackSmith must never translate a production adjective into one fixed Logic
   preset. It should select a hypothesis, state preservation risks, create
   alternatives where useful, and leave subjective listening decisive.

## Immutable source set

The four Apple-copyright PDFs are retained as local-use-only internal references
under the repository's fail-closed ingestion contract. No redistribution or
training rights are inferred.

| Source | Pages | SHA-256 | Review role |
|---|---:|---|---|
| Apple, *Logic Pro Effects for Mac* | 390 | `b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819` | Effects, amps, pedals, MIDI processors, meters, utilities |
| Apple, *Logic Pro Instruments for Mac* | 752 | `fc867e61b1bbcfc16d4ba98058f7cde104ec17e0649026769c308cff07049ab4` | Instruments, synthesis, sampling, modulation, built-in instrument effects |
| Apple, *Logic Pro User Guide for Mac* | 1324 | `aa016d18d7e4f3559cdec54a99937d00b379617fee87510db1ec9853a4996cff` | Project, editing, recording, automation, mixing, bounce, host workflow |
| Apple, *Control Surfaces Support Guide for Logic Pro* | 220 | `5ab5e4ef38e9c8e9279a0a2d36dcaabd1a9471942843d0162a3016f6ebf9322c` | Control mapping, automation behavior, supported surfaces |

The generated
`research/knowledge/logic-pro-12.3-manual-index.json` covers all 2,686 pages
and 2,662 unique PDF-outline entries with document hash, page location, and
outline path. Its status is `source_index_only_not_deep_review_evidence`.

## Review ledger

`Deep` means the actual relevant pages, parameters, signal flow, advice, and
limitations were read. `Synthesized earlier` refers to the exact same Effects
payload already reviewed in `TRACKSMITH_DEEP_SOURCE_SYNTHESIS.md`. `Indexed`
means only that every outline location is available; it is not a comprehension
claim.

| Effects family | Pages | Current status |
|---|---:|---|
| Effects overview and plug-in operations | 7-11 | Deep |
| Amp Designer | 12-25 | Deep |
| Bass Amp Designer | 26-35 | Deep |
| Pedalboard and all Stompboxes | 36-56 | Deep |
| Delay | 57-77 | Deep |
| Distortion | 78-86 | Deep |
| Dynamics | 87-111 | Deep |
| Equalizers | 112-138 | Deep |
| Filters | 139-165 | Deep |
| Imaging | 166-172 | Deep |
| Mastering Assistant | 173-177 | Deep |
| Metering | 178-196 | Deep and cross-checked against ITU/EBU sources |
| MIDI plug-ins | 197-242 | Deep |
| Modulation | 243-261 | Deep |
| Multi-effects | 262-299 | Deep |
| Pitch | 300-308 | Deep |
| Algorithmic reverb | 309-330 | Deep |
| Space Designer | 331-350 | Synthesized earlier from actual pages |
| Specialized | 351-354 | Deep |
| Utilities | 355-364 | Deep |
| Legacy | 365-389 | Deep |
| Instruments guide plus Quick Sampler supplement | PDF 1-752 plus 16 canonical web sections | Deep complete; see `TRACKSMITH_LOGIC_PRO_12_3_INSTRUMENT_ATLAS.md` |
| User guide | 1-1324 | Deep complete; see `TRACKSMITH_LOGIC_PRO_12_3_WORKFLOW_ATLAS.md` |
| Control surfaces | 1-220 | Deep complete; see `TRACKSMITH_LOGIC_PRO_CONTROL_SURFACES_ATLAS.md` |

## Canonical Logic effects inventory

This is the complete named top-level inventory in the 390-page Effects guide.
Compound tools such as Amp Designer, Pedalboard, Delay Designer, Compressor,
Channel EQ, Beat Breaker, ChromaVerb, and Space Designer have many subordinate
sections captured in the machine index.

- Amps and pedals: Amp Designer, Bass Amp Designer, Pedalboard, Stompboxes.
- Delay: Delay Designer, Echo, Sample Delay, Stereo Delay, Tape Delay.
- Distortion: Bitcrusher, ChromaGlow, Clip Distortion, Distortion, Distortion II,
  Overdrive, Phase Distortion.
- Dynamics: Adaptive Limiter, Compressor, DeEsser 2, Enveloper, Expander,
  Limiter, Multipressor, Noise Gate, Surround Compressor.
- EQ: Channel EQ, Linear Phase EQ, Match EQ, Single Band EQ, Vintage Console
  EQ, Vintage Graphic EQ, Vintage Tube EQ.
- Filter: AutoFilter, EVOC 20 Filterbank, EVOC 20 TrackOscillator, Fuzz-Wah,
  Spectral Gate.
- Imaging: Binaural Post-Processing, Spatial Audio Monitoring, Direction Mixer,
  Stereo Spread.
- Mastering: Mastering Assistant.
- Metering: BPM Counter, Correlation Meter, Level Meter, Loudness Meter,
  MultiMeter, Surround MultiMeter, Tuner.
- MIDI: Arpeggiator, Chord Trigger, Modifier, Modulator, Note Repeater,
  Randomizer, Scripter, Transposer, Velocity Processor, Record MIDI to Track.
- Modulation: Chorus, Ensemble, Flanger, Microphaser, Modulation Delay, Phaser,
  Ringshifter, Rotor Cabinet, Scanner Vibrato, Spreader, Tremolo.
- Multi-effects: Beat Breaker, Phat FX, Remix FX, Step FX.
- Pitch: Pitch Correction, Pitch Shifter, Vocal Transformer.
- Reverb: ChromaVerb, EnVerb, Quantec Room Simulator, SilverVerb, Space
  Designer.
- Specialized: Exciter, SubBass.
- Utilities: Auto Sampler, Down Mixer, Gain, I/O, Multichannel Gain, Test
  Oscillator.
- Legacy: AVerb, Bass Amp, DeEsser, Denoiser, Ducker, legacy EQ, GoldVerb,
  Grooveshifter, Guitar Amp Pro, PlatinumVerb, Silver Compressor, Silver Gate,
  Speech Enhancer.

## Signal-chain model for production decisions

Every Logic processing recommendation should answer these questions before it
names a tool:

1. **What enters the processor?** Source role, level distribution, spectrum,
   transient/sustain behavior, channel format, and prior processing determine
   the outcome.
2. **Is the operation linear, time-varying, or nonlinear?** Static gain and EQ,
   modulation/dynamics, and saturation/distortion have different interaction,
   aliasing, phase, and level risks.
3. **Where is it in the graph?** EQ before distortion changes which frequencies
   drive the nonlinearity; EQ after distortion shapes both source and generated
   harmonics. Compression before an amp or fuzz changes the drive envelope;
   compression afterward controls the resulting envelope and noise. Delay or
   reverb before distortion saturates their repeats/tails; after distortion it
   preserves a clearer separation between dry attack and ambience.
4. **Is it serial, parallel, split-band, or Mid/Side?** These topologies are not
   interchangeable. Parallel processing can preserve dry transients but can
   create phase/latency interactions. A frequency split changes the source seen
   by each branch. Mid/Side changes center versus lateral energy, not simply
   “width.”
5. **What should remain unchanged?** Level, low-end weight, consonants, pick
   attack, cymbal smoothness, groove, stereo motion, mono compatibility, noise,
   and existing character are explicit constraints.
6. **How is it evaluated?** Level-match, bypass, listen in context and solo,
   inspect peak/nonfinite safety, and run source-specific preservation checks.
   Objective measurements reject unsafe or constraint-violating candidates;
   they do not prove artistic superiority.

## Pedalboard architecture

### Documented behavior

- Signal travels left to right through the Pedal area.
- Pedalboard supports serial processing plus two discrete buses, A and B.
- A Splitter can send the same signal to both buses or divide it by frequency;
  the Mixer can solo A, mix A/B, or solo B, set their relationship, and pan each
  bus.
- Moving the split or mix point changes which pedals are before, within, or
  after the parallel portion of the graph.
- In mono-to-stereo instances, modulation pedals and the Mixer can change the
  downstream bus between mono and stereo. This is a material routing state, not
  a cosmetic setting.
- All pedal knobs, switches, and sliders can be automated. Eight Macro targets
  can each map to an inserted pedal parameter.
- Individual stompboxes can also be inserted directly in channel-strip effect
  slots. Imported pedal settings are distinct from whole-Pedalboard settings.

### Derived design consequences

- A dry/wet parallel branch should be level-matched and checked for combing,
  polarity, and mono loss. “Parallel” does not guarantee transparent blending.
- Frequency-split distortion can retain low-frequency fundamentals on one bus
  while adding upper-band harmonics on the other, but the crossover region and
  recombination must be auditioned for tonal discontinuity and phase effects.
- A stereo-producing modulation pedal before a later mono transition loses the
  lateral information it created. TrackSmith must inspect the entire downstream
  path, not just the chosen pedal.
- Macro automation is useful for expressive sweeps and transitions, but it is a
  user-controlled/Logic automation workflow; it is not authority for TrackSmith
  to emit arbitrary automation.

## Complete Pedalboard stompbox atlas

The following “effect on sound” descriptions separate documented control
behavior from production interpretation. Exact internal circuit transfer
functions remain unspecified by Apple.

### Delay and ambience pedals

| Pedal | What changes | Critical controls and interactions | Main risks/checks |
|---|---|---|---|
| Blue Echo | Adds tempo-free or tempo-synced repeats; a fixed filter biases repeat spectrum. | Time, Repeats, Mix, Lo/Hi/Off Tone Cut, Mute, Sync. Mute passes dry signal while existing repeats continue. | Feedback density can mask rhythm or words; match level and check repeat timing in context. |
| Spring Box | Adds algorithmic spring-style reverberant energy. | Short/medium/long Time, Tone cutoff, Boutique/Simple/Vintage/Bright/Resonant Style, Mix. | Bright/resonant modes can emphasize pick noise or sibilance; long settings can blur articulation. |
| Tie Dye Delay | Reverses delayed material, with feedback and spectral shaping. | Time/Sync, Feedback, Tone, fixed Bright/Dark EQ, Mix, Listen tail behavior. | Reverse attacks can pre-echo or obscure the source rhythm; feedback can accumulate. |
| Tru-Tape Delay | Adds normal or reverse tape-style repeats with bandwidth limiting, saturation, and time instability. | Lo/Hi Cut, Dirt, Flutter, Time/Sync, Feedback, Mix. Feedback automation can build self-reinforcing dub effects. | Dirt changes both repeat tone and dynamics; high feedback can become unstable/loud; flutter can compromise pitch focus. |

### Distortion pedals

| Pedal | What changes | Critical controls and interactions | Main risks/checks |
|---|---|---|---|
| Candy Fuzz | Bright, aggressive fuzz through input drive and output level. | Drive controls how hard the nonlinear stage is hit; Level is not a substitute for Drive. | Added upper harmonics, aliasing/noise, and reduced transient contrast; level-match. |
| Double Dragon | Combines saturation, compression, nonlinear contour, tone, parallel blend, and fixed Bright/Fat shelving. | Input and Drive jointly set operating point; Squash changes dynamics; Contour changes distortion; Mix restores dry signal. | Many controls are coupled. A louder/brighter result can masquerade as better; inspect envelope and preserved low end. |
| Fuzz Machine | Adds American-style fuzz; Tone simultaneously raises treble and reduces lows. | Fuzz, Level, Tone. | Tone is a tilt-like tradeoff, not independent treble gain; can thin a guitar or expose noise. |
| Grinder | Adds driven, filtered, lo-fi metal distortion with optional mid/tonal scoop. | Grind, harshness/crunch Filter, Level, Full/Scoop fixed Gain/Q setting. | Scoop can reduce audibility in a dense mix despite sounding large in solo; high Filter can become painful. |
| Grit | Uses separate input and output drive around a harsh/crunch filter. | Volume drives input, Filter changes edge, Distortion drives output. | Two drive locations make gain staging decisive; easily obscures keyboard voicing or guitar articulation. |
| Happy Face Fuzz | Adds softer, fuller fuzz with minimal controls. | Fuzz, Volume. | “Softer” is relative to the family, not transparent; bass buildup and intermodulation still require checking. |
| Hi-Drive | Overdrives either a high-frequency portion or the full-range signal. | Treble/Full selects processing range; Level controls output. | Treble mode can intensify hiss, pick edge, cymbals, or sibilance; Full can alter low-end definition. |
| Monster Fuzz | Adds high saturation with independently adjustable input gain, saturation, tonal color, texture, grain, and output. | Roar, Growl, Tone, Texture, Grain, Level. Higher Tone also lowers overall volume according to the manual. | Coupled tone/level invites biased comparisons; nonlinear texture can destroy note separation. |
| Octafuzz | Adds fat fuzz with integrated high-pass tone shaping. | Fuzz, Level, high-pass Tone cutoff. | Raising cutoff removes fundamental/body while generated harmonics remain; verify intended weight. |
| Rawk! Distortion | Adds metal/hard-rock saturation with a brightness control. | Crunch, Level, Tone. | Bright high-gain settings can amplify fizz and fatigue; context and level matching are essential. |
| Tube Burner | Combines tube-style drive, crossover-bias control, compression, multi-band tone shaping, and optional bass enhancement. | Fat, Low, Mid Freq/Gain, High, Tone, Bias, Squash, Drive, Output. | Bias can intentionally introduce crossover distortion; Fat and low EQ can overload downstream stages; Squash may erase playing dynamics. |
| Vintage Drive | Adds FET-described overdrive with Tone and optional low-frequency enhancement. | Drive, Tone, Fat, Level. | Apple's “warmer than bipolar” description is a model heuristic, not a universal semiconductor law; verify spectrum/envelope. |

### Dynamics and filter pedals

| Pedal | What changes | Critical controls and interactions | Main risks/checks |
|---|---|---|---|
| Squash Compressor | Reduces signals above a Sustain/threshold setting, then applies output gain. | Sustain, Level, Fast/Slow Attack source mode. | The manual exposes no ratio/release/meter, so behavior must be auditioned; added sustain can raise noise and reduce transient contrast. |
| Auto-Funk | Moves a band-pass or low-pass filter in response to input level. | Sensitivity threshold, Cutoff, BP/LP, preset resonance Hi/Lo, upward/downward modulation. | Performance level becomes modulation control; inconsistent input dynamics can produce inconsistent tone. |
| Classic Wah | Manually sweeps filter cutoff with the pedal. | Footpedal position and bypass. | Narrow resonant sweeps can create large peaks; automation timing is part of the performance. |
| Graphic EQ | Applies seven fixed-band boosts/cuts plus output level. | Seven frequency sliders and Level. | Adjacent broad bands interact; boosts change headroom into later drive stages. |
| Modern Wah | Sweeps a more aggressive wah response or volume, with adjustable resonance. | Pedal, Q, Wah/Volume Mode. | High Q produces narrow pronounced peaks; Volume mode is amplitude control rather than spectral wah. |

### Modulation pedals

| Pedal | What changes | Critical controls and interactions | Main risks/checks |
|---|---|---|---|
| Flange Factory | Modulates short delay to create moving comb filtering, with waveform, symmetry, curve, feedback, and bandwidth control. | Rate/Sync, Depth, Resonance, Mix, Wave, Symmetry, Curve, Manual delay, Low/High cutoffs. | Feedback and Manual can become metallic; stereo/mono routing and mono fold-down require checks. |
| Heavenly Chorus | Adds modulated voices to thicken and potentially stereo-spread the source. | Rate/Sync, Depth, fixed Bright EQ, Feedback, Density dry/effect relationship. | Feedback can create intermodulation; chorus can soften pitch center and mono definition. |
| Phase Tripper | Sweeps phase-derived notches, with feedback. | Rate/Sync, Depth, Feedback. | Can hollow out essential bands or disappear/change on mono summing. |
| Phaze 2 | Combines two independently bounded phasers. | Two Rates, Floor/Ceiling ranges, filter Order, Feedback, Tone; LFO mix and Sync. | Overlapping sweeps can become highly nonstationary; higher even order is heavier, odd order subtler per Apple, but exact response remains undocumented. |
| Retro Chorus | Adds a restrained chorus with rate and depth. | Rate/Sync, Depth. | Even subtle modulation can compromise mono compatibility or pitch stability on bass. |
| Robo Flanger | Adds flanging with feedback and a manual base delay. | Rate/Sync, Depth, Feedback, Manual. | High feedback plus short delay can create resonant metallic peaks. |
| Roswell Ringer | Ring-modulates/frequency-shifts content, creating sum/difference components that can sound metallic, tremolo-like, brighter, or unrecognizable. | Linear/exponential curve, Freq, Fine, Feedback, Mix. | Generally inharmonic sidebands can destroy tonal identity; low frequencies may act more like tremolo. |
| Roto Phase | Adds phase movement with a fixed-EQ “Vintage” option. | Rate/Sync, Intensity, Vintage/Modern. | The style switch includes EQ, so a preference may be tonal rather than modulation-specific. |
| Spin Box | Emulates a rotating-speaker cabinet with acceleration/braking, cabinet tone, drive, and horn brightness. | Cabinet, Fast Rate, Response inertia, Drive, Bright, Slow/Brake/Fast. | Movement, distortion, brightness, and stereo behavior are coupled; speed transitions must fit phrasing. |
| The Vibe | Provides three vibrato and three chorus variations derived from scanner-vibrato behavior. | Rate/Sync, Depth, V1-V3/C1-C3 Type. | Vibrato changes pitch; chorus mixes/modifies voices. They should not be treated as interchangeable “movement.” |
| Total Tremolo | Modulates amplitude with variable waveform and controllable acceleration. | Rate/Sync, Depth, Wave, Smooth, Volume, half/double/accelerate/decelerate controls. | Deep or sharp modulation can erase attacks or conflict with groove; post gain can bias audition. |
| Trem-O-Tone | Applies simple cyclic amplitude modulation. | Rate/Sync, Depth, Level. | Tremolo is level modulation, not pitch vibrato; verify rhythmic phase and audibility in context. |

### Pitch pedals

| Pedal | What changes | Critical controls and interactions | Main risks/checks |
|---|---|---|---|
| Dr. Octave | Adds two octave-shifted voices plus optional output overdrive. | Octave 1/2 levels, Direct balance, Drive. | Tracking/artifact behavior depends on source; added sub-octaves can overload low end and lose definition on chords. |
| Wham | Continuously pitch-shifts under pedal control and blends shifted/direct signals. | Pedal position, Tune, Mix. | Formants/timbre, transient smear, polyphonic tracking, and automation gestures require listening; mixed paths can create beating. |

### Utility pedals

| Utility | What it does | Production consequence |
|---|---|---|
| Splitter | Routes equally to both buses or sends lows to A and highs to B around a chosen frequency. | Enables parallel and split-band pedal designs; crossover/recombination and branch gain must be checked. |
| Mixer | Solos A/B or blends them, sets relationship/level, pans each bus, and can change mono/stereo state in mono-to-stereo instances. | It defines where branches recombine. Moving it changes graph topology; pan and mode can materially affect mono compatibility. |

## Amp Designer

### Complete model inventory

Amp Designer exposes more than 20 modeled combinations, but it also lets the
amp, cabinet, EQ, microphone, microphone position/distance, integrated reverb,
tremolo/vibrato, and gain stages be recombined. The documented models are:

- Tweed: Small Tweed Combo, Large Tweed Combo, Mini Tweed Combo.
- Classic American: Large Black Panel Combo, Silver Panel Combo, Mini Black
  Panel Combo, Small Brown Panel Combo, Blues Blaster Combo.
- British stacks: Vintage British Stack, Modern British Stack, Brown Stack.
- British combos: British Blues Combo, British Combo, Small British Combo,
  Boutique British Combo.
- British alternatives: Sunshine Stack, Small Sunshine Combo, Stadium Stack,
  Stadium Combo.
- Metal: Modern American Stack, High Octane Stack, Turbo Stack.
- Additional/utility: Studio Combo, Boutique Retro Combo, Pawnshop Combo,
  Transparent Preamp.

Cabinets: Tweed 1x12, Tweed 4x10, Tweed 1x10, Black Panel 4x10, Silver Panel
2x12, Black Panel 1x10, Brown Panel 1x12, Brown Panel 1x15, Vintage British
4x12, Modern British 4x12, Brown 4x12, British Blues 2x12, Modern American
4x12, Studio 1x12, British 2x12, British 1x12, Boutique British 2x12,
Sunshine 4x12, Sunshine 1x12, Stadium 4x12, Stadium 2x12, Boutique Retro
2x12, High Octane 4x12, Turbo 4x12, Pawnshop 1x8, and Direct.

Microphones: Condenser 87, Condenser 414, Dynamic 20, Dynamic 57, Dynamic
421, Dynamic 609, and Ribbon 121. EQ circuits: British Bright, Vintage, U.S.
Classic, Modern, and Boutique. Integrated ambience includes ten spring/modern
reverb types; modulation can be tremolo (amplitude) or vibrato (pitch).

### Production model

- Gain controls preamplifier drive. Master sends the amp stage into the cabinet
  and, for tube-described models, can add compression/saturation as well as
  level. Output is a separate final trim. These three controls are not
  interchangeable.
- Amp EQ circuits differ in target frequencies, gain, and interaction with the
  modeled amp. Apple explicitly notes that some EQs amplify the signal enough
  to alter distortion. Therefore a Bass/Mids/Treble value has no universal
  meaning across EQ types.
- Cabinet choice changes resonant coloration and phase structure. Open-back and
  closed-back, old/new speaker, speaker size, and multiple-speaker interaction
  are candidate explanations, not guarantees of a subjective adjective.
- Microphone model, axis position, and distance are part of tone design. Apple's
  model documents center/on-axis as fuller/more powerful, rim/off-axis as
  brighter/thinner, and closer placement as more bass-emphasized. This differs
  from simplified generic microphone folklore and must be treated as behavior
  of this modeled coordinate system, not a universal real-microphone rule.
- The integrated effects receive the preamplified, pre-Master signal and occur
  before Presence and Master. This placement matters: their output is affected
  by the master-stage behavior.

## Bass Amp Designer

### Complete architecture inventory

- Amp models: Classic Amp with 8x10, Flip Top Amp with 1x15, Modern Amp with a
  three-way array.
- Cabinets: Modern 15, 10, and 6; Classic 8x10; Flip Top 1x15; Modern three-way;
  Direct PowerAmp Out; Direct PreAmp Out.
- Microphones: Condenser 87, Dynamic 20, Dynamic 421.
- Processing: model-dependent passive/active amp EQ, Hard/Soft bass compressor
  with always-on AutoGain, switchable graphic or two-band parametric EQ, and a
  six-curve modeled DI tone section.

### Production model

- The amp and DI are parallel whenever Blend is not fully left or right. The
  chosen Direct/cabinet mode changes which amp stages remain. This enables clean
  fundamental plus colored amp designs, but branch alignment and level must be
  auditioned.
- The additional EQ can be pre- or post-compressor. Pre-EQ changes detector/input
  emphasis and therefore the compression pattern; post-EQ shapes the compressed
  output. The manual's complete routing table must be used when all three EQ,
  additional EQ, and compressor blocks are enabled.
- The compressor's Hard/Soft names do not expose a full static curve or time
  constants. “Soft” is documented as slow attack with longer sustain; exact
  behavior requires measurement. AutoGain is always active, so a bypass
  comparison must compensate for possible loudness bias.
- DI Tone positions are fixed curves, several with broad mid scoops or sloped
  low-frequency attenuation. They are choices with arrangement consequences,
  not source-independent bass presets.

## Bitcrusher deep model

### Documented behavior

- Resolution is 1-24 bits and changes process precision. Lower settings increase
  quantization/sampling error and can leave distortion stronger than usable
  signal.
- Downsampling divides effective sample rate: 1x is unchanged, 2x halves it,
  10x makes a 44.1 kHz source effectively 4.41 kHz. It does not change playback
  speed or pitch.
- Drive increases input gain and therefore tends to increase output clipping.
- Clip Level determines where Fold, Clip, or Wrap begins and strongly changes
  all three modes.
- Mix blends dry and processed paths; the waveform display shows the selected
  nonlinearity's shape.

### Technical interpretation and limits

- Bit-depth reduction is amplitude quantization. Its error depends on signal
  amplitude and correlation; without documented dither, TrackSmith must not
  assume noise-like, signal-independent quantization error.
- Downsampling without an anti-aliasing claim creates spectral images folded
  into the retained band. Apple explicitly markets artificial aliasing here;
  this is a creative effect, not sample-rate conversion for fidelity.
- Clip is an abrupt thresholded nonlinearity. Fold and Wrap remap over-threshold
  samples differently, but Apple's prose does not provide exact equations. The
  manual says “Cut mode” twice under Clip/Wrap even though the UI exposes Clip;
  this is recorded as an apparent terminology error pending measurement.
- Drive, Resolution, Downsampling, Mode, and Clip Level interact. For example,
  lowering Resolution does not prove that a sound will become “warmer”; it may
  add coarse inharmonic error. Increasing Downsampling does not merely make a
  sound “darker”; alias products can add non-harmonic high-frequency energy.
- Safe use requires output/true-peak checks, level matching, source-role checks,
  and listening for lost intelligibility, pitch definition, transient shape,
  harsh aliases, and stereo/mono differences.

### Direct Logic 12.3 evidence status — partial, 2026-07-18

The first versioned native-host run covers only the observed Default Preset at
48 kHz mono with the amplitude-ladder fixture. Logic exposed Clip, +3 dB Drive,
8-bit Resolution, 1x Downsampling, 100% Mix, and 0 dB Clip Level. Three settled
active renders plus one post-save/reload render share one decoded-PCM hash. Three
settled bypass renders are sample-identical to the source. The processed result
reached digital full scale, raised best-fit level by approximately 2.55 dB, and
mapped the quietest ladder material to zero. These observations are compatible
with the documented controls but do not reveal Apple's exact quantizer or Clip
equation.

The first bypass and active renders after state transitions contained short
startup differences that disappeared on subsequent repeats. Consequently the
empirical protocol now retains first-transition renders and requires at least
three settled decoded-PCM repeats. Fold, Wrap, Downsampling above 1x, parameter
interactions, stereo, other rates, impulse latency/tail, automation, musical
material, and listening remain open. The authoritative run record is
`research/evaluation/logic-native-empirical-runs/logic-12.3-bitcrusher-default-2026-07-18/run.json`.

## Delay processors

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| Delay Designer | A multi-tap delay with up to 26 independently timed, filtered, pitched, panned/spread, and leveled taps; one tap can feed back. Tap high/low cut ordering can create either a passed band or a rejected band. | It can build rhythmic patterns, diffusion-like clusters, stereo motion, or pitched echoes. Tap density, feedback, and spectral accumulation can mask attacks and words. A visually complex pattern is not automatically musically useful. |
| Echo | One tempo-related delay with feedback, spectral Color, and dry/wet balance. | Appropriate when a simple repeat is clearer than a designed multi-tap field. Repeat timing and color must fit the phrase; feedback can turn a small cue into masking. |
| Sample Delay | Delays channels by a number of samples or milliseconds. | Primarily an alignment and deliberate interchannel-offset tool. It can improve multi-mic summation or create width, but the same offset can cause comb filtering and mono loss. Polarity inversion and delay are different operations. |
| Stereo Delay | Independent left/right delays with selectable input source, crossfeed, phase controls, filters, feedback, and routing modes. | Can create stable stereo echoes or cross-channel motion. Crossfeed and phase choices can build cancellation or runaway density; check both stereo and mono. |
| Tape Delay | A delay with tempo/free timing, deviation and smoothing, feedback filtering, clipping threshold, clean/diffuse head choices, LFO/flutter, spread, freeze, and dry/wet control. | Time instability, bandwidth loss, saturation, and feedback filtering can make repeats feel less literal. Those dimensions are separate: “tape” is not one tone. Freeze and high feedback require output and transition safety checks. |

## Distortion and nonlinear processors

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| ChromaGlow | A family of saturation models and style variants with drive, output/mix, a frequency-domain Bypass Below control, and pre/post low/high filtering. | Model adjectives are product descriptions, not perceptual proof. Bypass Below can leave low-frequency material outside the nonlinear path; it is not a level threshold. Filtering changes what drives the nonlinearity versus what remains afterward. Exact curves and oversampling are undocumented. |
| Clip Distortion | Input gain, drive, pre-distortion high-pass, nonlinear clipping, post-distortion low-pass, dry/effect mixing, a final low-pass, shelf shaping, and output control. | Pre-filtering changes which bands create harmonics; post-filtering removes generated energy. It is therefore not equivalent to clipping followed by one tone knob. |
| Distortion | A bipolar-transistor-described distortion with Drive, Tone/high cut, and output compensation. | Useful as a bounded harmonic-density candidate, but “bipolar” does not establish the exact circuit or transfer curve. Preserve attack, low end, and level explicitly. |
| Distortion II | Four documented circuit styles—Growl, Bity, Nasty, and Class AB soft/hard—with pre-gain, drive, tone, and mix controls. | Different styles should be treated as competing nonlinear hypotheses, not strengths of one algorithm. Class AB modes may add crossover-like character; exact implementation requires measurement. |
| Overdrive | A FET-described overdrive with Drive, Tone, and output level. | Apple's device-family description is not an acoustic guarantee. Compare against other nonlinear options at matched loudness and inspect intermodulation, noise, and transient loss. |
| Phase Distortion | A short delay whose modulation comes from a low-pass-filtered version of the input, with intensity, phase-reversal, and mix controls. | This is input-dependent delay modulation, not ordinary static waveshaping. Its motion follows source content, so percussive and sustained sources behave differently. |

The ChromaGlow filter text appears to call the Low Cut frequency a low-pass and
the High Cut frequency a high-pass. Those names conflict with the exposed control
labels and ordinary cut-filter terminology. TrackSmith records this as a likely
documentation defect and does not infer topology from those two sentences alone.

## Dynamics processors

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| Adaptive Limiter | Look-ahead peak limiting with input gain, output ceiling, an Optimal mode, DC removal, and true-peak detection. | Useful for bounded peak control, not proof of mastering quality. Gain into the limiter changes density and distortion; ceiling alone does not set loudness. |
| Compressor | Seven circuit models plus threshold, ratio, knee, attack/release, detector, channel linking, side-chain filter, make-up, parallel mix, output limiter, and distortion. | “Compression” is a family of envelope decisions. Strategy must state whether it preserves transients, increases density, controls peaks, changes sustain, or reacts to a filtered side chain. |
| DeEsser 2 | Relative or absolute detection, selectable frequency/range, split-band or wideband attenuation, and bounded maximum reduction. | Sibilance is event- and phoneme-dependent. High-frequency energy supports a hypothesis but is not a diagnosis; preserve intelligibility and breath. |
| Enveloper | Independently changes attack and release portions using detector and gain stages. | A direct candidate for snap, softness, sustain, or room emphasis. Increasing release also raises spill/noise/ambience; transient enhancement can worsen cymbals. |
| Expander | Upward expansion above a threshold with ratio, attack/release, knee, lookahead, and gain controls. | Can increase dynamic contrast and attack, but may exaggerate noise, breaths, bleed, and inconsistent performance. It is not a noise gate. |
| Limiter | Peak limiting with lookahead, release, gain/ceiling, legacy/precision behavior, and true-peak option. | A safety and density tool whose artifacts depend on release, spectral content, and amount of gain reduction. True-peak mode is not a universal delivery guarantee. |
| Multipressor | Four crossover bands, each with compression and downward-expansion behavior, plus per-band solo/bypass/gain and overall lookahead/output controls. | Band-specific dynamics can solve localized instability but crossovers and independent envelopes can change tone, phase, punch, and stereo image. Prefer simpler processing when evidence does not justify four bands. |
| Noise Gate | Gate or ducker behavior with threshold, hysteresis, reduction, attack/hold/release, lookahead, and side-chain filtering. | Hysteresis and hold reduce chatter; aggressive gating can truncate breaths, decays, and room. Ducker mode and gate mode solve different routing problems. |
| Surround Compressor | Multichannel compression with group assignments, per-group controls, peak/RMS detection choices, and LFE handling. | Channel grouping determines image stability. Independent channel compression can move the scene; linked processing can overreact to one channel. TrackSmith cannot infer an immersive strategy from a stereo capture. |

## Equalizers

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| Channel EQ | Eight bands with high/low pass, shelves and bells, spectrum analysis, output gain, oversampling, and stereo/L/R/Mid/Side modes. | General corrective and shaping tool. Analyzer peaks are evidence, not automatic cut targets. Mid/Side edits require mono and center/side preservation checks. |
| Linear Phase EQ | Similar band architecture while preserving phase relationships at the cost of latency and possible pre-ringing/transient effects. | Appropriate when phase response is the primary constraint, not automatically “better.” Steep/narrow moves can audibly change onset behavior. |
| Match EQ | Learns source and reference spectra, computes a difference curve, and permits smoothing, strength, and range control. | It matches an averaged spectral relation, not performance, dynamics, depth, arrangement, or identity. The reference must be context-compatible and the result listened to at matched level. |
| Single Band EQ | One selectable low/high cut, shelf, or parametric band. | Useful for simple bounded moves and automation. A single band can be more defensible than a complex curve when the evidence is local. |
| Vintage Console EQ | A modeled console-style EQ with drive/output behavior and band controls. | The model can couple tone and nonlinearity; control labels do not reveal exact analog transfer behavior. Treat “vintage” as a family of hypotheses. |
| Vintage Graphic EQ | Multiple fixed-frequency bands with modeled drive/output behavior. | Fast broad contouring, but adjacent bands interact and fixed centers may not match a measured issue. |
| Vintage Tube EQ | A modeled passive/tube-associated equalizer with linked boost/attenuation-style controls and output drive. | Simultaneous boost/cut interactions can create shapes unlike one bell. Use for a chosen contour/color, not because “tube” guarantees warmth. |

## Filter processors

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| AutoFilter | Envelope-followed and/or LFO cutoff modulation, state-variable and four-pole low-pass modes, resonance/self-oscillation, stereo spread, fatness, and distinct pre/post distortion. | The source envelope becomes control data. Pre-distortion changes the material seen by the filter; post-distortion colors its output. Resonance and self-oscillation demand peak checks. |
| EVOC 20 Filterbank | Two parallel 20-band formant-filter banks with crossfade, shifting, modulation, overdrive, and stereo layout. | Can morph/filter a source without a carrier vocoder. Formant shifts and resonant bands can make dramatic spectral motion, but intelligibility and level can change rapidly. |
| EVOC 20 TrackOscillator | Analysis/synthesis filter banks, unvoiced detection, monophonic pitch tracking, FM oscillator options, pitch quantization, and formant stretch/shift. | A vocoder and tracked-synthesis system, not transparent correction. Tracking is source-dependent; polyphony/noise/transients can invalidate pitch assumptions. |
| Fuzz-Wah | Wah, compressor, and fuzz blocks whose serial order can be changed. | Order is part of the sound: compression before fuzz changes drive consistency; wah before fuzz changes harmonic generation; wah after fuzz filters generated harmonics. |
| Spectral Gate | Splits spectral content around a threshold, exposes super/sub-threshold energy and modulation of center/bandwidth. | Can isolate or transform spectral strata, but Apple's prose does not fully specify the internal algorithm. Do not infer exact FFT/window/phase behavior without measurement. |

## Imaging, mastering, and metering

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| Binaural Post-Processing | Converts or conditions binaural material for speaker/headphone presentation using mode-specific crosstalk-related processing. | Playback format is part of the meaning. A binaural-to-speaker choice can alter timbre and localization; do not promise translation without the target playback condition. |
| Spatial Audio Monitoring | Monitoring-format and profile choices for spatial playback, including head tracking and music/movie modes. | This is monitoring/rendering context, not permission for TrackSmith to claim immersive source knowledge. Validation must identify monitoring format and profile. |
| Direction Mixer | LR or MS direction/width manipulation, with split high/low controls. | Changes center/lateral balance and apparent direction, not a scalar “quality.” Low-band side energy and mono-sum behavior are preservation constraints. |
| Stereo Spread | Alternates frequency bands between channels over a chosen range. | Can create apparent width from spectral redistribution. It may hollow the mono sum or destabilize low frequencies; Apple specifically warns about low-band use. |
| Mastering Assistant | Analyzes the project/cycle and offers Clean, Valve, Punch, or Transparent character, Auto EQ, dynamics/excite/width controls, loudness compensation, LUFS/LRA/peak displays, and broad three-band correction. | It is an interactive starting point, not an oracle. Apple's approximately -14 LUFS-I center is described as typical rather than best or mandatory; platform targets and artistic choices vary. Character words remain product heuristics. |

Metering tools do not all answer the same question:

| Meter | What it observes | What it cannot establish |
|---|---|---|
| BPM Counter | Estimated tempo from incoming audio. | Tempo confidence, meter, groove, subdivisions, or musical correctness for every source. |
| Correlation Meter | Time-varying interchannel correlation. | It cannot establish preferred width, spatial quality, or absence of frequency-local cancellation. |
| Level Meter | Peak and RMS-style level with selectable display behavior. | Standards loudness or perceived quality. Apple's “ears are RMS instruments” wording is pedagogical shorthand, not BS.1770. |
| Loudness Meter | Momentary, short-term, integrated loudness, range, target, and start/pause/reset measurement scope. | It does not establish universal mastering targets or complete formal conformance without external vectors. TrackSmith's own standards algorithms remain independently traceable. |
| MultiMeter | Spectrum, goniometer/correlation, peak/RMS/true-peak display, and loudness-oriented views. | It does not produce a single quality score. Its “AES 128” wording is an apparent manual error; normative claims come from EBU R 128/ITU sources. |
| Surround MultiMeter | Multichannel level, correlation, and spectrum-oriented displays. | An immersive perceptual verdict or unmeasured render/downmix safety. |
| Tuner | Fundamental/note tuning feedback for suitable input. | Reliable pitch for polyphonic, noisy, transient-only, or inharmonic sources. |

## MIDI processors and generated control

Logic's MIDI processors sit serially before the software instrument and operate
on MIDI events, not rendered audio. Their output can be captured with **Record
MIDI to Track Here** at a selected point in the chain.

| Processor | Documented operation | Production consequence and authority boundary |
|---|---|---|
| Arpeggiator | Orders held notes into patterns with latch, order, octave/inversion, rate, swing, velocity/note-length, live/grid and 16-step controls. | Converts harmony into a performance pattern. Note order, octave, gate, and swing are musical decisions, not audio-effect parameters. |
| Chord Trigger | Maps an input note or note range to learned/transposed chord output. | Useful for repeatable voicings; it can also create collisions, range problems, or unintended harmony. |
| Modifier | Transforms selected MIDI event data, including scale/add/reassign-style operations. | A bounded event mapping tool. It must not be confused with audio modulation or unrestricted scripting. |
| Modulator | LFO plus DAHR envelope generation targeting MIDI CC, aftertouch, pitch bend, or an instrument/effect parameter. | Produces time-varying control. Target range, polarity, tempo relation, and reset behavior must be explicit. |
| Note Repeater | Repeats incoming notes with timing and performance controls. | Creates rolls/retriggers; density and velocity evolution affect groove and instrument voice allocation. |
| Randomizer | Randomizes chosen event properties with range/probability and a seed. | A fixed seed makes repeatable output during bounce; changing the seed is a creative variation, not a deterministic revision unless recorded. |
| Scripter | Runs JavaScriptCore-based real-time MIDI scripts using event, timing, parameter, `HandleMIDI`, and `ProcessMIDI` APIs; scripts persist with settings/projects. | **Security-critical:** untrusted provider text must never become executable Scripter code. TrackSmith has no arbitrary-code authority. Any future scripting feature needs a separate typed DSL, static validation, resource bounds, consent, and host proof. |
| Transposer | Constrains/transposes note output by scale and root-related controls. | Useful for pitch-set mapping, but source harmony and non-note events still need explicit handling. |
| Velocity Processor | Shapes, compresses/expands, clips, adds, or randomizes note velocity. | Changes instrument articulation and sample-layer selection, not merely loudness. |
| Record MIDI to Track Here | Captures the MIDI stream after the chosen plug-in-chain location. | A Logic workflow for committing generated events. It is not ordinary AU host authority available to TrackSmith. |

## Modulation processors

| Processor | Documented operation | Production judgment and limits |
|---|---|---|
| Chorus | Mixes the source with modulated delayed voice(s). | Thickens/spreads and can soften pitch definition; check mono and low-frequency use. |
| Ensemble | Uses multiple modulated voices for denser chorus-like animation. | Greater density can sound lush or unfocused; voice count does not prove width or quality. |
| Flanger | Modulated short delay with feedback, producing moving comb notches/peaks. | Can add motion or metallic resonance; feedback and delay center govern severity. |
| Microphaser | A simplified phase-sweep effect. | Useful for restrained motion; moving cancellations can alter body and mono translation. |
| Modulation Delay | A delay-based chorus/flange architecture with modulation and feedback/routing controls. | Can range from doubling to obvious flanging; base delay, feedback, and wet relationship are separate dimensions. |
| Phaser | Cascaded phase-shift stages under modulation, with feedback and stereo controls. | Changes frequency-dependent phase/cancellation. Stage count and feedback affect complexity and peaks. |
| Ringshifter | Frequency shifting or ring modulation with delay, feedback, envelope/LFO modulation and wet/dry control. | Frequency shift moves every component by a fixed amount rather than preserving ratios; ring modulation creates sum/difference components. Both can become inharmonic. |
| Rotor Cabinet | Rotating-speaker/cabinet simulation with motor speed transitions, cabinet and mic behavior. | Modulates amplitude, spectrum, phase, and stereo position together. Acceleration/braking is part of phrasing. |
| Scanner Vibrato | Scanner-style vibrato/chorus variants. | Vibrato changes pitch; chorus-style modes combine/directly relate voices. Preserve tuning and mono intent. |
| Spreader | Produces stereo spread through frequency- and phase-related processing. | Apparent width can cost mono solidity. Exact internal response is not fully specified by the prose. |
| Tremolo | Tempo/free cyclic amplitude modulation with phase/symmetry/smoothing-related controls. | A rhythmic level tool, not pitch vibrato. Wave shape, phase and depth can reinforce or fight the groove. |

## Multi-effects

| Processor | Documented architecture | Production judgment and limits |
|---|---|---|
| Beat Breaker | Buffers live input and slices/reorders it with Time, Repeat, Cutoff, Resonance, Volume and Pan modes across ten patterns, per-slice settings, declicking, Bypass Below, and bounded randomization controls. | A real-time rearrangement effect that leaves the source file unchanged. It can create rhythmic edits, but buffer/slice timing and transient integrity must be auditioned; randomness needs stored state. |
| Phat FX | Reorderable serial Bandpass, Filter, three distortion slots, modulation FX, Bass Enhancer and Compressor, driven by two LFOs, an envelope follower and XY controls, with mix/output/limiter. | The same modules in different orders are different processors. Preset-level adjectives cannot substitute for graph inspection. |
| Remix FX | Performance-oriented XY Filter, Wobble, Orbit, Repeater, Reverb and Delay plus Gater, Downsampler, Reverse, Scratch and Tape Stop controls, all usable with automation. | Best understood as gesture/performance processing. A static setting does not capture the automation trajectory that creates the result. |
| Step FX | Reorderable Mod FX, delay, filter, distortion and reverb, driven by three independent up-to-128-step modulators plus envelope, gate/pan, polyrhythm and XY control. | Enables deterministic rhythmic motion when every pattern/state is stored. Polyrhythmic modulation can create long cycles; transition/reset behavior matters. |

The Step FX text refers once to “Phat FX filters” while describing Step FX, an
apparent copy error. It does not establish shared implementation.

## Pitch processors

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| Pitch Correction | Monophonic pitch correction against a scale/grid with input-range detection, response/tolerance, bypass notes, and reference tuning. | Best for a single pitched line. Scale choice and response affect musical expression; noisy/polyphonic input and deliberate slides/vibrato can fail. |
| Pitch Shifter | Pitch transposition with source-oriented algorithms such as Drums, Speech, Vocals, Manual and Pitch Tracking, plus latency compensation/mix controls. | Algorithm must fit source. Transposition can alter transients, formants and texture; latency and parallel blending require checks. |
| Vocal Transformer | Separates pitch/formant-style controls and adds robotize/grain-related transformation while retaining unvoiced components. | Creative voice transformation, not transparent identity preservation. Monophonic assumptions and unvoiced handling limit generality. |

## Reverb and ambience processors

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| ChromaVerb | Algorithmic room models with predelay, attack/early/late relationships, size/density/decay, frequency-dependent damping, modulation, distance, width, low-frequency mono, and output EQ. | Depth is multivariable: dry/wet, predelay, early energy, tail, spectrum and width all matter. Damping changes the decay process; output EQ changes the returned result. |
| EnVerb | Shapes the reverb tail with a time envelope rather than only one decay constant. | Useful for gated, reverse-like or contour-specific ambience. Envelope timing must fit the source phrase and can expose abrupt boundaries. |
| Quantec Room Simulator | QRS and YardStick algorithm families with separate direct/first-reflection/tail levels, Freeze/Add/Clear behavior, frequency-dependent time controls, and model-specific drive/complexity/density/correlation controls. | A detailed algorithmic-room design tool. Model heritage and adjectives do not establish physical accuracy; freeze/add states and tail level must be managed explicitly. |
| SilverVerb | A compact algorithmic reverb with predelay, reflectivity/room-size/density-time, modulation and wet/dry-oriented controls. | Useful when a bounded ambience is sufficient. Fewer controls do not make the outcome source-independent. |
| Space Designer | Convolution with recorded or synthesized impulse responses, including IR sample-rate/length/envelope/filter/EQ and stereo/surround handling. | Captures an IR's linear time-invariant response, not every nonlinear or time-varying property of hardware/space. IR changes may require recalculation and not all parameters are automatable. |

## Specialized processors

| Processor | Documented signal model | Production judgment and limits |
|---|---|---|
| Exciter | High-passes the source for nonlinear harmonic generation, then blends generated content with the original; Color choices alter harmonic/intermodulation behavior. | Creates upper-band content rather than simply boosting existing highs. It can add apparent detail or worsen sibilance, cymbals and intermodulation; Color 2 is documented as producing more intermodulation. |
| SubBass | Derives two narrow source bands and synthesizes sine-based subharmonic content at chosen ratios. | It is subharmonic synthesis, not ordinary pitch-shifting of the waveform. Stable narrow source bands and suitable monitoring are required; added sub can consume headroom and fail on small speakers. |

## Utilities and production tools

| Tool | Documented operation | Production consequence and authority boundary |
|---|---|---|
| Auto Sampler | Sends notes/velocities to a software or external instrument and records key ranges, velocity layers, round robins, sustain/release and optional loop variants into a Sampler instrument. Upstream effects are baked into each sampled note; downstream effects are not. | Excellent for committing a playable instrument snapshot. Effects become per-note sample character rather than editable time-varying mix processing, and the resulting library requires provenance/storage management. TrackSmith cannot invoke this host workflow through its ordinary AU. |
| Down Mixer | Maps a surround master to a chosen destination format with per-destination-channel level controls. | Useful for a quick alternate-format check, not complete delivery validation. Downmix coefficients, correlation and limiting can change loudness and balance. |
| Gain | Applies gain, channel-specific polarity inversion, balance, L/R swap and mono sum, with format-dependent controls. | Fundamental diagnostic/routing tool. Polarity inversion is not a time delay; mono sum is a direct compatibility check; gain changes downstream nonlinear/dynamic behavior. |
| I/O | Routes to/from discrete external hardware, with input/output trims, dry/wet, Stereo or Mid/Side format, latency ping and manual sample offset. | Makes hardware part of Logic's graph. Round-trip latency, conversion, noise and recall must be recorded; ping accuracy improves when other latent processors are bypassed. TrackSmith has no hardware-routing authority. |
| Multichannel Gain | Per-channel gain, mute and polarity inversion plus master gain for surround channels. | Enables diagnostic and balance work by channel. It does not replace a renderer or perceptual spatial evaluation. |
| Test Oscillator | Generates static sine/square/noise/needle signals or linear/log sine sweeps, including aliased/anti-aliased square/needle choices, decorrelated noise and level/dim controls. | Essential for measurement and troubleshooting. Test signals can be dangerously loud and are not musical evaluation; the positive-only needle is specifically useful for polarity/phase inspection. |

Auto Sampler's looping modes include search, crossfaded search, reverse-crossfade,
bidirectional, and a Penrose Machine synthesized loop. Apple's prose does not
publish enough of the Penrose algorithm to reproduce it, so TrackSmith records
only its documented purpose and exposed absence of parameters.

## Legacy processors

Legacy processors are retained for project/concert compatibility and normally
appear for direct insertion only when Option-opening the plug-in menu. They are
valid tools, but a new recipe should usually compare them with maintained modern
alternatives and record why legacy behavior is desired.

| Processor | Documented operation | Production consequence and limits |
|---|---|---|
| AVerb | Basic algorithmic reverb whose Density/Time jointly moves from discernible reflection clusters toward a denser tail, with predelay, reflectivity, size and mix. | Fast ambience/echo design; the coupled density/time control prevents independent optimization. |
| Bass Amp | Nine legacy amp/DI voicings with pre-gain, bass/mid/treble, sweepable mid frequency and output. | A compatibility color option. Model/genre descriptions are heuristics and the current Bass Amp Designer exposes a more inspectable amp/DI architecture. |
| DeEsser | Separate detector and suppressor frequencies, sensitivity/strength, monitoring and smoothing; the manual says the band is isolated/subtracted rather than split through a crossover. | Can target detection and reduction bands independently. Legacy behavior may be useful for recall; modern DeEsser 2 offers more explicit relative/absolute and split/wide behavior. |
| Denoiser | FFT-based attenuation of low-level, lower-complexity bands below a threshold, with reduction/noise-type and frequency/time/transition smoothing. | Noise reduction can create musical-noise or smearing artifacts. Find a noise-only region, use minimum sufficient reduction, and compare artifacts against the original noise. |
| Ducker | Analyzes an existing side-chain recording to lower an output/aux path with amount, threshold, attack, hold, release and lookahead; it is explicitly not live-input ducking. | A post/broadcast workflow, not a real-time side-chain compressor substitute. The legacy side chain is mixed back after the plug-in, a routing exception that must be understood. |
| DJ EQ | Fixed high/low shelves plus one parametric band with up to deep cut. | Broad performance/remix contouring, not surgical or source-diagnostic EQ. |
| Fat EQ | Five bands with selectable pass/shelf/bell roles and master output. | A flexible low-complexity curve; filter-role choices and output gain must be stored. |
| Single-Band EQs | Separate legacy cut/pass/shelf/parametric processors, with filter order/smoothing where exposed. | Useful for exact legacy recall and simple automation; do not assume equivalence to current EQ bands without measurement. |
| Silver EQ | High/low shelves plus one parametric band. | A simple three-band tone tool; limited bands can encourage deliberate broad decisions. |
| GoldVerb | Separately controls early reflections and tail, including room geometry, stereo base, delay, spread, high cut, density, diffusion and RT60-oriented time. | Early/late balance and predelay govern depth/definition. Manual room analogies remain simplified models. |
| Grooveshifter | Delays even eighth/sixteenth positions toward a selected swing amount and can accent them, using beat or granular tonal modes. | Requires source/project tempo alignment; incorrect tempo or material type degrades timing. It changes performed timing, not merely a groove label. |
| Guitar Amp Pro | Recombines 11 amp models, 15 cabinets/direct, four EQ types, condenser/dynamic mic choices, two positions, tremolo/vibrato/reverb, Gain/Master and final Output. | A legacy but deep amp architecture. Master changes modeled character while Output is final level; model adjectives and mic claims remain model-specific. |
| PlatinumVerb | Two-band algorithmic reverb with separate early/tail structure, crossover-dependent low-band time/level, high cut, density/diffusion and dry/wet. | Can keep low-frequency reverberation shorter/quieter than the upper tail, reducing masking; crossover and band timing can also change body. |
| Silver Compressor | Simplified threshold/ratio/attack/release compressor with gain-reduction meter. | Suitable for a bounded legacy dynamics move, but it lacks the detector/topology controls needed for many source-preservation constraints. |
| Silver Gate | Simplified lookahead/threshold/attack/hold/release gate. | Useful for simple cleanup; insufficient context can truncate desired decays and low-level articulation. |
| Speech Enhancer | Combines denoising, built-in-Mac microphone-response models and multiband voice enhancement modes. | Designed around speech and specific Apple microphones. It must not be treated as a universal vocal-production processor or proof of an “expensive microphone” result. |

## Documentation contradiction and uncertainty ledger

| Manual statement or defect | TrackSmith treatment |
|---|---|
| Bitcrusher text says “Cut mode” where the interface and surrounding section say Clip. | Apparent terminology error; use exposed `Clip` identity and measure any transfer claim. |
| ChromaGlow Low Cut/High Cut descriptions appear to swap low-pass/high-pass wording. | Do not infer topology from the suspect sentences; use control labels, listening, and measurement. |
| MultiMeter says “AES 128” while the dedicated loudness material says EBU R 128. | Normative loudness behavior comes only from untouched ITU/EBU sources and external vectors. |
| Step FX text says “Phat FX filters” in the Step FX section. | Apparent copy error; do not infer shared code or exact response. |
| Mastering Assistant discusses -1 dBFS true peak as meeting a requirement and centers output around -14 LUFS-I. | Treat as a practical default/example, not a universal platform or artistic requirement. Delivery specifications are versioned external constraints. |
| Product/model descriptions use words such as warm, punchy, polished, professional, vintage, fat, and aggressive. | Professional-practice/product heuristic only; never a measured fact or fixed semantic preset. |
| Several analog/circuit/model names imply hardware lineage without publishing algorithms. | Exposed behavior is documented; exact circuit, transfer, oversampling, alias, latency and phase behavior remain unknown until measured. |
| Randomizer can be repeatable with a seed, while random controls can create new output. | Store the seed and all state for deterministic evidence; never call an unstored random result reproducible. |
| Scripter persists executable JavaScript with settings/projects. | Provider text and untrusted context have zero code-execution authority. |

## Effects-guide completion statement

The actual relevant content of all 390 pages was reviewed, including parameter
lists, signal-flow notes, mode differences, source limitations, examples, tips,
legacy exceptions, and copyright/licensing notices. This establishes deep
comprehension of the documented interface and behavior; it does **not** establish
undocumented internals or perceptual superiority. Exact transfer functions,
latency, aliasing, state transitions, automation edge cases, and version-specific
host behavior remain in the empirical verification lane below.

## TrackSmith integration consequences

1. Logic-native knowledge is explanatory and advisory until a capability is
   explicitly implemented in TrackSmith's deterministic graph. The model must
   not hallucinate that it inserted Pedalboard, an amp, or any native Logic
   plug-in.
2. Knowledge retrieval should select a small set of applicable tools and include
   their signal model, topology, preservation risks, and unsupported status. It
   must not place the complete 2,686-page manual corpus into a provider prompt.
3. Requests such as “make this guitar nastier but keep the pick attack” should
   yield competing hypotheses: frequency-shaped drive, parallel distortion, or
   amp/cab/mic changes. Candidate rejection should consider attack loss, upper-
   band growth, output level, and the current graph.
4. A requested Logic recipe should distinguish **how to perform it in Logic**
   from **what TrackSmith can execute itself**. The former may name native tools;
   only validated deterministic nodes may enter an executable TrackSmith plan.
5. The generated 142-entry catalog exposes `deep_full_relevant_section_read`,
   immutable Effects-guide provenance, evidence classes, and an advisory-only
   execution boundary for every processor/pedal identity. The separate manual
   outline index remains explicitly index-only and can never masquerade as deep
   source comprehension.
6. All 35 pedal effects plus Mixer and Splitter carry bounded musician-language
   aliases and pedal-specific candidate semantic tags. These improve retrieval
   (for example, *soft fuzz*, *tape echo*, *envelope filter*, *ring mod*, or
   *frequency split*) but remain professional-practice hypotheses. They never
   become fixed word-to-pedal presets, and the retrieved mechanism/risks still
   govern source-aware listening choices.

## Empirical verification queue

Manual documentation cannot establish exact internal transfer behavior. A
versioned Logic 12.3 measurement lane should use controlled impulses, swept
sines, steady tones, two-tone intermodulation signals, transient bursts, stereo
polarity fixtures, and representative musical clips to characterize, where
repeatably measurable:

- frequency and phase response versus control state;
- static nonlinear transfer and harmonic/intermodulation spectra;
- alias behavior versus sample rate and drive;
- attack/release/envelope behavior;
- latency, tail, reset, bypass, mono/stereo, and automation behavior;
- gain staging and parameter coupling;
- whether behavior changes by Logic version, channel format, or sample rate.

Measured behavior must be stored with Logic build, macOS, sample rate, channel
format, exact preset/parameter state, test-signal hash, render hash, and method.
Perceptual labels still require controlled listening or explicit
professional-practice provenance.

Current campaign state: **197 `not_run`, three `partial`, zero `complete`**. The
partial identities are Bitcrusher, Channel EQ, and Compressor. Each closes only
the dimensions named in its own run record; none closes the processor or campaign.
