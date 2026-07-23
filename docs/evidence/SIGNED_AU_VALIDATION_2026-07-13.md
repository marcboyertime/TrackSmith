# Signed AU validation evidence — 2026-07-13

## Verdict and boundary

The current source revision was built as an Apple Development-signed Release,
installed at `~/Applications/Logic Audio Assistant.app`, strict-verified, and
validated as an out-of-process AUv3 effect with:

```sh
auval -v aufx LgAA ExAI
```

`auval` exited zero and reported `AU VALIDATION SUCCEEDED`. It passed open-time,
required/recommended properties, class state, host callbacks, parameter persistence
and scheduling, equal-layout mono and stereo rendering, connection semantics,
maximum-frame failure, and render probes from 11.025 through 192 kHz. The reported
channel capabilities were exactly `[1, 1]` and `[2, 2]`. The only warning was the
legacy `CurrentPreset` property deprecation in favor of `PresentPreset`.

This proves packaging, system discovery, AU instantiation, and the validator's
render/property matrix. It is not proof of the companion workflow inside Logic,
project save/reload, bounce/freeze, low-latency mode, automation, or sustained
real-time safety under a production Logic project. The later direct workflow run is
recorded separately in
[`LOGIC_MVP_VALIDATION_2026-07-14.md`](LOGIC_MVP_VALIDATION_2026-07-14.md).

## Environment

| Property | Recorded value |
|---|---|
| macOS | 26.3 arm64 |
| Xcode / SDK | 26.6 / macOS 26.5 |
| Logic Pro installed | 11.2.2 |
| Component | `aufx` / `LgAA` / `ExAI` |
| Component version | 1.0.0 |
| Execution mode | out of process |
| Development Team | `KDV9RC892F` |

## Installed identity

Both bundles passed `codesign --verify --deep --strict`. `pluginkit` reports the
installed extension identifier. Those facts alone do not prove a Logic insertion;
the separate Logic evidence record does.

| Artifact | Bundle identifier | CDHash | Executable SHA-256 |
|---|---|---|---|
| Containing app | `com.marcboyer.logicaudioassistant` | `14d484cc3b52db2cd71acecdcfa0fd0fe3a6508d` | `e4b2c5bea7cf6c272b06388d88fae75c8b1b7a1eb08f46da932339dfd635b4e4` |
| AU extension | `com.marcboyer.logicaudioassistant.AudioUnit` | `e714e243969cbf0f1b0e0d5371db556cbeab9639` | `9d954c9ad84eecaa3513e375e2f9336b282ddbb51981d0cc84b73e8bf62d6aa2` |

The signed app and extension both carry the same Team-ID-prefixed App Group:
`KDV9RC892F.com.marcboyer.logicaudioassistant`.

## Adjacent current-source evidence

- `TestRunner`: 42/42 in current Debug and Release runs; its Thread Sanitizer run
  exited without a report.
- Production-class `AudioUnitHostProbe`: passed in Debug, Release, and
  ThreadSanitizer runs.
- The host probe rejects actual 1-input/2-output and 2-input/1-output resource
  allocations, snapshot mismatch, stale expected graph, changed capture format, and
  commits while deallocated without changing the live graph or serialized state.
- Release representative callback timing at 48 kHz and 128 frames was 9.1 us mean,
  9.7 us p99, and 49.4 us maximum against a 2,666.7 us buffer deadline.

Those adjacent proofs exercise repository code in a custom host. They do not enlarge
the direct `auval` or Logic evidence boundary.
