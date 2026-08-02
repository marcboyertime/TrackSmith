#!/usr/bin/env python3
"""Build TrackSmith's curated overlay without rewriting dataset-supplied labels."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


CORPUS_DIR = (
    "research/evaluation/production-mastery-v1/audio-evidence-corpus"
)


SPECS: list[dict[str, Any]] = [
    {
        "annotationID": "pmv1-medleydb-liz-rainfall-mix",
        "assetID": "medleydb:MedleyDB_sample/Audio/LizNelson_Rainfall/LizNelson_Rainfall_MIX.wav",
        "sourceClass": "full_mix",
        "role": "natural_full_song_reference",
        "recordingCondition": ["natural_performance", "full_song"],
        "processingCondition": ["dataset_mix", "unknown_mastering_status"],
        "curatorClass": "research_practice_derived",
        "notes": "Natural full-song reference selected for long-form, source-preservation, and level-matched processor evaluation. The dataset does not state that this mix is artistically optimal.",
        "desired": ["preserve_song_scale_relationships_during_bounded_evaluation"],
        "preserved": ["performance", "section_dynamics", "source_balance", "stereo_image"],
        "prohibited": ["source_overwrite", "unmatched_loudness_preference", "dataset_mix_as_universal_target"],
        "competingInterpretations": ["unchanged_reference", "corrective_processing", "aesthetic_processing"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": True,
        "humanListeningDecisive": True,
        "evidenceClass": "research_practice_derived",
        "failureMapCaseIDs": ["MIX-CUR-001", "MIX-CUR-004", "MIX-CUR-005"],
        "dspFixtureIDs": ["pmv1:natural:medleydb:LizNelson_Rainfall:mixture"],
        "languageCaseIDs": [],
        "listeningTaskIDs": ["PMV1-LISTEN-MEDLEY-LIZ-001"],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-medleydb-phoenix-scotch-morris-mix",
        "assetID": "medleydb:MedleyDB_sample/Audio/Phoenix_ScotchMorris/Phoenix_ScotchMorris_MIX.wav",
        "sourceClass": "full_mix",
        "role": "natural_full_song_reference",
        "recordingCondition": ["natural_performance", "full_song"],
        "processingCondition": ["dataset_mix", "unknown_mastering_status"],
        "curatorClass": "research_practice_derived",
        "notes": "Independent natural full-song reference with aligned raw sources and stems. Selection establishes fixture diversity, not production preference.",
        "desired": ["preserve_transients_tone_and_structure_during_bounded_evaluation"],
        "preserved": ["performance", "transient_shape", "source_balance", "stereo_image"],
        "prohibited": ["source_overwrite", "unmatched_loudness_preference", "dataset_mix_as_universal_target"],
        "competingInterpretations": ["unchanged_reference", "corrective_processing", "aesthetic_processing"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": True,
        "humanListeningDecisive": True,
        "evidenceClass": "research_practice_derived",
        "failureMapCaseIDs": ["DRM-CUR-001", "DRM-CUR-002", "DRM-CUR-003"],
        "dspFixtureIDs": ["pmv1:natural:medleydb:Phoenix_ScotchMorris:mixture"],
        "languageCaseIDs": [],
        "listeningTaskIDs": ["PMV1-LISTEN-MEDLEY-PHOENIX-001"],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g1-c8-t3-vocal-slapback",
        "assetID": "mixassist:Group1:cut_50.wav",
        "sourceTurns": [["group1_conv8", 3]],
        "sourceClass": "vocal",
        "role": "lead_vocal_in_mix",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["pre_or_during_slapback_audition"],
        "curatorClass": "direct_human",
        "notes": "Human producer requests a clearly audible slapback experiment before later asking for restraint. The 16 kHz mono clip is contextual language evidence, not a high-fidelity delay target.",
        "desired": ["short_vocal_echo_for_depth_and_movement"],
        "preserved": ["vocal_center", "intelligibility", "dry_presence"],
        "prohibited": ["unbounded_feedback", "loudness_only_difference"],
        "competingInterpretations": ["single_slap", "tempo_related_echo", "filtered_short_delay"],
        "noProcessingCouldBeCorrect": False,
        "nonDSPCouldBeCorrect": False,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["VOC-CUR-006", "GTR-CUR-004"],
        "dspFixtureIDs": [],
        "languageCaseIDs": ["mixassist:group1_conv8:turn3"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g1-c8-t4-vocal-delay-restraint",
        "assetID": "mixassist:Group1:cut_51.wav",
        "sourceTurns": [["group1_conv8", 4]],
        "sourceClass": "vocal",
        "role": "lead_vocal_in_mix",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["slapback_revision"],
        "curatorClass": "direct_human",
        "notes": "The next human turn keeps the idea but asks for a much less drastic amount. This is a targeted-revision case, not evidence for one preferred delay setting.",
        "desired": ["retain_slapback_character_at_lower_intensity"],
        "preserved": ["selected_delay_character", "dry_vocal", "unrelated_EQ"],
        "prohibited": ["same_drastic_amount", "collateral_reverb_or_EQ_change"],
        "competingInterpretations": ["reduce_wet_mix", "reduce_feedback", "shorten_delay", "restore_then_rebuild"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": False,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["VOC-CUR-006"],
        "dspFixtureIDs": ["pmv1:revision:delay_intensity_only"],
        "languageCaseIDs": ["mixassist:group1_conv8:turn4"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g1-c8-t5-reverb-only-revision",
        "assetID": "mixassist:Group1:cut_52.wav",
        "sourceTurns": [["group1_conv8", 5]],
        "sourceClass": "vocal",
        "role": "lead_vocal_in_mix",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["slapback_plus_reverb_revision"],
        "curatorClass": "direct_human",
        "notes": "Human producer asks to lower reverb after adding slapback. The revision target is one element; the delay and earlier EQ are preservation constraints.",
        "desired": ["reduce_reverb_contribution_only"],
        "preserved": ["slapback", "earlier_EQ", "dry_vocal_position"],
        "prohibited": ["remove_delay", "change_EQ", "global_level_substitution"],
        "competingInterpretations": ["lower_reverb_send", "shorten_tail", "reduce_early_reflections"],
        "noProcessingCouldBeCorrect": False,
        "nonDSPCouldBeCorrect": False,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["VOC-CUR-006"],
        "dspFixtureIDs": ["pmv1:revision:reverb_only_preserve_delay"],
        "languageCaseIDs": ["mixassist:group1_conv8:turn5"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g3-c4-t0-live-airy-drum-bleed",
        "assetID": "mixassist:Group3:cut_13.wav",
        "sourceTurns": [["group3_conv4", 0]],
        "sourceClass": "drums",
        "role": "live_drum_bus_context",
        "recordingCondition": ["natural_mix_excerpt", "bleed"],
        "processingCondition": ["individual_and_bus_processing_in_progress"],
        "curatorClass": "direct_human",
        "notes": "Human dialogue explicitly values a live, airy drum feel while identifying snare spill in the hi-hat track and the timing risk of editing bleed-linked tracks.",
        "desired": ["maintain_live_airy_drum_character"],
        "preserved": ["performance_timing", "natural_decay", "coherent_bleed"],
        "prohibited": ["independent_timing_damage", "hard_gate_chatter", "sterile_isolation"],
        "competingInterpretations": ["accept_and_balance_bleed", "bounded_expansion", "group_editing", "no_processing"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": True,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["DRM-CUR-004"],
        "dspFixtureIDs": ["pmv1:natural:drum_bleed_preservation"],
        "languageCaseIDs": ["mixassist:group3_conv4:turn0"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g3-c4-t2-purposeful-drum-bus",
        "assetID": "mixassist:Group3:cut_15.wav",
        "sourceTurns": [["group3_conv4", 2]],
        "sourceClass": "drums",
        "role": "live_drum_bus_context",
        "recordingCondition": ["natural_mix_excerpt", "bleed"],
        "processingCondition": ["bus_routing_decision"],
        "curatorClass": "direct_human",
        "notes": "Human advice makes bus compression conditional on a production or workflow purpose. Routing neatness alone is not treated as evidence that compression is needed.",
        "desired": ["purposeful_bus_decision"],
        "preserved": ["individual_drum_balance", "live_feel", "workflow_editability"],
        "prohibited": ["automatic_bus_compression", "processing_without_audible_goal"],
        "competingInterpretations": ["individual_processing_first", "subtle_bus_compression", "routing_only", "no_bus"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": True,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["DRM-CUR-003"],
        "dspFixtureIDs": [],
        "languageCaseIDs": ["mixassist:group3_conv4:turn2"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g4-c8-t0-bass-saturation-hypothesis",
        "assetID": "mixassist:Group4:cut_29.wav",
        "sourceTurns": [["group4_conv8", 0]],
        "sourceClass": "bass",
        "role": "bass_in_mix",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["bass_refinement"],
        "curatorClass": "direct_human",
        "notes": "Human producer proposes saturation or cabinet-like coloration as one bass-refinement hypothesis. The proposal is advisory and must be compared against EQ, level, and unchanged interpretations.",
        "desired": ["bass_presence_and_character"],
        "preserved": ["low_end_weight", "note_definition", "genre_role"],
        "prohibited": ["small_bass", "excess_fuzz", "loudness_only_preference"],
        "competingInterpretations": ["saturation", "cabinet_coloration", "EQ", "level", "no_processing"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": True,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["BAS-CUR-001", "BAS-CUR-006"],
        "dspFixtureIDs": ["pmv1:natural:bass_saturation_candidates"],
        "languageCaseIDs": ["mixassist:group4_conv8:turn0"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g4-c8-t1-adaptive-limiter-punch",
        "assetID": "mixassist:Group4:cut_30.wav",
        "sourceTurns": [["group4_conv8", 1]],
        "sourceClass": "bass",
        "role": "bass_in_mix",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["adaptive_limiter_audition"],
        "curatorClass": "direct_human",
        "notes": "One human response describes this limiter audition as somewhat punchier. It is context-specific subjective evidence, not measured limiter behavior or a universal mastering recommendation.",
        "desired": ["perceived_bass_punch"],
        "preserved": ["low_end_size", "note_shape", "peak_safety"],
        "prohibited": ["loudness_confounded_punch_claim", "unbounded_limiting"],
        "competingInterpretations": ["limiting", "transient_shaping", "compression", "saturation", "level_match"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": False,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["BAS-CUR-001"],
        "dspFixtureIDs": ["logic-pro-12.3:adaptive-limiter:future_bounded_profile"],
        "languageCaseIDs": ["mixassist:group4_conv8:turn1"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g4-c8-t3-keep-some-mud",
        "assetID": "mixassist:Group4:cut_32.wav",
        "sourceTurns": [["group4_conv8", 3]],
        "sourceClass": "bass",
        "role": "bass_in_country_mix",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["subtle_drive_revision"],
        "curatorClass": "direct_human",
        "notes": "Human producer intentionally preserves some muddiness because of the genre role while considering only subtle additional drive. Corrective clarity is therefore not automatically desirable.",
        "desired": ["subtle_drive_with_intentional_low_mid_body"],
        "preserved": ["chosen_muddiness", "country_role", "bass_weight"],
        "prohibited": ["sterile_cleanup", "excess_drive", "genre_context_erasure"],
        "competingInterpretations": ["small_saturation_increase", "retain_current_state", "selective_EQ", "level_change"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": True,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["BAS-CUR-001"],
        "dspFixtureIDs": ["pmv1:preservation:intentional_low_mid_body"],
        "languageCaseIDs": ["mixassist:group4_conv8:turn3"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g6-c0-section-dynamics-and-center",
        "assetID": "mixassist:Group6:cut_1.wav",
        "sourceTurns": [
            ["group6_conv0", 0],
            ["group6_conv0", 1],
            ["group6_conv0", 2],
            ["group6_conv0", 3],
            ["group6_conv0", 4]
        ],
        "sourceClass": "full_mix",
        "role": "overall_mix",
        "recordingCondition": ["natural_mix_excerpt", "dense"],
        "processingCondition": ["diagnostic_discussion"],
        "curatorClass": "direct_human",
        "notes": "Human discussion diagnoses weak section contrast, an almost inaudible vocal, mid-heavy balance, and an over-centered presentation. Several causes are level, panning, and arrangement decisions rather than one processor preset.",
        "desired": ["section_contrast", "vocal_intelligibility", "clearer_center_and_space"],
        "preserved": ["arrangement_identity", "intended_large_and_small_sections", "human_performance"],
        "prohibited": ["constant_loudness", "automatic_width_without_mono_check", "single_processor_overclaim"],
        "competingInterpretations": ["level_automation", "panning", "subtractive_arrangement", "EQ", "selective_dynamics"],
        "noProcessingCouldBeCorrect": False,
        "nonDSPCouldBeCorrect": True,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["MIX-CUR-002", "MIX-CUR-004", "MIX-CUR-005"],
        "dspFixtureIDs": [],
        "languageCaseIDs": ["mixassist:group6_conv0:turns0-4"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g6-c6-t3-master-reverb-audition",
        "assetID": "mixassist:Group6:cut_35.wav",
        "sourceTurns": [
            ["group6_conv6", 3],
            ["group6_conv6", 4],
            ["group6_conv6", 5]
        ],
        "sourceClass": "full_mix",
        "role": "overall_mix",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["full_mix_reverb_audition"],
        "curatorClass": "direct_human",
        "notes": "Human participants deliberately audition a small amount of reverb on the full mix while acknowledging that source-specific placement may be more conventional. The audition is a hypothesis, not a best-practice rule.",
        "desired": ["small_shared_space_audition"],
        "preserved": ["dry_mix", "transient_clarity", "front_back_relationship"],
        "prohibited": ["master_reverb_as_default", "washed_sections", "loudness_confounded_preference"],
        "competingInterpretations": ["full_mix_reverb", "source_specific_sends", "short_room", "no_processing"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": False,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["MIX-CUR-005", "DRM-CUR-002"],
        "dspFixtureIDs": ["pmv1:natural:full_mix_reverb_hypotheses"],
        "languageCaseIDs": ["mixassist:group6_conv6:turns3-5"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g6-c6-t6-subtle-glue-result",
        "assetID": "mixassist:Group6:cut_36.wav",
        "sourceTurns": [["group6_conv6", 6]],
        "sourceClass": "full_mix",
        "role": "overall_mix",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["post_subtle_reverb_and_EQ_audition"],
        "curatorClass": "direct_human",
        "notes": "One human describes the result as more glued and immediately emphasizes that little processing was needed. This preference remains participant- and context-specific.",
        "desired": ["subtle_cohesion"],
        "preserved": ["section_breathing", "transients", "dry_definition"],
        "prohibited": ["heavy_bus_processing", "universal_glue_claim", "loudness_confounded_preference"],
        "competingInterpretations": ["subtle_reverb", "subtle_EQ", "bus_compression", "unchanged"],
        "noProcessingCouldBeCorrect": True,
        "nonDSPCouldBeCorrect": False,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["MIX-CUR-005"],
        "dspFixtureIDs": ["pmv1:revision:subtle_glue_restraint"],
        "languageCaseIDs": ["mixassist:group6_conv6:turn6"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    },
    {
        "annotationID": "pmv1-mixassist-g7-c4-t2-distortion-mask",
        "assetID": "mixassist:Group7:cut_42.wav",
        "sourceTurns": [["group7_conv4", 2]],
        "sourceClass": "full_mix",
        "role": "distorted_source_against_bass",
        "recordingCondition": ["natural_mix_excerpt"],
        "processingCondition": ["masking_diagnosis"],
        "curatorClass": "direct_human",
        "notes": "Human advice identifies low-frequency overlap on a distortion channel as one reason it does not cut through and proposes removing lows from that channel, not from the bass or whole mix.",
        "desired": ["distorted_source_cut_through"],
        "preserved": ["bass_low_end", "distortion_upper_character", "overall_level"],
        "prohibited": ["global_low_cut", "make_everything_louder", "bass_weight_loss"],
        "competingInterpretations": ["channel_specific_high_pass", "level_balance", "arrangement_space", "different_distortion"],
        "noProcessingCouldBeCorrect": False,
        "nonDSPCouldBeCorrect": True,
        "humanListeningDecisive": True,
        "evidenceClass": "direct_human",
        "failureMapCaseIDs": ["BAS-CUR-006", "MIX-ADV-002"],
        "dspFixtureIDs": ["pmv1:natural:masking_channel_specific_EQ"],
        "languageCaseIDs": ["mixassist:group7_conv4:turn2"],
        "listeningTaskIDs": [],
        "listeningStatus": "not_run"
    }
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    temporary.replace(path)


def build_annotations(repo_root: Path) -> dict[str, Any]:
    corpus_dir = repo_root / CORPUS_DIR
    index = load_json(corpus_dir / "natural-audio-index.json")
    assets = {asset["assetID"]: asset for asset in index["assets"]}
    annotations: list[dict[str, Any]] = []

    for spec in SPECS:
        asset_id = spec["assetID"]
        if asset_id not in assets:
            raise RuntimeError(f"annotation asset is absent: {asset_id}")
        asset = assets[asset_id]
        source_turns = []
        for conversation_id, turn_id in spec.get("sourceTurns", []):
            matches = [
                reference
                for reference in asset.get("dialogueReferences", [])
                if reference["conversationID"] == conversation_id
                and reference["turnID"] == turn_id
                and reference["referenceKind"] == "current_turn"
            ]
            if not matches:
                raise RuntimeError(
                    f"{spec['annotationID']}: source turn "
                    f"{conversation_id}:{turn_id} is not linked to {asset_id}"
                )
            source_turns.extend(matches)

        dataset_supplied: dict[str, Any] = {
            "sourceCaptureID": asset["sourceCaptureID"],
            "sourceCaptureSHA256": asset["sourceCaptureSHA256"],
        }
        if asset["datasetID"] == "medleydb":
            dataset_supplied.update(
                {
                    "trackID": asset["trackID"],
                    "annotationMemberPaths": asset[
                        "datasetAnnotationMemberPaths"
                    ],
                    "preferenceLabelSupplied": False,
                }
            )
        else:
            dataset_supplied.update(
                {
                    "dialogueTurns": source_turns,
                    "releasedSourceSplits": asset["sourceSplits"],
                    "releasedSourceSplitContaminated": asset[
                        "sourceSplitContaminated"
                    ],
                    "processedAudioFormatBoundary": "16_kHz_mono_PCM",
                    "preferenceScope": (
                        "human_turn_context_only_not_universal_truth"
                    ),
                }
            )

        annotation = {
            "annotationID": spec["annotationID"],
            "datasetID": asset["datasetID"],
            "assetID": asset_id,
            "split": asset["split"],
            "timeScope": {
                "startSeconds": 0,
                "endSeconds": asset["pcm"]["durationSeconds"],
                "scopeClass": (
                    "full_song"
                    if asset["datasetID"] == "medleydb"
                    else "conversation_turn"
                ),
                "sectionLabel": None,
            },
            "datasetSupplied": dataset_supplied,
            "mechanicallyDerived": {
                "artifactSHA256": asset["artifactSHA256"],
                "byteCount": asset["byteCount"],
                "pcm": asset["pcm"],
                "exactDuplicateGroupMember": any(
                    asset_id in group["assetIDs"]
                    for group in index["summary"]["exactDuplicateGroups"]
                ),
            },
            "directlyCurated": {
                "sourceClass": spec["sourceClass"],
                "role": spec["role"],
                "recordingCondition": spec["recordingCondition"],
                "processingCondition": spec["processingCondition"],
                "curatorClass": spec["curatorClass"],
                "notes": spec["notes"],
            },
            "productionJudgment": {
                "desired": spec["desired"],
                "preserved": spec["preserved"],
                "prohibited": spec["prohibited"],
                "competingInterpretations": spec[
                    "competingInterpretations"
                ],
                "noProcessingCouldBeCorrect": spec[
                    "noProcessingCouldBeCorrect"
                ],
                "nonDSPCouldBeCorrect": spec["nonDSPCouldBeCorrect"],
                "humanListeningDecisive": spec["humanListeningDecisive"],
                "evidenceClass": spec["evidenceClass"],
            },
            "listeningEvidence": {
                "status": spec["listeningStatus"],
                "resultIDs": [],
            },
            "evaluationLinks": {
                "failureMapCaseIDs": spec["failureMapCaseIDs"],
                "dspFixtureIDs": spec["dspFixtureIDs"],
                "languageCaseIDs": spec["languageCaseIDs"],
                "listeningTaskIDs": spec["listeningTaskIDs"],
            },
        }
        annotations.append(annotation)

    annotations.sort(key=lambda annotation: annotation["annotationID"])
    provenance_counts = Counter(
        annotation["productionJudgment"]["evidenceClass"]
        for annotation in annotations
    )
    return {
        "schemaVersion": "1.0",
        "corpusID": index["corpusID"],
        "status": "curated_overlay_validated",
        "generator": "research/scripts/build-audio-evidence-annotations.py",
        "claimBoundary": {
            "datasetLabelsRewritten": False,
            "humanPreferenceMadeUniversal": False,
            "mixAssist16kMonoMadeHighFidelityReference": False,
            "measuredBehaviorInferredFromDialogue": False,
            "providerUploadAuthorized": False,
        },
        "summary": {
            "annotationCount": len(annotations),
            "evidenceClassCounts": dict(sorted(provenance_counts.items())),
            "protocolReadyListeningTaskCount": sum(
                1
                for annotation in annotations
                if annotation["listeningEvidence"]["status"]
                == "protocol_ready"
            ),
        },
        "annotations": annotations,
    }


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    target = repo_root / CORPUS_DIR / "tracksmith-annotations.json"
    result = build_annotations(repo_root)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.check:
        if not target.exists() or target.read_text(encoding="utf-8") != rendered:
            print("TrackSmith audio-evidence annotations are stale", file=sys.stderr)
            return 1
    if args.write:
        write_json(target, result)
    print(json.dumps(result["summary"], indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
