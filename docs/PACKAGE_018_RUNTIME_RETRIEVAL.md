# Package 018 runtime retrieval

The Tutor remains LLM-first: TrackSmith supplies bounded evidence, read-only tools, and one reversible experiment; the model reasons and writes the response.

`TutorSystemPolicy` version `package018/1` is the sole permanent constitution. Provider adapters carry it unchanged. Its audit records UTF-8 bytes, SHA-256, required invariants, and forbidden evaluation/package markers. Turn receipts add the policy version without rewriting historic receipts.

The production target bundles only `CandidateRetrieval.sqlite` and `CandidateRetrieval.manifest.json`. The 6,212-card P16 projection is retained under `research/community_knowledge/runtime_projection/p16` for import checks and the legacy test oracle. Package 017 remains evaluation-only with zero runtime rows.

At runtime, `CandidateRetrievalIndex` is actor-owned and opens the bundle using SQLite read-only immutable mode. It validates the small manifest/header, uses FTS/BM25 to select an ID pool, lazily decodes only selected card payloads, applies general overlap reranking, question deduplication, and bounded early domain diversity, then returns at most four provisional candidates. It has typed `ready`, `unavailable`, `corrupt`, `versionMismatch`, and `disabled` states. It never exposes local paths or supplies exact Logic navigation.

The live model-facing registry has seven tools. `search_candidate_corpus` is the
seventh, read-only lower-authority tool: it returns one bounded primary candidate,
alternatives/disagreements, and compact selection diagnostics. Its schema has no
package or record identifiers. The index retains package columns only for injected
legacy-oracle tests and pre-payload internal filtering; they never affect score.

The deterministic builder canonicalizes separators, common suffixes, and a compact
consonant skeleton for dropped-vowel tolerance. It stores a compact ranking row and
contentless weighted FTS (`primary=5`, `context=2`, `utterance=0.5`), keeping rich
detail in the one selected JSON payload. AND retrieval falls back to bounded OR when
the AND pool lacks topical diversity. A 26-point general floor plus a two-unique-term
minimum prevents low-evidence candidate claims. Broad host-navigation and vague-status
terms are excluded before retrieval, so an ordinary no-match, an unsupported
"cannot find" request, and an insufficient-evidence report all fail soft instead of
being mapped to a speculative corpus family. This is a shared lexical rule, not a
case, package, record, or score exception.

Tracked local evidence is in `docs/evidence/PACKAGE_018_RUNTIME_RETRIEVAL_REPORT.json`.
On the captured host, three separate readiness samples had a 5.717 ms indexed median
and 26,183.862 ms legacy-oracle median (99.978% faster). `/usr/bin/time -l` median
peak RSS was 12,992,512 versus 506,839,040 bytes. These are local source/runtime
measurements, not installed-app or real-time-thread evidence; the three samples are
reported raw and median only, without an underpowered p95.

Generate or verify the artifact with:

```sh
python3 research/scripts/build_candidate_retrieval_index.py
python3 research/scripts/build_candidate_retrieval_index.py --check
make p18-audit
make p18-diagnostics
```

`package18_audit.py` is local source/index evidence only. It does not claim installed-app, Logic, model-listening, owner-listening, memory, or main-thread evidence.

Package 018 also carries a narrow P17 acceptance repair: pre-level `{}` preferences
migrate to Amateur and v1 preferences decode, while corrupt and future-version
payloads fail closed. Candidate availability and retrieval-family behavior are
level-invariant; Package 017 remains evaluation-only.

## Captured verification

All commands below exited `0` on the Package 018 host unless explicitly noted.

- `python3 research/scripts/import-community-saturation-transient-shaping-v1.py --check` — `COMMUNITY_CORPUS_IMPORT_CHECK_OK`, 6,212 canonical cards.
- Linux CI equivalent: Python syntax; `community_corpus_import.py --check`; deterministic index `--check`; `package17-evaluation.py --check`; `package18_audit.py`; product-resource and generated-drift checks — passed. The post-fix `build_candidate_retrieval_index.py --check` and `package18_audit.py` also passed.
- Clean-checkout CI repair: the Package 001 vocal-quantization preservation tree now has an additive deterministic Git-tracked projection. Its historical 33-file / `3f53c159…` field is retained because it included an ignored local `.DS_Store`; the source-controlled projection is 32 files / `62a04801302256adedb07f489ce06b19712349512d01e150f0c3ee22a49cf57d`. The importer, P10–P15 capture tools, and P16 preservation gate select this explicit projection rather than ambient filesystem contents; immutable source, runtime, evaluation, manifest, queue, and descriptor checks remain enforced. A disposable clean worktree reproduced the old failure and passed after this correction.
- Primary-session Release evidence: `swift build -c release`; TestRunner (104/104); full TutorConversationTests (36/36); named P16/P17/P18 diagnostics, performance/fallback, and P16 evidence audit — passed. The post-fix P18 diagnostic passed 1/1 with indexed readiness about 2 ms and the research-only legacy oracle about 26,295 ms.
- Fresh `xcodegen generate` and unsigned Release `xcodebuild` for Companion and AU using `/tmp/tracksmith-p18-final-derived.VuG2NQ` — passed. Companion app was 65,856 KB, AU 1,612 KB, and the ProductionTutor bundle 40,168 KB. Each built product contained only Info.plist, `CandidateRetrieval.sqlite` (41,119,744 bytes; SHA-256 `99934b5354738f092333091f08c51d6e08cc7a178be95fcf4b157398f8e67935`), and `CandidateRetrieval.manifest.json` (SHA-256 `b208b04db65bf9182ea052269531d7aba6eebec2a1d7cf811b494e9689fde306`). Both resource hashes matched source; app/AU candidate-resource searches found only those two retrieval resources, and the forbidden-marker scan was clean.
- `AudioUnitHostProbe` passed: mean 13.6 µs, p99 18.8 µs, max 64.8 µs against a 2,666.7 µs buffer budget.
- `git diff --check` and Ruby YAML parsing of both CI workflows — passed.

`make verify` ran all import reconstruction targets successfully, then stopped at the existing Package 005 staged audit because its tracked baseline import report lacks required `force_semantics:false`. That condition is present on immutable baseline and unrelated to Package 018. The remaining verify targets were run manually: general knowledge check/audit, Vocal evaluation (89/89), listening selfcheck, Release build, TestRunner, full Tutor tests, and AudioUnitHostProbe. The selfcheck is not listening evidence; no installed-app, Logic, model-listening, or owner-listening claim is made.

Package 019 later adds additive portable attestations for the historical P005/P006
omission. Package 018 baseline fields and historical source evidence remain
preserved, while `PACKAGE_018_RUNTIME_RETRIEVAL_REPORT.json` is a refreshed,
versioned compatibility/migration report rather than a byte-immutable historical
artifact.

## Final evidence boundary

The machine report records aggregate legacy lexical, indexed FTS-pool, and final
rerank metrics separately; only final rerank reports ambiguity. Its abstention
denominator is every frozen case labelled `abstain`: `p18-natural-014` (ordinary
no-match), `p18-natural-026` (cannot find), and `p18-natural-027`
(insufficient evidence). The final stage abstained in all three; the legacy and raw
FTS-pool stages each abstained in one of three. The post-review source index is
41,119,744 bytes (SHA-256 `99934b5354738f092333091f08c51d6e08cc7a178be95fcf4b157398f8e67935`),
now confirmed in both fresh unsigned Release products. It also records
frozen P17-family coverage, policy/index hashes, P17 level invariance, raw local
latency/RSS samples, and all unavailable baseline measurements with reasons.
The next highest-value step is a clean-checkout CI run of the two workflows; no
installed, provider, Logic, model-listening, or owner-listening evidence is claimed.

Ambiguity is intentionally reported as a diagnostic rather than an acceptance
threshold. On the frozen suite it flags 11/15 `expected` cases, but correctly
leaves clear cases unflagged only 1/6 times. Boundary, abstain, and evaluation-only
labels are excluded from this classification score. This poor clear-case specificity
is recorded as a retrieval limitation; no post-freeze threshold retuning was done.
