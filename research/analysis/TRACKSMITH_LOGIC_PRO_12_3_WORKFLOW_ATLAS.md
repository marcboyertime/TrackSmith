# TrackSmith Logic Pro 12.3 Workflow and Tool Atlas

Status: complete deep review, 2026-07-15. This atlas records actual reading of
every page of Apple's 1,324-page *Logic Pro User Guide for Mac*. It complements
the complete Effects and Instruments atlases. An outline entry or search hit was
never counted as deep review.

## Epistemic and execution rules

1. Apple documentation is authoritative for documented Logic controls,
   workflows, state scopes, formats, and host behavior. It is not proof of an
   undocumented API or of TrackSmith authority to invoke a host command.
2. A documented workflow may be advisory-only for TrackSmith. In particular,
   region/file edits, MIDI edits, third-party insertion, bounce, project
   mutation, Environment wiring, Session Player changes, Stem Splitter, and
   automation are not ordinary AU permissions.
3. Destructive, file-writing, overwrite, merge, flatten, replace, consolidate,
   normalize, and export operations require explicit source-preservation and
   rollback analysis. A convenient Logic command is not automatically safe for
   conversational execution.
4. Project state, region state, audio-file state, plug-in state, automation,
   Library patch state, and companion conversation state are different identity
   domains. The atlas records these distinctions rather than calling all of them
   “the project.”
5. Editing and production advice is context-dependent. A tool's availability
   does not establish that using it will satisfy a perceptual intent.
6. TrackSmith's deterministic DSP graph remains the only audio-execution
   authority. This knowledge can explain Logic-native alternatives and limits;
   it cannot invent successful host actions.

## Immutable primary source

| Source | Version | Pages | SHA-256 | Rights/status |
|---|---|---:|---|---|
| Apple, *Logic Pro User Guide for Mac* | Logic Pro 12.3 payload, PDF created 2026-07-07, retrieved 2026-07-14 | 1,324 | `aa016d18d7e4f3559cdec54a99937d00b379617fee87510db1ec9853a4996cff` | Apple copyright; immutable local-use-only research object |

Canonical object:
`research/papers/tracksmith-logic-12.3-archive/objects/aa016d18d7e4f3559cdec54a99937d00b379617fee87510db1ec9853a4996cff.pdf`.
The generated outline index remains navigation metadata with status
`source_index_only_not_deep_review_evidence`.

Version-specific supplement: Apple's mutable *Logic Pro for Mac release notes*
page was captured 2026-07-16 through the research-ingestion contract as validated
HTML, SHA-256
`854fd08c8e38351d521a9feed35a77fc2ce5969baab473e270decd2425f0dcb0`.
The complete 12.3 section was read, including feature, stability, AU, ARA,
automation, bounce/export, control-surface, editing, Flex, mixer/routing, recording,
sampler, and sound-library deltas. Because Apple updates this page, claims are
bound to this exact payload rather than to a future page with the same URL.

## Review ledger

`Deep` means every relevant page in the stated range was read, including
warnings, state effects, exceptions, and destructive behavior. `Prior focused
deep read` means the TrackSmith host-contract review already read the named
subfamilies, but the complete top-level range still awaits this exhaustive pass.

| User Guide family | Pages | Status |
|---|---:|---|
| What's new in Logic Pro 12.3 | 10-12 | Deep |
| Logic Pro basics/interface/windows/tools/undo | 13-67 | Deep |
| External audio, MIDI, and virtual devices | 68-77 | Deep |
| Projects, assets, alternatives, backups, properties | 78-115 | Deep |
| Tracks, patches, stacks, groove, articulations, bounce/SBP/export | 116-190 | Deep |
| Audio/software-instrument recording, metronome, comping | 191-247 | Deep |
| Apple Loops, browsers, project audio, formats | 248-287 | Deep |
| Arrange regions/chords/fades/Stem Splitter/silence/folders/groove | 288-371 | Deep |
| Audio Track Editor | 372-377 | Deep |
| Piano Roll Editor | 378-402 | Deep |
| Session Players | 403-435 | Deep |
| Flex Time, Flex Pitch, Varispeed | 436-459 | Deep |
| Event List, Step Editor, Audio File Editor, MIDI Transform | 460-538 | Deep |
| Mixer, plug-ins, routing, groups, panning, undo | 539-620 | Deep |
| Track and region automation | 621-644 | Deep |
| Smart Controls | 645-657 | Deep |
| Live Loops | 658-694 | Deep |
| Step Sequencer | 695-731 | Deep |
| Global tracks, markers, signatures, tempo, beat mapping | 732-801 | Deep |
| Score Editor and notation | 802-907 | Deep |
| Bounce/share/export | 908-930 | Deep |
| Surround and Spatial Audio/Dolby Atmos | 931-1015 | Deep |
| Video and synchronization | 1016-1032 | Deep |
| Logic/project settings, key commands, pointer shortcuts | 1033-1171 | Deep |
| Touch Bar | 1172-1181 | Deep |
| Control surfaces and controller assignments | 1182-1223 | Deep |
| Environment and object reference | 1224-1295 | Deep |
| Glossary | 1296-1323 | Deep |
| Copyright and trademarks | 1324 | Deep |

## Existing host-contract conclusions retained

- Logic exposes AUv2 and AUv3 through ordinary plug-in workflows and labels AUv3
  as `(AU3)` in Plug-in Manager. This does not grant project/region/file access.
- Selection-Based Processing owns an independent A/B effect chain, context
  preview, tail handling, gain/loudness/overload choices, and region/take output.
  It is a product-workflow analogue, not a callable capability of a plain AU.
- Track and region automation, host bypass, Low Latency Monitoring, offline or
  real-time bounce, project alternatives/backups, save/reload, and audio-asset
  handling have already been deeply reviewed for TrackSmith's validated host
  contract. The exhaustive pass will add the surrounding editing semantics
  without rewriting the existing Logic 11.2.2 or 12.3 evidence.

## Logic 12.3 deltas that affect production reasoning

- Beat Breaker adds per-slice Cutoff, Resonance, and Pan plus bounded-by-UI but
  stochastic Randomize probability/amount. This expands Logic-native creative
  options but also adds random state and stereo/mono risk.
- Alchemy and Sample Alchemy add synchronized granular formant control and
  parallel grain streams. Advice derived from older granular behavior must not
  omit the 12.3 Sync path.
- Flex region state is now split among a Flex checkbox, Smart Tempo selection,
  File Tempo, and independent Follow Tempo/Follow Pitch behavior. “Make this
  follow the project” is therefore not one switch.
- Chord ID can analyze only the cycle-overlapped part of a dragged region and is
  documented as improved for both single instruments and full mixes. This is a
  host analysis workflow, not proof of exact transcription and not available to
  TrackSmith's ordinary AU.
- Video hit-point sync can adjust preceding tempo events so audio lands on a
  picture event. It is a global tempo mutation and cannot be inferred from an
  audio-only production request.

## Interface, tools, and state scopes

### Work areas and focus

- The Tracks area, Mixer, inspectors, Smart Controls, editors, list editors,
  browsers, notes, and separate windows are alternate views over different state
  scopes. Key commands act on the window/area with key focus; a correct command
  in the wrong focused editor can affect a different object type.
- Inspector region parameters generally change playback without rewriting the
  region's underlying data, while track parameters affect every region on a
  track. The Audio Track Editor is non-destructive; the Audio File Editor can
  destructively alter shared source files.
- An audio region is a reference to all or part of an audio file. MIDI data is
  stored in MIDI regions; pattern and Session Player regions retain different
  generative/editing semantics. Converting between these types can destroy or
  freeze generative state.
- A patch can contain multiple channel strips, plug-ins, sends, routing, and
  Smart Controls. A plug-in preset and a channel-strip setting have narrower
  scopes. Library Revert can erase current patch changes.
- The Project Audio Browser exposes file and derived-region identity, missing
  and tempo metadata, sample rate/bit depth/format, and file paths. The All Files
  Browser can import from the wider filesystem. Neither should be supplied to a
  cloud model as uncontrolled filenames or metadata.

### Tool semantics and hidden conversions

- Pointer, Pencil, Eraser, Text, Scissors, Join, Solo, Mute, Zoom, Fade,
  Automation Select/Curve, Marquee, Flex, Slip, Rotate, and Gain are distinct
  actions. Selection can broaden an operation: using Scissors or Eraser on one
  item while multiple items are selected can alter every selected item.
- Pointer click zones can silently become Fade, Loop, or Marquee behavior based
  on region edge/half and modifier keys. Left-, Command-, and right-click tools
  are separately assignable, so visible pointer/tool state is part of any manual
  reproduction evidence.
- Slip moves content within stationary boundaries and requires additional source
  material. Rotate wraps overflow; rotating audio converts the result to a
  one-track folder with two regions. Slip/rotate of a Session Player region first
  converts it to MIDI, losing the original generative region semantics.
- Marquee selection can drive Selection-Based Processing. The same selection can
  also constrain edits or playback, so TrackSmith must never infer scope solely
  from the selected track.
- Audio File Editor tools are destructive; Score, Step, Piano Roll, Environment,
  and Tracks-area tools have area-specific meanings. “Use the Pencil” is not a
  complete instruction without focus, target type, snap state, and selection.

### Complete editor-tool inventory

Apple's common/specific tool inventory on User Guide pages 54-60 contains 30
named tools. TrackSmith's machine-readable advisory catalogue is
`research/knowledge/logic-pro-12.3-editor-tool-knowledge.json`; its generator
requires the immutable User Guide hash and forbids host-execution authority.
The compact map below records the decisive state distinction for every tool;
the catalogue retains the fuller mechanism and risk synthesis.

| Tool | Area/scope | Decisive consequence or boundary |
|---|---|---|
| Pointer | Multiple areas | Selection, modifiers, click zones, snap, focus, and item type decide whether it selects, moves, copies, resizes, loops, fades, or marquees. |
| Pencil | Multiple areas | Creates or edits regions/events; Score use creates notation. MIDI defaults can be inherited from the last event. |
| Eraser | Multiple areas | A click can delete the entire current selection, not only the visible target. |
| Text | Multiple areas | Renames host objects or creates score text; text and names remain untrusted metadata. |
| Scissors | Multiple areas | Splits every selected item at the edit position; snap, zero crossings, takes, and folders alter the result. |
| Join | Multiple areas | Combines selected material; audio, MIDI, loops, Flex, takes, and folders have different conversion/asset consequences. |
| Solo | Multiple areas | Temporary hold/scrub audition, not a committed mix solo transaction. |
| Mute | Multiple areas | Toggles region/event mute and can propagate the clicked state across a selection; it is not track mute, bypass, or deletion. |
| Zoom | Multiple areas | View-only; affects visibility and click precision, never the sound. |
| Fade | Multiple areas | Creates/reshapes region fades; fade, crossfade, loop, overlap, and file-edge scopes differ. |
| Automation Select | Automation areas | Selects automation and can add border points; parameter, track/region scope, mode, snap, locks, and move-with-region policy are required context. |
| Automation Curve | Automation areas | Changes the host curve between points; the drawn curve is not proof of a plug-in's exact smoothed trajectory. |
| Marquee | Tracks/editors | Creates a temporal selection for editing/playback/SBP; the later command determines material consequences. |
| Flex | Tracks/audio editing | Edits time state; algorithm, tempo metadata, File Tempo, Follow behavior, groups, takes, and markers interact. |
| Slip | Tracks/editors | Offsets content inside fixed boundaries; Session Player regions convert to MIDI first. |
| Rotate | Tracks/editors | Wraps content; audio becomes a two-region one-track folder and Session Player regions convert to MIDI first. |
| Finger | Piano Roll/Step Editor | Resizes MIDI notes or moves steps depending on area focus. |
| Quantize | Piano Roll/Score | Applies active MIDI timing quantization; grid, strength, swing, Q-range, and region/event scope remain material. |
| Velocity | Piano Roll/Score | Changes MIDI velocity, whose audible mapping is instrument-dependent and is not a dB quantity. |
| Brush | Piano Roll | Paints notes/patterns using quantize and optional scale constraints; can generate many events from inherited state. |
| Vibrato | Audio Track Editor | Changes Flex Pitch note vibrato and inherits analysis/segmentation uncertainty. |
| Volume | Audio Track Editor | Changes analyzed-note gain; differs from region gain, fader, automation, normalization, and compression. |
| Move | Audio File Editor | Moves selected file content inside the destructive shared-file domain. |
| Camera | Score Editor | Exports notation as an image; it neither renders audio nor proves playback state. |
| Layout | Score Editor | Changes graphical notation placement without ordinarily moving MIDI timing; layout and playback positions remain distinct. |
| Resize | Score Editor | Changes displayed notation size, not velocity, duration, density, or level. |
| Voice Separation | Score Editor | Assigns notes to voice MIDI channels; this is not audio source separation. |
| Line | Step Editor | Draws/edits linear MIDI-event values; it cannot create MIDI note events. |
| MIDI Thru | MIDI Environment | Assigns an Environment object to the selected track, an unsupported host-routing mutation outside the AU. |
| Gain | Tracks area | Applies nondestructive region/marquee gain in dB; differs from file gain, normalization, fader, plug-in gain, and loudness. |

Direct consequence: a model may explain or recommend one of these tools only
after resolving the work area, object type, selection, temporal scope, snap,
modifier/tool assignment, current state, and preservation risk. The catalogue
contains no key command, Accessibility action, or executable Logic command.

### Undo, screensets, and advisory security

- Undo History can hold at most 200 configured steps. Mixer and plug-in changes
  are included only when their Undo History categories are enabled. A new edit
  after undo discards redo entries; deleting Undo History is irreversible.
  TrackSmith's own snapshots therefore remain necessary and cannot assume host
  undo is a complete transaction log.
- Screensets store window layout, focus-related views, zoom, and open panes and
  can switch automatically via MIDI meta event 49. They do not represent audio
  snapshots. Project import can replace/import screensets independently.
- Project and track notes can contain rich text, images, Apple Intelligence
  output, and arbitrary user/imported content. They are untrusted context and
  must never override TrackSmith constraints or become executable authority.
- Sound Library download/delete/relocation changes shared installed content and
  asset availability. These are user-consent/storage operations, not production
  moves a model may silently perform.

## External-device, driver, and MIDI authority boundaries

- Logic communicates with Core Audio devices through device drivers. Apple
  recommends using one device for input and output where possible; split input
  and output devices can introduce clocking, latency-reporting, and monitoring
  differences that are not recoverable from captured samples alone.
- Microphone level, instrument level, line level, impedance, preamplifier gain,
  analog clipping, direct monitoring, and hardware effects are upstream physical
  conditions. TrackSmith may measure their audible consequences, but it must not
  report a particular cable, impedance, preamp, or monitoring route as measured
  fact without explicit device metadata or user confirmation.
- MIDI over USB, dedicated MIDI interfaces, and daisy-chained MIDI hardware have
  different routing and timing behavior. Multiport and multichannel devices add
  explicit port/channel identity; a note event alone does not identify the
  intended external destination.
- A hardware synthesizer with Local Control enabled can sound both its local
  keyboard path and Logic's returned MIDI path. Apple documents doubled or
  phased notes and reduced effective polyphony as consequences; Local Off is the
  usual sequencer configuration. TrackSmith must not misdiagnose that condition
  as an EQ, chorus, or dynamics problem solely from audio evidence.
- Logic's Virtual In and Virtual Out ports connect other macOS applications to
  Logic and expose application/external-device authority outside the AU. Their
  presence does not permit TrackSmith to send MIDI, rewire applications, or
  control hardware.
- Driver buffer, device safety offset, plug-in latency, round-trip hardware
  latency, and direct-monitoring latency are separate quantities. Production
  advice that depends on performance feel or phase alignment must preserve this
  uncertainty unless the actual route is measured.

Direct TrackSmith consequence: device topology is labeled `CURRENT_STATE` only
when obtained from a trusted host/device interface or explicit user input. It is
never inferred as `MEASURED_EVIDENCE` from source-aware audio metrics. Changes to
drivers, Audio MIDI Setup, Local Control, virtual ports, clocks, or physical
connections remain manual/unsupported host operations.

## Projects, assets, transport, and global properties

### Project identity is not asset identity

- A Logic project may be a package or a folder. Audio, video, Sampler,
  Alchemy, Ultrabeat, Space Designer impulse responses, and other assets can be
  copied inside it or referenced externally. A successful project save therefore
  does not by itself prove that every dependency is portable or immutable.
- `Save As`, `Save a Copy As`, templates, alternatives, backups, autosave, and
  `Revert to` have different identity and retention behavior. Alternatives share
  project assets rather than cloning them; Logic retains up to ten ordinary
  save-created backups per alternative. Neither is equivalent to TrackSmith's
  capture-bound graph/snapshot ancestry.
- Project cleanup can permanently delete unused or unreferenced audio files from
  disk and can delete all alternatives' backups. Deleting a package/folder can
  also delete contained assets. Consolidation copies external assets into the
  project; moving a project does not move assets that remain externally
  referenced. These are destructive or filesystem-mutating user operations,
  never model-authorized production moves.
- MIDI recordings, added loops/MIDI files, and channel-strip/plug-in parameter
  state are stored in the project, while some audio/sample/IR/video dependencies
  may remain external. A committed AU graph surviving save/reload is evidence for
  AU state persistence, not evidence that every source dependency is embedded.

### Open/save and loading behavior

- Logic can keep multiple projects open and allows transfer between them. The
  active project and target runtime must therefore be explicit; window focus or
  most-recent ordering is insufficient identity.
- With dynamic loading enabled, Logic initially loads only plug-ins needed by the
  playback signal flow and loads others on demand. An undiscovered or unloaded
  instance is not proof that the project does not contain it.
- Projects saved by a newer Logic version are not backward-compatible with older
  versions. Opening an older project may convert it. Historical 11.2.2 and 12.3
  host evidence must remain versioned rather than being rewritten as one generic
  “Logic compatible” claim.
- `Close Project without Saving` suppresses the save prompt. Reorganize Memory
  can inspect/repair project structure, and Logic may report corruption. These
  recovery actions remain manual and cannot be substituted for TrackSmith state
  validation.

### Transport, selection, cycle, and chase

- Playback start can be determined by playhead, cycle locators, marquee,
  selection, marker, last locate position, visible window edge, or a configured
  Play shortcut-menu action. The Space bar can target a browser/editor preview
  instead of the project when that area has key focus.
- Auto Set Locators can follow marquee, region, note, marker, or chord selection.
  A skip cycle omits a passage. Consequently, an audible capture's temporal scope
  cannot be inferred from yellow locator state, selected track, or playhead alone.
- Flashback Capture reconstructs recent performance without prior record mode;
  this is a Logic recording facility distinct from TrackSmith's bounded recent
  AU capture.
- Chase Events reconstructs selected MIDI state when playback begins midstream,
  but chasing a sampler loop trigger can restart the sample from its beginning
  and become unsynchronized. Chase behavior, sustain, pitch bend, controller
  reset, and stuck-note panic are MIDI performance state, not audio-effect
  parameters.
- Logic Remote can control playback, recording, patches, plug-ins, mixing, and
  automation. Its documented existence does not give TrackSmith remote-control
  authority.

### Global musical and technical properties

- Project tempo is global and spans 5-990 BPM; tempo automation, tap tempo, and
  tempo lists/tracks can make it time-varying. The project key can affect Apple
  Loops and some MIDI playback depending on Pitch Source, whereas a displayed
  enharmonic key change may affect notation only. Time signature changes the
  musical grid rather than recorded audio playback.
- Project sample rate affects audio-device configuration, processing cost,
  imported-file conversion, playback, and bounce. Changing it after audio is
  added can create mismatches. Copy/Convert may replace a project file reference;
  it is not an advisory-only audition.
- Apple says higher sample rates “generally” provide higher fidelity and says
  nothing is lost when Logic performs real-time conversion for unsupported
  hardware. Those sentences do not establish perceptual transparency for every
  converter, signal, nonlinear processor, or monitoring route. TrackSmith treats
  conversion quality as implementation- and context-dependent and validates its
  own DSP at the actual render sample rate.
- Project start/end, SMPTE view offset, frame rate, division, master volume, and
  locator positions are separate global/display/playback states. Master Volume
  changes the master channel strip and mix level, not merely monitor loudness.

### Cross-project import is broad mutation

- Track import can add or replace content and independently import cells,
  plug-ins and insertion order, sends plus destination channel strips, I/O,
  automation, notes, and take folders. Bus-number remapping can avoid conflicts;
  importing a software-instrument I/O assignment does not import the instrument
  itself.
- Project-settings import can replace/import screensets, transform/lane/score
  sets, synchronization, metronome, recording, tuning, audio, MIDI, movie, and
  asset settings. Imported names, notes, and metadata are untrusted. This whole
  workflow is outside a plain AU and must not be hallucinated as a TrackSmith
  capability.

Direct TrackSmith consequence: a request can mention Logic-native project
operations, but the typed capability validator must label them unsupported and
must not convert them into AU commands. Capture/runtime identity, committed graph
identity, conversation ancestry, project/alternative identity, and source-file
hash remain separately validated.

## Tracks, patches, stacks, articulations, and derived audio

### Track, region, and channel-strip relationships

- Audio, software-instrument, external-MIDI, and folder tracks have different
  content and routing semantics. An instrument track can contain MIDI, pattern,
  and Session Player regions simultaneously; its Default Region Type only
  chooses default creation/editor behavior.
- Creating a track normally creates a channel strip, but multiple tracks can
  share one existing channel strip or one multitimbral instrument. `New Track
  for Selected Regions` moves regions while retaining the shared strip; copying
  a track can copy regions and automation while still sharing the same strip.
  “Duplicate the track” is therefore ambiguous without content/channel identity.
- Reassigning one track with Option can globally reassign every track that
  shared the original strip. `Not Assigned` suppresses data; a folder-assigned
  track plays folder regions rather than normal regions. Focused-track identity
  remains material when shared strips record or receive edits.
- Selecting a track can select all of its regions, or only cycle-overlapping
  regions, unless the preference/Option gesture prevents it. A multiple
  selection also has one focused track, and Library operations may affect only
  that focused track.
- Renaming a still-default-named track can also rename default-named regions and
  their source audio files. User-facing labels cannot be treated as immutable
  source identity.

### Creation by drag is sometimes a render

- Dragging an audio file, region, or loop below tracks can simply create a
  corresponding track. Dragging content into Quick Sampler, Sample Alchemy,
  Sampler, or Drum Machine Designer zones creates a sample instrument and may
  analyze, slice, tune, normalize, crop silence, detect notes, or map samples.
- Critically, dragging an audio or MIDI *region* into a sample-instrument zone
  first bounces the region through its effective path: MIDI effects,
  instrument, audio effects, and, for audio tracks, processing such as Flex.
  Dragging the underlying audio file does not perform that bounce. TrackSmith
  must distinguish source file, region playback, and rendered result.
- Dropping content on an existing sample-instrument header can replace a Quick
  Sampler/Sample Alchemy sample or add material to Sampler/Drum Machine
  Designer. This is instrument-state mutation, not a reversible preview by
  default.

### Mute, solo, off, protect, freeze, hide, and delete are not synonyms

- Track Mute mutes the shared channel strip, so every track using it is silenced,
  while its plug-ins keep processing. Turning a track off silences that track and
  deactivates/reloads plug-ins; Apple says the operation can take time and cannot
  be automated. Option-Off can leave shared plug-ins loaded. A turned-off
  software-instrument track can still sound live MIDI input.
- Track Solo, selection-driven channel-strip solo, region solo, solo lock, and
  preview solo have different state models. Clear/Recall Solo can reinstate the
  previous set.
- Track pan on mono positions one source; stereo Balance changes relative left
  and right levels and is not true stereo panning. The same header control can be
  reassigned to a send. Surround replaces it with a Surround Panner.
- Protect blocks recording/region edits/new regions but is not TrackSmith node
  locking. Hide changes views only. Delete removes the track and all its regions.
  Swipe gestures can change controls across many tracks.
- Freeze renders a 32-bit-float playback file including automation; Source Only
  excludes audio effects, while Pre Fader includes effects. The original track is
  temporarily inactive and content cannot be edited until unfreezing. Freeze is
  not available for multi-output instruments and is not the same identity or
  rollback model as Bounce in Place.

### Track alternatives, patches, and performance mapping

- Track alternatives vary regions/arrangements but share one channel strip and
  plug-ins. One is active, but an inactive alternative can temporarily replace
  the audible active one; deleting inactive alternatives removes their regions.
  They are not independent processing snapshots.
- A patch may include instrument, audio/MIDI effects, multiple channel strips,
  sends, aux routing, Smart Controls, and controller metadata. A plug-in preset
  and channel-strip setting are narrower. Patch merging can selectively replace
  MIDI effects, instrument, audio effects, and sends; ordinary patch selection
  replaces all selected classes. Revert discards edits, and deleting a user patch
  is irreversible across projects.
- Percussion performance patches use velocity splits, note-on/note-off direction,
  and articulation mapping. Logic may play a live note from a sample anchor but
  play the full pre-attack sample for recorded MIDI. The same nominal note and
  patch can therefore have different live and sequenced timing.

### Folder and summing stacks are different topologies

- A folder stack is organizational and its main strip acts like a VCA; it does
  not reroute subtrack audio. A summing stack reroutes subtracks to a bus/aux so
  main-track plug-ins affect the subgroup. Its main MIDI regions can feed every
  instrument subtrack.
- Moving a track into a summing stack changes its output to the stack bus;
  removing it changes output to the main output. Routing a subtrack outside the
  stack exempts it from main controls. Nonadjacent tracks are reordered when a
  stack is made.
- Folder-to-summing conversion turns main VCA automation into aux volume
  automation. Flattening can delete the main track/aux or retain subgrouping
  depending on unity settings, processing, pan, and automation. “Put these in a
  stack” and “flatten this” are routing mutations, not cosmetic organization.

### Groove and articulation state

- Only one groove track exists. Matched tracks lose ordinary time-quantization
  availability; Apple Loops' original iteration follows it but repeated
  iterations do not. Groove matching cannot be reduced to a single global
  quantize amount.
- Articulation Sets store names/IDs, input switches, output transformations,
  MIDI channels, notation symbols, and up to three output messages. Note On,
  Note Off, velocity, controller, program, aftertouch, poly-aftertouch, and pitch
  bend can switch articulations with permanent, momentary, toggle, retrigger, or
  trigger behavior.
- Choosing an articulation in the plug-in header affects subsequent live notes,
  not previously recorded ones. Articulation IDs, keyswitch state, MIDI Remote,
  octave offset, recorded per-note articulation, and third-party output mapping
  are separate. A tone adjective cannot safely overwrite this performance state.

### Drum replacement is a hypothesis, not transcription truth

- Replace/Double Drum Track detects transients, creates a Sampler track and MIDI
  triggers, then either mutes all original regions or layers the sample. Relative
  threshold, trigger note, timing offset, and average attack determine the
  result. Transient detection errors, bleed, flams, dynamics, and sample latency
  remain listening-dependent; TrackSmith must never present generated triggers
  as ground truth.

### Bounce, Selection-Based Processing, and export

- Track/region Bounce in Place is 24-bit at project sample rate. Freeze uses
  32-bit float. Internal sources normally bounce offline; external audio/MIDI
  routes require real time, and external MIDI tracks cannot use Bounce in Place.
- Track bounce can replace a track and, after completion, lose its original
  regions, most automation, and instrument/strip state; Undo is the documented
  recovery. `And Replace All Tracks` is correspondingly broad. Region bounce can
  create one file, one per track, or one per region; replace/delete/mute/leave the
  source; include tails; render or copy volume/pan automation; and normalize.
- Selection-Based Processing has independent A/B chains, plug-in or strip
  settings, context/solo preview, optional cycling, tail behavior, four gain
  modes, marquee splitting, and new-take behavior. It can reapply the last chain
  to a new selection. This remains a Logic-native analogue rather than an API
  exposed to the TrackSmith AU.
- Track/region export can render plug-ins, multi-outputs, tails, automation,
  normalization, and tempo metadata into new files. Moving audio files used by
  regions actually relocates every selected region's referenced file, including
  external assets. Preparing MIDI export permanently applies parameters and
  quantization, expands aliases/loops, joins regions, and inserts instrument
  settings as events.

Direct TrackSmith consequence: these tools enrich explanations and manual
alternatives, but ordinary AU execution stays limited to a validated editable
DSP graph. Any plan that depends on track creation, routing, patch changes,
articulation edits, bounces, exports, file movement, or source replacement must
be rejected as unsupported host mutation rather than described as completed.

## Recording, capture, takes, and comping

### Audio recording and monitoring

- Recording format/path, project sample rate and bit depth, input assignment,
  hardware gain, Mic Mode, tuning, metronome, software monitoring, direct
  monitoring, and record enable all affect a take. Monitor level controls
  playback/monitoring, not recorded level. A captured waveform cannot disclose
  every upstream setting.
- Software monitoring passes input through the record-enabled strip and always
  adds some hardware/driver-dependent latency. Direct monitoring may be the
  timing-safe path but omits Logic insert effects. A production diagnosis must
  not equate a performer's monitoring complaint with recorded timing or tone.
- A project fade-out is temporarily deactivated during recording. The audible
  monitoring state during a take can therefore differ from ordinary playback.
- Single focused-track auto-enable and explicit multitrack record enable behave
  differently. Shared channel strips, focus, input assignments, and the
  uppermost eligible track can determine where audio is recorded.

### Cycle takes, punch, replace, and deletion

- Cycle recording can create a take folder, new tracks, or new tracks while
  muting older passes, depending on project preferences. A take folder appears
  after successive passes and is not equivalent to stacked ordinary regions.
- Quick Punch records in the background from playback start to make seamless
  entry possible and consumes additional channel capacity. Autopunch uses
  separate red punch locators, can be driven by marquee state, and records only
  record-enabled tracks. Cycle and autopunch may be combined.
- Quick Punch can replace an existing region. Audio Replace mode erases the
  covered existing material even if no new sound is performed. Deleting a region
  leaves its file in the project; deleting through Project Audio Browser sends
  the underlying file to Trash. Those actions require different confirmation.
- Record Repeat and Discard Recording explicitly delete the new recording;
  Record Toggle stops recording while playback continues. A user's “try that
  again” must not be mapped to a destructive record command by an AU assistant.

### MIDI recording state

- Musical Typing, onscreen keyboard, Touch Bar, hardware MIDI, other apps via
  Virtual In, and Internal MIDI In can all create MIDI. They carry distinct
  velocity, sustain, bend, modulation, port/channel, and timing information.
- MIDI cycle recording can create take folders, merge/overdub, or make new/muted
  tracks. Spot Erase deletes every matching note encountered under the playhead;
  Note Repeat creates repeated notes with rate, gate, velocity, controller, and
  key-remote state.
- MIDI Replace has four materially different scopes: region erase, region punch,
  content erase, and content punch. The erase variants can delete regions or
  events across the whole recording interval even when no replacement event is
  played.
- Multiple record-enabled instrument tracks depend on MIDI input port/channel
  filters. Events sent on unmatched channels can be lost. Step input inserts
  exact notes/rests with note length, velocity, triplet, dot, quantize, channel,
  chord, sustain, and playhead state; it is not an audio-analysis operation.
- Internal MIDI routing can tap MIDI-effect output, instrument input, or an
  instrument's MIDI output and optionally combine it with live input. That is a
  directed MIDI graph with source track/channel identity, not a generic “copy
  the performance” action.

### Metronome and recent-performance capture

- The Klopfgeist metronome follows the project/Smart Tempo map and has separate
  playback, recording, count-in, and pre-roll behavior. Microphone recordings can
  capture audible click bleed; its spectral/transient evidence is not proof of a
  source-intrinsic defect.
- Logic Flashback Capture is distinct from TrackSmith recent capture. MIDI can
  be retained while stopped or playing, with silence/time rules and optional
  automation capture. Audio is captured only during project playback, requires
  at least four seconds, retains at most one minute, responds to detected input
  rather than silence, and uses the last focused audio track's input/format.
- In Adapt mode, Logic Flashback Capture may change the project tempo from the
  captured performance. TrackSmith's AU capture never inherits that host-global
  authority.

### Take and comp identity

- Audio Quick Swipe Comping selects time spans across takes; MIDI take folders do
  not support Quick Swipe. Extending a comp selection normally shortens adjacent
  selections to avoid gaps, while Shift-shortening can intentionally create
  silence. Click-zone and mode state determine whether a drag comps or edits.
- A saved/duplicated comp, active take, take region, comp section, and take folder
  are distinct. Deleting a take also removes comp selections that use it;
  deleting other comps is irreversible within that folder's history.
- Cutting a folder cuts every take; moving regions between lanes maintains
  no-overlap behavior. Export copies a take/comp to a new track, whereas Move
  removes it from the folder.
- Flatten keeps only current-comp sections and deletes unused take portions.
  Flatten and Merge additionally creates a new audio file. Unpacking can share
  one channel strip, clone settings to independent strips, mute inactive items,
  or create track alternatives. Shared-strip unpack means an edit on one is
  reflected in all.
- Packing regions from different tracks into one take folder moves them to the
  topmost track and one channel strip, which may change the sound. “Comp these”
  is therefore not safe without routing and source-identity awareness.

Direct TrackSmith consequence: take/comp work remains an explicit unsupported
host-editing class. Conversational interpretation may explain the likely manual
workflow, but must clarify whether the user means performance selection or
tone/dynamics processing. The AU may process only the captured audio presented
to its instance; it cannot claim to choose, flatten, delete, or repair Logic
takes.

## Loops, media browsers, audio-file identity, and interchange

### Apple Loop behavior

- Audio, MIDI, pattern, and Session Player Apple Loops retain different editable
  representations. Dropping MIDI/pattern/Session Player loops onto an audio track
  converts them to audio; a Session Player loop can become MIDI on an instrument
  track. Conversion changes future editability.
- In an otherwise empty project, the first Apple Loop can change project tempo
  and key. Later loops generally conform to project tempo/key, with chord-track,
  region-chord, Pitch Source, and Session Player exceptions. A loop with embedded
  chords can replace/add global Chord-track material depending on the browser's
  current policy.
- Browser preview can use project, original, or specified key and project tempo.
  Auto Leveling is non-destructive but applies region gain to audio loops and
  track volume to MIDI/pattern/Session Player loops. It does not retroactively
  change placed loops. Preview level is therefore not raw-file level.
- Loop-family replacement changes the region's source choice. Repetition can be
  an inspector loop, not copied regions; repeated Apple Loop iterations have
  documented groove-track exceptions.
- Creating a user Apple Loop writes a global User Library asset and searchable
  descriptors. Loop versus one-shot controls tempo/key conformance; loop regions
  must span whole beats. Exported tempo/key changes and user-entered mood,
  instrument, genre, and name are metadata, not measured ground truth.

### Untagged and arbitrary files

- Untagged loops lack the full Apple Loop metadata contract. Logic can batch
  analyze tempo, preview at original/project tempo, and copy content or create
  folder aliases in a shared Untagged Loops library. Analysis results remain
  fallible and importing may mutate user-library state.
- The All Files Browser traverses local, home, project, and attached storage,
  searches names/comments/type/format/length/date/sample-rate/size/bit-depth, and
  imports multiple media/project formats. Filenames, comments, bookmarks,
  directory structure, and imported text are untrusted and must not enter model
  authority or cloud context by default.
- Ordinary audio import may analyze tempo, apply project tempo if classified as
  a loop, or change an empty project's tempo. Import is not guaranteed to be a
  transparent file-to-region reference operation unless Smart Tempo policy is
  known.

### Project Audio Browser and destructive file operations

- One audio file can back arbitrarily many regions. Removing a region, removing
  a file reference from the project, and moving the underlying file to Trash are
  separate operations. A file used by other projects can be broken by deletion.
- `Optimize File` is explicitly destructive and cannot be undone. It removes all
  source-file spans not covered by used regions, concatenates retained spans,
  and redefines the regions; a preservation margin is optional. It can alter an
  externally shared file while retaining the filename.
- Project Audio Browser preview can use the selected track's strip or the
  Environment Preview strip and is isolated from project playback. A browser
  audition may therefore include different processing from the timeline.
- Renaming an audio file propagates to every currently open project using it and
  renames same-drive backups. Move updates references in all open projects, which
  then need saving. Copy/Convert can change sample rate, depth, format, stereo
  conversion, and dither and optionally replace the current project reference.
- Saving regions as independent files creates derivatives. Export Region
  Information writes region metadata into the audio file and overwrites existing
  embedded region information. These are filesystem mutations beyond AU scope.

### Formats and interchange

- Logic documents integer/float PCM containers, AIFF/WAVE/BWF timestamps, CAF,
  lossy MP3/AAC, lossless ALAC, QTA layers, Apple Loops, SMF, and ADM BWF. File
  support does not mean every codec preserves identical perceptual quality or
  metadata semantics. Apple's claim that AAC is better than MP3 at a given rate
  is a broad codec heuristic, not a TrackSmith acceptance threshold.
- Opening GarageBand translates tracks, tempo/key, patches, mix/effects, and bus
  effects and then saves a Logic project; it is one-way. Final Cut XML retains
  some automation, may convert sample rates, always bounces software instruments,
  omits MIDI tracks, and can require real-time rendering.
- SMF Format 0 collapses to one track; Format 1 supports multiple tracks but
  neither represents Logic region boundaries. Opening MIDI can create a new
  project/environment, tempo/marker/copyright state, and automatically assigned
  instruments. Preparing export permanently applies parameters/quantization and
  expands aliases/loops.
- AAF carries used audio regions, timing/track references, and volume automation
  under bounded sample-rate/depth/format choices. It does not imply full Logic
  session fidelity.

Direct TrackSmith consequence: media browsing, library mutation, import,
conversion, relocation, metadata writing, project interchange, and deletion are
explicit unsupported capabilities. TrackSmith may explain them and may process
audio already delivered to its AU, but must never claim that a semantic request
changed files, loops, chord tracks, libraries, or interchange documents.

## Arrangement, regions, chords, fades, and timing

### Grid, drag, selection, and overlap state

- Snap can be Smart, bar, beat, division, tick (1/3840 beat), frame, quarter
  frame, sample, or off, and can preserve relative offsets or force absolute grid
  positions. Zoom level can silently alter Smart resolution or force temporary
  Smart behavior; Control and Control-Shift overrides depend on zoom. A pointer
  gesture is not reproducible without snap, zoom, focus, and modifier state.
- `Snap Flexed Audio Regions to First Downbeat` relies on analyzed downbeats,
  which Apple explicitly allows the user to correct. Detected beat/downbeat
  positions are hypotheses, not immutable audio facts.
- Overlap, No Overlap, X-Fade, Shuffle Left, and Shuffle Right determine whether
  moving/resizing/deleting preserves borders, shortens neighbors, crossfades, or
  ripples other regions. On one audio track, only the later overlapping region is
  audible. Visual overlap does not imply an audible sum.
- Marquee selection can split/copy/delete/move only selected spans, set cycle
  locators, create automation boundary points, and start bounded playback. If
  recording begins, it engages Autopunch, replaces marquee with punch locators,
  record-enables included tracks, and deactivates others.
- Selection commands can target all following, same-track following, locator
  contents, empty, overlapped, muted, or same-colored regions. Toolbar section
  commands may affect all locator-contained regions even when only some are
  visibly selected.

### Quantize, delay, stretch, and region timing

- Region quantization is normally non-destructive playback state. Audio requires
  Flex; a MIDI region's quantize grid begins at the region start, not necessarily
  a bar. Q-Swing, Q-Range, Q-Strength, Q-Velocity, Q-Length, and Q-Flam control
  which events move and how their timing, velocity, length, or chord spread
  follows a template.
- Classic Quantize moves events toward individual targets. Smart Quantize groups
  nearby MIDI events using a proximity/velocity-weighted reference and preserves
  relative order of notes, note-offs, bends, controllers, rolls, flams, and pedal
  events. Apple's “more natural” language is a practice heuristic; listening
  remains decisive.
- Region Delay moves playback without moving region boundaries and can compensate
  slow attacks or external instruments. Apple calls one-tick predelay potentially
  transformative; that is an engineer heuristic, not a universal timing rule.
- Option-resizing MIDI proportionally changes event timing. Option-resizing audio
  creates a new PCM file (or AIFF if the source was not PCM) and replaces the
  region. Universal, Complex, Percussive, and legacy material-specific algorithms
  are choices, not guarantees; Apple's “perfectly maintains” wording for
  percussive timing does not prove perceptual transparency.
- Region Reverse is non-destructive but unavailable with Flex active; Audio File
  Editor reverse changes the source. Slip keeps boundaries while moving available
  source content; rotate wraps content and turns audio into a two-region one-track
  folder. Session Player slip/rotate first converts to MIDI.

### Region edits and global arrangement mutation

- Cutting/copying audio makes new region references, not necessarily new audio
  files. `Halve` discards the right half; `Double` repeats content. Move can cross
  open projects, target timestamped recorded position, or align the audio-region
  anchor rather than its visible start.
- Insert Silence, Cut Section, Copy/Insert Section, Repeat Section, Shuffle, and
  Delete-and-Move can cut regions and ripple later content. Depending on selection
  and command, tempo, signatures, markers, and score symbols can also move. These
  are project-structure edits, not audio DSP.
- Looping repeats only the visible region span (including added MIDI silence),
  stops at a later region/project end, and differs from copied repetitions or MIDI
  aliases. Conversions among repetitions, loops, aliases, and real copies alter
  dependency/edit semantics.
- Splitting MIDI can keep, shorten, or duplicate notes crossing the boundary;
  splitting Session Player regions may regenerate patterns because of fill state.
  Splitting region automation inserts boundary points. Demix by channel or pitch
  creates tracks/regions and can change instrument routing.
- Joining adjacent audio normally creates a new mixdown file; compressed sources
  become AIFF. Cross-track mixdown applies track volume/pan and Clipscan; Undo may
  restore regions but leave/delete the derivative by user choice. Joining MIDI
  normalizes differing transpose, velocity, and dynamics parameters.

### Gain, normalization, aliases, and conversions

- Region Gain and marquee Gain are non-destructive playback offsets. Normalize
  Region Gain can operate globally, per track, or per region using peak dB or
  loudness LUFS targets. It is not source-file normalization and does not establish
  artistic correctness.
- MIDI aliases share parent event content but retain independent names and region
  parameters. Deleting a parent can convert aliases or leave useless orphans;
  converting to a real copy breaks the dependency. An alias identity cannot be
  treated as an independent performance until resolved.
- MIDI-to-pattern and MIDI-to-Session-Player replacement change representation.
  Audio-to-Sampler/DMD/Alchemy can slice at regions or detected transients, mute
  originals, create MIDI triggers, and retain external sample references unless
  asset settings copy them.
- Deleting newly recorded audio regions may optionally delete the underlying
  file; imported regions are treated more conservatively. Undo and Project Audio
  Browser restoration cover different cases.

### Chord authority and analysis uncertainty

- The global Chord track can drive all Session Players, while region chords can
  override it for an entire region. `Pitch Source` selects the authority without
  deleting the inactive region chords. Applying one source to another replaces
  existing chords over the affected range.
- Chords store root/type/extensions/bass/associated scale, and edits to duration
  can resize, split, or overwrite neighbors. Grouping, looping, halving/doubling
  chord rhythm, and key-relative progressions mutate generated performances.
- Adding a Session Player may create an eight-bar style-specific default
  progression when the Chord track is empty. A region longer than a selected
  progression repeats it; a shorter one truncates it.
- Logic can infer key from contiguous chords and infer chords from audio/MIDI,
  optionally only in the cycle-overlapped range, then write results to the
  Signature/Chord track. The manual gives no accuracy guarantee or confidence
  interface. TrackSmith must label any such result as host-derived analysis and
  never equate it with harmonic truth.

### Fades, stems, silence, folders, and groove templates

- Region fades/crossfades are non-destructive. Fade Out, linear crossfade,
  equal-power crossfade, and S-curve have different summing behavior; Speed Up/
  Slow Down change playback speed rather than amplitude. Automatic X-Fade is drag
  mode. Audio File Editor fades alter source audio.
- Stem Splitter creates a summing stack of estimated vocal/drum/bass/guitar/
  piano/other regions and mutes the original. It is Apple-silicon-only and does
  not prove isolated stems are artifact-free or source-accurate. Source separation
  remains outside this milestone and plain-AU authority.
- Remove Silence is amplitude-threshold segmentation with minimum gap, preattack,
  release, and zero-crossing controls. It can preserve absolute anchors and make
  new regions, but low-level breaths, room tone, reverberation, cymbal tails, and
  noise make “silence” context-dependent. The manual's gate/cleanup examples are
  workflows, not semantic guarantees.
- A folder is a nested arrangement region, unlike a folder *stack*. Moving a
  single-track folder can make contents use the host track's strip; unpacking may
  target new or existing tracks. Unlimited nesting and display-level focus make
  apparent track context incomplete.
- Groove templates depend on retained source regions and use only the first
  transient/note around a musical position. Deleting the source leaves a named
  template that does nothing. Applying a groove is a timing hypothesis, not a
  proof that two performances now share human feel.

### Region-inspector execution semantics

- Audio-region state includes mute, loop, quantize/Flex, pitch/fine tune where
  applicable, Smart Tempo/File Tempo, gain, delay, fade/speed, reverse, and
  source-type-specific controls. Changing File Tempo can make playback wrong and
  requires known original tempo.
- MIDI-region state includes mute, loop, quantize, transpose, Pitch Source,
  velocity offset, dynamics compression/expansion, gate time, Clip Length,
  score visibility, delay, and advanced groove controls. Track `No Transpose` can
  override region transpose.
- `Apply All Parameters Permanently` writes most MIDI playback transformations
  into event data and neutralizes parameters, with exceptions; channel handling
  can require user choice. It preserves the immediate audible result while
  deliberately sacrificing easy reversibility.

Direct TrackSmith consequence: natural-language requests about timing, groove,
arrangement, chords, fades, regions, silence, or stems must be separated into
supported AU processing versus unsupported Logic edits. TrackSmith may offer
manual Logic guidance with explicit state preconditions, but it cannot claim to
move, split, quantize, analyze, regenerate, normalize, or replace project regions.

## Audio Track Editor

- Audio Track Editor region operations are non-destructive views/edits over
  timeline regions; Audio File Editor operations can permanently alter the shared
  source. The similar names are a critical safety distinction.
- The lower half of a region automatically acts as Marquee except at trim corners.
  Moving or Option-copying a region across another can cut the overlapped span.
  Delete removes the region from the timeline/project but leaves the browser file.
- Joining adjacent untransposed non-loop regions may create PCM derived audio;
  compressed inputs use the configured conversion format. Snap to Zero Crossings
  reduces edit discontinuities but is not a guarantee against every click, since
  phase, multichannel crossings, processing, and tails also matter.
- Flex Time/Pitch can be edited locally even while Tracks-area Flex display is
  off; this editor also exposes Volume and Vibrato tools. Automation shown here is
  linked to actual track/region/channel-strip/Smart-Control/plug-in automation,
  and Touch/Latch/Write can write values.

Direct TrackSmith consequence: the editor is a manual nondestructive workflow
surface, not AU host authority. TrackSmith must not infer that an edit is source-
safe merely because it occurred in an audio-named editor; the exact editor and
derivative-file behavior must be known.

## Piano Roll Editor

- The editor can display one region, multiple selected regions/tracks, folder
  contents, or project-wide MIDI. Link mode and a double-click can change the
  visible parent scope; a note's displayed pitch/time alone does not establish
  its region, track, channel, articulation, or instrument.
- Pencil inherits the last edited note's length, velocity, and channel; Brush
  paints at Time Quantize rate and can replay a user-defined phrase. Snap has its
  own absolute/relative grid independent of Tracks-area Snap, with zoom-sensitive
  Smart behavior and modifier overrides.
- Snap to Scale/Scale Quantize can constrain or remap pitches but does not
  understand voice leading or musical intention. MIDI velocity often affects
  amplitude, but can instead control cutoff, resonance, articulation, layers, or
  other synthesis parameters; it must not be reported as measured loudness.
- Moving notes can optionally carry associated bend/modulation/aftertouch data.
  Copy/Move MIDI Events supports merge, replace, insert, rotate, direct swap, and
  remove, and can ripple or erase destination/source events. It is much broader
  than clipboard copy.
- Note resize can preserve relative differences, force common end/length, remove
  overlaps with exact gaps, or create legato/overlap. Converting sustain pedal to
  note lengths consumes and deletes CC64 events, sacrificing later pedal editing.
- Time Quantize is non-destructive playback state; pitch quantize maps notes to a
  chosen scale. Per-note articulation, SMPTE lock, note mute, channel, and color
  are separate state. SMPTE lock preserves absolute time across tempo changes.
- Duplicate-event deletion treats same-position/pitch events as duplicates even
  when velocity, aftertouch, or controller values differ, but keeps separate MIDI
  channels. Quantization can cause events to count as simultaneous. “Clean up
  doubles” can therefore erase musically distinct data.
- Time Handles scale selected timing around either boundary and can reverse event
  order with Shift. Chord-top/bottom selection and channel-by-voice assignment
  are heuristics for separating voices and mutate channel data.
- The Automation/MIDI area can show track automation, region automation, or
  per-note/controller data independently of the Tracks-area lane; edits to a
  shared curve propagate immediately.

Documentation cautions: page 380 routes the Mac guide's bright-background step
through “Logic Pro for iPad > Settings,” likely a product-name copy error. Page
390 describes `Note End to Playhead` as trimming the *start*, another likely text
error. TrackSmith does not silently normalize either statement into host truth.

Direct TrackSmith consequence: MIDI composition/editing advice may be offered as
manual guidance, but no Piano Roll edit is executable from the TrackSmith AU.
Terms such as “harder,” “tighter,” “more human,” or “legato” must be interpreted
in instrument/articulation context, not mapped blindly to velocity, quantize, or
note length.

## Session Players

- Bass Player, Keyboard Player, and Drummer generate region-scoped performances
  from style, chords, pattern, complexity, intensity, fills, swing, feel,
  dynamics, humanize, tempo mode, follow targets, and player-specific settings.
  These inputs interact; no single control has a context-free acoustic meaning.
- New-region length/source follows a priority chain: active marquee overrides
  cycle, cycle overrides arrangement markers, arrangement markers otherwise
  create named regions, and the default is eight bars. Default chord
  progressions can be added unless disabled.
- Selecting a different *style* regenerates the chosen region but by default
  loads a track-wide instrument patch, affecting every other region's sound.
  Choosing a different player also changes the patch while existing regions keep
  their settings, which Apple warns can be undesirable. `Change Patch` and Keep
  Settings locks materially alter the result.
- Presets are region performance settings, not full instrument/track snapshots.
  Preview changes cycle and solo state. Fill and swing locks survive some
  preset/style changes; user presets can be deleted.
- Regenerate creates a different performance with unchanged visible settings,
  most noticeably at high complexity/fill settings. The manual does not expose a
  random seed, so reproducibility requires storing the generated region/MIDI,
  not merely the controls.

### Performance-specific semantics

- Keyboard left/right hands are coupled: muting one changes how the other voices.
  Hand ranges, bass/root patterns, common-tone/fixed-inversion/full/stacked
  voicings, movement, grace-note probability, phrasing, arpeggio direction,
  sustain/tie behavior, note start, and note length all shape the part.
- Bass uses melody/chord-tone policy, octave probability, phrasing, lowest note,
  muting, dead notes, pickup hits, slides, double stops, blue notes, root
  alignment, and style-specific techniques. Mute Offset does nothing when Studio
  Bass Mute is zero. Slide can be encoded as Studio Bass events/articulations,
  pitch bend, or overlapping mono-legato notes; they are not interchangeable.
- Synth Players use Alchemy by default but can drive other instruments. Their LFO
  can target MIDI CC (default CC74), velocity, or length and can be beat/chord/
  region/free/random synchronized. Random rate, phrase-variation probabilities,
  and regeneration affect determinism.
- Synth bass adds 808 repeats/triplets, pump-envelope behavior, phrase length,
  rhythm/octave/melody variation, portamento curves, retrigger policy, MPE mono
  mode, bend range, pattern accents, and chord-response policy. “Pump” is a
  generated modulation similar to sidechain compression, not proof a compressor
  exists.
- Synth keyboard pads combine voicing, tied tones, start/length, strum, velocity,
  LFO, and a dedicated attack/hold/decay envelope with relative/fixed/clipped
  alignment modes. The audible pulse may originate in MIDI CC/envelope motion,
  not audio amplitude automation.
- Drummer has independent kit-piece patterns/mutes, brush techniques, acoustic
  articulations, electronic complexity/phrase variation, fills, and follow-rhythm
  sources. Manual patterns are sixteenth-note grids of configurable length, but
  generation still adds player behavior beyond lit steps.

### Routing and conversion boundaries

- Session Players can follow chord rhythm and one track's rhythm on a per-region
  basis. This is a generated-performance dependency, not an audio sidechain.
- Acoustic Drummer multichannel kits expose mic, room, individual strip, effect,
  and routing state. Apple explicitly requires latency compensation `All` for
  phase-coherent playback; stereo patches are recommended for low-latency live
  playing. Low Latency Monitoring can bypass/alter latency-inducing paths.
- Converting to MIDI freezes the generated notes into editable events. Converting
  to pattern makes at most four-bar pattern regions and may create several.
  Replacing edited MIDI/pattern with Session Player discards those edits. Session
  Player regions always use No Overlap.

Evidence boundary: Apple's “realistic,” “expert backing band,” “authentic,” and
“faithfully reproduce” descriptions are product/practice claims. The manual
provides no controlled listening study or comparative accuracy evidence.

Direct TrackSmith consequence: Session Player knowledge can help explain how a
musician could change a generated arrangement, but it must not be confused with
TrackSmith source-aware DSP. The ordinary AU cannot create/regenerate players,
modify chords, follow tracks, swap patches, or convert regions.

## Flex Time, Flex Pitch, and Varispeed

- Flex begins with fallible transient or pitch detection. Automatic mode maps
  inferred monophonic material to Monophonic, percussion to Slicing, and complex
  material to Polyphonic; user correction and material-aware audition remain
  necessary. Selecting Flex also changes Freeze Mode to Source Only.
- Slicing preserves slice playback speed and fills gaps with optional decay;
  Rhythmic loops/crossfades slice tails; Monophonic assumes one relatively dry
  melodic line and has transient preservation; Polyphonic is phase-vocoder based
  and processor-intensive; Tempophone deliberately exposes grain artifacts;
  Speed changes both time and pitch. Algorithm names are suitability priors, not
  guaranteed artifact-free classifications.
- Quantize-Locked groups use chosen Q-Reference tracks, commonly kick/snare, to
  align a multimiked performance. Independent correction requires temporarily
  disabling the group. Phase-coherent results depend on group membership,
  reference transients, and every microphone's shared edit topology.
- A flex-marker move compresses one adjacent span and expands the other, bounded
  by markers, tempo markers, or region edges. Crossing a marker moves that
  boundary to another transient. A single gesture can therefore alter audio on
  both sides of the apparent target.
- Upper/lower waveform zones add different sets of surrounding markers; Marquee
  and Flex tools add three or four markers. Eraser in the waveform removes
  markers, but Eraser in the header deletes the region. Reset Manual and Reset
  All differ because the latter also removes quantize-created markers.

### Flex Pitch

- Flex Pitch exposes detected note position/length, pitch curve, drift, vibrato,
  note gain, fine pitch, and formant shift. Formant processing can preserve
  unvoiced sibilants/plosives while processing voiced formants. This is useful for
  vocal production but does not make sibilance/plosive classification exact.
- The method is documented for monophonic material; chords and unpitched audio
  can be misinterpreted. Audio-to-MIDI explicitly requires correction and
  audition for inaccuracies. “Perfect pitch” is a grid target, not proof that
  tuning to it serves expressive intonation.
- Enabling Flex Pitch disables destructive Audio File Editor functions. The
  manual recommends destructive edits first or Bounce in Place after pitch work,
  which creates a derivative and changes rollback/source identity.
- Track zoom exposes a reduced pitch-bar interface. The guide repeatedly states
  a visible/edit range of `+/-0.50 cents` while also describing movement within a
  semitone; these units appear internally inconsistent (a semitone boundary is
  normally +/-50 cents). TrackSmith records the documentation issue and does not
  use it as an algorithmic constant without empirical verification.

### Varispeed

- Varispeed is project-global from -50% speed to +100%. Speed Only compensates
  master-output pitch; Speed and Pitch emulates tape; Varispeed and MIDI also
  semitone-quantizes external-MIDI transposition. Percent, resulting BPM,
  semitone/cents, and tuning-reference Hz are alternate displays of one state.
- Resulting BPM follows tempo-map changes while the normal Tempo display retains
  original values. A musician's “slow it down” may mean monitor/practice
  Varispeed, permanent timing edit, tempo-map mutation, or an audio effect and
  requires scope disambiguation.

Direct TrackSmith consequence: Flex/Pitch/Varispeed remain manual Logic
workflows. Source-aware evidence may flag timing/pitch uncertainty and suggest
appropriate algorithms, but the AU cannot move markers, tune host regions,
extract MIDI, or alter global speed. Any future pitch module must keep its own
typed confidence/failure contract and never inherit Logic's detected notes as
truth without provenance.

## Event List, Step Editor, destructive file editing, and MIDI Transform

### Event identity and filtered scope

- The Event List can show regions/folders or the event stream inside a region.
  With several regions selected it displays the last selected region (or the
  first marquee-selected region), so visible events are not a complete statement
  of selection scope. Event-type filters both hide events and protect those
  hidden types from selection/editing; filter state is therefore part of any
  reproducible edit description.
- Event fields expose position, length, status/type, channel, two data bytes,
  release velocity, articulation ID, and—where applicable—SMPTE position. Relative
  edits preserve differences among selected events unless a modifier requests an
  absolute value. A one-tick minimum and the interaction between region-relative,
  absolute, and SMPTE-locked time make “move this event” underspecified without a
  time domain.
- MIDI status families have different data semantics: note-on/off, controller,
  14-bit pitch bend, program/bank selection, channel aftertouch, polyphonic
  aftertouch, SysEx, fader, and Logic meta events are not interchangeable numeric
  lanes. Bank-selection behavior is device-manufacturer dependent; SysEx can be
  corrupted or lost by an inappropriate edit.
- Logic meta events are internal commands rather than musical performance data.
  The documented set includes sending a byte, switch-fader control, screenset
  recall, project selection, marker jump, and stopping playback. Imported MIDI,
  prior provider output, or arbitrary model text must never be allowed to create
  these as executable authority.

### Step Editor and lane-state consequences

- A Step Editor lane is a typed view over MIDI events with its own grid, delay,
  length, channel filter, first-data-byte filter, display style, and Lane Set.
  Changing a lane's grid affects newly created events, not existing ones. Lane
  Sets and vertical zoom are project state; `Automatic` and `Auto Define` can add
  lanes based on encountered events.
- Pointer, Pencil, Line, Finger, Eraser, and modifier behavior differ. Dragging
  across beams changes a run of values; the Line tool can create missing grid
  events; an unmodified Pointer gesture can change a beam value when the user
  intended only selection. Clipboard and advanced merge/swap operations can
  cross regions.
- Moving or converting a lane retains numeric values while changing event type.
  Thus a volume value moved to pan becomes a pan value, and converting a note or
  controller lane may change musical meaning without changing the displayed
  number. Optional quantization in the Convert dialog can additionally move
  events.
- Per-lane Delay offsets existing and newly inserted events; Apple presents
  controller-before-note timing as a general tip, but actual device scheduling
  and response remain hardware-dependent. SMPTE lock preserves absolute time
  through tempo changes, not musical bar/beat position.
- Hi-hat groups enforce mutual exclusion at a ruler position: inserting an event
  in one grouped lane deletes the event already present in another. This is a
  deliberate performance constraint, but it is still a deleting operation and
  depends on correct kit mapping.

### Audio File Editor is source-file authority

- The Audio File Editor operates directly on an audio file, which may be shared
  by multiple regions or projects. Its independent Preview path can use either
  the source track's channel strip or Logic's Preview channel strip, so audition
  tone is not automatically the committed arrangement path.
- Selection, region bounds, file bounds, anchor, sample-loop header, transient
  markers, and project locators are separate scopes. Adjust Tempo by Selection
  and Locators mutates the project tempo; moving the anchor changes alignment;
  writing a sample loop changes file-header metadata.
- Cut closes the gap, Delete leaves a gap, Delete and Move closes it, Paste
  inserts and shifts later data but replaces anything currently selected, Trim
  discards everything outside the selection, and Silence writes zero samples
  without changing duration. These are materially different operations despite
  sharing ordinary editing vocabulary.
- Pencil redraw, Change Gain, peak normalization, destructive fades, reverse,
  polarity inversion, DC-offset removal, and transient-marker processing alter
  the original file or its analysis metadata. Trim can delete material used by
  regions and shorten partially overlapping regions. `Revert to Backup`
  completely replaces the file and cannot itself be undone.
- Logic's transient detection is confidence-dependent. Increasing/decreasing
  detected markers changes a validity threshold; deleting a marker marks it
  invalid rather than erasing it. A fresh Detect Transients pass can overwrite
  manual marker edits. This is analysis state, not ground-truth onset identity.
- Peak normalization preserves sample-to-sample level relationships within the
  selected passage but says nothing about perceived loudness, intersample true
  peak, later EQ overshoot, or artistic balance. Apple's 3–6 dB headroom advice
  is a professional-practice rule of thumb, not a standard-derived target.
- Apple's statement that polarity inversion is useful for phase cancellation is
  directionally sound but insufficient for diagnosis: a 180-degree polarity
  flip cannot correct arbitrary frequency-dependent phase or timing error. The
  guide's suggestion concerning multiple out-of-tune/chorused signals is a
  context-dependent practice claim, not a guaranteed fix.
- Many destructive functions are unavailable for Apple Loops, surround files,
  or Flex-Pitch-active regions. Bounce in Place is frequently offered as a
  workaround, but it creates a new rendered asset and changes source identity;
  it is not a transparent permission escape hatch.

### MIDI Transform is a programmable mutation engine

- MIDI Transform separates selection conditions from operations and exposes
  four materially different modes: operate on matching events, operate and
  delete every nonmatching event, delete matching events, or copy matching
  events and transform the copies. `Operate Only` ignores selection conditions.
  A safe explanation must name both scope and mode.
- Conditions can combine relative/absolute/marquee-derived position, event
  status, channel, both data bytes, length, subposition, equality/inequality,
  ranges, and a numeric map. The map is universal and has no awareness of
  whether its values represent pitch, velocity, length, or controller data.
- Operations include type conversion, fixed/add/subtract/min/max/range, flip,
  multiply/divide/scale, random perturbation, reverse, quantize, exponential
  remapping, crescendo/relative crescendo, and map application. Converting notes
  creates paired on/off-derived events; converting those to controllers can
  therefore create two controller messages per note.
- Presets such as Humanize, Random Pitch/Velocity/Length, Double/Half Speed,
  Reverse Position/Pitch, velocity curves/limits, and length transforms encode
  broad mutations rather than universally correct production moves. Randomized
  presets have no documented exposed seed in these pages; an exact reproducible
  result must store the resulting event data rather than assume regeneration.
- User transform sets persist in projects/templates and can be imported from
  another project. Environment Transformer objects can perform related work in
  real time. Both are user/project authority outside TrackSmith's deterministic
  audio graph.

Direct TrackSmith consequence: these chapters improve explanations and manual
Logic guidance, but none authorizes the AU or a provider to edit MIDI, generate
meta/SysEx events, rewrite files, change project tempo, invoke an external sample
editor, or operate a Transform set. Any future host-editing feature would need a
typed target identity, explicit scope/mode, preflight selection report, immutable
source backup, stored result identity, and user-confirmed commit. Current
TrackSmith remains advisory-only for all of these workflows.

## Mixer, plug-ins, routing, grouping, and panning

### Channel-strip identity and signal scope

- Mixer `Single`, `Tracks`, and `All` views expose different subsets. Aux,
  output, VCA, master, Preview, inactive, hidden, multi-output, and unassigned
  channel strips may have no visible Tracks-area counterpart. Multiple Mixer
  windows can also have different view/filter/width/fader configurations. A
  visible strip list is therefore not proof of the complete signal graph.
- Audio, instrument, aux, output, VCA, master, and external-MIDI strips perform
  different functions. Deleting a strip may delete tracks and their content,
  leave tracks unassigned, affect bus destinations, or be disallowed. Selecting
  a strip can select every track sharing it; reordering a track-assigned strip
  reorders tracks, and moving a multi-output aux can irreversibly remove it from
  the instrument's displayed output group.
- Hardware-device controls such as phantom power, input type/gain, hardware
  filter, polarity, and direct monitoring appear only with compatible devices.
  They can change the recorded source upstream of TrackSmith. Phantom power in
  particular is hardware authority requiring microphone/interface knowledge,
  not an inferred production move.
- Channel format (`mono`, `stereo`, one side of stereo, surround), output
  destination, monitoring state, pre/post-fader meter mode, pan law, and project
  surround format all affect the meaning of meters and controls. The same knob
  is pan on mono, balance by default on stereo, or a surround/3D control in other
  formats.

### Levels, clipping, and panning claims

- Logic distinguishes output-strip clipping from above-0 dB internal floating-
  point level on other strips. Apple's statement that an individual strip's
  above-zero indication is not itself a problem assumes a floating-point path
  and a clean final output; it does not prove safety at nonlinear plug-ins,
  hardware I/O, fixed-point exports, true-peak reconstruction, or any downstream
  format boundary.
- Lowering a channel fader by a displayed peak excess can fix a post-fader
  output level, but it cannot repair clipping already recorded or occurring
  before the fader/in a nonlinear insert. Apple's example that a rare 0.3 dB
  output clip may be subjectively acceptable is an expert-practice anecdote that
  conflicts with standards/delivery requirements where clipping or true-peak
  exceedance is prohibited. TrackSmith retains its measured peak/nonfinite/
  true-peak gates.
- Peak meters, fader gain, perceived loudness, loudness range, crest factor, and
  gain reduction are different measurements. The strip's gain-reduction meter
  reports only the first Compressor, or otherwise an inserted Limiter/Adaptive
  Limiter; it is not total dynamic reduction across the graph.
- Apple's center/side placement recommendations are common mixing heuristics,
  not universal arrangements. Mono Pan distributes one signal; stereo Balance
  changes relative left/right output levels; Stereo Pan positions/narrows the
  two input channels and can swap them. Width, pan, balance, channel swap, and
  mono compatibility must remain separate intents and tests.
- Pan law changes center gain. Independent Send Pan and Sends on Faders can make
  the visible pan/fader temporarily control a send rather than the main path.
  Manual reproduction therefore needs active send identity and mode, not just a
  numeric pan/fader value.

### Plug-in state, order, presets, side chains, and latency

- Audio effects can occupy audio, instrument, aux, and output inserts; MIDI
  effects and instruments have narrower strip types. Moving/replacing/inserting
  an effect changes serial order. Inserting Channel/Linear Phase EQ at slot one
  can shift every existing insert and redirect automation; adding it to the next
  free slot has different sound and state consequences.
- Apple's diagram/text correctly establishes serial insert order, but saying an
  insert output is “added” to its incoming signal is not a general transfer
  rule. An insert supplies processed output to the next stage; dry/wet addition,
  latency, channel-format conversion, and nonlinearity depend on the particular
  plug-in.
- Bypass, removal, reset, Compare, per-plug-in Undo, project Undo, a saved plug-in
  setting, channel-strip setting, patch, default, and copied plug-in settings are
  distinct states. Compare toggles the project-saved setting against the current
  edit; it is not one of TrackSmith's level-matched preview identities.
- Channel-strip settings can load an entire routing/plug-in configuration, can
  paste only inserts or sends, and can be recalled as a MIDI-program-change
  performance. Preset names and program changes are untrusted control context;
  a conversational provider may describe but never trigger them.
- An external side chain controls a supporting plug-in without being that
  plug-in's ordinary processed input. Its identity may be a track, hardware
  input, bus, or an internal source, and third-party AU support varies. Sidechain
  latency is included in compensation, but the audible main/sidechain timing
  still depends on the complete route and correct reported latency.
- Logic latency compensation aligns reported playback paths by delaying other
  paths; `Audio and Software Instrument Tracks` and `All` have different scope.
  “Perfectly synchronized” is a host goal, not proof against an incorrect
  plug-in latency report, external hardware delay, live-input monitoring delay,
  Bluetooth MIDI, device buffering, or acoustic timing.
- Low Latency Monitoring may bypass the plug-in that pushes cumulative latency
  above a threshold and normally disables sends on the focused/record-enabled/
  monitored path. `Low Latency Safe` can exempt a send. It is inactive for
  bounce. Thus live monitoring, ordinary playback, and bounce can audibly use
  different graphs even when the project appears unchanged.
- AUv2 and AUv3 share ordinary Logic plug-in workflows but differ in installation
  and Plug-in Manager labeling. A hidden AU still scans and loads from an old
  project; an ignored AU does neither. Scan success is compatibility evidence,
  not proof of correct state restoration or audible behavior.

### Sends, auxes, outputs, multi-output instruments, groups, and VCA

- A direct insert is serial processing of the complete strip path. A send splits
  a signal toward a bus/aux and can coexist with the main output. `Post Pan`,
  `Post Fader`, and `Pre Fader` have different gain/pan dependencies; a send is
  not generically “parallel compression” or “wet/dry” without knowing its aux
  processing and return routing.
- Aux strips can serve as effect returns, subgroups, alternate destinations, or
  additional outputs for an instrument. Routing source outputs to one bus creates
  actual summing; a Mixer group merely links selected controls; a VCA changes
  member gains without carrying/summing their audio. A summing stack is related
  to an aux subgroup but also imposes Tracks-area hierarchy.
- Post-fader sends follow member level changes, including VCA changes; pre-fader
  sends do not. An aux subgroup and a VCA can therefore produce different effect-
  send relationships even when their headline use is “turn all drums down.”
- Multi-output instruments keep outputs 1–2 on the instrument strip and expose
  later mono/stereo outputs through aux strips created by the user. Correct drum
  or instrument advice needs the plug-in's internal output assignment plus aux
  identity; apparent strip names alone are insufficient.
- Output strips map to physical/interface destinations and allow inserts but not
  further sends. Stereo output mirroring duplicates signal to another physical
  pair. Solo-safe output behavior can exempt a path from master control. These
  are monitoring/delivery topology changes, not artistic DSP parameters.
- Mixer groups may link edit selection, phase-locked quantization, automation
  mode, volume, mute, input, pan, solo, record enable, eight sends, color, zoom,
  and hiding. Group automation writes separate data to each member; turning the
  group off later does not remove that automation. Group membership and the
  global Group Clutch are necessary context before any “change one track” action.

### Binaural, external MIDI, global labels, and untrusted names

- Binaural panning uses an HRTF approximation with angle, elevation, distance,
  stereo spread, planar/spherical geometry, Doppler, and diffuse-field
  compensation. Apple explicitly notes anatomical individuality and headphone
  suitability. Position coordinates do not guarantee a shared perceived
  location across listeners, loudspeakers, headphones, or HRTFs; listening and
  translation tests remain decisive.
- External-MIDI strips transmit controller 7 for volume, controller 10 for pan,
  device-dependent bank/program messages, and arbitrary assigned controllers.
  Project reload can resend device state. The sound-producing device and its
  current patch remain external authority; TrackSmith cannot infer a controller's
  exact acoustic effect from its number alone.
- I/O labels are device-specific Logic settings shared across projects, not
  project state. Custom plug-in names, short names, channel-strip names, I/O
  labels, and track notes can all contain user-authored text. They aid navigation
  but remain untrusted context and cannot establish a capability or routing fact
  without stable identifiers.
- Mixer/plug-in undo inclusion is configurable, and Mixer Undo history can be
  deleted. TrackSmith's capture-bound graph, snapshots, locks, and commit identity
  remain the authoritative reversible-edit record for its own processing.

Direct TrackSmith consequence: the Mixer manual supplies a rigorous vocabulary
for explaining signal flow and diagnosing why a Logic session sounds different,
but a normal AU has no authority to inspect or mutate the surrounding Mixer,
sidechain, group, automation, send, output, control-surface, or external-device
graph. TrackSmith context must distinguish known inserted-instance state from
user-reported host topology. A provider may recommend a Logic-native manual move
with uncertainty; it may never report that the move was performed.

## Track and region automation

- Track automation is anchored to project time and stays behind when regions are
  moved or copied unless an explicit move policy applies. Region automation is
  carried with a moved/copied region but is lost when that region is re-recorded.
  A track can contain both simultaneously, and conversions can target the visible
  lane or every automation parameter. “The automation for this clip” is therefore
  incomplete without the automation domain.
- Collapsed track stacks can overlay member automation. The main lane displays
  one selected parameter while additional lanes may be hidden without deleting
  their data. Muting a parameter curve, removing a visible lane, turning all
  automation Off, and deleting automation are distinct operations.
- Parameter identities include strip volume/pan/mute/solo, sends, Smart Controls,
  instrument/MIDI data, and per-insert plug-in parameters. Slot order matters;
  copying automation to an incompatible target can create orphaned automation,
  and a plug-in/slot mutation can change or redirect the association.
- Read follows existing automation, Touch returns to it after release, Latch keeps
  writing the last touched value, and Write erases prior automation as the
  playhead passes—even if the user does not move a control. Trim offsets an
  existing curve; Relative adds a second curve for volume, pan, or send level.
  Consolidation preserves playback but removes the independent relative/absolute
  edit representation.
- Contrary to a casual reading of “Read,” region automation recording can be
  enabled by default on audio or instrument regions while the track is in Read.
  The option can be applied to one track or all current/future tracks of that
  type. Automation mode alone is not a sufficient record-safety check.
- Live region-automation destination on a shared channel strip depends on which
  track is selected, whether a region is selected, and otherwise which region was
  created most recently. Live track automation can also propagate through Mixer
  groups and is written separately to each member. Focus, selection, group state,
  and domain must accompany any reproduction evidence.
- Splitting a region inserts automation boundary points. Drawing a MIDI-velocity
  line creates values at intersected notes; Pencil mode can produce curved or
  stepped sequences depending on a global setting/modifier. Marquee/region/
  selection commands can create one or two boundary points and thereby alter
  ramps beyond the obvious gesture.
- Moving or copying selected automation deletes points already present at the
  destination. Instant vertical transitions, stepped curves, curved segments,
  absolute range moves, Trim offsets, and Option-overridden saturation behavior
  produce different parameter trajectories from the same endpoints.
- `Move Automation with Regions` can be Never, Always, or Ask. Automation Snap
  is independently configured by editor, while Automation Snap Offset applies a
  positive or negative tick shift to automation on *all tracks*. These are global
  editing states with consequences far outside one AU instance.
- Delete commands range from one point to the visible parameter, every parameter
  on a selected track, orphaned data, redundant points across all regions/tracks,
  or all track automation. “Clean up automation” cannot be accepted without
  explicit deletion scope and a retained snapshot.
- The Automation Event List exposes time/value data directly. Automation Quick
  Access and control surfaces can bind a physical controller to the currently
  active parameter; changing track/focus can therefore change what one hardware
  gesture controls.
- The manual documents editor trajectory and host modes, not each plug-in's
  smoothing, modulation rate, sample accuracy, zipper-noise behavior, or audible
  response. A drawn curve is control data, not proof of a particular acoustic
  outcome. Low Latency Monitoring, bypass, inactive strips, group state, and
  plug-in availability can further prevent the nominal graph from sounding as
  displayed.

Direct TrackSmith consequence: TrackSmith may explain automation and preserve
its own deterministic node parameters, but current AU authority cannot create,
convert, delete, read, or resolve host automation lanes. A future automation
bridge would require versioned parameter IDs, track/region domain, slot and
runtime identity, mode/group/snap state, preview of affected time ranges, and an
atomic reversible transaction. Model output alone can never be that transaction.

## Smart Controls and macro mappings

- A Smart Control is a patch-saved macro, not necessarily a direct plug-in
  parameter. One screen control can drive several channel-strip, instrument,
  effect, articulation, or send-related parameters. The label derives from the
  first/top mapping and can be freely renamed, so a control named `Warmth` or
  `Punch` is not acoustic evidence and does not reveal everything it changes.
- Each mapping has independent minimum/maximum bounds, optional inversion, and
  a user-editable transfer graph that may be linear, curved, nonlinear, or
  multipoint. Reordering mappings changes which one defines the screen control's
  displayed value. A macro value cannot be translated to raw DSP values without
  the complete ordered mapping graph and target identities.
- Automatic layout/mapping asks Logic to choose mappings from the current strip.
  Copy/paste is reliable only where plug-in structures correspond. Patch,
  plug-in-order, mapping, and layout changes can therefore make superficially
  similar controls address different parameters.
- Smart Controls `Master` refers to the output channel strip's effects, not the
  Mixer master fader, because inserts cannot be placed on the latter. Send-effect
  controls expose auxes reached from the selected track. Selection and topology
  are necessary to interpret the displayed macro surface.
- Selecting `Main Track Smart Controls` for a summing-stack subtrack and touching
  a control switches focus to the stack main track. Folder and summing stack main
  tracks have different layout capabilities.
- Auto-assigned USB controllers can bind physical buttons not just to macros but
  to transport, record, cycle, marker, and other key-command functions. Learn
  mode and external assignments are host-control authority. Untrusted MIDI,
  provider output, or an AI-inferred mapping must never be allowed to engage
  assignment or send a learned command.
- Smart Control Compare toggles only mapped-parameter edits; changes to unmapped
  parameters remain. It is not a whole-patch A/B and cannot establish that two
  audible states differ only in the displayed macro.
- Turning on the Smart Controls Arpeggiator inserts a MIDI plug-in if absent;
  subsequent use bypasses it. That first action is topology mutation, not merely
  a UI toggle.
- Automation records screen-control movement rather than the underlying target
  values. It can survive replacement/removal of one mapped plug-in and then act
  through the remaining/current mappings; if all mapped plug-ins are removed the
  automation is deleted. Macro automation identity is therefore mapping-version
  dependent.

Direct TrackSmith consequence: Smart Control labels are useful as user-authored
production vocabulary but remain `CURRENT_STATE`/untrusted metadata, never
`MEASURED_EVIDENCE`. Current TrackSmith cannot inspect or operate mappings. Any
future importer must capture every target ID, order, range, graph, patch version,
and automation relationship before it may explain what one macro actually does.

## Live Loops and nonlinear performance state

- A Live Loops row shares the adjacent track's channel strip/routing, but the
  grid and Tracks area are competing playback sources: on one track a playing
  cell silences regions, and stopping the cell does not automatically reactivate
  them. Divider-column activation/pause state determines which domain is audible.
  A project-end playhead stop can leave cells playing.
- Cells and scenes can inherit or override Quantize Start. Individual trigger
  modes are Start/Stop, Momentary, and Retrigger, while `Play From` may use the
  configured start, last stop, the prior cell's position, or a hypothetical
  playhead-relative position. Queued, playing, paused, stopped, and region-active
  are distinct states.
- Smart Pickup can start a late-triggered cell immediately in musical sync by
  skipping its beginning. Quantize Loop Start can likewise skip pre-loop content,
  while `Preserve Start` may delay launch to retain it. A timing-correct launch is
  not proof that the intended attack or pickup was preserved.
- Start, loop start, loop end/length, cell end/length, loop enable, playback
  speed, reverse, and original/project-tempo following are independent. Display
  can express starts as absolute position or offset and lengths as lengths or end
  positions at several resolutions. Any reproducible “trim this loop” request
  must identify the exact marker/domain.
- Apple Loops, tagged audio, and ordinary audio take different tempo paths. For
  an untagged file Logic analyzes tempo and conforms it to project tempo; users
  can edit Smart Tempo/transients, and disabling Flex preserves original tempo.
  Automatic tempo/beat inference is fallible and can audibly time-stretch source
  material without the user changing a nominal speed control.
- Session Player cells follow cell-region chords, not the live global Chord Track
  directly. Dragging a Session Player region can copy Chord Track information
  into the cell depending on Pitch Source; converting it to MIDI freezes generated
  notes and discards the generative representation.
- Moving/copying/pasting a region or cell can create a track, copy channel-strip
  settings, replace an occupied cell, overlap/replace Tracks-area regions, or
  insert a whole scene while shifting later content. Scene focus and scene
  selection differ; some commands affect only the focused scene.
- `Extract Best Loops` requires repetition, Flex, and accurate tempo mapping. The
  guide explicitly says the algorithm seeks smooth loop transitions and may not
  follow musical structure. “Best” is an implementation ranking, not a perceptual
  or compositional truth; manual audition/correction remains decisive.
- Cell gain normalization can be peak- or LUFS-targeted and can operate globally,
  per track, or per cell, but these pages do not specify the exact loudness
  window/gating/channel behavior. It must not be cited as evidence of EBU/ITU
  conformance without a separate implementation/standards check.
- Cell recording has `Takes`, MIDI-only `Merge`, and destructive `Replace` modes;
  record length may be fixed or finalized to the next bar/beat, and Rec-End can
  play or continue into overwrite/take/merge passes. Type defaults can affect
  newly recorded cells and regions. Flatten permanently deletes all nonactive
  takes, and comp editing requires a round trip through the Tracks area.
- Recording a Live Loops performance writes played cells as Tracks-area regions
  and can write automation; Session Player cells become MIDI regions. This is a
  capture of performance decisions, not persistence of every cell/generator
  identity.
- Cell-in-place bounce has explicit source leave/mute/delete, instrument multi-
  output inclusion, effect bypass, second-loop, tail, volume/pan automation, and
  normalization choices. The rendered range can contain the initial pass plus a
  loop pass; different choices are different assets and graphs.
- Live Loops pads/scenes can be assigned to control surfaces, key commands, or
  Logic Remote, including record and region-activation functions. Learned MIDI
  messages are host authority and cannot be supplied by an untrusted model.

Direct TrackSmith consequence: Live Loops knowledge is advisory and diagnostic.
The ordinary TrackSmith AU sees its current incoming audio but cannot determine
which cell/scene/region generated it, edit cell tempo or loops, trigger playback,
record a performance, or bounce cells. Any future integration needs explicit
cell/scene/track IDs, queued/playback/activation state, all timing markers,
tempo/Flex provenance, and a user-confirmed non-destructive transition.

## Step Sequencer patterns, probability, and generated control

- Each pattern region/cell is an independent sequencer storing pattern, row,
  step, and view state. Pattern regions can generate note data on MIDI-based
  tracks or stepped parameter automation on audio tracks; pattern cells do not
  provide the audio-track automation case. A saved template omits current step
  values, while a saved pattern/loop can include them and may also bring a patch.
- Musical duration is a coupled timing system: pattern length/rate, each row's
  loop start/end and rate, each step's rate/skip/offset, playback mode, and outer
  region/cell length all contribute. Non-divisible row cycles repeat at their
  least common alignment; Ping-Pong expands a cycle; Random can be effectively
  nonperiodic; an outer region can truncate or restart a row before its cycle
  finishes. “One bar pattern” is not established by 16 visible columns.
- Note rows and automation rows share On/Off, Tie, Loop, Chance, Offset, Step
  Rate, and Skip concepts but differ in payload. Note rows add velocity, gate,
  pitch/octave, and repeats; automation rows emit parameter values. Velocity may
  control timbre or switching instead of simple loudness. Skip removes time from
  the row, unlike an inactive step, which consumes its duration.
- Row assignment may be a fixed note/kit piece, melodic pitch, chord degree,
  MIDI CC, strip control, Smart Control, or plug-in parameter. Changing the
  assignment can change row type and meaning. DMD note/octave edits transpose a
  pad sound rather than selecting another kit piece, unlike other drum
  instruments.
- Mono mode suppresses future simultaneous activations but does not repair
  already-active polyphonic steps. Live recording uses the last received note in
  a step window for Mono/Melodic input. Step recording advances after the final
  note-off but not after CC/automation events.
- Chance, Randomize (probability/relative offset/range), Wander, Shuffle, and
  Random playback introduce stochastic behavior. No exposed seed or reproducible
  random-state contract is documented in this chapter. The guide's sentence that
  a Chance step's “active state” remains until edited is ambiguous beside the
  statement that Chance determines playback on each repeat; TrackSmith must not
  infer an undocumented RNG lifecycle.
- Following project key, region chords, or the Chord Track can continuously
  reinterpret row degrees as different notes. Pattern loops may transpose to
  project key and carry region chords. Chord-analysis correctness and source
  identity therefore precede any claim about intended harmony.
- Live Pattern Recording maps incoming timing to the closest step and can capture
  velocity, synthesize gate/ties from note length, store precise offset when
  unquantized, and capture MPE. The detailed description says selecting Quantize
  removes offsets, while the later instruction says choose Quantize “to add a
  step offset”; this is internally contradictory documentation and requires a
  Logic 12.3 empirical check before automation.
- MIDI-to-pattern conversion is limited to 64 steps and represents position via
  offset and duration via tie/gate; Apple recommends short regions with events no
  closer than a sixteenth for best accuracy. Pattern-to-MIDI freezes the result.
  Conversion is therefore not guaranteed lossless for dense timing, stochastic
  conditions, recurrence, continuous/MPE detail, or sequencer edit semantics.
- Pattern/row automation can Latch a value until the next active event or Slide
  between values. Slide is host-generated interpolation, not proof of the target
  plug-in's audible smoothing. Automation values may be heard only on active
  steps depending on the target/row behavior.
- Playback conditions include Always, Recurrence, First Loop, and Last Loop;
  note repeat adds repeat count, velocity ramp/curve, and nonuniform timing
  distribution. Legato extends 100% gate by one tick to overlap the next note.
  These are musically consequential event-generation rules, not mere display.
- Copying a fixed-note row can intentionally discard its Note/Octave values,
  while a Melodic row retains them; copying an unedited-rate step inherits the
  destination's rate. Clearing current-mode values, a row, all note/automation
  row values, and the entire pattern have different destructive scope.
- Learn Add/Assign, MIDI In/Out, controller events, automatic row creation, and
  row automation bind external/control-surface messages to executable musical or
  host parameter behavior. They are user-authorized host functions, never a
  frontier model's direct action surface.

Direct TrackSmith consequence: Step Sequencer knowledge helps translate musician
language about groove, probability, repeats, swing, and evolving patterns into
clear manual Logic suggestions. TrackSmith's AU cannot read or edit patterns,
rows, chord sources, random state, or automation targets. Any future bridge must
serialize the full nested timing/generation state and validate every parameter
target; a flat note list or screenshot is insufficient provenance.

## Global tracks, markers, signatures, tempo, and beat mapping

### Global identity, markers, and arrangement mutation

- Arrangement, Movie, Tempo, Chord, Marker, Signature, and Beat Mapping tracks
  control different project-global domains. Visibility, order, height, and Single
  Global Track mode are window-specific; hidden global events remain active.
  Protect buttons reduce accidental edits but do not transfer authority to an AU.
- Markers carry bar/time position, length/end, SMPTE-lock state, color, name, and
  arbitrary rich text. Marker sets hide all but one alternative set. Marker names
  renumber by timeline order, so a displayed number is not a durable identity;
  marker text is untrusted user/imported context.
- Markers can set locators/cycle and drive navigation, and marker metadata can be
  imported from or written into audio files. File-embedded markers are metadata,
  not verified production instructions, and writing/removing them is a source-
  file mutation.
- Arrangement markers are content-connected project sections. Move/copy/swap/
  replace/split/delete affects every region, ordinary marker, and automation
  point in the section, and later sections close or make room. The first Delete
  removes underlying regions and the second removes the empty marker. Suspending
  content connection changes this behavior; it must be part of any edit proof.
- Creating arrangement markers can cause later-added default Session Player
  tracks to receive matching generated regions. Section labels and generated
  performance state are coupled but not the same identity.

### Signatures, chord-following, and Pitch Source

- Time signatures define the ruler/edit grid, metronome/transform bar logic, and
  score beaming/display; the guide states that signature changes do not directly
  change audio/MIDI playback. Key signatures affect notation and only those
  Apple Loop, MIDI, pattern, or Session Player regions whose Pitch Source permits
  it. Ordinary audio regions have no Pitch Source.
- A key-signature change can optionally transpose Chord Track chords and/or
  region chords from that point. Pitch Source independently selects Off, Key
  Signature, Region Chords, or Chord Track; older projects may retain legacy
  Project Key/Transposition Track behavior. “Change the key” therefore requires
  explicit targets and chord-transposition policy.
- Time-signature beat grouping affects beaming and can print as composite meter;
  hidden score signatures remain present as project events. Splitting a bar can
  insert temporary shorter measures before resuming the prior signature.
- Signature sets hide alternative change sets while preserving the initial time
  and key. Apple Loop `Automatic` chord behavior may write region chords into the
  global Chord Track or instead follow existing global chords depending on
  overlap and loop type. An import can mutate global harmony without changing
  raw audio/MIDI content.

### Tempo points and project-global operations

- The Tempo track/List stores discrete events plus sampled curve events. Moving
  or pasting tempo points replaces events at target positions; `Extend Left`
  replaces the previous point. Curve Snap/granularity controls actual event
  density, not merely display smoothness.
- Smoothing and weighted-average replacement seek to preserve section duration;
  constant, scale, stretch, thin, round, and random Tempo Operations have
  different invariants. Randomize Tempo has no documented seed. Dense curves add
  processing/events without necessarily producing a perceptually smoother
  result.
- The manual's “Create a constant tempo curve” instruction says to choose Create
  Tempo Curve despite separately listing a Create Constant Tempo operation. That
  appears to be a documentation copy error and requires UI verification.
- `Set Time For Last Selected Tempo Event` changes preceding selected tempo
  values so a final event lands at a video hit point. Tempo recording can accept
  external MIDI, sync, Environment tempo fader, or controller input. A tempo
  fader temporarily disables Tempo List playback while moved and uses executable
  meta event 100. None is provider authority.
- The Tempo Interpreter's Manual-sync instructions also list `Auto enable
  external sync` as an alternative, although those labels describe different
  sync behaviors. This wording is internally suspect; exact synchronization
  setup remains an empirical/manual validation item.

### Smart Tempo is inferred, editable, and mutating

- `Keep` preserves project tempo and can Flex regions to it; `Adapt` mutates the
  project tempo from recorded/imported/moved material; `Automatic` chooses based
  on a host-defined “musical tempo reference” (metronome, material in the range,
  Session Player, or cycle). Auto is an operational heuristic, not an explicit
  user intent.
- Adapt is intentionally temporary/cautionary: trimming, moving, or deleting the
  only reference region in a passage can trim, move, or delete corresponding
  project tempo events. It is mutually exclusive with Cycle behavior in the
  documented cases. `Apply Region Tempo` can move the region/downbeat and all
  other regions/automation to maintain relative positions.
- Per-region Smart Tempo Off ignores file tempo; On Flexes against it; Align Bars
  and Align Bars+Beats add progressively denser beat-marker conformance. Those
  settings combine with Flex and are not equivalent to ordinary audio
  quantization, which starts from transient peaks rather than musical-beat
  inference.
- Free Tempo Recording immediately disables metronome, solos the selected track,
  skips count-in, and then offers several project/region analysis choices. Those
  choices map to different Smart Tempo settings and may globally change tempo;
  they are not merely capture preferences.
- A Smart Tempo multitrack set downmixes selected contributing files, analyzes the
  downmix, and writes one result across every file in the set—even excluded files
  still receive the result. Inputs are assumed to share start time/performance.
  Poorly chosen contributors can contaminate every track's tempo metadata.
- Smart Tempo hints trigger a fresh analysis; beat-marker edits directly alter
  results but may be ignored/removed on the next analysis. Locked ranges protect
  approved edits. Hints, detected beats, downbeats, tempo, time signature, and
  loop status are hypotheses that require metronome/audition and manual
  correction, especially with variable/irregular material.
- Smart Tempo edits and analysis are written into audio files; MIDI analysis is
  stored in the project. Removing tempo information, setting/replacing file time
  signature, doubling/halving detected tempo, or exporting project tempo are
  metadata mutations with cross-project consequences.

### Beat Mapping preserves performance time by changing project time

- Beat Mapping connects existing audio transients or MIDI notes to musical ruler
  positions and inserts tempo events so their *absolute* time stays fixed. This
  differs from Flex/conform operations that time-stretch audio to a fixed project
  grid. Subsequent manual Tempo-track changes can defeat the mapping.
- Audio transient threshold controls which candidate peaks appear; high settings
  create rhythmically meaningless extras. Protect MIDI and Protect Flex keep
  selected event/marker domains from being remapped while the other domain drives
  tempo.
- Automatic mapping can tolerate missing/additional events or force every event.
  Apple explicitly limits the former's best case to fairly regular material and
  gives manual-downbeat/guide-MIDI fallbacks for failures. Algorithm selection,
  transient confidence, and user correction must be preserved with the result.
- File/project `Use musical grid` behavior, Follow Tempo metadata, Smart Tempo,
  Flex, region length, and loop length can interact so tempo changes cause
  overlap, muted overlap portions, or irregular loops even when original audio
  playback speed itself is unchanged. A tempo-map change is never presumed
  locally harmless.
- Apple's recommendation to leave stereo master/VCA gain at 0 dB and adjust the
  output is a workflow heuristic. Its background-noise-versus-clipping language
  does not replace TrackSmith's standards-based peak/true-peak/loudness analysis
  or monitoring-chain calibration.

Direct TrackSmith consequence: TrackSmith can analyze temporal evidence from its
captured window and discuss manual options, but cannot observe or mutate Logic's
global tracks, signatures, chord sources, tempo sets, Smart Tempo file metadata,
or beat maps. Source-aware “timing” requests must distinguish performance timing,
audio stretching, project tempo, marker/section placement, and generated harmony.
If the required domain is unavailable, TrackSmith must say so rather than promise
a tempo edit it cannot execute.

## Score Editor, notation, and MIDI/playback boundaries

### Display state is not uniformly separated from musical state

- The Score Editor has multiple display levels, score sets, Linear/Page/Wrapped
  views, Link/Catch modes, hidden regions, staff styles, voice assignments, and
  project-wide score settings. A score screenshot is therefore a selected view
  of project data, not a complete or authoritative MIDI representation.
- Graphical Layout position is distinct from event position and playback time.
  The Layout tool can move a symbol visually without moving the MIDI event, while
  the Pointer tool can change its bar position. Ordinary paste may quantize the
  first pasted item's position; `Paste at Original Position` preserves the
  source position. A visual edit and a performance edit cannot be inferred from
  the same drag gesture without tool and object identity.
- Score display quantization and MIDI Time Quantize are separate. Display
  Quantize, Interpretation, Syncopation, No Overlap, Max Dots, visual tuplets,
  user rests, ties, clefs, staff transposition, and many symbols can change
  notation while leaving the underlying performance intact. Time Quantize
  changes playback non-destructively. `Fix displayed Note Positions` can bake
  displayed positions into event data for export, so display-only state becomes
  destructive to the original timing distinction when that command is used.
- A tie represents a single MIDI event, not repeated tied notes. Independent and
  grace-note status affect notation but the notes still play. Hidden note heads,
  notes suppressed by a voice/channel display rule, hidden bar lines, hidden
  signatures, and hidden repeat symbols are not evidence that the underlying
  MIDI event or playback is absent.
- Editing a duration bar changes note length. Resetting note attributes can also
  delete attached score symbols. Adding/deleting notes, changing velocity,
  channel, duration, quantization, pedal controller data, or certain note
  attributes is musical-state mutation even when performed in a notation view.

### Symbols vary between visual, MIDI, and project-global authority

- Dynamics, crescendi/hairpins, slurs, most articulation marks, accents, trill
  signs, repeat signs, barline styles, text, lyrics, chord grids, and layout
  objects are primarily notation unless explicitly connected to MIDI behavior.
  Apple does not establish that every displayed expression symbol is rendered
  by the instrument. Their presence must not be treated as measured automation.
- Sustain-pedal symbols are an important exception: they create/edit MIDI CC64
  and affect playback. Standard region text is stored as a MIDI meta event; text,
  lyrics, track names, and imported MusicXML labels are untrusted metadata and
  never model instructions.
- Voice separation by split point can be display logic, but channel-based voice
  assignment changes MIDI channel data. `Assign MIDI Channels based on Score
  Split`, the Voice Separation tool, event-channel commands, and Auto Split can
  mutate note channels. The Track inspector may still determine playback
  channel, so display channel and audible destination are not universally the
  same thing.
- Staff/voice assignments, Explode Polyphony, cross-staff beaming, clefs,
  brackets, rest visibility, note-head shapes, colors, note names, and display
  transposition are normally visual. For mapped drum styles, pitch-to-sound
  identity comes from a mapped Environment instrument while note head, group,
  relative position, and staff-style offset determine notation. An invisible
  mapped note may still trigger its drum sound.
- The manual contradicts itself about inserted key signatures in the Score
  chapter: it first says score key-signature changes affect display only and not
  MIDI playback, then shortly says inserted signatures affect all instruments
  visually *and in MIDI playback*. The global-signature chapter conditions pitch
  behavior on region type and Pitch Source. TrackSmith must use the latter typed
  state model and treat the Score wording as unresolved until direct Logic 12.3
  tests cover ordinary MIDI, Apple Loop, pattern, and Session Player regions.
- The score-automation instructions refer to the Piano Roll Editor in a Score
  Editor procedure. This appears to be a documentation copy error and is not
  evidence that the two editors have identical automation scope.

### Staff styles, score sets, layout, and export

- Staff styles are project-saved shared definitions. Editing one affects all
  tracks/regions using it. A style can contain multiple staffs and up to 16
  voices, with clef, key display, staff spacing/size, display transposition,
  voice/rest/stem/tie/beam/head/color rules, MIDI-channel assignment, and split
  pitch. `Auto Style` is a range-based display heuristic, not instrumentation or
  orchestration analysis.
- Score sets independently select/reorder instruments, substitute printed names,
  group staffs, choose score/part layout parameters, and scale output. They are
  saved with the project and can be imported from another project. Extracted
  parts and the immutable `All Instruments` set have different scaling/name
  behavior. A score-set name or instrument label is not reliable track identity.
- Line/page breaks, local margins, page layout, score/part format, symbol fonts,
  colors, guides, global-track visibility, and instrument-name visibility are
  engraving/print state. Moving a bar with the Layout tool can recalculate and
  delete later manual line breaks unless Option is held; resetting line layout
  removes all edited breaks and margins in the current set.
- Printing/PDF and Camera-tool export reproduce Page view subject to documented
  omissions such as margins, playhead, hidden heads/bars/tuplets, and selected-
  region screen colors. They export notation, not an audio render or a complete
  machine-readable performance. MusicXML import/export also requires semantic
  verification rather than an assumption of lossless round-trip behavior.
- Apple's staff-size recommendations and statements about readable voice counts
  are engraving practice heuristics. They are useful defaults, not universal
  perceptual or accessibility standards.

Direct TrackSmith consequence: Score knowledge is an advisory/manual workflow
domain. The TrackSmith AU cannot inspect or edit Score Editor selection, staff
styles, score sets, notation symbols, MIDI channels, MusicXML, Environment drum
maps, or print state. A future host bridge would need durable region/event/style/
score-set identities and explicit operation classes (`DISPLAY_ONLY`,
`MIDI_MUTATION`, `PROJECT_GLOBAL_MUTATION`, `FILE_EXPORT`). Until then,
TrackSmith may explain exact Logic steps but must not claim that notation was
changed, infer playback from a symbol, or convert score text into provider
authority.

## Bounce, sharing, interchange, and delivery state

### A bounce is a fully specified render, not merely a filename

- Project/section bounce includes the routed, unmuted signal reaching the chosen
  output, with parameters, effects, and automation. Output-strip format selects
  mono, stereo, or surround file topology. Cycle/selection/dialog range,
  realtime/offline/automatic mode, second-cycle pass, audio tail, tempo metadata,
  normalization, file type, bit depth, sample rate, interleaved/split topology,
  dither, and destination are all part of render identity.
- Offline bounce is limited to internal audio/software-instrument sources on
  native Core Audio devices. External MIDI, live inputs, DSP hardware, I/O,
  external inserts, and some plug-ins force or require realtime. `Automatic` is
  host-selected behavior, not proof that two runs followed the same render path.
  Stateful/random instruments and effects still require explicit state capture
  before reproducibility can be claimed.
- `Bounce 2nd Cycle Pass` renders the second traversal so the first traversal's
  tail can enter its beginning. `Include Audio Tail` extends until Logic decides
  release/effect tails end; Apple warns that mastering/noise/test-oscillator
  plug-ins can prevent a useful termination. Neither option is interchangeable
  with manually extending the end range.
- `Normalize On` scans for the highest amplitude peak and applies bidirectional
  gain; `Overload Protection Only` applies downward gain above 0 dB. The guide
  does not establish BS.1770 loudness, intersample true-peak protection, or a
  mastering target. TrackSmith preview matching and delivery validation must use
  its own standards-mapped measurements rather than Logic bounce normalization.
- Tempo information can be omitted only for uncompressed bounce. Adding a file
  to the Project Audio Browser or Music library changes asset/library state but
  not the rendered samples. Bounce name/location and all derivative hashes must
  be retained separately from capture/source identity.

### Encoding, sample-rate conversion, and dither

- Uncompressed output supports AIFF/WAVE/CAF, 8-bit through 32-bit float, 11.025
  through 192 kHz, and split/interleaved topology. MP3 and M4A paths create/use a
  temporary uncompressed source and, when necessary, automatically convert
  rates above 48 kHz. CDDA converts higher rates to 44.1 kHz. Those derived
  encodes are not source-preserving masters.
- MP3 is lossy and stereo-only; AAC is lossy while Apple Lossless is lossless.
  Bitrate, VBR, encoder quality, `best encoding`, sub-10 Hz filtering, joint/
  normal stereo, and tags change either coded audio or metadata. Apple's claims
  that improvements above 96 kb/s mono or 192 kb/s stereo are nominal, that
  sub-10 Hz is inaudible, and that filtering it improves perceived quality are
  context-dependent product guidance, not universal psychoacoustic findings.
- Apple states compressed encoding occurs before the selected output dither.
  Dither choices are None, POWr #1/#2/#3, and UV22HR, and the manual correctly
  warns against repeated dithering. Material-dependent audition remains
  decisive. The section incorrectly labels bit-depth reduction as
  “downsampling”; sample-rate conversion and word-length reduction are different
  operations. Its dynamic-range-extension and “best possible” claims do not
  expose transfer functions or conformance evidence and must not become
  TrackSmith standards claims.
- Dither is relevant when reducing fixed-point word length, not a generic
  enhancer. TrackSmith must preserve source/output bit depth, prior dither/noise-
  shaping uncertainty, codec, sample-rate conversion, and number of renders.

### Bounce in place, freeze, sharing, and interchange have different loss scopes

- Freeze can preserve playback of unavailable Audio Units; pre-fader freeze
  includes effects. Track-in-place bounce can replace/create a track, optionally
  include multi-output auxes as one or additional files, render or copy volume/
  pan automation, include/bypass plug-ins, and normalize. After the documented
  operation, original regions and most automation are lost and the original
  strip is reset; host Undo is the recovery path. This is destructive project
  mutation even when the source audio file remains on disk.
- Sharing a package can include its contained assets; sharing a folder may send
  only the project file. GarageBand for iOS receives a reference mix plus future
  returned tracks rather than an editable clone of every Logic object. Logic for
  iPad has explicit incompatibilities including surround/Spatial Audio,
  binaural panning, folder-organized projects, rates above 96 kHz, time rulers,
  non-1 1 1 1 starts, arrange folders, external MIDI, and unassigned tracks.
  Missing plug-ins may require freeze/bounce, and some Mac plug-ins are playback-
  only on iPad.
- AirDrop, Mail/Mail Drop, Music, Voice Memos, iCloud, GarageBand, and iPad share
  operations disclose files externally and may require network/account consent.
  Metadata fields and imported layered memo names are untrusted. They are never
  provider authority and cannot be initiated silently by TrackSmith.
- AAF includes used audio regions, track/time references, and volume automation
  at selected format/rate/depth/dither; that list is not a promise of complete
  Logic graph, plug-in, pan, bus, instrument, or project-state interchange.
  Final Cut XML supports volume/stereo-pan automation, bounces software
  instruments, and ignores MIDI tracks. MusicXML addresses notation and is not a
  lossless audio/MIDI/project exchange guarantee.
- Spatial export offers ADM BWF, Dolby Digital Plus with Atmos, or AC-4 L4 and
  can derive its range from project, cycle, marquee, or selected regions. Its
  actual renderer/object/bed and metadata requirements are covered by the
  dedicated Spatial Audio chapter rather than inferred from this summary page.

Direct TrackSmith consequence: TrackSmith's current commit remains an editable
deterministic AU graph, not a host bounce/share/export command. It may validate
captured/offline previews and explain a precise manual export recipe, but it must
not claim that Logic rendered, froze, consolidated, transmitted, or converted a
project. Future render evidence needs an immutable manifest containing project/
output identity, exact range, realtime/offline path, graph and stochastic state,
tail policy, format/rate/depth/channel topology, SRC/codec/dither/normalization,
destination hash, and external-device participation.

## Surround, Spatial Audio, and Dolby Atmos

### Channel topology, routing, and project conversion

- Logic distinguishes stereo, channel-based surround, and object-based Spatial
  Audio with Dolby Atmos. The selected project surround format, channel-strip
  input/output mode, plug-in format at each insert, I/O assignment, meter channel
  order, physical speaker routing, monitoring renderer, and bounce/export format
  are independent state. A meter with unlabeled bars cannot establish channel
  identity without the View setting, and that setting does not control metering
  plug-ins.
- Setting any strip output to Surround converts a stereo project to surround:
  the master becomes a surround master, its multichannel inserts activate,
  stereo-output inserts become inactive but are retained, and individual output
  strips may hide. Returning to stereo can reactivate the earlier output chain.
  Format conversion is therefore a project/graph transition, not a reversible
  pan-knob substitution unless all dormant state is captured.
- Empty audio strips adopt the first file's format; instruments adopt their
  instantiated output; auxes adopt the input until overridden. Logic can
  automatically upmix/downmix mismatched file, strip, aux, and plug-in formats.
  Option-inserting a mismatched plug-in can produce a downmix-process-upmix path
  (for example 5.1 to quad and back). That hidden conversion is audible graph
  state and must be represented in any parity claim.
- Surround files are interleaved on recording/import conversion. Split-bounce
  suffixes identify/import channel assignments but changing a suffix does not
  change samples. Channel identifiers, file order, project format, and I/O
  assignment all remain necessary provenance.
- A Spatial project supports 5.1, 7.1, or 7.1.2 beds; the renderer can monitor up
  to 7.1.4. Logic recommends native 48 or 96 kHz; 44.1/88.2 material is converted
  in real time. Creating/converting a project also sets 24 fps and defaults to a
  7.1.2 bed. Changing sample rate after recording or changing surround format can
  alter playback and plug-in channel modes, so Apple explicitly recommends a
  copy/alternative before converting a finished mix.

### Beds, objects, panners, and automation

- Bed tracks route mono/stereo/surround audio through one shared channel-based
  bed and the Surround Panner/Balancer. Bed audio reaches pre-Atmos surround-
  master inserts. Object tracks are mono/stereo only, consume one/two of up to
  118 object inputs, send audio directly to the Dolby Atmos plug-in, and send XYZ
  panning as separate metadata; they bypass pre-Atmos master inserts and cannot
  directly address LFE.
- The mono/stereo Surround Panner distributes a signal by Angle, Diversity,
  Elevation, Spread, Center/LFE offsets, enabled speaker set, and optional front/
  rear and left/right Separation. `Planar` center maximizes diversity and may feed
  height speakers even at 0 elevation; `Spherical` center moves to 90-degree
  elevation and feeds height only. Those modes are different routing algorithms,
  not visual skins. Stereo negative Spread swaps left/right; zero folds to mono.
- A Surround Balancer does not cross-pan a multichannel source; it changes the
  relative output-channel levels with Angle/Amount. Turning off a Panner speaker
  redistributes signal among remaining channels and changes effective topology;
  turning one off in Balancer merely mutes that source channel.
- The 3D Object Panner creates normalized left/right, back/front, elevation,
  Size, and stereo Spread metadata. Size is described perceptually as making the
  image more diffuse; Apple does not publish the renderer transfer function.
  Every parameter can be automated. An object subgroup requires routing sources
  through an aux and making the aux an object; an LFE feed requires a separate
  bed aux, filtering, panner speaker disabling, and gain control.
- Panner presets and `Save As Default` can silently change the starting state of
  future tracks. Object/bed names and viewer spheres are UI identity, not durable
  object IDs. Object automation and audio must remain paired across import,
  snapshot, and export.

### Multichannel plug-ins and linked detection

- Plug-in format is determined at each insert point and may be mono, stereo,
  mono-to-stereo/surround, native multichannel, dual mono, or multi-mono.
  Multi-mono instantiates separate processors for channel pairs/singles. Groups
  A-E can copy/link parameter state; adding a channel adopts group values and
  mass assignment inherits the front-left values. `Couple` only propagates the
  parameters changed while active.
- Multi-mono bypass is group-scoped. A side-chain-capable grouped plug-in shares
  linked detection across the group, even without an external side chain, to
  avoid spatial-image deformation. Independent channel processing, linked
  parameter editing, and linked detection are separate dimensions and must not
  be flattened into a single `linked` flag.
- Native surround availability varies by plug-in and maximum format. An Audio
  Unit *may* support surround, but its actual declared formats and behavior must
  be validated. The guide's automatic “best use” configuration is host policy,
  not evidence that it is artistically appropriate.

### Dolby renderer, monitoring, and deliverables

- The Dolby Atmos plug-in is created only through Spatial project settings and
  is not an ordinary insert-menu effect. It accepts the bed plus object audio/
  metadata, renders a selected channel-based monitoring path, stores per-bed/
  object Dolby binaural Near/Mid/Far/Off mode, and stores downmix/trim metadata.
  Dolby binaural modes do not affect Apple Renderer monitoring; Apple head
  tracking/personalized profiles/music/movie modes affect playback only and do
  not change ADM export.
- Monitoring is hardware-dependent: Dolby binaural, Apple binaural, personalized
  HRTF, head tracking, built-in/display speaker virtualization, and dedicated
  2.0/5.1/7.1/height layouts are different renderers or configurations. Binaural
  perception is listener/HRTF/headphone dependent, and speaker virtualization is
  not proof of translation to a calibrated room.
- Downmix selection includes direct rendering, Lo/Ro, Dolby Pro Logic variants,
  surround/height trims, and front/back balance. The manual prints coefficient
  expressions using dB values as if multiplied directly and uses signed terms in
  the Lt/Rt matrix; implementation requires conversion of dB gains to linear
  amplitude and verification against the controlling Dolby specification rather
  than literal transcription from the prose equations.
- ADM BWF export keeps the bed, mono/split-stereo objects, object pan automation,
  and required downmix/trim metadata; monitoring-format selection does not affect
  it. Import merges all original bed tracks to one bed track, splits stereo
  objects, applies object automation, resets track faders to unity, and retains
  only the Dolby plug-in on the master. It is not a lossless Logic-project round
  trip.
- Bounce renders the *selected monitoring format* to a conventional channel-
  based file; that bounce cannot be used as the Atmos delivery master. ADM is
  uncompressed object-based delivery; Dolby Digital Plus/AC-4 MP4s are encoded
  quality-control/delivery simulations with profile-specific contents. Dolby
  Digital Plus ignores binaural render modes.
- Pre-Atmos master inserts affect only the bed and are included in ADM; object
  tracks bypass them. Post-Atmos inserts affect monitoring/channel-based bounce
  but not ADM export. Apple recommends metering only after Atmos except for a
  temporary channel-based master. A seemingly global limiter before Atmos can
  therefore change bed/object balance rather than limit the full mix.
- The guide contradicts itself about the post-Atmos channel format. Page 999 says
  it is always 7.1.4 even when a smaller/binaural monitoring format is selected;
  pages 1001-1002 say the monitoring choice changes the downstream Level Meter's
  channel mode. TrackSmith must not settle this from prose; a Logic 12.3 format-
  negotiation probe is required.
- Apple gives `-1 dBTP` per rendered channel and `-18 LUFS` integrated measured
  with 5.1 monitoring as Atmos mix guidance. These are source-/delivery-specific
  targets, not universal mastering limits and not, by themselves, proof that an
  ADM passes a platform's current delivery checks. The exact Dolby/Apple Music
  specification/version and conformance method must be attached before TrackSmith
  calls a master compliant.

### Surround-production guidance and manual errors

- The chapter lists channel layouts and describes 5.1 geometry, equal arrival
  time/level calibration, surround placement, and overhead/LFE practice. Room,
  monitor directivity, bass management, decoder, calibration level, target
  market, and standards version materially affect translation. Statements such
  as 7.1.4 being recommended, a 120 Hz LFE low-pass being standard for “most”
  applications, and genre-specific downmix trims are professional-practice
  guidance, not universal acoustic truth.
- The statement that bass frequencies “travel much slower than higher
  frequencies” is false for ordinary audio propagation in air and must not inform
  delay alignment. Low-frequency localization and room modes are real, but they
  have different physical causes.
- The claim that DTS generally sounds better solely because of a stated 3:1 vs
  12:1 compression ratio is an oversimplified, codec/version/material-dependent
  assertion. The guide also alternates between `Low Frequency Enhancement` and
  the conventional `Low Frequency Effects`; terminology is not algorithm proof.
- QTA Spatial Playback (macOS Tahoe 26 minimum) decodes four-channel first-order
  ambisonic recordings to mono/stereo/surround and offers voice isolation/
  ambience removal modes. Apple's words “higher quality” and “completely remove”
  are product claims without error/separation metrics. QTA import/processing is a
  special host workflow and outside TrackSmith's ordinary AU access.

Direct TrackSmith consequence: current TrackSmith processing is mono/stereo and
must reject unsupported surround/object graphs instead of silently downmixing.
It can identify a captured channel configuration only when trusted format
metadata accompanies the samples, and it cannot infer bed/object identity,
renderer, panner automation, speaker calibration, or ADM compliance from a
stereo capture. Spatial advice remains manual/advisory until explicit typed
multichannel buffers, renderer topology, object IDs/metadata, format negotiation,
offline parity, and dedicated conformance/listening lanes exist.

## Video, absolute time, and synchronization authority

- A project can reference one QuickTime movie, display it in a window/global
  track, and chase between movie and Logic playheads. Movie audio is audible only
  while the Movie inspector/window is open. Logic does not edit video imagery,
  but can import embedded audio, replace/export the soundtrack, or export a
  cycle-delimited shortened movie. Removing the movie removes project references;
  scene markers can be kept or removed separately.
- Automatic scene markers use an undocumented fixed cut-detection threshold and
  choose scope by marquee, cycle, selected regions, then all. Apple's claim that
  it works well for most movie types is not benchmark evidence. Scene markers are
  SMPTE-locked absolute-time hypotheses and need visual review before becoming
  hit points.
- Movie audio import creates Project Audio Browser assets/tracks and mutes the
  embedded playback. The manual's sentence that the selected audio tracks are
  “bounced” while describing movie-track extraction is ambiguous and requires a
  file-level import probe. Export-to-movie can replace the soundtrack in a newly
  saved movie and choose which original movie tracks survive; it is an external
  file mutation with explicit format/rate/depth and consent requirements.
- The assertion that QuickTime video is embedded with internal SMPTE timecode is
  too broad: container/timecode-track presence must be inspected per file. Movie
  filenames, track labels, and embedded metadata are untrusted context.

### Musical time, absolute time, and locks

- Bars/beats and absolute SMPTE time are different coordinate systems. Tempo
  changes move unlocked musical events in absolute time. SMPTE-locking a region
  locks all its events; copied/Option-dragged locked items lose locked status.
  Unlock fixes the item at its current bar position, after which later tempo
  changes move its absolute time.
- `Pickup Clock` moves an event/region to the playhead, but for audio it aligns
  the region *anchor*, not necessarily the visible region start. Positioning a
  bar at an absolute time mutates the preceding tempo so the target event lands
  at that time. Neither action is a local audio-processing edit.
- A frame rate, drop/non-drop interpretation, project start, movie timecode,
  event SMPTE lock, tempo map, and audio region anchor must all accompany any
  claim of picture synchronization.

### Clock, timecode, transport, and network sync are separate

- Logic supports receiving/transmitting MTC, sending MIDI Clock (not receiving
  it), word-clock-driven audio timing, MMC transport/record commands, Ableton
  Link, Tempo Interpreter/manual sync, and Auto Sync. One timecode/transport
  transmitter is required, but sample clock, musical tempo/phase, absolute
  timecode, and machine control are different layers and may have different
  authorities.
- MTC cannot fully encode all source frame-rate distinctions. Logic maps 23.976
  to 24, 30 drop to 29.97 drop, and 30 non-drop to 29.97 unless manually
  overridden. All device/project rates must be verified; automatic detection is
  not authoritative when a synchronizer encodes the wrong rate.
- Ableton Link discovers peers on a local/ad-hoc network. Any participant can
  change session tempo, which overrides/deactivates Logic Tempo-track automation
  and Smart Tempo until the track is reactivated; reactivating then publishes
  Logic's tempo to peers. This is shared network/project authority, not a benign
  monitoring mode and never provider-controlled behavior.
- MMC can locate, play, arm up to 64 external recorder tracks, punch, record, and
  stop hardware. A special MMC track icon changes track behavior; selection can
  alter the external machine's record-ready state. Stopping creates empty MIDI
  regions as take indicators, which are not recorded audio. External machines
  may disagree with Logic's displayed record state if command sequences are not
  completed as documented.
- Word-clock failure, missing clock during stop, different playback vs recording
  sync conditions, frame-rate mismatch, and unsupported audio-sync modes can all
  cause drift or failure. The guide's troubleshooting suggestions are starting
  heuristics, not proof of root cause.

Direct TrackSmith consequence: TrackSmith's AU may analyze audio aligned to its
captured sample timeline, but cannot see movie frames/timecode tracks, region
anchors/SMPTE locks, project frame rate, external clock health, Link peers, or MMC
hardware state. It must not claim frame accuracy, place cues, change tempo for a
hit point, arm hardware, transmit transport, join a Link network, or export a
movie. Future picture workflows need trusted frame/timecode metadata, explicit
clock-domain and transport authority, immutable source/output hashes, and direct
host/external-device validation.

## Application settings, project settings, commands, and pointer state

### Settings are layered mutable state

- Application settings apply across projects and are persisted on quit;
  project settings are saved/importable with each project; some apparently local
  controls write application preferences. Templates can make project defaults
  appear global. A reproducible Logic workflow therefore needs the effective
  value and scope, not just the visible project file.
- Reset-all-settings also resets the control bar, toolbar, inspector/channel-
  strip components, track-header defaults, and New Tracks details while retaining
  key commands. Deleting preference/control-surface files creates defaults on
  next launch. Reset warning state changes which consent/destructive dialogs can
  appear. None is a harmless diagnostic action.
- Application analytics can be linked to an Apple Account/Creator Studio
  identifier and iCloud Keychain devices. Sound Library location may be local,
  removable, shared, or networked; a missing library can cause a new empty bundle
  to be created. Asset/path/analytics settings are privacy and availability state,
  not production semantics.
- Selection coupling, right-click mode, click zones, one-direction dragging,
  Force Touch, editor-on-double-click, Catch/Link, and warning suppression alter
  the result of the same pointer gesture. Force Touch can create/delete notes or
  regions and automation points. A UI recipe without these settings is not exact.

### Audio engine, monitoring, latency, and realtime behavior

- Core Audio enablement, input/output devices, microphone permission, macOS Mic
  Mode, I/O buffer, recording delay, processing threads/buffer, multithreading,
  summing precision, sample-accurate automation, software/hardware monitoring,
  focused-track monitoring, independent monitor level, pan law, and latency
  compensation all affect heard/recorded behavior in different places.
- macOS Voice Isolation can process interface channels 1-2 before Logic and Apple
  warns it can degrade recording quality. Input/output device choices are stored
  with the project but device availability and clock topology are external.
  TrackSmith cannot infer an upstream OS transform or device route from project
  graph state alone.
- I/O buffer governs live round-trip latency/CPU pressure; process buffer governs
  non-live lookahead computation; each live track plus its dependent signal path
  is constrained to a processing thread. Changing the I/O buffer can reload
  plug-ins. `Automatic` threads and displayed resulting latency are host estimates,
  not proof of measured acoustic or external-loop latency.
- 64-bit summing changes Mixer buffer precision, but the guide's claim that it
  necessarily produces “better-sounding” results is a product assertion without
  audibility conditions. TrackSmith may describe numerical precision, not promise
  a perceptual improvement.
- Sample-accurate automation can cover volume/pan/sends or plug-in parameters,
  but Apple explicitly says not all Audio Units support it. Plug-in delay
  compensation may be Off, tracks only, or All; playback pre-roll can prevent a
  start-position transient from being missed. Reported plug-in latency remains
  dependent on correct plug-in reporting.
- Low Latency Monitoring is application-global across open projects until quit;
  it can bypass latency-heavy plug-ins and disable sends beyond a configurable
  limit, with selected sends marked safe. It is inactive during bounce. Thus the
  performer can hear a materially different graph from normal playback/bounce.
  Any listening or host evidence must record this state.

### Recording, file, sampler, and automation defaults

- Audio File Editor warning/undo/normalize history are independently configurable
  and can be cleared on close. An external sample editor expands destructive file
  authority outside Logic. TrackSmith snapshots cannot rely on that undo ledger.
- Recording file type/depth applies only to future files. The manual's 16-/24-bit
  dynamic-range figures are approximate theoretical quantization ranges. Its
  claim that 32-bit-float recording can always recover digital clipping is true
  only when the ADC/interface transmits recoverable floating-point headroom; it
  cannot undo analog preamp/ADC saturation or fixed-point clipping. Raising a
  low-level file does not add quantization noise, but it also raises captured
  analog/electronic noise, so “without increasing the noise floor” is not a
  universal recording-chain claim.
- MIDI overlap/replace settings can merge, overlap, create takes/tracks/
  alternatives, or erase regions/content—with distinctions for cycle and whether
  notes arrive. Audio overlap can create take folders, tracks, or alternatives.
  These hidden defaults determine source/take identity before any production
  processing occurs.
- Sampler may store original/32-bit-float samples, search local/network/all
  volumes, trust file headers or filenames, analyze the longest detected note, or
  silently fall back to C3. Filenames are untrusted; pitch inference is uncertain.
  The page-1048 example incorrectly identifies MIDI note 60 as E6. Virtual-memory
  attack preload/disk streaming, buffers, host-disk-activity hint, and late-read
  counters affect dropout behavior, not sample semantics.
- Track-automation movement policy, following trails, return ramp, snap offset,
  automation write scope/mode, region-vs-track priority, and unautomated-region
  value inheritance can all change results. Region priority defaults differ for
  old and new projects. Lazy plug-in loading can leave unused strips inactive
  until selection, region insertion, unfreeze, monitoring, SBP, or routing makes
  them necessary.
- Project sample rate, Spatial mode, surround format, pan law, legacy Apple Loop
  algorithm, and automatic Environment strip management are audio-graph state.
  `-3/-4.5/-6 dB compensated` pan laws boost hard-panned positions; changing pan
  law can change levels throughout an existing mix.
- General `Use musical grid` also determines whether tempo information is written
  into recorded audio files. Asset settings decide whether audio, sampler,
  Alchemy, Ultrabeat, Space Designer IRs, movie, and library content are copied;
  Finder drag always copies/converts audio even when import-command policy differs.

### MIDI data, chase/reset, tuning, and notation settings

- MIDI 2.0 enablement and display resolution are distinct: displaying 0.0-127.9
  or percent does not prove a device/plug-in preserves higher-resolution data.
  Input ports may be USB/Bluetooth, virtual, IAC, network, or Auto Sampler; the
  Activity display shows disabled ports too. Large SysEx streams can still affect
  performance/project integrity.
- Reset, chase, clip-length, input-filter, MIDI Thru, articulation-switch, CC7/10,
  and post-load Environment/instrument settings can send external commands or
  reconstruct state at playback/cycle/region boundaries. Text meta and SysEx can
  be chased. These are executable MIDI authority, not trustworthy conversation.
- The Reset Messages descriptions inconsistently say some options in the
  `External MIDI` section send to software instruments. The Input Filter's System
  Exclusive item incorrectly says it filters program changes. The recording
  setting says MIDI data reduction reduces controller-event “duration” even
  though controllers are point messages; it likely means density/count. Exact
  behavior requires MIDI-capture tests.
- Score `MIDI Meaning` is the conditional bridge between visual articulation
  symbols and playback: configured velocity offsets and length percentages are
  applied at symbol insertion and reversed at deletion, but defaults are no
  change and later setting changes do not retroactively affect existing symbols.
  TrackSmith must inspect this project state before calling a score accent
  audible.
- Tablature string assignment can use pitch or MIDI channel. The channel can
  change display/string selection while track output determines playback. Score
  layout, colors, names, clef/signature visibility, page/bar offsets, and most
  engraving settings remain visual despite being saved globally per project.
- Equal temperament, historic fixed tables, per-semitone user tables, tuning
  stretch, and dynamic Hermode modes can affect Logic software-instrument pitch.
  Hermode infers chord structures and retunes thirds/fifths/sevenths; Apple does
  not provide a complete algorithm or ambiguity model. Its style/pleasantness
  recommendations are practice heuristics.
- The tuning prose incorrectly says equal temperament has *no* perfectly tuned
  interval; octaves remain exact 2:1. The `Stretch Upper` description says higher
  settings tune “low notes” farther down, duplicating `Stretch Lower` and likely
  containing a copy error. No production logic should be derived from that line
  without an instrument-frequency probe.

### Key commands and pointer shortcuts are an executable capability map

- Nearly every Logic function can be assigned, and some functions exist only as
  key commands. Sets can be imported wholesale, merged, limited to a selection,
  initialized, saved, and customized; the tables document only the U.S. default
  preset. The same keystroke is focus/context dependent and may have multiple
  commands. A printed default is never proof of the live assignment.
- Learn modes bind keyboard, Touch Bar, or arbitrary incoming controller messages
  to commands. Imported assignments can overwrite existing ones; the UI even
  permits conflicting functions to be retained. Provider output, filenames,
  MIDI, Lua scripts, and prior conversational text must never enter Learn mode or
  dispatch key commands.
- The command surface includes recording/discard, project save/import/export,
  bounce, file deletion/optimization, destructive Audio File Editor processing,
  permanent parameter/quantization application, arrangement/global section
  mutation, automation deletion/conversion, take flattening, pattern randomize/
  clear, Environment cabling, track activation, and external sample editing.
  Knowledge of a shortcut is not authorization to execute it.
- Startup modifiers can disable Core Audio/Audio Units, load only validated AUs,
  skip opening a project, or choose an alternative/backup. These are useful
  diagnostic/manual lanes but can materially change the validation environment.
- Pointer modifiers can alter group scope, copy vs move, alias creation, snap/
  sample precision, stretch vs resize, tool identity, global mute/solo/on,
  sequential routing, plug-in format, automation, and destructive editing.
  Channel-strip EQ/compressor display shortcuts can insert/remove processors at
  the highest/top slot, changing order.
- The Surround Panner modifier table on page 1170 says Option locks Diversity and
  Option-Shift locks Angle, contradicting pages 958-963, which say Command and
  Control-Command. Direct Logic 12.3 UI testing is required; neither instruction
  is safe automation evidence by itself.

Direct TrackSmith consequence: TrackSmith should be able to *explain* the exact
settings and manual commands relevant to a user's goal, including preconditions,
scope, reversibility, and expected audible effect. Its production AU and frontier
provider still receive no key-command, pointer, MIDI-Learn, settings-file,
filesystem, or host-command authority. Host evidence must capture the effective
application/project settings that affect the tested path; defaults and screenshots
alone are insufficient.

## Touch Bar control surface

- Touch Bar controls are selected by current screen, focused Logic window/editor,
  selected track type, modifier key, Smart Control mapping, and user-customized key
  commands. The same visible position can mean transport, split/crop/quantize,
  Mixer filtering, Score display, plug-in access, or track creation. A Touch Bar
  screenshot is not an operation identity.
- It can start/stop/record, move playhead/locators, change cycle, navigate the
  Tracks area, select tools, split/join/repeat/shuffle/crop/quantize, change
  automation mode, enable groups/Flex, open Selection-Based Processing, trigger
  Note Repeat/Spot Erase, select inputs, adjust gain/level, record-enable/monitor,
  and play pitched/drum instruments with scale/octave/repeat/velocity controls.
  These are executable project, recording, and musical-performance actions.
- The Smart Controls screen exposes mapped macros rather than native target
  identity. A button may toggle or open a subordinate screen; a level-like button
  may become a slider. As elsewhere, the displayed label does not prove which
  plug-in/channel-strip parameters it changes.
- Key Commands screens are customizable through the ordinary command-assignment
  system, so Apple’s listed defaults do not establish the live command. Touch Bar
  hardware availability is also machine-specific and absent from many current
  Macs.

Direct TrackSmith consequence: Touch Bar knowledge is useful for optional manual
instructions to users who actually have the hardware. It provides no stable API
or TrackSmith authority. The provider must never emit a raw Touch Bar gesture;
any future integration would resolve a typed, user-confirmed operation against
the live focus, selection, assignment, and track state first.

## Control surfaces and controller assignments

### Device support and persistent executable mappings

- Control surfaces can connect through dedicated USB/peripheral, MIDI, Ethernet/
  OSC, Bluetooth, virtual MIDI, or network paths. Directly supported devices use
  built-in MIDI Device Profiles/plug-ins or Lua MIDI Device Scripts; third-party
  control-surface plug-ins are Intel-only in the documented architecture, while
  Apple-silicon use depends on an available built-in profile/script. Driver,
  firmware, SysEx support, port direction, and device mode are prerequisites.
- Device setup, groups, and assignments are saved automatically in the global
  `~/Library/Preferences/com.apple.logic.pro.cs` file. Pinned assignments are
  project-local and target a specific track/plug-in instance; focused assignments
  are global and follow whichever compatible track/plug-in has focus. Mixer index
  targets are unstable when strip order changes; fader-bank/track-lock/view state
  changes the addressed strip.
- Up to 20 groups combine devices horizontally into one virtual surface; separate
  rows are independent groups. Device/group offsets determine fader banks and
  Live Loops scenes. `Arrange`, `All`, `Tracks`, and `Single` views expose different
  strip identities. Lua assignments always occupy a top-level modeless zone and
  interact with group 1.
- A device can automatically assign transport/key commands, Smart Controls,
  Mixer faders, and plug-in parameters. Enabling a Lua-supported device starts its
  optional MIDI input/output processing; disabling removes script assignments but
  preserves user-edited ones. On Intel, an installed plug-in can replace the Lua
  assignments. Firmware may itself be updated by playing an executable MIDI dump.

### Control interpretation is stateful and many-to-many

- Device/group state includes ports, module/model/firmware, bank/scene offsets,
  view, focus following, plug-in window following, flip mode, display/clock mode,
  track lock, EQ/send/insert slot and parameter pages, upper/lower split, relative
  mode/resolution, and active zone/mode. A physical knob has no stable meaning
  without the full state tuple.
- Easy Learn maps MIDI to a selected strip/plug-in parameter and can fill a
  controller series. Expert Learn can target global transport/playhead/locators,
  markers, automation of all tracks, quantize/division/zoom, any strip/plug-in,
  a keyboard key/key command, surface-group banking, or automation-group state.
  `Keep both` deliberately turns one control into a multi-parameter macro.
- Zones contain mutually active modes plus modeless assignments. Mode changes can
  be direct, toggle, relative, or rotating. Exclusive/flip groups, modifiers,
  pressed/released messages, Touch/Release, key repeat, input ranges, multiply,
  direct/toggle/scaled/relative/rotate/XOR modes, and destination min/max determine
  behavior. Labels and control names are display strings, not authority.
- MIDI messages may be 7-/14-bit with explicit byte templates and signed encodings.
  OSC uses UDP/IPv4 paths and normalized floats except some group/global feedback;
  the chapter documents no authentication or transport-security layer. Game
  controller buttons are also assignable. All external inputs are untrusted until
  bound through explicit user-controlled configuration.
- Feedback may drive displays, LED rings, motors, or Lua MIDI output; local
  feedback can be suppressed while touched to prevent fader fighting. Pickup mode
  prevents jumps on nonmotorized controls; disabling it can instantly jump a
  parameter to hardware position. Bypassing control surfaces is a distinct global
  state used for noise/MIDI troubleshooting.

### Control surfaces can cross consent and recording boundaries

- Hardware controls can start/stop/record, arm tracks, trigger Live Loops, choose
  routing/automation modes, alter every track's automation state, emulate arbitrary
  keystrokes, and repeat commands. Some controllers send MMC transport commands
  and require Logic to listen to MMC.
- Supported surfaces display modal alerts and can press the dialog's default,
  Cancel, checkbox, or radio action. This includes authorization warnings and
  destructive confirmations. A network/MIDI/model-generated message must never be
  able to accept consent or bypass a safety dialog.
- Automatic scanning, rebuilding defaults, changing ports, importing/copying the
  preference file, and global `Bypass all` mutate the live mapping. Device display
  values and motor positions are feedback, not proof that the underlying parameter
  write was recorded, committed, or belongs to the expected track.
- The User Guide is internally inconsistent about opening Controller Assignments:
  page 1135 lists `Option-Shift-K`, while pages 1202/1205/1211 say `Command-K`;
  page 1132 assigns `Command-K` to Musical Typing. Live key-command lookup, not
  prose, decides. The claim on page 1196 that X/Y are a “different representation”
  of Angle/Diversity and therefore “independent” is also conceptually ambiguous
  and requires a panner-state test.

Direct TrackSmith consequence: control-surface expertise lets TrackSmith diagnose
wrong-bank, wrong-mode, pickup, focus, mapping, feedback, port, and automation
problems and give device-aware manual instructions. It does not make MIDI/OSC/Lua
a production control API. TrackSmith networking remains companion-only; provider
output cannot enter Learn, emulate keys, accept dialogs, send feedback, or address
strips by mutable index. Any future bridge needs authenticated local transport,
typed stable object IDs, live scope/state validation, explicit consent, bounded
operations, and an audit trail independent of `com.apple.logic.pro.cs`.

## Environment and object reference

### Environment identity, topology, and compatibility state

- Apple now presents the Environment as a legacy compatibility feature, but its
  objects remain executable project state. There is one Physical Input, one
  Sequencer Input, protected `All Objects` and `Global Objects` layers, ordinary
  layers, automatic channel-strip objects, object aliases, and nested macros.
  Deleting a layer deletes its objects. Moving an object between layers preserves
  its cabling; copying an object generally preserves or recreates output cables.
- MIDI normally flows from Physical Input, through optional Environment processors,
  to Sequencer Input, then to the selected track and its target object. Region MIDI
  is mixed with incoming MIDI at the track path. Instruments, multi-instruments,
  mapped instruments, touch tracks, GM mixers, and the metronome can also have
  direct outputs, bypassing the normal track-to-Sequencer-Input route. A single
  source can be cabled to several destinations for serial or parallel processing,
  monitoring, duplication, or special-output behavior.
- Environment import is not a lossless merge primitive. Importing a layer or merging
  environments can replace the unique Physical Input and Sequencer Input objects and
  lose their incoming cables. `Update` imports additions but not deletions; replacement
  can match by port/channel/name or perform total replacement, and Apple explicitly
  warns that it involves guesswork and often needs fine tuning. Pasting over selected
  objects can replace their definitions while retaining cables. These operations need
  a project alternative/backup and manual topology verification, never model inference.
- Object display protection hides cables or prevents accidental recabling; it does not
  make the signal path immutable. `Assignable` controls whether an object appears as a
  track destination. Common name/icon/appearance fields are descriptive UI state, while
  Port, Channel, cabling, and processor definitions are executable routing state.

### Instrument, bank, drum-map, and external-device behavior

- Standard instruments can rechannelize output; transpose notes; add/subtract velocity;
  filter by pitch or velocity; send events early/late; ignore region transposition; opt
  out of reset messages; and assign default staff/articulation state. Program, volume,
  pan, and bank values transmit only when their checkboxes are enabled, but editing an
  enabled value sends it immediately; Option-selecting a track can also send its current
  settings. `No Reset` changes external-controller reconstruction, not merely UI state.
- A multi-instrument is sixteen MIDI-channel subinstruments sharing a port and global
  object settings. Each subchannel retains most standard-instrument parameters and can
  select programs from up to fifteen named banks. A subchannel's port change affects the
  entire multi-instrument. A cable cannot be dragged directly to a subchannel; direct
  subchannel assignment uses the destination menu. Names and program labels do not prove
  the external device's actual patch state.
- Mapped instruments can rename every input note and independently change its output
  note, velocity, channel, one of sixteen output cables, note head, display position, and
  notation group. Output-note editing emits MIDI while the value changes. Missing output
  cables silently drop assigned notes. Head/relative-position/group are score-only;
  pitch, velocity, channel, and cable fields are audible/executable. This distinction is
  crucial when TrackSmith explains a drum map.
- Custom bank selection may contain an arbitrary ordered list of MIDI events, including
  SysEx, for each of sixteen banks. The whole list is transmitted on a manual or standard
  bank change; if no list exists Logic sends its default bank-select message. Device-
  specific formats, ordering, channel fallback, and external documentation are therefore
  required before describing a bank change as safe.
- The GM mixer sends external bank/program/controller messages, including CC7 volume,
  CC10 pan, and user-assigned controllers. GS/XG modes can select effects and set reverb/
  chorus parameters. Its Reset sends GS On or XG On and neutralizes controllers; it is an
  external-device state reset, not a harmless visual reset. MMC Record Buttons can arm or
  disarm tracks on an external MMC recorder, including video/timecode/aux tracks.

### Performance generators and source-transforming processors

- Touch Tracks maps input notes to MIDI regions or folders, with pitch transposition,
  velocity sensitivity, exclusive groups, free or quantized launch/stop, delay, and six
  trigger modes: Multi, Single, Gate, Gate Loop, Toggle, and Toggle Loop. It cannot launch
  audio regions directly. Triggered material plays through its source tracks and can build
  a live arrangement, so this is performance authority rather than a simple note effect.
- The Environment arpeggiator expands held notes by direction, fixed/original/random
  velocity, pitch range, rhythmic resolution down to 1/768 note, length, start quantize,
  repeat, one-to-ten octaves, and per-repeat velocity change. Notes outside its key range
  pass through; it resets on cycle jumps. Its processed output can be cabled back to
  Sequencer Input and recorded, provided a feedback-producing output path is avoided.
- Delay Line creates up to 99 MIDI-event repeats between one tick and 256 whole notes,
  optionally suppressing the original and changing note transposition and velocity per
  repeat. Repeats rotate among connected outputs. This changes MIDI performance, not
  audio like Logic's delay effects; TrackSmith must not confuse the two meanings of delay.
- Voice Limiter constrains one-to-32 simultaneous MIDI notes and steals earliest, lowest,
  or highest notes according to priority; it can also force note-on velocity. Channel
  Splitter routes by MIDI channel with uncabled channels falling to `SUM`. Chord Memorizer
  maps each of twelve pitch classes to zero-to-twelve-note chords, with range, channel,
  transposition/key, and per-note cable splitting. These operations can alter harmony,
  voicing, rhythm, and articulation before any audio DSP occurs.
- Transformer evaluates status/channel/data-byte conditions, then passes, filters, copies,
  reorders, transforms, or splits matching events. Its special modes alternate outputs,
  build device-specific SysEx, or turn MIDI into channel-strip automation. It processes
  14-bit pitch bend and can be reprogrammed live by meta events. Position and note length
  do not apply because this object operates in real time, unlike the region-based MIDI
  Transform window.

### Faders, SysEx, meta events, and hidden execution authority

- A fader's visual style is separate from its event type. Sliders, knobs, buttons, text
  menus, and two-dimensional vector controls can send or receive note, poly/channel
  pressure, controller, program-change, pitch-bend, SysEx, switch, or Logic meta data.
  Faders can translate one event type to another, filter matching/nonmatching/all/physical-
  input events, send final-only values, generate paired 14-bit controllers, or permit a
  normally suppressed feedback loop. MIDI remote control can exceed the displayed range.
- Fader output is recordable on the selected track during record or record/pause. `Send
  All Fader Values`, `Send Selected Fader Values`, reset-to-zero, and the project-load
  `All fader values` option transmit batches to connected destinations. A displayed fader
  layout can therefore be a virtual synth editor, mixer snapshot, or external control
  surface with delayed side effects after project load.
- Cable Switcher routes arbitrary MIDI/meta events among up to 128 outlets. Input values
  choose a route, with 126/127 decrement/increment semantics and wraparound. Alias Assigner
  can dynamically retarget one or more aliases. Aliases share the parent's processing but
  can have independent fader value, channel override, name, and size, so identity cannot
  be inferred from appearance.
- Meta events never leave Logic, but they can assign aliases; jump to a screenset, project,
  or marker; stop playback; change fader ranges/values; resend or step a fader; control
  tempo; and mutate Transformer conditions, operations, map position, and map values.
  They may work globally without cabling or target a cabled object. This is direct host/
  project-control authority hidden in an event-like format.
- A SysEx fader can send an ordered batch of arbitrary MIDI or meta events with one click,
  not only SysEx. Selected bytes follow its value; other events transmit exactly as stored.
  It supports learned or hand-authored device strings, manufacturer/device IDs, five
  checksum schemes, MSB/LSB order, BCD, nibble, and ASCII encodings. Apple notes there is
  no uniform device-message standard. Neither provider output nor imported text may be
  compiled into this executable byte stream.
- Vector mode normally emits horizontal and vertical messages; if both definitions match,
  it emits four consecutive-channel values representing proximity to four corners. The
  documented default center produces 32 on every channel while corner values total 127;
  with altered ranges the manual says the four values always total 125. That unusual,
  unexplained discrepancy needs capture testing before exact emulation.

### Physical/Sequencer input, channel strips, and preview-path consequences

- The Physical Input exposes 65 outputs: individual interface inputs plus `SUM` for inputs
  not separately cabled. Control-surface remote events are intercepted before Environment
  output and recording. Sequencer Input is Logic's track-recording ingress; with no cable
  into it, Logic records no MIDI. `Channelize` rewrites incoming channel data to the selected
  track object's channel. Complex Environment output can be fed back into it to print the
  processed performance.
- Environment channel-strip objects are the underlying audio/software-instrument/aux/
  output/master/input/bus objects controlled by the Mixer and inspector. MIDI objects can
  feed control data into them even though audio strips are not part of the MIDI signal
  stream. Automatic channel-strip management normally creates/removes these objects;
  disabling it exposes manual system-level routing and compatibility behavior.
- Input strips can process live hardware input through plug-ins even while transport is
  stopped, route external instruments into a mix, and feed a recorded audio strip with
  effects printed. Legacy Bus strips are distinct from modern aux-based bussing. Device,
  strip type, MIDI control channel, Q-reference, Flex algorithm, inserts/sends, and I/O are
  executable audio-graph or timing state.
- Each project has an automatically created Preview strip for Project Audio Browser and
  Audio File Editor auditioning. It can have its own level, effects, and output. Deleting it
  does not silence preview: Logic falls back to the highest-numbered audio strip, whose
  processing can make auditioned files sound materially different. This explains why a
  browser preview is not proof of the raw file's sound.
- Macros package roughly 100-200 objects, can nest, and infer I/O from `Macro-In`/
  `Macro-Out` names or object position. Building a macro from objects with external cables
  deletes those cables in the macro copy; protected macros cannot be unpacked. The macro's
  `No Reset` description incorrectly points to `Logic Pro for iPad > Settings`, and the
  Transformer creation instruction likewise says `Logic Pro for iPad Environment` inside
  the Mac guide. These are editorial errors, not cross-platform capability evidence.

Direct TrackSmith consequence: Environment expertise supports precise diagnosis of
wrong MIDI channels, missing notes, duplicate paths, transformed velocities, bank/program
surprises, printed MIDI, preview coloration, external-device resets, and compatibility
routing. It does not authorize TrackSmith to edit or import an Environment, emit MIDI/
SysEx/meta events, control tempo/transport/external recorders, write automation, or address
mutable channel strips. Any future typed bridge would need live topology capture, stable
object/runtime identity, loop detection, per-operation consent, device-specific validation,
and reversible project evidence. The present AU remains audio-only and deterministic.

## Glossary and manual-wide terminology audit

- The glossary was read as a terminology cross-check, not as an algorithm or production-
  practice authority. It usefully confirms Logic's intended distinctions among an audio
  file, audio region, track, channel strip, patch, setting, project, alternative, backup,
  automation point, controller, MIDI event, and Environment object. Those identities must
  remain separate in TrackSmith contracts and explanations.
- It reinforces destructive versus nondestructive scope: Audio File Editor operations alter
  file data; Audio Track Editor/region parameters normally alter references or playback;
  normalization means different things for audio files and MIDI regions; Selection-Based
  Processing renders a selection; freeze renders track state; bounce combines source,
  routing, effects, and eligible automation into new media. None is interchangeable with
  changing TrackSmith's AU graph.
- The glossary's compact definitions omit operational preconditions. For example, `bounce`
  says offline mode cannot apply live automation or real-time input, but the detailed bounce
  chapter is needed to distinguish existing automation from control performed during a
  real-time pass. `Audio Units` says Logic supports all AU-format plug-ins, while the detailed
  host chapter and validation behavior establish architecture, compatibility, security, and
  Plug-in Manager qualification. Short definitions never supersede the full workflow.

### Claims TrackSmith must not promote to universal truth

- “Higher sample rates yield higher-quality audio” is an unconditional glossary claim.
  Sample rate changes bandwidth, anti-alias/filter design, storage, CPU, conversion paths,
  and sometimes nonlinear-processing behavior; perceived quality depends on source,
  converter/algorithm, processing chain, delivery rate, and controlled listening evidence.
- Saturation is defined as slight tape/tube distortion that produces a “warm, rounded”
  sound. Actual saturation can add different odd/even spectra, compression, intermodulation,
  aliasing, noise, bandwidth shifts, and level-dependent transients; it can sound harsh,
  bright, dull, fuzzy, dense, or nearly transparent. `Warm` remains a source/context-dependent
  intent, not a guaranteed saturation result.
- Distortion is defined as what occurs after exceeding reproducible digital limits. That
  describes clipping but excludes intentional nonlinear distortion below 0 dBFS, analog-
  modeled distortion, quantization, aliasing, intermodulation, speaker/amplifier distortion,
  and many other mechanisms documented in the Effects manual.
- “Bypassed plug-ins do not drain system resources” is too absolute for a host contract.
  Bypass mode, AU/native implementation, tail/latency/state handling, host scheduling, shared
  resources, and Logic's own lazy-loading behavior can differ. Direct performance and latency
  probes decide; the UI bypass state alone does not prove zero CPU or zero retained resource.
- “Cutting at a zero crossing” is said to guarantee no click. Matching instantaneous sample
  value reduces a value discontinuity but does not guarantee matched slope, channel phase,
  DC behavior, spectral continuity, effect state, or waveform context. A short appropriate
  crossfade and audition remain safer.
- Mono is defined as mixing stereo channels in equal amounts, which is one fold-down method,
  not the definition of every mono source/path. Equal summing can change gain and cancel
  anti-correlated content. Stereo-to-mono compatibility requires an explicit matrix and
  correlation/level checks.
- Quantization is described as moving all notes perfectly to the nearest grid while remaining
  nondestructive. The detailed chapters allow strength, swing, Q-range/velocity/length/flam,
  groove templates, event-level commands, and permanent application. TrackSmith must name
  the specific quantize path and preserve the original timing rather than inherit the glossary
  simplification.
- Pitch is described as corresponding to frequency and frequency as corresponding to pitch.
  That is a useful first-order mapping for periodic tones, not a full perceptual model for
  missing fundamentals, inharmonic/complex/noisy sources, pitch salience, register, tuning
  context, or time-varying material.
- Filter cutoff is said to be “typically” the -3 dB point and high/low-pass bands to pass
  unaltered. Actual response at cutoff and in the passband depends on filter family, order,
  slope, resonance/Q, gain normalization, phase, and topology. Exact plug-in documentation
  or measurements control.
- White noise is described as all frequencies sounding simultaneously at the same intensity,
  and blue noise simply as high-pass-filtered white noise. Engineering use needs power
  spectral density, bandwidth, sampling, weighting, filter slope, and generator definition;
  these phrases are mnemonic descriptions only.
- A de-esser does not literally “remove” all hissing/sibilance. It detects and attenuates a
  chosen band or event under topology-dependent conditions, with risks to consonants,
  brightness, intimacy, and lisping. Reverb, chorus, flanging, compression, expansion,
  headroom, and dynamic range receive similarly introductory definitions whose detailed
  manuals and measured behavior take precedence.

### Editorial and provenance limits

- The glossary contains `DFS`/`0 dB DFS` where the conventional notation is dBFS, a missing
  opening parenthesis in the second `sample` sense, and a `Session Payer region` typo. It
  calls S/P-DIF a professional format even though the surrounding guide distinguishes it
  from the professional AES/EBU interface. These are further evidence that editorial prose
  must be cross-checked rather than treated as executable specification.
- Page 1324 grants an owner or authorized user of a valid Logic copy permission to reproduce
  the publication for learning, while prohibiting commercial reproduction/transmission such
  as selling copies or providing paid support. TrackSmith retains only the immutable,
  local-use research payload and its own synthesis; the Apple manual is not redistributed
  as product content.

Direct TrackSmith consequence: the complete User Guide establishes Logic 12.3 vocabulary,
visible workflows, state scopes, and documented behavior. It does not establish an API,
perfect implementation behavior, psychoacoustic universals, or permission for TrackSmith to
mutate host/project/file state. Explanations must route from the relevant detailed chapter or
Effects/Instruments manual and clearly label professional heuristics and listening-dependent
judgment. The glossary is a search vocabulary and disambiguation aid only.

## Coverage closure

All ledger ranges are now `Deep`. The synthesis above covers interface/editing tools;
recording, take folders, comping, punch, and source preservation; media/import and asset
identity; arrangement and region operations; Session Player and generated-performance
boundaries; mixer/routing/automation/Smart Control topology; Live Loops and Step Sequencer;
tempo, beat, marker, signature, score, bounce, Spatial Audio, synchronization, settings,
commands, control surfaces, Environment, glossary limits, and compatibility risks.

This closes documentary coverage of the Logic Pro 12.3 User Guide, not empirical closure.
Every identified contradiction, undocumented algorithm, device-dependent path, potentially
destructive workflow, and capability outside a normal AU remains subject to the direct-test
queue and cannot be promoted to implemented TrackSmith behavior without evidence.
