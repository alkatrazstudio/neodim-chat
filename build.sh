#!/usr/bin/env bash
set -e
cd "$(dirname -- "${BASH_SOURCE[0]}")"

flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

BUILD_PARAMS=(
    --release \
    --dart-define=APP_BUILD_TIMESTAMP="$(date +%s)" \
    --dart-define=APP_GIT_HASH="$(git rev-parse HEAD)"
)

case "$1" in
    apk)
        flutter build apk "${BUILD_PARAMS[@]}" --split-debug-info=build/debug_info
        ;;

    bundle)
        flutter build appbundle "${BUILD_PARAMS[@]}"
        ;;

    upload)
        flutter build appbundle "${BUILD_PARAMS[@]}"
        export LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
        bundle exec fastlane upload_play
        ;;
esac
