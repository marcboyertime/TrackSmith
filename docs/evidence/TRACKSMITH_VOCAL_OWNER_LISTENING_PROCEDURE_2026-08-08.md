# TrackSmith Vocal v1 — owner Logic and listening procedure

**Evidence class:** `SINGLE_LISTENER_FORMATIVE_EVIDENCE`
**Scope:** a local, blinded, one-owner formative study. This is not expert
validation, a population result, or proof that any candidate sounds better.

`VocalListeningStudyCLI` is intentionally a file-contract tool. It does not
render, play, alter, or inspect audio; it does not contact a network service;
and it cannot create a listening judgment. The owner must audition the
already-rendered, level-matched candidate audio separately and record their own
judgment only after remaining blind to the candidate identities.

## Part A — direct Logic capture-to-recovery proof

Use a new disposable Logic project and a rights-cleared real vocal recording.
Do not perform this lane in an unreleased song. Record the Logic/macOS versions,
project sample rate and buffer size, the installed app/AU Team ID and CDHashes,
and a SHA-256 of the source audio before beginning. Keep the provider/network
available only for the initial language interpretation if desired; the recovery
half of the lane must run with provider access disabled.

1. Insert a fresh `Audio Units > Marc Boyer > Logic Audio Assistant` instance on
   the vocal channel, play the whole test range, and confirm changing input level
   in the TrackSmith companion.
2. Open **Vocal**, enter the actual room, available equipment, constraints,
   desired result, capture priorities, and qualities to preserve. Generate the
   bounded capture interpretations and select one explicitly.
3. Click **Capture Bound Vocal Test Take** while the chosen source range plays.
   Record the instance ID, runtime epoch, capture ID, immutable source ID, source
   hash, sample rate, channel count, frame count, brief ID, interpretation ID,
   and completed test-take binding ID shown or exported by TrackSmith.
4. Review the local measurement findings separately from the listen-only prompts.
   Enter the owner's actual compact feedback. If a capture revision is requested,
   confirm it has a new revision ID and retains the prior plan as ancestry.
5. Enter one substantial production request. For a vague request such as
   "make it better," verify that TrackSmith asks one clarification and creates no
   executable candidate until an actual desired change is supplied.
6. Generate the three interpretations. Require three valid cards or record the
   explicit rejection reason; do not turn a rejected render into a pass. Record
   every intent, candidate, plan, preview, render, source, and parent identity and
   hash, plus the reported loudness compensation and residual mismatch.
7. Audition from the same start point. Choose one explicitly with **Use as
   working**; audition alone must not change working or commit authority.
8. Lock one accepted aspect, then request one narrow revision such as "clearer
   words, but keep the movement" or "less reverb and more wobble." Confirm the
   locked aspect and unrelated nodes are identical while only the authorized
   target/scope and dependent loudness stage change.
9. Commit the accepted current working graph. Record the command, expected-current
   plan, acknowledgement/applied-plan, runtime epoch, and final plan hashes.
10. Bypass and restore while playing. Require finite dry audio during bypass and
    the exact committed graph after restore. Then use **Revert** and verify the
    exact pre-capture graph is accepted and restored.
11. Recommit the approved graph, save the Logic project, close it, close and reopen
    the companion, then reopen the project. Reconcile the exact plan, lock, global
    bypass state, source/test-take identity, and inspectable Vocal history.
    Unavailable cached audio must stay unavailable rather than being fabricated.
12. Disable provider/network access and play again. Require the committed AU graph,
    exact recovery, bypass/restore, and history inspection to work without a model
    or provider call.
13. Run one imaginative request end to end: either "underwater, but keep every word
    understandable" or "more like a trumpet." If the request is section-scoped,
    require an explicitly new provenance-bearing asset rather than claimed Logic
    region authority. Confirm prompt, typed intent, full plan, boundary decision,
    scope, source authority, ancestry, engine/pipeline version, seed when present,
    render identity/hash, and known limitations in the manifest.
14. Hash the original Logic audio and the TrackSmith preserved source copy again.
    Both must equal their pre-run hashes. Any generated asset must have its own
    path and hash; it must not replace the source.
15. Record every failure, warning, missing identity, audible glitch, stale result,
    or recovery mismatch. Do not repair the evidence file by hand or infer a pass
    from `auval`, a custom host, a screenshot, or an earlier Logic session.

The retained direct-Logic record should contain the exact identifiers above,
the before/after source hashes, the chosen/rejected alternatives, revision and
lock deltas, save/reload comparison, provider-offline observation, and the owner
signature/date. Until that record exists, Vocal gate V8 remains pending.

## Part B — blinded owner listening

### 1. Prepare the blind package

Create a local plan JSON with exactly these top-level fields:

| Field | Required value |
|---|---|
| `schemaVersion` | `"1.0.0"` |
| `studyID` | a stable printable identifier |
| `targetDescription` | the plain-language listening target |
| `source` | `sourceID`, `captureID`, and the lowercase 64-character `sourceAudioSHA256` |
| `candidates` | 2–8 entries, each with `candidateID`, `candidateSHA256`, `processingPlanID`, `processingPlanSHA256`, `previewID`, `renderedAudioSHA256`, `sourceAudioSHA256`, `originalSourceUnmodified`, and `renderIsReproducibleDerivative`; a rendered asset additionally supplies paired `assetID` and `assetManifestSHA256` fields |
| `deterministicSeed` | an unsigned integer retained for deterministic replay |
| `levelMatchingRequired` | `true` |
| `maximumLevelMismatchDB` | finite number from `0` through `1` |
| `evidenceClass` | `"SINGLE_LISTENER_FORMATIVE_EVIDENCE"` |

Every candidate must retain the exact source hash; bind unique candidate,
processing-plan, preview, and rendered-audio identities; use distinct lowercase
SHA-256 values; set both preservation booleans to `true`; and be a real,
reproducible candidate. Asset identity and manifest hash are either both absent
for an ordinary preview or both present for an asset-backed item. The CLI
validates the plan and rejects unknown keys, oversized JSON, invalid hashes,
invalid study bounds, unpaired asset fields, and malformed preservation claims.
It does not verify a render against an audio file, so do not substitute a hash
for actual render provenance.

Choose new, nonexistent output paths. The participant package and private key
must never share a participant-accessible folder. “Sealed” here means a separate,
checksum-bound plaintext JSON file written with owner-only `0600` permissions; it
is not encrypted, and procedural self-blinding still depends on the owner not
opening it before finalization.

```sh
swift run -c release VocalListeningStudyCLI prepare \
  --plan /absolute/path/study-plan.json \
  --participant-package /absolute/path/owner-blind/participant-package.json \
  --sealed-key /absolute/path/owner-private-key/sealed-answer-key.json
```

The participant package provides ordered blind codes (`A`, `B`, …) and render
hashes, but no TrackSmith candidate, processing-plan, preview, or asset identity
or private state hash. Those values are checksum-bound inside the sealed answer
key and appear only in validated unblinded evidence. Keep that key closed and
separate until a response is finalized. Do not edit, merge, regenerate, or open
it to guide a judgment.

### 2. Listen while blind

Use the participant package only to map its blind codes to the separately
prepared, level-matched audio. Start every item at the same position and use
the same loop. Record conditions and score every shown code before choosing a
preference. There is no minimum result implied by this procedure: a legitimate
outcome can be no preference or no acceptable candidate.

Create one owner-input JSON file with exactly these fields. `note` is optional;
all six scores are integers from 1 through 7.

```json
{
  "conditions": {
    "transducer": "headphones",
    "environment": "quiet_untreated",
    "outputDeviceDescription": "owner-described local device",
    "levelMatched": true,
    "measuredMaximumLevelMismatchDB": 0.1,
    "listeningMinutes": 12,
    "fatigueBefore": 1,
    "fatigueAfter": 2
  },
  "judgments": [
    {
      "blindCode": "A",
      "scores": {
        "targetRelevance": 1,
        "sourcePreservation": 1,
        "naturalness": 1,
        "intelligibility": 1,
        "temporalCoherence": 1,
        "usefulness": 1
      },
      "note": "Owner's actual blind observation, if useful."
    }
  ],
  "preference": {
    "kind": "no_preference"
  },
  "confidence": 3
}
```

The actual file must contain each package code in its displayed order, exactly
once. Use one of these preference forms:

- Candidate selected: `{ "kind": "candidate", "blindCode": "A" }`
- No preference among acceptable options: `{ "kind": "no_preference" }`
- None acceptable: `{ "kind": "none" }`

Finalize without supplying the sealed key. This validates the participant
package, conditions, deterministic code order, scores, preference, confidence,
and response checksum before writing a finalized response.

```sh
swift run -c release VocalListeningStudyCLI finalize \
  --participant-package /absolute/path/owner-blind/participant-package.json \
  --owner-input /absolute/path/owner-blind/owner-input.json \
  --response /absolute/path/owner-blind/finalized-response.json
```

### 3. Unblind after finalization

Only after the finalized response exists, unblind it with the still-sealed
key. The command validates the participant package, final response, package
fingerprint, response checksum, answer-key checksum, and sealed-key flag before
it emits the identity-bearing evidence file.

```sh
swift run -c release VocalListeningStudyCLI unblind \
  --participant-package /absolute/path/owner-blind/participant-package.json \
  --sealed-key /absolute/path/owner-private-key/sealed-answer-key.json \
  --response /absolute/path/owner-blind/finalized-response.json \
  --evidence /absolute/path/owner-blind/unblinded-formative-evidence.json
```

The exported evidence retains the exact label
`SINGLE_LISTENER_FORMATIVE_EVIDENCE` and the claim boundary that it is one
product-owner listening judgment, formative only, not expert or population
evidence. A tampered package, response, or key is rejected before an evidence
file is written.

### File handling and mechanical verification

Every accepted JSON file is capped at 1,048,576 bytes. The CLI accepts local
regular files only; it has no network client. Each output is first completed in
a same-directory private temporary file and then atomically linked into a new
destination. Existing destinations are always refused, so use fresh paths for
each run and preserve the final response rather than overwriting it.

Run the deterministic, no-audio self-check before using a changed build:

```sh
make vocal-listening-selfcheck
```

The self-check uses only temporary synthetic fixture metadata. It proves
repeatable blind order, private candidate/plan/preview/asset identity omission
from the participant package, overwrite refusal, package/response/key tamper rejection, refusal to
unblind an unfinalized response, exact export and reload, and both
`no_preference` and `none` pathways. It produces no rendered audio and makes
no listening claim.
