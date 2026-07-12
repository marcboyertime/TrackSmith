# DSP design

## Signal flow and implementation status

The serialized graph is an ordered acyclic list. Current compiler order is exactly
the list order. Implemented: trim/loudness gain, polarity, high-pass, low-pass,
single-band peaking EQ, linked feed-forward-style compressor, tanh saturation/soft
clip, mid/side width, zero-lookahead peak limiter, meter no-op, and global finite
sample sanitation. Deferred node types fail with `DSPError.unsupportedNode` rather
than silently doing nothing.

```text
input → ordered enabled nodes → finite/denormal guard → output
```

The peak limiter is a sample-peak safety module, not a true-peak limiter. The
compressor currently uses hard-knee gain calculation even though the schema reserves
`kneeDB`; this parameter is validated/serialized but not yet applied. These gaps are
called out so the UI cannot mislabel the current result.

## Parameter ranges

Authoritative ranges are in `PlanValidator.ranges`: gain -60...+24 dB; frequency
10...24 kHz (clamped below Nyquist during compilation); Q 0.1...20; compressor
threshold -80...0 dBFS; ratio 1...40; attack 0.05...500 ms; release 1...5000 ms;
makeup -24...+24 dB; ceiling -24...0 dBFS; mix 0...1; width 0...2; drive
0...36 dB; lookahead 0...20 ms. Each node also has an allow-list of parameters.

## Real-time rules

Plan validation and node compilation occur off render. Node/filter/envelope storage
is allocated at compile. State reset is explicit. Scalar changes require smoothing
or sample-accurate event handling. A C11 atomic wrapper supports macOS 14 without a
third-party dependency. The capture producer writes to preallocated raw memory and
publishes the completed frame count with release ordering; the non-real-time reader
loads with acquire ordering and allocates the immutable snapshot.

The offline `AudioBuffer` uses Swift arrays and is not itself the AU host-buffer
adapter. Production AU wiring must operate on borrowed channel pointers, prepare
capture per host format, avoid Swift copy-on-write, and atomically exchange whole
compiled graphs only outside active use.

## Latency

Current implemented modules have zero declared algorithmic latency. A future
lookahead limiter, linear-phase process, denoiser, or convolution must report a
fixed worst-case delay through `AUAudioUnit.latency`; Apple notes that variable
latency is generally not useful to hosts ([latency API](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/latency)). Reverb/delay tails must report `tailTime`.

## Analysis 1.0

Implemented metrics explicitly avoid false precision:

| Metric | Unit / range | Window | Limitation |
|---|---|---|---|
| sample peak | dBFS / -240...+24 | full interval | not oversampled true peak |
| RMS | dBFS / -240...+24 | full interval | not gated LUFS |
| DC offset | linear / -1...1 | full interval | channel-folded mean |
| clipping samples | count | full interval | misses upstream clipped-but-rescaled audio |
| crest factor | ratio | full interval | sample peak/RMS only |
| centroid and low/mid/high ratios | Hz / ratios | first max 2048 frames, Hann | one mono-folded DFT, not time varying |
| stereo correlation | -1...1 | full interval | zero-lag, not frequency dependent |

True peak, EBU R128 loudness, LRA, noise-floor/hum, transient, source-aware, spatial
band, and reference models remain scheduled work. Until implemented, the UI must
not show invented values for them.

## Test methodology

Release tests cover bypass identity, ceiling/finite safety, 44.1/48/88.2/96/192 kHz
at 32/64/128/256/512/1024 frames, Float32 WAV round-trip, known 1 kHz sine peak/RMS/
centroid, capture wrap order, and preview level matching. Required next tests include
impulse/sweep frequency response, compressor static/time curves, automation ramps,
denormal timing, channel independence, fuzzed plans, golden hashes with tolerances,
and callback deadline distributions under release host load.
