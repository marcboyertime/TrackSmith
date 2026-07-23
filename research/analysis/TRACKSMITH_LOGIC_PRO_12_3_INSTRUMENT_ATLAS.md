# TrackSmith Logic Pro 12.3 Instrument Atlas

Status: complete full-guide technical read plus canonical Quick Sampler web
supplement; living synthesis, 2026-07-16. This atlas records actual reading of
Apple's 752-page *Logic Pro Instruments for Mac* guide and the 16 live Logic
12.3 Quick Sampler pages omitted from that PDF payload. It is
not a substitute for the manual and does not imply that TrackSmith can insert,
play, automate, or edit Logic-native instruments. Pages not marked `Deep` have
not yet been used to justify settled product behavior.

## Epistemic and execution rules

1. Apple is authoritative for the exposed controls, routing, formats, and
   documented host behavior. Descriptions such as *warm*, *aggressive*,
   *punchy*, *fat*, *creamy*, or *ideal* are professional-practice language,
   not universal perceptual findings.
2. A model or circuit label does not disclose exact internal code, coefficient
   design, oversampling, antialiasing, component tolerances, or transfer curves.
   Those require direct measurement or another primary implementation source.
3. Explanations inferred from established synthesis/DSP are labeled **derived
   technical interpretation**. They must not be presented as Apple quotations.
4. Instrument sound is stateful and performance-dependent. Note order,
   velocity, articulation, release tails, voice allocation, controller state,
   random state, tempo, tuning, and prior modulation can all change the result.
5. TrackSmith may retrieve this knowledge to explain a sound or advise a user.
   It may not convert a Logic-native instrument entry into a `ProcessingNode`,
   invent a plug-in insertion, emit unrestricted MIDI/automation, or claim an
   edit was applied when the current execution graph cannot perform it.
6. Listening remains decisive. A technically valid patch or production move is
   not objectively superior merely because its spectrum, loudness, width, or
   transient measurement changed in the expected direction.

## Immutable primary source

| Source | Version | Pages | SHA-256 | Rights/status |
|---|---|---:|---|---|
| Apple, *Logic Pro Instruments for Mac* | Logic Pro 12.3 payload, retrieved 2026-07-14 | 752 | `fc867e61b1bbcfc16d4ba98058f7cde104ec17e0649026769c308cff07049ab4` | Apple copyright; immutable local-use-only research object |

Canonical object:
`research/papers/tracksmith-logic-12.3-archive/objects/fc867e61b1bbcfc16d4ba98058f7cde104ec17e0649026769c308cff07049ab4.pdf`.
The generated outline index is useful for navigation but explicitly remains
`source_index_only_not_deep_review_evidence`.

### Canonical Quick Sampler supplement

The PDF repeatedly names and links Quick Sampler, but jumps from EVOC 20
PolySynth to Retro Synth without containing the standalone chapter that appears
in Apple's live Logic Pro 12.3 table of contents. TrackSmith therefore did not
silently claim PDF coverage. The following official HTML payloads were captured
under the fail-closed ingestion contract and read in full on 2026-07-16.

| Apple live-guide section | Article ID | Immutable SHA-256 |
|---|---|---|
| Quick Sampler overview | `lgcp5af33756` | `a0ea49d2b1c68b55711703eea264c0dc7999c2aaeedb6b216a018f979ce1c62f` |
| Add audio | `lgcpc1e3525a` | `8215ebdd84ffe7a5208c22daddf0bc01dc3ff70b68645f1868c76a91f7dccc2c` |
| Choose a mode | `lgcpabc8c044` | `d85b85d4da9291cd483fa781678f1e78312d22c55e10102e5902c4e63b5428ee` |
| Classic mode | `lgcpb1f3f01c` | `d97f08c2aecdfdd28fc9ee0a335795443753e8d2e811ec0fa61b6bcf65166a1a` |
| One Shot mode | `lgcp35eefd58` | `8cc61d91195998b008c8f6e50160463802fd17fedec5771d958d6d826dbd9f93` |
| Slice mode | `lgcp18515788` | `32409ad099fb91155e154ada6acdd9e3460234470a7fcd7f805c6088fa0e9156` |
| Recorder mode | `lgcpa8e3df79` | `bb293df93762bb87ca8cf29fabc43ba2187ff02a761198507e81c03bb2813792` |
| Waveform display and Action menu | `lgcp4492eed9` | `8e84577be2f0ffcf8ecdd1131b0adc22657db52b76044b9c853115711f663de0` |
| Flex | `lgcpe3d7978d` | `5950fe4c6d76da76d30ed26cfe68930416e1102bfd732938813cb10d5426872b` |
| Mod Matrix | `lgcp26511d86` | `10772649048cccc534db6af079608424c71d82449fe8294ddbba161131fda27f` |
| LFO controls | `lgcpa1ea74f6` | `ce11693b54f5477143da607d4529f2be8514938cc49f3479f979886b071671f8` |
| Pitch controls | `lgcpd22b3634` | `beacebd3f82188048c16f1b027eeed08350d047e1035f3dcd3d6b8b6ca9c0a54` |
| Filter controls | `lgcp5c4ed964` | `a3786a99ade2326b1f5d41dad585ba320be748ec34d65ab45705dcbed918748c` |
| Filter types | `lgcpdd9d92ba` | `25f7cda01d966bb3dfb5cf93350da006fa0f0a2e15c32f30a547fd955f264eec` |
| Amp controls | `lgcpa9017890` | `9efffb2f51d08beddbcf4b733ea250e9a835660d6d3705b631006537d32d80c4` |
| Extended parameters | `lgcp3df3cd4a` | `78d1cf249a4d71b2e22cbcf14fae4ccb589b5b8e648558b7afbcb9dc27e817d3` |

## Review ledger

`Deep` means the actual relevant pages, parameter definitions, signal flow,
warnings, limitations, and tutorials were read. This table is deliberately
conservative.

| Instrument family | Manual pages | Status |
|---|---:|---|
| Instrument loading, copying, bypass, multi-output overview | 9-16 | Deep |
| Alchemy | 17-183 | Deep |
| Drum Kit Designer | 184-190 | Deep |
| Drum Machine Designer | 191-203 | Deep |
| Drum Synth | 204-208 | Deep |
| ES1 | 209-221 | Deep |
| ES2 | 222-289 | Deep |
| EFM1 | 290-298 | Deep |
| ES E | 299-303 | Deep |
| ES M | 304-307 | Deep |
| ES P | 308-313 | Deep |
| EVOC 20 PolySynth | 314-332 | Deep |
| Quick Sampler live-guide chapter | 16 canonical HTML sections listed above | Deep |
| Retro Synth | 333-349 | Deep |
| Sample Alchemy | 350-374 | Deep |
| Sampler | 375-463 | Deep |
| Sculpture | 464-550 | Deep |
| Studio Bass | 551-557 | Deep |
| Studio Horns | 558-564 | Deep |
| Studio Piano | 565-566 | Deep |
| Studio Strings | 567-572 | Deep |
| Ultrabeat | 573-638 | Deep |
| Instrument utilities | 639-642 | Deep |
| Vintage B3 | 643-678 | Deep |
| Vintage Clav | 679-695 | Deep |
| Vintage Electric Piano | 696-706 | Deep |
| Vintage Mellotron | 707-709 | Deep |
| Legacy instruments | 710-721 | Deep |
| Synthesis fundamentals | 722-751 | Deep |
| Copyright and usage notice | 752 | Deep |

## Instrument-wide host model

### Documented behavior

- Software instruments occupy the instrument slot of a software-instrument
  channel strip. Audio effects process their output afterward unless an
  instrument exposes its own internal effect/routing stage.
- An instrument can expose mono, stereo, multi-output, or surround variants.
  A multi-output instance creates auxiliary paths that allow individual parts
  or microphone channels to receive separate downstream processing.
- Plug-in settings store a single plug-in's state. Library patches can store a
  broader channel-strip or track-stack configuration, including instruments,
  effects, sends, and routing. Treating a patch as a preset loses this scope
  distinction.
- Bypass, move, copy, and replace operations alter the processing topology and
  may change latency, tail behavior, channel format, and state. They are host
  operations, not mere parameter edits.

### Derived production consequences

- A recommendation must identify whether it concerns synthesis, performance,
  internal instrument effects, channel-strip effects, auxiliary outputs, or
  arrangement. These scopes are not interchangeable.
- Multi-output drum and sampler workflows can preserve per-piece control that
  is impossible after a stereo sum. Conversely, processing only the stereo sum
  can create desirable bus interaction and glue. TrackSmith must not assume one
  is always better.
- A playable patch includes controller and articulation behavior, not just a
  static timbre. Evaluating only a held C3 can miss velocity, range, voice
  allocation, legato, release, round-robin, keyswitch, and mono-collapse faults.

## Alchemy: hybrid resynthesis and synthesis

### Signal architecture established by the manual

- Four independent sources, A-D, can combine additive, spectral, granular,
  sampler, and virtual-analog elements subject to element-specific
  compatibility constraints.
- Each source has three source filters with serial/parallel routing. Two main
  per-voice filters follow the source/morph stage and can run serially or in
  parallel. Sources can also bypass the main filters into effect racks.
- Five serial effect racks exist: Main plus A-D. Source and filter routing can
  feed the source-specific racks and the Main rack. The dry path is mixed with
  processed output.
- Modulation is nested: most continuous controls can accept as many as ten
  modulators; modulation depth can itself be modulated, with another nested
  layer available. Menu/button state is often not modulatable.
- Perform view exposes eight knobs, two XY pads, four envelope controls, and
  eight Transform Pad snapshots. These are automatable macro states, not a
  disclosure of every underlying assignment at a glance.

### Synthesis and import distinctions

- **Additive** reconstructs a signal with partials. Apple recommends it mainly
  for monophonic harmonic material. Alchemy can use up to 600 partials and can
  alter partial amplitude, pitch variation, symmetry, odd/even relationships,
  and other group properties.
- **Spectral** divides a signal into frequency bins filled with sine or filtered
  noise energy. It is suited to polyphonic or complex material but the editor's
  painted resolution is coarser than the underlying resynthesis and is not a
  precise melody editor.
- **Add+Spec** separates harmonic and noisy components between the two engines.
  The quality of that separation remains source-dependent.
- **Granular** extracts 2-230 ms grains. Size and density interact; additional
  taps create parallel grain streams. Modulation sampled per grain can become
  audibly stepped. Granular and sampler elements cannot coexist within the same
  source.
- **Sampler** performs conventional sample playback; pitch changes also change
  playback speed. **Virtual analog** supplies generated waveforms, sync, noise,
  unison, and related oscillator behavior.
- These import recommendations are Apple practice heuristics. The manual itself
  asks the user to compare methods; TrackSmith must not claim one analysis mode
  is universally correct from source label alone.

### Morph is not crossfade

- XFade plays multiple sources simultaneously at changing levels.
- Morph interpolates eligible analyzed elements and parameter states into a
  hybrid result. Buttons and popup choices commonly do not morph.
- Elemental morphing can independently interpolate additive/spectral-granular,
  pitch, formant, and envelope/timing components.
- Compatible analysis modes, warp-marker correspondence, source duration, and
  time alignment materially govern the result. Zone fades are incompatible
  with morphing; only the first zone is used and fades are disabled.
- The tutorials explicitly describe some additive morph results as a search for
  “happy accidents” rather than a predictable process. TrackSmith must expose
  morphing as exploratory and listening-decisive.

### Grouping, performance, and deterministic risk

- Groups can use attack/release triggers, key/velocity/controller ranges,
  keyswitches, fades, per-group polyphony, sequential or random round robin,
  and boolean And/Or/Not rules.
- Random round robin, note-on random modulation, free-running oscillators/LFOs,
  granular randomization, and arpeggiator state can make repeated renders differ.
  Exact reproduction requires capturing the relevant state or explicitly
  classifying the result as stochastic.
- The arpeggiator supports global or independent A-D instances, as many as 128
  steps and 16 patterns, per-step control, latch, split, swing, and independent
  polyrhythms. Sufficient polyphony is required or notes will be stolen.
- Convolution-reverb file commands do not copy the referenced impulse response.
  Portability must be verified rather than inferred from preset state.

### Production consequences

- Per-voice nonlinearity and post-voice nonlinearity are not equivalent. A
  per-voice distortion can preserve complex chord clarity that a summed
  distortion may obscure through intermodulation.
- A Transform Pad snapshot should be evaluated for meaningful timbral change,
  relative loudness, range consistency, and transition safety. Snapshot motion
  can change many hidden assignments at once.
- “Make the Alchemy patch warmer” could mean source partial balance, formant
  size, filter topology, per-voice drive, post effect, unison, or performance
  macro adjustment. The source, current patch, range, and requested preservation
  constraints must narrow the hypothesis.

## Logic drum-instrument stack

### Drum Kit Designer

- Drum Kit Designer presents sampled acoustic drum/percussion pieces. Per-piece
  Tune, Dampen, and Gain alter pitch, sustain, and level. Multi-channel `+` kits
  additionally expose microphone leak, overhead participation, and room A/B/off.
- Kick and snare can be exchanged in all kits; multi-channel kits also permit
  tom, cymbal, and hi-hat exchange, with toms and crashes exchanged as groups.
- GM, GM + mod-wheel hi-hat, and V-Drum mappings are distinct performance
  contracts. Brush kits maintain hand, circle, mute, and downbeat-synchronized
  state; a brush hit cannot be modeled as a stateless one-shot sample.

### Drum Machine Designer

- Drum Machine Designer is a track-based meta-instrument, not one ordinary
  instrument plug-in. Its main track plus per-pad subtracks form a track stack;
  each pad can own an instrument, effects, channel strip, input note, and output
  note. A kit patch can therefore store multiple channel strips.
- Main-track notes are remapped and dispatched to subtracks; notes placed on a
  subtrack bypass that remap and may play its instrument chromatically and
  polyphonically.
- Pads can layer on one input note, use exclusive choke groups, resample the
  complete assigned path into Quick Sampler, or receive audio/MIDI/region drops.
  Reorder mode can move sounds while preserving note mappings or be visual only.

### Drum Synth

- Drum Synth is a compact electronic synthesis engine with separate kick,
  snare/clap, percussion, and hat/cymbal models. The selected model determines
  which subset of as many as eight context-specific controls is available.
- Key tracking and Mono/Poly/Gate determine whether the result acts as a fixed
  drum voice, chromatic instrument, sustained voice, or choke-like monophonic
  part.
- Labels such as Body, Punch, Snap, Sweep, Tension, Material, Cycles, Crush,
  Dirt, Dissonance, and Metallic are macro controls whose interactions are
  documented but whose exact algorithms are not. They must not be translated
  into universal acoustic definitions.

### Producer-facing decision boundary

“Tighten the drums” may require shorter sampled sustain or less room in Drum Kit
Designer, an envelope/sample edit on one Drum Machine Designer pad, a synthesis
decay/body change in Drum Synth, a bus process after the kit, or an arrangement
change that TrackSmith cannot observe. The system must first resolve the
instrument topology and the preserved attributes (weight, ambience, cymbals,
groove) before recommending a move.

## Classic subtractive and FM synths

### ES1

- ES1 is a one-primary-plus-sub-oscillator subtractive synth. Its sub source can
  also be noise or an external side-chain signal routed through the synth engine.
- Its lowpass filter offers 12, 18, 24 classic, and 24 fat slopes; high resonance
  can self-oscillate. Drive is filter input level. Filter Boost changes internal
  gain staging while roughly maintaining output level.
- Oscillator phase can be synchronized at Analog = 0 for more repeatable attack;
  higher Analog values introduce note/filter variation. AGateR, ADSR, and GateR
  select different amplifier-envelope behavior.

### ES2

- ES2 combines three oscillators, 100 Digiwaves, oscillator FM, sync, ring
  modulation, noise, dual filters, ten source/via/target router lanes, two LFOs,
  three conventional envelopes, a two-axis Planar Pad, and a 16-point looping
  Vector Envelope.
- Filter 1 is multimode; Filter 2 is lowpass with 12/18/24/Fat slopes. They can
  run serially or in parallel. Filter Blend changes both audible balance and,
  in serial mode, the location/number of overdrive stages.
- Filter Drive acts per voice; the integrated Distortion effect acts after the
  polyphonic sum. They therefore have different chordal intermodulation.
- Free oscillator start adds variation but can change initial level and punch.
  Soft starts at a zero crossing; Hard begins at the waveform maximum and is
  most audible with a very fast amp attack.
- Vector Envelope looping moves oscillator-mix/Planar-Pad control state; it does
  not loop audio. Normal and Finish release modes, loop placement, time scaling,
  and curve type materially change note behavior.
- Randomization is cumulative from current state and can be restricted by
  subsystem. Master level, filter bypass, and oscillator on/off are excluded,
  but random state still makes reproducibility an explicit concern.

### EFM1

- EFM1 is a 16-voice two-operator-style FM instrument: a multiwave modulator
  changes a sine carrier. Carrier/modulator harmonic ratios define the broad
  overtone structure; even ratios often sound more harmonic and odd ratios more
  inharmonic, but selection remains source- and goal-dependent.
- The modulation envelope can change FM depth and modulator pitch. A separate
  output envelope, sine sub-oscillator, unison, and doubled Stereo Detune engine
  shape weight and width. Apple explicitly warns Stereo Detune may lose mono
  compatibility.

### ES E, ES M, and ES P

- ES E is an eight-voice ensemble/pad synth: saw-to-pulse oscillator, LFO
  vibrato/PWM, lowpass filter, shared AR envelope, and chorus/ensemble variants.
- ES M is monophonic and bass-oriented: saw/one-octave-lower rectangle blend,
  automatic fingered portamento, 24 dB/octave lowpass with resonance bass
  compensation, simple decay envelopes, and output overdrive.
- ES P is an eight-voice poly synth with independently mixed triangle,
  sawtooth, rectangle, two rectangular sub-octaves, and noise; its lowpass
  filter offers stepped key follow, shared ADSR, chorus, and overdrive.
- These concise instruments deliberately expose macros. Their descriptive
  names do not justify pretending TrackSmith knows an undisclosed circuit.

## EVOC 20 PolySynth

- EVOC 20 PS uses an analysis side chain plus a MIDI-played synthesis signal.
  Matching analysis/synthesis filter banks divide the spectrum into as many as
  20 bands. Envelope followers from the analysis bands control the levels of
  corresponding synthesis bands.
- More bands can improve spectral precision and intelligibility but consume
  more resources. Analysis Attack/Release trade articulation against smoothness;
  very short release can sound rough/grainy and very long release can smear.
- Unvoiced/voiced detection can replace unvoiced portions with noise,
  noise+synth, or a high-passed analysis blend. Excess sensitivity and level can
  create static-like results or internal overload.
- Formant Stretch changes synthesis-band distribution; Formant Shift moves the
  synthesis bank. High resonance with extreme formant transforms can create
  unusual resonances.
- Intelligibility depends on overlapping analysis/synthesis energy. Apple's
  advice to compress, EQ, gate, enunciate, and preserve high-frequency content
  is professional workflow guidance, not a universal chain; gating and
  compression can also raise breaths/noise or damage natural articulation.

## Quick Sampler: one file, several materially different state models

### Source and asset behavior

- Quick Sampler creates an instrument from one audio file or a new recording;
  Sampler is the multi-file alternative. Replacing Quick Sampler with Sampler
  transfers the current content, and Sampler can load a saved Quick Sampler
  setting. The reverse is explicitly unsupported.
- `Original` retains source tuning, loudness, loop state, and length.
  `Optimized` analyzes tuning and loudness, can crop leading/trailing silence,
  and can create loop and crossfade markers for suitable material. These are
  transformations and inferred state, not a neutral file-open operation.
- Dragging a region invokes an offline resample through the region's active
  path: MIDI processors/instrument/audio effects for a software-instrument
  region, or audio effects and processing such as Flex for an audio region.
  Dragging the underlying audio file does not perform that track bounce. The two
  gestures can therefore create different source bytes from apparently the same
  musical passage.
- Settings and Library patches have different scope. `Save` may overwrite an
  existing instrument setting; `Save As` and `Save A Copy As` create another;
  `Save As Default` changes the starting state of future instances.
- The waveform menu can rename the current audio file and write loop data into
  its header. Crop Sample/Crop Loop remove material outside markers, but the
  page does not make every underlying-file/reference consequence precise.
  TrackSmith classifies these as file/asset authority requiring explicit user
  action and empirical source-preservation checks.

### Playback modes are not interchangeable presets

- `Classic` is key-gated and supports forward, reverse, alternating, or
  play-to-end-on-release looping. Root key affects pitch and ordinary playback
  speed; loop, sample, fade, and crossfade markers are separate state.
- `One Shot` triggers from sample start to end, ignores loop markers, and can
  reverse playback. The Amp envelope still governs audible note duration, so
  “one shot” does not mean envelope-independent output.
- `Slice` maps segments to chromatic, white-key, or black-key sequences. Markers
  can come from transient detection, beat divisions, equal divisions, or manual
  placement. Gate changes release behavior; Play to End changes each slice's
  extent. Manually protected markers can ignore later Sensitivity changes.
- `Recorder` captures a selected input immediately or after a threshold is
  crossed, with optional monitoring. It is an input/feedback and recording-
  consent path, not a harmless synthesis parameter.

### Time, pitch, envelope, filter, and modulation behavior

- Without Flex, keyboard pitch transposition ordinarily changes playback speed.
  Flex holds playback speed while pitch changes; Follow Tempo synchronizes
  suitable tempo-aware material to project tempo. Speed division/multiplication
  remains separately selectable and modulatable. Correct musical timing does
  not guarantee preserved transients or texture.
- Pitch has coarse/fine tuning, glide, key tracking, bend range, a velocity-
  scaled AR/AHDSR-style envelope, and modulation depth. Turning off key tracking
  plays the original pitch/speed from every note rather than merely disabling a
  corrective process.
- Filter choice includes LP/BP/HP/BR/peaking families and documented Creamy,
  Edgy, Gritty, Lush, Lush (Fat), and Sharp variants. Cutoff, resonance, drive,
  key scaling, velocity, and a dedicated envelope interact. Apple identifies
  pole/model families but does not publish coefficients, nonlinear curves,
  oversampling, alias behavior, or complete phase response.
- Amp state includes volume, pan, maximum polyphony, velocity response, and a
  dedicated envelope. Voice count and release can change voice stealing and
  phrase continuity, not merely output level.
- Two LFOs expose free or tempo-synced rate, waveform, unipolar/bipolar
  polarity, fade in/out, phase, key trigger, poly/mono reset behavior, a target,
  and optional `via` control of modulation depth. Mono legato does not retrigger
  while a key remains held; Poly creates per-voice modulation state.
- The Mod Matrix adds four independent source-target routes. Sample/loop start,
  end, and position targets can quantize to bars, beats, or triplets; the chosen
  target quantization applies to every route addressing that target. This can
  turn smooth modulation into discrete playback-location jumps.
- MIDI Mono mode distributes voices across MIDI channels with a common base
  channel; per-note channels accept pitch bend, aftertouch, modulation, and
  controller data. Its bend range is independent state. This is performance
  authority, not downstream audio processing.

### Direct production consequences and non-claims

- “Make this sample tighter” could mean marker placement, tail/fade length,
  envelope release, Slice Gate/Play to End, Flex timing, source resampling, or
  downstream dynamics. TrackSmith must identify which state is implicated.
- Automatic loop, transient, tempo, tuning, gain, and optimization results are
  editable hypotheses. The pages publish no accuracy benchmark, confidence
  score, exact detector, or guarantee of click-free/musically correct results.
- A saved Quick Sampler sound includes asset identity, marker state, playback
  mode, Flex/tempo interpretation, synthesis/modulation state, voice behavior,
  and possibly file-header changes. A static spectrum cannot reconstruct it.
- TrackSmith may explain or diagnose this state only. Its current AU cannot
  load samples, record inputs into Quick Sampler, create MIDI regions, insert
  instruments, mutate files, or edit Logic project state.

## Retro Synth

- Retro Synth has four mutually exclusive engines: Analog, Sync, Table, and FM.
  Much of the downstream filter, amp, envelope, modulation, unison, MPE, and
  controller architecture is shared.
- Table mode offers supplied/custom wavetables. Custom-source audio should have
  stable-pitch sections; rapidly changing timbre can give unpredictable
  analysis. Shape scanning and formant stretching are distinct operations.
- The multimode filter includes documented state-variable, biquad, and
  analog-modeled variants labeled Creamy, Edgy, Gritty, Lush, Lush Fat, and
  Sharp. The names are heuristics; exact responses remain undisclosed.
- Stereo Spread alternates voices symmetrically and unison stacks voices.
  Width, polyphony, phase, envelope attack, and mono compatibility therefore
  need evaluation together.

## Sample Alchemy

- Sample Alchemy turns one sample into as many as four independent sources.
  Each handle selects a waveform position and each source can independently use
  granular, additive, or spectral resynthesis.
- Play modes are not interchangeable: Classic traverses from a handle; Loop
  repeats a defined range; Scrub reads at handle positions; Bow alternates
  forward/reverse motion; Arp triggers sections as a tempo-synchronized pattern.
- Motion mode records handle paths, loops them in tempo, and permits overwrite
  behavior similar to Touch automation. Handle performance can also become
  region automation through Logic's internal MIDI route.
- Granular mode uses 2-230 ms grains. Size and density jointly set overlap;
  taps add offset grain streams; Random Time smooths but reduces exact
  repeatability. Apple-provided pad/drum values are starting heuristics.
- Additive mode models time-varying partial amplitude, pitch, pan, and phase.
  Spectral mode fills frequency bins with sine or filtered-noise energy. Both
  can change formant structure, pitch variability, harmonic balance, and source
  identity in ways that one brightness metric cannot predict.
- Per-source/global filters include modeled LP/BP/HP types, comb physical-model
  behavior, a downsampler, and audio-rate FM. The Downsampler reduces sample
  rate; it is only *similar* to a bitcrusher and is not evidence of bit-depth
  reduction.
- The output limiter is a safety option, not proof that a patch is perceptually
  balanced or free of intersample/host-level problems.

## Sampler

### Data and signal model

- A sampler instrument stores mapping and synthesis state plus references to
  external AIFF, WAV, or CAF files; the audio is not embedded in the instrument
  file. Sampler also imports EXS, SoundFont2, DLS, and Gigasampler material.
- A **zone** refers to one audio file and defines root pitch, key/velocity
  range, gain/pan/output, sample/fade/loop/anchor markers, one-shot/reverse
  behavior, Flex behavior, and related playback state. A **group** contains
  zones and adds shared range, crossfade, mixer, output, envelope/filter offset,
  articulation, selection, release-trigger, exclusive-class, and voice rules.
- Synth parameters and mapping are separable data. Sampler can copy/import
  synthesis, modulation, and envelopes without a mapping, or import a mapping
  without synthesis parameters. A Library patch is broader again and can store
  associated channel-strip settings and routing.
- Samples normally load into RAM; disk streaming retains attacks in memory and
  streams the remainder for libraries larger than available RAM. Playback
  reliability therefore depends on file availability, storage performance,
  project assets, and current memory pressure.

### Synthesis, modulation, and voice behavior

- Two filters can run serially or in parallel. In parallel mode, filter Drive
  occurs before the split, both filters receive the driven mono signal, and
  Filter Blend recombines their outputs. With only one active filter, Blend
  crossfades between dry and filtered paths.
- Filter Drive operates per voice, limiting the post-sum intermodulation that
  would occur with one nonlinear processor after polyphonic mixing. Exact
  transfer behavior of named Creamy/Edgy/Gritty/Lush/Fat/Sharp models remains
  undisclosed.
- Twenty Source/Via/Target modulation routes can coexist. Available targets
  include sample selection, bit resolution, sample/loop markers, Flex speed,
  pitch/glide, both filters, output, LFO/envelope parameters, sustain, and
  articulation ID. Multiple routes can target the same parameter.
- Sample Select crossfades may require every potential velocity layer to play
  in parallel. Layer count, unison count, crossfades, group voices, and global
  polyphony jointly determine actual voice use and stealing risk.
- Four LFOs can run mono or poly, free or tempo-synchronized, unipolar or
  bipolar, key-triggered or free phase, with ramps. Five envelopes are
  available; ENV 1 is the non-removable amplitude envelope. Random sample
  select, random velocity, Random modulation, random detune, and un-keyed LFOs
  make deterministic reproduction state-dependent.

### Mapping and performance semantics

- Within one group, zones cannot overlap in the Key Mapping Editor; forced
  overlap cuts selected or unselected zones according to protection settings.
  True layers use separate groups or velocity divisions.
- Groups can be selected by round robin, articulation ID, pitch bend, MIDI
  channel, controller range, note/keyswitch, tempo range, and combinations of
  these criteria. Release-trigger groups model note-off noises; exclusive
  classes and per-group voice limits model choke behavior.
- Round robin avoids repeated-sample “machine gun” behavior but introduces
  sequence state. Articulation IDs belong to note events and can be assigned in
  Logic's MIDI editors or selected by a validated controller-to-ID modulation.
- Linear-dB, linear-gain, and equal-power group/loop crossfades differ. Equal
  power introduces a documented 3 dB midpoint boost. The manual explicitly
  notes that a crossfaded loop does not always sound better.
- The anchor value allows sequenced playback to begin early so a later rhythmic
  event lands on the note boundary. Live playing begins at the anchor and omits
  pre-anchor material; a shaker or breath pickup can therefore behave
  differently live and on the timeline.

### Creation, analysis, and preservation risks

- Chromatic import maps files successively and retains recorded attributes.
  Optimized import analyzes root pitch, perceived loudness, silence, loop
  points, velocity layers, and crossfade settings. These are starting mappings,
  not proof that the detected pitch, velocity ordering, or loop is musically
  correct.
- Optimized import and `Normalize Loudness` use an Apple-documented target of
  -12 LUFS for zones. Normalizing multiple selected zones destroys their prior
  inter-zone loudness relationship even though each zone's internal dynamics
  remain unchanged. This is not a mastering target and must not be generalized.
- Dragging a region to create a sampled instrument bounces the source through
  the track's active MIDI instrument/audio processing (and Flex where
  applicable); dragging the underlying audio file does not. Provenance must
  record which path created the sample.
- Crop commands create replacement files rather than cutting the original.
  `Write Sample Loop` and `Write Mapping` change metadata in an audio-file
  header. Both are file mutations outside TrackSmith's current authority and
  must never be implied by an advisory response.
- Save/Save Copy can duplicate referenced audio; consolidation creates CAF
  files. Saving only the instrument without audio can leave a nonportable
  reference graph. Project restore must verify assets rather than trusting the
  sampler-instrument file alone.
- Flex separates pitch from playback speed only when valid tempo information
  is present; Follow Tempo then synchronizes playback to the project. Incorrect
  header/analysis data can require re-analysis or deriving tempo from loop
  length, so a failed sync is not automatically a DSP defect.

## Sculpture

### Stateful component-model architecture

- Sculpture models a vibrating string as a chain of coupled elements rather
  than playing a sample or merely filtering an oscillator. The documented
  per-voice path is objects into the string, two pickups, amplitude envelope,
  Waveshaper, and filter. Voices are then summed and pass through global Body
  EQ, delay, and limiter/output processing.
- The model retains the current vibration of a string. Repeating a note can
  interact with vibration left by the prior note, and the manual explicitly
  warns that string, object, and pickup parameters interact: adding or moving
  one component can invalidate an earlier setting. This is not a separable
  bank of one-parameter tone controls.
- The Material Pad jointly controls Inner Loss and Stiffness. Media Loss,
  Resolution, Tension Modulation, key scaling, and release scaling further
  change damping, overtone density, pitch behavior, and decay across the
  keyboard. Small changes can be large or unexpected; key scaling is essential
  for a patch intended to work beyond one audition note.
- Tension Modulation introduces nonlinear pitch behavior. Apple warns that
  extreme values can destabilize the model and cause a volume spike or
  dropout. MIDI Mono Mode may intentionally stop tracking an extreme upward
  bend precisely in order to preserve model stability.

### Objects, pickups, and physical interpretation

- At least one exciter is required. Object 1 can excite; Object 2 can excite,
  disturb, or damp; Object 3 can disturb or damp. Exciters include Impulse,
  Strike, GravStrike, Pick, Bow, Bow wide, Noise, Blow, and an Object-2 External
  side-chain mode. Their Strength, Timbre, and Variation controls change
  different physical quantities by type, so the labels are not semantically
  interchangeable across objects.
- Disturb/damp types are Disturb, Disturb 2-sided, Bouncing, Bound, Mass, and
  Damp. Bouncing is explicitly random and cannot be synchronized. Bound limits
  and reflects displacement; Mass can introduce inharmonicity; Damp applies a
  localized loss. Recommending one requires the intended physical interaction,
  not merely an adjective such as *vintage* or *organic*.
- Moving either pickup changes the sampled vibration and therefore spectral
  nulls and level. Pickup B can be phase-inverted; depending on positions this
  may thin the sound through cancellation or make it richer. Pickup Spread and
  key-dependent panning create stereo motion, but Apple explicitly notes that
  not all pickup positions are mono-compatible.
- Pickup-position modulation can approximate chorus-like movement but is not a
  true chorus or harmonizer. This distinction matters when a user asks to
  preserve pitch stability, mono compatibility, or the dry articulation.

### Modulation, morphing, and repeatability

- The modulation system includes two LFOs, dedicated vibrato, two jitter
  generators, two per-note random sources, two velocity routes, Controller A/B
  routes, and two recordable polyphonic control envelopes. The envelopes can
  run conventionally, add live controller offsets, loop forward/backward/
  alternately, synchronize to tempo, or replay recorded controller motion.
- Jitter is continuous random variation. Note-on random generates a new value
  per voice and holds it until release. Free or partially polyphonic LFO phase,
  jitter, Bouncing objects, note-on random, and randomized morph points all
  prevent an assumption of sample-identical renders unless their state and
  seeding are controlled and verified.
- Five Morph Pad points capture all morphable parameter values; intermediate
  positions interpolate those states. A nine-point Morph Envelope can replay,
  loop, offset, scan, or step a path for each voice. Morph randomization can be
  constrained by parameter family, and Apple excludes Tension Modulation in a
  dedicated option because indiscriminate randomization can be uncontrolled.
- Recorded control and morph envelopes are limited to 48 bars or 40 seconds.
  Switching between millisecond and tempo-synchronized time recalculates to the
  nearest representable unit, so it is not an identity-preserving mode change.

### Render quality and production consequences

- Basic render mode supports at most 100 string elements and therefore at most
  99 overtones for one voice. Extended raises the maximum to 1000 and limits
  overtones relative to Nyquist. High Definition also runs the model with
  internal 2x oversampling and is materially more processor-intensive.
  Resolution also changes the timbre and level; it cannot be treated solely as
  an inaudible CPU-quality control.
- Body EQ uses modeled instrument-body responses derived from impulse-response
  measurements, but the manual does not expose exact responses. The integrated
  delay can create spatial impressions, yet Apple recommends a dedicated reverb
  plug-in for sophisticated reverberation. The limiter is a safety/gain-stage
  option, not proof of a balanced or release-safe patch.
- The tutorials repeatedly show that there are multiple valid component models
  for one target instrument and advise listening, small changes, range testing,
  and revisiting earlier controls after later components are added. Their exact
  numeric examples are teaching starts, not universal presets.
- A TrackSmith advisory must therefore state the physical hypothesis, playable
  range, performance/controller assumptions, stability and CPU risk, stochastic
  behavior, and mono/stereo preservation constraints. It must never imply that
  a Sculpture patch was edited or rendered through TrackSmith's current
  deterministic DSP graph.

## Studio instruments: performance is part of the sound

### Studio Bass

- Studio Bass is multisampled, with distinct electric/upright instruments,
  finger/pick/slap styles where supported, articulations, string/neck-position
  selection, release and handling noises, muting, transient Definition, pickup
  choices, and mono/poly/one-voice-per-string modes.
- The same pitch can have a different tone on a different string or fret
  position. MIDI output channels can prefer individual strings or hand
  positions; articulation IDs/keyswitches distinguish legato, dead notes,
  harmonics, slides, pickup hits, taps, and playing-hand variants.
- Upright Growl is an upper-harmonic/fingerboard interaction whose attack varies
  with note duration and pitch. The Noises macro combines rattles, releases,
  and handling probability. These are source/performance models, not EQ bands.
- A “tighter bass” request can therefore mean less mute release, more transient
  Definition, a different playing/string position, reduced handling/noise,
  dynamics control, or downstream processing. TrackSmith must inspect context
  before proposing compression or low-frequency EQ.

### Studio Horns and Studio Strings

- Both instruments expose solo and section presets, articulations, controller-
  driven dynamics, attack/release, vibrato, release samples, legato transition
  samples, authentic or extended key range, and MIDI-channel access to
  individual section members.
- Auto Voice Split distributes chord notes to different players or groups. Its
  lead-first, bass-first, key-split, unison, octave-double, Drop 2, and Drop 2+4
  options are arrangement/voicing decisions, not tone controls. With Horns
  voice split off, overlapping ranges layer players; with Strings split off,
  the section is divided by range instead.
- Dynamic-controller modes are materially different: absolute ignores velocity,
  Catch waits until a controller crosses the current value, and Relative adds
  controller movement to the velocity-established state.
- Falls/doits can attach to the end of an existing note with minimal gap and a
  second same-pitch articulation event. Treating them as a generic pitch bend
  loses the sampled transition and timing semantics.
- Horn Humanize intentionally introduces random pitch/level/embouchure-like
  variation. Authentic range, deterministic repetition, section balance, and
  legato/release behavior therefore need explicit evaluation.

### Studio Piano

- Studio Piano blends independently switchable condenser/ribbon stereo pairs
  and a mono ribbon microphone, with pedal noise, key noise, release samples,
  and sympathetic resonance. These controls alter perspective, mechanism, and
  undamped-string interaction rather than merely “brightness.”
- Lowering release samples can make note ends unnaturally abrupt. Increasing
  noise or resonance may add realism in one performance and unwanted density
  in another. A piano recommendation must consider pedaling, register, note
  density, microphone blend, and downstream mono/phase constraints.

## Ultrabeat: 25 synths, mixer, and sequencer

### Architecture and preservation model

- An Ultrabeat instance contains 25 independent synthesizers, their mixer and
  output assignments, as many as 24 patterns, and per-sound sequences of up to
  32 steps. Voices 1-24 occupy C1-B2; voice 25 is chromatic from C3 upward.
- Its multi-output form provides eight stereo and eight mono outputs, with a
  subgroup/aux path for independently or jointly processing voices. Routing a
  sound away from Main removes it from the main output.
- Swapping/copying a sound by drag does not move its sequence; clipboard
  commands can separately copy a voice, one sequence, or all sequences. A
  setting stores sound/sequencer state but only references external audio
  samples. Portability therefore requires asset verification.
- Sampler imports are approximated only for zones/layers from C1-C3 and cap at
  the 25-sound range; out-of-range zones are ignored. User-loaded single samples
  cannot use Ultrabeat's velocity-layer feature.

### Per-voice synthesis and routing

- Oscillator 1 provides phase distortion, FM carrier, or an externally gated
  side-chain source. Oscillator 2 provides phase distortion, sample playback,
  or a component-modeled string. Separate noise and ring-modulator sources can
  join them. Each source can enter or bypass the main filter independently.
- A side-chain signal does not trigger a voice by itself; MIDI or the internal
  sequencer must gate the chosen sound. Ring modulation requires both
  oscillators to be on even when their direct mixer levels are zero.
- Filter and distortion order is reversible. The distortion stage chooses an
  analog-modeled overdrive or bit reduction. In Crush mode, Level is an input
  threshold for when crushing begins, not a normal output level. This is
  distinct from Logic's standalone Bitcrusher and must not inherit its exact
  parameter semantics.
- Two output EQ bands, pan modulation or frequency-dependent stereo spread,
  per-voice level, trigger mode, choke group, and Gate follow the synthesis
  section. Envelope 4 is permanently tied to voice volume; the Assignment
  mixer is a later relative-level stage.

### Modulation, rhythm, and production meaning

- Two LFOs, four envelopes, velocity, and four assignable controllers can
  modulate most synthesis parameters. A `via` source scales or can reverse the
  first modulation's range. LFOs can reach 100 Hz, stop after 1-100 cycles,
  retrigger per note, or free-run; the latter can enrich a sound at the cost of
  repeatable percussive attack.
- The two-segment Bezier envelopes normally run one-shot, ignoring note-off.
  Sustain mode and/or per-voice Gate is required for sequenced gate length to
  govern note duration.
- Swing moves only even-numbered steps and works only at 1/8 or 1/16 grid
  resolution. Accent is per sound; exported accents become polyphonic
  aftertouch. Step automation stores relative parameter offsets, not absolute
  values, and excludes menus, buttons, and pan/spread.
- Random trigger/velocity/gate/offset operations and free LFO state are creative
  operations, not deterministic production facts. Exporting a pattern while
  leaving the internal sequencer active can double-trigger it.
- Apple's kick/snare/cymbal tutorials strongly support component hypotheses:
  separate body, pitch-drop attack, noise/snare wire, transient, resonance, and
  decay layers. Their named 808/909/Kraftwerk approximations are pedagogical
  recipes, and Apple explicitly says some original circuits cannot be reproduced
  exactly. TrackSmith must not promise exact hardware replication.

## Instrument utilities

- External Instrument unifies MIDI destination/channel, return audio input,
  gain, optional reported-latency compensation, and bank/program transmission.
  External hardware must bounce in real time; program/bank changes can be sent
  automatically when state loads. These are external-state mutations and remain
  outside TrackSmith's current execution authority.
- Klopfgeist is a mono/four-voice click instrument with pitch, detune, tonality,
  damping, and velocity-scaled level. A click used for recording/cueing is not
  automatically part of the desired mix or analysis source.
- Test Oscillator is documented with the effect utilities and is intended for
  calibration. Test signals require explicit routing and level safeguards; they
  must never be injected into a live project by conversational inference.

## Vintage keyboard models

### Vintage B3 Organ

- Vintage B3 models an additive tonewheel organ with upper/lower manuals and
  pedals, drawbar registrations, scanner vibrato/chorus, upper-manual
  percussion, key contact/click, tonewheel leakage/crosstalk, pitch irregularity,
  and multiple modeled/IR Leslie cabinets.
- Drawbars combine a sparse set of harmonic footages rather than a complete
  spectrum. The 8' and 5 1/3' registrations can invoke the missing-fundamental
  residual effect; low-register upper harmonics can also imply unintended major
  harmony. Overdrive is commonly useful partly because it fills in harmonics,
  but this is a practice consequence, not a requirement.
- Scanner vibrato is a tapped analog-delay/capacitor-scanner model, not an
  ordinary LFO chorus. Leslie movement combines amplitude, spectrum, Doppler,
  acceleration/deceleration, bass/horn rates, cabinet, deflectors, microphone
  type/position, and stereo geometry. Slow/Fast/Brake is therefore a stateful
  performance gesture, not merely a static modulation rate.
- Percussion can be mono per note or B3-style polyphonic retriggered only after
  every key is released. Registrations store drawbars only; full plug-in settings
  store broader state. Preset-key switching can retrigger held chords.
- The integrated chain allows EQ, Wah, and Distortion reorder, then Reverb and
  rotor placement. Bypassing pedal-register effects can preserve bass and avoid
  distortion intermodulation. Distortion auto-compensates output, which does not
  guarantee perceptual loudness equality.
- Warmth, click duration/color, leakage, crosstalk, filter age, and Random FM
  intentionally add random or aged-condition behavior. They cannot guarantee
  identical renders or be reduced to a single “vintage” intensity.

### Vintage Clav

- Vintage Clav is a component model of a D6-like string/hammer/pickup system,
  expanded to stereo/full MIDI range and several non-D6 models. Pickups can be
  freely moved/angled/wired; crossed or opposed pickups can create phase
  cancellation and silent keyboard zones.
- Models deliberately include key-to-key timbral jumps, inharmonicity, hammer
  wear, release clicks, string sticking, tension/pitch fall, and, for Funktone,
  long-term resonant collapse. These behaviors can be intended character or a
  constraint violation depending on the request.
- String Damping, Stiffness, Inharmonicity, Tension Mod, hammer Excite, click
  randomization, pickup geometry, and key/pickup stereo spreading act at
  different physical stages. “More bite” need not mean treble EQ.
- Its serial effects—compressor, distortion, phaser/flanger/chorus, and wah—can
  be reordered. Compressor position changes distortion drive; wah-before-drive
  and drive-before-wah produce different spectra. Apple warns that extreme
  Phaser rate/intensity can endanger ears and speakers.

### Vintage Electric Piano

- The component model covers Rhodes-, Wurlitzer-, Electra-, and synthetic
  variants without sample-zone transitions. Tine/reed/tone-bar motion, pickup
  interaction, hammer/damper transients, decay, and note noise are modeled.
- Drive is documented as the first effect stage and the model-dependent EQ is
  documented after Drive. Chorus, a four-filter analog-style phaser, and
  mono/stereo tremolo provide further motion. Drive Tone pre-equalizes the
  nonlinear stage; EQ after it is not equivalent.
- Tine Bell, Decay, Release, Damper Noise, velocity-dependent delay, polyphony,
  and key-based width change attack, sustain, mechanism, playability, and
  stereo—not just static tone. Model changes reset parameters and mute voices.
- Warmth is random per-note detuning. Stretch tuning is supplied chiefly for
  matching acoustic piano; the manual explicitly notes the physical stretch
  rationale does not apply to electric pianos themselves. Combining both can
  sound severely out of tune.

### Vintage Mellotron

- Vintage Mellotron samples the pitch/performance irregularity of original
  note-by-note tapes but loops them for indefinite sustain, unlike the original
  eight-second hard stop. It can blend any two library sounds and independently
  octave-shift them—capabilities broader than the source hardware.
- Tape Speed changes pitch/tone globally; Tone reduces bass toward the bright/
  nasal direction or reduces brightness toward warm/mellow. Attack, Release,
  pitch bend, and velocity response are modern extensions and may reduce source
  authenticity. “Authentic Mellotron” therefore requires stating which original
  limitation is being preserved or intentionally relaxed.

## Legacy instruments and synthesis fundamentals

- Legacy instruments are compatibility-focused, lower-resource variants that
  are hidden unless the insert menu is Option-opened. They load automatically
  for older GarageBand/Logic/MainStage content. Their simplified macros do not
  disclose the exact lower-level mappings of the instruments on which many are
  based; TrackSmith must not infer parameter identity from a shared name.
- External Instrument Legacy should be replaced with the current External
  Instrument according to Apple. That recommendation does not authorize an
  automatic host mutation.
- Apple's synthesis appendix confirms the major architecture distinctions used
  throughout this atlas: subtractive filtering; sample playback's coupled
  speed/pitch; FM carrier/modulator ratios and sidebands; component modeling;
  wavetable/vector/LA methods; additive partials; spectral bins; additive versus
  spectral resynthesis; phase distortion; and granular 2-230 ms particles.
- The appendix is explicitly introductory, not a scientific or mathematical
  specification. Its adjectives and simplified waveform/filter explanations
  are useful user education but cannot substitute for calibrated measurements,
  primary DSP literature, or implementation disclosure.
- A complete read of the 2026 rights page establishes local learning use only;
  no redistribution or training right is inferred from possession of the PDF.

## Current contradictions, ambiguity, and non-overclaim ledger

- Apple repeatedly uses production adjectives as navigational language. Those
  labels are useful vocabulary evidence but are not measurement definitions.
- Alchemy and Sample Alchemy both use additive/spectral/granular concepts but
  have different routing, editing, modulation, and playback models. Advice must
  identify the actual instrument.
- Logic instruments contain internal effects that may resemble channel-strip
  effects but do not necessarily expose the same algorithm or gain structure.
- “Analog” controls often add random pitch/filter variation; they are not proof
  of comprehensive analog-circuit emulation.
- Wavetable, granular, spectral, and morph results can be source-analysis
  dependent and nondeterministic. A successful example does not establish a
  general mapping from an adjective to a parameter.
- Apple documents some precise mechanisms and some intentionally broad macros.
  TrackSmith must state when the exact implementation behind a macro is unknown.
- The current Instruments PDF omits Quick Sampler's standalone chapter even
  though the PDF text references it and Apple's live 12.3 table of contents
  contains it. The 16 validated web pages above are a canonical supplemental
  source; PDF completeness alone must not be equated with instrument coverage.
- Apple labels the legacy Electric Piano tremolo as “wobbling pitch,” whereas
  the full Vintage Electric Piano chapter correctly defines tremolo as amplitude
  modulation. Treat the legacy wording as a documentation error, not DSP truth.
- The synthesis appendix describes white noise imprecisely as all frequencies
  “at full level” around a center frequency. Use accepted noise power-spectral-
  density definitions and measured behavior for engineering claims.
- The B3 Leslie history uses a loose train/Doppler analogy that mixes perceived
  level, spectrum, and relative-motion pitch. It is useful pedagogy, not a full
  acoustic model of rotating-speaker radiation and room pickup.
- Studio/Vintage model names and phrases such as `faithfully`, `accurately`, or
  `ultra-realistic` are Apple product claims. The manual supplies controls and
  workflows, not comparative listening-test evidence establishing universal
  realism.

## Required empirical and listening follow-up

1. Render calibrated impulses, sines, multitone signals, noise, drum hits,
   chords, and velocity/range sweeps through representative instrument states.
2. Compare per-voice drive with post-sum distortion for intermodulation and
   level behavior.
3. Measure mono fold-down and correlation for unison, Stereo Detune, Stereo
   Spread, grain panning, EVOC band spreading, and modulation effects.
4. Test repeated-render stability for free oscillator phase, random round robin,
   granular randomization, note-on random sources, and randomized patches.
5. Verify preset/patch portability when samples, impulse responses, user
   wavetables, and external side chains are involved.
6. Evaluate playable range, velocity, legato, articulation, release, and voice
   stealing—not merely a static note.
7. Use level-matched, blinded listening where an artistic preference is being
   claimed. Measurements may reject unsafe or constraint-breaking candidates;
   they cannot prove that a sound is “expensive,” “alive,” or “better.”
8. Test Quick Sampler `Original` versus `Optimized`, region-resample versus file
   import, Flex modes, voice stealing, loop/crossfade commands, and every
   potentially file-mutating Action command on disposable copies before making
   source-preservation or deterministic-render claims.

## Instruments-guide completion statement

The actual relevant content of all 752 PDF pages and all 16 canonical Quick
Sampler web sections was read, including the PDF copyright and usage notice.
The `Deep` ledger therefore covers the complete retained PDF plus its identified
live-guide omission, not only outline or search hits. This establishes documented control behavior,
signal/routing models, warnings, and Apple-authored teaching practice. It does
not disclose proprietary implementation internals, prove Apple's subjective
sound-quality adjectives, or establish that TrackSmith can execute Logic-native
instrument edits.

The reviewed synthesis is also available to Production Intelligence as 28
bounded, source-hashed, advisory-only entries in
`research/knowledge/logic-pro-12.3-instrument-knowledge.json`. Retrieval
requires an explicit instrument name or reviewed alias. The generated Swift
catalog contains no MIDI, automation, parameter, preset, or host-action
payload and cannot become a `ProcessingNode`.
