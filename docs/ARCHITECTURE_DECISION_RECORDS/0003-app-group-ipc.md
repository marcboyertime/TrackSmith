# ADR 0003: App Group is the sharing boundary

- Status: accepted and current-source signed-host validated
- Date: 2026-07-12

Use a signed App Group container for companion/extension state and supported local
IPC. Versioned messages carry instance/runtime/snapshot/schema identity, publication
uses temporary-file-plus-rename atomicity, and artifacts are path-contained and
hash/metadata checked. Direct AI or network activity inside the AU is prohibited.

The file mailbox is a bounded command transport, not an indefinite audit database.
One advisory `flock` with a 500 ms acquisition bound serializes maintenance and publication across processes. Default
limits are 2,048 message files, 32 MiB aggregate message bytes, and 512 instance
files. A send performs eligible maintenance before admission and fails closed with a
typed full-mailbox error if capacity remains unavailable; it never evicts an
still-deliverable command to make room. Each live command reserves terminal-response
capacity and has a five-minute hard file-age limit. Completed expired command/reply sets are eligible 10
minutes after completion, other diagnostics after 24 hours, and stale instance files
after 10 minutes, using filesystem modification dates rather than sender-controlled
timestamps. Each AU bridge attempts maintenance no more often than every 60 seconds.
Its processed-command set is intersected with the visible scan, which bounds memory
by the file quota while preserving deduplication for every still-readable command.

Consequences: polling/wake-up latency and filesystem lock contention remain load-test
items; retention removal also removes cross-restart replay evidence, so this is not a
durable idempotency ledger. Audio caches have a separate explicit delete operation
and do not yet expire automatically. XPC remains an option for heavy local services
after entitlement/lifecycle testing, but stable DSP does not depend on it.
