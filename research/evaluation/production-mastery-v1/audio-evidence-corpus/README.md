# TrackSmith Audio Evidence Corpus v1

Status: acquisition in progress  
Milestone gate: G1.5  
Payload root: `research/datasets/production-mastery-v1/` (local and ignored)

## Why this gate exists

TrackSmith's generated PCM fixtures are the correct evidence for deterministic
transfer, timing, state, bypass, parity, and source-preservation claims. They are
not representative musical evidence and cannot establish:

- natural recording and performance variation;
- full-song section and arrangement interaction;
- aligned raw, processed-stem, and mix relationships;
- source-role, bleed, activity, genre, or production-language coverage;
- production preference or preservation success.

This gate adds only material that can change a failure-map ranking, create a
meaningfully adverse fixture, support a long-form or multitrack test, expand
non-generated language coverage, or ground a controlled listening task.

## Evidence and rights boundary

- Dataset labels remain dataset-supplied labels, not TrackSmith measurements.
- Mechanically derived measurements remain objective descriptors, not preference.
- Curated desired, preserved, prohibited, ambiguous, no-op, and non-DSP labels are a
  separate TrackSmith evidence layer.
- Listening results require a recorded protocol and real participant; no dataset
  label is silently converted into a listening preference.
- Dataset, annotation, source-audio, repository, model-weight, and training rights
  are reviewed separately.
- This milestone authorizes local evaluation acquisition only. It grants no
  provider upload, model training, product shipping, or redistribution authority.
- Current providers never receive raw audio.

## Ranked acquisition lanes

1. MedleyDB metadata/annotations and permitted audio: raw recordings, processed
   stems, mixes, instrument/source roles, genre, bleed, activity, and full songs.
2. MoisesDB or another independently recorded known-stem corpus: broader genres,
   hierarchical stems, reconstruction, leakage, cross-track, and long-form tests.
3. MixAssist and MusicSem material whose payload and underlying-media rights pass
   review: audio-grounded production dialogue and natural music language.
4. AudioSet balanced/evaluation metadata or features only: event, noise, and
   source-presence adversarial coverage. AudioSet is not production-judgment ground
   truth and is not the primary musical corpus.
5. MUSDB18-HQ is a useful secondary benchmark when its educational-use access and
   local handling are accepted; it is not required merely to increase byte count.

## Acceptance

The gate is ready only when:

- every retained artifact matches its recorded byte count and SHA-256;
- archive/container and structured-file integrity checks pass;
- handling, license, local-only, redistribution, training, and provider-upload
  fields are explicit;
- at least one natural multitrack/known-stem lane and one audio-language lane are
  accepted, or an access/rights record names a validated substitute;
- a natural-audio index has stable dataset/asset/split identities;
- duplicate and split-leakage checks pass within the indexed scope;
- supported WAV material passes PCM, duration, channel, rate, silence, clipping,
  and—where stems permit it—alignment and reconstruction checks;
- TrackSmith annotations validate against `annotation-schema.json`;
- every selected excerpt points to a failure-map case, DSP/listening fixture,
  language case, or explicit long-form/multitrack evaluation.

Run:

```sh
python3 research/scripts/acquire-audio-evidence-corpus.py --all
python3 research/scripts/promote-audio-evidence-captures.py --write
python3 research/scripts/build-audio-evidence-index.py --write
python3 research/scripts/build-audio-evidence-annotations.py --write
python3 research/scripts/audit-audio-evidence-corpus.py
python3 research/scripts/audit-audio-evidence-corpus.py --require-ready
```

The acquisition command expands the versioned request profiles in
`acquisition-plan.json` and sends every payload through `ResearchIngestCLI`.
Requests, content-addressed objects, exact capture records, and failed attempts
remain under the ignored local payload root. A successful download is not added
to `acceptedCaptures` until its returned record and format-specific checks have
been reviewed.

The promotion command rechecks exact size, SHA-256, and any publisher-supplied
MD5 before generating the checked-in capture and attempt ledgers. The first
audit command validates structure and all promoted artifacts. The final command
also fails until every gate-exit condition is satisfied.
