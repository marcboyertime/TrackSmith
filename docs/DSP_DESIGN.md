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

The peak limiter is a sample-peak safety module, not a true-peak limiter. Offline
analysis and preview ceiling checks use an ITU-R BS.1770-5 true-peak estimate.
Compression uses a branching feed-forward peak envelope and supports hard or
quadratic soft-knee gain calculation.

## Parameter ranges

Authoritative ranges are in `PlanValidator.ranges`: gain -60...+24 dB; frequency
10...24 kHz (clamped below Nyquist during compilation); Q 0.1...20; compressor
threshold -80...0 dBFS; ratio 1...40; attack 0.05...500 ms; release 1...5000 ms;
makeup -24...+24 dB; ceiling -24...0 dBFS; mix 0...1; width 0...2; drive
0...36 dB; lookahead is currently constrained to 0 ms. Each node also has an allow-
list of parameters, and enabled unimplemented node types fail validation.

## Real-time rules

Plan validation and node compilation occur off render. Node/filter/envelope storage
is allocated at compile. State reset is explicit. Scalar changes require smoothing
or sample-accurate event handling. A C11 atomic wrapper supports macOS 14 without a
third-party dependency. Capture samples use atomic Float32 bit storage; a completed
frame count is published with release ordering and read with acquire ordering. The
storage reserves 8,192 guard frames beyond the user-visible capacity so an analysis
copy can proceed while the producer advances; the reader retries if it is delayed
beyond that guard.

The offline `AudioBuffer` uses Swift arrays and never enters the AU callback. The AU
path processes borrowed noninterleaved Float32 channel pointers in place. Tests prove
sample parity with the offline graph when the same stream is split across irregular
host blocks. The current graph is prepared before `allocateRenderResources` returns;
whole-graph publication during active rendering remains intentionally unsupported.

## Latency

Current implemented modules have zero declared algorithmic latency. A future
lookahead limiter, linear-phase process, denoiser, or convolution must report a
fixed worst-case delay through `AUAudioUnit.latency`; Apple notes that variable
latency is generally not useful to hosts ([latency API](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/latency)). Reverb/delay tails must report `tailTime`.

## Analysis 1.1

Implemented metrics explicitly avoid false precision:

| Metric | Unit / range | Window | Limitation |
|---|---|---|---|
| sample peak | dBFS / -240...+24 | full interval | separate from true peak |
| true peak | dBTP / -240...+24 | full interval | BS.1770 Annex 2 FIR; normative coefficient set is 48 kHz |
| integrated loudness | LUFS / -240...+24 | 400 ms, 75% overlap | two-stage BS.1770 gate; unavailable below one block |
| maximum momentary loudness | LUFS / -240...+24 | 400 ms | not the 3 s short-term measure |
| RMS | dBFS / -240...+24 | full interval | not gated LUFS |
| DC offset | linear / -1...1 | full interval | channel-folded mean |
| clipping samples | count | full interval | misses upstream clipped-but-rescaled audio |
| crest factor | ratio | full interval | sample peak/RMS only |
| centroid, rolloff, flatness, slope, band ratios | typed | 2048 Hann / 1024 hop | averaged mono fold-down; descriptive, not quality diagnoses |
| positive flux and transient density | ratio / events per second | adjacent spectral frames | event type and tempo are not inferred |
| stereo correlation | -1...1 | full interval | zero-lag, not frequency dependent |

LRA, calibrated noise/hum, source-aware vocal/drum, spatial-band, SRMR/YIN, and
reference models remain scheduled work. Until implemented, the UI must not show
invented values for them. Band names such as `harshness_band_ratio` report literal
energy ranges and explicitly do not claim a perceptual defect.

## Test methodology

Release tests cover BS.1770 calibration/gating/true peak, bypass identity,
ceiling/finite safety, 44.1/48/88.2/96/192 kHz
at 32/64/128/256/512/1024 frames, Float32 WAV round-trip, known 1 kHz sine peak/RMS/
centroid, capture wrap order, borrowed-pointer/offline parity, dry-on-layout-failure,
AU mono/stereo format negotiation, AU capture/state restoration, and BS.1770/RMS preview matching. Required next tests include
impulse/sweep frequency response, compressor static/time curves, automation ramps,
denormal timing, channel independence, fuzzed plans, golden hashes with tolerances,
and callback deadline distributions under release host load.
