# Automation Retrieval Tool Contract

This package should normally extend the scalable corpus/community retrieval tool already integrated for Packages 1–4.

## Authority

```text
kind: read_only
mutation_authority: none
logic_authority: none
filesystem_authority: package-index reads only
network_authority: none at query time
```

## Suggested request

```json
{
  "query": "why does my fader snap back after I move it",
  "domain": "automation",
  "subdomains": ["automation_modes", "troubleshooting"],
  "logic_version": "12.3",
  "source_type": "vocal",
  "current_context": {
    "automation_mode": "Read",
    "parameter": "Volume",
    "track_or_region": "unknown"
  },
  "limit": 6
}
```

## Suggested response

```json
{
  "package_id": "tracksmith-corpus-005-automation",
  "package_version": "1.0.0",
  "corpus_version": "1.0",
  "matches": [
    {
      "canonical_qa_id": "pkg005.qa.000000",
      "title": "...",
      "candidate_answer": "...",
      "first_experiment": "...",
      "clarification_questions": ["..."],
      "key_distinction": "...",
      "tradeoffs": ["..."],
      "logic_procedure_id": "pkg005.procedure.000000",
      "logic_verification_status": "candidate_unverified_on_installed_logic",
      "source_ids": ["pkg005.source.000001"],
      "evidence_class": "derived_synthesis",
      "review_state": "candidate_not_yet_human_reviewed"
    }
  ],
  "disagreements": [],
  "limitations": [
    "Candidate synthesis; not automatically reviewed truth.",
    "Exact Logic labels are version-scoped."
  ]
}
```

## Bounds

- Maximum 6 canonical matches by default.
- Maximum 2 relevant disagreement records.
- Maximum 8 source references.
- No raw forum post body.
- No full utterance list.
- No arbitrary SQL or file path from model input.
- Query length and output bytes must be bounded.
- Record package/version and selected IDs in the evidence receipt.

## Required evidence label

Use a candidate/community/practitioner label appropriate to the selected sources. Do not label the result `Reviewed` merely because the package validator passed.

## Exact instructions

The retrieval tool may return a candidate procedure ID and status. Exact instructions shown as trusted procedure authority require a separate TrackSmith review/verification path.
