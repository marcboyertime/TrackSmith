#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="$ROOT/.build/realtime-heap-probe"
DYLIB="$BUILD_DIR/libLogicAudioAssistantRealtimeHeapProbe.dylib"

mkdir -p "$BUILD_DIR"
xcrun clang \
  -std=c11 \
  -dynamiclib \
  -O2 \
  -Wall \
  -Wextra \
  -Werror \
  "$ROOT/tools/RealtimeHeapProbe/RealtimeHeapInterposer.c" \
  -o "$DYLIB"

swift build -c release --package-path "$ROOT" --product AudioUnitHostProbe

DYLD_INSERT_LIBRARIES="$DYLIB" \
LAA_REQUIRE_RT_HEAP_PROBE=1 \
"$ROOT/.build/release/AudioUnitHostProbe"
