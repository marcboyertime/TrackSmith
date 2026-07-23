# TrackSmith Production Intelligence — Logic Pro 12.3 evidence lane

Status: **prepared; direct frontier-provider session not yet executed**  
Prepared: 2026-07-15  
Rechecked: 2026-07-16  
Historical evidence preserved: `LOGIC_MVP_VALIDATION_2026-07-14.md` and
`LOGIC_12_3_VALIDATION_2026-07-14.md` are unchanged.

## Claim boundary

This document is intentionally not a passing evidence report yet. Provider adapters,
typed validation, local grounding, durable conversation state, and natural-reference
catalogs pass local tests, but the Keychain still contains no TrackSmith OpenAI or
Gemini credential. Computer Use can operate Logic Pro on the 2026-07-16 recheck; the
companion window is visually inspectable but its Computer Use accessibility session
currently returns `remoteConnection`, so companion-button automation is not counted as
proven. Credential availability is the primary frontier blocker. The credential must
be entered only into the signed companion's secure field. No credential may be pasted
into a terminal, chat transcript, source file,
evidence file, log, App Group payload, or Logic project.

## Fixed environment

| Item | Prepared value |
|---|---|
| Host | `/Applications/Logic Pro.app`, version 12.3, build 6674 |
| OS | macOS 26.3 (25D125), arm64 |
| Fixture | `tmp/logic-validation-12.3/source-vocal-48k-mono.wav` |
| Fixture provenance | Deterministically generated TrackSmith demo vocal; no third-party recording payload |
| Fixture format | 8.000 s, 48,000 Hz, mono, PCM24 |
| Fixture SHA-256 before | `ad289bb28f37fd2bef753b176e7a371bf08fbb7b4c5c76adb5e83db2a694e2c0` |
| New project target | `tmp/logic-validation-12.3/TrackSmith Production Intelligence 2026-07-16.logicx` |
| AU component | `aufx` / `LgAA` / `ExAI`; compatibility display name `Logic Audio Assistant` |

Do not overwrite the 2026-07-14 disposable project. Use Logic **Save As** to the new
project target before the first Production Intelligence mutation.

## 2026-07-16 preparatory host state

- Opened the preserved 2026-07-14 validation project in Logic 12.3 and chose its
  saved state rather than the auto-saved alternative.
- Immediately used **Save As** to create the separate 2026-07-16 project above; the
  historical project was not overwritten.
- Recorded the initial package ledger at
  `tmp/logic-validation-12.3/production-intelligence-project-hashes-initial-2026-07-16.txt`.
  Initial `ProjectData` SHA-256:
  `04326aedd6cb79da9ab1af235aa1f1df44d82fd77aadd5f12dde5986ae9cc00f`.
- The companion discovered two live TrackSmith instances at 44,100 Hz mono. Logic
  played the generated source through the prepared project for nine seconds and was
  stopped normally. No **Analyze Recent Playback** command was successfully issued,
  so this is preparation only—not capture, preview, provider, or commit evidence.
- After playback, the external fixture still hashed to
  `ad289bb28f37fd2bef753b176e7a371bf08fbb7b4c5c76adb5e83db2a694e2c0` and
  `Alternatives/000/ProjectData` still hashed to the initial value above. Logic's
  project-local 44.1 kHz media copy is a separate asset identity and is not used as
  proof that the external 48 kHz fixture remained unchanged.

## Credential handoff

In the installed companion:

1. Select **OpenAI** or **Google Gemini**.
2. Type the credential only into **Provider API credential**.
3. Choose **Save to Keychain** and verify the UI reports a credential available.
4. Enable **Allow this request's labeled text context and measurements to be sent
   to the selected cloud provider**.
5. Record only provider adapter, exact returned model identifier, request/response
   IDs, latency, attempt count, and token usage. Never record the credential.

Before the host session, run one bounded generated-audio provider case through the
same production pipeline:

```sh
.build/debug/ProductionIntelligenceEvaluation \
  --provider openai \
  --cloud-consent \
  --case VOC-FRONTIER-01 \
  --output .build/evidence/production-intelligence-openai-voc-frontier01-2026-07-16
```

This lane uses the Keychain only, allows one request/attempt, uploads no raw audio, and
must exit nonzero on missing consent/credential, provider failure, validation rejection,
or an unsafe candidate set. On 2026-07-16 the consent guard exited 2 before creating
output, and the consented no-credential check exited 1 with the typed category
`credential_missing`; neither check performed provider networking.

The same `VOC-FRONTIER-01` case run through `MockModelProvider` exited 1 with
`semantic_expectation_unsatisfied`: it identified `intimate` but omitted an
“expensive” interpretation and the requested breathiness/air preservation. This is
direct evidence that the frontier lane is testing understanding beyond the current
keyword fallback rather than duplicating an already-solved alias request.

## Required direct sequence

1. Open the new Logic project and verify the current signed TrackSmith compatibility
   AU is inserted on the generated vocal source.
2. Play/loop the source and verify live input, then **Analyze Recent Playback**.
3. Set source class to vocal.
4. Submit this genuinely free-form request:

   > Make this vocal feel more intimate and expensive, but keep the breathiness.

5. Record the exact typed desired, preserved, prohibited, ambiguity/uncertainty,
   measured evidence identifiers, hypotheses, configured model alias, separately
   bounded provider-reported model identity, response ID, capture identity, and the
   persisted six-stage validation audit. “Expensive” must not become an unqualified
   fact or a fixed preset.
6. Require exactly three valid, distinct, level-matched previews. Record preview,
   hypothesis, candidate and plan IDs; peak/true-peak, level-match method/gain,
   pairwise-difference and constraint results; and all warnings.
7. Inspect every node and select version two as the working plan. Lock one explicit
   EQ node.
8. Submit the natural revision:

   > Version two was closest. Keep its warmth, use less compression, and bring the
   > vocal slightly forward.

9. Verify `version two` resolves through the typed reference catalog to the exact
   preview ID, the locked EQ remains byte-for-byte identical, warmth is preserved,
   compression is reduced through bounded local controls, and any unsupported part
   is disclosed rather than hallucinated.
10. Render and listen to the revised working preview, then commit through the
    capture-bound protocol. Record the command, plan, capture, instance and runtime
    identities plus acknowledgement/heartbeat reconciliation.
11. Bypass and restore without discarding the graph.
12. Save, close and reopen the new Logic project. Verify the deterministic graph and
    lock survive under the new runtime identity.
13. Disable cloud consent or select Offline, verify playback and the committed graph
    remain fully functional without provider availability.
14. Create or retain a second AU instance and verify commands remain instance-bound.
15. Re-hash the external fixture and require the same SHA-256 as before.

## Evidence to append after execution

- installed containing-app and AU executable SHA-256, Team ID, CDHash, entitlements,
  bundle/version and strict signature result;
- Logic project `ProjectData` hash before and after save/reload;
- AU instance/runtime/capture IDs and captured WAV descriptor/hash;
- provider adapter, configured model alias, provider-reported resolved model,
  response ID, bounded usage and persisted validation stages;
- typed intent, evidence and competing hypothesis summaries without hidden model
  reasoning;
- preview/revision/plan/commit IDs and measurement table;
- locked-node before/after values;
- bypass/restore and save/reload heartbeats;
- provider-offline playback result;
- source hash after;
- screenshots or human-observed UI record, with no credential or raw provider header.

Only after all steps pass should the status and verdict be changed. Failure or an
unavailable credential must remain explicit rather than being converted into an
inferred success from unit tests or the historical deterministic Logic run.
