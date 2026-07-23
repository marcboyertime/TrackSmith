#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
binary="$repo_root/.build/arm64-apple-macosx/debug/ProductionIntelligenceEvaluation"
identifier="com.marcboyer.tracksmith.production-intelligence-evaluation"

identity_hash="$(
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+([0-9A-F]{40})[[:space:]]+"Apple Development:.*/\1/p' \
    | head -n 1
)"

if [[ ! "$identity_hash" =~ '^[0-9A-F]{40}$' ]]; then
  print -u2 "error: no usable Apple Development signing identity was found"
  exit 2
fi

cd "$repo_root"
swift build --product ProductionIntelligenceEvaluation

# A stable certificate + identifier gives Keychain one durable designated
# requirement. Ad-hoc SwiftPM signatures use a changing CDHash and therefore
# cause a fresh authorization prompt after each rebuild.
codesign \
  --force \
  --sign "$identity_hash" \
  --identifier "$identifier" \
  --timestamp=none \
  "$binary"
codesign --verify --strict --verbose=1 "$binary"

exec "$binary" "$@"
