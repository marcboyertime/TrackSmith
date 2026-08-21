#!/usr/bin/env python3
"""Repository-owned, no-follow Package 016 integration guard.

This deliberately does not import or execute any supplied P16 code.  P16 has no
subject records: it preserves its audited integration material and records the
immutable 6,134-record baseline separately from the selected current 6,212-card
overlay.  It never generates a Tutor resource, SQLite database, evaluation fixture,
procedure, or exact-alias runtime input.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import sqlite3
import stat
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
COMMUNITY = ROOT / "research/community_knowledge"
PID = "tracksmith-corpus-016-integration-retrieval-quality-control"
ARCHIVE_SHA256 = "07d391c61e7ead04d5a9f29c128146e8715d38d9d46cbd59c3bbb7917e145aad"
SIDECAR_SHA256 = "9cdd26ec1920b579f0b7f586940fe9c27dfcecb2c388659ff44fd63f8df2c73f"
MANIFEST_SHA256 = "5c02ef373e6d2aa82260083ed4c697af4a5bcb51461bd135f19851eb56506637"
INTEGRATION_SHA256 = "71f3d4b4a17934aa5b77624a4df79427517c3f9ca24b1570015d4dfa94d06968"
CHECKSUM_SHA256 = "f2748a4c943794942dd772aff97eec642afbdb71e896a7cccbbbc10dd933e7b3"
TREE_SHA256 = "4fb517236757ccb135b9383435ed728a5c161a8424f6095872b794111a879135"
BASELINE = COMMUNITY / "preservation_baselines/package-016-preimport-p001-p015.json"
DESTINATION = COMMUNITY / "packages" / PID
REGISTRY = COMMUNITY / "package_registry.json"
DEPENDENCY = COMMUNITY / "dependency_maps" / f"{PID}.json"
REPORT = COMMUNITY / f"import_report_{PID}.json"
RECONCILIATION = COMMUNITY / "reconciliations" / f"{PID}.json"
RUNTIME_MIGRATION = COMMUNITY / "reconciliations" / f"{PID}-runtime-projection-migration.json"

P16_ZERO_SUBJECT_KINDS = {
    "canonical_qa", "claim_candidates", "contradictions",
    "logic_procedure_candidates", "multiturn_scenarios", "myths_and_antipatterns",
    "provenance", "retrieval_evaluations", "strategy_candidates", "user_utterances",
}
P2_P3_CURRENT = {
    "community-level-balancing-eq-v1": {
        "expectedArchiveSHA256": "ebfebda08ade164bcf0b2ec9122202210a436a89453ddb45688b95bf616f5cba",
        "currentArchiveSHA256": "d66bb9ccf05d2966148242a909a1e3dacc6ff355eb2af481af0507b5659349da",
        "baselineCanonical": 190, "currentCanonical": 238,
    },
    "community-compression-arrangement-frequency-allocation-v1": {
        "expectedArchiveSHA256": "dfd71277e0595a283506af73801c432c605723fd3a24f3c12dd4dd7f43483097",
        "currentArchiveSHA256": "6d7e2a41aa2e95a5ad7e49bae1e1600b6286258f5a7b3b4aa323d83f84c370eb",
        "baselineCanonical": 320, "currentCanonical": 350,
    },
}


def die(message: str) -> None:
    raise SystemExit("P16_INTEGRATION_ERROR: " + message)


def sha(path: pathlib.Path) -> str:
    if path.is_symlink() or not path.is_file():
        die("unsafe or missing file " + str(path))
    return hashlib.sha256(path.read_bytes()).hexdigest()


def json_file(path: pathlib.Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        die("invalid JSON " + str(path) + ": " + str(error))


def write_json_new(path: pathlib.Path, value: object) -> None:
    """Atomic creation only; never replaces an existing preservation artifact."""
    if path.exists() or path.is_symlink():
        die("refuses to replace existing artifact " + str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            json.dump(value, output, indent=2, sort_keys=True)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def atomic_replace_bytes(path: pathlib.Path, value: bytes) -> None:
    """Restore only a byte-for-byte-known file; used by the narrow stage rollback."""
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".rollback", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(value)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def regular_files(root: pathlib.Path) -> dict[str, pathlib.Path]:
    if root.is_symlink() or not root.is_dir():
        die("unsafe root " + str(root))
    result: dict[str, pathlib.Path] = {}
    for base, directories, names in os.walk(root, followlinks=False):
        base_path = pathlib.Path(base)
        for directory in directories:
            path = base_path / directory
            if path.is_symlink() or not stat.S_ISDIR(path.lstat().st_mode):
                die("unsafe directory " + str(path))
        for name in names:
            path = base_path / name
            if path.is_symlink() or not stat.S_ISREG(path.lstat().st_mode):
                die("unsafe file " + str(path))
            result[path.relative_to(root).as_posix()] = path
    return result


def tree_digest(root: pathlib.Path) -> dict[str, object]:
    files = regular_files(root)
    digest = hashlib.sha256()
    for relative, path in sorted(files.items()):
        digest.update(b"FILE\0" + relative.encode() + b"\0" + path.read_bytes())
    return {"fileCount": len(files), "sha256": digest.hexdigest()}


def package_allowlist(incoming: pathlib.Path) -> dict[str, str]:
    sums = incoming / "PACKAGE_SHA256SUMS.txt"
    if sha(sums) != CHECKSUM_SHA256:
        die("P16 checksum-manifest pin drift")
    expected: dict[str, str] = {}
    for line in sums.read_text(encoding="utf-8").splitlines():
        pieces = line.split("  ", 1)
        if len(pieces) != 2 or len(pieces[0]) != 64:
            die("P16 checksum line shape drift")
        digest, relative = pieces
        pure = pathlib.PurePosixPath(relative)
        if pure.is_absolute() or ".." in pure.parts or relative in expected:
            die("P16 checksum path drift")
        expected[relative] = digest
    expected["PACKAGE_SHA256SUMS.txt"] = CHECKSUM_SHA256
    if len(expected) != 47:
        die("P16 allowlist count is not 47")
    actual = regular_files(incoming)
    if set(actual) != set(expected):
        die("P16 external tree is not the exact 47-file allowlist; extras/missing=" +
            ",".join(sorted(set(actual) ^ set(expected))[:8]))
    for relative, digest in expected.items():
        if sha(actual[relative]) != digest:
            die("P16 package byte pin drift " + relative)
    return expected


def current_resources() -> dict[str, int]:
    resources = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources"
    values: dict[str, int] = {}
    for path in sorted(resources.glob("*.json")):
        data = json_file(path)
        if not isinstance(data, dict) or not isinstance(data.get("packageID"), str):
            continue
        cards = data.get("canonicalCards")
        if isinstance(cards, list):
            values[data["packageID"]] = len(cards)
    if len(values) != 15:
        die("expected exactly 15 existing runtime package resources, found " + str(len(values)))
    if PID in values:
        die("P16 must not have a subject runtime resource")
    return values


def reconciliation(incoming: pathlib.Path) -> dict[str, object]:
    manifest = json_file(incoming / "package_manifest.json")
    if not isinstance(manifest, dict):
        die("P16 manifest is not an object")
    declared = manifest.get("prior_package_aggregate_counts", {})
    if declared.get("canonical_qa") != 6134:
        die("P16 immutable audited baseline is not 6134")
    resources = current_resources()
    current = sum(resources.values())
    if current != 6212:
        die("selected current canonical overlay is not 6212")
    overlays: dict[str, object] = {}
    for package_id, value in P2_P3_CURRENT.items():
        observed = resources.get(package_id)
        if observed != value["currentCanonical"]:
            die("current selected overlay count drift " + package_id)
        overlays[package_id] = {
            **value,
            "canonicalDelta": value["currentCanonical"] - value["baselineCanonical"],
            "classification": "repository_native_superseding_overlay_not_p16_knowledge",
        }
    return {
        "schemaVersion": "1.0",
        "immutableAuditedBaseline": {"canonical_qa": 6134, "source": "P16 package manifest"},
        "selectedCurrentCanonical": 6212,
        "selectedOverlayCanonicalDelta": 78,
        "suppliedAggregateClaim": "stale_for_selected_current_variants",
        "overlays": overlays,
        "perPackageCanonical": resources,
        "statusAuthority": "P16 preserves source status/ID provenance; synthesized adapter metadata is explicitly synthesized",
    }


def preflight(incoming: pathlib.Path, archive: pathlib.Path, sidecar: pathlib.Path) -> dict[str, object]:
    if sha(archive) != ARCHIVE_SHA256:
        die("P16 archive pin drift")
    if sha(sidecar) != SIDECAR_SHA256:
        die("P16 sidecar byte pin drift")
    text = sidecar.read_text(encoding="utf-8").strip()
    if text != ARCHIVE_SHA256 + "  " + archive.name:
        die("P16 sidecar textual pin drift")
    package_allowlist(incoming)
    if sha(incoming / "package_manifest.json") != MANIFEST_SHA256:
        die("P16 manifest pin drift")
    if sha(incoming / "integration/integration_manifest.json") != INTEGRATION_SHA256:
        die("P16 integration-manifest pin drift")
    manifest = json_file(incoming / "package_manifest.json")
    integration = json_file(incoming / "integration/integration_manifest.json")
    if not isinstance(manifest, dict) or manifest.get("package_id") != PID or manifest.get("package_type") != "integration_framework":
        die("P16 identity/type drift")
    if not isinstance(integration, dict) or integration.get("counts", {}).get("canonical_qa") != 0:
        die("P16 integration zero-subject contract drift")
    for key in P16_ZERO_SUBJECT_KINDS:
        if manifest.get("record_counts", {}).get(key, 0) != 0:
            die("P16 manifest has subject data " + key)
    output = reconciliation(incoming)
    output.update({"archiveSHA256": ARCHIVE_SHA256, "sidecarSHA256": SIDECAR_SHA256,
                   "tree": tree_digest(incoming), "zeroSubjectRecords": True,
                   "runtimeResourceEmitted": False, "suppliedImporterExecuted": False})
    if output["tree"] != {"fileCount": 47, "sha256": TREE_SHA256}:
        die("P16 tree pin drift")
    return output


def state_fingerprint() -> dict[str, object]:
    registry = json_file(REGISTRY)
    if not isinstance(registry, dict) or not isinstance(registry.get("packages"), list):
        die("package registry shape drift")
    protected = [row for row in registry["packages"] if isinstance(row, dict) and row.get("package_number", 0) <= 15]
    if [row.get("package_number") for row in protected] != list(range(1, 16)):
        die("P1-P15 registry sequence drift")
    paths = [ROOT / "research/knowledge/general-tutor-source-registry.json",
             ROOT / "research/knowledge/general-tutor-review-queue.json",
             ROOT / "packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.generated.swift"]
    package_trees: dict[str, object] = {}
    for row in protected:
        path = ROOT / str(row["path"])
        package_trees[str(row["package_id"])] = tree_digest(path)
    registry_projection = hashlib.sha256(json.dumps(protected, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"schemaVersion": "1.0", "protectedPackageCount": 15,
            "registryProjectionSHA256": registry_projection,
            "files": {str(path.relative_to(ROOT)): sha(path) for path in paths},
            "packageTrees": package_trees,
            "runtimeResources": current_resources()}


def check_baseline() -> None:
    if not BASELINE.is_file() or BASELINE.is_symlink():
        die("P16 preservation baseline missing")
    if json_file(BASELINE) != state_fingerprint():
        die("P16 preservation check failed: P1-P15 state drift")


def audit_runtime_projection() -> None:
    """Record the derived-runtime boundary without touching immutable raw trees.

    The current resource projections do not contain the P16 synthetic
    ``exactpkg`` fixtures, so their bytes remain unchanged.  Native lookup is
    removed by policy in CommunityCandidateCorpus; this manifest makes that
    intentional no-byte migration explicit instead of recapturing a baseline.
    """
    check_baseline()
    resources = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources"
    registry = json_file(REGISTRY)
    sequence = {str(row["package_id"]): int(row["package_number"])
                for row in registry["packages"] if isinstance(row, dict) and 1 <= row.get("package_number", 0) <= 15}
    records: list[dict[str, object]] = []
    fixture_count = 0
    for path in sorted(resources.glob("*.json")):
        data = json_file(path)
        package_id = str(data["packageID"])
        cards = data.get("canonicalCards", [])
        utterances = data.get("utterances", [])
        if package_id not in sequence or not isinstance(cards, list) or not isinstance(utterances, list):
            die("runtime resource projection shape drift " + path.name)
        # Synthetic P16 fixture strings are intentionally never inserted into a
        # shipping resource. Their generated count is therefore test-only.
        fixture_count += len(cards)
        records.append({"packageID": package_id, "packageNumber": sequence[package_id],
                        "resource": str(path.relative_to(ROOT)), "oldSHA256": sha(path), "newSHA256": sha(path),
                        "canonicalCardCount": len(cards), "retainedUtteranceCount": len(utterances),
                        "removedNormalizedAliasCount": 0, "removedNormalizedAliasIDs": [],
                        "migration": "policy-only-no-fixture-bytes-present"})
    if fixture_count != 6212:
        die("runtime fixture projection canonical count drift")
    expected = {"schemaVersion": "1.0", "policyVersion": "package16-runtime-projection/1.0",
        "runtimeExactIdentity": "disabled", "runtimeAliasAuthority": "disabled", "ordinaryLexicalPostings": "retained",
        "testOnlySyntheticExactFixtureCount": fixture_count, "immutableAuditedBaselineFixtureCount": 6134,
        "selectedOverlayFixtureDelta": 78, "resources": records,
        "rawPackageTreesChanged": False, "evaluationFixturesChanged": False, "sourceQueueReviewChanged": False}
    if RUNTIME_MIGRATION.is_symlink() or (RUNTIME_MIGRATION.exists() and not RUNTIME_MIGRATION.is_file()):
        die("runtime migration manifest must be a regular non-symlink file")
    if RUNTIME_MIGRATION.exists():
        if json_file(RUNTIME_MIGRATION) != expected:
            die("runtime migration manifest drift")
    else:
        write_json_new(RUNTIME_MIGRATION, expected)
    check_baseline()
    print("P16_RUNTIME_PROJECTION_AUDIT_OK resources=15 fixtureCount=6212 removedAliases=0")


def normalized(value: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", value.lower()))


def build_development_index(index: pathlib.Path) -> None:
    """Build an explicitly non-shipping P1-P15 development SQLite index.

    Only derived runtime cards and test-only fixture metadata are read.  The
    supplied P16 database is neither opened nor copied.
    """
    check_baseline()
    index = index.expanduser().resolve()
    if ROOT == index or ROOT in index.parents:
        die("development index must be outside the repository (user-deletable cache only)")
    if index.exists() or index.is_symlink():
        die("refuses to replace development index cache")
    index.parent.mkdir(parents=True, exist_ok=True)
    temporary = index.with_name(index.name + ".tmp-" + str(os.getpid()))
    resources = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources"
    registry = json_file(REGISTRY)
    sequence = {str(row["package_id"]): int(row["package_number"])
                for row in registry["packages"] if isinstance(row, dict) and 1 <= row.get("package_number", 0) <= 15}
    try:
        connection = sqlite3.connect(temporary)
        cursor = connection.cursor()
        cursor.executescript("""
            PRAGMA journal_mode=OFF;
            PRAGMA synchronous=FULL;
            CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE package_totals(package_id TEXT PRIMARY KEY, package_number INTEGER NOT NULL, canonical_count INTEGER NOT NULL, utterance_count INTEGER NOT NULL, resource_sha256 TEXT NOT NULL);
            CREATE TABLE canonical_cards(canonical_id TEXT PRIMARY KEY, package_id TEXT NOT NULL, package_number INTEGER NOT NULL, domain TEXT, source_ids_json TEXT NOT NULL, review_state TEXT, source_resource_sha256 TEXT NOT NULL);
            CREATE TABLE source_provenance(canonical_id TEXT NOT NULL, source_id TEXT NOT NULL, source_class TEXT NOT NULL, PRIMARY KEY(canonical_id, source_id, source_class));
            CREATE TABLE test_only_exact_fixtures(normalized_alias TEXT PRIMARY KEY, canonical_id TEXT UNIQUE NOT NULL, package_id TEXT NOT NULL, classification TEXT NOT NULL CHECK(classification='exact_unique'));
            CREATE TABLE natural_alias_collisions(normalized_alias TEXT PRIMARY KEY, canonical_ids_json TEXT NOT NULL, package_ids_json TEXT NOT NULL, classification TEXT NOT NULL CHECK(classification='diagnostic_ambiguous_alias'));
            CREATE TABLE package16_test_cases(test_id TEXT PRIMARY KEY, kind TEXT NOT NULL, query TEXT NOT NULL, expected TEXT);
        """)
        aliases: dict[str, set[tuple[str, str]]] = {}
        cards_total = 0
        for path in sorted(resources.glob("*.json")):
            resource = json_file(path)
            package_id = str(resource["packageID"])
            package_number = sequence.get(package_id)
            if package_number is None:
                die("development index resource not in P1-P15 " + path.name)
            checksum = sha(path)
            cards = resource.get("canonicalCards", [])
            utterances = resource.get("utterances", [])
            if not isinstance(cards, list) or not isinstance(utterances, list):
                die("development index resource shape drift " + path.name)
            cursor.execute("INSERT INTO package_totals VALUES (?,?,?,?,?)", (package_id, package_number, len(cards), len(utterances), checksum))
            for package_index, card in enumerate(cards, start=1):
                if not isinstance(card, dict) or not isinstance(card.get("id"), str):
                    die("development index card identity drift " + path.name)
                source_groups = {
                    "official_or_authoritative": card.get("authoritativeSupportingSourceIDs") or [],
                    "primary_research": card.get("primaryResearchSourceIDs") or [],
                    "professional_practice": card.get("professionalPracticeSourceIDs") or [],
                    "discovery_language": card.get("discoveryLanguageSourceIDs") or [],
                    "standards": card.get("standardsSourceIDs") or [],
                }
                sources = sorted({str(source) for values in source_groups.values() for source in values})
                cursor.execute("INSERT INTO canonical_cards VALUES (?,?,?,?,?,?,?)", (card["id"], package_id, package_number, card.get("domain"), json.dumps(sources, separators=(",", ":")), card.get("originalReviewStatus"), checksum))
                for source_class, values in source_groups.items():
                    cursor.executemany("INSERT OR IGNORE INTO source_provenance VALUES (?,?,?)", [(card["id"], str(source), source_class) for source in values])
                fixture = normalized(f"TrackSmith exact Package {package_number:03d} reference exactpkg{package_number:03d}qa{package_index:06d}")
                cursor.execute("INSERT INTO test_only_exact_fixtures VALUES (?,?,?,?)", (fixture, card["id"], package_id, "exact_unique"))
                cards_total += 1
            for utterance in utterances:
                if isinstance(utterance, dict) and isinstance(utterance.get("text"), str) and isinstance(utterance.get("canonicalID"), str):
                    alias = normalized(utterance["text"])
                    if alias:
                        aliases.setdefault(alias, set()).add((utterance["canonicalID"], package_id))
        for alias, values in sorted(aliases.items()):
            if len({identifier for identifier, _ in values}) > 1:
                ordered = sorted(values)
                cursor.execute("INSERT INTO natural_alias_collisions VALUES (?,?,?,?)", (alias, json.dumps([item[0] for item in ordered], separators=(",", ":")), json.dumps(sorted({item[1] for item in ordered}), separators=(",", ":")), "diagnostic_ambiguous_alias"))
        p16_tests = DESTINATION / "tests/retrieval_cases.jsonl"
        for line in p16_tests.read_text(encoding="utf-8").splitlines():
            test = json.loads(line)
            cursor.execute("INSERT INTO package16_test_cases VALUES (?,?,?,?)", (test["id"], test["kind"], test["query"], test.get("expected")))
        metadata = {"schema_version": "1.0", "index_kind": "research_only_unified_development_index",
                    "p16_archive_sha256": ARCHIVE_SHA256, "p16_policy_version": "package16-runtime-projection/1.0",
                    "immutable_audited_baseline_canonical": "6134", "selected_current_canonical": str(cards_total),
                    "selected_overlay_canonical_delta": str(cards_total - 6134), "supplied_p16_database_used": "false"}
        cursor.executemany("INSERT INTO metadata VALUES (?,?)", sorted(metadata.items()))
        connection.commit()
        integrity = cursor.execute("PRAGMA integrity_check").fetchone()[0]
        collision_count = cursor.execute("SELECT COUNT(*) FROM natural_alias_collisions").fetchone()[0]
        fixture_count = cursor.execute("SELECT COUNT(*) FROM test_only_exact_fixtures").fetchone()[0]
        if integrity != "ok" or cards_total != 6212 or fixture_count != 6212 or collision_count != 69:
            die(f"development index closure drift integrity={integrity} cards={cards_total} fixtures={fixture_count} collisions={collision_count}")
        connection.close()
        os.replace(temporary, index)
    except BaseException:
        if temporary.exists():
            temporary.unlink()
        raise
    check_baseline()
    print(f"P16_DEVELOPMENT_INDEX_OK path={index} integrity=ok cards=6212 fixtures=6212 collisions=69")


def check_development_index(index: pathlib.Path) -> None:
    index = index.expanduser().resolve()
    if index.is_symlink() or not index.is_file():
        die("development index missing or unsafe")
    connection = sqlite3.connect(f"file:{index}?mode=ro", uri=True)
    try:
        cursor = connection.cursor()
        integrity = cursor.execute("PRAGMA integrity_check").fetchone()[0]
        counts = {table: cursor.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] for table in ("package_totals", "canonical_cards", "test_only_exact_fixtures", "natural_alias_collisions", "package16_test_cases")}
        if integrity != "ok" or counts != {"package_totals": 15, "canonical_cards": 6212, "test_only_exact_fixtures": 6212, "natural_alias_collisions": 69, "package16_test_cases": 5}:
            die("development index check drift " + json.dumps({"integrity": integrity, **counts}, sort_keys=True))
    finally:
        connection.close()
    print("P16_DEVELOPMENT_INDEX_CHECK_OK integrity=ok packages=15 cards=6212 fixtures=6212 collisions=69")


def dependency_resolution() -> dict[str, str]:
    registry = json_file(REGISTRY)
    output: dict[str, str] = {}
    canonical = {
        1: "tracksmith-corpus-001-vocal-quantization",
        2: "tracksmith-corpus-002-level-balancing-eq",
        3: "tracksmith-corpus-003-compression-arrangement-frequency-allocation",
        4: "tracksmith-corpus-004-reverb-delay",
    }
    for row in registry["packages"]:
        if not isinstance(row, dict) or not 1 <= row.get("package_number", 0) <= 15:
            continue
        package_id = str(row["package_id"])
        number = int(row["package_number"])
        output[canonical.get(number, package_id)] = package_id
    # The package manifest uses canonical predecessor identifiers while P1-P4 are legacy paths.
    return {"dependencyResolutionVersion": "1.0", "selectedPackageIDs": output,
            "P2P3SupersedingOverlays": P2_P3_CURRENT,
            "noArchiveReplacement": True}


def copy_allowlisted(incoming: pathlib.Path, staging: pathlib.Path, allowed: dict[str, str]) -> None:
    for relative in sorted(allowed):
        source = incoming / relative
        destination = staging / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination, follow_symlinks=False)
        if sha(destination) != allowed[relative]:
            die("staging copy drift " + relative)


def stage(incoming: pathlib.Path, evidence: dict[str, object], dry_run: bool) -> None:
    check_baseline()
    allowed = package_allowlist(incoming)
    if DESTINATION.exists() or REPORT.exists() or DEPENDENCY.exists() or RECONCILIATION.exists():
        die("P16 destination/evidence already exists; refuses replacement")
    planned = [str(DESTINATION.relative_to(ROOT)), str(REGISTRY.relative_to(ROOT)),
               str(DEPENDENCY.relative_to(ROOT)), str(REPORT.relative_to(ROOT)), str(RECONCILIATION.relative_to(ROOT))]
    if dry_run:
        print("P16_DRY_RUN_OK writes=0 additivePaths=" + json.dumps(planned, separators=(",", ":")))
        return
    before = {relative: sha(path) for relative, path in regular_files(COMMUNITY).items()}
    original_registry = REGISTRY.read_bytes()
    staged_registry_sha: str | None = None
    temporary = pathlib.Path(tempfile.mkdtemp(prefix=".p16-stage-", dir=DESTINATION.parent))
    created: list[pathlib.Path] = []
    try:
        copy_allowlisted(incoming, temporary, allowed)
        if tree_digest(temporary) != {"fileCount": 47, "sha256": TREE_SHA256}:
            die("P16 temporary tree drift")
        os.replace(temporary, DESTINATION); created.append(DESTINATION)
        write_json_new(DEPENDENCY, dependency_resolution()); created.append(DEPENDENCY)
        write_json_new(RECONCILIATION, evidence); created.append(RECONCILIATION)
        registry = json_file(REGISTRY)
        registry["packages"].append({"package_id": PID, "package_number": 16, "package_version": "1.0.0",
            "contract_version": "1.0", "path": str(DESTINATION.relative_to(ROOT)),
            "review_state": "infrastructure_review_required", "logic_procedure_status": "not_applicable_no_new_procedures",
            "package_type": "integration_framework", "runtime_resource": "none", "package_manifest_sha256": MANIFEST_SHA256,
            "immutableBaselineCanonical": 6134, "selectedCurrentCanonical": 6212, "overlayCanonicalDelta": 78,
            "migration_adapter": "package16-integration-reconciliation/1.0", "synthesized_fields_labeled": True})
        write_json_new(REGISTRY.with_name(REGISTRY.name + ".p16-new"), registry)
        os.replace(REGISTRY.with_name(REGISTRY.name + ".p16-new"), REGISTRY); created.append(REGISTRY)
        staged_registry_sha = sha(REGISTRY)
        write_json_new(REPORT, {"status": "staged", "package_id": PID, "package_type": "integration_framework",
            "record_counts": {key: 0 for key in sorted(P16_ZERO_SUBJECT_KINDS)} | {"sources": 17},
            "staged_tree": {"fileCount": 47, "sha256": TREE_SHA256}, "archive_sha256": ARCHIVE_SHA256,
            "incoming_importer_executed": False, "force_semantics": False, "runtime_subject_resource_emitted": False,
            "development_sqlite_research_only": True, "reconciliation": evidence}); created.append(REPORT)
        after = {relative: sha(path) for relative, path in regular_files(COMMUNITY).items()}
        changed = {path for path in set(before) | set(after) if before.get(path) != after.get(path)}
        expected = {str(path.relative_to(COMMUNITY)) for path in [DEPENDENCY, RECONCILIATION, REGISTRY, REPORT]}
        expected |= {str(path.relative_to(COMMUNITY)) for path in [DESTINATION, *DESTINATION.rglob("*")] if path.is_file()}
        if changed != expected:
            die("post-stage allowlisted delta drift")
        check_baseline()
    except BaseException:
        # Roll back only our exact registry replacement.  A concurrent writer changes the
        # digest and is never overwritten or silently repaired by this recovery path.
        if staged_registry_sha is not None and REGISTRY.is_file() and sha(REGISTRY) == staged_registry_sha:
            atomic_replace_bytes(REGISTRY, original_registry)
        for target in reversed(created):
            if target == REGISTRY or not target.exists():
                continue
            if target.is_dir():
                shutil.rmtree(target)
            else:
                target.unlink()
        if temporary.exists(): shutil.rmtree(temporary)
        raise
    print("P16_STAGE_OK writes=%d packageFiles=47 baselineCanonical=6134 overlayCanonical=78 selectedCanonical=6212" % len(expected))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--incoming", type=pathlib.Path, required=True)
    parser.add_argument("--archive", type=pathlib.Path, required=True)
    parser.add_argument("--sidecar", type=pathlib.Path, required=True)
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--supplied-claim-only", action="store_true")
    parser.add_argument("--capture-baseline", action="store_true")
    parser.add_argument("--check-preservation", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--stage", action="store_true")
    parser.add_argument("--audit-runtime-projection", action="store_true")
    parser.add_argument("--build-development-index", type=pathlib.Path)
    parser.add_argument("--check-development-index", type=pathlib.Path)
    args = parser.parse_args()
    if sum((args.preflight, args.supplied_claim_only, args.capture_baseline, args.check_preservation, args.dry_run, args.stage, args.audit_runtime_projection, args.build_development_index is not None, args.check_development_index is not None)) != 1:
        die("select exactly one action")
    incoming = args.incoming.resolve()
    evidence = preflight(incoming, args.archive.resolve(), args.sidecar.resolve())
    if args.supplied_claim_only:
        die("SUPPLIED_P16_AGGREGATE_STALE baselineCanonical=6134 selectedCanonical=6212 overlayCanonical=78")
    if args.preflight:
        print("P16_PREFLIGHT_OK files=47 zeroSubjectRecords=true baselineCanonical=6134 overlayCanonical=78 selectedCanonical=6212 suppliedClaim=STALE")
    elif args.capture_baseline:
        write_json_new(BASELINE, state_fingerprint())
        print("P16_PRESERVATION_BASELINE_CAPTURED packages=15")
    elif args.check_preservation:
        check_baseline(); print("P16_PRESERVATION_OK packages=15")
    elif args.audit_runtime_projection:
        audit_runtime_projection()
    elif args.build_development_index is not None:
        build_development_index(args.build_development_index)
    elif args.check_development_index is not None:
        check_development_index(args.check_development_index)
    else:
        stage(incoming, evidence, args.dry_run)


if __name__ == "__main__":
    main()
