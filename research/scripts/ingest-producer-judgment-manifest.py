#!/usr/bin/env python3
"""Ingest the TrackSmith producer-judgment paper manifest safely and reproducibly."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = (
    REPO_ROOT
    / "TrackSmith_Producer_Judgment_Expansion"
    / "04_manifest"
    / "source_manifest.csv"
)
DEFAULT_ARCHIVE = REPO_ROOT / "research" / "papers" / "tracksmith-producer-judgment-archive"
RESULTS_PATH = DEFAULT_MANIFEST.parent / "ingestion_results.json"


SOURCE_METADATA = {
    "2309.03404": {
        "version": "v3",
        "authors": "Soumya Sai Vanka; Maryam Safi; Jean-Baptiste Rolland; Gyorgy Fazekas",
        "folder": "01_professional_intent",
        "filename": "01_2309.03404_communication_and_reference_songs.pdf",
    },
    "2507.06329": {
        "version": "v1",
        "authors": "Michael Clemens; Ana Marasovic",
        "folder": "01_professional_intent",
        "filename": "02_2507.06329_mixassist.pdf",
    },
    "2605.29931": {
        "version": "v1",
        "authors": "Finn McClellan; Fabio Morreale",
        "folder": "03_quality_and_workflow",
        "filename": "03_2605.29931_ai_workflow_speed_and_agency.pdf",
    },
    "2202.08898": {
        "version": "v2",
        "authors": "Satvik Venkatesh; David Moffat; Eduardo Reck Miranda",
        "folder": "02_semantic_language",
        "filename": "04_2202.08898_word_embeddings_for_automatic_eq.pdf",
    },
    "2602.12301": {
        "version": "v1",
        "authors": "Marion Baranes; Romain Hennequin; Elena V. Epure",
        "folder": "02_semantic_language",
        "filename": "05_2602.12301_preference_bearing_intent.pdf",
    },
    "2602.17769": {
        "version": "v1",
        "authors": (
            "Rebecca Salganik; Teng Tu; Fei-Yueh Chen; Xiaohao Liu; Keifeng Lu; "
            "Ethan Luvisia; Zhiyao Duan; Guillaume Salha-Galvan; Anson Kahng; "
            "Yunshan Ma; Jian Kang"
        ),
        "folder": "02_semantic_language",
        "filename": "06_2602.17769_musicsem.pdf",
    },
    "2603.16682": {
        "version": "v1",
        "authors": "Joseph Cameron; Alan Blackwell",
        "folder": "02_semantic_language",
        "filename": "07_2603.16682_semantic_timbre_electric_guitar.pdf",
    },
    "2412.03373": {
        "version": "v1",
        "authors": "Angeliki Mourgela; Elio Quinton; Spyridon Bissas; Joshua D. Reiss; David Ronan",
        "folder": "03_quality_and_workflow",
        "filename": "08_2412.03373_audio_mix_and_master_trends.pdf",
    },
    "1803.11154": {
        "version": "v1",
        "authors": "David Ronan; Joshua D. Reiss; Hatice Gunes",
        "folder": "03_quality_and_workflow",
        "filename": "09_1803.11154_emotion_and_production_quality.pdf",
    },
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def arxiv_id(pdf_url: str) -> str:
    stem = pdf_url.removesuffix(".pdf").rstrip("/").rsplit("/", 1)[-1]
    if stem not in SOURCE_METADATA:
        raise ValueError(f"unrecognized arXiv PDF URL: {pdf_url}")
    return stem


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    required = {"priority", "category", "title", "year", "url", "pdf_url", "key_value"}
    if not rows or set(rows[0]) != required:
        raise ValueError(f"manifest columns must be exactly {sorted(required)}")
    priorities = [int(row["priority"]) for row in rows]
    if priorities != list(range(1, len(rows) + 1)):
        raise ValueError("manifest priorities must be contiguous and ordered from 1")
    ids = [arxiv_id(row["pdf_url"]) for row in rows]
    if len(rows) != len(SOURCE_METADATA) or set(ids) != set(SOURCE_METADATA):
        raise ValueError("manifest rows do not match the reviewed source metadata set")
    return rows


def build_request(row: dict[str, str], identifier: str) -> dict[str, object]:
    metadata = SOURCE_METADATA[identifier]
    return {
        "resourceID": f"arxiv-{identifier.replace('.', '-')}",
        "title": row["title"],
        "publisherOrAuthors": metadata["authors"],
        "evidenceRole": row["key_value"],
        "canonicalURL": row["url"],
        "retrievalURL": row["pdf_url"],
        "sourceVersion": f"arXiv:{identifier}{metadata['version']}",
        "captureMode": "pdf",
        "expectedMediaTypes": ["application/pdf"],
        "minimumByteCount": 10_000,
        "minimumPageCount": 2,
        "minimumUsefulTextCharacters": 500,
        "requiresExtractableText": True,
        "handlingClass": "internalReference",
        "rightsBasis": (
            "Publicly accessible arXiv author manuscript retained as an internal research "
            "reference; redistribution and model-training rights are not inferred."
        ),
        "licenseStatus": "internalUseOnly",
        "localUseOnly": True,
        "replacementPolicy": "rejectDifferentPayload",
        "notes": (
            f"Producer Judgment Expansion priority {row['priority']}; category {row['category']}. "
            f"Manifest value: {row['key_value']}"
        ),
    }


def run() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--archive-root", type=Path, default=DEFAULT_ARCHIVE)
    arguments = parser.parse_args()

    rows = load_rows(arguments.manifest.resolve())
    subprocess.run(
        ["swift", "build", "--product", "ResearchIngestCLI"],
        cwd=REPO_ROOT,
        check=True,
    )
    bin_path = subprocess.run(
        ["swift", "build", "--show-bin-path"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    cli = Path(bin_path) / "ResearchIngestCLI"

    records: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="tracksmith-producer-judgment-") as temp:
        temp_root = Path(temp)
        for row in rows:
            identifier = arxiv_id(row["pdf_url"])
            metadata = SOURCE_METADATA[identifier]
            request = build_request(row, identifier)
            request_path = temp_root / f"{request['resourceID']}.json"
            request_path.write_text(
                json.dumps(request, indent=2, ensure_ascii=True) + "\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [str(cli), "fetch", str(request_path), str(arguments.archive_root)],
                cwd=REPO_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            record = json.loads(result.stdout)
            if record["captureStatus"] not in {"accepted", "duplicate"}:
                raise RuntimeError(f"{identifier}: unexpected capture status {record['captureStatus']}")
            if record["qualityStatus"] != "validated" or not record.get("localPath"):
                raise RuntimeError(f"{identifier}: capture was not validated and published")

            object_path = arguments.archive_root / str(record["localPath"])
            destination = arguments.manifest.parents[1] / str(metadata["folder"]) / str(metadata["filename"])
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists():
                if sha256_file(destination) != record["sha256"]:
                    raise RuntimeError(f"refusing to overwrite changed destination: {destination}")
            else:
                shutil.copy2(object_path, destination)
            if sha256_file(destination) != record["sha256"]:
                raise RuntimeError(f"categorized copy hash mismatch: {destination}")

            records.append(
                {
                    "priority": int(row["priority"]),
                    "category": row["category"],
                    "resource_id": record["resourceID"],
                    "source_version": record["sourceVersion"],
                    "title": record["title"],
                    "authors": record["publisherOrAuthors"],
                    "canonical_url": record["canonicalURL"],
                    "retrieval_url": record["retrievalURL"],
                    "retrieved_at_utc": record["retrievedAtUTC"],
                    "capture_status": record["captureStatus"],
                    "quality_status": record["qualityStatus"],
                    "byte_count": record["byteCount"],
                    "sha256": record["sha256"],
                    "archive_object": str((arguments.archive_root / str(record["localPath"])).relative_to(REPO_ROOT)),
                    "categorized_copy": str(destination.relative_to(REPO_ROOT)),
                    "handling_class": record["handlingClass"],
                    "local_use_only": record["localUseOnly"],
                    "quality_findings": record["qualityFindings"],
                }
            )

    temporary_results = RESULTS_PATH.with_suffix(".json.tmp")
    temporary_results.write_text(
        json.dumps({"manifest_version": "1.0", "resources": records}, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )
    temporary_results.replace(RESULTS_PATH)
    print(f"Ingested {len(records)} resources; results: {RESULTS_PATH.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
