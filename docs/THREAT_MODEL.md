# Threat model

## Assets

Unreleased audio, references, project identity/path, prompts, provider credentials,
processing state, Logic project integrity, speaker/listener safety, and DAW uptime.

## Trust boundaries and threats

| Boundary | Threat | Required control |
|---|---|---|
| model response → planner | prompt injection, extreme gain, invented nodes/actions | decode typed schema; allow-list; bounds/gain/lock/stale validation; no executable tools |
| audio metadata/name → prompt | malicious instructions disguised as metadata | treat as quoted data; never concatenate into system authority |
| companion → AU | spoofed/stale/corrupt plan | signed App Group; version/hash/instance/snapshot IDs; atomic messages; schema validation |
| render callback | blocking, allocation, crash, NaN, runaway gain | precompile/preallocate; atomic publication; bounded loops; finite/ceiling guards; prior graph retained |
| provider/network | audio exfiltration, secret leakage, retention | explicit consent; Keychain; TLS; redacted logs; provider disclosure; local default |
| model download/cache | substitution or path traversal | signed manifest/hash, fixed cache root, safe extraction, quarantine and version pinning |
| Accessibility/MIDI → Logic | wrong selection, unintended project mutation | feature flag; permission; pre/postcondition verification; transaction stop/recovery; user approval |
| diagnostic export | unreleased audio/path/prompt leakage | preview and redact by default; never include audio without separate opt-in |
| cache/state | other app access, tamper, disk growth | App Group/SIP boundary, integrity hashes, quotas, expiry, delete-all control |

## Safety behavior

Invalid plans never replace committed audio. IPC/provider/preview failure leaves the
prior graph active. Experimental project action failure stops the sequence; no
follow-on clicks occur. The system never overwrites the sole source. Output must be
bounded and a production fault counter must trigger safe bypass after repeated DSP
faults. Availability attacks must not move AI/network/database work onto render.

## Out of scope but tracked

Formal third-party DSP audit, sandbox penetration testing, notarization pipeline,
Keychain access-group testing, cloud-provider contractual review, and supply-chain
SBOM/signing are required before external beta.
