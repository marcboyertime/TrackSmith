# Real-time safety and boundaries

All size and performance statements below are shard-backed status summaries, not TrackSmith measurements. “Estimate/unknown” must be measured at a future pinned configuration; it is never a performance promise. Each candidate has exactly one conservative primary boundary.

| # | repository | size status; CPU/memory/latency; sample-rate/frame assumptions | allocation/thread-safety and render suitability | network/local audio; replay | primary boundary |
|---:|---|---|---|---|---|
| 1 | AudioKit | unknown; graph-dependent; offline default max 4096 frames | no package-wide allocation/thread guarantee; no | no declared network; local APIs; partial only | external test dependency |
| 2 | basic-pitch | models ~1.9 MB; two-second 22.05 kHz mono windows | NumPy/runtime allocation; no | local files but training/demo may network; fixture-hash only | research-only directory |
| 3 | NeuralNote | unknown; deferred/long latency model workflow | JUCE/model state; no | local only if controlled; conditional replay | research-only directory |
| 4 | RNNoise | unknown; fixed 48 kHz speech frame baseline | model state requires symbol-level proof; no now | local/no intended network; conditional fixed-config replay | research-only directory |
| 5 | noise-suppression-for-voice | unknown; retroactive VAD adds latency | plugin/model/JUCE behavior; no | local processing possible; not product replay | research-only directory |
| 6 | DDSP | unknown; TensorFlow variable inference | Python/model allocations; no | local research only; hash configuration | research-only directory |
| 7 | webMUSHRA | no native binary; 256–16384 WebAudio buffers | DOM/WebAudio/PHP; no | server/result endpoint possible; browser seed/env needed | research-only directory |
| 8 | akouste | no native binary; browser-content dependent | DOM/localStorage/Math.random; no | optionally local, remote examples possible; no seed contract | research-only directory |
| 9 | pluginval | host tool, not AU payload | validator/JUCE host; never render dependency | external executable; log/environment hashes | external test dependency |
| 10 | chowdsp_utils | no selected binary; processor-specific, e.g. 48 kHz/512 example | mixed modules; only independently authored fixed-capacity path after proof | no inherent DSP network; record exact parameters | AU render thread |
| 11 | JUCE | framework size unknown; host/module dependent | mixed locks/UI/pools; no framework import/render use | optional network modules; host/config hash required | research-only directory |
| 12 | iPlug2 | framework size unknown; processor-specific | framework not a TrackSmith RT contract; no import | no required network; independent test only | external test dependency |
| 13 | Essentia | size/cost varies by algorithm/models | C++/Python algorithms no AU callback proof | local/offline comparison only; pin env/input | research-only directory |
| 14 | librosa | external Python environment, unknown distribution size | NumPy/SciPy/Numba/cache behavior; no | downloads/examples must be disabled; fixture/env hash | offline CLI |
| 15 | madmom | Python/Cython/model footprint unknown; 44.1 kHz online helper | Python objects/workers/pickles; no | ffmpeg may be invoked; fixed single-worker replay only | research-only directory |
| 16 | Demucs | PyTorch/weights large; ~1.5x track CPU, 3–7 GB GPU guidance; 44.1 kHz | tensors/download/split/random shifts; no | remote first-model fetch; local pre-provision only, conditional replay | research-only directory |

## TrackSmith non-negotiable rules

- Preserve the native SwiftPM macOS/AUv3 architecture. Do not rewrite around JUCE, Python, Electron, iPlug2, or AudioKit.
- AU render work is deterministic, bounded DSP only. No model inference, network, file I/O, allocation, blocking, locks, dynamic graph work, provider call, or arbitrary provider-selected DSP/code is allowed in the render callback.
- Use App Group IPC only for typed, versioned, instance/runtime/capture-bound messages. Providers have bounded proposal authority; TrackSmith validates typed plans and retains control of DSP, files, AU state, and commits.
- Preserve sources: capture identity and hashes, immutable snapshots, preview/revision/explicit commit, locks, stale-result protection, and exact rollback are mandatory. A mismatch, stale snapshot, changed format, or deallocated AU fails closed.
- For any future selected integration, capture input/source/output/code/runtime/model hashes (where applicable), sample rate, channels, frames, seed, state/reset, parameters, and environment. Prove deterministic replay, save/reload, offline/realtime parity where applicable, no-allocation callback behavior, sanitizer/TSAN coverage, source preservation, rollback, and stale-result rejection.
- User audio remains local in TrackSmith storage/App Group unless a separately approved typed workflow says otherwise. Any external tool uses explicitly selected copied input, no uploads, no raw-provider authority, and a provenance record.

The `AU render thread` designation for chowdsp_utils is not an approval to link that repository: it records the shard's eventual target boundary for a newly authored, one-algorithm, cleared, fixed-capacity native translation. Every other primary boundary is deliberately outside real-time rendering.
