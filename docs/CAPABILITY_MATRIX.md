# Logic integration capability matrix

Status as of 2026-07-12. Local evidence: macOS 26.3 arm64, Logic Pro 11.2.2
(`com.apple.logic10`, universal binary), Swift 6.2.1, Xcode 26.6 / SDK 26.5.
“Documented” means a public vendor document exists; “verified” means this repository
ran a proof. Nothing in this table claims Logic-host success unless stated.

Apple documents AUv3 effects, buses, render blocks, parameters, transport/musical
callbacks, persistence, bypass and latency in [`AUAudioUnit`](https://developer.apple.com/documentation/audiotoolbox/auaudiounit), and Logic documents use of [AUv3 extensions](https://support.apple.com/guide/logicpro/work-with-audio-units-in-logic-pro-for-mac-lgcp22a0dab0/mac).

| Mechanism | Read / write capability | Selection / audio / plug-ins / automation | Apple Silicon, sandbox, permission | Evidence and production judgment |
|---|---|---|---|---|
| AUv3 effect | Reads its input buses and host callbacks; writes its output and own state/parameters | No selected-region API; input-stream audio only; controls own parameters; host may automate them | Supported on Apple Silicon; no microphone permission for insert audio; final sandbox/App Group entitlements pending team IDs | Xcode builds and locally signs the containing app/extension. An in-process Apple host probe passes mono/stereo rendering, capture, graph state and restore. LaunchServices sees the AU extension; `auval`/Logic validation still pending a clean registrar restart. **Production core.** |
| AUv2 | Similar audio/parameter host contract; component bundle distribution | Does not add a Logic project API | Apple says AUv2 is maintenance mode; sandbox compatibility varies | [Apple recommends AUv3 for new work](https://developer.apple.com/documentation/audiotoolbox/hosting-audio-unit-extensions-using-the-auv2-api). **Fallback only if a measured Logic blocker requires it.** |
| Native companion | Owns UI, disk, models, preview cache, Keychain, imports | Cannot introspect Logic merely by being installed | Final sandbox, user-selected-file, network, and App Group entitlements are not configured yet | Native SwiftUI target builds and is locally signed; its current controls are scaffold-only. **Production.** |
| App Groups | Shared container plus supported IPC primitives | Shares product state, not Logic state | Same signing team and entitlements; supported for apps/extensions/XPC | Two release processes exchanged an atomic message. Signed group not yet verified. [Apple App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups). **Production candidate.** |
| XPC / process boundary | Typed local service calls when entitlement and lifecycle permit | Heavy work only; no new Logic authority | Sandboxed XPC requires correct group/Mach service design | Not implemented; App Group exchange is current fallback. **Candidate after signing spike.** |
| Core MIDI | Creates endpoints; sends/receives MIDI | Can drive user-mapped controls; no audio or project DOM | Native Apple Silicon; MIDI permission behavior to test | API documented, adapter not implemented. [Virtual endpoints](https://developer.apple.com/documentation/coremidi/midiendpointref). **Production for explicit mappings.** |
| Virtual MIDI endpoints | Software source/destination visible to Logic | Same as MIDI; feedback depends on Logic assignment/protocol | No private framework; user must connect/assign | Public API documented; direct Logic test pending. **Production candidate.** |
| Logic control surfaces / assignments | Bidirectional mapped mixer, transport and exposed plug-in parameters | Selected channel feedback and automation are possible for supported mappings; arbitrary project edits are not guaranteed | Apple Silicon supports built-in profiles/scripts; third-party legacy plug-ins are constrained | [Controller assignments](https://support.apple.com/en-ie/guide/logicpro/ctls71c31487/10.7/mac/11.0). **Capability-gated.** |
| Mackie Control / HUI | MIDI protocol for supported Logic surface profiles | Transport, bank/track selection, mixer and mapped plug-in control; semantics/profile state require tests | Uses built-in Logic support; user setup required | Logic guide documents control surfaces, not a general software-agent API. **Experimental until state feedback is verified.** |
| Logic key commands | Invokes user-configured commands | Can trigger transport/bounce/navigation; state readback absent | Requires user mapping/focus or MIDI assignment | Apple documents key-command mapping through control surfaces. **User-mediated only.** |
| Accessibility (`AXUIElement`) | Reads exposed semantic attributes/actions; can set or press exposed elements | Potential UI selection/insertion/bounce; reliability depends on Logic's accessibility tree | Accessibility permission required; sandbox entitlement/consent; UI/version sensitive | Apple API can return not-implemented, invalid, or cannot-complete errors. [AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h). **Feature-flagged experimental.** |
| Apple Events / AppleScript | Only the target app's published dictionary, plus UI scripting through System Events | No public Logic project dictionary was proven; UI scripting collapses to Accessibility | Automation and possibly Accessibility consent | `sdef` could not run because full Xcode is absent; existing Python starter is unverified UI scripting. **Not stable.** |
| Drag/drop or explicit import | User grants a file and places rendered alternatives | Full source file only when user supplies it; no selection inference | User-selected file permission; sandbox friendly | WAV reader/writer and offline tools work. **Production fallback.** |
| Bounce in Place | Logic renders track/region through its own UI command | Can create/replace material but is project destructive depending on options | User action/key command/AX; no public direct API found | Apple warns track replacement loses original content/most automation. [Bounce behavior](https://support.apple.com/en-mide/guide/logicpro/lgcp8aa3b784/10.7/mac/11.0). **User-mediated, never automatic in MVP.** |
| Buffer input in plug-in | Copies audio already passing through insert into bounded memory | Bounded recent interval; explicit “next” arming is not wired yet; not the selected source file | No microphone permission; no disk/file work on render | Atomic-payload ring, chronology test, and AU host capture proof pass. A reserved overwrite guard permits safe non-real-time snapshots during playback. **Production after Logic test.** |
| ARA 2 | Host/plug-in share regions, audio files, structure and analysis | Directly addresses timeline/source access for compatible audio tracks | Logic supports ARA 2; third-party SDK/licensing and vendor approval required; operational limitations apply | [Logic ARA 2 support](https://support.apple.com/en-ie/guide/logicpro/lgcp58ce340b/10.7/mac/11.0). **Future licensed spike, not MVP dependency.** |
| User-mediated workflows | Explicit insert, capture, import, export, key command, drag/drop | Reliable because the user establishes scope and verifies result | Minimal permissions | **Primary fallback and production UX.** |
| Other official Logic extension system | AUv3, MIDI Device Scripts/control assignments, and ARA 2 were found | No official general project-editing extension was found | Varies | Recheck each supported Logic release. **No speculative authority.** |

## Direct answers to the spike questions

1. **Can an AU know the selected Logic region?** No public AU API found.
2. **Can it access the selected region's source file?** No through AUv3. User import works; ARA 2 may when licensed and correctly integrated.
3. **Can it access only audio passing through its insert?** Yes, through its input bus.
4. **Can it identify its host track?** `contextName` can contain host context such as a track label, but hosts choose what to provide; Logic behavior is unverified and must not be an identity key.
5. **Can it receive transport/timeline information?** AU host transport and musical-context callbacks exist; Logic delivery is pending host test.
6. **Can it buffer a bounded interval?** Yes in the AU class host probe: incoming samples enter a preallocated atomic ring with no file I/O or allocation on render. Logic validation remains open.
7. **Can a companion communicate with it?** Supported App Group mechanisms exist and two local processes exchanged a message. Signed app/extension reliability is not yet proven.
8. **Can it manipulate its own parameters?** Yes, through `AUParameterTree`; host automation is part of the AU API.
9. **Can it control native Logic plug-ins?** No direct public project API. User MIDI mappings/control surfaces or Accessibility are limited adapters.
10. **Can it insert Logic/third-party plug-ins?** No stable public API found.
11. **Can it inspect an existing channel strip?** No stable public API found; partial control-surface feedback is not a complete strip model.
12. **Can it create automation?** Hosts can automate the product's exposed AU parameters. Arbitrary Logic automation is only a user-mapped/experimental control path.
13. **Can it create/duplicate tracks or regions?** No stable public API found.
14. **Can it safely invoke Bounce in Place?** No direct API. User invocation is safest; Accessibility/key-command automation is experimental and must verify every dialog/result.
15. **Can control-surface feedback determine selected track?** Possibly enough for a mapped surface, but identity and synchronization are unverified; not stable scope authority.
16. **Can Accessibility identify controls semantically?** Only to the degree Logic exposes roles, labels, values, actions, and stable hierarchy. Direct tests are required per version; coordinates are prohibited.
17. **What joins Logic native undo?** Host-recorded changes to exposed AU parameters and Logic's own commands may. Product graph snapshots and external UI sequences cannot assume native undo.
18. **What needs product snapshots?** Every graph proposal/commit, preview, node lock/removal, provider result, and all experimental project-action transactions.
19. **What remains impossible without new APIs?** A supported general Logic project DOM: arbitrary region/source access, channel-strip inspection, insert/reorder, track/region creation, and verified project transactions.
