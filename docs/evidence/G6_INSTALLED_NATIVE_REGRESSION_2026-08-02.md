# G6 installed native regression evidence — 2026-08-02

## Ledger status

**G6 is in progress, not passed.** This record adds fresh native verification,
signed-install, and Audio Unit validation evidence. It does not substitute
custom-host results for the direct Logic workflow and recovery regression required by
the milestone plan.

Provenance class: `tracksmith_measurement`.

## Fresh native and installed evidence

| Command | Fresh result | What it establishes |
| --- | --- | --- |
| `make native-verify` | Exit 0. The Xcode Debug arm64 build reported `BUILD SUCCEEDED`. Release HostProbe reported `PERF callback frames=128 rate=48000 mean=13.9 us p99=17.9 us max=44.3 us deadline=2666.7 us`; the heap lane reported `RT_HEAP callback iterations=4000 operations=0`; heap HostProbe reported `mean=13.4 us p99=14.6 us max=55.2 us`; the expected `PASS` lines were emitted. | The current source builds in the native Debug lane and passes the exercised custom-host and interposed-heap paths. |
| `make native-install` | Exit 0. A signed Release app was installed at `/Users/marcboyer/Applications/Logic Audio Assistant.app` with Team ID `KDV9RC892F`. | The current signed Release artifact was installed at the declared user application path. |
| `auval -v aufx LgAA ExAI` | Exit 0; `AU VALIDATION SUCCEEDED`. | System AU discovery, instantiation, and the validator's exercised property/render matrix passed for component `aufx/LgAA/ExAI`. |

The HostProbe and heap results above are custom-host evidence. The p99 value is a
measurement of that exercised callback path, not a timing measurement inside Logic.
Likewise, `auval` is not a Logic project workflow result.

### Fresh installed-bundle identity and hashes

Strict verification was run against the installed app and its embedded Audio Unit:

```text
codesign --verify --deep --strict --verbose=2 "/Users/marcboyer/Applications/Logic Audio Assistant.app"
/Users/marcboyer/Applications/Logic Audio Assistant.app: valid on disk
/Users/marcboyer/Applications/Logic Audio Assistant.app: satisfies its Designated Requirement

codesign --verify --deep --strict --verbose=2 "/Users/marcboyer/Applications/Logic Audio Assistant.app/Contents/PlugIns/Logic Audio Assistant AU.appex"
/Users/marcboyer/Applications/Logic Audio Assistant.app/Contents/PlugIns/Logic Audio Assistant AU.appex: valid on disk
/Users/marcboyer/Applications/Logic Audio Assistant.app/Contents/PlugIns/Logic Audio Assistant AU.appex: satisfies its Designated Requirement
```

Both the app and embedded AU report `TeamIdentifier=KDV9RC892F`, and both
entitlement payloads include `KDV9RC892F.com.marcboyer.logicaudioassistant`. The
fresh SHA-256 values of their installed executables are:

```text
app: 1cab1b5a3f2aa0823f0e72db342812fb38ab5e5734e9103e0deb7f5251dc36ec
AU:  1d57842b7a735f293d2f9e4ea90749019e20cf22da21de63317dc955d3d0bf99
```

These are installed-bundle identity and byte-hash checks. They do not establish
direct Logic transaction, recovery, instance-isolation, unchanged-source, or
perceptual evidence.

## G6 acceptance accounting

The G6 definition in
[`docs/PRODUCTION_MASTERY_PERCEPTUAL_EVALUATION_V1.md`](../PRODUCTION_MASTERY_PERCEPTUAL_EVALUATION_V1.md)
requires an accepted release candidate to rerun G0 plus new-node AU state restore,
signed binary and App Group verification, `auval`, and a direct Logic sequence
covering capture, preview, revision, lock, exact commit, bypass/restore, save/reload,
provider-offline playback, instance isolation, unchanged source, representative
listening cases, and exact approved-result recovery.

| G6 requirement | Status from this record |
| --- | --- |
| Native current-source build; custom-host and real-time heap check | Passed for the exercised `make native-verify` lanes. |
| Signed installed binary | Passed for the installed Release app. |
| Fresh App Group verification | Passed: installed app and embedded AU both carry `KDV9RC892F.com.marcboyer.logicaudioassistant`; TeamIdentifier `KDV9RC892F`; deep strict codesign verification passed. |
| Fresh installed executable hashes | Passed: app `1cab1b5a3f2aa0823f0e72db342812fb38ab5e5734e9103e0deb7f5251dc36ec`; embedded AU `1d57842b7a735f293d2f9e4ea90749019e20cf22da21de63317dc955d3d0bf99`. |
| `auval` | Passed. |
| Fresh G0 rerun and new-node production-AU state restore | Not recorded by this evidence. |
| Fresh direct Logic capture-to-recovery workflow, provider-offline playback, instance isolation, and unchanged-source verification | The newest current-source transaction records bounded capture, exact commit, bypass on/off acknowledgements, final `bypass=false`, and a two-instance live probe; the subsequent save/close/reopen observation retains each persisted plan and epoch with `bypass=false` in new instances. Prior current sections retain bounded provider-offline and project-media byte-stability observations. Complete recovery, provider restoration, full isolation/recovery, and complete project-source comparison remain open. Partial. |
| Representative listening cases and exact approved-result recovery | Partial for bounded system transaction evidence only: the newest current-source capture, exact commit acknowledgement, committed plan identity, bypass/restore acknowledgements, two-instance probe, and subsequent persisted-plan save/close/reopen observation are recorded below. Persistence is not human approval, exact approved-result recovery, or representative listening evidence; those gates remain open. |

Fresh installed-bundle verification now records `codesign --verify --deep
--strict` success for the installed app and embedded AU. Both entitlements carry
`KDV9RC892F.com.marcboyer.logicaudioassistant`; the app reports TeamIdentifier
`KDV9RC892F`. This closes the signed-bundle/App Group identity check, but not the
direct Logic transaction and recovery sequence.

Historical direct-Logic records remain historical evidence; they do not make this
fresh G6 release-candidate regression complete. The residual gap is therefore a full,
current direct Logic interactive regression with retained artifacts, including the
required recovery and listening evidence.

## Additional direct Logic observation

The installed Logic Pro application opened the retained Direction Mixer project at
`research/evaluation/logic-native-empirical-runs/logic-12.3-direction-mixer-production-profile-2026-08-02/project/` and played it through the MacBook Pro Speakers. The Logic transport entered Play and the channel meters moved without clipping. The retained screen capture is
`docs/evidence/G6_LOGIC_DIRECT_PLAYBACK_2026-08-02.png` (SHA-256
`07022bd7cb229c7029d515daed9fcabca38f9480b3efbddb7a7dafbd76af1fa4`). This is
direct Logic playback evidence only; it does not close the required TrackSmith
capture/preview/revision/commit/recovery sequence or establish perceptual success.

## Disposable-copy playback/save-reload observation

On 2026-08-02, a disposable copy
`/tmp/TrackSmith-G6-current.tyacu0/TrackSmith-G6-current.logicx` was opened in
installed Logic Pro. Direct transport playback showed active meters. The copy was
saved with `Cmd-S`, closed, reopened, and returned to the saved project with
playback available. The retained screen capture is
`docs/evidence/G6_LOGIC_PLAYBACK_SAVE_RELOAD_2026-08-02.png` (SHA-256
`4058df0aed41b773c357f6e1167fc5b7a941ee577fa2b75bd2b75cf427e84a91`).

This is playback/save-reload evidence only; it does not establish capture, preview,
revision, commit, rollback, provider-offline, instance isolation, unchanged-source,
or recovery.

## Primary-session installed-artifact validation — 2026-08-02

The primary session performed the following fresh checks against the installed
Release artifact:

| Check | Result | What it establishes |
| --- | --- | --- |
| `auval -v aufx LgAA ExAI` | Exit 0; `AU VALIDATION SUCCEEDED`. | Installed system Audio Unit discovery and validator coverage for `aufx/LgAA/ExAI`. |
| `codesign --verify --deep --strict "/Users/marcboyer/Applications/Logic Audio Assistant.app"` | Passed. | The installed application bundle is valid under strict deep code-signature verification. |
| `codesign --verify --deep --strict "/Users/marcboyer/Applications/Logic Audio Assistant.app/Contents/PlugIns/Logic Audio Assistant AU.appex"` | Passed. | The installed nested Audio Unit extension is valid under strict deep code-signature verification. |
| Installed AU `Info.plist` inspection | Bundle identifier `com.marcboyer.logicaudioassistant.AudioUnit`; component `aufx/LgAA/ExAI`; `sandboxSafe=true`. | The installed extension declares the expected identity, Audio Unit component, and sandbox-safety flag. |

These checks establish installed-artifact identity and validator success only. They
do not establish Logic capture, preview, revision, commit, rollback, recovery, App
Group isolation, unchanged-source, or representative listening evidence; the full
installed Logic transaction/recovery gate remains open.

## Latest post-install registration transient and recovery — 2026-08-02

The latest signed Release reinstall preserved an important registration-timing
observation rather than collapsing it into a single green result:

1. `make native-install` passed and installed the signed Release app.
2. An immediate `auval -v aufx LgAA ExAI` invocation failed to find the component
   because the newly installed Audio Unit was not yet registered.
3. After launching `/Users/marcboyer/Applications/Logic Audio Assistant.app` once,
   rerunning `auval -v aufx LgAA ExAI` passed with `AU VALIDATION SUCCEEDED`.
4. Strict deep codesign verification passed for the app and nested Audio Unit.

The latest installed executable SHA-256 values are:

```text
app: 6ac8b00c46177ab49da8b8a638781c3ce40296d2681e7e92e08dc8dc1dd5a26d
AU:  1d57842b7a735f293d2f9e4ea90749019e20cf22da21de63317dc955d3d0bf99
```

The earlier app hash recorded above (`1cab1b5a3f2aa0823f0e72db342812fb38ab5e5734e9103e0deb7f5251dc36ec`)
is retained as a prior installed-artifact observation; this section identifies the
latest reinstall. The transient `auval` miss and post-launch recovery establish
registration behavior and validator success only. They do not close the direct Logic
capture, preview, revision, commit, rollback, provider-offline, instance-isolation,
unchanged-source, recovery, or listening requirements.

## Historical Logic Pro 12.3 frontier-workflow reconciliation

This section reconciles the direct-Logic portion of the current G6 acceptance matrix
with the existing [2026-07-27 frontier-AI validation report](LOGIC_12_3_FRONTIER_AI_VALIDATION_2026-07-27.md).
Every claim in the historical-coverage column below is attributable only to that
dated report and its one exercised Logic Pro 12.3 session. It is useful direct-Logic
evidence, but it is not a 2026-08-02 current-source rerun and cannot promote G6.

In particular, the historical report identifies source commit
`97d52ea6023af2b79188b966f4f0b77211f5c557` and historical installed executable
hashes `81166dd7de58a84238cfd5baef74767f78dd192b2b4db56479b4f445a6803d1d`
(app) and `0783992c6e9533e76820553a3a62b349e85db7531a57c923c4d616f00aa5893f`
(AU). Those 2026-07-27 identities are not asserted to identify the current source
or installed release candidate. The separately dated 2026-08-02 installed hashes,
`auval`, strict codesign, and App Group observations above remain the only current
installed-artifact evidence in this record.

The failed current CUA `remoteConnection` attempt provides no evidence of companion
UI behavior, so no cell below infers companion behavior from it. Likewise, the
current direct-playback and disposable-copy save/reload observations remain limited
to the scope stated above; they do not supply a current capture-to-recovery
transaction.

| G6 direct-Logic requirement | Coverage in the 2026-07-27 frontier report (historical direct Logic) | Related 2026-08-02 evidence and boundary | Fresh current-source G6 evidence? |
| --- | --- | --- | --- |
| Capture | Logic played the source through the inserted AU; the companion located that specific live instance and requested a recent capture through the signed App Group exchange. The report retains a capture snapshot, descriptor/WAV metadata, frame count, source snapshot, and SHA-256. | The current record shows direct Logic playback only; it records no current companion capture transaction. | No. |
| Preview | Three finite, source-bound, editable preview candidates were validated, including disclosed loudness-match limits. | No current companion preview run is recorded. | No. |
| Revision | The report records one accepted natural multi-turn revision with typed preview and node references, explicit lock behavior, and validation gates. | No current companion revision run is recorded. | No. |
| Lock | The accepted revision retained the identified EQ node as locked, with its exact parameters recorded. | No current lock operation or post-operation state is recorded. | No. |
| Exact commit | The capture-bound plan was committed through compare-and-swap; the report records matching working-preview/result-snapshot plan hashes and a live-AU heartbeat for the request/graph. | No current commit or current exact plan/result identity is recorded. | No. |
| Bypass/restore | Global bypass was toggled on and off without discarding the plan; after reopen, the restored insert reported the committed request, exact graph, locked EQ, and bypass `false`. | The current playback observations do not exercise or inspect bypass or restored AU state. | No. |
| Save/reload | Logic and the companion were quit after save, then the project was reopened with the committed graph restored. | A current disposable copy was saved, closed, reopened, and played. The appended current-source installed-Logic observation additionally records exact persisted plan, epoch, and `bypass=false` retention across `Cmd-S`, close, and reopen for two distinct instances; it is persistence evidence only and does not establish the complete G6 workflow or recovery. | Partial for persisted-plan save/close/reopen only; current preview/revision, complete recovery, and listening gates remain open. |
| Provider-offline playback and restoration | The historical reopen began with the companion unavailable, and the saved deterministic graph did not require the provider for playback or restoration. | Bounded provider-offline playback with persisted graphs is recorded in the appended section, but complete provider restoration is not. | Partial. |
| Instance isolation | A second live AU instance retained its different graph and epoch while the validated instance was committed, bypassed, restored, saved, and reopened. | Distinct current instances and persisted plan IDs are recorded in the appended section, but the full isolation/recovery workflow is not closed. | Partial. |
| Unchanged source | The report records the same project-source SHA-256 before the workflow and after save/reload. | The installed Logic save/close/reopen cycle hashed project media file `Media/Audio Files/source-vocal-48k-mono.wav` before and after: SHA-256 `fb61fc24468af8b852717e459c63d1a495281583265221ebbe7bafdfe2dd8192` both times, with size 1,061,290 bytes both times. This is bounded byte-stability evidence for that media file, not a complete project-source comparison; the appended persistence run did not produce a source project hash. | Partial. |
| Exact approved-result recovery | The historical working-preview and persisted result-snapshot plan hashes matched; the reopened insert restored the same graph, while the companion recovered the conversation as historical view-only state after the runtime epoch changed. | Current-source evidence records capture, the exact commit acknowledgement, committed plan request identity, and save/close/reopen retention. This is bounded committed-plan persistence only; it is not a human-approved result, an approved-result/result-snapshot identity, or approved-result recovery. | Partial for committed-plan persistence only; approved-result recovery remains open. |
| Representative listening cases | The historical report expressly leaves listening decisive and does not claim artistic or perceptual success. | Current playback and meter observations are not listening-case evidence. | No; perceptual/listening evidence remains open. |

The historical workflow therefore supplies dated coverage for the named direct Logic
behaviors, while the current record supplies separately bounded installation,
validation, playback, and narrow project save/reload observations. It does not
convert the historical workflow into fresh release-candidate evidence. G6 remains in
progress until a current-source direct Logic capture-to-approved-result recovery
rerun retains the required artifacts, including representative listening evidence.

## Current-source installed Logic frontier session — 2026-08-02

**G6 status remains `in_progress`.** This dated section records the current-source
frontier project session exercised through installed Logic Pro and the signed App
Group transaction. It is artifact-backed installed Logic evidence only; it does not
replace the historical sections above, substitute custom-host results, or infer a
source, instrument, or vocal identity from the project.

The historical reconciliation table above is preserved, with its dated historical coverage and prior `No` cells left intact; its `No` cells
describe the evidence available when that historical matrix was written. This
appended section records the separate current-source transaction evidence below.

### Capture and exact plan commit

- Capture request `57818AB9-9575-446E-A669-8E5D19767E0F` produced capture artifact
  `5F728750-6781-439D-9F6A-A8ECBE68671A` with SHA-256
  `7c082fe05965f2dcdf80e91ce7b5934f0902d4904935574d99d4c66175c242a4`. The retained
  capture is 44,100 Hz, mono, and 273,408 frames.
- Commit request `1B61E669-40CE-4E7C-BE5A-091951FB28C4` returned the exact
  acknowledgement `Validated graph published for the next audio block.` The
  committed plan request ID is `4BDE4D93-9AE3-4956-B633-B1BA6FDEECE1`.
- After that transaction, instance
  `F492BBF9-3C9F-471D-ADC9-184DDFE460C2` reported runtime epoch
  `E721F3DC-4EC8-42E8-9D17-6053EB53EFD1`, persisted plan
  `4BDE4D93-9AE3-4956-B633-B1BA6FDEECE1`, and bypass `false`.

These records establish the observed installed Logic/App Group capture and exact
commit acknowledgement for this session. They do not establish preview, revision,
or perceptual success.

### Bypass acknowledgements

- Bypass-on request `7EA028EF-607C-44FE-883D-3AE340F5F720` returned
  `Global bypass enabled; the committed graph remains loaded.`
- Bypass-off request `5FEA35AC-1001-4FDB-998F-5E4D32FECC09` returned
  `Global bypass disabled; the committed graph was restored.`

The two acknowledgements document the observed on/off transaction and the reported
restoration of the committed graph; they do not by themselves prove a complete G6
recovery workflow.

### Save/reload persistence and instance isolation

After save, close, and reopen, new instance
`3290C101-9FA6-42BD-B6C2-888D831ADD73` retained persisted plan
`4BDE4D93-9AE3-4956-B633-B1BA6FDEECE1` with bypass `false`. A separate instance
`3D97CEA8-B3BB-4E48-8D49-358F6EEE489B` retained plan
`D1FBF3F8-769E-4479-ABCA-B9BF7ACCDD50`, also with bypass `false`. Within this
observed session, the distinct persisted plan IDs provide bounded instance-isolation
evidence while the first new instance demonstrates save/reload persistence of the
committed plan.

The retained save/reload screenshot is
`docs/evidence/G6_LOGIC_CURRENT_SAVE_RELOAD_2026-08-02.png` with SHA-256
`aed075663f9f08aa6cc970a6e55a92d69a1dbaefde474c2242881279018f4e34`.

### Exact committed-plan persistence boundary — 2026-08-02

The current-source installed Logic session records a bounded persistence chain:
capture artifact SHA-256 `7c082fe05965f2dcdf80e91ce7b5934f0902d4904935574d99d4c66175c242a4`
was followed by commit request `1B61E669-40CE-4E7C-BE5A-091951FB28C4`, whose exact
acknowledgement was `Validated graph published for the next audio block.` The
acknowledged committed plan request ID was
`4BDE4D93-9AE3-4956-B633-B1BA6FDEECE1`; after save, close, and reopen, instance
`3290C101-9FA6-42BD-B6C2-888D831ADD73` retained that persisted plan, while distinct
instance `3D97CEA8-B3BB-4E48-8D49-358F6EEE489B` retained its different plan.

This establishes exact committed-plan persistence and bounded instance distinction
only. The commit acknowledgement is a system transaction, not human approval; no
human-approved result, approved-result/result-snapshot recovery, representative
listening, perceptual success, or G6 closure is claimed, and the listening and
approval gates remain open.

### Remaining G6 gaps

This is current installed Logic/App Group transaction evidence for the frontier
project session, not G6 closure and not perceptual or representative-listening
evidence. The remaining gaps include current preview/revision, complete provider
restoration, exact unchanged-source hash comparison, approved-result recovery, and
representative listening. None of those unperformed gates is claimed here.

## Current-source capture-bound portable preview/revision slice — 2026-08-02

**G6 status remains `in_progress`.** The command result for this bounded run was
`PASS real-audio offline vertical slice`. It used the current-source capture with
SHA-256
`7c082fe05965f2dcdf80e91ce7b5934f0902d4904935574d99d4c66175c242a4` and produced
`valid_previews=3`, `source_unmodified=true`, and
`live_au_commit_proven=false`.

The complete retained artifact is
[`research/evaluation/production-mastery-v1/installed-logic-current-session-2026-08-02/`](../../research/evaluation/production-mastery-v1/installed-logic-current-session-2026-08-02/),
including `evidence.json`, `plans/`, `analysis/`, and `audio/`. The archived
`evidence.json` SHA-256 is
`4cb52a3c05515cb315ef483557abadb0f97839fd1f5a2b4fe210d5061f0464d7`.
Its recorded `overallPassed=true`, `sourceWasUnmodified=true`, and
`revisionRenderWasDeterministic=true` values are retained alongside the individual
check results.

The retained checks passed for deterministic previews, preview strength validation,
revision safety and determinism, locked-node preservation, unmentioned-node
preservation, undo/redo, dry-bypass sample exactness, and source-hash stability.
The evidence also records that the three preview strengths were rendered in order
and that the saved graphs reproduced their audition renders.

This is capture-bound portable workflow evidence for the captured input. It is not
installed-AU preview/revision evidence, does not prove a live Audio Unit commit, and
does not close G6. No perceptual success or source, instrument, or vocal identity is
claimed by this record.

## Provider-offline installed Logic playback — 2026-08-02

**G6 status remains `in_progress`.** After the companion process was intentionally
stopped, `/Users/marcboyer/Applications/Logic Audio Assistant.app/Contents/MacOS/Logic Audio Assistant`
was absent; only the Audio Unit extension process remained. The Logic project was
reopened with the current persisted plan `4BDE4D93-9AE3-4956-B633-B1BA6FDEECE1` on
instance `3290C101-9FA6-42BD-B6C2-888D831ADD73` and distinct plan
`D1FBF3F8-769E-4479-ABCA-B9BF7ACCDD50` on instance
`3D97CEA8-B3BB-4E48-8D49-358F6EEE489B`; both instances reported bypass `false`.

During direct Logic playback while the companion was unavailable, fresh input peaks
were `-9.288888931274414 dBFS` on both instances, with `updatedAt` around
`1785706018`. The retained screenshot is
`docs/evidence/G6_LOGIC_PROVIDER_OFFLINE_2026-08-02.png` (SHA-256
`d034828dd3bef467b843bde542df822defc852d58266a50a68cf92e0a792a718`).

This establishes only bounded provider-offline playback with persisted graph
availability in the observed instances. It does not prove complete provider
restoration, preview or revision, unchanged-source preservation, approved-result
recovery, or perceptual success; no instrument, vocal, or source identity is inferred.

## Current-source project-media hash stability — 2026-08-02

During the installed Logic save/close/reopen cycle for the current-source project,
the project media file `Media/Audio Files/source-vocal-48k-mono.wav` was hashed
before saving and again after closing and reopening:

| Check | Before save | After close/reopen |
| --- | --- | --- |
| SHA-256 | `fb61fc24468af8b852717e459c63d1a495281583265221ebbe7bafdfe2dd8192` | `fb61fc24468af8b852717e459c63d1a495281583265221ebbe7bafdfe2dd8192` |
| Size | 1,061,290 bytes | 1,061,290 bytes |

The identical hash and byte size prove byte stability for this project media file
across this observed cycle. They do not constitute a complete project-source hash
or full G6 closure; complete project-source comparison, recovery, listening, and
other open G6 gates remain outstanding.

## Fresh installed Logic transaction — 2026-08-02

**G6 remains `in_progress`; listening, approval, and recovery gates remain open.**
This separate installed-Logic transaction recorded the following bounded
capture/commit and bypass evidence:

- Capture request `CAB79A09-C751-427C-B4B1-A1ED18BDBC4E` produced artifact
  `50F78B54-FB32-43A4-AD76-061D959B19E7` with SHA-256
  `ec2169ca9fa9de5fd295dbc3c31f69187de4cd5c679b1d880b3329eeafac0062`. The
  captured audio is 44,100 Hz, mono, and 285,696 frames.
- Commit request `B226E10E-183D-4BE0-8970-1D76A8F5C600` ran on instance
  `70D163B1-615D-4C3F-A2EA-A9B65228774D` at epoch
  `14FBF465-F8AF-4858-83D3-420AE27E902F`, with committed plan
  `58213A7A-E593-44C7-8E9D-5F15B2F6F8A6`. The acknowledgement was
  `Validated graph published for the next audio block.`
- Bypass-on request `1D1B6EBE-EF3C-4773-8B51-079B32F43C91` returned
  `Global bypass enabled; the committed graph remains loaded.`
- Bypass-off request `2D5374EA-84B3-4823-A2B3-D17FDAE0195F` returned
  `Global bypass disabled; the committed graph was restored.` The final bypass
  state was `false`, and the applied command ID matched the bypass-off request.

The final live probe found both instance
`7D5D204B-4103-46A9-A736-851C658B495C` and instance
`70D163B1-615D-4C3F-A2EA-A9B65228774D` at 44,100 Hz mono, with plans present and
bypass `false`; the latter retained committed plan
`58213A7A-E593-44C7-8E9D-5F15B2F6F8A6`. The project was stopped and `Cmd-S` was
issued afterward. The subsequent section records the save/close/reopen persistence
observation from that saved project.

These records establish only the observed installed transaction. They do not claim
human approval, perceptual or representative-listening success, approved-result
recovery, full provider restoration, or G6 closure, and they make no instrument or
vocal identity claim.

## Current installed Logic save/close/reopen persistence — 2026-08-02

**G6 remains `in_progress`.** After the latest installed-Logic transaction above,
the same project path was saved with `Cmd-S`, the Logic project was closed, and that
same path was reopened. This is exact persisted-plan/save-reload evidence only; it
is not human-approved result recovery or listening evidence.

### State before close

Immediately before `Cmd-S` and close, the observed installed App Group instances
were:

| Instance | Persisted plan | Runtime epoch | Bypass |
| --- | --- | --- | --- |
| `70D163B1-615D-4C3F-A2EA-A9B65228774D` | `58213A7A-E593-44C7-8E9D-5F15B2F6F8A6` | `14FBF465-F8AF-4858-83D3-420AE27E902F` | `false` |
| `7D5D204B-4103-46A9-A736-851C658B495C` | `D1FBF3F8-769E-4479-ABCA-B9BF7ACCDD50` | `362C9411-BDF9-4D99-83EE-910881B33FED` | `false` |

### State after close and reopen

After closing and reopening the same path, new distinct instances retained the
corresponding plan, epoch, and bypass state:

| New instance | Retained persisted plan | Retained runtime epoch | Bypass |
| --- | --- | --- | --- |
| `99120EE3-38EF-4A5D-9323-7C148875446C` | `58213A7A-E593-44C7-8E9D-5F15B2F6F8A6` | `14FBF465-F8AF-4858-83D3-420AE27E902F` | `false` |
| `50F6D017-4B46-4700-AB27-B6EAA958FB80` | `D1FBF3F8-769E-4479-ABCA-B9BF7ACCDD50` | `362C9411-BDF9-4D99-83EE-910881B33FED` | `false` |

State JSON files for the reopened instances were observed in the installed App
Group `Exchange-v1/instances` directory. No source project hash was produced by
this save/close/reopen run.

The matching plan and epoch values across the pre-close and post-reopen instance
records establish bounded persisted-plan/save-reload retention for the observed
instances. They do not establish preview or revision, rollback, provider
restoration, complete instance isolation, unchanged source, human-approved or
approved-result recovery, representative listening, perceptual success, or G6
closure. All of those gates remain open where not separately evidenced above.
