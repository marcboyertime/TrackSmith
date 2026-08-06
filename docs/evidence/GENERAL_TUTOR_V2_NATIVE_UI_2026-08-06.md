# General Tutor v2 — native Guide Me open-question surface (2026-08-06)

Records what was actually built and actually observed running. No Logic host
interaction and no perceptual claim.

## What changed

Guide Me previously accepted only the bounded Tutor v1 lesson flow. It now has
an **Ask** action that accepts any production question and renders the
validated open-domain answer natively.

| Element | Source |
|---|---|
| Interpreted question kind + routed domains + confidence class | `GeneralTutorAnswerContract` |
| Direct answer | `directAnswer` |
| "What I am assuming" (collapsible) | `assumptions` |
| "TRY THIS FIRST" with listen-for and stop rule | `recommendedFirstMove`, `whatToListenFor`, `stopConditions` |
| Ranked strategy cards, first marked BEST FIRST | `strategyOptions` |
| Per-card tradeoffs, preservation risks, stop rule (Standard/Technical depth) | strategy option fields |
| "Start guided experiment" button | only when the option names a reviewed procedure |
| "Credible sources disagree" panel | `contradictionDisclosures` |
| Collapsible preserve / risk / non-DSP / cannot-see | corresponding contract fields |
| Sources list with evidence class | `sourceIDs` + retrieved claim evidence class |
| Audio-influence statement | `audioInfluence.statement` |
| Teaching principle | `teachingPrinciple` |

`Ask` is the prominent default action (⌘↩). `Start Lesson` remains for the
bounded vocal fast path. Prompt chips were broadened beyond the nasal case to
cover chorus energy, MIDI timing, a concept question, and "I am stuck."

## Verified live

Signed build installed via `make native-install` (Team `KDV9RC892F`) and
launched. Logic Pro was **not** running and no AU was inserted; this exercised
the no-capture path only.

Observed in the running app:

1. On relaunch the restored session correctly displayed **"Capture evidence is
   historical — The Audio Unit or capture changed since this lesson started."**
2. Source set to **Keyboard**, explanation depth **Standard**, question
   "How do I tighten my MIDI piano without making it robotic?" — a question
   with no Tutor v1 issue-enum match.
3. `Ask` produced, without a capture:
   - header `TROUBLESHOOTING · timing editing · humanization · piano and keys`,
     right-aligned `source-grounded strategy`;
   - direct answer: *"The most likely useful direction: Tighten timing without
     flattening the performance. Quantization strength, the note selection you
     apply it to, and whether you move notes at all are three separate
     decisions. Most robotic results come from applying full strength to every
     note including ones that were expressive on purpose."*;
   - **TRY THIS FIRST**: *"Before quantizing anything, decide whether the grid
     is right for this performance: loop eight bars and ask whether the part
     sounds wrong against the other instruments, or only wrong against the
     ruler."*;
   - stop rule: *"Stop when the part sits with the other instruments; going
     further only serves the ruler"*;
   - two strategy cards, first badged **BEST FIRST**, with tradeoffs ("Grid
     accuracy versus human feel", "Ensemble tightness versus expressive
     timing") and preservation ("Intentional rubato, rolled chords, grace
     notes, and the difference between hands").
4. The evidence banner read **"No recent capture"** and the answer did not
   claim any measurement informed it.

This satisfies acceptance criterion 28 in the shipping UI: a useful strategy
distinguishing note quantization, selection scope, and the tempo-map direction,
with no pretence that TrackSmith can inspect or edit the MIDI region.

## Not done

- No **Research This** control; the research path is specified, not built.
- No memory controls ("Remember this worked" / "Do not remember").
- No structured user-context entry beyond the existing channel-chain reporter.
- No in-host verification of this surface: Logic was not running, no AU was
  inserted, and the capture-grounded path through `Ask` was not exercised.
- No owner session. Whether these answers are *useful on real work* is
  untested and remains gate GP8.
