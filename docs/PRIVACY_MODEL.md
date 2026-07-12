# Privacy model

## Defaults

Core capture, analysis, planning recipes, DSP, previews, state and manual editing are
local. No telemetry, audio upload, account, or cloud provider is implemented. The
plug-in does not request microphone access because it receives host insert audio.
The app requests user-selected read access only for explicit imports. Accessibility
is absent from stable targets and will be requested only when the user enables the
experimental Logic adapter.

## Data classes and retention

- Audio source: host-bounded memory or user-selected file; never logged.
- Preview audio: local cache, content-addressed, user-deletable, expiry configurable.
- Plans/snapshots: local App Group state and Logic AU document state; no credentials.
- Prompts/provider responses: local session by default; diagnostic export redacts
  project names, file paths and prompt/audio content unless the user opts in.
- Credentials: macOS Keychain only; never logs, presets, project state or source.

Before any future provider sends data, the UI must state whether text, metrics,
audio, reference audio, metadata or identifiers leave the Mac; name the provider;
link retention terms; estimate payload; and require explicit informed consent for
audio. Text consent never implies audio consent. Transport must use TLS and model
downloads need signature/hash verification.

## User controls

Provider-offline mode, per-request disclosure, opt-in telemetry, opt-in retention,
cache inventory, delete-all-cached-audio, credential removal, diagnostics preview,
and permission revocation instructions are release gates.
