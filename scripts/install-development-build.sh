#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
derived_data="$repo_root/.build/xcode-signed-derived"
source_app="$derived_data/Build/Products/Release/Logic Audio Assistant.app"
destination="$HOME/Applications/Logic Audio Assistant.app"
staged_destination="$HOME/Applications/.Logic Audio Assistant.installing.$$.app"
source_extension="$source_app/Contents/PlugIns/Logic Audio Assistant AU.appex"
installed_extension="$destination/Contents/PlugIns/Logic Audio Assistant AU.appex"

certificate_subject="$(
  security find-certificate -a -c 'Apple Development' -p "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    || true
)"
# The parenthesized code in an Apple Development certificate's display name is
# not necessarily its Team ID. The signed certificate subject's OU is authoritative.
development_team="$(print -r -- "$certificate_subject" | sed -E 's/.*OU=([A-Z0-9]{10}).*/\1/')"

if ! print -r -- "$development_team" | grep -Eq '^[A-Z0-9]{10}$'; then
  print -u2 "error: no usable Apple Development certificate or Team ID was found"
  print -u2 ""
  print -u2 "Open Xcode → Settings → Accounts, add your Apple Account, then"
  print -u2 "Manage Certificates → + → Apple Development. Rerun make native-install."
  exit 2
fi

cd "$repo_root"
xcodegen generate
xcodebuild \
  -project LogicAudioAssistant.xcodeproj \
  -scheme CompanionMacApp \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
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
rm -rf "$staged_destination"
trap 'rm -rf "$staged_destination"' EXIT
ditto "$source_app" "$staged_destination"
codesign --verify --deep --strict --verbose=1 "$staged_destination"
rm -rf "$destination"
mv "$staged_destination" "$destination"
trap - EXIT
codesign --verify --deep --strict --verbose=1 "$destination"

# Xcode's RegisterWithLaunchServices build phase registers the derived-data copy.
# Remove that transient record and register only the exact installed bundle so hosts
# cannot discover two equal-version extensions at different paths.
pluginkit -r "$source_extension" 2>/dev/null || true
pluginkit -a "$installed_extension"

print "Installed signed development build:"
print "  $destination"
print "Team ID: $development_team"
print "Next: close Logic if it is open, launch this app once, then reopen Logic."
