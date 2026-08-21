# Start Here for Codex

This is **TrackSmith Corpus Package 4: Reverb + Delay**.

## Sequence gate

Do not integrate this package until Packages 1–3 are stable. Preserve all earlier package IDs, corpus versions, migrations, source records, evaluation cases, and review states.

## First actions

1. Extract this archive outside the TrackSmith repository.
2. Run:

   ```bash
   python3 tools/validate_package.py
   ```

3. Read:
   - `integration/PACKAGE_SEQUENCE.md`
   - `integration/TRACKSMITH_IMPORT_PLAN.md`
   - `integration/REVIEW_CHECKLIST.md`
4. Inspect the SQLite retrieval database and representative records.
5. Integrate through the scalable read-only corpus/retrieval layer established for earlier packages.

## Do not

- Do not compile the large corpus into `GeneralTutorKnowledge.generated.swift`.
- Do not overwrite reviewed TrackSmith knowledge.
- Do not promote candidate procedures without installed-Logic verification.
- Do not treat numeric ranges as presets.
- Do not treat community popularity as correctness.
- Do not give the model raw forum dumps.
- Do not add any Logic mutation authority.
- Do not conflate a measured tail, model-listening observation, or forum pattern with proof of artistic quality.

## Recommended Tutor role

The corpus should help the Tutor:

- interpret ordinary descriptions such as washed out, too dry, distant, splashy, phasey, echoey, disconnected, and cluttered;
- distinguish reverb, delay, routing, level, spectral, arrangement, stereo, and monitoring causes;
- ask one decision-changing clarification;
- select one reversible experiment;
- retrieve current Logic-specific candidates;
- preserve disagreement;
- adapt after Better / Worse / No change / Not sure / Can't find it;
- teach the relationship between direct sound, reflections, tail, repeats, and arrangement space.

Keep final Tutor responses natural and model-authored.
