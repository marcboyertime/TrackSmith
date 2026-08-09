# DSP design

## Signal flow and implementation status

The serialized graph is an ordered acyclic list, bounded to 32 nodes and 32 goals
with rationales no larger than 4 KiB. Current compiler order is exactly
the list order. Implemented: trim/loudness gain, polarity, high-pass, low-pass,
single-band peaking EQ, linked feed-forward-style compressor, linked split-band
de-esser, linked downward expander/gate, tanh saturation/soft clip, mid/side
width, fixed-time feedback delay, bounded Schroeder-style algorithmic room,
zero-lookahead sample-peak limiter, meter no-op, and global finite-sample
sanitation. Deferred node types fail with
`DSPError.unsupportedNode` rather than silently doing nothing.

```text
input → ordered enabled nodes → finite/denormal guard → output
```

The peak limiter is a sample-peak safety module, not a true-peak limiter. Offline
analysis, preview ceiling checks, and fail-closed commit validation use a sample-rate-
aware approximate true-peak measurement: Annex 2 at 48 kHz and a bounded windowed-
sinc approximation at other rates.
Real-time activation also requires the final enabled limiter's sample ceiling to be
no higher than `outputConstraints.maxTruePeakDB`, including the limiter's implicit
-1 dB default. This prevents an obvious structural contradiction, but it does not
make a sample-peak limiter guarantee live inter-sample dBTP compliance.
Compression uses a branching feed-forward peak envelope and supports hard or
quadratic soft-knee gain calculation.
The de-esser uses an exact digital one-pole -3 dB split, calibrates its detector from
the same linked upper-band RMS metric, and applies shared gain to the upper band.

## Parameter ranges

Authoritative ranges are in `PlanValidator.ranges`: gain -60...+24 dB; frequency
10...24 kHz; Q 0.1...20; compressor
threshold -80...0 dBFS; ratio 1...40; attack 0.05...500 ms; release 1...5000 ms;
makeup -24...+24 dB; ceiling -24...0 dBFS; mix 0...1; width 0...2; drive
0...36 dB; delay 1...2000 ms; feedback 0...0.5; damping/crossfeed 0...1;
reverb predelay 0...250 ms, decay 0.1...8 seconds, room size/diffusion 0...1;
expander hold 0...1000 ms, hysteresis 0...24 dB, and range 0...80 dB.
Lookahead is currently constrained to 0 ms. The three production-mastery nodes
require explicit `algorithmVersion = 1`. Each node also has an allow-list of
parameters, and enabled unimplemented node types fail validation. Compilation
rejects sample rates outside 8–192 kHz and frequencies that are not valid for the
active rate rather than silently changing a detector or filter frequency.

The temporal-DSP budget allows at most four delays totaling 4000 ms, two
algorithmic reverbs, and four expanders per plan. At the maximum stereo 192 kHz
format this caps delay storage and the number of per-sample feedback paths; the
ordinary 32-node graph bound still applies.

## Real-time rules

Plan validation and node compilation occur off render. Node/filter/envelope storage
is allocated at compile. Mutable biquad, compressor, expander, and de-esser
mono/stereo state uses fixed scalar fields. Delay, comb, and allpass storage uses
preallocated pointer-backed lines with a valid-sample horizon, so reset is
constant-time and cannot clear a multi-second buffer in the callback. Reverb owns
two unequal feedback-comb paths and one scalar allpass diffusion stage per channel;
the requested predelay is included in each comb-path offset. No topology or buffer
growth occurs during render. State reset is explicit, and a graph generation counter causes a retained
graph to reset before its first block after reactivation. Programmatic output-gain
changes are smoothed over 10 ms. AU immediate and ramp events for output gain apply
at sample offsets, ramps persist across callback boundaries, and the event walk is
bounded to 256 entries per render. A later programmatic write cancels scheduled
ownership while preserving the instantaneous value through the de-zipper. Sample-
accurate events for general graph-node parameters are still open. A C11 atomic
wrapper supports macOS 14 without a third-party dependency,
and startup verifies that every atomic primitive used by the callback is lock-free.
Capture samples use atomic Float32 bit storage; a completed frame count is published
with release ordering and read with acquire ordering. Capture allocation is capped at
24 MiB. Storage reserves one allocation-time `maximumFramesToRender` guard beyond
the user-visible capacity so the largest accepted callback cannot overwrite the
reader's protected interval in a single write. A callback larger than that bound is
rejected without partial capture publication. The reader retries if it is delayed
beyond the guard and fails closed if it cannot obtain a coherent snapshot.

The offline `AudioBuffer` uses Swift arrays and never enters the AU callback. The AU
path processes borrowed noninterleaved Float32 channel pointers. Allocation creates
a distinct preallocated input ABL and owned null-output storage sized from the
allocation-time maximum. The callback resets the input ABL before every upstream
pull, validates channel and byte sizes, copies into the host's original output when
nonnull, and publishes owned pointers when output `mData` is null. This preserves
the output contract even if upstream replaces its pull pointers. Tests prove sample
parity with the offline graph when the same stream is split across irregular host
blocks. The current graph is prepared before `allocateRenderResources` returns;
whole replacement graphs may also be published during active rendering. One graph
pointer/reset snapshot is retained for the complete callback, so publication cannot
split a block between graphs. Lifecycle allocation/deallocation/reset/publication
and off-thread status snapshots are serialized without adding a lock to the render
callback. Host input is sanitized to zero for NaN/infinity before metering, capture,
global bypass, or graph processing; finite global bypass remains sample-exact.

Host reset and bypass have separate timeline semantics. Reset invalidates graph DSP
history and any in-flight scheduled gain ramp at the next block boundary. A bypass
transition invalidates graph history but preserves and advances scheduled gain state
while graph DSP/output trim are skipped, so un-bypass resumes at the correct host
timeline. An upstream `OutputIsSilence` flag causes the preallocated pulled input to
be zeroed. The AU conservatively clears the outgoing flag after processing because
stateful IIR nodes can emit a tail from zero input.

Source inspection and custom-host tests show no explicit dynamic allocation,
blocking lock, filesystem/network/database/log/UI work, or unbounded loop in the
callback after the host pull. A thread-local development interposer covering malloc,
calloc, realloc, free, aligned allocation, and macOS zone entry points observed zero
heap operations across 4,000 complete representative callbacks. This is still not a
formal guarantee that every OS/host/runtime path can never allocate; the measured
interposer run used the production AU class in the custom host, not inside Logic.

## Latency

Current implemented modules, including the fixed-time delay and algorithmic
reverb, have zero inserted lookahead latency; audible repeats and tails are not
latency. A future
lookahead limiter, linear-phase process, denoiser, or convolution must report a
fixed worst-case delay through `AUAudioUnit.latency`; Apple notes that variable
latency is generally not useful to hosts ([latency API](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/latency)). Reverb/delay tails must report `tailTime`.
The current AU reports a static conservative `tailTime` of 180 seconds against a
declared -120 dB amplitude threshold. Hosts may cache this property, and the
maximum-feedback aggregate delay graph or supported low-frequency/high-Q IIR can be
committed after instantiation, so dynamically returning zero for a dry graph would
understate a later graph's tail. A maximum-bound impulse test couples the validator,
DSP decay, and AU declaration. This is a host-scheduling bound, not inserted latency.

## Analysis 1.1

Implemented metrics explicitly avoid false precision:

| Metric | Unit / range | Window | Limitation |
|---|---|---|---|
| sample peak | dBFS / -240...+24 | full interval | separate from true peak |
| true peak | dBTP / -240...+24 | full interval | BS.1770 Annex 2 FIR at 48 kHz; bounded windowed-sinc estimate at other rates, not formally conformance-tested |
| integrated loudness | LUFS / -240...+24 | 400 ms, 75% overlap | two-stage BS.1770 gate; unavailable below one block |
| maximum momentary loudness | LUFS / -240...+24 | 400 ms | not the 3 s short-term measure |
| RMS | dBFS / -240...+24 | full interval | not gated LUFS |
| DC offset | linear / -1...1 | full interval | channel-folded mean |
| clipping samples | count | full interval | misses upstream clipped-but-rescaled audio |
| crest factor | ratio | full interval | sample peak/RMS only |
| centroid, rolloff, flatness, slope, band ratios | typed | 2048 Hann / 1024 hop | averaged mono fold-down; descriptive, not quality diagnoses |
| positive flux and transient density | ratio / events per second | adjacent spectral frames | event type and tempo are not inferred |
| stereo correlation | -1...1 | full interval | zero-lag, not frequency dependent |

Calibrated noise/hum, phoneme/event classifiers, frequency-dependent spatial
analysis, SRMR/YIN, and reference models remain scheduled work. Until implemented,
the UI must not show invented values for them. LRA and typed source-aware evidence
for all six declared source classes are implemented, but their confidence and
failure conditions remain explicit. Band names such as `harshness_band_ratio`
report literal energy ranges and do not claim a perceptual defect.

## Test methodology

The frozen pre-Vocal portable suite at commit `406b446` declares 91 ordinary
checks plus one optional official-vector lane (92 possible when
`TRACKSMITH_BS2217_VECTORS` is enabled). On 2026-08-08 the Debug and Release
ordinary lanes pass 91/91, and an isolated Release/Thread Sanitizer run with the
14 local BS.2217-2 vectors passes 92/92 with no sanitizer report. The earlier
2026-08-02 72/72 ordinary and 73/73 vector-enabled results remain dated
historical evidence for that earlier harness. The added coverage exercises
Short-term Loudness, LRA, source-aware analysis, production-intent hypotheses,
semantic evaluation, immutable research ingestion, mailbox retention,
reply-capacity reservation, strict reply correlation, command sequence/expiry, and
fail-closed message-file quota behavior. The checks cover BS.1770
calibration/gating and multi-rate approximate true-peak estimates, sample-peak
limiter release/reset, gain smoothing reset, soft clipping, bypass identity,
commit-time ceiling/finite safety, stateful-DSP recovery after nonfinite input,
expander hysteresis/hold/range/link/reset, exact delay timing/feedback/crossfeed/
reset, reverb decay/rate/tail/reset, new-node serialization and legacy disabled-
placeholder migration,
44.1/48/88.2/96/192 kHz at 32/64/128/256/512/1024 frames, Float32/PCM24 WAV
round-trips and malformed-rate rejection, known 1 kHz analysis, capture wrap order,
borrowed-pointer/offline parity, dry-on-layout-failure, fail-closed ring snapshots,
exact materialized preview graphs, revision/lock preservation, and BS.1770/RMS
preview matching, final-limiter/declared-peak consistency, bounded IPC retention,
and checked-in JSON Schema parity with the runtime's 32-goal, 32-node and 4,096-byte
UTF-8 rationale limits. The suite also rejects EQ frequencies outside the active
sample rate's stable range and excessive high-band growth under an explicit
harshness constraint.

The expanded `AudioUnitHostProbe` adds AU mono/stereo negotiation, capture/state
restoration, atomic publication/reset stress, two-instance isolation, exact
revision/commit/undo/redo, persisted global bypass, nonfinite bypass sanitation,
capture teardown/reallocation, atomic commit guards, and callback timing. Current
probe cases also cover the expander, delay, and reverb in the representative graph,
native bypass routing, a 180-second static tail with a -120 dB bound, null output
buffers, upstream pointer replacement, maximum-frame validation, output-silence
handling, sample-offset output-gain events, cross-block ramps, reset/bypass timeline
semantics, and one-graph-per-callback publication isolation. The expanded
2026-07-27 Debug and Release probes passed: Debug measured 822.1 us mean and
873.7 us p99; Release measured 16.9 us mean and 18.2 us p99, against a 2,666.7 us
deadline. With the heap interposer loaded, Release measured 16.9 us mean, 17.8 us
p99, and 47.0 us maximum with zero heap operations across 4,000 callbacks. These
are custom-host results, not Logic-load certification.
Required next tests include broad sweep response, fuller expander/reverb/delay
automation and transition campaigns, denormal timing, fuzzed plans, golden hashes
with tolerances, broader heap/VM instrumentation, and deadline distributions under
release Logic load.
