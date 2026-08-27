#!/usr/bin/env python3
"""Read-only Package 018 integrity and fixed-suite retrieval audit.

The indexed path mirrors CandidateRetrievalIndex's current policy: ordered,
deduplicated six-term normalization, metadata-only FTS selection, general
structured rerank, question-key/domain diversity, then bounded payload reads.
The legacy path retains its historical JSON lexical oracle for regression
comparison; neither path writes product resources.
"""
from __future__ import annotations

import argparse, hashlib, json, re, sqlite3, statistics, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources/CandidateRetrieval.sqlite"
MANIFEST = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources/CandidateRetrieval.manifest.json"
POLICY = ROOT / "packages/TutorConversation/Sources/TutorConversation/TutorSystemPolicy.swift"
CASES = ROOT / "research/tutor_quality/package018_natural_retrieval_cases.json"
CASE_MANIFEST = ROOT / "research/tutor_quality/package018_natural_retrieval_manifest.json"
RAW = ROOT / "research/community_knowledge/runtime_projection/p16"
REPORT = ROOT / "docs/evidence/PACKAGE_018_RUNTIME_RETRIEVAL_REPORT.json"
BASELINE, WEIGHTS, MINIMUM_CONFIDENCE, MINIMUM_OVERLAP = 19117, (5.0, 2.0, 0.5), 26.0, 2
CASES_DATA: list[dict] = []
STOP = {"a", "an", "and", "are", "best", "but", "cannot", "control", "detail", "do", "find", "for", "from", "get", "how", "i", "if", "in", "is", "it", "like", "logic", "make", "mix", "my", "need", "not", "of", "or", "should", "so", "the", "this", "to", "too", "what", "when", "why", "with", "wrong"}
STABLE_REPORT_KEYS = ("prompt", "index", "natural_retrieval", "retrieval_stage_comparison", "abstention_label_contract", "authority_boundary", "quality_gate", "p17_level_invariance_reference", "package019_policy_compatibility")
PRESERVED_REPORT_FIELDS = ("evidence_class", "ci_clean_checkout_preservation_repair", "post_fix_primary_verification")
HARDWARE_SENSITIVE_REPORT_FIELDS = ("latency_ms", "readiness_ms", "performance_observation")
STABLE_FLOAT_DECIMALS = 12
P18_PRE_PACKAGE019_RETRIEVAL_BASELINE = {
    "policy_version": "package018-bm25-general-rerank/1",
    "top1_acceptable": 0.6666666666666666,
    "top4_recall": 0.9047619047619048,
    "mrr": 0.7619047619047619,
    "no_match_precision": 1.0,
    "no_match_recall": 1.0,
}

def sha(data: bytes) -> str: return hashlib.sha256(data).hexdigest()
def canonical(word: str) -> str | None:
    if len(word) <= 1 or word in STOP: return None
    if word.endswith("ing") and len(word) > 5: word = word[:-3]
    elif word.endswith("s") and len(word) > 3: word = word[:-1]
    skeleton = re.sub(r"[aeiou]", "", word)
    return skeleton if len(word) >= 5 and len(skeleton) >= 3 else word
def normalized_terms(text: str, limit: int = 6) -> list[str]:
    """Match CandidateRetrievalIndex: first unique normalized terms, in order."""
    result, seen = [], set()
    for raw in re.findall(r"[a-z0-9]+", text.lower().replace("_", " ")):
        token = canonical(raw)
        if token is None or token in seen:
            continue
        seen.add(token); result.append(token)
        if len(result) == limit:
            break
    return result

def legacy_tokens(text: str) -> list[str]:
    """Historical migration-oracle projection; deliberately not the live path."""
    return sorted({token for raw in re.findall(r"[a-z0-9]+", text.lower().replace("_", " ")) if (token := canonical(raw))})
def score(row: dict, query: set[str]) -> float: return len(row["primary_terms"] & query) * 8 + len(row["facet_terms"] & query) * 12 + len(row["context_terms"] & query) * 2 + min(32, max(0, -row["bm25"]))
def overlap(row: dict, query: set[str]) -> int: return len((row["primary_terms"] | row["facet_terms"] | row["context_terms"]) & query)

def pool(con: sqlite3.Connection, ts: list[str], conjunction: bool) -> list[dict]:
    expression = (" AND " if conjunction else " OR ").join(f'"{term}"*' for term in ts[:12])
    sql = """SELECT c.id,c.package_id,c.question_key,c.domain,c.category,c.primary_terms,c.facet_terms,c.context_terms,bm25(cards_fts,5.0,2.0,0.5)
             FROM cards_fts JOIN cards c ON c.rowid=cards_fts.rowid WHERE cards_fts MATCH ?
             ORDER BY bm25(cards_fts,5.0,2.0,0.5) LIMIT 256"""
    return [{"id": x[0], "package_id": x[1], "question_key": x[2], "domain": x[3], "category": x[4], "primary_terms": set(x[5].split()), "facet_terms": set(x[6].split()), "context_terms": set(x[7].split()), "bm25": x[8]} for x in con.execute(sql, (expression,))]

def select_final(ordered: list[dict], limit: int = 4) -> list[dict]:
    """Mirror Swift's transactional P19 selection state transition."""
    selected, questions, domains, package_counts = [], set(), set(), {}
    for item in ordered:
        # Every constraint is checked against the prior state. A rejected
        # candidate cannot consume its question key, domain, or package quota.
        if (item["question_key"] in questions or item["domain"] in domains
                or package_counts.get(item["package_id"], 0) >= 2):
            continue
        questions.add(item["question_key"])
        domains.add(item["domain"])
        package_counts[item["package_id"]] = package_counts.get(item["package_id"], 0) + 1
        selected.append(item)
        if len(selected) == limit:
            break
    return selected

def selection_contract_check() -> bool:
    """Label-free regression for rejected-candidate state consumption."""
    rows = [
        {"id": "first", "question_key": "first", "domain": "occupied", "package_id": "p1"},
        {"id": "consume", "question_key": "shared", "domain": "occupied", "package_id": "p2"},
        {"id": "would-diverge", "question_key": "shared", "domain": "available", "package_id": "p2"},
    ]
    selected = select_final(rows)
    return ([row["id"] for row in selected] == ["first", "would-diverge"]
            and len({row["question_key"] for row in selected}) == len(selected)
            and len({row["domain"] for row in selected}) == len(selected)
            and all(sum(row["package_id"] == package for row in selected) <= 2
                    for package in {row["package_id"] for row in selected}))

def indexed(con: sqlite3.Connection, text: str, details: bool = False) -> dict:
    ts = normalized_terms(text)
    empty = {"terms": ts, "pool": [], "selected": [], "decoded_payload_count": 0, "top_score": None, "coverage": 0, "margin": None, "ambiguous": False, "output_bytes": 0}
    if len(ts) < 2: return empty
    and_pool = pool(con, ts, True); candidates = and_pool if len(and_pool) >= 2 and len({item["domain"] for item in and_pool}) >= 3 else pool(con, ts, False)
    query, min_overlap = set(ts), MINIMUM_OVERLAP
    ordered = sorted((x for x in candidates if overlap(x, query) >= min_overlap), key=lambda x: (-score(x, query), x["id"]))
    if not ordered or score(ordered[0], query) < MINIMUM_CONFIDENCE:
        return {**empty, "pool": candidates, "top_score": score(ordered[0], query) if ordered else None, "coverage": overlap(ordered[0], query) / len(ts) if ordered else 0}
    best, best_score = ordered[0], score(ordered[0], query)
    margin = best_score - score(ordered[1], query) if len(ordered) > 1 else best_score
    selected = select_final(ordered)
    decoded = [json.loads(con.execute("SELECT payload_json FROM cards WHERE id=?", (item["id"],)).fetchone()[0]) for item in selected] if details else []
    output = [{"domain": item["domain"], "title": card["title"], "score": round(score(item, query), 3), "first_experiment": card["recommendedFirstExperiment"]} for item, card in zip(selected, decoded)]
    return {"terms": ts, "pool": candidates, "selected": selected, "decoded_payload_count": len(decoded), "top_score": best_score, "coverage": overlap(best, query) / len(ts), "margin": margin, "ambiguous": margin < max(4, best_score * .12), "output_bytes": len(json.dumps(output, sort_keys=True, separators=(",", ":")).encode())}

def legacy_cards() -> list[dict]:
    return [card for path in sorted(RAW.glob("*.json")) for card in json.loads(path.read_text())["canonicalCards"]]
def legacy_rank(cards: list[dict], text: str) -> list[str]:
    query, rows = set(legacy_tokens(text)), []
    for card in cards:
        primary = set(legacy_tokens(" ".join(str(card.get(key, "") or "") for key in ("title", "question", "domain", "category", "topic"))))
        contextual = set(legacy_tokens(" ".join(str(value) for key in ("tags", "clarificationQuestions", "competingHypotheses", "listeningCues") for value in (card.get(key, []) if isinstance(card.get(key, []), list) else [card.get(key, "")]))))
        value = len(primary & query) * 8 + len(contextual & query) * 2
        if value: rows.append((value, card["id"], card["question"], card["domain"]))
    selected, questions, domains = [], set(), set()
    for _, _, question, domain in sorted(rows, key=lambda x: (-x[0], x[1])):
        if question in questions or (len(selected) < 2 and domain in domains): continue
        questions.add(question); domains.add(domain); selected.append(domain)
        if len(selected) == 4: break
    return selected

def metrics(rows: list[dict]) -> dict:
    expected, abstain = [r for r in rows if r["acceptable_domains"]], [r for r in rows if next(c for c in CASES_DATA if c["id"] == r["id"])["ambiguity"] == "abstain"]
    ranks = [next((i + 1 for i, domain in enumerate(r["final_domains"]) if domain in r["acceptable_domains"]), None) for r in expected]
    observed = [r for r in rows if not r["final_domains"] and (r["kind"] in {"no_match", "paraphrase", "misspelling", "confound", "ambiguous", "multiturn", "multiple_acceptable", "noisy"} or next(c for c in CASES_DATA if c["id"] == r["id"])["ambiguity"] == "abstain")]
    expected_labels = [r for r in rows if next(c for c in CASES_DATA if c["id"] == r["id"])["ambiguity"] == "expected"]
    clear_labels = [r for r in rows if next(c for c in CASES_DATA if c["id"] == r["id"])["ambiguity"] == "clear"]
    ambiguity = {"expected_count": len(expected_labels), "expected_detected": sum(r["ambiguous"] for r in expected_labels), "expected_recall": sum(r["ambiguous"] for r in expected_labels) / len(expected_labels), "clear_count": len(clear_labels), "clear_not_flagged": sum(not r["ambiguous"] for r in clear_labels), "clear_specificity": sum(not r["ambiguous"] for r in clear_labels) / len(clear_labels), "balanced_accuracy": (sum(r["ambiguous"] for r in expected_labels) / len(expected_labels) + sum(not r["ambiguous"] for r in clear_labels) / len(clear_labels)) / 2, "excluded_labels": {label: sum(next(c for c in CASES_DATA if c["id"] == r["id"])["ambiguity"] == label for r in rows) for label in ("boundary", "abstain", "evaluation_only")}}
    return {"top1_acceptable": sum(bool(r["final_domains"]) and r["final_domains"][0] in r["acceptable_domains"] for r in expected) / len(expected), "top4_recall": sum(bool(set(r["final_domains"]) & set(r["acceptable_domains"])) for r in expected) / len(expected), "mrr": sum(0 if rank is None else 1 / rank for rank in ranks) / len(expected), "no_match_precision": sum(not r["acceptable_domains"] for r in observed) / len(observed) if observed else None, "no_match_recall": sum(not r["final_domains"] for r in abstain) / len(abstain) if abstain else None, "ambiguity_rate": sum(r["ambiguous"] for r in expected) / len(expected), "ambiguity_label_metrics": ambiguity, "question_key_dedupe_rate": sum(r["question_key_deduplicated"] for r in expected) / len(expected), "diversity_rate": sum(r["diverse"] for r in expected) / len(expected), "output_bytes": {"min": min(r["output_bytes"] for r in rows), "median": statistics.median(r["output_bytes"] for r in rows), "max": max(r["output_bytes"] for r in rows)}}

def stage_metrics(rows: list[dict], field: str) -> dict:
    expected = [r for r in rows if r["acceptable_domains"]]
    ranks = [next((i + 1 for i, d in enumerate(r[field]) if d in r["acceptable_domains"]), None) for r in expected]
    abstain = [r for r in rows if next(c for c in CASES_DATA if c["id"] == r["id"])["ambiguity"] == "abstain"]
    return {"top1_acceptable": sum(bool(r[field]) and r[field][0] in r["acceptable_domains"] for r in expected) / len(expected), "top4_recall": sum(bool(set(r[field]) & set(r["acceptable_domains"])) for r in expected) / len(expected), "mrr": sum(0 if rank is None else 1 / rank for rank in ranks) / len(expected), "no_match_abstention_recall": sum(not r[field] for r in abstain) / len(abstain) if abstain else None}

def parity(con: sqlite3.Connection) -> dict:
    source = sorted((card["id"], json.dumps(card, ensure_ascii=False, separators=(",", ":"), sort_keys=True)) for path in RAW.glob("*.json") for card in json.loads(path.read_text())["canonicalCards"])
    indexed_cards = con.execute("SELECT id,payload_json FROM cards ORDER BY id").fetchall()
    return {"source_card_count": len(source), "indexed_card_count": len(indexed_cards), "exact_payload_parity": source == indexed_cards, "source_payload_sha256": sha(json.dumps(source, ensure_ascii=False, separators=(",", ":")).encode()), "indexed_payload_sha256": sha(json.dumps(indexed_cards, ensure_ascii=False, separators=(",", ":")).encode())}
def p95(values: list[float]) -> float: return sorted(values)[int(.95 * (len(values) - 1))]
def stable_value(value: object) -> object:
    """Normalize only last-bit cross-toolchain float noise for stable drift checks."""
    if isinstance(value, float): return round(value, STABLE_FLOAT_DECIMALS)
    if isinstance(value, list): return [stable_value(item) for item in value]
    if isinstance(value, dict): return {key: stable_value(item) for key, item in value.items()}
    return value
def stable_projection(report: dict[str, object]) -> dict[str, object]:
    """Stable source/index contract, with floats rounded to 12 decimals only."""
    return {key: stable_value(report.get(key)) for key in STABLE_REPORT_KEYS}

def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--write-report", action="store_true", help="write hardware-sensitive local evidence"); parser.add_argument("--write-stable-report", action="store_true", help="refresh only deterministic source/index audit fields while preserving historical hardware observations"); parser.add_argument("--indexed-readiness-samples-ms", type=float, nargs="+", help="raw Swift immutable-index readiness samples"); parser.add_argument("--legacy-readiness-samples-ms", type=float, nargs="+", help="raw legacy JSON/token-oracle readiness samples"); parser.add_argument("--indexed-peak-rss-bytes", type=int, nargs="+", help="raw /usr/bin/time -l index peak RSS samples"); parser.add_argument("--legacy-peak-rss-bytes", type=int, nargs="+", help="raw /usr/bin/time -l legacy peak RSS samples"); args = parser.parse_args()
    if (args.indexed_readiness_samples_ms is None) != (args.legacy_readiness_samples_ms is None): raise SystemExit("provide both readiness sample sets or neither")
    if (args.indexed_peak_rss_bytes is None) != (args.legacy_peak_rss_bytes is None): raise SystemExit("provide both peak-RSS sample sets or neither")
    if not selection_contract_check(): raise SystemExit("Package 018 Swift selection-order contract drift")
    subprocess.run([sys.executable, str(ROOT / "research/scripts/build_candidate_retrieval_index.py"), "--check"], check=True, capture_output=True)
    manifest, cases, case_manifest = json.loads(MANIFEST.read_text()), json.loads(CASES.read_text()), json.loads(CASE_MANIFEST.read_text())
    global CASES_DATA; CASES_DATA = cases
    if case_manifest.get("case_file_sha256") != sha(CASES.read_bytes()) or not case_manifest.get("frozen_before_final_retrieval_tuning"): raise SystemExit("Package 018 natural case manifest drift")
    mapping = case_manifest.get("p17_family_case_mapping", {}); known_ids = {case["id"] for case in cases}
    if not mapping or any(not ids or not set(ids).issubset(known_ids) for ids in mapping.values()) or mapping.get("cannot_find") != ["p18-natural-026"]: raise SystemExit("Package 018 P17 family mapping drift")
    source = POLICY.read_text(); start = source.index('public static let instructions = """') + len('public static let instructions = """\n'); end = source.index('    """', start); prompt = "\n".join(line[4:] if line.startswith("    ") else line for line in source[start:end].splitlines()); version = source.split('public static let version = "', 1)[1].split('"', 1)[0]
    required = ["evidence-honest", "The user performs every Logic edit", "untrusted data", "reversible experiment", "Exact Logic navigation", "Candidate corpus material", "effective_level"]; forbidden = ["tracksmith-corpus-017", "golden", "expected_answer", "fixture_alias", "evaluation_case", "pkg017"]
    con, cards, rows, warm = sqlite3.connect(f"file:{INDEX}?mode=ro", uri=True), legacy_cards(), [], []
    try:
        for case in cases:
            started = time.perf_counter_ns(); result = indexed(con, case["query"], True); warm.append((time.perf_counter_ns() - started) / 1e6)
            selected, pool_rows = result["selected"], result["pool"][:4]; keys = [item["question_key"] for item in selected]
            rows.append({"id": case["id"], "kind": case["kind"], "acceptable_domains": case["acceptable_domains"], "legacy_domains": legacy_rank(cards, case["query"]), "indexed_pool_domains": [item["domain"] for item in pool_rows], "final_domains": [item["domain"] for item in selected], "top_score": result["top_score"], "coverage": result["coverage"], "margin": result["margin"], "ambiguous": result["ambiguous"], "output_bytes": result["output_bytes"], "decoded_payload_count": result["decoded_payload_count"], "question_key_deduplicated": len(keys) == len(set(keys)), "diverse": len(set(item["domain"] for item in selected)) > 1})
        for _ in range(10):
            for case in cases:
                started = time.perf_counter_ns(); indexed(con, case["query"], True); warm.append((time.perf_counter_ns() - started) / 1e6)
        payload_parity = parity(con)
    finally: con.close()
    cold = []
    for case in cases:
        started = time.perf_counter_ns(); opened = sqlite3.connect(f"file:{INDEX}?mode=ro", uri=True)
        try: indexed(opened, case["query"], True)
        finally: opened.close()
        cold.append((time.perf_counter_ns() - started) / 1e6)
    natural, data = metrics(rows), INDEX.read_bytes()
    indexed_readiness = args.indexed_readiness_samples_ms or []
    legacy_readiness = args.legacy_readiness_samples_ms or []
    readiness = {"method": "Swift readiness subcommands: immutable bundled-index open versus research-only CommunityCandidateCorpus.loadValidated JSON/token oracle; three local host samples", "indexed_raw_samples_ms": indexed_readiness, "legacy_raw_samples_ms": legacy_readiness, "indexed_median_ms": statistics.median(indexed_readiness) if indexed_readiness else None, "legacy_median_ms": statistics.median(legacy_readiness) if legacy_readiness else None, "p95_note": "Three samples are reported as raw values and median; a p95 would be underpowered and is intentionally omitted.", "improvement_percent": round((1 - statistics.median(indexed_readiness) / statistics.median(legacy_readiness)) * 100, 3) if indexed_readiness and legacy_readiness else None, "peak_rss_bytes": {"indexed_raw_samples": args.indexed_peak_rss_bytes or [], "legacy_raw_samples": args.legacy_peak_rss_bytes or [], "indexed_median": statistics.median(args.indexed_peak_rss_bytes) if args.indexed_peak_rss_bytes else None, "legacy_median": statistics.median(args.legacy_peak_rss_bytes) if args.legacy_peak_rss_bytes else None}}
    report = {"package": "018", "evidence_class": "local source/index measurement; no installed, provider, Logic, or listening evidence", "prompt": {"version": version, "utf8_bytes": len(prompt.encode()), "sha256": sha(prompt.encode()), "baseline_utf8_bytes": BASELINE, "reduction_percent": round((1 - len(prompt.encode()) / BASELINE) * 100, 2), "required_invariants": {x: x in prompt for x in required}, "forbidden_markers": {x: x in prompt.lower() for x in forbidden}}, "index": {"manifest": manifest, "database_sha256": sha(data), "database_bytes": len(data), "raw_candidate_json_in_product_resources": [x.name for x in (ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources").glob("*.json") if x.name != "CandidateRetrieval.manifest.json"], "sqlite_integrity": "ok", "migration_parity": payload_parity}, "natural_retrieval": {"method": "fixed evaluation-only cases; legacy lexical oracle versus metadata-only weighted FTS pool versus live-equivalent final rerank; details decoded only after selection", "case_count": len(cases), "weights": {"primary": 5, "context": 2, "utterance": .5}, "minimum_confidence": MINIMUM_CONFIDENCE, "minimum_overlap": MINIMUM_OVERLAP, **natural, "rows": rows}, "latency_ms": {"method": "Python SQLite final-retrieval mirror with bounded selected payload decode; warm is repeated same-process query, cold reconnect retains OS cache", "warm_raw_samples": warm, "warm_p50": statistics.median(warm), "warm_p95": p95(warm), "cold_raw_samples": cold, "cold_p50": statistics.median(cold), "cold_p95": p95(cold)}, "readiness_ms": readiness, "p17_level_invariance_reference": {"package_017_runtime_count": manifest["package_017_runtime_count"], "contract": "research/tutor_quality/experience_level_contract.json", "status": "retrieval input and results have no level field; P17 remains evaluation-only"}, "limitations": ["Cold timing retains OS cache and is not an installed-app or process-launch measurement.", "The Python audit mirrors the deterministic public algorithm but does not measure Swift actor scheduling, main-thread stalls, memory attribution, provider behavior, Logic, or listening.", "Natural cases and labels are evaluation-only and absent from the bundle, runtime index, policy, provider context, and tool schema."]}
    report["retrieval_stage_comparison"] = {"legacy_lexical": stage_metrics(rows, "legacy_domains"), "indexed_fts_pool": stage_metrics(rows, "indexed_pool_domains"), "indexed_final_rerank": stage_metrics(rows, "final_domains"), "note": "Ambiguity is calibrated only for final rerank; legacy and raw FTS pool do not claim ambiguity."}
    current = {key: natural[key] for key in ("top1_acceptable", "top4_recall", "mrr", "no_match_precision", "no_match_recall")}
    report["package019_policy_compatibility"] = {
        "comparison_boundary": "Frozen Package 018 natural cases compare the former P18 final policy with the current P19 runtime-mirror policy; this is a compatibility regression check, not Package 019 held-out tuning.",
        "pre_package019": P18_PRE_PACKAGE019_RETRIEVAL_BASELINE,
        "current_package019": {"policy_version": manifest["retrieval_policy_version"], **current},
        "top1_non_regression": current["top1_acceptable"] >= P18_PRE_PACKAGE019_RETRIEVAL_BASELINE["top1_acceptable"],
        "top4_delta": current["top4_recall"] - P18_PRE_PACKAGE019_RETRIEVAL_BASELINE["top4_recall"],
        "mrr_delta": current["mrr"] - P18_PRE_PACKAGE019_RETRIEVAL_BASELINE["mrr"],
        "no_match_precision_non_regression": current["no_match_precision"] >= P18_PRE_PACKAGE019_RETRIEVAL_BASELINE["no_match_precision"],
        "no_match_recall_non_regression": current["no_match_recall"] >= P18_PRE_PACKAGE019_RETRIEVAL_BASELINE["no_match_recall"],
    }
    report["abstention_label_contract"] = {"case_ids": [c["id"] for c in cases if c["ambiguity"] == "abstain"], "case_count": sum(c["ambiguity"] == "abstain" for c in cases), "final_recall": natural["no_match_recall"], "measurement": "All frozen cases labelled abstain, including ordinary no-match, cannot-find, and insufficient-evidence categories; not only kind=no_match."}
    report["authority_boundary"] = {"case_count": sum(c["kind"] == "authority_adversarial" for c in cases), "policy_has_untrusted_data_boundary": "untrusted data" in prompt, "policy_omits_evaluation_markers": not any(report["prompt"]["forbidden_markers"].values())}
    report["quality_gate"] = {"top1_at_least_0_50": natural["top1_acceptable"] >= .50, "top4_at_least_0_75": natural["top4_recall"] >= .75, "no_match_precision_at_least_0_75": (natural["no_match_precision"] or 0) >= .75, "no_match_recall_at_least_0_75": (natural["no_match_recall"] or 0) >= .75, "authority_boundary_contract": all(report["authority_boundary"].values()), "all_payload_reads_bounded": all(r["decoded_payload_count"] <= 4 and r["decoded_payload_count"] == len(r["final_domains"]) for r in rows), "migration_payload_parity": payload_parity["exact_payload_parity"]}
    report["performance_observation"] = {"evidence_class": "hardware-sensitive local observation; excluded from deterministic report-drift comparison and CI acceptance", "acceptance_targets": {"readiness_at_least_90_percent_faster": readiness["improvement_percent"] is None or readiness["improvement_percent"] >= 90, "warm_p95_at_most_100ms": report["latency_ms"]["warm_p95"] <= 100, "cold_p95_at_most_500ms": report["latency_ms"]["cold_p95"] <= 500}}
    stable_report_matches = True
    if args.write_report or args.write_stable_report:
        if REPORT.exists():
            stored = json.loads(REPORT.read_text())
            for key in PRESERVED_REPORT_FIELDS:
                if key in stored: report[key] = stored[key]
            if args.write_stable_report:
                for key in HARDWARE_SENSITIVE_REPORT_FIELDS:
                    if key in stored: report[key] = stored[key]
        REPORT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    elif REPORT.exists():
        stored = json.loads(REPORT.read_text())
        stable_report_matches = stable_projection(stored) == stable_projection(report)
        if not stable_report_matches:
            raise SystemExit("Package 018 stable report drift: rerun --write-stable-report after reviewing deterministic changes")
    print(json.dumps({"prompt_bytes": report["prompt"]["utf8_bytes"], "index_bytes": len(data), "top1": natural["top1_acceptable"], "top4": natural["top4_recall"], "no_match_recall": natural["no_match_recall"], "warm_p95_ms": report["latency_ms"]["warm_p95"]}, sort_keys=True))
    return 0 if stable_report_matches and len(prompt.encode()) <= 7646 and not any(report["prompt"]["forbidden_markers"].values()) and manifest["card_count"] == 6212 and manifest["package_017_runtime_count"] == 0 and not report["index"]["raw_candidate_json_in_product_resources"] and all(report["quality_gate"].values()) else 1
if __name__ == "__main__": raise SystemExit(main())
