# Open-source audio-intelligence audit

Audit scope: Apple M1 Max, 64 GB, arm64, macOS 26.3. No MLX or Python audio stack is installed. This is a source/deployment review, not a benchmark, performance claim, or model evaluation.

| Project | Audited revision | Deployment/evidence truth | Decision |
|---|---|---|---|
| AudioToolAgent | `00e1bdcbd646202b42409cc4c1524ead2680dcb7` | Agent/tool research; not an in-process exact-WAV listener here | Deferred |
| MOSS-Music | `ad107c7ddaa06de168a0dfbc18d3e1e6a40c0e5e` | Checkpoint/dependency fit requires separate review | Deferred |
| NVIDIA Audio Flamingo/Music Flamingo | `f4579633f5b7ceaa5001f44d49fce5247777ab1e` | Heavyweight CUDA/checkpoint route; not deployed | Deferred |
| Sony Fx-Encoder++ | `7b1e1f7efaa8a7c212ae4d62c01a5bac5f61c47b` | Research encoder; no local runtime integration | Deferred |
| demucs-mlx | `b37e6ba3c5985af531f61c43564cf13c6ed349fd` | Derived separated-source estimates, not original-source truth | Deferred |
| all-in-one-mlx | `da5f3474503fde41860b454a48bc9e7899cd5dfa` | MLX/Python absent; derived output must remain labeled | Deferred |
| Spotify Pedalboard | `f7f01757406354f29f277d5cadce987c39d97629` | Python deployment is outside this self-contained Swift slice | Deferred |
| Essentia | `b9fa6cb674ca43dfb94d28d293aeda441c6745db` | Useful descriptor reference; no vendored/runtime dependency | Deferred |
| auraloss | `0853e9e732cd32a7b23f11ef4f0d2975d259e653` | Training-loss library, not a direct Tutor listener | Rejected for this slice |

Primary-reviewed upstream pages: [AudioToolAgent](https://github.com/GLJS/AudioToolAgent) (no license text/file located on the audited page; unknown), [MOSS-Music](https://github.com/OpenMOSS/MOSS-Music) (released models: Apache-2.0), [Audio Flamingo](https://github.com/NVIDIA/audio-flamingo) (code: MIT; checkpoints: noncommercial plus additional model licenses), [Fx-Encoder++](https://github.com/SonyResearch/Fx-Encoder_PlusPlus) (CC BY-NC 4.0), [demucs-mlx](https://github.com/ssmall256/demucs-mlx) (MIT), [all-in-one-mlx](https://github.com/ssmall256/all-in-one-mlx) (MIT; retains upstream terms), [Pedalboard](https://github.com/spotify/pedalboard) (GPLv3 plus bundled dependency terms), [Essentia](https://github.com/MTG/essentia) (AGPLv3), and [auraloss](https://github.com/csteinmetz1/auraloss) (Apache-2.0). These are deployment-screening notes, not legal advice; license fit and redistribution obligations need a dedicated review before shipping any dependency/checkpoint. Heavy CUDA/noncommercial checkpoint routes and all Python/MLX runtimes remain deferred. The immediate implementation is the existing public Swift DSP/WAV path: it sees capture-bound exact local waveform bytes and emits local measurements only. No repository secret, credential, host-specific path, or network request is required.
