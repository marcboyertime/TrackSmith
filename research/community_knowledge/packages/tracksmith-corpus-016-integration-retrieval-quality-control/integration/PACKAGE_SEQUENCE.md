# Package Sequence

Package 016 depends on Packages 001–015. It does not replace them. It registers, migrates, validates and indexes them additively.

Legacy Package 001–004 archives are normalized during import. Their original IDs and review/verification fields remain in development metadata. Packages 005–015 are ingested using their native stable schema.

The alternate archive `tracksmith_vocal_qa_corpus_v1.zip` is treated as a superseded/alternate Package 001 artifact and excluded by default unless explicitly mapped.
