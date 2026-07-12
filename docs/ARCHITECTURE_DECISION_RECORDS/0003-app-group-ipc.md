# ADR 0003: App Group is the sharing boundary

- Status: provisional pending signed-host test
- Date: 2026-07-12

Use a signed App Group container for companion/extension state and supported local
IPC. The repository proves atomic messages across two processes. Production will add
authenticated instance/snapshot/schema fields and a wake-up mechanism. Direct AI or
network activity inside the AU is prohibited. XPC remains an option for heavy local
services after entitlement/lifecycle testing.
