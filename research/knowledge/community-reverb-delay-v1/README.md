# TrackSmith Reverb + Delay Q&A Corpus v1

**Package sequence:** 4  
**Integrate after:** Vocal + Quantization, Level Balancing + EQ, and Compression + Arrangement + Frequency Allocation  
**Status:** candidate corpus; no record is automatically trusted or promoted

This is a separate Codex-ready research and retrieval package for TrackSmith Tutor. It adds deep coverage of reverb, delay, spatial depth, ambience, rhythmic echo, routing, stereo/phase behavior, sound design, and current Logic Pro workflows.

## Contents

- 300 canonical Q&A records
  - 160 reverb
  - 140 delay
- 6,600 natural user utterances
- 900 multi-turn Tutor scenarios
- 1,500 retrieval-evaluation cases
- 105 registered sources
- 40 preserved disagreements
- 50 myths and anti-patterns
- 300 candidate claims
- 300 candidate strategies
- 300 candidate Logic procedures
- SQLite FTS5 retrieval database
- schemas, validators, query tools, and Codex integration instructions

## Knowledge boundary

Every canonical item, claim, strategy, and Logic procedure is marked:

`candidate_not_yet_human_reviewed`

Numeric values are starting orientations, never presets. Exact Logic paths must be reverified against the installed Logic version before promotion to reviewed exact-instruction authority. Community material is bounded discovery/context evidence, not consensus or truth.

## Reddit boundary

Reddit status for this package is `MANUAL_PUBLIC_SEEDS_ONLY`. No approved bulk Reddit API was available, and this package does not claim a Reddit scrape. Bounded public community seeds informed vocabulary and disagreement mapping; the corpus itself is original paraphrased synthesis grounded in official documentation, acoustics research, professional education, specialist discussions, and community discovery.

## Start

```bash
python3 tools/validate_package.py
python3 tools/query_corpus.py "muddy vocal reverb"
python3 tools/query_corpus.py "vocal delay throw"
```

Codex should begin with `integration/START_HERE_FOR_CODEX.md`.
