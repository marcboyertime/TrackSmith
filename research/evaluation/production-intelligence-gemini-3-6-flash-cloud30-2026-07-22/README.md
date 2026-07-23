# TrackSmith Gemini 3.6 Flash cloud-30 evidence — 2026-07-22

## Result

TrackSmith completed 30 of 30 bounded cloud-assisted semantic-to-preview cases with `gemini-interactions-v1` / `gemini-3.6-flash`. Coverage is five cases each for vocal, drums, bass, guitar, synth/keys, and full stereo mix.

Every selected run demonstrates:

- one explicit stateless, tool-free provider request with raw-audio upload disabled;
- credential retrieval from the TrackSmith macOS Keychain service only;
- typed decoding plus schema, semantic, capability, state-reference, and constraint validation;
- source-aware measured evidence and deterministic TrackSmith hypothesis/planning;
- exactly three valid level-matched previews;
- unchanged source-file bytes;
- provider/model identity, provider response identity, token metadata, latency, interpretation, hypotheses, plan identities, measurements, warnings, and source provenance in `run.json`.

The selected evidence contains 30 unique cases and 90 valid previews. Aggregate provider metadata is 194,075 input tokens, 17,198 output tokens, and 3,546.5 ms mean reported latency (2,706 ms minimum; 4,916 ms maximum). Ten accepted provider results required a bounded audited contract normalization. No selected preview was rejected; 29 warnings identify deliberately conservative options that may be difficult to distinguish or were constrained by a peak/gain bound.

## Fixture and claim boundary

The audio is deterministic, locally generated musical test material, not third-party copyrighted recordings. Each case records its generator version, seed/variant, PCM metadata, and SHA-256 source hash. The generated fixtures satisfy the milestone's legally usable generated-audio lane, but they do not substitute for musician listening tests or prove that any preview sounds artistically better. Listening remains decisive.

## Archive layout

`cases/<CASE-ID>/run.json` is the machine-readable run record. Each case directory also contains `SUMMARY.txt`, the generated source WAV, and a `previews/` bundle with the preserved original, rendered WAVs, exact processing plans, manifest, and audition notes.

## Development failures retained outside this promoted set

Three earlier attempts are intentionally retained under `.build/evidence` and were not promoted as passing evidence:

- `BAS-01`: the third conservative option fell below the source-relative audibility floor; candidate selection/audibility calibration was corrected.
- `BAS-02`: Gemini placed a do-not constraint in the preservation bucket; TrackSmith added bounded audited recategorization while retaining downstream contradiction checks.
- `BAS-03`: conservative compression fell just below the audibility floor; the minimum conservative dynamics depth was raised without changing balanced or strong behavior.

The failed attempts preserved source bytes and never reached commit authority.

## Security boundary

No credential value, raw provider envelope, hidden reasoning, raw audio, arbitrary file content, shell capability, Logic project authority, or real-time-thread authority is present in these artifacts. The stable-signed evaluation runner uses identifier `com.marcboyer.tracksmith.production-intelligence-evaluation` so macOS Keychain authorization is tied to a durable Apple Development designated requirement instead of a rebuild-specific ad-hoc CDHash.

