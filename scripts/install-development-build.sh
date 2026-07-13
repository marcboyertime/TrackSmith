#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
derived_data="$repo_root/.build/xcode-signed-derived"
source_app="$derived_data/Build/Products/Debug/Logic Audio Assistant.app"
destination="$HOME/Applications/Logic Audio Assistant.app"

identity_line="$(security find-identity -v -p codesigning | grep '"Apple Development:' | head -1 || true)"
if [[ -z "$identity_line" ]]; then
  print -u2 "error: no Apple Development signing identity is installed"
  print -u2 ""
  print -u2 "Open Xcode → Settings → Accounts, add your Apple Account, then"
  print -u2 "Manage Certificates → + → Apple Development. Rerun make native-install."
  exit 2
fi

identity_hash="$(print -r -- "$identity_line" | sed -E 's/^[[:space:]]*[0-9]+\) ([0-9A-F]+) .*/\1/')"
development_team="$(print -r -- "$identity_line" | sed -E 's/.*\(([A-Z0-9]{10})\)".*/\1/')"
if ! print -r -- "$identity_hash" | grep -Eq '^[0-9A-F]{40}$' || \
   ! print -r -- "$development_team" | grep -Eq '^[A-Z0-9]{10}$'; then
  print -u2 "error: could not derive the Apple Development identity or Team ID"
  print -u2 "identity: $identity_line"
  exit 2
fi

cd "$repo_root"
xcodegen generate
xcodebuild \
  -project LogicAudioAssistant.xcodeproj \
  -scheme CompanionMacApp \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="$identity_hash" \
  DEVELOPMENT_TEAM="$development_team" \
  build

app_team="$(codesign -dv --verbose=4 "$source_app" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
extension_team="$(codesign -dv --verbose=4 "$source_app/Contents/PlugIns/Logic Audio Assistant AU.appex" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [[ "$app_team" != "$development_team" || "$extension_team" != "$development_team" ]]; then
  print -u2 "error: Xcode did not produce matching development-signed app and extension bundles"
  print -u2 "expected Team ID: $development_team; app: $app_team; extension: $extension_team"
  exit 2
fi

mkdir -p "$HOME/Applications"
ditto "$source_app" "$destination"
codesign --verify --deep --strict --verbose=1 "$destination"

print "Installed signed development build:"
print "  $destination"
print "Team ID: $development_team"
print "Next: close Logic if it is open, launch this app once, then reopen Logic."
