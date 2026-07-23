# TrackSmith research-ingestion contract

Version: 1.0  
Effective: 2026-07-14  
Implementation: `ResearchIngestion` Swift package and `ResearchIngestCLI`

## Purpose

TrackSmith does not treat a successful HTTP request, a public URL, a cloned
repository, or an archive checksum as proof that a source is usable. A capture
becomes research evidence only after identity, rights handling, transport, media
type, file integrity, and minimum content quality have been recorded and
validated. Deep-review status is a separate human judgment and is never inferred
from ingestion success.

The implementation supersedes the permissive downloader discussed in
`TRACKSMITH_RESOURCE_REVIEW.md`. It never overwrites user-supplied research
artifacts and does not mutate the source file passed to `ingest-file`.

## Required declaration

Every capture request records:

- stable `resource_id`, title, author or publisher, and evidence role;
- canonical source URL and exact retrieval URL;
- source/document version, kept distinct from retrieval date;
- capture mode and allowed media types;
- minimum byte, page, and useful-text requirements;
- handling class, rights basis, license status, optional SPDX identifier, and
  whether the artifact is local-use-only;
- replacement policy, exact superseded hash where relevant, and a human reason;
- source notes that remain distinct from the source payload.

`redistributable` is accepted only with a verified SPDX license and
`local_use_only == false`. This is an engineering handling rule, not a legal
opinion or a grant of model-training rights.

The operational handling classes are:

| Class | TrackSmith behavior |
|---|---|
| `redistributable` | Capture may be stored and redistributed for the declared use; license and notices still travel with it. |
| `internalReference` | Validated payload may be retained locally; do not redistribute or infer training rights. |
| `linkAndNotes` | Store the canonical URL and original TrackSmith notes, but no source payload. |
| `licenseReviewRequired` | Quarantine product use until the intended use and dependency chain are reviewed. |

## Retrieval and validation sequence

`ResearchIngestCLI fetch` uses a nonpersistent URL session and a temporary
download location. Before content-addressed publication, the validator performs:

1. absolute canonical and retrieval URL validation;
2. exact HTTP 200 enforcement for payload captures;
3. rejection of HTTP 206 and any `Content-Range` response;
4. `Content-Length` comparison when the response exposes one;
5. media-type normalization and allow-list comparison;
6. minimum byte count;
7. format-specific integrity and quality checks;
8. SHA-256 over the exact received representation;
9. duplicate/replacement evaluation;
10. atomic publication of accepted objects and an append-only audit record.

### PDF

A PDF must have the `%PDF-` signature, an EOF marker within the final 4096
bytes, parse successfully with PDFKit, meet the declared page minimum, and—when
required—expose enough sampled extractable text. Passing these checks does not
prove equations or figures are visually faithful. Standards, equations, UI
screenshots, and scan-heavy sources still require rendered-page visual review,
which is recorded in the deep-source synthesis rather than fabricated by the
ingestor.

### HTML

HTML must have a document root and enough visible text after scripts, styles,
comments, and markup are removed. Known JavaScript-required, bot-check,
access-denied, and error-shell markers are rejected when the payload lacks
substantial visible content. Apple DocC shell pages therefore cannot silently
stand in for the corresponding content endpoint.

### Text and binary

Text must be valid UTF-8 and meet its useful-text threshold. Generic binary
captures receive transport, type, length, and hash checks only; their manifest
explicitly says a format-specific semantic validator is still required.

## Immutable storage and audit history

The archive layout is content-addressed:

```text
ARCHIVE_ROOT/
├── objects/<sha256>.<type>
├── quarantine/<sha256>.<type>
└── manifests/
    ├── current/<resource_id>.json
    └── history/<retrieval-time>-<resource_id>-<audit-id>.json
```

Accepted object bytes are never replaced. A repeated hash reuses the existing
object. Every accepted, duplicate, rejected, link-only, and Git-pinning attempt
gets a distinct history record. `current` is only a pointer manifest for the
latest accepted identity; replacing that pointer never removes the old object or
history.

Invalid, partial, mislabeled, shell-only, corrupted, or policy-conflicting
payloads are written under `quarantine` by immutable hash and are not published
as current evidence. A caller receives a failure even though the forensic bytes
and audit record are retained.

## Canonical-source replacement policy

Changed bytes under an existing `resource_id` fail closed by default.

- `rejectDifferentPayload`: default; the current record remains unchanged.
- `appendNewDocumentVersion`: requires a different `source_version` and an
  explicit replacement reason. Both accepted versions remain addressable.
- `supersedeNamedNoncanonicalPayload`: requires the exact prior SHA-256 and an
  explicit reason, for cases such as replacing a regenerated/corrupted copy with
  the canonical publisher original. The prior bytes and provenance remain.

A retrieval date alone is not a new document version. A mutable “current” URL
must not silently rewrite historical evidence.

## Git checkout handling

TrackSmith does not bulk-copy or treat a mutable checkout as a stable source.
`GitCheckoutInspector` requires:

- a local Git worktree;
- a full 40–64 digit object ID for `HEAD`;
- optional equality with a caller-pinned expected commit;
- a clean tracked and untracked worktree;
- an `origin` URL matching the declared canonical or retrieval repository URL.

The archive records the immutable commit and remote provenance, not the mutable
working directory. Licenses, notices, model weights, datasets, generated assets,
and transitive dependencies still require separate review.

## Command-line use

```bash
swift run ResearchIngestCLI fetch REQUEST.json ARCHIVE_ROOT
swift run ResearchIngestCLI ingest-file REQUEST.json INPUT ARCHIVE_ROOT MEDIA_TYPE
swift run ResearchIngestCLI link REQUEST.json ARCHIVE_ROOT
swift run ResearchIngestCLI git REQUEST.json CHECKOUT ARCHIVE_ROOT EXPECTED_COMMIT
```

The request is a JSON encoding of `ResearchIngestionRequest`. The command prints
the resulting `ResearchCaptureRecord`. Failed payload captures exit nonzero after
quarantine and audit publication.

## Evidence boundary

An `accepted` record proves only that the declared representation passed the
implemented ingestion checks. It does not prove:

- that the source is authoritative when the declared URL was wrong;
- that a paper's method or conclusions are valid;
- that extracted equations match the rendered source;
- that an HTML page is complete beyond the retained representation;
- that a public resource is redistributable or suitable for model training;
- that TrackSmith deeply read the source.

Deep-review identity, sections read, methods, equations, evidence, limitations,
contradictions, implementation consequences, and non-claims remain in
`TRACKSMITH_DEEP_SOURCE_SYNTHESIS.md` with exact payload hashes.
