# Privacy model

## Defaults

Core capture, analysis, planning recipes, DSP, previews, state and manual editing are
local. No telemetry or raw-audio upload path is implemented. Provider-neutral OpenAI
Responses and Google Gemini Interactions text/measurement adapters exist only in the
companion and are disabled unless the user selects one, stores a credential in
Keychain, and enables cloud-reasoning consent. The plug-in does not request
microphone access because it receives host insert audio. The app requests user-
selected read access only for explicit imports. Accessibility is absent from stable
targets.

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
- Cloud request: bounded user language plus labeled typed source context,
  measurements, current graph/reference identities, relevant production knowledge,
  capabilities and limitations. Captured audio, preview audio, file names/paths,
  project names, AU state blobs, credentials, and executable plans are excluded by
  the provider input type.
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
  as general knowledge. Persistence and deletion UI are not yet implemented.
- Credentials: macOS Keychain service
  `com.marcboyer.tracksmith.provider-credentials`, provider-specific accounts,
  when-unlocked device-only accessibility; never logs, prompts, requests, App Group,
  presets, project state, conversation state or source.

The current UI names the active provider and separates local deterministic behavior
from cloud-assisted reasoning. A cloud call requires explicit text/measurement
consent and uses TLS through an ephemeral no-cache/no-cookie session with bounded
timeout, cancellation, output and attempts. Before external release, the disclosure
must also link current provider retention terms and describe the exact data classes.
Text consent never implies audio consent. Any future raw/reference-audio path needs a
separate interface, disclosure, per-use informed consent, retention handling, and
test lane. Model downloads need signature/hash verification.

## User controls

The companion implements secure credential save/delete and confirmed deletion of all
App Group capture/preview audio without deleting Logic source files, AU document
state, heartbeats, or protocol diagnostics. That audio-cache action intentionally
does not alter a live command transaction or the separate local conversation store;
independent bounded mailbox maintenance expires protocol metadata according to the
policy above. A conversation-history deletion UI, provider-terms disclosure,
audio-cache inventory/automatic expiry, diagnostic export preview, and permission-
revocation instructions remain release gates. No opt-in telemetry path exists.
