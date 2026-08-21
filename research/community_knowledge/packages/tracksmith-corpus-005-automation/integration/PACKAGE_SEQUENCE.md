# Package Sequence

## Package identity

```text
Package 5
tracksmith-corpus-005-automation
namespace: pkg005
contract: tracksmith-corpus-package/1.0
```

## Declared dependencies

1. `tracksmith-corpus-001-vocal-quantization`
2. `tracksmith-corpus-002-level-balancing-eq`
3. `tracksmith-corpus-003-compression-arrangement-frequency-allocation`
4. `tracksmith-corpus-004-reverb-delay`
5. `tracksmith-corpus-005-automation` — this package

Packages 1–4 may have been integrated before the stable 1.0 contract existed. Their stored package IDs or layouts may therefore differ. Codex must inspect the TrackSmith package registry and map any legacy package identity to the dependency above rather than overwriting or reimporting prior content.

## Sequencing rules

- Package 5 must not overwrite prior package IDs, source records, review states, migrations, or evaluation records.
- `pkg005.*` IDs are globally reserved for this package.
- Do not renumber records.
- Do not merge candidate records into generated reviewed Swift knowledge automatically.
- Import should be additive and reversible through Git.
- Unified indexes may reference Package 5 records, but the package source remains immutable.

## Future package rule

Every future package should use the same root layout, schemas, table names, review states, tools, and ID conventions. Only package number, namespace, domain data, dependency list, counts, and domain-specific reports should change.
