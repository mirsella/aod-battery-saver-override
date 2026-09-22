set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

project := "aod-battery-saver-override"
dist_dir := "dist"
debug_apk := dist_dir + "/" + project + "-debug.apk"
release_apk := dist_dir + "/" + project + "-release.apk"

default: build

clean:
  rm -rf {{dist_dir}}
  ./gradlew clean

build: build-debug build-release

build-debug:
  mkdir -p {{dist_dir}}
  ./gradlew assembleDebug
  cp app/build/outputs/apk/debug/app-debug.apk {{debug_apk}}
  @printf 'Debug APK: %s\n' '{{debug_apk}}'

build-release:
  secretspec run --reason "Build and sign the AOD module release APK" -- just _build-release

[private]
_build-release:
  #!/usr/bin/env bash
  set -euo pipefail
  umask 077
  : "${RELEASE_KEYSTORE_BASE64:?Release keystore is required}"
  : "${RELEASE_KEYSTORE_PASSWORD:?Release keystore password is required}"
  mkdir -p {{dist_dir}}
  signing_dir=$(mktemp -d "{{dist_dir}}/.signing.XXXXXX")
  trap 'rm -rf "$signing_dir"' EXIT
  printf '%s' "$RELEASE_KEYSTORE_BASE64" | base64 --decode > "$signing_dir/release.p12"
  export RELEASE_KEYSTORE_PATH="$PWD/$signing_dir/release.p12"
  unset RELEASE_KEYSTORE_BASE64
  ./gradlew assembleRelease
  cp app/build/outputs/apk/release/app-release.apk {{release_apk}}
  printf 'Release APK: %s\n' '{{release_apk}}'

artifacts: build
  @printf 'Artifacts ready in %s\n' '{{dist_dir}}'
