# TrackSmith local production-course deep-review lane

Version: 2026-07-18.2  
Evidence class: professional-practice heuristic  
Machine-readable ledger: `research/metadata/local-production-course-review-v1.json`

Audit commands:

```bash
python3 research/scripts/audit-local-production-course-review.py --verify-durations
python3 research/scripts/audit-local-production-course-review.py --verify-durations --verify-hashes
```

The second command re-reads every media payload and is reserved for evidence
checkpoints; routine focused work uses metadata, byte-count, and duration checks.

After a Whisper JSON navigation pass completes, validate and reduce it to a
text-free timing index with:

```bash
python3 research/scripts/build-local-course-transcript-index.py \
  "tmp/local-course-transcripts/logic-pro-11/Logic Pro 11 Complete Tutorial (12-Hour Course).json" \
  --model base --language en
```

The generated metadata contains segment/chapter coverage and the ignored local
transcript hash, but no transcript prose. Its review flags remain false until the
corresponding audio, video, context, and Logic 12.3 cross-checks are performed.

## What this lane is—and is not

The user supplied eight long-form local videos spanning Logic Pro, equalization,
compression, vocal recording and production, mastering, general production, and
a whole-song mix segment. They can show how an educator listens, orders decisions,
compares alternatives, revises a chain, and explains musical intent.

They are not standards, controlled perceptual experiments, proof of undocumented
processor internals, or universal recipes. Numeric settings, genre claims, and
preferred chains remain contextual professional-practice evidence. A consequence
can enter TrackSmith only after the relevant audiovisual passage is reviewed in
context and labeled with its dependencies, limitations, failure cases, and
preservation risks.

The media stays at its original user-supplied path. TrackSmith records exact
SHA-256, duration, byte count, identity status, and review status; it does not copy
the videos or raw transcripts into the repository. Public availability is not
treated as redistribution or model-training permission.

## Transcript boundary

Speech recognition is used only to navigate very long videos. A transcript can
omit on-screen settings, mishear technical words, lose emphasis, and cannot carry
the sound of an A/B comparison. Therefore:

1. transcription success never sets `fullSourceReviewed`;
2. a claim is checked against the source video at the cited time range;
3. audible examples are reviewed by listening, level matched when practical;
4. on-screen settings and routing are checked visually;
5. version-sensitive behavior is checked against Logic Pro 12.3 primary manuals,
   release notes, or dated direct-host evidence;
6. settings remain conditional examples, never fixed presets;
7. raw transcript text remains ignored local working material.

The first indexing job is the Logic Pro 11 course. Its version mismatch is made
explicit: material differences against Logic 12.3 become stale-workflow or changed-
behavior records. The navigation pass is complete: 5,161 ordered segments cover
the 43,139.10-second source through 43,139.08 seconds (`0.99999954` endpoint
coverage), all 15 routed chapters have segments, and the ignored local transcript
hash is recorded in the text-free index. Six boundary/distribution timestamps were
spot-checked against extracted video frames and nearby ASR segments: recording,
Apple Loops/MIDI setup, Alchemy, legacy-synth controls, and the source endpoint
aligned well enough for navigation. This does not validate technical wording or
audible claims. Its state remains **indexed, not deeply reviewed** until audiovisual
review and Logic 12.3 cross-checking finish.

## Review order

1. **Logic Pro 11 Complete Tutorial:** workflow/instrument navigation, checked
   against the already reviewed Logic Pro 12.3 primary sources.
2. **How to Use Compression:** intent-to-envelope reasoning, serial/parallel
   behavior, time constants, source dependence, and audible side effects.
3. **How to Use an Equalizer:** source-conditioned spectral judgment, masking,
   resonance, broad tone versus narrow repair, and level-matched evaluation.
4. **How to Produce & Mix Pro Vocals:** performance preservation, editing,
   arrangement, cleanup, dynamics, tone, depth, effects, and automation.
5. **How to Master Your Music:** reference use, translation, global correction,
   loudness, limiting, and stopping criteria; standards claims are checked against
   ITU/EBU directly.
6. **How to Record Pro Vocals:** room, microphone, performance, cleanup, timing,
   tuning, and the limits of post-production repair.
7. **Music Production For Beginners:** arrangement, energy arc, sound choice,
   layering, automation, and finishing, including project-level actions the
   TrackSmith AU cannot execute.
8. **Mixing a Song From Start to Finish, part 2:** excluded from claim admission
   until publisher, canonical source, companion part, and context are resolved.

## Claim-extraction record

Each reviewed section will record:

- resource ID, payload hash, time range, and review date;
- whether audio, visuals, and surrounding explanation were all reviewed;
- problem, goal, source, genre, arrangement, recording, and existing-chain context;
- observations, options considered, selected/rejected strategy, and revision;
- processor, routing, automation, gain-compensation, and A/B details;
- intended change, preserved attributes, risks, stopping condition, and audible
  result claimed by the instructor;
- whether TrackSmith independently measured or reproduced the behavior;
- supporting or contradicting primary sources and direct-host evidence;
- evidence strength, prohibited overclaims, and bounded product consequence.

This separates what the instructor said, what was audible in that example, what
primary sources establish, and what TrackSmith can execute safely.

## Practical synthesis targets

The course lane will improve producer judgment by teaching TrackSmith to:

- consider multiple source-aware explanations for musician language;
- distinguish tone problems from arrangement, level, dynamics, ambience,
  automation, performance, and sound-choice problems;
- retain “do less” and “leave it alone” as valid strategies;
- preserve breath, pick attack, groove, low-end weight, cymbal smoothness, vocal
  humanity, contrast, and emotional arc;
- clarify when project, multitrack, room, microphone, arrangement, or performance
  context is unavailable;
- generate meaningfully different level-matched candidates and keep listening
  decisive;
- improve explanations without giving prose DSP authority.

## Current evidence state

- Eight payloads have exact hashes, durations, byte counts, handling status,
  chapter routing, and cross-check requirements.
- The Logic course has a verified public identity and chapter map. Its local
  speech-to-text navigation index is complete and structurally validated at 5,161
  segments with all 15 chapters represented, and six distributed timestamp/frame/
  ASR boundary checks support its use for navigation. The text-free index is
  `research/metadata/local-production-course-logic-pro-11-transcript-index-v1.json`;
  no course-derived claim has yet been admitted as deeply reviewed evidence.
- Compression and EQ publisher pages are identified. Other exact item URLs remain
  unresolved where the local container has no identifying metadata. The Compression
  course is now the second navigation job in progress because compressor judgment
  is the highest-recurrence processing family in the curated production cases; its
  transcript will remain navigation-only and its untimed topical routing will not
  be misrepresented as publisher chapter timestamps.
- The whole-song part-two video is quarantined from synthesis until its identity
  and missing context are resolved.

That conservative state prevents a long transcript—or a confident instructor—
from silently becoming TrackSmith's idea of truth.
