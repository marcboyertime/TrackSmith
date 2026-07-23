#!/usr/bin/env python3
"""Analyze a Logic-native render against its deterministic source fixture.

This tool deliberately uses only the Python standard library so the empirical
lane does not depend on an unrecorded scientific-Python environment.  It is not
a perceptual-quality scorer.  It reports file identity, PCM identity, format,
level, sample-aligned error, least-squares gain, polarity/correlation, and a
bounded latency estimate.  Those measurements support reproducible claims
about a documented Logic test state; they do not establish artistic quality or
identify Apple's private implementation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import wave
from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class WavePayload:
    path: pathlib.Path
    channels: int
    sample_rate: int
    sample_width_bytes: int
    frame_count: int
    compression_type: str
    pcm_bytes: bytes
    samples: tuple[int, ...]

    @property
    def bit_depth(self) -> int:
        return self.sample_width_bytes * 8

    @property
    def duration_seconds(self) -> float:
        return self.frame_count / self.sample_rate


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def decode_pcm(payload: bytes, sample_width: int) -> tuple[int, ...]:
    if sample_width == 1:
        # WAVE 8-bit PCM is unsigned.
        return tuple(value - 128 for value in payload)
    if sample_width == 2:
        return tuple(
            int.from_bytes(payload[offset : offset + 2], "little", signed=True)
            for offset in range(0, len(payload), 2)
        )
    if sample_width == 3:
        decoded: list[int] = []
        for offset in range(0, len(payload), 3):
            value = (
                payload[offset]
                | (payload[offset + 1] << 8)
                | (payload[offset + 2] << 16)
            )
            if value & 0x800000:
                value -= 1 << 24
            decoded.append(value)
        return tuple(decoded)
    if sample_width == 4:
        return tuple(
            int.from_bytes(payload[offset : offset + 4], "little", signed=True)
            for offset in range(0, len(payload), 4)
        )
    raise ValueError(f"unsupported PCM sample width: {sample_width} bytes")


def read_wave(path: pathlib.Path) -> WavePayload:
    with wave.open(str(path), "rb") as handle:
        channels = handle.getnchannels()
        sample_rate = handle.getframerate()
        sample_width = handle.getsampwidth()
        frame_count = handle.getnframes()
        compression_type = handle.getcomptype()
        if compression_type != "NONE":
            raise ValueError(
                f"{path}: only uncompressed PCM is supported, got {compression_type}"
            )
        pcm_bytes = handle.readframes(frame_count)
    expected_bytes = frame_count * channels * sample_width
    if len(pcm_bytes) != expected_bytes:
        raise ValueError(
            f"{path}: partial PCM payload ({len(pcm_bytes)} != {expected_bytes})"
        )
    return WavePayload(
        path=path,
        channels=channels,
        sample_rate=sample_rate,
        sample_width_bytes=sample_width,
        frame_count=frame_count,
        compression_type=compression_type,
        pcm_bytes=pcm_bytes,
        samples=decode_pcm(pcm_bytes, sample_width),
    )


def dbfs(amplitude: float, full_scale: float) -> float | None:
    if amplitude <= 0:
        return None
    return 20.0 * math.log10(amplitude / full_scale)


def channel_samples(payload: WavePayload, channel_index: int) -> tuple[int, ...]:
    return payload.samples[channel_index :: payload.channels]


def summarize_channel(samples: Iterable[int], bit_depth: int) -> dict[str, object]:
    values = tuple(samples)
    count = len(values)
    full_scale = float(1 << (bit_depth - 1))
    peak = max((abs(value) for value in values), default=0)
    sum_squares = sum(value * value for value in values)
    rms = math.sqrt(sum_squares / count) if count else 0.0
    mean = (sum(values) / count) if count else 0.0
    nonzero_indices = tuple(
        index for index, value in enumerate(values) if value != 0
    )
    return {
        "sample_count": count,
        "peak_integer": peak,
        "peak_dbfs": dbfs(float(peak), full_scale),
        "rms_dbfs": dbfs(rms, full_scale),
        "dc_offset_normalized": mean / full_scale,
        "nonzero_sample_count": len(nonzero_indices),
        "first_nonzero_sample": nonzero_indices[0] if nonzero_indices else None,
        "last_nonzero_sample": nonzero_indices[-1] if nonzero_indices else None,
    }


def summarize_wave(payload: WavePayload) -> dict[str, object]:
    return {
        "path": str(payload.path),
        "file_sha256": sha256_file(payload.path),
        "pcm_sha256": sha256_bytes(payload.pcm_bytes),
        "channels": payload.channels,
        "sample_rate_hz": payload.sample_rate,
        "bit_depth": payload.bit_depth,
        "frame_count": payload.frame_count,
        "duration_seconds": payload.duration_seconds,
        "compression_type": payload.compression_type,
        "channel_metrics": [
            summarize_channel(channel_samples(payload, channel), payload.bit_depth)
            for channel in range(payload.channels)
        ],
    }


def normalized_correlation(left: tuple[int, ...], right: tuple[int, ...]) -> float | None:
    if not left or len(left) != len(right):
        return None
    sum_left_sq = sum(value * value for value in left)
    sum_right_sq = sum(value * value for value in right)
    if sum_left_sq == 0 or sum_right_sq == 0:
        return None
    dot = sum(a * b for a, b in zip(left, right))
    return dot / math.sqrt(sum_left_sq * sum_right_sq)


def bounded_lag_estimate(
    source: tuple[int, ...],
    rendered: tuple[int, ...],
    max_lag_frames: int,
    sample_budget: int = 20_000,
) -> dict[str, float | int | None]:
    if not source or not rendered or max_lag_frames < 0:
        return {"lag_frames": None, "correlation": None, "analysis_stride": None}
    common = min(len(source), len(rendered))
    stride = max(1, common // sample_budget)
    best_lag = 0
    best_correlation: float | None = None
    for lag in range(-max_lag_frames, max_lag_frames + 1):
        source_start = max(0, -lag)
        rendered_start = max(0, lag)
        available = min(
            len(source) - source_start,
            len(rendered) - rendered_start,
        )
        if available <= 0:
            continue
        source_slice = source[source_start : source_start + available : stride]
        rendered_slice = rendered[
            rendered_start : rendered_start + available : stride
        ]
        correlation = normalized_correlation(source_slice, rendered_slice)
        if correlation is None:
            continue
        if best_correlation is None or abs(correlation) > abs(best_correlation):
            best_lag = lag
            best_correlation = correlation
    return {
        "lag_frames": best_lag if best_correlation is not None else None,
        "correlation": best_correlation,
        "analysis_stride": stride,
    }


def compare_channel(
    source: tuple[int, ...],
    rendered: tuple[int, ...],
    bit_depth: int,
    max_lag_frames: int,
) -> dict[str, object]:
    count = min(len(source), len(rendered))
    left = source[:count]
    right = rendered[:count]
    full_scale = float(1 << (bit_depth - 1))
    differences = tuple(b - a for a, b in zip(left, right))
    differing_indices = tuple(
        index for index, difference in enumerate(differences) if difference != 0
    )
    error_sum_squares = sum(value * value for value in differences)
    error_rms = math.sqrt(error_sum_squares / count) if count else 0.0
    source_sum_squares = sum(value * value for value in left)
    dot = sum(a * b for a, b in zip(left, right))
    least_squares_gain = (
        dot / source_sum_squares if source_sum_squares != 0 else None
    )
    gain_db = (
        20.0 * math.log10(abs(least_squares_gain))
        if least_squares_gain not in (None, 0.0)
        else None
    )
    return {
        "compared_sample_count": count,
        "sample_count_match": len(source) == len(rendered),
        "sample_exact": left == right and len(source) == len(rendered),
        "zero_lag_correlation": normalized_correlation(left, right),
        "least_squares_gain": least_squares_gain,
        "least_squares_gain_db": gain_db,
        "polarity": (
            "inverted"
            if least_squares_gain is not None and least_squares_gain < 0
            else "noninverted"
        ),
        "max_absolute_error_integer": max(
            (abs(value) for value in differences), default=0
        ),
        "differing_sample_count": len(differing_indices),
        "first_differing_sample": (
            differing_indices[0] if differing_indices else None
        ),
        "last_differing_sample": (
            differing_indices[-1] if differing_indices else None
        ),
        "absolute_error_threshold_counts": {
            str(threshold): sum(
                1 for value in differences if abs(value) >= threshold
            )
            for threshold in (1, 16, 256, 1024)
        },
        "rms_error_dbfs": dbfs(error_rms, full_scale),
        "mean_error_normalized": (
            (sum(differences) / count) / full_scale if count else 0.0
        ),
        "bounded_lag_estimate": bounded_lag_estimate(
            left, right, max_lag_frames
        ),
    }


def compare_waves(
    source: WavePayload,
    rendered: WavePayload,
    max_lag_frames: int,
) -> dict[str, object]:
    format_match = (
        source.channels == rendered.channels
        and source.sample_rate == rendered.sample_rate
        and source.sample_width_bytes == rendered.sample_width_bytes
    )
    result: dict[str, object] = {
        "format_match": format_match,
        "frame_count_match": source.frame_count == rendered.frame_count,
        "pcm_byte_exact": source.pcm_bytes == rendered.pcm_bytes,
    }
    if not format_match:
        result["channel_comparisons"] = []
        result["comparison_unavailable_reason"] = "channel/sample-rate/bit-depth mismatch"
        return result
    result["channel_comparisons"] = [
        compare_channel(
            channel_samples(source, channel),
            channel_samples(rendered, channel),
            source.bit_depth,
            max_lag_frames,
        )
        for channel in range(source.channels)
    ]
    return result


def amplitude_ladder_transfer(
    source: WavePayload,
    rendered: WavePayload,
    levels_dbfs: tuple[float, ...],
    segment_seconds: float,
    edge_exclusion_seconds: float,
) -> dict[str, object]:
    """Measure each steady portion of the deterministic 1 kHz level ladder.

    Whole-file least-squares gain is intentionally insufficient for processors
    that clip, gate, compress, or otherwise change behavior with input level.
    This view keeps the input-level regimes separate.  It is still an objective
    signal measurement, not a perceptual score or a private-algorithm claim.
    """

    if source.channels != 1 or rendered.channels != 1:
        raise ValueError("amplitude-ladder analysis requires mono files")
    if source.sample_rate != rendered.sample_rate:
        raise ValueError("amplitude-ladder analysis requires matching sample rates")
    if source.sample_width_bytes != rendered.sample_width_bytes:
        raise ValueError("amplitude-ladder analysis requires matching bit depths")
    segment_frames = round(segment_seconds * source.sample_rate)
    edge_frames = round(edge_exclusion_seconds * source.sample_rate)
    if segment_frames <= 0 or edge_frames < 0 or edge_frames * 2 >= segment_frames:
        raise ValueError("invalid amplitude-ladder segment/edge duration")
    required_frames = segment_frames * len(levels_dbfs)
    if source.frame_count != required_frames or rendered.frame_count != required_frames:
        raise ValueError(
            "amplitude-ladder files do not match the declared segment layout "
            f"({source.frame_count}, {rendered.frame_count} != {required_frames})"
        )

    source_samples = channel_samples(source, 0)
    rendered_samples = channel_samples(rendered, 0)
    full_scale = float(1 << (source.bit_depth - 1))
    segments: list[dict[str, object]] = []
    for index, input_level in enumerate(levels_dbfs):
        segment_start = index * segment_frames
        start = segment_start + edge_frames
        end = segment_start + segment_frames - edge_frames
        left = source_samples[start:end]
        right = rendered_samples[start:end]
        source_sum_squares = sum(value * value for value in left)
        rendered_sum_squares = sum(value * value for value in right)
        dot = sum(a * b for a, b in zip(left, right))
        gain = dot / source_sum_squares if source_sum_squares else None
        gain_db = (
            20.0 * math.log10(abs(gain))
            if gain not in (None, 0.0)
            else None
        )
        source_rms = math.sqrt(source_sum_squares / len(left)) if left else 0.0
        rendered_rms = (
            math.sqrt(rendered_sum_squares / len(right)) if right else 0.0
        )
        clipped = sum(1 for value in right if abs(value) >= full_scale - 1)
        segments.append(
            {
                "segment_index": index,
                "declared_input_peak_dbfs": input_level,
                "analyzed_start_frame": start,
                "analyzed_end_frame_exclusive": end,
                "source_rms_dbfs": dbfs(source_rms, full_scale),
                "rendered_rms_dbfs": dbfs(rendered_rms, full_scale),
                "least_squares_gain_db": gain_db,
                "zero_lag_correlation": normalized_correlation(left, right),
                "rendered_peak_dbfs": dbfs(
                    float(max((abs(value) for value in right), default=0)),
                    full_scale,
                ),
                "clipped_sample_count": clipped,
                "clipped_sample_fraction": clipped / len(right) if right else 0.0,
            }
        )
    return {
        "fixture_assumption": "deterministic 1 kHz amplitude ladder",
        "declared_levels_dbfs": list(levels_dbfs),
        "segment_seconds": segment_seconds,
        "edge_exclusion_seconds": edge_exclusion_seconds,
        "analysis_boundary": (
            "Separates steady input-level regimes; does not identify a private "
            "transfer function or establish perceptual quality."
        ),
        "segments": segments,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("rendered", type=pathlib.Path)
    parser.add_argument(
        "--max-lag-frames",
        type=int,
        default=128,
        help="bounded absolute lag searched per channel (default: 128)",
    )
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument(
        "--amplitude-ladder",
        action="store_true",
        help=(
            "add segment-aware analysis for TrackSmith's deterministic 1 kHz "
            "amplitude ladder"
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.max_lag_frames < 0 or args.max_lag_frames > 8192:
        raise SystemExit("--max-lag-frames must be in 0...8192")
    source = read_wave(args.source.resolve())
    rendered = read_wave(args.rendered.resolve())
    report = {
        "schema_version": 2,
        "scope": "logic_native_empirical_render_comparison",
        "claim_boundary": (
            "Objective file/signal comparison only; no perceptual superiority or "
            "private-implementation claim."
        ),
        "source": summarize_wave(source),
        "rendered": summarize_wave(rendered),
        "comparison": compare_waves(source, rendered, args.max_lag_frames),
    }
    if args.amplitude_ladder:
        report["amplitude_ladder_transfer"] = amplitude_ladder_transfer(
            source,
            rendered,
            (-60.0, -48.0, -36.0, -30.0, -24.0, -18.0, -12.0, -6.0, -3.0, -1.0),
            segment_seconds=0.8,
            edge_exclusion_seconds=0.05,
        )
    serialized = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(serialized, encoding="utf-8")
    print(serialized, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
