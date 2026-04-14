# AOD Battery Saver Override

LSPosed module that keeps Always On Display available while Battery Saver is enabled.

Current release target: modern LSPosed API 101.

## How It Works

The module does not disable Battery Saver globally. Instead, it hooks the framework code that returns `PowerSaveState` and only rewrites the AOD-related answer so Android behaves as if Battery Saver is not blocking Always On Display.

The main path lives in the framework hook. There is also a narrower SystemUI fallback hook in the project for cases where the framework hook is not enough.

Compatibility is intentionally explicit: the project currently maps support around SDK 36 / Android 16 QPR2 style internals and logs warnings when signatures do not match expectations.

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

## Notes

- The main entry point is `ModuleEntry.kt`.
- Framework-level behavior is implemented in `FrameworkHooks.kt`.
- Compatibility mapping is tracked in `compat/VersionMap.kt`.
- The fallback hook is not the primary path and exists for edge cases.

## GitHub Actions

Download the latest build artifacts from the Actions tab:

- `https://github.com/mirsella/aod-battery-saver-override/actions`
