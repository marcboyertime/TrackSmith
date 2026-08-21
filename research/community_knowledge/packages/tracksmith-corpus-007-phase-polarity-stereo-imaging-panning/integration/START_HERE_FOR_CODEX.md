# Start Here for Codex — Package 007

This is **TrackSmith Corpus Package 007 — Phase and Polarity + Stereo Imaging + Panning**.

## Sequence

Integrate this package only after Packages 001–006 are stable. Do not overwrite earlier package IDs, manifests, migrations, source records, databases, evaluations, or review states.

## Preflight

```bash
python3 tools/validate_package.py
python3 tools/inspect_package.py
python3 tools/query_corpus.py "negative correlation mono"
python3 tools/query_corpus.py "Stereo Pan versus Balance"
python3 tools/query_corpus.py "send pan versus return pan"
```

Before changing TrackSmith:

```bash
python3 tools/import_to_tracksmith.py --target /path/to/TrackSmith --dry-run
```

Use `--dependency-map` if Packages 001–004 are installed under legacy IDs.

## Integration requirements

1. Stage the package through the existing scalable community-knowledge package registry.
2. Do **not** compile this corpus into `GeneralTutorKnowledge.generated.swift`.
3. Preserve `candidate_not_yet_human_reviewed` on every candidate.
4. Preserve `candidate_unverified_on_installed_logic` and `execution_authority: false` on every Logic procedure.
5. Keep official documentation, primary research, professional practice, specialist discussion, measurement, model listening, inference, and user-confirmed outcomes as distinct evidence classes.
6. Retrieve a small, diverse slice. Do not dump many records into the Tutor prompt.
7. Preserve disagreement: polarity versus timing, natural arrival versus alignment, width versus mono compatibility, Balance versus Stereo Pan, hard versus intermediate pan positions, and M/S tradeoffs are context-dependent.
8. Require a matched-loudness stereo/mono comparison for decisions that change width, phase relationship, or panning.
9. Exact Logic navigation must remain version-scoped until verified on the installed build.
10. The user performs every Logic action.

## Expected Tutor behavior

TrackSmith should distinguish:

- polarity inversion from frequency-dependent phase shift;
- timing offset from channel orientation;
- phase cancellation from ordinary masking or level imbalance;
- correlation measurement from artistic quality;
- stereo width from left/right balance;
- mono Pan from stereo Balance and Stereo Pan;
- direct-source widening from ambience width;
- Mid/Side components from object or stem separation;
- panning from arrangement, register, level, and depth;
- intentional stereo compromise from critical mono failure.

Recommend one reversible experiment, say what to listen for, provide a stop condition and undo, and adapt to the user’s report without restarting from generic advice.
