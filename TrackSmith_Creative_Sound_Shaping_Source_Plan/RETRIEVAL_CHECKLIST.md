# Retrieval checklist for Sol

For each paper:

- fetch from the canonical arXiv or publisher location;
- verify `application/pdf`, complete transfer, PDF structure and nontrivial extracted text;
- hash and deduplicate;
- record revision/version and retrieval date;
- inspect supplementary demos and code when available;
- distinguish latest preprints from peer-reviewed versions;
- do not claim deep review until methods, experiments and limitations are read.

For each repository:

- clone the canonical origin at a pinned commit;
- record license and model/data licenses separately;
- inspect issues and reproducibility instructions;
- identify pretrained weights and hardware needs;
- run only isolated offline evaluations before considering integration.

For datasets/models:

- record whether commercial use, redistribution and derived outputs are permitted;
- document consent/provenance and dataset domain limits;
- avoid making a model a production dependency until weights and deployment rights are clear;
- treat recent 2026 preprints as experiments until independently evaluated.
