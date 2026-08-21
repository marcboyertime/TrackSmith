#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import py_compile
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    'README.md','package_manifest.json','PACKAGE_SHA256SUMS.txt',
    'integration/START_HERE_FOR_CODEX.md','integration/PACKAGE_SEQUENCE.md',
    'integration/TRACKSMITH_IMPORT_PLAN.md','integration/REVIEW_CHECKLIST.md',
    'integration/TOOL_CONTRACT.md','integration/integration_manifest.json',
    'corpus/canonical_qa.jsonl','corpus/user_utterances.jsonl',
    'corpus/multiturn_scenarios.jsonl','corpus/retrieval_evaluations.jsonl',
    'corpus/contradictions.jsonl','corpus/myths_and_antipatterns.jsonl',
    'knowledge_candidates/claims.jsonl','knowledge_candidates/strategies.jsonl',
    'knowledge_candidates/logic_procedures.jsonl','sources/source_registry.jsonl',
    'sources/source_access_manifest.json','sources/provenance_manifest.jsonl',
    'schemas/canonical_qa.schema.json','schemas/user_utterance.schema.json',
    'schemas/multiturn_scenario.schema.json','schemas/retrieval_evaluation.schema.json',
    'schemas/contradiction.schema.json','schemas/myth.schema.json',
    'schemas/claim_candidate.schema.json','schemas/strategy_candidate.schema.json',
    'schemas/logic_procedure_candidate.schema.json','database/corpus.sqlite',
    'database/database_manifest.json','tools/validate_package.py',
    'tools/build_database.py','tools/query_corpus.py','tools/inspect_package.py',
    'tools/import_to_tracksmith.py','tests/retrieval_cases.jsonl',
    'tests/integrity_cases.jsonl','tests/expected_statistics.json',
    'reports/COVERAGE_REPORT.md','reports/SOURCE_REPORT.md',
    'reports/QUALITY_BOUNDARIES.md','reports/VALIDATION_REPORT.md',
    'examples/example_canonical_record.json','examples/example_multiturn_scenario.json',
    'examples/example_queries.md',
]
EMPTY_INFRASTRUCTURE_FILES = [
    'corpus/canonical_qa.jsonl','corpus/user_utterances.jsonl',
    'corpus/multiturn_scenarios.jsonl','corpus/retrieval_evaluations.jsonl',
    'corpus/contradictions.jsonl','corpus/myths_and_antipatterns.jsonl',
    'knowledge_candidates/claims.jsonl','knowledge_candidates/strategies.jsonl',
    'knowledge_candidates/logic_procedures.jsonl','sources/provenance_manifest.jsonl',
]
STATUS_FIELDS = [
    'review_state','native_review_state','original_review_state',
    'original_verification_status','runtime_eligibility',
]
FORBIDDEN_RUNTIME_KEYS = {
    'logic_guidance','logic_procedure_status','logic_verification_status','location',
    'steps','show_me_query','visual_target_query','verification_status','procedure_id',
    'execution_authority','scenario_type','messages','evaluation_type',
    'expected_canonical_ids','expected_top_1','retrieval_expectation','test_fixture',
    'exact_fixture','sqlite_path','database_path','menu_path','navigation',
}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with path.open(encoding='utf-8') as f:
        return [json.loads(line) for line in f if line.strip()]


def load_importer():
    spec = importlib.util.spec_from_file_location('pkg016_importer', ROOT / 'tools/import_to_tracksmith.py')
    if spec is None or spec.loader is None:
        raise RuntimeError('Could not load Package 016 importer')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def recurse_runtime(obj: Any, path: str = '$') -> list[str]:
    errors: list[str] = []
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in FORBIDDEN_RUNTIME_KEYS:
                errors.append(f'{path}.{key}')
            errors.extend(recurse_runtime(value, f'{path}.{key}'))
    elif isinstance(obj, list):
        for index, value in enumerate(obj):
            errors.extend(recurse_runtime(value, f'{path}[{index}]'))
    elif isinstance(obj, str):
        lower = obj.casefold()
        if 'corpus.sqlite' in lower or lower.endswith('.sqlite') or 'expected_top_1' in lower:
            errors.append(path)
    return errors


def load_sums() -> dict[str, str]:
    result: dict[str, str] = {}
    for line in (ROOT / 'PACKAGE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        digest, rel = line.split(maxsplit=1)
        result[rel.strip()] = digest
    return result


def fts_query(text: str) -> str:
    import re
    normalized = ' '.join(re.sub(r'[^\w]+', ' ', text.casefold()).split())
    terms = [t for t in normalized.split() if len(t) > 1][:24]
    return ' OR '.join(f'"{t}"' for t in terms) or '"__none__"'


def validate_archive_matches_root(archive: Path, errors: list[dict]) -> None:
    if not archive.exists():
        errors.append({'archive_missing': str(archive)})
        return
    try:
        with zipfile.ZipFile(archive) as z:
            bad = z.testzip()
            if bad:
                errors.append({'zip_crc_failure': bad})
                return
            roots = {name.split('/')[0] for name in z.namelist() if name and not name.startswith('__MACOSX/')}
            if len(roots) != 1:
                errors.append({'archive_root_count': sorted(roots)})
                return
            root = next(iter(roots))
            archive_files = sorted(
                name[len(root) + 1:] for name in z.namelist()
                if name.startswith(root + '/') and not name.endswith('/')
            )
            if archive_files != sorted(REQUIRED):
                errors.append({'archive_structure': {
                    'missing': sorted(set(REQUIRED) - set(archive_files)),
                    'extra': sorted(set(archive_files) - set(REQUIRED)),
                }})
            for rel in REQUIRED:
                member = f'{root}/{rel}'
                if member not in z.namelist() or not (ROOT / rel).exists():
                    continue
                archive_digest = hashlib.sha256(z.read(member)).hexdigest()
                local_digest = sha256_file(ROOT / rel)
                if archive_digest != local_digest:
                    errors.append({'archive_local_mismatch': rel})
    except zipfile.BadZipFile as exc:
        errors.append({'invalid_zip': str(exc)})


def validate_package_database(errors: list[dict], manifest: dict) -> None:
    db_path = ROOT / 'database/corpus.sqlite'
    connection = sqlite3.connect(db_path)
    try:
        integrity = connection.execute('PRAGMA integrity_check').fetchone()[0]
        if integrity != 'ok':
            errors.append({'database_integrity': integrity})
        expected = manifest['record_counts']
        actual_sources = connection.execute('SELECT COUNT(*) FROM sources').fetchone()[0]
        actual_audio = connection.execute('SELECT COUNT(*) FROM audio_datasets').fetchone()[0]
        if actual_sources != expected['sources']:
            errors.append({'database_source_count': [actual_sources, expected['sources']]})
        if actual_audio != expected['sources']:
            errors.append({'database_audio_dataset_count': [actual_audio, expected['sources']]})
        for table in [
            'canonical_qa','user_utterances','multiturn_scenarios','retrieval_evaluations',
            'contradictions','myths_and_antipatterns','claim_candidates',
            'strategy_candidates','logic_procedure_candidates','provenance',
        ]:
            count = connection.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0]
            if count != 0:
                errors.append({'infrastructure_database_nonempty': {table: count}})
    finally:
        connection.close()


def validate_audio_manifest(errors: list[dict], manifest: dict) -> None:
    access = json.loads((ROOT / 'sources/source_access_manifest.json').read_text(encoding='utf-8'))
    datasets = access.get('datasets', [])
    ids = [d.get('id') for d in datasets]
    if len(ids) != len(set(ids)):
        errors.append({'duplicate_audio_dataset_ids': True})
    if len(datasets) != manifest['record_counts']['sources']:
        errors.append({'audio_dataset_count': [len(datasets), manifest['record_counts']['sources']]})
    profiles = access.get('profiles', {})
    if not {'smoke','standard','full','request_required'}.issubset(profiles):
        errors.append({'missing_audio_profiles': sorted({'smoke','standard','full','request_required'} - set(profiles))})
    by_id = {d['id']: d for d in datasets}
    for profile, definition in profiles.items():
        for dataset_id in definition.get('dataset_ids', []):
            if dataset_id not in by_id:
                errors.append({'audio_profile_missing_dataset': [profile, dataset_id]})
    smoke = [by_id[x] for x in profiles.get('smoke', {}).get('dataset_ids', []) if x in by_id]
    if not any('audio' in d.get('tags', []) or 'multitrack' in d.get('tags', []) or 'loudness' in d.get('tags', []) for d in smoke):
        errors.append({'smoke_profile_has_no_waveform_source': True})
    if not any('midi' in d.get('tags', []) for d in smoke):
        errors.append({'smoke_profile_has_no_midi_source': True})
    for dataset in datasets:
        if not dataset.get('canonical_url', '').startswith('https://'):
            errors.append({'invalid_dataset_url': dataset.get('id')})
        download = dataset.get('download') or {}
        if download.get('kind') == 'direct' and not download.get('url', '').startswith('https://'):
            errors.append({'invalid_direct_download_url': dataset.get('id')})
        if download.get('kind') == 'request_required' and dataset.get('access_mode') != 'request_required':
            errors.append({'request_status_mismatch': dataset.get('id')})


def validate_unified_bundle(summary: dict, unified: Path, errors: list[dict], expected: dict, package_manifest: dict) -> None:
    mapping = {
        'canonical_qa': 'canonical', 'user_utterances': 'utterances',
        'multiturn_scenarios': 'scenarios', 'retrieval_evaluations': 'evaluations',
        'contradictions': 'contradictions', 'myths_and_antipatterns': 'myths',
        'claim_candidates': 'claims', 'strategy_candidates': 'strategies',
        'logic_procedure_candidates': 'procedures', 'sources': 'sources',
        'provenance': 'provenance',
    }
    for key, value in expected['post_migration_counts'].items():
        actual = summary['counts'].get(mapping[key])
        if actual != value:
            errors.append({'aggregate_count_mismatch': {key: [actual, value]}})
    if summary.get('exact_fixture_count') != expected['exact_fixture_count']:
        errors.append({'exact_fixture_count': [summary.get('exact_fixture_count'), expected['exact_fixture_count']]})
    if summary.get('runtime_counts', {}).get('canonical') != expected['prior_aggregate_counts']['canonical_qa']:
        errors.append({'runtime_canonical_count': summary.get('runtime_counts', {}).get('canonical')})
    if summary.get('retrieval_budget') != expected['required_runtime_retrieval_budget']:
        errors.append({'retrieval_budget': summary.get('retrieval_budget')})
    actual_packages = {x['package_id']: x for x in summary.get('packages', [])}
    expected_inventory = {x['package_id']: x for x in package_manifest['prior_package_inventory']}
    if set(actual_packages) != set(expected_inventory):
        errors.append({'prior_package_id_set': {
            'actual': sorted(actual_packages), 'expected': sorted(expected_inventory),
        }})
    for pid, record in actual_packages.items():
        expected_record = expected_inventory.get(pid)
        if expected_record and record.get('sha256') != expected_record.get('archive_sha256'):
            errors.append({'prior_archive_hash_changed': pid})

    db = sqlite3.connect(unified / 'unified_corpus.sqlite')
    db.row_factory = sqlite3.Row
    try:
        integrity = db.execute('PRAGMA integrity_check').fetchone()[0]
        if integrity != 'ok':
            errors.append({'unified_database_integrity': integrity})
        exact_count = db.execute('SELECT COUNT(*) FROM exact_fixture_aliases').fetchone()[0]
        exact_unique_aliases = db.execute('SELECT COUNT(DISTINCT normalized_alias) FROM exact_fixture_aliases').fetchone()[0]
        exact_unique_ids = db.execute('SELECT COUNT(DISTINCT canonical_qa_id) FROM exact_fixture_aliases').fetchone()[0]
        if not (exact_count == exact_unique_aliases == exact_unique_ids == expected['exact_fixture_count']):
            errors.append({'exact_reference_uniqueness': [exact_count, exact_unique_aliases, exact_unique_ids]})
        missing_targets = db.execute('''
            SELECT COUNT(*) FROM exact_fixture_aliases e
            LEFT JOIN canonical_qa c ON c.id=e.canonical_qa_id
            WHERE c.id IS NULL
        ''').fetchone()[0]
        if missing_targets:
            errors.append({'exact_reference_missing_targets': missing_targets})
        collision_count = db.execute('SELECT COUNT(*) FROM alias_collisions').fetchone()[0]
        if collision_count != summary.get('alias_collision_count'):
            errors.append({'alias_collision_count': [collision_count, summary.get('alias_collision_count')]})

        # Representative bounded retrieval: nonempty, <=4, <=2/package, <=2/domain.
        retrieval_cases = read_jsonl(ROOT / 'tests/retrieval_cases.jsonl')
        for case in retrieval_cases:
            query = case.get('query', '')
            kind = case.get('kind', '')
            if not query or kind == 'runtime_purity':
                continue
            if kind == 'exact_fixture_policy':
                import re
                normalized = ' '.join(re.sub(r'[^\w]+', ' ', query.casefold()).split())
                exact = db.execute(
                    'SELECT canonical_qa_id FROM exact_fixture_aliases WHERE normalized_alias=?',
                    (normalized,),
                ).fetchall()
                if len(exact) != 1:
                    errors.append({'exact_fixture_lookup': [query, len(exact)]})
                continue
            try:
                rows = db.execute('''
                    SELECT c.*, bm25(canonical_qa_fts) AS rank
                    FROM canonical_qa_fts f JOIN canonical_qa c ON c.id=f.id
                    WHERE canonical_qa_fts MATCH ? ORDER BY rank LIMIT 80
                ''', (fts_query(query),)).fetchall()
            except sqlite3.OperationalError as exc:
                errors.append({'fts_query_failed': [query, str(exc)]})
                continue
            selected = []
            per_package: dict[str, int] = {}
            per_domain: dict[str, int] = {}
            for row in rows:
                if len(selected) >= 4:
                    break
                package_id, domain = row['package_id'], row['domain']
                if per_package.get(package_id, 0) >= 2 or per_domain.get(domain, 0) >= 2:
                    continue
                selected.append(row['id'])
                per_package[package_id] = per_package.get(package_id, 0) + 1
                per_domain[domain] = per_domain.get(domain, 0) + 1
            if case.get('expect_nonempty', True) and not selected:
                errors.append({'retrieval_empty': query})
            if len(selected) > 4 or any(v > 2 for v in per_package.values()) or any(v > 2 for v in per_domain.values()):
                errors.append({'retrieval_budget_violation': query})
    finally:
        db.close()

    for rel in ['unified_canonical.runtime.jsonl', 'unified_utterances.runtime.jsonl']:
        rows = read_jsonl(unified / rel)
        runtime_errors: list[str] = []
        for index, row in enumerate(rows):
            runtime_errors.extend(recurse_runtime(row, f'{rel}[{index}]'))
            if rel.startswith('unified_canonical'):
                for field in STATUS_FIELDS:
                    if field not in row:
                        runtime_errors.append(f'{rel}[{index}].missing:{field}')
        if runtime_errors:
            errors.append({'runtime_projection_purity': runtime_errors[:50]})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive')
    parser.add_argument('--prior-packages')
    parser.add_argument('--target')
    parser.add_argument('--full', action='store_true')
    args = parser.parse_args()

    errors: list[dict] = []
    checks: list[str] = []
    package_manifest = json.loads((ROOT / 'package_manifest.json').read_text(encoding='utf-8'))
    integration_manifest = json.loads((ROOT / 'integration/integration_manifest.json').read_text(encoding='utf-8'))
    expected = json.loads((ROOT / 'tests/expected_statistics.json').read_text(encoding='utf-8'))

    files = sorted(str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    if files != sorted(REQUIRED):
        errors.append({'structure': {
            'missing': sorted(set(REQUIRED) - set(files)),
            'extra': sorted(set(files) - set(REQUIRED)),
        }})
    checks.append('exact_47_file_structure')

    if package_manifest.get('package_id') != 'tracksmith-corpus-016-integration-retrieval-quality-control':
        errors.append({'package_id': package_manifest.get('package_id')})
    if package_manifest.get('package_number') != 16 or integration_manifest.get('sequence') != 16:
        errors.append({'sequence': [package_manifest.get('package_number'), integration_manifest.get('sequence')]})
    if integration_manifest.get('prerequisites') != package_manifest.get('depends_on'):
        errors.append({'prerequisites_mismatch': True})
    if integration_manifest.get('namespace') != 'pkg016':
        errors.append({'namespace': integration_manifest.get('namespace')})
    checks.append('identity_and_prerequisites')

    for rel in EMPTY_INFRASTRUCTURE_FILES:
        if (ROOT / rel).read_text(encoding='utf-8').strip():
            errors.append({'infrastructure_only_violation': rel})
    checks.append('infrastructure_only_runtime_files')

    sums = load_sums()
    expected_sum_files = set(REQUIRED) - {'PACKAGE_SHA256SUMS.txt'}
    if set(sums) != expected_sum_files:
        errors.append({'checksum_coverage': {
            'missing': sorted(expected_sum_files - set(sums)),
            'extra': sorted(set(sums) - expected_sum_files),
        }})
    for rel, digest in sums.items():
        path = ROOT / rel
        if not path.exists() or sha256_file(path) != digest:
            errors.append({'hash_mismatch': rel})
    for rel, digest in integration_manifest.get('file_hashes', {}).items():
        path = ROOT / rel
        if not path.exists() or sha256_file(path) != digest:
            errors.append({'integration_hash_mismatch': rel})
    checks.append('internal_hashes')

    validate_package_database(errors, package_manifest)
    validate_audio_manifest(errors, package_manifest)
    checks.extend(['package_database', 'audio_source_manifest'])

    for script in (ROOT / 'tools').glob('*.py'):
        try:
            py_compile.compile(str(script), doraise=True)
        except py_compile.PyCompileError as exc:
            errors.append({'python_compile': [script.name, str(exc)]})
    checks.append('tool_compilation')

    if args.archive:
        validate_archive_matches_root(Path(args.archive).resolve(), errors)
        checks.append('archive_crc_structure_and_local_parity')

    unified_summary = None
    if args.prior_packages:
        importer = load_importer()
        with tempfile.TemporaryDirectory(prefix='pkg016-validation-') as temp_dir:
            unified = Path(temp_dir) / 'unified'
            try:
                unified_summary = importer.build_unified_bundle(Path(args.prior_packages).resolve(), unified)
            except BaseException as exc:
                errors.append({'unified_build_failed': str(exc)})
            else:
                validate_unified_bundle(unified_summary, unified, errors, expected, package_manifest)
                checks.extend(['legacy_migration', 'unified_database', 'exact_reference_uniqueness', 'bounded_retrieval', 'runtime_projection_purity'])

                if args.target:
                    target = Path(args.target).resolve()
                    if not (target / '.git').exists():
                        errors.append({'target_not_git_checkout': str(target)})
                    else:
                        process = subprocess.run([
                            sys.executable, str(ROOT / 'tools/import_to_tracksmith.py'),
                            '--target', str(target), '--prior-packages', str(Path(args.prior_packages).resolve()),
                            '--prebuilt-unified', str(unified), '--dry-run',
                        ], capture_output=True, text=True, timeout=120)
                        if process.returncode != 0:
                            errors.append({'importer_dry_run': process.stderr[-4000:]})
                        else:
                            checks.append('importer_dry_run_with_prebuilt_bundle')

                if args.full:
                    try:
                        audio_plan = importer.prepare_audio_assets(
                            Path(temp_dir) / 'audio_plan', 'smoke', 2_000_000_000, False, plan_only=True
                        )
                        if not audio_plan.get('planned'):
                            errors.append({'audio_smoke_plan_empty': True})
                        if audio_plan.get('pending_access'):
                            # Smoke must not block on request-gated datasets.
                            errors.append({'audio_smoke_plan_request_gated': audio_plan['pending_access']})
                        checks.append('autonomous_public_audio_smoke_plan')
                    except BaseException as exc:
                        errors.append({'audio_plan_failed': str(exc)})

    report = {
        'status': 'FAIL' if errors else 'PASS',
        'package_id': package_manifest.get('package_id'),
        'checks_completed': checks,
        'errors': errors,
        'required_file_count': len(REQUIRED),
        'prior_package_count': len(package_manifest.get('depends_on', [])),
        'unified_summary': unified_summary,
    }
    report_path = ROOT.parent / f'{ROOT.name}_validation_report.json'
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + '\n', encoding='utf-8')
    report['external_report_path'] = str(report_path)
    print(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False))
    if errors:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
