# 0006 — Open-domain production tutoring with reviewed knowledge cards

Date: 2026-08-06. Status: accepted.

## Decision

TrackSmith answers open-ended production questions by routing them into a
typed intent, retrieving reviewed knowledge cards, and synthesizing a
validated answer contract. The Tutor v1 closed issue vocabulary is retained as
a fast path but is no longer a precondition for responding.

Breadth comes from *knowledge*, not from model latitude. A model may classify,
rank, compare, and explain; it may never author an instruction, a value, a
control name, a Logic path, or a source.

## Rationale

Tutor v1's own closure record identified its binding constraint: 18 enum cases
cannot represent the space of ordinary production questions, and most
recognized issues outside a narrow vocal set terminated in a limitation. The
options were to widen the enum (which does not scale and still fails on
unanticipated wording), to let a model answer freely (which discards the
authority split that made Tutor v1 trustworthy), or to separate *what is known*
from *what is exactly instructable*.

The third option is what this ADR adopts. A `ProductionStrategyCard` can carry
a useful, source-grounded decision pattern for a domain that has no exact
procedure. That is how the tutor answers an arrangement or MIDI-feel question
honestly without pretending it has a validated step-by-step for it.

## Constraints adopted

1. **Exact instructions remain catalog-only.** `exactProcedureIDs` must
   resolve to the reviewed procedure catalog, or validation throws.
2. **Numbers must be traceable.** A numeric recommendation in prose is
   rejected unless the figure appears verbatim in a cited reviewed card or the
   answer carries a validated procedure.
3. **Evidence classes are not flattened.** Documented behavior, measured
   behavior, inference, practice heuristic, subjective preference, personal
   result, and provisional research remain distinct in the contract and in the
   answer.
4. **Contradictions are disclosed, not resolved.** When credible sources
   disagree and both sides are cited, the answer must surface the
   contradiction and what determines which applies.
5. **Audio influence is never overstated.** The answer records exactly which
   measurements influenced it; claiming influence with no influencing metric is
   a validation error. "A capture exists but cannot resolve this" is expected.
6. **Personal outcomes never generalize.** A user-confirmed result may rank
   for that user but is rejected if phrased as universal.
7. **Sources needing audiovisual review cannot ground trusted claims.** A
   transcript alone is insufficient when the claim depends on hearing or
   seeing something.

## Retrieval choice

Deterministic lexical ranking with typed filters, rather than embeddings.
Reasons: full local operation, reproducible ordering (identical question →
identical cards, which is what makes a 332-case corpus meaningful),
inspectability when a wrong card is retrieved, no added dependency or binary
weight, and no privacy surface. Embeddings remain an option if measured
retrieval quality justifies them; the interface does not assume lexical.

## Alternatives rejected

- **Widening the issue enum.** Does not scale and still fails on wording the
  author did not anticipate.
- **Free-form model answers with a disclaimer.** Discards the property that
  makes the product trustworthy and reintroduces invented settings.
- **Promoting research results directly into knowledge.** Provisional answers
  stay provisional and can only become candidate cards in a review queue.
