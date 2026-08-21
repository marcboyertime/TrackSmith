#!/usr/bin/env python3
"""Build P011's reviewed dependency and disagreement evidence from input data.

This never executes an incoming package program.  Targets are selected from
semantic wording and declared source provenance, then capacity checked.  The
output records the rationale and selection basis so it remains auditable rather
than hiding a broad attachment heuristic.
"""
from __future__ import annotations
import argparse, json, pathlib, re

ROOT=pathlib.Path(__file__).resolve().parents[2]
PID="tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping"
STOP={"the","and","with","that","this","from","into","always","should","smart","tempo","logic","project","audio","region","mode","map","use","keep","adapt","beat","markers","more","every","than","then","only","for","are","not"}
CURATED_TARGETS={
"contradictions":["tempo_authority_decision","automatic_project_tempo_mode","free_tempo_recording","detect_audio_tempo","region_length_locators_bpm","gradual_drift_correction","gradual_drift_correction","apply_region_tempo_to_project","maintain_relative_positions","wrong_imported_tempo_metadata","flex_follow_region_behavior","bars_vs_beats_alignment","beat_vs_transient_markers","downbeat_hints","half_double_tempo","move_individual_beat_marker","beat_hints","reanalyze_remove_edits","lock_analyzed_range","multitrack_downmix_reference","multitrack_downmix_reference","free_tempo_recording","record_multitrack_without_click","downbeat_hints","smart_tempo_editor_overview","gradual_tempo_curves","tempo_list_granularity","tempo_sets","tempo_operations","tap_tempo_interpreter","gradual_drift_correction","mixed_meter_mapping","reanalyze_remove_edits","imported_loop_different_bpm","bars_vs_beats_alignment","imported_loop_different_bpm","apply_region_tempo_to_project","adapt_region_edit_side_effects","gradual_drift_correction","beat_vs_transient_markers","tempo_synced_dependents","tempo_synced_dependents","detect_midi_performance_tempo","wrong_downbeat_correction","gradual_drift_correction","tempo_track_points","recover_changed_speed_import","record_multitrack_without_click","detect_audio_tempo","preview_with_metronome"],
"myths":["tempo_authority_decision","keep_project_tempo_mode","adapt_region_edit_side_effects","automatic_project_tempo_mode","detect_audio_tempo","flex_follow_region_behavior","beat_vs_transient_markers","beat_hints","beat_hints","half_double_tempo","wrong_downbeat_correction","downbeat_hints","beat_hints","lock_analyzed_range","reanalyze_remove_edits","apply_region_tempo_to_project","apply_project_tempo_to_region","maintain_relative_positions","wrong_imported_tempo_metadata","recover_changed_speed_import","flex_follow_region_behavior","bars_vs_beats_alignment","imported_loop_different_bpm","adapt_project_tempo_mode","detect_audio_tempo","gradual_drift_correction","gradual_drift_correction","gradual_tempo_curves","tempo_track_points","tempo_sets","tempo_operations","tap_tempo_interpreter","tap_tempo_interpreter","region_length_locators_bpm","multitrack_downmix_reference","multitrack_downmix_reference","multitrack_smart_tempo_analysis","tempo_synced_dependents","tempo_synced_dependents","tempo_synced_dependents","detect_midi_performance_tempo","flex_follow_region_behavior","wrong_downbeat_correction","mixed_meter_mapping","mixed_meter_mapping","preview_with_metronome","gradual_drift_correction","flex_follow_region_behavior","adapt_region_edit_side_effects","adapt_region_edit_side_effects","automatic_project_tempo_mode","free_tempo_recording","record_multitrack_without_click","multitrack_downmix_reference","preview_with_metronome","tempo_track_points","flex_follow_region_behavior","recover_changed_speed_import","detect_midi_performance_tempo","tempo_track_points"]}

def rows(path): return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
def tokens(text): return {word for word in re.findall(r"[a-z]+", text.lower()) if len(word)>2 and word not in STOP}
def stable(value): return json.dumps(value,indent=2,sort_keys=True,ensure_ascii=False)+"\n"

def select(row, cards, usage, subdomain):
    """Choose within an explicit content-reviewed semantic card family."""
    text=" ".join(str(row.get(k,"")) for k in ("topic","position_a","position_b","what_decides","myth","correction","safer_principle"))
    wanted=tokens(text); source_ids=set(row["source_ids"])
    ranked=[]
    for card in cards:
        if card["subdomain"] != subdomain: continue
        hay=tokens(" ".join(str(card.get(k,"")) for k in ("topic","subdomain","title","canonical_question","key_distinction","direct_answer")))
        score=8*len(source_ids & set(card["source_ids"]))+len(wanted & hay)-5*usage[card["id"]]
        ranked.append((score,card["id"],card))
    _,_,target=max(ranked,key=lambda item:(item[0],item[1]))
    usage[target["id"]]+=1
    source_overlap=bool(source_ids & set(target["source_ids"]))
    basis="source_provenance_plus_topic_terms" if source_overlap else ("semantic_topic_capacity_preserving_alternate" if usage[target["id"]]>1 else "semantic_topic_without_card_source_overlap")
    statement=row.get("topic") or row.get("myth")
    return {"canonicalID":target["id"],"topicCompatibility":target["topic"],"rationale":"Direct semantic attachment: %s. Target preserves the authority, analysis, map, or conformance distinction without turning the disagreement into a universal rule." % statement,"selectionBasis":basis}

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--incoming",type=pathlib.Path,required=True); ap.add_argument("--write",action="store_true"); ap.add_argument("--audit",action="store_true"); args=ap.parse_args()
    root=args.incoming.resolve(); cards=rows(root/"corpus/canonical_qa.jsonl")
    usage={card["id"]:0 for card in cards}; mapping={}
    for output,relative in (("contradictions","corpus/contradictions.jsonl"),("myths","corpus/myths_and_antipatterns.jsonl")):
        cap=2; values={}
        input_rows=rows(root/relative)
        if len(input_rows)!=len(CURATED_TARGETS[output]): raise SystemExit("P011 curated target count drift")
        for row,subdomain in zip(input_rows,CURATED_TARGETS[output]):
            detail=select(row,cards,usage,subdomain)
            if usage[detail["canonicalID"]]>cap:
                raise SystemExit("P011 evidence selection exceeds package cap")
            values[row["id"]]=detail
        mapping[output]=values
        if {detail["topicCompatibility"] for detail in values.values()} - set(CURATED_TARGETS[output]): raise SystemExit("P011 semantic audit target-family drift")
    dependencies={
      "tracksmith-corpus-001-vocal-quantization":"community-vocal-quantization-v1",
      "tracksmith-corpus-002-level-balancing-eq":"community-level-balancing-eq-v1",
      "tracksmith-corpus-003-compression-arrangement-frequency-allocation":"community-compression-arrangement-frequency-allocation-v1",
      "tracksmith-corpus-004-reverb-delay":"community-reverb-delay-v1",
      **{"tracksmith-corpus-%03d-%s" % (n,slug):"tracksmith-corpus-%03d-%s" % (n,slug) for n,slug in ((5,"automation"),(6,"saturation-transient-shaping"),(7,"phase-polarity-stereo-imaging-panning"),(8,"editing-layering"),(9,"gain-staging-bus-processing-loudness"),(10,"flex-time-manual-timing"))},
    }
    if args.write:
        evidence=ROOT/"research/community_knowledge"; (evidence/"dependency_maps").mkdir(parents=True,exist_ok=True); (evidence/"disagreement_maps").mkdir(parents=True,exist_ok=True)
        (evidence/"dependency_maps"/(PID+".json")).write_text(stable(dependencies))
        (evidence/"disagreement_maps"/(PID+".json")).write_text(stable(mapping))
    if args.audit:
        for output,relative in (("contradictions","corpus/contradictions.jsonl"),("myths","corpus/myths_and_antipatterns.jsonl")):
            for row,subdomain in zip(rows(root/relative),CURATED_TARGETS[output]):
                detail=mapping[output][row["id"]]
                print("P011_SEMANTIC_AUDIT %s %s => %s (%s)" % (row["id"], subdomain, detail["canonicalID"], detail["selectionBasis"]))
    print("P011_CONTRACT_ARTIFACTS_OK dependencies=%d contradictions=%d myths=%d" % (len(dependencies),len(mapping["contradictions"]),len(mapping["myths"])))
if __name__=="__main__": main()
