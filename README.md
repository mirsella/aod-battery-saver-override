# AOD Battery Saver Override

LSPosed module that keeps Always On Display available while Battery Saver is enabled.

Current release target: modern LSPosed API 101.

## Build

```bash
just build
```

If you prefer Gradle directly:

```bash
./gradlew assembleDebug assembleRelease
```

## Artifacts

- `dist/aod-battery-saver-override-debug.apk`
- `dist/aod-battery-saver-override-release.apk`

## Install

Install the generated APK, enable the module in LSPosed, then reboot if needed.

## GitHub Actions

Download the latest build artifacts from the Actions tab:

- `https://github.com/mirsella/aod-battery-saver-override/actions`
