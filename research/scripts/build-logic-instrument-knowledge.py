#!/usr/bin/env python3
"""Build TrackSmith's reviewed Logic 12.3 instrument advisory catalog.

The curated instrument atlas is the human-auditable synthesis. This generator
contains only TrackSmith-authored summaries of the reviewed Apple manual. The
generated entries can explain an explicitly named Logic instrument but cannot
become DSP, MIDI, automation, or host-control authority.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[2]
ATLAS = ROOT / "research/analysis/TRACKSMITH_LOGIC_PRO_12_3_INSTRUMENT_ATLAS.md"
JSON_OUTPUT = ROOT / "research/knowledge/logic-pro-12.3-instrument-knowledge.json"
SWIFT_OUTPUT = (
    ROOT
    / "packages/ProductionIntelligence/Sources/ProductionIntelligence/LogicNativeInstrumentKnowledge.generated.swift"
)
INSTRUMENTS_SHA256 = "fc867e61b1bbcfc16d4ba98058f7cde104ec17e0649026769c308cff07049ab4"
LOGIC_ARCHIVE = ROOT / "research/papers/tracksmith-logic-12.3-archive"
QUICK_SAMPLER_RESOURCE_IDS = (
    "apple-logic-pro-12.3-quick-sampler-overview",
    "apple-logic-pro-12.3-quick-sampler-add-audio",
    "apple-logic-pro-12.3-quick-sampler-choose-mode",
    "apple-logic-pro-12.3-quick-sampler-classic-mode",
    "apple-logic-pro-12.3-quick-sampler-one-shot-mode",
    "apple-logic-pro-12.3-quick-sampler-slice-mode",
    "apple-logic-pro-12.3-quick-sampler-recorder-mode",
    "apple-logic-pro-12.3-quick-sampler-waveform-display",
    "apple-logic-pro-12.3-quick-sampler-flex",
    "apple-logic-pro-12.3-quick-sampler-mod-matrix",
    "apple-logic-pro-12.3-quick-sampler-lfo",
    "apple-logic-pro-12.3-quick-sampler-pitch",
    "apple-logic-pro-12.3-quick-sampler-filter",
    "apple-logic-pro-12.3-quick-sampler-filter-types",
    "apple-logic-pro-12.3-quick-sampler-amp",
    "apple-logic-pro-12.3-quick-sampler-extended",
)
EXPECTED_ENTRY_COUNT = 28


def entry(
    name: str,
    family: str,
    pages: str,
    aliases: tuple[str, ...],
    sources: tuple[str, ...],
    tags: tuple[str, ...],
    mechanism: str,
    consequence: str,
) -> dict[str, object]:
    return {
        "name": name,
        "family": family,
        "manualPages": pages,
        "aliases": list(aliases),
        "applicableSourceTypes": list(sources),
        "semanticTags": list(tags),
        "documentedMechanism": mechanism,
        "productionConsequence": consequence,
    }


SYNTH = ("keyboard", "synth")
DRUM = ("drums", "drumBus", "keyboard", "synth")
ALL_RECORDED = (
    "vocal", "vocalBus", "drums", "drumBus", "bass", "guitar", "keyboard", "synth", "fullMix"
)

ENTRIES = [
    entry(
        "Alchemy", "hybrid_synth", "17-183", ("alchemy synth",), SYNTH,
        ("warm", "bright", "dark", "wide", "vintage", "modern", "raw"),
        "Four-source hybrid instrument combining additive, spectral, granular, sampler, and virtual-analog elements with source/main filters, five effect racks, deep modulation, morphing, Transform Pad states, and arpeggiation.",
        "Morphing is not a crossfade, and import mode, warp alignment, routing, per-voice processing, random state, and referenced assets can all change the result. A request must identify synthesis, performance, effects, or downstream mix scope.",
    ),
    entry(
        "Drum Kit Designer", "drum_instrument", "184-190", ("dkd", "logic drum kit designer"), DRUM,
        ("punchy", "tight", "raw", "polished", "controlled", "dynamic"),
        "Sampled acoustic drum and percussion kits with per-piece tune, damping, and gain; multi-channel kits add microphone leak, overhead, room, piece exchange, and separate outputs.",
        "Tightness, punch, size, and realism can come from piece sustain, room/overhead balance, microphone bleed, performance, individual outputs, or bus processing. Those scopes are not interchangeable.",
    ),
    entry(
        "Drum Machine Designer", "drum_instrument", "191-203", ("dmd", "drum machine designer pads"), DRUM,
        ("punchy", "tight", "raw", "modern", "energetic", "wide"),
        "A track-stack meta-instrument whose pads can own instruments, channel strips, effects, input/output note mappings, choke groups, layers, and resampled paths.",
        "A pad edit, subtrack edit, main-stack bus edit, resample, note remap, and kit reordering operation affect different state. TrackSmith must not call this one ordinary plug-in or imply host authority over its subtracks.",
    ),
    entry(
        "Drum Synth", "drum_instrument", "204-208", ("logic drum synth",), DRUM,
        ("punchy", "tight", "aggressive", "soft", "boomy", "modern"),
        "Model-selectable synthesized kick, snare/clap, percussion, and hat/cymbal voices with context-dependent macro controls plus key tracking and mono/poly/gate behavior.",
        "Labels such as Body, Punch, Snap, Material, Crush, Dirt, and Metallic are instrument-specific macros, not universal acoustic quantities. Model choice and note behavior must be known before recommending a control.",
    ),
    entry(
        "ES1", "subtractive_synth", "209-221", ("es 1",), SYNTH,
        ("warm", "bright", "dark", "vintage", "aggressive", "soft"),
        "One-primary-plus-sub/noise/external-source subtractive synth with multiple low-pass slopes, self-oscillating resonance, filter drive/boost, selectable amplifier-envelope behavior, and controlled analog variation.",
        "Filter drive, boost, resonance, oscillator phase, Analog variation, and envelope mode affect attack and repeatability as well as tone. Output matching is required when comparing gain-stage changes.",
    ),
    entry(
        "ES2", "hybrid_synth", "222-289", ("es 2",), SYNTH,
        ("warm", "bright", "dark", "wide", "aggressive", "vintage", "modern"),
        "Three-oscillator synth with Digiwaves, FM, sync, ring modulation, noise, serial/parallel dual filters, a ten-lane modulation router, Planar Pad, and looping Vector Envelope.",
        "Filter Blend changes routing and overdrive topology; per-voice drive differs from post-sum distortion. Oscillator start, vector loops, release mode, randomization, and unison affect repeatability, chord clarity, and mono behavior.",
    ),
    entry(
        "EFM1", "fm_synth", "290-298", ("efm 1", "logic fm synth"), SYNTH,
        ("bright", "aggressive", "soft", "wide", "modern", "vintage"),
        "Sixteen-voice two-operator-style FM instrument with multiwave modulator, sine carrier, modulation and output envelopes, sine sub-oscillator, unison, and stereo detune.",
        "Carrier/modulator ratios and time-varying FM depth govern harmonic versus inharmonic spectra. Stereo detune can add width but Apple explicitly warns about mono compatibility.",
    ),
    entry(
        "ES E", "compact_synth", "299-303", ("ese", "es-e"), SYNTH,
        ("soft", "smooth", "wide", "vintage", "warm"),
        "Eight-voice ensemble/pad synth with saw-to-pulse oscillator, vibrato/PWM, low-pass filter, shared AR envelope, and chorus/ensemble variants.",
        "Its concise controls couple performance envelope and tone; chorus or ensemble width can soften pitch focus and mono stability. The macro interface does not disclose an exact circuit.",
    ),
    entry(
        "ES M", "compact_synth", "304-307", ("esm", "es-m"), SYNTH,
        ("tight", "boomy", "warm", "aggressive", "vintage"),
        "Monophonic bass-oriented synth with saw/sub-rectangle blend, fingered portamento, resonant 24 dB/octave low-pass filtering, simple decay envelopes, and output overdrive.",
        "Portamento, resonance compensation, decay, sub balance, and overdrive affect definition and low-end weight differently. A tighter result is not necessarily more compression.",
    ),
    entry(
        "ES P", "compact_synth", "308-313", ("esp", "es-p"), SYNTH,
        ("warm", "bright", "punchy", "wide", "vintage", "aggressive"),
        "Eight-voice poly synth mixing triangle, saw, rectangle, two sub-octaves, and noise through a key-following low-pass filter, shared ADSR, chorus, and overdrive.",
        "Oscillator/sub/noise balance, key follow, envelope, chorus, and overdrive address different causes of body, attack, brightness, or width; their interactions must be auditioned across the played range.",
    ),
    entry(
        "EVOC 20 PolySynth", "vocoder_synth", "314-332", ("evoc", "evoc 20 ps", "logic vocoder"), SYNTH,
        ("clear", "aggressive", "smooth", "modern", "vintage", "airy"),
        "Twenty-band analysis/synthesis vocoder with side-chain analysis, MIDI-played synthesis, envelope followers, voiced/unvoiced handling, formant shift/stretch, and resonance.",
        "Intelligibility depends on overlapping analysis/synthesis energy and attack/release behavior. More bands are not automatically better; gating, compression, EQ, sensitivity, and formant moves can also raise noise or smear articulation.",
    ),
    entry(
        "Quick Sampler", "sample_instrument", "Logic 12.3 live guide: lgcp5af33756-lgcp3df3cd4a", ("quick sampler", "q-sampler", "q sampler"), ALL_RECORDED,
        ("raw", "polished", "tight", "punchy", "modern", "wide", "dynamic"),
        "Single-file sampler and recorder with Original or Optimized import, Classic, One Shot, Slice, and Recorder modes, editable sample/loop/fade/crossfade/slice markers, Flex playback, dedicated pitch/filter/amp envelopes, two LFOs, a four-route modulation matrix, and voice/MIDI Mono controls.",
        "A region drop is bounced through its track processing while a file drop is not. Optimized import can retune, change gain, crop silence, and create loop/crossfade state; rename and write-loop commands explicitly reach file identity/header state, while crop's complete underlying-file consequence still needs a disposable-copy test. Mode, gate, Flex, voice allocation, modulation, and source-file identity must be preserved, and Apple's analysis/filter internals remain undocumented.",
    ),
    entry(
        "Retro Synth", "multi_engine_synth", "333-349", ("logic retro synth",), SYNTH,
        ("warm", "bright", "dark", "wide", "vintage", "modern", "aggressive"),
        "Four mutually exclusive Analog, Sync, Table, and FM engines sharing downstream filter, amplifier, envelope, modulation, unison, MPE, and controller architecture.",
        "Engine choice changes the sound-generation hypothesis. Custom wavetable analysis is source-dependent, filter-style adjectives are not measured responses, and voice spread/unison must be checked with phase, polyphony, and mono compatibility.",
    ),
    entry(
        "Sample Alchemy", "sample_resynthesis", "350-374", ("samplealchemy", "sample alchemy"), ALL_RECORDED,
        ("raw", "modern", "wide", "energetic", "aggressive", "airy", "dark"),
        "Transforms one sample into up to four granular, additive, or spectral sources with multiple traversal modes, handle-motion recording, source/global filters, downsampling, FM, and effects.",
        "Classic, Loop, Scrub, Bow, Arp, and Motion are performance behaviors, not presets of one algorithm. Granular random time, resynthesis, handle paths, and the built-in limiter change repeatability and identity; its Downsampler does not establish bit-depth reduction.",
    ),
    entry(
        "Sampler", "sample_instrument", "375-463", ("logic sampler", "exs24 replacement"), ALL_RECORDED,
        ("raw", "polished", "tight", "wide", "dynamic", "modern"),
        "Zone/group sample instrument with mapping, key/velocity/controller conditions, round robin, articulation and trigger rules, per-zone/group synthesis, filters, modulation, envelopes, LFOs, pitch/time processing, and effects.",
        "A Sampler sound includes assets, mapping, trigger logic, release behavior, controller state, modulation, and processing. Analysis-assisted mapping and flex/pitch modes are source-dependent; a saved setting does not by itself prove portable audio assets.",
    ),
    entry(
        "Sculpture", "physical_model_synth", "464-550", ("sculpture synth", "logic physical modeling"), SYNTH,
        ("warm", "bright", "dark", "raw", "wide", "dynamic", "vintage"),
        "Component-model instrument with an exciter/disturber/damper acting on a virtual string, movable pickups, material morphing, nonlinear waveshaping, body EQ, delay, modulation, Morph Pad, and envelope recording.",
        "Object type/position, material, string state, pickup geometry and phase, note history, CPU quality, morph motion, and random modulation can all alter the result. Physical labels are model controls, not proof of a literal instrument or deterministic repeat.",
    ),
    entry(
        "Studio Bass", "sampled_performance_instrument", "551-557", ("logic studio bass",), ("bass", "keyboard", "synth"),
        ("tight", "boomy", "punchy", "raw", "controlled", "lowEndWeight"),
        "Multisampled electric and upright basses with playing styles, articulations, string/fret selection, release/handling noise, muting, transient definition, pickups, and mono/poly/string voice modes.",
        "The same pitch changes timbre by string and position. Tightness may mean performance articulation, mute/release/noise, transient definition, string choice, or downstream processing rather than a fixed low-frequency or compressor move.",
    ),
    entry(
        "Studio Horns", "sampled_performance_instrument", "558-564", ("logic studio horns",), SYNTH,
        ("forward", "soft", "energetic", "polished", "raw", "dynamic"),
        "Solo/section sampled horns with articulations, controller dynamics, attack/release, vibrato, legato and release transitions, authentic/extended range, per-player MIDI channels, and automatic voice splitting.",
        "Voicing, range, articulation, dynamic-controller mode, humanization, and transition timing are performance or arrangement decisions. Tone processing cannot substitute for an incorrect player split or articulation.",
    ),
    entry(
        "Studio Piano", "sampled_performance_instrument", "565-566", ("logic studio piano",), SYNTH,
        ("intimate", "distant", "warm", "bright", "wide", "raw", "polished"),
        "Sampled piano blending two stereo microphone pairs and a mono ribbon path with pedal/key noise, release samples, and sympathetic resonance.",
        "Microphone blend changes perspective, spectrum, phase, and width; mechanism noise and resonance change realism and density. Pedaling, register, note density, release behavior, and mono translation remain decisive.",
    ),
    entry(
        "Studio Strings", "sampled_performance_instrument", "567-572", ("logic studio strings",), SYNTH,
        ("intimate", "distant", "soft", "energetic", "polished", "raw", "dynamic"),
        "Solo/section sampled strings with articulations, controller dynamics, attack/release, vibrato, legato and release transitions, authentic/extended range, per-player MIDI channels, and automatic voice splitting.",
        "Voice allocation, articulation, dynamics mode, range, transition samples, and release behavior determine realism and energy before downstream tone processing. Humanized or expressive variation must not be mistaken for a defect automatically.",
    ),
    entry(
        "Ultrabeat", "drum_synth_sampler", "573-638", ("ultra beat",), DRUM,
        ("punchy", "tight", "aggressive", "raw", "modern", "energetic", "boomy"),
        "Twenty-five independent drum synthesizers with mixer/output routing, up to 24 patterns, per-sound sequences, phase-distortion/FM/sample/string/noise/ring sources, reversible filter/distortion order, modulation, step automation, and randomization.",
        "Voice, sequence, mixer, routing, and referenced sample state are distinct. Crush is not the standalone Bitcrusher; free LFOs and randomization affect repeatability; exported patterns can double-trigger if the internal sequencer remains active.",
    ),
    entry(
        "External Instrument", "instrument_utility", "639-641", ("logic external instrument",), SYNTH,
        ("raw", "vintage", "modern", "dynamic"),
        "Unifies an external MIDI destination/channel, return-audio input, gain, optional reported-latency compensation, and bank/program transmission.",
        "Hardware must bounce in real time and recalled state can transmit program/bank changes. External routing, latency, device state, and MIDI mutation remain outside TrackSmith's current authority.",
    ),
    entry(
        "Klopfgeist", "instrument_utility", "641-642", ("logic click instrument", "metronome instrument"), ("drums", "keyboard", "synth"),
        ("bright", "dark", "soft", "punchy"),
        "Mono/four-voice click instrument with pitch, detune, tonality, damping, and velocity-scaled level.",
        "A cue or recording click is not automatically desired mix material. Routing and intent must be established before analyzing or processing it as part of the production.",
    ),
    entry(
        "Vintage B3 Organ", "modeled_keyboard", "643-678", ("logic vintage b3", "logic b3 organ"), SYNTH,
        ("warm", "vintage", "aggressive", "wide", "raw", "smooth"),
        "Tonewheel-organ model with drawbars, key click, leakage/crosstalk/condition controls, percussion, scanner vibrato, rotor cabinet, effects routing, pedals, splits, and performance mappings.",
        "Registration, percussion retriggering, scanner/rotor motion, drawbar harmonic interactions, leakage, click, distortion order, and random aging all affect sound. Slow/Fast/Brake is a performance gesture, not one static width setting.",
    ),
    entry(
        "Vintage Clav", "modeled_keyboard", "679-695", ("logic vintage clav", "logic clav"), SYNTH,
        ("punchy", "aggressive", "warm", "bright", "raw", "vintage", "pickAttack"),
        "Component model of string, hammer and pickup behavior with movable/angled/wired pickups, damping, stiffness, inharmonicity, tension, click/noise, stereo spreading, and reorderable compressor/distortion/modulation/wah effects.",
        "Pickup geometry and polarity can create cancellation or silent zones. Bite, attack, width, and vintage character may come from excitation, pickup, damping, phase, or effect order rather than simple EQ.",
    ),
    entry(
        "Vintage Electric Piano", "modeled_keyboard", "696-706", ("logic vintage electric piano", "logic vintage ep"), SYNTH,
        ("warm", "bright", "smooth", "punchy", "vintage", "wide", "raw"),
        "Component model spanning tine, reed, tone-bar, pickup, hammer/damper, decay/noise, Drive-first processing, model-dependent post-drive EQ, chorus, phaser, and tremolo.",
        "Drive Tone changes what reaches the nonlinearity while EQ follows it. Bell, decay, release, damper noise, velocity timing, warmth randomization, stretch tuning, and stereo behavior affect performance and tuning beyond static tone.",
    ),
    entry(
        "Vintage Mellotron", "sampled_keyboard", "707-709", ("logic vintage mellotron", "logic mellotron"), SYNTH,
        ("warm", "dark", "bright", "vintage", "raw", "smooth"),
        "Sampled note-by-note tape character with indefinite looping, two-sound blend, independent octave shifts, Tape Speed, Tone, attack/release, pitch bend, and velocity response.",
        "Logic extends the original hardware's duration and performance controls. An authenticity request must specify which tape irregularity or historical limitation should be preserved versus intentionally relaxed.",
    ),
    entry(
        "Legacy instruments", "legacy_instrument_family", "710-721", ("garageband legacy instruments", "logic legacy instruments"), ALL_RECORDED,
        ("vintage", "raw", "warm", "bright", "dark", "modern"),
        "Compatibility-focused lower-resource instrument variants hidden unless the insert menu is Option-opened, including emulated-instrument and simplified synthesizer families.",
        "Their macros do not disclose exact underlying mappings and shared names do not prove parameter equivalence. Apple recommends replacing legacy External Instrument with the current one, but TrackSmith has no authority to perform that host mutation.",
    ),
]


def slug(value: str) -> str:
    result = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    if not result:
        raise SystemExit(f"could not create identifier for {value!r}")
    return result


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def swift_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def quick_sampler_sources() -> list[dict[str, object]]:
    sources = []
    for resource_id in QUICK_SAMPLER_RESOURCE_IDS:
        path = LOGIC_ARCHIVE / "manifests/current" / f"{resource_id}.json"
        if not path.is_file():
            raise SystemExit(f"missing accepted Quick Sampler source manifest: {path}")
        record = json.loads(path.read_text(encoding="utf-8"))
        if record.get("resourceID") != resource_id:
            raise SystemExit(f"Quick Sampler source identity mismatch: {path}")
        if record.get("captureStatus") not in {"accepted", "duplicate"} or record.get("qualityStatus") != "validated":
            raise SystemExit(f"Quick Sampler source is not validated: {path}")
        digest = str(record.get("sha256", ""))
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise SystemExit(f"Quick Sampler source has invalid SHA-256: {path}")
        sources.append({
            "resourceID": resource_id,
            "title": record["title"],
            "canonicalURL": record["canonicalURL"],
            "sourceVersion": record["sourceVersion"],
            "sha256": digest,
            "reviewStatus": "deep_full_relevant_section_read",
            "localUseOnly": True,
        })
    if len({source["sha256"] for source in sources}) != len(QUICK_SAMPLER_RESOURCE_IDS):
        raise SystemExit("Quick Sampler supplemental payloads are not uniquely identified")
    return sources


def write_swift(entries: list[dict[str, object]], supplemental_sources: list[dict[str, object]]) -> None:
    lines = [
        "// Generated by research/scripts/build-logic-instrument-knowledge.py.",
        "// Do not edit by hand; edit the reviewed atlas or generator instead.",
        "",
        "import AgentCore",
        "import PlanSchema",
        "",
        "extension LogicNativeInstrumentKnowledgeCatalog {",
        "    public static let logicPro12_3 = LogicNativeInstrumentKnowledgeCatalog(",
        f"        sourceSHA256: {swift_string(INSTRUMENTS_SHA256)},",
        "        supplementalSourceSHA256s: [",
    ]
    for source in supplemental_sources:
        lines.append(f"            {swift_string(str(source['sha256']))},")
    lines.extend([
        "        ],",
        "        reviewStatus: .deepFullRelevantSectionRead,",
        "        entries: [",
    ])
    for item in entries:
        aliases = ", ".join(swift_string(value) for value in item["aliases"])
        sources = ", ".join(f".{value}" for value in item["applicableSourceTypes"])
        tags = ", ".join(f".{value}" for value in item["semanticTags"])
        lines.extend([
            "            .init(",
            f"                identifier: {swift_string(str(item['identifier']))},",
            f"                name: {swift_string(str(item['name']))},",
            f"                family: {swift_string(str(item['family']))},",
            f"                manualPages: {swift_string(str(item['manualPages']))},",
            f"                aliases: [{aliases}],",
            f"                applicableSourceTypes: [{sources}],",
            f"                semanticTags: [{tags}],",
            f"                documentedMechanism: {swift_string(str(item['documentedMechanism']))},",
            f"                productionConsequence: {swift_string(str(item['productionConsequence']))}",
            "            ),",
        ])
    lines.extend(["        ]", "    )", "}", ""])
    SWIFT_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    SWIFT_OUTPUT.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    if not ATLAS.is_file():
        raise SystemExit(f"missing reviewed atlas: {ATLAS}")
    if len(ENTRIES) != EXPECTED_ENTRY_COUNT:
        raise SystemExit(f"expected {EXPECTED_ENTRY_COUNT} entries, found {len(ENTRIES)}")
    names = [str(item["name"]) for item in ENTRIES]
    if len(names) != len(set(names)):
        raise SystemExit("duplicate instrument name")

    supplemental_sources = quick_sampler_sources()
    entries = []
    for source in ENTRIES:
        item = dict(source)
        item["identifier"] = f"logic-pro-12.3-instrument:{slug(str(item['name']))}"
        item["reviewStatus"] = "deep_full_relevant_section_read"
        item["mechanismEvidenceClass"] = "apple_documented_behavior"
        item["productionConsequenceEvidenceClass"] = (
            "derived_technical_interpretation_and_professional_practice_heuristic"
        )
        item["executionBoundary"] = "advisory_only_logic_native_tool_no_tracksmith_execution_authority"
        item["subjectiveListeningDecisive"] = True
        entries.append(item)
    entries.sort(key=lambda value: (str(value["family"]), str(value["name"]).casefold()))

    payload = {
        "schemaVersion": "1.0",
        "product": "TrackSmith",
        "logicVersionContext": "Logic Pro for Mac 12.3 selected in Apple's live guide at retrieval",
        "knowledgeStatus": "deep_reviewed_advisory_knowledge_not_execution_authority",
        "source": {
            "identity": "Apple, Logic Pro Instruments for Mac",
            "pageCount": 752,
            "sha256": INSTRUMENTS_SHA256,
            "reviewCompletedDate": "2026-07-15",
            "fullRelevantContentRead": True,
            "localUseOnly": True,
            "redistributionRightsInferred": False,
        },
        "supplementalSources": {
            "identity": "Apple Logic Pro for Mac 12.3 live Quick Sampler guide chapter",
            "reason": "The 752-page Instruments PDF names Quick Sampler but omits the standalone chapter present in Apple's live Logic 12.3 table of contents.",
            "reviewCompletedDate": "2026-07-16",
            "fullRelevantContentRead": True,
            "entries": supplemental_sources,
        },
        "atlas": {
            "relativePath": str(ATLAS.relative_to(ROOT)),
            "sha256": sha256(ATLAS),
        },
        "retrievalContract": {
            "explicitInstrumentReferenceRequired": True,
            "genericRecordedSourceMustNotInferGeneratingInstrument": True,
        },
        "safetyContract": {
            "mayExplainNamedInstrument": True,
            "mayBecomeProcessingNode": False,
            "mayEmitMIDI": False,
            "mayEmitAutomation": False,
            "mayControlLogicProject": False,
            "mustLeaveSubjectivePreferenceToListening": True,
        },
        "entryCount": len(entries),
        "entries": entries,
    }
    JSON_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    JSON_OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_swift(entries, supplemental_sources)
    print(f"wrote {len(entries)} reviewed instrument entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
