#!/usr/bin/env python3
"""Build the reviewed Logic 12.3 editor-tool advisory catalogue.

The catalogue describes host-side editing semantics and their state risks. It
contains no key command, Accessibility action, automation payload, or executable
host command; TrackSmith's plain AU has no authority to perform these actions.
"""

from __future__ import annotations

import hashlib
import json
import pathlib


ROOT = pathlib.Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "research/knowledge/logic-pro-12.3-editor-tool-knowledge.json"
SWIFT_OUTPUT = ROOT / "packages/ProductionIntelligence/Sources/ProductionIntelligence/LogicEditorToolKnowledge.generated.swift"
USER_GUIDE_SHA256 = "aa016d18d7e4f3559cdec54a99937d00b379617fee87510db1ec9853a4996cff"


def item(
    name: str,
    areas: tuple[str, ...],
    details: str,
    scope: str,
    consequence: str,
) -> dict[str, object]:
    return {
        "name": name,
        "areas": list(areas),
        "inventoryPages": "54-60",
        "documentedBehavior": details,
        "stateScope": scope,
        "productionConsequenceAndRisk": consequence,
        "executionBoundary": "advisory_only_no_tracksmith_host_authority",
    }


MULTIPLE = ("Tracks area", "area-specific editors")

ENTRIES = [
    item("Pointer", MULTIPLE, "Selects, moves, Option-copies, resizes, and in supported contexts loops items; its click zones can temporarily become Fade, Loop, or Marquee behavior.", "selection_region_event_or_view_dependent", "Selection, click zone, modifiers, snap, focus, and item type determine the edit; one gesture is not one invariant operation."),
    item("Pencil", MULTIPLE, "Creates regions or events and can select, move, loop, or resize them; in Score it also creates notation symbols.", "region_event_or_score_notation", "Created MIDI notes inherit prior/default length, velocity, and channel; Score symbols and playable events are different state."),
    item("Eraser", MULTIPLE, "Deletes a clicked item and, when the clicked item is selected, can delete every currently selected item.", "region_event_or_object", "Selection broadening makes a local-looking click a multi-item deletion; host undo availability is not guaranteed to be a complete safety transaction."),
    item("Text", MULTIPLE, "Renames regions or objects and creates text in the Score Editor.", "metadata_or_score_notation", "Names and imported text are untrusted metadata; score text is not an acoustic instruction or executable authority."),
    item("Scissors", MULTIPLE, "Splits regions or events at the edit position and applies to all selected items.", "region_or_event_boundaries", "Snap, zero-crossing behavior, take/folder state, and selection determine the actual boundary and number of affected items."),
    item("Join", MULTIPLE, "Joins selected regions or events into a single region or event.", "region_event_and_possible_derived_asset", "Joining audio, MIDI, looped, Flex-enabled, take, or folder material has different conversion and asset consequences; source identity must be rechecked."),
    item("Solo", MULTIPLE, "Auditions a held region or event in isolation and scrubs items crossed by horizontal movement.", "temporary_audition_transport", "This is an audition gesture, not a committed mute/solo mix state; transport focus and monitoring route remain relevant."),
    item("Mute", MULTIPLE, "Toggles item mute state; if multiple items are selected, the clicked item's resulting state applies to all selected items.", "region_or_event_mute_state", "Mute is stateful and selection-broadened; it is not deletion, bypass, silence trimming, or track mute."),
    item("Zoom", MULTIPLE, "Changes view magnification around a dragged area and can restore the prior/default zoom.", "view_only", "Zoom affects evidence visibility and click precision but not audio; it must never be reported as a production edit."),
    item("Fade", MULTIPLE, "Creates and edits fades and fade-curve shapes on supported material.", "audio_region_fade_state", "Fade, crossfade, loop, region edge, and file-edge behavior differ; a fade can change attack, sustain, clicks, or overlap without changing the source file."),
    item("Automation Select", MULTIPLE, "Selects automation data and can create automation points at region borders.", "track_or_region_automation", "Parameter identity, automation scope, mode, snap, Move Automation with Regions, and locks must be explicit before an edit."),
    item("Automation Curve", MULTIPLE, "Bends the segment between two automation points to form a nonlinear transition.", "track_or_region_automation", "The visible curve is host automation data, not proof of a plug-in's audible smoothing or exact sample trajectory."),
    item("Marquee", MULTIPLE, "Selects time-bounded portions of regions for editing, playback, and Selection-Based Processing.", "temporal_selection", "A marquee defines scope but does not identify a source asset, track, take, or safe operation; subsequent commands determine material consequences."),
    item("Flex", MULTIPLE, "Creates or edits fundamental Flex timing controls without requiring the full Flex view.", "audio_region_flex_state", "Flex algorithm, tempo metadata, File Tempo, Follow Tempo/Pitch, groups, takes, and transient/tempo markers interact; timing edits can create artifacts."),
    item("Slip", MULTIPLE, "Moves content inside fixed region boundaries by the Snap value when extra source content exists.", "region_content_offset", "Session Player regions are first converted to MIDI, losing generative semantics; source availability, snap, and boundaries constrain the move."),
    item("Rotate", MULTIPLE, "Moves region content while wrapping overflow to the opposite edge.", "region_content_rotation_and_conversion", "Rotating audio converts it to a one-track folder containing two regions; Session Player regions convert to MIDI first."),
    item("Finger", ("Piano Roll Editor", "Step Editor"), "Resizes MIDI notes from anywhere in Piano Roll and moves selected steps to another position or lane in Step Editor.", "midi_note_length_or_step_position", "Area focus changes the operation; multi-note/step selection and modifiers can preserve or overwrite relative differences."),
    item("Quantize", ("Piano Roll Editor", "Score Editor"), "Applies the active quantize value to clicked or selected MIDI events.", "midi_event_timing", "Grid value, strength, swing, Q-range, region parameters, and destructive versus playback quantization scope must be distinguished."),
    item("Velocity", ("Piano Roll Editor", "Score Editor"), "Adjusts MIDI note velocity for individual or selected notes.", "midi_note_velocity", "Velocity may control level, timbre, articulation, modulation, or nothing depending on the instrument; it is not a measured dB change."),
    item("Brush", ("Piano Roll Editor",), "Paints MIDI notes or a defined brush pattern using current time-quantize and optional scale constraints.", "midi_note_generation", "It can create many events quickly and inherits pattern, quantize, key/scale, velocity, channel, and snap context."),
    item("Vibrato", ("Audio Track Editor",), "Adjusts detected Flex Pitch note vibrato by dragging vertically.", "audio_region_flex_pitch_note", "Requires Flex Pitch analysis; note segmentation and analysis can be wrong, and vibrato amount is not ordinary pitch correction."),
    item("Volume", ("Audio Track Editor",), "Adjusts gain for an analyzed audio note by dragging vertically.", "audio_region_flex_pitch_note_gain", "Per-note gain depends on Flex Pitch note boundaries and differs from region gain, clip gain, automation, fader level, compression, and normalization."),
    item("Move", ("Audio File Editor",), "Moves a selected section left or right within the audio file editor.", "audio_file_content", "The Audio File Editor is a destructive shared-file domain; aliases, other regions, backups, zero crossings, and source hashes must be considered."),
    item("Camera", ("Score Editor",), "Selects and exports a Page-view score section as an image.", "score_image_export", "Creates a derivative image file and depends on engraving/page state; it does not render audio or prove playback state."),
    item("Layout", ("Score Editor",), "Moves notation graphically without changing MIDI event timing, subject to item-specific positioning rules.", "score_display_layout", "Graphical position and playback position are distinct; moving some bar-level layout objects can still affect surrounding engraving."),
    item("Resize", ("Score Editor",), "Changes the displayed size of notes and supported score symbols.", "score_display_layout", "This is notation presentation, not MIDI velocity, duration, arrangement density, or audible level."),
    item("Voice Separation", ("Score Editor",), "Draws a split line that assigns notes to predefined voice MIDI channels.", "midi_note_channel_and_score_voice", "It changes event-channel/voice assignment and may affect routing or articulation; it is not source separation or audio demixing."),
    item("Line", ("Step Editor",), "Creates or edits a linear series of event-beam values; it can edit MIDI events but cannot create MIDI note events.", "step_editor_midi_event_values", "Lane/event definition, grid, existing events, and line endpoints determine the affected data; it is not an audio envelope."),
    item("MIDI Thru", ("MIDI Environment",), "Assigns the clicked Environment object to the selected track in the main window.", "environment_object_track_routing", "This is host MIDI-routing authority outside TrackSmith's AU and can redirect external or internal destinations; it remains unsupported."),
    item("Gain", ("Tracks area",), "Applies nondestructive audio-region gain in dB to whole regions, selected regions, or a marquee selection.", "audio_region_or_marquee_gain", "It differs from file gain, normalization, track fader, automation, plug-in gain, and loudness; selection scope and headroom require validation."),
]


def main() -> int:
    if len(ENTRIES) != 30:
        raise SystemExit(f"expected 30 editor tools, found {len(ENTRIES)}")
    names = [entry["name"] for entry in ENTRIES]
    if len(names) != len(set(names)):
        raise SystemExit("duplicate editor-tool name")
    source = ROOT / "research/papers/tracksmith-logic-12.3-archive/objects" / f"{USER_GUIDE_SHA256}.pdf"
    if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != USER_GUIDE_SHA256:
        raise SystemExit("Logic User Guide immutable source is missing or changed")
    payload = {
        "schemaVersion": "1.0",
        "product": "TrackSmith",
        "logicVersionContext": "Logic Pro for Mac 12.3",
        "knowledgeStatus": "deep_reviewed_advisory_host_workflow_knowledge",
        "source": {
            "identity": "Apple, Logic Pro User Guide for Mac",
            "pageCount": 1324,
            "sha256": USER_GUIDE_SHA256,
            "reviewCompletedDate": "2026-07-15",
            "inventoryPages": "54-60",
            "fullRelevantContentRead": True,
            "localUseOnly": True,
        },
        "entryCount": len(ENTRIES),
        "safetyContract": {
            "advisoryOnly": True,
            "mayControlLogic": False,
            "mayEmitAccessibilityActions": False,
            "mayBecomeDSP": False,
            "stateScopeAndFocusRequired": True,
        },
        "entries": ENTRIES,
    }
    OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    SWIFT_OUTPUT.write_text(render_swift(), encoding="utf-8")
    print(f"wrote {OUTPUT} and {SWIFT_OUTPUT}: {len(ENTRIES)} reviewed editor tools")
    return 0


def swift_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def identifier(value: str) -> str:
    normalized = "-".join("".join(character.lower() if character.isalnum() else " " for character in value).split())
    return f"logic-pro-12.3-editor-tool:{normalized}"


def render_swift() -> str:
    lines = [
        "// Generated by research/scripts/build-logic-editor-tool-knowledge.py.",
        "// Do not edit by hand; edit the reviewed generator instead.",
        "",
        "extension LogicEditorToolKnowledgeCatalog {",
        "    public static let logicPro12_3 = LogicEditorToolKnowledgeCatalog(",
        f"        sourceSHA256: {swift_string(USER_GUIDE_SHA256)},",
        "        reviewStatus: .deepFullRelevantSectionRead,",
        "        entries: [",
    ]
    for entry in sorted(ENTRIES, key=lambda value: str(value["name"]).casefold()):
        areas = ", ".join(swift_string(str(area)) for area in entry["areas"])
        lines.extend(
            [
                "            .init(",
                f"                identifier: {swift_string(identifier(str(entry['name'])))},",
                f"                name: {swift_string(str(entry['name']))},",
                f"                areas: [{areas}],",
                f"                manualPages: {swift_string(str(entry['inventoryPages']))},",
                f"                documentedBehavior: {swift_string(str(entry['documentedBehavior']))},",
                f"                stateScope: {swift_string(str(entry['stateScope']))},",
                f"                productionConsequenceAndRisk: {swift_string(str(entry['productionConsequenceAndRisk']))}",
                "            ),",
            ]
        )
    lines.extend(["        ]", "    )", "}", ""])
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
