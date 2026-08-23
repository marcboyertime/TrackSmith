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
    "actions/checkout": "3d3c42e5aac5ba805825da76410c181273ba90b1",
    "actions/setup-python": "5fda3b95a4ea91299a34e894583c3862153e4b97",
    "actions/upload-artifact": "043fb46d1a93c77aae656e7c1c64a875d1fc6a0a",
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
SECRET_REF = re.compile(r"\bsecrets\s*(?:\.\s*[A-Za-z_][A-Za-z0-9_]*|\[\s*['\"][^'\"]+['\"]\s*\])", re.I)
FORBIDDEN_COMMAND = re.compile(r"\b(?:openai|anthropic|claude|gemini|bedrock|vertex|azure|aws|gcloud|cloud[-_ ]?(?:eval|harness|text|audio)|model[-_ ]?eval)\b", re.I)
UNSAFE_ARTIFACT = re.compile(r"(?:^|/)(?:\.build|DerivedData|Applications|Library/Audio/Plug-Ins)(?:/|$)|\.(?:app|appex|sqlite|db|wav|aiff|mp3|flac)(?:$|\s)", re.I)
ENTRYPOINT_COMMAND = re.compile(r"bash (scripts/ci/[A-Za-z0-9_.-]+\.sh)(?: <choice>)?$")
SCRIPT_RELATIVE_PATH = re.compile(r"scripts/ci/[A-Za-z0-9_.-]+\.sh$")
LITERAL_SCRIPT_TOKEN = re.compile(r"(?<![A-Za-z0-9_.\-/])(scripts/ci/[A-Za-z0-9_.-]+\.sh)(?![A-Za-z0-9_.\-/])")
SCRIPT_CI_PATH_ATTEMPT = re.compile(r"scripts/ci/[^\s'\";|&()]*\.sh\b")
SHELL_DEPENDENCY_INVOKER = re.compile(r"^(?:(?:env|command)(?:\s+[-A-Za-z0-9_=]+)*\s+)?(?:bash|sh|source)\b|^\.\s+")
STANDARD_LIB_SOURCE = re.compile(r'^source "\$\(cd -- "\$\(dirname -- "\$\{BASH_SOURCE\[0\]\}"\)" && pwd -P\)/lib\.sh"$')
MAX_SCRIPT_CLOSURE_FILES = 32
MAX_SCRIPT_CLOSURE_BYTES = 1_000_000
SCRIPT_CLOUD_MODEL = re.compile(
    r"(?:https?://[^\s'\"]*(?:openai|anthropic|claude|gemini|bedrock|vertex|azure|aws|gcloud)[^\s'\"]*|"
    r"(?<![./\w-])(?:openai|anthropic|claude|gemini|bedrock|vertex|azure|aws|gcloud|cloud[-_ ]?(?:eval|harness|text|audio)|model[-_ ]?eval)\b)",
    re.I,
)
SCRIPT_OWNER_SURFACE = re.compile(
    r"\b(?:codesign|productbuild|pkgbuild|installer|auval|pluginkit|afplay|ffmpeg|sox)\b|"
    r"\bLogic\s+Pro\b|\bCODE_SIGNING_ALLOWED\s*=\s*(?!NO\b)\S+|"
    r"(?:^|[\s'\"])(?:/Applications|Library/Audio/Plug-Ins)(?:/|\b)",
    re.I,
)
XCODEBUILD_BUILD = re.compile(r"\bxcodebuild\b.*\bbuild\b", re.I)
UNSIGNED_XCODEBUILD = re.compile(r"\bCODE_SIGNING_ALLOWED\s*=\s*NO\b", re.I)
LOGIC_LAUNCH = re.compile(r"\bopen\s+-a\s+['\"]?Logic(?:\s+Pro)?['\"]?(?=\s|$|;|&&|\|\|)", re.I)
PRIVATE_AUDIO_PATH = re.compile(r"(?:^|[\s'\"])(?:/|~/)[^\s'\"]+\.(?:wav|aiff|mp3|flac)(?=$|[\s'\";])", re.I)


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


def script_path(relative: str, repo_root: pathlib.Path) -> pathlib.Path | None:
    if not SCRIPT_RELATIVE_PATH.fullmatch(relative):
        return None
    candidate = repo_root / relative
    try:
        resolved = candidate.resolve(strict=True)
        resolved.relative_to((repo_root / "scripts/ci").resolve(strict=True))
    except (OSError, ValueError):
        return None
    if candidate.is_symlink() or not resolved.is_file() or resolved.parent != (repo_root / "scripts/ci").resolve():
        return None
    return resolved


def entrypoint_path(command: Any, repo_root: pathlib.Path) -> pathlib.Path | None:
    if not isinstance(command, str):
        return None
    match = ENTRYPOINT_COMMAND.fullmatch(command)
    return script_path(match.group(1), repo_root) if match else None


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
            if " <choice>" in lane["command"] or entrypoint_path(lane["command"], repo_root) is None:
                errors.append(f"manifest:{lane_id}: command must name an existing stable scripts/ci shell entry point")
        elif lane_id == "manual_heavy":
            if not lane["command"].endswith(" <choice>") or entrypoint_path(lane["command"], repo_root) is None:
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


def strip_shell_comment(line: str) -> str:
    quote: str | None = None
    escaped = False
    for index, character in enumerate(line):
        if escaped:
            escaped = False
        elif character == "\\" and quote != "'":
            escaped = True
        elif quote:
            if character == quote:
                quote = None
        elif character in {"'", '"'}:
            quote = character
        elif character == "#" and (index == 0 or line[index - 1].isspace()):
            return line[:index]
    return line


def executable_commands(path: pathlib.Path) -> list[tuple[int, str]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError as error:
        raise RuntimeError(f"manifest entry point is not UTF-8 shell text: {path}: {error}") from error
    commands: list[tuple[int, str]] = []
    pending = ""
    pending_line = 0
    for line_number, line in enumerate(lines, 1):
        executable = strip_shell_comment(line).strip()
        if not executable:
            continue
        if not pending:
            pending_line = line_number
        pending += executable[:-1].rstrip() + " " if executable.endswith("\\") else executable
        if not executable.endswith("\\"):
            commands.append((pending_line, pending))
            pending = ""
    if pending:
        raise RuntimeError(f"unterminated line continuation: {path}:{pending_line}")
    return commands


def shell_segments(command: str) -> list[str]:
    return [segment.strip() for segment in re.split(r"(?:&&|\|\||;|\|)", command) if segment.strip()]


def script_closure(entrypoint: pathlib.Path, repo_root: pathlib.Path) -> list[tuple[pathlib.Path, list[tuple[int, str]]]]:
    closure: list[tuple[pathlib.Path, list[tuple[int, str]]]] = []
    visited: set[pathlib.Path] = set()
    active: set[pathlib.Path] = set()
    total_bytes = 0

    def visit(path: pathlib.Path) -> None:
        nonlocal total_bytes
        if path in active:
            raise RuntimeError(f"script dependency cycle: {path.relative_to(repo_root)}")
        if path in visited:
            return
        if len(visited) >= MAX_SCRIPT_CLOSURE_FILES:
            raise RuntimeError(f"script dependency closure exceeds {MAX_SCRIPT_CLOSURE_FILES} files")
        size = path.stat().st_size
        total_bytes += size
        if total_bytes > MAX_SCRIPT_CLOSURE_BYTES:
            raise RuntimeError(f"script dependency closure exceeds {MAX_SCRIPT_CLOSURE_BYTES} bytes")
        active.add(path)
        commands = executable_commands(path)
        closure.append((path, commands))
        for line_number, command in commands:
            if STANDARD_LIB_SOURCE.fullmatch(command):
                dependency = script_path("scripts/ci/lib.sh", repo_root)
                if dependency is None:
                    raise RuntimeError(f"missing standard lib dependency: {path.relative_to(repo_root)}:{line_number}")
                visit(dependency)
                continue
            literal_paths = {match.group(1) for match in LITERAL_SCRIPT_TOKEN.finditer(command)}
            attempted_paths = {match.group(0) for match in SCRIPT_CI_PATH_ATTEMPT.finditer(command)}
            if attempted_paths != literal_paths or (literal_paths and ("$(" in command or "`" in command)):
                raise RuntimeError(f"dynamic, constructed, or traversal script dependency: {path.relative_to(repo_root)}:{line_number}")
            for segment in shell_segments(command):
                segment_paths = {match.group(1) for match in LITERAL_SCRIPT_TOKEN.finditer(segment)}
                if SHELL_DEPENDENCY_INVOKER.search(segment) and not segment_paths:
                    raise RuntimeError(f"dynamic, external, or unresolvable shell dependency: {path.relative_to(repo_root)}:{line_number}")
            for relative in literal_paths:
                dependency = script_path(relative, repo_root)
                if dependency is None:
                    raise RuntimeError(f"invalid script dependency: {path.relative_to(repo_root)}:{line_number}")
                visit(dependency)
        active.remove(path)
        visited.add(path)

    visit(entrypoint)
    return closure


def audit_manifest_entrypoints(manifest: dict[str, Any], repo_root: pathlib.Path, errors: list[str]) -> None:
    for lane in manifest["lanes"]:
        lane_id = lane["id"]
        path = entrypoint_path(lane["command"], repo_root)
        if path is None:
            # manifest_errors already reports this contract failure.
            continue
        try:
            closure = script_closure(path, repo_root)
        except (OSError, RuntimeError) as error:
            errors.append(f"manifest-entrypoint:{lane_id}: entrypoint: {error}")
            continue
        for script, commands in closure:
            relative = script.relative_to(repo_root)
            for line_number, command in commands:
                detail = f"{relative}:{line_number}"
                if SECRET_REF.search(command):
                    reject(errors, manifest, "manifest-entrypoint", lane_id, "secrets", f"secret reference in {detail}")
                if SCRIPT_CLOUD_MODEL.search(command):
                    reject(errors, manifest, "manifest-entrypoint", lane_id, "cloud_model", f"provider/cloud/model surface in {detail}")
                if SCRIPT_OWNER_SURFACE.search(command) or LOGIC_LAUNCH.search(command) or PRIVATE_AUDIO_PATH.search(command):
                    reject(errors, manifest, "manifest-entrypoint", lane_id, "owner_surface", f"sign/install/Logic/private-audio surface in {detail}")
                for segment in shell_segments(command):
                    if XCODEBUILD_BUILD.search(segment) and not UNSIGNED_XCODEBUILD.search(segment):
                        reject(errors, manifest, "manifest-entrypoint", lane_id, "xcode_signing", f"xcodebuild build lacks CODE_SIGNING_ALLOWED=NO in {detail}")


def audit(workflow_dir: pathlib.Path, manifest_path: pathlib.Path, repo_root: pathlib.Path = ROOT) -> list[str]:
    repo_root = repo_root.resolve()
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        return [f"manifest: unreadable or invalid JSON: {error}"]
    errors = manifest_errors(manifest, repo_root)
    if errors:
        return errors
    audit_manifest_entrypoints(manifest, repo_root, errors)
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
    good = """name: safe\non: [pull_request]\npermissions:\n  contents: read\njobs:\n  check:\n    runs-on: ubuntu-24.04\n    timeout-minutes: 5\n    steps:\n      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1\n"""
    with tempfile.TemporaryDirectory() as temp:
        root = pathlib.Path(temp); repo = root / "repo"; repo.mkdir(); workflows = root / "workflows"; workflows.mkdir(); manifest = root / "lanes.json"
        def write_manifest(data: dict[str, Any]) -> None: manifest.write_text(json.dumps(data))
        def write_entrypoints(data: dict[str, Any]) -> None:
            for lane in data.get("lanes", []):
                match = ENTRYPOINT_COMMAND.fullmatch(lane.get("command", "")) if isinstance(lane, dict) else None
                if match:
                    path = repo / match.group(1); path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text("#!/usr/bin/env bash\nset -euo pipefail\nprintf 'safe entrypoint\\n'\n")
        write_manifest(manifest_data); write_entrypoints(manifest_data); (workflows / "safe.yml").write_text(good)
        if audit(workflows, manifest, repo): raise AssertionError("valid fixture was rejected")
        cases: list[tuple[str, str, dict[str, Any]]] = [
            ("paid-runner", good.replace("ubuntu-24.04", "ubuntu-latest"), manifest_data),
            ("missing-timeout", good.replace("    timeout-minutes: 5\n", ""), manifest_data),
            ("secret", good + "      - run: echo ${{ secrets.TOKEN }}\n", manifest_data),
            ("unpinned", good.replace("@3d3c42e5aac5ba805825da76410c181273ba90b1", "@v7"), manifest_data),
            ("target", good.replace("on: [pull_request]", "on: [pull_request_target]"), manifest_data),
            ("cloud", good + "      - run: cloud-eval\n", manifest_data),
            ("artifact", good + "      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: ${{ runner.temp }}/DerivedData\n          retention-days: 90\n", manifest_data),
            ("unreviewed-action", good.replace("actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1", "actions/cache@3d3c42e5aac5ba805825da76410c181273ba90b1"), manifest_data),
        ]
        cache = good + "      - uses: actions/cache@3d3c42e5aac5ba805825da76410c181273ba90b1\n"
        malformed = json.loads(json.dumps(manifest_data)); malformed["lanes"].pop()
        expired = json.loads(json.dumps(manifest_data)); expired["audit_exceptions"] = [{"workflow":"safe.yml","job":"check","rule":"runner","reason":"fixture","owner":"owner","reviewed_on":"2026-08-01","expires_on":"2026-08-02"}]
        bad_exception = json.loads(json.dumps(manifest_data)); bad_exception["audit_exceptions"] = [{"workflow":"safe.yml","job":"check","rule":"runner","reason":"fixture","owner":"owner","reviewed_on":"2026-08-23"}]
        cases.extend([
            ("cache-disabled", cache, manifest_data),
            ("missing-lane", good, malformed),
            ("expired-exception", good, expired),
            ("malformed-exception", good, bad_exception),
            ("timeout-too-large", good.replace("timeout-minutes: 5", "timeout-minutes: 121"), manifest_data),
            ("retention-zero", good + "      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: ${{ runner.temp }}/safe.json\n          retention-days: 0\n", manifest_data),
            ("applications-artifact", good + "      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: /Applications/TrackSmith.app\n          retention-days: 3\n", manifest_data),
            ("plugin-artifact", good + "      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: Library/Audio/Plug-Ins/Components/TrackSmith.component\n          retention-days: 3\n", manifest_data)
        ])
        external_entrypoint = json.loads(json.dumps(manifest_data)); external_entrypoint["lanes"][0]["command"] = "bash /tmp/not-allowed.sh"
        cases.append(("external-entrypoint", good, external_entrypoint))
        for name, text, data in cases:
            for file in workflows.glob("*.yml"): file.unlink()
            write_manifest(data); write_entrypoints(data); (workflows / f"{name}.yml").write_text(text)
            if not audit(workflows, manifest, repo): raise AssertionError(f"negative fixture was accepted: {name}")
        def reset_safe_fixture() -> None:
            for file in workflows.glob("*.yml"): file.unlink()
            write_manifest(manifest_data); write_entrypoints(manifest_data)
            (workflows / "safe.yml").write_text(good)

        reset_safe_fixture()
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\nxcodebuild -project App.xcodeproj CODE_SIGNING_ALLOWED=NO build\n")
        if audit(workflows, manifest, repo): raise AssertionError("explicit unsigned xcodebuild fixture was rejected")

        def reject_entrypoint(name: str, content: str, helper: str | None = None, symlink_helper: bool = False) -> None:
            reset_safe_fixture()
            entrypoint = repo / "scripts/ci/run-linux-integrity.sh"
            entrypoint.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + content)
            helper_path = repo / "scripts/ci/opaque-check.sh"
            if helper_path.exists() or helper_path.is_symlink(): helper_path.unlink()
            if helper is not None:
                if symlink_helper:
                    target = repo / "scripts/ci/safe-helper.sh"; target.write_text("#!/usr/bin/env bash\nprintf safe\\n")
                    helper_path.symlink_to(target.name)
                else:
                    helper_path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + helper)
            if not audit(workflows, manifest, repo): raise AssertionError(f"negative fixture was accepted: {name}")

        for name, content, helper, symlink_helper in (
            ("hidden-script-secret", "printf '${{ secrets.TOKEN }}'\n", None, False),
            ("hidden-script-bracket-secret", "printf \"${{ secrets['TOKEN'] }}\"\n", None, False),
            ("hidden-script-cloud", "curl https://api.openai.com/v1/responses\n", None, False),
            ("hidden-script-owner-surface", "codesign --force unsafe.app\n", None, False),
            ("hidden-script-unsigned-xcodebuild", "xcodebuild -project App.xcodeproj build\n", None, False),
            ("hidden-script-xcodebuild-late-disable", "xcodebuild -project App.xcodeproj build && CODE_SIGNING_ALLOWED=NO true\n", None, False),
            ("hidden-script-logic-launch", "open -a Logic\n", None, False),
            ("hidden-script-private-wav", "printf safe /tmp/owner-take.wav\n", None, False),
            ("hidden-script-helper-direct", "bash scripts/ci/opaque-check.sh\n", "curl https://api.openai.com/v1/responses\n", False),
            ("hidden-script-helper-env", "env bash scripts/ci/opaque-check.sh\n", "curl https://api.openai.com/v1/responses\n", False),
            ("hidden-script-helper-command", "command bash scripts/ci/opaque-check.sh\n", "curl https://api.openai.com/v1/responses\n", False),
            ("hidden-script-helper-source", "source scripts/ci/opaque-check.sh\n", "curl https://api.openai.com/v1/responses\n", False),
            ("hidden-script-helper-dot", ". scripts/ci/opaque-check.sh\n", "curl https://api.openai.com/v1/responses\n", False),
            ("hidden-script-command-substitution", "bash \"$(printf scripts/ci/opaque-check.sh)\"\n", "printf safe\n", False),
            ("hidden-script-dynamic-construction", "helper=\"scripts/ci/opaque-check.sh\"\nbash \"$helper\"\n", "printf safe\n", False),
            ("hidden-script-external", "bash /tmp/opaque-check.sh\n", None, False),
            ("hidden-script-traversal", "bash scripts/ci/../outside.sh\n", None, False),
            ("hidden-script-symlink", "bash scripts/ci/opaque-check.sh\n", "unused\n", True),
            ("hidden-script-dynamic", "bash \"scripts/ci/$CHECK.sh\"\n", None, False),
            ("hidden-script-cycle", "bash scripts/ci/opaque-check.sh\n", "bash scripts/ci/run-linux-integrity.sh\n", False),
        ):
            reject_entrypoint(name, content, helper, symlink_helper)
    print("audit-free-compute self-test: 37 rejection classes passed")


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
