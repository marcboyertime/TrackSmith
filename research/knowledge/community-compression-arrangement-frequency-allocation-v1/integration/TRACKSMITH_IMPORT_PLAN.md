# TrackSmith Import Plan — Package 3

## Sequencing

Prerequisites:

1. Package 1 vocal/quantization import is stable.
2. Package 2 level/EQ import is stable.
3. Corpus manifests and migration logic can distinguish package sequence 1, 2, and 3.

## Recommended implementation

1. Register this package manifest and source registry without altering earlier IDs.
2. Import utterances and evaluation cases first; these can improve language coverage without promoting production claims.
3. Add Package 3 records to the scalable local retrieval index.
4. Filter/rerank by domain, source type, role, section, mix context, and installed Logic version.
5. Return compact patterns and source IDs to the Tutor rather than raw records.
6. Route claims, strategies, and exact procedures through the existing review workflow.
7. Add evidence receipts containing package/corpus version and selected record IDs.
8. Run the multi-turn scenarios against the frontier Tutor.
9. Verify selected Logic procedures in the installed Logic version.

## Suggested Tutor retrieval behavior

- Search reviewed knowledge first for documented Logic behavior.
- Search Package 3 for practitioner decision patterns, common phrasings, contradictions, and likely clarification questions.
- Retrieve no more than a small bounded diverse set.
- Preserve disagreement and applicability conditions.
- Let the frontier model synthesize one natural answer and at most one current experiment.

## Domain distinctions

### Compression

Treat compression as time-varying envelope/level control. Separate:

- phrase/section automation;
- transient shaping;
- saturation/clipping;
- limiting;
- sidechain detector behavior;
- bus and multiband tradeoffs.

### Arrangement

Test role, density, register, rhythm, entrance/exit, and contrast before mix surgery.
Use Project Alternatives/Arrangement Markers only as recoverable Logic workflows,
not as automatic compositional authority.

### Frequency allocation

Test level, role, voicing, timing, note length, arrangement, and masking context
before EQ. Treat spectral overlap as evidence only when actual cues are obscured.
