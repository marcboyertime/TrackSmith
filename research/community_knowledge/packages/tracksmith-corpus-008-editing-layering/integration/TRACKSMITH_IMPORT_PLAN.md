# TrackSmith import plan

- Validate dependencies and namespace before writes.
- Stage Package 008 immutably.
- Merge package/source metadata by namespaced ID.
- Import canonical Q&A, utterances, scenarios, evaluations, disagreements, myths, and candidate records into the scalable retrieval store.
- Preserve raw candidate states; do not promote automatically.
- Rebuild the unified hybrid index and run Package 008 retrieval regressions.
- Expose a bounded read-only retrieval result to the Tutor.
- Persist only compact result IDs/hashes in conversation receipts, not the full corpus text.
- Keep exact Logic procedures behind installed-version review.
