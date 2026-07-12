# Data flow

```text
Logic insert audio
  → AU render bus → committed compiled graph → Logic output
                  ↘ preallocated bounded ring (explicit capture state)
                     → non-RT immutable buffer → local analysis
User prompt ────────────────────────────────┐          │
Imported reference (security-scoped) → local analysis │
                                             ▼        ▼
                                   goal/reference resolver
                                             ↓
                                   versioned candidate plans
                                             ↓
                         validator → offline preview renderer
                                      ↓                 ↓
                                preview cache      measurements
                                      └──── user A/B/commit ───→ AU state
```

The render branch never crosses disk/network/UI/AI boundaries. App Group messages
carry plan/state identifiers and small typed payloads; captured/preview audio should
use bounded shared files outside render, with content hashes and lifecycle records.
AU document state contains the committed graph and minimal snapshot metadata, not
audio, API keys, chat transcripts, absolute paths, or provider retention data.

Cloud path (not implemented): the companion builds a disclosure, obtains explicit
consent, minimizes/redacts the payload, sends over TLS, validates the untrusted
response locally, and records provider/model/version and consent scope. A network
failure returns a typed error and local manual/DSP features continue.
