#!/usr/bin/env python3
"""Fail closed on paid, secret, unbounded, or unreviewed Actions changes."""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import pathlib
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
import zipfile
import stat
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
WORKFLOW_JOB_BINDINGS = {
    ("tutor-integrity.yml", "linux_integrity"): ("linux_integrity",),
    ("tutor-integrity.yml", "linux_retrieval"): ("linux_retrieval",),
    ("tutor-integrity.yml", "linux_evaluation"): ("linux_evaluation",),
    ("tutor-integrity.yml", "linux_docs_policy_security"): ("linux_docs_policy_security",),
    ("tutor-macos-swift.yml", "macos_swift_core"): ("macos_swift_core",),
    ("tutor-macos-swift.yml", "macos_tutor"): ("macos_tutor",),
    ("tutor-macos-swift.yml", "macos_xcode_products"): ("macos_xcode_companion", "macos_xcode_au"),
}
LANE_FIELDS = {
    "id", "purpose", "operating_system", "architecture", "runner_label", "command",
    "timeout_minutes", "deterministic", "required", "requires_secrets", "requires_logic",
    "requires_signing_or_install", "artifact_outputs", "expected_maximum_artifact_bytes",
    "change_paths", "safe_for_fork_pull_requests",
}
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
DISALLOWED_RUNNER = re.compile(r"self-hosted|larger|gpu|large|xlarge|windows|ubuntu-latest|macos-latest", re.I)
SECRET_REF = re.compile(r"\bsecrets\s*(?:\.\s*[A-Za-z_][A-Za-z0-9_]*|\[\s*[^\]\r\n]+\s*\])", re.I)
FORBIDDEN_COMMAND = re.compile(r"\b(?:openai|anthropic|claude|gemini|bedrock|vertex|azure|aws|gcloud|cloud[-_ ]?(?:eval|harness|text|audio)|model[-_ ]?eval)\b", re.I)
UNSAFE_ARTIFACT = re.compile(r"(?:^|/)(?:\.build|DerivedData|Applications|Library/Audio/Plug-Ins)(?:/|$)|\.(?:app|appex|sqlite|db|wav|aiff|mp3|flac)(?:$|\s)|(?:^|[\s/])(?:credential(?:s)?|secret(?:s)?|token(?:s)?|api[-_]?key(?:s)?|provider[-_]?response(?:s)?)(?:[._/-]|$)", re.I)
ENTRYPOINT_COMMAND = re.compile(r"bash (scripts/ci/[A-Za-z0-9_.-]+\.sh)(?: <choice>)?$")
SCRIPT_RELATIVE_PATH = re.compile(r"scripts/ci/[A-Za-z0-9_.-]+\.sh$")
LITERAL_SCRIPT_TOKEN = re.compile(r"(?<![A-Za-z0-9_.\-/])(scripts/ci/[A-Za-z0-9_.-]+\.sh)(?![A-Za-z0-9_.\-/])")
SCRIPT_CI_PATH_ATTEMPT = re.compile(r"scripts/ci/[^\s'\";|&()]*\.sh\b")
LOCAL_PYTHON_HELPER = re.compile(r"\b(?:python3?|python)\s+(?:-[A-Za-z0-9_=-]+\s+)*['\"]?((?:scripts|research)/[A-Za-z0-9_.\-/]+\.py)['\"]?")
LOCAL_PYTHON_ATTEMPT = re.compile(r"(?:scripts|research)/[^\s'\";|&()]*\.py\b")
DIRECT_LOCAL_HELPER = re.compile(r"(?:^|[;&|]\s*)['\"]?(\./[A-Za-z0-9_.\-/]+)['\"]?")
SHELL_DEPENDENCY_INVOKER = re.compile(r"^(?:(?:env|command)(?:\s+[-A-Za-z0-9_=]+)*\s+)?(?:bash|sh|source)\b|^\.\s+")
SHELL_CONTROL_PREFIX = re.compile(r"^(?:(?:if|then|do|while|until)\s+|!\s*|\(\s*)")
SHELL_ASSIGNMENT_PREFIX = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*=(?:[^\s]+|\"[^\"]*\"|'[^']*')\s+)+")
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
XCODEBUILD_REFERENCE = re.compile(r"\b(?:xcodebuild|xcrun\b[^;|&]*\bxcodebuild)\b", re.I)
XCODEBUILD_SAFE_QUERY = re.compile(r"\bxcodebuild\s+-(?:version|help|list|showsdks|showBuildSettings)\b|\b(?:command\s+-v|require_command)\s+xcodebuild\b", re.I)
XCODEBUILD_DYNAMIC = re.compile(r"\bxcode(?:build)?(?:\$\{|\$\(|`)|\b[A-Za-z_][A-Za-z0-9_]*\s*=\s*['\"]?xcode(?:build)?\b", re.I)
UNSIGNED_XCODEBUILD = re.compile(r"\bCODE_SIGNING_ALLOWED\s*=\s*NO\b", re.I)
LOGIC_LAUNCH = re.compile(r"\bopen\s+-a\s+['\"]?Logic(?:\s+Pro)?['\"]?(?=\s|$|;|&&|\|\|)", re.I)
PRIVATE_AUDIO_PATH = re.compile(r"(?:^|[\s'\"])(?:/|~/)[^\s'\"]+\.(?:wav|aiff|mp3|flac)(?=$|[\s'\";])", re.I)
SOFT_FAILURE = re.compile(r"\|\||\bset\s+\+e\b|\bexit\s+0\b|\btrap\s+.*\bEXIT\b", re.I)
BACKGROUND_PROCESS = re.compile(r"(?<![>&])&(?![&>])|\b(?:disown|nohup)\b", re.I)
# Every checked-in lane starts with the runner-provided command search path.  A
# pull request must not be able to prepend the checkout (or another arbitrary
# location) and turn a lexically-bound `bash scripts/ci/...` into a repository
# executable.  Keep this deliberately small and fail closed on the shell
# mechanisms that can alter lookup for a later command in the same run.
COMMAND_RESOLUTION_ENV = {"PATH", "BASH_ENV", "ENV", "GITHUB_PATH", "GITHUB_ENV"}
COMMAND_RESOLUTION_MUTATION = re.compile(
    r"(?:^|[;&|\s])(?:export\s+|readonly\s+|declare\s+|typeset\s+)?(?:PATH|BASH_ENV|ENV)\s*\+?="
    r"|\b(?:hash\s+-p|enable\s+-f)\b"
    r"|\b(?:alias|function)\s+(?:bash|sh|python3?|swift|xcodebuild)\b"
    r"|\b(?:bash|sh|python3?|swift|xcodebuild)\s*\(\s*\)",
    re.I,
)
GITHUB_PATH_MUTATION = re.compile(r"\$(?:\{GITHUB_PATH\}|GITHUB_PATH)\b|\b(?:PATH|BASH_ENV|ENV|GITHUB_PATH)\s*\+?=.*\$(?:\{GITHUB_ENV\}|GITHUB_ENV)\b|\$(?:\{GITHUB_ENV\}|GITHUB_ENV)\b.*\b(?:PATH|BASH_ENV|ENV|GITHUB_PATH)\s*\+?=", re.I)
COMMAND_RESOLUTION_INDIRECTION = re.compile(r"\$\{![^}]+\}|\b[A-Za-z_][A-Za-z0-9_]*\s*=\s*['\"]?(?:\$?\{?GITHUB_(?:ENV|PATH)\}?|GITHUB_(?:ENV|PATH))\b", re.I)
# Command substitution embedded in an unquoted shell word can synthesize an
# executable, an environment-control name, or a signing assignment. The lane
# permits command substitution only as a complete quoted/assignment value; it
# never needs a dynamically constructed command token.
WORD_EMBEDDED_COMMAND_SUBSTITUTION = re.compile(r"(?<![\s=:{\"'-])\$\(")


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


def local_helper_path(relative: str, repo_root: pathlib.Path) -> pathlib.Path | None:
    if not isinstance(relative, str) or relative.startswith("/") or ".." in pathlib.PurePosixPath(relative).parts:
        return None
    candidate = repo_root / relative.removeprefix("./")
    try:
        resolved = candidate.resolve(strict=True)
        resolved.relative_to(repo_root.resolve(strict=True))
    except (OSError, ValueError):
        return None
    if candidate.is_symlink() or not resolved.is_file(): return None
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
    elif type(cache_policy.get("soft_budget_bytes")) is not int or not 0 <= cache_policy["soft_budget_bytes"] <= 2 * 1024 * 1024 * 1024:
        errors.append("manifest: cache_policy soft budget must be an integer no larger than 2 GiB")
    artifact_policy = manifest.get("artifact_policy")
    if not isinstance(artifact_policy, dict) or type(artifact_policy.get("maximum_bytes_per_run")) is not int or not 0 <= artifact_policy["maximum_bytes_per_run"] <= 25 * 1024 * 1024 or type(artifact_policy.get("retention_days")) is not int or not 1 <= artifact_policy["retention_days"] <= 3:
        errors.append("manifest: artifact budget and retention must be exact bounded integers")
        artifact_limit = 0
    else:
        artifact_limit = artifact_policy["maximum_bytes_per_run"]
    lanes = manifest.get("lanes")
    if not isinstance(lanes, list) or {lane.get("id") for lane in lanes if isinstance(lane, dict)} != set(LANE_IDS) or len(lanes) != len(LANE_IDS):
        errors.append("manifest: lanes must contain exactly the 10 required lane IDs")
        lanes = []
    for lane in lanes:
        lane_id = lane.get("id", "<unknown>")
        if set(lane) != LANE_FIELDS:
            errors.append(f"manifest:{lane_id}: lane fields must exactly match the contract")
            continue
        if type(lane["expected_maximum_artifact_bytes"]) is not int or not 0 <= lane["expected_maximum_artifact_bytes"] <= artifact_limit or not isinstance(lane["artifact_outputs"], list) or len(lane["artifact_outputs"]) != len(set(lane["artifact_outputs"])) or any(not isinstance(item, str) or not item for item in lane["artifact_outputs"]):
            errors.append(f"manifest:{lane_id}: artifact outputs and budget must be bounded exact schema values")
        if lane_id in ACTION_LANES:
            if lane["runner_label"] not in ALLOWED_RUNNERS:
                errors.append(f"manifest:{lane_id}: required Actions lane uses a nonstandard runner")
            if not lane["required"] or type(lane["timeout_minutes"]) is not int or lane["timeout_minutes"] <= 0:
                errors.append(f"manifest:{lane_id}: required Actions lane needs required=true and positive timeout")
            if any(lane[key] for key in ("requires_secrets", "requires_logic", "requires_signing_or_install")):
                errors.append(f"manifest:{lane_id}: required Actions lane must be no-secret, no-Logic, no-sign/install")
            if " <choice>" in lane["command"] or entrypoint_path(lane["command"], repo_root) is None:
                errors.append(f"manifest:{lane_id}: command must name an existing stable scripts/ci shell entry point")
        elif lane_id == "manual_heavy":
            if type(lane["timeout_minutes"]) is not int or lane["timeout_minutes"] <= 0 or not lane["command"].endswith(" <choice>") or entrypoint_path(lane["command"], repo_root) is None:
                errors.append("manifest:manual_heavy: local command must name an existing choice entry point")
        elif lane_id == "local_apple_logic_owner":
            if lane["runner_label"] != "not an Actions lane" or type(lane["timeout_minutes"]) is not int or lane["timeout_minutes"] != 0:
                errors.append("manifest:local_apple_logic_owner: must remain an owner-only non-Actions lane with timeout 0")
    # A checked-in exception is self-authorizable by the same pull request it
    # would excuse. Keep the contract deliberately exception-free; an external
    # governance process must resolve any legitimate policy change first.
    if manifest.get("audit_exceptions") != []:
        errors.append("manifest: audit_exceptions must be an empty list")
    # The local semantic planner and the remote lane manifest must agree on
    # every routed prefix. Otherwise a path rename can silently omit the
    # required remote job even while each JSON file remains individually valid.
    try:
        dependencies = json.loads((repo_root / "ci/semantic_dependencies.json").read_text())
        semantic_lanes = dependencies.get("lanes") if isinstance(dependencies, dict) else None
        lane_map = {lane["id"]: lane for lane in lanes if isinstance(lane, dict) and isinstance(lane.get("id"), str)}
        if not isinstance(semantic_lanes, dict):
            errors.append("semantic-dependencies: lanes must be an object")
        elif set(semantic_lanes) != set(LANE_IDS[:8]):
            errors.append("semantic-dependencies: lane IDs must match Actions lanes")
        else:
            for lane_id, prefixes in semantic_lanes.items():
                if not isinstance(prefixes, list) or not all(isinstance(prefix, str) and prefix for prefix in prefixes):
                    errors.append(f"semantic-dependencies:{lane_id}: prefixes must be nonempty strings"); continue
                declared = set(lane_map[lane_id]["change_paths"])
                shared = {prefix for prefix in dependencies.get("shared_prefixes", []) if prefix in declared}
                semantic = set(prefixes)
                if semantic | shared != declared:
                    missing = sorted(declared - semantic - shared)
                    unexpected = sorted(semantic - declared)
                    errors.append(f"semantic-dependencies:{lane_id}: exact lane paths disagree with compute manifest (missing={missing}, unexpected={unexpected})")
    except (OSError, json.JSONDecodeError, KeyError, TypeError):
        errors.append("semantic-dependencies: unreadable or incompatible with compute manifest")
    return errors


def reject(errors: list[str], manifest: dict[str, Any], workflow: str, job: str, rule: str, detail: str) -> None:
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


def has_shell_dependency_invoker(segment: str) -> bool:
    remaining = segment.strip()
    for _ in range(8):
        stripped = SHELL_CONTROL_PREFIX.sub("", remaining, count=1)
        stripped = SHELL_ASSIGNMENT_PREFIX.sub("", stripped, count=1)
        if stripped == remaining:
            break
        remaining = stripped.strip()
    return bool(SHELL_DEPENDENCY_INVOKER.search(remaining))


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
        if len(visited | active) >= MAX_SCRIPT_CLOSURE_FILES:
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
                if has_shell_dependency_invoker(segment) and not segment_paths:
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


def inline_commands(value: str) -> list[str]:
    commands: list[str] = []
    pending = ""
    for line in value.splitlines():
        command = strip_shell_comment(line).strip()
        if not command: continue
        pending += command[:-1].rstrip() + " " if command.endswith("\\") else command
        if not command.endswith("\\"):
            commands.append(pending)
            pending = ""
    if pending: raise RuntimeError("unterminated inline shell continuation")
    return commands


def local_python_paths(command: str, repo_root: pathlib.Path) -> set[pathlib.Path]:
    attempts = {match.group(0) for match in LOCAL_PYTHON_ATTEMPT.finditer(command)}
    if any("$" in value or "`" in value for value in attempts):
        raise RuntimeError("dynamic or constructed local Python helper path")
    literals = attempts
    paths: set[pathlib.Path] = set()
    for relative in literals:
        path = local_helper_path(relative, repo_root)
        if path is None: raise RuntimeError(f"invalid local Python helper: {relative}")
        paths.add(path)
    for match in DIRECT_LOCAL_HELPER.finditer(command):
        relative = match.group(1)
        if "$" in relative or "`" in relative: raise RuntimeError("dynamic direct local helper path")
        path = local_helper_path(relative, repo_root)
        if path is None: raise RuntimeError(f"invalid direct local helper: {match.group(1)}")
        if path.suffix == ".py": paths.add(path)
        elif path.suffix != ".sh" or script_path(relative.removeprefix("./"), repo_root) is None:
            raise RuntimeError(f"invalid direct local shell helper: {match.group(1)}")
    return paths


def local_shell_paths(command: str, repo_root: pathlib.Path) -> set[pathlib.Path]:
    literals = {match.group(1) for match in LITERAL_SCRIPT_TOKEN.finditer(command)}
    attempts = {match.group(0) for match in SCRIPT_CI_PATH_ATTEMPT.finditer(command)}
    if literals != attempts or (literals and ("$(" in command or "`" in command)):
        raise RuntimeError("dynamic or constructed local shell helper path")
    paths: set[pathlib.Path] = set()
    for relative in literals:
        path = script_path(relative, repo_root)
        if path is None: raise RuntimeError(f"invalid local shell helper: {relative}")
        paths.add(path)
    return paths


def audit_shell_helper(path: pathlib.Path, manifest: dict[str, Any], repo_root: pathlib.Path, workflow: str, job: str, errors: list[str], seen_python: set[pathlib.Path], seen_shell: set[pathlib.Path]) -> None:
    if path in seen_shell: return
    seen_shell.add(path)
    try: closure = script_closure(path, repo_root)
    except (OSError, RuntimeError) as error:
        raise RuntimeError(f"unresolvable local shell helper {path.relative_to(repo_root)}: {error}") from error
    audit_script_commands(closure, manifest, repo_root, workflow, job, errors, seen_python, seen_shell)


def audit_python_helper(path: pathlib.Path, manifest: dict[str, Any], repo_root: pathlib.Path, workflow: str, job: str, errors: list[str], seen_python: set[pathlib.Path], seen_shell: set[pathlib.Path]) -> None:
    if path in seen_python: return
    seen_python.add(path)
    try: tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (OSError, SyntaxError, UnicodeDecodeError) as error:
        raise RuntimeError(f"unreadable local Python helper {path.relative_to(repo_root)}: {error}") from error
    for node in ast.walk(tree):
        if isinstance(node, ast.Import) and any(alias.name in {"subprocess", "os"} and alias.asname for alias in node.names):
            raise RuntimeError(f"aliased process-spawn module import is forbidden in {path.relative_to(repo_root)}:{node.lineno}")
        if isinstance(node, ast.ImportFrom) and node.module in {"subprocess", "os"} and any(alias.name in ({"run", "call", "check_call", "check_output", "Popen"} if node.module == "subprocess" else {"system"}) for alias in node.names):
            raise RuntimeError(f"aliased process-spawn import is forbidden in {path.relative_to(repo_root)}:{node.lineno}")
        if isinstance(node, (ast.Assign, ast.AnnAssign)):
            value = node.value
            if ((isinstance(value, ast.Name) and value.id in {"subprocess", "os"}) or (isinstance(value, ast.Attribute) and isinstance(value.value, ast.Name) and value.value.id in {"subprocess", "os"})):
                raise RuntimeError(f"aliased process-spawn assignment is forbidden in {path.relative_to(repo_root)}:{node.lineno}")
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "getattr" and node.args and isinstance(node.args[0], ast.Name) and node.args[0].id in {"subprocess", "os"}:
            raise RuntimeError(f"dynamic process-spawn lookup is forbidden in {path.relative_to(repo_root)}:{node.lineno}")
        if isinstance(node, ast.Call) and ((isinstance(node.func, ast.Name) and node.func.id in {"__import__", "exec", "eval", "compile"}) or (isinstance(node.func, ast.Attribute) and node.func.attr in {"__import__", "import_module"})):
            raise RuntimeError(f"dynamic Python import/evaluation is forbidden in {path.relative_to(repo_root)}:{node.lineno}")
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call): continue
        function = node.func.attr if isinstance(node.func, ast.Attribute) else node.func.id if isinstance(node.func, ast.Name) else ""
        if function not in {"run", "call", "check_call", "check_output", "Popen", "system"}: continue
        if function == "Popen" and job == "macos_xcode_products":
            reject(errors, manifest, workflow, job, "background_process", f"artifact-producing Python helper cannot use subprocess.Popen: {path.relative_to(repo_root)}:{node.lineno}")
            continue
        argument = node.args[0] if node.args else next((item.value for item in node.keywords if item.arg in {"args", "command"}), None)
        if argument is None: continue
        local_children: set[pathlib.Path] = set()
        if isinstance(argument, ast.Constant) and isinstance(argument.value, str):
            command = argument.value
        elif isinstance(argument, (ast.List, ast.Tuple)):
            rendered_items: list[str] = []
            for item in argument.elts:
                if isinstance(item, ast.Constant) and isinstance(item.value, str): rendered_items.append(item.value); continue
                # A literal path rooted at this repository remains resolvable;
                # every other computed repo-local helper path fails closed.
                if isinstance(item, ast.Call) and isinstance(item.func, ast.Name) and item.func.id == "str" and len(item.args) == 1:
                    parts: list[str] = []
                    cursor = item.args[0]
                    while isinstance(cursor, ast.BinOp) and isinstance(cursor.op, ast.Div) and isinstance(cursor.right, ast.Constant) and isinstance(cursor.right.value, str):
                        parts.append(cursor.right.value); cursor = cursor.left
                    if isinstance(cursor, ast.Name) and cursor.id == "ROOT":
                        relative = "/".join(reversed(parts)); child = local_helper_path(relative, repo_root)
                        if child is not None and child.suffix == ".py": local_children.add(child); rendered_items.append(relative); continue
                rendered = ast.unparse(item)
                if "scripts/" in rendered or "research/" in rendered or "./" in rendered:
                    rendered_items = []
                    break
                rendered_items.append(rendered)
            if not rendered_items:
                rendered = ast.unparse(argument)
                if "scripts/" in rendered or "research/" in rendered or "./" in rendered:
                    raise RuntimeError(f"dynamic local helper execution in {path.relative_to(repo_root)}:{node.lineno}")
                continue
            command = " ".join(rendered_items)
        else:
            rendered = ast.unparse(argument)
            if "scripts/" in rendered or "research/" in rendered or "./" in rendered:
                raise RuntimeError(f"dynamic local helper execution in {path.relative_to(repo_root)}:{node.lineno}")
            continue
        # A statically rendered Python subprocess is an execution surface, not
        # merely a route to another local helper.  Apply the same no-secret,
        # unsigned-Xcode, and no-background policy before recursing.
        detail = f"{path.relative_to(repo_root)}:{node.lineno}"
        audit_command_surface(command, manifest, workflow, job, errors, detail, include_nonexecution_surfaces=False)
        if BACKGROUND_PROCESS.search(command):
            reject(errors, manifest, workflow, job, "background_process", f"Python helper cannot launch a background process: {detail}")
        for child in local_python_paths(command, repo_root):
            audit_python_helper(child, manifest, repo_root, workflow, job, errors, seen_python, seen_shell)
        for child in local_children:
            audit_python_helper(child, manifest, repo_root, workflow, job, errors, seen_python, seen_shell)
        for child in local_shell_paths(command, repo_root):
            audit_shell_helper(child, manifest, repo_root, workflow, job, errors, seen_python, seen_shell)


def audit_command_surface(command: str, manifest: dict[str, Any], workflow: str, job: str, errors: list[str], detail: str, include_nonexecution_surfaces: bool = True) -> None:
    # Python helper AST coverage is intentionally execution-oriented: a static
    # source listing can contain consent-gated/audio-only branches that are not
    # reached by the CI invocation.  Its rendered subprocess command still
    # receives the signing, resolution, and process-lifecycle checks below.
    if include_nonexecution_surfaces:
        if SECRET_REF.search(command): reject(errors, manifest, workflow, job, "secrets", f"secret reference in {detail}")
        if SCRIPT_CLOUD_MODEL.search(command): reject(errors, manifest, workflow, job, "cloud_model", f"provider/cloud/model surface in {detail}")
        if SCRIPT_OWNER_SURFACE.search(command) or LOGIC_LAUNCH.search(command) or PRIVATE_AUDIO_PATH.search(command):
            reject(errors, manifest, workflow, job, "owner_surface", f"sign/install/Logic/private-audio surface in {detail}")
    # Shell quoting and backslashes concatenate tokens.  Inspect the compact
    # spelling too, so `target=GITHUB_'ENV'` cannot hide a later redirect to a
    # command-resolution control file.  We do not try to evaluate shell: any
    # dynamic execution mechanism is rejected below.
    shell_compact = re.sub(r"[\\'\"]", "", command)
    if COMMAND_RESOLUTION_MUTATION.search(command) or GITHUB_PATH_MUTATION.search(command) or COMMAND_RESOLUTION_INDIRECTION.search(command) or COMMAND_RESOLUTION_INDIRECTION.search(shell_compact):
        reject(errors, manifest, workflow, job, "command_resolution", f"PATH or shell command-resolution mutation is forbidden in {detail}")
    if "`" in command or re.search(r"\beval\b", command):
        reject(errors, manifest, workflow, job, "inline_shell", f"dynamic shell evaluation or backtick substitution is forbidden in {detail}")
    if WORD_EMBEDDED_COMMAND_SUBSTITUTION.search(command):
        reject(errors, manifest, workflow, job, "inline_shell", f"command substitution cannot construct an audited shell token in {detail}")
    if re.search(r"\bpython(?:3)?\s+-c\b", command):
        reject(errors, manifest, workflow, job, "background_process", f"opaque inline process launch is forbidden in {detail}")
    for segment in shell_segments(command):
        # Every non-query xcodebuild path is a build-like owner surface: the
        # default action, build, archive, and test all must be unsigned. This
        # is deliberately lexical so shell variables and command/xcrun wrappers
        # cannot conceal the executable from the static closure audit.
        # Shell quotes concatenate words.  Treat `xcode"build"` exactly like
        # xcodebuild, but reject the obfuscated spelling outright: it defeats
        # simple token parsers and offers no approved CI value.
        # Quotes and backslashes can concatenate shell words; parameter
        # expansion can do the same dynamically.  Normalize only enough to
        # identify that construction, then reject it unless the original text
        # contained the literal approved executable/assignment token.
        shell_resolved = re.sub(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*", "", segment)
        shell_resolved = re.sub(r"\\(.)", r"\1", shell_resolved)
        shell_resolved = re.sub(r"['\"]", "", shell_resolved)
        references = len(re.findall(r"\bxcodebuild\b", shell_resolved, re.I))
        queries = len(XCODEBUILD_SAFE_QUERY.findall(shell_resolved))
        assignment_values = re.findall(r"\bCODE_SIGNING_ALLOWED\s*=\s*([^\s;|&]+)", shell_resolved, re.I)
        literal_safe_assignments = re.findall(r"(?<!\S)CODE_SIGNING_ALLOWED=NO(?!\S)", segment, re.I)
        if assignment_values and (any(value != "NO" for value in assignment_values) or len(assignment_values) != len(literal_safe_assignments)):
            reject(errors, manifest, workflow, job, "xcode_signing", f"CODE_SIGNING_ALLOWED must be a literal standalone NO assignment in {detail}")
        if (references and not XCODEBUILD_REFERENCE.search(segment)) or XCODEBUILD_DYNAMIC.search(segment):
            reject(errors, manifest, workflow, job, "xcode_signing", f"dynamic xcodebuild/xcrun construction is forbidden in {detail}")
        if references > queries and (len(assignment_values) != 1 or len(literal_safe_assignments) != 1 or re.search(r"CODE_SIGNING_ALLOWED=NO\b.*\$", segment, re.I)):
            reject(errors, manifest, workflow, job, "xcode_signing", f"xcodebuild/xcrun build-like invocation lacks CODE_SIGNING_ALLOWED=NO in {detail}")


def audit_script_commands(closure: list[tuple[pathlib.Path, list[tuple[int, str]]]], manifest: dict[str, Any], repo_root: pathlib.Path, workflow: str, job: str, errors: list[str], seen_python: set[pathlib.Path] | None = None, seen_shell: set[pathlib.Path] | None = None) -> None:
    seen_python = set() if seen_python is None else seen_python
    seen_shell = set() if seen_shell is None else seen_shell
    for script, commands in closure:
        seen_shell.add(script)
        relative = script.relative_to(repo_root)
        for line_number, command in commands:
            audit_command_surface(command, manifest, workflow, job, errors, f"{relative}:{line_number}")
            if job == "macos_xcode_products" and BACKGROUND_PROCESS.search(command):
                reject(errors, manifest, workflow, job, "background_process", f"artifact-producing shell closure cannot launch a background process: {relative}:{line_number}")
            for helper in local_python_paths(command, repo_root):
                audit_python_helper(helper, manifest, repo_root, workflow, job, errors, seen_python, seen_shell)


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
        try:
            audit_script_commands(closure, manifest, repo_root, "manifest-entrypoint", lane_id, errors)
        except RuntimeError as error:
            errors.append(f"manifest-entrypoint:{lane_id}: helper: {error}")


def audit_inline_run(command: str, manifest: dict[str, Any], repo_root: pathlib.Path, workflow: str, job: str, errors: list[str]) -> None:
    seen_python: set[pathlib.Path] = set()
    seen_shell: set[pathlib.Path] = set()
    for line_number, inline in enumerate(inline_commands(command), 1):
        detail = f"inline:{line_number}"
        audit_command_surface(inline, manifest, workflow, job, errors, detail)
        if BACKGROUND_PROCESS.search(inline):
            reject(errors, manifest, workflow, job, "background_process", f"workflow inline run cannot launch a background process in {detail}")
        for helper in local_python_paths(inline, repo_root):
            audit_python_helper(helper, manifest, repo_root, workflow, job, errors, seen_python, seen_shell)
        literal_paths = {match.group(1) for match in LITERAL_SCRIPT_TOKEN.finditer(inline)}
        attempted_paths = {match.group(0) for match in SCRIPT_CI_PATH_ATTEMPT.finditer(inline)}
        if attempted_paths != literal_paths or (literal_paths and ("$(" in inline or "`" in inline)):
            reject(errors, manifest, workflow, job, "inline_shell", f"dynamic, constructed, or traversal script dependency in {detail}")
            continue
        for segment in shell_segments(inline):
            segment_paths = {match.group(1) for match in LITERAL_SCRIPT_TOKEN.finditer(segment)}
            if has_shell_dependency_invoker(segment) and not segment_paths:
                reject(errors, manifest, workflow, job, "inline_shell", f"dynamic or external shell dependency in {detail}")
        for relative in literal_paths:
            dependency = script_path(relative, repo_root)
            if dependency is None:
                reject(errors, manifest, workflow, job, "inline_shell", f"invalid inline script dependency in {detail}")
                continue
            try: closure = script_closure(dependency, repo_root)
            except (OSError, RuntimeError) as error:
                reject(errors, manifest, workflow, job, "inline_shell", f"unresolvable inline script dependency in {detail}: {error}")
                continue
            audit_script_commands(closure, manifest, repo_root, workflow, job, errors)


def audit_execution_environment(value: Any, manifest: dict[str, Any], workflow: str, job: str, errors: list[str], detail: str) -> None:
    if value is None: return
    if not isinstance(value, dict):
        reject(errors, manifest, workflow, job, "inline_shell", f"{detail} must be a mapping")
        return
    for key, item in value.items():
        if not isinstance(key, str) or not isinstance(item, (str, int, float, bool)):
            reject(errors, manifest, workflow, job, "inline_shell", f"{detail} contains a non-scalar environment value")
            continue
        if key.upper() in COMMAND_RESOLUTION_ENV:
            reject(errors, manifest, workflow, job, "command_resolution", f"{detail} cannot set {key}")
        if isinstance(item, str): audit_command_surface(item, manifest, workflow, job, errors, f"{detail}.{key}")


def audit_shell(value: Any, manifest: dict[str, Any], workflow: str, job: str, errors: list[str], detail: str) -> None:
    if value is not None and (not isinstance(value, str) or value not in {"bash", "sh"}):
        reject(errors, manifest, workflow, job, "inline_shell", f"{detail} must use the default bash/sh shell")


def audit_workflow_job_binding(workflow: str, job: str, body: dict[str, Any], manifest: dict[str, Any], errors: list[str]) -> None:
    lane_ids = WORKFLOW_JOB_BINDINGS.get((workflow, job))
    if lane_ids is None: return
    commands = {lane["id"]: lane["command"] for lane in manifest["lanes"]}
    allowed = {commands[lane] for lane in lane_ids}
    if "if" in body or "continue-on-error" in body:
        errors.append(f"{workflow}:{job}: manifest_entrypoint: required manifest-bound job cannot be conditional or continue-on-error")
    runs = [step["run"] for step in body.get("steps", []) if isinstance(step, dict) and isinstance(step.get("run"), str)]
    for step in body.get("steps", []):
        if not isinstance(step, dict):
            errors.append(f"{workflow}:{job}: manifest_entrypoint: required manifest-bound job has a non-mapping step")
            continue
        if "if" in step or "continue-on-error" in step:
            errors.append(f"{workflow}:{job}: manifest_entrypoint: required manifest-bound step cannot be conditional or continue-on-error")
        if isinstance(step.get("run"), str) and SOFT_FAILURE.search(step["run"]):
            errors.append(f"{workflow}:{job}: manifest_entrypoint: required manifest-bound step masks a failure")
    executable = {line for run in runs for line in inline_commands(run)}
    if not allowed.issubset(executable):
        errors.append(f"{workflow}:{job}: manifest_entrypoint: job must execute its exact stable manifest command(s), not a no-op or substituted lane")
    invoked = {line for line in executable if ENTRYPOINT_COMMAND.fullmatch(line)}
    if not invoked.issubset(allowed):
        errors.append(f"{workflow}:{job}: manifest_entrypoint: job invokes an entrypoint outside its bound manifest lane")


def manifest_artifact_paths(workflow: str, job: str, manifest: dict[str, Any]) -> set[str] | None:
    lane_ids = WORKFLOW_JOB_BINDINGS.get((workflow, job))
    if lane_ids is None: return None
    lanes = {lane["id"]: lane for lane in manifest["lanes"]}
    return {path for lane_id in lane_ids for path in lanes[lane_id]["artifact_outputs"]}


def audit_artifact_upload(workflow: str, job: str, steps: list[Any], index: int, config: Any, manifest: dict[str, Any], errors: list[str]) -> None:
    expected = manifest_artifact_paths(workflow, job, manifest)
    if expected is None:
        reject(errors, manifest, workflow, job, "artifact_path", "artifact upload is not bound to a manifest lane")
        return
    raw_paths = config.get("path") if isinstance(config, dict) else None
    if not isinstance(raw_paths, str):
        reject(errors, manifest, workflow, job, "artifact_path", "artifact path must be an exact multiline string")
        return
    paths = [line.strip() for line in raw_paths.splitlines() if line.strip()]
    if len(paths) != len(set(paths)) or set(paths) != expected or any(any(token in path for token in ("*", "?", "[", "]", "..")) for path in paths):
        reject(errors, manifest, workflow, job, "artifact_path", "artifact paths must exactly equal the manifest-declared compact files")
    guard = f"python3 scripts/ci/check-artifact-budget.py"
    preceding = [step.get("run") for step in steps[:index] if isinstance(step, dict) and isinstance(step.get("run"), str)]
    if not any(guard in run and "--seal-output" in run and all(path in run for path in expected) for run in preceding):
        reject(errors, manifest, workflow, job, "artifact_budget", "artifact upload requires a preceding exact sealing check-artifact-budget guard")


def audit_artifact_guard_script(repo_root: pathlib.Path, errors: list[str]) -> None:
    path = repo_root / "scripts/ci/check-artifact-budget.py"
    if not path.is_file() or path.is_symlink():
        errors.append("artifact-budget: guard must be a regular non-symlink Python file"); return
    with tempfile.TemporaryDirectory() as directory:
        for probe in range(3):
            root = pathlib.Path(directory) / str(probe); root.mkdir()
            receipt_data, report_data = secrets.token_bytes(1 + secrets.randbelow(4096)), secrets.token_bytes(1 + secrets.randbelow(4096))
            receipt = root / f"{secrets.token_hex(8)}-receipt.json"
            report = root / f"{secrets.token_hex(8)}-report.json"
            output = root / f"{secrets.token_hex(8)}-evidence.zip"
            receipt.write_bytes(receipt_data); report.write_bytes(report_data)
            result = subprocess.run([sys.executable, str(path), "--seal-output", str(output), str(receipt), str(report)], capture_output=True, text=True)
            if result.returncode:
                errors.append(f"artifact-budget: guard rejected probe {probe}: {result.stderr.strip() or result.stdout.strip()}"); return
            try:
                entry = os.lstat(output)
                if stat.S_ISLNK(entry.st_mode) or not stat.S_ISREG(entry.st_mode) or entry.st_size > 25 * 1024 * 1024 or not zipfile.is_zipfile(output): raise ValueError("output is not a bounded regular ZIP")
                with zipfile.ZipFile(output) as archive:
                    expected = {receipt.name: receipt.read_bytes(), report.name: report.read_bytes()}
                    if set(archive.namelist()) != {*expected, "artifact-manifest.json"}: raise ValueError("ZIP members are not exact")
                    manifest = json.loads(archive.read("artifact-manifest.json"))
                    expected_manifest = {"schema_version": "tracksmith-compact-artifact/1", "files": [{"name": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()} for name, data in expected.items()]}
                    if manifest != expected_manifest or any(archive.read(name) != data for name, data in expected.items()): raise ValueError("ZIP content or internal manifest hash mismatch")
            except (OSError, ValueError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as error:
                errors.append(f"artifact-budget: guard did not produce the required sealed ZIP snapshot: {error}"); return


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
    audit_artifact_guard_script(repo_root, errors)
    tutor_runner = repo_root / "scripts/ci/run-macos-tutor.sh"
    if tutor_runner.exists():
        tutor_text = tutor_runner.read_text(encoding="utf-8")
        if "cpu_budget.py" not in tutor_text or "TRACKSMITH_MAX_TUTOR_SHARDS:-3" not in tutor_text:
            errors.append("phase2:macos_tutor: worker cap must use cpu_budget.py and a maximum of three shards")
        if "swift build -c release --product TutorConversationTests" not in tutor_text or "swift run -c release TutorConversationTests" in tutor_text:
            errors.append("phase2:macos_tutor: must build once and execute the release binary directly")
    for path in sorted((*workflow_dir.glob("*.yml"), *workflow_dir.glob("*.yaml"))):
        doc = parse_yaml(path)
        workflow, raw = path.name, path.read_text()
        if doc.get("permissions") != {"contents": "read"}:
            errors.append(f"{workflow}:<workflow>: permissions: top-level permissions must be exactly contents: read")
        triggers = doc.get("on", doc.get("true", doc.get(True)))
        if triggers == "pull_request_target" or (isinstance(triggers, (list, dict)) and "pull_request_target" in triggers):
            errors.append(f"{workflow}:<workflow>: pull_request_target: forbidden")
        if (isinstance(triggers, str) and triggers in {"workflow_run", "repository_dispatch", "schedule"}) or (isinstance(triggers, (list, dict)) and any(item in triggers for item in ("workflow_run", "repository_dispatch", "schedule"))):
            errors.append(f"{workflow}:<workflow>: recursive or scheduled trigger is forbidden")
        jobs = doc.get("jobs")
        if not isinstance(jobs, dict) or not jobs:
            errors.append(f"{workflow}:<workflow>: jobs: missing jobs mapping")
            continue
        for job, body in jobs.items():
            if not isinstance(body, dict):
                errors.append(f"{workflow}:{job}: job: must be a mapping")
                continue
            audit_execution_environment(doc.get("env"), manifest, workflow, job, errors, "workflow env")
            audit_execution_environment(body.get("env"), manifest, workflow, job, errors, "job env")
            defaults = doc.get("defaults")
            if defaults is not None:
                audit_shell(defaults.get("run", {}).get("shell") if isinstance(defaults.get("run"), dict) else None, manifest, workflow, job, errors, "workflow defaults.run.shell")
            job_defaults = body.get("defaults")
            if job_defaults is not None:
                audit_shell(job_defaults.get("run", {}).get("shell") if isinstance(job_defaults.get("run"), dict) else None, manifest, workflow, job, errors, "job defaults.run.shell")
            if type(body.get("timeout-minutes")) is not int or not 1 <= body["timeout-minutes"] <= 120:
                reject(errors, manifest, workflow, job, "timeout", "timeout-minutes must be an integer from 1 through 120")
            runner = body.get("runs-on")
            labels = runner if isinstance(runner, list) else [runner]
            if not labels or any(not isinstance(label, str) or label not in ALLOWED_RUNNERS or DISALLOWED_RUNNER.search(label) for label in labels):
                reject(errors, manifest, workflow, job, "runner", f"runs-on must use only {sorted(ALLOWED_RUNNERS)}")
            serialized = json.dumps(body)
            if isinstance(body.get("strategy"), dict) and "matrix" in body["strategy"]:
                reject(errors, manifest, workflow, job, "matrix", "matrix jobs are forbidden until a bounded audited contract is added")
            if SECRET_REF.search(serialized): reject(errors, manifest, workflow, job, "secrets", "secret references are forbidden")
            if FORBIDDEN_COMMAND.search(serialized): reject(errors, manifest, workflow, job, "cloud_model", "cloud/model command is forbidden")
            steps = body.get("steps", []) if isinstance(body.get("steps"), list) else []
            for step_index, step in enumerate(steps):
                if not isinstance(step, dict): continue
                if "run" in step:
                    if not isinstance(step["run"], str):
                        reject(errors, manifest, workflow, job, "inline_shell", "inline run must be a string")
                    else:
                        try: audit_inline_run(step["run"], manifest, repo_root, workflow, job, errors)
                        except RuntimeError as error: reject(errors, manifest, workflow, job, "inline_shell", str(error))
                audit_shell(step.get("shell"), manifest, workflow, job, errors, "step shell")
                audit_execution_environment(step.get("env"), manifest, workflow, job, errors, "step env")
                if not isinstance(step.get("uses"), str): continue
                action, sep, pin = step["uses"].rpartition("@")
                if not sep or not FULL_SHA.fullmatch(pin):
                    reject(errors, manifest, workflow, job, "action_pin", f"action must use a full SHA: {step['uses']}")
                if action == "actions/cache" and not manifest["cache_policy"]["enabled"]:
                    reject(errors, manifest, workflow, job, "cache_policy", "actions/cache is prohibited while cache_policy.enabled is false")
                if action not in APPROVED_ACTIONS or pin != APPROVED_ACTIONS.get(action):
                    reject(errors, manifest, workflow, job, "action_allowlist", f"unreviewed action or SHA: {step['uses']}")
                if action == "actions/upload-artifact":
                    config = step.get("with", {})
                    if not isinstance(config, dict) or type(config.get("retention-days")) is not int or not 1 <= config["retention-days"] <= 3:
                        reject(errors, manifest, workflow, job, "artifact_retention", "artifacts require integer retention-days from 1 through 3")
                    artifact_path = str(config.get("path", ""))
                    if not artifact_path or UNSAFE_ARTIFACT.search(artifact_path):
                        reject(errors, manifest, workflow, job, "artifact_path", "artifact path includes unsafe payload")
                    audit_artifact_upload(workflow, job, steps, step_index, config, manifest, errors)
            audit_workflow_job_binding(workflow, job, body, manifest, errors)
        if DISALLOWED_RUNNER.search(raw): errors.append(f"{workflow}:<workflow>: runner_terms: disallowed runner term appears")
    return errors


def self_test() -> None:
    manifest_data = json.loads((ROOT / "ci/tracksmith_compute_lanes.json").read_text())
    good = """name: safe\non: [pull_request]\npermissions:\n  contents: read\njobs:\n  check:\n    runs-on: ubuntu-24.04\n    timeout-minutes: 5\n    steps:\n      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1\n"""
    with tempfile.TemporaryDirectory() as temp:
        root = pathlib.Path(temp); repo = root / "repo"; repo.mkdir(); workflows = root / "workflows"; workflows.mkdir(); manifest = root / "lanes.json"
        def write_manifest(data: dict[str, Any]) -> None: manifest.write_text(json.dumps(data))
        def write_semantic_dependencies(data: dict[str, Any] | None = None) -> None:
            target = repo / "ci/semantic_dependencies.json"; target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(data if data is not None else json.loads((ROOT / "ci/semantic_dependencies.json").read_text())))
        def write_entrypoints(data: dict[str, Any]) -> None:
            for lane in data.get("lanes", []):
                match = ENTRYPOINT_COMMAND.fullmatch(lane.get("command", "")) if isinstance(lane, dict) else None
                if match:
                    path = repo / match.group(1); path.parent.mkdir(parents=True, exist_ok=True)
                    if path.name == "run-macos-tutor.sh":
                        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\nswift build -c release --product TutorConversationTests\npython3 scripts/ci/cpu_budget.py --cap \"${TRACKSMITH_MAX_TUTOR_SHARDS:-3}\" --reserve 1\n")
                        (repo / "scripts/ci/cpu_budget.py").write_text("#!/usr/bin/env python3\nprint(1)\n")
                    else:
                        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\nprintf 'safe entrypoint\\n'\n")
            (repo / "scripts/ci/check-artifact-budget.py").write_text((ROOT / "scripts/ci/check-artifact-budget.py").read_text())
        write_manifest(manifest_data); write_semantic_dependencies(); write_entrypoints(manifest_data); (workflows / "safe.yml").write_text(good)
        if audit(workflows, manifest, repo): raise AssertionError("valid fixture was rejected")
        cases: list[tuple[str, str, dict[str, Any]]] = [
            ("paid-runner", good.replace("ubuntu-24.04", "ubuntu-latest"), manifest_data),
            ("missing-timeout", good.replace("    timeout-minutes: 5\n", ""), manifest_data),
            ("secret", good + "      - run: echo ${{ secrets.TOKEN }}\n", manifest_data),
            ("computed-secret", good + "      - run: echo ${{ secrets[env.SECRET_NAME] }}\n", manifest_data),
            ("unpinned", good.replace("@3d3c42e5aac5ba805825da76410c181273ba90b1", "@v7"), manifest_data),
            ("target", good.replace("on: [pull_request]", "on: [pull_request_target]"), manifest_data),
            ("cloud", good + "      - run: cloud-eval\n", manifest_data),
            ("artifact", good + "      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: ${{ runner.temp }}/DerivedData\n          retention-days: 90\n", manifest_data),
            ("unreviewed-action", good.replace("actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1", "actions/cache@3d3c42e5aac5ba805825da76410c181273ba90b1"), manifest_data),
            ("matrix", good.replace("    steps:\n", "    strategy:\n      matrix: { shard: [1, 2] }\n    steps:\n"), manifest_data),
            ("recursive-trigger", good.replace("on: [pull_request]", "on: [workflow_run]"), manifest_data),
            ("scalar-recursive-trigger", good.replace("on: [pull_request]", "on: workflow_run"), manifest_data),
            ("scalar-scheduled-trigger", good.replace("on: [pull_request]", "on: schedule"), manifest_data),
        ]
        cache = good + "      - uses: actions/cache@3d3c42e5aac5ba805825da76410c181273ba90b1\n"
        malformed = json.loads(json.dumps(manifest_data)); malformed["lanes"].pop()
        semantic_lane_drift = json.loads(json.dumps(manifest_data)); next(lane for lane in semantic_lane_drift["lanes"] if lane["id"] == "macos_xcode_companion")["change_paths"] = ["apps/CompanionApp/"]
        expired = json.loads(json.dumps(manifest_data)); expired["audit_exceptions"] = [{"workflow":"safe.yml","job":"check","rule":"runner","reason":"fixture","owner":"owner","reviewed_on":"2026-08-01","expires_on":"2026-08-02"}]
        bad_exception = json.loads(json.dumps(manifest_data)); bad_exception["audit_exceptions"] = [{"workflow":"safe.yml","job":"check","rule":"runner","reason":"fixture","owner":"owner","reviewed_on":"2026-08-23"}]
        soft_budget_true = json.loads(json.dumps(manifest_data)); soft_budget_true["cache_policy"]["soft_budget_bytes"] = True
        soft_budget_false = json.loads(json.dumps(manifest_data)); soft_budget_false["cache_policy"]["soft_budget_bytes"] = False
        manual_timeout_false = json.loads(json.dumps(manifest_data)); next(lane for lane in manual_timeout_false["lanes"] if lane["id"] == "manual_heavy")["timeout_minutes"] = False
        owner_timeout_false = json.loads(json.dumps(manifest_data)); next(lane for lane in owner_timeout_false["lanes"] if lane["id"] == "local_apple_logic_owner")["timeout_minutes"] = False
        artifact_budget_true = json.loads(json.dumps(manifest_data)); artifact_budget_true["artifact_policy"]["maximum_bytes_per_run"] = True
        artifact_retention_false = json.loads(json.dumps(manifest_data)); artifact_retention_false["artifact_policy"]["retention_days"] = False
        cases.extend([
            ("cache-disabled", cache, manifest_data),
            ("missing-lane", good, malformed),
            ("semantic-lane-drift", good, semantic_lane_drift),
            ("expired-exception", good, expired),
            ("malformed-exception", good, bad_exception),
            ("soft-budget-true", good, soft_budget_true),
            ("soft-budget-false", good, soft_budget_false),
            ("manual-timeout-false", good, manual_timeout_false),
            ("owner-timeout-false", good, owner_timeout_false),
            ("artifact-budget-true", good, artifact_budget_true),
            ("artifact-retention-false", good, artifact_retention_false),
            ("timeout-too-large", good.replace("timeout-minutes: 5", "timeout-minutes: 121"), manifest_data),
            ("retention-zero", good + "      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: ${{ runner.temp }}/safe.json\n          retention-days: 0\n", manifest_data),
            ("applications-artifact", good + "      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: /Applications/TrackSmith.app\n          retention-days: 3\n", manifest_data),
            ("plugin-artifact", good + "      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: Library/Audio/Plug-Ins/Components/TrackSmith.component\n          retention-days: 3\n", manifest_data),
            ("inline-codesign", good + "      - run: codesign --force unsafe.app\n", manifest_data),
            ("inline-signed-xcode", good + "      - run: CODE_SIGNING_ALLOWED=YES xcodebuild -project App.xcodeproj build\n", manifest_data),
            ("inline-unsigned-xcode", good + "      - run: xcodebuild -project App.xcodeproj build\n", manifest_data),
            ("inline-logic", good + "      - run: open -a Logic\n", manifest_data),
            ("inline-private-audio", good + "      - run: afplay /tmp/private.wav\n", manifest_data),
            ("inline-shell-indirection", good + "      - run: bash -c 'codesign --force unsafe.app'\n", manifest_data),
            ("inline-bare-xcode", good + "      - run: xcodebuild\n", manifest_data),
            ("inline-bash-env", good.replace("jobs:\n", "env:\n  BASH_ENV: /tmp/unsafe.sh\njobs:\n"), manifest_data),
            ("workflow-path-shadow", good.replace("jobs:\n", "env:\n  PATH: ${{ github.workspace }}:$PATH\njobs:\n"), manifest_data),
            ("workflow-path-case-shadow", good.replace("jobs:\n", "env:\n  Path: ${{ github.workspace }}:$PATH\njobs:\n"), manifest_data),
            ("job-path-shadow", good.replace("    steps:\n", "    env:\n      PATH: ${{ github.workspace }}:$PATH\n    steps:\n"), manifest_data),
            ("step-path-shadow", good + "      - run: bash scripts/ci/run-linux-integrity.sh\n        env:\n          PATH: ${{ github.workspace }}:$PATH\n", manifest_data),
            ("github-path-shadow", good + "      - run: echo '${{ github.workspace }}' >> \"$GITHUB_PATH\"\n", manifest_data),
            ("github-env-path-shadow", good + "      - run: echo 'PATH=${{ github.workspace }}:$PATH' >> \"$GITHUB_ENV\"\n", manifest_data),
            ("github-env-bash-shadow", good + "      - run: echo 'BASH_ENV=${{ github.workspace }}/bash' >> \"$GITHUB_ENV\"\n", manifest_data),
            ("github-env-indirect-shadow", good + "      - run: target=GITHUB_ENV; echo 'PATH=${{ github.workspace }}:$PATH' >> \"${!target}\"\n", manifest_data),
            ("github-env-quoted-target", good + "      - run: target=GITHUB_'ENV'; echo 'PATH=${{ github.workspace }}:$PATH' >> \"$target\"\n", manifest_data),
            ("github-env-eval-shadow", good + "      - run: target=GITHUB_'ENV'; eval \"echo PATH=${{ github.workspace }}:$PATH >> \\\"${!target}\\\"\"\n", manifest_data),
            ("github-env-command-substitution", good + "      - run: printenv GITHUB_$(printf ENV); PA$(printf TH)=${{ github.workspace }}:$PATH bash scripts/ci/run-linux-integrity.sh\n", manifest_data),
            ("inline-path-shadow", good + "      - run: PATH=${{ github.workspace }}:$PATH bash scripts/ci/run-linux-integrity.sh\n", manifest_data),
            ("inline-shell-function-shadow", good + "      - run: bash() { exit 0; }; bash scripts/ci/run-linux-integrity.sh\n", manifest_data),
            ("inline-background", good + "      - run: bash scripts/ci/run-linux-integrity.sh &\n", manifest_data),
        ])
        for name, artifact_path in (
            ("credentials-artifact", "${{ runner.temp }}/credentials.json"),
            ("secret-artifact", "reports/secret.txt"),
            ("token-artifact", "reports/token.txt"),
            ("api-key-artifact", "reports/api-key.txt"),
            ("provider-response-artifact", "reports/provider-response.json"),
        ):
            cases.append((name, good + f"      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a\n        with:\n          path: {artifact_path}\n          retention-days: 3\n", manifest_data))
        external_entrypoint = json.loads(json.dumps(manifest_data)); external_entrypoint["lanes"][0]["command"] = "bash /tmp/not-allowed.sh"
        cases.append(("external-entrypoint", good, external_entrypoint))
        for name, text, data in cases:
            for file in workflows.glob("*.yml"): file.unlink()
            write_manifest(data); write_entrypoints(data); (workflows / f"{name}.yml").write_text(text)
            if not audit(workflows, manifest, repo): raise AssertionError(f"negative fixture was accepted: {name}")
        for name, mutate in (
            ("semantic-path-missing", lambda value: value["lanes"]["linux_retrieval"].remove("research/scripts/package18_audit.py")),
            ("semantic-path-broader", lambda value: value["lanes"]["macos_tutor"].append("packages/")),
        ):
            semantic = json.loads((ROOT / "ci/semantic_dependencies.json").read_text())
            mutate(semantic)
            for file in workflows.glob("*.yml"): file.unlink()
            write_manifest(manifest_data); write_semantic_dependencies(semantic); write_entrypoints(manifest_data); (workflows / f"{name}.yml").write_text(good)
            if not audit(workflows, manifest, repo): raise AssertionError(f"negative fixture was accepted: {name}")
        write_semantic_dependencies()
        def reset_safe_fixture() -> None:
            for file in workflows.glob("*.yml"): file.unlink()
            write_manifest(manifest_data); write_entrypoints(manifest_data)
            (workflows / "safe.yml").write_text(good)

        reset_safe_fixture()
        (repo / "scripts/ci/check-artifact-budget.py").write_text("#!/usr/bin/env python3\nfrom pathlib import Path\nimport sys, zipfile\npaths = [Path(value) for value in sys.argv[3:]]\noutput = Path(sys.argv[2])\nif [path.name for path in paths] == ['package019-ci-receipt.json', 'xcode-products-report.json'] and [path.stat().st_size for path in paths] == [27, 26]:\n    with zipfile.ZipFile(output, 'w') as archive:\n        [archive.write(path, path.name) for path in paths]\nelse:\n    output.write_bytes(b'not-a-zip-artifact')\n")
        if not audit(workflows, manifest, repo): raise AssertionError("fixed-probe fake artifact guard was accepted")

        reset_safe_fixture()
        (repo / "scripts/ci/opaque-check.sh").write_text("#!/usr/bin/env bash\ncodesign --force unsafe.app\n")
        (workflows / "inline-helper-owner.yml").write_text(good + "      - run: bash scripts/ci/opaque-check.sh\n")
        if not audit(workflows, manifest, repo): raise AssertionError("negative fixture was accepted: inline-helper-owner")
        reset_safe_fixture()
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\nxcodebuild -project App.xcodeproj CODE_SIGNING_ALLOWED=NO build\n")
        if audit(workflows, manifest, repo): raise AssertionError("explicit unsigned xcodebuild fixture was rejected")
        for name, command in (
            ("xcrun-default", "xcrun xcodebuild\n"),
            ("xcrun-archive", "xcrun --sdk macosx xcodebuild archive\n"),
            ("xcode-test", "xcodebuild test\n"),
            ("xcode-variable", "builder=xcodebuild; \"$builder\" build\n"),
            ("xcode-command", "command xcodebuild archive\n"),
            ("xcode-quoted", "xcode\"build\" -project App.xcodeproj build\n"),
            ("xcrun-quoted", "xcrun xcode\"build\" archive\n"),
            ("xcode-backslash", "xcode\\build -project App.xcodeproj CODE_SIGNING_ALLOWED=NO build\n"),
            ("xcode-expansion", "xco${EMPTY}debuild -project App.xcodeproj CODE_SIGNING_ALLOWED=NO build\n"),
            ("xcode-backslash-signing-override", "xcodebuild -project App.xcodeproj CODE_SIGNING_ALLOWED=NO CO\\DE_SIGNING_ALLOWED=YES build\n"),
            ("xcode-backtick", "xco`printf de`build -project App.xcodeproj CODE_SIGNING_ALLOWED=NO build\n"),
            ("xcode-backtick-signing", "xcodebuild -project App.xcodeproj CODE_SIGNING_ALLOWED=NO CO`printf DE`_SIGNING_ALLOWED=YES build\n"),
            ("xcode-command-substitution", "xco$(printf debuild) -project App.xcodeproj CO$(printf DE)_SIGNING_ALLOWED=NO build\n"),
            ("xcode-split-signing-override", "signing='CO''DE_SIGNING_ALLOWED=YES'\nxcodebuild -project App.xcodeproj CODE_SIGNING_ALLOWED=NO \"$signing\" build\n"),
        ):
            reset_safe_fixture()
            (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + command)
            if not audit(workflows, manifest, repo): raise AssertionError(f"negative fixture was accepted: {name}")
        reset_safe_fixture()
        (workflows / "tutor-integrity.yml").write_text(good.replace("  check:\n", "  linux_integrity:\n") + "      - run: true\n")
        if not audit(workflows, manifest, repo): raise AssertionError("bound lane no-op fixture was accepted")
        reset_safe_fixture()
        (workflows / "tutor-integrity.yml").write_text(good.replace("  check:\n", "  linux_integrity:\n") + "      - run: bash scripts/ci/run-linux-evaluation.sh\n")
        if not audit(workflows, manifest, repo): raise AssertionError("bound lane substitution fixture was accepted")
        for name, text in (
            ("bound-lane-if", good.replace("  check:\n", "  linux_integrity:\n    if: ${{ always() }}\n") + "      - run: bash scripts/ci/run-linux-integrity.sh\n"),
            ("bound-lane-continue", good.replace("  check:\n", "  linux_integrity:\n    continue-on-error: true\n") + "      - run: bash scripts/ci/run-linux-integrity.sh\n"),
            ("bound-lane-soft", good.replace("  check:\n", "  linux_integrity:\n") + "      - run: bash scripts/ci/run-linux-integrity.sh || true\n"),
        ):
            reset_safe_fixture()
            (workflows / "tutor-integrity.yml").write_text(text)
            if not audit(workflows, manifest, repo): raise AssertionError(f"negative fixture was accepted: {name}")
        reset_safe_fixture()
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\nxcode$(printf build)\n")
        if not audit(workflows, manifest, repo): raise AssertionError("dynamic xcode fixture was accepted")
        reset_safe_fixture()
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\npython3 \"research/scripts/$HELPER.py\"\n")
        if not audit(workflows, manifest, repo): raise AssertionError("dynamic Python helper fixture was accepted")
        reset_safe_fixture()
        helper = repo / "research/scripts/unsafe-helper.py"; helper.parent.mkdir(parents=True, exist_ok=True)
        helper.write_text("import subprocess\nsubprocess.run(args=['bash', 'scripts/ci/unsafe.sh'], check=True)\n")
        (repo / "scripts/ci/unsafe.sh").write_text("#!/usr/bin/env bash\ncodesign --force unsafe.app\n")
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\npython3 research/scripts/unsafe-helper.py\n")
        if not audit(workflows, manifest, repo): raise AssertionError("Python keyword shell helper fixture was accepted")
        reset_safe_fixture()
        helper.write_text("import os, subprocess\nsubprocess.run(['xcodebuild', 'CODE_SIGNING_ALLOWED=YES', 'build'], check=True)\nos.system('sleep 1 &')\n")
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\npython3 research/scripts/unsafe-helper.py\n")
        if not audit(workflows, manifest, repo): raise AssertionError("Python subprocess policy-surface fixture was accepted")
        reset_safe_fixture()
        helper.write_text("from subprocess import run as spawn\nfrom os import system as invoke\nspawn(['xcodebuild', 'CODE_SIGNING_ALLOWED=YES', 'build'])\ninvoke('sleep 1 &')\n")
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\npython3 research/scripts/unsafe-helper.py\n")
        if not audit(workflows, manifest, repo): raise AssertionError("aliased Python process-spawn fixture was accepted")
        reset_safe_fixture()
        helper.write_text("import subprocess\nspawn = subprocess.run\nspawn(['xcodebuild', 'CODE_SIGNING_ALLOWED=YES', 'build'])\n")
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\npython3 research/scripts/unsafe-helper.py\n")
        if not audit(workflows, manifest, repo): raise AssertionError("assigned Python process-spawn fixture was accepted")
        reset_safe_fixture()
        helper.write_text("getattr(__import__('subprocess'), 'run')(['xcodebuild', 'CODE_SIGNING_ALLOWED=YES', 'build'])\n")
        (repo / "scripts/ci/run-linux-integrity.sh").write_text("#!/usr/bin/env bash\nset -euo pipefail\npython3 research/scripts/unsafe-helper.py\n")
        if not audit(workflows, manifest, repo): raise AssertionError("reflective Python process-spawn fixture was accepted")
        artifact_job = """name: safe
on: [pull_request]
permissions:
  contents: read
jobs:
  macos_xcode_products:
    runs-on: macos-15
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - run: bash scripts/ci/run-macos-xcode-products.sh
      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
        with:
          path: ${{ runner.temp }}/tracksmith-xcode-products/xcode-evidence.zip
          retention-days: 3
"""
        reset_safe_fixture()
        (workflows / "tutor-macos-swift.yml").write_text(artifact_job)
        if not audit(workflows, manifest, repo): raise AssertionError("artifact upload without size guard was accepted")
        reset_safe_fixture()
        seal_guard = """      - run: >-
          python3 scripts/ci/check-artifact-budget.py
          --seal-output \"${{ runner.temp }}/tracksmith-xcode-products/xcode-evidence.zip\"
          \"${{ runner.temp }}/tracksmith-xcode-products/package019-ci-receipt.json\"
          \"${{ runner.temp }}/tracksmith-xcode-products/xcode-products-report.json\"
"""
        sealed_job = artifact_job.replace("      - uses: actions/upload-artifact", seal_guard + "      - uses: actions/upload-artifact")
        (workflows / "tutor-macos-swift.yml").write_text(sealed_job)
        if audit(workflows, manifest, repo): raise AssertionError("sealed artifact fixture was rejected")
        reset_safe_fixture()
        unsealed_guard = sealed_job.replace("--seal-output \"${{ runner.temp }}/tracksmith-xcode-products/xcode-evidence.zip\"\n          ", "")
        (workflows / "tutor-macos-swift.yml").write_text(unsealed_guard)
        if not audit(workflows, manifest, repo): raise AssertionError("non-atomic artifact guard was accepted")
        reset_safe_fixture()
        broad = sealed_job.replace("${{ runner.temp }}/tracksmith-xcode-products/xcode-evidence.zip", ".")
        (workflows / "tutor-macos-swift.yml").write_text(broad)
        if not audit(workflows, manifest, repo): raise AssertionError("broad artifact path was accepted")

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
            ("hidden-script-if-dynamic", "if bash \"$helper\"; then printf safe; fi\n", None, False),
            ("hidden-script-negated-external", "! bash /tmp/helper.sh\n", None, False),
            ("hidden-script-grouped-external", "( bash /tmp/helper.sh )\n", None, False),
            ("hidden-script-assignment-external", "FOO=bar bash /tmp/helper.sh\n", None, False),
        ):
            reject_entrypoint(name, content, helper, symlink_helper)
        def closure_chain(total_files: int) -> list[str]:
            reset_safe_fixture()
            names = [f"chain-{index:02}.sh" for index in range(total_files - 1)]
            entrypoint = repo / "scripts/ci/run-linux-integrity.sh"
            entrypoint.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + (f"bash scripts/ci/{names[0]}\n" if names else "printf safe\n"))
            for index, name in enumerate(names):
                next_command = f"bash scripts/ci/{names[index + 1]}\n" if index + 1 < len(names) else "printf safe\n"
                (repo / "scripts/ci" / name).write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + next_command)
            return audit(workflows, manifest, repo)
        if closure_chain(32): raise AssertionError("32-file closure was rejected")
        if not closure_chain(33): raise AssertionError("33-file closure was accepted")
    print("audit-free-compute self-test: 111 rejection classes passed (81 retained plus command-resolution, dynamic-shell, shell-resolved Xcode, Python execution-surface, and randomized sealed-artifact rejection)")


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
