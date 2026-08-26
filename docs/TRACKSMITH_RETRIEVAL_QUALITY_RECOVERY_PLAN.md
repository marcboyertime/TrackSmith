# TrackSmith Retrieval Quality Recovery Plan

## Summary

The current deterministic retriever is too far below target for incremental BM25 tuning:

| Metric | Current | Target | Gap |
|---|---:|---:|---:|
| Top-1 acceptable | 42.65% | 80% | 37.35 points |
| Top-4 recall | 70.59% | 95% | 24.41 points |
| No-match precision | 50% | 90% | 40 points |
| No-match recall | 75% | 90% | 15 points |
| Ambiguity balanced accuracy | 64.99% | 75% | 10.01 points |

The index contains 6,212 cards across 40 domains. The main problems are lossy query normalization, weak natural-language coverage in Packages 010–015, card-first ranking across dense neighboring domains, and one score being asked to handle both ranking and abstention.

The replacement will remain fully local and deterministic:

1. Preserve exact words and add word, bigram, and character features.
2. Classify the likely problem domain before selecting cards.
3. Rank cards inside the strongest domains.
4. Decide `noMatch` with a separate calibrated model.
5. Detect ambiguity separately and keep it model-withheld until validated.
6. Prove the result against both the existing regression suite and a new sealed benchmark.

Planning, benchmark judgment, and quality verdicts use direct xhigh review, not Sol Advisor. Repository-changing implementation will still obey the repository's mandatory implementation policy, but that lane cannot redefine targets or approve its own result.

## Quality and Benchmark Contract

### Existing suite

- Preserve all 240 Package 019 cases unchanged.
- Rename its former `held_out` partition conceptually to `observed_regression`; it has already been inspected and is no longer blind.
- Require the complete 240-case suite to meet all four primary targets.
- Require its 72-case observed-held-out partition to reach:
  - At least 55 of 68 positive cases correct at top 1.
  - At least 65 of 68 positive cases present in the top 4.
  - All four no-match cases correctly rejected, with no false abstains.
- Preserve the current results as a frozen before-state rather than rewriting historical evidence.

### New 600-case authoritative benchmark

Create three evaluation-only partitions:

- Development: 300 cases.
- Calibration: 150 cases.
- Sealed blind: 150 cases.

Distribution:

| Partition | Matchable cases | No-match cases |
|---|---:|---:|
| Development | 240: six per runtime domain | 60 |
| Calibration | 120: three per runtime domain | 30 |
| Sealed blind | 120: three per runtime domain | 30 |

For matchable cases:

- Cover all 40 runtime domains equally.
- Split each partition evenly between clear and genuinely ambiguous cases.
- Label every case with one or more acceptable domains and explicit hard-negative sibling domains.
- Distribute eight query forms using a deterministic Latin-square assignment:
  - ordinary natural language;
  - jargon or colloquial language;
  - misspelled or noisy input;
  - multiple symptoms;
  - multi-turn context;
  - follow-up outcome language;
  - unavailable Logic/listening context;
  - adversarial authority, unsupported-product, or procedure traps.

For no-match cases, balance six classes:

- insufficient description;
- contextless follow-up;
- genuinely out-of-domain request;
- shopping-only request with no diagnosable problem;
- execution/navigation-only request with no safe evidence;
- nonsense or unrecoverable text.

A request for an unsupported plug-in or exact Logic action is not automatically `noMatch` when an underlying audio problem remains retrievable.

### Benchmark governance

- Xhigh drafts cases and proposed labels.
- A human benchmark steward approves every gold label and preserves meaningful multi-label disagreement.
- Benchmark authors must not inspect retriever output while labeling.
- Development and calibration cases may be versioned as evaluation-only data.
- The sealed archive remains outside the repository and runtime resources; only its specification, count, and SHA-256 are committed.
- A blind run is one-shot. Once results or labels are inspected, that archive becomes observed and can never again support a blind release claim.
- If the blind run fails, fix using observed evidence and create a fresh sealed 150-case partition.
- Raw benchmark text, labels, IDs, and expected answers must never enter the live SQLite index or Tutor projection.

### Hard release gates

On both the new calibration and sealed partitions:

- Top-1 acceptable: at least 96 of 120, or 80%.
- Top-4 recall: at least 114 of 120, or 95%.
- No-match precision: at least 90%.
- No-match recall: at least 27 of 30, or 90%.
- Ambiguity balanced accuracy: at least 75%.
- Clear-case and ambiguous-case recall must each be at least 70%.
- No runtime domain may score 0 of 3 for top-4 recall.
- Report Wilson confidence intervals and every domain/sibling confusion, but retain the point targets as the formal gates.

## Retriever and Data Changes

### 1. Repair the natural-language coverage gap

Create a retrieval-training-only utterance resource separate from candidate authority and evaluation fixtures.

For each of the 40 domains:

- Draft 24 utterances from canonical candidate content without seeing benchmark cases.
- Require at least 20 human-approved utterances per domain.
- Cover symptom language, jargon, misspellings, multi-turn/follow-up language, and hard-neighbor contrasts.
- Record positive domains, hard-negative domains, source-card provenance, reviewer state, and `execution_authority: false`.
- Prohibit Logic click paths, candidate procedures, test aliases, expected answers, or status promotion.
- Keep all original candidate review and verification states unchanged.

Create a symmetric hard-neighbor graph in which every domain has at least two reviewed neighbors. Examples include Flex Time versus Smart Tempo, recording latency versus plug-in delay, and volume automation versus automation modes.

### 2. Replace lossy query normalization

In `CandidateRetrievalIndex.swift`:

- Remove consonant-skeleton replacement.
- Remove the first-six-terms limit.
- Process up to 2 KiB or 128 normalized tokens.
- Normalize with a versioned cross-language contract: Unicode compatibility decomposition, diacritic removal, POSIX lowercase, alphanumeric tokenization, and whitespace collapse.
- Preserve exact tokens as the strongest channel.
- Add exact word bigrams.
- Add a lower-weight light-stem channel.
- Apply stop-word filtering both before and after stemming.
- Add boundary-marked character 3–5 grams for non-stop tokens of at least four characters.
- Downweight conversational boilerplate conservatively; never delete symptom-bearing clauses merely because they resemble follow-up language.
- Add Python/Swift parity fixtures covering suffixes, punctuation, misspellings, Unicode, long queries, and empty input.

### 3. Build a deterministic sparse domain model

Extend `build_candidate_retrieval_index.py` to train a 40-class Complement Naive Bayes domain model from runtime-eligible card text and approved retrieval utterances.

Model contract:

- Equal class priors so dense domains cannot win merely from card count.
- Word unigram, word bigram, light-stem, and character-gram channels.
- Vocabulary capped at 50,000 features.
- Character features require document frequency of at least three; word features require at least two.
- Retain the 1,024 most discriminative sparse weights per domain.
- Quantize weights to signed 16-bit values with a recorded per-channel scale.
- Select smoothing from `{0.1, 0.3, 1.0}` using development results.
- Use fixed input ordering, no random shuffle, and no external ML/runtime dependency.
- Record trainer version, input hashes, feature schema, selected parameters, logical model hash, and exclusions in the manifest.

SQLite additions should include feature metadata, sparse domain weights, reviewed neighbor relationships, static domain-card priors, and calibrated decision parameters. Version the new policy as `tracksmith-hybrid-sparse-domain-v1`; preserve the old policy's historical manifests.

### 4. Use domain-first hybrid retrieval

Candidate generation becomes the union of:

- FTS exact/stem candidates, capped at 256.
- Candidate priors from the six strongest predicted domains, capped at 32 cards per domain.
- Exact phrase and structured-facet matches.

Ranking becomes two-stage:

1. Rank domains using the sparse domain model plus aggregated evidence from their best three candidate cards.
2. Rank cards inside those domains using weighted reciprocal-rank fusion over:
   - domain rank;
   - primary-field BM25;
   - exact phrase and bigram coverage;
   - structured facet/context coverage;
   - approved retrieval-utterance coverage.

Search fusion weights over `{0.5, 1, 2, 4}` and reciprocal-rank constant `{20, 60}` on development cases. Select lexicographically by top-1, top-4, worst-domain top-4, then latency. Do not tune against calibration or sealed cases.

Preserve:

- One selected card per domain.
- At most two cards from one package.
- At most four returned cards.
- Maximum 16 KiB model-facing output.
- No record IDs, package IDs, SQLite details, procedures, navigation, or evaluation metadata in Tutor output.
- Existing typed integrity failures; do not silently fall back from a corrupt v2 index.

### 5. Separate abstention from ranking

Create a deterministic matchability score using:

- strongest domain evidence;
- top-1/top-2 domain margin;
- posterior entropy;
- exact lexical coverage;
- agreement among domain, FTS, and facet channels;
- out-of-vocabulary ratio;
- viable candidate-pool density.

Select non-negative normalized feature weights from `{0, 0.5, 1, 2}` using development cases. On calibration, choose the midpoint of the widest contiguous threshold range satisfying both 90% precision and 90% recall. If no such range exists, fail the phase rather than weakening the target.

`noMatch` must remain distinct from:

- index missing, corrupt, disabled, or version-mismatched;
- malformed selected payload;
- query failure;
- an ambiguous but still useful result;
- a valid audio problem paired with an unsupported execution request.

### 6. Separate ambiguity detection

Build a second calibrated score from domain margin, entropy, number of competing clauses, sibling-domain evidence, and cross-channel disagreement.

- Tune weights on development.
- Select the midpoint of the widest calibration threshold interval reaching 75% balanced accuracy and both class recalls of at least 70%.
- Keep the signal internal while below threshold.
- Once activated, expose only a safe "multiple plausible directions" indication and diverse candidates—not labels, probabilities, or evaluation vocabulary.
- Never force a top-1 certainty claim merely because the retrieval API returns an ordered list.

### Interfaces and compatibility

- Keep the public retrieval and Tutor tool call surface unchanged.
- Add internal versioned diagnostics for tests and evaluation only.
- Extend the SQLite and manifest schemas without altering Package 001–019 IDs, migrations, registries, review states, or source records.
- Keep the LLM as the primary reasoner and final response author.
- Retrieval remains provisional, read-only evidence and never becomes proof of diagnosis, listening, Logic state, or procedure authority.

## Execution Sequence and Exit Gates

### Phase 0 — Freeze truth

- Capture clean-commit hashes, index identity, policy versions, baseline metrics, latency, and per-case failures.
- Mark the current suite as observed regression.
- Add leakage and provenance audits before generating new data.

Exit: the baseline reproduces exactly in Swift and Python.

### Phase 1 — Build the evaluation and training firewalls

- Finalize the 40-domain ontology and sibling graph.
- Draft and human-review retrieval-training utterances.
- Draft, adjudicate, partition, and seal the 600-case benchmark.
- Verify no near-duplicate benchmark/training pair exceeds 0.70 normalized token-Jaccard similarity.
- Commit only development, calibration, benchmark specification, and sealed-archive hash.

Exit: all domain counts, review states, hashes, and exclusion scans pass.

### Phase 2 — Implement and parity-test feature extraction

- Implement the new normalization and sparse feature pipeline.
- Produce shared normalization fixtures and compare Python versus Swift features exactly.
- Keep v1 and v2 evaluation outputs available side by side without runtime fallback.

Exit: feature IDs and logical scores match across languages, with no regression in integrity behavior.

### Phase 3 — Implement domain-first ranking

- Build the v2 index and sparse domain model.
- Add candidate union, domain aggregation, and reciprocal-rank fusion.
- Run error reports by domain, query form, hard-neighbor pair, and package.

Intermediate gate:

- Development top-1 at least 70%.
- Development top-4 at least 90%.
- No domain completely absent from top 4.
- If missed, improve reviewed training coverage or model structure; do not conceal ranking failures with abstention.

### Phase 4 — Calibrate abstention and ambiguity

- Fit only the small aggregate decision weights on development.
- Select thresholds only on calibration.
- Lock parameters and regenerate the deterministic index.

Exit:

- Development and calibration meet all primary targets.
- Existing 240-case regression meets its target contract.
- Ambiguity stays withheld unless its independent activation gates pass.

### Phase 5 — Performance and integrity gate

Run release-mode benchmarks on `macos-15` and the existing free-compute lanes:

- Index size no more than 64 MiB; current baseline is 41.1 MB.
- Cold index readiness no more than 150 ms.
- Warm p95 query latency no more than 50 ms.
- Maximum warm query latency no more than 100 ms.
- Maximum output 16 KiB and four candidates.
- Logical index/model hash identical across rebuilds.
- Byte-identical database on the pinned SQLite toolchain.
- No raw aliases, benchmark data, candidate procedures, or forbidden authority fields visible through the Tutor resource projection.
- Existing Package 017–019 integrity, compatibility, and typed-failure tests remain green.

### Phase 6 — One-shot blind evaluation

- Run the frozen release candidate against the external sealed archive.
- Emit only aggregate metrics, per-slice counts, build hashes, and the archive hash.
- Do not reveal or inspect case text until the pass/fail decision is recorded.

Exit: every blind quality gate passes. Otherwise, declare the archive observed, diagnose honestly, and prepare a fresh sealed set after corrections.

### Phase 7 — Tutor and installed-product acceptance

- Exercise clear, ambiguous, no-match, index-failure, and authority-adversarial prompts through the real Tutor tool boundary.
- Confirm the Tutor still writes a natural model-authored answer.
- Verify one reversible experiment, preserved baseline, listening target, tradeoff, stop rule, and undo path.
- Confirm it does not claim to have heard audio, edited Logic, verified a candidate procedure, or converted provisional retrieval into authority.
- Run the complete local and GitHub CI surfaces, obtain direct xhigh judgment on the final diff and evidence, then merge and verify local/remote synchronization.

Retrieval metrics prove retrieval only. Installed Tutor behavior, model judgment, and owner listening remain separately reported evidence classes.

## Rollback and Stop Rules

- Ship v2 only as a versioned policy/index change. Rollback is a normal revert to the prior policy and generated index, never a silent runtime fallback.
- Stop if benchmark leakage, source-status mutation, procedure exposure, or evaluation data enters runtime resources.
- Stop if quality improvements depend on provider reranking or non-deterministic Apple embeddings.
- Stop if top-4 gains come from returning redundant cards rather than domain diversity.
- Stop tuning thresholds when ranking is the actual failure.
- Preserve ambiguity and human disagreement with multi-label gold answers rather than rewriting labels to match the retriever.
- No paid/provider run is required for the hard retrieval gate; any later model-response study remains separate and cannot substitute for deterministic acceptance.
