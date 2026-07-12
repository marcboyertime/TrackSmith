#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
derived_data="$repo_root/.build/xcode-signed-derived"
source_app="$derived_data/Build/Products/Debug/Logic Audio Assistant.app"
destination="$HOME/Applications/Logic Audio Assistant.app"

cd "$repo_root"
xcodegen generate
xcodebuild \
  -project LogicAudioAssistant.xcodeproj \
  -scheme CompanionMacApp \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  build

mkdir -p "$HOME/Applications"
ditto "$source_app" "$destination"
codesign --verify --deep --strict --verbose=1 "$destination"

print "Installed signed development build:"
print "  $destination"
print "Next: close Logic if it is open, launch this app once, then reopen Logic."
