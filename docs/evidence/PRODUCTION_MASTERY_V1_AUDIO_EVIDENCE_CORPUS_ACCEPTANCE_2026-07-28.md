# Production Mastery v1 audio-evidence corpus acceptance

Date: 2026-07-28  
Milestone gate: G1.5  
Status: passed  
Frozen predecessor: Production Intelligence v1 at
`a19c0b7e9dbee7909552feb3547fa607a312f2db`

## Decision

The annotated natural-audio gate materially improved the milestone and is
accepted. It is an evaluation corpus, not a training corpus or a claim that
more downloaded bytes imply better production judgment.

The accepted scope contains:

- 19 content-addressed captures from MedleyDB, MixAssist, and AudioSet;
- 632,714,727 exact retained bytes;
- 390 individually SHA-256-identified PCM assets;
- 10,668.909007794784 seconds of summed asset duration, including aligned
  raw, stem, and mix representations of the same songs;
- 14 TrackSmith annotations: 12 grounded in human MixAssist dialogue and 2
  research-practice-derived MedleyDB fixture annotations;
- all required acquisition lanes and zero exact leakage across TrackSmith's
  local evaluation/holdout boundary.

No raw audio is sent to a provider. Acquisition grants no authority for model
training, product shipping, redistribution, Logic control, or executable DSP.
No listening participant, preference result, or high-fidelity MixAssist claim
is fabricated.

## Accepted natural multitrack scope

The official MedleyDB sample capture is:

- source record: Zenodo 1438309 revision 53;
- byte count: 415,502,011;
- SHA-256:
  `603fa6cc6fc8d6dd0f5ffcc5bd97b8b2c74820e2498b1e44a285308e772d7910`;
- publisher MD5: `dbb5b4ff5122233915d04cab4486ead1`, matched;
- archive scope: 118 members, 99 regular files, 671,071,703 uncompressed
  bytes;
- indexed PCM: 2 full-song stereo mixes, 9 stereo processed stems, and 10
  mono raw sources at 44.1 kHz, with no clipped or silent indexed asset.

The official MedleyDB page says CC BY-NC-SA 4.0 and asks that the dataset not
be republished without consent. Zenodo's sample record says CC BY-SA 4.0.
TrackSmith retains the contradiction and applies the stricter noncommercial,
local-only boundary.

The two-song sample removes the absence of any natural aligned
raw/stem/mix evidence. It does not provide the genre or recording diversity
required for the final perceptual milestone. Full MedleyDB or MoisesDB remains
a ranked expansion only when later evaluation coverage needs it.

## Accepted audio-grounded language scope

All seven MixAssist processed-audio archives and the pinned train,
validation, and test Parquet objects are retained. Every archive matches the
publisher MD5 and every WAV passed PCM validation.

The indexed scope contains 369 MixAssist clips. All are 16 kHz mono. They are
admissible for:

- audio-grounded production-language context;
- multi-turn revision and reference resolution;
- coarse source, role, and change context.

They are prohibited as evidence of high-fidelity timbre, stereo width, phase,
or mastering preference.

The pinned release reuses nine identical audio assets across its published
train, validation, or test turn splits. Four additional exact duplicate-audio
groups occur within a single TrackSmith local split. TrackSmith therefore
retains the release splits only as provenance and uses a session-disjoint
local policy: Groups 1–5 are evaluation material and Groups 6–7 are holdout
material. The resulting TrackSmith exact split-leak count is zero.

The MixAssist audio on Zenodo is declared CC BY 4.0. The pinned Hugging Face
dialogue revision has no explicit dataset license tag, so its text remains
local-only and license-review-required. The GitHub code license is not
silently applied to the data.

## Accepted supplemental AudioSet scope

TrackSmith retained compact AudioSet labels and quality records, not raw
YouTube audio or the 2.4 GB feature bundle:

- v1 evaluation and balanced-train weak labels;
- the 527-class label map;
- per-class quality true counts;
- 132,766 rerated video identifiers;
- 139,538 strong evaluation events;
- 958,528 framed positive/negative labels;
- the 456 strong-label display-name mappings.

AudioSet remains supplemental event/noise/source-presence evidence, never
production preference.

The official download page says the evaluation and balanced splits contain
20,383 and 22,176 segments. The exact downloaded CSV headers and data contain
20,371 and 22,160. Both claims are retained. Artifact-backed counts govern
TrackSmith's indexed scope.

## Rejected attempts and ingestion regression

Eight first Zenodo attempts were rejected because URLSession combined two
identical `Content-Type` values. The rejected attempts and quarantined bytes
remain in the local immutable archive.

Research ingestion was narrowed to normalize repeated media types only when
all values are identical. Conflicting repeated values remain non-allowlisted
and fail closed. The full Debug TestRunner passed 72 of 72 tests, including
both new cases, before the archives were reacquired.

## Gate verification

The deterministic gate command passed:

```sh
python3 research/scripts/audit-audio-evidence-corpus.py \
  --require-ready \
  --write-report \
  research/evaluation/production-mastery-v1/audio-evidence-corpus/audit-report.json
```

Accepted evidence hashes:

- audit report:
  `76323630c3b47e9e5d2b2b40d27d8b3a3f4d361633ee3dfd61fb1b5a28d04dd8`;
- acquisition plan:
  `2c9b90f026fdc32262f74fd7fd388510373aff50550e29153dbe2aca51c36c1a`;
- natural-audio index:
  `ee288d304ca88f5b1c86c9c038af9908396dd6d6352c6c1cf5b95bab2bf5acdc`;
- TrackSmith annotation overlay:
  `f52c5380bcd1f16e16ff4929159716796edbc19fd15a4ed512fa3128c5793192`.

The index and annotation hashes above identify the exact accepted pre-closure
representations. The gate remains reproducible through the checked-in
acquisition, promotion, index, annotation, and audit scripts.

## Remaining boundary

This gate permits the milestone to resume Logic processor profiling and
TrackSmith-owned DSP work. It does not satisfy the later controlled-listening
gate. The two MedleyDB listening task IDs remain `not_run`; candidates,
level-matching evidence, a protocol, real participant responses, and returned
artifact verification are still required before any preference claim.
