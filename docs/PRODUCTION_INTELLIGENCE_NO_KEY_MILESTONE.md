# TrackSmith Production Intelligence v1 — no-key milestone amendment

Status date: 2026-07-22  
Supersedes: only the credential-dependent acceptance clauses of the active
Production Intelligence v1 goal

Historical-status note: this amendment remains preserved for auditability, but it
is not the current completion gate. The active 2026-07-22 goal prioritizes the
credential-backed OpenAI/Gemini lanes, whose live evidence is recorded in the
cross-provider and Gemini cloud-30 evaluation reports. It must not be read as
evidence that those later live runs were absent.

## Decision

Production Intelligence v1 must be completable without an OpenAI, Gemini, or
other cloud API credential. No user-supplied secret, paid cloud account, network
connection, or cloud-provider availability is a completion dependency.

The existing provider-neutral contracts, OpenAI and Gemini adapters, Keychain
storage, consent gates, redaction, and fail-closed networking remain implemented
optional capabilities. They are not removed and must not regress, but a live
credential-backed run is no longer required to prove the milestone.

This is a sequencing decision, not a rejection of cloud providers. TrackSmith is
expected to activate and directly validate OpenAI, Gemini, and other compatible
provider adapters later when credentials are intentionally provisioned. The
provider-neutral contract must therefore stay production-ready, and future cloud
evidence must run through the same validation, privacy, cost, cancellation,
staleness, and deterministic-DSP authority boundaries as the no-key lane.

## Required semantic provider

The required non-mock semantic lane is the Apple on-device system language model
through the Foundation Models framework when it is available. It must:

- run only in the companion process;
- use no API key and no network;
- receive the same bounded, labeled TrackSmith context as every other provider;
- emit only the versioned semantic contract, never DSP parameters or executable
  actions;
- pass decoding, schema, semantic, capability, reference, constraint, and stale-
  authority validation before it can influence a candidate plan;
- preserve deterministic mock/offline behavior when the system model is
  unavailable;
- report model/runtime availability explicitly rather than silently falling back
  and claiming model understanding;
- remain subject to provider-neutral evaluation and exact model/OS evidence.

Apple describes this model as device-scale and suitable for tasks such as input
analysis, extraction, and classification, not as a source of advanced world
knowledge. TrackSmith therefore supplies its own reviewed production knowledge and
measured evidence, decomposes interpretation into a bounded task, and retains all
DSP and state authority locally.

## Replacement completion clauses

The following clauses replace the credential-dependent clauses in the active
goal:

1. At least one real, non-mock semantic model provider works end to end without
   credentials. The preferred current lane is Apple's on-device Foundation Models
   framework.
2. The provider architecture remains vendor-neutral; deterministic mock/offline
   behavior and optional cloud adapters continue to work and fail closed.
3. The direct Logic Pro Production Intelligence session uses the real on-device
   provider. It still must demonstrate free-form interpretation, typed intent,
   measured evidence, competing hypotheses, three editable level-matched previews,
   a natural typed revision, constraint/lock preservation, capture-bound commit,
   bypass/restore, save/reload, provider-unavailable playback, and unchanged source
   audio.
4. The provider evaluation harness must record on-device availability, macOS build,
   configured provider/model identity, latency, validation stages, and failure
   category. It must not mislabel deterministic fallback output as model output.
5. Cloud live-provider and cloud-assisted Logic evidence are explicitly planned
   follow-on interoperability lanes, but are not Production Intelligence v1
   release gates and do not block current work.

Every other safety, semantic, real-audio, Logic-host, DSP, persistence, adversarial,
regression, documentation, and evidence requirement remains in force.

## Evidence boundary

Installed-framework presence and `SystemLanguageModel` availability prove only
that the on-device runtime can be invoked. They do not prove semantic quality.
TrackSmith must still pass the structured semantic corpus, adversarial output
validation, real-audio pipeline cases, and direct Logic workflow before claiming
the no-key milestone is complete.
