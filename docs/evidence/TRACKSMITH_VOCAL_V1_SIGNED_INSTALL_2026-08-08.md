# TrackSmith Vocal v1 — signed install and AU validation

**Date:** 2026-08-08
**Verification refreshed:** 2026-08-09
**Evidence class:** development-Mac installed-artifact verification
**Vocal gate:** V7 — passed at the bounded scope below

This record proves the exact local Apple Development-signed app and AU installed
for the current Vocal v1 worktree. It does not prove a notarized distribution,
direct Logic use, a real-vocal workflow, artistic quality, owner preference, or
release completion.

## Installed identity

| Item | Observed value |
|---|---|
| Installed app | `/Users/marcboyer/Applications/Logic Audio Assistant.app` |
| App bundle ID | `com.marcboyer.logicaudioassistant` |
| AU bundle ID | `com.marcboyer.logicaudioassistant.AudioUnit` |
| AU component | `aufx / LgAA / ExAI`, version `1.0.0` |
| Signing identity class | Apple Development |
| Team ID | `KDV9RC892F` for both app and AU |
| App CDHash | `50dcaffa61f648a02d3f082aea5988cd94e4e418` |
| AU CDHash | `e102031e47697b12f46d67d5b4352097f80e65b5` |
| App executable SHA-256 | `fe6237bd21f7bdd02083eba39cc02fcd8aa7f4c994e27889681370523dcf0346` |
| AU executable SHA-256 | `562172201af2ce70aff0f5ef161172b557335903a1af49c4bab3a948661093a7` |
| Architecture | thin Mach-O arm64 for both app and AU |

The installed executable hashes exactly matched the corresponding executables
inside `.build/xcode-signed-derived/Build/Products/Release`. `codesign --verify
--deep --strict` reported the installed app valid on disk and satisfying its
Designated Requirement.

## Entitlements and registration

Both signed targets carry:

- `com.apple.security.app-sandbox = true`;
- App Group `KDV9RC892F.com.marcboyer.logicaudioassistant`;
- `com.apple.security.get-task-allow = true`, appropriate to this local
  development build.

Only the companion has `com.apple.security.network.client`; the AU does not.
`pluginkit -m -v -p com.apple.AudioUnit-UI` listed exactly one matching extension,
at the installed app path. The transient DerivedData registration was removed by
the installer before the installed extension was registered.

## AU validation

`auval -v aufx LgAA ExAI` loaded the version 3 AU out of process and ended with
`AU VALIDATION SUCCEEDED`. The run passed open/initialization, default formats,
required/recommended properties, class state, host callbacks, parameter
retention, mono/stereo format handling, render slices, sample rates from 11.025
to 192 kHz, bad-maximum-frame refusal, connection semantics, scheduled and
ramped parameters, and MIDI probing. The validator emitted a non-failing
deprecated-`CurrentPreset` recommendation and found no custom Cocoa view; neither
changes the validation verdict.

## Installed App Group observation

The out-of-process installed AU published two fresh heartbeat records during
validation:

- `E32248B4-A9D6-4AE4-AC14-AFC7F9057EFC`, runtime epoch
  `A7623769-5574-4F15-9AB0-280097A3EA4D`;
- `BC1ACCE7-26C5-4298-B94C-9254ABA32649`, runtime epoch
  `ED79FC18-88CD-4C96-8238-A8B1BCB004CF`.

Each record was a mode `0600`, owner-only JSON file in
`KDV9RC892F.com.marcboyer.logicaudioassistant/LogicAudioAssistant/Exchange-v1`,
with schema `1.0`, plug-in version `1.0.0`, finite input peak, bypass state, and
timestamp. A separate Debug companion with the same bundle identifier was already
running under concurrent human use, so the final installed companion was not
launched or substituted for it. The installed app entitlement was inspected, and
the installed AU publication proves the bounded container path. The broader
capture/preview/commit round trip is separately exercised by `AudioUnitHostProbe`;
no fresh installed-companion or direct Logic round trip is inferred.

## Claim boundary

V7 is passed because the signed install, exact installed identity, entitlement
match, single registration, out-of-process AU validation, installed container
publication, and shared typed IPC regression are all observed. V8 remains
pending: the owner has not yet completed the exact real-vocal direct Logic and
blinded listening procedure.
