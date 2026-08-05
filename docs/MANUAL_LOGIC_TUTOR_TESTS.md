# Direct Logic 12.3 user-mediated tutor validation (gate T7)

Status: **pending**. This checklist is the exact manual procedure for closing
tutor gate T7 in
[`research/evaluation/logic-production-tutor-v1/ledger.json`](../research/evaluation/logic-production-tutor-v1/ledger.json).
No step below has been executed as of 2026-08-05, and Tutor v1 must not be
declared closed until the artifacts listed here exist. A human must operate
Logic; TrackSmith has no host automation, and none may be added for this test.

## Preconditions

0. **Quit Logic Pro before installing.** Replacing the `.appex` while Logic
   has it loaded can wedge Logic on an undismissable document-close dialog
   (observed 2026-08-05). Install first, launch the companion once, then open
   Logic.
1. Install the current build via `make native-install` (Apple Development
   signing per README) and record:
   - app bundle ID, AU component (`aufx LgAA ExAI`), both CDHashes,
   - `git rev-parse HEAD` of the installed source.
2. Use a user-owned vocal recording. Do not commit the audio. Record its
   SHA-256 and duration/rate/channel metadata in the evidence record.
3. Confirm the portable lanes at that HEAD: `make verify` (includes the tutor
   knowledge checks and 82-check TestRunner) and `make tutor-evaluation`
   (77/77).

## Scenario

| # | Action | Expected result | Artifact |
|---|---|---|---|
| 1 | Record installed identities (above) | Exact IDs captured | evidence record header |
| 2 | Insert TrackSmith on the vocal track; play the phrase | Companion lists the instance | screenshot |
| 3 | Analyze Recent Playback with Source = Vocal | Capture succeeds; waveform shown; capture hash recorded | screenshot + hash |
| 4 | Select **Guide Me** | Mode switch visible; Create For Me panels hidden | screenshot |
| 5 | Enter "I sound nasal. Tell me exactly what to try and why." and start the lesson | Evidence banner shows audio-grounded; hypotheses panel separates user report, measured evidence (worded as consistent-with, not proof), competing causes, and uncertainty | screenshot |
| 6 | Inspect the first step card | Exactly one active experiment (compression-emphasis confirm step for an unknown chain) with instruction, listen-for, why, stop rule, side effect, and undo | screenshot |
| 7 | Check the AU | No TrackSmith processing graph changed; committed plan untouched (compare heartbeat/plan state before and after) | state dump |
| 8 | Report one feedback (e.g. Done, then Better) | Next step changes per the deterministic reducer; hypothesis badges update | screenshot |
| 9 | Press Undo | Exact rollback instruction shown; no host state assumed | screenshot |
| 10 | Quit and relaunch the companion | Tutor session restores; audio-grounded claims are labeled historical until re-analysis | screenshot |
| 11 | Remove/reinsert the AU (new runtime), re-open Guide Me | Evidence banner demotes to historical; no live claim from the old capture | screenshot |
| 12 | Switch to **Create For Me**; generate three previews, audition, revise, commit | Existing workflow works unchanged | screenshot + manifest |
| 13 | Disable network / no credential, repeat step 5 in a new lesson | Offline path completes the nasal lesson identically | screenshot |
| 14 | Verify source audio hash after the whole session | Unchanged SHA-256 | hash pair |
| 15 | Inspect tutor persistence and provider traffic | No raw audio, path, credential, or raw provider response in `Application Support/com.marcboyer.tracksmith/ProductionTutor/`; no provider traffic at all in the offline lesson | file listing + redacted excerpt |

## Owner self-evaluation (acceptance criterion 23)

Separately from the checklist, the owner completes at least one real
nasal-vocal troubleshooting lesson end to end without an external tutorial and
records: the feedback path taken, which experiment (if any) helped, the exact
user-chosen settings (labeled user-entered), and whether the completion
summary taught a reusable principle. Label this **owner self-evaluation** — it
is personal utility evidence, not a general perceptual study, and no listener
panel is claimed.

## Evidence record

Write `docs/evidence/LOGIC_12_3_TUTOR_V1_VALIDATION_<date>.md` with the exact
host/OS/signing identities, hashes, per-step outcomes, screenshots, and any
deviations. Update tutor ledger gate T7 only after that record exists.
