#!/usr/bin/env python3
"""Fail-closed documentary coverage audit for TrackSmith's Logic 12.3 knowledge.

This audit proves source integrity and catalogue-to-source coverage. It does not
claim that Apple's proprietary transfer functions have been measured, that every
musical use is known, or that TrackSmith can execute Logic-native operations.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import subprocess
import unicodedata
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[2]
ARCHIVE = ROOT / "research/papers/tracksmith-logic-12.3-archive"
KNOWLEDGE = ROOT / "research/knowledge"
OUTPUT = KNOWLEDGE / "logic-pro-12.3-knowledge-coverage.json"
EVIDENCE_ROOT = ROOT / "research/evaluation/logic-native-empirical-runs"
CORE_DECISION_ATLAS = ROOT / "research/analysis/TRACKSMITH_CORE_EFFECT_DECISION_ATLAS.md"

MANUALS = {
    "effects": {
        "sha256": "b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819",
        "pages": 390,
    },
    "instruments": {
        "sha256": "fc867e61b1bbcfc16d4ba98058f7cde104ec17e0649026769c308cff07049ab4",
        "pages": 752,
    },
    "user-guide": {
        "sha256": "aa016d18d7e4f3559cdec54a99937d00b379617fee87510db1ec9853a4996cff",
        "pages": 1324,
    },
    "control-surfaces": {
        "sha256": "5ab5e4ef38e9c8e9279a0a2d36dcaabd1a9471942843d0162a3016f6ebf9322c",
        "pages": 220,
    },
}

ATLAS_PATHS = {
    "effects": ROOT / "research/analysis/TRACKSMITH_LOGIC_PRO_12_3_TOOL_ATLAS.md",
    "instruments": ROOT / "research/analysis/TRACKSMITH_LOGIC_PRO_12_3_INSTRUMENT_ATLAS.md",
    "workflow": ROOT / "research/analysis/TRACKSMITH_LOGIC_PRO_12_3_WORKFLOW_ATLAS.md",
    "controlSurfaces": ROOT / "research/analysis/TRACKSMITH_LOGIC_PRO_CONTROL_SURFACES_ATLAS.md",
}

RELEASE_RESOURCE_ID = "apple-logic-pro-12.3-release-notes-2026-07-16"
RELEASE_SHA256 = "854fd08c8e38351d521a9feed35a77fc2ce5969baab473e270decd2425f0dcb0"
RELEASE_REQUIRED_PHRASES = (
    "New in Logic Pro for Mac 12.3",
    "Beat Breaker",
    "new filter and resonance modes",
    "panning mode",
    "randomization for all modes",
    "granular sync mode",
    "formant Shifting",
    "Flex without using file tempo",
    "I/O assignments above channel 128",
    "third-party Audio Unit plug-in user interfaces",
    "Save with audio data",
)

LOGIC_FIXTURE_FILES = {
    "silence_mono.wav",
    "single_impulse_mono.wav",
    "impulse_level_ladder_mono.wav",
    "log_sweep_20hz_20khz_mono.wav",
    "amplitude_ladder_1khz_mono.wav",
    "multitone_mono.wav",
    "smpte_imd_60hz_7khz_mono.wav",
    "ccif_imd_19khz_20khz_mono.wav",
    "deterministic_noise_bursts_mono.wav",
    "guitar_like_dynamic_plucks_mono.wav",
    "bass_like_dynamic_plucks_mono.wav",
    "vocal_like_mono.wav",
    "stereo_in_phase.wav",
    "stereo_left_only.wav",
    "stereo_right_only.wav",
    "stereo_anti_phase.wav",
    "stereo_one_sample_offset.wav",
    "stereo_mid_low_side_high.wav",
}
EXPECTED_PEDAL_MEASUREMENT_PROFILES = {
    "pedal_delay_or_ambience": 4,
    "pedal_nonlinear_drive_or_fuzz": 12,
    "pedal_dynamics": 1,
    "pedal_envelope_filter": 1,
    "pedal_manual_filter_or_eq": 3,
    "pedal_modulation": 12,
    "pedal_pitch": 2,
    "pedalboard_routing_utility": 2,
}


def digest(path: pathlib.Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def load_json(path: pathlib.Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def resolve_json_path(payload: Any, components: list[Any], label: str) -> Any:
    current = payload
    for component in components:
        if isinstance(component, int):
            require(isinstance(current, list), f"assertion expected list: {label}")
            require(0 <= component < len(current), f"assertion index out of range: {label}")
            current = current[component]
        else:
            require(isinstance(component, str) and component,
                    f"invalid assertion path component: {label}")
            require(isinstance(current, dict) and component in current,
                    f"assertion key missing: {label}:{component}")
            current = current[component]
    return current


def normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value).casefold()
    return " ".join(re.sub(r"[^a-z0-9]+", " ", decomposed).split())


def parse_range(value: str) -> tuple[int, int] | None:
    match = re.fullmatch(r"\s*(\d+)\s*(?:-\s*(\d+)\s*)?", value)
    if match is None:
        return None
    start = int(match.group(1))
    return start, int(match.group(2) or start)


def pdf_text(path: pathlib.Path, start: int, end: int) -> str:
    result = subprocess.run(
        ["pdftotext", "-f", str(start), "-l", str(end), "-layout", str(path), "-"],
        check=True,
        capture_output=True,
        text=True,
    )
    return normalize(result.stdout)


def validated_current_manifests() -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for path in sorted((ARCHIVE / "manifests/current").glob("*.json")):
        record = load_json(path)
        resource_id = record.get("resourceID")
        if isinstance(resource_id, str):
            result[resource_id] = record
    return result


def audit_empirical_runs(
    campaign_entries: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    campaign_by_identifier = {entry["identifier"]: entry for entry in campaign_entries}
    discovered: dict[str, tuple[pathlib.Path, dict[str, Any]]] = {}
    referenced_run_ids: set[str] = set()
    result: list[dict[str, Any]] = []

    for path in sorted(EVIDENCE_ROOT.glob("*/run.json")):
        record = load_json(path)
        run_id = record.get("runID")
        identifier = record.get("identityIdentifier")
        status = record.get("status")
        require(record.get("schemaVersion") == "1.0", f"unsupported run schema: {path}")
        require(isinstance(run_id, str) and run_id, f"runID missing: {path}")
        require(run_id not in discovered, f"duplicate empirical runID: {run_id}")
        require(identifier in campaign_by_identifier, f"unknown empirical identity: {identifier}")
        require(status in {"partial", "complete"}, f"invalid empirical run status: {run_id}")
        require(record.get("directHostEvidence") is True, f"run is not direct host evidence: {run_id}")
        require(isinstance(record.get("exactTransferCharacterized"), bool),
                f"exact-transfer boundary missing: {run_id}")
        require(not (status == "partial" and record["exactTransferCharacterized"]),
                f"partial run overclaims exact transfer: {run_id}")
        entry = campaign_by_identifier[identifier]
        require(record.get("identityName") == entry["name"], f"run identity name mismatch: {run_id}")
        require(record.get("identityType") == entry["identityType"],
                f"run identity type mismatch: {run_id}")
        coverage = record.get("dimensionCoverage")
        require(isinstance(coverage, dict), f"dimension coverage missing: {run_id}")
        required_dimensions = set(entry["requiredDimensions"])
        covered_dimensions = set(coverage)
        require(covered_dimensions.issubset(required_dimensions),
                f"dimension coverage contains undeclared campaign requirements: {run_id}")
        require(covered_dimensions, f"partial run closes no declared dimension: {run_id}")
        if status == "complete":
            require(covered_dimensions == required_dimensions,
                    f"complete run omits campaign dimensions: {run_id}")
        for dimension, evidence in coverage.items():
            require(isinstance(evidence, dict), f"invalid dimension evidence: {run_id}:{dimension}")
            dimension_status = evidence.get("status")
            require(
                isinstance(dimension_status, str)
                and dimension_status.split("_", 1)[0] in {"not", "partial", "complete"},
                f"invalid dimension status: {run_id}:{dimension}",
            )
            require(isinstance(evidence.get("evidence"), str) and evidence["evidence"],
                    f"dimension evidence text missing: {run_id}:{dimension}")
            if status == "complete":
                require(dimension_status.startswith("complete_"),
                        f"complete run contains an unclosed dimension: {run_id}:{dimension}")
        for required_object in (
            "environment", "project", "nativeState", "input", "renderMethod",
            "measurements", "interpretation", "claimBoundary",
        ):
            require(isinstance(record.get(required_object), dict),
                    f"required run object missing: {run_id}:{required_object}")
        artifact_files = record.get("artifactFiles")
        require(isinstance(artifact_files, list) and artifact_files,
                f"artifact ledger missing: {run_id}")
        run_root = path.parent.resolve()
        seen_artifact_paths: set[str] = set()
        for artifact in artifact_files:
            require(isinstance(artifact, dict), f"invalid artifact record: {run_id}")
            relative_path = artifact.get("path")
            expected_hash = artifact.get("sha256")
            require(isinstance(relative_path, str) and relative_path,
                    f"artifact path missing: {run_id}")
            require(relative_path not in seen_artifact_paths,
                    f"duplicate artifact path: {run_id}:{relative_path}")
            seen_artifact_paths.add(relative_path)
            require(isinstance(expected_hash, str) and re.fullmatch(r"[0-9a-f]{64}", expected_hash) is not None,
                    f"invalid artifact hash: {run_id}:{relative_path}")
            artifact_path = (path.parent / relative_path).resolve()
            try:
                artifact_path.relative_to(run_root)
            except ValueError:
                raise SystemExit(f"artifact escapes run directory: {run_id}:{relative_path}")
            require(artifact_path.is_file(), f"artifact missing: {run_id}:{relative_path}")
            require(digest(artifact_path) == expected_hash,
                    f"artifact hash mismatch: {run_id}:{relative_path}")

        measurement_assertions = record.get("measurementAssertions", [])
        require(isinstance(measurement_assertions, list),
                f"invalid measurement assertions: {run_id}")
        for index, assertion in enumerate(measurement_assertions):
            label = f"{run_id}:measurementAssertions[{index}]"
            require(isinstance(assertion, dict), f"invalid assertion: {label}")
            artifact_path = assertion.get("artifactPath")
            json_path = assertion.get("jsonPath")
            require(artifact_path in seen_artifact_paths,
                    f"assertion references unledgered artifact: {label}")
            require(isinstance(json_path, list) and json_path,
                    f"assertion JSON path missing: {label}")
            assertion_payload = load_json((path.parent / artifact_path).resolve())
            measured = resolve_json_path(assertion_payload, json_path, label)
            predicates = 0
            if "equals" in assertion:
                predicates += 1
                require(measured == assertion["equals"],
                        f"assertion equality failed: {label}")
            if "minimum" in assertion:
                predicates += 1
                require(isinstance(measured, (int, float)) and not isinstance(measured, bool),
                        f"assertion minimum is not numeric: {label}")
                require(measured >= assertion["minimum"],
                        f"assertion minimum failed: {label}")
            if "maximum" in assertion:
                predicates += 1
                require(isinstance(measured, (int, float)) and not isinstance(measured, bool),
                        f"assertion maximum is not numeric: {label}")
                require(measured <= assertion["maximum"],
                        f"assertion maximum failed: {label}")
            require(predicates > 0, f"assertion has no predicate: {label}")
        discovered[run_id] = (path, record)
        result.append(
            {
                "runID": run_id,
                "identityIdentifier": identifier,
                "status": status,
                "exactTransferCharacterized": record["exactTransferCharacterized"],
                "artifactCount": len(artifact_files),
                "path": str(path.relative_to(ROOT)),
                "runRecordSHA256": digest(path),
                "statusSummary": "direct_host_evidence_artifacts_present_and_hash_validated",
            }
        )

    for entry in campaign_entries:
        status = entry.get("status")
        require(status in {"not_run", "partial", "complete"},
                f"invalid campaign status: {entry['identifier']}:{status}")
        measured_ids = entry.get("measuredRunIDs")
        require(isinstance(measured_ids, list) and len(measured_ids) == len(set(measured_ids)),
                f"invalid campaign run IDs: {entry['identifier']}")
        evidence_paths = entry.get("evidenceRunRecords", [])
        if status == "not_run":
            require(not measured_ids and not evidence_paths,
                    f"not_run identity references evidence: {entry['identifier']}")
            require(entry.get("exactTransferCharacterized") is False,
                    f"not_run identity claims exact transfer: {entry['identifier']}")
            continue
        require(measured_ids, f"measured identity has no run IDs: {entry['identifier']}")
        require(len(evidence_paths) == len(measured_ids),
                f"campaign evidence-path count mismatch: {entry['identifier']}")
        for run_id in measured_ids:
            require(run_id in discovered, f"campaign references missing run: {run_id}")
            run_path, run = discovered[run_id]
            require(run["identityIdentifier"] == entry["identifier"],
                    f"campaign run identity mismatch: {run_id}")
            require(str(run_path.relative_to(ROOT)) in evidence_paths,
                    f"campaign run path mismatch: {run_id}")
            referenced_run_ids.add(run_id)
        if status == "partial":
            require(entry.get("exactTransferCharacterized") is False,
                    f"partial campaign identity claims exact transfer: {entry['identifier']}")
            require(all(discovered[run_id][1]["status"] == "partial" for run_id in measured_ids),
                    f"partial campaign identity includes complete run: {entry['identifier']}")
        else:
            require(any(discovered[run_id][1]["status"] == "complete" for run_id in measured_ids),
                    f"complete campaign identity has no complete run: {entry['identifier']}")

    require(referenced_run_ids == set(discovered),
            "one or more empirical run records are not referenced by the campaign")
    return result


def audit_manuals(index: dict[str, Any]) -> list[dict[str, Any]]:
    require(index.get("manualCount") == 4, "manual index must contain four manuals")
    require(index.get("totalPageCount") == 2686, "manual index total page count changed")
    indexed = {item["identifier"]: item for item in index["manuals"]}
    result: list[dict[str, Any]] = []
    for identifier, expected in MANUALS.items():
        require(identifier in indexed, f"manual missing from index: {identifier}")
        item = indexed[identifier]
        source_hash = expected["sha256"]
        path = ARCHIVE / "objects" / f"{source_hash}.pdf"
        require(path.is_file(), f"immutable manual object missing: {path}")
        require(digest(path) == source_hash, f"manual hash mismatch: {identifier}")
        require(item.get("sha256") == source_hash, f"manual index hash mismatch: {identifier}")
        require(item.get("pageCount") == expected["pages"], f"manual page count mismatch: {identifier}")
        require(item.get("qualityStatus") == "validated", f"manual is not validated: {identifier}")
        result.append(
            {
                "identifier": identifier,
                "sha256": source_hash,
                "pageCount": expected["pages"],
                "outlineEntryCount": item["outlineEntryCount"],
                "integrity": "passed",
            }
        )
    return result


def entry_name_evidence(
    catalogue: dict[str, Any], manual_identifier: str, excluded_names: set[str] | None = None
) -> list[dict[str, Any]]:
    excluded_names = excluded_names or set()
    manual_hash = MANUALS[manual_identifier]["sha256"]
    manual_path = ARCHIVE / "objects" / f"{manual_hash}.pdf"
    cache: dict[tuple[int, int], str] = {}
    records: list[dict[str, Any]] = []
    for entry in catalogue["entries"]:
        if entry["name"] in excluded_names:
            continue
        page_range = parse_range(entry["manualPages"])
        require(page_range is not None, f"non-numeric page range for {entry['name']}")
        if page_range not in cache:
            cache[page_range] = pdf_text(manual_path, *page_range)
        candidates = [entry["name"], *entry.get("aliases", [])]
        matched = next((candidate for candidate in candidates if normalize(candidate) in cache[page_range]), None)
        require(matched is not None, f"catalogue entry not found in declared pages: {entry['name']}")
        records.append(
            {
                "name": entry["name"],
                "declaredPages": entry["manualPages"],
                "matchedIdentity": matched,
                "status": "identity_found_in_declared_primary_source_pages",
            }
        )
    return records


def audit_supplements(
    instrument_catalogue: dict[str, Any], manifests: dict[str, dict[str, Any]]
) -> list[dict[str, Any]]:
    supplement = instrument_catalogue.get("supplementalSources", {})
    entries = supplement.get("entries", [])
    require(len(entries) == 16, "Quick Sampler supplement must contain 16 sources")
    hashes: set[str] = set()
    result: list[dict[str, Any]] = []
    for entry in entries:
        resource_id = entry["resourceID"]
        require(resource_id in manifests, f"supplement manifest missing: {resource_id}")
        audit = manifests[resource_id]
        require(audit.get("captureStatus") == "accepted", f"supplement not accepted: {resource_id}")
        require(audit.get("qualityStatus") == "validated", f"supplement not validated: {resource_id}")
        require(audit.get("localUseOnly") is True, f"supplement rights boundary changed: {resource_id}")
        source_hash = entry["sha256"]
        require(audit.get("sha256") == source_hash, f"supplement hash mismatch: {resource_id}")
        require(source_hash not in hashes, f"duplicate supplement payload: {resource_id}")
        hashes.add(source_hash)
        path = ARCHIVE / audit["localPath"]
        require(path.is_file() and digest(path) == source_hash, f"supplement object invalid: {resource_id}")
        result.append(
            {
                "resourceID": resource_id,
                "sha256": source_hash,
                "status": "accepted_validated_unique_immutable_local_use_only",
            }
        )
    return result


def audit_release_notes(manifests: dict[str, dict[str, Any]]) -> dict[str, Any]:
    require(RELEASE_RESOURCE_ID in manifests, "Logic 12.3 release-notes manifest missing")
    audit = manifests[RELEASE_RESOURCE_ID]
    require(audit.get("captureStatus") == "accepted", "release notes were not accepted")
    require(audit.get("qualityStatus") == "validated", "release notes were not validated")
    require(audit.get("sha256") == RELEASE_SHA256, "release-notes payload changed")
    path = ARCHIVE / audit["localPath"]
    require(path.is_file() and digest(path) == RELEASE_SHA256, "release-notes object integrity failed")
    rendered = subprocess.run(
        ["pandoc", "-f", "html", "-t", "plain", str(path)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    missing = [phrase for phrase in RELEASE_REQUIRED_PHRASES if phrase.casefold() not in rendered.casefold()]
    require(not missing, f"release-notes 12.3 delta phrases missing: {missing}")
    return {
        "resourceID": RELEASE_RESOURCE_ID,
        "sha256": RELEASE_SHA256,
        "retrievedAtUTC": audit["retrievedAtUTC"],
        "requiredDeltaEvidenceCount": len(RELEASE_REQUIRED_PHRASES),
        "status": "accepted_validated_immutable_and_12_3_delta_present",
        "warning": "Apple's release-notes page is mutable; this result applies only to the captured hash.",
    }


def main() -> int:
    manual_index = load_json(KNOWLEDGE / "logic-pro-12.3-manual-index.json")
    effects = load_json(KNOWLEDGE / "logic-pro-12.3-effects-knowledge.json")
    instruments = load_json(KNOWLEDGE / "logic-pro-12.3-instrument-knowledge.json")
    editor_tools = load_json(KNOWLEDGE / "logic-pro-12.3-editor-tool-knowledge.json")
    empirical_campaign = load_json(KNOWLEDGE / "logic-pro-12.3-empirical-campaign.json")
    core_priority = load_json(KNOWLEDGE / "logic-pro-12.3-core-effect-priority.json")
    manifests = validated_current_manifests()

    require(effects.get("entryCount") == 142 and len(effects.get("entries", [])) == 142,
            "effect catalogue must contain 142 entries")
    require(instruments.get("entryCount") == 28 and len(instruments.get("entries", [])) == 28,
            "instrument catalogue must contain 28 entries")
    require(editor_tools.get("entryCount") == 30 and len(editor_tools.get("entries", [])) == 30,
            "editor-tool catalogue must contain 30 entries")
    require(
        empirical_campaign.get("counts") == {
            "effectsAndNativeAudioTools": 142,
            "instrumentAndInstrumentUtilities": 28,
            "editorTools": 30,
            "totalIdentities": 200,
            "pedalboardEffects": 35,
            "pedalboardRoutingUtilities": 2,
        },
        "empirical campaign does not cover all 200 reviewed native identities",
    )
    campaign_entries = (
        empirical_campaign.get("effects", [])
        + empirical_campaign.get("instruments", [])
        + empirical_campaign.get("editorTools", [])
    )
    require(empirical_campaign.get("schemaVersion") == "1.2",
            "empirical campaign schema must include effect-family measurement profiles")
    status_counts = {
        status: sum(1 for entry in campaign_entries if entry.get("status") == status)
        for status in ("not_run", "partial", "complete")
    }
    require(sum(status_counts.values()) == len(campaign_entries),
            "empirical campaign contains an invalid status")
    require(empirical_campaign.get("statusCounts") == status_counts,
            "empirical campaign status counts are stale")
    require(empirical_campaign.get("claimBoundary", {}).get("empiricalCampaignComplete") is False,
            "incomplete empirical campaign was marked complete")
    require(core_priority.get("schemaVersion") == "1.0",
            "unsupported core-effect priority schema")
    priority_boundaries = core_priority.get("boundaries", {})
    for boundary in (
        "globalPluginUsageFrequencyClaimed",
        "artisticImportanceRankingClaimed",
        "fixedProcessingOrderClaimed",
        "automaticInsertionAuthorityClaimed",
    ):
        require(priority_boundaries.get(boundary) is False,
                f"core-effect priority overclaims {boundary}")
    require(priority_boundaries.get("listeningStillDecisive") is True,
            "core-effect priority removed listening authority")
    priority_case_evidence = core_priority.get("professionalCaseEvidence", {})
    require(priority_case_evidence.get("caseCount") == 58,
            "core-effect priority professional-case count changed")
    for source in priority_case_evidence.get("sources", []):
        source_path = (ROOT / source.get("path", "")).resolve()
        try:
            source_path.relative_to(ROOT)
        except ValueError:
            raise SystemExit("core-effect priority source escapes repository")
        require(source_path.is_file() and digest(source_path) == source.get("sha256"),
                f"core-effect priority source hash is stale: {source.get('path')}")
    priority_queue = core_priority.get("firstEmpiricalAndPracticeQueue", [])
    require(len(priority_queue) == 20,
            "core-effect priority must contain twenty first-queue identities")
    priority_names = [entry.get("name") for entry in priority_queue]
    require(len(priority_names) == len(set(priority_names)),
            "core-effect priority contains duplicate identities")
    decision_atlas_text = CORE_DECISION_ATLAS.read_text(encoding="utf-8")
    decision_headings = re.findall(r"^##\s+(.+?)\s*$", decision_atlas_text, re.MULTILINE)
    missing_decision_cards = [
        name for name in priority_names
        if not any(name in heading for heading in decision_headings)
    ]
    require(not missing_decision_cards,
            f"core-effect decision atlas lacks first-queue cards: {missing_decision_cards}")
    require("Current deep cards: all 20 first-queue processors" in decision_atlas_text,
            "core-effect decision atlas does not declare complete first-queue coverage")
    require(not any("Pedalboard" in heading or "Bitcrusher" in heading
                    for heading in decision_headings),
            "creative effects displaced the core decision-card lane")
    for entry in empirical_campaign.get("effects", []):
        require(isinstance(entry.get("measurementProfile"), str) and entry["measurementProfile"],
                f"effect has no measurement profile: {entry.get('identifier')}")
        fixtures = entry.get("requiredFixtures")
        require(isinstance(fixtures, list) and len(fixtures) == len(set(fixtures)),
                f"invalid or duplicate effect fixture list: {entry.get('identifier')}")
        require(set(fixtures).issubset(LOGIC_FIXTURE_FILES),
                f"effect references unknown fixture identities: {entry.get('identifier')}")
        require(isinstance(entry.get("requiredLanes"), list) and entry["requiredLanes"],
                f"effect has no required lane: {entry.get('identifier')}")
        require(all(isinstance(lane, str) and re.fullmatch(r"[a-z0-9_]+", lane)
                    for lane in entry["requiredLanes"]),
                f"effect has malformed lane identity: {entry.get('identifier')}")
        require(isinstance(entry.get("requiredDimensions"), list)
                and len(entry["requiredDimensions"]) == len(set(entry["requiredDimensions"])),
                f"effect has invalid campaign dimensions: {entry.get('identifier')}")
        require(all(isinstance(dimension, str) and re.fullmatch(r"[a-z0-9_]+", dimension)
                    for dimension in entry["requiredDimensions"]),
                f"effect has malformed dimension identity: {entry.get('identifier')}")
    empirical_run_evidence = audit_empirical_runs(campaign_entries)
    campaign_by_identifier = {entry["identifier"]: entry for entry in campaign_entries}
    effects_by_identifier = {entry["identifier"]: entry for entry in effects["entries"]}
    for expected_order, priority_entry in enumerate(priority_queue, start=1):
        identifier = priority_entry.get("identifier")
        require(priority_entry.get("order") == expected_order,
                f"core-effect priority order is not contiguous: {identifier}")
        require(identifier in effects_by_identifier,
                f"core-effect priority references unknown identity: {identifier}")
        effect = effects_by_identifier[identifier]
        require(priority_entry.get("name") == effect["name"]
                and priority_entry.get("family") == effect["family"]
                and priority_entry.get("reviewStatus") == effect["reviewStatus"]
                and priority_entry.get("empiricalStatus") == effect["empiricalStatus"],
                f"core-effect priority identity is stale: {identifier}")
        require(not effect["family"].startswith("pedalboard_"),
                f"Pedalboard subeffect displaced the core queue: {identifier}")
        campaign_entry = campaign_by_identifier[identifier]
        require(campaign_entry.get("measurementProfile", "").startswith("core_")
                and "core_effect_priority_lane" in campaign_entry.get("requiredLanes", []),
                f"core-effect identity has only a generic empirical profile: {identifier}")
    effect_context_status_counts = {"notRun": 0, "partial": 0, "complete": 0}
    for effect in effects["entries"]:
        campaign_entry = campaign_by_identifier[effect["identifier"]]
        expected_context_status = {
            "not_run": "notRun",
            "partial": "partial",
            "complete": "complete",
        }[campaign_entry["status"]]
        require(effect.get("empiricalStatus") == expected_context_status,
                f"provider-context empirical status is stale: {effect['identifier']}")
        require(effect.get("measuredRunIDs") == campaign_entry.get("measuredRunIDs"),
                f"provider-context run IDs are stale: {effect['identifier']}")
        summary = effect.get("empiricalEvidenceSummary")
        if expected_context_status == "notRun":
            require(summary is None, f"unmeasured effect has an empirical summary: {effect['identifier']}")
        else:
            require(isinstance(summary, str) and summary,
                    f"measured effect has no bounded provider summary: {effect['identifier']}")
        effect_context_status_counts[expected_context_status] += 1

    effect_evidence = entry_name_evidence(effects, "effects")
    instrument_evidence = entry_name_evidence(instruments, "instruments", {"Quick Sampler"})
    pedal_effects = [entry for entry in effects["entries"] if entry["family"].startswith("pedalboard_")]
    pedal_names = {entry["name"] for entry in pedal_effects}
    require(len(pedal_effects) == 37, "Pedalboard catalogue must contain 35 effects plus Mixer and Splitter")
    require({"Mixer", "Splitter"}.issubset(pedal_names), "Pedalboard routing utilities missing")
    pedal_campaign = [
        entry for entry in empirical_campaign["effects"]
        if entry["family"].startswith("pedalboard_")
    ]
    pedal_profile_counts = {
        profile: sum(1 for entry in pedal_campaign if entry["measurementProfile"] == profile)
        for profile in EXPECTED_PEDAL_MEASUREMENT_PROFILES
    }
    require(pedal_profile_counts == EXPECTED_PEDAL_MEASUREMENT_PROFILES,
            f"Pedalboard measurement-profile coverage changed: {pedal_profile_counts}")
    user_guide_path = ARCHIVE / "objects" / f"{MANUALS['user-guide']['sha256']}.pdf"
    tool_inventory_text = pdf_text(user_guide_path, 54, 60)
    editor_tool_evidence = []
    for entry in editor_tools["entries"]:
        require(normalize(entry["name"]) in tool_inventory_text,
                f"editor tool missing from User Guide inventory pages: {entry['name']}")
        require(entry.get("executionBoundary") == "advisory_only_no_tracksmith_host_authority",
                f"unsafe editor-tool authority: {entry['name']}")
        editor_tool_evidence.append(
            {
                "name": entry["name"],
                "status": "identity_found_in_user_guide_tool_inventory_and_advisory_only",
            }
        )

    result = {
        "schemaVersion": "1.0",
        "product": "TrackSmith",
        "logicVersionContext": "Logic Pro for Mac 12.3; installed host build 6674",
        "generatedDate": "2026-07-18",
        "epistemicStatus": {
            "documentaryCoverage": "complete_for_the_four_archived_manual_payloads_and_current_catalogues",
            "deepReviewClaim": "supported_by_human_review_ledgers_and_synthesis_atlases_not_by_this_script_alone",
            "empiricalTransferCharacterization": "incomplete_requires_disposable_copy_measurement_lane",
            "musicalUseUniversality": "not_claimed_context_and_listening_remain_decisive",
            "logicNativeExecutionAuthority": "none_advisory_knowledge_only",
        },
        "manualIntegrity": audit_manuals(manual_index),
        "catalogueCoverage": {
            "effects": {
                "entryCount": len(effect_evidence),
                "status": "all_entry_identities_found_in_declared_primary_source_page_ranges",
                "providerContextEmpiricalStatusCounts": effect_context_status_counts,
                "providerContextStatus": (
                    "direct-run identities are exposed as bounded evidence while "
                    "unmeasured identities remain explicitly notRun"
                ),
                "entries": effect_evidence,
            },
            "pedalboard": {
                "documentedEffectCount": len(pedal_effects) - 2,
                "routingUtilityCount": 2,
                "routingUtilities": ["Mixer", "Splitter"],
                "measurementProfileCounts": pedal_profile_counts,
                "status": "all_35_pedals_plus_both_utilities_have_effect_specific_measurement_profiles",
            },
            "instruments": {
                "entryCount": instruments["entryCount"],
                "pdfBackedEntryCount": len(instrument_evidence),
                "pdfBackedEntries": instrument_evidence,
                "quickSamplerSupplement": audit_supplements(instruments, manifests),
                "status": "27_entries_found_in_pdf_plus_quick_sampler_deep_read_from_16_canonical_live_guide_pages",
            },
            "editorTools": {
                "entryCount": len(editor_tool_evidence),
                "inventoryPages": "54-60",
                "entries": editor_tool_evidence,
                "status": "all_30_documented_editor_tool_identities_catalogued_with_state_scope_and_no_host_authority",
            },
        },
        "releaseNotes": audit_release_notes(manifests),
        "empiricalCampaign": {
            "path": "research/knowledge/logic-pro-12.3-empirical-campaign.json",
            "sha256": digest(KNOWLEDGE / "logic-pro-12.3-empirical-campaign.json"),
            "identityCount": len(campaign_entries),
            "statusCounts": status_counts,
            "status": (
                f"enumerated_with_{status_counts['partial']}_partial_and_"
                f"{status_counts['complete']}_complete_evidence_identities"
            ),
            "evidenceRuns": empirical_run_evidence,
            "warning": (
                "Documentary coverage is complete; empirical characterization is not. "
                "A partial status proves only the dimensions explicitly closed by its "
                "hash-validated run record."
            ),
        },
        "coreEffectPriority": {
            "path": "research/knowledge/logic-pro-12.3-core-effect-priority.json",
            "sha256": digest(KNOWLEDGE / "logic-pro-12.3-core-effect-priority.json"),
            "professionalCaseCount": priority_case_evidence["caseCount"],
            "firstQueueIdentityCount": len(priority_queue),
            "firstProcessingIdentity": priority_names[1],
            "creativePedalboardPriority": "after_core_processing_roles",
            "status": "source_hash_validated_role_weighted_priority_without_global_usage_claim",
        },
        "coreEffectDecisionAtlas": {
            "path": str(CORE_DECISION_ATLAS.relative_to(ROOT)),
            "sha256": digest(CORE_DECISION_ATLAS),
            "firstQueueCardsCovered": len(priority_names),
            "creativeEffectsDisplacedCoreLane": False,
            "status": "all_first_queue_processors_have_source_aware_decision_cards",
        },
        "atlasProvenance": {
            name: {"path": str(path.relative_to(ROOT)), "sha256": digest(path)}
            for name, path in ATLAS_PATHS.items()
        },
        "unclosedQuestions": [
            "Apple does not publish every proprietary transfer function, coefficient, oversampling mode, nonlinear state model, or tolerance.",
            "Documentation proves controls and stated behavior, not exact audible response for every parameter combination or signal.",
            "Musical suitability, source interactions, gain staging, stereo/mono translation, and artistic preference require measured renders and listening.",
            "The first native-effect render after insertion or a bypass/state transition may contain initialization behavior; repeatability claims require settled decoded-PCM repeats.",
            "Quick Sampler file-affecting commands require disposable-copy tests before TrackSmith may make stronger source-preservation claims.",
            "TrackSmith has no authority to execute Logic-native effects, instruments, editor tools, automation, routing, or file operations.",
        ],
    }
    OUTPUT.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"wrote {OUTPUT}: 4 manuals, {len(effect_evidence)} effects/tools, "
        f"{len(instrument_evidence)} PDF instruments + 16 Quick Sampler pages, "
        f"{len(editor_tool_evidence)} editor tools, empirical status counts {status_counts}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
