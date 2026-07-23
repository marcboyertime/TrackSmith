# TrackSmith Logic Pro Control Surfaces Atlas

Status: complete deep review, 2026-07-15. This atlas records actual reading of
every page of Apple's 220-page *Control Surfaces Support Guide for Logic Pro*.
It complements the complete Logic Pro 12.3 User Guide, Effects, and Instruments
atlases. A table-of-contents entry or device name was never counted as deep review.

## Epistemic and authority rules

1. The guide documents Apple-supplied mappings for named hardware and supported
   emulation modes. It does not prove the mapping is active on an unverified device,
   firmware, port configuration, custom assignment set, or current Logic focus/mode.
2. A surface control is identified by device, firmware/profile, device group, view,
   bank, zone/mode, modifier, selection/focus, assignment page, and press/touch state.
   Its printed label alone is not an operation identity.
3. Hardware can control transport, recording, automation, routing, plug-ins, project
   navigation, edit commands, dialogs, external devices, and destructive operations.
   Documentary knowledge never grants TrackSmith or a model permission to emit MIDI,
   OSC, keystrokes, Lua, EuCon, HUI, or Mackie Control messages.
4. User customization, manufacturer plug-ins, MIDI Device Scripts, Controller
   Assignments, and emulation layers can override or extend documented defaults.
5. Device-specific workflow recommendations are professional/UI heuristics, not
   evidence that one mapping or gesture is musically correct.

## Immutable primary source

| Source | Version | Pages | SHA-256 | Rights/status |
|---|---|---:|---|---|
| Apple, *Control Surfaces Support Guide for Logic Pro* | PDF created 2025-05-15, retrieved 2026-07-14 with Logic 12.3 manual set | 220 | `5ab5e4ef38e9c8e9279a0a2d36dcaabd1a9471942843d0162a3016f6ebf9322c` | Apple copyright; immutable local-use-only research object |

Canonical object:
`research/papers/tracksmith-logic-12.3-archive/objects/5ab5e4ef38e9c8e9279a0a2d36dcaabd1a9471942843d0162a3016f6ebf9322c.pdf`.

Text was extracted page-by-page in bounded ranges and dense/contradictory layouts were
checked against rendered page images. In particular, rendered pages 15, 67, and 138 confirm
that the V-Pot 5/V-Pot 4 insertion error, duplicated EuCon Link-enabled condition, and
Prev/Next C4 reversal are present in the source layout rather than extraction artifacts.

## Review ledger

| Family | Pages | Status |
|---|---:|---|
| Overview | 1-7 | Deep |
| Mackie Control | 8-56 | Deep |
| M-Audio iControl | 57-64 | Deep |
| Euphonix/Avid | 65-75 | Deep |
| CM Labs Motormix | 76-85 | Deep |
| Frontier Design TranzPort | 86-89 | Deep |
| JLCooper CS-32 MiniDesk | 90-96 | Deep |
| JLCooper FaderMaster 4/100 | 97-98 | Deep |
| JLCooper MCS3 | 99-101 | Deep |
| Korg microKONTROL/KONTROL49 | 102-107 | Deep |
| Mackie Baby HUI | 108-111 | Deep |
| Mackie HUI | 112-127 | Deep |
| Mackie C4 | 128-139 | Deep |
| Novation Launchpad | 140-149 | Deep |
| Radikal SAC-2K | 150-157 | Deep |
| Recording Light | 158-159 | Deep |
| Roland SI-24 | 160-166 | Deep |
| Tascam US-2400 | 167-175 | Deep |
| Yamaha 01V96 | 176-187 | Deep |
| Yamaha 02R96 | 188-193 | Deep |
| Yamaha DM1000 | 194-206 | Deep |
| Yamaha DM2000 | 207-219 | Deep |
| Copyright | 220 | Deep |

## Cross-device findings

- Logic's surface path is bidirectional: hardware writes can change Logic state and
  Logic changes drive displays, LEDs, encoders, and motorized faders. Feedback is not
  proof that automation was written, a command succeeded, or the addressed track is
  the one the user intended.
- Supported surfaces arrive with default mappings, while unassigned controls can be
  mapped and Lua-supported devices can be remapped through Controller Assignments or
  Smart Controls. The same hardware may instead run a manufacturer plug-in or an
  emulation protocol. Live configuration remains authoritative.
- Surface automation can be recorded even when Logic itself is not in record mode.
  `recording` is therefore ambiguous between media recording, track automation writing,
  and external-machine record enable.

## Mackie Control, XT, Logic Control, and emulation mode

### State model and feedback

- `Mackie Control` in this guide includes Mackie Control Universal, original Mackie
  Control, Logic Control, XT extenders, and devices in a Mackie Control emulation mode.
  Automatic detection and the Apple profile do not prove that a third-party emulation
  reproduces every display, touch, motor, resolution, or modifier behavior.
- The main LCD has eight two-line parameter columns; separate displays show assignment
  mode and either musical or SMPTE position. Track/parameter names are abbreviated and
  non-7-bit characters are approximated. V-Pot LED rings, signal LEDs, motor faders,
  clip flags, and the global Solo indicator are partial feedback. Bank/view changes can
  hide the actual soloed, armed, selected, or edited strip.
- The effective mode includes Mixer versus Channel view, Track/Pan/EQ/Send/Plug-in/
  Instrument assignment, plug-in parameter page, fader bank, Global View filters, Flip/
  Swap/Zero, group mode, marker/nudge/cycle/punch mode, zoom/cursor mode, and modifiers.
  Logic remembers separate bank positions for channel-strip classes. In a surface group,
  bank movement is scaled by the group's total strip count.

### Mixer, plug-in, instrument, and routing authority

- V-Pots change values, choose destinations or plug-ins, confirm flashing selections,
  open plug-in windows, enter folders, reset/toggle parameters, or invoke menus. OPTION
  can jump among min/default/max and CMD/ALT enables fine changes. A preselection is not
  applied until confirmed, but turning another encoder cancels it.
- Track modes can change volume, pan, mono/stereo/left/right/surround format, Spread,
  input/output assignment, automation mode, group membership, software instrument,
  insert 1/2, and send levels. Channel view can insert an instrument/effect or bypass/mute
  an instrument, plug-in, channel, or send. Choosing `--` and confirming removes the
  instrument or plug-in. Entering EQ Channel view automatically inserts Channel EQ when
  neither Channel EQ nor Linear Phase EQ is present.
- Pan/Surround modes edit Angle/Pan, Diversity, LFE, Spread, and X/Y. X/Y are constrained
  to the surround circle; invalid pairs adjust the other coordinate, and only Angle/
  Diversity are documented as recorded automation. Non-surround strips continue to edit
  ordinary pan even while adjacent surround strips use another parameter.
- EQ modes edit every band's frequency, gain, Q, and bypass, with faders optionally forming
  a frequency/gain surface. Send modes select destination, level, pre/post position, and
  mute across strips or within one strip. Assigning a destination also initializes other
  send fields to defaults, so it is not a single-field mutation.
- Plug-in/instrument edit exposes every automatable parameter independent of native/AU
  format. Third-party plug-ins that omit textual names appear only as `Control #N` with a
  normalized 0-1000 display. That generic value is not a unit, safe bound, or semantic
  identity. Parameter order/page state and the live AU parameter tree remain decisive.
- Flip mirrors a V-Pot assignment on a touch-sensitive fader; Swap exchanges encoder and
  fader assignments. This allows overwriting automation with a constant while touched.
  Zero parks and disables motors to avoid their mechanical noise near microphones; it is
  not a mix reset. The Master fader targets Logic's Master strip, falls back to Output 1-2
  if none exists, and controls only the first audio device in a multiple-device setup.

### Recording, editing, project, and consent boundaries

- Strip buttons arm/disarm recording, toggle input monitoring, solo, mute, select, create
  tracks, reset volume, and modify selection. Automation buttons set selected or *all*
  strips to Read/Off, Touch, Latch, or Write. Apple explicitly warns that Write destroys
  existing automation, while Latch can continue overwriting until Stop.
- Global function keys recall screensets; open editors/windows; Cut, Copy, Paste, Clear,
  Select All/Following/Similar/Inside Locators; and act as numeric keys in modal dialogs.
  Global View buttons become more numeric/operator keys in dialogs. CANCEL activates
  Cancel/Escape or a contextual toolbox/folder exit; ENTER activates the dialog's default
  button. Hardware input must never be permitted to approve authorization or destructive
  confirmation on TrackSmith's behalf.
- SAVE writes immediately after the initial path exists; OPTION-SAVE opens Save As. UNDO,
  Redo, and Undo History affect the host's shared editing history. Project changes illuminate
  the Save LED, but that does not establish which changes are committed to TrackSmith's AU
  state or whether source media changed.
- Transport controls play, pause, stop, record, shuttle, scrub, and navigate. Marker modes
  create/delete/navigate markers. Nudge modes move selected regions/events by ticks,
  divisions, beats, bars, frames, half-frames, the current nudge unit, or directly to the
  playhead. Cycle and Autopunch modes set and move locators; Replace can overwrite existing
  recording. CLICK toggles metronome, while SHIFT-CLICK toggles external sync and MMC.
- Group mode creates groups and changes membership and group behavior. Cursor/zoom modes
  can change editor selection or view. Six user modes enter Controller Assignment Learn.
  Footswitches default to Play/Stop and Record; an expression pedal defaults to Master
  level. These always remain user-owned performance inputs.

### Internal contradictions requiring live verification

- Page 15 says V-Pot 5 selects Insert 2 but confirmation uses V-Pot 4, evidently copying
  the preceding Insert 1 instruction. The expected matching control is V-Pot 5, but only a
  device trace may establish actual behavior.
- Page 12 maps SHIFT-SELECT to additive selection and OPTION-SELECT to unity gain, whereas
  page 46 maps SHIFT-SELECT to unity gain and OPTION-SELECT to creation of a same-assignment
  track. Both cannot describe the same default state.
- Page 30 assigns unmodified F8 to Screenset 8; page 50 assigns it to closing the topmost
  floating window. The detailed EQ shortcut list on page 20 maps F1-F4 to frequency, gain,
  Q, and bypass, while the summary table on pages 48-49 maps them to bypass, EQ type,
  frequency, and gain.
- Page 40 says unmodified global SOLO toggles ordinary Solo and SHIFT-SOLO enables Solo
  Lock. Page 54 describes unmodified SOLO as toggling Solo Lock. The same table says Fast
  Forward in Marker mode goes to the *previous* marker, contradicting pages 34-35 and the
  adjacent explicit next-marker mapping.
- Page 41 assigns per-track zoom modifiers to OPTION; page 55 assigns the related cursor-
  zoom operations to SHIFT. Custom key/mapping state cannot resolve a contradiction in
  nominal defaults, so each needs a Logic/device capture test.

Direct TrackSmith consequence: this knowledge can provide state-aware Mackie Control
instructions and diagnose wrong bank, page, view, insert, send, parameter, focus, modifier,
or motor mode. It cannot be a covert host-control channel. Model output may not enter Learn,
emit protocol data, insert/remove plug-ins, change routing or automation, arm/record, move
regions, accept dialogs, or save a project. Any future adapter must resolve a typed request
against live device/profile/mode/strip identities and require explicit confirmation for every
host mutation.

## M-Audio iControl

- iControl is automatically detected and retains its GarageBand-oriented layout inside
  Logic. Eight encoders switch among all-strip volume/pan and selected-strip instrument,
  EQ, insert, send, gate/compressor, pan, and level parameters. Track Info repurposes the
  eight Select buttons as bypass controls for five inserts and two sends. Generator and
  plug-in modes page through every automatable parameter in groups of eight.
- Entering EQ mode inserts Channel EQ automatically when neither Channel EQ nor Linear
  Phase EQ exists. Effect 1/2 address Insert 3/4 rather than the first two slots; OPTION
  toggles those slots' bypass. The fixed Track Info mappings for Noise Gate threshold and
  Compressor ratio apply only when those plug-ins occupy the expected GarageBand-derived
  configuration, so a label is not a general channel analysis.
- Arrow buttons bank eight strips or page eight parameters depending on assignment state.
  Strip controls select, arm, mute, solo, and clear those states globally with OPTION.
  Encoders with OPTION jump among parameter extrema/default. Transport starts media
  recording, returns to zero, moves by bars, plays/stops, and edits Cycle locators; the jog
  wheel changes the playhead or defines cycle/skip-cycle ranges. The hardware Master fader
  controls Logic's Master stage.
- Page 59 contradicts itself about OPTION-arrow endpoints: the prose first says Arrow Up
  jumps to the *first* eight and Arrow Down to the *last*, then its 64-strip example assigns
  Arrow Up to 57-64 and Arrow Down to 1-8. The summary table only says first/last without
  resolving direction. A live device trace is required.

Direct TrackSmith consequence: iControl-specific advice must name its assignment state,
selected channel, insert number, and page. The device offers no safe model-control shortcut;
automatic EQ insertion, bypass, arming, recording, locator edits, and Master level remain
explicit user actions.

## Euphonix/Avid EuCon devices

- EuCon is a separate integration path managed by current Avid EuControl software. Its
  devices neither appear in Logic's Control Surfaces Setup window nor accept changes through
  Controller Assignments. Avid Artist/MC Mix/MC Transport/MC Control are the documented
  family; legacy MC Pro, System 5-MC, and CM408T are no longer supported by the current
  protocol. Current Avid software, device documentation, surface membership, and network
  discovery must be verified independently of this 2025 Apple addendum.
- By default the surface mirrors Mixer Arrange View, not later Mixer filter/view changes.
  Multiple tracks routed to one channel strip are not separately accessible. Changing the
  group view can override this, while focused strips are indicated in blue Control Surface
  Bars. A surface strip therefore represents a channel-strip view, not necessarily a unique
  track.
- Device Read/Write nomenclature is translated: blank is Off, Read is Logic Read, Write is
  Logic Write, and combined Read/Write activates Logic Touch; Latch is unavailable from the
  surface. The `On` key is inverse to Logic Mute—lit means unmuted. Fader-touch selection is
  governed by the device's own EuControl preference, not Logic's corresponding setting.
- Hierarchical eight-parameter knobsets can insert/edit/bypass effect plug-ins; select audio
  inputs and mono/stereo/left/right/surround formats; insert/edit an instrument; edit the
  first Channel or Linear Phase EQ (or auto-insert Channel EQ); set send destination/level/
  pre-post; edit pan and seven surround parameters; change group membership; and choose
  output. Effect/instrument parameters follow Controls-view order and a knob press resets
  the parameter, so page/order identity matters.
- Layouts are stored with the Logic project. Logic does not support EuCon monitoring/control-
  room functions; Apple directs users to Studio Monitor Pro. This is a separate monitoring
  authority and must not be conflated with Logic mixer output state.
- Page 67 repeats the condition “If the Link button is enabled” before two mutually exclusive
  plug-in-window behaviors: one says selection replaces a linked window and exit does not
  close it; the next says a new window opens and exit closes it. The second condition almost
  certainly intended Link *disabled*, but that inference requires a Logic/EuControl test.

Direct TrackSmith consequence: EuCon advice requires the exact Avid software/device,
surface layout, strip view, automation translation, knobset/page, and plug-in-window Link
state. EuCon remains an external executable integration owned by the user; TrackSmith does
not send EuCon commands, edit layouts, change routing, insert plug-ins, or write automation.

## CM Labs Motormix

- Motormix requires explicit bidirectional MIDI port setup. Eight Select buttons change
  meaning across channel, window-focus/close, tool selection, transport, locate, marker,
  group, effect, instrument, and modal-dialog modes. In modal dialogs, Select, Multi, Burn,
  Solo, and Mute buttons emit the character printed on the hardware, so a surface action
  can become arbitrary dialog input rather than its usual mixer function.
- Faders normally control level but can mirror encoders. Encoders page among sends; every
  EQ band's frequency/gain/Q; Pan/Angle/Diversity/LFE/Spread/X/Y; format/input/output/
  automation/group; insert 1-15 assignment and plug-in parameters; instrument assignment/
  parameters; and group properties. Full/Fine modes jump to extremes or single-unit changes.
- Hardware can bypass EQ bands, sends, effects, and instruments; choose send destinations;
  set pre/post; select tools; create/delete/navigate markers; open/close windows; arm record;
  set selected or all channels to Latch/Write/Read/Touch/Off; create/edit groups; Undo; Save;
  open synchronization/automation project settings; invoke transport; and send Enter/Escape.
  Its many LEDs communicate mode, not semantic authorization.
- The automation table on pages 81-82 maps `ALL + SHIFT (fnctA)` to all-channel Latch,
  Read, and Off even though individual Read/Off use fnctB/fnctC. The repeated fnctA labels
  are internally inconsistent and likely editorial copies; live mapping is required.

Direct TrackSmith consequence: Motormix troubleshooting must reconstruct the flashing
mode LEDs, encoder selector, bank state, modifiers, selected strip, and modal status. Its
MIDI channel can write global automation, insert/modify processing, execute dialog input,
and save the project, so provider-originated messages are prohibited.

## Frontier Design TranzPort

- The wireless TranzPort uses vendor software plus its USB bridge and is automatically
  installed in native mode. Its small LCD shows one strip's name, volume, pan, meter, and
  playhead position; the `ANY SOLO` light aggregates track, strip, and region solo.
- It banks one/eight strips; arms/mutes/solos the current strip or clears each globally;
  performs Undo/Redo; sets, navigates, and deletes markers; configures Cycle, skip-cycle,
  and Autopunch locators; scrubs/shuttles/moves by bars; adjusts selected-strip volume;
  plays, pauses, stops, records, saves, and punches via footswitch. Identical jog/transport
  hardware therefore changes project state according to held LOOP/PUNCH/SHIFT and jog mode.

Direct TrackSmith consequence: this is a remote performance/recording surface, not merely
a monitor. Advice must include the active strip and modifier/mode; TrackSmith never emits
its commands or treats the LCD/solo light as proof of a capture or commit identity.

## JLCooper CS-32 MiniDesk

- Only the MIDI connection in Host mode is supported. Its two-digit display is necessarily
  lossy: names are two characters, numeric values retain only the last two digits, and signs
  appear only when space permits. Nonmotorized pots/faders use optional Pickup with NULL
  arrows; until hardware crosses the current value, movement may intentionally do nothing.
- Pots edit instrument/effect pages, up to five send levels/destinations, pan, and input
  format. Thirty-two strip controls change identity between Track/Locate/Arm and Pan/Solo/
  Mute banks. LOCATE can jump to 32 markers; modified positions create/delete markers,
  open marker UI, set locators, or navigate. Mute buttons can enable six automation classes
  and set Read/Touch/Latch/Write/Off. Other controls arm/record, edit Cycle/Autopunch/
  metronome/locators, zoom, select insert/page, scrub, and shuttle.
- Page 91 defines the Read-mode display as `rd`, while page 93 says `Td`; this is an internal
  label inconsistency. It does not change the underlying automation risk but prevents a
  documentation-only display assertion.

Direct TrackSmith consequence: any CS-32 instruction must state its red-bank LED, F-key/
SHIFT state, selected strip, insert/page, and Pickup relation. Truncated display feedback is
not sufficient identity for an automated production edit.

## JLCooper FaderMaster 4/100 and MCS3

- FaderMaster requires firmware 1.03+, current USB driver or bidirectional MIDI, and can
  combine devices into one surface while each unit retains its own Track-button mode.
  Four touch-sensitive motor faders control volume; Track buttons switch globally per unit
  among selection, record-enable, solo, and mute, with four-strip banking.
- MCS3 USB/MIDI exposes three assignment layers; F4-F6 and W1-W7 are intentionally
  unassigned per layer and may execute arbitrary user keyboard mappings. Its cursors mirror
  context-sensitive computer arrows, jog scrubs, shuttle changes transport speed/direction,
  and dedicated buttons record/play/stop or move by bars.

Direct TrackSmith consequence: FaderMaster Track labels require the unit-local mode, and
MCS3 programmable keys require the live layer/assignment. Neither surface can be reasoned
about from its faceplate alone or driven by provider output.

## Korg microKONTROL and KONTROL49

- Logic automatically switches a USB-connected unit into native mode and ignores its
  internal Scenes; quitting Logic/deleting the surface restores normal mode. Bus-power delay
  can prevent identification. Eight Pad modes plus three overlays repurpose 16 Pads, and
  eight encoder modes repurpose channel strips; faders are nonmotorized and optionally use
  Pickup.
- Pads select transport/scrub/shuttle, internal/external sync, click, Cycle, Autopunch,
  Replace, Solo, record/pause/play/stop, per-strip solo/mute/arm/select, send bypass/pre-post,
  and effect bypass. Encoders control pan, send level/destination, automation mode,
  instrument/effect pages, and user-defined Learn mappings. MESSAGE duplicates the current
  encoder assignment on faders; footswitch controls play/stop and pedal controls Master.
- User Pad/encoder modes are unassigned and can learn key commands. Korg Pads emit a range
  when released normally, so the manual requires holding the Pad until Learn disengages to
  capture a fixed value. This is executable mapping state, not a performance nuance.

Direct TrackSmith consequence: Korg advice must name native mode, Pad mode/overlay,
encoder mode, insert/send/page, bank, Pickup state, and automation-color meaning. TrackSmith
must never initiate Learn or infer a user-mode action from the hardware label.

## Mackie Baby HUI

- Baby HUI requires manual, bidirectional MIDI-port installation. Encoder presses select
  strips or, with SHIFT, arm them; encoders control pan or Sends 1-4, while faders control
  level and dedicated buttons solo/mute.
- Automation controls set Off/Read/Write/Touch, while SHIFT changes whether volume, mute,
  pan, or send-level automation is played/recorded. Other buttons open UI, Undo, bank,
  navigate/set punch locators, shuttle, play, stop, and record.

Direct TrackSmith consequence: even this compact surface crosses recording, automation,
history, and punch boundaries. A Baby HUI instruction must identify SHIFT and the current
encoder assignment/bank; TrackSmith never treats its MIDI port as an AI control channel.

## Mackie HUI and HUI emulation

- HUI needs manual bidirectional MIDI setup. Apple explicitly does not support or guarantee
  unlisted third-party HUI emulations. Multiple-HUI devices require multiple configured
  instances; devices with only one DSP Edit section need `HUI Channel Strips only` for the
  extra instances, and Apple suggests the DM2000 profile for some DSP-display failures.
  Those workarounds demonstrate that protocol label and physical capability can diverge.
- Assignment state covers eight sends, pan/surround, input/output, strip format, automation,
  Flip, effect assignment/edit, and send-destination assignment. Several choices are staged:
  V-Select must confirm pan/I/O/send/effect choices, and unconfirmed send changes are lost
  on mode exit. `DEFAULT` changes V-Select from normal behavior to parameter reset.
- Strips arm, solo, mute, select/add selection, reset unity, adjust level, and expose momentary/
  peak meters. DSP controls insert/select/bypass effects and page parameters. HUI can enable
  or disable recording of volume, pan, plug-in, mute, and send automation and set selected or
  all strips to Read/Latch/Touch/Write/Off; group mode creates and edits group membership.
- It can Save/Save As, Undo/Redo/open history, choose tools, Cut/Copy/Paste/Delete, recall
  markers/screensets, generate independent keypad/operator input, enter folders/dialogs,
  open the destructive Audio File Editor (called `Sample Editor` in this older mapping), set
  locators/punch, toggle internal/external sync, Cycle/Autopunch, shuttle/scrub, and record.
  User-visible status LEDs and scribble strips remain partial, mode-dependent feedback.

Direct TrackSmith consequence: HUI instructions must specify whether the device is genuine
or emulated, configured instance and DSP section, ASSIGN/BYPASS/MUTE/DEFAULT/Flip state,
selected strip/slot/page, and whether a change is only staged. TrackSmith cannot emit HUI,
confirm staged routing, manipulate automation, or send keyboard/dialog operations.

## Mackie C4

- C4 adds 32 push encoders and can join another surface's group (adding mixer channels) or
  remain independent for simultaneous plug-in/instrument editing. Four rows change roles in
  Mixer versus Channel views and can split 8/24, 16/16, or 24/8 to edit two sections or two
  plug-ins; multiple C4s extend the split. Track Lock deliberately decouples C4 selection
  from the Tracks window.
- Views edit pan/eight surround parameters; strip volume/pan/format/I/O/automation/group;
  all eight EQ bands (auto-inserting Channel EQ on entry where applicable); eight send
  destinations/levels/positions/mutes; effect and instrument selection/insertion/bypass and
  32-parameter pages; Cycle and Autopunch. Channel Strip overlay combines parametric EQ,
  eight inserts, eight sends, instrument, output, automation, group, level, pan/diversity,
  and format on one surface.
- Marker/Track/Channel Strip/Function overlays radically change encoder identity. Eight
  user modes are freely assignable. Function overlay can move current/all track automation
  to regions and back, delete visible/all automation, select editing tools, move Cycle,
  quantize selected events, change plug-in/instrument setting, reset meters, and globally
  clear arm/solo/mute. These are project edits, not just parameter control.
- The function table labels V-Select 31 `Prev SetEXS` but says it executes *Next* setting,
  while V-Select 32 is labeled `Next` but executes *Previous*. Page 139 says OPTION with
  TRACK Left/Right reaches the first or last bank, yet its example says either direction
  shows the last eight. Direction must be tested. Split-mode LED descriptions also collapse
  several distinct multi-C4 splits to the same three-light state, so LEDs alone cannot
  reconstruct the split.

Direct TrackSmith consequence: C4 advice must carry group membership, split upper/lower,
view/overlay, track lock, channel, row, slot, and parameter page. Its broad automation,
quantization, routing, and insertion powers make it especially unsuitable as an untyped AI
bridge.

## Novation Launchpad family

- Seven documented models differ materially. Logic normally detects them, sets a 90-degree-
  right orientation so physical Scene buttons mirror the bottom of Live Loops, and allows
  grouped units to extend eight tracks/scenes or separate groups to operate independently.
  Scene and fader-bank offsets plus orientation decide which cell a pad addresses.
- Session pads trigger/stop momentary or latched cells and scenes, select cells on Pro, and
  encode queued/playing/recording/selected/stopped states with model-dependent color,
  flash, and pulse conventions. User mode sends MIDI notes to perform/record. Mixer modes
  arm, select, solo, mute, stop/start/record cells, set Sends 1-2 or 1-8, pan, and volume;
  older Launchpad/S/Mini do not support send/pan/volume modes.
- Launchpad Pro additionally toggles metronome; Undo/Redo; deletes; quantizes; duplicates;
  doubles/halves regions, cells, or events; and offers latch/momentary temporary mixer pages.
  Velocity/pressure changes the *rate* of send-level adjustment on Pro/X rather than directly
  denoting an absolute send level. Pressing a column cell in the basic Mixer view can reset
  send/volume to 0 dB or pan to center, distinct from entering the finer row mode.
- The setup prose says Logic sets Orientation to `90º Right`, then immediately says the user
  “can change” it to the same value. This is redundant/possibly an omitted alternative, so
  only the live icon/physical grid establishes orientation.

Direct TrackSmith consequence: Launchpad expertise must resolve exact model, orientation,
group/offset, Session/Mixer/User/temporary mode, pad coordinate, scene/track, and cell state.
Pad lights are queued playback/recording feedback, not proof of committed audio. TrackSmith
does not trigger cells, record performances, or mutate Live Loops through provider output.

## Radikal Technologies SAC-2K

- SAC-2K uses explicit bidirectional MIDI. Its Mute/Solo control cycles strip buttons among
  mute, solo, and record-enable; faders control volume or encoder assignments, and Master
  targets Master or falls back to Output 1-2. Pressing EQ inserts Channel EQ if needed.
- Twelve encoders and mode buttons edit pan/surround, all EQ bands, eight sends, 15 inserts,
  effect/instrument pages, format/I/O/automation/group, and selectable channel classes.
  Send destinations and effect choices are staged until the encoder push confirms them.
- Navigation buttons become reassignable computer arrows/numbers/Enter or Undo/Copy/Paste/
  Save. An eight-digit locator display compresses a Logic position that may need fourteen
  characters. Marker, Cycle, Replace, recording, transport, group, and Channel Edit modes
  add further state-dependent behavior.
- If the device is accidentally in Logic Control/HUI emulation, names truncate and mappings
  fail; PASSIVE mode can leave faders dead with `00000000`. Apple's remedy is a power cycle
  to reinitialize native communication. Protocol/mode must be diagnosed before production
  advice.

Direct TrackSmith consequence: SAC-2K guidance must name native/emulation/passive state,
Mute/Solo mode, view, encoder/slot/page, staged confirmation, bank, and truncated position.
Reassignable key equivalents and project mutation remain outside model authority.

## Recording Light

- Recording Light is an output-only behavioral role implemented as a manually installed
  control-surface plug-in plus user-supplied MIDI hardware. Logic sends configurable MIDI
  status/channel/data/value when any strip becomes record-ready and separately when
  recording begins, then an off message when arming/recording ends.
- Record-ready and actively recording are distinct triggers. The plug-in's suggested
  separate surface group, output port, message type, channel, Data 1 mappings, and On value
  must match the external device; its sign/light state is downstream feedback, not proof
  that Logic captured audio successfully.

Direct TrackSmith consequence: it may explain studio signaling but cannot infer capture
identity from the light or send its MIDI. TrackSmith's own commit/capture evidence remains
authoritative.

## Roland SI-24

- SI-24 is control-only in this integration and still needs another audio I/O device plus two
  dedicated bidirectional MIDI ports. Twelve strips switch STATUS buttons among automation,
  arm, solo, and mute; faders control level and Master controls Logic Master.
- Pan/EQ/Send/Plug-in/Instrument modes edit four EQ bands (auto-inserting Channel EQ),
  four send destinations/levels/mutes, insert selection and ten-parameter pages, instrument
  pages, pan, and surround. The joystick writes X/Y, while ON/OFF changes the selected
  strip's output between Surround and Output 1-2—not merely the panner display.
- AUTOMIX offers per-strip or all-track Off/Read/Latch/Write (no Touch in the listed cycle).
  Numeric modes save/Save As, Undo/Redo, cut/copy/paste/delete, create/delete/navigate
  markers, toggle scrub/Cycle/Autopunch, recall/lock screensets, open editors, and change
  track automation display. Transport records and scrubs.
- `Hyper Draw` and `Sample Editor` labels are legacy names in this mapping; current Logic
  surfaces are automation display and Audio File Editor. Literal old labels should not be
  mistaken for separate modern capabilities.

Direct TrackSmith consequence: SI-24 advice must state STATUS, channel class/bank,
Pan/EQ/Send/Plug-in/Instrument, SHIFT/numeric mode, output mode, and selected strip. Output
switching, auto-EQ insertion, automation, and destructive shortcuts remain user-authorized.

## Tascam US-2400

- USB US-2400 supports native and Mackie Control emulation. Apple recommends native
  because the physical layout differs and emulation loses controls such as the joystick.
  The guide says removing the native support plug-in from Logic's application bundle forces
  Mackie Control + two XT detection; modifying a signed application bundle is invasive,
  version-sensitive setup advice and must never be automated or treated as current best
  practice without direct signature/host validation.
- Twenty-four strips edit level, selection/additive selection, arm, solo, mute, eight sends,
  all eight EQ bands, pan, and six surround coordinates. Master selection/fader falls back to
  Output 1-2, global controls clear solo/mute/arm, and Flip/Swap/Zero mirror/swap encoders or
  disable motor noise.
- CHAN/PAN/AUX modes expose mixer, instrument, effect, and 24-parameter pages. F-KEY
  converts edit modes to instrument/effect/send assignment and several AUX buttons into
  editor windows. Plug-in view changes inserts/bypass; the meter mode repurposes 24 rings as
  peak/level feedback. Joystick writes X/Y or pan; NULL centers it.
- Jog/scrub/shuttle, banking, punch/cycle locators, independent arrow-key equivalents,
  play/stop/record, and modal SHIFT/F-KEY behavior mean the surface is both an editor and
  performance controller. Record is documented as a toggle rather than a simple start.

Direct TrackSmith consequence: instructions must first establish native versus emulated
profile, then CHAN/PAN/AUX/F-KEY/SHIFT, Flip, insert/page, bank, meter, and joystick state.
TrackSmith will not alter Logic's application bundle or drive US-2400 commands.

## Yamaha 01V96

- 01V96 requires current USB-MIDI driver, host routing `USB 1-2`, `General DAW` target, and
  REMOTE layer; Logic installs two horizontally grouped icons. Numerous starred DAW
  modifiers/functions must be manually assigned on the console, so the Apple table is a
  configuration recipe rather than proof of live keys.
- Display/Fader modes switch between 16-strip Channel, four-parameter Insert, and Meter
  views. Controls edit eight sends, pan/surround, input/output/format, effects and pages,
  automation, groups, level, and channel classes. AUX 6 changes buttons into default resets;
  AUX 8 changes SEL from channel selection to insert selection; HOME flips faders. Plug-in,
  send, input, and output choices may require ENTER confirmation.
- Assignable keys cover arm, group creation/edit/clutch, banking, reassignable keys, Undo/
  Redo/history, Save/Save As, tools, destructive Audio File Editor (`Sample Editor` label),
  scrub/shuttle, transport/record, locators/punch, external sync, and playback/recording of
  volume/pan/plug-in/mute/send automation. Automation keys can affect all strips or a
  selected strip/group depending on OPTION and stereo AUTO state.
- Page 184's SHIFT behavior for `DAW CREATE GROUP` says the channel strips on the
  *DM1000* reflect All view, an obvious cross-device copy inside the 01V96 chapter. The
  automation table also has a nonintuitive offset: OPTION with labels WRITE/TOUCH/LATCH/
  READ selects Touch/Latch/Read or all-Write respectively. It may reflect the manual key
  assignment layout, but needs live validation before instruction.

Direct TrackSmith consequence: 01V96 guidance must capture console USB/target/layer,
both Logic device icons/group, user-assigned starred keys, display/fader/AUX mode, channel,
slot/page, confirmation, and automation scope. No model may send console commands or assume
Apple's nominal key recipe is installed.

## Yamaha 02R96

- 02R96 setup uses current USB driver, `USB 1-2`, `General DAW`, and REMOTE layer; Logic
  creates three horizontally aligned device icons. AUX/encoder/fader modes edit sends,
  pan/surround, strip/plug-in selection and four-parameter pages, level, channel selection,
  and Flip. The console has separate Insert, Channel, and Meter display views.
- User-defined keys set selected strip/group automation modes, enable recording/playback of
  volume/mute/pan/send/plug-in automation, bank, switch Mixer/Tracks, and clutch groups.
  Machine controls recall markers, shuttle, play/stop/record; data controls scrub, enter/exit
  folders, emulate arrows, zoom, and change the selected parameter. Effects and I/O choices
  use explicit encoder/ENTER confirmation.
- EFFECT `Display` opens the destructive Audio File Editor under the legacy `Sample Editor`
  name. Page 193 maps both Cursor Up and Cursor Down in Zoom mode to “zooms out vertically,”
  while Left/Right correctly oppose one another; Up is likely a copy error, but only a live
  trace establishes direction.

Direct TrackSmith consequence: instructions require all three installed icons/group,
console target/layer, F2/F3/F4 view, AUX/Flip/insert state, strip, page, and confirmation.
Marker, automation, recording, editor, and folder actions remain user-controlled.

## Yamaha DM1000

- DM1000 setup uses USB MIDI `1-3`, `General DAW`, REMOTE 1/layer, current driver, and
  yields two horizontally aligned Logic icons. Starred DAW modifiers/keys are user-assigned
  prerequisites. Two icons do not imply only two USB ports or a single console bank.
- Its 16-strip Insert/Channel/Meter displays and AUX/Encoder/Fader modes edit eight sends,
  pan/surround, I/O, effects and four-parameter pages, automation, groups, and level. AUX 6
  turns controls into default resets; AUX 8 plus stereo AUTO determines selection versus
  insert/automation duties; choices may require encoder/ENTER confirmation.
- Assignable keys cover group creation/clutch, strip classes/banking, full/fine values,
  Undo/Redo/history, Save/Save As, tools, destructive Audio File Editor (`Sample Editor`),
  transport/record, punch/locators/Autopunch, external sync, and per-class automation
  enable. Automation modes cleanly distinguish selected strip/group from OPTION-all for
  Write/Touch/Latch/Read/Off; Trim is unassigned.
- The source contains obvious typographic corruption (`tıhe`, `aıs`) but the surrounding
  mapping remains intelligible. Such payload defects are retained in provenance and not
  normalized into purported exact control labels.

Direct TrackSmith consequence: DM1000 advice must state USB/REMOTE configuration, both
icons/group, manually assigned DAW keys, F2/F3/F4 view, AUX/AUTO/Flip state, strip/slot/page,
and confirmation. Its console is neither TrackSmith authority nor an audio-evidence source.

## Yamaha DM2000

- DM2000 setup uses USB MIDI `1-3`, `General DAW`, REMOTE 1/layer, current driver, and
  three horizontally aligned Logic icons. USER 4/5/13 modifiers and other starred actions
  depend on the console's user-defined assignments; the physical label often bears no
  relation to the resulting Logic command.
- MATRIX, AUX, Encoder/Fader, Insert, and display modes control default reset, send position/
  mute, strip versus insert selection/bypass, eight sends, pan/surround, input/output, staged
  send destination, Flip, plug-in insertion/edit, four-parameter pages, and groups. ASSIGN 3
  or encoder press confirms send destinations; plugin choice uses virtual encoder/ENTER.
- Twenty-four Track Arming buttons and MASTER can arm/clear strips. AUTOMIX controls map
  hardware `REC`, `ABORT/UNDO`, `AUTOREC`, `RETURN`, and `TOUCH SENSE` labels to Logic
  Write, Touch, Latch, Read, and Off, with USER 5 applying to all strips. OVERWRITE keys
  enable volume/pan/plug-in/mute/send automation recording. This label translation must be
  stated explicitly to avoid destructive mistakes.
- Locator/transport/cursor and USER keys recall markers, select tools, set punch/cycle
  positions, external sync and Autopunch, record, scrub/shuttle, enter/exit folders, scroll/
  zoom, group/clutch, full/fine values, Undo/Redo/history, Save/Save As, and windows. The
  Effect Display opens the destructive Audio File Editor under its legacy name.
- MATRIX 1's description says its reset behavior applies “when AUX 6 is held,” copied from
  the smaller Yamaha mappings even though this chapter assigns the behavior to MATRIX 1.
  Pages 215-216 again assign both Cursor Up and Down to vertical zoom-out, repeating the
  02R96 error. Live DM2000 verification is needed rather than silently repairing either.

Direct TrackSmith consequence: DM2000 instructions must resolve all three icons/group,
console USB/target/layer, USER assignments, MATRIX/AUX/ASSIGN/Flip/Insert/display mode,
selected strip/slot/page, confirmation, and automation scope. The misleading physical
AUTOMIX labels make untyped provider control especially unsafe.

## Rights and coverage closure

- Page 220 permits an owner or authorized Logic user to reproduce the publication for
  learning, while prohibiting commercial reproduction/transmission such as selling copies
  or paid-support redistribution. The PDF remains immutable local-use-only research; this
  atlas is TrackSmith's original synthesis, not a redistributed manual.
- Every page and named device family in this guide is now `Deep`. This establishes documented
  default mappings and their prerequisites, limitations, copy errors, and cross-consent
  behavior. It does not prove any device is attached, supported by the current macOS driver,
  on expected firmware, using the stated profile, or unmodified by user/manufacturer maps.
- TrackSmith can now answer device-aware questions and explain manual workflows. It still
  receives no control-surface authority. A future adapter would require authenticated local
  transport, explicit opt-in, live device/profile/firmware/group/mode capture, stable Logic
  object identity, typed allowlisted operations, stale-result rejection, confirmation for
  host changes, and independent audit/rollback evidence.
