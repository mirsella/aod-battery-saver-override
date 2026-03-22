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
  mkdir -p {{dist_dir}}
  ./gradlew assembleRelease
  cp app/build/outputs/apk/release/app-release.apk {{release_apk}}
  @printf 'Release APK: %s\n' '{{release_apk}}'

artifacts: build
  @printf 'Artifacts ready in %s\n' '{{dist_dir}}'
