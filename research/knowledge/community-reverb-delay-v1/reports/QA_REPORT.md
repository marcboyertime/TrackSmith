# QA Report

Expected package counts:

- Canonical: 300
  - Reverb: 160
  - Delay: 140
- Utterances: 6600
- Multi-turn scenarios: 900
- Retrieval evaluations: 1500
- Sources: 105
- Contradictions: 40
- Myths: 50
- Candidate claims/strategies/procedures: 300 each

Run `python3 tools/validate_package.py` after extraction. The validator checks IDs, cross-file links, source references, review states, database integrity, representative FTS retrieval, and `SHA256SUMS.txt`.
