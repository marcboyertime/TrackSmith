#!/usr/bin/env python3
"""General Production Tutor v2 source and knowledge review pipeline.

Subcommands implement the review lifecycle end to end:

  register-source  Add a source to the registry with rights, tier, handling
                   class, and transcript/audiovisual provenance. Never fetches
                   anything: you supply what you lawfully have.
  extract          Turn a local reviewed text into candidate claims in the
                   review queue. Candidates are machineExtracted and cannot
                   ground an answer.
  review           Promote, dispute, supersede, or reject a candidate, with
                   reviewer identity and date recorded.
  audit            Fail-closed audit of the registry, queue, and generated
                   knowledge base.

Design rules this enforces:
  - A machine-extracted claim is never trusted knowledge.
  - A source requiring audiovisual review cannot ground a trusted claim until
    that review is recorded.
  - Tier C (forums, comments, unverified short-form) can never be promoted to
    reviewed; it may only sit as discovery material.
  - Full transcripts are never written into the repository; only content
    hashes, locators, and paraphrased candidate claims.

State lives in research/knowledge/general-tutor-source-registry.json and
research/knowledge/general-tutor-review-queue.json.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys
from datetime import date

ROOT = pathlib.Path(__file__).resolve().parents[2]
K = ROOT / "research/knowledge"
REGISTRY = K / "general-tutor-source-registry.json"
QUEUE = K / "general-tutor-review-queue.json"
GENERATED = (
    ROOT / "packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift"
)
COMMUNITY_PACKAGES = {
    "community-vocal-quantization-v1": {
        "path": K / "community-vocal-quantization-v1", "canonical": 214,
        "original": {"claim": "candidate_not_reviewed", "strategy": "candidate_not_reviewed", "procedure": "candidate_requires_installed_logic_verification"},
    },
    "community-level-balancing-eq-v1": {
        "path": K / "community-level-balancing-eq-v1", "canonical": 238,
        "original": {"claim": "candidate_not_yet_human_reviewed", "strategy": "candidate_not_yet_human_reviewed", "procedure": "candidate_not_yet_human_reviewed"},
    },
    "community-compression-arrangement-frequency-allocation-v1": {
        "path": K / "community-compression-arrangement-frequency-allocation-v1", "canonical": 350,
        "original": {"claim": "candidate_not_yet_human_reviewed", "strategy": "candidate_not_yet_human_reviewed", "procedure": "candidate_not_yet_human_reviewed"},
    },
    "community-reverb-delay-v1": {
        "path": K / "community-reverb-delay-v1", "canonical": 300,
        "original": {"claim": "candidate_not_yet_human_reviewed", "strategy": "candidate_not_yet_human_reviewed", "procedure": "candidate_not_yet_human_reviewed"},
        "procedureVerification": "candidate_unverified_on_installed_logic",
    },
}


def stable_contract_packages() -> dict[str, dict]:
    """Discover stable packages from their checked-in manifests and source rows.

    This keeps the audit in lockstep with the registry/staged package contract:
    a newly registered contiguous stable package cannot silently evade its native
    candidate, source-evidence, and procedure-authority audit.
    """
    root = ROOT / "research/community_knowledge/packages"
    package_registry = json.loads((ROOT / "research/community_knowledge/package_registry.json").read_text(encoding="utf-8"))
    registered = [
        row for row in package_registry.get("packages", [])
        if isinstance(row.get("package_id"), str) and row["package_id"].startswith("tracksmith-corpus-")
    ]
    sequences = sorted(row.get("package_number") for row in registered)
    if sequences != list(range(5, len(sequences) + 5)):
        raise ValueError("stable package registry sequence is not contiguous from package 5")
    registered_ids = {row["package_id"] for row in registered}
    if len(registered_ids) != len(registered):
        raise ValueError("stable package registry has duplicate package IDs")
    discovered: dict[str, dict] = {}
    for row in sorted(registered, key=lambda value: value["package_number"]):
        package = root / row["package_id"]
        manifest_path = package / "package_manifest.json"
        if not manifest_path.is_file():
            raise ValueError(f"registered stable package is missing manifest: {package}")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest.get("package_contract") != "tracksmith-corpus-package":
            continue
        package_id = manifest.get("package_id")
        counts = manifest.get("record_counts", {})
        sources = [
            json.loads(line)
            for line in (package / "sources/source_registry.jsonl").read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        if not isinstance(package_id, str) or package_id != package.name or not isinstance(counts.get("canonical_qa"), int):
            raise ValueError(f"invalid stable package manifest: {package}")
        if manifest.get("package_number") != row["package_number"]:
            raise ValueError(f"stable package registry/manifest sequence drift: {package_id}")
        if manifest.get("package_type") == "integration_framework":
            # P16 is a zero-subject integration/audit package. Its 17 source
            # records remain outside candidate knowledge, so force that
            # boundary here instead of trying to infer a review partition from
            # deliberately empty claim/strategy/procedure files.
            zero_subject_kinds = {
                "canonical_qa", "claim_candidates", "contradictions",
                "logic_procedure_candidates", "multiturn_scenarios",
                "myths_and_antipatterns", "provenance", "retrieval_evaluations",
                "strategy_candidates", "user_utterances",
            }
            if row.get("package_type") != "integration_framework" or row.get("runtime_resource") != "none":
                raise ValueError(f"integration package registry/runtime contract drift: {package_id}")
            if any(counts.get(kind) != 0 for kind in zero_subject_kinds):
                raise ValueError(f"integration package has subject records: {package_id}")
            continue
        candidate_paths = {
            "claim": package / "knowledge_candidates/claims.jsonl",
            "strategy": package / "knowledge_candidates/strategies.jsonl",
            "procedure": package / "knowledge_candidates/logic_procedures.jsonl",
        }
        candidate_contracts = {}
        for kind, candidate_path in candidate_paths.items():
            candidates = [
                json.loads(line)
                for line in candidate_path.read_text(encoding="utf-8").splitlines()
                if line.strip()
            ]
            if len(candidates) != counts["canonical_qa"]:
                raise ValueError(f"stable package raw {kind} count drift: {package_id}")
            original_reviews = {
                candidate.get("original_review_state") or candidate.get("review_state")
                for candidate in candidates
            }
            original_verifications = {
                candidate.get("original_verification_status") or candidate.get("verification_status")
                for candidate in candidates
            }
            if len(original_reviews) != 1 or len(original_verifications) != 1:
                raise ValueError(f"stable package raw {kind} provenance is not a uniform exact partition: {package_id}")
            candidate_contracts[kind] = {
                "originalReviewStatus": next(iter(original_reviews)),
                "originalVerificationStatus": next(iter(original_verifications)),
            }
            if kind == "procedure":
                logic_verifications = {
                    candidate.get("logic_verification_status")
                    for candidate in candidates
                    if candidate.get("logic_verification_status") is not None
                }
                if len(logic_verifications) > 1:
                    raise ValueError(f"stable package raw procedure logic verification is not uniform: {package_id}")
                candidate_contracts[kind]["logicVerificationStatus"] = (
                    next(iter(logic_verifications)) if logic_verifications else None
                )
        discovered[package_id] = {
            "path": package,
            "canonical": counts["canonical_qa"],
            "candidateContracts": candidate_contracts,
            "sourceContracts": {
                # Stable packages may carry a newer native review state while
                # preserving a discovery-only original state.  The registry
                # intentionally audits that immutable provenance, not a
                # promotion-like substitution of the current review label.
                row["id"]: (row.get("evidence_class"), row.get("original_review_state") or row.get("review_state"))
                for row in sources
            },
        }
    staged_ids = {
        json.loads(path.read_text(encoding="utf-8")).get("package_id")
        for path in root.glob("tracksmith-corpus-*/package_manifest.json")
        if json.loads(path.read_text(encoding="utf-8")).get("package_contract") == "tracksmith-corpus-package"
    }
    if staged_ids != registered_ids:
        raise ValueError("stable package registry/staged manifest identity drift")
    return discovered


COMMUNITY_PACKAGES.update(stable_contract_packages())

STABLE_SOURCE_TIERS = {
    "official_documentation": "tierAPrimaryOrDirect",
    "product_documentation": "tierAPrimaryOrDirect",
    "primary_research": "tierAPrimaryOrDirect",
    "professional_practice": "tierBReviewedProfessionalPractice",
    "specialist_discussion": "tierCDiscoveryOrAnecdotal",
    "community_pattern": "tierCDiscoveryOrAnecdotal",
    "community_anecdote": "tierCDiscoveryOrAnecdotal",
}

VALID_TIERS = {
    "tierAPrimaryOrDirect",
    "tierBReviewedProfessionalPractice",
    "tierCDiscoveryOrAnecdotal",
}
VALID_HANDLING = {
    "openDocumentation",
    "licensedLocalReviewOnly",
    "publicWebMetadataOnly",
    "userOwnedLocalOnly",
    "trackSmithGenerated",
}
VALID_STATES = {
    "discovered", "acquired", "machineExtracted", "awaitingReview",
    "reviewed", "directlyVerified", "disputed", "superseded", "rejected",
}
TRUSTED_STATES = {"reviewed", "directlyVerified"}

# Claims that depend on hearing or seeing something cannot rest on a
# transcript alone.
AUDIOVISUAL_MARKERS = [
    "sounds", "sounded", "listen", "hear", "audible", "a/b", "compare",
    "on screen", "you can see", "the meter", "waveform", "setting shown",
]


def load(path: pathlib.Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def save(path: pathlib.Path, data):
    path.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


def fail(message: str) -> None:
    print(f"PIPELINE_ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


# ------------------------------------------------------------ register-source


def cmd_register_source(args) -> int:
    registry = load(REGISTRY, {"schemaVersion": "1.0", "sources": []})
    if any(s["id"] == args.id for s in registry["sources"]):
        fail(f"source {args.id} is already registered; use --supersede to replace it")
    if args.tier not in VALID_TIERS:
        fail(f"invalid tier {args.tier}")
    if args.handling not in VALID_HANDLING:
        fail(f"invalid handling class {args.handling}")
    if not args.rights:
        fail("a rights basis is required; state how you lawfully hold this source")

    hashes = []
    if args.local_file:
        path = pathlib.Path(args.local_file)
        if not path.exists():
            fail(f"local file not found: {path}")
        hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())

    entry = {
        "id": args.id,
        "type": args.type,
        "title": args.title,
        "creatorOrPublisher": args.creator,
        "locator": args.locator,
        "publicationDate": args.published,
        "retrievalDate": args.retrieved or date.today().isoformat(),
        "exactVersion": args.version,
        "rightsBasis": args.rights,
        "handlingClass": args.handling,
        "tier": args.tier,
        "transcriptAvailable": args.transcript,
        "transcriptIsAutomatic": args.auto_transcript,
        "requiresAudiovisualReview": args.requires_av,
        "audiovisualReviewCompleted": False,
        "contentSHA256": hashes,
        "limitations": args.limitation or [],
        "supersededBy": None,
        "reviewState": "acquired" if hashes or args.locator else "discovered",
    }
    if args.auto_transcript and not args.requires_av:
        entry["limitations"].append(
            "Automatic captions: wording may be mis-transcribed, especially plug-in and product names."
        )
    registry["sources"].append(entry)
    save(REGISTRY, registry)
    print(f"REGISTERED {args.id} tier={args.tier} state={entry['reviewState']}")
    return 0


# -------------------------------------------------------------------- extract


def cmd_extract(args) -> int:
    registry = load(REGISTRY, {"schemaVersion": "1.0", "sources": []})
    source = next((s for s in registry["sources"] if s["id"] == args.source), None)
    if source is None:
        fail(f"unknown source {args.source}; register it first")
    if source["tier"] == "tierCDiscoveryOrAnecdotal" and not args.discovery_only:
        fail(
            "Tier C sources may only produce discovery notes. Re-run with "
            "--discovery-only, or find a better source for this claim."
        )

    path = pathlib.Path(args.text)
    if not path.exists():
        fail(f"text file not found: {path}")
    body = path.read_text(encoding="utf-8")

    queue = load(QUEUE, {"schemaVersion": "1.0", "candidates": []})
    existing = {c["id"] for c in queue["candidates"]}

    # Sentence-level candidate extraction. Deliberately dumb: a human reviews
    # every candidate, so recall matters more than precision here.
    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", body) if len(s.strip()) > 40]
    added = 0
    for index, sentence in enumerate(sentences[: args.limit]):
        cid = f"cand.{args.source}.{index:03d}"
        if cid in existing:
            continue
        lowered = sentence.lower()
        needs_av = any(marker in lowered for marker in AUDIOVISUAL_MARKERS)
        queue["candidates"].append(
            {
                "id": cid,
                "sourceID": args.source,
                "claimText": sentence,
                "locator": args.locator,
                "reviewState": "machineExtracted",
                "dependsOnAudiovisual": needs_av,
                "extractedAt": date.today().isoformat(),
                "reviewer": None,
                "reviewedAt": None,
                "reviewNote": None,
                "discoveryOnly": bool(args.discovery_only),
            }
        )
        added += 1
    save(QUEUE, queue)
    print(f"EXTRACTED {added} candidate(s) from {args.source} (state=machineExtracted)")
    print("Candidates cannot ground an answer until reviewed.")
    return 0


# --------------------------------------------------------------------- review


def cmd_review(args) -> int:
    if args.state not in VALID_STATES:
        fail(f"invalid review state {args.state}")
    queue = load(QUEUE, {"schemaVersion": "1.0", "candidates": []})
    candidate = next((c for c in queue["candidates"] if c["id"] == args.id), None)
    if candidate is None:
        fail(f"unknown candidate {args.id}")

    registry = load(REGISTRY, {"schemaVersion": "1.0", "sources": []})
    source = next((s for s in registry["sources"] if s["id"] == candidate["sourceID"]), None)
    if source is None:
        fail(f"candidate {args.id} references unregistered source")

    if args.state in TRUSTED_STATES:
        if not args.reviewer:
            fail("promoting a candidate requires --reviewer")
        if candidate.get("candidateKind") == "procedure":
            fail(
                "procedure candidates require named installed-Logic verification and "
                "TutorProcedureCatalog regeneration; generic queue promotion is forbidden"
            )
        if candidate.get("discoveryOnly"):
            fail("discovery-only material cannot be promoted to trusted knowledge")
        if source["tier"] == "tierCDiscoveryOrAnecdotal":
            fail("Tier C sources cannot ground trusted knowledge")
        if source.get("supersededBy"):
            fail("this source has been superseded")
        if candidate.get("dependsOnAudiovisual") and not source.get("audiovisualReviewCompleted"):
            fail(
                "this claim depends on hearing or seeing the source. Record the "
                "audiovisual review first: `mark-av-reviewed --source "
                f"{source['id']}`"
            )

    candidate["reviewState"] = args.state
    candidate["reviewer"] = args.reviewer
    candidate["reviewedAt"] = date.today().isoformat()
    candidate["reviewNote"] = args.note
    if args.accepted_text:
        candidate["acceptedClaimText"] = args.accepted_text
    save(QUEUE, queue)
    print(f"REVIEWED {args.id} -> {args.state} by {args.reviewer or 'unspecified'}")
    return 0


def cmd_mark_av_reviewed(args) -> int:
    registry = load(REGISTRY, {"schemaVersion": "1.0", "sources": []})
    source = next((s for s in registry["sources"] if s["id"] == args.source), None)
    if source is None:
        fail(f"unknown source {args.source}")
    if not args.reviewer:
        fail("recording an audiovisual review requires --reviewer")
    source["audiovisualReviewCompleted"] = True
    source["audiovisualReviewBy"] = args.reviewer
    source["audiovisualReviewAt"] = date.today().isoformat()
    source["audiovisualReviewNote"] = args.note
    save(REGISTRY, registry)
    print(f"AV_REVIEW_RECORDED {args.source} by {args.reviewer}")
    print("Only claim what you actually watched and heard.")
    return 0


# ---------------------------------------------------------------------- audit


def cmd_audit(args) -> int:
    problems = []
    registry = load(REGISTRY, {"schemaVersion": "1.0", "sources": []})
    queue = load(QUEUE, {"schemaVersion": "1.0", "candidates": []})

    # The candidate corpus has four intentionally distinct original states.
    # Audit them here as native state, not merely in the package's standalone
    # validator, so a queue rewrite cannot obscure an accidental promotion.
    for package_id, spec in COMMUNITY_PACKAGES.items():
        if not spec["path"].exists():
            continue
        try:
            canonical_rows = [json.loads(line) for line in (spec["path"] / "corpus/canonical_qa.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
            if len(canonical_rows) != spec["canonical"] or any(row.get("review_status") != "candidate_not_yet_human_reviewed" for row in canonical_rows):
                if len(canonical_rows) != spec["canonical"] or any(row.get("review_state") != "candidate_not_yet_human_reviewed" for row in canonical_rows):
                    problems.append(f"{package_id}: canonical original status/count drift")
            for kind, contract in spec.get("candidateContracts", {}).items():
                imported = [item for item in queue["candidates"] if item.get("candidateCorpus") == package_id and item.get("candidateKind") == kind]
                if len(imported) != spec["canonical"] or any(item.get("originalReviewStatus") != contract["originalReviewStatus"] or item.get("originalVerificationStatus") != contract["originalVerificationStatus"] for item in imported):
                    problems.append(f"{package_id}: {kind} original status/count drift")
                logic_verification = contract.get("logicVerificationStatus") if kind == "procedure" else None
                if kind == "procedure" and any(
                    (logic_verification is not None and item.get("logicVerificationStatus") != logic_verification) or
                    item.get("candidatePayload", {}).get("execution_authority") is not False or
                    (item.get("candidatePayload", {}).get("user_performs_every_action") is not True and item.get("userPerformsEveryAction") is not True)
                    for item in imported
                ):
                    problems.append(f"{package_id}: procedure verification/authority provenance drift")
        except (OSError, json.JSONDecodeError) as error:
            problems.append(f"{package_id}: status audit unreadable: {error}")

    source_ids = set()
    for source in registry["sources"]:
        if source["id"] in source_ids:
            problems.append(f"duplicate source id {source['id']}")
        source_ids.add(source["id"])
        if source["tier"] not in VALID_TIERS:
            problems.append(f"{source['id']}: invalid tier")
        if source["handlingClass"] not in VALID_HANDLING:
            problems.append(f"{source['id']}: invalid handling class")
        if not source.get("rightsBasis"):
            problems.append(f"{source['id']}: missing rights basis")
        if source.get("candidateCorpus") == "community-reverb-delay-v1" and (source.get("reviewState") != "acquired" or source.get("originalReviewStatus") != "source_registered_not_full_claim_review"):
            problems.append(f"{source['id']}: package-4 source review boundary drift")
        stable_spec = COMMUNITY_PACKAGES.get(source.get("candidateCorpus"))
        source_contract = (stable_spec or {}).get("sourceContracts", {}).get(source["id"])
        if source_contract:
            evidence_class, review_status = source_contract
            if source.get("originalEvidenceClass") != evidence_class or source.get("originalReviewStatus") != review_status:
                problems.append(f"{source['id']}: stable-package source evidence/review provenance drift")
            expected_tier = STABLE_SOURCE_TIERS.get(evidence_class)
            if expected_tier is None or source.get("tier") != expected_tier:
                problems.append(f"{source['id']}: stable-package source tier boundary drift")
        if source.get("candidateCorpus") == "tracksmith-corpus-012-recording-latency-monitoring-comping-punch" and source.get("originalEvidenceClass") == "primary_research":
            if source.get("originalReviewStatus") != "candidate_reviewed_primary_research" or source.get("type") != "searchDiscoveryOnly" or source.get("handlingClass") != "publicWebMetadataOnly":
                problems.append(f"{source['id']}: P12 primary research must remain metadata-only discovery provenance")

    candidate_ids = set()
    for candidate in queue["candidates"]:
        if candidate["id"] in candidate_ids:
            problems.append(f"duplicate candidate id {candidate['id']}")
        candidate_ids.add(candidate["id"])
        if candidate["sourceID"] not in source_ids:
            problems.append(f"{candidate['id']}: unknown source {candidate['sourceID']}")
        partitions = {
            "authoritativeSupportingSourceIDs": "tierAPrimaryOrDirect",
            "standardsSourceIDs": "tierAPrimaryOrDirect",
            "primaryResearchSourceIDs": "tierAPrimaryOrDirect",
            "professionalPracticeSourceIDs": "tierBReviewedProfessionalPractice",
            "discoveryLanguageSourceIDs": "tierCDiscoveryOrAnecdotal",
        }
        partitioned_ids = []
        for field, expected_tier in partitions.items():
            values = candidate.get(field, [])
            if not isinstance(values, list):
                problems.append(f"{candidate['id']}: {field} is not a list")
                continue
            for source_id in values:
                partitioned_ids.append(source_id)
                source = next((s for s in registry["sources"] if s["id"] == source_id), None)
                if source is None:
                    problems.append(f"{candidate['id']}: unknown provenance source {source_id}")
                elif source["tier"] != expected_tier:
                    problems.append(f"{candidate['id']}: {source_id} in wrong provenance partition")
        if candidate.get("sourceIDs") and sorted(set(candidate["sourceIDs"])) != sorted(set(partitioned_ids)):
            problems.append(f"{candidate['id']}: sourceIDs do not equal partitioned provenance")
        if candidate.get("candidateCorpus") in COMMUNITY_PACKAGES and COMMUNITY_PACKAGES[candidate.get("candidateCorpus")].get("sourceContracts"):
            primary = candidate.get("primaryResearchSourceIDs", [])
            if not isinstance(primary, list) or any(next((s for s in registry["sources"] if s["id"] == source_id), {}).get("originalEvidenceClass") != "primary_research" for source_id in primary):
                problems.append(f"{candidate['id']}: primary research provenance drift")
            standards = candidate.get("standardsSourceIDs", [])
            if not isinstance(standards, list) or any(next((s for s in registry["sources"] if s["id"] == source_id), {}).get("originalEvidenceClass") != "primary_research" for source_id in standards):
                problems.append(f"{candidate['id']}: standards provenance drift")
        if candidate.get("candidateCorpus") in COMMUNITY_PACKAGES:
            if candidate.get("reviewState") == "awaitingReview":
                if any(candidate.get(key) is not None for key in ("reviewer", "reviewedAt", "reviewNote")):
                    problems.append(f"{candidate['id']}: awaiting review candidate has a review event")
            elif not candidate.get("reviewer") or not candidate.get("reviewedAt"):
                problems.append(f"{candidate['id']}: changed imported candidate lacks named reviewer/date")
            if candidate.get("candidateKind") not in {"claim", "strategy", "procedure"}:
                problems.append(f"{candidate['id']}: missing candidate kind")
            if not candidate.get("canonicalQAID") or not candidate.get("originalReviewStatus"):
                problems.append(f"{candidate['id']}: missing canonical/status provenance")
            if candidate.get("candidateKind") == "procedure" and candidate.get("reviewState") in TRUSTED_STATES:
                problems.append(f"{candidate['id']}: procedure candidate cannot become trusted without installed-Logic catalog regeneration")
        if candidate["reviewState"] in TRUSTED_STATES:
            if not candidate.get("reviewer"):
                problems.append(f"{candidate['id']}: trusted without a reviewer")
            source = next(s for s in registry["sources"] if s["id"] == candidate["sourceID"])
            if candidate.get("dependsOnAudiovisual") and not source.get("audiovisualReviewCompleted"):
                problems.append(
                    f"{candidate['id']}: trusted but its source still needs audiovisual review"
                )
            if source["tier"] == "tierCDiscoveryOrAnecdotal":
                problems.append(f"{candidate['id']}: Tier C source promoted to trusted")
            if not candidate.get("authoritativeSupportingSourceIDs", []) and not candidate.get("professionalPracticeSourceIDs", []):
                problems.append(f"{candidate['id']}: Tier C-only provenance promoted to trusted")

    # Generated base: every trusted claim must resolve to a usable source.
    if GENERATED.exists():
        text = GENERATED.read_text(encoding="utf-8")
        start, end = text.find('#"""'), text.rfind('"""#')
        if start != -1 and end != -1:
            base = json.loads(text[start + 4 : end])
            base_sources = {s["id"]: s for s in base.get("sources", [])}
            for claim in base.get("claims", []):
                source = base_sources.get(claim["sourceID"])
                if source is None:
                    problems.append(f"generated claim {claim['id']}: unknown source")
                    continue
                if claim["reviewState"] in TRUSTED_STATES:
                    if source.get("tier") == "tierCDiscoveryOrAnecdotal":
                        problems.append(f"generated claim {claim['id']}: Tier C source is trusted")
                    if source.get("supersededBy"):
                        problems.append(f"generated claim {claim['id']}: superseded source")
                    if source.get("requiresAudiovisualReview") and not source.get(
                        "audiovisualReviewCompleted"
                    ):
                        problems.append(
                            f"generated claim {claim['id']}: source needs audiovisual review"
                        )
            counts = {
                "sources": len(base.get("sources", [])),
                "claims": len(base.get("claims", [])),
                "strategies": len(base.get("strategies", [])),
                "concepts": len(base.get("concepts", [])),
                "contradictions": len(base.get("contradictions", [])),
            }
            # Candidate-corpus provenance may reach GeneralTutor only as
            # source metadata.  Derive every package namespace/count from the
            # registry so a later package cannot bypass this guard by lacking a
            # new package-specific audit branch.
            source_only_packages = {}
            for source in registry["sources"]:
                identifier = str(source.get("id", ""))
                match = re.match(r"^(pkg\d+)\.source\.", identifier)
                if source.get("candidateCorpus") and match:
                    source_only_packages.setdefault(match.group(1), set()).add(identifier)
            for namespace, expected_ids in sorted(source_only_packages.items()):
                generated = {item["id"] for item in base.get("sources", []) if str(item.get("id", "")).startswith(namespace + ".source.")}
                forbidden = tuple(namespace + suffix for suffix in (".qa.", ".claim.", ".strategy.", ".procedure.", ".contradiction.", ".myth."))
                if generated != expected_ids or any(token in text for token in forbidden):
                    problems.append(f"generated {namespace} source-only projection/leakage drift")
            registry_source_ids = {item["id"] for item in registry["sources"]}
            generated_source_ids = set(base_sources)
            if not registry_source_ids.issubset(generated_source_ids):
                problems.append("generated source registry projection drift")
            # The builder adds a small set of reviewed, non-registry curated
            # sources.  Count those from the generated source-only projection,
            # while the registry contributes every imported provenance source.
            expected_source_count = len(registry_source_ids) + len(generated_source_ids - registry_source_ids)
            if counts != {"sources": expected_source_count, "claims": 458, "strategies": 78, "concepts": 12, "contradictions": 2}:
                problems.append("generated non-source trusted projection count drift")
        else:
            counts = {}
    else:
        counts = {}

    if problems:
        for problem in problems:
            print(f"AUDIT_FAIL {problem}", file=sys.stderr)
        return 1

    trusted = sum(1 for c in queue["candidates"] if c["reviewState"] in TRUSTED_STATES)
    print(
        f"GENERAL_TUTOR_KNOWLEDGE_AUDIT_OK registeredSources={len(registry['sources'])} "
        f"candidates={len(queue['candidates'])} trustedCandidates={trusted} generated={counts}"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    reg = sub.add_parser("register-source")
    reg.add_argument("--id", required=True)
    reg.add_argument("--title", required=True)
    reg.add_argument("--type", default="document")
    reg.add_argument("--creator")
    reg.add_argument("--locator")
    reg.add_argument("--published")
    reg.add_argument("--retrieved")
    reg.add_argument("--version")
    reg.add_argument("--rights", required=True)
    reg.add_argument("--handling", required=True)
    reg.add_argument("--tier", required=True)
    reg.add_argument("--local-file")
    reg.add_argument("--transcript", action="store_true")
    reg.add_argument("--auto-transcript", action="store_true")
    reg.add_argument("--requires-av", action="store_true")
    reg.add_argument("--limitation", action="append")
    reg.add_argument("--supersede")
    reg.set_defaults(func=cmd_register_source)

    ext = sub.add_parser("extract")
    ext.add_argument("--source", required=True)
    ext.add_argument("--text", required=True, help="local reviewed text file")
    ext.add_argument("--locator")
    ext.add_argument("--limit", type=int, default=200)
    ext.add_argument("--discovery-only", action="store_true")
    ext.set_defaults(func=cmd_extract)

    rev = sub.add_parser("review")
    rev.add_argument("--id", required=True)
    rev.add_argument("--state", required=True)
    rev.add_argument("--reviewer")
    rev.add_argument("--note")
    rev.add_argument("--accepted-text")
    rev.set_defaults(func=cmd_review)

    av = sub.add_parser("mark-av-reviewed")
    av.add_argument("--source", required=True)
    av.add_argument("--reviewer")
    av.add_argument("--note")
    av.set_defaults(func=cmd_mark_av_reviewed)

    aud = sub.add_parser("audit")
    aud.set_defaults(func=cmd_audit)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
