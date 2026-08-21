# Start Here for Codex

## Mission

Integrate Packages 001–015 as one coherent, bounded retrieval system without rewriting the LLM-first Tutor and without exposing development/test artifacts to runtime.

Package 016 is **infrastructure-only**. Do not invent Package 016 Q&A content.

## Work autonomously first

Proceed without asking the owner for routine engineering decisions, package migration, public-dataset downloads, fixture generation, builds, tests, benchmark runs, database work, source inspection, or Git branch/tag creation.

Only involve the owner when a task truly requires a personal perceptual judgment or access grant that cannot be replaced by public data. Before that point:

1. use existing synthetic fixtures;
2. use TrackSmith DSP to generate known manipulations;
3. acquire the Package 016 smoke audio profile;
4. acquire the standard profile when disk space permits;
5. use request-free public datasets;
6. generate a request plan for gated datasets and continue independently;
7. run blinded model evaluations and automated checks;
8. use owner listening only for the final subjective boundary.

## Required order

1. Read `package_manifest.json`.
2. Read `integration/integration_manifest.json`.
3. Run the single full validation command.
4. Inspect the generated migration/collision/retrieval reports.
5. Dry-run import.
6. Create a dedicated branch; preserve current HEAD and passing tests.
7. Import Package 016 and the unified outputs.
8. Integrate a bounded read-only community-corpus search tool into the existing Tutor rather than adding another conversation engine.
9. Acquire real public audio smoke assets and build controlled fixtures.
10. Validate actual retrieval and audio-listening behavior.

## Do not

- compile the large corpus into `GeneralTutorKnowledge.generated.swift`;
- pass full package databases to the model;
- expose procedures, scenarios, evaluation answers, test aliases, or Logic navigation to runtime;
- merge reviewed knowledge and candidate/community evidence into one confidence class;
- call every package on every turn;
- ask the owner to supply audio before public data and controlled fixtures have been exhausted;
- block on MedleyDB or MUSDB access.
