# Privacy model

## Defaults

Core capture, analysis, reviewed knowledge, DSP, previews, state and manual editing
are local. No telemetry path is implemented. The LLM-first Tutor's OpenAI Responses
text/measurement route is disabled without explicit cloud-text consent and a
Keychain credential; it falls back locally. A separate optional OpenAI audio route
requires independent cloud-audio consent, a per-turn Listen toggle, a current
hash-bound capture, metadata validation, and a 12 MiB cap. The plug-in does not
request microphone access because it receives host insert audio. A read-only Logic
observer requests Accessibility only from an explicit user action and never prompts
during ordinary observation; it exposes no setters or actions. The directly
distributed companion is not App-Sandboxed because macOS forbids assistive-app
Accessibility APIs inside App Sandbox. The AU extension remains sandboxed, and the
model-facing tool receives only the observer's bounded value projection—not an
Accessibility object or general filesystem/process capability.

## Data classes and retention

- Audio source: host-bounded memory or user-selected file; never logged.
- Captured/preview audio: local App Group cache, SHA-256-verified at trust
  boundaries, and removable with the companion's confirmed **Delete Local Audio
  Cache** action. Automatic expiry and a cache inventory are not implemented yet.
- Protocol messages/instance heartbeats: local App Group metadata, bounded by 2,048
  message files/32 MiB and 512 instance files under a bounded cross-process `flock`.
  Every live command reserves terminal-response capacity, expires within 60 seconds,
  and cannot survive a five-minute filesystem-age cap. Completed expired transactions
  are eligible after 10 minutes, other diagnostics after 24 hours, and stale instance
  files after 10 minutes. A still-deliverable command is retained under quota pressure;
  a full mailbox rejects the new write. Maintenance uses
  filesystem modification time rather than untrusted message timestamps and runs
  off the audio thread at no more than 60-second cadence in each AU bridge.
- Plans/AU state: local App Group state and Logic AU document state; no credentials.
- Conversation/revision state: bounded local Application Support store with atomic
  0600 files, checksums, bounded history, credential-pattern redaction, corruption
  quarantine, and restore-time AU-authority reconciliation. It can contain user
  requests, typed interpretations, hypotheses/references, the accepted six-stage
  validation audit, configured and provider-reported model identifiers, response ID
  and bounded usage metadata, but not provider credentials, headers or raw audio.
- Vocal workspace state: bounded checksummed `VocalSessionStore` envelopes in the
  App Group `VocalSessions-v1` directory, written atomically as private 0600 files
  with credential-pattern redaction, strict validation, corruption quarantine, and
  source-authority reconciliation. The store contains typed capture briefs and
  interpretations, measurement findings, explicit owner feedback/preferences,
  creative intent, candidate/plan ancestry, revision and handoff records, and
  source/preview/asset identities and hashes. It contains no raw audio, provider
  credential, header, hidden reasoning, or executable provider response. A relaunch
  restores typed history read-only until the exact source authority is current;
  operational preview/asset audio is not reconstructed from metadata and must be
  re-established from the separate local cache.
- Future/Legacy Create cloud request: bounded user language plus labeled typed source context,
  measurements, current graph/reference identities, relevant production knowledge,
  capabilities and limitations. Captured audio, preview audio, file names/paths,
  project names, AU state blobs, credentials, and executable plans are excluded by
  the provider input type.
- LLM-first Tutor text request: up to 80 bounded local transcript messages, labeled
  runtime context, explicit source role, immutable capture IDs/hashes, at most 16
  descriptive metrics, limitations, bounded tool outputs, and locally confirmed
  experiment outcomes. Requests use an ephemeral no-cache/no-cookie session,
  `store=false`, strict tools, disabled parallel tool calls, a hard body/output
  bound, timeout, and cancellation. Credentials, headers, local paths, raw AU state,
  hidden reasoning, executable plans, and mutation capabilities are excluded.
- Optional Tutor audio request: only the exact validated WAV bytes for the current
  capture plus a bounded musician question and explicit scope label. The listener
  rechecks liveness, SHA-256, byte size, model identifier, and Keychain credential
  immediately before sending. Audio is never attached merely because text consent
  is on or a capture exists. The returned text is stored as a bounded Heard evidence
  summary linked to the capture ID; the WAV itself is not copied into Tutor history.
- Provider response: bounded typed semantic contract and provider usage/identity
  metadata. Configured model authority and provider-reported resolved-model evidence
  remain separate. Both adapters request `store=false`; this is not a guarantee that a
  provider retains no safety/abuse data. Provider contractual retention remains an
  external policy boundary.
- Tutor lesson state (Guide Me): bounded checksummed local store under
  `Application Support/com.marcboyer.tracksmith/ProductionTutor/` with atomic
  0600 files, credential-pattern redaction, size/count bounds, corruption
  quarantine, and explicit version rejection. It can contain the user's
  request text, recognized issues, cause hypotheses, materialized lesson
  steps, immutable feedback events, user-reported chain context, safe
  authority identities (UUIDs only), and concepts practiced. It never
  contains raw audio, source paths or file names, credentials, raw provider
  responses, or hidden model reasoning. Tutor provider input, when a provider
  is used at all, is the same bounded labeled text/measurement context class
  as Production Intelligence — never audio — and provider output is reduced
  to validated canonical IDs plus a bounded audit summary before persistence.
- LLM-first Tutor conversation state: bounded checksummed atomic 0600 snapshots
  under `Application Support/com.marcboyer.tracksmith/TutorConversation/`, retaining
  hard ceilings of 240 user/assistant messages and 120 experiment records with
  explicit outcomes, plus oldest-first eviction to remain inside the canonical
  byte envelope. Separate evidence receipts are created with POSIX exclusive-create,
  owner-only permissions, checksums, capture identity/hash, provider/model/usage,
  assistant-text hash, tool argument/output hashes, evidence modalities, and consent
  records. Receipts have no overwrite path but can be removed through the explicit
  Delete All Tutor History action. Transcript and receipts exclude credentials,
  headers, audio bytes, file paths, screenshots, hidden reasoning, AU state, and
  executable plans; credential-like strings are redacted before persistence.
- General tutor knowledge and sources: the generated knowledge base contains
  paraphrased claims and TrackSmith-authored strategy/concept cards derived
  from reviewed artifacts already in this repository, each with a source ID,
  rights basis, and handling class. No full public transcript, video payload,
  or copyrighted source text is committed. Source entries record whether a
  transcript was creator-provided or automatic and whether audiovisual review
  is required; a source needing that review cannot ground a trusted claim.
  Any future user-owned course material stays local and ignored, with only
  hashes, rights basis, and paraphrased notes retained.
- Personal production outcomes: `PersonalOutcomeRecord` is local-only, created
  only on explicit user confirmation, never cloud-synced, and never presented
  as general knowledge. It persists in a separate bounded, checksummed, atomic
  0600 profile with credential-pattern redaction, corruption quarantine, count
  and size bounds, per-item forget, delete-all, and a human-readable export.
  Guide Me exposes remember-helped / remember-did-not-help, per-item forget, and
  delete-all-learning controls. A confirmed outcome can only apply a bounded
  ranking preference for this user; it cannot manufacture relevance or become a
  general claim.
- Credentials: macOS Keychain service
  `com.marcboyer.tracksmith.provider-credentials`, provider-specific accounts,
  when-unlocked device-only accessibility; never logs, prompts, requests, App Group,
  presets, project state, conversation state or source.

The current UI names the Tutor models and separates local deterministic behavior
from cloud-assisted reasoning. Cloud text and audio have independent toggles, and
audio also requires a per-turn request. Both use TLS through ephemeral sessions with
bounded timeout, cancellation, and output; requests set `store=false`. This does not
guarantee a provider retains no safety/abuse data. Before external release, the
disclosure must link current provider retention terms and describe these exact data
classes. Model downloads need signature/hash verification.

## User controls

The companion implements secure credential save/delete, new/delete-all Tutor
conversation history and receipts, per-outcome feedback, per-outcome forget and
delete-all-learning for the local tutor profile, per-category forget for confirmed
Vocal capture/creative preferences, deletion of the current or all known typed Vocal
sessions, and confirmed deletion of all App Group capture/preview audio without
deleting Logic source files, AU document state, heartbeats, or protocol diagnostics.
Deleting Vocal typed state does not delete raw captures, Logic projects, or AU state;
deleting the audio cache does not delete Vocal ancestry or preference records. The
audio-cache action intentionally does not alter a live command transaction, the
separate local conversation store, or the separate tutor profile; each control states
its own scope. Independent bounded
mailbox maintenance expires protocol metadata according to the policy above. A
provider-terms disclosure, audio-cache inventory/automatic expiry, diagnostic export
preview, and permission-revocation instructions remain release gates. No opt-in
telemetry path exists.
