#!/usr/bin/env python3
"""Build TrackSmith's reviewed Logic 12.3 effects knowledge catalogue.

The curated atlas is the human-auditable source. This generator extracts only
TrackSmith-authored synthesis, never Apple's copyrighted manual prose. Every
entry is explicitly advisory-only: it cannot be decoded as a ProcessingNode or
used as authority to control a Logic-native plug-in.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
from dataclasses import dataclass


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_ATLAS = ROOT / "research/analysis/TRACKSMITH_LOGIC_PRO_12_3_TOOL_ATLAS.md"
DEFAULT_OUTPUT = ROOT / "research/knowledge/logic-pro-12.3-effects-knowledge.json"
EVIDENCE_ROOT = ROOT / "research/evaluation/logic-native-empirical-runs"
DEFAULT_SWIFT_OUTPUT = (
    ROOT
    / "packages/ProductionIntelligence/Sources/ProductionIntelligence/LogicNativeToolKnowledge.generated.swift"
)
EFFECTS_SHA256 = "b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819"
EXPECTED_ENTRY_COUNT = 142

ALL_PRODUCTION_SOURCES = (
    "vocal",
    "vocalBus",
    "drums",
    "drumBus",
    "bass",
    "guitar",
    "keyboard",
    "synth",
    "fullMix",
)

FAMILY_SOURCE_TYPES = {
    "amp": ("vocal", "drums", "drumBus", "bass", "guitar", "keyboard", "synth"),
    "imaging": ("drumBus", "guitar", "keyboard", "synth", "fullMix"),
    "mastering": ("fullMix",),
    "midi_processor": ("keyboard", "synth"),
    "pitch": ("vocal", "bass", "guitar", "keyboard", "synth"),
}

FAMILY_SEMANTIC_TAGS = {
    "amp": ("warm", "aggressive", "raw", "vintage", "modern", "clear", "punchy"),
    "delay": ("intimate", "distant", "wide", "clear", "energetic"),
    "distortion": ("warm", "aggressive", "raw", "vintage", "modern", "harsh", "smooth"),
    "dynamics": ("controlled", "dynamic", "punchy", "smooth", "aggressive", "soft"),
    "equalizer": ("warm", "bright", "dark", "clear", "muddy", "boxy", "harsh", "airy", "thin", "boomy", "tight", "smooth"),
    "filter": ("warm", "bright", "dark", "clear", "harsh", "aggressive", "energetic"),
    "imaging": ("wide", "narrow", "monoCompatibility", "clear"),
    "legacy": ("warm", "bright", "dark", "clear", "harsh", "vintage", "controlled", "dynamic"),
    "mastering": ("polished", "controlled", "dynamic", "energetic", "modern", "warm", "clear", "wide"),
    "metering": ("controlled", "dynamic", "wide", "monoCompatibility"),
    "midi_processor": ("energetic", "punchy", "dynamic", "raw", "modern"),
    "modulation": ("wide", "vintage", "modern", "smooth", "energetic", "intimate", "distant"),
    "multi_effect": ("energetic", "aggressive", "punchy", "wide", "raw", "modern"),
    "pedalboard": ("warm", "aggressive", "raw", "vintage", "modern", "wide", "punchy"),
    "pedalboard_delay_ambience": ("intimate", "distant", "wide", "clear"),
    "pedalboard_distortion": ("warm", "aggressive", "raw", "vintage", "modern", "harsh", "smooth"),
    "pedalboard_dynamics_filter": ("controlled", "dynamic", "punchy", "warm", "bright", "dark", "harsh"),
    "pedalboard_modulation": ("wide", "vintage", "modern", "smooth", "energetic"),
    "pedalboard_pitch": ("aggressive", "raw", "modern", "boomy", "lowEndWeight"),
    "pedalboard_utility": ("wide", "narrow", "monoCompatibility", "tight"),
    "pitch": ("polished", "intimate", "raw", "modern", "controlled", "dynamic"),
    "reverb": ("intimate", "distant", "wide", "narrow", "clear", "warm", "dark", "bright"),
    "specialized": ("airy", "bright", "harsh", "boomy", "lowEndWeight", "thin", "tight"),
    "utility": (),
}

TOOL_SEMANTIC_TAGS = {
    "Bitcrusher": ("raw", "aggressive", "vintage", "bright", "dark", "harsh"),
    "Blue Echo": ("distant", "energetic", "vintage", "clear"),
    "Spring Box": ("distant", "intimate", "bright", "dark", "vintage"),
    "Tie Dye Delay": ("distant", "energetic", "raw", "modern"),
    "Tru-Tape Delay": ("warm", "dark", "vintage", "raw", "distant", "smooth"),
    "Candy Fuzz": ("bright", "aggressive", "raw", "harsh"),
    "Double Dragon": ("warm", "aggressive", "controlled", "punchy", "raw"),
    "Fuzz Machine": ("bright", "thin", "aggressive", "raw", "vintage"),
    "Grinder": ("aggressive", "harsh", "raw", "modern", "thin"),
    "Grit": ("aggressive", "harsh", "raw", "modern"),
    "Happy Face Fuzz": ("warm", "smooth", "raw", "vintage", "boomy"),
    "Hi-Drive": ("bright", "aggressive", "harsh", "clear"),
    "Monster Fuzz": ("aggressive", "raw", "harsh", "modern"),
    "Octafuzz": ("aggressive", "raw", "thin", "vintage"),
    "Rawk! Distortion": ("aggressive", "bright", "harsh", "modern"),
    "Tube Burner": ("warm", "aggressive", "controlled", "punchy", "vintage", "boomy"),
    "Vintage Drive": ("warm", "smooth", "vintage", "boomy", "clear"),
    "Auto-Funk": ("punchy", "dynamic", "energetic", "bright", "dark"),
    "Classic Wah": ("forward", "energetic", "aggressive", "bright"),
    "Graphic EQ": ("warm", "bright", "dark", "clear", "muddy", "boxy", "harsh", "thin", "boomy"),
    "Modern Wah": ("aggressive", "forward", "bright", "energetic"),
    "Squash Compressor": ("controlled", "smooth", "punchy", "aggressive", "dynamic"),
    "Flange Factory": ("wide", "energetic", "modern", "vintage", "harsh"),
    "Heavenly Chorus": ("wide", "smooth", "airy", "bright", "vintage"),
    "Phase Tripper": ("wide", "smooth", "vintage", "energetic"),
    "Phaze 2": ("wide", "energetic", "modern", "vintage", "smooth"),
    "Retro Chorus": ("wide", "smooth", "vintage"),
    "Robo Flanger": ("wide", "aggressive", "energetic", "harsh"),
    "Roswell Ringer": ("aggressive", "raw", "modern", "harsh"),
    "Roto Phase": ("wide", "vintage", "modern", "smooth"),
    "Spin Box": ("wide", "vintage", "energetic", "aggressive", "bright"),
    "The Vibe": ("wide", "vintage", "smooth", "energetic"),
    "Total Tremolo": ("energetic", "dynamic", "vintage", "modern"),
    "Trem-O-Tone": ("energetic", "dynamic", "vintage"),
    "Dr. Octave": ("boomy", "lowEndWeight", "aggressive", "raw", "modern"),
    "Wham": ("aggressive", "raw", "modern", "energetic"),
    "Mixer": ("wide", "narrow", "monoCompatibility"),
    "Splitter": ("tight", "clear", "lowEndWeight", "monoCompatibility"),
    "DeEsser 2": ("sibilant", "airy", "intimate", "smooth", "controlled"),
    "DeEsser": ("sibilant", "airy", "intimate", "smooth", "controlled"),
    "Enveloper": ("punchy", "soft", "tight", "dynamic"),
    "Stereo Spread": ("wide", "narrow", "monoCompatibility"),
    "Direction Mixer": ("wide", "narrow", "monoCompatibility", "forward"),
    "Exciter": ("airy", "bright", "harsh", "thin"),
    "SubBass": ("lowEndWeight", "boomy", "tight", "thin"),
    "Mastering Assistant": ("polished", "controlled", "dynamic", "energetic", "modern", "warm", "clear", "wide"),
    "Pitch Correction": ("polished", "controlled", "raw", "dynamic"),
    "Noise Gate": ("controlled", "tight", "raw", "dynamic"),
    "Auto Sampler": (),
    "I/O": (),
    "Test Oscillator": (),
}

TOOL_ALIASES = {
    "Amp Designer": ("guitar amp", "amp sim", "cabinet", "cab sim"),
    "Bass Amp Designer": ("bass amp", "bass di", "bass cabinet"),
    "Pedalboard": ("pedal board", "pedals", "stompboxes", "stompbox"),
    "Bitcrusher": ("bit crusher", "bitcrush", "bit crush", "sample rate reduction", "downsample"),
    "Blue Echo": ("echo pedal", "simple echo"),
    "Spring Box": ("spring reverb", "spring reverb pedal"),
    "Tie Dye Delay": ("reverse delay", "reverse echo"),
    "Tru-Tape Delay": ("tape echo", "tape delay pedal"),
    "Candy Fuzz": ("bright fuzz",),
    "Double Dragon": ("parallel distortion pedal", "compressed distortion pedal"),
    "Fuzz Machine": ("american fuzz",),
    "Grinder": ("metal distortion pedal", "scooped distortion"),
    "Grit": ("crunch distortion pedal",),
    "Happy Face Fuzz": ("soft fuzz", "full fuzz"),
    "Hi-Drive": ("treble overdrive", "high frequency overdrive"),
    "Monster Fuzz": ("high gain fuzz",),
    "Octafuzz": ("octave fuzz", "high pass fuzz"),
    "Rawk! Distortion": ("hard rock distortion", "metal distortion"),
    "Tube Burner": ("tube overdrive pedal", "crossover distortion pedal"),
    "Vintage Drive": ("vintage overdrive", "fet overdrive"),
    "Auto-Funk": ("envelope filter", "auto wah", "touch wah"),
    "Classic Wah": ("wah pedal", "classic wah pedal"),
    "Graphic EQ": ("eq pedal", "seven band eq"),
    "Modern Wah": ("modern wah pedal", "volume pedal"),
    "Squash Compressor": ("compressor pedal", "sustain pedal"),
    "Flange Factory": ("advanced flanger", "flanger pedal"),
    "Heavenly Chorus": ("chorus pedal", "stereo chorus"),
    "Phase Tripper": ("phaser pedal",),
    "Phaze 2": ("dual phaser", "two phasers"),
    "Retro Chorus": ("subtle chorus", "vintage chorus"),
    "Robo Flanger": ("manual flanger",),
    "Roswell Ringer": ("ring mod", "ring modulator", "frequency shifter pedal"),
    "Roto Phase": ("vintage phaser", "modern phaser"),
    "Spin Box": ("rotary speaker", "leslie effect", "rotating speaker"),
    "The Vibe": ("vibe pedal", "univibe", "scanner vibrato"),
    "Total Tremolo": ("tremolo pedal", "accelerating tremolo"),
    "Trem-O-Tone": ("simple tremolo", "amplitude modulation pedal"),
    "Dr. Octave": ("octaver", "octave pedal", "sub octave pedal"),
    "Wham": ("whammy", "pitch pedal", "pitch shift pedal"),
    "Mixer": ("pedalboard mixer", "parallel pedal mixer", "blend buses"),
    "Splitter": (
        "pedalboard splitter",
        "frequency split",
        "frequency split pedals",
        "split pedals",
        "parallel pedal split",
    ),
    "DeEsser 2": ("de esser", "de-esser", "deessing", "de-essing"),
    "Delay Designer": ("multitap delay", "multi tap delay"),
    "Stereo Spread": ("stereo widening", "widening"),
    "Direction Mixer": ("mid side width", "m s width"),
    "SubBass": ("sub bass", "subharmonic", "sub harmonic"),
    "Pitch Correction": ("tune vocal", "pitch correct", "autotune"),
    "Scripter": ("midi script", "javascript midi"),
}


@dataclass(frozen=True)
class SectionSpec:
    family: str
    pages: str


SECTIONS = {
    "Delay and ambience pedals": SectionSpec("pedalboard_delay_ambience", "36-56"),
    "Distortion pedals": SectionSpec("pedalboard_distortion", "36-56"),
    "Dynamics and filter pedals": SectionSpec("pedalboard_dynamics_filter", "36-56"),
    "Modulation pedals": SectionSpec("pedalboard_modulation", "36-56"),
    "Pitch pedals": SectionSpec("pedalboard_pitch", "36-56"),
    "Utility pedals": SectionSpec("pedalboard_utility", "36-56"),
    "Delay processors": SectionSpec("delay", "57-77"),
    "Distortion and nonlinear processors": SectionSpec("distortion", "78-86"),
    "Dynamics processors": SectionSpec("dynamics", "87-111"),
    "Equalizers": SectionSpec("equalizer", "112-138"),
    "Filter processors": SectionSpec("filter", "139-165"),
    "Imaging, mastering, and metering": SectionSpec("imaging_mastering", "166-196"),
    "MIDI processors and generated control": SectionSpec("midi_processor", "197-242"),
    "Modulation processors": SectionSpec("modulation", "243-261"),
    "Multi-effects": SectionSpec("multi_effect", "262-299"),
    "Pitch processors": SectionSpec("pitch", "300-308"),
    "Reverb and ambience processors": SectionSpec("reverb", "309-350"),
    "Specialized processors": SectionSpec("specialized", "351-354"),
    "Utilities and production tools": SectionSpec("utility", "355-364"),
    "Legacy processors": SectionSpec("legacy", "365-389"),
}


MANUAL_ENTRIES = (
    {
        "name": "Amp Designer",
        "family": "amp",
        "manualPages": "12-25",
        "documentedMechanism": "Recombinable amp, cabinet, EQ, microphone, position/distance, gain-stage, reverb, tremolo, and vibrato model.",
        "productionConsequence": "Gain, Master, and Output are distinct; EQ can change drive, and cabinet/microphone choices change tone and phase. Exact analog behavior remains undocumented.",
    },
    {
        "name": "Bass Amp Designer",
        "family": "amp",
        "manualPages": "26-35",
        "documentedMechanism": "Parallel modeled bass-amp and six-curve DI paths with selectable cabinet/direct tap points, microphones, compressor, and reorderable additional EQ.",
        "productionConsequence": "Blend and routing can preserve a clean fundamental beside a colored amp path, but alignment, AutoGain bias, low-end phase, and headroom require listening and measurement.",
    },
    {
        "name": "Pedalboard",
        "family": "pedalboard",
        "manualPages": "36-56",
        "documentedMechanism": "Left-to-right serial pedal graph with two buses, movable split/recombination points, frequency splitting, panning, channel-format transitions, automation, and eight macros.",
        "productionConsequence": "Pedal order and branch topology are part of the sound. Parallel and split-band designs require level, phase, crossover, stereo, and mono checks.",
    },
    {
        "name": "Bitcrusher",
        "family": "distortion",
        "manualPages": "78-79",
        "documentedMechanism": "Separates amplitude quantization, effective sample-rate division, input drive, thresholded Fold/Clip/Wrap behavior, and dry/effect mixing.",
        "productionConsequence": "Downsampling intentionally aliases without changing pitch or speed; bit reduction is not inherently warm and downsampling is not merely dark. Exact nonlinear equations remain undocumented.",
    },
)


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--atlas", type=pathlib.Path, default=DEFAULT_ATLAS)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--swift-output", type=pathlib.Path, default=DEFAULT_SWIFT_OUTPUT)
    return parser.parse_args()


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def empirical_evidence() -> dict[str, list[dict[str, object]]]:
    by_identity: dict[str, list[dict[str, object]]] = {}
    seen_run_ids: set[str] = set()
    for path in sorted(EVIDENCE_ROOT.glob("*/run.json")):
        record = json.loads(path.read_text(encoding="utf-8"))
        run_id = record.get("runID")
        identifier = record.get("identityIdentifier")
        status = record.get("status")
        summary = record.get("modelContextSummary")
        if record.get("schemaVersion") != "1.0":
            raise SystemExit(f"unsupported empirical run schema: {path}")
        if not isinstance(run_id, str) or not run_id or run_id in seen_run_ids:
            raise SystemExit(f"invalid or duplicate empirical runID: {path}")
        seen_run_ids.add(run_id)
        if not isinstance(identifier, str) or not identifier:
            raise SystemExit(f"empirical run identity missing: {path}")
        if status not in {"partial", "complete"}:
            raise SystemExit(f"invalid empirical run status: {run_id}")
        if not isinstance(summary, str) or not summary or len(summary.encode("utf-8")) > 2_048:
            raise SystemExit(f"bounded model-context summary missing: {run_id}")
        if status == "partial" and record.get("exactTransferCharacterized") is not False:
            raise SystemExit(f"partial empirical run overclaims exact transfer: {run_id}")
        by_identity.setdefault(identifier, []).append(record)
    return by_identity


def clean_markdown(value: str) -> str:
    value = value.strip().replace("`", "").replace("**", "")
    return re.sub(r"\s+", " ", value)


def slug(value: str) -> str:
    result = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    if not result:
        raise SystemExit(f"could not create stable identifier for {value!r}")
    return result


def row_cells(line: str) -> list[str]:
    return [clean_markdown(cell) for cell in line.strip().strip("|").split("|")]


def is_separator(cells: list[str]) -> bool:
    return all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def extract_entries(atlas: pathlib.Path) -> list[dict[str, str]]:
    entries = [dict(entry) for entry in MANUAL_ENTRIES]
    current_heading = ""
    current_spec: SectionSpec | None = None
    headers: list[str] | None = None

    for raw_line in atlas.read_text(encoding="utf-8").splitlines():
        heading = re.match(r"^(##|###)\s+(.+?)\s*$", raw_line)
        if heading:
            current_heading = clean_markdown(heading.group(2))
            current_spec = SECTIONS.get(current_heading)
            headers = None
            continue
        if current_spec is None or not raw_line.startswith("|"):
            continue
        cells = row_cells(raw_line)
        if not cells or is_separator(cells):
            continue
        if cells[0] in {"Pedal", "Utility", "Processor", "Meter", "Tool"}:
            headers = cells
            continue
        if headers is None:
            headers = cells
            continue
        if len(cells) != len(headers):
            raise SystemExit(f"malformed table row under {current_heading}: {raw_line}")

        name = cells[0]
        if not name:
            continue
        if len(cells) == 4:
            mechanism = cells[1]
            consequence = f"Controls/interactions: {cells[2]} Risks/checks: {cells[3]}"
        elif len(cells) == 3:
            mechanism = cells[1]
            consequence = cells[2]
        else:
            raise SystemExit(f"unsupported table width under {current_heading}: {len(cells)}")

        family = current_spec.family
        if name in {"BPM Counter", "Correlation Meter", "Level Meter", "Loudness Meter", "MultiMeter", "Surround MultiMeter", "Tuner"}:
            family = "metering"
        elif name == "Mastering Assistant":
            family = "mastering"
        elif name in {"Binaural Post-Processing", "Spatial Audio Monitoring", "Direction Mixer", "Stereo Spread"}:
            family = "imaging"

        entries.append(
            {
                "name": name,
                "family": family,
                "manualPages": current_spec.pages,
                "documentedMechanism": mechanism,
                "productionConsequence": consequence,
            }
        )
    return entries


def enrich_entry(
    entry: dict[str, object],
    evidence_by_identity: dict[str, list[dict[str, object]]],
) -> None:
    family = str(entry["family"])
    name = str(entry["name"])
    entry["applicableSourceTypes"] = list(
        FAMILY_SOURCE_TYPES.get(family, ALL_PRODUCTION_SOURCES)
    )
    entry["semanticTags"] = list(
        TOOL_SEMANTIC_TAGS.get(name, FAMILY_SEMANTIC_TAGS.get(family, ()))
    )
    entry["aliases"] = list(TOOL_ALIASES.get(name, ()))
    runs = evidence_by_identity.get(str(entry["identifier"]), [])
    if not runs:
        entry["empiricalStatus"] = "notRun"
        entry["measuredRunIDs"] = []
        entry["empiricalEvidenceSummary"] = None
        return
    entry["empiricalStatus"] = (
        "complete" if any(run["status"] == "complete" for run in runs) else "partial"
    )
    entry["measuredRunIDs"] = sorted(str(run["runID"]) for run in runs)
    summaries = list(dict.fromkeys(str(run["modelContextSummary"]) for run in runs))
    combined_summary = " ".join(summaries)
    if len(combined_summary.encode("utf-8")) > 2_048:
        raise SystemExit(f"combined empirical context is oversized: {entry['identifier']}")
    entry["empiricalEvidenceSummary"] = combined_summary


def swift_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def swift_array(values: list[str], prefix: str = "") -> str:
    return "[" + ", ".join(f"{prefix}{swift_string(value)}" for value in values) + "]"


def write_swift_catalog(path: pathlib.Path, entries: list[dict[str, object]]) -> None:
    lines = [
        "// Generated by research/scripts/build-logic-effects-knowledge.py.",
        "// Do not edit by hand; edit the reviewed atlas or generator instead.",
        "",
        "import AgentCore",
        "import PlanSchema",
        "",
        "extension LogicNativeToolKnowledgeCatalog {",
        "    public static let logicPro12_3 = LogicNativeToolKnowledgeCatalog(",
        f"        sourceSHA256: {swift_string(EFFECTS_SHA256)},",
        "        reviewStatus: .deepFullRelevantSectionRead,",
        "        entries: [",
    ]
    for entry in entries:
        sources = "[" + ", ".join(f".{value}" for value in entry["applicableSourceTypes"]) + "]"
        tags = "[" + ", ".join(f".{value}" for value in entry["semanticTags"]) + "]"
        lines.extend(
            [
                "            .init(",
                f"                identifier: {swift_string(str(entry['identifier']))},",
                f"                name: {swift_string(str(entry['name']))},",
                f"                family: {swift_string(str(entry['family']))},",
                f"                manualPages: {swift_string(str(entry['manualPages']))},",
                f"                aliases: {swift_array(entry['aliases'])},",
                f"                applicableSourceTypes: {sources},",
                f"                semanticTags: {tags},",
                f"                documentedMechanism: {swift_string(str(entry['documentedMechanism']))},",
                f"                productionConsequence: {swift_string(str(entry['productionConsequence']))},",
                f"                empiricalStatus: .{entry['empiricalStatus']},",
                f"                measuredRunIDs: {swift_array(entry['measuredRunIDs'])},",
                "                empiricalEvidenceSummary: "
                + (
                    swift_string(str(entry["empiricalEvidenceSummary"]))
                    if entry["empiricalEvidenceSummary"] is not None
                    else "nil"
                ),
                "            ),",
            ]
        )
    lines.extend(["        ]", "    )", "}", ""])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = arguments()
    if not args.atlas.is_file():
        raise SystemExit(f"missing atlas: {args.atlas}")
    entries = extract_entries(args.atlas)
    evidence_by_identity = empirical_evidence()
    names = [entry["name"] for entry in entries]
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        raise SystemExit(f"duplicate tool identities: {', '.join(duplicates)}")
    if len(entries) != EXPECTED_ENTRY_COUNT:
        raise SystemExit(
            f"catalogue completeness changed: expected {EXPECTED_ENTRY_COUNT}, got {len(entries)}"
        )

    for entry in entries:
        entry["identifier"] = f"logic-pro-12.3:{slug(entry['name'])}"
        entry["reviewStatus"] = "deep_full_relevant_section_read"
        entry["mechanismEvidenceClass"] = "apple_documented_behavior"
        entry["productionConsequenceEvidenceClass"] = (
            "derived_technical_interpretation_and_professional_practice_heuristic"
        )
        entry["executionBoundary"] = (
            "advisory_only_logic_native_tool_no_tracksmith_execution_authority"
        )
        entry["subjectiveListeningDecisive"] = True
        enrich_entry(entry, evidence_by_identity)

    entries.sort(key=lambda item: (item["family"], item["name"].casefold()))
    payload = {
        "schemaVersion": "1.0",
        "product": "TrackSmith",
        "logicVersionContext": "Logic Pro for Mac 12.3 selected in Apple's live guide at retrieval",
        "knowledgeStatus": "deep_reviewed_advisory_knowledge_not_execution_authority",
        "source": {
            "identity": "Apple, Logic Pro Effects for Mac",
            "pageCount": 390,
            "sha256": EFFECTS_SHA256,
            "reviewCompletedDate": "2026-07-15",
            "fullRelevantContentRead": True,
            "localUseOnly": True,
            "redistributionRightsInferred": False,
        },
        "atlas": {
            "relativePath": str(args.atlas.relative_to(ROOT)),
            "sha256": sha256(args.atlas),
        },
        "empiricalEvidenceRoot": str(EVIDENCE_ROOT.relative_to(ROOT)),
        "safetyContract": {
            "mayNameLogicNativeTools": True,
            "mayExplainManualWorkflow": True,
            "mayBecomeProcessingNode": False,
            "mayClaimNativePluginInsertion": False,
            "mayEmitAutomation": False,
            "mayEmitScripterCode": False,
            "mayControlLogicProject": False,
            "mustSeparateDocumentedBehaviorFromHeuristic": True,
            "mustLevelMatchCandidates": True,
            "mustLeaveSubjectivePreferenceToListening": True,
        },
        "entryCount": len(entries),
        "entries": entries,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_swift_catalog(args.swift_output, entries)
    print(
        f"wrote {args.output} and {args.swift_output}: "
        f"{len(entries)} deeply reviewed advisory tool entries"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
