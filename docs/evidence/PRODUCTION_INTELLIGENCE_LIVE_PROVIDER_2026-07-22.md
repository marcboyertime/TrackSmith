# TrackSmith live Production Intelligence provider evidence — 2026-07-22

Status: **live provider path proven; direct Logic frontier follow-up completed
2026-07-27**

This record indexes the credential-backed provider evidence completed on 2026-07-22.
It does not replace the historical deterministic Logic 11.2.2 or Logic 12.3
validation records, and it does not claim that objective measurements establish
artistic superiority.

## Accepted evidence

| Lane | Provider/model | Coverage | Result |
|---|---|---:|---|
| Cross-provider | OpenAI Responses / `gpt-5.6-sol` | 6 cases: vocal, drums, bass, guitar, synth/keys, full mix | 6/6 accepted |
| Cross-provider | Gemini Interactions / `gemini-3.6-flash` | Same six source-aware cases | 6/6 accepted |
| Cloud-30 | Gemini Interactions / `gemini-3.6-flash` | 30 cases, five per source class | 30/30 accepted |

Every accepted case passed typed decoding, schema, semantic, capability,
state-reference, and constraint validation; deterministic hypothesis/planning;
three valid level-matched previews; and unchanged source bytes. Provider/model
identity, response identity, bounded usage metadata, interpretation, hypotheses,
plans, measurements, warnings, and source provenance are recorded in the machine-
readable run records. The provider requests were text/measurement-only for this
milestone; captured audio was not uploaded.

Canonical evidence directories:

- [`research/evaluation/production-intelligence-frontier-cross-provider-2026-07-22`](../../research/evaluation/production-intelligence-frontier-cross-provider-2026-07-22/README.md)
- [`research/evaluation/production-intelligence-gemini-3-6-flash-cloud30-2026-07-22`](../../research/evaluation/production-intelligence-gemini-3-6-flash-cloud30-2026-07-22/README.md)

## Security boundary

Credentials were retrieved from TrackSmith's macOS Keychain service by the
companion/evaluation process. No credential values, headers, raw provider bodies,
raw audio, file paths, Logic project state, or hidden reasoning are included in
the evidence. Provider output remains untrusted and cannot directly execute DSP,
modify the AU, operate Logic, or write arbitrary files.

## Completed follow-up

The remaining host acceptance proof was completed on 2026-07-27 without rewriting
this provider run. Logic Pro 12.3 demonstrated a genuinely free-form Gemini
request, typed evidence and competing hypotheses, three distinct bounded-loudness-
match previews, a natural multi-turn revision, lock/constraint preservation,
capture-bound commit, bypass/restore, save/reload, provider-offline playback of the
committed graph, multiple-instance isolation, and unchanged source audio. The
post-session Debug/Release/TSan/AU-host/heap/`auval` checkpoint also passed.

See
[`LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md`](LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md)
and
[`PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md`](PRODUCTION_INTELLIGENCE_V1_CLOSURE_2026-07-27.md).
