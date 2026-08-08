# TrackSmith open-source audio audit — synthesis

**Audit date:** 2026-08-08. This decision record synthesizes the three immutable, pinned-tree audit shards: [01–06](REPOSITORIES_01_06.md), [07–11](REPOSITORIES_07_11.md), and [12–16](REPOSITORIES_12_16.md). It is not legal advice, a license grant, or an approval to integrate. Pins, evidence paths, and factual detail remain in the linked shard entries. “Unresolved” means **not cleared**: absence of a discovered restriction is not legal, patent, content, model, data, dependency, or commercial-shipping clearance.

No dependency, model, code, sample, checkpoint, or repository output is approved as production-ready. No third-party code, model, asset, or dependency was copied into, retained in, vendored to, executed as part of, or integrated into TrackSmith; temporary inspection clones were used only to inspect pinned trees. The companion reports are [decisions CSV](REPOSITORY_DECISIONS.csv), [license/dependency risk](LICENSE_AND_DEPENDENCY_RISK.md), [real-time safety and boundaries](REALTIME_SAFETY_AND_BOUNDARIES.md), and [gated implementation slices](IMPLEMENTATION_SLICES.md).

Classification is exactly the shard classification; no shard classification was changed. Rank is the capability priority for the next safe, TrackSmith-owned action after all gates—not repository quality, permission to reuse, or permission to ship.

| rank | repository | pin/release | primary language | top-level license | exact classification | smallest useful capability | proposed boundary | recommendation/rationale |
|---:|---|---|---|---|---|---|---|---|
| 1 | [basic-pitch](REPOSITORIES_01_06.md#02-basic-pitch) | `fa5997a` | Python/setuptools | Apache-2.0 | STUDY_ONLY | Offline non-authoritative audio-to-MIDI candidate fixture | research-only directory | Python/ML runtime plus unclear weights/data prevent embedding; build only TrackSmith-owned mock adapter first. |
| 2 | [RNNoise](REPOSITORIES_01_06.md#04-rnnoise) | `70f1d25` | C/Autotools | BSD-3-Clause-style | STUDY_ONLY | Speech-only 48 kHz denoising research baseline | research-only directory | Model/training-data rights and real-time proof remain unresolved; never treat as music denoising. |
| 3 | [webMUSHRA](REPOSITORIES_07_11.md#07-webmushra) | `8c353f7` | JavaScript/PHP | custom Fraunhofer | LICENSE_BLOCKED | Independently authored blinded-study protocol | research-only directory | Source-delivery/patent/asset obligations preclude closed-source embedding. |
| 4 | [akouste](REPOSITORIES_07_11.md#08-akouste) | `ef5130b` | HTML/CSS/JavaScript | AGPL-3.0 | LICENSE_BLOCKED | Local blinded-listening export/integrity ideas | research-only directory | AGPL and unclear example assets block product reuse. |
| 5 | [librosa](REPOSITORIES_12_16.md#14-librosa) | `44947d` (`1.0.0rc0`) | Python/setuptools | ISC | SAFE_AS_OFFLINE_TOOL | Auditable reference analysis fixtures | offline CLI | Keep outside product/runtime; use only to validate independently authored native analysis. |
| 6 | [pluginval](REPOSITORIES_07_11.md#09-pluginval) | `4c5adc2` | C++/CMake/JUCE | GPL-3.0 | LICENSE_BLOCKED | Disposable external AU regression observation | external test dependency | GPL tool may inform independent tests; it is never a TrackSmith dependency. |
| 7 | [chowdsp_utils](REPOSITORIES_07_11.md#10-chowdsp_utils) | `e97b826` | C++/CMake/JUCE modules | mixed per-module/GPL | SAFE_TO_PORT_SELECTIVELY | Independent fixed-capacity utility specification | AU render thread | Only an independently authored, selected permissive algorithm after closure and RT proof; never GPL/JUCE import. |
| 8 | [AudioKit](REPOSITORIES_01_06.md#01-audiokit) | `c358c15` | Swift/SwiftPM | MIT | SAFE_TO_PORT_SELECTIVELY | Independently author one small MIDI/file convenience | external test dependency | Study a narrowly scoped, notice-gated utility; retain TrackSmith AUv3 ownership. |
| 9 | [iPlug2](REPOSITORIES_12_16.md#12-iplug2) | `5c2df9d` | C++/CMake | zlib-style | SAFE_TO_PORT_SELECTIVELY | Independent simple DSP reference test | external test dependency | Study one bounded utility only; do not import another plug-in framework. |
| 10 | [NeuralNote](REPOSITORIES_01_06.md#03-neuralnote) | `f979e51` | C++/CMake/JUCE | Apache-2.0 | STUDY_ONLY | Document deferred audio-to-MIDI behavior | research-only directory | JUCE/model/runtime and long-latency constraints conflict with native architecture. |
| 11 | [DDSP](REPOSITORIES_01_06.md#06-ddsp) | `cf5e62d` | Python/setuptools/TensorFlow | Apache-2.0 | STUDY_ONLY | Controlled harmonic/noise synthesis concepts | research-only directory | Treat model/data rights and Python inference as un-cleared; provider cannot control DSP. |
| 12 | [Essentia](REPOSITORIES_12_16.md#13-essentia) | `b9fa6cb` | C++/Python/Waf | AGPL-3.0-only | LICENSE_BLOCKED | Offline descriptor comparison | research-only directory | AGPL, submodule, model/data, and dependency closure require separate rights. |
| 13 | [madmom](REPOSITORIES_12_16.md#15-madmom) | `27f032e` | Python/Cython/setuptools | BSD-like code; CC BY-NC-SA data/models | STUDY_ONLY | Noncommercial algorithm-behavior comparison | research-only directory | Noncommercial model/data and unclosed dependencies prohibit shipping/derivation. |
| 14 | [Demucs](REPOSITORIES_12_16.md#16-demucs) | `e976d93` | Python/setuptools/PyTorch | MIT | STUDY_ONLY | Separation-plan UX/provenance benchmark | research-only directory | Remote unclear weights/data, large variable runtime, and unmaintained state rule out embedding. |
| 15 | [JUCE](REPOSITORIES_07_11.md#11-juce) | `7dda739` | C/C++/CMake | AGPL-3.0 or commercial | LICENSE_BLOCKED | AU host-edge-case test scenarios | research-only directory | No commercial license was supplied; framework migration is outside settled SwiftPM/AUv3 architecture. |
| 16 | [noise-suppression-for-voice](REPOSITORIES_01_06.md#05-noise-suppression-for-voice) | `9c4e5c2` | C++/C/CMake/JUCE | GPL-3.0 | LICENSE_BLOCKED | None; note retroactive-VAD latency only | research-only directory | GPL/JUCE/model-derived surface is incompatible with closed-source reuse. |

## Decision bins

### Integrate now

- AudioKit — only a separately reviewed, TrackSmith-authored narrow utility; no package import.
- chowdsp_utils — only a specifically selected, permissively cleared algorithm independently re-authored after complete closure and real-time proof.
- iPlug2 — only an independently authored bounded reference test; no framework import.

### Prototype offline first

- librosa — external offline CLI generation of hash-audited reference values; never product/AU runtime code.

### Study but do not port

- basic-pitch, NeuralNote, RNNoise, DDSP, madmom, and Demucs — research/protocol value only under their shard gates; no source/model/output is cleared for shipping.

### Reject or license first

- noise-suppression-for-voice, webMUSHRA, akouste, pluginval, JUCE, and Essentia — GPL/AGPL/custom/commercial-license conditions or architecture conflicts require explicit rights before any reuse; the listed study observations do not change that.

The bins map every audited repository exactly once. “Integrate now” authorizes only the tightly described TrackSmith-owned preparation and diligence, not third-party code/model/dependency incorporation.
