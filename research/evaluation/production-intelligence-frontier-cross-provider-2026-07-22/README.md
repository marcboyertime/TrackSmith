# TrackSmith frontier cross-provider evidence — 2026-07-22

## Result

OpenAI Responses (`openai-responses-v1`, `gpt-5.6-sol`, medium reasoning) and Google Gemini Interactions (`gemini-interactions-v1`, `gemini-3.6-flash`, low thinking) each completed the same six free-form source-aware TrackSmith cases: vocal, drums, bass, guitar, synth/keys, and full stereo mix.

All 12 runs passed. Every run produced a validated typed interpretation, deterministic TrackSmith hypotheses/plans, exactly three valid level-matched previews, and byte-identical source material after evaluation.

| Provider | Cases | Input tokens | Output tokens | Mean latency | Bounded repairs | Preview warnings |
|---|---:|---:|---:|---:|---:|---:|
| Gemini 3.6 Flash | 6/6 | 41,083 | 3,844 | 3,701.8 ms | 3 | 7 |
| OpenAI GPT-5.6-SOL | 6/6 | 45,533 | 6,965 | 21,677 ms | 0 | 4 |

Latency is provider-reported wall time observed in this environment, not a general benchmark. Token counts and quality can vary across requests. This evidence does not designate a permanent “best” provider and does not claim that objective safety metrics establish artistic superiority.

## Requests

- Vocal: “Make this vocal feel more intimate and expensive, but keep the breathiness.”
- Drums: “The drums feel flat and small. Give them more life without making the cymbals obnoxious.”
- Bass: “The bass is huge but blurry. Tighten it without losing the weight.”
- Guitar: “This guitar hurts when I turn it up, but don't take away the aggression.”
- Synth: “Make this synth wider without damaging mono compatibility.”
- Full mix: “Make this mix clearer without making it brighter.”

## Security and authority boundary

Both adapters are stateless, tool-free, text-only for this milestone, and receive no captured audio. Credentials are read only from TrackSmith's macOS Keychain service in the companion/evaluator process. Provider output is untrusted: it passes decoding, schema, semantic, capability, state-reference, and constraint validation before it can inform TrackSmith-owned hypotheses. Only bounded deterministic DSP plans accepted by `PlanValidator` can render or commit.

Gemini's three repairs were explicit audited semantic-shape normalizations (for example, equivalent preservation versus do-not constraint placement); no attribute, source class, capability, state identity, measurement, processing node, or raw parameter was invented during repair.

## Layout and claim boundary

`openai/<CASE-ID>/` and `gemini/<CASE-ID>/` contain each run's JSON evidence, deterministic generated source, exact plans, rendered previews, and audition notes. Fixtures are legally usable locally generated material with recorded hashes and provenance. Listening remains decisive, and these cases do not prove that any preview is aesthetically preferable.

