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
import statistics
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


def summarize_stereo_relationships(payload: WavePayload) -> dict[str, object]:
    """Report objective L/R relationships without assigning perceptual value."""

    if payload.channels != 2:
        raise ValueError("stereo relationship analysis requires exactly two channels")
    left = channel_samples(payload, 0)
    right = channel_samples(payload, 1)
    sums = tuple(a + b for a, b in zip(left, right))
    differences = tuple(a - b for a, b in zip(left, right))
    full_scale = float(1 << (payload.bit_depth - 1))
    mono_sum_peak = max((abs(value) for value in sums), default=0)
    side_difference_peak = max(
        (abs(value) for value in differences), default=0
    )
    return {
        "sample_count": len(left),
        "left_right_sample_exact": left == right,
        "left_right_inverted_exact": all(
            a == -b for a, b in zip(left, right)
        ),
        "left_right_inverted_within_one_integer_count": all(
            abs(value) <= 1 for value in sums
        ),
        "zero_lag_correlation": normalized_correlation(left, right),
        "mono_sum_peak_integer": mono_sum_peak,
        "mono_sum_peak_dbfs_per_channel_full_scale": dbfs(
            float(mono_sum_peak), full_scale
        ),
        "mono_sum_nonzero_sample_count": sum(
            1 for value in sums if value != 0
        ),
        "side_difference_peak_integer": side_difference_peak,
        "side_difference_peak_dbfs_per_channel_full_scale": dbfs(
            float(side_difference_peak), full_scale
        ),
        "side_difference_nonzero_sample_count": sum(
            1 for value in differences if value != 0
        ),
        "analysis_boundary": (
            "Objective inter-channel identity, polarity, correlation, mono-sum, "
            "and side-difference measurements only; no width, compatibility, "
            "or perceptual-quality conclusion."
        ),
    }


def summarize_wave(payload: WavePayload) -> dict[str, object]:
    summary = {
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
    if payload.channels == 2:
        summary["stereo_relationships"] = summarize_stereo_relationships(payload)
    return summary


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
    sample_format_match = (
        source.sample_rate == rendered.sample_rate
        and source.sample_width_bytes == rendered.sample_width_bytes
    )
    channel_count_match = source.channels == rendered.channels
    format_match = channel_count_match and sample_format_match
    result: dict[str, object] = {
        "format_match": format_match,
        "sample_rate_and_bit_depth_match": sample_format_match,
        "channel_count_match": channel_count_match,
        "frame_count_match": source.frame_count == rendered.frame_count,
        "pcm_byte_exact": (
            source.pcm_bytes == rendered.pcm_bytes if format_match else False
        ),
    }
    if not sample_format_match:
        result["channel_comparisons"] = []
        result["channel_mapping"] = []
        result["comparison_unavailable_reason"] = "sample-rate/bit-depth mismatch"
        return result
    if channel_count_match:
        channel_mapping = tuple(
            (channel, channel) for channel in range(source.channels)
        )
    elif source.channels == 1:
        channel_mapping = tuple(
            (0, rendered_channel)
            for rendered_channel in range(rendered.channels)
        )
    else:
        result["channel_comparisons"] = []
        result["channel_mapping"] = []
        result["comparison_unavailable_reason"] = (
            "unsupported channel mapping; only matching channel counts or "
            "mono-source broadcast comparisons are supported"
        )
        return result
    result["channel_mapping"] = [
        {
            "source_channel_index": source_channel,
            "rendered_channel_index": rendered_channel,
        }
        for source_channel, rendered_channel in channel_mapping
    ]
    result["channel_comparisons"] = []
    for source_channel, rendered_channel in channel_mapping:
        result["channel_comparisons"].append(
            compare_channel(
                channel_samples(source, source_channel),
                channel_samples(rendered, rendered_channel),
                source.bit_depth,
                max_lag_frames,
            )
        )
    result["source_broadcast_pcm_exact"] = (
        source.channels == 1
        and source.frame_count == rendered.frame_count
        and all(
            comparison["sample_exact"]
            for comparison in result["channel_comparisons"]
        )
    )
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

    if source.channels != 1:
        raise ValueError("amplitude-ladder analysis requires a mono source")
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
    full_scale = float(1 << (source.bit_depth - 1))
    def analyze_rendered_channel(channel_index: int) -> list[dict[str, object]]:
        rendered_samples = channel_samples(rendered, channel_index)
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
            source_rms = (
                math.sqrt(source_sum_squares / len(left)) if left else 0.0
            )
            rendered_rms = (
                math.sqrt(rendered_sum_squares / len(right)) if right else 0.0
            )
            clipped = sum(
                1 for value in right if abs(value) >= full_scale - 1
            )
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
                    "clipped_sample_fraction": (
                        clipped / len(right) if right else 0.0
                    ),
                }
            )
        return segments

    result = {
        "fixture_assumption": "deterministic 1 kHz amplitude ladder",
        "declared_levels_dbfs": list(levels_dbfs),
        "segment_seconds": segment_seconds,
        "edge_exclusion_seconds": edge_exclusion_seconds,
        "analysis_boundary": (
            "Separates steady input-level regimes; does not identify a private "
            "transfer function or establish perceptual quality."
        ),
    }
    if rendered.channels == 1:
        result["segments"] = analyze_rendered_channel(0)
    else:
        result["channels"] = [
            {
                "rendered_channel_index": channel_index,
                "segments": analyze_rendered_channel(channel_index),
            }
            for channel_index in range(rendered.channels)
        ]
    return result


def compressor_ballistics_transfer(
    source: WavePayload,
    rendered: WavePayload,
    *,
    stereo_link_probe: bool = False,
) -> dict[str, object]:
    """Measure gain settling on TrackSmith's deterministic 1 kHz level steps."""

    if stereo_link_probe:
        if source.channels != 2 or rendered.channels != 2:
            raise ValueError(
                "compressor stereo-link analysis requires stereo source and render"
            )
    elif source.channels != 1:
        raise ValueError("compressor-ballistics analysis requires a mono source")
    if source.sample_rate != rendered.sample_rate:
        raise ValueError("compressor-ballistics analysis requires matching sample rates")
    if source.sample_width_bytes != rendered.sample_width_bytes:
        raise ValueError("compressor-ballistics analysis requires matching bit depths")
    levels_dbfs = (-30.0, -6.0, -30.0, -6.0, -30.0, -6.0, -30.0)
    segment_frames = source.sample_rate
    required_frames = segment_frames * len(levels_dbfs)
    if source.frame_count != required_frames or rendered.frame_count != required_frames:
        raise ValueError(
            "compressor-ballistics files do not match the declared seven-second "
            f"layout ({source.frame_count}, {rendered.frame_count} != {required_frames})"
        )
    window_frames = round(source.sample_rate * 0.010)
    if window_frames <= 0 or segment_frames % window_frames != 0:
        raise ValueError(
            "compressor-ballistics analysis requires an integer count of 10 ms "
            "windows per one-second segment"
        )
    driver_levels_dbfs = levels_dbfs

    def window_rms(values: tuple[int, ...], start: int, end: int) -> float:
        count = end - start
        return (
            math.sqrt(sum(value * value for value in values[start:end]) / count)
            if count > 0
            else 0.0
        )

    def settling_time(gains: list[float], target: float) -> float | None:
        tolerance_db = 0.5
        for index in range(len(gains)):
            if all(
                abs(value - target) <= tolerance_db
                for value in gains[index:]
            ):
                return index * 10.0
        return None

    channels: list[dict[str, object]] = []
    for channel_index in range(rendered.channels):
        source_channel_index = channel_index if stereo_link_probe else 0
        source_values = channel_samples(source, source_channel_index)
        source_levels_dbfs = (
            levels_dbfs
            if not stereo_link_probe or channel_index == 0
            else tuple(-30.0 for _ in levels_dbfs)
        )
        rendered_values = channel_samples(rendered, channel_index)
        segments: list[dict[str, object]] = []
        segment_gains: list[list[float]] = []
        for segment_index, level_dbfs in enumerate(source_levels_dbfs):
            segment_start = segment_index * segment_frames
            gains: list[float] = []
            source_rms_values: list[float] = []
            rendered_rms_values: list[float] = []
            for window_start in range(
                segment_start,
                segment_start + segment_frames,
                window_frames,
            ):
                window_end = window_start + window_frames
                source_rms = window_rms(source_values, window_start, window_end)
                rendered_rms = window_rms(
                    rendered_values, window_start, window_end
                )
                if source_rms <= 0.0 or rendered_rms <= 0.0:
                    raise ValueError(
                        "compressor-ballistics analysis encountered a zero-RMS "
                        "window in the declared active-tone fixture"
                    )
                source_rms_values.append(source_rms)
                rendered_rms_values.append(rendered_rms)
                gains.append(20.0 * math.log10(rendered_rms / source_rms))
            segment_gains.append(gains)
            steady_gain = statistics.median(gains[-20:])
            sample_indices = (0, 1, 2, 4, 9, 19, 49, 89)
            segments.append(
                {
                    "segment_index": segment_index,
                    "declared_source_peak_dbfs": level_dbfs,
                    "window_count": len(gains),
                    "initial_10ms_gain_db": gains[0],
                    "steady_last_200ms_median_gain_db": steady_gain,
                    "minimum_window_gain_db": min(gains),
                    "maximum_window_gain_db": max(gains),
                    "settling_time_ms_within_0_5_db_for_remaining_segment": (
                        settling_time(gains, steady_gain)
                    ),
                    "sampled_gain_db": [
                        {
                            "time_after_segment_start_ms": (
                                index * 10.0 + 5.0
                            ),
                            "gain_db": gains[index],
                        }
                        for index in sample_indices
                    ],
                    "source_rms_dbfs_first_window": dbfs(
                        source_rms_values[0],
                        float(1 << (source.bit_depth - 1)),
                    ),
                    "rendered_rms_dbfs_first_window": dbfs(
                        rendered_rms_values[0],
                        float(1 << (rendered.bit_depth - 1)),
                    ),
                }
            )
        transitions = []
        for segment_index in range(1, len(driver_levels_dbfs)):
            gains = segment_gains[segment_index]
            target = statistics.median(gains[-20:])
            transitions.append(
                {
                    "transition_index": segment_index - 1,
                    "transition_at_seconds": float(segment_index),
                    "kind": (
                        "attack"
                        if driver_levels_dbfs[segment_index]
                        > driver_levels_dbfs[segment_index - 1]
                        else "release"
                    ),
                    "from_source_peak_dbfs": source_levels_dbfs[segment_index - 1],
                    "to_source_peak_dbfs": source_levels_dbfs[segment_index],
                    "from_driver_peak_dbfs": driver_levels_dbfs[segment_index - 1],
                    "to_driver_peak_dbfs": driver_levels_dbfs[segment_index],
                    "initial_10ms_gain_db": gains[0],
                    "steady_last_200ms_median_gain_db": target,
                    "settling_time_ms_within_0_5_db_for_remaining_segment": (
                        settling_time(gains, target)
                    ),
                    "maximum_absolute_deviation_from_steady_db": max(
                        abs(value - target) for value in gains
                    ),
                }
            )
        channels.append(
            {
                "source_channel_index": source_channel_index,
                "rendered_channel_index": channel_index,
                "segments": segments,
                "transitions": transitions,
            }
        )
    return {
        "fixture_assumption": (
            (
                "deterministic continuous-phase 1 kHz stereo link probe; "
                "left driver alternates -30 and -6 dBFS while right remains "
                "-30 dBFS"
            )
            if stereo_link_probe
            else (
                "deterministic continuous-phase 1 kHz mono tone with seven "
                "one-second peak-level segments alternating -30 and -6 dBFS"
            )
        ),
        "window_duration_ms": 10.0,
        "steady_estimate": "median gain over the final 200 ms of each segment",
        "settling_tolerance_db": 0.5,
        "analysis_boundary": (
            "Objective windowed gain settling for the exact recorded state only; "
            "does not identify a private detector or smoothing topology and does "
            "not establish musical usefulness."
        ),
        "channels": channels,
    }


def deesser_transfer(
    source: WavePayload,
    rendered: WavePayload,
    probe_kind: str,
) -> dict[str, object]:
    """Measure exact-frequency gain for TrackSmith's DeEsser 2 probe suite."""

    if source.sample_rate != rendered.sample_rate:
        raise ValueError("DeEsser analysis requires matching sample rates")
    if source.sample_width_bytes != rendered.sample_width_bytes:
        raise ValueError("DeEsser analysis requires matching bit depths")
    if source.channels != rendered.channels and not (
        source.channels == 1 and rendered.channels == 2
    ):
        raise ValueError(
            "DeEsser analysis requires matching channels or mono-source "
            "broadcast to stereo"
        )
    if probe_kind in {"level", "event"} and (
        source.channels != 1 or rendered.channels not in {1, 2}
    ):
        raise ValueError(f"DeEsser {probe_kind} probe requires mono files")
    if probe_kind == "stereo" and (
        source.channels != 2 or rendered.channels != 2
    ):
        raise ValueError("DeEsser stereo probe requires stereo files")
    required_frames = source.sample_rate * 6
    if source.frame_count != required_frames or rendered.frame_count != required_frames:
        raise ValueError(
            "DeEsser probe files do not match the declared six-second layout "
            f"({source.frame_count}, {rendered.frame_count} != {required_frames})"
        )

    frequencies = (500.0, 7_000.0)
    full_scale = float(1 << (source.bit_depth - 1))

    def tone_amplitude(
        values: tuple[int, ...],
        frequency: float,
        start: int,
        end: int,
    ) -> float:
        count = end - start
        if count <= 0:
            raise ValueError("DeEsser analysis window must contain samples")
        cosine = 0.0
        sine = 0.0
        angular = 2.0 * math.pi * frequency / source.sample_rate
        for frame in range(start, end):
            value = values[frame]
            phase = angular * frame
            cosine += value * math.cos(phase)
            sine += value * math.sin(phase)
        return 2.0 * math.hypot(cosine, sine) / count

    def tone_record(
        source_values: tuple[int, ...],
        rendered_values: tuple[int, ...],
        frequency: float,
        start: int,
        end: int,
    ) -> dict[str, object]:
        source_amplitude = tone_amplitude(source_values, frequency, start, end)
        rendered_amplitude = tone_amplitude(
            rendered_values, frequency, start, end
        )
        gain = (
            20.0 * math.log10(rendered_amplitude / source_amplitude)
            if source_amplitude > full_scale * 0.00001
            and rendered_amplitude > 0.0
            else None
        )
        return {
            "frequency_hz": frequency,
            "source_amplitude_dbfs": dbfs(source_amplitude, full_scale),
            "rendered_amplitude_dbfs": dbfs(rendered_amplitude, full_scale),
            "gain_db": gain,
        }

    if probe_kind == "level":
        segment_names = (
            "quiet_base_only",
            "quiet_same_ratio_high_minus_18",
            "loud_base_only",
            "loud_same_ratio_high_minus_6",
            "loud_static_high_minus_24",
            "loud_strong_high_minus_6_repeat",
        )
        declared_base_levels = (-30.0, -30.0, -18.0, -18.0, -18.0, -18.0)
        declared_high_levels = (None, -18.0, None, -6.0, -24.0, -6.0)
        channels: list[dict[str, object]] = []
        source_values = channel_samples(source, 0)
        for rendered_channel_index in range(rendered.channels):
            rendered_values = channel_samples(rendered, rendered_channel_index)
            segments: list[dict[str, object]] = []
            for index, name in enumerate(segment_names):
                start = (
                    index * source.sample_rate + round(0.2 * source.sample_rate)
                )
                end = (
                    index * source.sample_rate + round(0.8 * source.sample_rate)
                )
                segments.append(
                    {
                        "segment_index": index,
                        "name": name,
                        "declared_base_peak_dbfs": declared_base_levels[index],
                        "declared_high_peak_dbfs": declared_high_levels[index],
                        "analysis_window_seconds_within_segment": [0.2, 0.8],
                        "tones": [
                            tone_record(
                                source_values,
                                rendered_values,
                                frequency,
                                start,
                                end,
                            )
                            for frequency in frequencies
                        ],
                    }
                )
            channels.append(
                {
                    "source_channel_index": 0,
                    "rendered_channel_index": rendered_channel_index,
                    "segments": segments,
                }
            )
        return {
            "fixture_assumption": (
                "TrackSmith deterministic six-segment 500 Hz plus 7 kHz "
                "DeEsser level/mode probe"
            ),
            "probe_kind": probe_kind,
            "channels": channels,
            "analysis_boundary": (
                "Exact-tone steady-window measurements only. Same-ratio "
                "quiet/loud pairs can expose bounded level dependence, but "
                "they do not identify detector internals or musical quality."
            ),
        }

    segment_names = (
        "base_only",
        "event_high_minus_6",
        "static_high_minus_24",
        "event_high_minus_12",
        "static_high_minus_12",
        "event_high_minus_6_repeat",
    )
    window_frames = round(source.sample_rate * 0.010)
    if window_frames <= 0 or source.sample_rate % window_frames != 0:
        raise ValueError(
            "DeEsser event analysis requires an integer count of 10 ms windows"
        )
    windows_per_segment = source.sample_rate // window_frames
    channels: list[dict[str, object]] = []
    for rendered_channel_index in range(rendered.channels):
        source_channel_index = (
            rendered_channel_index if source.channels == 2 else 0
        )
        source_values = channel_samples(source, source_channel_index)
        rendered_values = channel_samples(rendered, rendered_channel_index)
        segments: list[dict[str, object]] = []
        for segment_index, name in enumerate(segment_names):
            base_gains: list[float] = []
            high_gains: list[float] = []
            sampled_windows: list[dict[str, object]] = []
            for window_index in range(windows_per_segment):
                start = (
                    segment_index * source.sample_rate
                    + window_index * window_frames
                )
                end = start + window_frames
                base = tone_record(
                    source_values,
                    rendered_values,
                    frequencies[0],
                    start,
                    end,
                )
                high = tone_record(
                    source_values,
                    rendered_values,
                    frequencies[1],
                    start,
                    end,
                )
                if base["gain_db"] is not None:
                    base_gains.append(float(base["gain_db"]))
                if high["gain_db"] is not None:
                    high_gains.append(float(high["gain_db"]))
                if 35 <= window_index <= 57:
                    sampled_windows.append(
                        {
                            "window_index": window_index,
                            "center_time_seconds_within_segment": (
                                window_index * 0.010 + 0.005
                            ),
                            "base_500hz_gain_db": base["gain_db"],
                            "high_7000hz_gain_db": high["gain_db"],
                        }
                    )
            event_base_gains = [
                float(item["base_500hz_gain_db"])
                for item in sampled_windows
                if 40 <= int(item["window_index"]) <= 51
                and item["base_500hz_gain_db"] is not None
            ]
            non_event_base_gains = [
                float(item["base_500hz_gain_db"])
                for item in sampled_windows
                if 35 <= int(item["window_index"]) <= 39
                and item["base_500hz_gain_db"] is not None
            ]
            segments.append(
                {
                    "segment_index": segment_index,
                    "name": name,
                    "base_500hz_gain_db_median": statistics.median(base_gains),
                    "base_500hz_gain_db_minimum": min(base_gains),
                    "base_500hz_gain_db_maximum": max(base_gains),
                    "high_7000hz_active_window_count": len(high_gains),
                    "high_7000hz_gain_db_median": (
                        statistics.median(high_gains) if high_gains else None
                    ),
                    "high_7000hz_gain_db_minimum": (
                        min(high_gains) if high_gains else None
                    ),
                    "high_7000hz_gain_db_maximum": (
                        max(high_gains) if high_gains else None
                    ),
                    "event_window_base_gain_db_median": (
                        statistics.median(event_base_gains)
                        if event_base_gains
                        else None
                    ),
                    "pre_event_window_base_gain_db_median": (
                        statistics.median(non_event_base_gains)
                        if non_event_base_gains
                        else None
                    ),
                    "sampled_10ms_windows": sampled_windows,
                }
            )
        channels.append(
            {
                "source_channel_index": source_channel_index,
                "rendered_channel_index": rendered_channel_index,
                "segments": segments,
            }
        )
    return {
        "fixture_assumption": (
            "TrackSmith deterministic six-segment 500 Hz base plus short/static "
            "7 kHz DeEsser event probe"
        ),
        "probe_kind": probe_kind,
        "event_window_seconds_within_segment": [0.40, 0.52],
        "window_seconds": 0.010,
        "channels": channels,
        "analysis_boundary": (
            "Exact-tone 10 ms window measurements only. These synthetic events "
            "are not speech or consonants and cannot establish intelligibility, "
            "air, breath, lisp avoidance, or musical usefulness."
        ),
    }


def goertzel_dft(samples: tuple[int, ...], frequency_hz: float, sample_rate: int) -> complex:
    """Return one DFT bin at an arbitrary frequency using bounded constant state."""

    if not samples:
        return 0j
    omega = 2.0 * math.pi * frequency_hz / sample_rate
    cosine = math.cos(omega)
    sine = math.sin(omega)
    coefficient = 2.0 * cosine
    previous = 0.0
    previous_previous = 0.0
    for sample in samples:
        current = float(sample) + coefficient * previous - previous_previous
        previous_previous = previous
        previous = current
    recurrence_output = complex(
        previous - previous_previous * cosine,
        previous_previous * sine,
    )
    # The standard recurrence output carries e^(j*w*(N-1)); remove that
    # length-dependent rotation so phase is referenced to sample zero even for
    # arbitrary frequencies that are not integer FFT bins.
    rotation = -omega * (len(samples) - 1)
    return recurrence_output * complex(math.cos(rotation), math.sin(rotation))


def unwrap_phases(phases: list[float]) -> list[float]:
    if not phases:
        return []
    unwrapped = [phases[0]]
    for phase in phases[1:]:
        adjusted = phase
        while adjusted - unwrapped[-1] > math.pi:
            adjusted -= 2.0 * math.pi
        while adjusted - unwrapped[-1] < -math.pi:
            adjusted += 2.0 * math.pi
        unwrapped.append(adjusted)
    return unwrapped


def impulse_response_transfer(
    source: WavePayload,
    rendered: WavePayload,
) -> dict[str, object]:
    """Measure a rendered response to TrackSmith's single-impulse fixture.

    The response is anchored to the source impulse frame, so reported phase
    retains any plug-in delay.  This is a sampled transfer observation for the
    exact recorded state, not an identification of a private filter topology.
    """

    if source.channels != 1:
        raise ValueError("impulse-response analysis requires a mono source")
    if source.sample_rate != rendered.sample_rate:
        raise ValueError("impulse-response analysis requires matching sample rates")
    if source.sample_width_bytes != rendered.sample_width_bytes:
        raise ValueError("impulse-response analysis requires matching bit depths")
    source_values = channel_samples(source, 0)
    source_nonzero = [
        index for index, value in enumerate(source_values) if value != 0
    ]
    if len(source_nonzero) != 1:
        raise ValueError(
            "impulse-response analysis requires exactly one nonzero source sample"
        )
    impulse_frame = source_nonzero[0]
    impulse_amplitude = source_values[impulse_frame]
    if impulse_amplitude == 0:
        raise ValueError("source impulse amplitude must be nonzero")

    requested_frequencies = (
        20.0,
        31.5,
        40.0,
        50.0,
        63.0,
        80.0,
        100.0,
        125.0,
        160.0,
        200.0,
        250.0,
        315.0,
        400.0,
        500.0,
        630.0,
        800.0,
        1_000.0,
        1_250.0,
        1_600.0,
        2_000.0,
        2_500.0,
        3_150.0,
        4_000.0,
        5_000.0,
        6_300.0,
        8_000.0,
        10_000.0,
        12_500.0,
        16_000.0,
        20_000.0,
    )
    frequencies = tuple(
        frequency
        for frequency in requested_frequencies
        if frequency < source.sample_rate / 2.0
    )
    full_scale = float(1 << (source.bit_depth - 1))
    channels: list[dict[str, object]] = []
    for channel_index in range(rendered.channels):
        values = channel_samples(rendered, channel_index)
        pre_impulse_nonzero = sum(
            1 for value in values[:impulse_frame] if value != 0
        )
        post_impulse = values[impulse_frame:]
        nonzero = [
            index for index, value in enumerate(post_impulse) if value != 0
        ]
        if nonzero:
            first_nonzero = nonzero[0]
            last_nonzero = nonzero[-1]
            response = post_impulse[: last_nonzero + 1]
            peak_offset = max(
                range(len(response)),
                key=lambda index: abs(response[index]),
            )
            peak = abs(response[peak_offset])
        else:
            first_nonzero = None
            last_nonzero = None
            response = ()
            peak_offset = None
            peak = 0

        points: list[dict[str, object]] = []
        wrapped_phases: list[float] = []
        for frequency in frequencies:
            transfer = (
                goertzel_dft(response, frequency, source.sample_rate)
                / impulse_amplitude
                if response
                else 0j
            )
            magnitude = abs(transfer)
            phase = math.atan2(transfer.imag, transfer.real)
            wrapped_phases.append(phase)
            points.append(
                {
                    "frequency_hz": frequency,
                    "magnitude_linear": magnitude,
                    "magnitude_db": (
                        20.0 * math.log10(magnitude)
                        if magnitude > 0.0
                        else None
                    ),
                    "wrapped_phase_degrees": math.degrees(phase),
                }
            )
        unwrapped = unwrap_phases(wrapped_phases)
        for index, point in enumerate(points):
            point["unwrapped_phase_degrees"] = math.degrees(unwrapped[index])
            if index == 0:
                point["group_delay_frames_from_previous_point"] = None
                point["group_delay_seconds_from_previous_point"] = None
                continue
            previous_omega = (
                2.0 * math.pi * frequencies[index - 1] / source.sample_rate
            )
            current_omega = 2.0 * math.pi * frequencies[index] / source.sample_rate
            group_delay_frames = -(
                unwrapped[index] - unwrapped[index - 1]
            ) / (current_omega - previous_omega)
            point["group_delay_frames_from_previous_point"] = group_delay_frames
            point["group_delay_seconds_from_previous_point"] = (
                group_delay_frames / source.sample_rate
            )
        channels.append(
            {
                "rendered_channel_index": channel_index,
                "pre_impulse_nonzero_sample_count": pre_impulse_nonzero,
                "first_nonzero_frame_relative_to_source_impulse": first_nonzero,
                "last_nonzero_frame_relative_to_source_impulse": last_nonzero,
                "tail_seconds_after_source_impulse": (
                    last_nonzero / source.sample_rate
                    if last_nonzero is not None
                    else None
                ),
                "peak_frame_relative_to_source_impulse": peak_offset,
                "peak_dbfs": dbfs(float(peak), full_scale),
                "frequency_points": points,
            }
        )
    return {
        "fixture_assumption": "deterministic mono single-impulse fixture",
        "source_impulse_frame": impulse_frame,
        "source_impulse_amplitude_integer": impulse_amplitude,
        "source_impulse_peak_dbfs": dbfs(
            float(abs(impulse_amplitude)), full_scale
        ),
        "phase_reference": (
            "Source impulse frame is time zero; plug-in delay remains in phase."
        ),
        "phase_convention": (
            "Goertzel DFT phase; adjacent-point group delay is a coarse sampled "
            "estimate and is unreliable near deep response nulls."
        ),
        "analysis_boundary": (
            "Objective response of the exact recorded state only; does not "
            "identify Apple's private topology or establish musical usefulness."
        ),
        "channels": channels,
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
    parser.add_argument(
        "--impulse-response",
        action="store_true",
        help=(
            "add magnitude, phase, coarse group-delay, latency, and tail "
            "analysis for TrackSmith's deterministic single-impulse fixture"
        ),
    )
    parser.add_argument(
        "--compressor-ballistics",
        action="store_true",
        help=(
            "add 10 ms gain-settling analysis for TrackSmith's deterministic "
            "seven-segment Compressor level-step fixture"
        ),
    )
    parser.add_argument(
        "--compressor-stereo-link-probe",
        action="store_true",
        help=(
            "add 10 ms per-channel gain-settling analysis for TrackSmith's "
            "asymmetric seven-segment Compressor stereo-link fixture"
        ),
    )
    parser.add_argument(
        "--deesser-probe",
        choices=("level", "event", "stereo"),
        help=(
            "add exact-tone analysis for the corresponding TrackSmith "
            "DeEsser 2 level, mono-event, or stereo-event probe"
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
        "schema_version": 4,
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
    if args.impulse_response:
        report["impulse_response_transfer"] = impulse_response_transfer(
            source,
            rendered,
        )
    advanced_modes = sum(
        [
            bool(args.compressor_ballistics),
            bool(args.compressor_stereo_link_probe),
            args.deesser_probe is not None,
        ]
    )
    if advanced_modes > 1:
        raise SystemExit(
            "--compressor-ballistics, --compressor-stereo-link-probe, and "
            "--deesser-probe are mutually exclusive"
        )
    if args.compressor_ballistics:
        report["compressor_ballistics_transfer"] = compressor_ballistics_transfer(
            source,
            rendered,
        )
    if args.compressor_stereo_link_probe:
        report["compressor_stereo_link_transfer"] = compressor_ballistics_transfer(
            source,
            rendered,
            stereo_link_probe=True,
        )
    if args.deesser_probe:
        report["deesser_transfer"] = deesser_transfer(
            source,
            rendered,
            args.deesser_probe,
        )
    serialized = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(serialized, encoding="utf-8")
    print(serialized, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
