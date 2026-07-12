# Product specification

## Personas

- A musician who can describe a sonic goal but not compressor/EQ parameters.
- A producer who wants fast alternatives without surrendering detailed control.
- A mix engineer who wants explainable, repeatable analysis and reversible graphs.

## Core user story

Given audio passing through an inserted effect or an explicitly imported file, the
user requests a sonic result. The system measures the current snapshot, compiles
explicit goals and prohibitions, renders conservative/balanced/strong graphs,
level-matches them, rejects constraint violations, and waits for a commit. Every
node remains inspectable, bypassable, removable, resettable, and lockable.

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
and proves source-byte preservation. It also proves graph revision for “undo only
the compression” and exact bypass for an empty graph. Logic insertion, render-thread
graph integration, capture UI, synchronized playback A/B, and project reload remain
open acceptance gates.

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
