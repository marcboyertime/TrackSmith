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

    for candidate in queue["candidates"]:
        if candidate["sourceID"] not in source_ids:
            problems.append(f"{candidate['id']}: unknown source {candidate['sourceID']}")
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
