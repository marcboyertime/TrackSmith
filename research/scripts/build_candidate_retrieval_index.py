#!/usr/bin/env python3
"""Build and audit the Package 019 runtime-only candidate retrieval index.

The input is the P16-approved projection already materialized as the fifteen
runtime JSON resources.  This tool is deliberately outside the application
target: application startup never decodes these files or creates an index.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RESOURCES = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources"
RAW_PROJECTION = ROOT / "research/community_knowledge/runtime_projection/p16"
PROJECTION = ROOT / "research/community_knowledge/reconciliations/tracksmith-corpus-016-integration-retrieval-quality-control-runtime-projection-migration.json"
DATABASE = RESOURCES / "CandidateRetrieval.sqlite"
MANIFEST = RESOURCES / "CandidateRetrieval.manifest.json"
SCHEMA_VERSION = "package018-candidate-index/1"
RETRIEVAL_POLICY_VERSION = "package019-bm25-ordered6-domain-diverse/1"
TOOL_VERSION = "package019-index-builder/1"
EXPECTED_CARD_COUNT = 6212
FORBIDDEN_MARKERS = ("tracksmith-corpus-017", "golden", "expected_answer", "expected answer", "fixture_alias", "evaluation_case")
STOP_TERMS = {"a", "an", "and", "are", "best", "but", "cannot", "control", "detail", "do", "find", "for", "from", "get", "how", "i", "if", "in", "is", "it", "like", "logic", "make", "mix", "my", "need", "not", "of", "or", "should", "so", "the", "this", "to", "too", "what", "when", "why", "with", "wrong"}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize(text: str) -> str:
    values = []
    for value in re.findall(r"[a-z0-9]+", text.lower().replace("_", " ")):
        if value in STOP_TERMS or len(value) <= 1:
            continue
        if value.endswith("ing") and len(value) > 5:
            value = value[:-3]
        elif value.endswith("s") and len(value) > 3:
            value = value[:-1]
        # A single consonant skeleton is a compact, general tolerance for a
        # dropped vowel (for example, a casual misspelling).  We keep either
        # the skeleton or the word -- never both -- so one lexical fact cannot
        # receive two votes.
        skeleton = re.sub(r"[aeiou]", "", value)
        if len(value) >= 5 and len(skeleton) >= 3:
            value = skeleton
        values.append(value)
    return " ".join(values)


def source_files() -> list[Path]:
    files = sorted(RAW_PROJECTION.glob("*.json"))
    if len(files) != 15:
        raise ValueError(f"expected 15 approved projection resources, found {len(files)}")
    return files


def load_projection() -> tuple[list[dict], list[dict]]:
    projection = json.loads(PROJECTION.read_text())
    if projection.get("policyVersion") != "package16-runtime-projection/1.0":
        raise ValueError("P16 runtime projection policy drift")
    expected = {Path(row["resource"]).name: row for row in projection.get("resources", [])}
    if set(expected) != {path.name for path in source_files()} or len(expected) != 15:
        raise ValueError("P16 reconciliation resource set drift")
    cards: list[dict] = []
    sources: list[dict] = []
    for path in source_files():
        raw = path.read_bytes()
        package = json.loads(raw)
        package_id = package["packageID"]
        reconciliation = expected[path.name]
        if reconciliation.get("packageID") != package_id or reconciliation.get("newSHA256") != sha256(raw):
            raise ValueError(f"P16 reconciliation checksum/provenance drift: {path.name}")
        if "017" in package_id or package_id == "tracksmith-corpus-017-golden-tutor-conversations-level-adaptation":
            raise ValueError("P17 is forbidden from the runtime index")
        canonical = package.get("canonicalCards", [])
        if not canonical:
            raise ValueError(f"empty canonical projection: {path.name}")
        utterances = package.get("utterances", [])
        if reconciliation.get("canonicalCardCount") != len(canonical) or reconciliation.get("retainedUtteranceCount") != len(utterances):
            raise ValueError(f"P16 reconciliation count drift: {path.name}")
        by_card: dict[str, list[str]] = {}
        for utterance in utterances:
            by_card.setdefault(utterance["canonicalID"], []).append(utterance["text"])
        for card in canonical:
            if card.get("packageID") != package_id or not all(isinstance(card.get(key), str) and card.get(key) for key in ("id", "version", "domain", "category", "title", "question", "evidenceClass")):
                raise ValueError(f"card package mismatch: {card.get('id')}")
            serialized = json.dumps(card, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
            lower = serialized.lower()
            if any(marker in lower for marker in FORBIDDEN_MARKERS):
                raise ValueError(f"forbidden runtime marker in {card.get('id')}")
            cards.append({"card": card, "payload": serialized, "utterances": sorted(by_card.get(card["id"], []))})
        sources.append({
            "resource": path.name,
            "package_id": package_id,
            "package_manifest_sha256": package["packageManifestSHA256"],
            "sha256": sha256(raw),
            "canonical_count": len(canonical),
            "utterance_count": len(utterances),
        })
    cards.sort(key=lambda item: item["card"]["id"])
    if len(cards) != EXPECTED_CARD_COUNT:
        raise ValueError(f"expected {EXPECTED_CARD_COUNT} cards, found {len(cards)}")
    if len({item["card"]["id"] for item in cards}) != len(cards):
        raise ValueError("duplicate canonical card id")
    return cards, sources


def build(database: Path) -> dict:
    cards, sources = load_projection()
    database.parent.mkdir(parents=True, exist_ok=True)
    if database.exists():
        database.unlink()
    con = sqlite3.connect(database)
    try:
        con.executescript("""
            PRAGMA page_size=4096;
            PRAGMA journal_mode=OFF;
            PRAGMA synchronous=OFF;
            PRAGMA temp_store=MEMORY;
            PRAGMA auto_vacuum=NONE;
            CREATE TABLE metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL) WITHOUT ROWID;
            CREATE TABLE cards (
                id TEXT PRIMARY KEY NOT NULL,
                package_id TEXT NOT NULL,
                version TEXT NOT NULL,
                domain TEXT NOT NULL,
                category TEXT NOT NULL,
                source_types TEXT NOT NULL,
                evidence_class TEXT NOT NULL,
                current_context INTEGER NOT NULL,
                logic_version TEXT NOT NULL,
                role_facets TEXT NOT NULL,
                section_facets TEXT NOT NULL,
                question_key TEXT NOT NULL,
                primary_terms TEXT NOT NULL,
                facet_terms TEXT NOT NULL,
                context_terms TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            -- Contentless FTS stores only postings.  Card JSON is held once in
            -- `cards` and read only for the selected bounded details.
            CREATE INDEX cards_filter_idx ON cards(domain, category, evidence_class, current_context);
            CREATE VIRTUAL TABLE cards_fts USING fts5(primary_text, context_text, utterance_text, content='', tokenize='unicode61 remove_diacritics 2');
        """)
        source_hash = sha256(json.dumps(sources, sort_keys=True, separators=(",", ":")).encode())
        metadata = {
            "schema_version": SCHEMA_VERSION,
            "corpus_version": "p16-runtime-projection-6212",
            "retrieval_policy_version": RETRIEVAL_POLICY_VERSION,
            "card_count": str(len(cards)),
            "source_projection_sha256": sha256(PROJECTION.read_bytes()),
            "source_resources_sha256": source_hash,
            "package_017_runtime_count": "0",
        }
        con.executemany("INSERT INTO metadata(key, value) VALUES (?, ?)", sorted(metadata.items()))
        for item in cards:
            card = item["card"]
            role_facets = json.dumps(sorted(card.get("roleFacets") or []), separators=(",", ":"))
            section_facets = json.dumps(sorted(card.get("sectionFacets") or []), separators=(",", ":"))
            source_types = json.dumps(sorted(card.get("sourceTypes") or []), separators=(",", ":"))
            primary_terms = normalize(" ".join([card.get("title", ""), card.get("question", "")]))
            facet_terms = normalize(" ".join([card.get("domain", ""), card.get("category", ""), card.get("topic", "") or ""]))
            # Keep only compact structured fields beside the rich card JSON.
            # Full clarification/hypothesis language belongs to contentless FTS,
            # so the row store does not duplicate it before payload selection.
            context_terms = normalize(" ".join((card.get("tags") or []) + (card.get("tracksmithDomains") or [])))
            context_parts = []
            for field in ("tags", "clarificationQuestions", "competingHypotheses", "listeningCues", "tracksmithDomains", "keyDistinction", "userIntent"):
                value = card.get(field, [])
                context_parts.extend(value if isinstance(value, list) else [value or ""])
            fts_context_terms = normalize(" ".join(context_parts))
            # Keep retrieval language compact: it augments structured card
            # fields but never makes the index a full raw-JSON duplicate.
            utterance_terms = normalize(" ".join(item["utterances"][:8]))
            con.execute("""INSERT INTO cards VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", (
                card["id"], card["packageID"], card["version"], card["domain"], card["category"], source_types,
                card["evidenceClass"], 1 if card.get("currentContext") else 0, card.get("logicVersion") or "", role_facets, section_facets,
                normalize(card.get("question", "")), primary_terms, facet_terms, context_terms, item["payload"],
            ))
            con.execute("INSERT INTO cards_fts(rowid, primary_text, context_text, utterance_text) VALUES (last_insert_rowid(), ?, ?, ?)", (" ".join([primary_terms, facet_terms]), fts_context_terms, utterance_terms))
        con.execute("INSERT INTO cards_fts(cards_fts) VALUES ('optimize')")
        con.commit()
        con.execute("VACUUM")
        con.commit()
    finally:
        con.close()
    data = database.read_bytes()
    logical_rows = []
    for item in cards:
        card = item["card"]
        role = json.dumps(sorted(card.get("roleFacets") or []), separators=(",", ":")); section = json.dumps(sorted(card.get("sectionFacets") or []), separators=(",", ":")); source = json.dumps(sorted(card.get("sourceTypes") or []), separators=(",", ":"))
        primary = normalize(" ".join([card.get("title", ""), card.get("question", "")]))
        facets = normalize(" ".join([card.get("domain", ""), card.get("category", ""), card.get("topic", "") or ""]))
        context = normalize(" ".join((card.get("tags") or []) + (card.get("tracksmithDomains") or [])))
        rich = []
        for field in ("tags", "clarificationQuestions", "competingHypotheses", "listeningCues", "tracksmithDomains", "keyDistinction", "userIntent"):
            value = card.get(field, []); rich.extend(value if isinstance(value, list) else [value or ""])
        logical_rows.append((card["id"], card["packageID"], card["version"], card["domain"], card["category"], source, card["evidenceClass"], int(bool(card.get("currentContext"))), card.get("logicVersion") or "", role, section, normalize(card.get("question", "")), primary, facets, context, normalize(" ".join(rich)), normalize(" ".join(item["utterances"][:8])), item["payload"]))
    logical = sha256(json.dumps({"schema": SCHEMA_VERSION, "policy": RETRIEVAL_POLICY_VERSION, "ftsWeights": [5, 2, .5], "metadata": metadata, "rows": logical_rows}, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode())
    return {
        "schema_version": SCHEMA_VERSION,
        "corpus_version": "p16-runtime-projection-6212",
        "retrieval_policy_version": RETRIEVAL_POLICY_VERSION,
        "builder_version": TOOL_VERSION,
        "card_count": len(cards),
        "package_count": len(sources),
        "package_017_runtime_count": 0,
        "source_projection": str(PROJECTION.relative_to(ROOT)),
        "source_projection_sha256": sha256(PROJECTION.read_bytes()),
        "sources": sources,
        "database": database.name,
        "database_bytes": len(data),
        "database_sha256": sha256(data),
        "database_header_sha256": sha256(data[:4096]),
        "logical_content_sha256": logical,
        "sqlite_version": sqlite3.sqlite_version,
        "determinism": "byte-identical on the same SQLite toolchain with fixed insertion order and pragmas",
    }


def write(manifest: dict, database: Path = DATABASE, manifest_path: Path = MANIFEST) -> None:
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


def audit(database: Path, manifest_path: Path) -> dict:
    manifest = json.loads(manifest_path.read_text())
    data = database.read_bytes()
    manifest_bytes = manifest_path.read_bytes().lower()
    checks = {
        "card_count": manifest.get("card_count") == EXPECTED_CARD_COUNT,
        "package_017_runtime_count": manifest.get("package_017_runtime_count") == 0,
        "database_sha256": manifest.get("database_sha256") == sha256(data),
        "database_header_sha256": manifest.get("database_header_sha256") == sha256(data[:4096]),
        "forbidden_markers": not any(marker.encode() in data.lower() or marker.encode() in manifest_bytes for marker in FORBIDDEN_MARKERS),
    }
    con = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    try:
        checks["sqlite_integrity"] = con.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        checks["sqlite_card_count"] = con.execute("SELECT COUNT(*) FROM cards").fetchone()[0] == EXPECTED_CARD_COUNT
        checks["sqlite_fts_count"] = con.execute("SELECT COUNT(*) FROM cards_fts").fetchone()[0] == EXPECTED_CARD_COUNT
        checks["p17_rows"] = con.execute("SELECT COUNT(*) FROM cards WHERE package_id LIKE '%017%'").fetchone()[0] == 0
    finally:
        con.close()
    return checks


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify tracked database and manifest without writing")
    parser.add_argument("--audit", action="store_true", help="perform a read-only leakage/integrity audit")
    args = parser.parse_args()
    if args.check:
        with tempfile.TemporaryDirectory(prefix="tracksmith-p18-index-") as directory:
            temporary_database = Path(directory) / DATABASE.name
            expected = build(temporary_database)
            actual = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
            same_sqlite = actual.get("sqlite_version") == sqlite3.sqlite_version
            same_toolchain_clean = same_sqlite and expected == actual and DATABASE.exists() and DATABASE.read_bytes() == temporary_database.read_bytes()
            cross_toolchain_clean = (not same_sqlite and actual.get("logical_content_sha256") == expected.get("logical_content_sha256") and actual.get("source_projection_sha256") == expected.get("source_projection_sha256") and actual.get("card_count") == expected.get("card_count"))
            if not (same_toolchain_clean or cross_toolchain_clean):
                print("Package 018 index drift: run research/scripts/build_candidate_retrieval_index.py", file=sys.stderr)
                return 1
        checks = audit(DATABASE, MANIFEST)
        if not all(checks.values()):
            print(json.dumps(checks, sort_keys=True), file=sys.stderr)
            return 1
        print(json.dumps({"status": "clean", **checks}, sort_keys=True))
        return 0
    if args.audit:
        checks = audit(DATABASE, MANIFEST)
        print(json.dumps(checks, indent=2, sort_keys=True))
        return 0 if all(checks.values()) else 1
    manifest = build(DATABASE)
    write(manifest)
    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
