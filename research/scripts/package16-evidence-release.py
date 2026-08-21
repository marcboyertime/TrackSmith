#!/usr/bin/env python3
"""Repository-owned P16 evidence, acquisition, and controlled-fixture runner.

It never executes a tool shipped in the supplied P16 archive.  Downloads and all
derived audio stay in the user-deletable P16 cache; repository files are inputs
only.  Reports deliberately distinguish bytes/measured transforms from listening.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import signal
import stat
import subprocess
import sys
import time
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "research/community_knowledge/packages/tracksmith-corpus-016-integration-retrieval-quality-control/sources/source_access_manifest.json"
DEFAULT_CACHE = pathlib.Path.home() / "Library/Caches/TrackSmith/P16"
MAX_STANDARD_BYTES = 8 * 1024**3
SMOKE_IDS = {
    "pkg016.source.audio.babyslakh", "pkg016.source.audio.ebu-loudness",
    "pkg016.source.audio.groove-midi-midionly", "pkg016.source.audio.maestro-midi",
}
LARGE_OR_REQUESTED = {"direct_download_large", "zenodo_api_large", "request_required"}
STOPPED = False


def stop(*_: object) -> None:
    global STOPPED
    STOPPED = True


signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def md5(path: pathlib.Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def cache_root(value: str | None) -> pathlib.Path:
    root = pathlib.Path(value).expanduser().resolve() if value else DEFAULT_CACHE.resolve()
    expected = (pathlib.Path.home() / "Library/Caches").resolve()
    if expected not in root.parents and root != expected:
        raise SystemExit("P16_EVIDENCE_ERROR cache must remain under ~/Library/Caches")
    root.mkdir(parents=True, exist_ok=True)
    return root


def report(root: pathlib.Path, name: str, value: object) -> pathlib.Path:
    output = root / "reports" / name
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, output)
    return output


def load_manifest() -> dict:
    value = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if not isinstance(value.get("datasets"), list):
        raise SystemExit("P16_EVIDENCE_ERROR invalid source manifest")
    seen: set[str] = set()
    for item in value["datasets"]:
        identifier = item.get("id")
        if not isinstance(identifier, str) or identifier in seen or not identifier.startswith("pkg016.source.audio."):
            raise SystemExit("P16_EVIDENCE_ERROR unsafe dataset identity")
        seen.add(identifier)
    return value


def usable_download(item: dict) -> tuple[bool, str]:
    download = item.get("download") or {}
    if item.get("access_mode") in LARGE_OR_REQUESTED:
        return False, "large_or_request_gated"
    if not item.get("license"):
        return False, "terms_missing"
    if not download.get("filename") or not download.get("size_bytes"):
        return False, "bounded_filename_or_size_missing"
    checksum, checksum_type = download.get("checksum"), download.get("checksum_type")
    if checksum_type not in {"sha256", "md5"} or not isinstance(checksum, str):
        return False, "checksum_missing"
    if item.get("access_mode") == "zenodo_api" and not isinstance(download.get("record_id"), int):
        return False, "zenodo_record_missing"
    if item.get("access_mode") == "direct_download" and not isinstance(download.get("url"), str):
        return False, "direct_url_missing"
    return True, "eligible_after_terms_recheck"


def free_space_ok(root: pathlib.Path, required: int) -> tuple[bool, int]:
    available = shutil.disk_usage(root).free
    return available >= required * 2, available


def zenodo_url(item: dict) -> str:
    download = item["download"]
    request = urllib.request.Request(f"https://zenodo.org/api/records/{download['record_id']}", headers={"User-Agent": "TrackSmith-P16-Evidence/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        metadata = json.load(response)
    matches = [entry for entry in metadata.get("files", []) if entry.get("key") == download["filename"]]
    if len(matches) != 1:
        raise ValueError("Zenodo manifest filename did not resolve uniquely")
    return str(matches[0]["links"]["self"])


def safe_extract(source: pathlib.Path, destination: pathlib.Path, byte_cap: int) -> int:
    if source.suffix.lower() != ".zip":
        return 0
    total = 0
    with zipfile.ZipFile(source) as archive:
        for member in archive.infolist():
            path = pathlib.PurePosixPath(member.filename)
            if path.is_absolute() or ".." in path.parts or stat.S_ISLNK(member.external_attr >> 16):
                raise ValueError("unsafe archive member")
            total += member.file_size
            if total > byte_cap:
                raise ValueError("archive expanded-byte cap exceeded")
        for member in archive.infolist():
            if member.is_dir():
                continue
            target = destination / pathlib.PurePosixPath(member.filename)
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as input_file, target.open("xb") as output_file:
                shutil.copyfileobj(input_file, output_file, 1024 * 1024)
    return total


def download_one(root: pathlib.Path, item: dict) -> dict:
    allowed, reason = usable_download(item)
    download = item.get("download") or {}
    result = {"id": item["id"], "status": "deferred", "reason": reason, "measured": False, "heard": False}
    if not allowed:
        return result
    size = int(download["size_bytes"])
    space_ok, free_bytes = free_space_ok(root, size)
    result["free_bytes"] = free_bytes
    if not space_ok:
        result["reason"] = "two_x_free_space_gate_failed"
        return result
    target = root / "downloads" / str(download["filename"])
    target.parent.mkdir(parents=True, exist_ok=True)
    expected = str(download["checksum"])
    checksum = sha256 if download["checksum_type"] == "sha256" else md5
    reused = target.is_file() and checksum(target) == expected
    if target.exists() and not reused:
        target.unlink()
    if STOPPED:
        result["reason"] = "cancelled_before_download"
        return result
    try:
        if not reused:
            url = str(download["url"]) if item["access_mode"] == "direct_download" else zenodo_url(item)
            request = urllib.request.Request(url, headers={"User-Agent": "TrackSmith-P16-Evidence/1.0"})
            temporary = target.with_suffix(target.suffix + ".part")
            with urllib.request.urlopen(request, timeout=30) as response, temporary.open("xb") as output:
                declared = response.headers.get("Content-Length")
                if declared and int(declared) > size + 1024 * 1024:
                    raise ValueError("remote content-length exceeds manifest cap")
                written = 0
                while not STOPPED:
                    block = response.read(1024 * 1024)
                    if not block:
                        break
                    written += len(block)
                    if written > size + 1024 * 1024:
                        raise ValueError("download byte cap exceeded")
                    output.write(block)
            if STOPPED:
                temporary.unlink(missing_ok=True)
                result["reason"] = "cancelled"
                return result
            if checksum(temporary) != expected:
                temporary.unlink(missing_ok=True)
                raise ValueError("checksum_mismatch")
            os.replace(temporary, target)
        extracted = 0
        if download.get("extract"):
            extraction = root / "extracted" / item["id"]
            marker = extraction / ".p16-extraction-complete"
            if extraction.exists() and not marker.exists():
                # This exact cache child is a previous failed/cancelled run,
                # never a user path. Remove it before retrying safely.
                shutil.rmtree(extraction)
            if extraction.exists():
                result.update({"status": "reused", "bytes": target.stat().st_size, "checksum": expected, "extracted_bytes": 0, "measured": True})
                return result
            extraction.mkdir(parents=True)
            # The 2× policy is a *free-space* gate, not an unsupported claim
            # that every safe archive expands to at most twice compressed size.
            # Keep a distinct smoke extraction ceiling under the 8 GiB profile.
            extracted = safe_extract(target, extraction, min(8 * 1024**3, free_bytes - size))
            marker.write_text("complete\n", encoding="utf-8")
        result.update({"status": "reused" if reused else "downloaded", "bytes": target.stat().st_size, "checksum": expected, "extracted_bytes": extracted, "measured": True})
    except Exception as error:  # network/dependency failures are recorded, not hidden
        target.with_suffix(target.suffix + ".part").unlink(missing_ok=True)
        result.update({"status": "failed", "reason": type(error).__name__ + ":" + str(error)[:160]})
    return result


def audit(root: pathlib.Path) -> int:
    manifest = load_manifest()
    rows = []
    for item in manifest["datasets"]:
        allowed, reason = usable_download(item)
        rows.append({"id": item["id"], "access_mode": item["access_mode"], "eligible": allowed, "reason": reason, "profiles": item.get("download", {}).get("profiles", [])})
    path = report(root, "p16-acquisition-audit.json", {"schemaVersion": "1.0", "manifestSHA256": sha256(MANIFEST), "cache": str(root), "datasets": rows, "noSuppliedToolsExecuted": True})
    print(f"P16_ACQUISITION_AUDIT_OK datasets={len(rows)} report={path}")
    return 0


def smoke(root: pathlib.Path) -> int:
    manifest = load_manifest()
    rows = [download_one(root, item) for item in manifest["datasets"] if item["id"] in SMOKE_IDS]
    path = report(root, "p16-smoke-acquisition.json", {"schemaVersion": "1.0", "profile": "smoke", "results": rows, "deletableCache": True, "heard": False})
    print(f"P16_SMOKE_ACQUISITION_DONE attempted={len(rows)} downloaded={sum(row['status'] == 'downloaded' for row in rows)} reused={sum(row['status'] == 'reused' for row in rows)} deferred={sum(row['status'] == 'deferred' for row in rows)} failed={sum(row['status'] == 'failed' for row in rows)} report={path}")
    return 0


def standard_plan(root: pathlib.Path) -> int:
    rows = []
    total = 0
    for item in load_manifest()["datasets"]:
        if "standard" not in (item.get("download") or {}).get("profiles", []):
            continue
        allowed, reason = usable_download(item)
        size = int((item.get("download") or {}).get("size_bytes") or 0)
        if allowed:
            total += size
        rows.append({"id": item["id"], "bytes": size, "eligible": allowed, "reason": reason, "termsVerified": False})
    space_ok, free_bytes = free_space_ok(root, total)
    value = {"schemaVersion": "1.0", "profile": "standard", "manifestDefaultByteCap": MAX_STANDARD_BYTES, "candidateBytes": total, "freeBytes": free_bytes, "twoXGate": space_ok, "authorized": False, "reason": "terms/license must be verified at acquisition; no standard download started", "pending": rows}
    path = report(root, "p16-standard-pending.json", value)
    print(f"P16_STANDARD_PENDING_OK candidates={sum(row['eligible'] for row in rows)} bytes={total} freeBytes={free_bytes} twoXGate={str(space_ok).lower()} report={path}")
    return 0


def standard(root: pathlib.Path) -> int:
    """Acquire only manifest-bounded, request-free standard entries.

    License/terms text and an attribution record are retained with each result;
    absent manifest attribution is recorded as an honest source-identity fallback.
    """
    candidates = []
    for item in load_manifest()["datasets"]:
        if "standard" not in (item.get("download") or {}).get("profiles", []):
            continue
        allowed, reason = usable_download(item)
        if allowed:
            candidates.append(item)
    total = sum(int(item["download"]["size_bytes"]) for item in candidates)
    space_ok, free_bytes = free_space_ok(root, total)
    rows = []
    if not space_ok or total > MAX_STANDARD_BYTES:
        reason = "two_x_free_space_gate_failed" if not space_ok else "manifest_standard_cap_exceeded"
        rows = [{"id": item["id"], "status": "deferred", "reason": reason} for item in candidates]
    else:
        for item in candidates:
            row = download_one(root, item)
            row.update({"terms": item["license"], "attribution": item.get("attribution") or {"sourceID": item["id"], "license": item["license"], "manifestSHA256": sha256(MANIFEST)}})
            rows.append(row)
    deferred = [{"id": item["id"], "reason": usable_download(item)[1]} for item in load_manifest()["datasets"] if "standard" in (item.get("download") or {}).get("profiles", []) and item not in candidates]
    path = report(root, "p16-standard-acquisition.json", {"schemaVersion": "1.0", "profile": "standard", "manifestDefaultByteCap": MAX_STANDARD_BYTES, "candidateBytes": total, "freeBytes": free_bytes, "twoXGate": space_ok, "results": rows, "deferred": deferred, "deletableCache": True, "heard": False})
    print(f"P16_STANDARD_ACQUISITION_DONE attempted={len(rows)} downloaded={sum(row.get('status') == 'downloaded' for row in rows)} reused={sum(row.get('status') == 'reused' for row in rows)} deferred={len(deferred) + sum(row.get('status') == 'deferred' for row in rows)} failed={sum(row.get('status') == 'failed' for row in rows)} bytes={total} report={path}")
    return 0


def fixture_command(base: pathlib.Path, output: pathlib.Path, filter_graph: str) -> list[str]:
    return ["ffmpeg", "-v", "error", "-y", "-i", str(base), "-af", filter_graph, "-ar", "48000", "-ac", "2", str(output)]


def fixtures(root: pathlib.Path) -> int:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("P16_EVIDENCE_ERROR ffmpeg missing; no fixture substitute claimed")
    generated = root / "fixtures" / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    base = generated / "p16-controlled-source.wav"
    version = subprocess.check_output([ffmpeg, "-version"], text=True).splitlines()[0]
    public_candidates = sorted(path for path in (root / "extracted" / "pkg016.source.audio.babyslakh").rglob("*.wav") if "__MACOSX" not in path.parts and not path.name.startswith("._")) if (root / "extracted" / "pkg016.source.audio.babyslakh").exists() else []
    if public_candidates:
        source_input = public_candidates[0]
        source_kind = "public_downloaded_babyslakh_stem"
        subprocess.run([ffmpeg, "-v", "error", "-y", "-i", str(source_input), "-t", "2", "-ar", "48000", "-ac", "2", str(base)], check=True)
    else:
        source_input = base
        source_kind = "deterministic_substitute_for_missing_public_audio_family"
        subprocess.run([ffmpeg, "-v", "error", "-y", "-f", "lavfi", "-i", "aevalsrc=0.18*sin(2*PI*220*t)|0.14*sin(2*PI*440*t):s=48000:d=2", "-ar", "48000", "-ac", "2", str(base)], check=True)
    transforms = {
        "null": "anull", "gain_level_match": "volume=6dB,volume=-6dB", "broad_eq": "equalizer=f=250:t=q:w=0.7:g=3", "narrow_eq": "equalizer=f=2500:t=q:w=10:g=5",
        "compression": "acompressor=threshold=-22dB:ratio=4:attack=20:release=180", "compression_attack_fast": "acompressor=threshold=-22dB:ratio=4:attack=2:release=180", "compression_release_long": "acompressor=threshold=-22dB:ratio=4:attack=20:release=600", "limiting": "alimiter=limit=0.65", "clipping": "acrusher=level_in=2:level_out=0.5:bits=8",
        "saturation_alias_orientation": "asoftclip=type=tanh:threshold=0.7", "reverb": "aecho=0.8:0.55:45|120:0.22|0.16", "delay": "adelay=180|180,volume=0.8",
        "polarity": "aeval=-val(0)|val(1)", "sample_delay": "adelay=1S|0S", "stereo_width": "extrastereo=m=1.5", "timing_stretch": "atempo=1.02",
        # No public stem archive has passed acquisition yet, so this is a
        # deliberately non-masking control rather than a fabricated stem mix.
        "masking_stems_unavailable": "volume=0.9", "vocal_or_arrangement_insufficient_evidence": "anull", "insufficient_evidence": "anull", "contradictory_context": "anull", "no_change": "anull",
    }
    rows = []
    for name, graph in transforms.items():
        output = generated / f"{name}.wav"
        subprocess.run(fixture_command(base, output, graph), check=True)
        rows.append({"id": f"p16.fixture.{name}", "sourceSHA256": sha256(base), "sourceInputSHA256": sha256(source_input), "outputSHA256": sha256(output), "sourceKind": source_kind, "measured": True, "heard": False, "tool": version, "chain": graph, "order": 1, "sampleRate": 48000, "channels": 2, "timeRangeSeconds": [0, 2], "levelMatch": "explicit only for gain_level_match; no perceptual claim", "seed": "p16-controlled-source-v1", "knownManipulation": name, "unknowns": ["source is not a production-quality ground truth", "no subjective quality label"], "confounds": ["one bounded source excerpt", "effects are technical transforms only"], "acceptableAbstention": "Any causal or perceptual conclusion beyond the recorded transform is acceptable."})
    vocal = next((p for p in (root / "extracted" / "pkg016.source.audio.vocalset").rglob("*.wav") if "__MACOSX" not in p.parts and not p.name.startswith("._")), None) if (root / "extracted" / "pkg016.source.audio.vocalset").exists() else None
    stem_groups: dict[pathlib.Path, list[pathlib.Path]] = {}
    for stem in public_candidates:
        stem_groups.setdefault(stem.parent, []).append(stem)
    stems = next((values[:2] for _, values in sorted(stem_groups.items()) if len(values) >= 2), [])
    if vocal:
        output = generated / "vocalset_technical_control.wav"
        subprocess.run(fixture_command(vocal, output, "highpass=f=80,equalizer=f=3000:t=q:w=1:g=1"), check=True)
        rows.append({"id":"p16.fixture.vocalset_technical_control","sourceSHA256":sha256(vocal),"sourceDataset":"VocalSet","outputSHA256":sha256(output),"measured":True,"heard":False,"tool":version,"chain":"highpass=80; EQ 3k +1dB","order":1,"sampleRate":48000,"channels":2,"timeRangeSeconds":[0,2],"levelMatch":"not claimed","seed":"p16-vocalset-v1","knownManipulation":"technical EQ control","unknowns":["no subjective label"],"confounds":["single excerpt"],"acceptableAbstention":"perceptual conclusions may abstain."})
    if len(stems) == 2 and stems[0].parent == stems[1].parent:
        output = generated / "babyslakh_true_stem_masking.wav"
        subprocess.run([ffmpeg,"-v","error","-y","-i",str(stems[0]),"-i",str(stems[1]),"-filter_complex","[0:a][1:a]amix=inputs=2:normalize=0","-t","2","-ar","48000","-ac","2",str(output)], check=True)
        rows.append({"id":"p16.fixture.babyslakh_true_stem_masking","sourceSHA256":sha256(stems[0]),"secondarySourceSHA256":sha256(stems[1]),"sourceDataset":"BabySlakh","sourceRelation":"distinct stems from same track directory","outputSHA256":sha256(output),"measured":True,"heard":False,"tool":version,"chain":"amix two same-track stems","order":1,"sampleRate":48000,"channels":2,"timeRangeSeconds":[0,2],"levelMatch":"not claimed","seed":"p16-babyslakh-stems-v1","knownManipulation":"true stem mixture","unknowns":["instrument labels not inferred"],"confounds":["two-stem excerpt"],"acceptableAbstention":"no subjective masking claim."})
        for row in rows:
            if row["id"] == "p16.fixture.masking_stems_unavailable":
                row["knownManipulation"] = "negative_control_after_true_stem_fixture"
                row["unknowns"] = ["explicit negative control; true-stem fixture is available separately"]
            if row["id"] == "p16.fixture.vocal_or_arrangement_insufficient_evidence":
                row["knownManipulation"] = "negative_control_after_vocalset_fixture"
                row["unknowns"] = ["explicit negative control; VocalSet technical fixture is available separately"]
    path = report(root, "p16-controlled-fixtures.json", {"schemaVersion": "1.0", "fixtures": rows, "deletableCache": True, "publicAudioUsed": bool(public_candidates), "reason": "public BabySlakh stem when available; deterministic substitute only when no public waveform passed acquisition"})
    print(f"P16_CONTROLLED_FIXTURES_OK fixtures={len(rows)} baseSHA256={sha256(base)} report={path}")
    return 0


def provider(root: pathlib.Path) -> int:
    categories = ["no_credential", "rejected", "credential_store_failure", "model_unavailable", "entitlement", "quota", "rate_limit", "timeout", "malformed", "unsupported", "success"]
    # Query only Keychain item presence. stdout/stderr are discarded so a
    # credential can never enter a report, log, command result, or history.
    security = shutil.which("security")
    keychain = subprocess.run([security, "find-generic-password", "-s", "com.marcboyer.tracksmith.provider-credentials", "-a", "openAI"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False) if security else None
    credential_status = "present" if keychain and keychain.returncode == 0 else "missing_or_store_failure"
    text = {"credentialPresence": credential_status, "status": "not_probed", "reason": "no text network health request was made; consent/model/entitlement/quota state remains unobserved"}
    receipt = root / "provider-text-20260815" / "run.json"
    if receipt.is_file():
        try:
            run = json.loads(receipt.read_text(encoding="utf-8"))
            case = (run.get("cases") or [{}])[0]
            provider_info = run.get("provider") or {}
            text = {"credentialPresence": credential_status, "status": "provider_reached_pipeline_rejected", "provider": provider_info.get("identifier"), "model": provider_info.get("modelIdentifier"), "sourceSHA256": case.get("sourceSHA256"), "validationFailureClass": case.get("failure"), "responseTextLogged": False}
        except (OSError, ValueError, TypeError, IndexError):
            text = {"credentialPresence": credential_status, "status": "malformed", "reason": "bounded provider receipt unreadable"}
    value = {"schemaVersion": "1.0", "textProvider": text, "audioProvider": {"status": "not_heard", "reason": "separate audio-consent setting is unset or off; no exact waveform/provider/model response receipt"}, "categories": categories, "credentialValuesLogged": False, "networkAttempted": receipt.is_file(), "heard": False}
    path = report(root, "p16-provider-health.json", value)
    print(f"P16_PROVIDER_REPORT_OK text={text['status']} audio={value['audioProvider']['status']} categories={len(categories)} report={path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache")
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--audit", action="store_true")
    action.add_argument("--smoke", action="store_true")
    action.add_argument("--standard-plan", action="store_true")
    action.add_argument("--standard", action="store_true")
    action.add_argument("--fixtures", action="store_true")
    action.add_argument("--provider-report", action="store_true")
    args = parser.parse_args()
    root = cache_root(args.cache)
    if args.audit: return audit(root)
    if args.smoke: return smoke(root)
    if args.standard_plan: return standard_plan(root)
    if args.standard: return standard(root)
    if args.fixtures: return fixtures(root)
    return provider(root)


if __name__ == "__main__":
    raise SystemExit(main())
