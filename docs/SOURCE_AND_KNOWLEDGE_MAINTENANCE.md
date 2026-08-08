# Source and knowledge maintenance

How production knowledge enters TrackSmith, gets reviewed, and eventually
leaves. The rule underneath all of it:

> A machine-extracted claim is never trusted knowledge. A human promotes it,
> on the record, or it never grounds an answer.

Tooling: `research/scripts/general-tutor-knowledge-pipeline.py`
(`register-source`, `extract`, `review`, `mark-av-reviewed`, `audit`).
The audit runs inside `make verify`.

## 1. Discovery

Start from a gap, not from a source. `research/evaluation/general-production-tutor-v2/gap-map.json`
lists every domain the question library demands, whether reviewed knowledge
covers it, and whether an exact procedure exists. Work the `highPriorityGaps`
list. Collecting sources for domains that are already covered inflates counts
without improving answers.

## 2. Registration

```bash
python3 research/scripts/general-tutor-knowledge-pipeline.py register-source \
  --id apple-logic-123-compressor \
  --title "Logic Pro 12.3 Effects Guide — Compressor" \
  --type officialManual \
  --tier tierAPrimaryOrDirect \
  --handling openDocumentation \
  --rights "official documentation reviewed locally; paraphrased" \
  --locator "pages 88-104" --version "Logic Pro 12.3"
```

Every source records a rights basis and a handling class. There is no default:
if you cannot state how you lawfully hold it, it does not get registered.

**Tiers.** `tierAPrimaryOrDirect` (official docs, standards, peer-reviewed
work, direct TrackSmith measurement, direct Logic verification, user-confirmed
results); `tierBReviewedProfessionalPractice` (experienced practitioner
material, manufacturer education, reputable technical writing, lawfully held
books and courses); `tierCDiscoveryOrAnecdotal` (forums, comments, unverified
short-form). **Tier C can never be promoted.** It surfaces questions and
hypotheses; the pipeline refuses to extract anything but discovery notes from
it.

**Video and course sources.** Record `--transcript`, `--auto-transcript`, and
`--requires-av` honestly. Automatic captions get an automatic limitation note
about mis-transcribed product names. Use `--requires-av` whenever the claim
depends on hearing an A/B, reading a setting on screen, or seeing routing.

Never commit a full transcript or media payload. Register the locator and the
content hash; keep the media local and ignored.

## 3. Extraction

```bash
python3 research/scripts/general-tutor-knowledge-pipeline.py extract \
  --source apple-logic-123-compressor --text /local/notes.txt --locator "p. 92"
```

Candidates land in `research/knowledge/general-tutor-review-queue.json` as
`machineExtracted`. They cannot ground an answer in that state. Extraction
flags any candidate whose wording depends on hearing or seeing something.

## 4. Review

```bash
python3 research/scripts/general-tutor-knowledge-pipeline.py review \
  --id cand.apple-logic-123-compressor.004 --state reviewed \
  --reviewer "marc" --note "matches p.92; bounded to Peak mode" \
  --accepted-text "…"
```

Promotion requires a named reviewer and records the date. The pipeline refuses
to promote when the candidate is discovery-only, the source is Tier C, the
source is superseded, or the claim depends on audiovisual review that has not
been recorded:

```bash
python3 research/scripts/general-tutor-knowledge-pipeline.py mark-av-reviewed \
  --source some-video --reviewer "marc" --note "watched 12:20-13:10; A/B audible"
```

Only record that after actually watching and listening. Reading captions is
not audiovisual review, and the distinction is the whole point of the gate.

States: `discovered → acquired → machineExtracted → awaitingReview → reviewed`
or `directlyVerified`, with `disputed`, `superseded`, and `rejected` as
terminal alternatives.

## 5. Build and verify

```bash
python3 research/scripts/build-general-tutor-knowledge.py   # regenerate
make general-tutor-knowledge-check                          # payload matches source
make general-tutor-knowledge-audit                          # registry + queue + base
make general-tutor-evaluation                               # 518 cases + retrieval
```

The generated Swift embeds the JSON plus its SHA-256; the runtime loader
refuses a payload whose hash does not match and then runs the structural
validator. A trusted claim cannot rest on a superseded source or one still
awaiting audiovisual review, and a reviewed strategy cannot be supported by
unreviewed claims.

## 6. Correction and supersession

Wrong claims get `--state disputed` with a note, not a silent edit. Replaced
sources get a `supersededBy` pointer; the validator then refuses to let
trusted claims rest on them. Historical evidence records are never rewritten —
add a new dated record instead.

## 7. Removal

Delete a candidate by rejecting it (`--state rejected`) so the decision stays
visible. Removing a source entirely means regenerating the knowledge base and
re-running the audit; anything that depended on it fails closed rather than
silently losing its provenance.

## What this pipeline has and has not done

Built and proven by exercising every refusal path. **Not yet fed:** no network
acquisition has been performed and no external or YouTube source has been
ingested. All shipped knowledge derives from reviewed artifacts already in
this repository. The registry and queue files are absent until the first real
registration.
