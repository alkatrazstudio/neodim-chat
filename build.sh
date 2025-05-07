#!/usr/bin/env bash
set -e
cd "$(dirname -- "${BASH_SOURCE[0]}")"

flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

BUILD_PARAMS=(
    --release \
    --dart-define=APP_BUILD_TIMESTAMP="$(date +%s)" \
    --dart-define=APP_GIT_HASH="$(git rev-parse HEAD)"
)

flutter build apk "${BUILD_PARAMS[@]}" --split-debug-info=build/debug_info
