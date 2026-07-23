#!/usr/bin/env python3
"""Build fail-closed ingestion requests for Logic 12.3 Quick Sampler pages.

Apple's current 752-page Instruments PDF names Quick Sampler and links to its
documentation, but the captured PDF payload omits the standalone Quick Sampler
chapter that appears in the live Logic Pro 12.3 web table of contents.  These
requests retain the canonical Apple HTML pages as local-use-only evidence.  An
accepted capture still does not imply deep review; that status is recorded in
the human synthesis only after the page content has actually been read.
"""

from __future__ import annotations

import json
import pathlib


ROOT = pathlib.Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "research/manifests/logic-12.3/quick-sampler"

PAGES = (
    ("lgcp5af33756", "overview", "Quick Sampler overview", "instrument identity, scope, architecture, and Sampler compatibility"),
    ("lgcpc1e3525a", "add-audio", "Add audio to Quick Sampler", "source import, Original and Optimized analysis, recording, replacement, and file-state behavior"),
    ("lgcpabc8c044", "choose-mode", "Choose a Quick Sampler mode", "Classic, One Shot, Slice, and Recorder mode semantics"),
    ("lgcpb1f3f01c", "classic-mode", "Quick Sampler Classic mode", "pitched gated playback, looping, fades, reverse, and Flex behavior"),
    ("lgcp35eefd58", "one-shot-mode", "Quick Sampler One Shot mode", "trigger-to-end playback, reverse, fades, and Flex behavior"),
    ("lgcp18515788", "slice-mode", "Quick Sampler Slice mode", "slice detection, marker mapping, gating, play-to-end, fades, and Flex behavior"),
    ("lgcpa8e3df79", "recorder-mode", "Recorder mode in Quick Sampler", "recording source, trigger, monitoring, threshold, count-in, and captured-sample state"),
    ("lgcp4492eed9", "waveform-display", "Quick Sampler waveform display", "sample-file operations, marker editing, snapping, processing commands, slice export, and destructive-state boundaries"),
    ("lgcpe3d7978d", "flex", "Use Flex in Quick Sampler", "tempo synchronization, pitch-speed decoupling, Follow Tempo, and speed modulation"),
    ("lgcp26511d86", "mod-matrix", "Quick Sampler Mod Matrix pane", "modulation source-target-via routing and bounded modulation behavior"),
    ("lgcpa1ea74f6", "lfo", "Quick Sampler LFO controls", "LFO waveform, rate, sync, fade, phase, key-trigger, mono/poly, and modulation behavior"),
    ("lgcpd22b3634", "pitch", "Quick Sampler Pitch controls", "coarse/fine pitch, glide, pitch envelope, key tracking, and pitch-processing behavior"),
    ("lgcp5c4ed964", "filter", "Quick Sampler Filter controls", "filter drive, cutoff, resonance, key tracking, velocity, and filter-envelope behavior"),
    ("lgcpdd9d92ba", "filter-types", "Quick Sampler filter types", "documented low-pass, high-pass, band-pass, band-reject, ladder, and modeled response families"),
    ("lgcpa9017890", "amp", "Quick Sampler Amp controls", "level, pan, velocity response, and amplifier-envelope behavior"),
    ("lgcp3df3cd4a", "extended", "Quick Sampler extended parameters", "voice allocation, pitch-bend, tuning, MIDI Mono, and extended playback behavior"),
)


def main() -> int:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    expected_names = set()
    for article_id, slug, title, role in PAGES:
        resource_id = f"apple-logic-pro-12.3-quick-sampler-{slug}"
        file_name = f"{resource_id}.json"
        expected_names.add(file_name)
        url = f"https://support.apple.com/guide/logicpro/{article_id}/mac"
        payload = {
            "resourceID": resource_id,
            "title": title,
            "publisherOrAuthors": "Apple Inc.",
            "evidenceRole": f"Canonical Logic Pro 12.3 Quick Sampler documentation for {role}",
            "canonicalURL": url,
            "retrievalURL": url,
            "sourceVersion": "Live Logic Pro for Mac 12.3 guide page captured 2026-07-16",
            "captureMode": "html",
            "expectedMediaTypes": ["text/html"],
            "minimumByteCount": 500_000,
            "minimumPageCount": 1,
            "minimumUsefulTextCharacters": 2_000,
            "requiresExtractableText": True,
            "handlingClass": "internalReference",
            "rightsBasis": "Apple-copyright documentation retained locally for engineering review; no redistribution or model-training rights inferred",
            "licenseStatus": "internalUseOnly",
            "licenseSPDX": None,
            "localUseOnly": True,
            "replacementPolicy": "rejectDifferentPayload",
            "supersedesSHA256": None,
            "replacementReason": None,
            "notes": "Closes a source-payload gap: the immutable 752-page Instruments PDF references Quick Sampler but omits this standalone chapter. Ingestion quality and deep-review status remain separate.",
        }
        (OUTPUT / file_name).write_text(
            json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    unexpected = sorted(
        path.name for path in OUTPUT.glob("*.json") if path.name not in expected_names
    )
    if unexpected:
        raise SystemExit(f"unexpected Quick Sampler manifests: {', '.join(unexpected)}")
    print(f"wrote {len(PAGES)} Quick Sampler ingestion requests to {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
