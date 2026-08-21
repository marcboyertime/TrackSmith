# TrackSmith Tutor north star

Status date: 2026-08-09

TrackSmith should feel like a thoughtful production mentor sitting beside the
musician in Logic: natural conversation first, exact evidence when available, one
reversible experiment at a time, and a short reusable lesson after the immediate
problem moves forward.

## The governing loop

**Hear → See → Understand → Ask only if necessary → Diagnose → Show one experiment
→ Listen again → Adapt → Teach.**

- **Hear** means either a separately consented model actually received the exact
  bounded capture, or TrackSmith says it did not. Local metrics are Measured, never
  Heard.
- **See** means a fresh read-only observation found a currently visible Logic UI
  attribute. Reviewed documentation, a screenshot inference, and user reporting are
  not Saw evidence.
- **Understand** starts from the musician's desired result and considers source,
  performance, recording, arrangement, masking, monitoring, and processing.
- **Ask** at most one or two questions when the answer changes the next move.
- **Diagnose** is an explicitly uncertain inference, not proof of cause.
- **Show one experiment** means one bounded, reversible, user-performed comparison
  with an exact location, starting range, listen-for, risk/stop rule, and undo.
- **Listen again** records what the musician heard under their own monitoring.
- **Adapt** uses the real conversation and explicit outcome instead of restarting
  from a stateless answer card.
- **Teach** names the portable principle without turning one outcome into universal
  production knowledge.

## Product topology

The native companion has two top-level boundaries:

1. **Tutor** is the primary product. It is a persistent streaming conversation with
   bounded read-only evidence tools and a deterministic offline fallback.
2. **Future / Legacy** preserves Classic Guide, Create For Me, and Vocal. Their
   existing explicit user-controlled processing paths remain compiled but are not
   model tools.

The Audio Unit's **Open TrackSmith Tutor** button requests the companion's
`tracksmith://tutor` route. It does not send a host command or alter audio state.

## Non-negotiable authority boundary

The Tutor model cannot click, type, insert, set, bypass, automate, render, commit,
save, or mutate Logic, the TrackSmith Audio Unit, files, or project state. It never
receives `CompanionSessionClient`, graph APIs, AU parameters, Accessibility setters
or actions, Apple Events, MIDI, keyboard/mouse injection, or filesystem paths.

The model-facing allowlist contains capture-context read, reviewed-knowledge search,
reviewed-procedure retrieval, prior-outcome read, visible-Logic read, bounded
lower-authority candidate-corpus search, and a presentation-only experiment-card
formatter. Candidate search is provisional evidence only: it never supplies package
identity, procedures, navigation, or authority. Unknown tools fail closed.

## Evidence language

Every completed answer carries bounded evidence references:

- **Heard** — the audio-listening model received the exact current capture bytes.
- **Measured** — TrackSmith computed a descriptive local metric.
- **Saw** — the read-only observer found a visible Logic attribute now.
- **You told me** — musician-provided context or outcome.
- **Reviewed** — validated local knowledge or procedure.
- **Inference** — diagnosis or recommendation reasoned from the above.
- **Unavailable** — the requested evidence could not be obtained.

An immutable receipt hashes the answer, model/provider metadata, tool arguments and
outputs, capture identity/hash, evidence labels, and consent state. It contains no
audio bytes, credentials, paths, screenshots, hidden reasoning, or executable plan.

## Strong vertical slice

The first coherent slice must support this as one actual conversation:

1. “My vocal sounds muddy.”
2. Tutor retrieves reviewed context and asks whether the issue is in solo, the mix,
   or both.
3. “In the full mix.”
4. Tutor presents one small reversible comparison with a stop rule and undo.
5. “Clearer, but thin.”
6. Tutor retrieves the persisted outcome, explains why useful body may have been
   removed, restores the failed hypothesis boundary, and proposes a different next
   comparison.
7. “Why?” and “I listened again” remain connected to every prior turn.

This proves dialogue state, tool use, outcome adaptation, and evidence persistence.
It does not prove the advice is perceptually correct or useful to a population.

## Evidence ladder

Claims must stay on their rung:

1. **Source tests** — contracts, streams, schemas, persistence, tools, fallbacks.
2. **Built artifact** — native app/AU compile and signed bundle contents.
3. **Installed artifact** — installed hashes, signatures, entitlements, registration,
   and `auval` for that exact build.
4. **Actual model call** — a real provider received the stated modality and returned
   the recorded response.
5. **Local measurement** — named code measured an identified capture.
6. **Logic observation** — direct, bounded host/UI evidence for the exact run.
7. **User listening** — the musician reports a result under their monitoring.

No lower rung implies a higher one. In particular, metrics are not model listening,
`auval` is not Logic workflow proof, Logic observation is not a user edit, and no
automated result is listening evidence.
