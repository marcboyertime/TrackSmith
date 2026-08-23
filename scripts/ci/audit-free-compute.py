#!/usr/bin/env python3
"""Fail closed on paid, secret, unbounded, or unreviewed Actions changes."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[2]
ALLOWED_RUNNERS = {"ubuntu-24.04", "macos-15"}
APPROVED_ACTIONS = {
    "actions/checkout": "11d5960a326750d5838078e36cf38b85af677262",
    "actions/setup-python": "a26af69be951a213d495a4c3e4e4022e16d87065",
    "actions/upload-artifact": "ea165f8d65b6e75b540449e92b4886f43607fa02",
}
LANE_IDS = (
    "linux_integrity", "linux_retrieval", "linux_evaluation", "linux_docs_policy_security",
    "macos_swift_core", "macos_tutor", "macos_xcode_companion", "macos_xcode_au",
    "manual_heavy", "local_apple_logic_owner",
)
ACTION_LANES = set(LANE_IDS[:8])
LANE_FIELDS = {
    "id", "purpose", "operating_system", "architecture", "runner_label", "command",
    "timeout_minutes", "deterministic", "required", "requires_secrets", "requires_logic",
    "requires_signing_or_install", "artifact_outputs", "expected_maximum_artifact_bytes",
    "change_paths", "safe_for_fork_pull_requests",
}
EXCEPTION_FIELDS = {"workflow", "job", "rule", "reason", "owner", "reviewed_on", "expires_on"}
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
DISALLOWED_RUNNER = re.compile(r"self-hosted|larger|gpu|large|xlarge|windows|ubuntu-latest|macos-latest", re.I)
SECRET_REF = re.compile(r"\bsecrets\s*\.", re.I)
FORBIDDEN_COMMAND = re.compile(r"\b(?:openai|anthropic|claude|gemini|bedrock|vertex|azure|aws|gcloud|cloud[-_ ]?(?:eval|harness|text|audio)|model[-_ ]?eval)\b", re.I)
UNSAFE_ARTIFACT = re.compile(r"(?:^|/)(?:\.build|DerivedData|Applications|Library/Audio/Plug-Ins)(?:/|$)|\.(?:app|appex|sqlite|db|wav|aiff|mp3|flac)(?:$|\s)", re.I)


def parse_yaml(path: pathlib.Path) -> dict[str, Any]:
    if not shutil.which("ruby"):
        raise RuntimeError("Ruby with its standard Psych YAML parser is required")
    program = "require 'yaml'; require 'json'; puts JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: false))"
    result = subprocess.run(["ruby", "-e", program, str(path)], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"YAML parse failure: {result.stderr.strip() or result.stdout.strip()}")
    value = json.loads(result.stdout)
    if not isinstance(value, dict):
        raise RuntimeError("workflow must parse to a mapping")
    return value


def manifest_errors(manifest: Any, repo_root: pathlib.Path) -> list[str]:
    errors: list[str] = []
    if not isinstance(manifest, dict):
        return ["manifest: must be an object"]
    if manifest.get("schema_version") != "tracksmith-free-compute-lanes/1":
        errors.append("manifest: unsupported or missing schema_version")
    cache_policy = manifest.get("cache_policy")
    if not isinstance(cache_policy, dict) or not isinstance(cache_policy.get("enabled"), bool):
        errors.append("manifest: cache_policy.enabled must be boolean")
    lanes = manifest.get("lanes")
    if not isinstance(lanes, list) or {lane.get("id") for lane in lanes if isinstance(lane, dict)} != set(LANE_IDS) or len(lanes) != len(LANE_IDS):
        errors.append("manifest: lanes must contain exactly the 10 required lane IDs")
        lanes = []
    for lane in lanes:
        lane_id = lane.get("id", "<unknown>")
        if set(lane) != LANE_FIELDS:
            errors.append(f"manifest:{lane_id}: lane fields must exactly match the contract")
            continue
        if lane_id in ACTION_LANES:
            if lane["runner_label"] not in ALLOWED_RUNNERS:
                errors.append(f"manifest:{lane_id}: required Actions lane uses a nonstandard runner")
            if not lane["required"] or not isinstance(lane["timeout_minutes"], int) or lane["timeout_minutes"] <= 0:
                errors.append(f"manifest:{lane_id}: required Actions lane needs required=true and positive timeout")
            if any(lane[key] for key in ("requires_secrets", "requires_logic", "requires_signing_or_install")):
                errors.append(f"manifest:{lane_id}: required Actions lane must be no-secret, no-Logic, no-sign/install")
            command = lane["command"]
            match = re.fullmatch(r"bash (scripts/ci/[A-Za-z0-9_.-]+\.sh)", command)
            if not match or not (repo_root / (match.group(1) if match else "")).is_file():
                errors.append(f"manifest:{lane_id}: command must name an existing stable scripts/ci shell entry point")
        elif lane_id == "manual_heavy":
            match = re.fullmatch(r"bash (scripts/ci/[A-Za-z0-9_.-]+\.sh) <choice>", lane["command"])
            if not match or not (repo_root / (match.group(1) if match else "")).is_file():
                errors.append("manifest:manual_heavy: local command must name an existing choice entry point")
        elif lane_id == "local_apple_logic_owner":
            if lane["runner_label"] != "not an Actions lane" or lane["timeout_minutes"] != 0:
                errors.append("manifest:local_apple_logic_owner: must remain an owner-only non-Actions lane with timeout 0")
    exceptions = manifest.get("audit_exceptions")
    if not isinstance(exceptions, list):
        return errors + ["manifest: audit_exceptions must be a list"]
    for item in exceptions:
        if not isinstance(item, dict) or set(item) != EXCEPTION_FIELDS or any(not isinstance(item.get(key), str) or not item[key] for key in EXCEPTION_FIELDS):
            errors.append("manifest: audit exception must contain exactly workflow, job, rule, reason, owner, reviewed_on, expires_on")
            continue
        if any("*" in item[key] for key in ("workflow", "job", "rule")):
            errors.append("manifest: audit exception cannot use wildcards")
            continue
        try:
            reviewed = dt.date.fromisoformat(item["reviewed_on"])
            expires = dt.date.fromisoformat(item["expires_on"])
        except ValueError:
            errors.append("manifest: audit exception dates must be ISO dates")
            continue
        if reviewed > dt.date.today() or expires < dt.date.today():
            errors.append("manifest: audit exception is future-reviewed or expired")
    return errors


def exception_applies(manifest: dict[str, Any], workflow: str, job: str, rule: str) -> bool:
    return any((item["workflow"], item["job"], item["rule"]) == (workflow, job, rule) for item in manifest["audit_exceptions"])


def reject(errors: list[str], manifest: dict[str, Any], workflow: str, job: str, rule: str, detail: str) -> None:
    if not exception_applies(manifest, workflow, job, rule):
        errors.append(f"{workflow}:{job}: {rule}: {detail}")


def audit(workflow_dir: pathlib.Path, manifest_path: pathlib.Path) -> list[str]:
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        return [f"manifest: unreadable or invalid JSON: {error}"]
    errors = manifest_errors(manifest, ROOT)
    if errors:
        return errors
    for path in sorted((*workflow_dir.glob("*.yml"), *workflow_dir.glob("*.yaml"))):
        doc = parse_yaml(path)
        workflow, raw = path.name, path.read_text()
        if doc.get("permissions") != {"contents": "read"}:
            errors.append(f"{workflow}:<workflow>: permissions: top-level permissions must be exactly contents: read")
        triggers = doc.get("on", doc.get("true", doc.get(True)))
        if triggers == "pull_request_target" or (isinstance(triggers, (list, dict)) and "pull_request_target" in triggers):
            errors.append(f"{workflow}:<workflow>: pull_request_target: forbidden")
        jobs = doc.get("jobs")
        if not isinstance(jobs, dict) or not jobs:
            errors.append(f"{workflow}:<workflow>: jobs: missing jobs mapping")
            continue
        for job, body in jobs.items():
            if not isinstance(body, dict):
                errors.append(f"{workflow}:{job}: job: must be a mapping")
                continue
            if not isinstance(body.get("timeout-minutes"), int) or not 1 <= body["timeout-minutes"] <= 120:
                reject(errors, manifest, workflow, job, "timeout", "timeout-minutes must be an integer from 1 through 120")
            runner = body.get("runs-on")
            labels = runner if isinstance(runner, list) else [runner]
            if not labels or any(not isinstance(label, str) or label not in ALLOWED_RUNNERS or DISALLOWED_RUNNER.search(label) for label in labels):
                reject(errors, manifest, workflow, job, "runner", f"runs-on must use only {sorted(ALLOWED_RUNNERS)}")
            serialized = json.dumps(body)
            if SECRET_REF.search(serialized): reject(errors, manifest, workflow, job, "secrets", "secret references are forbidden")
            if FORBIDDEN_COMMAND.search(serialized): reject(errors, manifest, workflow, job, "cloud_model", "cloud/model command is forbidden")
            for step in body.get("steps", []) if isinstance(body.get("steps"), list) else []:
                if not isinstance(step, dict) or not isinstance(step.get("uses"), str): continue
                action, sep, pin = step["uses"].rpartition("@")
                if not sep or not FULL_SHA.fullmatch(pin):
                    reject(errors, manifest, workflow, job, "action_pin", f"action must use a full SHA: {step['uses']}")
                if action == "actions/cache" and not manifest["cache_policy"]["enabled"]:
                    reject(errors, manifest, workflow, job, "cache_policy", "actions/cache is prohibited while cache_policy.enabled is false")
                if action not in APPROVED_ACTIONS or pin != APPROVED_ACTIONS.get(action):
                    reject(errors, manifest, workflow, job, "action_allowlist", f"unreviewed action or SHA: {step['uses']}")
                if action == "actions/upload-artifact":
                    config = step.get("with", {})
                    if not isinstance(config, dict) or not isinstance(config.get("retention-days"), int) or not 1 <= config["retention-days"] <= 3:
                        reject(errors, manifest, workflow, job, "artifact_retention", "artifacts require integer retention-days from 1 through 3")
                    artifact_path = str(config.get("path", ""))
                    if not artifact_path or UNSAFE_ARTIFACT.search(artifact_path):
                        reject(errors, manifest, workflow, job, "artifact_path", "artifact path includes unsafe payload")
        if DISALLOWED_RUNNER.search(raw): errors.append(f"{workflow}:<workflow>: runner_terms: disallowed runner term appears")
    return errors


def self_test() -> None:
    manifest_data = json.loads((ROOT / "ci/tracksmith_compute_lanes.json").read_text())
    good = """name: safe\non: [pull_request]\npermissions:\n  contents: read\njobs:\n  check:\n    runs-on: ubuntu-24.04\n    timeout-minutes: 5\n    steps:\n      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262\n"""
    with tempfile.TemporaryDirectory() as temp:
        root = pathlib.Path(temp); workflows = root / "workflows"; workflows.mkdir(); manifest = root / "lanes.json"
        def write_manifest(data: dict[str, Any]) -> None: manifest.write_text(json.dumps(data))
        write_manifest(manifest_data); (workflows / "safe.yml").write_text(good)
        if audit(workflows, manifest): raise AssertionError("valid fixture was rejected")
        cases: list[tuple[str, str, dict[str, Any]]] = [
            ("paid-runner", good.replace("ubuntu-24.04", "ubuntu-latest"), manifest_data),
            ("missing-timeout", good.replace("    timeout-minutes: 5\n", ""), manifest_data),
            ("secret", good + "      - run: echo ${{ secrets.TOKEN }}\n", manifest_data),
            ("unpinned", good.replace("@11d5960a326750d5838078e36cf38b85af677262", "@v4"), manifest_data),
            ("target", good.replace("on: [pull_request]", "on: [pull_request_target]"), manifest_data),
            ("cloud", good + "      - run: cloud-eval\n", manifest_data),
            ("artifact", good + "      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02\n        with:\n          path: ${{ runner.temp }}/DerivedData\n          retention-days: 90\n", manifest_data),
            ("unreviewed-action", good.replace("actions/checkout@11d5960a326750d5838078e36cf38b85af677262", "actions/cache@11d5960a326750d5838078e36cf38b85af677262"), manifest_data),
        ]
        cache = good + "      - uses: actions/cache@11d5960a326750d5838078e36cf38b85af677262\n"
        malformed = json.loads(json.dumps(manifest_data)); malformed["lanes"].pop()
        expired = json.loads(json.dumps(manifest_data)); expired["audit_exceptions"] = [{"workflow":"safe.yml","job":"check","rule":"runner","reason":"fixture","owner":"owner","reviewed_on":"2026-08-01","expires_on":"2026-08-02"}]
        bad_exception = json.loads(json.dumps(manifest_data)); bad_exception["audit_exceptions"] = [{"workflow":"safe.yml","job":"check","rule":"runner","reason":"fixture","owner":"owner","reviewed_on":"2026-08-23"}]
        cases.extend([
            ("cache-disabled", cache, manifest_data),
            ("missing-lane", good, malformed),
            ("expired-exception", good, expired),
            ("malformed-exception", good, bad_exception),
            ("timeout-too-large", good.replace("timeout-minutes: 5", "timeout-minutes: 121"), manifest_data),
            ("retention-zero", good + "      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02\n        with:\n          path: ${{ runner.temp }}/safe.json\n          retention-days: 0\n", manifest_data),
            ("applications-artifact", good + "      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02\n        with:\n          path: /Applications/TrackSmith.app\n          retention-days: 3\n", manifest_data),
            ("plugin-artifact", good + "      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02\n        with:\n          path: Library/Audio/Plug-Ins/Components/TrackSmith.component\n          retention-days: 3\n", manifest_data)
        ])
        for name, text, data in cases:
            for file in workflows.glob("*.yml"): file.unlink()
            write_manifest(data); (workflows / f"{name}.yml").write_text(text)
            if not audit(workflows, manifest): raise AssertionError(f"negative fixture was accepted: {name}")
    print("audit-free-compute self-test: 16 rejection classes passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workflow-dir", type=pathlib.Path, default=ROOT / ".github/workflows")
    parser.add_argument("--manifest", type=pathlib.Path, default=ROOT / "ci/tracksmith_compute_lanes.json")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test: self_test(); return 0
    errors = audit(args.workflow_dir, args.manifest)
    if errors:
        print("free-compute audit failed:", *[f"- {error}" for error in errors], sep="\n", file=sys.stderr); return 1
    print(f"free-compute audit passed: manifest contract and {len(list(args.workflow_dir.glob('*.yml'))) + len(list(args.workflow_dir.glob('*.yaml')))} workflow(s) checked")
    return 0


if __name__ == "__main__": raise SystemExit(main())
