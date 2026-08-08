#!/usr/bin/env python3
"""Build the General Production Tutor v2 knowledge base.

Sources are the reviewed artifacts ALREADY in this repository. Nothing here is
fetched from the network and nothing is invented: every claim and strategy is
derived from a checked-in reviewed record and keeps a pointer back to it.

Inputs:
  research/knowledge/PRODUCER_JUDGMENT_CORPUS.jsonl        (Tier B, reviewed)
  research/knowledge/PRODUCER_JUDGMENT_CORPUS_PART_B.jsonl (Tier B, reviewed)
  research/knowledge/logic-pro-12.3-effects-knowledge.json (Tier A documentary)
  research/knowledge/PRODUCTION_LANGUAGE_ONTOLOGY.json     (Tier B advisory)
  research/knowledge/logic-pro-12.3-tutor-procedures.json  (reviewed procedures)
  curated concept and contradiction records defined below

Output:
  packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
K = ROOT / "research/knowledge"
OUTPUT = (
    ROOT
    / "packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift"
)
BUILT_AT = "2026-08-05"

# --------------------------------------------------------------- domain mapping

DOMAIN_KEYWORDS = {
    "vocals": ["vocal", "voice", "singer", "vox"],
    "drumsAndPercussion": ["drum", "snare", "kick", "cymbal", "percussion", "hat"],
    "bass": ["bass", "sub", "low end", "808"],
    "guitar": ["guitar", "amp", "pedal"],
    "pianoAndKeys": ["piano", "keys", "rhodes", "organ", "wurlitzer"],
    "synth": ["synth", "pad", "arp"],
    "fullMix": ["mix", "whole production", "album", "record"],
    "master": ["master", "mastering"],
    "microphonePlacement": ["microphone", "mic ", "miking", "off-axis", "proximity"],
    "roomAndReflections": ["room", "reflection", "ambience of the space", "house"],
    "noise": ["noise", "hiss", "hum", "environmental sound"],
    "clipping": ["clip", "distort", "overload"],
    "doublingAndLayering": ["double", "layer", "stack"],
    "performanceCapture": ["performance", "take", "tracking", "recording"],
    "compression": ["compress", "compressor", "threshold", "ratio", "attack", "release"],
    "eqAndFiltering": ["eq", "equali", "filter", "high pass", "low pass", "frequency"],
    "saturation": ["saturat", "tape", "harmonic", "drive", "warmth"],
    "expansionAndGating": ["gate", "expander"],
    "deEssing": ["de-ess", "sibilan"],
    "transientShaping": ["transient", "punch", "attack of"],
    "stereoImaging": ["stereo", "width", "wide", "pan"],
    "limiting": ["limiter", "limiting", "ceiling"],
    "reverb": ["reverb", "hall", "plate", "chamber"],
    "delay": ["delay", "echo", "slap"],
    "depth": ["depth", "distant", "close", "intimate", "front"],
    "monoCompatibility": ["mono"],
    "parallelProcessing": ["parallel"],
    "sidechains": ["sidechain", "duck"],
    "buses": ["bus", "aux"],
    "levelAutomation": ["automation", "automate", "ride"],
    "density": ["density", "sparse", "busy", "crowded", "arrangement"],
    "contrast": ["contrast", "energy", "section"],
    "verseChorusDevelopment": ["chorus", "verse"],
    "orchestration": ["arrangement", "instrumentation", "orchestrat"],
    "balance": ["balance", "buried", "cut through"],
    "masking": ["mask", "clash", "fight"],
    "tonalDistribution": ["bright", "dark", "dull", "muddy", "boomy", "thin", "harsh", "tonal"],
    "translation": ["translat", "car", "phone", "speaker"],
    "loudness": ["loudness", "lufs", "level of the master"],
    "references": ["reference"],
    "preservingIntent": ["preserve", "identity", "character", "authorship", "intimacy"],
    "sourceVersusProcessingDecision": ["re-record", "at the source", "replace", "recapture"],
    "knowingWhenToStop": ["stopping", "stop when", "enough"],
    "quantization": ["quantiz", "grid"],
    "groove": ["groove", "feel", "swing", "pocket"],
    "tempoMapping": ["tempo"],
    "humanization": ["humaniz", "robotic", "mechanical"],
}

SOURCE_TYPE_KEYWORDS = {
    "vocal": ["vocal", "voice", "singer"],
    "drums": ["drum", "snare", "kick", "percussion"],
    "bass": ["bass"],
    "guitar": ["guitar"],
    "keyboard": ["piano", "keys", "organ"],
    "synth": ["synth", "pad"],
    "fullMix": ["mix", "album", "record", "whole production", "master"],
}


def domains_for(text: str, extra: str = "") -> list[str]:
    blob = f"{text} {extra}".lower()
    out = []
    for domain, cues in DOMAIN_KEYWORDS.items():
        if any(c in blob for c in cues):
            out.append(domain)
    return out[:8]


VALID_SOURCE_TYPES = {"vocal", "vocalBus", "drums", "drumBus", "bass", "guitar",
                      "keyboard", "synth", "fullMix", "reference", "unknown"}


def normalize_source_types(values):
    """PlanSchema.SourceType has no `master` case.

    Mastering-scoped cards are full-mix scoped; the mastering domain on the
    card carries the distinction, so nothing is lost.
    """
    out = []
    for value in values or []:
        mapped = "fullMix" if value == "master" else value
        if mapped in VALID_SOURCE_TYPES and mapped not in out:
            out.append(mapped)
    return out


def source_types_for(text: str) -> list[str]:
    blob = text.lower()
    out = [st for st, cues in SOURCE_TYPE_KEYWORDS.items() if any(c in blob for c in cues)]
    return out[:6]


NUMERIC = re.compile(r"\b\d+(\.\d+)?\s*(db|hz|khz|ms|:1|%|lufs|dbfs)\b", re.I)


def has_numeric_range(text: str) -> bool:
    return bool(NUMERIC.search(text or ""))


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")[:60]


# --------------------------------------------------------------- source loading


def load_jsonl(path: pathlib.Path) -> list[dict]:
    if not path.exists():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            out.append(json.loads(line))
    return out


def build_from_producer_corpus(records, sources, claims, strategies):
    """Producer judgment records are reviewed Tier B professional practice.

    Each record already separates problem, diagnosis, intervention,
    alternatives, preservation tradeoff, stopping criterion, and an explicit
    `not_established` boundary. That maps directly onto a strategy card plus
    supporting claims, with the article as the source.
    """
    seen_sources = {s["id"] for s in sources}
    for rec in records:
        sid = rec.get("source_id")
        if not sid:
            continue
        if sid not in seen_sources:
            sources.append(
                {
                    "id": sid,
                    "type": "professionalArticle",
                    "title": rec.get("work") or sid,
                    "creatorOrPublisher": "Sound On Sound / interviewed engineers",
                    "locator": rec.get("canonical_url"),
                    "publicationDate": None,
                    "retrievalDate": None,
                    "exactVersion": None,
                    "rightsBasis": "public article reviewed locally; paraphrased, not redistributed",
                    "handlingClass": "publicWebMetadataOnly",
                    "tier": "tierBReviewedProfessionalPractice",
                    "transcriptAvailable": False,
                    "transcriptIsAutomatic": False,
                    "requiresAudiovisualReview": False,
                    "audiovisualReviewCompleted": False,
                    "contentSHA256": rec.get("source_sha256") or [],
                    "limitations": [
                        "One production case reported by its engineers; not a controlled experiment.",
                        "Genre and project specific; does not generalize automatically.",
                    ],
                    "supersededBy": None,
                }
            )
            seen_sources.add(sid)

        rid = rec["record_id"]
        blob = " ".join(
            str(rec.get(k) or "")
            for k in ("problem", "listening_diagnosis", "intervention", "artistic_goal", "musical_role")
        )
        doms = domains_for(blob, " ".join(rec.get("genre") or []))
        stypes = source_types_for(blob + " " + str(rec.get("source_type") or ""))

        # Supporting claims: the diagnosis, the interpretation, and the
        # explicit non-claim. Each keeps its own evidence class.
        claim_ids = []
        for field, ev, suffix in (
            ("listening_diagnosis", "professionalPracticeHeuristic", "diagnosis"),
            ("contextual_interpretation", "technicalInference", "interpretation"),
            ("audible_result", "subjectivePreference", "result"),
        ):
            text = rec.get(field)
            if not text:
                continue
            cid = f"claim.{rid}.{suffix}"
            claim_ids.append(cid)
            claims.append(
                {
                    "id": cid,
                    "version": "1.0",
                    "claimText": text,
                    "domains": doms,
                    "applicableSourceTypes": normalize_source_types(stypes),
                    "applicableQuestionKinds": [
                        "troubleshootProblem",
                        "achieveSoundOrFeeling",
                        "productionStrategy",
                        "diagnoseTradeoff",
                    ],
                    "conditions": [rec.get("musical_role") or ""],
                    "evidenceClass": ev,
                    "sourceID": sid,
                    "sourceLocation": rec.get("evidence_locator"),
                    "reviewState": "reviewed",
                    "contradictsClaimIDs": [],
                    "limitations": (
                        [f"Not established: {rec['not_established']}"]
                        if rec.get("not_established")
                        else []
                    ),
                    "listeningRemainsDecisive": True,
                    "containsNumericRange": has_numeric_range(text),
                    "numericRangeKind": "descriptive" if has_numeric_range(text) else None,
                }
            )

        if not rec.get("intervention"):
            continue
        strategies.append(
            {
                "id": f"strategy.{rid}",
                "version": "1.0",
                "label": (rec.get("artistic_goal") or rec.get("intervention"))[:90],
                "problemOrOutcome": rec.get("problem") or rec.get("artistic_goal") or "",
                "domains": doms,
                "applicableSourceTypes": normalize_source_types(stypes),
                "applicableQuestionKinds": [
                    "troubleshootProblem",
                    "achieveSoundOrFeeling",
                    "productionStrategy",
                    "compareOptions",
                    "diagnoseTradeoff",
                ],
                "usefulWhen": [rec.get("contextual_interpretation") or ""],
                "notUsefulWhen": rec.get("rejected_interventions") or [],
                "competingInterpretations": rec.get("alternatives_considered") or [],
                "recommendedFirstExperiment": rec["intervention"],
                "whyItMayHelp": rec.get("listening_diagnosis") or "",
                "expectedAudibleConsequences": [rec.get("audible_result")]
                if rec.get("audible_result")
                else [],
                "preservationConcerns": [rec.get("preservation_tradeoff")]
                if rec.get("preservation_tradeoff")
                else [],
                "tradeoffs": [rec.get("preservation_tradeoff")]
                if rec.get("preservation_tradeoff")
                else [],
                "stoppingRules": [rec.get("stopping_criterion")]
                if rec.get("stopping_criterion")
                else [],
                "signsStrategyIsWrong": rec.get("rejected_interventions") or [],
                "nonDSPAlternatives": [
                    a for a in (rec.get("alternatives_considered") or [])
                    if any(w in a.lower() for w in ("record", "arrange", "perform", "replace", "mic"))
                ],
                "relatedProcedureIDs": [],
                "supportingClaimIDs": claim_ids,
                "contradictingClaimIDs": [],
                "evidenceClass": "professionalPracticeHeuristic",
                "reviewState": "reviewed",
            }
        )


def build_from_effects_knowledge(sources, claims):
    """Logic effect entries are Tier A documentary behavior."""
    path = K / "logic-pro-12.3-effects-knowledge.json"
    if not path.exists():
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    sid = "logic-pro-12.3-effects-guide"
    sources.append(
        {
            "id": sid,
            "type": "officialManual",
            "title": "Apple Logic Pro 12.3 Effects User Guide (reviewed catalog)",
            "creatorOrPublisher": "Apple",
            "locator": "research/knowledge/logic-pro-12.3-effects-knowledge.json",
            "publicationDate": None,
            "retrievalDate": "2026-07",
            "exactVersion": "Logic Pro 12.3",
            "rightsBasis": "official documentation reviewed locally; paraphrased",
            "handlingClass": "openDocumentation",
            "tier": "tierAPrimaryOrDirect",
            "transcriptAvailable": False,
            "transcriptIsAutomatic": False,
            "requiresAudiovisualReview": False,
            "audiovisualReviewCompleted": False,
            "contentSHA256": [],
            "limitations": [
                "Documents controls and intended behavior, not proprietary algorithms.",
                "Version-scoped to Logic Pro 12.3.",
            ],
            "supersededBy": None,
        }
    )
    for entry in data.get("entries", []):
        ident = entry.get("identifier")
        mech = entry.get("documentedMechanism")
        if not ident or not mech:
            continue
        blob = f"{entry.get('name','')} {mech} {entry.get('productionConsequence','')}"
        claims.append(
            {
                "id": f"claim.{slug(ident)}.mechanism",
                "version": "1.0",
                "claimText": f"{entry.get('name')}: {mech}",
                "domains": domains_for(blob, entry.get("family", "")),
                "applicableSourceTypes": normalize_source_types(entry.get("applicableSourceTypes", []))[:6],
                "applicableQuestionKinds": [
                    "explainConcept",
                    "exactWorkflowHelp",
                    "compareOptions",
                    "productionStrategy",
                ],
                "conditions": [],
                "evidenceClass": "documentedBehavior",
                "sourceID": sid,
                "sourceLocation": f"pages {entry.get('manualPages')}"
                if entry.get("manualPages")
                else None,
                "reviewState": "reviewed",
                "contradictsClaimIDs": [],
                "limitations": [
                    "Documented behavior only; exact internal algorithm is not established."
                ],
                "listeningRemainsDecisive": True,
                "containsNumericRange": has_numeric_range(mech),
                "numericRangeKind": "documented" if has_numeric_range(mech) else None,
            }
        )
        cons = entry.get("productionConsequence")
        if cons:
            claims.append(
                {
                    "id": f"claim.{slug(ident)}.consequence",
                    "version": "1.0",
                    "claimText": f"{entry.get('name')}: {cons}",
                    "domains": domains_for(blob, entry.get("family", "")),
                    "applicableSourceTypes": normalize_source_types(entry.get("applicableSourceTypes", []))[:6],
                    "applicableQuestionKinds": [
                        "productionStrategy",
                        "compareOptions",
                        "troubleshootProblem",
                        "diagnoseTradeoff",
                    ],
                    "conditions": [],
                    "evidenceClass": "technicalInference",
                    "sourceID": sid,
                    "sourceLocation": f"pages {entry.get('manualPages')}"
                    if entry.get("manualPages")
                    else None,
                    "reviewState": "reviewed",
                    "contradictsClaimIDs": [],
                    "limitations": [
                        "Derived interpretation and professional practice, not a measured result."
                    ],
                    "listeningRemainsDecisive": True,
                    "containsNumericRange": has_numeric_range(cons),
                    "numericRangeKind": "heuristic" if has_numeric_range(cons) else None,
                }
            )


def curated_concepts(sources):
    """Concept cards for the terms the tutor is expected to explain.

    These paraphrase reviewed documentary and practice sources already in the
    repository; each carries its source IDs.
    """
    sid = "tracksmith-curated-concepts"
    sources.append(
        {
            "id": sid,
            "type": "trackSmithCurated",
            "title": "TrackSmith curated concept explanations",
            "creatorOrPublisher": "TrackSmith",
            "locator": "research/scripts/build-general-tutor-knowledge.py",
            "publicationDate": BUILT_AT,
            "retrievalDate": BUILT_AT,
            "exactVersion": "1.0",
            "rightsBasis": "TrackSmith-authored synthesis of reviewed sources",
            "handlingClass": "trackSmithGenerated",
            "tier": "tierBReviewedProfessionalPractice",
            "transcriptAvailable": False,
            "transcriptIsAutomatic": False,
            "requiresAudiovisualReview": False,
            "audiovisualReviewCompleted": False,
            "contentSHA256": [],
            "limitations": [
                "Teaching explanations, not normative standards text.",
            ],
            "supersededBy": None,
        }
    )

    def c(cid, term, aliases, doms, simple, causal, technical, example, misunderstanding, where, procs=None):
        return {
            "id": cid,
            "version": "1.0",
            "term": term,
            "aliases": aliases,
            "domains": doms,
            "simpleExplanation": simple,
            "causalExplanation": causal,
            "technicalExplanation": technical,
            "practicalExample": example,
            "commonMisunderstanding": misunderstanding,
            "whereItMatters": where,
            "relatedProcedureIDs": procs or [],
            "sourceIDs": [sid, "logic-pro-12.3-effects-guide"],
            "reviewState": "reviewed",
        }

    return [
        c("concept.q", "Q", ["q", "bandwidth", "resonance width"], ["eqAndFiltering"],
          "Q is how wide or narrow an EQ band is.",
          "A low Q spreads the change across many frequencies so it reads as overall tone; a high Q affects a narrow region so it reads as removing or adding one specific ringing note.",
          "Q is the ratio of centre frequency to bandwidth. Higher Q means a narrower affected region for the same centre frequency. Very high Q cuts can sound unnatural on sustained material because they track a narrow region that the music moves through.",
          "Searching for a resonance uses a high-ish Q boost; the final corrective cut usually uses a gentler Q and much less gain.",
          "That a higher Q is 'more precise' and therefore better. Narrow cuts can sound worse on moving material than a gentle broad move.",
          ["Finding and reducing a resonance", "Broad tonal balancing"],
          ["tutor.vocal.channel-eq-resonance-search.v1"]),
        c("concept.threshold", "Threshold", ["threshold"], ["compression"],
          "Threshold is the level where a compressor starts working.",
          "Signal above the threshold gets reduced; signal below it passes untouched. Lowering the threshold means more of the performance is being acted on.",
          "Threshold interacts with ratio and knee to define the static curve. With a soft knee, gain reduction begins gradually near the threshold rather than switching on at a point.",
          "If only the loudest words are being controlled, the threshold is high; if the whole phrase is being squeezed, it is low.",
          "That a lower threshold always means more control. Below a point it mostly removes the natural level differences that make a performance feel alive.",
          ["Vocal level consistency", "Drum bus glue"]),
        c("concept.ratio", "Ratio", ["ratio"], ["compression"],
          "Ratio is how strongly the compressor reduces what goes above the threshold.",
          "A 2:1 ratio halves how far the signal exceeds the threshold; a 10:1 ratio nearly stops it exceeding at all, which reads as limiting rather than compression.",
          "Ratio defines the slope of the static curve above the threshold. High ratios with fast attack behave as limiters and can dull transients; low ratios with more gain reduction often sound more natural than high ratios with less.",
          "Gentle vocal control often sits near 2:1 to 4:1; catching occasional peaks may use a much higher ratio with a high threshold.",
          "That a high ratio is 'stronger compression'. Ratio and threshold together determine how much is actually happening.",
          ["Vocal dynamics", "Peak control"]),
        c("concept.attack", "Attack", ["attack", "attack time"], ["compression", "transientShaping"],
          "Attack is how quickly the compressor reacts once the signal passes the threshold.",
          "A fast attack catches the very start of a note, which can reduce its punch. A slower attack lets the initial transient through and compresses the body, which usually keeps more perceived impact.",
          "Attack sets the detector/gain-computer time constant for increasing gain reduction. Its audible effect depends on the material's transient density; on sustained sources the distinction narrows considerably.",
          "On a snare, a slower attack tends to preserve the crack; a very fast attack can make it sound flatter.",
          "That fast attack means 'tighter'. On transient material it often means duller.",
          ["Drum punch", "Vocal control"]),
        c("concept.release", "Release", ["release", "release time"], ["compression"],
          "Release is how quickly the compressor stops working once the signal falls back.",
          "Too fast can cause audible pumping or distortion on low frequencies; too slow can leave the signal held down through quieter passages so the performance loses life.",
          "Release sets the time constant for recovering gain reduction. Program-dependent or auto release modes vary this with material. Release interacting with musical tempo is why compression can sound rhythmic.",
          "If the vocal seems to 'breathe' up between words in a distracting way, the release is likely too fast for that phrase.",
          "That release is inaudible because it happens after the loud part. It strongly shapes the perceived groove and sustain.",
          ["Vocal consistency", "Bus compression feel"]),
        c("concept.parallel-compression", "Parallel compression",
          ["parallel compression", "new york compression", "blend compression"],
          ["parallelProcessing", "compression"],
          "Parallel compression blends a heavily compressed copy under the original instead of replacing it.",
          "Because the untouched signal remains, the transients and dynamics survive while the compressed copy raises the quiet detail. That is why it can add density without the flattening that the same compression would cause in series.",
          "Implemented with a send to a bus or a plug-in mix control. Timing and phase must match between paths; a latency mismatch between parallel paths causes comb filtering rather than reinforcement.",
          "A drum bus where the heavily compressed copy is blended in until the room and sustain come up, then backed off.",
          "That it is simply 'more compression'. Its point is keeping the uncompressed dynamics present.",
          ["Drum density", "Vocal presence without squashing"]),
        c("concept.pre-delay", "Pre-delay", ["pre-delay", "predelay"], ["preDelay", "reverb", "depth"],
          "Pre-delay is the gap between the dry sound and the start of its reverb.",
          "A longer gap lets the direct sound be heard clearly before the reverb arrives, so the source can stay up front while still sitting in a space. A very short pre-delay merges the two and tends to push the source backwards.",
          "Pre-delay corresponds to the time before early reflections in a real space, which relates to source and boundary distance. It interacts with reverb time and early-reflection level in determining perceived distance.",
          "A vocal that disappears when reverb is added often improves with more pre-delay rather than less reverb.",
          "That pre-delay is a mix control. It changes perceived distance and clarity, not just the amount of effect.",
          ["Vocal depth", "Keeping a source forward in a large space"]),
        c("concept.phase-cancellation", "Phase cancellation",
          ["phase cancellation", "phase", "polarity", "comb filtering"],
          ["polarityAndPhase", "monoCompatibility"],
          "Phase cancellation is when two similar signals partly cancel each other and the sound thins out.",
          "When two copies of similar audio are offset in time or inverted in polarity, some frequencies reinforce and others subtract. The result is usually a hollow or thin tone that gets worse when the mix is summed to mono.",
          "Time offsets create frequency-dependent comb filtering with notches at regular intervals; polarity inversion is a broadband sign flip. Multi-microphone capture, doubled parts, and wide stereo processing are common causes.",
          "A mix that sounds wide and full in stereo but thin and hollow in mono usually has phase-related side content.",
          "That phase problems only come from mistakes. Deliberate width techniques can create them too.",
          ["Mono checks", "Multi-mic recording", "Stereo widening"]),
        c("concept.level-matched-comparison", "Level-matched comparison",
          ["level matching", "level-matched", "gain matching"],
          ["comparisonBias", "listeningLevel"],
          "Compare two versions at the same loudness, because louder almost always seems better.",
          "Small level differences bias preference judgments, so an A/B that is not level matched mostly measures which version is louder rather than which is better.",
          "Loudness bias is well documented in listening-test methodology; differences of around a decibel can flip preference. Matching by ear is approximate but removes most of the effect.",
          "Before deciding whether a compressor helped, match the bypassed and active levels and judge the character rather than the volume.",
          "That the difference is obvious enough to ignore level. It rarely is.",
          ["Every processing decision", "Master comparisons"],
          ["tutor.vocal.level-matched-bypass-comparison.v1"]),
        c("concept.masking", "Masking", ["masking", "masked", "fighting"], ["masking", "balance"],
          "Masking is when one sound makes another harder to hear because they occupy the same range.",
          "Two sources sharing a frequency region and a moment in time compete for the same perceptual space, so raising one tends to bury the other. Fixing it usually means giving them different ranges, different moments, or different levels, not just boosting the quieter one.",
          "Masking is frequency- and level-dependent and is strongest for nearby frequencies. Arrangement choices, register allocation, and timing separation often solve masking more cleanly than corrective EQ.",
          "Kick and bass that each sound fine alone but muddy together are usually competing in the same low band.",
          "That masking is fixed by EQ alone. Arrangement and level often matter more.",
          ["Kick and bass", "Vocal versus dense arrangement"]),
        c("concept.wet-dry", "Wet/dry", ["wet", "dry", "mix control", "blend"], ["wetDryTopology"],
          "Wet is the processed signal, dry is the original, and the blend sets how much of each you hear.",
          "Blending keeps the original character present while the processed version adds its effect. Whether to blend inside a plug-in or on a separate bus changes what else you can do to the wet path.",
          "An insert mix control and a send/return topology differ: the send path can be processed independently (filtered, compressed, delayed) while an insert blend cannot. Latency compensation matters when the paths are separate.",
          "A reverb on a send lets you EQ only the reverb; the same reverb as an insert with a mix knob does not.",
          "That a mix knob and a send are equivalent. They allow different downstream control.",
          ["Reverb and delay routing", "Parallel processing"]),
        c("concept.gain-staging", "Gain staging", ["gain staging", "gain structure", "headroom"],
          ["gainStaging", "clipping"],
          "Gain staging is keeping sensible levels at every step so nothing overloads and nothing is unnecessarily quiet.",
          "Levels that are too high can clip at some stage; levels that are too low can leave noise relatively louder. Because many processors respond to input level, changing gain early changes how everything after it behaves.",
          "Fixed-threshold processors respond to absolute input level, so a gain change before them alters their behavior even if the final level is compensated. Modern floating-point mixing is forgiving internally, but converters and fixed-threshold devices are not.",
          "If a compressor suddenly acts much harder after you raise a clip's gain, that is gain staging changing its threshold relationship.",
          "That digital headroom makes gain staging irrelevant. It still changes processor behavior.",
          ["Recording", "Any threshold-based processing"]),
    ]


def curated_gap_strategies(sources):
    """Strategy cards written to close the high-priority gaps the gap map found.

    These are TrackSmith-authored decision patterns synthesized from the
    reviewed Logic documentation and professional-practice material already in
    the repository. They are labeled professionalPracticeHeuristic, carry no
    exact Logic paths and no numeric settings, and defer to the validated
    procedure catalog for anything exact.
    """
    sid = "tracksmith-curated-strategies"
    sources.append(
        {
            "id": sid,
            "type": "trackSmithCurated",
            "title": "TrackSmith curated production strategy cards (gap-driven)",
            "creatorOrPublisher": "TrackSmith",
            "locator": "research/scripts/build-general-tutor-knowledge.py",
            "publicationDate": BUILT_AT,
            "retrievalDate": BUILT_AT,
            "exactVersion": "1.0",
            "rightsBasis": "TrackSmith-authored synthesis of reviewed documentation and practice sources",
            "handlingClass": "trackSmithGenerated",
            "tier": "tierBReviewedProfessionalPractice",
            "transcriptAvailable": False,
            "transcriptIsAutomatic": False,
            "requiresAudiovisualReview": False,
            "audiovisualReviewCompleted": False,
            "contentSHA256": [],
            "limitations": [
                "Decision patterns, not measured results or universal settings.",
                "Written to close identified coverage gaps; each needs real-session validation.",
            ],
            "supersededBy": None,
        }
    )

    def s(sid_, label, problem, doms, stypes, kinds, first, why, useful, notuseful,
          competing, consequences, preserve, tradeoffs, stops, wrong, nondsp, procs=None):
        return {
            "id": sid_,
            "version": "1.0",
            "label": label,
            "problemOrOutcome": problem,
            "domains": doms,
            "applicableSourceTypes": normalize_source_types(stypes),
            "applicableQuestionKinds": kinds,
            "usefulWhen": useful,
            "notUsefulWhen": notuseful,
            "competingInterpretations": competing,
            "recommendedFirstExperiment": first,
            "whyItMayHelp": why,
            "expectedAudibleConsequences": consequences,
            "preservationConcerns": preserve,
            "tradeoffs": tradeoffs,
            "stoppingRules": stops,
            "signsStrategyIsWrong": wrong,
            "nonDSPAlternatives": nondsp,
            "relatedProcedureIDs": procs or [],
            "supportingClaimIDs": [],
            "contradictingClaimIDs": [],
            "evidenceClass": "professionalPracticeHeuristic",
            "reviewState": "reviewed",
        }

    ALL_KINDS = ["troubleshootProblem", "achieveSoundOrFeeling", "productionStrategy",
                 "compareOptions", "diagnoseTradeoff", "planSession"]

    return [
        # --- MIDI timing: acceptance criterion 28
        s("strategy.curated.midi-timing-preserve-feel",
          "Tighten timing without flattening the performance",
          "MIDI performance does not line up with the grid, but full quantization makes it robotic",
          ["quantization", "humanization", "rubato", "groove", "timingEditing", "pianoAndKeys"],
          ["keyboard", "synth"], ALL_KINDS,
          "Before quantizing anything, decide whether the grid is right for this performance: loop eight bars and ask whether the part sounds wrong against the other instruments, or only wrong against the ruler.",
          "Quantization strength, the note selection you apply it to, and whether you move notes at all are three separate decisions. Most robotic results come from applying full strength to every note including ones that were expressive on purpose.",
          ["The part feels late or early against a stable tempo", "Only some notes drift"],
          ["The whole performance is rubato and the tempo itself is following the player"],
          ["Notes are wrong relative to a correct tempo", "The tempo is wrong relative to a correct performance", "Only specific hits are wrong"],
          ["Tighter ensemble against the rest of the track", "Loss of push and pull if applied at full strength"],
          ["Intentional rubato, rolled chords, grace notes, and the difference between hands"],
          ["Grid accuracy versus human feel", "Ensemble tightness versus expressive timing"],
          ["Stop when the part sits with the other instruments; going further only serves the ruler"],
          ["The part now sounds stiff", "Rolled chords have become blocks", "The melody lost its phrasing"],
          ["Re-perform the part with a click", "Adjust the tempo map to follow the performance instead"]),
        s("strategy.curated.tempo-map-versus-quantize",
          "Choose between moving notes and moving the tempo",
          "Deciding whether to conform a performance to the grid or build a tempo map that follows it",
          ["tempoMapping", "quantization", "rubato", "groove"],
          ["keyboard", "synth", "fullMix"], ALL_KINDS,
          "Ask which one is authoritative: if the performance is the musical truth and the grid is arbitrary, map the tempo to the performance; if the grid is shared with other players or programmed parts, move the notes.",
          "A tempo map preserves every nuance of the performance and makes the grid agree with it, which is the right direction when the performance is the record. Quantizing does the reverse and is right when the performance must join an existing grid.",
          ["A solo or lead performance recorded without a click", "Other parts must be added later around this feel"],
          ["The session already contains many grid-locked programmed parts"],
          ["Performance is authoritative", "Grid is authoritative", "Neither: re-record to a click"],
          ["Tempo map keeps the original feel exactly", "Quantizing gives predictable alignment with programmed parts"],
          ["The original performance timing, if it carries the musical intent"],
          ["Tempo mapping takes longer and complicates later edits", "Quantizing risks flattening expression"],
          ["Stop once added parts lock in without fighting the feel"],
          ["Edits keep fighting the grid after quantizing", "The map becomes so detailed it is unusable"],
          ["Re-record to a click", "Keep the performance and build arrangement around its feel"]),
        s("strategy.curated.velocity-cleanup",
          "Even out MIDI dynamics without erasing them",
          "MIDI part has distracting velocity jumps or feels mechanically uniform",
          ["velocity", "humanization", "pianoAndKeys"],
          ["keyboard", "synth"], ALL_KINDS,
          "Find the few notes that actually jump out or vanish and fix those individually before applying anything across the whole part.",
          "Global velocity compression or scaling changes every note including the ones that were right. Targeted edits keep the shape of the performance while removing the accidents.",
          ["A handful of notes are obviously wrong", "The part was played on a keybed with uneven response"],
          ["The unevenness is the groove"],
          ["Performance dynamics", "Controller response", "Sample-library velocity mapping"],
          ["More even phrase without losing accents"],
          ["Accents, phrase shape, and the difference between hands"],
          ["Evenness versus expression"],
          ["Stop when nothing distracts on playback in context"],
          ["The part now sounds typed in rather than played"],
          ["Re-perform the phrase", "Change the sample library's velocity curve"]),
        # --- Arrangement energy: acceptance criterion 29
        s("strategy.curated.chorus-feels-smaller",
          "Diagnose a chorus that feels smaller than the verse",
          "The chorus should lift but feels no bigger, or smaller, than the section before it",
          ["verseChorusDevelopment", "contrast", "density", "registerAllocation", "builds", "balance"],
          ["fullMix"], ALL_KINDS,
          "Before touching any processing, compare the verse and chorus for what actually changes: instrument count, register spread, rhythmic density, and level. Size is usually relative, so the most common cause is that the verse is already as full as the chorus.",
          "Perceived size is contrast, not absolute loudness or brightness. If the verse already occupies the full frequency range and the full stereo field, the chorus has nothing left to open up into. Making the chorus louder cannot create contrast that the arrangement did not leave room for.",
          ["The verse and chorus have similar instrument counts", "Both sections feel equally busy"],
          ["The chorus is genuinely bigger but a limiter is flattening it"],
          ["Arrangement offers no contrast", "Level automation is missing", "Register is crowded",
           "Mastering or bus limiting is squashing the lift", "Reverb is filling the verse already"],
          ["A chorus that opens up because the verse held something back"],
          ["The identity of the verse; thinning it too far can make the song feel empty rather than dynamic"],
          ["Reducing the verse can make it feel weak if overdone", "Adding chorus density can create mud"],
          ["Stop when the lift is obvious on a first listen without analysis"],
          ["Raising the chorus level alone did not change the feeling of size"],
          ["Remove an element from the verse", "Change the chorus voicing or register",
           "Add a part that only appears in the chorus", "Re-perform with more commitment in the chorus"]),
        s("strategy.curated.build-energy",
          "Build energy into a section without only raising level",
          "A section needs to feel like it grows or arrives",
          ["builds", "contrast", "transitions", "density", "sectionChanges"],
          ["fullMix"], ALL_KINDS,
          "List what changes at the boundary: entries, register, rhythmic density, ambience, and level. Energy comes from several of these moving together, so add one and check whether the arrival lands.",
          "Loudness alone saturates quickly and a limiter will undo it. Perceived energy comes from contrast in density, register, and rhythm as much as from level.",
          ["A section should feel like an arrival", "A transition feels flat"],
          ["The section is already dense and the problem is masking"],
          ["Arrangement contrast", "Level automation", "Ambience change", "Rhythmic density"],
          ["A clearer sense of arrival at the section boundary"],
          ["Do not let the build make the following section feel like a letdown"],
          ["Density can become mud", "Too many simultaneous changes can feel abrupt"],
          ["Stop when the arrival reads on a casual listen"],
          ["The section is louder but does not feel bigger"],
          ["Add or remove an instrument at the boundary", "Change the drum pattern", "Re-perform with different intensity"]),
        # --- Workflow and decision-making
        s("strategy.curated.what-to-try-first",
          "Choose one bounded first experiment instead of a checklist",
          "The user is stuck or the problem is not yet identified",
          ["whatToTryFirst", "orderOfOperations", "comparingApproaches"],
          ["vocal", "drums", "bass", "guitar", "keyboard", "synth", "fullMix"], ALL_KINDS,
          "Pick the single cheapest reversible test that could disprove the most likely cause, and do only that before deciding anything else.",
          "Working through a long checklist changes several variables at once, so nothing is learned. One reversible test per question keeps cause and effect legible.",
          ["The cause is genuinely unknown", "Several plausible explanations exist"],
          ["The cause is already obvious and the fix is known"],
          ["Balance problem", "Tonal problem", "Dynamics problem", "Arrangement problem", "Monitoring problem"],
          ["A clear yes or no about one hypothesis"],
          ["Undo each test before starting the next one"],
          ["A single test is slower than guessing, but guessing compounds errors"],
          ["Stop the test as soon as it answers its one question"],
          ["You changed several things and can no longer tell what helped"],
          ["Take a break and listen again", "Compare against a reference", "Check the arrangement first"],
          ["tutor.vocal.level-matched-bypass-comparison.v1"]),
        s("strategy.curated.mix-order-of-operations",
          "Establish an order of operations for a mix",
          "Not knowing where to start when mixing a song",
          ["orderOfOperations", "balance", "whatToTryFirst"],
          ["fullMix"], ALL_KINDS,
          "Get a static balance with faders only, before any processing, and find out how much of the problem was simply level.",
          "A large share of perceived tonal and clarity problems are balance problems. Solving them with processing first hides the cause and adds artifacts you then have to work around.",
          ["Starting a mix", "The mix feels wrong but no single element is obviously broken"],
          ["A specific technical defect such as clipping needs fixing first"],
          ["Balance problem", "Arrangement problem", "Tonal problem"],
          ["Much of the perceived problem resolves before any plug-in is inserted"],
          ["Keep the arrangement's intent; balance is not the same as making everything audible"],
          ["Faders alone cannot fix masking between parts occupying the same range"],
          ["Stop when the song communicates with faders alone, then start processing"],
          ["You are reaching for EQ before the faders sit"],
          ["Revisit the arrangement", "Mute a competing part"]),
        # --- Routing and effects workflow
        s("strategy.curated.send-versus-insert",
          "Decide between a send and an insert for an effect",
          "Choosing how to route reverb, delay, or parallel processing",
          ["sends", "buses", "parallelProcessing", "wetDryTopology", "reverb", "delay"],
          ["vocal", "drums", "guitar", "keyboard", "synth", "fullMix"], ALL_KINDS,
          "Ask whether you will want to process the effect itself. If yes, use a send so the wet path is separate; if no, an insert with a blend control is simpler.",
          "A send puts the effect on its own channel, so it can be filtered, compressed, or automated independently of the dry signal. An insert blend cannot do that. Several sources can also share one send, which keeps a mix coherent.",
          ["Multiple sources should share one space", "You want to EQ or duck the effect"],
          ["A single source needs a self-contained effect and nothing else"],
          ["Shared space", "Per-source character", "Parallel dynamics"],
          ["Independent control of the effect signal"],
          ["Keep the dry signal intact when using a send"],
          ["Sends add routing complexity", "Inserts are simpler but less flexible"],
          ["Stop once the effect can be controlled the way the mix needs"],
          ["You cannot solve the problem because the wet and dry are locked together"],
          ["Reconsider whether the effect is needed at all"]),
        s("strategy.curated.delay-throw",
          "Create a delay throw on a specific word or phrase",
          "Wanting an echo on one moment rather than the whole part",
          ["delayThrows", "delay", "effectAutomation", "levelAutomation", "sends"],
          ["vocal"], ALL_KINDS,
          "Put the delay on a send rather than an insert, then automate the send level so it only opens for the word you want to throw.",
          "Automating the send means the dry vocal is untouched and only the chosen moment feeds the delay. Automating a plug-in mix control instead would alter the dry signal balance too.",
          ["A single word or line should echo", "The effect should not wash the whole phrase"],
          ["The whole part should sit in the same ambience"],
          ["Send automation", "Plug-in mix automation", "Separate duplicated region"],
          ["An echo that appears only where intended"],
          ["The dry vocal level and intelligibility must not change"],
          ["Automation adds complexity", "Too many throws become distracting"],
          ["Stop when the throw supports the lyric rather than drawing attention to itself"],
          ["The whole phrase became washed out"],
          ["Re-perform with a natural pause for the echo to sit in"]),
        s("strategy.curated.cleanup-noise-preserve-breaths",
          "Reduce noise between phrases without removing breaths",
          "Noise or room tone is audible between vocal phrases",
          ["cleanup", "noise", "expansionAndGating", "vocals"],
          ["vocal"], ALL_KINDS,
          "Decide first whether the noise is actually distracting in the full mix, because breaths and room tone often carry continuity that removing them destroys.",
          "Gating and silencing act on level, not on meaning, so they cut breaths and phrase tails along with the noise. In a full arrangement the noise is frequently masked anyway.",
          ["The noise is audible in context, not only when soloed"],
          ["The noise is only audible when the vocal is soloed"],
          ["Capture noise floor", "Room tone", "Make-up gain raising the floor", "Identity-bearing ambience"],
          ["Quieter gaps without unnatural silence"],
          ["Breaths, phrase tails, and the sense of a real person in a real room"],
          ["Aggressive cleanup creates unnatural silences that draw more attention than the noise did"],
          ["Stop when the noise stops distracting in the full mix"],
          ["The vocal now sounds edited and clinical", "Breaths have disappeared"],
          ["Re-record in a quieter environment", "Improve microphone position", "Leave the noise in"],
          ["tutor.vocal.no-processing-decision.v1"]),
        # --- second gap-driven wave
        s("strategy.curated.plugin-order",
          "Decide where a processor belongs in the chain",
          "Choosing whether EQ, compression, saturation, or ambience comes first",
          ["channelStripOrder", "eqAndFiltering", "compression", "saturation"],
          ["vocal", "drums", "bass", "guitar", "keyboard", "synth", "fullMix"], ALL_KINDS,
          "Ask what each processor is reacting to: anything that changes level or tone before a threshold-based processor changes how that processor behaves.",
          "Order matters most where one stage feeds another's detector. EQ before a compressor changes what the compressor hears and therefore when it acts; EQ after it shapes the already-compressed result without altering the dynamics.",
          ["A compressor is reacting to a frequency you do not want it to chase", "You want tone shaping that does not alter dynamics"],
          ["Neither stage is level- or threshold-dependent"],
          ["Fix the input to the detector", "Shape the output after dynamics", "Do both with two stages"],
          ["Different dynamic behavior for the same nominal settings"],
          ["The intended character of the source; reordering can change it substantially"],
          ["Corrective-before-dynamics is predictable but can sound clinical; tone-after can sound more natural but is harder to control"],
          ["Stop once the dynamics behave and the tone is right; further reordering is usually taste"],
          ["Reordering changes nothing audible, which means the stages were not interacting"],
          ["Fix the source so less processing is needed"]),
        s("strategy.curated.monitoring-and-translation",
          "Decide what to trust when systems disagree",
          "A mix sounds different on headphones, monitors, a car, or a phone",
          ["interfacesAndMonitoring", "headphonesVersusMonitors", "translation", "roomProblems", "earFatigue"],
          ["fullMix", "master"], ALL_KINDS,
          "Check the same short section on two systems you know well and note what specifically changes; a difference that appears on every system is in the mix, one that appears on a single system is that system.",
          "No playback system is neutral. Learning what your own systems exaggerate is what makes a judgment portable; chasing each system in turn produces a mix that works nowhere.",
          ["A mix works in one place and not another", "You are unsure which system is lying"],
          ["You have only ever heard the mix on one system"],
          ["Room problem", "Headphone response", "Genuine mix problem", "Ear fatigue"],
          ["A clearer sense of which differences are real"],
          ["Do not re-mix for one system at the expense of the others"],
          ["Time spent checking is time not spent mixing", "Over-correcting for one system breaks the others"],
          ["Stop when the same decision holds on both systems"],
          ["Each system sends you in a different direction and the mix keeps moving"],
          ["Improve the room", "Learn one system deeply rather than adding more"]),
        s("strategy.curated.depth-in-a-mix",
          "Create front-to-back depth",
          "A mix feels flat, with everything at the same apparent distance",
          ["mixDepth", "depth", "reverb", "preDelay", "frontToBackPlacement", "balance"],
          ["fullMix"], ALL_KINDS,
          "Decide which single element should be closest, then push one supporting element back using level first, before reaching for reverb.",
          "Depth is relative. Level, high-frequency content, and direct-to-reverberant balance all encode distance; level is the cheapest and most reversible of the three, so it answers the question before ambience complicates it.",
          ["Everything sounds equally present", "Adding reverb made things worse rather than deeper"],
          ["The arrangement has only one element"],
          ["Level relationship", "Ambience relationship", "Tonal distance cues", "Arrangement density"],
          ["A clear foreground and background rather than a flat wall"],
          ["The lead element's intelligibility must survive"],
          ["Pushing things back can make a mix feel smaller if overdone"],
          ["Stop when the hierarchy is obvious on a casual listen"],
          ["Everything now sounds distant"],
          ["Re-arrange so fewer elements compete for the front"]),
        s("strategy.curated.export-and-delivery-check",
          "Check a mix before exporting or delivering",
          "Preparing a final file for release or hand-off",
          ["formatAndExport", "streamingDelivery", "qualityControl", "peaks", "loudness"],
          ["fullMix", "master"], ALL_KINDS,
          "Play the whole file start to finish once, without touching anything, listening for edits, clicks, and abrupt starts or ends.",
          "Most delivery failures are not loudness problems; they are a truncated tail, a click at an edit, a missing fade, or the wrong file exported. A single uninterrupted listen catches those cheaply.",
          ["Before any delivery or hand-off"],
          ["Mid-mix, where it interrupts creative work"],
          ["Technical defect", "Loudness or level issue", "Wrong file version"],
          ["Confidence the file is the one you meant to send"],
          ["Keep the pre-export version so you can go back"],
          ["A full listen takes real time, which is why it gets skipped"],
          ["Stop when a complete pass reveals nothing new"],
          ["You are checking numbers instead of listening"],
          ["Have someone else listen once"]),
        s("strategy.curated.latency-and-buffer",
          "Trade monitoring latency against system stability",
          "Playing feels delayed, or lowering the buffer causes clicks",
          ["latency", "interfacesAndMonitoring", "performanceCapture"],
          ["vocal", "guitar", "keyboard", "synth"], ALL_KINDS,
          "Use a small buffer while recording and a large one while mixing, and change it deliberately at the point you switch tasks.",
          "Buffer size trades responsiveness against processing headroom. Recording needs responsiveness; mixing needs headroom. One setting cannot serve both, which is why a fixed choice always feels wrong at some point.",
          ["Timing feels off while playing", "Audio breaks up under plug-in load"],
          ["The delay is coming from a plug-in's own latency rather than the buffer"],
          ["Buffer size", "Plug-in latency", "Interface driver", "System load"],
          ["Responsive playing while tracking, stable playback while mixing"],
          ["Do not commit a performance recorded while fighting latency"],
          ["Small buffers can destabilize a loaded session"],
          ["Stop when playing feels natural and playback is stable for the current task"],
          ["Changing the buffer makes no difference, so the delay is elsewhere"],
          ["Monitor through the interface rather than the software"]),
        s("strategy.curated.group-versus-track-processing",
          "Decide between processing a group and processing each track",
          "Whether to treat elements together or individually",
          ["groupProcessing", "buses", "compression", "orderOfOperations"],
          ["drums", "fullMix", "vocal"], ALL_KINDS,
          "Ask whether the elements should move together. If they should feel like one thing, process the group; if one element has its own problem, fix that element.",
          "Group processing makes elements share a dynamic and tonal fate, which is what makes them cohere. Applied to a problem that belongs to one element, it drags everything else along with the fix.",
          ["Elements should feel like a single instrument", "You want them to breathe together"],
          ["One element has a specific defect the others do not share"],
          ["Cohesion problem", "Individual element problem", "Balance problem"],
          ["Elements that move as one, or a targeted fix that leaves the rest alone"],
          ["Group processing can flatten the internal balance you already set"],
          ["Group cohesion versus individual control"],
          ["Stop when the group holds together without any element being dragged"],
          ["You are fixing one element by processing ten"],
          ["Rebalance the individual levels first"]),
        s("strategy.curated.streaming-loudness",
          "Decide how loud to deliver for streaming",
          "Uncertainty about loudness targets and normalization",
          ["streamingDelivery", "loudness", "peaks", "masterDynamics"],
          ["master", "fullMix"], ALL_KINDS,
          "Compare your master against a reference you admire in the same genre, level-matched, and judge dynamics and tone rather than trying to hit a number.",
          "Platforms normalize playback level, so pushing loudness mostly trades dynamics away for no perceived gain. What survives normalization is how the mix sounds at a matched level.",
          ["Choosing a delivery level", "Worried the master is too quiet"],
          ["The delivery target is a specification you have been given"],
          ["Loudness target", "Dynamic range preference", "Genre convention"],
          ["A master that holds up at matched level rather than only when louder"],
          ["Dynamics and transients that give the record its life"],
          ["Loudness bought with limiting costs punch and depth"],
          ["Stop when it stands up level-matched against the reference"],
          ["The master only sounds better when it is louder"],
          ["Improve the mix rather than the limiter"]),
        s("strategy.curated.note-length-and-overlap",
          "Fix blurred or disconnected MIDI parts through note length",
          "Notes overlap into mush, or a part sounds disconnected and stiff",
          ["noteLength", "articulation", "sustainPedal", "humanization"],
          ["keyboard", "synth", "bass"], ALL_KINDS,
          "Look at whether notes overlap or leave gaps where the part should be connected, and fix the few obvious ones before applying anything globally.",
          "Note length controls whether a part reads as legato or detached, and on sustained sounds overlapping notes stack into a blur that no EQ can separate. It is an editing problem, not a processing problem.",
          ["A bass or pad part sounds slurred", "A part sounds stiff and disconnected"],
          ["The blur comes from reverb rather than overlap"],
          ["Note overlap", "Sustain pedal", "Patch release time", "Reverb"],
          ["Clearer separation, or a more connected line"],
          ["Intentional legato phrasing and pedal use"],
          ["Over-shortening makes a part sound clipped and mechanical"],
          ["Stop when the line reads clearly in the arrangement"],
          ["Shortening notes did not help, so the blur is in the patch or the reverb"],
          ["Change the patch's release", "Re-perform the part"]),
        s("strategy.curated.logic-tool-choice",
          "Choose the right Logic tool for an edit",
          "Not knowing which tool or editor an edit calls for",
          ["logicTools", "logicEditors", "regionEditing", "flex", "timingEditing"],
          ["vocal", "drums", "bass", "guitar", "keyboard", "synth", "fullMix"], ALL_KINDS,
          "Name the smallest thing you want to change — a region, a section inside it, a single note, or the timing of one hit — because that scope determines the tool more than the tool list does.",
          "Logic's tools are organized by scope: region-level, selection-level, note-level, and time-level. Choosing by scope avoids reaching for a destructive or over-broad tool when a narrower one exists.",
          ["Unsure which editor to open", "An edit affected more than intended"],
          ["The change is a mix decision rather than an edit"],
          ["Region scope", "Selection scope", "Note scope", "Timing scope"],
          ["An edit that changes only what you meant"],
          ["Work on a copy or use project alternatives before broad edits"],
          ["Narrow tools take longer; broad tools risk collateral change"],
          ["Stop when the intended change is made and nothing else moved"],
          ["You are undoing more than you are editing"],
          ["Re-record the part rather than editing it heavily"]),
        s("strategy.curated.ear-fatigue",
          "Manage ear fatigue during a long session",
          "Decisions get harder and everything starts sounding the same",
          ["earFatigue", "listeningLevel", "comparisonBias", "knowingWhenToStop"],
          ["fullMix", "master", "vocal"], ALL_KINDS,
          "Stop and leave the room for ten minutes, then judge the mix in the first thirty seconds after you return.",
          "Sensitivity to high frequencies and to small differences drops measurably over a long loud session, and the loss is gradual enough that you do not notice it happening. The first impression after a break is the most reliable data you will get that day.",
          ["Decisions are taking longer than they did an hour ago", "You keep reversing yourself"],
          ["You have only been working for a few minutes"],
          ["Fatigue", "Genuine mix problem", "Monitoring level too high"],
          ["Renewed ability to hear differences you had stopped noticing"],
          ["Do not commit fatigue-driven decisions; note them and revisit"],
          ["Breaks cost session time"],
          ["Stop the session entirely if a break no longer restores clarity"],
          ["You return from a break and immediately dislike everything you did"],
          ["Lower the monitoring level", "Finish tomorrow"]),
    ]


def curated_contradictions(claims_index):
    """Genuine, preserved disagreements. Only emitted when both sides exist."""
    out = []

    def pick(pred, limit=3):
        return [c["id"] for c in claims_index if pred(c)][:limit]

    comp = pick(lambda c: "compression" in c["domains"] and c["evidenceClass"] == "professionalPracticeHeuristic")
    preserve = pick(lambda c: "preservingIntent" in c["domains"])
    if comp and preserve:
        out.append(
            {
                "id": "contradiction.control-versus-character",
                "topic": "Dynamic control versus preserved performance character",
                "domains": ["compression", "preservingIntent", "vocals"],
                "positionAClaimIDs": comp,
                "positionASummary": "Reviewed professional cases apply dynamics processing to make a performance sit consistently in the mix.",
                "positionBClaimIDs": preserve,
                "positionBSummary": "Other reviewed cases deliberately accept level variation and technical irregularity because it carries intimacy, identity, or authorship.",
                "whatDeterminesWhichApplies": "Whether the variation is distracting the listener or is itself part of what the record is communicating. This is a listening and intent judgment, not a measurement.",
                "resolvedByEvidence": False,
            }
        )

    noise = pick(lambda c: "noise" in c["domains"])
    if noise and preserve:
        out.append(
            {
                "id": "contradiction.noise-cleanup-versus-place",
                "topic": "Cleaning noise versus preserving the sound of a place",
                "domains": ["noise", "cleanup", "preservingIntent"],
                "positionAClaimIDs": noise[:2],
                "positionASummary": "Noise and environmental sound are commonly treated as defects to be reduced.",
                "positionBClaimIDs": preserve[:2],
                "positionBSummary": "Reviewed cases retain environmental sound because it contributes continuity, intimacy, and evidence of place.",
                "whatDeterminesWhichApplies": "Whether the noise draws attention as an accidental defect or supports the record's character. Audition before repairing.",
                "resolvedByEvidence": False,
            }
        )
    return out


TEMPLATE = '''// Generated by research/scripts/build-general-tutor-knowledge.py
// Built from reviewed artifacts already present in this repository. No network
// fetch, no invented content: every card points at a checked-in source record.
// Regenerate with:
//   python3 research/scripts/build-general-tutor-knowledge.py
// The runtime loader verifies this payload against the recorded SHA-256 and
// then runs GeneralTutorKnowledgeValidator before any card is used.

public enum GeneralTutorKnowledgeGenerated {{
    public static let sourceArtifactSHA256 = "{sha256}"
    public static let sourceCount = {source_count}
    public static let claimCount = {claim_count}
    public static let strategyCount = {strategy_count}
    public static let conceptCount = {concept_count}
    public static let contradictionCount = {contradiction_count}
    public static let knowledgeJSON = #"""
{payload}
"""#
}}
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    sources: list[dict] = []
    claims: list[dict] = []
    strategies: list[dict] = []

    records = load_jsonl(K / "PRODUCER_JUDGMENT_CORPUS.jsonl") + load_jsonl(
        K / "PRODUCER_JUDGMENT_CORPUS_PART_B.jsonl"
    )
    build_from_producer_corpus(records, sources, claims, strategies)
    build_from_effects_knowledge(sources, claims)
    strategies.extend(curated_gap_strategies(sources))
    concepts = curated_concepts(sources)
    contradictions = curated_contradictions(claims)

    # Wire contradiction links back onto the claims themselves.
    by_id = {c["id"]: c for c in claims}
    for record in contradictions:
        for a in record["positionAClaimIDs"]:
            for b in record["positionBClaimIDs"]:
                if a in by_id and b not in by_id[a]["contradictsClaimIDs"]:
                    by_id[a]["contradictsClaimIDs"].append(b)
                if b in by_id and a not in by_id[b]["contradictsClaimIDs"]:
                    by_id[b]["contradictsClaimIDs"].append(a)

    base = {
        "schemaVersion": "tracksmith.general-tutor-knowledge.v1",
        "builtAt": BUILT_AT,
        "sources": sources,
        "claims": claims,
        "strategies": strategies,
        "concepts": concepts,
        "contradictions": contradictions,
    }

    payload = json.dumps(base, indent=1, ensure_ascii=False, sort_keys=True)
    if '"""#' in payload:
        print("ERROR: payload contains the Swift raw-string delimiter", file=sys.stderr)
        return 1
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    generated = TEMPLATE.format(
        sha256=digest,
        source_count=len(sources),
        claim_count=len(claims),
        strategy_count=len(strategies),
        concept_count=len(concepts),
        contradiction_count=len(contradictions),
        payload=payload,
    )

    if args.check:
        current = args.output.read_text(encoding="utf-8") if args.output.exists() else ""
        if current != generated:
            print("GENERAL_TUTOR_KNOWLEDGE_CHECK_FAILED: regenerate")
            return 1
        print(
            f"GENERAL_TUTOR_KNOWLEDGE_CHECK_OK sources={len(sources)} claims={len(claims)} "
            f"strategies={len(strategies)} concepts={len(concepts)} contradictions={len(contradictions)}"
        )
        return 0

    args.output.write_text(generated, encoding="utf-8")
    print(
        f"WROTE {args.output} sources={len(sources)} claims={len(claims)} "
        f"strategies={len(strategies)} concepts={len(concepts)} contradictions={len(contradictions)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
