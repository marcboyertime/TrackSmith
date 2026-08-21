# QA report

## Generated corpus

- Canonical records: 214
- Vocal records: 147
- Quantization/timing records: 67
- User utterances: 3290
- Multi-turn scenarios: 428
- Contradictions: 17
- Sources: 34
- Procedure candidates: 214

## Structural checks performed during generation

- Canonical IDs are unique.
- Utterance IDs are unique.
- Scenario IDs are unique.
- Every utterance resolves to a canonical record.
- Every scenario resolves to a canonical record.
- Every source reference resolves to the source registry.
- All canonical rows remain `candidate_not_yet_human_reviewed`.
- Every canonical row contains:
  - at least one clarification;
  - multiple candidate hypotheses where applicable;
  - one first experiment;
  - Logic steps;
  - listening cues;
  - stop rule;
  - undo;
  - teaching principle;
  - limitations.
- No raw forum body or long quotation was intentionally included.

## Content-quality design checks

The corpus intentionally rejects these failure patterns:

- mapping “muddy,” “nasal,” “harsh,” or “boxy” to one fixed frequency;
- treating a spectrum as proof of perception;
- recommending ten processors before asking whether the problem exists solo or in the mix;
- using compression as a substitute for automation, source quality, arrangement, or performance;
- using 100% Classic Quantize as the universal timing fix;
- moving MIDI notes before checking tempo authority, region start, latency, pedal/CC, and musical role;
- hiding Flex artifacts behind a passing structural test;
- treating popular forum advice as professional consensus.

## Human-review requirement

This package was generated as a large, structured candidate corpus. It has not completed record-by-record owner review in a real Logic session.

The integration agent should:

1. import utterances/scenarios for retrieval and QA;
2. prioritize high-value canonical records by actual query frequency;
3. run named source/Logic-version review before promotion;
4. record corrections rather than silently rewriting the immutable package.
