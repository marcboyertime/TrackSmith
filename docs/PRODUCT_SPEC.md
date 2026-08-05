# Product specification

## Personas

- A musician who can describe a sonic goal but not compressor/EQ parameters.
- A producer who wants fast alternatives without surrendering detailed control.
- A mix engineer who wants explainable, repeatable analysis and reversible graphs.
- A learning producer who wants to become genuinely skilled: told exactly what
  to try in Logic, why it works, what to listen for, and what principle to
  reuse — not just handed a finished result.

## Product modes

TrackSmith has two permanent top-level modes:

1. **Guide Me** (tutor): the user describes a problem or desired result.
   TrackSmith presents a short diagnostic summary with competing possible
   causes and visible uncertainty, then one reversible manual experiment at a
   time in extremely simple language: what to do, where in Logic Pro, a
   validated bounded starting value when applicable, what to listen for, why,
   when to stop, what could go wrong, and exactly how to undo it. It adapts
   deterministically to Better / Worse / No change / Not sure / Not
   applicable / Cannot find it / Done / Undo. Exactness comes only from
   locally validated versioned procedural knowledge; uncertainty and evidence
   grounding (audio-grounded versus user-reported-only) stay visible; the
   tutor never operates Logic and never mutates the AU graph.
2. **Create For Me**: the existing capture → analyze → three level-matched
   previews → audition → revise → explicit commit workflow.

The long-term relationship is: guide me through doing it myself; create it
for me; explain what you created and teach me to reproduce it. The tutor is
the permanent explanation/learning layer for later automated modules.

## Tutor core user story

Given a vocal passing through the inserted effect, the user types "I sound
nasal." TrackSmith recognizes the report without collapsing it to a different
term, distinguishes user report from measured evidence, presents two or three
competing causes (performance, capture, compression interaction, static or
vowel-dependent resonance) plus the possibility that the quality is character
worth keeping, and runs one experiment at a time until the user reports an
improvement, chooses to keep the sound, or the validated experiments are
honestly exhausted. Completion teaches the production principle practiced,
not only the setting chosen.

## Core user story

Given audio passing through an inserted effect or an explicitly imported file, the
user requests a sonic result. The system measures the current snapshot, compiles
explicit goals and prohibitions, renders conservative/balanced/strong graphs,
level-matches them, rejects constraint violations, and waits for a commit. Every
node remains inspectable, bypassable, removable, resettable, and lockable.

That final sentence is the product target. The current companion cards expose
inspection, enable/bypass and lock; per-card reset, removal, effect solo and advanced
editing are not yet complete.

## Requirements

1. The stable product works without project-wide Logic automation.
2. Original audio is never overwritten; previews derive from immutable snapshots.
3. Model output cannot bypass the plan validator or invoke arbitrary capabilities.
4. No AI, network, file I/O, allocation, blocking, or UI work occurs on render.
5. Manual processing remains available with providers offline.
6. Loudness-matched A/B is the default and peak/phase constraints are measured.
7. State restoration is owned by AU document state plus the product snapshot graph.

## MVP flow and acceptance

The target MVP is the 15-step workflow in the product brief. The portable slice now
accepts a real mono/stereo WAV and prompt, analyzes it, renders three independently
auditionable level-matched WAVs, writes every plan/measurement, refuses overwrite,
and proves source-byte preservation. A real user-owned vocal run additionally proves
three pairwise-distinct options, exact audition/committed graph equivalence, “use less
compression” with a locked EQ and unrelated nodes preserved, typed undo/redo, and
sample-exact dry bypass.

The custom AU host proves recent-input capture, synchronized preview planning,
capture-bound exact commit, revision, undo/redo, two-instance isolation, global
bypass, and AU `fullState` graph/bypass reload using the production AU class. The
companion's bounded conversation/snapshot/edit history persists locally and restores
with safe live-AU reconciliation. The current signed AU completed
the same capture-to-revision-to-commit workflow in disposable Logic Pro 11.2.2 and
Logic Pro 12.3 projects, including internal bypass/restore, exact graph/lock reload,
unchanged source hashes, companion reconnect, and two-instance isolation. The 12.3
lane identifies the exact installed compatibility binary and does not claim the
uninstalled working tree ran inside Logic. Bus/stereo-output insertion,
freeze/bounce, low-latency mode, general automation, and the full host matrix remain
outside the proved MVP scope.

## Non-goals for 1.0

Source separation, generative composition, voice cloning, arbitrary region editing,
private Logic APIs, exact named-artist replication, and autonomous destructive
project modification are not 1.0 dependencies.

## UX direction

The primary surface is a studio tool, not a chat transcript: source/connection and
capture state at top; waveform and interval; request and goal constraints; three
preview lanes; original/result level-matched transport; change cards; snapshot and
undo controls; analysis, CPU, latency, and warning status. Conversation is an input
method over explicit state, not the sole state store.
