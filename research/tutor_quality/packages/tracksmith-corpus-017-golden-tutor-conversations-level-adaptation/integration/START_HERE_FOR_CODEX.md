# Start Here for Codex

1. Validate the archive against Packages 001–016.
2. Run the importer dry run.
3. Read `integration/integration_manifest.json`, especially `experience_level_contract` and `evaluation_isolation`.
4. Import this package only into TrackSmith's test/evaluation area. The importer must emit zero live runtime knowledge records.
5. Implement the explicit Noob / Amateur / Pro selector in the existing LLM-first Tutor.
6. Run every golden case at all three levels without exposing expected text to the model.
7. Use Package 016 public audio for audio-grounded cases before requesting private audio.
8. Build, install, and directly test the app/AU in Logic.

The separate Codex prompt distributed beside this ZIP contains the full execution contract.
