#!/usr/bin/env python3
"""Regression coverage for warm and one-miss Tutor cache execution."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import deterministic_case_cache as cache
from aggregate_shards import aggregate
from run_tutor_cached import components, semantic
from shard_protocol import build_contract, digest


def list_contexts(binary: Path, root: Path) -> dict[str, tuple[str, str, str, str]]:
    output = subprocess.run([str(binary), "--list-tests"], cwd=root, check=True, text=True, capture_output=True).stdout
    rows = [line.split("\t") for line in output.splitlines()]
    assert rows and all(len(row) == 5 and all(field for field in row) for row in rows), "invalid --list-tests context rows"
    return {identifier: (resource, name, implementation, shared) for identifier, resource, name, implementation, shared in rows}


def main(binary: Path) -> None:
    binary = binary.resolve()
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory() as directory:
        temporary = Path(directory); listing = temporary / "list.tsv"
        listing.write_text(subprocess.run([str(binary), "--list-tests"], cwd=root, check=True, text=True, capture_output=True).stdout)
        contract = build_contract(root / "ci/tutor_test_costs.json", root, listing, "local", "local-observational", "test-toolchain")
        contract_path = temporary / "contract.json"; contract_path.write_text(json.dumps(contract))
        listed = {fields[0]: (fields[1], fields[2], fields[3], fields[4]) for fields in (line.split("\t") for line in listing.read_text().splitlines())}
        cache_root = temporary / "cache"
        for identifier, (resource_class, name, case_implementation, shared_evaluator) in listed.items():
            value = semantic(contract, identifier, resource_class, name, case_implementation, shared_evaluator)
            cache.store(cache_root, components(contract, identifier, value, shared_evaluator), {"case_id": identifier, "semantic_input_hash": value, "outcome": "passed", "result_hash": digest(f"{identifier}|passed|{value}")})
        fake = temporary / "fake-tutor.py"; counter = temporary / "counter"
        fake.write_text("""#!/usr/bin/env python3
import hashlib, json, os, sys
contract=json.load(open(os.environ['TRACKSMITH_TEST_CONTRACT']))
listed={line.split('\\t')[0]:(line.split('\\t')[1],line.split('\\t')[2],line.split('\\t')[3],line.split('\\t')[4]) for line in open(os.environ['TRACKSMITH_TEST_LIST']).read().splitlines()}
identifier=sys.argv[sys.argv.index('--include')+1]
resource,name,case_implementation,shared_evaluator=listed[identifier]
semantic=hashlib.sha256('|'.join((contract['suite_id'],contract['suite_version'],identifier,name,resource,case_implementation,shared_evaluator,contract['policy_hash'],contract['index_hash'],'ordinary-case-schema-v2')).encode()).hexdigest()
value={'id':identifier,'semantic_input_hash':semantic,'outcome':'passed','duration_seconds':0.01,'result_hash':hashlib.sha256(f'{identifier}|passed|{semantic}'.encode()).hexdigest(),'resource_class':resource}
output=sys.argv[sys.argv.index('--output-json')+1]
json.dump({'cases':[value]},open(output,'w'))
open(os.environ['TRACKSMITH_TEST_COUNTER'],'a').write(identifier+'\\n')
""")
        fake.chmod(0o700)
        environment = {**os.environ, "TRACKSMITH_TEST_CONTRACT": str(contract_path), "TRACKSMITH_TEST_LIST": str(listing), "TRACKSMITH_TEST_COUNTER": str(counter)}
        command = [sys.executable, str(root / "scripts/ci/run_tutor_cached.py"), "--binary", str(fake), "--contract", str(contract_path), "--list", str(listing), "--cache-root", str(cache_root), "--output-dir", str(temporary / "warm"), "--shard-count", "3", "--cost-manifest", str(root / "ci/tutor_test_costs.json"), "--repo-root", str(root)]
        subprocess.run(command, cwd=root, check=True, env=environment, capture_output=True, text=True)
        assert not counter.exists(), "warm cache invoked the binary"
        aggregate(sorted((temporary / "warm").glob("shard-*.json")), contract=contract)
        target = sorted(listed)[0]; resource_class, name, case_implementation, shared_evaluator = listed[target]; value = semantic(contract, target, resource_class, name, case_implementation, shared_evaluator)
        cache.path_for(cache_root, cache.key(components(contract, target, value, shared_evaluator))).unlink()
        partial = [*command]; partial[partial.index("--output-dir") + 1] = str(temporary / "partial")
        subprocess.run(partial, cwd=root, check=True, env=environment, capture_output=True, text=True)
        assert counter.read_text().splitlines() == [target], "one cache miss did not execute exactly one case"
        aggregate(sorted((temporary / "partial").glob("shard-*.json")), contract=contract)
        changed = {**contract, "policy_hash": digest("changed-policy")}
        assert all(cache.load(cache_root, components(changed, identifier, semantic(changed, identifier, resource, name, case_implementation, shared_evaluator), shared_evaluator)) is None for identifier, (resource, name, case_implementation, shared_evaluator) in listed.items())
        changed_shared = {identifier: (resource, name, case_implementation, digest("changed-package-or-resource")) for identifier, (resource, name, case_implementation, _) in listed.items()}
        assert all(cache.load(cache_root, components(contract, identifier, semantic(contract, identifier, resource, name, case_implementation, shared_evaluator), shared_evaluator)) is None for identifier, (resource, name, case_implementation, shared_evaluator) in changed_shared.items())
        mutation_root = temporary / "resource-mutation-root"
        source_relative = Path("tools/TutorConversationTests/Sources/TutorConversationTests/TutorConversationTests.swift")
        source_copy = mutation_root / source_relative
        source_copy.parent.mkdir(parents=True)
        shutil.copy2(root / source_relative, source_copy)
        resource_relative = Path("research/community_knowledge/packages/tracksmith-corpus-015-midi-cc-piano-roll-bounce-freeze-pdc-object-model/knowledge_candidates/strategies.jsonl")
        resource_copy = mutation_root / resource_relative
        resource_copy.parent.mkdir(parents=True)
        shutil.copy2(root / resource_relative, resource_copy)
        before_resource_mutation = list_contexts(binary, mutation_root)
        resource_copy.write_text(resource_copy.read_text() + "\n")
        after_resource_mutation = list_contexts(binary, mutation_root)
        assert before_resource_mutation.keys() == after_resource_mutation.keys() == listed.keys()
        assert all(before_resource_mutation[identifier][2] == after_resource_mutation[identifier][2] for identifier in listed), "resource mutation changed a per-case body hash"
        assert all(before_resource_mutation[identifier][3] != after_resource_mutation[identifier][3] for identifier in listed), "Package 15 strategies mutation did not invalidate the shared execution closure"
        mutation_cache = temporary / "resource-mutation-cache"
        for identifier, (resource, name, case_implementation, shared_evaluator) in before_resource_mutation.items():
            value = semantic(contract, identifier, resource, name, case_implementation, shared_evaluator)
            cache.store(mutation_cache, components(contract, identifier, value, shared_evaluator), {"case_id": identifier, "semantic_input_hash": value, "outcome": "passed", "result_hash": digest(f"{identifier}|passed|{value}")})
        assert all(cache.load(mutation_cache, components(contract, identifier, semantic(contract, identifier, resource, name, case_implementation, shared_evaluator), shared_evaluator)) is None for identifier, (resource, name, case_implementation, shared_evaluator) in after_resource_mutation.items()), "Package 15 strategies mutation reused a stale cache entry"
    print("test-tutor-cache-runner: warm hits, one-case miss execution, aggregate equivalence, and policy/shared/Package-15-resource invalidation passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--binary", type=Path, required=True); args = parser.parse_args(); main(args.binary)
