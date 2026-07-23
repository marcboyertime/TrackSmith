#!/usr/bin/env python3
"""Build the complete, auditable Logic 12.3 empirical campaign ledger.

Every native identity starts at ``not_run`` and can move only through a checked,
versioned ``research/evaluation/logic-native-empirical-runs/*/run.json`` record.
This keeps documentary review distinct from measured transfer evidence while
allowing direct host work to accumulate without hand-editing the generated
campaign or granting TrackSmith Logic-native execution authority.
"""

from __future__ import annotations

import json
import pathlib
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[2]
KNOWLEDGE = ROOT / "research/knowledge"
OUTPUT = KNOWLEDGE / "logic-pro-12.3-empirical-campaign.json"
EVIDENCE_ROOT = ROOT / "research/evaluation/logic-native-empirical-runs"

FIXTURES = {
    "silence": "silence_mono.wav",
    "impulse": "single_impulse_mono.wav",
    "impulseLevels": "impulse_level_ladder_mono.wav",
    "sweep": "log_sweep_20hz_20khz_mono.wav",
    "amplitude": "amplitude_ladder_1khz_mono.wav",
    "multitone": "multitone_mono.wav",
    "smpteIMD": "smpte_imd_60hz_7khz_mono.wav",
    "ccifIMD": "ccif_imd_19khz_20khz_mono.wav",
    "bursts": "deterministic_noise_bursts_mono.wav",
    "guitar": "guitar_like_dynamic_plucks_mono.wav",
    "bass": "bass_like_dynamic_plucks_mono.wav",
    "vocal": "vocal_like_mono.wav",
    "stereoInPhase": "stereo_in_phase.wav",
    "stereoLeft": "stereo_left_only.wav",
    "stereoRight": "stereo_right_only.wav",
    "stereoAntiPhase": "stereo_anti_phase.wav",
    "stereoOffset": "stereo_one_sample_offset.wav",
    "stereoFrequencySplit": "stereo_mid_low_side_high.wav",
}

LINEAR = ("silence", "impulse", "sweep", "multitone", "amplitude")
NONLINEAR = ("silence", "impulseLevels", "sweep", "amplitude", "multitone", "smpteIMD", "ccifIMD", "bursts")
DYNAMICS = ("silence", "impulseLevels", "amplitude", "multitone", "bursts", "vocal", "guitar")
TIME = ("silence", "impulse", "sweep", "bursts", "vocal", "guitar")
STEREO = ("stereoInPhase", "stereoLeft", "stereoRight", "stereoAntiPhase", "stereoOffset", "stereoFrequencySplit")
PITCH = ("silence", "impulse", "bursts", "vocal", "guitar", "bass", "stereoInPhase")

NONLINEAR_FAMILIES = {
    "amp", "distortion", "specialized", "pedalboard_distortion",
}
DYNAMICS_FAMILIES = {"dynamics", "pedalboard_dynamics_filter", "mastering"}
TIME_FAMILIES = {
    "delay", "reverb", "modulation", "multi_effect",
    "pedalboard_delay_ambience", "pedalboard_modulation",
}
PITCH_FAMILIES = {"pitch", "pedalboard_pitch"}
LINEAR_FAMILIES = {"equalizer", "filter", "imaging", "legacy"}

PEDALBOARD_PROFILE_NAMES = {
    "pedal_delay_or_ambience": {
        "Blue Echo", "Spring Box", "Tie Dye Delay", "Tru-Tape Delay",
    },
    "pedal_nonlinear_drive_or_fuzz": {
        "Candy Fuzz", "Double Dragon", "Fuzz Machine", "Grinder", "Grit",
        "Happy Face Fuzz", "Hi-Drive", "Monster Fuzz", "Octafuzz",
        "Rawk! Distortion", "Tube Burner", "Vintage Drive",
    },
    "pedal_dynamics": {"Squash Compressor"},
    "pedal_envelope_filter": {"Auto-Funk"},
    "pedal_manual_filter_or_eq": {"Classic Wah", "Graphic EQ", "Modern Wah"},
    "pedal_modulation": {
        "Flange Factory", "Heavenly Chorus", "Phase Tripper", "Phaze 2",
        "Retro Chorus", "Robo Flanger", "Roswell Ringer", "Roto Phase",
        "Spin Box", "The Vibe", "Total Tremolo", "Trem-O-Tone",
    },
    "pedal_pitch": {"Dr. Octave", "Wham"},
    "pedalboard_routing_utility": {"Mixer", "Splitter"},
}
PEDALBOARD_PROFILE_BY_NAME = {
    name: profile
    for profile, names in PEDALBOARD_PROFILE_NAMES.items()
    for name in names
}
if len(PEDALBOARD_PROFILE_BY_NAME) != 37:
    raise RuntimeError("Pedalboard measurement profiles must cover 35 pedals plus two utilities")

CORE_EFFECT_REQUIREMENTS: dict[str, dict[str, tuple[str, ...] | str]] = {
    "Gain": {
        "profile": "core_gain_channel_matrix_and_level_baseline",
        "lanes": ("core_effect_priority_lane", "gain_channel_matrix_and_null_lane"),
        "fixtures": LINEAR + STEREO,
        "dimensions": (
            "gain_scale_unity_minimum_maximum_and_level_independence",
            "left_right_polarity_balance_swap_and_format_specific_channel_matrix",
            "mono_sum_gain_peak_and_antiphase_cancellation_behavior",
            "bit_exact_or_residual_null_at_documented_neutral_state",
        ),
    },
    "Channel EQ": {
        "profile": "core_channel_eq_filter_phase_channel_mode_and_headroom",
        "lanes": ("core_effect_priority_lane", "channel_eq_response_phase_and_channel_mode_lane"),
        "fixtures": LINEAR + ("impulseLevels", "bursts") + STEREO,
        "dimensions": (
            "each_band_enable_type_frequency_gain_q_and_pass_filter_slope_states",
            "single_band_and_coupled_multiband_magnitude_phase_group_delay_and_headroom",
            "stereo_left_right_mid_side_processing_and_mono_translation",
            "oversampling_output_gain_and_input_level_invariance_or_nonlinearity_rejection",
            "analyzer_pre_post_and_display_state_audio_null_and_save_reload",
        ),
    },
    "Linear Phase EQ": {
        "profile": "core_linear_phase_eq_latency_preringing_and_transient_tradeoff",
        "lanes": ("core_effect_priority_lane", "linear_phase_eq_latency_preringing_and_transient_lane"),
        "fixtures": LINEAR + ("impulseLevels", "bursts", "guitar") + STEREO,
        "dimensions": (
            "band_response_phase_preservation_reported_and_measured_latency",
            "impulse_pre_ringing_post_ringing_and_steep_narrow_filter_transient_behavior",
            "channel_modes_output_gain_headroom_and_mono_translation",
            "matched_curve_comparison_against_channel_eq_without_better_worse_claim",
        ),
    },
    "Compressor": {
        "profile": "core_compressor_static_detector_ballistics_link_and_color",
        "lanes": ("core_effect_priority_lane", "compressor_static_detector_ballistics_and_link_lane"),
        "fixtures": DYNAMICS + ("sweep", "smpteIMD", "ccifIMD", "bass") + STEREO,
        "dimensions": (
            "threshold_ratio_knee_static_curve_makeup_autogain_and_level_matched_bypass",
            "attack_release_auto_release_overshoot_recovery_pumping_and_program_dependence",
            "peak_rms_detector_sidechain_filter_and_external_sidechain_where_safely_available",
            "seven_circuit_models_distortion_modes_limiter_and_dry_wet_parallel_behavior",
            "stereo_max_sum_link_left_right_asymmetry_and_mono_translation",
            "transient_sustain_noise_low_end_and_source_specific_preservation_listening",
        ),
    },
    "DeEsser 2": {
        "profile": "core_deesser_event_detection_band_reduction_and_breath_preservation",
        "lanes": ("core_effect_priority_lane", "deesser_event_detection_and_band_reduction_lane"),
        "fixtures": DYNAMICS + ("sweep", "vocal", "stereoLeft", "stereoRight"),
        "dimensions": (
            "relative_absolute_detection_threshold_and_level_dependence",
            "frequency_range_split_wide_and_maximum_reduction_response",
            "short_high_band_event_reduction_versus_static_brightness_nontrigger",
            "consonant_intelligibility_breath_air_and_lisp_risk_on_vocal_material",
            "stereo_link_channel_specific_events_latency_and_level_matched_bypass",
        ),
    },
    "Noise Gate": {
        "profile": "core_noise_gate_ducker_hysteresis_timing_and_decay_preservation",
        "lanes": ("core_effect_priority_lane", "noise_gate_ducker_hysteresis_and_timing_lane"),
        "fixtures": DYNAMICS + ("sweep", "bass") + STEREO,
        "dimensions": (
            "gate_ducker_threshold_hysteresis_reduction_and_input_level_states",
            "attack_hold_release_lookahead_chatter_retrigger_and_recovery",
            "sidechain_filter_frequency_dependence_and_false_open_close_behavior",
            "breath_room_decay_cymbal_tail_note_end_and_noise_floor_preservation",
        ),
    },
    "Enveloper": {
        "profile": "core_enveloper_attack_release_detector_and_spill_tradeoff",
        "lanes": ("core_effect_priority_lane", "enveloper_attack_release_and_detector_lane"),
        "fixtures": DYNAMICS + ("bass", "stereoInPhase"),
        "dimensions": (
            "attack_gain_and_time_response_across_transient_level_and_duration",
            "release_gain_and_time_response_sustain_room_spill_and_noise",
            "detector_filter_gain_stage_peak_headroom_and_reset_behavior",
            "drum_bass_guitar_attack_and_cymbal_or_pick_preservation_listening",
        ),
    },
    "ChromaVerb": {
        "profile": "core_chromaverb_early_late_decay_spectrum_modulation_and_depth",
        "lanes": ("core_effect_priority_lane", "chromaverb_impulse_tail_depth_and_stereo_lane"),
        "fixtures": TIME + ("bass",) + STEREO,
        "dimensions": (
            "every_room_algorithm_and_default_impulse_early_late_tail_identity",
            "predelay_attack_size_density_distance_dry_wet_and_early_late_interactions",
            "decay_frequency_dependent_damping_output_eq_and_low_frequency_mono",
            "modulation_quality_width_channel_matrix_tail_repeatability_and_mono_translation",
            "vocal_drum_guitar_synth_depth_articulation_masking_and_level_matched_listening",
        ),
    },
    "Space Designer": {
        "profile": "core_space_designer_ir_asset_convolution_envelope_filter_and_format",
        "lanes": ("core_effect_priority_lane", "space_designer_ir_asset_and_convolution_lane"),
        "fixtures": TIME + ("bass",) + STEREO,
        "dimensions": (
            "recorded_synthesized_ir_identity_hash_sample_rate_length_and_reload",
            "latency_impulse_tail_linearity_level_dependence_and_time_variance_rejection",
            "ir_envelope_filter_eq_reverse_density_and_dry_wet_where_applicable",
            "mono_stereo_true_stereo_channel_matrix_tail_and_mono_translation",
            "source_depth_articulation_masking_and_level_matched_listening",
        ),
    },
    "Stereo Delay": {
        "profile": "core_stereo_delay_dual_time_crossfeed_feedback_phase_and_mono",
        "lanes": ("core_effect_priority_lane", "stereo_delay_timing_crossfeed_and_feedback_lane"),
        "fixtures": TIME + ("multitone", "bass") + STEREO,
        "dimensions": (
            "left_right_free_sync_time_division_and_tempo_change_accuracy",
            "input_source_crossfeed_feedback_routing_and_runaway_peak_safety",
            "filter_phase_and_dry_wet_effect_on_repeat_spectrum_and_mono_sum",
            "tail_decay_transition_repeatability_realtime_offline_and_save_reload",
            "rhythmic_masking_width_articulation_and_level_matched_source_listening",
        ),
    },
    "Tape Delay": {
        "profile": "core_tape_delay_time_instability_feedback_color_freeze_and_spread",
        "lanes": ("core_effect_priority_lane", "tape_delay_instability_feedback_color_and_freeze_lane"),
        "fixtures": TIME + ("amplitude", "multitone", "ccifIMD", "bass") + STEREO,
        "dimensions": (
            "free_sync_time_deviation_smoothing_tempo_change_and_repeat_timing",
            "feedback_filtering_decay_clipping_threshold_head_and_runaway_peak_safety",
            "lfo_flutter_sidebands_pitch_stability_spread_channel_matrix_and_mono_sum",
            "freeze_enter_exit_tail_state_repeatability_realtime_offline_and_reload",
            "dry_wet_level_matched_rhythm_articulation_masking_and_source_listening",
        ),
    },
    "ChromaGlow": {
        "profile": "core_chromaglow_model_style_threshold_filter_transfer_and_alias",
        "lanes": ("core_effect_priority_lane", "chromaglow_nonlinear_model_and_threshold_lane"),
        "fixtures": NONLINEAR + ("guitar", "bass", "vocal") + STEREO,
        "dimensions": (
            "every_model_style_drive_output_mix_and_level_matched_bypass",
            "static_transfer_symmetry_harmonics_imd_alias_dc_noise_and_sample_rate_dependence",
            "bypass_below_threshold_trigger_release_and_quiet_material_preservation",
            "pre_post_low_high_filter_operating_point_and_generated_harmonic_interaction",
            "transient_dynamic_low_end_note_separation_harshness_and_source_listening",
        ),
    },
    "Overdrive": {
        "profile": "core_overdrive_drive_tone_transfer_imd_alias_and_transient",
        "lanes": ("core_effect_priority_lane", "overdrive_transfer_tone_and_alias_lane"),
        "fixtures": NONLINEAR + ("guitar", "bass", "vocal") + STEREO,
        "dimensions": (
            "drive_tone_output_static_transfer_and_level_matched_bypass",
            "harmonics_imd_alias_dc_noise_and_sample_rate_dependence",
            "tone_control_pre_post_nonlinearity_inference_boundary_and_headroom",
            "transient_dynamic_low_end_note_separation_and_source_specific_listening",
        ),
    },
    "Limiter": {
        "profile": "core_limiter_peak_ceiling_release_lookahead_true_peak_and_artifact",
        "lanes": ("core_effect_priority_lane", "limiter_peak_release_true_peak_and_artifact_lane"),
        "fixtures": DYNAMICS + ("sweep", "ccifIMD", "bass") + STEREO,
        "dimensions": (
            "gain_ceiling_static_peak_behavior_legacy_precision_and_level_matched_bypass",
            "lookahead_reported_measured_latency_release_recovery_and_repeated_transients",
            "true_peak_mode_external_oversampled_peak_comparison_across_supported_rates",
            "gain_reduction_density_distortion_pumping_stereo_link_and_mono_translation",
            "standards_delivery_claim_boundary_and_source_specific_listening",
        ),
    },
    "Adaptive Limiter": {
        "profile": "core_adaptive_limiter_gain_ceiling_optimal_dc_true_peak_and_density",
        "lanes": ("core_effect_priority_lane", "adaptive_limiter_peak_density_and_true_peak_lane"),
        "fixtures": DYNAMICS + ("sweep", "ccifIMD", "bass") + STEREO,
        "dimensions": (
            "input_gain_output_ceiling_peak_behavior_and_level_matched_bypass",
            "lookahead_latency_release_recovery_optimal_mode_and_program_dependence",
            "dc_removal_true_peak_mode_and_external_oversampled_peak_comparison",
            "density_distortion_pumping_stereo_link_mono_translation_and_sample_rate",
            "standards_delivery_claim_boundary_and_source_specific_listening",
        ),
    },
    "Loudness Meter": {
        "profile": "core_loudness_meter_readout_window_gate_reset_and_external_vector",
        "lanes": ("core_effect_priority_lane", "loudness_meter_external_vector_and_readout_lane"),
        "fixtures": DYNAMICS + STEREO,
        "dimensions": (
            "momentary_short_term_integrated_loudness_window_update_and_units",
            "absolute_relative_gate_start_stop_pause_reset_and_short_program_behavior",
            "loudness_range_true_peak_channel_weighting_and_supported_format_behavior",
            "closest_available_official_external_vector_and_tracksmith_meter_comparison",
            "logic_readout_evidence_without_unproven_formal_conformance_claim",
        ),
    },
    "MultiMeter": {
        "profile": "core_multimeter_spectrum_level_correlation_and_loudness_readout",
        "lanes": ("core_effect_priority_lane", "multimeter_readout_ballistics_and_manual_contradiction_lane"),
        "fixtures": LINEAR + DYNAMICS + STEREO,
        "dimensions": (
            "spectrum_frequency_level_resolution_peak_hold_and_display_ballistics",
            "peak_rms_gain_channel_link_calibration_and_reset_behavior",
            "goniometer_correlation_channel_matrix_and_antiphase_behavior",
            "loudness_readout_comparison_and_apparent_aes_128_manual_error_boundary",
            "meter_display_state_audio_null_and_save_reload",
        ),
    },
    "Direction Mixer": {
        "profile": "core_direction_mixer_lr_ms_split_width_direction_and_mono",
        "lanes": ("core_effect_priority_lane", "direction_mixer_channel_matrix_and_mono_lane"),
        "fixtures": LINEAR + STEREO,
        "dimensions": (
            "lr_ms_mode_direction_spread_minimum_unity_above_unity_and_polarity",
            "split_high_low_crossover_frequency_dependent_mid_side_transfer",
            "left_right_channel_matrix_gain_peak_correlation_low_band_side_and_mono_sum",
            "width_direction_localization_low_end_and_source_specific_listening",
        ),
    },
    "Correlation Meter": {
        "profile": "core_correlation_meter_window_ballistics_and_frequency_local_failure",
        "lanes": ("core_effect_priority_lane", "correlation_meter_readout_and_limitation_lane"),
        "fixtures": STEREO,
        "dimensions": (
            "in_phase_antiphase_left_right_offset_and_frequency_split_readout",
            "window_update_peak_hold_reset_and_transport_behavior",
            "comparison_with_offline_zero_lag_and_frequency_local_mono_loss_evidence",
            "explicit_boundary_that_correlation_is_risk_evidence_not_spatial_quality",
        ),
    },
    "Pitch Correction": {
        "profile": "core_pitch_correction_scale_range_response_tolerance_and_artifact",
        "lanes": ("core_effect_priority_lane", "pitch_correction_monophonic_tracking_and_artifact_lane"),
        "fixtures": PITCH + ("multitone", "stereoLeft", "stereoRight"),
        "dimensions": (
            "scale_grid_root_bypass_notes_reference_tuning_and_input_range_states",
            "response_tolerance_tracking_latency_retrigger_vibrato_slide_and_transition_behavior",
            "confidence_pitch_range_noise_unvoiced_and_deliberate_out_of_scale_noncorrection",
            "polyphonic_chord_failure_formant_timbre_transient_and_artifact_behavior",
            "performance_intent_source_identity_and_level_matched_listening",
        ),
    },
}


def load(name: str) -> dict[str, Any]:
    return json.loads((KNOWLEDGE / name).read_text(encoding="utf-8"))


def unique(values: tuple[str, ...] | list[str]) -> list[str]:
    return list(dict.fromkeys(values))


def evidence_runs() -> dict[str, list[tuple[pathlib.Path, dict[str, Any]]]]:
    by_identity: dict[str, list[tuple[pathlib.Path, dict[str, Any]]]] = {}
    seen_run_ids: set[str] = set()
    for path in sorted(EVIDENCE_ROOT.glob("*/run.json")):
        record = json.loads(path.read_text(encoding="utf-8"))
        if record.get("schemaVersion") != "1.0":
            raise SystemExit(f"unsupported evidence-run schema: {path}")
        run_id = record.get("runID")
        identifier = record.get("identityIdentifier")
        status = record.get("status")
        if not isinstance(run_id, str) or not run_id:
            raise SystemExit(f"evidence run has no runID: {path}")
        if run_id in seen_run_ids:
            raise SystemExit(f"duplicate evidence runID: {run_id}")
        seen_run_ids.add(run_id)
        if not isinstance(identifier, str) or not identifier:
            raise SystemExit(f"evidence run has no identityIdentifier: {path}")
        if status not in {"partial", "complete"}:
            raise SystemExit(f"invalid evidence status for {run_id}: {status}")
        if not isinstance(record.get("exactTransferCharacterized"), bool):
            raise SystemExit(f"missing exact-transfer boundary for {run_id}")
        if status == "partial" and record["exactTransferCharacterized"]:
            raise SystemExit(f"partial run cannot claim exact transfer: {run_id}")
        if not isinstance(record.get("dimensionCoverage"), dict):
            raise SystemExit(f"evidence run has no dimensionCoverage: {run_id}")
        if not record.get("artifactFiles"):
            raise SystemExit(f"evidence run has no artifact ledger: {run_id}")
        by_identity.setdefault(identifier, []).append((path, record))
    return by_identity


def merge_evidence(
    campaign_entries: list[dict[str, Any]],
    runs_by_identity: dict[str, list[tuple[pathlib.Path, dict[str, Any]]]],
) -> None:
    indexed = {entry["identifier"]: entry for entry in campaign_entries}
    unknown = sorted(set(runs_by_identity) - set(indexed))
    if unknown:
        raise SystemExit(f"evidence runs reference unknown identities: {unknown}")
    for identifier, runs in runs_by_identity.items():
        entry = indexed[identifier]
        complete_runs = [record for _, record in runs if record["status"] == "complete"]
        entry["status"] = "complete" if complete_runs else "partial"
        entry["measuredRunIDs"] = sorted(record["runID"] for _, record in runs)
        entry["evidenceRunRecords"] = sorted(
            str(path.relative_to(ROOT)) for path, _ in runs
        )
        entry["exactTransferCharacterized"] = bool(
            complete_runs
            and any(record["exactTransferCharacterized"] for record in complete_runs)
        )


def pedalboard_lanes(name: str) -> tuple[str, list[str], list[str], list[str]]:
    profile = PEDALBOARD_PROFILE_BY_NAME[name]
    lanes = ["logic_native_documented_state_capture"]
    common = [
        "documented_default_and_bypass_path",
        "every_discrete_mode_model_algorithm_and_routing_state",
        "bounded_continuous_parameter_grid_with_interaction_followup",
        "reported_and_measured_latency_polarity_gain_peak_tail",
        "three_identical_renders_for_repeatability",
        "save_reload_state_and_source_hash_verification",
    ]
    if profile == "pedal_delay_or_ambience":
        return (
            profile,
            lanes + ["pedal_delay_reverb_tempo_tail_and_feedback_lane"],
            [FIXTURES[key] for key in unique(TIME + ("bass",) + STEREO)],
            common + [
                "free_sync_tempo_impulse_timing_feedback_decay_and_tail_where_applicable",
                "tone_filter_style_reverse_dirt_flutter_and_saturation_interactions_where_applicable",
                "dry_wet_mute_listen_transition_and_reload_behavior",
                "source_articulation_masking_pitch_stability_and_stereo_mono_translation",
            ],
        )
    if profile == "pedal_nonlinear_drive_or_fuzz":
        return (
            profile,
            lanes + ["pedal_nonlinear_transfer_harmonic_imd_alias_and_noise_lane"],
            [FIXTURES[key] for key in unique(NONLINEAR + ("guitar", "bass", "vocal") + STEREO)],
            common + [
                "input_operating_point_drive_output_gain_and_level_matched_bypass",
                "static_transfer_symmetry_harmonics_imd_alias_products_dc_and_self_noise",
                "tone_filter_fat_scoop_bias_texture_and_parallel_mix_interactions_where_applicable",
                "transient_sustain_dynamic_range_note_separation_and_low_end_preservation",
                "source_specific_level_matched_listening_with_downstream_headroom_check",
            ],
        )
    if profile == "pedal_dynamics":
        return (
            profile,
            lanes + ["pedal_effective_static_curve_attack_release_recovery_and_noise_lane"],
            [FIXTURES[key] for key in unique(DYNAMICS + ("bass",) + STEREO)],
            common + [
                "effective_static_curve_threshold_ratio_knee_and_makeup_without_private_topology_claim",
                "attack_overshoot_release_recovery_pumping_and_program_dependence",
                "sustain_output_level_noise_floor_transient_and_playing_dynamic_preservation",
                "source_specific_level_matched_listening",
            ],
        )
    if profile == "pedal_envelope_filter":
        return (
            profile,
            lanes + ["pedal_input_envelope_to_filter_motion_lane"],
            [FIXTURES[key] for key in unique(LINEAR + DYNAMICS + ("bass", "guitar") + STEREO)],
            common + [
                "sensitivity_and_filter_motion_across_input_level_attack_decay_and_playing_dynamics",
                "bandpass_lowpass_upward_downward_resonance_and_cutoff_states",
                "response_recovery_peak_headroom_and_note_to_note_consistency",
                "pre_post_compression_order_hypothesis_and_source_specific_listening",
            ],
        )
    if profile == "pedal_manual_filter_or_eq":
        return (
            profile,
            lanes + ["pedal_static_and_manually_swept_filter_response_lane"],
            [FIXTURES[key] for key in unique(LINEAR + ("bursts", "guitar", "bass") + STEREO)],
            common + [
                "minimum_center_maximum_pedal_or_band_positions_frequency_response_and_phase",
                "resonance_q_mode_fixed_band_interaction_output_gain_and_headroom_where_applicable",
                "manual_or_automation_gesture_timing_kept_separate_from_static_filter_transfer",
                "source_presence_body_pick_attack_and_harsh_peak_preservation",
            ],
        )
    if profile == "pedal_modulation":
        dimensions = common + [
            "rate_sync_depth_waveform_phase_transport_start_and_repeat_variance_where_applicable",
            "manual_delay_feedback_resonance_tone_and_dry_wet_interactions_where_applicable",
            "sidebands_notch_motion_pitch_motion_amplitude_motion_and_stereo_channel_matrix",
            "mono_fold_pitch_center_transient_groove_and_low_end_preservation",
            "source_specific_level_matched_listening_and_speed_transition_behavior",
        ]
        if name == "Roswell Ringer":
            dimensions.append(
                "carrier_frequency_fine_curve_feedback_and_sum_difference_sideband_map"
            )
        return (
            profile,
            lanes + ["pedal_modulation_sideband_time_variance_stereo_and_mono_lane"],
            [FIXTURES[key] for key in unique(TIME + ("amplitude", "multitone", "ccifIMD", "bass") + STEREO)],
            dimensions,
        )
    if profile == "pedal_pitch":
        return (
            profile,
            lanes + ["pedal_pitch_tracking_latency_transient_polyphony_and_mix_lane"],
            [FIXTURES[key] for key in unique(PITCH + ("multitone", "stereoLeft", "stereoRight"))],
            common + [
                "interval_tune_pedal_position_direct_shifted_voice_level_and_drive_where_applicable",
                "tracking_latency_retrigger_glide_transient_smear_and_repeated_note_consistency",
                "monophonic_interval_chord_polyphony_pitch_range_and_artifact_behavior",
                "formant_timbre_low_end_headroom_and_source_identity_preservation",
            ],
        )
    if profile == "pedalboard_routing_utility":
        return (
            profile,
            lanes + ["pedalboard_topology_channel_matrix_crossover_and_recombination_lane"],
            [FIXTURES[key] for key in unique(LINEAR + STEREO)],
            common + [
                "split_mix_position_equal_and_frequency_split_branch_identity",
                "branch_gain_solo_relationship_pan_crossover_and_channel_format_where_applicable",
                "branch_latency_polarity_null_recombination_peak_and_mono_fold",
                "before_inside_after_split_topology_and_save_reload_identity",
            ],
        )
    raise RuntimeError(f"unhandled Pedalboard profile: {profile}")


def effect_lanes(entry: dict[str, Any]) -> tuple[str, list[str], list[str], list[str]]:
    family = entry["family"]
    name = entry["name"]
    lanes = ["logic_native_documented_state_capture"]
    dimensions = [
        "documented_default_and_bypass_path",
        "every_discrete_mode_model_algorithm_and_routing_state",
        "bounded_continuous_parameter_grid_with_interaction_followup",
        "reported_and_measured_latency_polarity_gain_peak_tail",
        "three_identical_renders_for_repeatability",
        "save_reload_state_and_source_hash_verification",
    ]

    if name in PEDALBOARD_PROFILE_BY_NAME:
        return pedalboard_lanes(name)

    if name == "Scripter":
        return (
            "security_boundary",
            lanes + ["security_boundary_only_no_arbitrary_script_execution"],
            [],
            dimensions + ["confirm_advisory_knowledge_never_becomes_code_or_host_authority"],
        )
    if family == "midi_processor":
        return (
            "midi_event_behavior",
            lanes + ["midi_event_host_lane", "instrument_render_observation"],
            [],
            dimensions + ["input_and_output_midi_event_log", "channel_port_timing_and_transport_context"],
        )
    if family == "metering":
        return (
            "meter_readout_and_ballistics",
            lanes + ["meter_readout_conformance_lane"],
            [FIXTURES[key] for key in unique(LINEAR + DYNAMICS + STEREO)],
            dimensions + ["readout_capture_units_ballistics_gates_reset_and_channel_weighting"],
        )
    if name in {"I/O", "Auto Sampler"}:
        return (
            "external_device_or_asset_workflow",
            lanes + ["external_device_or_asset_workflow_manual_lane"],
            [],
            dimensions + ["external_route_asset_identity_latency_and_user_consent"],
        )
    if family == "pedalboard":
        return (
            "pedalboard_container_topology",
            lanes + ["pedalboard_topology_lane"],
            [
                FIXTURES[key]
                for key in unique(LINEAR + NONLINEAR + DYNAMICS + TIME + STEREO + ("guitar", "bass"))
            ],
            dimensions + ["serial_parallel_split_band_order_branch_gain_crossover_and_macro_state"],
        )
    if family in NONLINEAR_FAMILIES:
        fixture_keys = NONLINEAR + ("guitar", "bass", "vocal") + STEREO
        lanes.append("nonlinear_transfer_and_alias_lane")
        profile = "nonlinear_transfer"
    elif family in DYNAMICS_FAMILIES:
        fixture_keys = DYNAMICS + ("bass",) + STEREO
        lanes.append("static_curve_and_time_constant_lane")
        profile = "dynamics_static_and_time_behavior"
    elif family in TIME_FAMILIES:
        fixture_keys = TIME + ("bass",) + STEREO
        lanes.append("time_variance_tempo_tail_and_stereo_lane")
        profile = "time_variance_tempo_tail_and_stereo"
    elif family in PITCH_FAMILIES:
        fixture_keys = PITCH
        lanes.append("pitch_tracking_formant_transient_and_polyphony_lane")
        profile = "pitch_tracking_and_artifacts"
    elif family in LINEAR_FAMILIES:
        fixture_keys = LINEAR + STEREO
        lanes.append("linear_response_then_nonlinearity_rejection_lane")
        profile = "linear_response_then_nonlinearity_rejection"
    else:
        fixture_keys = LINEAR + DYNAMICS + STEREO
        lanes.append("utility_or_composite_behavior_lane")
        profile = "utility_or_composite_behavior"
    return profile, lanes, [FIXTURES[key] for key in unique(fixture_keys)], dimensions


def effect_record(entry: dict[str, Any]) -> dict[str, Any]:
    profile, lanes, fixtures, dimensions = effect_lanes(entry)
    core = CORE_EFFECT_REQUIREMENTS.get(entry["name"])
    if core is not None:
        profile = str(core["profile"])
        lanes = unique(lanes + list(core["lanes"]))
        fixtures = unique(
            fixtures + [FIXTURES[key] for key in core["fixtures"]]
        )
        dimensions = unique(dimensions + list(core["dimensions"]))
    return {
        "identityType": "effect_or_native_audio_tool",
        "identifier": entry["identifier"],
        "name": entry["name"],
        "family": entry["family"],
        "documentaryPages": entry["manualPages"],
        "measurementProfile": profile,
        "requiredLanes": lanes,
        "requiredFixtures": fixtures,
        "requiredDimensions": dimensions,
        "status": "not_run",
        "measuredRunIDs": [],
        "exactTransferCharacterized": False,
        "executionBoundary": "manual_disposable_logic_project_no_tracksmith_native_host_authority",
    }


def instrument_record(entry: dict[str, Any]) -> dict[str, Any]:
    dimensions = [
        "documented_default_and_every_engine_model_or_mode",
        "midi_note_range_velocity_ladder_note_length_release_and_retrigger",
        "pitch_bend_modulation_sustain_and_exposed_expression_controls",
        "mono_polyphony_unison_voice_stealing_and_repeated_note_behavior",
        "mono_stereo_output_routing_peak_nonfinite_latency_and_repeatability",
        "preset_project_save_reload_and_referenced_asset_identity",
        "rendered_output_hash_and_level_matched_real_musical_audition",
    ]
    if entry["name"] == "Quick Sampler":
        dimensions.extend(
            [
                "original_versus_optimized_and_region_drop_versus_file_drop",
                "classic_one_shot_slice_recorder_flex_filter_modulation_and_voice_state",
                "rename_write_loop_crop_reimport_and_conversion_only_on_disposable_asset_copies",
            ]
        )
    return {
        "identityType": "instrument_or_instrument_utility",
        "identifier": entry["identifier"],
        "name": entry["name"],
        "family": entry["family"],
        "documentaryPages": entry["manualPages"],
        "requiredLanes": ["logic_native_instrument_midi_and_audio_render_lane"],
        "requiredFixtures": ["versioned_deterministic_midi_note_velocity_expression_fixture"],
        "requiredDimensions": dimensions,
        "status": "not_run",
        "measuredRunIDs": [],
        "exactTransferCharacterized": False,
        "executionBoundary": "manual_disposable_logic_project_no_tracksmith_native_host_authority",
    }


def editor_record(entry: dict[str, Any]) -> dict[str, Any]:
    dimensions = [
        "correct_area_window_focus_and_left_command_right_tool_assignment",
        "empty_single_and_multiple_selection_scope",
        "snap_modifier_click_zone_and_object_type",
        "expected_state_identity_before_after_and_undo_redo",
        "save_reload_and_source_asset_hash_before_after",
        "unsupported_host_authority_and_no_accessibility_automation",
    ]
    if entry["stateScope"] == "audio_file_content":
        dimensions.append("destructive_audio_file_operation_only_on_disposable_copy")
    if "conversion" in entry["stateScope"] or "possible_derived_asset" in entry["stateScope"]:
        dimensions.append("conversion_and_derived_asset_identity")
    return {
        "identityType": "editor_tool",
        "identifier": entry["name"],
        "name": entry["name"],
        "areas": entry["areas"],
        "documentaryPages": entry["inventoryPages"],
        "stateScope": entry["stateScope"],
        "requiredLanes": ["manual_disposable_project_state_transition_lane"],
        "requiredFixtures": [],
        "requiredDimensions": dimensions,
        "status": "not_run",
        "measuredRunIDs": [],
        "exactTransferCharacterized": False,
        "executionBoundary": "manual_only_no_tracksmith_host_or_accessibility_authority",
    }


def main() -> int:
    effects = load("logic-pro-12.3-effects-knowledge.json")
    instruments = load("logic-pro-12.3-instrument-knowledge.json")
    editor_tools = load("logic-pro-12.3-editor-tool-knowledge.json")
    if effects["entryCount"] != 142 or instruments["entryCount"] != 28 or editor_tools["entryCount"] != 30:
        raise SystemExit("catalogue counts changed; review and version the campaign")
    effect_campaign = [effect_record(entry) for entry in effects["entries"]]
    instrument_campaign = [instrument_record(entry) for entry in instruments["entries"]]
    editor_campaign = [editor_record(entry) for entry in editor_tools["entries"]]
    if sum(1 for entry in effect_campaign if entry["family"].startswith("pedalboard_")) != 37:
        raise SystemExit("Pedalboard campaign must include 35 effects plus Mixer and Splitter")
    pedal_names = {
        entry["name"] for entry in effect_campaign if entry["family"].startswith("pedalboard_")
    }
    if pedal_names != set(PEDALBOARD_PROFILE_BY_NAME):
        raise SystemExit(
            "Pedalboard profile identities changed: "
            f"missing={sorted(pedal_names - set(PEDALBOARD_PROFILE_BY_NAME))} "
            f"stale={sorted(set(PEDALBOARD_PROFILE_BY_NAME) - pedal_names)}"
        )
    all_campaign_entries = effect_campaign + instrument_campaign + editor_campaign
    merge_evidence(all_campaign_entries, evidence_runs())
    status_counts = {
        status: sum(1 for entry in all_campaign_entries if entry["status"] == status)
        for status in ("not_run", "partial", "complete")
    }
    payload = {
        "schemaVersion": "1.2",
        "product": "TrackSmith",
        "logicVersion": "12.3",
        "logicBuild": "6674",
        "campaignVersion": "logic-pro-12.3-native-empirical-v1.1",
        "protocol": "docs/LOGIC_NATIVE_EMPIRICAL_MEASUREMENT_PROTOCOL.md",
        "fixtureSuiteVersion": "logic-native-measurement-suite-v1",
        "claimBoundary": {
            "documentaryCoverageComplete": True,
            "empiricalCampaignComplete": False,
            "artisticSuperiorityClaimed": False,
            "exactPrivateImplementationClaimed": False,
            "trackSmithHostExecutionAuthority": False,
        },
        "counts": {
            "effectsAndNativeAudioTools": len(effect_campaign),
            "instrumentAndInstrumentUtilities": len(instrument_campaign),
            "editorTools": len(editor_campaign),
            "totalIdentities": len(effect_campaign) + len(instrument_campaign) + len(editor_campaign),
            "pedalboardEffects": 35,
            "pedalboardRoutingUtilities": 2,
        },
        "statusCounts": status_counts,
        "requiredRunRecordFields": [
            "macOS_version_build_hardware",
            "Logic_version_build",
            "native_identity_channel_format_preset_all_parameters",
            "sample_rate_tempo_buffer_latency_mode_routing_and_gain_stage",
            "render_method_realtime_normalization_tail_encoding_dither_repeat",
            "input_and_output_sha256",
            "source_unchanged",
            "measurements_uncertainty_and_claim_class",
        ],
        "effects": effect_campaign,
        "instruments": instrument_campaign,
        "editorTools": editor_campaign,
    }
    OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"wrote {OUTPUT}: {len(effect_campaign)} effects/tools, "
        f"{len(instrument_campaign)} instruments, {len(editor_campaign)} editor tools; "
        f"status counts {status_counts}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
