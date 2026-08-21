# TrackSmith import plan

## Existing architecture alignment

The current TrackSmith Tutor already distinguishes:

- source registry entries;
- knowledge claims;
- strategy cards;
- contradictions;
- exact reviewed procedures;
- personal outcomes;
- retrieval/evaluation corpora.

This package should enter those existing boundaries.

## Canonical records

`corpus/canonical_qa.jsonl` is the human-readable source of truth for the package.

A canonical record combines:

- question language;
- diagnostic branching;
- first experiment;
- version-scoped Logic instructions;
- listening cues;
- stop/undo;
- teaching principle;
- sources and limitations.

Do not render every field to the user. The frontier Tutor should synthesize a natural answer and optionally render one compact experiment card.

## Utterance rows

Use utterance rows for:

- retrieval recall;
- paraphrase robustness;
- domain routing;
- realistic user-language QA.

Do not:
- promote utterance text into independent knowledge;
- calculate confidence from number of paraphrases;
- train the Tutor to respond with the same template to every phrasing.

## Candidate claims

Map candidate claims to the repository’s `ProductionKnowledgeClaim` equivalent only after review.

Recommended evidence class:
`professionalPracticeHeuristic` or a new explicitly bounded `communityPracticeSynthesis`.

Each imported claim should retain:
- canonical QA ID;
- all supporting source IDs;
- review event;
- conditions;
- limitations;
- listening-remains-decisive flag.

## Candidate strategies

Map strategy candidates to `ProductionStrategyCard`.

Preserve:
- competing interpretations;
- first experiment;
- listen-for;
- preservation;
- tradeoffs;
- stop rule;
- undo;
- non-DSP alternatives;
- source list.

## Procedure candidates

Exact instructions are the highest-risk import.

For each candidate:

1. Resolve every named Logic control against Apple documentation.
2. Verify the visible path on the installed Logic version.
3. Add “Can’t find it” fallback.
4. Confirm undo/reset behavior.
5. Ensure the procedure never claims TrackSmith performed the user action.
6. Mark menu/control paths documentary or directly verified.
7. Promote only after named review.

## Contradictions

Contradiction records should be retrieved whenever:
- both positions match the question;
- a community rule is being universalized;
- context determines which strategy applies.

A Tutor response should explain what decides between positions and propose an A/B or discriminating test.

## Personal outcomes

Do not generalize a user-confirmed result into this shared candidate corpus.

Personal memory may reorder strategies for the owner while preserving the general evidence class.

## Suggested repository location

A reasonable import location is:

`research/knowledge/community-vocal-quantization-v1/`

Keep this package intact as an immutable input and generate repository-native artifacts from it.
