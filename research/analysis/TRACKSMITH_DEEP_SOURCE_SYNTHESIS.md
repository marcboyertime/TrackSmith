# TrackSmith deep source synthesis

Status: prior implementation milestone complete; comprehensive research expansion active  
Last updated: 2026-07-16

## Purpose and evidence discipline

This is TrackSmith's decision record for what the underlying sources establish,
where they disagree, and what the product may safely infer. It is deliberately
not a bibliography or a sequence of abstracts. A source is marked **full-read**
only when the actual relevant payload was reviewed beyond its abstract or summary,
including methods, equations or algorithms, test conditions, limitations, and
conclusions. A source still awaiting that treatment cannot settle architecture or
product semantics here.

Evidence classes used below:

- **Strongly established**: normative primary standard or convergent primary
  evidence within its stated scope.
- **Moderately supported**: peer-reviewed or otherwise methodologically useful
  primary work with material scope, data, or ecological-validity limits.
- **Expert-practice heuristic**: professional workflow advice that is useful as
  a candidate strategy, never a universal acoustic law.
- **Product heuristic**: a bounded TrackSmith policy chosen for safety or UX and
  labelled as such.
- **Disputed or source-dependent**: definitions, methods, or conclusions vary.
- **Perceptual**: listening remains decisive and no single measurement proves the
  requested quality.

## Current synthesis: what TrackSmith can defend

### Strongly established

1. BS.1770-5 defines a specific programme-loudness algorithm: two-stage
   K-weighting, channel-weighted mean-square energy, 400 ms blocks, 75% overlap,
   an absolute gate at -70 LKFS, and a relative gate 10 LU below the
   absolute-gated level. It does not define a general-purpose music-production
   quality score.
2. EBU Mode Short-term Loudness is an ungated rectangular 3 s measurement with
   an update rate of at least 10 Hz. It is distinct from both Integrated Loudness
   and the 400 ms blocks used by the Integrated gate.
3. EBU Loudness Range is the difference between the 95th and 10th percentiles of
   a separately gated Short-term Loudness distribution. Its absolute gate is
   -70 LUFS, its relative gate is -20 LU, and the reference percentile index uses
   `round((n - 1) * p / 100 + 1)` in one-based indexing.
4. EBU explicitly does not recommend LRA for programmes shorter than one minute.
   Short or isolated material can produce misleading results. Therefore
   TrackSmith may compute an LRA for a 3-60 s capture, but must mark it unstable
   and must not treat it as a production verdict.
5. True-peak measurement is an oversampled estimate. BS.1770-5's 48 kHz reference
   uses a 48-tap, four-phase FIR and documents residual under-reading at high
   normalized frequencies. TrackSmith must not describe a finite phase-grid
   estimate as the unknowable continuous-time maximum.
6. The official BS.2217-2 files define reproducible mono/stereo Integrated
   Loudness checks. Passing a subset supports the tested algorithms and layouts;
   it is not proof of conformance for immersive layouts, live meter ballistics,
   every sample rate, or every true-peak case.

### Moderately supported

- Explicit, human-readable effect controls are a useful architectural bias across
  the reviewed compressor, automatic-EQ, differentiable-console, and effects-
  transfer studies. The evidence does not establish one correct mix, one target
  spectrum, or fixed meanings for production adjectives.
- Source identity and context can improve bounded EQ/compression hypotheses, but
  the reviewed datasets and listening panels are too limited to turn source-class
  averages or correlations into universal production rules.
- Low-level spectral, temporal, periodicity, and stereo descriptors can support a
  production hypothesis when their valid conditions are met. A descriptor's
  presence in an analysis library does not validate its semantic interpretation.
- Language is a useful interface for expressing edit targets and preservation
  constraints, but current audio-language and foundation-editing evidence does
  not establish reliable open-domain perceptual judgment. Structured grounding,
  source-local evidence, explicit preservation constraints, and human listening
  remain necessary.
- A small producer study supports iterative revision, editability, multiple
  candidates, and DAW integration as useful workflow directions. Its 17-person,
  one-hour, one-model design does not establish universal producer behavior.

### Expert-practice and product heuristics

- The EBU broadcast target of -23 LUFS and linear-production maximum of -1 dBTP
  are profile-specific workflow recommendations. They are not universal targets
  for stems, music masters, previews, or streaming delivery.
- TrackSmith's decision to use a minimum three-second input before exposing LRA
  is a conservative product validity condition. Tech 3342 warns about very short
  material but does not turn three seconds into a universal perceptual boundary.
- Marking LRA from 3-60 seconds as `unstableBelowSixtySeconds` is an explicit
  product representation of the EBU warning, not a claim that 60 seconds makes
  every measurement perceptually representative.

### Disputed or source-dependent

1. **Momentary ballistics differ.** ITU-R BS.1771-1 specifies a first-order IIR
   with a 400 ms time constant over squared energy. EBU Tech 3341 v4 keeps its
   original ungated rectangular 400 ms window and states that the two can differ
   by as much as 2 LU. TrackSmith's current `maximum_momentary_loudness_lufs`
   is the EBU rectangular definition and must be labelled EBU Mode, not presented
   as a generic implementation of every BS.1771 display.
2. **Loudness units do not equal perceived increments.** BS.1771 describes LU as
   the gain adjustment applied to the signal and notes that the loudness estimate
   assumes fixed electroacoustic gain. TrackSmith must not say that a 1 LU meter
   difference guarantees a fixed subjective loudness difference in every room,
   playback level, or programme.
3. **Downmix and rendering are source-dependent.** BS.1770-5 Annexes 3-4 and
   Tech 3343 show that renderer choice, coefficients, correlation, and limiting
   can change objective loudness. A stereo measurement cannot certify an
   unmeasured immersive or alternate downmix.

### Perceptual boundaries

- Integrated Loudness, Short-term Loudness, LRA, true peak, crest factor, and
  spectrum describe different properties. None proves that audio is polished,
  punchy, warm, professional, over-compressed, or preferable.
- Tech 3343 recommends mixing by ear under controlled monitoring and treats the
  loudness measures as workflow aids. LRA has no universal brick-wall production
  limit; experienced listening remains decisive.
- BS.1770's listening development used broadcast-like material and a particular
  loudness-matching procedure. Its high correlation in those experiments does
  not validate every isolated stem, pure tone, or semantic production judgment.

## Logic Pro 12.3 and Audio Unit host-contract synthesis

### Source identities and review extent

The current Logic payload reviewed was Apple's *Logic Pro User Guide for Mac*,
downloaded 14 July 2026, PDF creation date 7 July 2026, 1,324 pages, SHA-256
`aa016d18d7e4f3559cdec54a99937d00b379617fee87510db1ec9853a4996cff`.
Review status: **complete read of every page**, finished 15 July 2026. All 1,324
pages were read in bounded extracted-text ranges, including every editor, tool,
recording/import/arrangement workflow, Session Player, mixer/routing/automation,
Live Loops, Step Sequencer, global/score/bounce/Spatial/video/sync family,
application/project setting, command and pointer table, Touch Bar, control-
surface/controller-assignment chapter, Environment object reference, glossary,
and rights page. Extracted text was checked against rendered PDF pages for the
plug-in, latency, automation, bounce, and other layout-sensitive families. The
detailed page ledger, contradictions, destructive-state analysis, and direct
TrackSmith consequences are in
`TRACKSMITH_LOGIC_PRO_12_3_WORKFLOW_ATLAS.md`.

Apple's *Control Surfaces Support Guide for Logic Pro*, current PDF downloaded
14 July 2026, 220 pages, SHA-256
`5ab5e4ef38e9c8e9279a0a2d36dcaabd1a9471942843d0162a3016f6ebf9322c`,
was **read completely through all 220 pages**, finished 15 July 2026. The review
covers the overview and all 21 named device/profile families, every default mapping,
modifier/mode/page/feedback rule, setup dependency, troubleshooting note, and
rights page. Rendered pages 15, 67, and 138 confirm three important errors are in
the PDF layout rather than extraction: Mackie Insert 2 confirmation names V-Pot 4,
both EuCon Link branches say Link enabled, and C4 Prev/Next labels invoke the
opposite commands. Detailed findings and a page ledger are in
`TRACKSMITH_LOGIC_PRO_CONTROL_SURFACES_ATLAS.md`. Apple's mutable current release-
notes page was separately captured through the fail-closed ingestion contract on
16 July 2026 (1,247,448-byte validated HTML, SHA-256
`854fd08c8e38351d521a9feed35a77fc2ce5969baab473e270decd2425f0dcb0`).
The complete Logic 12.3 section was read, not only its feature bullets: Beat
Breaker and Alchemy changes, AU scanning/UI fixes, ARA save/reload, automation,
bounce/export, control-surface feedback, Flex/tempo state, routing above channel
128, Sampler state, and recording/import changes were reviewed. The hash applies
only to that dated mutable-page capture. Current web versions of Audio Units and
Selection-Based Processing were also cross-checked against the PDFs.

The public Audio Unit source family comprised Apple's current `AUAudioUnit`
reference, *Audio Unit v3 Plug-Ins*, and *Configuring App Groups*, retrieved
14 July 2026. Review status: **full relevant-source read**. The top-level payloads
were read completely; linked DocC nodes for render resources, input/output busses,
state, scheduling, latency, tail, bypass, offline rendering, in-place processing,
musical/transport context, and render-context observation were read at their
canonical endpoints. Local retrieval-payload hashes are respectively
`28c345afae3ff1570478e3f8f5650a025cc8ebcf19cff65681dd5b31137b821f`,
`6741f5a19723b268025c1bf29ff20d725373dcaf6a40b07648843d61dcef7504`,
and `31d91f7cced5fef3c445cbd1ab3df22faf79f2e8be898d79ca710ca91ede1ca8`.
These hashes identify retrieved representations, not immutable versions of
Apple's mutable web documentation.

The official ARA page available through Apple's versioned Logic guide is for the
Logic 11.x documentation family, not a newly versioned 12.3 chapter. It was read
in full and cross-checked against the current 12.3 release notes, which still
document ARA save/reload fixes. This establishes current maintenance of ARA in
12.3 but leaves a documentation-version gap; TrackSmith must not silently describe
the older workflow page as a new 12.3 API contract.

### What the host documentation strongly establishes

1. Logic 12.3 presents AUv2 components and AUv3 app extensions in the same Audio
   Units menus and identifies AUv3 with `(AU3)` in Plug-in Manager. Discovery,
   compatibility scanning, insertion, parameter editing, copying, host bypass,
   settings, latency handling, and project reload are ordinary plug-in workflows.
2. `AUAudioUnit` owns audio busses, parameters, render behavior, and its own state.
   `internalRenderBlock` is the real-time render contract; the host sets
   `maximumFramesToRender` before allocating render resources and that value is
   immutable while resources remain allocated. The render path therefore cannot
   discover an arbitrary new maximum, allocate opportunistically, or block.
3. `scheduleParameterBlock` is safe for a host to call from any thread and routes
   parameter events to the render implementation. Musical-context and transport
   callbacks should be queried outside the hottest render work and cached in
   real-time-safe storage. These are timing/context services, not project-editing
   authority.
4. `fullState` is for all non-transitory plug-in state, while
   `fullStateForDocument` distinguishes document state from global/preset state.
   The base implementation persists parameters by depth-first pre-order traversal
   but does not persist stream formats. TrackSmith's graph, locks, commit state,
   and bypass representation must therefore be explicitly versioned and restored;
   stream-layout negotiation remains separate.
5. `latency` reports the DSP's impulse input-to-output delay and `tailTime` reports
   the post-input time until silence. Logic compensates plug-in latency across
   channel strips, automation, and sidechains, but Low Latency Monitoring can
   bypass a plug-in when total path latency exceeds the user threshold and can
   disable sends. Low Latency Monitoring is inactive during project bounce.
6. `isRenderingOffline` permits a plug-in to choose work that is not constrained
   by a real-time deadline; it does not make nondeterministic network calls or
   mutable cloud state safe for a reproducible bounce. Automatic Logic bounce may
   select offline or real-time, and all unmuted parameters, effects, and automation
   are included. TrackSmith must be correct in both render modes and preserve
   effect tails where the host requests them.
7. Logic track automation reads or writes automatable parameters through Read,
   Touch, Latch, Write, Trim, and Relative workflows. Relative mode is restricted
   to volume, pan, and send. TrackSmith's semantic plan/commit transaction is not
   equivalent to Logic's automation timeline; any future exposure of graph
   controls as automatable AU parameters needs stable IDs, ranges, smoothing, and
   conflict policy.
8. Selection-Based Processing operates on a selected region or marquee, uses an
   independent effect chain with A/B sets, can preview in context, can create a
   new take, can include tails, and offers gain/loudness/overload options. This is
   a strong UX and safety analogue for preview/compare/commit, but Apple's user
   guide does not grant an ordinary AU knowledge of the selection or permission
   to invoke the host workflow.
9. Apple's ARA documentation explicitly describes sharing song structure,
   regions, associated audio files, transients, pitch analysis, and updates between
   host and compatible plug-in. It also requires the first insert slot, a playback
   transfer, disables Flex and Compare, and warns about Freeze compatibility. The
   existence of this separate integration is further evidence that a plain AU
   should not be treated as having equivalent region/file access.

### Control surfaces, companion communication, and source-file safety

Logic control surfaces can operate mixer and automatable plug-in parameters,
receive feedback, and write automation, but the complete source shows much broader
and riskier authority than those phrases imply. Depending on device/profile/mode,
they can insert or remove instruments/effects, insert Channel EQ implicitly, change
input/output/format/sends/groups, arm and record, overwrite all-channel automation,
move/quantize/delete regions and events, change cycle/punch/sync, control external
recorders, save or Save As, emit keyboard input, open the destructive Audio File
Editor, and accept a modal dialog's default button. Hardware labels are never stable
operation IDs: device/firmware/profile, port, group, bank, view, overlay, page, strip
focus, modifier, touch/press, pickup, staged confirmation, and user assignment all
participate. EuCon bypasses Controller Assignments; HUI/Mackie emulation may omit or
reinterpret controls; nonmotorized pickup may deliberately ignore movement; feedback
can be truncated or hidden by banking.

The Mackie documentation is explicit that only automatable plug-ins are editable and
that missing parameter names fall back to generic `Control #N` labels with normalized
values, which are neither semantic identities nor physical units. Multiple source
contradictions—including SELECT/F8/EQ/Solo/zoom mappings, Launchpad orientation prose,
Yamaha zoom directions, and copied cross-device labels—make live mapping capture
mandatory. Control-surface access still does not expose region audio payloads,
arbitrary project serialization, or an undo-safe audio-replacement API. Current
Apple-silicon requirements also constrain third-party control-surface plug-in
compatibility. It is not a viable hidden project-editing back door for TrackSmith,
and model/provider output receives no MIDI, OSC, EuCon, HUI, Lua, Learn, key-emulation,
or dialog authority.

Apple App Groups support a shared container and same-team IPC mechanisms such as
Mach/POSIX facilities, shared memory, and UNIX sockets. That supports the existing
AU-extension/companion split, subject to entitlement and signing validation. It
does not change Logic's host authority: the companion only knows what the plug-in
deliberately captures and publishes. The original project audio file remains
outside the render contract; TrackSmith's capture/preview/commit flow must keep
source-file hashes unchanged and persist its own reversible state.

### Direct consequences and prohibited overclaims

- Current production architecture remains a deterministic AUv3 render core plus
  companion process and explicit versioned graph/state. No LLM or network work is
  permitted on the render thread or required for an offline bounce.
- TrackSmith may say it is Logic-hosted and Logic-aware only for workflows it
  validates. It must not claim arbitrary project editing, selected-region access,
  source-file ownership, ARA behavior, or control-surface authority.
- Host bypass and TrackSmith's internal reversible bypass are distinct states and
  both require tests. A host can also deactivate an inactive signal-flow plug-in;
  live-instance discovery must tolerate lifecycle transitions.
- Validation must cover Plug-in Manager discovery, Apple-silicon AU isolation,
  maximum render quantum, state save/reload, online/offline bounce, latency and
  tail reporting, Low Latency behavior, automation interaction, multiple-instance
  isolation, and unchanged project-source hashes.
- Logic 12.3 release notes include fixes in AU scanning/UI, ARA save/reload,
  automation, and bounce. Historical Logic 11.2.2 proof remains valid evidence for
  that exact host; it was not silently promoted to 12.3. The separate direct
  Logic 12.3 build-6674 deterministic host lane has since completed and remains a
  distinct dated evidence record. The still-pending frontier-provider Logic
  session must not be confused with that deterministic host proof.

## Logic Effects and source-aware production-practice synthesis

Source identity: Apple, *Logic Pro Effects for Mac*, current guide downloaded
14 July 2026, 390 pages, SHA-256
`b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819`.
The same immutable payload was independently retained by the fail-closed archive
on 15 July 2026. Review status: **complete technical read of the full guide**,
finished 15 July 2026. All processor families, parameter and signal-flow sections,
mode differences, source limitations, examples, utilities, MIDI processors, and
legacy exceptions were read. Rendered pages were visually checked for Pedalboard
routing and Bitcrusher controls. The manual is a primary source for what Apple's
processors expose and how Apple describes their operation. It is not a source for
undocumented transfer functions, and its creative advice is an **expert-practice
heuristic**, not an experiment or universal law. The detailed tool-by-tool
synthesis is maintained in `TRACKSMITH_LOGIC_PRO_12_3_TOOL_ATLAS.md`.

### Strongly established tool and signal-path facts

- Compressor exposes model, threshold, ratio, knee, attack, release, make-up,
  Peak/RMS, stereo Max/Sum, side-chain filtering, wet/dry, limiter, and distortion
  choices. This reinforces that “compression” is not one transform and that a
  TrackSmith hypothesis must state transient, detector, channel-linking, and
  level-preservation consequences.
- DeEsser 2 compares a selected high-frequency band with either the full-band
  signal (Relative) or an absolute threshold, applies bounded reduction in Split
  or Wide mode, and provides detector solo. This supports **relative, event-aware
  high-band evidence** over a whole-file 5–10 kHz ratio, and bounded reduction to
  preserve consonant intelligibility. It does not prove that every high-band event
  is sibilance.
- Enveloper independently alters attack and release evidence; increasing attack
  can emphasize drum snap or string pick/pluck, while decreasing it softens
  percussion. Increasing release can expose ambience and noise. Consequently a
  “punch” or “tight” request must preserve or alter attack and sustain separately,
  not infer both from crest factor alone.
- Channel EQ implements explicit high/low-pass, shelves, four bell bands, output
  gain, pre/post FFT analysis, stereo/L/R/Mid/Side modes, and oversampling. Linear
  Phase EQ trades phase shift for greater latency and can alter transient onset,
  especially with steep cuts or narrow large moves. “Preserve attack” is therefore
  a processor-selection constraint, not just an EQ-gain limit.
- Distortion/saturation processors are nonlinear and generate or reshape harmonic
  energy; drive, pre/post filtering, mix, symmetry, compensation, and model all
  change the result. Exciter high-passes before harmonic generation, so it creates
  high-frequency content absent from the input rather than simply boosting an
  existing air band. These are distinct candidate strategies with different
  aliasing, intermodulation, transient, and loudness risks.
- ChromaVerb separately exposes predelay, early/late balance, distance, decay,
  frequency-dependent damping, output EQ, width, and low-frequency mono making.
  Space Designer convolves with a recorded or synthesized impulse response and
  cannot automate every parameter because IR changes require recalculation.
  “Intimate,” “distant,” “wide,” and “ambient” therefore span direct/effect level,
  predelay, early/late energy, decay spectrum, modulation, and stereo—not one
  reverb-time metric.
- Direction Mixer makes LR spread 0 a mono sum and values above 1 wider than the
  speakers; in MS mode the same control changes side level. Correlation below zero
  signals possible mono cancellation, and -1 cancels identical opposite-polarity
  channels. A widening plan must inspect mid/side and low-frequency behavior and
  validate the mono render, not maximize width.
- Pedalboard is a left-to-right graph with serial processing and two discrete
  buses. Splitter can duplicate or frequency-divide the source; Mixer controls
  branch recombination and panning. Moving either utility changes which pedals
  are common, parallel, or downstream. A pedal recipe therefore requires graph
  topology, gain, channel format, and mono/phase checks—not merely a list of
  stompbox names.
- Bitcrusher separates amplitude quantization (Resolution, 1-24 bits) from
  sample-rate division (Downsampling) and from thresholded Fold/Clip/Wrap
  nonlinear behavior. Downsampling deliberately aliases without changing pitch
  or speed. “Lo-fi,” “warm,” and “dark” cannot be inferred from one control.
- Delay Designer exposes as many as 26 independently timed, filtered, pitched,
  panned/spread and leveled taps, with a single feedback tap. Tape Delay adds
  time deviation/smoothing, feedback filtering, clipping, head, LFO/flutter,
  spread and freeze behavior. “Delay” is therefore not one transform or one
  distance cue.
- Logic's Scripter is a JavaScriptCore real-time MIDI environment with event,
  timing and parameter APIs, and scripts persist with settings/projects. This is
  executable code, not a safe natural-language control surface. TrackSmith's
  provider output must never gain Scripter authority.
- Auto Sampler records note/velocity ranges into a sampler instrument. Effects
  before Auto Sampler are baked into every sampled note; effects after it are not.
  This distinguishes instrument capture from editable mix processing and remains
  a host workflow outside an ordinary TrackSmith AU's authority.

### Useful heuristics, never semantic truth

- Apple's vocal de-essing workflow says human sibilance is *typically* in the
  5–10 kHz region and warns that over-reduction sounds unnatural. TrackSmith may
  treat short relative high-band excess in that region as vocal sibilance evidence,
  with source/confidence gates; the band is not a phoneme detector.
- The manual advises longer compressor attack to retain defining transients and
  notes that attack/release outcomes depend on source, threshold, and ratio. This
  agrees with the compressor papers' context dependence. It does not establish a
  universal fast/slow mapping for drums, vocals, bass, or guitar.
- Apple's Channel EQ workflow recommends inspecting repeated spectral peaks and
  deciding by intent whether to cut or emphasize them. It explicitly says use
  depends on material and outcome. TrackSmith may expose spectral concentration
  evidence, but a peak is not automatically resonance, masking, harshness, or an
  EQ target.
- The guide commonly reduces side low-frequency content and warns that Stereo
  Spread below 300 Hz can alter mix energy. This supports low-end mono-compatibility
  checks and a conservative low-side-energy constraint, not a universal 300 Hz
  crossover or mandatory mono bass.
- ChromaVerb says short predelay tends to push a sound away and longer predelay can
  bring it forward, while extremes color or detach the source. That is a processor-
  specific practice model; distance perception also depends on direct/reverberant
  ratio, early energy, spectrum, source, and monitoring.

### Contradictions and overclaims in the manual

- The Level Meter section calls RMS an indication of perceived loudness and says
  human ears are “RMS instruments.” This is pedagogical shorthand, not the
  standards algorithm, and conflicts with the frequency/channel/gating model in
  BS.1770. TrackSmith keeps RMS as level/dynamics evidence and uses BS.1770/EBU
  metrics for standards-derived loudness.
- MultiMeter twice calls its loudness behavior “AES 128,” while the dedicated
  Loudness Meter says it conforms to **EBU R 128**. No normative AES 128 standard
  was identified. TrackSmith treats the MultiMeter wording as an apparent manual
  error and takes its standard mapping only from untouched ITU/EBU sources.
- ChromaGlow descriptions claim that saturation yields “polished” or
  “professional-sounding” output and assign *warm*, *vintage*, *punchy*, and
  *muddy* to models. Those are Apple product descriptions with no methods,
  listening data, or acoustic definitions. They can seed candidate vocabulary
  with `professional-practice heuristic` provenance only; they cannot define an
  intent term or justify automatic saturation.
- Correlation 0 is described as the widest permissible divergence. Zero-lag
  correlation alone is content-, window-, and frequency-dependent and does not
  certify a preferred or artifact-free stereo image. TrackSmith must retain
  correlation as bounded mono-risk evidence and directly inspect low-band side
  energy and mono loss.
- Bitcrusher twice says “Cut mode” where the interface and surrounding text say
  Clip. ChromaGlow's Low Cut/High Cut descriptions appear to swap low-pass and
  high-pass terminology. The Step FX section once calls its filters “Phat FX
  filters.” These are recorded as apparent documentation defects; TrackSmith does
  not invent an internal topology from them.
- Mastering Assistant describes approximately -14 LUFS-I as a typical center and
  discusses -1 dBFS true peak as meeting a requirement. The same section says the
  loudness center is not strict or necessarily best. TrackSmith treats both as
  workflow examples, not universal streaming, mastering, or artistic targets.

### TrackSmith consequences

Source-aware analysis v1 should compute descriptive band energy, short-time
envelope/crest/flux, event density, mid/side or correlation evidence, and standards
loudness with explicit source applicability and failures. It must not emit
*muddy*, *harsh*, *sibilant*, *punchy*, *warm*, *wide*, or *professional* as a
single-metric diagnosis. The intent system may combine several observations into
one or more production hypotheses, but it must preserve competing strategies,
make processor risks visible, and label listening as decisive where appropriate.

### Documentary closure versus empirical closure

TrackSmith now has a fail-closed coverage audit over the immutable source objects
and generated catalogs. It validates four manuals/2,686 pages, every one of the
142 effect/native-tool identities inside its declared Effects-guide page range,
all 35 Pedalboard effects plus Mixer and Splitter, 27 instrument identities in the
Instruments PDF plus the 16-page canonical Quick Sampler supplement, and all 30
named editor tools in User Guide pages 54-60. This is **documentary identity and
provenance coverage**, not empirical proof of every transfer function or musical
use.

The distinction changed the engineering plan. A reproducible 48 kHz PCM24
measurement suite now covers silence, impulse/level ladders, logarithmic sweep,
amplitude ladder, multitone, two intermodulation pairs, dynamic bursts,
guitar/bass/vocal-like probes, and six stereo/phase/channel states. The versioned
campaign ledger enumerates all 200 reviewed native identities (142 effects/tools,
28 instrument/utility identities, and 30 editor tools). Each identity starts at
`not_run` and can change status only through a versioned, hash-audited direct-host
run record. Its protocol requires exact Logic/build/channel/preset/parameter/
routing/render/input/output identities, repeated renders, unchanged source hashes,
and separate documented, measured, and practice-heuristic claim layers.

The first such record was completed on 18 July 2026 for Bitcrusher's observed
Default Preset in Logic 12.3 build 6674 at 48 kHz mono. It is deliberately
`partial`: Default was directly observed as Clip, +3 dB Drive, 8-bit Resolution,
1x Downsampling, 100% Mix, and 0 dB Clip Level; three settled active renders and
one post-reload render were decoded-PCM identical; three settled bypass renders
were sample-identical to the source. The run also found short, one-time differences
in the first render after active/bypass state transitions. That observation changed
the measurement protocol: the first render is retained as diagnostic evidence, and
transfer claims require at least three settled decoded-PCM repeats. Fold, Wrap,
parameter grids, alias spectra, stereo, other rates, musical material, and listening
remain unmeasured.

A second partial record now covers Channel EQ in the same Logic build and 48 kHz
mono boundary. Three settled unmodified-default renders and three settled header-
bypass renders were sample-identical to the fixture. Peak 3 at 1000 Hz, +6.0 dB,
Q1 measured approximately +6 dB at every unclipped ladder level, repeated with
identical decoded PCM three times, and survived save/reload. The -6, -3, and -1
dBFS input steps reached the PCM24 export ceiling; segment-aware analysis was added
so their clipping no longer biases one whole-file gain estimate into a false EQ
claim. Other bands, slopes, frequency/Q grids, HQ, channel modes, broadband phase/
group delay, stereo, other rates, automation, musical material, and listening remain
unmeasured.

A third partial record covers Compressor. Three observed-default renders repeated
exactly but were not neutral because Auto Gain -12 dB was active; three header-
bypass renders matched the source PCM. One controlled Platinum Digital Peak/hard-
knee state at threshold -20 dB and ratio 4.1:1 agreed with the public hard-knee
static relation within 0.000128 dB across the above-threshold steady ladder steps.
The first controlled render differed only at samples 1-1022, while subsequent and
post-reload renders matched exactly. Timing, detector isolation, six circuit models,
stereo linking, side-chain filters, distortion, limiter, parallel mix, other rates,
musical material, and listening remain open. The campaign is therefore 197
`not_run`, three `partial`, and zero `complete`, not “Bitcrusher, Channel EQ, and
Compressor characterized.”

Therefore TrackSmith may currently explain what the reviewed native controls are
documented to do and may state the bounded findings in the three dated runs. For
example, it may explain what Bitcrusher Resolution,
Downsampling, Drive, Clip Level, Fold/Clip/Wrap, and Mix are documented to do, and
it may state the bounded direct findings for the one measured Default state. It may
not claim Apple's
exact Fold/Wrap equations, alias spectrum for every project rate, proprietary
oversampling, or one universal artistic outcome until the corresponding dated
renders are executed and analyzed. The same boundary applies to every pedal,
effect, instrument, and editor operation.

### Local long-form production-practice lane

Eight user-supplied long-form courses are now governed by a versioned identity and
review ledger rather than treated as an undifferentiated tutorial dump. Exact local
payload hashes, durations, rights handling, chapter routing, review status, and
required cross-checks are recorded in
`research/metadata/local-production-course-review-v1.json`; the method is documented
in `TRACKSMITH_LOCAL_PRODUCTION_COURSE_REVIEW.md`.

This lane adds contextual professional practice—how an educator listens, orders
work, compares alternatives, revises, and describes musical consequences—but its
claims are not standards-backed or universally causal. Raw transcripts are only
navigation indexes. A course-derived consequence is not admitted here until the
relevant audio, visuals, surrounding explanation, assumptions, and failure cases
are reviewed, and any Logic-version or DSP-mechanism statement is cross-checked
against a primary source or direct measurement. The first twelve-hour Logic Pro 11
course now has a structurally validated, text-free 5,161-segment navigation index
covering all 15 routed chapters and essentially the full source duration. It remains
explicitly **not deeply reviewed** because no transcript can substitute for the
on-screen settings, audible comparisons, surrounding context, or Logic 12.3
cross-checks. A second navigation pass is in progress for the ten-hour Compression
course, selected ahead of creative-effects material by the role-weighted core
priority. No course-derived compressor claim is admitted by transcription alone.

### Core-effect priority is role-weighted, not novelty-weighted

The empirical and practice lanes now use
`research/knowledge/logic-pro-12.3-core-effect-priority.json` rather than treating
all 142 effects as equally urgent. In the 58 curated professional decision cases,
gain/balance/automation language occurs in 46 records, dynamics in 29, EQ/tone in
26, transient/envelope in 18, ambience/delay in 16, pitch/timing/editing in 14,
cleanup/gate/de-essing in 12, saturation/distortion in 10, and stereo/pan/phase in
8. Those are keyword-presence signals in a deliberately curated corpus—not global
plug-in usage statistics and not proof that a processor was applied.

The supported consequence is nevertheless clear: broad production coverage comes
first from gain and metering, Channel EQ, Compressor, source-specific dynamics and
cleanup, ChromaVerb/Space Designer, Stereo/Tape Delay, bounded saturation,
limiting/loudness, stereo/phase, and source-appropriate pitch work. Bitcrusher,
Pedalboard, and other creative processors retain their documentary and empirical
records but move behind that core queue. Lower product priority does not mean lower
artistic value for a song that specifically needs them.

## Logic Instruments and performance-model synthesis

Source identity: Apple, *Logic Pro Instruments for Mac*, current guide retrieved
14 July 2026 and immutably accepted by the research archive on 15 July 2026,
752 pages, SHA-256
`fc867e61b1bbcfc16d4ba98058f7cde104ec17e0649026769c308cff07049ab4`.
Review status: **complete technical read of the full PDF plus its canonical
Quick Sampler web supplement**, finished 16 July 2026. The PDF's 752 pages were
read in full. A coverage audit then found that the PDF repeatedly links Quick
Sampler but omits the standalone chapter present in Apple's live Logic 12.3
table of contents. All 16 official Quick Sampler pages were therefore captured
under the fail-closed ingestion contract and read in full. Exact per-page hashes,
sections, and the conservative review ledger are maintained in
`TRACKSMITH_LOGIC_PRO_12_3_INSTRUMENT_ATLAS.md`.

This source establishes exposed behavior and Apple-authored programming practice.
It does not expose proprietary algorithms, establish objective realism, validate
adjectives such as *warm* or *punchy*, or grant TrackSmith host authority over a
Logic-native instrument.

### Strongly established architecture and performance facts

1. A software-instrument sound includes source generation, per-voice processing,
   global/post-sum processing, performance state, controller mapping, voice
   allocation, articulation, assets, and channel routing. A static spectrum or
   one held note cannot represent the complete instrument state.
2. Alchemy's four sources can combine additive, spectral, granular, sampler, and
   virtual-analog mechanisms under compatibility constraints. Crossfade plays
   multiple sources; Morph interpolates eligible analyzed elements and parameters.
   Warp alignment, analysis mode, source duration, and stochastic modulation
   materially govern the result.
3. Sampler instruments refer to external audio rather than embedding it. Zones,
   groups, articulations, release triggers, round robin, velocity layers,
   crossfades, exclusive classes, Flex metadata, stream state, and mapping are
   independent dimensions. Region-to-Sampler creation can bake active track
   processing, while dragging the underlying file does not.
4. Sculpture is a coupled, state-retaining string model. Exciters, disturbances,
   damping, object/pickup positions, string material, tension, resolution, prior
   vibration, and per-voice modulation interact. Extreme tension/bend settings
   can destabilize the model; random and Bouncing sources can prevent identical
   renders; some stereo pickup geometries are not mono-compatible.
5. Studio Bass, Horns, Strings, and Piano are performance instruments. String or
   neck position, articulation, legato transition, dynamic controller mode,
   release/handling/mechanical samples, section voice distribution, microphone
   blend, and resonance can be more causally relevant than downstream EQ or
   compression.
6. Ultrabeat contains 25 independent synthesizers, a mixer/multi-output router,
   24 patterns, and 32-step per-sound sequences. Its oscillators, sample/physical
   model, side chain, ring modulation, noise, filter, distortion/bit reduction,
   envelopes, LFOs, choke groups, and relative step offsets form one stateful
   production object. Sound copy and sequence copy are distinct operations.
7. Vintage B3, Clav, and Electric Piano deliberately model physical/electrical
   artifacts: leakage, crosstalk, contact clicks, component aging, random pitch,
   pickup cancellation, hammer/string behavior, inharmonicity, damper noise,
   and nonlinear amplification. These mechanisms may be wanted character or an
   explicit preservation violation; “vintage” does not identify one of them.
8. Internal instrument effects and external channel-strip effects are separate
   scopes and can have different algorithms, routing, state, and gain structure.
   Per-voice nonlinearity is not equivalent to summed-bus distortion because the
   latter creates inter-voice intermodulation.
9. Quick Sampler is a one-file instrument whose source-import method is part of
   the sound and provenance. `Original` and `Optimized` are different state
   transitions; a region drop bounces the active track path while an audio-file
   drop does not. Classic, One Shot, Slice, Recorder, Flex, marker, envelope,
   modulation, voice, and MIDI Mono state remain distinct. Rename and write-loop
   operations can reach file identity/header state and are not ordinary sound
   parameters.

### Useful Apple practice, bounded as heuristic

- The instrument tutorials support component-based reasoning: decompose a drum
  into body, impact, noise, resonance, and decay; decompose a modeled instrument
  into exciter, resonator, pickup/body, performance, and room. This is a useful
  hypothesis framework, not proof that Apple's numeric examples are optimal.
- Apple repeatedly recommends small changes, range/velocity testing, revisiting
  earlier parameters after changing coupled components, and listening to the
  complete signal chain. This converges with TrackSmith's competing-hypothesis,
  editable-preview design.
- Articulation, voicing, note duration, playing position, and controller dynamics
  should be checked before treating a sampled-instrument problem as a mix defect.
  TrackSmith may advise this diagnosis but cannot edit unsupported MIDI regions,
  articulation sets, or Logic project state.
- Bit reduction, downsampling, clipping, overdrive, per-voice drive, post-sum
  drive, filter cutoff, and static treble loss are different operations. Apple's
  instruments reinforce the Effects-guide conclusion that *lo-fi*, *dark*,
  *warm*, and *aggressive* are multi-hypothesis intents.

### Source-dependent and perceptual limits

- Alchemy/Sample Alchemy resynthesis quality depends on source type and analysis;
  the tutorials explicitly invite method comparison and “happy accidents.”
- Sampler's optimized mapping, pitch/loudness/loop analysis, and -12 LUFS zone
  normalization are creation aids. They do not certify pitch, loop musicality,
  layer ordering, or a mastering target; multi-zone normalization destroys the
  prior inter-zone loudness relationship.
- Sculpture's component model admits multiple plausible models for one acoustic
  target. Its render modes change the number of modeled elements and, in High
  Definition, enable 2x internal oversampling. Resolution can change both tone
  and level, not merely CPU cost.
- Studio and Vintage claims such as `accurately`, `faithfully`, and
  `ultra-realistic` are product descriptions. The manual reports no controlled
  comparative listening tests establishing universal realism.
- Random round robin, note-on random, jitter, free-running phases, random tonewheel
  condition, granular time variation, and performance-dependent trigger logic
  mean that reproducibility requires explicit state control and repeated-render
  checks.

### Contradictions and documentation defects

- The Legacy Electric Piano chapter calls tremolo “wobbling pitch,” while the
  full Vintage Electric Piano chapter correctly defines tremolo as amplitude
  modulation. TrackSmith treats the legacy phrase as an error.
- The introductory synthesis appendix is explicitly not a scientific treatise.
  Its description of white noise as all frequencies at “full level” around a
  center is imprecise; engineering claims must use primary DSP definitions.
- Several tutorials use historic-device names while also admitting the circuit
  cannot be replicated completely. TrackSmith may describe an approximation's
  characteristics, never promise exact hardware, artist, or record replication.
- The Instruments PDF is not a complete inventory by itself: its Quick Sampler
  links point to a chapter present in the live guide but absent from the PDF
  payload. TrackSmith records this source contradiction and uses the immutable
  16-page web supplement rather than silently treating a search hit as review.
- Pedagogical labels such as *warm*, *woody*, *punchy*, *organic*, *aggressive*,
  and *rich* identify audition directions. They are professional-practice
  vocabulary evidence, not measurable definitions.

### Direct TrackSmith consequences

- Logic-native instrument knowledge is **advisory only**. It can ground an
  explanation or diagnose performance-versus-processing scope, but cannot become
  a deterministic `ProcessingNode`, host action, MIDI script, automation command,
  or claim of an applied edit.
- Context construction should retrieve only the relevant instrument family and
  label every field as documented mechanism, derived interpretation, or practice
  heuristic. Instrument names, patch names, sample metadata, and prior provider
  output remain untrusted text.
- This consequence is now implemented as a 28-entry, primary-manual-plus-
  supplemental-source-hashed
  advisory catalog. Retrieval requires an explicit instrument name or reviewed
  alias and is capped at two entries; a generic synth/keys analysis cannot infer
  Alchemy, Sampler, Sculpture, or any other generating instrument. Returned
  entries explicitly deny DSP-node, MIDI, automation, and Logic-control authority.
- Any future instrument-edit authority needs a separate, explicitly validated
  host/MIDI capability and must preserve asset references, articulation identity,
  note/controller state, voice behavior, randomness, mono compatibility, and
  rollback. That work is outside Production Intelligence v1's current execution
  boundary.

## Loudness source-family synthesis

### ITU-R BS.1770-5, November 2023

Source identity: *Algorithms to measure audio programme loudness and true-peak
audio level*, Recommendation ITU-R BS.1770-5 (11/2023).  
Canonical URL: <https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.1770-5-202311-I%21%21PDF-E.pdf>  
Official-payload SHA-256: `eefb926f72f72a96b96f251067bfee0650a0f29a26f60661d354162038b041ad`  
Review status: **full-read**, all 32 pages; equations and figures visually checked
against rendered pages.

Relevant material reviewed:

- Main recommendation and scope.
- Annex 1 sections 1-4, equations (1)-(7), filter coefficients, block formation,
  absolute gate, and relative gate.
- Annex 2 true-peak model, FIR coefficients, oversampling guidance, and residual
  under-read tables.
- Annex 3 advanced channel weights and Annex 4 rendering/reporting conditions.
- Attachment 1 subjective-test design, programme set, matching conditions,
  correlations, and stated uncertainty.

Algorithm mapping used by TrackSmith:

| Source operation | TrackSmith implementation | Evidence state |
|---|---|---|
| K-weighting stage 1 shelving filter and stage 2 high-pass | `KWeighting` / `MeasurementBiquad` | Implemented; official mono/stereo frequency-vector checks pass at 48 kHz |
| 400 ms block, nearest sample, 75% overlap, incomplete tail discarded | `BS1770Meter.measure` | Implemented |
| `l_j = -0.691 + 10 log10(sum_i G_i z_ij)` | `loudness(_:)` over mono/stereo energy | Implemented for mono/stereo; advanced layouts not supported |
| absolute gate `l_j > -70` | strict filter in Integrated path | Implemented |
| relative threshold absolute-gated level minus 10 LU; strict comparison | Integrated second gate | Implemented |
| Annex 2 48 kHz, 4-phase, 48-tap FIR | `annexTwoPeak` | Implemented; not the complete true-peak conformance matrix |
| other input rates must reach at least 192 kHz | bounded windowed-sinc phase grid | Approximate engineering path, explicitly not claimed conformant |

Important assumptions and limits:

- TrackSmith's stable analysis scope is mono and stereo. BS.1770 channel weights
  for surround and advanced layouts are not implemented.
- Pure-tone behavior is useful for conformance checks, but the source itself says
  the method is not generally suitable for subjective loudness of pure tones.
- The recommendation estimates programme loudness under its listening and level
  assumptions. It is not a semantic production classifier.

### ITU-R BS.1771-1, January 2012

Source identity: *Requirements for loudness and true-peak indicating meters*,
Recommendation ITU-R BS.1771-1 (01/2012).  
Canonical URL: <https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.1771-1-201201-I%21%21PDF-E.pdf>  
Official-payload SHA-256: `33dce2dc84d13cf1f6daa2353c05b6f874c6e0b9099a7ab183288d4e572cc53a`  
Review status: **full-read**, all 14 pages.

TrackSmith consequence: use the document for display and terminology context,
but do not collapse its IIR Momentary definition into EBU Mode's rectangular
definition. Short-term is ungated and exactly 3 s. A meter value reports an
estimated gain adjustment under fixed reproduction assumptions, not a universal
psychophysical unit.

### ITU-R BS.2217-2, November 2016, and official attachments

Source identity: *Compliance material for Recommendation ITU-R BS.1770*, Report
ITU-R BS.2217-2 (11/2016).  
Canonical report URL: <https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BS.2217-2-2016-PDF-E.pdf>  
Attachment index: <https://www.itu.int/oth/R1102000001/en>  
Report SHA-256: `0ae77dc00c1528198ab6acf61620b70f82c5f3c521f8a6918bb3a24281f98376`  
Review status: **full-read**, all 9 pages; official attachment names, formats,
targets, channel layouts, and tolerances reviewed.

Empirical evidence acquired in this pass:

- Fourteen official 48 kHz, 16-bit PCM mono/stereo vectors were downloaded from
  the ITU attachment service without checking copyrighted WAV payloads into the
  repository: twelve 25 Hz-10 kHz frequency cases plus the absolute- and
  relative-gate cases.
- All fourteen pass TrackSmith's Integrated Loudness implementation at the
  report's ±0.1 LKFS file-measurement tolerance.
- This is **closest-available subset conformance evidence**, not a complete
  product certification. Advanced layouts, frequency sweep/live behavior, and
  the complete true-peak suite remain outside this result.

### EBU R 128 v5, November 2023

Source identity: *Loudness normalisation and permitted maximum level of audio
signals*, EBU R 128 v5 (2023).  
Canonical URL: <https://tech.ebu.ch/docs/r/r128.pdf>  
SHA-256: `4292cd2396e4cb386c3a6c1412cb4370fc108ef50956e78a24fbd8657ce2ca28`  
Review status: **full-read**, all 5 pages.

What it establishes within its profile: programme Integrated Loudness, LRA as a
supplement, a -23 LUFS broadcast target, and true-peak limits for specified
production paths. What it does not establish: a target for every stem, a
streaming-master target, or a preferred amount of music dynamics. Its explicit
warning against LRA for content shorter than one minute is represented directly
in TrackSmith's metric reliability.

### EBU Tech 3341 v4, November 2023

Source identity: *Loudness Metering: EBU Mode metering to supplement loudness
normalisation in accordance with EBU R 128*, v4.  
Canonical URL: <https://tech.ebu.ch/docs/tech/tech3341.pdf>  
SHA-256: `dd5a7b0b611024e616b86a42c89eed0ded33f3129afc1994204885216fa1619e`  
Review status: **full-read**, all 10 pages including all 23 minimum test cases.

TrackSmith now implements the rectangular, ungated 3 s Short-term measurement at
10 Hz. The current maximum 400 ms value also follows the EBU rectangular
definition; documentation must be corrected anywhere it implies BS.1771 IIR
ballistics. Passing minimum tests would still not prove complete meter accuracy;
the source says so explicitly.

### EBU Tech 3342 v4, November 2023

Source identity: *Loudness Range: A measure to supplement loudness normalisation*,
v4.  
Canonical URL: <https://tech.ebu.ch/docs/tech/tech3342.pdf>  
SHA-256: `a12cb59fa4a8258d400bc931c7a79326a83a27c1cfd7b38220bc85ba5cfa89d8`  
Review status: **full-read**, all 8 pages including the reference MATLAB code and
six minimum test descriptions.

Implementation consequences now present:

- 3 s Short-term vector, at least 2.9 s overlap (TrackSmith uses 2.9 s).
- Inclusive `>= -70 LUFS` absolute gate.
- Relative threshold 20 LU below the power-domain mean of absolute-gated values.
- Inclusive relative gate.
- Exact 10th/95th percentile index translation.
- 1.5 s of virtual trailing silence for the file-based final value.
- Synthetic versions of minimum cases 1-4 pass at the specified ±1 LU tolerance.
- LRA is explicitly typed in LU, not LUFS.

### EBU Tech 3343 v4, November 2023

Source identity: *Practical guidelines for Production and Implementation in
accordance with EBU R 128*, v4. The downloaded temporary filename says `v3`, but
the document history and content identify v4; the filename is therefore not used
as provenance.  
Canonical URL: <https://tech.ebu.ch/docs/tech/tech3343.pdf>  
SHA-256: `92d6500c78c4fca586daad1e37c8d8dbe144d81ef1dbe413badf13330b18a36c`  
Review status: **full-read**, all 46 pages.

Relevant conclusions for TrackSmith:

- Loudness normalization preserves intended internal dynamics better than peak
  normalization, but does not guarantee a good mix.
- Stems and components should not each be forced to the programme target.
- Maximum Short-term Loudness is often more informative than LRA for content
  under a minute.
- Album/music sequence relationships, renderer/downmix choices, monitoring, and
  listener preference are context that a scalar metric cannot recover.
- The document is broadcast-production guidance. Its streaming and adaptation
  discussion is context, not permission to hard-code one music-master target.

## Source-fidelity and provenance findings

The user-supplied
`research/papers/13_ITU-R_BS.1770-5_Loudness_True_Peak.pdf` is preserved unchanged
at SHA-256 `ce14d02196af55b7724781678c56c2d9e5c6795424f8d93617163b7bb97facc0`.
It is a Ghostscript 10.02.1 regeneration with visually corrupted equation glyphs
and is **quarantined as non-normative evidence**. It was not silently overwritten.
The canonical official payload above was used for the deep review and algorithm
mapping. The supplied R 128 payload does match the official byte stream.

The EBU v5 audio test-set page is canonical, but its 87.4 MB ZIP returned HTTP 403
to direct retrieval in this environment. TrackSmith therefore uses the exact
published Tech 3342 synthetic descriptions for LRA cases 1-4 and records that the
official audio payload was not acquired. It does not claim to have run that set.

## Immediate TrackSmith consequences already implemented

- `LoudnessMeasurement` now carries maximum Short-term Loudness, LRA, a
  reliability state, the 10 Hz Short-term series, and the gated LRA block count.
- `AudioAnalyzer` publishes `maximum_short_term_loudness_lufs`,
  `loudness_range_lu`, and `short_term_loudness_lufs_timeline` with units,
  limitations, window details, and short-content confidence reduction.
- Long LRA test vectors can disable true-peak FIR work explicitly; production
  analysis still measures true peak by default.
- The TestRunner passes 55/55 in Debug and Release when the 14 selected official
  BS.2217-2 vectors are supplied, including four Tech 3342 synthetic LRA cases.
  The ordinary Thread Sanitizer lane passes 54/54 with the external WAVs omitted.

## Compression and intelligent-mixing source-family synthesis

### Giannoulis, Massberg, and Reiss: compressor design, 2012

Source identity: Dimitrios Giannoulis, Michael Massberg, and Joshua D. Reiss,
*Digital Dynamic Range Compressor Design—A Tutorial and Analysis*, JAES 60(6),
2012, pp. 399-408.  
Local lawful payload SHA-256: `dd65e1f91e8fafd855cc994246bfe957d671254a271b83ba8fab2239f7b23b44`  
Review status: **full-read**, all 10 pages; equations (1)-(24), detector and
topology figures, THD/effective-ratio/FES experiments, Table 1, scope, and
conclusion reviewed.

Strongly established for TrackSmith:

- The threshold/ratio hard-knee curve and its quadratic soft-knee extension are
  explicit, continuous mappings. They are suitable for an editable deterministic
  graph and already match TrackSmith's gain-computer curve.
- A one-pole time constant defined by reaching `1 - 1/e` maps to
  `alpha = exp(-1 / (tau * sampleRate))`. Attack/release labels are otherwise
  definition-dependent; documentation and tests must state which definition is
  used.
- Compressor sound is not determined by threshold and ratio alone. Feedforward
  versus feedback topology, peak versus RMS detection, detector placement,
  branching versus decoupled behavior, knee, and smoothing all change behavior.

Moderately supported design recommendation:

- For predictable, lower-artifact digital compression, the authors recommend a
  feedforward topology, a gain-reduction detector in the log domain after the
  gain computer, and a smooth decoupled peak detector (or smooth branching with
  its possible slope discontinuity). Their experiments compare THD, effective
  compression ratio, and envelope-shape fidelity for selected artificial and
  guitar/bass/drum/vocal signals. This is relevant evidence, not proof that the
  same topology is artistically preferred for every source.

Limitations and non-claims:

- The paper analyzes standard single-band compressor architecture. It explicitly
  leaves recommended production parameter settings, side-chain filtering,
  multiband designs, and intelligent adaptation outside scope.
- FES and THD are technical descriptors, not complete perceptual preference
  measures. Table 1 is based on one strong parameter configuration and four
  signals.

Direct TrackSmith consequence: the current compressor is feedforward and uses the
paper's static soft knee and one-pole coefficients, but its detector smooths linear
input level before the gain computer. That does **not** match the paper's preferred
log-domain gain-reduction placement and carries the described attack-lag/release
behavior. This discrepancy is now an implementation ticket, not something the
documentation may silently call equivalent.

Direct Logic 12.3 cross-check, 2026-07-20: a manual disposable-host run used the
paper's equations (2)-(3) only as a public static-curve reference for one explicit
Logic Compressor state: Platinum Digital, threshold -20 dB, ratio 4.1:1, knee 0,
Peak detector, attack 0 ms, release 51 ms, Auto Gain/Auto Release/distortion/
limiter/side-chain filter off, Mix 100%, and unity input/output gain. On a steady
1 kHz amplitude ladder, all five above-threshold gain values agreed with the
hard-knee relation within `0.000128 dB`; five below-threshold values measured
`0 dB`. This strongly establishes the exposed static relation for that state and
fixture, not the private topology or time response. The exact observed default
was materially different because `Auto Gain -12 dB` was active: it added about
`+3.4055 dB` on the four quietest steps before gain reduction increased. Therefore
the Logic default cannot serve as TrackSmith's neutral or fair bypass reference.

The run also constrains repeatability claims. The first controlled bounce differed
from the stabilized render only at sample indices 1-1022; subsequent pre-reload
and post-reload PCM matched exactly. The cause is unknown. TrackSmith must retain
transition renders and wait for repeated stabilization rather than quietly treating
the first result as deterministic. Exact method, state, hashes, rejected metronome/
project-rate setup failures, and non-claims are in
`docs/evidence/LOGIC_NATIVE_COMPRESSOR_EMPIRICAL_2026-07-20.md`.

### Giannoulis, Massberg, and Reiss: parameter automation, 2013

Source identity: *Parameter Automation in a Dynamic Range Compressor*, JAES
61(10), 2013, pp. 716-726.  
Payload SHA-256: `d1ac2af3fb7238bafa8c861edc5a907a286983dabffcdbc2e4cbb2f4a29d9bb8`  
Review status: **full-read**, all 11 pages; crest and spectral-flux methods,
automation equations, empirical constants, evaluation procedure/results, and
limitations reviewed.

What the work demonstrates:

- Crest factor and positive spectral flux can drive bounded adaptive timing. The
  proposed crest mapping is `2 * tau_max / crest^2`, with release adjusted for
  attack in that detector design. Spectral flux was more sensitive to frequency
  change and generally matched the panel's timing choices better in the four test
  signals.
- Loudness-based make-up gain agreed better with panel medians than mean gain
  reduction for most tested sources, but still overestimated the drum case by
  about 3 dB. The authors explicitly attribute limits to applying a broadcast
  loudness measure to isolated percussive sources.

Why this is **moderate evidence/product-hypothesis input**, not a preset law:

- Nine professional and seven amateur participants used their own environments;
  only short drums, slap bass, soft vocal, and acoustic-guitar tracks were used;
  the sources were isolated rather than evaluated in mixes; static user choices
  were compared with adaptive values; and several thresholds/exponents/time
  constants were derived empirically or informally.
- Participants disagreed about whether loudness matching should follow transients
  or sustain when dynamics changed. “Loudness matched” therefore does not settle
  perceived equality for a heavily altered isolated source.

TrackSmith may use crest/flux timing as one source-aware candidate with explicit
uncertainty and user strength, but must consider transient preservation and must
not claim that high flux universally calls for a faster attack.

### Ma et al.: intelligent multitrack compression, 2015

Source identity: Zheng Ma et al., *Intelligent Multitrack Dynamic Range
Compression*, JAES 63(6), 2015, DOI 10.17743/jaes.2015.0053.  
Payload SHA-256: `46852ebccfe3504ae4892c5fa89b6bd2e0ca8c4a0bc425b82e6f2b78e903b6d4`  
Review status: **full-read**, all 15 pages; assumptions, feature definitions,
method-of-adjustment experiment, correlation/regression tables, prediction bounds,
implementation equations, MUSHRA-style evaluation, and limitations reviewed.

Moderately supported findings within this dataset:

- Ratio choices correlated more strongly with the proposed low-frequency and
  percussivity weights than with EBU LRA. Threshold correlated most strongly with
  absolute RMS; the selected simple regressions used percussivity/low-frequency
  weighting for ratio and RMS/percussivity for threshold.
- EBU LRA had weak correlations with both ratio and threshold. The authors give
  two plausible reasons directly relevant to TrackSmith: broadcast design does
  not fit isolated tracks, and the 3 s window misses smaller fluctuations.
- In a separate test of six 20 s songs, sixteen moderately experienced listeners
  rated the proposed automatic compression competitively with two
  semi-professional mixes across appropriateness, artifacts, stabilization, and
  preference. The paper does not demonstrate parity with expert commercial mixes.

Limitations that cap TrackSmith claims:

- The parameter-adjustment study used 15 participants, about half from one UK
  research group, and a small multitrack set. The final listeners were moderately
  experienced, not a broad expert panel. The reference in the MUSHRA-style test
  was explicitly not an objectively high-quality reference, and there was no
  prescribed low-quality anchor.
- Several control assumptions came from literature/practice and the later
  evaluation only tests the whole selected system on the chosen material. It does
  not causally validate every mapping or coefficient.

### Pestana and Reiss: best-practice strategies, 2014

Source identity: Pedro Pestana and Joshua D. Reiss, *Intelligent Audio Production
Strategies Informed by Best Practices*, AES 53rd International Conference, 2014.  
Payload SHA-256: `5cb46304f10419c7f936d787fdc34ddef07a64d397cacc184288d8b34fb43b19`  
Review status: **full-read**, all 9 pages; the 42 selected assumptions, evidence
ranking, loudness/panning/EQ/temporal/dynamics sections, figures, contradictions,
and conclusions reviewed. This is a compact synthesis of a larger thesis, so
claims whose underlying experiment is not fully reported here remain moderate or
expert-practice evidence.

Useful, bounded conclusions:

- Blind high-pass filtering, a universal low-mid “clarity” cut, “experts always
  cut rather than boost,” and “hard panning should be avoided” were not supported.
  This directly rejects source-agnostic recipe rules.
- Masking/unmasking recurred across loudness, panning, and EQ. The reported
  exercises support reducing salient resonances and making context-dependent
  spectral room, but also identify an unresolved opposing wall-of-sound strategy.
- Low-frequency centering, left/right energy balance, mono-compatibility checks,
  tempo-related delays, filtered ambience sends/returns, and lower tolerance of
  low-frequency content for ambience were common practices in the studied corpus.
  They remain context-sensitive heuristics, not immutable laws.
- The study found no expert consensus for compressor attack/release mapping. It
  reports that the common rules “let only the transient through” and “release by
  the next note” were not validated as universal. Frequency/source identity was
  more promising than EBU LRA as a compression-amount cue.

Important contradictions:

- The 2013 automation paper found one spectral-flux timing mapping promising on
  four isolated sources; the 2014 broader best-practice synthesis found no expert
  consensus. TrackSmith must preserve multiple strategies and listening as
  decisive rather than promoting the former mapping to a universal rule.
- The 2015 system assumes more level fluctuation implies more compression, while
  its own feature analysis finds LRA weak and the 2014 work recommends automatic
  fluctuation correction only in extreme cases. “Dynamic inconsistency” can
  support an intervention hypothesis but cannot select compression by itself.
- The 2014 work reports an aggregate spectral target resembling pink noise with
  edge roll-off, yet also says every song has a unique contour and blind EQ rules
  fail. TrackSmith may compare broad balance and masking evidence, never force a
  universal target curve.

### Martínez Ramírez and Reiss: deep mixing proof of concept, 2017

Source identity: *Deep Learning and Intelligent Audio Mixing*, 3rd Workshop on
Intelligent Music Production, 2017, CC BY 4.0.  
Payload SHA-256: `44dd485fcc1970a880d7ff5f472b6fd10166bddaefa984fc6e105f52271c28c6`  
Review status: **full-read**, all 4 pages including dataset construction,
preprocessing, autoencoder configuration, qualitative outputs, and conclusion.

The proof of concept trained instrument-group magnitude-spectrum autoencoders on
102 multitracks, reconstructed with input phase, and visibly preserved some
harmonics/envelopes. It also introduced artifacts and noise, performed worse for
vocals/keys, and had no listening or similarity evaluation. The paper itself calls
the system early and simple. It supports TrackSmith's decision to keep opaque
waveform transformations outside the deterministic production foundation; it does
not demonstrate an editable or production-ready mixing engine.

## Differentiable DSP, automatic EQ, and style-transfer synthesis

### Steinmetz, Bryan, and Reiss: differentiable audio-effects transfer, 2022

Source identity: Christian J. Steinmetz, Nicholas J. Bryan, and Joshua D.
Reiss, *Style Transfer of Audio Effects with Differentiable Signal Processing*,
JAES/arXiv:2207.08759v1, 18 July 2022.  
Payload SHA-256: `142ea315bda6edabe3c56f7e922c0b9d5de50fddf8a01dc0915743f1de558652`  
Review status: **full-read**, all 12 pages; differentiable-processor variants,
self-supervised data construction, effect-chain and encoder configurations,
objectives, speech/music experiments, proxy and gradient estimators,
sample-rate behavior, ablations, objective evaluation, non-intrusive realistic-data
evaluation, discussion, and conclusion reviewed.

What the paper establishes within its experimental scope:

- An explicit EQ/compressor chain can be placed in an end-to-end learned system
  while retaining inspectable controls. Exact automatic differentiation gave the
  best or near-best objective performance in the tested synthetic transfer tasks;
  neural proxies and simultaneous-perturbation estimates provide trade-offs when
  processors are not directly differentiable.
- Self-supervised pairs created by randomly applying known effects can teach a
  controller to recover production transformations, and separating encoder
  resampling from sample-rate-aware DSP allowed the exact-DSP system to operate at
  sample rates not seen during training.

The evidence does **not** define production adjectives or prove expert-grade
mixing. The paper's “realistic” styles are hand-authored parameter distributions
informed by presets; they are not empirical definitions of *warm*, *bright*, or
any other production term. Real-recording evaluation uses non-intrusive proxy
metrics because no clean target exists, and the paper reports no controlled
subjective listening test for that experiment. Speech and music are evaluated as
broad domains rather than TrackSmith's six source classes, the chain is fixed,
and success depends on the generated training distribution. TrackSmith can adopt
the explicit-control architecture and sample-rate separation as **moderately
supported design principles**, but semantic interpretation and production
quality remain unproven.

### Steinmetz et al.: ST-ITO, 2024

Source identity: Christian J. Steinmetz, Shubhr Singh, Marco Comunità, Ilias
Ibnyahya, Shanxin Yuan, Emmanouil Benetos, and Joshua D. Reiss, *ST-ITO:
Controlling Audio Effects for Style Transfer with Inference-Time Optimization*,
arXiv:2410.21233v1, 28 October 2024.  
Payload SHA-256: `0d189726bfba637f31e0be3950a290e18c4fc5fa11afae00c0b5b5f5e982c6d8`  
Review status: **full-read**, all 8 pages; AFx-Rep pretraining, datasets and effect
sampling, CMA-ES search, both differentiable and unseen/non-differentiable chains,
classification/retrieval/parameter-estimation benchmarks, listening-test design,
failure cases, timing, limitations, and conclusion reviewed.

The learned style representation was trained by identifying effects and presets
across seven audio datasets and 63 VST effects, with 20,000 examples per effect;
the inference search used CMA-ES with a population of 64 and at most 25
iterations. That is evidence that a learned metric plus black-box parameter search
can control an arbitrary supplied effect chain, including an unseen Pedalboard
chain. A 23-participant experienced-listener test also supports higher perceived
style similarity for ST-ITO on the selected ten cases.

Important limits are architectural, not footnotes: the method assumes a minimally
processed input, requires the user/system to supply an appropriate serial chain,
optimizes similarity rather than general mix quality, takes roughly a minute in
the reported configuration versus roughly a second for direct prediction, and
failed more visibly on guitar/reference mismatch. Simple rule-based matching won
some simple cases. The benchmark measures a particular learned notion of effect
style; it does not establish that all production intent is captured. In line with
the goal boundary, ST-ITO remains an **experimental offline reference**, not a
production dependency or a license to implement full reference matching.

### Steinmetz et al.: differentiable multitrack console, 2020

Source identity: Christian J. Steinmetz, Jordi Pons, Santiago Pascual, and Joan
Serrà, *Automatic Multitrack Mixing with a Differentiable Mixing Console of
Neural Audio Effects*, arXiv:2010.10291v1, 20 October 2020.  
Payload SHA-256: `709159e2f6ccab6eae7d40d1623605f77c9f69ed982825c693eb08c2606b4489`  
Review status: **full-read**, all 5 pages; neural-effect emulation, controller and
context pooling, console topology, sum/difference stereo loss, dataset reduction,
training, audio-engineer evaluation, statistics, failure examples, and conclusion
reviewed.

The system's strongest transferable idea is its inductive bias: a shared,
permutation-invariant controller predicts human-readable gain, polarity, fader,
pan, EQ, compression, and reverb controls, while a sum/difference loss separately
penalizes mono-compatible and stereo-side errors. On ENST drum mixtures, the
proposed system was not significantly different from the target in the reported
listening result (`p = 0.08`). This moderately supports editable console controls
and explicit stereo evaluation.

It does not establish a general automatic mixer. The full-mix MedleyDB subset had
only 65 usable songs with at most six tracks and targets from 16 engineers. The
system was statistically worse than targets, and several examples over-reverbed
or became harsh. EQ, compression, and reverb were neural proxies that could add
artifacts. Multiple mixes can be valid, yet waveform reconstruction was the
training objective. TrackSmith should use the graph/parameter and stereo-loss
ideas while rejecting the implication that one target mix or one metric is the
right production answer.

### Mockenhaupt, Rieber, and Nercessian: instrument-aware automatic EQ, 2024

Source identity: Florian Mockenhaupt, Joscha Simon Rieber, and Shahan Nercessian,
*Automatic Equalization for Individual Instrument Tracks Using Convolutional
Neural Networks*, DAFx-24/arXiv:2407.16691v1, 23 July 2024.  
Payload SHA-256: `b4926354e71ad2d620107f69dbfbf9227f84cef567bc6049fd9bc67247370a06`  
Review status: **full-read**, all 8 pages; analysis representation, classifier,
target construction, spectral-difference conditioning, biquad/EQ constraints,
network and loss equations, synthetic and real-data construction, objective and
listening evaluations, and conclusion reviewed.

The method classifies 6 s, 256-by-256 spectral inputs among 35 instrument classes
with 79% test accuracy, forms a zero-mean dB target by averaging a curated subset
within each class, smooths and zero-centers the input-to-target difference, scales
it to at most 12 dB, and predicts ten controls for a four-band shelf/peak/peak/shelf
EQ. Fine-tuning a CNN against real-world target differences reduced frequency-
response MAE to 1.02 dB, a reported 24% improvement over the earlier synthetic
MLP configuration. In a blind internal A/B test, 26 proficient participants
preferred treated isolated tracks nearly two-to-one, with 14% neutral responses.

This is useful evidence that source identity improves over a universal pink/flat
target and that interpretable parametric EQ can be optimized in frequency-
response space. It is **not** a canonical tonal-balance model: both the curated
“suitably produced” data and class averages are proprietary/internal, the class
accuracy and near-class substitutions can hide meaningful source differences,
and the listening criteria asked participants to imagine whether isolated tracks
would fit a mix. The four EQ ranges and Q limits were chosen from common practice,
not validated as universal. TrackSmith may use source class and broad spectral
evidence to form competing tonal hypotheses, but must not force an average class
spectrum or infer “muddy,” “harsh,” or “clear” from distance to one target.

### Consequences across this source family

The papers agree that explicit effects and human-readable controls are a valuable
inductive bias. They also expose a consistent evidence boundary: target choice,
effect-chain choice, data distribution, source identity, and mix context determine
what the optimizer learns. Objective response matching can validate whether a DSP
plan executes as designed; it cannot validate the artistic goal. TrackSmith's
production-intent layer must therefore generate one or more inspectable,
source-conditioned hypotheses with preservation constraints and uncertainty,
then render bounded deterministic plans. It must not map a production adjective
to a learned target or fixed preset merely because a paper used the same word for
a synthetic style distribution.

## Analysis descriptors and perceptual-evaluation synthesis

### Bogdanov et al.: Essentia 2.0, 2013

Source identity: Dmitry Bogdanov et al., *Essentia: An Audio Analysis Library
for Music Information Retrieval*, ISMIR 2013.  
Payload SHA-256: `ff3cf5310d0dc3fdb51355525437a5ca8c19ff3a510f1318dc495c179cd574f8`  
Review status: **full-read**, all 7 pages; architecture, standard/streaming
execution, algorithm inventory, spectral/temporal/tonal/rhythm/SFX/high-level
descriptors, aggregation, extractors, applications, real-time caveat, licensing,
and conclusion reviewed.

The paper establishes that Essentia 2.0 offered a composable implementation of
many established low- and high-level MIR algorithms, including band energies,
spectral flux, HFC, rolloff, peaks, onset functions, envelope/attack/decay
descriptors, pitch salience, YinFFT, stereo panorama, and statistical aggregation.
It explicitly says its streaming scheduler favored analysis throughput rather
than real-time latency, that not every algorithm was suitable for real time, and
that the library was AGPL with commercial licensing also offered.

This paper is an implementation catalog, not a validation that each descriptor
supports a production decision. High-level labels such as *dark/bright* or
*aggressive/relaxed* are trained classifiers whose accuracies and domains live in
other cited work. TrackSmith may use documented low-level algorithms as
implementation references or independent comparators, subject to license review,
but provenance for a production metric must come from the metric's underlying
method/evaluation rather than from its presence in Essentia.

### de Cheveigné and Kawahara: YIN, 2002

Source identity: Alain de Cheveigné and Hideki Kawahara, *YIN, a Fundamental
Frequency Estimator for Speech and Music*, JASA 111(4), 2002,
DOI 10.1121/1.1458024.  
Payload SHA-256: `0055503a04be6b1453eaf0a768c90d123adb004643a1421e0a542155c6778344`  
Review status: **full-read**, all 14 pages; signal model, all six algorithm steps
and equations, error mechanisms, speech databases and ground truth, comparison,
parameter sensitivity, implementation/latency, confidence, extensions,
auditory-model discussion, conclusion, and evaluation appendix reviewed.

YIN replaces autocorrelation with the squared difference function, divides by the
cumulative mean to form the normalized difference, selects the first local
minimum under an absolute threshold (or the global minimum), interpolates the dip,
and optionally searches locally for the most reliable estimate. In the reported
1.9 h speech corpus, regularly voiced regions with laryngograph-derived ground
truth yielded a 1.03% average gross-error rate under a permissive 20% error
threshold, about one third of the best comparator in those conditions. The
normalized difference at the selected period is useful as an aperiodicity/
confidence indicator; a larger value means less reliable periodicity.

The paper deliberately removed irregular voice, fry, diplophony, unvoiced
regions, and dubious ground truth, did not solve voicing detection, and evaluated
music only informally. It warns that at least twice the longest expected period is
needed and that larger windows trade temporal resolution for stability. Therefore
TrackSmith may use YIN as a **moderately supported monophonic pitch/periodicity
evidence source**, with confidence and valid-condition checks. It must not label a
polyphonic mix, distorted bass, noisy cymbal-rich signal, or irregular vocal as
“out of tune” from YIN alone.

### Wilson and Fazenda: open-ended production quality, 2013

Source identity: Alex Wilson and Bruno Fazenda, *Perception & Evaluation of
Audio Quality in Music Production*, DAFx-13, 2013.  
Payload SHA-256: `6809079a119e9d78e47d408223c49b66425ec450f8811260d1826728a0d5b2dd`  
Review status: **full-read**, all 6 pages; hypotheses, participant/sample
selection, listening environments, loudness matching, all objective features,
post-hoc feature construction, ANOVA/correlation results, domain mismatch,
discussion, and limitations reviewed.

The study is useful chiefly as a warning against single-metric quality. Twenty-
four listeners rated 55 twenty-second, predominantly pop/rock commercial
excerpts; expertise and familiarity affected ratings, and individual feature
regressions explained only `r² = 0.0831` to `0.3532`. The authors explicitly call
the small-panel results indicative rather than conclusive.

Several apparent findings are especially unsafe to universalize. The 2–5 kHz
“harsh energy” and 20–80 Hz low-frequency bands were selected after comparing
candidate bands against the same quality ratings. The emotion model was trained
on likely film-score material and produced wildly out-of-range “anger” values on
commercial music. Stereo width was `1 - correlation` at zero lag and its reported
optimum was influenced by headphone playback and confounded with era/dynamics.
The proposed amplitude-histogram “Gauss” measure was exploratory. These results
can justify investigating band evidence, crest behavior, and stereo correlation,
but cannot justify the direct semantic outputs *harsh*, *quality*, *professional*,
or an optimal width.

### Senoussaoui, Santos, and Falk: SRMR variants, 2015

Source identity: Mohammed Senoussaoui, João F. Santos, and Tiago H. Falk, *SRMR
Variants for Improved Blind Room Acoustics Characterization*, ACE Challenge
Workshop/arXiv:1510.04707v1, 15 October 2015.  
Payload SHA-256: `777ca8c75e33fc645410e20951d2c52d0c1aeac70484af7fce0a6274bc0579a4`  
Review status: **full-read**, all 5 pages; gammatone/Hilbert/modulation pipeline,
all SRMR variants and equations, normalization, speech/RIR/noise datasets,
regression mappings, single/multichannel evaluation, error variance, limitations,
and conclusion reviewed.

SRMR-family ratios separate low and high speech-envelope modulation energies to
predict room `RT60` or direct-to-reverberant ratio. The strongest reported variant
improved correlation and RMSE against one blind-decay benchmark on ACE/TIMIT
speech convolved with measured or synthetic room responses and additive noise.
The chosen acoustic band and mappings were empirical, performance varied sharply
by noise, some lower-error variants had worse variance, and the multichannel path
was simple channel averaging with missing results for the best single-channel
variant.

This is **source-dependent speech-room evidence**, not a validated ambience or
reverb metric for produced music. TrackSmith must not use SRMR to declare a mix or
instrument “too reverberant,” “distant,” or “intimate.” It may remain a future
experiment for suitably detected dry/near-monophonic vocal or speech material,
with explicit domain qualification and new music-specific validation.

### ITU-R BS.1534-3: MUSHRA, in-force 2015 version with 2023 edits

Source identity: ITU-R BS.1534-3 (10/2015), *Method for the Subjective Assessment
of Intermediate Quality Level of Audio Systems*, in force; official English PDF
posted 9 May 2023 and editorially amended March 2023.  
Canonical URL: `https://www.itu.int/rec/R-REC-BS.1534-3-201510-I/en`  
Payload SHA-256: `0a751fa8941e72178de216c3008bc55affd456e2551cbaed67d7934c334f430f`;
the supplied payload is byte-identical to the current official English PDF.  
Review status: **full relevant source read**, all normative Annex 1 sections,
normative assessor instructions and non-parametric attachment, informative UI,
parametric-analysis, and anchor-behavior material reviewed; key equations and
screening/statistics pages also visually inspected from the canonical PDF.

Strongly established for its intended use:

- MUSHRA is a double-blind, multi-stimulus method for **intermediate-quality
  systems with significant impairments**, not a generic name for any preference
  test. It requires an open reference, a hidden reference, and hidden low/mid
  anchors; scores concentrated in 80–100 can mean the method is invalid for the
  task.
- Experienced, trained assessors, representative critical material, randomized
  presentation, controlled and reported listening conditions, fast switching,
  loudness control, assessor reliability/discrimination, and adequate power are
  parts of the method—not optional polish. The document says there is no one
  universally critical programme item.
- The raw distribution must be inspected. Median and IQR are required, means and
  95% intervals may supplement them, multimodality/sub-populations and
  interactions require attention, and exclusions need evidence and reporting.
  A null difference is not credible unless experimental sensitivity is shown.

For TrackSmith, these requirements govern any future claim that DSP strategies
sound better under a MUSHRA test. The standard's unprocessed reference is a
quality ideal for testing impaired transmission/audio systems; in creative
production, the unprocessed source is often intentionally *not* the artistic
target. Consequently TrackSmith should use MUSHRA only for suitable intermediate-
impairment comparisons and should design separate blinded preference or
attribute-specific studies for creative production hypotheses. Internal A/B
checks without reference, anchors, training, and prescribed reporting must never
be called MUSHRA.

### Consequences across analysis and evaluation

Low-level descriptors can provide bounded evidence, and validated listening tests
can decide perceptual questions that metrics cannot. Neither the presence of a
descriptor in a library nor a statistically significant correlation in a small,
post-hoc production-quality study converts it into semantic truth. TrackSmith's
metrics must state source applicability, window/aggregation, confidence, valid
conditions, and known failures; production terms must remain multi-evidence,
context-dependent hypotheses. Evaluation must distinguish conformance vectors,
objective DSP-direction assertions, blinded preference, attribute-specific tests,
and actual MUSHRA.

## Source-aware production-practice synthesis

### iZotope: Mixing Guide, 2014 edition

Source identity: iZotope Inc., *Mixing Guide: Principles, Tips, and Techniques*,
2014 edition, 70 pages.  
Canonical URL: `https://downloads.izotope.com/guides/iZotope-Mixing-Guide-Principles-Tips-Techniques.pdf`  
Payload SHA-256: `285fd062e781d9ead2735309e47d1b1ef088e173a2d3c6fbbdda715bda882373`  
Review status: **full relevant source read**; EQ, dynamics, panning/M-S,
time-based effects, distortion, client/rough-mix preparation, complete drums,
bass, guitars, keyboards, vocals, arrangement/automation, master-bus, revision,
and delivery sections were read. Representative EQ, stereo, drums, percussion,
vocal, and finishing pages were rendered and visually checked. Product appendix
material was not used to justify acoustic claims.

This is a vendor-authored educational guide for beginning mixers, not a standard
or controlled experiment. It is nevertheless useful because it states
professional-practice hypotheses across all TrackSmith v1 source classes and
repeatedly qualifies them by part, arrangement, genre, recording, client intent,
and listening in context. It explicitly says frequency suggestions vary, the
kick/bass allocation is stylistic, revisions are normal, source processing must
be judged with the rest of the mix, and client intent can override the mixer's
interpretation. Those qualifications are more important to TrackSmith than any
individual frequency number.

Useful source-dependent strategies include:

- Vocal: consider unwanted sub/room/proximity energy, event-specific sibilance,
  dynamic rides or compression, upper-frequency air, saturation, and wet-effect
  filtering as separate decisions. A dry/less-reverberant vocal is commonly
  perceived as closer, while reverb/delay can add depth, but neither relation
  uniquely determines “intimate” or “distant.”
- Drums: distinguish initial transient, body/sustain, cymbal/overhead energy,
  room contribution, and bus behavior. “Tighter” and “boomier” can imply opposite
  sustain changes. A snare's presence can mask vocal consonants, so drum evidence
  must be evaluated against other sources rather than in isolation.
- Bass: fundamental/sub allocation changes by note and by its relationship with
  kick; upper harmonics can improve audibility on smaller systems; performance
  style changes transient and compression needs; stereo low-frequency changes
  need mono checks. No fixed crossover or kick-wins/bass-wins rule follows.
- Guitar and keys/synth: role is decisive. A featured acoustic guitar or piano
  should not receive the same trimming as a dense support layer. Distorted guitar
  already has nonlinear dynamic shaping; a keyboard may occupy broad spectral and
  stereo space, but neither fact proves that further compression or narrowing is
  required.
- Stereo and ambience: panning, independent performances, M-S balance, reverb,
  delay, predelay/decay, and modulation can change width and depth through
  different mechanisms. Mono collapse and headphone/speaker translation are
  independent checks. “Wide” must not become one global width multiplier.
- Saturation/distortion: nonlinear processing can add harmonics, change envelope
  and density, and alter audibility. Its result depends on waveshape, spectrum,
  level, oversampling/aliasing, and source. “Warm,” “bright,” “punchy,” “glue,”
  “vintage,” and “exciting” are possible descriptions, not guaranteed outputs.
- Full mix/master bus: the guide explicitly calls master-bus practice disputed
  and recommends keeping an unprocessed print if bus processing is used. It
  supports revisions, alternatives, unchanged source/session assets, and delivery
  at the session's rate/depth; it does not establish a loudness target.

Important contradictions and defects prevent preset extraction. The guide says a
compressor “typically” adds distortion by emphasizing harmonics, whereas the
reviewed compressor theory models a potentially clean time-varying gain element;
harmonic generation is implementation- and time-constant-dependent, not a
defining compressor requirement. It presents tube/tape harmonic and tonal
descriptions too categorically for the many circuits and models bearing those
labels. It says low frequencies should “never” be too wide while elsewhere
acknowledging no hard rules. Its keyboard ratio “1:4-2:1” is internally suspect
because a conventional downward compressor ratio below 1:1 has a different
meaning. Broad bands such as 125-500 Hz for mud or 4-8 kHz for snap/harshness are
search regions, not semantic boundaries. The product examples also confound
technique with one vendor's 2014 algorithms.

TrackSmith consequence: store these as **professional-practice heuristics** that
generate multiple source-aware hypotheses. Frequency regions may focus evidence
or initialize bounded searches only after inspecting the actual signal. Do not
hard-code the example ratios, frequencies, chains, wet percentages, or analog
labels as meanings of production terms. Preserve source role, arrangement,
existing processing, user constraints, requested strength, mono behavior, and
listening as first-class inputs.

### Current iZotope vocal-EQ article, 2025

Source identity: Chris Wainwright, *Ultimate guide: How to EQ vocals for
beginners*, iZotope, 24 July 2025.  
Canonical URL: `https://www.izotope.com/community/blog/how-to-eq-vocals`  
Review status: **full relevant article read**; stated scope, key/note/harmonic
analysis, all nine frequency-region steps, example settings, de-essing, final
comparison, and limitations were reviewed. Embedded before/after audio was not
available in the text payload, so no independent listening claim is made.

The article improves on fixed-recipe framing by saying that every voice differs
and by tying the example to one male D-major vocal spanning D3-D4. It treats the
named bands as places to investigate while requiring the actual key, melody,
harmonics, recording, and ears. It also identifies a preservation tradeoff: an
upper boost can increase sibilance; excessive de-essing can create lisping and
reduce intelligibility; low-mid removal can trade body/warmth for clarity; too
little 400-800 Hz can sound hollow. Its individual example frequencies and 3 dB
high shelf are demonstrations, not general targets.

TrackSmith consequence: vocal `warm`, `clear`, `boxy`, `sibilant`, and `airy`
must be modeled as overlapping, sometimes contradictory hypotheses. Whole-capture
band ratios cannot replace event-based sibilance evidence, and a de-esser plan
must carry intelligibility/air preservation risks. The article is professional
practice, not peer-reviewed validation, and must not be cited as proof that any
measured ratio makes a vocal muddy, boxy, or airy.

## Foundation-model editing, audio-language, and human-AI workflow synthesis

### Preference roles, production references, and abstract musician language

This pass read six actual primary payloads that constrain how TrackSmith may use
open-ended musician language. They do **not** establish a universal adjective-to-
audio mapping. Together they support a representation and ambiguity policy:
separate preference role, reference relation, source/scope, perceptual hypothesis,
effect identity, implementation, and executable transform; then let measurements
support or contradict a hypothesis without declaring the adjective true.

**Baranes, Hennequin, and Epure, *Beyond Musical Descriptors: Extracting
Preference-Bearing Intent in Music Queries*, arXiv:2602.12301v1 (2026).** Payload
SHA-256: `f101bea39906f4731d657966a975b54531e0089a2bd84f5c96138db8c9eed652`.
Review status: **full source read**, all seven pages including corpus construction,
two-annotator protocol, span and role agreement, three-role model, model prompts,
benchmark, error analysis, conclusion, and appendix examples. The authors label
descriptor spans in 2,291 Reddit queries and assign desired/positive, excluded/
negative, or referential roles, yielding 3,935 annotations. On mutually extracted
descriptors, role agreement is high (reported Cohen's kappa 0.927), while exact
descriptor-span agreement is 77.1%; these measure different problems and must not
be collapsed. The evaluated negative class is only 31 examples. Referential
phrases remain a material failure mode: the reported confusion matrix includes
231 referential cases predicted positive. The strongest reported model result
(Gemma 27B) reaches .69 exact and .76 partial F1 for the combined task, with generic
over-detection, omissions, segmentation disputes, and genuine ambiguity retained.
TrackSmith consequence: desired, prohibited, preserved, and referential spans need
different typed roles and exact state/reference resolution. A phrase such as “like
version two” or “the warmth of Reference A” is not a positive global target.
TrackSmith must not overclaim that this retrieval-query corpus proves production
semantics, acoustic interpretations, or robust negation from the small negative set.

**Vanka, Safi, Rolland, and Fazekas, *The Role of Communication and Reference Songs
in the Mixing Process: Insights from Professional Mix Engineers*,
arXiv:2309.03404v3 (2023).** Payload SHA-256:
`ff21c74540262cac4828eb9d1e00674466ab04f7e90e76c31e3f32f555d15f55`.
Review status: **full relevant source read**, including the two-phase method,
participant profiles, demo/reference use, feedback and completion results,
discussion, and limitations. Phase one interviewed five professional engineers;
phase two surveyed 22 professional/pro-am engineers, all with more than three years'
experience. The sample came through personal networks, was about 95% male in phase
two, emphasized pop/rock/metal practice, and supports descriptive—not population—
claims. Reported reference use was heterogeneous: roughly 90% of respondents who
used references used more than one; references could concern a whole mix, one
element, an interaction, emotion, structure, or a technical benchmark and were
often explicitly not targets for exact copying. Engineers iterated through client
feedback and contextual stopping decisions. TrackSmith consequence: reference
identity, attribute scope, relationship, and preservation goal are first-class;
multiple references and revisions remain separate rather than averaged into one
target. TrackSmith must not turn these convenience-sample percentages into global
usage prevalence or infer a processing chain from a named record.

**Wilmering, Fazekas, and Sandler, *Towards Ontological Representations of Digital
Audio Effects*, DAFx-2011 proceedings.** Payload SHA-256:
`ab3c3203e1a694892e1d0937e7d60bf8ed03aa3f7983f272fff3e84d3a59b2d0`.
Review status: **full source read**, all four pages including the perceptual,
technical/DSP, and audio-engineering taxonomy views; RDF/OWL listings; effect,
implementation, transform, parameter, event, timeline, track, and provenance
relations; SPARQL example; limitations; and conclusion. The paper directly
demonstrates a representation and one provenance query, not acoustic or usability
validation. It explicitly acknowledges ambiguity in technical classification and
leaves a specialized DSP ontology to future work. TrackSmith consequence: a user
term, possible acoustic sense, Logic effect identity, deterministic TrackSmith
implementation, parameter state, render event, and source provenance must remain
different typed objects. RDF is not required to preserve that separation.
TrackSmith must not claim ontology membership proves an audible result or that the
paper's perceptual links are complete or contextually correct.

**Venkatesh, Moffat, and Miranda, *Word Embeddings for Automatic Equalization in
Audio Mixing*, arXiv:2202.08898v2 (2022).** Payload SHA-256:
`76d2cf38a375a5bd0d8767cd5e33478341d31c4a0c1bf3b551b43ae34a4a7b8a`.
Review status: **full source read**, all ten pages including SocialEQ construction,
folds, frozen GloVe/Tok2Vec/Dict2Vec inputs, network layers, normalization, loss,
MAE and Perceptual-Centroid-Metric results, plots, descriptor examples, discussion,
and limitations. The English subset contains 918 of 1,595 examples, 388 unique
words, three source files (electric guitar, piano, drums), and 40 EQ bands. Test
words are unseen during training; high-quality/high-relevance test terms have
consistency above .7, while noisy training terms were not filtered. The network
maps a frozen 300-dimensional embedding through dense layers of 300/200/100/80/60
units to 40 sigmoid outputs, interpreted over a bounded -4 to +4 dB range. Tok2Vec
improves MAE from .836 without embeddings to .760, a small numerical result. The
paper reports a much larger improvement in its Perceptual Centroid Metric (human
2.9, GloVe 9.3, Tok2Vec 10.5, no embedding 35.4) but also says that metric is not
ideal; there is no listening test of generated EQ. Several examples are plausible,
others conflict or resemble chance, and source identity is not a network input.
The authors explicitly note that “bright” for vocals may differ from “bright” for
drums. TrackSmith consequence: lexical/embedding similarity may retrieve bounded
candidate terms, never select EQ or establish perceptual correctness. Source class,
measured evidence, competing hypotheses, and level-matched listening remain
mandatory. TrackSmith must not cite the MAE/centroid scores as proof of a universal
word-to-EQ function.

**Cameron and Blackwell, *A Semantic Timbre Dataset for the Electric Guitar*,
arXiv:2603.16682v1 (2026).** Payload SHA-256:
`4cbd805767a2934a9d50e9e59bd83a602fa8ab172fa4ae60c9c070ba3e5752e0`.
Review status: **full source read**, all five pages including the 275,310-note
dataset construction, 19-descriptor taxonomy derived from 72 pedals and two
software suites, Guitar Rig control stepping, VAE subset/architecture and
Griffin-Lim reconstruction, CNN classification, 20-listener MOS study, interpolation
ranking, and conclusion. The VAE uses only 1,771 E4-D6 examples from the larger
monophonic-note collection. Most reported MOS values exceed four, but *Tight*
(2.91), *Stutter* (2.74), and *Wah* (2.95) are materially weaker. The same 20
participants—18 musically trained and eight guitarists—rank selected interpolation
pairs, producing Kendall's tau .879. The classifier is trained inside the same
constructed descriptor universe and therefore is not independent evidence that
the labels are universal. TrackSmith consequence: source-specific semantic
structure and alternative senses are useful for retrieval and audition; guitar
descriptor interpolation is not evidence for vocals, drums, bass, synths, mixes,
or arbitrary guitar roles. TrackSmith must not present the descriptor labels,
classifier, or small listening panel as a universal adjective-to-effect map.

**Salganik et al., *MusicSem: A Semantically Rich Language--Audio Dataset of
Natural Music Descriptions*, arXiv:2602.17769v1 (2026).** Payload SHA-256:
`7961b2d2faf59b93f4ae37650bc1ce7781b74e238b1c733b965203d7dfe829d7`.
Review status: **full relevant source read**, all 51 pages covering taxonomy,
Equations 1-4, Reddit/data pipeline, GPT-4o extraction and summarization, Claude
3.7 hallucination filtering, manual checks, statistics/bias/ethics, three evaluation
lanes, fine-tuning, metrics, limitations, prompts, hyperparameters, and appendices.
The taxonomy separates descriptive, contextual, situational, atmospheric, and
metadata language. The semantic-sensitivity test uses 50 MusicCaps pairs for which
trained musicians wrote counterfactual captions. Its generation sensitivity is the
mean `1 - cosine` distance between representations of original and counterfactual
outputs; retrieval sensitivity is `1 -` the overlap ratio of their top-k result
sets. These are response-change measures, not production-correctness measures.
MusicSem contains 32,493 language-audio pairs for 11,842 songs and 4,430 artists
from five English-language subreddits over 2008-2022, plus a 480-entry human-
validated test set. The pipeline and evaluation retain Reddit/genre/cultural/
popularity bias, residual subjectivity/noise, entity ambiguity, and model-generated
text/checks. Retrieval remains difficult (for example, reported CLaMP3 Recall@10
is 26.84% on MusicSem); captions hallucinate facts; n-gram metrics do not imply
semantic correctness; FAD depends on embedding/reference; and CLAP score is weakly
sensitive to contextual meaning. Fine-tuning improves in-domain retrieval and the
selected sensitivity measure but does not validate production decisions.
TrackSmith consequence: atmospheric, situational, and contextual phrases should
remain labeled non-acoustic context unless decomposed into supported production
hypotheses. Counterfactual semantic tests should verify that desired, prohibited,
preserved, and referential roles change appropriately. TrackSmith must not use CLAP,
caption similarity, or semantic sensitivity as evidence that an edit sounds better
or that a musician's intent has one acoustic realization.

The implemented consequence is a separate generated
`AbstractMusicianLanguageKnowledgeCatalog`, derived from
`PRODUCTION_LANGUAGE_ONTOLOGY.json`. It initially covers 14 high-value abstract
concepts—including *expensive*, *bedroom-recorded*, *vulnerable*, *alive*,
*emotionally boring*, *glued*, *small/bigger*, *three-dimensional*, *human*,
*blurry*, *painful when loud*, *surround the vocal*, and *clean without
sterilizing*. Each entry supplies source-scoped alternate senses, contradictions,
candidate canonical terms, only allow-listed strategy categories, preservation
risks, non-DSP/unsupported causes, resolution policy, exact provenance, and a
prohibited fixed mapping. Context labels these entries
`PROFESSIONAL_PRACTICE_HEURISTIC`; they contain explicit false authority fields
and no `NodeType`, parameter map, host action, or measurement. Exact phrase
retrieval can improve which existing typed metrics/terms are shown to the provider,
but every provider response still passes decoding, schema, semantic, capability,
state-reference, and constraint validation before it can influence planning.

### Pan et al.: foundation-model audio-editing survey, 2026

Source identity: Changhao Pan et al., *Audio Editing in the Era of Foundation
Models: A Survey*, arXiv:2606.23139v1, 22 June 2026.  
Payload SHA-256: `2894274b643225b21826e612a852d6cb63ed7d9a34f2861951b337b49f5404f2`  
Review status: **full relevant source read**; taxonomy, token/diffusion/flow
architectures, instructional and reference conditioning, training-based and
training-free methods, inversion/attention/masking, datasets, evaluation,
limitations, scope, detailed task taxonomy, and future-challenge sections were
read. The bibliography was checked as provenance, not treated as evidence that
all cited primary experiments were independently reproduced here.

The survey's most useful contribution for TrackSmith is a separation between
acoustic, semantic, and instance editing and its observation that real requests
are often compositional rather than one-label tasks. It consistently treats
target modification and non-target preservation as separate requirements.
Instructional training can represent an operation, target, style, and preservation
scope in language; reference conditioning can express a direction by example;
masking provides explicit locality. These are organizing concepts, not proof that
a particular model reliably performs them.

The architecture comparison exposes different failure modes. Discrete codec
models can lose spectral detail and accumulate autoregressive errors, particularly
for complex music. Continuous diffusion/flow approaches can preserve acoustic
detail but remain sensitive to inversion, localization, masking, source
conditioning, and preservation objectives. Training-based systems can be stable
inside a covered task/data distribution; training-free systems are more flexible
but less predictable. The survey reports that instruction-aligned editing data
are scarce and that many systems rely on synthetic or adapted pairs. It also
explicitly excludes detailed signal-processing workflows and spatial audio and
focuses mainly on monaural foundation-model editing.

Its evaluation synthesis is strongly aligned with TrackSmith's safety model:
instruction adherence, target success, non-target preservation/locality,
temporal/structural consistency, and audio quality are distinct dimensions. An
output can sound natural but miss the instruction, or satisfy the instruction
while changing identity, ambience, rhythm, or texture. Text-audio similarity is
only a semantic proxy; acoustic-quality predictors do not know whether the edit
was correct; model-based judges require calibration to human listening. The
paper's broad claim that foundation models improved controllability is a survey
judgment over heterogeneous cited work, not a controlled cross-system
experiment. It is also a very recent v1 preprint and cannot settle production
architecture by itself.

TrackSmith consequence: use language to construct a typed edit specification,
not to bypass evidence. The system must represent target, preserved attributes,
prohibited changes, source scope, uncertainty, and expected direction separately.
Foundation waveform editing, source replacement, and reference matching remain
experimental and out of this milestone. TrackSmith must not cite this survey as
proof that a model understands a mix, preserves non-target audio, or can judge
production quality.

### Su et al.: systematic audio-language survey, 2026

Source identity: Yi Su et al., *Audio-Language Models for Audio-Centric Tasks: A
Systematic Survey*, arXiv:2501.15177v2, 12 March 2026.  
Payload SHA-256: `dcfdb1f3aa7fbda8e029b6180d56d97292d384c6458b5d5ad6954170e717b646`  
Review status: **full relevant source read**; pre-training/transfer model,
two-tower, two-head, one-head and cooperating-system architectures, contrastive
equations and finite-negative-pool issue, multi-task/instruction tuning, agent
systems, datasets, benchmark/evaluation methods, reported results, hallucination,
security, privacy, bias, compute cost, and evaluation recommendations were read.

The survey distinguishes embedding alignment from open-ended reasoning. A
two-tower CLAP-style system is optimized with symmetric InfoNCE to retrieve or
classify via similarity in a joint audio-text space; that objective does not by
itself yield causal production reasoning. The finite batch supplies a sparse,
biased negative pool, and larger batches trade bias mitigation for substantial
compute. Two-head systems add a language model, while cooperating systems use an
LLM to select specialized tools. The latter is the closest architectural analogue
to TrackSmith, but the survey says systematic application-specific comparisons
remain limited and recommends evaluation in the actual deployment context.

Several constraints are directly relevant. Audio-language models can generate
answers ungrounded in the audio and can affirm sounds that do not exist. Web data
bring link rot, duplication/leakage, weak or generated text, cultural and
linguistic bias, privacy risk, and unstable benchmark comparability. Supervised
adaptation substantially changes results, so zero-shot benchmark scores cannot be
ported to a production planner. The review labels language a versatile interface;
it does not demonstrate that free-form text maps uniquely to an acoustic state or
safe DSP settings. Although called systematic, the paper does not report a
PRISMA-style search, inclusion, or quality-assessment protocol, so completeness
claims should be treated cautiously.

TrackSmith consequence: an LLM may parse or explain a request, while typed code
must own evidence qualification, plan constraints, validation, and DSP parameter
bounds. Embedding similarity may later rank candidate terms or references, but it
must not be treated as proof that audio is warm, polished, muddy, or correct.
Unverified model statements about the audio require contradiction checks against
deterministic measurements and, for perceptual decisions, listening.

### Yang et al.: AIR-Bench primary evaluation study, 2024

Source identity: Qian Yang et al., *AIR-Bench: Benchmarking Large Audio-Language
Models via Generative Comprehension*, ACL 2024, pages 1979-1998.  
Payload SHA-256: `210791f4d8f6f379cc89411e8a584aa1ca9c5707191ebf365b41363343e2ec65`  
Review status: **full relevant source read**; benchmark composition, question and
candidate generation, manual review, mixed-audio construction, GPT-4 reference
and evaluator pipeline, tested models, results, human comparison, position-bias
ablation, limitations, and ethical considerations were read.

AIR-Bench contains more than 19,000 foundation questions over 19 tasks and more
than 2,000 open-ended chat questions spanning speech, sound, music, and synthetic
mixed audio. Much of the question/reference construction uses GPT-4 over dataset
metadata, followed by manual review. Its evaluator does not hear the waveform;
GPT-4 receives metadata, a question, a reference answer, and a model hypothesis.
The study therefore validates answer alignment to available metadata, not
production listening or direct acoustic judgment.

The reported human comparison is useful but bounded: three native-English
listeners evaluated 400 foundation questions for a representative model, and
three evaluated 200 chat questions as pairwise preferences among selected
systems. GPT-4 agreement was 98.2% for the foundation selection task and above
70% for chat pairwise preferences. The authors also found a clear hypothesis-
position bias and mitigated it by scoring both orders. This supports a narrow use
of LLM judging for structured answer comparison; it does not validate an LLM as
a mix engineer, a perceptual-quality meter, or an audio-grounded judge when it
does not receive the audio. The benchmark excludes multi-audio comparison,
music-coherence assessment, and multi-turn/multi-audio dialogue, and depends on
an external closed evaluator.

TrackSmith consequence: semantic corpus assertions may use deterministic schema
checks and bounded text comparisons. Audio success still needs metric-direction
checks and listening. Any future model-based judge must declare what it actually
receives, counter ordering bias, and be calibrated on TrackSmith-specific audio
tasks instead of inheriting AIR-Bench's headline agreement rate.

### Ronchini et al.: producer workflow user study, 2025

Source identity: Francesca Ronchini et al., *AI-Assisted Music Production: A User
Study on Text-to-Music Models*, Proceedings of the 17th CMMR, 2025, CC BY 4.0.  
Payload SHA-256: `d0413d0e10a91c5af6aa9f55bd8b67200beb8a1378d482b13be974675f0fc8b2`  
Review status: **full-read**, all sections including participant recruitment,
interface/model choices, one-hour procedure, questionnaires, descriptive results,
qualitative coding process, themes, discussion, conclusions, and disclosures.

Seventeen producers from seven countries used a custom Gradio interface around
MusicGen and six-stem HT-Demucs during a one-hour session in their own DAW/setup.
MusicGen melody conditioning and vocals were excluded. The study reports
descriptive Likert results and an inductive thematic analysis: one author drafted
39 codes, two others iteratively refined them into 14 themes. It reports no
inter-rater reliability statistic, no control condition, no longitudinal use, and
no inferential test capable of establishing population-level effects.

Within that scope, the evidence supports product hypotheses. Participants often
used generation for ideation and experimentation; control and prompt
responsiveness were mixed. Recurring integration problems included tempo, key,
beat/loop alignment, separation artifacts, and only partially usable outputs.
Participants requested finer controls, reference or multimodal input, iterative
revision of only part of an accepted result, preserved state, and DAW integration.
Unexpected outputs sometimes inspired new directions but also displaced a clear
original intent. The authors consequently describe the tested system as more
useful for sketching/inspiration than production-ready delivery.

TrackSmith consequence: preserve the user's stated intent, make revisions local
and editable, show multiple candidates, retain accepted state, expose uncertainty,
and integrate into the actual DAW workflow. These are moderately supported UX
directions, not universal truths about all producers or evidence for text-to-music
generation. TrackSmith must not interpret surprise as success when it violated a
preservation constraint, and must not generalize percentages from this small
self-selected sample to the producer population.

### Consequences across these source families

The defensible architecture is:

`language request -> typed intent and preservation contract -> source-aware
evidence -> explicit competing hypotheses -> bounded editable DSP plans ->
objective direction checks plus listening`.

This differs materially from both an audio chatbot and direct text-to-parameter
mapping. It preserves ambiguity instead of hallucinating a single meaning,
separates acoustic evidence from perceptual language, keeps non-target preservation
first-class, and supports iterative revision without regenerating accepted work.
Cloud or audio-language models can later assist with parsing, retrieval, or
explanation, but their outputs remain untrusted proposals until grounded by the
typed layer. Full generative editing and automated perceptual judging should
remain experimental.

## Sources not allowed to settle decisions by themselves

All minimum source families named for this milestone now have at least one actual
relevant primary, normative, or clearly labelled professional-practice payload
reviewed in detail. This does **not** make the corpus exhaustive. Vendor tutorials,
single user studies, small listening panels, surveys, source-class averages,
foundation-model benchmarks, and the Logic effects manual cannot individually
settle production semantics. Any newly introduced architecture, threshold,
semantic mapping, or evaluation claim still requires its own source-level review
and traceability entry before it becomes a TrackSmith default.

## Implemented consequence and validation closure

This section closes the loop from the reviewed payloads to the milestone's concrete
behavior. It is not a new evidence class: the source claims, assumptions,
contradictions, hashes, and review extents above remain controlling.

### Host and workflow consequences

- The official Logic and Audio Unit material supports an AU effect plus companion,
  host-owned parameter/state restoration, selection/bounce as explicit user
  workflows, and conservative treatment of control surfaces. Those consequences are
  represented in `docs/ARCHITECTURE.md`, `docs/DATA_FLOW.md`, and
  `docs/LOGIC_INTEGRATION_SPIKE.md`; ARA, arbitrary project editing, Accessibility
  automation, and broad MIDI control remain outside this milestone.
- A versioned real-host lane now records Logic Pro 12.3 build 6674 on macOS 26.3,
  the exact AU/app signing identities and executable hashes, 44.1 kHz mono runtime,
  discovery/insertion/playback, recent capture, three distinct previews, inspected
  graph, locked-node targeted revision, commit, bypass/restore, save/reload,
  two-live-instance isolation, and unchanged source bytes. The authoritative ledger
  is `docs/evidence/LOGIC_12_3_VALIDATION_2026-07-14.md`.
- The Logic 11.2.2 evidence is preserved as a separate historical lane. The 12.3
  lane proves the exactly identified installed compatibility binary; portable
  working-tree regressions prove current source separately. TrackSmith must not
  collapse those two facts into a claim that every current source edit ran inside
  Logic 12.3.

### Standards consequences

- `packages/AudioAnalysis/Sources/AudioAnalysis/LoudnessMeter.swift` implements
  BS.1770 K-weighted Integrated Loudness, EBU Mode 3-second rectangular Short-term
  Loudness at 100 ms hops, and Tech 3342 LRA using the -70 LUFS absolute gate,
  -20 LU relative gate, power-domain mean, and specified percentile indexing.
- `packages/AudioAnalysis/Sources/AudioAnalysis/AudioAnalyzer.swift` exposes those
  results with units, windowing, and limitations. LRA has an explicit insufficient-
  duration state and an `unstableBelowSixtySeconds` state rather than presenting a
  short capture as representative programme dynamics.
- `docs/LOUDNESS_STANDARDS_TRACEABILITY.md` maps document versions, exact sections,
  equations/algorithms, implementation interpretations, vectors, deviations, and
  conformance boundaries. Four Tech 3342 synthetic minimum cases and 14 official
  BS.2217-2 mono/stereo Integrated Loudness vectors pass. This is supported-subset
  conformance evidence, not complete BS.1770/EBU or true-peak conformance.

### Source-aware analysis consequences

- `packages/AudioAnalysis/Sources/AudioAnalysis/SourceAwareAnalysis.swift` provides
  typed versioned reports for vocal, drums/drum bus, bass, guitar, synth/keys, and
  full stereo mix. Each metric states units or range, confidence, applicable source,
  validity conditions, aggregation/windowing, known failure modes, version, and
  source/practice provenance.
- The implemented metrics cover the milestone's requested evidence families:
  sibilance/plosive bands, level consistency, spectral balance and proximity/air;
  transients/onsets/crest/low punch/high-frequency energy/sustain; bass balance,
  low-mid density, consistency and definition; guitar/synth density,
  concentration, stereo behavior and envelope; and full-mix tonal, loudness/LRA,
  crest, width/correlation, mono low end, and broad imbalance evidence.
- These are descriptors, not diagnoses. No output directly asserts “muddy,”
  “punchy,” “warm,” “professional,” or another perceptual adjective from one value.
  Mono fold-down, arrangement, room, role, lyrics/phonemes, monitoring, and listener
  preference remain important unobserved variables.

### Production-language and planning consequences

- `packages/AgentCore/Sources/AgentCore/ProductionIntentVocabulary.swift` covers all
  28 requested production descriptors plus four explicit preservation concepts.
  Definitions carry aliases, source applicability, competing acoustic
  interpretations, context dependence, supporting and contradictory evidence,
  candidate strategies, risks, failures, confidence, evidence class, and provenance.
- `research/knowledge/PRODUCTION_LANGUAGE_ONTOLOGY.json` now generates a separate
  14-entry abstract-language advisory catalog for source-dependent phrases that do
  not belong in the executable term enum. Exact bounded phrase retrieval supplies
  alternate senses, contradictions, non-DSP causes, preservation risks, and
  clarification policy as professional-practice heuristics. It cannot create a
  capability, metric, node, parameter, host action, or constraint override.
- `packages/AgentCore/Sources/AgentCore/ProductionHypothesisEngine.swift` implements
  the typed boundary
  `intent -> source-aware evidence -> competing production hypothesis -> bounded
  deterministic editable plans`. A hypothesis records evidence for and against,
  uncertainty, options considered, selection, preservation constraints, risks,
  expected measurable direction, listening dependence, and provenance. No LLM is
  connected directly to DSP parameters.
- The eight required examples pass through that boundary for vocal, drums, bass,
  guitar, synth, and full mix, including preservation and prohibited-change
  constraints. Passing means schema, evidence, constraint, plan-validation, and
  expected-direction assertions succeeded; it does not mean a listening panel has
  established that each render is perceptually optimal.
- `research/evaluation/TRACKSMITH_PRODUCTION_INTENT_CORPUS_V1.json` contains 70
  semantic templates expanded over six source contexts, producing 420 evaluated
  cases. It covers ordinary, vague, contradictory, preservation, impossible,
  source-inappropriate, multi-term, revision, named-reference, and ambiguous input.
  Deterministic assertions test scope, desired/preserved/prohibited attributes,
  uncertainty, and clarification/rejection behavior. This is structural semantic
  regression, not open-domain language understanding or perceptual validation.
- `research/analysis/TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md` adds nine
  content-addressed sources on professional references, rough-mix constraints,
  co-creative dialogue, preference-bearing roles, natural music language,
  source-specific timbre, workflow, quality priors, and listener expertise. Its
  concrete consequence is to keep desired, preserved, prohibited, and referential
  intent distinct and to require an explicit scope before using a reference.

### Provenance-ingestion consequences

- `research/RESOURCE_INGESTION_CONTRACT.md` and
  `packages/ResearchIngestion/Sources/ResearchIngestion/` replace blind archival
  downloads with exact retrieval completion, declared/observed media validation,
  minimum-quality checks, HTML/JavaScript-shell and partial/corrupt rejection,
  SHA-256 content addressing, duplicate reuse, immutable publication, quarantine,
  append-only history, explicit version/supersession, rights/local-use metadata,
  and clean pinned Git origin/commit validation.
- Ingestion never overwrites user-supplied artifacts. A successful ingest proves
  provenance and payload mechanics only; human review is still required before the
  content can justify a TrackSmith decision.

### Current regression evidence and remaining uncertainty

- With the 14 selected official BS.2217-2 WAVs supplied, current Debug and Release
  TestRunner lanes pass 55/55. The ordinary Thread Sanitizer lane passes 54/54 with
  those external files omitted and emits no race report. `auval`, Debug/Release/TSan
  host probes, and the 4,000-callback heap interposer lane pass; the Release host
  measured 9.6 us mean, 11.2 us p99, and 44.5 us maximum for the recorded graph,
  while the interposer observed zero heap operations on its exercised callback path.
- These results do not close the remaining listening, broad-host-matrix,
  automation, bounce/freeze, low-latency, full rate/buffer, immersive loudness,
  comprehensive true-peak, learned source-recognition, or open-language gaps. Named
  style/reference matching, ST-ITO deployment, source separation, waveform
  generation/replacement, and general project editing remain experimental or out of
  scope exactly as the source review recommends.

## 2026-07-16 comprehensive-research expansion

The first expansion batch adds eight full-read academic sources and eighteen
competitor-source reviews. Its detailed evidence remains in
`AUTOMATIC_MIXING_REFERENCE_CONTROL_SYNTHESIS.md`, `COMPETITOR_LANDSCAPE.md`,
`EVALUATION_PATTERNS.md`, and the corresponding deep-review JSONL records. This
section records only the conclusions that materially refine the product boundary.

### Strong convergence with the existing architecture

The new evidence does not justify replacing the AUv3 effect, macOS companion,
signed App Group communication, typed intent/hypothesis boundary, deterministic
DSP, exact preview/revision/commit workflow, or provider-neutral future-reasoning
layer. It strengthens them:

1. Diff-MST and ITO-Master use explicit processor graphs because inspectable DSP
   is a useful inductive and product constraint. Ozone, Neutron, Nectar, RX, and
   the sonible smart series likewise expose analysis results through editable
   modules or conventional controls. Editable DSP is therefore necessary but no
   longer differentiating by itself.
2. Competitor manuals repeatedly condition analysis on source profile, section,
   role, full-song context, sidechain, or reference. The academic sources show
   that matched-content inverse recovery, paired transformation learning,
   synthetic same-song style, different-content feature matching, and cross-track
   control are different mathematical problems. TrackSmith must type that scope
   before it chooses measurements or an optimizer.
3. The strongest trust mechanisms are observable and operational: loudness-
   controlled comparison, delta/removed-signal audition, bypass, multiple states,
   exact candidate persistence, and the ability to abstain. A confidence number
   without those controls is insufficient.
4. The evidence repeatedly contradicts one-optimum behavior. In the reviewed
   automatic multitrack-compression study, light processing competed with no
   compression while heavy processing failed; an expert's role-specific vocal
   choice violated the global allocation rule. TrackSmith's simultaneous,
   labelled candidates and no-op route are architectural advantages.

### Reference audio is negotiated evidence

The phrase “reference matching” now resolves to a typed set of routes:

- `matchedContentInverse`: identical aligned content and a declared transform
  family; constrained recovery can be tested offline;
- `pairedTransformationLearning`: aligned before/after examples for a bounded,
  state-aware processor family;
- `syntheticStyleRecovery`: controlled test/pretraining material, never automatic
  proof of human style;
- `scopedDifferentContentStyle`: selected feature directions with explicit
  desired, preserved, prohibited, source, role, and uncertainty fields;
- `crossTrackRelationship`: no external reference, but a protected role and
  explicit context mechanism are required; and
- `provenanceReconstruction`: queryable source/plan/result lineage rather than an
  acoustic matching objective.

A different song cannot reveal its original plug-in chain, settings, monitoring,
stems, arrangement intent, or which audible traits the user values. Feature or
embedding distance may rank bounded candidates; it cannot authorize commit.

### Measurements and optimizers remain proposal machinery

The full-read papers provide useful bounded methods: constrained least squares
for known aligned linear transforms, SPSA through cloned stateful processors,
explicit-console prediction, learned-latent optimization, source-conditioned
regression, cross-track descriptors, and effect/provenance representation. Each
has material transfer limits:

- linear inverse recovery fails outside alignment, rank, conditioning and model-
  class assumptions;
- different-content objectives are underdetermined and can improve one feature
  metric while degrading another distributional metric;
- learned models use short clips, synthetic processing, limited track counts,
  static settings or small panels;
- spectral-overlap and LRA-derived heuristics do not establish artistic priority;
  and
- semantic or genre prompts can reproduce stereotypes without demonstrating
  production knowledge.

Any later optimization must run outside the real-time thread, stay within typed
parameter/preservation bounds, emit an ordinary inspectable `ProcessingPlan`,
retain multiple nondominated candidates when objectives conflict, and remain
subject to technical guardrails and listening.

### Competitive differentiation now has a sharper definition

The crowded ideas are one-click analysis, target curves, profile selection,
semantic macro controls, visible modules, and basic A/B. The less-crowded and
better-fitting TrackSmith opportunity is a durable production-reasoning contract:

```text
observation with validity and failure conditions
-> contextual interpretation and alternatives
-> evidence for and against a production hypothesis
-> explicit preservation/prohibition constraints
-> bounded candidate plans including no change
-> exact loudness-controlled and operation-specific audition
-> local revision with parent/evidence lineage
-> commit/bypass/project persistence
```

Cross-track capability must be typed rather than Boolean: shared metering, remote
control, sidechain interaction, joint group objective, sequential accepted-plan
context, and actual multitrack rendering are not equivalent. Estimated stems and
generated parts must become new provenance-tagged assets rather than masquerading
as original stems or deterministic effect nodes. Speech enhancement remains useful
workflow evidence but cannot establish music-production quality.

### New evaluation consequence

One benchmark cannot support all product claims. TrackSmith now requires separate
lanes for source integrity, semantic/ambiguity resolution, normative measurement,
reference-problem routing, deterministic real-time DSP, audition validity,
technical and preservation guardrails, repair/separation, long-form coherence,
human listening/workflow, competitor black-box tests, and future provider/model
calibration. `EVALUATION_PATTERNS.md` defines the minimum evidence and prohibited
inference for each lane.

This expansion still does not establish search saturation, broad user consensus,
patent freedom to operate, complete producer judgment, genre rules, or expert-
level autonomous production. Those remain active corpus tasks rather than hidden
assumptions.
