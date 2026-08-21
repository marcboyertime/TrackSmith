#!/usr/bin/env python3
"""Build the external, candidate-only CommunityCandidateCorpus resource store.

Both supplied community packages remain immutable inputs.  This module is used by
the package-specific import entry points so either order reconstructs one shared
registry, review queue, runtime resource store, and evaluation-only fixtures.
"""
from __future__ import annotations
import argparse, copy, hashlib, json, os, pathlib, re, stat, subprocess, sys, tempfile

def lexical_absolute(path):
    return pathlib.Path(os.path.abspath(os.fspath(path)))
def assert_unlinked_absolute(path, expect_directory):
    path=lexical_absolute(path)
    if not path.is_absolute(): raise ValueError("preservation path is not absolute: "+str(path))
    current=pathlib.Path(path.anchor)
    if not stat.S_ISDIR(current.lstat().st_mode): raise ValueError("preservation filesystem root is unsafe: "+str(current))
    for index,part in enumerate(path.parts[1:]):
        current=current/part
        try: mode=current.lstat().st_mode
        except FileNotFoundError as error: raise ValueError("missing preservation path: "+str(current)) from error
        if stat.S_ISLNK(mode): raise ValueError("symlinked preservation path: "+str(current))
        if index < len(path.parts)-2 and not stat.S_ISDIR(mode): raise ValueError("non-directory preservation ancestor: "+str(current))
    if expect_directory and not stat.S_ISDIR(current.lstat().st_mode): raise ValueError("preservation root is not a directory: "+str(path))
    if not expect_directory and not stat.S_ISREG(current.lstat().st_mode): raise ValueError("preservation file is not regular: "+str(path))
    return path
def lexical_repository_root(script_path):
    script=assert_unlinked_absolute(script_path,False)
    return assert_unlinked_absolute(script.parents[2],True)
ROOT = lexical_repository_root(__file__)
K = ROOT / "research/knowledge"
REGISTRY = K / "general-tutor-source-registry.json"
QUEUE = K / "general-tutor-review-queue.json"
# P18 keeps the approved raw runtime projection under research/test ownership.
# The application target receives only CandidateRetrieval.sqlite and its manifest.
RES = ROOT / "research/community_knowledge/runtime_projection/p16"
EVAL = ROOT / "tools/TutorConversationTests/Resources"
DESCRIPTOR = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.generated.swift"
P6_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-006-saturation-transient-shaping.json"
P7_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning.json"
P8_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-008-editing-layering.json"
P9_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-009-gain-staging-bus-processing-loudness.json"
P10_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-010-flex-time-manual-timing.json"
P11_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping.json"
P12_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-012-recording-latency-monitoring-comping-punch.json"
P13_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-013-sends-buses-auxes-track-stacks-groups-submixes.json"
P14_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-014-sidechain-automation-midi-groove-velocity-transform.json"
P15_BASELINE=ROOT/"research/community_knowledge/preservation_baselines/tracksmith-corpus-015-midi-cc-piano-roll-bounce-freeze-pdc-object-model.json"
PACKAGES = {
 "community-vocal-quantization-v1": dict(canonical=214, utterances=3290, scenarios=428, contradictions=17, myths=0, sources=34, candidatePrefix="candidate.", original={"claim":"candidate_not_reviewed","strategy":"candidate_not_reviewed","procedure":"candidate_requires_installed_logic_verification"}),
 "community-level-balancing-eq-v1": dict(canonical=238, utterances=4007, scenarios=714, contradictions=23, myths=30, sources=81, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}),
 "community-compression-arrangement-frequency-allocation-v1": dict(canonical=350, utterances=7700, scenarios=1050, evaluations=1750, contradictions=36, myths=48, sources=91, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}),
 "community-reverb-delay-v1": dict(canonical=300, utterances=6600, scenarios=900, retrieval=1500, contradictions=40, myths=50, sources=105, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-005-automation": dict(canonical=240, utterances=5280, scenarios=720, retrieval=1200, contradictions=36, myths=44, sources=63, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-006-saturation-transient-shaping": dict(canonical=384, utterances=8448, scenarios=1152, retrieval=1920, contradictions=42, myths=50, sources=82, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-007-phase-polarity-stereo-imaging-panning": dict(canonical=396, utterances=8712, scenarios=1188, retrieval=1980, contradictions=42, myths=50, sources=82, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-008-editing-layering": dict(canonical=420, utterances=9240, scenarios=1260, retrieval=2100, contradictions=46, myths=54, sources=95, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-009-gain-staging-bus-processing-loudness": dict(canonical=430, utterances=9460, scenarios=1290, retrieval=2150, contradictions=48, myths=56, sources=95, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-010-flex-time-manual-timing": dict(canonical=450, utterances=10350, scenarios=1350, retrieval=2250, contradictions=48, myths=56, sources=81, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping": dict(canonical=450, utterances=10350, scenarios=1350, retrieval=2250, contradictions=50, myths=60, sources=79, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-012-recording-latency-monitoring-comping-punch": dict(canonical=480, utterances=11040, scenarios=1440, retrieval=2400, contradictions=52, myths=64, sources=84, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-013-sends-buses-auxes-track-stacks-groups-submixes": dict(canonical=480, utterances=11040, scenarios=1440, retrieval=2400, contradictions=52, myths=64, sources=88, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-014-sidechain-automation-midi-groove-velocity-transform": dict(canonical=660, utterances=15180, scenarios=1980, retrieval=3300, contradictions=66, myths=78, sources=88, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
 "tracksmith-corpus-015-midi-cc-piano-roll-bounce-freeze-pdc-object-model": dict(canonical=720, utterances=16560, scenarios=2160, retrieval=3600, contradictions=72, myths=84, sources=90, candidatePrefix="", original={"claim":"candidate_not_yet_human_reviewed","strategy":"candidate_not_yet_human_reviewed","procedure":"candidate_not_yet_human_reviewed"}, verification="candidate_unverified_on_installed_logic"),
}
TIERS={"A":"tierAPrimaryOrDirect","B":"tierBReviewedProfessionalPractice","C":"tierCDiscoveryOrAnecdotal"}
NAV=("audio track editor","piano roll","audio fx","channel strip","region inspector"," inspector","flex mode menu","quantize menu","menu path","press i","open the ","open a ","select the ","select a ","show inspector")
FALLBACK="Run one reversible duplicate comparison of the candidate technique; use get_logic_procedure for exact Logic navigation."
SAFE_P3_FALLBACK="Run one reversible, level-matched comparison of one candidate variable; listen in context for the named improvement, stop if a preservation goal worsens, then undo to the saved state."
P1_ANCHORS={"contradiction.vocal.deess_manual":"vocal.tone.sibilant","contradiction.vocal.source_vs_fix":"vocal.recording.performance_weak","contradiction.quant.full_vs_partial":"quant.midi.q_strength"}
P1_LEGACY_SHA256="8f4bffcc038ec6bb2a953d2c270ce1a346d890eccb449a88fea47b78f0c57906"
P1_GENERIC={"a","an","and","auto","automatic","context","effects","full","manual","one","or","partial","the","to","versus","vs","with","vocal","quant","contradiction","lead","using","use"}
P2_CONTRADICTION_ANCHORS={
"contradiction.fixed_track_target":"level.foundation.fixed_track_peak_myth","contradiction.faders_at_unity":"level.foundation.faders_near_zero","contradiction.master_vs_channels":"level.foundation.master_fader_vs_tracks","contradiction.normalize_all":"level.foundation.normalization_vs_balance","contradiction.mix_in_mono":"level.foundation.mono_balance","contradiction.limiter_from_start":"level.foundation.limiter_while_mixing","contradiction.eq_first_or_comp_first":"eq.foundation.eq_before_compression","contradiction.cut_never_boost":"eq.foundation.subtractive_vs_additive","contradiction.highpass_everything":"eq.foundation.high_pass_everything","contradiction.narrow_surgical":"eq.foundation.wide_vs_narrow","contradiction.eq_in_solo":"eq.foundation.eq_in_solo","contradiction.analyzer":"eq.foundation.analyzer_use","contradiction.linear_phase":"eq.foundation.linear_phase","contradiction.dynamic_eq":"eq.foundation.dynamic_eq","contradiction.match_eq":"eq.foundation.match_eq","contradiction.midside":"eq.foundation.mid_side_eq","contradiction.boost_target_cut_competitor":"eq.foundation.boost_vs_cut_relative","contradiction.automation_compression":"level.foundation.automation_vs_compression","contradiction.clip_gain_fader":"level.foundation.fader_vs_region_gain","contradiction.reference_curve":"level.foundation.reference_level_match","contradiction.pink_noise":"level.foundation.meter_vs_ear","contradiction.master_eq_or_remix":"eq.foundation.master_eq","contradiction.vintage_clean":"eq.foundation.vintage_vs_clean"}
P2_MYTH_ANCHORS={
"myth.001":"level.foundation.fixed_track_peak_myth","myth.002":"level.foundation.headroom_target","myth.003":"level.foundation.master_fader_vs_tracks","myth.004":"level.foundation.normalization_vs_balance","myth.005":"level.foundation.plugin_gain_match","myth.006":"level.foundation.faders_near_zero","myth.007":"eq.foundation.boost_vs_cut_relative","myth.008":"eq.foundation.high_pass_everything","myth.009":"eq.foundation.subtractive_vs_additive","myth.010":"eq.foundation.frequency_chart_myth","myth.011":"eq.foundation.analyzer_use","myth.012":"eq.foundation.eq_in_solo","myth.013":"eq.foundation.linear_phase","myth.014":"eq.foundation.dynamic_eq","myth.015":"eq.foundation.match_eq","myth.016":"eq.foundation.mid_side_eq","myth.017":"level.foundation.meter_vs_ear","myth.018":"level.foundation.automation_vs_compression","myth.019":"level.foundation.fader_vs_region_gain","myth.020":"level.foundation.limiter_while_mixing","myth.021":"level.source.lead_vocal.buried","myth.022":"eq.source.full_mix.muddy","myth.023":"eq.source.full_mix.harsh","myth.024":"eq.foundation.eq_in_solo","myth.025":"eq.foundation.analyzer_use","myth.026":"eq.foundation.vintage_vs_clean","myth.027":"level.foundation.anchor_element","myth.028":"level.foundation.mono_balance","myth.029":"level.foundation.mix_too_quiet","myth.030":"eq.foundation.over_eq"}
P3_CONTRADICTION_ANCHORS={"contradiction.01.compression.eq_before_after":"compression.foundation.eq_order","contradiction.02.compression.fast_slow_attack":"compression.foundation.attack","contradiction.03.compression.fast_slow_release":"compression.foundation.release","contradiction.04.compression.serial_single":"compression.vocal.serial","contradiction.05.compression.automation_compression":"compression.foundation.compression_vs_automation","contradiction.06.compression.parallel_insert":"compression.drums.parallel","contradiction.07.compression.mixbus_early_late":"compression.bus.mix_into","contradiction.08.compression.multiband_dynamic_eq":"compression.advanced.dynamic_eq_vs_mb","contradiction.09.compression.vocal_track_bus":"compression.bus.vocal_bus","contradiction.10.compression.sidechain_full_band":"compression.sidechain.multiband","contradiction.11.arrangement.add_subtract":"arrangement.roles.underarranged","contradiction.12.arrangement.bridge":"arrangement.section.bridge_needed","contradiction.13.arrangement.chorus_layers":"arrangement.section.chorus_too_crowded","contradiction.14.arrangement.double_vocals":"arrangement.roles.doubles_everywhere","contradiction.15.arrangement.section_lengths":"arrangement.section.odd_length_section","contradiction.16.arrangement.reference":"arrangement.foundation.reference_map","contradiction.17.arrangement.busy_minimal":"arrangement.roles.drums_too_busy","contradiction.18.arrangement.transitions":"arrangement.section.transition_abrupt","contradiction.19.frequency.cut_target_masker":"frequency.foundation.masking","contradiction.20.frequency.cut_boost":"frequency.foundation.level_first","contradiction.21.frequency.highpass_all":"frequency.low_end.highpass_everything","contradiction.22.frequency.static_dynamic":"frequency.technique.dynamic_eq","contradiction.23.frequency.arrangement_eq":"frequency.foundation.arrangement_first","contradiction.24.frequency.pan_eq":"frequency.foundation.pan_width","contradiction.25.frequency.kick_bass":"frequency.pair.kick_bass","contradiction.26.frequency.master_source":"frequency.low_end.master_low_end","contradiction.27.frequency.spectral_tools":"frequency.technique.spectral_unmask","contradiction.28.frequency.vocal_slot":"frequency.vocal_midrange.vocal_guitars","contradiction.29.frequency.low_mono":"frequency.low_end.low_end_mono","contradiction.30.frequency.chart":"frequency.foundation.frequency_chart","contradiction.31.frequency.level_eq":"frequency.foundation.level_first","contradiction.32.frequency.reverb_filter":"frequency.vocal_midrange.vocal_reverb","contradiction.33.frequency.doubles":"frequency.vocal_midrange.doubles_lead","contradiction.34.frequency.multiband_sidechain":"frequency.technique.multiband_sidechain","contradiction.35.frequency.reference_curve":"frequency.technique.reference","contradiction.36.frequency.solo_context":"frequency.technique.mute_test"}
P3_MYTH_ANCHORS={"myth.01":"compression.foundation.how_much_gr","myth.02":"compression.foundation.what_compression_does","myth.03":"compression.foundation.attack","myth.04":"compression.foundation.attack","myth.05":"compression.foundation.release","myth.06":"compression.foundation.auto_gain","myth.07":"compression.vocal.track_print","myth.08":"compression.vocal.serial","myth.09":"compression.drums.parallel","myth.10":"compression.bus.glue","myth.11":"compression.foundation.compressor_vs_limiter","myth.12":"compression.advanced.dynamic_eq_vs_mb","myth.13":"compression.sidechain.internal_hpf","myth.14":"compression.hearing.gain_reduction_meter","myth.15":"compression.foundation.compression_vs_automation","myth.16":"compression.foundation.same_settings_different","myth.17":"arrangement.section.chorus_too_crowded","myth.18":"arrangement.section.bridge_needed","myth.19":"arrangement.foundation.density","myth.20":"frequency.foundation.arrangement_first","myth.21":"arrangement.section.odd_length_section","myth.22":"arrangement.section.second_verse_repeat","myth.23":"arrangement.section.riser_overuse","myth.24":"arrangement.roles.doubles_everywhere","myth.25":"arrangement.foundation.track_stacks","myth.26":"arrangement.foundation.markers","myth.27":"arrangement.roles.backing_vocals","myth.28":"arrangement.foundation.loop_to_song","myth.29":"arrangement.foundation.reference_map","myth.30":"arrangement.roles.countermelody","myth.31":"arrangement.section.breakdown_empty","myth.32":"arrangement.section.transition_too_smooth","myth.33":"frequency.foundation.role_not_band","myth.34":"frequency.foundation.frequency_chart","myth.35":"frequency.low_end.highpass_everything","myth.36":"frequency.foundation.masking","myth.37":"frequency.foundation.arrangement_first","myth.38":"frequency.foundation.level_first","myth.39":"frequency.foundation.pan_width","myth.40":"frequency.technique.analyzer","myth.41":"frequency.low_end.kick_bass_roles","myth.42":"frequency.technique.dynamic_eq","myth.43":"frequency.technique.spectral_unmask","myth.44":"frequency.vocal_midrange.vocal_formants","myth.45":"frequency.low_end.low_end_mono","myth.46":"frequency.technique.reference","myth.47":"frequency.technique.mute_test","myth.48":"frequency.foundation.arrangement_first"}
P3_MYTH_ANCHORS.update({"myth.02":"compression.foundation.what_it_does","myth.14":"compression.hearing.meter_vs_ear","myth.25":"arrangement.logic.track_stacks","myth.26":"arrangement.logic.markers","myth.28":"arrangement.roles.loop_syndrome","myth.48":"frequency.technique.register_revoice"})
P3_SOURCE_COLLISIONS={"apple.logic.deesser2","apple.logic.groups","apple.logic.multimeter","apple.logic.vca","izotope.dynamic_eq","izotope.high_end","izotope.transparent_compression","logicprohelp.parallel_compression","sos.mix_mono","sos.mix_rescue_metal","sos.mixing_essentials","sos.stereo_width"}
P4_SOURCE_COLLISIONS={"apple.logic.automation","apple.logic.low_latency","gearspace.vocal_chain"}
# These are deliberately complete, explicit anchor maps rather than a broad
# source-only attachment heuristic.  P4 disagreements remain reachable but do
# not become broadly attached advice.
P4_CONTRADICTION_ANCHORS={
"contradiction.reverb.insert_vs_send":"reverb.routing_and_processing.insert_vs_send", "contradiction.reverb.predelay_tempo":"reverb.foundations.predelay", "contradiction.reverb.eq_order":"reverb.routing_and_processing.eq_before_vs_after", "contradiction.reverb.deess_order":"reverb.routing_and_processing.deess_reverb", "contradiction.reverb.ducking_vs_automation":"reverb.routing_and_processing.ducked_reverb", "contradiction.reverb.one_shared_vs_many":"reverb.routing_and_processing.shared_reverb", "contradiction.reverb.algorithmic_vs_convolution":"reverb.foundations.algorithmic_vs_convolution", "contradiction.reverb.plate_vs_room_vocal":"reverb.creative_and_sound_design.plate_vocal", "contradiction.reverb.long_low_vs_short_high":"reverb.foundations.reverb_tail_energy", "contradiction.reverb.dark_vs_bright_vocal":"reverb.diagnosis_and_clarity.vocal_washed_out", "contradiction.reverb.predelay_depth":"reverb.foundations.predelay", "contradiction.reverb.mono_vs_stereo":"reverb.foundations.mono_vs_stereo_reverb", "contradiction.reverb.tempo_decay":"reverb.foundations.decay_time", "contradiction.reverb.reverb_vs_delay_depth":"reverb.foundations.reverb_vs_delay", "contradiction.reverb.print_vs_live":"reverb.routing_and_processing.print_reverb_vs_live", "contradiction.reverb.low_cut_every_return":"reverb.diagnosis_and_clarity.boomy_reverb", "contradiction.reverb.compress_return":"reverb.routing_and_processing.compress_after_reverb", "contradiction.reverb.reverb_on_bass":"reverb.source_specific.bass_use", "contradiction.reverb.realistic_vs_artificial":"reverb.foundations.natural_vs_stylized", "contradiction.reverb.early_vs_tail":"reverb.foundations.early_reflections_vs_tail",
"contradiction.delay.sync_vs_free":"delay.rhythm_and_tempo.off_grid_delay", "contradiction.delay.insert_vs_send":"delay.routing_and_creative.insert_vs_send", "contradiction.delay.send_vs_return_automation":"delay.routing_and_creative.automate_send_return", "contradiction.delay.dotted_vs_quarter":"delay.rhythm_and_tempo.dotted_eighth", "contradiction.delay.filter_pre_post_feedback":"delay.routing_and_creative.feedback_fx_loop", "contradiction.delay.clean_vs_tape":"delay.logic_pro_specific.tape_delay_setup", "contradiction.delay.haas_vs_double":"delay.stereo_phase_and_utility.haas_guitar_width", "contradiction.delay.pingpong_vs_center":"delay.stereo_phase_and_utility.ping_pong_center", "contradiction.delay.delay_vs_reverb_vocal":"delay.foundations.delay_vs_reverb", "contradiction.delay.feedback_low_high":"delay.routing_and_creative.feedback_fx_loop", "contradiction.delay.mono_vs_stereo_bass":"delay.stereo_phase_and_utility.dual_mono_vs_stereo", "contradiction.delay.sample_align_vs_keep_room":"delay.stereo_phase_and_utility.sample_align_bass_di", "contradiction.delay.pdc_vs_manual":"delay.stereo_phase_and_utility.delay_compensation", "contradiction.delay.delay_before_reverb":"delay.routing_and_creative.reverb_order", "contradiction.delay.throw_send_muting":"delay.routing_and_creative.delay_throw", "contradiction.delay.stereo_times":"delay.foundations.dual_delay", "contradiction.delay.sync_tempo_changes":"delay.rhythm_and_tempo.tempo_changes", "contradiction.delay.print_vs_live":"delay.routing_and_creative.print_delay_tail", "contradiction.delay.duck_vs_filter":"delay.routing_and_creative.ducked_delay", "contradiction.delay.true_echo_vs_invisible":"delay.foundations.delay_depth"}
P4_MYTH_ANCHORS={
"myth.reverb.more_wet_more_depth":"reverb.foundations.reverb_perception_distance", "myth.reverb.longer_bigger":"reverb.foundations.size_vs_decay", "myth.reverb.predelay_formula":"reverb.foundations.predelay", "myth.reverb.highpass_always":"reverb.diagnosis_and_clarity.boomy_reverb", "myth.reverb_plate_vocals_only":"reverb.creative_and_sound_design.plate_vocal", "myth.reverb.send_only":"reverb.routing_and_processing.post_fader_send", "myth.reverb.one_room_glue":"reverb.routing_and_processing.shared_reverb", "myth.reverb_convolution_real":"reverb.foundations.algorithmic_vs_convolution", "myth.reverb_algorithmic_fake":"reverb.foundations.algorithmic_vs_convolution", "myth.reverb_width_better":"reverb.foundations.reverb_width", "myth.reverb_solo_setting":"reverb.diagnosis_and_clarity.reverb_not_audible", "myth.reverb_eq_source":"reverb.routing_and_processing.eq_before_reverb", "myth.reverb_bright_clarity":"reverb.diagnosis_and_clarity.reverb_too_bright", "myth.reverb_dark_invisible":"reverb.diagnosis_and_clarity.reverb_too_dark", "myth.reverb_predelay_forward":"reverb.foundations.predelay", "myth.reverb_tail_no_peak":"reverb.foundations.reverb_tail_energy", "myth.reverb_low_cpu_quality":"reverb.diagnosis_and_clarity.reverb_cpu_latency", "myth.reverb_ir_name_truth":"reverb.foundations.algorithmic_vs_convolution", "myth.reverb_mono_bad":"reverb.foundations.mono_vs_stereo_reverb", "myth.reverb_bass_never":"reverb.source_specific.bass_use", "myth.reverb_fix_bad_room":"reverb.diagnosis_and_clarity.reverb_detached", "myth.reverb_every_track":"reverb.routing_and_processing.multiple_reverbs", "myth.reverb_tempo_exact":"reverb.foundations.tempo_sync_reverb", "myth.reverb_preset_professional":"reverb.source_specific.lead_vocal_use", "myth.reverb_analyzer_proves":"reverb.foundations.reverb_tail_energy",
"myth.delay.sync_always":"delay.rhythm_and_tempo.tempo_formula", "myth.delay_dotted_magic":"delay.rhythm_and_tempo.dotted_eighth", "myth.delay_feedback_repeats":"delay.routing_and_creative.feedback_fx_loop", "myth.delay_haas_safe":"delay.stereo_phase_and_utility.haas_vocal_width", "myth.delay_sample_visual":"delay.stereo_phase_and_utility.sample_align_parallel", "myth.delay_pdc_everything":"delay.stereo_phase_and_utility.delay_compensation", "myth.delay_more_feedback_bigger":"delay.routing_and_creative.feedback_fx_loop", "myth.delay_filter_optional":"delay.logic_pro_specific.delay_designer_filters", "myth.delay_send_only":"delay.routing_and_creative.insert_vs_send", "myth.delay_throw_return":"delay.routing_and_creative.delay_throw", "myth.delay_quarter_formula":"delay.rhythm_and_tempo.tempo_formula", "myth.delay_stereo_better":"delay.stereo_phase_and_utility.dual_mono_vs_stereo", "myth.delay_bass_never":"delay.source_specific.bass_use", "myth.delay_real_double":"delay.stereo_phase_and_utility.doubling_vs_true_double", "myth.delay_pingpong_width":"delay.foundations.ping_pong", "myth.delay_louder_groove":"delay.rhythm_and_tempo.swing_delay", "myth.delay_solo_setting":"delay.diagnosis_and_clarity.delay_not_audible", "myth.delay_no_harmony":"delay.diagnosis_and_clarity.delay_masks_words", "myth.delay_feedback_fx_safe":"delay.routing_and_creative.feedback_fx_loop", "myth.delay_sample_fix_performance":"delay.stereo_phase_and_utility.sample_align_parallel", "myth.delay_tape_better":"delay.logic_pro_specific.tape_delay_setup", "myth.delay_reverb_substitute":"delay.foundations.delay_vs_reverb", "myth.delay_wet_percent":"delay.foundations.wet_dry", "myth.delay_analyzer_proves":"delay.diagnosis_and_clarity.delay_not_audible", "myth.delay_one_value_song":"delay.rhythm_and_tempo.tempo_formula"}
P4_CONTRADICTION_ANCHORS["contradiction.delay.sync_tempo_changes"]="delay.rhythm_and_tempo.tempo_change"
P4_CONTRADICTION_ANCHORS["contradiction.delay.delay_vs_reverb_vocal"]="reverb.source_specific.rap_vocal_use"
P4_MYTH_ANCHORS.update({"myth.reverb_ir_name_truth":"reverb.foundations.room_ir_choice", "myth.delay_one_value_song":"delay.rhythm_and_tempo.choose_subdivision", "myth.delay_more_feedback_bigger":"delay.routing_and_creative.self_oscillation"})
P4_MYTH_ANCHORS.update({"myth.reverb_solo_setting":"reverb.foundations.wet_dry", "myth.reverb_fix_bad_room":"reverb.foundations.ambience_vs_obvious_reverb", "myth.delay_solo_setting":"delay.foundations.wet_dry", "myth.delay_no_harmony":"delay.rhythm_and_tempo.repeat_harmonic_change", "myth.delay_analyzer_proves":"delay.rhythm_and_tempo.swing_delay"})
# This explicit per-ID table intentionally does not infer semantic compatibility
# from free-form tags or lexical overlap.
P4_TOPIC_COMPATIBILITY={identifier: True for identifier in (*P4_CONTRADICTION_ANCHORS, *P4_MYTH_ANCHORS)}

def digest(b): return hashlib.sha256(b).hexdigest()
VALID_REVIEW_STATES={"discovered","acquired","machineExtracted","awaitingReview","reviewed","directlyVerified","disputed","superseded","rejected"}
def readj(p, default=None): return json.loads(p.read_text()) if p.exists() else default
def lines(p): return [json.loads(x) for x in p.read_text().splitlines() if x.strip()]
def nav_match(s, phrase): return re.search(r"(?<![a-z0-9])"+re.escape(phrase)+r"(?![a-z0-9])",s,re.IGNORECASE) is not None
def clean(s, safe_p3=False):
    s=str(s); return (SAFE_P3_FALLBACK if safe_p3 else FALLBACK) if any(nav_match(s,x) for x in NAV) else s
def clean_utterance(s, canonical_id):
    """Remove navigation paths without collapsing distinct user intent to a stock prompt."""
    out=str(s); changed=False
    for index,phrase in enumerate(sorted(NAV,key=len,reverse=True),start=1):
        out,next_count=re.subn(r"(?<![a-z0-9])"+re.escape(phrase)+r"(?![a-z0-9])","the relevant control group "+str(index),out,flags=re.IGNORECASE); changed = changed or bool(next_count)
    if changed: out=out.rstrip(" ?.")+" about "+canonical_id.rsplit(".",1)[-1].replace("_"," ")+"?"
    return out if out.strip() else "What reversible, level-matched comparison should I try, what should I listen for, and when should I undo?"
FORBIDDEN_RUNTIME_KEYS={"logic_pro_steps","logicsteps","procedure_candidates","procedurecandidates","procedure_steps","proceduresteps","procedure_body","procedurebody"}
RUNTIME_STATUS_KEY_FRAGMENTS=("review","status","verification","eligibility")
def assert_runtime_safe(value, path="runtime"):
    """Fail closed over every projected field, including P3 attachments/arrays."""
    if isinstance(value,dict):
        for key,item in value.items():
            if str(key).lower().replace("-","_") in FORBIDDEN_RUNTIME_KEYS: raise ValueError("unsafe runtime key: "+path+"."+str(key))
            assert_runtime_safe(item,path+"."+str(key))
    elif isinstance(value,list):
        for index,item in enumerate(value): assert_runtime_safe(item,path+"["+str(index)+"]")
    elif isinstance(value,str):
        lower=value.lower()
        if any(nav_match(lower,term) for term in NAV) or any(term.replace("_"," ") in lower for term in FORBIDDEN_RUNTIME_KEYS): raise ValueError("unsafe runtime body: "+path)
def assert_runtime_status_free(value, path="runtime"):
    """Status-free runtime capabilities exclude review/status provenance keys."""
    if isinstance(value,dict):
        for key,item in value.items():
            normalized=str(key).lower().replace("-","_")
            if any(fragment in normalized for fragment in RUNTIME_STATUS_KEY_FRAGMENTS): raise ValueError("runtime status key leaked: "+path+"."+str(key))
            assert_runtime_status_free(item,path+"."+str(key))
    elif isinstance(value,list):
        for index,item in enumerate(value): assert_runtime_status_free(item,path+"["+str(index)+"]")
def assert_runtime_field_exclusions(value, fragments, path="runtime"):
    """Fail closed for a capability-declared runtime field exclusion contract."""
    if isinstance(value,dict):
        for key,item in value.items():
            normalized=str(key).lower().replace("-","_")
            if any(fragment in normalized for fragment in fragments):
                raise ValueError("runtime excluded field leaked: "+path+"."+str(key))
            assert_runtime_field_exclusions(item, fragments, path+"."+str(key))
    elif isinstance(value,list):
        for index,item in enumerate(value): assert_runtime_field_exclusions(item,fragments,path+"["+str(index)+"]")
def canon(v): return json.dumps(v, ensure_ascii=False, indent=1, sort_keys=True)+"\n"
def unlinked_repository_path(path, expect_directory):
    """Return a lexical repository path only after no-follow component checks."""
    assert_unlinked_absolute(ROOT,True)
    path=lexical_absolute(path)
    try: relative=path.relative_to(ROOT)
    except ValueError as error: raise ValueError("preservation package is outside repository: "+str(path)) from error
    if not relative.parts or any(part in {"", ".", ".."} for part in relative.parts): raise ValueError("unsafe preservation package path: "+str(path))
    assert_unlinked_absolute(path,expect_directory)
    return relative.as_posix()
def preservation_tree(path):
    """Hash the repository-tracked projection, never ambient host files."""
    relative=unlinked_repository_path(path,True)
    tracked=subprocess.run(["git","-C",str(ROOT),"ls-files","-z","--",relative],capture_output=True)
    if tracked.returncode: raise ValueError("cannot enumerate tracked preservation files: "+tracked.stderr.decode(errors="replace").strip())
    files=[ROOT/name.decode() for name in tracked.stdout.split(b"\0") if name]
    if not files: raise ValueError("tracked preservation package empty: "+relative)
    for item in files: unlinked_repository_path(item,False)
    h=hashlib.sha256()
    for item in files: h.update(b"FILE\0"+item.relative_to(path).as_posix().encode()+b"\0"+item.read_bytes())
    return len(files),h.hexdigest()
def expected_preservation_tree(expected):
    """Use an additive portable projection when a historical baseline has one."""
    source_controlled = expected.get("sourceControlledTree", expected)
    return source_controlled["files"], source_controlled["tree"]
def preservation_baseline_matches(expected, observed):
    """Compare capture output while retaining historical host-artifact fields."""
    expected = json.loads(json.dumps(expected))
    for package in expected.get("packages", {}).values():
        source_controlled = package.pop("sourceControlledTree", None)
        if source_controlled is not None:
            package["files"] = source_controlled["files"]
            package["tree"] = source_controlled["tree"]
    return expected == observed
def preservation_capture_document(existing, observed):
    """Add refreshed tracked projections without recapturing legacy tree fields."""
    output=json.loads(json.dumps(observed))
    for pid,package in output.get("packages",{}).items():
        historical=existing.get("packages",{}).get(pid,{})
        if "files" in historical and "tree" in historical:
            package["sourceControlledTree"]={"files":package["files"],"tree":package["tree"]}
            package["files"]=historical["files"]
            package["tree"]=historical["tree"]
    return output
def preservation_self_check():
    """Reject both symlink roots and symlink ancestors before Git enumeration."""
    legacy={"packages":{"p1":{"files":33,"tree":"legacy"}}}
    observed={"packages":{"p1":{"files":32,"tree":"tracked"}}}
    captured=preservation_capture_document(legacy,observed)
    expected={"files":33,"tree":"legacy","sourceControlledTree":{"files":32,"tree":"tracked"}}
    if captured["packages"]["p1"] != expected or not preservation_baseline_matches(captured,observed): raise ValueError("preservation capture merge regression")
    seeded={"packages":{"p1":{**expected,"sourceControlledTree":{"files":32,"tree":"old-tracked"}}}}
    updated=preservation_capture_document(seeded,{"packages":{"p1":{"files":31,"tree":"new-tracked"}}})
    if updated["packages"]["p1"] != {"files":33,"tree":"legacy","sourceControlledTree":{"files":31,"tree":"new-tracked"}}: raise ValueError("preservation capture projection update regression")
    with tempfile.TemporaryDirectory(dir=ROOT) as temporary:
        base=pathlib.Path(temporary); target=K/"community-vocal-quantization-v1"
        os.symlink(target,base/"root-link")
        (base/"ancestor").mkdir(); os.symlink(target.parent,base/"ancestor"/"linked")
        os.symlink(target/"README.md",base/"tracked-file-link")
        for unsafe in (base/"root-link",base/"ancestor"/"linked"/target.name,base/"tracked-file-link"):
            try: preservation_tree(unsafe)
            except ValueError: continue
            raise ValueError("symlinked preservation path accepted: "+str(unsafe))
        for label, linked_script in (("repository root", base/"linked-repository"/"research/scripts/community_corpus_import.py"), ("repository ancestor", base/"linked-parent"/ROOT.name/"research/scripts/community_corpus_import.py")):
            if label == "repository root": os.symlink(ROOT, base/"linked-repository")
            else: os.symlink(ROOT.parent, base/"linked-parent")
            child=subprocess.run([sys.executable,str(linked_script),"--preservation-self-check"],capture_output=True,text=True)
            if child.returncode == 0 or "symlinked preservation path" not in (child.stdout+child.stderr): raise ValueError("symlinked "+label+" invocation was not rejected by lexical-path validation")
def generated_non_p10_projection():
    text=(ROOT/"packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift").read_text(); start,end=text.find('#"""'),text.rfind('"""#')
    if start<0 or end<0: raise ValueError("P10 preservation baseline generated payload unreadable")
    def post_p10_source(row):
        match=re.match(r"^pkg(\d{3})\.", str(row.get("id", "")))
        return match is not None and int(match.group(1)) >= 10
    payload=json.loads(text[start+4:end]); payload["sources"]=[row for row in payload.get("sources",[]) if not post_p10_source(row)]
    return digest(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode())
def verify_p6_preservation_baseline():
    if not P6_BASELINE.exists(): return
    baseline=readj(P6_BASELINE); packages=baseline.get("packages",{})
    registry_rows=readj(ROOT/"research/community_knowledge/package_registry.json")["packages"]
    prior_registry=[row for row in registry_rows if row.get("package_number",0)<=5]
    if digest(json.dumps(prior_registry,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()) != baseline["registryProjection"]: raise ValueError("P6 preservation baseline registry-entry drift")
    source_rows=readj(REGISTRY,{"sources":[]})["sources"]; queue_rows=readj(QUEUE,{"candidates":[]})["candidates"]
    descriptor_lines=DESCRIPTOR.read_text().splitlines(keepends=True)
    for pid, expected in packages.items():
        package=(ROOT/"research/community_knowledge/packages"/pid) if pid.startswith("tracksmith-corpus") else K/pid
        count,value=preservation_tree(package)
        if (count,value)!=expected_preservation_tree(expected): raise ValueError("P6 preservation baseline package-tree drift: "+pid)
        if digest((RES/(pid+".json")).read_bytes())!=expected["runtime"]: raise ValueError("P6 preservation baseline runtime drift: "+pid)
        if digest((EVAL/(pid+"-evaluation.json")).read_bytes())!=expected["evaluation"]: raise ValueError("P6 preservation baseline evaluation drift: "+pid)
        sources=[x for x in source_rows if x.get("candidateCorpus")==pid]; queue=[x for x in queue_rows if x.get("candidateCorpus")==pid]
        compact=lambda value: digest(json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode())
        if compact(sources)!=expected["sourceProjection"] or compact(queue)!=expected["queueProjection"]: raise ValueError("P6 preservation baseline source/queue/review-event drift: "+pid)
        line=next((x for x in descriptor_lines if f'packageID: "{pid}"' in x),None)
        # Adding P6 turns P5 from the last array declaration into an interior
        # declaration.  The generated delimiter is non-semantic; preserve all
        # declaration bytes while removing exactly that one trailing comma.
        if line is None: raise ValueError("P6 preservation baseline descriptor missing: "+pid)
        comparable=line[:-2]+"\n" if pid == P5_ID and line.endswith(",\n") else line
        if digest(comparable.encode())!=expected["descriptorLine"]: raise ValueError("P6 preservation baseline descriptor drift: "+pid)
def verify_p7_preservation_baseline():
    if not P7_BASELINE.exists(): return
    baseline=readj(P7_BASELINE); packages=baseline.get("packages",{})
    registry_rows=readj(ROOT/"research/community_knowledge/package_registry.json")["packages"]
    prior_registry=[row for row in registry_rows if row.get("package_number",0)<=6]
    if digest(json.dumps(prior_registry,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()) != baseline["registryProjection"]: raise ValueError("P7 preservation baseline registry-entry drift")
    source_rows=readj(REGISTRY,{"sources":[]})["sources"]; queue_rows=readj(QUEUE,{"candidates":[]})["candidates"]; descriptor_lines=DESCRIPTOR.read_text().splitlines(keepends=True)
    for pid, expected in packages.items():
        package=(ROOT/"research/community_knowledge/packages"/pid) if pid.startswith("tracksmith-corpus") else K/pid
        count,value=preservation_tree(package)
        if (count,value)!=expected_preservation_tree(expected): raise ValueError("P7 preservation baseline package-tree drift: "+pid)
        if digest((RES/(pid+".json")).read_bytes())!=expected["runtime"] or digest((EVAL/(pid+"-evaluation.json")).read_bytes())!=expected["evaluation"]: raise ValueError("P7 preservation baseline runtime/evaluation drift: "+pid)
        compact=lambda value: digest(json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode())
        if compact([x for x in source_rows if x.get("candidateCorpus")==pid])!=expected["sourceProjection"] or compact([x for x in queue_rows if x.get("candidateCorpus")==pid])!=expected["queueProjection"]: raise ValueError("P7 preservation baseline source/queue/review-event drift: "+pid)
        line=next((x for x in descriptor_lines if f'packageID: "{pid}"' in x),None)
        if line is None or digest((line[:-2]+"\n" if line.endswith(",\n") else line).encode())!=expected["descriptorLine"]: raise ValueError("P7 preservation baseline descriptor drift: "+pid)
def verify_p8_preservation_baseline():
    if not P8_BASELINE.exists(): return
    baseline=readj(P8_BASELINE); source_rows=readj(REGISTRY,{"sources":[]})["sources"]; queue_rows=readj(QUEUE,{"candidates":[]})["candidates"]; lines=DESCRIPTOR.read_text().splitlines(keepends=True)
    registry=[x for x in readj(ROOT/"research/community_knowledge/package_registry.json")["packages"] if x.get("package_number",0)<=7]
    compact=lambda value:digest(json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode())
    if compact(registry)!=baseline["registryProjection"]: raise ValueError("P8 preservation baseline registry drift")
    for pid,expected in baseline["packages"].items():
        package=(ROOT/"research/community_knowledge/packages"/pid) if pid.startswith("tracksmith-corpus") else K/pid; count,value=preservation_tree(package)
        line=next((x for x in lines if f'packageID: "{pid}"' in x),None); comparable=line[:-2]+"\n" if line and line.endswith(",\n") else line
        if (count,value)!=expected_preservation_tree(expected) or digest((RES/(pid+".json")).read_bytes())!=expected["runtime"] or digest((EVAL/(pid+"-evaluation.json")).read_bytes())!=expected["evaluation"] or compact([x for x in source_rows if x.get("candidateCorpus")==pid])!=expected["sourceProjection"] or compact([x for x in queue_rows if x.get("candidateCorpus")==pid])!=expected["queueProjection"] or comparable is None or digest(comparable.encode())!=expected["descriptorLine"]: raise ValueError("P8 preservation baseline drift: "+pid)
def verify_p9_preservation_baseline(baseline_path: pathlib.Path | None = None):
    """Verify P1-P8 bytes, optionally using a disposable baseline fixture."""
    path = pathlib.Path(baseline_path) if baseline_path is not None else P9_BASELINE
    if not path.exists(): return
    baseline=readj(path); compact=lambda value:digest(json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode())
    registry=[x for x in readj(ROOT/"research/community_knowledge/package_registry.json")["packages"] if x.get("package_number",0)<=8]
    if compact(registry)!=baseline["registryProjection"]: raise ValueError("P9 preservation baseline registry drift")
    source_rows=readj(REGISTRY,{"sources":[]})["sources"]; queue_rows=readj(QUEUE,{"candidates":[]})["candidates"]; descriptor_lines=DESCRIPTOR.read_text().splitlines(keepends=True)
    for pid,expected in baseline["packages"].items():
        package=(ROOT/"research/community_knowledge/packages"/pid) if pid.startswith("tracksmith-corpus") else K/pid
        count,value=preservation_tree(package); manifest=package/("package_manifest.json" if (package/"package_manifest.json").exists() else "manifest.json")
        line=next((x for x in descriptor_lines if f'packageID: "{pid}"' in x),None); comparable=line.rstrip(",\n") if line else None
        if (count,value)!=expected_preservation_tree(expected) or digest(manifest.read_bytes())!=expected["manifest"] or digest((RES/(pid+".json")).read_bytes())!=expected["runtime"] or digest((EVAL/(pid+"-evaluation.json")).read_bytes())!=expected["evaluation"] or compact([x for x in source_rows if x.get("candidateCorpus")==pid])!=expected["sourceProjection"] or compact([x for x in queue_rows if x.get("candidateCorpus")==pid])!=expected["queueProjection"] or comparable is None or digest(comparable.encode())!=expected["descriptorLine"]: raise ValueError("P9 preservation baseline drift: "+pid)
    # P10's source-only GeneralTutor delta is protected by the stronger P10
    # canonical payload baseline below.  Retain the historical P9 byte check
    # until that successor baseline exists, then avoid treating an additive P10
    # source row as a P9 regression.
    if not P10_BASELINE.exists():
        generated=(ROOT/"packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift").read_text()
        if digest("\n".join(x for x in generated.splitlines() if "pkg009." not in x).encode())!=baseline["nonP9GeneratedAdviceProjection"]: raise ValueError("P9 preservation baseline generated non-P9 advice drift")
def verify_p10_preservation_baseline(enforce_p10_metadata=False):
    """Keep every Package 001–009 raw/state projection byte-identical for P10."""
    if not P10_BASELINE.exists(): return
    baseline=readj(P10_BASELINE); compact=lambda value:digest(json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode())
    registry=[x for x in readj(ROOT/"research/community_knowledge/package_registry.json")["packages"] if x.get("package_number",0)<=9]
    if compact(registry)!=baseline["registryProjection"]: raise ValueError("P10 preservation baseline registry drift")
    source_rows=readj(REGISTRY,{"sources":[]})["sources"]; queue_rows=readj(QUEUE,{"candidates":[]})["candidates"]; descriptor_lines=DESCRIPTOR.read_text().splitlines(keepends=True)
    for pid,expected in baseline["packages"].items():
        package=(ROOT/"research/community_knowledge/packages"/pid) if pid.startswith("tracksmith-corpus") else K/pid
        count,value=preservation_tree(package); manifest=package/("package_manifest.json" if (package/"package_manifest.json").exists() else "manifest.json")
        line=next((x for x in descriptor_lines if f'packageID: "{pid}"' in x),None); comparable=line.rstrip(",\n") if line else None
        if (count,value)!=expected_preservation_tree(expected) or digest(manifest.read_bytes())!=expected["manifest"] or digest((RES/(pid+".json")).read_bytes())!=expected["runtime"] or digest((EVAL/(pid+"-evaluation.json")).read_bytes())!=expected["evaluation"] or compact([x for x in source_rows if x.get("candidateCorpus")==pid])!=expected["sourceProjection"] or compact([x for x in queue_rows if x.get("candidateCorpus")==pid])!=expected["queueProjection"] or comparable is None or digest(comparable.encode())!=expected["descriptorLine"]: raise ValueError("P10 preservation baseline drift: "+pid)
    if generated_non_p10_projection()!=baseline["nonP10GeneratedAdviceProjection"]: raise ValueError("P10 preservation baseline generated non-P10 advice drift")
    if enforce_p10_metadata:
        registry,report,repairs=p10_metadata_artifacts()
        rows=[row for row in registry["packages"] if row.get("package_id")==P10_ID]
        if repairs or len(rows)!=1 or rows[0].get("runtime_contract_reconciliation")!=p10_runtime_contract_reconciliation() or report.get("runtime_contract_reconciliation")!=p10_runtime_contract_reconciliation():
            raise ValueError("P10 runtime-contract metadata preservation drift")

def verify_p11_preservation_baseline():
    """P011's successor baseline protects every P001-P010 byte/state surface."""
    if not P11_BASELINE.exists():
        return
    result=subprocess.run([sys.executable,str(ROOT/"research/scripts/capture-p11-preservation-baseline.py"),"--check"],text=True,capture_output=True)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip())
def verify_p12_preservation_baseline():
    """P012's predecessor baseline protects every P001-P011 surface."""
    if not P12_BASELINE.exists():
        return
    result=subprocess.run([sys.executable,str(ROOT/"research/scripts/capture-p12-preservation-baseline.py"),"--check"],text=True,capture_output=True)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip())
def verify_p13_preservation_baseline():
    """P013's predecessor baseline protects every P001-P012 surface."""
    if not P13_BASELINE.exists():
        return
    result=subprocess.run([sys.executable,str(ROOT/"research/scripts/capture-p13-preservation-baseline.py"),"--check"],text=True,capture_output=True)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip())
def verify_p14_preservation_baseline():
    """P014's predecessor baseline protects every P001-P013 surface."""
    if not P14_BASELINE.exists():
        return
    result=subprocess.run([sys.executable,str(ROOT/"research/scripts/capture-p14-preservation-baseline.py"),"--check"],text=True,capture_output=True)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip())
def verify_p15_preservation_baseline():
    """P015's predecessor baseline protects every P001-P014 surface."""
    if not P15_BASELINE.exists():
        return
    result=subprocess.run([sys.executable,str(ROOT/"research/scripts/capture-p15-preservation-baseline.py"),"--check"],text=True,capture_output=True)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip())
def package_digest(package):
    manifest=readj(package/"manifest.json")
    if package.name == "community-reverb-delay-v1":
        expected={"schema_version","package","version","package_sequence","generated_at","integrate_after","counts","review_boundary","reddit_access_status","database","files"}
        expected_counts={"package_name":"TrackSmith_Reverb_Delay_QA_Corpus_v1","package_sequence":4,"created_at":"2026-08-11","canonical_total":300,"canonical_by_domain":{"reverb":160,"delay":140},"canonical_by_category":{"reverb::foundations":25,"reverb::routing_and_processing":25,"reverb::diagnosis_and_clarity":35,"reverb::source_specific":40,"reverb::creative_and_sound_design":20,"reverb::logic_pro_specific":15,"delay::foundations":20,"delay::rhythm_and_tempo":25,"delay::source_specific":35,"delay::stereo_phase_and_utility":25,"delay::routing_and_creative":20,"delay::logic_pro_specific":15},"utterances":6600,"multiturn_scenarios":900,"retrieval_evaluations":1500,"sources":105,"sources_by_tier":{"A":42,"B":43,"C":20},"contradictions":40,"myths":50,"candidate_claims":300,"candidate_strategies":300,"candidate_logic_procedures":300,"reddit_access_status":"MANUAL_PUBLIC_SEEDS_ONLY","review_status":"candidate_not_yet_human_reviewed"}
        expected_boundary={"canonical":"candidate_not_yet_human_reviewed","claims":"candidate_not_yet_human_reviewed","strategies":"candidate_not_yet_human_reviewed","logic_procedures":"candidate_not_yet_human_reviewed and candidate_unverified_on_installed_logic"}
        if set(manifest)!=expected or manifest.get("package")!="TrackSmith_Reverb_Delay_QA_Corpus_v1" or manifest.get("version")!="1.0.0" or manifest.get("package_sequence")!=4 or manifest.get("integrate_after") != ["TrackSmith Vocal + Quantization","TrackSmith Level Balancing + EQ","TrackSmith Compression + Arrangement + Frequency Allocation"] or manifest.get("counts")!=expected_counts or manifest.get("review_boundary")!=expected_boundary:
            raise ValueError("unexpected package-4 manifest shape")
    if isinstance(manifest["files"],list):
        if package.name == "community-reverb-delay-v1":
            inventory={row.get("path") for row in manifest["files"] if isinstance(row,dict)}
            actual={p.relative_to(package).as_posix() for p in package.rglob("*") if p.is_file()}
            if actual != inventory | {"manifest.json","SHA256SUMS.txt"}:
                raise ValueError("package-4 inventory drift")
            sums={}
            for line in (package/"SHA256SUMS.txt").read_text().splitlines():
                match=re.fullmatch(r"([0-9a-f]{64})  (.+)",line)
                if not match or match.group(2) in sums: raise ValueError("package-4 SHA256SUMS shape drift")
                sums[match.group(2)]=match.group(1)
            manifest_sums={row["path"]:row["sha256"] for row in manifest["files"] if isinstance(row,dict) and set(row)=={"path","bytes","sha256"}}
            manifest_hash=digest((package/"manifest.json").read_bytes())
            if sums != {**manifest_sums,"manifest.json":manifest_hash}: raise ValueError("package-4 SHA256SUMS inventory drift")
        for row in manifest["files"]:
            p=package/row["path"]
            if set(row)!={"path","bytes","sha256"} or not p.exists() or p.stat().st_size != row["bytes"] or digest(p.read_bytes()) != row["sha256"]: raise ValueError("immutable package manifest mismatch: "+row["path"])
    elif isinstance(manifest["files"],dict):
        expected={"domains","files","generated_at","independent_package","integrate_after","package_name","package_sequence","package_version","prerequisites","reddit_access_status","stats"}
        if set(manifest)!=expected or manifest["package_name"]!="TrackSmith_Compression_Arrangement_Frequency_Allocation_QA_Corpus_v1" or manifest["independent_package"] is not True or manifest["integrate_after"]!="TrackSmith_Level_Balancing_EQ_QA_Corpus_v1" or manifest["prerequisites"]!=["TrackSmith_Vocal_Quantization_QA_Corpus_v1","TrackSmith_Level_Balancing_EQ_QA_Corpus_v1"] or manifest["package_sequence"]!=3 or manifest["package_version"]!="1.0.0" or not all(isinstance(k,str) and isinstance(v,str) and re.fullmatch(r"[0-9a-f]{64}",v) for k,v in manifest["files"].items()): raise ValueError("unexpected package-3 manifest shape")
        for path,expected_hash in manifest["files"].items():
            p=package/path
            if not p.exists() or digest(p.read_bytes())!=expected_hash: raise ValueError("immutable package manifest mismatch: "+path)
    else: raise ValueError("unexpected package manifest files shape")
    return digest((package/"manifest.json").read_bytes()), manifest
def package_source_id(pid, original, all_existing):
    # The two documented collisions may coexist only via package-2 namespacing.
    collisions={"apple.logic.audio_region_parameters","logicprohelp.mud_projects"}
    if pid=="community-level-balancing-eq-v1" and original in collisions: return "community-level-balancing-eq-v1."+original
    if pid=="community-compression-arrangement-frequency-allocation-v1" and original in P3_SOURCE_COLLISIONS: return pid+"."+original
    if pid=="community-compression-arrangement-frequency-allocation-v1" and original in all_existing: raise ValueError("unexpected package-3 source collision: "+original)
    if pid=="community-reverb-delay-v1" and original in P4_SOURCE_COLLISIONS: return pid+"."+original
    if pid=="community-reverb-delay-v1" and original in all_existing: raise ValueError("unexpected package-4 source collision: "+original)
    if original in all_existing and all_existing[original].get("originalSourceID", original) != original: raise ValueError("unexpected source collision: "+original)
    return original
def source_entry(pid, row, native):
    value={"id":native,"type":row["source_type"],"title":row["title"],"creatorOrPublisher":row.get("publisher"),"locator":row.get("url"),"publicationDate":None,"retrievalDate":None,"exactVersion":None,"rightsBasis":"Candidate corpus metadata and paraphrased synthesis; source body is not redistributed.","handlingClass":"openDocumentation" if row["evidence_tier"]=="A" else "publicWebMetadataOnly","tier":TIERS[row["evidence_tier"]],"transcriptAvailable":False,"transcriptIsAutomatic":False,"requiresAudiovisualReview":False,"audiovisualReviewCompleted":False,"contentSHA256":[],"limitations":row.get("limitations",[]),"supersededBy":None,"reviewState":"acquired","candidateCorpus":pid,"originalAccessStatus":row.get("access_status"),"originalUse":row.get("use")}
    if pid == "community-reverb-delay-v1": value["originalReviewStatus"]="source_registered_not_full_claim_review"
    if pid != "community-vocal-quantization-v1": value["originalSourceID"]=row["source_id"]
    return value
def parts(ids, source_map):
    out={"authoritativeSupportingSourceIDs":[],"professionalPracticeSourceIDs":[],"discoveryLanguageSourceIDs":[]}
    for i in sorted(set(ids)):
        if i not in source_map: raise ValueError("unknown package source "+i)
        out[{"A":"authoritativeSupportingSourceIDs","B":"professionalPracticeSourceIDs","C":"discoveryLanguageSourceIDs"}[source_map[i]["evidence_tier"]]].append(source_map[i]["native"])
    return out
def contradiction(row, safe_p3=False): return {"id":row["id"],"summary":clean(row.get("position_a",row.get("summary",""))+" / "+row.get("position_b",""),safe_p3),"whatDecides":clean(row.get("what_determines_which_applies",row.get("what_decides","")),safe_p3),"tutorBehavior":clean(row.get("tutor_behavior","Use a short reversible comparison before choosing."),safe_p3),"originalReviewStatus":row.get("review_status","candidate_not_yet_human_reviewed")}
def myth(row, safe_p3=False): return {"id":row["id"],"myth":clean(row.get("myth",""),safe_p3),"correction":clean(row.get("correction",""),safe_p3),"originalReviewStatus":row.get("review_status","candidate_not_yet_human_reviewed")}
def token(s): return set(re.findall(r"[a-z0-9]+",s.lower()))
def normalized_runtime_identity(s): return " ".join(re.findall(r"[a-z0-9]+",str(s).lower()))
def p1_cues(s): return {x.rstrip("s") for x in re.findall(r"[a-z0-9]+",s.lower()) if len(x)>2 and x not in P1_GENERIC}
def p1_attachments(canonical, contradictions):
    buckets={x["id"]:[] for x in canonical}
    for record in contradictions:
        for item in canonical:
            shared=set(item.get("source_ids",[])) & set(record.get("source_ids",[]))
            cues=p1_cues(item["id"]+" "+item.get("title","")+" "+item.get("category","")+" "+item.get("subcategory","")+" "+" ".join(item.get("tags",[]))+" "+" ".join(item.get("user_language_aliases",[])))
            topic=p1_cues(record["id"]+" "+record.get("topic",""))
            if item["id"] == P1_ANCHORS.get(record["id"]) or (shared and len(cues & topic)>=2):
                buckets[item["id"]].append(contradiction(record))
    for values in buckets.values(): values.sort(key=lambda x:x["id"])
    if any(len(values)>3 for values in buckets.values()): raise ValueError("package-1 contradiction cap drift")
    if {x["id"] for values in buckets.values() for x in values} != {x["id"] for x in contradictions}: raise ValueError("package-1 orphaned contradiction")
    return buckets
P10_PROVENANCE_REPAIR_COUNT = 0

def merge_review_event(generated, existing):
    global P10_PROVENANCE_REPAIR_COUNT
    if not existing: return generated
    immutable=("id","candidateKind","canonicalQAID","originalReviewStatus","originalVerificationStatus")
    immutable_changed=[k for k in immutable if existing.get(k)!=generated.get(k)]
    # One-time repair for P10 rows created before original verification and
    # installed-Logic verification were kept as separate provenance fields.
    # It is intentionally exact and cannot rewrite a human review event.
    p10_repair = (
        immutable_changed == ["originalVerificationStatus"] and
        generated.get("candidateCorpus") == P10_ID and
        generated.get("candidateKind") == "procedure" and
        existing.get("originalVerificationStatus") == "candidate_unverified_on_installed_logic" and
        generated.get("originalVerificationStatus") == "candidate_generated_from_registered_sources" and
        existing.get("logicVerificationStatus") == generated.get("logicVerificationStatus") == "candidate_unverified_on_installed_logic" and
        all(existing.get(key) == generated.get(key) for key in ("id", "candidateKind", "canonicalQAID", "originalReviewStatus", "reviewState", "reviewer", "reviewedAt", "reviewNote")) and
        not any("event" in key.lower() and value not in (None, "", [], {}) for key, value in existing.items()) and
        existing.get("candidatePayload", {}).get("original_verification_status") == generated.get("originalVerificationStatus")
    )
    if immutable_changed and not p10_repair: raise ValueError(generated["id"]+": imported immutable queue provenance changed: "+",".join(immutable_changed))
    if p10_repair: P10_PROVENANCE_REPAIR_COUNT += 1
    state=existing.get("reviewState"); named=bool(existing.get("reviewer") and existing.get("reviewedAt"))
    valid=state in VALID_REVIEW_STATES and ((state=="awaitingReview" and not named and existing.get("reviewNote") is None) or (state!="awaitingReview" and named))
    if not valid: return generated
    for key,value in existing.items():
        lower=key.lower()
        if key in {"reviewState","reviewer","reviewedAt","reviewNote","acceptedClaimText"} or (("review" in lower or "event" in lower) and key!="originalReviewStatus"):
            generated[key]=value
    return generated
def verify_review_event_merge():
    generated={"id":"regression","candidateKind":"claim","canonicalQAID":"card","originalReviewStatus":"candidate","reviewState":"awaitingReview","reviewer":None,"reviewedAt":None,"reviewNote":None}
    reviewed={**generated,"reviewState":"reviewed","reviewer":"named-reviewer","reviewedAt":"2026-08-11","reviewNote":"retained","acceptedClaimText":"accepted","reviewEventID":"event-1"}
    kept=merge_review_event(dict(generated),reviewed)
    if kept["reviewState"] != "reviewed" or kept.get("reviewEventID") != "event-1": raise ValueError("named review-event preservation regression")
    malformed={**generated,"reviewState":"reviewed","reviewer":None,"reviewedAt":None}
    reset=merge_review_event(dict(generated),malformed)
    if reset["reviewState"] != "awaitingReview": raise ValueError("malformed review-event fail-closed regression")
def p1_legacy_projection(canonical, utterances, scenarios, contradictions, sources, manifest_digest):
    cards=[]
    attached=p1_attachments(canonical,contradictions)
    legacy_contradiction=lambda value:{k:value[k] for k in ("id","summary","whatDecides","tutorBehavior")}
    for item in canonical:
        card={"id":item["id"],"domain":item["domain"],"category":item["category"],"title":item["title"],"question":item["canonical_user_question"],"originalReviewStatus":item["review_status"],"clarificationQuestions":[clean(v) for v in item.get("clarification_questions",[])],"competingHypotheses":[clean(h["label"]+": "+h["mechanism"]) for h in item.get("candidate_hypotheses",[])],"recommendedFirstExperiment":clean(item["recommended_first_experiment"]["summary"]),"rationale":clean(item["rationale"]),"listeningCues":[clean(v) for v in item.get("what_to_listen_for",[])],"stopOrUndo":[clean(item["stop_rule"]),clean(item["undo_or_reset"])],"tradeoffs":[clean(v) for v in item.get("tradeoffs_and_risks",[])],"teachingPrinciple":clean(item["teaching_principle"]),"numericGuidancePolicy":item["numeric_guidance_policy"],**parts(item["source_ids"],sources),"contradictions":[legacy_contradiction(x) for x in attached[item["id"]]]}
        cards.append(card)
    return {"schemaVersion":"1.0","packageManifestSHA256":manifest_digest,"canonicalCards":sorted(cards,key=lambda x:x["id"]),"utterances":sorted([{"id":x["utterance_id"],"canonicalID":x["canonical_id"],"text":x["text"]} for x in utterances],key=lambda x:x["id"]),"scenarios":sorted([{"id":x["scenario_id"],"canonicalID":x["canonical_id"],"domain":x["domain"],"branchKind":x["branch_kind"],"evaluationCriteria":x["evaluation_criteria"],"turns":x["turns"]} for x in scenarios],key=lambda x:x["id"]),"contradictions":sorted([legacy_contradiction(contradiction(x)) for x in contradictions],key=lambda x:x["id"])}
def attach(rows, cards, key, limit=3):
    # provenance plus topic match when possible; deterministic explicit fallback
    # keeps each disagreement reachable without broad all-card attachment.
    buckets={x["id"]:[] for x in cards}
    for record in rows:
        candidates=[]; cues=token(record["id"]+" "+record.get("topic",record.get("myth","")))
        for c in cards:
            if set(c["_source_ids"]) & set(record.get("source_ids",[])) and (len(cues & token(c["id"]+" "+c["title"]+" "+c["category"]))>=1): candidates.append(c)
        if not candidates: candidates=[c for c in cards if set(c["_source_ids"]) & set(record.get("source_ids",[]))]
        if not candidates: candidates=cards
        choice=next((c for c in sorted(candidates,key=lambda x:x["id"]) if len(buckets[c["id"]])<limit), None)
        if choice is None: raise ValueError("attachment cap exhausted for "+record["id"])
        buckets[choice["id"]].append(key(record))
    return buckets
def anchored(rows, cards, mapping, key, limit):
    card_ids={x["id"] for x in cards}
    row_ids={x["id"] for x in rows}
    if row_ids != set(mapping): raise ValueError("explicit attachment map does not cover package lane")
    if not set(mapping.values()) <= card_ids: raise ValueError("explicit attachment map references unknown canonical card")
    buckets={x["id"]:[] for x in cards}
    for row in rows: buckets[mapping[row["id"]]].append(key(row))
    for values in buckets.values(): values.sort(key=lambda x:x["id"])
    if any(len(x)>limit for x in buckets.values()): raise ValueError("explicit attachment cap exceeded")
    return buckets
def p4_anchored(rows, cards, mapping, key, limit):
    """Enforce the P4 static map plus source and exact topic-cue compatibility."""
    buckets=anchored(rows,cards,mapping,key,limit)
    by_id={card["id"]:card for card in cards}
    for row in rows:
        card=by_id[mapping[row["id"]]]
        if not set(row.get("source_ids",[])) & set(card.get("_source_ids",[])):
            raise ValueError("package-4 anchor has no source intersection: "+row["id"])
        if P4_TOPIC_COMPATIBILITY.get(row["id"]) is not True:
            raise ValueError("package-4 anchor lacks explicit topic compatibility: "+row["id"])
    return buckets
def rewrite_package3_source_references(value, source_map):
    """Namespace every exact P3 source reference, including nested payload arrays."""
    if isinstance(value, list): return [rewrite_package3_source_references(x,source_map) for x in value]
    if isinstance(value, dict): return {k:rewrite_package3_source_references(v,source_map) for k,v in value.items()}
    return source_map[value]["native"] if isinstance(value,str) and value in source_map else value
ROLE_FACET_MAP={
    "lead":"focal","vocal":"focal","hook":"focal","lead_vocal":"focal","chorus_hook":"focal","main_hook":"focal","bass":"foundation","sub":"foundation","kick":"foundation","kick_bass":"foundation",
    "drum":"rhythmic","percussion":"rhythmic","rhythm":"rhythmic","pad":"textural","texture":"textural",
    "transition":"transitional","riser":"transitional","impact":"transitional","backing":"supporting","harmony":"supporting","double":"supporting"}
SECTION_FACET_MAP={"intro":"intro","verse":"verse","prechorus":"prechorus","pre_chorus":"prechorus","chorus":"chorus","chorus_hook":"chorus","postchorus":"postchorus","post_chorus":"postchorus","bridge":"bridge","drop":"drop","breakdown":"breakdown","outro":"outro","transition":"transition","whole_song":"whole_song"}
def normalized_facets(row, mapping):
    # Maps are deliberately small, explicit vocabularies; no substring facts.
    values=set(str(x).lower().replace("-","_") for x in [row.get("category",""),row.get("subcategory","")] + row.get("tags",[]))
    return sorted({mapped for value,mapped in mapping.items() if value in values})
def role_facets(row): return normalized_facets(row,ROLE_FACET_MAP)
def section_facets(row): return normalized_facets(row,SECTION_FACET_MAP)

P5_ID="tracksmith-corpus-005-automation"
P5_ROOT=ROOT/"research/community_knowledge/packages"/P5_ID
P5_DISAGREEMENTS=ROOT/"research/community_knowledge/disagreement_maps"/(P5_ID+".json")
P6_ID="tracksmith-corpus-006-saturation-transient-shaping"
P7_ID="tracksmith-corpus-007-phase-polarity-stereo-imaging-panning"
P8_ID="tracksmith-corpus-008-editing-layering"
P9_ID="tracksmith-corpus-009-gain-staging-bus-processing-loudness"
P10_ID="tracksmith-corpus-010-flex-time-manual-timing"
P12_ID="tracksmith-corpus-012-recording-latency-monitoring-comping-punch"
P13_ID="tracksmith-corpus-013-sends-buses-auxes-track-stacks-groups-submixes"
P14_ID="tracksmith-corpus-014-sidechain-automation-midi-groove-velocity-transform"
P15_ID="tracksmith-corpus-015-midi-cc-piano-roll-bounce-freeze-pdc-object-model"
P10_PACKAGE_REGISTRY=ROOT/"research/community_knowledge/package_registry.json"
P10_IMPORT_REPORT=ROOT/("research/community_knowledge/import_report_"+P10_ID+".json")
P10_RUNTIME_RESOURCE=RES/(P10_ID+".json")
P10_EVALUATION_RESOURCE=EVAL/(P10_ID+"-evaluation.json")
P10_RUNTIME_SHA256="da8c0cb4cf44b192fde0cb64c6063ed81d0106395bff9f7dfb6487bb9b3cf49b"
P10_EVALUATION_SHA256="b20b83fd55352d67449e17578b9fb22b8760ce69976667f0a9ae19037d81541c"
STABLE_CONTRACT_SPECS={
    P5_ID: {"number":5,"canonical":240,"utterances":5280,"scenarios":720,"retrieval":1200,"contradictions":36,"myths":44,"sources":63,"documentary":32,"scenarioMessageCounts":{4:480,6:240},"contradictionCap":3,"mythCap":2,"combinedCap":4,"includePrimaryResearch":False,"preserveDisagreementProvenance":False,"directSemanticMap":False,"nonProcessingField":False,"emitTopic":False,"rawExactCount":480,"rawNonExactCount":720,"sourceClassCounts":{"official_documentation":32,"professional_practice":17,"specialist_discussion":11,"community_pattern":3}},
    P6_ID: {"number":6,"canonical":384,"utterances":8448,"scenarios":1152,"retrieval":1920,"contradictions":42,"myths":50,"sources":82,"documentary":60,"scenarioMessageCounts":{6:1152},"contradictionCap":3,"mythCap":2,"combinedCap":4,"includePrimaryResearch":True,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":False,"nonProcessingField":True,"emitTopic":False,"rawExactCount":1920,"runtimeExactCount":1920,"rawNonExactCount":0,"runtimeNonExactCount":0,"sourceClassCounts":{"official_documentation":46,"primary_research":14,"professional_practice":11,"specialist_discussion":10,"community_pattern":1}},
    P7_ID: {"number":7,"canonical":396,"utterances":8712,"scenarios":1188,"retrieval":1980,"contradictions":42,"myths":50,"sources":82,"documentary":50,"scenarioMessageCounts":{6:1188},"contradictionCap":3,"mythCap":2,"combinedCap":4,"includePrimaryResearch":True,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":True,"emitTopic":True,"rawExactCount":1980,"runtimeExactCount":1980,"rawNonExactCount":0,"runtimeNonExactCount":0,"sourceClassCounts":{"official_documentation":34,"primary_research":16,"professional_practice":20,"specialist_discussion":10,"community_pattern":2}},
    P8_ID: {"number":8,"canonical":420,"utterances":9240,"scenarios":1260,"retrieval":2100,"contradictions":46,"myths":54,"sources":95,"documentary":55,"scenarioMessageCounts":{6:1260},"contradictionCap":2,"mythCap":2,"combinedCap":4,"includePrimaryResearch":True,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":True,"emitTopic":True,"rawExactCount":840,"runtimeExactCount":840,"rawNonExactCount":1260,"runtimeNonExactCount":1260,"sourceClassCounts":{"official_documentation":43,"primary_research":8,"professional_practice":32,"specialist_discussion":5,"product_documentation":4,"community_pattern":2,"community_anecdote":1}},
    P9_ID: {"number":9,"canonical":430,"utterances":9460,"scenarios":1290,"retrieval":2150,"contradictions":48,"myths":56,"sources":95,"documentary":75,"scenarioMessageCounts":{4:860,6:430},"contradictionCap":2,"mythCap":2,"combinedCap":4,"includePrimaryResearch":True,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":True,"emitTopic":True,"numericGuidancePolicy":"contextual_orientation_or_measurement_not_preset","rawExactCount":430,"runtimeExactCount":430,"rawNonExactCount":1720,"runtimeNonExactCount":1720,"sourceClassCounts":{"official_documentation":65,"primary_research":10,"professional_practice":15,"specialist_discussion":4,"community_pattern":1},"sourceMatrix":{"official_documentation|candidate_reviewed_documentary|permittedPublicHTML":65,"primary_research|candidate_reviewed_documentary|permittedPublicHTML":10,"professional_practice|candidate_reviewed_professional_practice|permittedPublicHTML":15,"specialist_discussion|candidate_discovery_only|searchDiscoveryOnly":4,"community_pattern|candidate_discovery_only|searchDiscoveryOnly":1},"domains":{"gain_staging":140,"bus_processing":130,"clipping_limiting_loudness":160},"scenarioDomains":{"gain_staging":420,"bus_processing":390,"clipping_limiting_loudness":480},"scenarioTypes":{"better_with_tradeoff":430,"cannot_find_or_measure":430,"no_change":430},"retrievalTypes":{"canonical":430,"comparison":430,"followup":430,"logic":430,"short_query":430},"archiveSHA256":"0918e6a8b97d1944696cf62e8072ca01c62540890a76d6a88c1e5956c1060130","manifestSHA256":"c17a4cee0168172e6f191c9ad00b7515b821c71b4db82fc2200c9bb1b96c4aa7","treeSHA256":"4768f21d3400781fddb59f90a515915b258b5ddfc9e57dee952e83ba3f80c09b","checksumSHA256":"26ea1fa29a5eab11ddf492ca4ddc078b53b4339b023967e373db21b687d12b03","dependencySHA256":"0b8f38b1990d6101b972aaf4c94889e246598d452d514a2e2a0cc4274a579678"},
    P10_ID: {"number":10,"canonical":450,"utterances":10350,"scenarios":1350,"retrieval":2250,"contradictions":48,"myths":56,"sources":81,"documentary":40,"scenarioMessageCounts":{6:1350},"contradictionCap":2,"mythCap":2,"combinedCap":4,"includePrimaryResearch":False,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":True,"emitTopic":True,"canonicalOnlyRuntime":True,"classifiedRetrievalTests":True,"observedStatusContract":True,"disagreementSelectionBasis":True,"rawExactCount":450,"runtimeExactCount":0,"rawNonExactCount":1800,"runtimeNonExactCount":2250,"sourceClassCounts":{"official_documentation":40,"professional_practice":33,"specialist_discussion":7,"community_pattern":1},"sourceMatrix":{"official_documentation|candidate_reviewed_documentary|permittedPublicHTML":40,"professional_practice|candidate_reviewed_professional_practice|permittedPublicHTML":33,"specialist_discussion|candidate_discovery_only|searchDiscoveryOnly":7,"community_pattern|candidate_discovery_only|searchDiscoveryOnly":1},"domains":{"flex_time_manual_timing":450},"scenarioDomains":{"flex_time_manual_timing":1350},"scenarioTypes":{"better_tradeoff":450,"cannot_find":450,"no_change":450},"retrievalTypes":{"exact_unique":450,"diagnostic_semantic_only":450,"diagnostic_multi_intent":450,"diagnostic_cross_domain_collision":450,"diagnostic_low_margin":450},"archiveSHA256":"bd4f86037377ff4ef070dcb609d7e97f697f22a16b396073b00357098daa8827","manifestSHA256":"6f56095b16c1ae9560e322623b48f10135001716628467e3db3b68113e42814b","integrationManifestSHA256":"f72f5cbe2290087e93ffc5acd4f50b5b3a2035528248be6ce41077c5f040b310","treeSHA256":"907e98c7194fa3de483be18f11aa7582cf41707dbd4b329625f0f966d6dd391e","checksumSHA256":"de1a1b297a49da51a13c6e05798b332d20045ad550967bb7c458b35c7de792d5","dependencySHA256":"6ee41fbe8c2be06e9e332bf77778c90bc91a61ba6229d3069323976d222d3487"},
    "tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping": {"number":11,"canonical":450,"utterances":10350,"scenarios":1350,"retrieval":2250,"contradictions":50,"myths":60,"sources":79,"documentary":40,"scenarioMessageCounts":{6:1350},"contradictionCap":2,"mythCap":2,"combinedCap":4,"includePrimaryResearch":True,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":True,"emitTopic":True,"canonicalOnlyRuntime":True,"classifiedRetrievalTests":True,"integrationManifestReconciliation":True,"observedStatusContract":{"review_state":{"candidate_discovery_only","candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_primary_research","candidate_reviewed_professional_practice"},"native_review_state":{"candidate_discovery_only","candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_primary_research","candidate_reviewed_professional_practice"},"original_review_state":{"candidate_discovery_only","candidate_procedure_synthesis","candidate_reviewed_documentary","candidate_reviewed_primary_research","candidate_reviewed_professional_practice","community_and_professional_disagreement","derived_myth_correction","derived_synthesis","owner_supplied_example_language","synthetic_exact_retrieval_fixture"},"original_verification_status":{"candidate_generated_from_registered_sources","deterministic_fixture_alias","literal_user_example_preserved","source_metadata_registered","source_span_or_documentary_metadata_registered"},"logic_verification_status":{"candidate_unverified_on_installed_logic","not_applicable_to_source"},"runtime_eligibility":{"excluded_from_runtime","retrieval_candidate","source_reference_only","test_only"}},"archiveRequired":True,"disagreementSelectionBasis":True,"metadataRepair":True,"rawExactCount":450,"runtimeExactCount":0,"rawNonExactCount":1800,"runtimeNonExactCount":2250,"sourceClassCounts":{"official_documentation":40,"primary_research":14,"professional_practice":14,"specialist_discussion":10,"community_pattern":1},"sourceMatrix":{"official_documentation|candidate_reviewed_documentary|permittedPublicHTML":40,"primary_research|candidate_reviewed_primary_research|permittedPublicHTML":14,"professional_practice|candidate_reviewed_professional_practice|permittedPublicHTML":14,"specialist_discussion|candidate_discovery_only|searchDiscoveryOnly":10,"community_pattern|candidate_discovery_only|manualSeedOnly":1},"domains":{"smart_tempo_bpm_detection_tempo_mapping":450},"scenarioDomains":{"smart_tempo_bpm_detection_tempo_mapping":1350},"scenarioTypes":{"better_tradeoff":450,"cannot_find":450,"no_change":450},"retrievalTypes":{"exact_unique":450,"diagnostic_semantic_only":450,"diagnostic_multi_intent":450,"diagnostic_cross_domain_collision":450,"diagnostic_low_margin":450},"archiveSHA256":"0579ec7f516d71a39bf6eca5f284ef2b9fc8ef32e005ff517b94e8482f5d9386","manifestSHA256":"49db3cf8b10ca9dade637811aa63d34fe6ae753d8d04c91b88e1baf16da980b8","integrationManifestSHA256":"9d704cbd98dd06192452a77257ebd2cdd40343256ffcb45a8d5604f96b6b6202","treeSHA256":"4f553a43ee3cddadb182423033c1c8b58f3c9699e9c5daa6d50c04106ed2ec6d","checksumSHA256":"32aa9c4a497f32486a01c4fc3eac93a536858cee1f7a5565bc27b34a447ccf13","dependencySHA256":"ef92d5379c5a07abd54ea149bf2292f8bab73193945be6cadc10aaca28bcb809"},
    P12_ID: {"number":12,"canonical":480,"utterances":11040,"scenarios":1440,"retrieval":2400,"contradictions":52,"myths":64,"sources":84,"documentary":36,"scenarioMessageCounts":{6:1440},"contradictionCap":2,"mythCap":2,"combinedCap":4,"includePrimaryResearch":True,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":True,"emitTopic":True,"canonicalOnlyRuntime":True,"classifiedRetrievalTests":True,"fixtureMode":"exact_subset","fixtureTestCount":480,"integrationManifestReconciliation":True,"observedStatusContract":True,"archiveRequired":True,"disagreementSelectionBasis":True,"metadataRepair":True,"rawExactCount":480,"runtimeExactCount":0,"rawNonExactCount":1920,"runtimeNonExactCount":2400,"sourceClassCounts":{"official_documentation":36,"primary_research":2,"professional_practice":21,"specialist_discussion":24,"community_pattern":1},"sourceMatrix":{"official_documentation|candidate_reviewed_documentary|permittedPublicHTML":36,"primary_research|candidate_reviewed_primary_research|searchDiscoveryOnly":2,"professional_practice|candidate_reviewed_professional_practice|permittedPublicHTML":21,"specialist_discussion|candidate_discovery_only|manualSeedOnly":5,"specialist_discussion|candidate_discovery_only|searchDiscoveryOnly":19,"community_pattern|candidate_discovery_only|manualSeedOnly":1},"domains":{"recording_latency_monitoring_delay":120,"input_monitoring_record_enable_signal_flow":120,"take_folders_comping_multiple_performances":120,"cycle_punch_replace_recording":120},"scenarioDomains":{"recording_latency_monitoring_delay":360,"input_monitoring_record_enable_signal_flow":360,"take_folders_comping_multiple_performances":360,"cycle_punch_replace_recording":360},"scenarioTypes":{"better_tradeoff":480,"cannot_find_or_recover":480,"no_change":480},"retrievalTypes":{"exact_unique":480,"diagnostic_semantic_only":480,"diagnostic_multi_intent":480,"diagnostic_cross_domain_collision":480,"diagnostic_low_margin":480},"archiveSHA256":"9ed250ad60cccc4eee4544f68b3624187555d5b6b5d725f86b2058a291209557","manifestSHA256":"9a6978a6e070c374156d7b7645e302ad977fd68f2ad8f3ec7be79fbfdd21ee56","integrationManifestSHA256":"12471db2a877563f66bcf091cb278b4745a6a7a530bbccaa852d42ae81ecacc3","treeSHA256":"9365f374d39f4c79443a461518361ebb431ff8ea335fa76ee95792685f98fd45","checksumSHA256":"bae938aa9f2c038b76bec539bff81f6054e677c14dea31792f62cfea6e31e30a","dependencySHA256":"fc50eefa42bace39195595901965e0b73ca0dc1ec7c2c57dd1b77ccbd06ce8e5","disagreementSHA256":"52d27cb3076e5a31a87863ff01ba5b1de39375c1b09e625f2d7a520c739653a4","declaredRuntimeFiles":["generated:research/community_knowledge/runtime/pkg012_recording_latency_monitoring_comping_punch.runtime.jsonl"]},
    P13_ID: {"number":13,"canonical":480,"utterances":11040,"scenarios":1440,"retrieval":2400,"contradictions":52,"myths":64,"sources":88,"documentary":40,"scenarioMessageCounts":{6:1440},"contradictionCap":2,"mythCap":2,"combinedCap":4,"includePrimaryResearch":False,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":True,"emitTopic":True,"canonicalOnlyRuntime":True,"classifiedRetrievalTests":True,"fixtureMode":"exact_subset","fixtureTestCount":480,"integrationManifestReconciliation":True,"observedStatusContract":True,"archiveRequired":True,"disagreementSelectionBasis":True,"metadataRepair":True,"runtimeExcludeCardStatusKeys":True,"sourceHandlingByAccessContract":True,"rawNormalizedUniqueMatchCount":952,"rawNormalizedNonMatchCount":1448,"diagnosticNormalizedExactCollisionCount":472,"diagnosticNormalizedExactByClassification":{"exact_unique":480,"diagnostic_semantic_only":472,"diagnostic_multi_intent":0,"diagnostic_cross_domain_collision":0,"diagnostic_low_margin":0},"runtimeNormalizedUniqueMatchCount":0,"runtimeNormalizedNonMatchCount":2400,"classifiedExpectedTop1Count":480,"classifiedDiagnosticOnlyCount":1920,"sourceClassCounts":{"official_documentation":40,"professional_practice":30,"specialist_discussion":14,"community_pattern":4},"sourceMatrix":{"official_documentation|candidate_reviewed_documentary|permittedPublicHTML":40,"professional_practice|candidate_reviewed_professional_practice|permittedPublicHTML":30,"specialist_discussion|candidate_discovery_only|permittedPublicHTML":14,"community_pattern|candidate_discovery_only|manualSeedOnly":4},"domains":{"sends_buses_auxes_shared_effects":240,"track_stacks_groups_submixes":240},"scenarioDomains":{"sends_buses_auxes_shared_effects":720,"track_stacks_groups_submixes":720},"scenarioTypes":{"better_tradeoff":480,"cannot_find_or_trace":480,"no_change":480},"retrievalTypes":{"exact_unique":480,"diagnostic_semantic_only":480,"diagnostic_multi_intent":480,"diagnostic_cross_domain_collision":480,"diagnostic_low_margin":480},"archiveSHA256":"ca228a0e546339531df2034c228b2cbf4e4e44097ba8714453e9eb1e01034fd9","manifestSHA256":"30cc9fb35ac4d6427e64b5f43f82329b6b43323b617fa84b6fb11a84e2cec27d","integrationManifestSHA256":"fd17b869af4fe68d14b47c60f11945ce9e333fde4b56abe70280961bb7626fe5","treeSHA256":"33bc62d9e034b09bc6b18107f235d5254cd2f75bf1352e5392ac9d31282811e6","checksumSHA256":"6fd60925bc32e9a356d7573d691c6c0be6b1a16d5f350dd67a58bf6423af41f4","dependencySHA256":"f4603d8839f578acb831b6beb5eb21eed434e5a16dc4c73e1620320afc3b5c06","disagreementSHA256":"f083bb553897b63a834073bae1c6e443dad5ea692715c01d0f38f56deeffb056","declaredRuntimeFiles":["generated:research/community_knowledge/runtime/pkg013_sends_buses_auxes_track_stacks_groups_submixes.runtime.jsonl"]},
    P14_ID: {"number":14,"canonical":660,"utterances":15180,"scenarios":1980,"retrieval":3300,"contradictions":66,"myths":78,"sources":88,"documentary":48,"scenarioMessageCounts":{6:1980},"contradictionCap":2,"mythCap":2,"combinedCap":4,"includePrimaryResearch":False,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":True,"emitTopic":True,"canonicalOnlyRuntime":True,"classifiedRetrievalTests":True,"fixtureMode":"exact_subset","fixtureTestCount":660,"integrationManifestReconciliation":True,"observedStatusContract":True,"archiveRequired":True,"disagreementSelectionBasis":True,"metadataRepair":True,"runtimeExcludeCardStatusKeys":True,"sourceHandlingByAccessContract":True,"competingHypothesesText":True,"sourceRetrievedAtOptional":True,"runtimeFieldExclusionFragments":["review","status","verification","eligibility","procedure","navigation","evaluation","scenario","sqlite","test","expected","authority"],"runtimeCardKeyExclusions":["authoritativeSupportingSourceIDs"],"rawNormalizedUniqueMatchCount":1296,"rawNormalizedNonMatchCount":2004,"diagnosticNormalizedExactCollisionCount":636,"diagnosticNormalizedExactByClassification":{"exact_unique":660,"diagnostic_semantic_only":636,"diagnostic_multi_intent":0,"diagnostic_cross_domain_collision":0,"diagnostic_low_margin":0},"runtimeNormalizedUniqueMatchCount":0,"runtimeNormalizedNonMatchCount":3300,"classifiedExpectedTop1Count":660,"classifiedDiagnosticOnlyCount":2640,"sourceClassCounts":{"official_documentation":48,"professional_practice":20,"specialist_discussion":12,"community_pattern":8},"sourceMatrix":{"official_documentation|candidate_reviewed_documentary|permittedPublicHTML":48,"professional_practice|candidate_reviewed_professional_practice|permittedPublicHTML":20,"specialist_discussion|candidate_not_yet_human_reviewed|permittedPublicHTML":12,"community_pattern|candidate_not_yet_human_reviewed|manualSeedOnly":8},"domains":{"sidechain_routing_ducking":100,"volume_pan_plugin_automation":100,"automation_modes_troubleshooting":110,"midi_quantization_groove":110,"midi_velocity_musical_dynamics":120,"midi_transform_humanize_batch_editing":120},"scenarioDomains":{"sidechain_routing_ducking":300,"volume_pan_plugin_automation":300,"automation_modes_troubleshooting":330,"midi_quantization_groove":330,"midi_velocity_musical_dynamics":360,"midi_transform_humanize_batch_editing":360},"scenarioTypes":{"better_tradeoff":660,"cannot_find_or_trace":660,"no_change":660},"retrievalTypes":{"exact_unique":660,"diagnostic_semantic_only":660,"diagnostic_multi_intent":660,"diagnostic_cross_domain_collision":660,"diagnostic_low_margin":660},"archiveSHA256":"2e45a493f575e61c35a995bbd6fb15bf75106efbb92af49087dfceadfba359df","manifestSHA256":"6abcd58ad650970156c13e982150420b6d446e3d83a8419630be2d9250d5494b","integrationManifestSHA256":"256e74f5f1eb03a235e22ce561c9963909772010e67729980bd6e29b471b69fc","treeSHA256":"da89792ee2d45e6a4529872a3d32648f36563bb38df82669ef2f48c95243d240","checksumSHA256":"c76793affdd798ecb31d25a6595a650be2283e3a4aee66cfca10b8c4db2a0866","dependencySHA256":"bb879a742ee9c72ca77cfaa52087f444ec87a088ec2a3dff05ce8f79c43218ca","disagreementSHA256":"5677fdceba6116b3c31e88af4cc537d26f0cd74364f4c72570128ce15976895b","declaredRuntimeFiles":["generated:research/community_knowledge/runtime/pkg014_sidechain_automation_midi_groove_velocity_transform.runtime.jsonl"]},
    P15_ID: {"number":15,"canonical":720,"utterances":16560,"scenarios":2160,"retrieval":3600,"contradictions":72,"myths":84,"sources":90,"documentary":59,"scenarioMessageCounts":{6:2160},"contradictionCap":2,"mythCap":2,"combinedCap":4,"includePrimaryResearch":True,"preserveDisagreementProvenance":True,"directSemanticMap":True,"recordSpecificRationale":True,"nonProcessingField":False,"emitTopic":True,"canonicalOnlyRuntime":True,"classifiedRetrievalTests":True,"fixtureMode":"exact_subset","fixtureTestCount":720,"integrationManifestReconciliation":True,"observedStatusContract":True,"archiveRequired":True,"disagreementSelectionBasis":True,"metadataRepair":True,"runtimeExcludeCardStatusKeys":True,"competingHypothesesText":True,"sourceRetrievedAtOptional":True,"strategyDerivedStopRule":True,"runtimeFieldExclusionFragments":["review","status","verification","eligibility","procedure","navigation","evaluation","scenario","sqlite","test","expected","authority"],"runtimeCardKeyExclusions":["authoritativeSupportingSourceIDs"],"rawNormalizedUniqueMatchCount":1440,"rawNormalizedNonMatchCount":2160,"diagnosticNormalizedExactCollisionCount":720,"diagnosticNormalizedExactByClassification":{"exact_unique":720,"diagnostic_semantic_only":720,"diagnostic_multi_intent":0,"diagnostic_cross_domain_collision":0,"diagnostic_low_margin":0},"runtimeNormalizedUniqueMatchCount":0,"runtimeNormalizedNonMatchCount":3600,"classifiedExpectedTop1Count":720,"classifiedDiagnosticOnlyCount":2880,"sourceClassCounts":{"official_documentation":45,"primary_research":14,"professional_practice":13,"specialist_discussion":14,"community_pattern":4},"sourceMatrix":{"official_documentation|candidate_reviewed_documentary|permittedPublicHTML":45,"primary_research|candidate_reviewed_documentary|permittedPublicHTML":14,"professional_practice|candidate_reviewed_professional_practice|permittedPublicHTML":13,"specialist_discussion|candidate_discovery_only|permittedPublicHTML":14,"community_pattern|candidate_discovery_only|manualPublicSeedOnly":3,"community_pattern|candidate_discovery_only|permittedPublicHTML":1},"domains":{"bounce_export_stems":140,"freeze_cpu_management":100,"logic_object_model":120,"midi_cc_sustain_expression":120,"piano_roll_precise_editing":120,"plugin_delay_low_latency":120},"scenarioDomains":{"bounce_export_stems":420,"freeze_cpu_management":300,"logic_object_model":360,"midi_cc_sustain_expression":360,"piano_roll_precise_editing":360,"plugin_delay_low_latency":360},"scenarioTypes":{"better_tradeoff":720,"cannot_find_or_wrong_owner":720,"no_change":720},"retrievalTypes":{"exact_unique":720,"diagnostic_semantic_only":720,"diagnostic_multi_intent":720,"diagnostic_cross_domain_collision":720,"diagnostic_low_margin":720},"archiveSHA256":"bfd65f88b36ba1de1bddddddc1b397f5e36032671dcf1098d0caaf225a7b3f98","sidecarSHA256":"d14e41414a751c9791695667cf31b5c44998ce1f124bed76c9d53860f814ce0d","manifestSHA256":"60f3d680c08016a0b68687da1ce7c0a5cb4feb7e95d2e17e5154970908bf9503","integrationManifestSHA256":"950c92991fb533ef665a577935d6036217daab8e470daa883f363e40a8287abb","treeSHA256":"7d208108addd476c9e2ad25d18eedefcd5e8852e69fb6d2a017581ac833bc1db","checksumSHA256":"e0425cf3ff96b0af1aebc0f43aa5c44ecdd8ee508b4541a71bce086ab720b84d","dependencySHA256":"ff039dd2ab9565ffb9bf950aad60905ac9460ec4323fc8b74c93beba86b91b93","disagreementSHA256":"2357d5a3da6816225b888f00fc766f7083510a0a76b24c9c66a9de5f12166c7d","declaredRuntimeFiles":["generated:research/community_knowledge/runtime/pkg015_midi_cc_piano_roll_bounce_freeze_pdc_object_model.runtime.jsonl"]},
}
STABLE_CONTRACT_SPECS[P12_ID].update({
    "runtimeExcludeCardStatusKeys": True,
    "sourceHandlingByAccessContract": True,
    "classifiedExpectedTop1Count": 480,
    "classifiedDiagnosticOnlyCount": 1920,
    "rawNormalizedUniqueMatchCount": 944,
    "rawNormalizedNonMatchCount": 1456,
    "diagnosticNormalizedExactCollisionCount": 464,
    "diagnosticNormalizedExactByClassification": {"exact_unique": 480, "diagnostic_semantic_only": 464, "diagnostic_multi_intent": 0, "diagnostic_cross_domain_collision": 0, "diagnostic_low_margin": 0},
    "runtimeNormalizedUniqueMatchCount": 0,
    "runtimeNormalizedNonMatchCount": 2400,
    "metadataRepairPredecessors": [
        {"runtimeSHA256":"5f1a7377861437f43673bc3f054df06d186f9054f78cef0909dd9316199d31e3", "evaluationSHA256":"5d87c5332d5b9c0cf538f0e636a68aeb4be1c7a7c8e207d7ece2cf79e7e25b20"},
        {"runtimeSHA256":"7552d9ecd0b068e5a1f36c995e8fcaa088661f73dd65829f027a0aa0a1bd2cea", "evaluationSHA256":"2c6e41aa45489b3b48de75371d9fd9ff480f2adbbcbfa84fc3b8f702fc84c4f1"},
    ],
})
STABLE_CONTRACT_SPECS[P13_ID].update({"competingHypothesesText": True})
STABLE_CONTRACT_SPECS[P13_ID].update({"sourceRetrievedAtOptional": True})
for _stable_spec in STABLE_CONTRACT_SPECS.values():
    if _stable_spec.get("fixtureMode") == "exact_subset":
        for _legacy_accounting_key in ("rawExactCount", "rawNonExactCount", "runtimeExactCount", "runtimeNonExactCount"):
            _stable_spec.pop(_legacy_accounting_key, None)
STABLE_CONTRACT_SPECS[P10_ID]["observedStatusContract"]={
    "review_state":{"candidate_discovery_only","candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_professional_practice"},
    "native_review_state":{"candidate_discovery_only","candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_professional_practice"},
    "original_review_state":{"candidate_discovery_only","candidate_procedure_synthesis","candidate_reviewed_documentary","candidate_reviewed_professional_practice","community_and_professional_disagreement","derived_myth_correction","derived_synthesis","owner_supplied_example_language","synthetic_exact_retrieval_fixture"},
    "original_verification_status":{"candidate_generated_from_registered_sources","deterministic_fixture_alias","literal_user_example_preserved","source_metadata_registered","source_span_or_documentary_metadata_registered"},
    "logic_verification_status":{"candidate_unverified_on_installed_logic","not_applicable_to_source"},
    "runtime_eligibility":{"excluded_from_runtime","retrieval_candidate","source_reference_only","test_only"},
}
STABLE_CONTRACT_SPECS[P12_ID]["observedStatusContract"]={
    "review_state":{"candidate_discovery_only","candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_primary_research","candidate_reviewed_professional_practice"},
    "native_review_state":{"candidate_discovery_only","candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_primary_research","candidate_reviewed_professional_practice"},
    "original_review_state":{"candidate_discovery_only","candidate_procedure_synthesis","candidate_reviewed_documentary","candidate_reviewed_primary_research","candidate_reviewed_professional_practice","community_and_professional_disagreement","derived_myth_correction","derived_synthesis","owner_supplied_example_language","synthetic_exact_retrieval_fixture"},
    "original_verification_status":{"candidate_generated_from_registered_sources","deterministic_fixture_alias","literal_user_example_preserved","source_metadata_registered","source_span_or_documentary_metadata_registered"},
    "logic_verification_status":{"candidate_unverified_on_installed_logic","not_applicable_to_source"},
    "runtime_eligibility":{"excluded_from_runtime","retrieval_candidate","source_reference_only","test_only"},
}
STABLE_CONTRACT_SPECS[P13_ID]["observedStatusContract"]=copy.deepcopy(STABLE_CONTRACT_SPECS[P12_ID]["observedStatusContract"])
STABLE_CONTRACT_SPECS[P13_ID].update({
    # The manifest permits canonical guidance but forbids the raw package's
    # procedure/evaluation/navigation/test artifacts.  Provenance remains in
    # raw and registry records; no authority-labelled field ships to runtime.
    "runtimeFieldExclusionFragments": ["review", "status", "verification", "eligibility", "procedure", "navigation", "evaluation", "scenario", "sqlite", "test", "expected", "authority"],
    "runtimeCardKeyExclusions": ["authoritativeSupportingSourceIDs"],
    # The prior reviewed P13 projection is an interruption-safe predecessor
    # for this narrower runtime schema; no unpinned state is accepted.
    "metadataRepairPredecessors": [{
        "runtimeSHA256": "3ef136bf592e3db7d79d90710edddc626526e22ab24827a76e600f15bc48b0cc",
        "evaluationSHA256": "4cf840862a14a18e883a781a3a82b72996948852f7ae1c4b29f31f1b8fead1a4",
    }],
})
STABLE_CONTRACT_SPECS[P13_ID]["observedStatusContract"]={
    "review_state":{"candidate_discovery_only","candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_professional_practice"},
    "native_review_state":{"candidate_discovery_only","candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_professional_practice"},
    "original_review_state":{"candidate_discovery_only","candidate_procedure_synthesis","candidate_reviewed_documentary","candidate_reviewed_professional_practice","community_and_professional_disagreement","derived_myth_correction","derived_synthesis","owner_supplied_example_language","synthetic_exact_retrieval_fixture"},
    "original_verification_status":{"candidate_generated_from_registered_sources","deterministic_fixture_alias","literal_user_example_preserved","source_metadata_registered","source_span_or_documentary_metadata_registered"},
    "logic_verification_status":{"candidate_unverified_on_installed_logic","not_applicable_to_source"},
    "runtime_eligibility":{"excluded_from_runtime","retrieval_candidate","source_reference_only","test_only"},
}
STABLE_CONTRACT_SPECS[P14_ID]["observedStatusContract"]={
    # Derived from the complete P14 raw record set and integration declaration;
    # kept independent of P12/P13 because P14 has neither discovery-native
    # sources nor primary-research review states.
    "review_state":{"candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_professional_practice"},
    "native_review_state":{"candidate_not_yet_human_reviewed","candidate_reviewed_documentary","candidate_reviewed_professional_practice"},
    "original_review_state":{"candidate_discovery_only","candidate_procedure_synthesis","candidate_reviewed_documentary","candidate_reviewed_professional_practice","community_and_professional_disagreement","derived_myth_correction","derived_synthesis","owner_supplied_example_language","synthetic_exact_retrieval_fixture"},
    "original_verification_status":{"candidate_generated_from_registered_sources","deterministic_fixture_alias","literal_user_example_preserved","source_metadata_registered","source_span_or_documentary_metadata_registered"},
    "logic_verification_status":{"candidate_unverified_on_installed_logic","not_applicable_to_source"},
    "runtime_eligibility":{"excluded_from_runtime","retrieval_candidate","source_reference_only","test_only"},
}
STABLE_CONTRACT_SPECS[P15_ID]["observedStatusContract"]=copy.deepcopy(STABLE_CONTRACT_SPECS[P10_ID]["observedStatusContract"])

def p10_runtime_contract_reconciliation(package_root=None):
    """Canonical repository record of the immutable incoming/runtime boundary."""
    root=pathlib.Path(package_root) if package_root is not None else ROOT/"research/community_knowledge/packages"/P10_ID
    integration=readj(root/"integration/integration_manifest.json")
    incoming={
        "projection":"bounded-jsonl-projection-v1",
        "source":"corpus/canonical_qa.jsonl",
        "record_count":450,
        "forbidden_categories":["procedures","Logic navigation instructions","evaluations","multi-turn scenarios","SQLite databases","test fixtures"],
        "purity_validation":"recursive key and text scan plus full validator",
        "declared_runtime_files":["generated:research/community_knowledge/runtime/pkg010_flex_time_manual_timing.runtime.jsonl"],
    }
    expected_integration={
        "contract":"tracksmith-corpus-integration-manifest",
        "contract_version":"1.0",
        "compatibility":{"general_tutor_generated_swift_modified":False,"mode":"additive","overwrites_prior_ids":False,"requires_registered_prerequisites":True,"runtime_schema":"bounded-jsonl-projection-v1"},
        "runtime_projection":{"forbidden_categories":incoming["forbidden_categories"],"generated_by":"tools/import_to_tracksmith.py","purity_validation":incoming["purity_validation"],"record_count":incoming["record_count"],"source":incoming["source"]},
        "runtime_files":incoming["declared_runtime_files"],
    }
    if not isinstance(integration,dict) or any(integration.get(key)!=value for key,value in expected_integration.items()):
        raise ValueError("P10 integration runtime declaration drift")
    if digest((root/"integration/integration_manifest.json").read_bytes()) != STABLE_CONTRACT_SPECS[P10_ID]["integrationManifestSHA256"]:
        raise ValueError("P10 integration manifest pin drift")
    runtime=readj(P10_RUNTIME_RESOURCE); evaluation=readj(P10_EVALUATION_RESOURCE)
    if digest(P10_RUNTIME_RESOURCE.read_bytes()) != P10_RUNTIME_SHA256 or digest(P10_EVALUATION_RESOURCE.read_bytes()) != P10_EVALUATION_SHA256:
        raise ValueError("P10 shipping resource pin drift")
    if runtime.get("schemaVersion")!="2.0" or runtime.get("packageID")!=P10_ID or len(runtime.get("canonicalCards",[]))!=450 or runtime.get("utterances")!=[]:
        raise ValueError("P10 canonical-only shipping projection drift")
    if evaluation.get("packageID")!=P10_ID or len(evaluation.get("retrievalTests",[]))!=2250:
        raise ValueError("P10 evaluation-only projection drift")
    return {
        "integration_manifest_sha256":STABLE_CONTRACT_SPECS[P10_ID]["integrationManifestSHA256"],
        "integration_contract":"tracksmith-corpus-integration-manifest",
        "integration_contract_version":"1.0",
        "incoming_runtime_projection":incoming,
        "repository_adapter":"tracksmith-corpus-integration-manifest/1.0",
        "shipping_schema_version":"2.0",
        "shipping_runtime_projection":"canonical-only",
        "shipping_canonical_count":450,
        "runtime_resource_sha256":P10_RUNTIME_SHA256,
        "evaluation_test_only_sha256":P10_EVALUATION_SHA256,
    }

def integration_contract_reconciliation(pid, package_root=None):
    """Pin the incoming integration declaration before any package code can run.

    The artifact's declaration is authoritative only as immutable data.  The
    repository separately chooses the bounded shipping projection below.
    """
    spec=STABLE_CONTRACT_SPECS[pid]
    if not spec.get("integrationManifestReconciliation"):
        return None
    root=pathlib.Path(package_root) if package_root is not None else ROOT/"research/community_knowledge/packages"/pid
    integration=readj(root/"integration/integration_manifest.json")
    expected={
        "contract":"tracksmith-corpus-integration-manifest",
        "contract_version":"1.0",
        "compatibility":{"general_tutor_generated_swift_modified":False,"mode":"additive","overwrites_prior_ids":False,"requires_registered_prerequisites":True,"runtime_schema":"bounded-jsonl-projection-v1"},
        "runtime_projection":{"forbidden_categories":["procedures","Logic navigation instructions","evaluations","multi-turn scenarios","SQLite databases","test fixtures"],"generated_by":"tools/import_to_tracksmith.py","purity_validation":"recursive key and text scan plus full validator","record_count":spec["canonical"],"source":"corpus/canonical_qa.jsonl"},
    }
    if pid == P15_ID:
        # P015 is the first immutable package-manifest adapter.  Keep that
        # declaration exact here; do not weaken P10-P14's distinct contract.
        expected["contract"]="tracksmith-corpus-package"
    if spec.get("declaredRuntimeFiles"):
        expected["runtime_files"] = spec["declaredRuntimeFiles"]
    if not isinstance(integration,dict) or any(integration.get(key)!=value for key,value in expected.items()):
        raise ValueError(pid+" integration runtime declaration drift")
    if digest((root/"integration/integration_manifest.json").read_bytes()) != spec["integrationManifestSHA256"]:
        raise ValueError(pid+" integration manifest pin drift")
    return {"integration_manifest_sha256":spec["integrationManifestSHA256"],"integration_contract":expected["contract"],"integration_contract_version":"1.0","repository_adapter":"tracksmith-corpus-package/1.0" if pid == P15_ID else "tracksmith-corpus-integration-manifest/1.0","shipping_schema_version":"2.0","shipping_runtime_projection":"canonical-only","shipping_canonical_count":spec["canonical"],"incoming_runtime_projection":expected["runtime_projection"]}

def normalized_observed_status_contract(spec):
    """Turn the stable-spec set declaration into deterministic JSON metadata."""
    contract=spec.get("observedStatusContract")
    if not isinstance(contract,dict) or not contract:
        raise ValueError("metadata repair requires an observed-status contract")
    normalized={}
    for field,values in sorted(contract.items()):
        if not isinstance(field,str) or not isinstance(values,(set,frozenset,list,tuple)) or not values or any(not isinstance(value,str) for value in values):
            raise ValueError("metadata repair observed-status contract drift")
        normalized[field]=sorted(set(values))
    return normalized

def metadata_repair_reconciliation(pid, runtime_value=None, evaluation_value=None):
    """Pin shipping metadata only for stable specs that declare this capability."""
    spec=STABLE_CONTRACT_SPECS[pid]
    if not spec.get("metadataRepair"):
        raise ValueError(pid+" does not declare metadata repair")
    reconciliation=integration_contract_reconciliation(pid)
    if reconciliation is None:
        raise ValueError(pid+" metadata repair requires an integration declaration")
    runtime_path=RES/(pid+".json"); evaluation_path=EVAL/(pid+"-evaluation.json")
    if (runtime_value is None or evaluation_value is None) and any(path.is_symlink() or not path.is_file() for path in (runtime_path,evaluation_path)):
        raise ValueError(pid+" metadata repair requires shipping resources")
    runtime=readj(runtime_path) if runtime_value is None else runtime_value
    evaluation=readj(evaluation_path) if evaluation_value is None else evaluation_value
    if runtime.get("schemaVersion")!="2.0" or runtime.get("packageID")!=pid or len(runtime.get("canonicalCards",[]))!=spec["canonical"] or runtime.get("utterances")!=[]:
        raise ValueError(pid+" canonical-only shipping projection drift")
    assert_runtime_safe(runtime)
    if evaluation.get("packageID")!=pid or len(evaluation.get("retrievalCases",[]))!=spec["retrieval"] or len(evaluation.get("retrievalTests",[]))!=spec.get("fixtureTestCount", spec["retrieval"]):
        raise ValueError(pid+" evaluation-only projection drift")
    runtime_bytes=runtime_path.read_bytes() if runtime_value is None else canon(runtime).encode()
    evaluation_bytes=evaluation_path.read_bytes() if evaluation_value is None else canon(evaluation).encode()
    return {**reconciliation,"runtime_resource_sha256":digest(runtime_bytes),"evaluation_test_only_sha256":digest(evaluation_bytes),"observed_status_contract":normalized_observed_status_contract(spec)}

_MISSING=object()

def metadata_repair_predecessors(pid):
    """Explicitly pin a reviewed prior reconciliation, never an arbitrary hash."""
    predecessor_pins=STABLE_CONTRACT_SPECS[pid].get("metadataRepairPredecessors", [])
    if not predecessor_pins:
        return []
    def predecessor(runtime_hash, evaluation_hash):
        value=integration_contract_reconciliation(pid)
        value.update({"runtime_resource_sha256":runtime_hash,"evaluation_test_only_sha256":evaluation_hash,"observed_status_contract":normalized_observed_status_contract(STABLE_CONTRACT_SPECS[pid])})
        return value
    return [predecessor(value["runtimeSHA256"], value["evaluationSHA256"]) for value in predecessor_pins]

def reconcile_metadata_pair(pid, row, report, base_registry, base_report, base_reconciliation, reconciliation, predecessors=()):
    """Resume a verified metadata transition without ever replacing a full side.

    Registry and report are written separately.  A crash between those writes is
    therefore a recoverable state only when the surviving side is exactly the
    immutable base/incoming declaration or exactly the expected reconciliation.
    """
    key="runtime_contract_reconciliation"
    if any(row.get(field)!=value for field,value in base_registry.items()) or set(row)-set(base_registry)-{key}:
        raise ValueError(pid+" registry immutable identity/review field drift")
    if any(report.get(field)!=value for field,value in base_report.items()) or set(report)-set(base_report)-{key}:
        raise ValueError(pid+" report immutable identity/tree field drift")
    registry_value=row.get(key,_MISSING); report_value=report.get(key,_MISSING)
    allowed_values=[_MISSING if base_reconciliation is _MISSING else base_reconciliation, reconciliation, *predecessors]
    for side,value in (("registry",registry_value),("report",report_value)):
        if value not in allowed_values:
            raise ValueError(pid+" "+side+" metadata reconciliation drift")
    repaired=registry_value != reconciliation or report_value != reconciliation
    if registry_value != reconciliation:
        row[key]=reconciliation
    if report_value != reconciliation:
        report[key]=reconciliation
    return int(repaired)

def metadata_repair_artifacts(pid, registry=None, report=None, runtime_value=None, evaluation_value=None):
    """Reconcile a generic stable package against a shared registry object."""
    spec=STABLE_CONTRACT_SPECS[pid]
    if not spec.get("metadataRepair"):
        raise ValueError(pid+" does not declare metadata repair")
    incoming=integration_contract_reconciliation(pid)
    reconciliation=metadata_repair_reconciliation(pid, runtime_value, evaluation_value)
    if registry is None: registry=readj(P10_PACKAGE_REGISTRY)
    if report is None: report=readj(ROOT/("research/community_knowledge/import_report_"+pid+".json"))
    rows=[row for row in registry.get("packages",[]) if row.get("package_id")==pid]
    if len(rows)!=1:
        raise ValueError(pid+" registry identity drift")
    row=rows[0]; root=ROOT/"research/community_knowledge/packages"/pid; manifest=readj(root/"package_manifest.json")
    base_registry={"package_id":pid,"package_number":spec["number"],"package_version":manifest["package_version"],"contract_version":manifest["contract_version"],"path":"research/community_knowledge/packages/"+pid,"review_state":manifest["review_state"],"logic_procedure_status":manifest["logic_procedure_status"],"depends_on":manifest["depends_on"],"dependency_resolution":readj(ROOT/"research/community_knowledge/dependency_maps"/(pid+".json")),"package_manifest_sha256":spec["manifestSHA256"]}
    base_report={"status":"staged","package_id":pid,"package_version":manifest["package_version"],"record_counts":manifest["record_counts"],"package_manifest_sha256":spec["manifestSHA256"],"dependency_resolution":base_registry["dependency_resolution"],"staged_tree":{"fileCount":47,"sha256":spec["treeSHA256"]},"staging_authority":"repository_owned_no_follow_copy","incoming_importer_executed":False,"force_semantics":False}
    repairs=reconcile_metadata_pair(pid,row,report,base_registry,base_report,incoming,reconciliation,metadata_repair_predecessors(pid))
    return registry,report,repairs

def p10_metadata_artifacts(registry=None, report=None):
    """Resume the P10 base-to-reconciliation metadata transition safely."""
    reconciliation=p10_runtime_contract_reconciliation()
    if registry is None: registry=readj(P10_PACKAGE_REGISTRY)
    if report is None: report=readj(P10_IMPORT_REPORT)
    rows=[row for row in registry.get("packages",[]) if row.get("package_id")==P10_ID]
    if len(rows)!=1: raise ValueError("P10 registry identity drift")
    row=rows[0]
    manifest=readj(ROOT/"research/community_knowledge/packages"/P10_ID/"package_manifest.json")
    base_registry={"package_id":P10_ID,"package_number":10,"package_version":"1.0.0","contract_version":"1.0","path":"research/community_knowledge/packages/"+P10_ID,"review_state":"candidate_not_yet_human_reviewed","logic_procedure_status":"candidate_unverified_on_installed_logic","depends_on":manifest["depends_on"],"dependency_resolution":readj(ROOT/"research/community_knowledge/dependency_maps"/(P10_ID+".json")),"package_manifest_sha256":STABLE_CONTRACT_SPECS[P10_ID]["manifestSHA256"]}
    base_report={"status":"staged","package_id":P10_ID,"package_version":"1.0.0","record_counts":manifest["record_counts"],"package_manifest_sha256":STABLE_CONTRACT_SPECS[P10_ID]["manifestSHA256"],"dependency_resolution":base_registry["dependency_resolution"],"staged_tree":{"fileCount":47,"sha256":STABLE_CONTRACT_SPECS[P10_ID]["treeSHA256"]},"staging_authority":"repository_owned_no_follow_copy","incoming_importer_executed":False,"force_semantics":False}
    repairs=reconcile_metadata_pair(P10_ID,row,report,base_registry,base_report,_MISSING,reconciliation)
    return registry,report,repairs

def metadata_repair_self_check():
    """Exercise recoverable metadata write interruption states without writing files."""
    registry=readj(P10_PACKAGE_REGISTRY)
    p10_report=readj(P10_IMPORT_REPORT)
    p10_full,p10_report_full,p10_repairs=p10_metadata_artifacts(copy.deepcopy(registry),copy.deepcopy(p10_report))
    if p10_repairs: raise ValueError("P10 self-check requires a fully reconciled fixture")
    generic_pids=[pid for pid,spec in STABLE_CONTRACT_SPECS.items() if spec.get("metadataRepair")]
    if not generic_pids: raise ValueError("metadata repair self-check requires a generic package")
    generic_full={}
    for pid in generic_pids:
        report=readj(ROOT/("research/community_knowledge/import_report_"+pid+".json"))
        checked_registry,checked_report,repairs=metadata_repair_artifacts(pid,copy.deepcopy(registry),copy.deepcopy(report))
        if repairs: raise ValueError(pid+" self-check requires a fully reconciled fixture")
        generic_full[pid]=(checked_registry,checked_report)

    def row_for(value,pid):
        return next(row for row in value["packages"] if row.get("package_id")==pid)
    def base_p10(value):
        value=copy.deepcopy(value); row_for(value,P10_ID).pop("runtime_contract_reconciliation",None); return value
    def base_generic(value,pid):
        value=copy.deepcopy(value); row_for(value,pid)["runtime_contract_reconciliation"]=integration_contract_reconciliation(pid); return value
    def assert_resumes(pid, repair, base_registry, base_report):
        expected_registry,expected_report,_=repair(copy.deepcopy(base_registry),copy.deepcopy(base_report))
        for registry_fixture,report_fixture in ((base_registry,base_report),(expected_registry,base_report),(base_registry,expected_report)):
            repaired_registry,repaired_report,repairs=repair(copy.deepcopy(registry_fixture),copy.deepcopy(report_fixture))
            if repairs != 1 or repaired_registry != expected_registry or repaired_report != expected_report:
                raise ValueError(pid+" metadata interruption self-check failed")
        drift=copy.deepcopy(base_registry); row_for(drift,pid)["runtime_contract_reconciliation"]={"corrupt":True}
        try:
            repair(drift,copy.deepcopy(base_report))
        except ValueError:
            pass
        else:
            raise ValueError(pid+" metadata corruption self-check accepted drift")

    p10_base_registry=base_p10(p10_full); p10_base_report=copy.deepcopy(p10_report_full); p10_base_report.pop("runtime_contract_reconciliation",None)
    assert_resumes(P10_ID,lambda reg,report:p10_metadata_artifacts(reg,report),p10_base_registry,p10_base_report)
    combined_registry=copy.deepcopy(p10_base_registry)
    p10_after,p10_report_after,_=p10_metadata_artifacts(combined_registry,p10_base_report)
    for pid,(generic_registry,generic_report) in generic_full.items():
        generic_base_registry=base_generic(generic_registry,pid); generic_base_report=copy.deepcopy(generic_report); generic_base_report["runtime_contract_reconciliation"]=integration_contract_reconciliation(pid)
        assert_resumes(pid,lambda reg,report,package_id=pid:metadata_repair_artifacts(package_id,reg,report),generic_base_registry,generic_base_report)
        combined_registry,_,_=metadata_repair_artifacts(pid,combined_registry,generic_base_report)
        if row_for(combined_registry,P10_ID).get("runtime_contract_reconciliation") != row_for(p10_after,P10_ID).get("runtime_contract_reconciliation") or row_for(combined_registry,pid).get("runtime_contract_reconciliation") != row_for(generic_registry,pid).get("runtime_contract_reconciliation"):
            raise ValueError("simultaneous metadata repair self-check lost a registry reconciliation")

def stable_metadata_json(value):
    return json.dumps(value,ensure_ascii=False,indent=2,sort_keys=True)+"\n"
def stable_source_tier(row):
    return {"official_documentation":"A","product_documentation":"A","primary_research":"R","professional_practice":"B","specialist_discussion":"C","community_pattern":"C","community_anecdote":"C"}.get(row.get("evidence_class"))
def stable_parts(ids, source_map, include_primary=False):
    mapped={"authoritativeSupportingSourceIDs":[],"professionalPracticeSourceIDs":[],"discoveryLanguageSourceIDs":[]}
    if include_primary: mapped["primaryResearchSourceIDs"]=[]
    if any(identifier.startswith("pkg009.source.") for identifier in ids): mapped["standardsSourceIDs"]=[]
    for identifier in sorted(set(ids)):
        row=source_map.get(identifier)
        if not row: raise ValueError("unknown stable-contract source "+identifier)
        tier=stable_source_tier(row)
        if tier == "R" and not include_primary: raise ValueError("primary research requires stable-contract provenance")
        if identifier in {f"pkg009.source.{number:06d}" for number in range(41,51)}:
            mapped["standardsSourceIDs"].append(identifier)
        else:
            mapped[{"A":"authoritativeSupportingSourceIDs","R":"primaryResearchSourceIDs","B":"professionalPracticeSourceIDs","C":"discoveryLanguageSourceIDs"}[tier]].append(identifier)
    return mapped
def stable_safe(value):
    # The general leak guard deliberately treats visual UI names as navigation.
    # Keep the candidate decision context while removing plural forms that do
    # not match the legacy singular navigation matcher.
    return re.sub(r"\bchannel strips?\b", "output controls", clean(value, True), flags=re.IGNORECASE)
def classified_fixture_accounting(tests, canonical_ids, spec):
    """Classify test-only fixtures without making diagnostics production data.

    P10/P11 retain their full-bijection fixtures.  P12's fixtureMode is an
    exact subset: only the declared exact-unique rows are test fixtures while
    the remaining classified evaluation rows remain diagnostic-only.
    """
    expected_exact=spec["classifiedExpectedTop1Count"] if "classifiedExpectedTop1Count" in spec else spec["rawExactCount"]
    fixture_mode=spec.get("fixtureMode","full_bijection")
    expected={"exact_unique":expected_exact} if fixture_mode=="exact_subset" else dict(spec["retrievalTypes"])
    counts={kind:sum(row.get("classification",row.get("retrieval_classification"))==kind for row in tests) for kind in expected}
    if counts != expected or len(tests) != sum(expected.values()): raise ValueError("classified fixture accounting drift")
    for row in tests:
        kind=row.get("classification",row.get("retrieval_classification")); target=row.get("canonical_qa_id")
        exact_expected = row.get("expected_top_1") if "expected_top_1" in row else row.get("retrieval_expectation")=="expected_top_1"
        if target not in canonical_ids or (kind=="exact_unique") != (row.get("diagnostic_only") is False and exact_expected is True) or (kind!="exact_unique" and (row.get("diagnostic_only") is not True or exact_expected is not False)):
            raise ValueError("classified exact/diagnostic fixture contract drift")
    return counts
def stable_runtime_projection(pid, manifest, manifest_digest, data, mapping=None):
    """The single candidate-facing stable runtime projection used for shipping and preflight.

    `mapping` is optional only for the external non-strict dry-run; strict staging
    and the importer provide it so disagreement attachments/provenance are exact.
    """
    spec=STABLE_CONTRACT_SPECS[pid]
    standards_by_card={}
    if pid == P9_ID:
        standards=readj(ROOT/"research/community_knowledge/standards_maps"/(pid+".json"))["standards"]
        for source_id, detail in standards.items():
            for canonical_id in detail["canonicalIDs"]: standards_by_card.setdefault(canonical_id,[]).append(source_id)
    canonical=data["canonical_qa"]; utter=data["user_utterances"]; contr=data["contradictions"]; myths=data["myths_and_antipatterns"]
    source_map={x["id"]:x for x in data["sources"]}; procedures={x["canonical_qa_id"]:x for x in data["logic_procedure_candidates"]}
    strategies={x["canonical_qa_id"]:x for x in data.get("strategy_candidates", [])}
    if spec.get("strategyDerivedStopRule") and set(strategies) != {row["id"] for row in canonical}:
        raise ValueError(pid+" strategy-derived stop-rule coverage drift")
    attachments={"contradictions":{x["id"]:[] for x in canonical},"myths":{x["id"]:[] for x in canonical}}
    if mapping is not None:
        for kind,rows,source_name in (("contradictions",contr,"contradictions"),("myths",myths,"myths_and_antipatterns")):
            for row in rows:
                detail=mapping[kind][row["id"]]; target=detail["canonicalID"] if isinstance(detail,dict) else detail
                item=contradiction(row,True) if kind=="contradictions" else myth(row,True)
                if spec["preserveDisagreementProvenance"]: item.update({"sourceIDs":sorted(row["source_ids"]),"sourceEvidenceClasses":sorted({source_map[x]["evidence_class"] for x in row["source_ids"]})})
                attachments[kind][target].append(item)
    cards=[]
    for row in canonical:
        procedure=procedures[row["id"]]; source_ids=row["source_ids"]
        hypotheses=row["competing_hypotheses"]
        hypothesis_texts=[stable_safe(value) for value in hypotheses] if spec.get("competingHypothesesText") else [stable_safe(value["label"]+": "+value["description"]) for value in hypotheses]
        stop_rule = strategies[row["id"]]["stop_rule"] if spec.get("strategyDerivedStopRule") else row["logic_guidance"]["stop_condition"]
        card={"id":row["id"],"packageID":pid,"version":manifest["package_version"],"domain":row["domain"],"category":row["subdomain"],"title":stable_safe(row["title"]),"question":stable_safe(row["canonical_question"]),"originalReviewStatus":row["review_state"],"sourceTypes":sorted({source_map[x]["evidence_class"] for x in source_ids}),"evidenceClass":row["evidence_class"],"logicVersion":procedure.get("logic_version_scope"),"currentContext":True,"tags":[stable_safe(x) for x in row["retrieval_tags"]],"clarificationQuestions":[stable_safe(x) for x in row["clarification_questions"]],"competingHypotheses":hypothesis_texts,"recommendedFirstExperiment":stable_safe(row["recommended_first_experiment"]),"rationale":stable_safe(row["key_distinction"]),"listeningCues":[stable_safe(row["logic_guidance"]["listen_for"])],"stopOrUndo":[stable_safe(stop_rule),stable_safe(row["logic_guidance"]["undo"])],"tradeoffs":[stable_safe(x) for x in row["tradeoffs"]],"teachingPrinciple":stable_safe(row["teaching_principle"]),"numericGuidancePolicy":spec.get("numericGuidancePolicy", "starting_point_not_preset"),"packageSequence":spec["number"],"subcategory":row["subdomain"],"directCandidateAnswer":stable_safe(row["direct_answer"]),"keyDistinction":stable_safe(row["key_distinction"]),"firstExperiment":stable_safe(row["recommended_first_experiment"]),"listenFor":stable_safe(row["logic_guidance"]["listen_for"]),"nonAutomationPossibilities":[stable_safe(x) for x in row["non_automation_possibilities"]] if pid==P5_ID else [],"evidenceNeeded":[stable_safe(x) for x in row["evidence_needed"]],"userIntent":stable_safe(row["user_intent"]),"procedureCandidateID":procedure["id"],"procedureVerificationStatus":"candidate_unverified_on_installed_logic","contradictions":attachments["contradictions"][row["id"]],"myths":attachments["myths"][row["id"]],**stable_parts(source_ids,source_map,spec["includePrimaryResearch"])}
        if spec["emitTopic"]: card["topic"]=row["topic"]
        if pid == P9_ID: card["standardsSourceIDs"]=sorted(set(standards_by_card.get(row["id"], [])))
        if spec["nonProcessingField"]: card["nonProcessingPossibilities"]=[stable_safe(x) for x in row["non_processing_possibilities"]]
        if spec.get("canonicalOnlyRuntime"):
            # Canonical-only P10 shipping deliberately omits all candidate
            # procedure references and disagreement material.  Their original
            # status/eligibility remains in raw, source, queue, and evaluation
            # projections only.
            card.pop("procedureCandidateID"); card.pop("procedureVerificationStatus")
            card["contradictions"]=[]; card["myths"]=[]
        if spec.get("runtimeExcludeCardStatusKeys"):
            card.pop("originalReviewStatus")
        for key in spec.get("runtimeCardKeyExclusions", []):
            card.pop(key, None)
        cards.append(card)
    def stable_disagreement(row,kind):
        item=contradiction(row,True) if kind=="contradiction" else myth(row,True)
        if spec["preserveDisagreementProvenance"]: item.update({"sourceIDs":sorted(row["source_ids"]),"sourceEvidenceClasses":sorted({source_map[x]["evidence_class"] for x in row["source_ids"]})})
        return item
    runtime_utterances=[] if spec.get("canonicalOnlyRuntime") else sorted([{ "id":x["id"],"canonicalID":x["canonical_qa_id"],"text":clean_utterance(x["text"],x["canonical_qa_id"]),"originalReviewStatus":x["review_state"]} for x in utter],key=lambda x:x["id"])
    runtime={"schemaVersion":"2.0","packageID":pid,"packageManifestSHA256":manifest_digest,"metadata":{"domains":sorted({x["domain"] for x in cards}),"retrievalMode":"lexical_structured_provisional","runtimeProjection":"canonical-only" if spec.get("canonicalOnlyRuntime") else "candidate-only"},"canonicalCards":sorted(cards,key=lambda x:x["id"]),"utterances":runtime_utterances,"contradictions":[] if spec.get("canonicalOnlyRuntime") else sorted([stable_disagreement(x,"contradiction") for x in contr],key=lambda x:x["id"]),"myths":[] if spec.get("canonicalOnlyRuntime") else sorted([stable_disagreement(x,"myth") for x in myths],key=lambda x:x["id"])}
    if spec.get("runtimeExcludeCardStatusKeys"): assert_runtime_status_free(runtime)
    if spec.get("runtimeFieldExclusionFragments"):
        assert_runtime_field_exclusions(runtime, spec["runtimeFieldExclusionFragments"])
    return runtime
def stable_contract_build(pid, existing_sources, existing_candidates):
    """One stable-contract 1.0 projection path; legacy P1-P4 stay below."""
    spec=STABLE_CONTRACT_SPECS[pid]; root=ROOT/"research/community_knowledge/packages"/pid
    if not root.exists(): raise ValueError(pid+" is not staged")
    manifest=readj(root/"package_manifest.json"); md=digest((root/"package_manifest.json").read_bytes())
    if manifest.get("package_contract")!="tracksmith-corpus-package" or manifest.get("contract_version")!="1.0" or manifest.get("package_id")!=pid or manifest.get("package_number")!=spec["number"]: raise ValueError(pid+" stable contract drift")
    canonical=lines(root/"corpus/canonical_qa.jsonl"); utter=lines(root/"corpus/user_utterances.jsonl"); scenarios=lines(root/"corpus/multiturn_scenarios.jsonl"); retrieval=lines(root/"corpus/retrieval_evaluations.jsonl"); contr=lines(root/"corpus/contradictions.jsonl"); myths=lines(root/"corpus/myths_and_antipatterns.jsonl"); sources=lines(root/"sources/source_registry.jsonl"); claims=lines(root/"knowledge_candidates/claims.jsonl"); strategies=lines(root/"knowledge_candidates/strategies.jsonl"); procedures=lines(root/"knowledge_candidates/logic_procedures.jsonl"); tests=lines(root/"tests/retrieval_cases.jsonl"); integrity=lines(root/"tests/integrity_cases.jsonl")
    counts=manifest["record_counts"]
    expected=(counts["canonical_qa"],counts["user_utterances"],counts["multiturn_scenarios"],counts["retrieval_evaluations"],counts["contradictions"],counts["myths_and_antipatterns"],counts["sources"])
    expected_tuple=tuple(spec[x] for x in ("canonical","utterances","scenarios","retrieval","contradictions","myths","sources"))
    if (len(canonical),len(utter),len(scenarios),len(retrieval),len(contr),len(myths),len(sources)) != expected or expected != expected_tuple: raise ValueError(pid+" inventory drift")
    if any(x.get("review_state")!="candidate_not_yet_human_reviewed" for x in canonical+utter+scenarios+retrieval+contr+myths+claims+strategies+procedures): raise ValueError(pid+" candidate review-state drift")
    if any(stable_source_tier(x) is None for x in sources): raise ValueError(pid+" source evidence/review drift")
    matrix={"|".join((x["evidence_class"],x["review_state"],x["access_mode"])):0 for x in sources}
    for source in sources: matrix["|".join((source["evidence_class"],source["review_state"],source["access_mode"]))]+=1
    if spec.get("sourceMatrix"):
        if matrix != spec["sourceMatrix"]: raise ValueError(pid+" source class/status/access matrix drift")
    elif sum(x["review_state"]=="candidate_reviewed_documentary" for x in sources)!=spec["documentary"]: raise ValueError(pid+" documentary source count drift")
    if any(x["id"] in existing_sources for x in sources): raise ValueError(pid+" globally namespaced source collision")
    source_map={x["id"]:x for x in sources}
    procedure_by_card={x["canonical_qa_id"]:x for x in procedures}
    if set(procedure_by_card)!={x["id"] for x in canonical} or any(x.get("execution_authority") is not False or x.get("verification_status")!="candidate_unverified_on_installed_logic" for x in procedures): raise ValueError(pid+" procedure boundary drift")
    expected_classes=spec.get("sourceClassCounts")
    if expected_classes and ({x["evidence_class"] for x in sources} - set(expected_classes) or {x["evidence_class"]:sum(y["evidence_class"]==x["evidence_class"] for y in sources) for x in sources} != expected_classes): raise ValueError(pid+" source class counts drift")
    mapping=readj(ROOT/"research/community_knowledge/disagreement_maps"/(pid+".json"))
    if set(mapping)!={"contradictions","myths"}: raise ValueError(pid+" disagreement map shape drift")
    by_card={x["id"]:x for x in canonical}
    def mapped(rows, key, cap):
        values=mapping[key]
        targets={identifier:(value["canonicalID"] if isinstance(value,dict) else value) for identifier,value in values.items()}
        if set(values)!={x["id"] for x in rows} or not set(targets.values()) <= set(by_card): raise ValueError(pid+" disagreement map coverage drift")
        buckets={identifier:[] for identifier in by_card}
        for row in rows:
            target=targets[row["id"]]
            if spec["directSemanticMap"]:
                detail=values[row["id"]]
                rationale=detail.get("rationale") if isinstance(detail,dict) else None
                record_specific=row.get("topic") if key=="contradictions" else row.get("myth")
                required="Direct semantic attachment:" if spec.get("recordSpecificRationale") else "Direct semantic attachment"
                if not isinstance(detail,dict) or detail.get("topicCompatibility") != by_card[target]["topic"] or not isinstance(rationale,str) or not rationale.startswith(required) or (spec.get("recordSpecificRationale") and (not isinstance(record_specific,str) or record_specific not in rationale)): raise ValueError(pid+" disagreement topic/rationale drift: "+row["id"])
                if spec.get("disagreementSelectionBasis") and detail.get("selectionBasis") not in {"source_provenance_plus_topic_terms","source_provenance_with_explicit_low_lexical_margin","semantic_topic_without_card_source_overlap","semantic_topic_capacity_preserving_alternate"}: raise ValueError(pid+" disagreement selection basis drift: "+row["id"])
                if any(identifier not in source_map for identifier in row["source_ids"]): raise ValueError(pid+" disagreement provenance source drift: "+row["id"])
                item=contradiction(row,True) if key=="contradictions" else myth(row,True)
                item["sourceIDs"]=sorted(row["source_ids"]); item["sourceEvidenceClasses"]=sorted({source_map[x]["evidence_class"] for x in row["source_ids"]})
            else:
                if not set(row["source_ids"]) & set(by_card[target]["source_ids"]): raise ValueError(pid+" disagreement map source intersection drift: "+row["id"])
                item=contradiction(row,True) if key=="contradictions" else myth(row,True)
            buckets[target].append(item)
        if any(len(v)>cap for v in buckets.values()): raise ValueError(pid+" disagreement per-kind cap drift")
        return buckets
    cattach=mapped(contr,"contradictions",spec["contradictionCap"]); mattach=mapped(myths,"myths",spec["mythCap"])
    if any(len(cattach[k])+len(mattach[k])>spec["combinedCap"] for k in by_card): raise ValueError(pid+" disagreement combined cap drift")
    stable_data={"canonical_qa":canonical,"user_utterances":utter,"contradictions":contr,"myths_and_antipatterns":myths,"sources":sources,"strategy_candidates":strategies,"logic_procedure_candidates":procedures}
    runtime=stable_runtime_projection(pid,manifest,md,stable_data,mapping)
    assert_runtime_safe(runtime)
    def exact_ids(rows):
        out={}
        for row in rows: out.setdefault(normalized_runtime_identity(row["text"]),set()).add(row["canonical_qa_id"] if "canonical_qa_id" in row else row["canonicalID"])
        return {k:sorted(v) for k,v in out.items()}
    raw=exact_ids(utter); safe=exact_ids(runtime["utterances"])
    raw_matches=[x["id"] for x in retrieval if raw.get(normalized_runtime_identity(x["query"]),[])==x["expected_canonical_ids"]]; safe_matches=[x["id"] for x in retrieval if safe.get(normalized_runtime_identity(x["query"]),[])==x["expected_canonical_ids"]]
    classifications=None
    if spec.get("classifiedRetrievalTests"):
        classifications=classified_fixture_accounting(tests,{card["id"] for card in canonical},spec)
        if spec.get("fixtureMode") != "exact_subset":
            # Earlier packages retain their historical classified-fixture accounting.
            raw_matches=[row["id"] for row in tests if row.get("classification",row.get("retrieval_classification"))=="exact_unique"]
            safe_matches=[]
    if spec.get("fixtureMode") == "exact_subset":
        lexical_by_class={kind:sum(row.get("retrieval_classification")==kind and row["id"] in raw_matches for row in retrieval) for kind in spec["retrievalTypes"]}
        evaluation_classifications={kind:sum(row.get("retrieval_classification")==kind for row in retrieval) for kind in spec["retrievalTypes"]}
        if len(raw_matches)!=spec["rawNormalizedUniqueMatchCount"] or len(retrieval)-len(raw_matches)!=spec["rawNormalizedNonMatchCount"] or lexical_by_class!=spec["diagnosticNormalizedExactByClassification"]:
            raise ValueError(pid+" raw normalized lexical accounting drift")
        if evaluation_classifications!=spec["retrievalTypes"]:
            raise ValueError(pid+" retrieval classification accounting drift")
        if lexical_by_class["diagnostic_semantic_only"]!=spec["diagnosticNormalizedExactCollisionCount"] or sum(lexical_by_class[kind] for kind in lexical_by_class if kind!="exact_unique")!=spec["diagnosticNormalizedExactCollisionCount"]:
            raise ValueError(pid+" diagnostic lexical collision accounting drift")
        if len(safe_matches)!=spec["runtimeNormalizedUniqueMatchCount"] or len(retrieval)-len(safe_matches)!=spec["runtimeNormalizedNonMatchCount"]:
            raise ValueError(pid+" runtime normalized lexical accounting drift")
        accounting={"classifiedExpectedTop1Count":spec["classifiedExpectedTop1Count"],"classifiedDiagnosticOnlyCount":spec["classifiedDiagnosticOnlyCount"],"classificationCounts":evaluation_classifications,"rawNormalizedUniqueMatchCount":len(raw_matches),"rawNormalizedNonMatchCount":len(retrieval)-len(raw_matches),"diagnosticNormalizedExactCollisionCount":spec["diagnosticNormalizedExactCollisionCount"],"diagnosticNormalizedExactByClassification":lexical_by_class,"runtimeNormalizedUniqueMatchCount":len(safe_matches),"runtimeNormalizedNonMatchCount":len(retrieval)-len(safe_matches),"runtimeCarriesNoTestUtterances":True}
    else:
        if len(raw_matches)!=spec["rawExactCount"] or len(retrieval)-len(raw_matches)!=spec["rawNonExactCount"]: raise ValueError(pid+" raw exact accounting drift")
        if "runtimeExactCount" in spec and (len(safe_matches)!=spec["runtimeExactCount"] or len(retrieval)-len(safe_matches)!=spec["runtimeNonExactCount"]): raise ValueError(pid+" runtime-safe exact accounting drift")
        accounting={"rawPackageUniqueExactCaseCount":len(raw_matches),"rawPackageNonExactLexicalCaseCount":len(retrieval)-len(raw_matches),"runtimeSafeUniqueExactCaseCount":len(safe_matches),"runtimeSafeNonExactLexicalCaseCount":len(retrieval)-len(safe_matches),"safetyRedactedExactFixtureIDs":sorted(set(raw_matches)-set(safe_matches))}
        if classifications is not None: accounting.update({"classificationCounts":classifications,"runtimeCarriesNoTestUtterances":True})
    evaluation={"packageID":pid,"scenarios":scenarios,"retrievalCases":retrieval,"retrievalTests":tests,"integrityCases":integrity,"retrievalAccounting":accounting}
    candidates=[]
    for kind, rows in (("claim",claims),("strategy",strategies),("procedure",procedures)):
        if len(rows)!=spec["canonical"]: raise ValueError(pid+" candidate count drift")
        for row in rows:
            ids=row["source_ids"]; provenance=stable_parts(ids,source_map,spec["includePrimaryResearch"]); base={"id":row["id"],"candidateKind":kind,"canonicalQAID":row["canonical_qa_id"],"sourceID":ids[0],"sourceIDs":sorted(ids),**provenance,"originalReviewStatus":row["review_state"],"reviewState":"awaitingReview","reviewer":None,"reviewedAt":None,"reviewNote":None,"dependsOnAudiovisual":False,"discoveryOnly":False,"candidatePayload":row,"candidateCorpus":pid,"userPerformsEveryAction":True}
            if spec.get("observedStatusContract"): base.update({"nativeReviewStatus":row["native_review_state"],"originalReviewStatus":row["original_review_state"],"originalVerificationStatus":row["original_verification_status"],"logicVerificationStatus":row["logic_verification_status"],"runtimeEligibility":row["runtime_eligibility"]})
            # P10 carries original verification and installed-Logic
            # verification as distinct immutable fields.  Preserve both rather
            # than collapsing the original candidate provenance into the Logic
            # status used by legacy packages.
            if kind=="procedure" and not spec.get("observedStatusContract"): base["originalVerificationStatus"]=row["verification_status"]
            candidates.append(merge_review_event(base,existing_candidates.get(row["id"])))
    registry_entries=[]
    for row in sources:
        handling="openDocumentation" if stable_source_tier(row) in {"A","R"} else "publicWebMetadataOnly"
        if spec.get("sourceHandlingByAccessContract"):
            # Access policy governs handling before provenance tier: only the
            # declared public official documentation is open documentation.
            handling="openDocumentation" if row["evidence_class"]=="official_documentation" and row["access_mode"]=="permittedPublicHTML" else "publicWebMetadataOnly"
        entry={"id":row["id"],"type":row["access_mode"],"title":row["title"],"creatorOrPublisher":row["publisher_or_community"],"locator":row["canonical_url"],"publicationDate":None,"retrievalDate":row.get("retrieved_at"),"exactVersion":row["version_scope"],"rightsBasis":"Candidate corpus metadata and paraphrased synthesis; source body is not redistributed.","handlingClass":handling,"tier":TIERS["A" if stable_source_tier(row)=="R" else stable_source_tier(row)],"transcriptAvailable":False,"transcriptIsAutomatic":False,"requiresAudiovisualReview":False,"audiovisualReviewCompleted":False,"contentSHA256":[],"limitations":row["limitations"],"supersededBy":None,"reviewState":"acquired","candidateCorpus":pid,"originalEvidenceClass":row["evidence_class"],"originalReviewStatus":row["review_state"],"originalAccessMode":row["access_mode"],"originalVersionScope":row["version_scope"],"originalSourceID":row["id"]}
        if spec.get("observedStatusContract"): entry.update({"nativeReviewStatus":row["native_review_state"],"originalReviewStatus":row["original_review_state"],"originalVerificationStatus":row["original_verification_status"],"logicVerificationStatus":row["logic_verification_status"],"runtimeEligibility":row["runtime_eligibility"]})
        registry_entries.append(entry)
    if spec.get("sourceHandlingByAccessContract") and spec.get("includePrimaryResearch"):
        primary=[entry for entry in registry_entries if entry["originalEvidenceClass"]=="primary_research"]
        if len(primary)!=2 or any(entry["type"]!="searchDiscoveryOnly" or entry["originalReviewStatus"]!="candidate_reviewed_primary_research" or entry["handlingClass"]!="publicWebMetadataOnly" for entry in primary):
            raise ValueError(pid+" primary-research metadata-only handling drift")
    return runtime,evaluation,registry_entries,candidates,manifest
def build(pid, existing_sources, existing_candidates):
    if pid in STABLE_CONTRACT_SPECS: return stable_contract_build(pid, existing_sources, existing_candidates)
    p=K/pid; cfg=PACKAGES[pid]; md, manifest=package_digest(p)
    canonical=lines(p/"corpus/canonical_qa.jsonl"); utter=lines(p/"corpus/user_utterances.jsonl"); scenarios=lines(p/"corpus/multiturn_scenarios.jsonl"); retrieval=lines(p/"corpus/retrieval_evaluation.jsonl") if (p/"corpus/retrieval_evaluation.jsonl").exists() else []; evaluations=lines(p/"corpus/evaluation_cases.jsonl") if (p/"corpus/evaluation_cases.jsonl").exists() else []; contr=lines(p/"research/contradictions.jsonl"); myths=lines(p/"research/myths_and_antipatterns.jsonl") if (p/"research/myths_and_antipatterns.jsonl").exists() else []
    sources=lines(p/"research/source_registry.jsonl"); claims=lines(p/"integration/tracksmith_claim_candidates.jsonl"); strategies=lines(p/"integration/tracksmith_strategy_candidates.jsonl"); procedures=lines(p/"integration/logic_procedure_candidates.jsonl")
    if (len(canonical),len(utter),len(scenarios),len(contr),len(myths),len(sources)) != tuple(cfg[x] for x in ("canonical","utterances","scenarios","contradictions","myths","sources")): raise ValueError(pid+": package count drift")
    if any(x.get("review_status")!="candidate_not_yet_human_reviewed" for x in canonical): raise ValueError(pid+": canonical status drift")
    if pid == "community-compression-arrangement-frequency-allocation-v1":
        if len(evaluations)!=cfg["evaluations"] or {x.get("kind") for x in evaluations}!={"retrieval","paraphrase","clarification","tradeoff","myth_resistance"}: raise ValueError(pid+": mixed evaluation shape drift")
        p3_rows=utter+scenarios+evaluations+contr+myths
        if any(x.get("package_sequence")!=3 or x.get("review_status")!="candidate_not_yet_human_reviewed" for x in p3_rows): raise ValueError(pid+": row provenance drift")
        overlap={x["source_id"] for x in sources} & set(existing_sources)
        if overlap != P3_SOURCE_COLLISIONS: raise ValueError("package-3 collision-map drift: "+repr(sorted(overlap)))
    if pid == "community-reverb-delay-v1":
        if len(retrieval)!=cfg["retrieval"] or any(x.get("package_sequence")!=4 for x in retrieval+scenarios) or {x.get("review_status") for x in retrieval}!={"synthetic_retrieval_evaluation"} or {x.get("review_status") for x in scenarios}!={"synthetic_multiturn_evaluation"}: raise ValueError(pid+": evaluation/scenario provenance drift")
        if {x.get("domain") for x in canonical}!={"reverb","delay"} or sum(x.get("domain")=="reverb" for x in canonical)!=160: raise ValueError(pid+": canonical domain inventory drift")
        if any(x.get("package_sequence")!=4 or x.get("review_status")!="candidate_not_yet_human_reviewed" for x in canonical+contr+myths): raise ValueError(pid+": row provenance drift")
        overlap={x["source_id"] for x in sources} & set(existing_sources)
        if overlap != P4_SOURCE_COLLISIONS: raise ValueError("package-4 collision-map drift: "+repr(sorted(overlap)))
    sm={}
    for row in sources:
        if row["source_id"] in sm: raise ValueError("duplicate package source")
        native=package_source_id(pid,row["source_id"],existing_sources); sm[row["source_id"]]={**row,"native":native}
    cards=[]
    for x in canonical:
        safe_runtime=pid.endswith("frequency-allocation-v1") or pid=="community-reverb-delay-v1"; card={"id":x["id"],"packageID":pid,"version":manifest.get("version",manifest.get("package_version")),"domain":x["domain"],"category":x["category"],"title":x["title"],"question":x["canonical_user_question"],"originalReviewStatus":x["review_status"],"sourceTypes":sorted({sm[s]["source_type"] for s in x.get("source_ids",[]) if s in sm}),"evidenceClass":x.get("evidence_class","community_candidate"),"logicVersion":x.get("logic_version_scope"),"currentContext":x.get("requires_mix_context",False),"tags":x.get("tags",[]),"clarificationQuestions":[clean(v,safe_runtime) for v in x.get("clarification_questions",[])],"competingHypotheses":[clean(h.get("label","")+": "+h.get("mechanism", ""),safe_runtime) for h in x.get("candidate_hypotheses",[])],"recommendedFirstExperiment":clean(x["recommended_first_experiment"]["summary"],safe_runtime),"rationale":clean(x.get("rationale",""),safe_runtime),"listeningCues":[clean(v,safe_runtime) for v in x.get("what_to_listen_for",[])],"stopOrUndo":[clean(x.get("stop_rule",""),safe_runtime),clean(x.get("undo_or_reset",""),safe_runtime)],"tradeoffs":[clean(v,safe_runtime) for v in x.get("tradeoffs_and_risks",[])],"teachingPrinciple":clean(x.get("teaching_principle",""),safe_runtime),"numericGuidancePolicy":x.get("numeric_guidance_policy","starting_point_not_preset"),"_source_ids":x.get("source_ids",[])}
        if pid == "community-compression-arrangement-frequency-allocation-v1":
            card["title"]=clean(card["title"],True); card["question"]=clean(card["question"],True); card["tags"]=[clean(v,True) for v in card["tags"]]
            card.update({"packageSequence":3,"subcategory":x.get("subcategory"),"tracksmithDomains":x.get("tracksmith_domains",[]),"preservationGoals":[clean(v,True) for v in x.get("preservation_goals",[])],"nonDSPPossibilities":[clean(v,True) for v in x.get("non_dsp_possibilities",[])],"startingPoints":[clean(v,True) for v in x.get("starting_points",[])],"commonMistakes":[clean(v,True) for v in x.get("common_mistakes",[])],"rawCommunityDisagreementIDs":x.get("community_disagreement_ids",[]),"roleFacets":role_facets(x),"sectionFacets":section_facets(x)})
        elif pid == "community-reverb-delay-v1":
            card["title"]=clean(card["title"],True); card["question"]=clean(card["question"],True); card["tags"]=[clean(v,True) for v in card["tags"]]
        card.update(parts(card["_source_ids"],sm)); cards.append(card)
    if pid == "community-vocal-quantization-v1": cattach=p1_attachments(canonical,contr)
    elif pid == "community-reverb-delay-v1": cattach=p4_anchored(contr,cards,P4_CONTRADICTION_ANCHORS,lambda row: contradiction(row,True),3)
    else: cattach=anchored(contr,cards,P3_CONTRADICTION_ANCHORS if pid.endswith("frequency-allocation-v1") else P2_CONTRADICTION_ANCHORS,lambda row: contradiction(row,pid.endswith("frequency-allocation-v1")),3)
    if not myths: mattach={x["id"]:[] for x in cards}
    elif pid == "community-reverb-delay-v1": mattach=p4_anchored(myths,cards,P4_MYTH_ANCHORS,lambda row: myth(row,True),2)
    else: mattach=anchored(myths,cards,P3_MYTH_ANCHORS if pid.endswith("frequency-allocation-v1") else P2_MYTH_ANCHORS,lambda row: myth(row,pid.endswith("frequency-allocation-v1")),2)
    for card in cards:
        card["contradictions"]=cattach[card["id"]]; card["myths"]=mattach[card["id"]]; card.pop("_source_ids")
    if pid == "community-compression-arrangement-frequency-allocation-v1":
        known={x["id"] for x in contr}
        if any(not set(card["rawCommunityDisagreementIDs"]) <= known for card in cards): raise ValueError("package-3 raw disagreement reference drift")
    runtime={"schemaVersion":"2.0","packageID":pid,"packageManifestSHA256":md,"metadata":{"domains":sorted({x["domain"] for x in cards}),"retrievalMode":"lexical_structured_provisional"},"canonicalCards":sorted(cards,key=lambda x:x["id"]),"utterances":sorted([{"id":x.get("utterance_id",x.get("id")),"canonicalID":x["canonical_id"],"text":clean_utterance(x["text"],x["canonical_id"]) if safe_runtime else x["text"],"originalReviewStatus":x.get("review_status","")} for x in utter],key=lambda x:x["id"]),"contradictions":sorted([contradiction(x,safe_runtime) for x in contr],key=lambda x:x["id"]),"myths":sorted([myth(x,safe_runtime) for x in myths],key=lambda x:x["id"])}
    if pid.endswith("frequency-allocation-v1"):
        raw_counts={}; safe_counts={}
        for source,projected in zip(utter,runtime["utterances"]):
            raw_counts[source["text"].strip().lower()]=raw_counts.get(source["text"].strip().lower(),0)+1; safe_counts[projected["text"].strip().lower()]=safe_counts.get(projected["text"].strip().lower(),0)+1
        if any(count > raw_counts.get(text,0) for text,count in safe_counts.items()): raise ValueError("package-3 sanitization introduced duplicate utterance text")
    if pid == "community-vocal-quantization-v1":
        legacy=p1_legacy_projection(canonical,utter,scenarios,contr,sm,md)
        legacy_hash=digest(json.dumps(legacy,ensure_ascii=False,sort_keys=True,separators=(",",":" )).encode())
        if legacy_hash != P1_LEGACY_SHA256: raise ValueError("package-1 legacy core projection SHA-256 drift: "+legacy_hash)
        runtime["legacyCoreProjectionSHA256"]=legacy_hash
    # P1/P2 artifacts are hash-preserved migrations. P3/P4 are the applicable
    # runtime projections that require recursive procedure/navigation leak scans.
    if safe_runtime: assert_runtime_safe(runtime)
    # Evaluation fixtures intentionally retain all scenario/retrieval fields but
    # never ship in the provider bundle.
    evaluation={"packageID":pid,"scenarios":scenarios,"retrievalCases":retrieval,"evaluationCases":evaluations} if evaluations else {"packageID":pid,"scenarios":scenarios,"retrievalCases":retrieval}
    if pid == "community-reverb-delay-v1":
        def exact_ids(rows):
            values={}
            for row in rows: values.setdefault(normalized_runtime_identity(row["text"]),set()).add(row["canonical_id"] if "canonical_id" in row else row["canonicalID"])
            return {key:sorted(value) for key,value in values.items()}
        raw_exact=exact_ids(utter)
        runtime_exact=exact_ids(runtime["utterances"])
        raw_matches=[row["id"] for row in retrieval if raw_exact.get(normalized_runtime_identity(row["query"]),[]) == row["expected_canonical_ids"]]
        runtime_matches=[row["id"] for row in retrieval if runtime_exact.get(normalized_runtime_identity(row["query"]),[]) == row["expected_canonical_ids"]]
        safety_redacted=sorted(set(raw_matches)-set(runtime_matches))
        if len(raw_matches) != 316 or len(runtime_matches) != 315 or safety_redacted != ["eval.delay.logic_pro_specific.logic_region_delay.1"]:
            raise ValueError(pid+": exact retrieval safety-accounting drift")
        evaluation["retrievalAccounting"]={"rawPackageUniqueExactCaseCount":316,"rawPackageNonExactLexicalCaseCount":1184,"runtimeSafeUniqueExactCaseCount":315,"runtimeSafeNonExactLexicalCaseCount":1185,"safetyRedactedExactFixtureIDs":safety_redacted}
    candidates=[]
    for kind, values in (("claim",claims),("strategy",strategies),("procedure",procedures)):
        if len(values)!=cfg["canonical"]: raise ValueError(pid+": candidate count drift")
        for x in values:
            original=(x.get("verificationState",x.get("review_status")) if kind=="procedure" and pid!="community-reverb-delay-v1" else x.get("reviewState",x.get("review_status")))
            verification=x.get("verification_status",x.get("verificationState")) if kind=="procedure" else None
            if original != cfg["original"][kind] or (kind=="procedure" and pid=="community-reverb-delay-v1" and verification != cfg["verification"]): raise ValueError(pid+": "+kind+" status drift")
            if kind=="procedure" and pid=="community-reverb-delay-v1" and (x.get("execution_authority") is not False or x.get("user_performs_every_action") is not True): raise ValueError(pid+": procedure authority drift")
            ids=x.get("sourceIDs",x.get("source_ids",x.get("supportingSourceIDs",[]))); qid=x.get("canonicalQAID",x.get("canonical_id")); ident=x["id"]
            payload=rewrite_package3_source_references(x,sm) if pid.endswith("frequency-allocation-v1") else (rewrite_package3_source_references(x,sm) if pid=="community-reverb-delay-v1" else x)
            generated={"id":ident,"candidateKind":kind,"canonicalQAID":qid,"sourceID":(parts(ids,sm)["authoritativeSupportingSourceIDs"] or parts(ids,sm)["professionalPracticeSourceIDs"] or parts(ids,sm)["discoveryLanguageSourceIDs"])[0],"sourceIDs":sorted(sum(parts(ids,sm).values(),[])),**parts(ids,sm),"originalReviewStatus":original,"reviewState":"awaitingReview","reviewer":None,"reviewedAt":None,"reviewNote":None,"dependsOnAudiovisual":False,"discoveryOnly":not bool(parts(ids,sm)["authoritativeSupportingSourceIDs"] or parts(ids,sm)["professionalPracticeSourceIDs"]),"candidatePayload":payload,"candidateCorpus":pid}
            if kind=="procedure" and pid=="community-reverb-delay-v1": generated["originalVerificationStatus"]=verification
            candidates.append(merge_review_event(generated,existing_candidates.get(ident)))
    return runtime,evaluation,[source_entry(pid,x,sm[x["source_id"]]["native"]) for x in sources],candidates, manifest
def descriptor(rows):
    blocks=[]
    for runtime, evals, _, _, manifest in rows:
        pid=runtime["packageID"]; data=canon(runtime).encode(); name=pid+".json"; cfg=PACKAGES[pid]
        p2=pid=="community-level-balancing-eq-v1"; p3=pid.endswith("frequency-allocation-v1"); p4=pid=="community-reverb-delay-v1"; stable=pid in STABLE_CONTRACT_SPECS
        sequence=STABLE_CONTRACT_SPECS[pid]["number"] if stable else (4 if p4 else (3 if p3 else (2 if p2 else 1)))
        legacy=f', legacyCoreProjectionSHA256: "{P1_LEGACY_SHA256}"' if pid=="community-vocal-quantization-v1" else ', legacyCoreProjectionSHA256: nil'
        version=manifest.get("version",manifest.get("package_version")); kinds=evals.get("evaluationCases",[]); kind_counts={k:sum(x.get("kind")==k for x in kinds) for k in sorted({x.get("kind") for x in kinds})}; swift_kind_counts="[:]" if not kind_counts else "["+", ".join(f'\"{k}\": {v}' for k,v in kind_counts.items())+"]"
        canonical_only=STABLE_CONTRACT_SPECS.get(pid,{}).get("canonicalOnlyRuntime",False)
        raw_utterances=STABLE_CONTRACT_SPECS[pid]["utterances"] if canonical_only else len(runtime["utterances"])
        raw_contradictions=STABLE_CONTRACT_SPECS[pid]["contradictions"] if canonical_only else len(runtime["contradictions"])
        raw_myths=STABLE_CONTRACT_SPECS[pid]["myths"] if canonical_only else len(runtime["myths"])
        # The descriptor capability follows the shared runtime projection
        # contract: status-free resources must also hide those labels at the
        # live candidate-tool boundary. P10/P11 lack this capability.
        status_free=STABLE_CONTRACT_SPECS.get(pid,{}).get("runtimeExcludeCardStatusKeys",False)
        blocks.append(f'CommunityCandidateCorpusPackageDescriptor(packageID: "{pid}", version: "{version}", packageSequence: {sequence}, domains: {json.dumps(runtime["metadata"]["domains"])}, resourceName: "{name}", resourceSHA256: "{digest(data)}", packageManifestSHA256: "{runtime["packageManifestSHA256"]}", canonicalCount: {len(runtime["canonicalCards"])}, utteranceCount: {raw_utterances}, contradictionCount: {raw_contradictions}, mythCount: {raw_myths}, scenarioCount: {len(evals["scenarios"])}, retrievalCaseCount: {len(evals["retrievalCases"])}, evaluationCaseCount: {len(kinds)}, evaluationKindCounts: {swift_kind_counts}, canonicalOriginalStatus: "candidate_not_yet_human_reviewed", utteranceOriginalStatus: {"\"candidate_not_yet_human_reviewed\"" if (p3 or p4 or stable) else ("\"synthetic_retrieval_language\"" if p2 else "nil")}, contradictionOriginalStatus: "candidate_not_yet_human_reviewed", mythOriginalStatus: {"\"candidate_not_yet_human_reviewed\"" if (p2 or p3 or p4 or stable) else "nil"}, claimOriginalStatus: "{cfg["original"]["claim"]}", strategyOriginalStatus: "{cfg["original"]["strategy"]}", procedureOriginalStatus: "{cfg["original"]["procedure"]}"{legacy}{", runtimeCanonicalOnly: true" if canonical_only else ""}{", runtimeStatusFree: true" if status_free else ""})')
    return "// Generated by research/scripts/community_corpus_import.py.\nimport Foundation\n\npublic enum CommunityCandidateCorpusGenerated {\n    public static let descriptors: [CommunityCandidateCorpusPackageDescriptor] = [\n        "+",\n        ".join(blocks)+"\n    ]\n}\n"
def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--check",action="store_true"); ap.add_argument("--package",choices=PACKAGES); ap.add_argument("--metadata-repair-self-check",action="store_true"); ap.add_argument("--preservation-self-check",action="store_true"); a=ap.parse_args()
    if a.metadata_repair_self_check:
        metadata_repair_self_check()
        print("COMMUNITY_CORPUS_METADATA_REPAIR_SELF_CHECK_OK")
        return 0
    if a.preservation_self_check:
        preservation_self_check()
        print("COMMUNITY_CORPUS_PRESERVATION_SELF_CHECK_OK")
        return 0
    verify_review_event_merge()
    global P10_PROVENANCE_REPAIR_COUNT
    P10_PROVENANCE_REPAIR_COUNT = 0
    verify_p6_preservation_baseline(); verify_p7_preservation_baseline(); verify_p8_preservation_baseline(); verify_p9_preservation_baseline(); verify_p10_preservation_baseline(); verify_p11_preservation_baseline(); verify_p12_preservation_baseline(); verify_p13_preservation_baseline(); verify_p14_preservation_baseline(); verify_p15_preservation_baseline()
    existing=readj(REGISTRY,{"sources":[]}); preserved={x["id"]:x for x in existing.get("sources",[]) if x.get("candidateCorpus") not in PACKAGES}
    loaded_queue=readj(QUEUE,{"candidates":[]}); imported_existing={x["id"]:x for x in loaded_queue.get("candidates",[]) if x.get("candidateCorpus") in PACKAGES}; rows=[]; built_by_pid={}; source_map=dict(preserved); queue_preserved={x["id"]:x for x in loaded_queue.get("candidates",[]) if x.get("candidateCorpus") not in PACKAGES}; candidates=dict(queue_preserved)
    for pid in PACKAGES:
        r=build(pid,source_map,imported_existing); rows.append(r)
        built_by_pid[pid]=r
        for x in r[2]:
            if x["id"] in source_map: raise ValueError("unexpected source collision: "+x["id"])
            source_map[x["id"]]=x
        generated_ids=[x["id"] for x in r[3]]
        if len(generated_ids) != len(set(generated_ids)) or any(identifier in candidates for identifier in generated_ids): raise ValueError("duplicate candidate ID across imported packages")
        candidates.update({x["id"]:x for x in r[3]})
    if P10_PROVENANCE_REPAIR_COUNT not in {0, 450}: raise ValueError("P10 provenance repair count drift: "+str(P10_PROVENANCE_REPAIR_COUNT))
    metadata_registry=readj(P10_PACKAGE_REGISTRY)
    p10_registry,p10_report,p10_metadata_repairs=p10_metadata_artifacts(metadata_registry)
    metadata_repairs=[]
    repaired_metadata={}
    for pid,spec in STABLE_CONTRACT_SPECS.items():
        if spec.get("metadataRepair"):
            generated=built_by_pid.get(pid)
            registry_value,report_value,repairs=metadata_repair_artifacts(pid,metadata_registry,runtime_value=generated[0] if generated else None,evaluation_value=generated[1] if generated else None)
            repaired_metadata[pid]=(registry_value,report_value)
            metadata_repairs.append(repairs)
    expected={REGISTRY:canon({"schemaVersion":"1.0","sources":[source_map[k] for k in sorted(source_map)]}),QUEUE:canon({"schemaVersion":"1.0","candidates":[candidates[k] for k in sorted(candidates)]}),DESCRIPTOR:descriptor(rows)}
    expected[P10_PACKAGE_REGISTRY]=stable_metadata_json(p10_registry)
    expected[P10_IMPORT_REPORT]=stable_metadata_json(p10_report)
    for pid,(registry_value,report_value) in repaired_metadata.items():
        expected[P10_PACKAGE_REGISTRY]=stable_metadata_json(registry_value)
        expected[ROOT/("research/community_knowledge/import_report_"+pid+".json")]=stable_metadata_json(report_value)
    for runtime, evaluation, _, _, _ in rows:
        expected[RES/(runtime["packageID"]+".json")]=canon(runtime); expected[EVAL/(runtime["packageID"]+"-evaluation.json")]=canon(evaluation)
    if a.check:
        drift=[str(p.relative_to(ROOT)) for p,t in expected.items() if not p.exists() or p.read_text()!=t]
        if drift: print("COMMUNITY_CORPUS_IMPORT_CHECK_FAILED: drift in "+", ".join(drift),file=sys.stderr); return 1
    else:
        for p,t in expected.items(): p.parent.mkdir(parents=True,exist_ok=True); p.write_text(t)
    verify_p6_preservation_baseline(); verify_p7_preservation_baseline(); verify_p8_preservation_baseline(); verify_p9_preservation_baseline(); verify_p10_preservation_baseline(enforce_p10_metadata=True); verify_p11_preservation_baseline(); verify_p12_preservation_baseline(); verify_p13_preservation_baseline(); verify_p14_preservation_baseline(); verify_p15_preservation_baseline()
    raw_count=lambda runtime,key: STABLE_CONTRACT_SPECS[runtime["packageID"]][key] if STABLE_CONTRACT_SPECS.get(runtime["packageID"],{}).get("canonicalOnlyRuntime") else len(runtime["utterances"] if key=="utterances" else runtime[key])
    totals={"canonical":sum(len(r[0]["canonicalCards"]) for r in rows),"utterances":sum(raw_count(r[0],"utterances") for r in rows),"runtimeUtterances":sum(len(r[0]["utterances"]) for r in rows),"scenarios":sum(len(r[1]["scenarios"]) for r in rows),"retrieval":sum(len(r[1]["retrievalCases"]) for r in rows),"evaluations":sum(len(r[1].get("evaluationCases",[])) for r in rows),"contradictions":sum(raw_count(r[0],"contradictions") for r in rows),"myths":sum(raw_count(r[0],"myths") for r in rows),"sources":len(source_map),"awaiting":sum(x.get("reviewState")=="awaitingReview" for x in candidates.values()),"trusted":sum(x.get("reviewState") in {"reviewed","directlyVerified"} for x in candidates.values())}
    print("COMMUNITY_CORPUS_IMPORT_CHECK_OK packages=%d canonical=%d utterances=%d runtimeUtterances=%d scenarios=%d retrievalCases=%d mixedEvaluationCases=%d contradictions=%d myths=%d sources=%d awaitingImportedCandidates=%d trustedImportedCandidates=%d p10ProvenanceRepairs=%d p10MetadataRepairs=%d metadataRepairs=%d" % (len(rows),totals["canonical"],totals["utterances"],totals["runtimeUtterances"],totals["scenarios"],totals["retrieval"],totals["evaluations"],totals["contradictions"],totals["myths"],totals["sources"],totals["awaiting"],totals["trusted"],P10_PROVENANCE_REPAIR_COUNT,p10_metadata_repairs,sum(metadata_repairs)))
    return 0
if __name__=="__main__":
    try: raise SystemExit(main())
    except (OSError,KeyError,ValueError,json.JSONDecodeError) as e: print("COMMUNITY_CORPUS_IMPORT_ERROR: "+str(e),file=sys.stderr); raise SystemExit(1)
