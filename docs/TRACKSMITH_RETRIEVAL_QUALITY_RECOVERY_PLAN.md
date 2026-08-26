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

The current column is observed Package 019 evidence. The targets apply to the new authoritative benchmark, not retroactively as hard gates on those 240 cases.

The index contains 6,212 cards across 40 domains. The main problems are lossy query normalization, uneven natural-language coverage, unresolved cross-domain collisions, card-first ranking across dense neighboring domains, and one score being asked to handle both ranking and abstention. These are hypotheses to verify with a full-corpus audit and controlled ablations before committing to a replacement model.

The replacement will remain fully local and deterministic:

1. Preserve exact words and add word, bigram, and character features.
2. Preserve structured context as distinct, separately weighted fields.
3. Compare simple family-level baselines against Complement Naive Bayes before selecting an architecture.
4. Rank cards inside the strongest domains or families only after an architecture wins.
5. Decide `noMatch` with a separate calibrated model.
6. Keep ambiguity and raw retrieval diagnostics out of model-facing context.
7. Prove retrieval, tool-loop convergence, and response-plus-card usefulness separately against a new sealed benchmark and controlled ablations.

Planning, benchmark judgment, and quality verdicts use direct xhigh review, not Sol Advisor. Repository-changing implementation will still obey the repository's mandatory implementation policy, but that lane cannot redefine targets or approve its own result.

## Quality and Benchmark Contract

### Existing 240-case regression evidence

- Preserve all 240 Package 019 cases unchanged.
- Rename its former `held_out` partition conceptually to `observed_regression`; every partition has been inspected and none is blind.
- Use it for before/after comparisons, failure-taxonomy continuity, compatibility checks, and regression diagnosis only.
- Continue reporting its top-1, top-4, no-match, ambiguity, domain, and query-form results against the frozen Package 019 baseline.
- Do not use the 240 cases, any individual partition, or their original target arithmetic as a hard release benchmark.
- A material decline must be investigated and explained, but this observed suite cannot independently pass or fail release.
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

- Use separate training-data and benchmark-authoring lanes with different fresh xhigh contexts and separate manifests.
- The training-data author may inspect canonical cards, structured fields, collision reports, and aggregate redacted development reports limited to per-domain counts and metrics. That author may not inspect any raw benchmark query, wording, case ID, label, acceptable-answer set, calibration data, or sealed data, and benchmark phrasing may not be copied or paraphrased into training utterances.
- The benchmark author may inspect the frozen domain ontology and benchmark specification, but may not inspect retrieval-training utterances, model scores, ranked outputs, or implementation failure reports.
- No author may switch lanes for the same benchmark generation.
- A human benchmark steward approves every gold label and preserves meaningful multi-label disagreement.
- The steward records authorship, source visibility, adjudication state, and content hashes before a partition is accepted.
- Benchmark authors and adjudicators must not inspect retriever output while labeling.
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

### 1. Audit the full corpus before choosing a model

Run a deterministic audit over all 6,212 cards, all 40 domains, every runtime-projection source, and every structured retrieval field. Produce both machine-readable results and a concise human report.

Collision analysis must include:

- exact duplicate and normalized duplicate cards;
- near-duplicate titles, questions, utterances, and combined card text using token Jaccard, character n-gram similarity, and MinHash candidate generation;
- same-domain redundancy versus cross-domain semantic collisions;
- pairs that differ only through a structured field that would be lost by flattening;
- broad-domain cards that collide with fine-grained sibling domains;
- repeated generic phrases, boilerplate, and package-template language;
- conflicting domain, category, topic, key-distinction, or intent assignments;
- a ranked collision queue with both members, provenance, similarity channels, and whether the collision is benign, acceptable multi-label evidence, or a correction candidate.

Language-coverage analysis must report per package and per domain:

- card, question, retained-utterance, and unique-utterance counts;
- zero-utterance and low-utterance sources, including the known Packages 010–015 gap;
- normalized vocabulary size, singleton rate, token entropy, and lexical concentration;
- coverage of ordinary language, expert terms, colloquialisms, abbreviations, misspellings, follow-up language, and multi-turn references;
- coverage of objects, symptoms, actions, signal-flow stages, musical references, and explicit near-neighbor distinctions;
- out-of-vocabulary and field-coverage rates for development queries without using calibration or sealed labels;
- unsupported language or locale assumptions, with English-only coverage stated explicitly rather than implied as multilingual support.

Freeze the audit hash before model experiments. Do not repair collisions by deleting source records or changing candidate authority; proposed source corrections require a separate review-preserving migration.

### 2. Stage language enrichment behind an early ablation

Create a retrieval-training-only utterance resource separate from candidate authority and evaluation fixtures. Training authors may use canonical cards, structured fields, and the collision audit, but not benchmark content.

- Draft a pilot of 80 utterances: ten for each of the eight highest-collision or lowest-coverage domains selected by the frozen audit.
- Human-review only those 80 pilot utterances first.
- Compare the winning corpus-only architecture with and without the approved pilot on a frozen development slice.
- Proceed to the remaining 720 approvals only if targeted-domain top-1 improves by at least five absolute points and global top-4 declines by no more than one point.
- If the pilot misses that gate, stop the approval expansion and improve field use, collision handling, or architecture instead.
- If it passes, complete 20 approved utterances for each of the 40 domains: 800 total, including the pilot.

Approved utterances must cover symptom language, jargon, misspellings, multi-turn/follow-up language, and hard-neighbor contrasts. Each record stores positive domains, hard-negative domains, source-card provenance, authorship lane, reviewer state, and `execution_authority: false`. Logic click paths, candidate procedures, test aliases, expected answers, and status promotion are prohibited.

Create a symmetric hard-neighbor graph in which every domain has at least two reviewed neighbors. Examples include Flex Time versus Smart Tempo, recording latency versus plug-in delay, and volume automation versus automation modes.

### 3. Replace lossy query normalization

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

### 4. Preserve structured context as separately weighted fields

Do not flatten all card context into one training or FTS string. Preserve at least these versioned field groups through index construction, candidate generation, scoring, ablation, and diagnostics:

1. Primary identity: title, canonical question, domain, category, and topic.
2. User language: retained utterances and separately approved training utterances.
3. Intent and facets: tags, user intent, TrackSmith domains, and relevant object or signal stage.
4. Diagnostic context: clarification questions and competing hypotheses.
5. Listening and experiment context: listening cues, key distinctions, reversible comparison, stop rule, and undo information.
6. Authority and provenance: review state, verification status, source type, runtime eligibility, and execution authority.

Authority and provenance fields may filter eligibility but must never boost semantic relevance. Search weights for the other field groups are selected on development from a checked-in finite grid. Calibration and sealed cases cannot choose field weights. Every evaluation report must include a field-ablation table so gains cannot be attributed vaguely to "more context."

### 5. Compare family-level architectures before selecting CNB

Implement the same feature contract and candidate pool behind several deterministic, provider-free baselines:

- current BM25 card ranking with domain aggregation;
- BM25 over one synthesized document per domain or reviewed family;
- TF-IDF sparse domain centroids with equal domain priors;
- weighted structured-field centroid retrieval;
- Complement Naive Bayes with equal class priors.

All architectures use the same frozen corpus audit, tokenizer, structured fields, development cases, and latency measurements. Compare both the 40-domain formulation and the reviewed family-level ontology so fine-domain density does not determine the result by accident.

Select the architecture lexicographically by development top-1, top-4, worst-domain top-4, index size, and warm p95 latency. Require the winner to beat the best simpler baseline by at least two absolute development top-1 points or match it within one point while improving development worst-domain top-4 by at least five points or warm p95 latency by at least 20%, with no development top-4 decline greater than one point. Otherwise select the simpler baseline. CNB is a candidate, not the presumed winner.

Use floating-point reference weights and scores during architecture selection. Do not cap to 1,024 weights per domain or quantize model parameters until the winning architecture meets development and calibration quality gates. Afterward, evaluate pruning and signed 16-bit quantization as independent ablations. Accept an optimization only if top-1 and top-4 each decline by no more than 0.5 absolute points on both development and calibration, no domain loses all top-4 coverage, and all no-match and ambiguity thresholds remain satisfied. It must also reduce model-parameter bytes by at least 25% or warm p95 latency by at least 15%. Otherwise ship the floating-point winner.

Record architecture, feature schema, selected parameters, input hashes, logical model hash, baseline comparison, and any accepted optimization in the manifest. Preserve the old policy's historical manifests.

### 6. Use domain- or family-first hybrid retrieval

Candidate generation becomes the union of:

- FTS exact/stem candidates, capped at 256;
- candidate priors from the six strongest predicted domains or families, capped at 32 cards each;
- exact phrase matches and separately scored structured-field matches.

Ranking becomes two-stage only if the architecture comparison supports it:

1. Rank domains or families using the winning sparse model plus aggregated evidence from their best three candidate cards.
2. Rank cards inside those domains or families using weighted reciprocal-rank fusion over domain/family rank, primary-field BM25, exact phrase and bigram coverage, each structured context field, and approved utterance coverage.

Search fusion weights over `{0.5, 1, 2, 4}` and reciprocal-rank constant `{20, 60}` on development cases. Select lexicographically by top-1, top-4, worst-domain top-4, then latency. Do not tune against calibration or sealed cases.

Preserve one selected card per domain, at most two cards from one package, at most four returned cards, a 16 KiB model-facing cap, and existing typed integrity failures. Do not silently fall back from a corrupt v2 index.

### 7. Separate abstention from ranking

Create a deterministic matchability score using strongest domain evidence, top-1/top-2 margin, entropy, exact lexical coverage, cross-channel agreement, out-of-vocabulary ratio, and viable candidate-pool density.

Select non-negative normalized feature weights from `{0, 0.5, 1, 2}` using development cases. On calibration, choose the midpoint of the widest contiguous threshold range satisfying both 90% precision and 90% recall. If no such range exists, fail the phase rather than weakening the target.

`noMatch` must remain distinct from index missing, corrupt, disabled, or version-mismatched; malformed payload; query failure; an ambiguous but useful result; and a valid problem paired with an unsupported execution request.

### 8. Remove ambiguity and raw diagnostics from model-facing context immediately

Before ranking experimentation, reduce the live Tutor projection to the minimum safe candidate payload.

- Remove model-facing ambiguity flags, ambiguity scores, score margins, confidence values, raw BM25 or model scores, token/field matches, rank explanations, database metadata, and other retrieval diagnostics.
- Keep ambiguity labels, confusion details, scores, and thresholds evaluation-only even if the internal detector later exceeds its metric target.
- Do not automatically re-enable an ambiguity hint after validation; any future exposure requires a separate reviewed interface change.
- Keep only sanitized provisional candidate content, bounded safe context, and the existing typed availability or `noMatch` outcome needed by the Tutor.
- Do not expose record IDs, package IDs, SQLite details, procedures, Logic navigation, evaluation metadata, or test aliases.
- Add projection tests proving forbidden fields cannot reach the system prompt, tool result, transcript, logs, or model request.

The internal ambiguity detector may still be calibrated from domain margin, entropy, competing clauses, sibling evidence, and channel disagreement. Its balanced-accuracy target remains an evaluation metric, not model authority.

### 9. Add tool-loop convergence and response-plus-card evaluation

Treat retrieval quality, tool-loop behavior, and final response quality as three linked but distinct workstreams.

Tool-loop traces must record evaluation-only state transitions without exposing diagnostics to the model. Measure:

- whether retrieval is called when relevant and skipped when unnecessary;
- repeated identical or semantically unchanged queries;
- reformulation novelty and whether a second call adds a new useful domain;
- repeated cards and shrinking or non-improving candidate sets;
- behavior after `noMatch`, disabled, unavailable, corrupt, and query-failed outcomes;
- whether the Tutor converges to a final answer rather than searching indefinitely.

The expected policy is one retrieval call for an ordinary single-intent question and no more than two calls when a genuinely new clarification or reformulation can change the result. Stop after an identical query, no new domain and no new card in the top four, or a terminal typed failure. The Tutor must still provide an honest clarification or safe response when retrieval cannot help.

Score the final response and returned cards together on diagnosis-family support, card relevance, evidence honesty, correct provisional framing, reversible-experiment completeness, and whether the final answer uses rather than merely repeats card content. Preserve the natural model-authored response requirement.

Run paired candidate-enabled and candidate-disabled ablations on a frozen stratified set of 120 scenarios: 80 matchable cases covering every domain twice, 20 balanced no-match cases, and 20 multi-turn or typed-failure stress cases. Use identical prompts, context, model configuration, and three repetitions with randomized condition order. Also retain ranking-only scores so a good response cannot hide poor cards and good cards cannot hide a poor response.

Blind adjudicators score both conditions on five shared dimensions from 0 to 2: diagnosis support, evidence honesty, provisional framing, reversible-experiment completeness, and usefulness. Their sum is the 0–10 shared response score. Candidate-enabled outputs receive one additional 0–2 card-contribution score covering card relevance and actual integration; the 0–12 response-plus-card score is reported separately and is never substituted for the shared paired comparison. Average adjudicators and repetitions within each scenario before aggregating scenarios.

Candidate-enabled operation must satisfy every gate:

- zero additional forbidden-authority or safety violations;
- mean evidence-honesty and provisional-framing scores no more than 0.1 below the disabled condition on their 0–2 scales;
- mean paired shared-response improvement of at least 0.5 points on the 0–10 scale;
- strictly positive paired improvement in at least 55% of scenarios, with ties counted as neutral rather than positive;
- mean response-plus-card score of at least 9 of 12 and mean card contribution of at least 1.5 of 2;
- non-convergent tool-loop rate no greater than 5% and no more than two percentage points above the disabled condition.

If candidate-enabled responses do not outperform the disabled condition, do not compensate with more model-facing diagnostics. Revisit card projection, retrieval triggering, or the value of candidate context.

### Interfaces and compatibility

- Keep the public retrieval and Tutor tool call surface stable except for removing unsafe model-facing diagnostic fields.
- Add versioned internal diagnostics for tests and evaluation only.
- Extend SQLite and manifest schemas without altering Package 001–019 IDs, migrations, registries, review states, or source records.
- Keep the LLM as the primary reasoner and final response author.
- Retrieval remains provisional, read-only evidence and never becomes proof of diagnosis, listening, Logic state, or procedure authority.

## Execution Sequence and Exit Gates

### Phase 0 — Freeze truth and reduce model-facing exposure

- Capture clean-commit hashes, index identity, policy versions, baseline metrics, latency, and per-case failures.
- Mark all 240 existing cases as observed regression evidence, not release authority.
- Remove model-facing ambiguity and raw retrieval diagnostics while preserving internal evaluation capture and typed failures.
- Add tests proving the removed fields cannot reach tool output, model requests, transcripts, or logs.

Exit: the baseline reproduces exactly in Swift and Python, the old suite is frozen as diagnostic evidence, and the live projection contains only sanitized provisional cards and typed outcomes.

### Phase 1 — Complete the full-corpus audit

- Audit every card and separately weighted field for exact duplicates, near-duplicates, cross-domain collisions, boilerplate, coverage gaps, and language assumptions.
- Produce per-domain/package coverage tables, the ranked collision queue, and the initial hard-neighbor graph.
- Freeze machine-readable and human-readable audit hashes before changing retrieval training data.

Exit: all 6,212 cards and 40 domains reconcile to the runtime projection, every collision is classified or queued, and no source record or authority state has been silently changed.

### Phase 2 — Establish separated authorship and the new benchmark

- Launch distinct fresh training-data and benchmark-authoring contexts with documented visibility boundaries.
- Finalize the 40-domain and family-level ontologies plus acceptable multi-label mappings.
- Draft, adjudicate, partition, and seal the 600-case benchmark.
- Verify no near-duplicate benchmark/training pair exceeds 0.70 normalized token-Jaccard similarity.
- Commit only development, calibration, benchmark specification, authorship manifests, and sealed-archive hash.

Exit: partition counts, authorship separation, human adjudication, hashes, and runtime-exclusion scans pass.

### Phase 3 — Implement and parity-test feature extraction

- Implement the new normalization and sparse feature pipeline.
- Preserve primary, utterance, intent/facet, diagnostic, listening/experiment, and authority/provenance fields separately.
- Produce shared normalization fixtures and compare Python versus Swift features exactly.
- Add field-isolation and field-ablation reporting.

Exit: feature IDs, per-field values, and logical scores match across languages, with no regression in eligibility or integrity behavior.

### Phase 4 — Compare corpus-only architectures

- Implement card BM25 aggregation, family BM25, TF-IDF centroids, structured-field centroids, and CNB behind one evaluation interface.
- Compare 40-domain and family-level variants on the same frozen development set.
- Keep all reference weights floating point.
- Select the simplest qualifying winner under the predeclared lexicographic rule.

Intermediate gate:

- Development top-1 at least 70%.
- Development top-4 at least 90%.
- No domain completely absent from top 4.
- The selected architecture beats the best simpler baseline by two development top-1 points or matches within one point while improving development worst-domain top-4 by at least five points or warm p95 latency by at least 20%, with no development top-4 decline greater than one point.
- If missed, revisit collisions, structured fields, or family definitions; do not conceal ranking failures with abstention or default to CNB.

### Phase 5 — Run the 80-approval enrichment ablation

- Select the eight pilot domains strictly from the frozen collision/coverage audit.
- Draft and human-approve ten training utterances per pilot domain.
- Rebuild the winning corpus-only architecture with no other changes.
- Compare targeted-domain and global metrics against the corpus-only winner.

Exit: authorize the remaining 720 approvals only if targeted-domain top-1 gains at least five points and global top-4 loses no more than one point. Otherwise stop enrichment and retain the corpus-only architecture.

### Phase 6 — Complete justified enrichment and hybrid ranking

- If authorized, complete 800 total approvals with 20 per domain.
- Re-run the architecture comparison because enrichment may change which simple model wins.
- Add the candidate union, domain/family aggregation, structured-field fusion, and card selection rules to the new winner.
- Run error reports by domain, family, field, query form, hard-neighbor pair, and package.

Exit: development ranking gates pass with the final approved training set and architecture recorded in the manifest.

### Phase 7 — Calibrate abstention and internal ambiguity

- Fit only the small aggregate decision weights on development.
- Select thresholds only on calibration.
- Lock parameters and regenerate the deterministic index.

Exit:

- Development and calibration meet all primary targets.
- Existing 240-case results are reported against the frozen baseline as regression evidence without becoming a release veto.
- Ambiguity metrics remain evaluation-only regardless of whether the internal target passes.

### Phase 8 — Optimize only after the architecture wins

- Measure the floating-point winner first.
- Ablate vocabulary pruning, weight pruning, and signed 16-bit quantization independently.
- Accept only optimizations that preserve the development and calibration tolerances, domain coverage, and thresholds while reducing model-parameter bytes by at least 25% or warm p95 latency by at least 15%.
- Keep floating-point parameters if optimization evidence is not favorable.

Exit: the manifest identifies the reference architecture, every optimization delta, and the exact shipped representation.

### Phase 9 — Tool-loop and combined-quality workstream

- Add deterministic tool-loop trace validation for call necessity, duplicate queries, reformulation novelty, candidate-set change, terminal outcomes, and convergence.
- Run paired candidate-enabled and candidate-disabled scenarios over development and calibration with identical model conditions.
- Score ranking, final response, and response-plus-card quality separately.
- Human/xhigh adjudication verifies candidate contribution, evidence honesty, reversible-experiment completeness, and natural model-authored language.

Exit: ordinary cases converge in one retrieval call, justified clarifications converge in no more than two, terminal failures do not loop, and candidate-enabled responses add grounded value without safety or honesty regression.

### Phase 10 — Performance and integrity gate

Run release-mode benchmarks on `macos-15` and the existing free-compute lanes:

- Index size no more than 64 MiB; current baseline is 41.1 MB.
- Cold index readiness no more than 150 ms.
- Warm p95 query latency no more than 50 ms.
- Maximum warm query latency no more than 100 ms.
- Maximum output 16 KiB and four candidates.
- Logical index/model hash identical across rebuilds.
- Byte-identical database on the pinned SQLite toolchain.
- No raw aliases, benchmark data, candidate procedures, forbidden authority fields, ambiguity fields, scores, margins, or retrieval diagnostics visible through the Tutor resource projection.
- Existing Package 017–019 integrity, compatibility, and typed-failure tests remain green.

### Phase 11 — One-shot blind evaluation

- Run the frozen release candidate against the external sealed archive.
- Emit only aggregate metrics, per-slice counts, build hashes, and the archive hash.
- Do not reveal or inspect case text until the pass/fail decision is recorded.

Exit: every blind quality gate passes. Otherwise, declare the archive observed, diagnose honestly, and prepare a fresh sealed set after corrections.

### Phase 12 — Tutor and installed-product acceptance

- Exercise clear, ambiguous, no-match, candidate-disabled, index-failure, and authority-adversarial prompts through the real Tutor tool boundary.
- Confirm the Tutor still writes a natural model-authored answer.
- Verify one reversible experiment, preserved baseline, listening target, tradeoff, stop rule, and undo path.
- Confirm it does not claim to have heard audio, edited Logic, verified a candidate procedure, or converted provisional retrieval into authority.
- Confirm model requests contain no ambiguity signal or raw retrieval diagnostics and tool calls satisfy the convergence policy.
- Run the complete local and GitHub CI surfaces, obtain direct xhigh judgment on the final diff and evidence, then merge and verify local/remote synchronization.

Retrieval metrics prove retrieval only. Installed Tutor behavior, model judgment, and owner listening remain separately reported evidence classes.

## Rollback and Stop Rules

- Ship v2 only as a versioned policy/index change. Rollback is a normal revert to the prior policy and generated index, never a silent runtime fallback.
- Stop if benchmark leakage, source-status mutation, procedure exposure, or evaluation data enters runtime resources.
- Stop and reseal affected data if training and benchmark authorship boundaries are crossed.
- Stop if quality improvements depend on provider reranking or non-deterministic Apple embeddings.
- Stop if top-4 gains come from returning redundant cards rather than domain diversity.
- Stop tuning thresholds when ranking is the actual failure.
- Do not authorize the remaining 720 human approvals when the 80-record pilot misses its ablation gate.
- Do not quantize, prune, or cap the winning model before the floating-point architecture passes quality gates.
- Do not restore model-facing ambiguity or raw diagnostics to improve response scores.
- Stop and revisit candidate projection or retrieval triggering if candidate-enabled responses do not add value over the disabled condition.
- Preserve ambiguity and human disagreement with multi-label gold answers rather than rewriting labels to match the retriever.
- No paid/provider run is required for the hard retrieval gate; any later model-response study remains separate and cannot substitute for deterministic acceptance.
