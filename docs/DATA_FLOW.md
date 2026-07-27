# Data flow

```text
Logic insert audio
  → AU render bus → atomically selected compiled graph → Logic output
                  ↘ preallocated bounded dry-input ring (up to 30 s / 24 MiB)
                     └─ off-render snapshot → atomic hashed WAV artifact
                                              │
Signed AU heartbeat → App Group instance file │
                             ↘                 ▼
                         companion discovers instance
                                  ↓
User prompt + explicit source context
                                  ↓
 typed intent + preserved/prohibited attributes + ambiguity state
                                  ↓
source-aware evidence (validity/confidence/failure modes/provenance)
                                  ↓
 competing production hypotheses + risks + expected metric direction
                                  ↓
                three validated deterministic candidate plans
                                  ↓
         offline render → level match → objective/pairwise guardrails
                                  ↓
              synchronized original/variant audition + change cards
                                  ↓ explicit exact commit/revision/revert
 capture + expected plan + canonical graph → companion preflight re-render
                                  ↓ expiring epoch-bound command
 plug-in rechecks source → AU lifecycle-locked snapshot/format/CAS/lock validation
                                  ↓
       atomic graph publication + serialized current-plan state advance
                                  ↓
               heartbeat application record → retryable terminal acknowledgement
```

No language model is connected directly to DSP parameters. The typed intent,
source-aware evidence, hypothesis, and plan-validation stages are ordinary versioned
data structures. A perceptual adjective can select competing source-conditioned
hypotheses, but no single metric is allowed to assert that adjective as fact.

Research material follows a separate immutable trust path:

```text
canonical URL + declared rights/version
  -> exact retrieval + content/media/length checks
  -> SHA-256 content address + duplicate lookup
  -> publish immutable payload or quarantine with reason
  -> append-only retrieval/history record + explicit supersession metadata
  -> human source review and TrackSmith consequence record
```

An ingested payload is evidence that bytes were acquired safely, not evidence that
the source is correct or that its claims apply to TrackSmith.

The render branch never crosses disk/network/UI/AI boundaries. The AU-owned bridge
runs on a utility queue and performs ring snapshots, WAV I/O, message polling,
validation, graph compilation, and once-per-60-second mailbox maintenance. The
callback pulls through a separate preallocated input ABL, copies into validated host
output or preallocated storage for null output `mData`, writes the bounded ring,
loads one published graph pointer for the complete callback, and applies atomic
scalar parameters. Resetting the pull ABL on every call permits upstream pointer
replacement without losing the host's original output addresses.

Capture duration is capped by both 30 seconds and 24 MiB. Higher-rate stereo formats
therefore retain less than 30 seconds rather than allocating unbounded memory; every
reply declares the actual rate, channels and frame count.

App Group messages use schema version `1.1`, UUID identity/correlation, plug-in
instance ID, per-instance runtime epoch, monotonic command sequence, and bounded
expiry. Capture replies must
match the instance/runtime selected when the command was sent. JSON and WAV publication
is temporary-file-plus-rename atomic. Exchange directories use mode 0700 and files
0600; messages are bounded to 1 MiB, artifacts to 128 MiB, artifact paths remain
inside the controlled root, and captured WAVs are verified by SHA-256 plus declared
sample-rate/channel/frame metadata before use. A ring snapshot that cannot be made
coherent within bounded retries fails closed.
Heartbeats publish once per second and companion discovery considers only the most
recent five seconds active. A confirmed companion privacy action removes every file
beneath the capture-artifact and preview cache roots while retaining those roots,
messages, heartbeats and AU state; automatic audio-cache expiry is not implemented.

Protocol storage is independently bounded. One cross-process advisory `flock` with
a 500 ms acquisition bound serializes message/heartbeat publication and maintenance.
The default mailbox admits
at most 2,048 message files totaling 32 MiB and 512 instance files. Every live
command reserves a 32 KiB terminal-response allowance and is removed after a
five-minute hard file-age limit. Before adding a new entry, maintenance removes only
eligible state: completed expired transactions
after 10 minutes, other protocol diagnostics after 24 hours, and instance files
after 10 minutes without modification. An unexpired command is never evicted to
admit another command; if retained files still fill either quota, the write fails
closed with `mailboxFull`. The bridge's processed-command set contains only IDs still
visible in the scan and is therefore bounded by the message-file quota. Retention
uses file modification dates rather than sender-authored timestamps. Reads reject
symlinks, require regular descriptors and canonical UUID filenames. Terminal replies
must match the original command's instance, runtime and legal result kind.

Commit is accepted only for the capture's originating instance/runtime and snapshot.
The companion rehashes and decodes that WAV, verifies metadata, activation safety,
canonical materialized-plan identity, and a fresh in-memory render/measurement before
publishing a request. The request carries an explicit expected current plan,
including the distinction between “expect dry” and “expectation omitted.” The plug-in
resolves and re-verifies the artifact, then calls one AU transaction. Under the AU
lifecycle lock, that transaction requires allocated render resources, matches the
capture's snapshot identity and rate/channels against the plan and both current
buses, compares the expected current graph, validates locked-node preservation and
activation safety, publishes the graph, and advances serialized plan state. Host
deallocation and `fullState` restoration are excluded until the transaction
finishes. A wrong snapshot, stale plan, changed format or deallocated unit cannot
overwrite a newer graph or saved state; the focused HostProbe exercises successful
controls for each rejection.

Capture state has the same lifetime as render resources. Deallocation discards the
ring and makes both direct and IPC capture fail; the IPC failure publishes no audio
artifact. A later allocation starts with an empty ring, so pre-deallocation samples
cannot be resurrected. The HostProbe verifies the first subsequent capture contains
only audio rendered after reallocation.

After application, heartbeat state records the applied command/plan IDs before the
bridge attempts a reply. The companion treats matching heartbeat state as success if
the acknowledgement is lost, and does not automatically retry an unconfirmed
timeout. Neither signal proves that the render callback has emitted the new graph.
There is no durable cross-restart command-idempotency ledger or automatic audio-
cache expiry. Companion semantic/revision history does persist separately in a
bounded checksummed local store, but it becomes view-only when live AU authority
does not reconcile. Protocol garbage collection is bounded
retention, not a durable transaction journal: once eligible files are removed,
cross-restart deduplication history is gone. AU document state contains the committed
graph and independent global-bypass flag, not audio, API keys, chat transcripts,
absolute paths, or provider retention data. Commit-time approximate true-peak
measurement is a safety gate; the real-time limiter is sample-peak only.

Only output gain consumes AU scheduled parameter events today. Immediate and ramp
events apply at sample offsets, ramps persist across callbacks, and event walking is
bounded to 256 entries per callback. One processing graph remains retained for the
whole callback even if a companion publication races the render. Host reset clears
DSP history and scheduled automation; host/companion bypass clears graph history but
keeps advancing the scheduled gain timeline while output remains dry. When upstream
sets `OutputIsSilence`, the AU substitutes zero input and clears the outgoing flag
after processing because an IIR tail may still be audible. The static reported tail
bound is 60 seconds.

Cloud path: the companion selects relevant typed context, obtains explicit consent,
reads the selected provider credential from Keychain, sends bounded text and
measurements over an ephemeral TLS session, validates the untrusted response through
six local gates, and records provider/model/version and bounded usage metadata. Raw
audio, paths, filenames, AU state, credentials and executable plans are excluded.
A network/credential/validation/staleness failure is typed and local manual/DSP and
saved-project playback continue. The adapters pass mocked wire/failure tests,
OpenAI/Gemini live cross-provider cases, Gemini's 30-case cloud lane, and a direct
Gemini/Logic Pro 12.3 workflow through save/reload and provider-offline graph
restoration. Provider output still never crosses directly into AU or DSP authority.
