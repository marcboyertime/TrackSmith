# Contributing

Build and test before submitting changes:

```sh
make verify
```

Keep render-callback code allocation-free, lock-free, bounded, and free of file,
network, UI, database, model, and logging operations. Every new plan parameter
needs a typed range, validator coverage, deterministic serialization, and DSP
tests. Do not claim Logic compatibility without recording the Logic/macOS/build
versions and a reproducible host test in `docs/MANUAL_LOGIC_TESTS.md`.

Generated or copyrighted commercial audio must not be committed. Intentional
golden-audio changes require a changelog entry explaining the acoustic change.
