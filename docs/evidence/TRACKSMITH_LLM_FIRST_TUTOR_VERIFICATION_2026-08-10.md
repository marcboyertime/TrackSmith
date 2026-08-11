# TrackSmith LLM-First Tutor Verification — 2026-08-10

## Evidence boundary

This record keeps source verification, signed installed-artifact proof, model listening, local measurements, Logic observation, and user listening separate. A pass in one class is not evidence for another.

## Preservation and Git state

- Untouched pre-pivot commit: `6843210cee66cbdbe6ada41bfaa62378ed232057`.
- Archival branch: `archive/pre-tutor-pivot-2026-08-09` at the untouched commit.
- Annotated tag: `tracksmith-pre-tutor-pivot-2026-08-09`; tag object `3939cd1996886737ce21126fe14928448a9b5401`, peeling to the untouched commit.
- New branch: `codex/llm-first-tutor-2026-08-09`. It was created from the untouched commit and does not reuse the historical Tutor branch.
- Main pivot commit: `95b62f56f49c42da87d4b4c5b1cabbe66a76ebd8` (`Pivot TrackSmith to LLM-first Tutor`).
- Acceptance hardening commit: `5b0c5839070318a2b8e2ec73f3a746be7e63e28b` (`Tighten Tutor fallback evidence`).
- Concurrent files `.codex/agents/*.toml`, `apps/CompanionMacApp/Assets.xcassets/**`, and the resulting generated Xcode-project resource references were not authored, staged, or committed by this work.

## Implemented vertical slice

- Tutor is the companion app's default product surface. Create/Vocal and prior production intelligence remain available only behind the explicit `Future / Legacy` boundary.
- The Audio Unit retains the legacy component and bundle identifiers and exposes an explicit `Open TrackSmith Tutor` button.
- Conversation is genuinely stateful across turns and persists bounded local transcript, experiment, and outcome state.
- The OpenAI Responses path streams text and uses stateless `store: false` requests. Current-turn encrypted reasoning/output items may be replayed only within the bounded function loop and are never persisted as hidden reasoning.
- The exact model-visible tool registry contains six tools: `get_current_capture_context`, `search_production_knowledge`, `get_logic_procedure`, `retrieve_prior_experiments`, `inspect_logic`, and `present_experiment`.
- Five tools are read-only and `present_experiment` is presentation-only. There is no Logic, Audio Unit, file, parameter, transport, automation, render, or project mutation tool.
- Capture ingestion uses exact bounded WAV bytes, live-authority and metadata checks, `O_NOFOLLOW`, `fstat`, a byte cap, and SHA-256 rebinding immediately before optional upload.
- Local analysis is descriptive evidence, never labeled model listening.
- Evidence receipts are checksum-bound, owner-only (`0600`), immutable (`O_EXCL`), and include provider, consents, evidence classes, tool hashes, capture hashes, and a bounded/redacted primary-provider failure reason when fallback completes.
- The offline Tutor now recognizes common vocal issue language, presents one reversible user-performed experiment, persists the experiment, and explicitly disclaims audio/Logic observation.

## Source verification

Verification was rerun in a detached worktree whose leaf directory remained `LogicAudioAssistant`, at exact commit `5b0c5839070318a2b8e2ec73f3a746be7e63e28b`. The two reviewed producer-judgment corpora that are intentionally ignored by Git were copied read-only into that worktree so the existing knowledge reproducibility check exercised the same registered inputs. Git porcelain was clean when the Vocal evaluator recorded its provenance.

- `make verify`: pass.
  - production-language generated check: 14 entries.
  - Logic Tutor procedure audit: 8 procedures / 18 steps.
  - General Tutor knowledge check/audit: 15 sources / 458 claims / 78 strategies / 12 concepts / 2 contradictions.
  - Vocal semantic evaluation: 89/89, corpus SHA-256 `22f359b6d10bf59b124d701258a8ec26a8e0f93f57356e417a919948baff9ca1`.
  - local listening selfcheck: pass, with the explicit boundary that it rendered no audio and made no listening claim.
  - Release package build: pass.
  - existing `TestRunner`: 104/104.
  - `TutorConversationTests`: 12/12, including genuine muddy → thin history, bounded tools, experiment/outcome persistence, immutable receipt behavior, audio consent/hash checks, automatic fallback reason, and cancellation/exclusion.
  - `AudioUnitHostProbe`: pass; 128 frames at 48 kHz, mean `14.8 µs`, p99 `18.1 µs`, max `84.0 µs`, deadline `2666.7 µs`.
- `make realtime-heap-probe`: pass, `4000` callback iterations and `0` heap operations.
  - first clean-worktree run: mean `25.1 µs`, p99 `108.9 µs`, max `7734.6 µs`; the single max exceeded the nominal block deadline even though the probe passed and reported no heap operations.
  - immediate repeat: mean `14.9 µs`, p99 `24.3 µs`, max `118.4 µs`, deadline `2666.7 µs`, `0` heap operations.
- Checked-in Vocal report identifies commit `5b0c5839070318a2b8e2ec73f3a746be7e63e28b`, `sourceTreeState: clean`, and evaluator executable SHA-256 `871469353a62a59f10cb18b0f871eda081703f78e8a66bc002d0b7b1c686c1c4`.

The first detached-worktree attempt failed before compilation because the intentionally ignored producer-judgment corpora were absent. This was an environment/input-parity failure, not a code failure; the successful clean run above restored those same reviewed inputs.

## Signed installed-artifact proof

- Installed app: `/Users/marcboyer/Applications/Logic Audio Assistant.app`.
- Xcode Release installation: `BUILD SUCCEEDED`.
- App and nested AU pass `codesign --verify --deep --strict` / strict nested verification.
- Signing Team ID: `KDV9RC892F`.
- Staged and installed app executable SHA-256 both equal `75848746cb80a0359ed5310554ea008063625e07beede8403c1d93bfbebb293f`.
- Staged and installed AU executable SHA-256 both equal `0bd623fbcae5cb9a0b1ab33938cabc42929d04435abc1a2cab0eb17bcaac7bc1`.
- App entitlements: App Group, network client, development `get-task-allow`; no App Sandbox so the opt-in accessibility observer can make read-only AX queries.
- AU entitlements: App Sandbox, App Group, development `get-task-allow`.
- Preserved app bundle ID: `com.marcboyer.logicaudioassistant`.
- Preserved AU bundle ID: `com.marcboyer.logicaudioassistant.AudioUnit`.
- Preserved component: `aufx/LgAA/ExAI`.
- `pluginkit` registration: `com.marcboyer.logicaudioassistant.AudioUnit(1.0)`.
- `auval -v aufx LgAA ExAI`: `AU VALIDATION SUCCEEDED`; AUv3 loaded out of process, mono/stereo formats rendered from 11.025 through 192 kHz.

The final installed app was launched directly by absolute path. It opened in Tutor mode with `Future / Legacy` off. With cloud consent off, the installed Tutor answered a muddy-vocal request with a low-mid masking hypothesis, one user-controlled broad `1–2 dB` A/B around `250–400 Hz`, explicit listen/stop/undo guidance, a persistent experiment card, `Show Me`, and Better/Worse/No change/Can't find it outcomes.

Installed receipt `4AB53057-AD16-4DED-95B6-17DAAFA0B7E4` is `0600`, records `tracksmith-offline-tutor-v1` / `deterministic-issue-tutor-v1`, records `Cloud conversation consent is off` as the bounded fallback reason, records `present_experiment`, and records no capture or cloud consent for that turn.

## Logic and capture evidence

- Logic Pro 12.3 was opened through the authorized Computer Use route.
- A read-only `LogicTutorObservationProbe` returned `status: observed` at `2026-08-11T03:03:30Z`, bundle `com.apple.logic10`, bounded visible-control semantics, and the visible-UI-only limitation. Window/project titles and coordinates are omitted from model-facing observation output.
- The signed installed AU was selected from Logic's Audio Units menu and hosted as a mono insert.
- Hosted UI showed `Logic Audio Assistant`, `Deterministic graph active · recent dry input retained in bounded memory`, `Waiting for audio`, Output gain `+0.0 dB`, `Open TrackSmith Tutor`, and the explicit statement that Tutor cannot change Logic or the AU.
- The AU button opened the installed companion, which reported an active `TrackSmith — 44100 Hz · mono` insert.
- The repository's synthetic `demo-vocal.wav` was imported into an isolated TrackSmith acceptance project, played through the installed AU, and captured.
- First live capture: `60EAE608-C12F-4502-9E67-B1F55465E1F6`, SHA-256 `24d075cf941cc454b19834ff07774c9bcf6a2015d31034d436c649ae9bdfbdbe`, about `10.4 s`, 44.1 kHz mono, with seven bounded local measurements retained in the receipt.
- Final installed-AU capture: `53CA9B9A-2D9E-45AD-AE22-770082BC3510`, SHA-256 `747a83d9128530ef715b8e9f621e11e15d12827e12106e5817ba3b446cbf535d`, `8.986122 s`, 44.1 kHz mono Float32, owner-only WAV.
- The test region and AU insert were removed with Logic undo and the original muted empty-track state was restored. That recovered state was preserved as the isolated project `/Users/marcboyer/Music/Logic/TrackSmith Tutor Acceptance 2026-08-10.logicx`; unrelated Logic projects were not overwritten.

This is proof of installed AU hosting, actual Logic playback capture, and local measurement generation. It is not proof that a model or the user listened.

## Model-listening and user-listening evidence

- An installed-app audio turn was attempted with separate text and audio consent, exact bounded WAV attachment, and the configured `gpt-audio-1.5` route. The turn completed through deterministic fallback and its receipt correctly marked listening unavailable.
- A final package-path acceptance probe exercised the same `OpenAITutorAudioListener`, the final capture bytes, live snapshot/hash contract, Keychain credential store, 12 MiB cap, and `gpt-audio-1.5`. It returned the bounded reason: `The provider rejected the OpenAI credential.` No credential value or response body was printed.
- Therefore actual model listening is **not proven and must not be claimed**.
- Cloud text and cloud audio consent switches were restored off after testing.
- No owner/user listening result was collected. No improvement, broad preference, or expert-quality claim is authorized.

## Limitations and next step

- Cloud conversation and audio listening remain unavailable until the configured OpenAI credential is replaced or granted access; deterministic offline teaching remains operational.
- The app's accessibility observer requires the companion app to remain unsandboxed. It has no AX setters, actions, synthetic input, or model mutation tools, but that entitlement boundary deserves continued review.
- Logic observation covers currently visible accessibility state only; it is not project graph introspection.
- The first heap-probe repeat contained one scheduler outlier above a 128-frame deadline. The p99 and immediate repeat were comfortably below deadline with zero heap operations, but a longer host soak should characterize scheduling tails.
- The strongest next step is to provision a valid scoped OpenAI credential, rerun the exact hash-bound synthetic capture through the installed app until a receipt records `heardByModel`, then run a blinded owner-listening A/B on representative material and record the explicit outcome.
