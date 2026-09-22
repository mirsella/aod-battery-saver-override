# AOD Battery Saver Override

LSPosed module that keeps Always On Display available while Battery Saver is enabled.

Targets modern Xposed API 102 and requires a framework with API 102 support.

## How It Works

The module does not disable Battery Saver globally. Instead, it hooks the framework code that returns `PowerSaveState` and only rewrites the AOD-related answer so Android behaves as if Battery Saver is not blocking Always On Display.

The main path lives in the framework hook. There is also a narrower SystemUI fallback hook in the project for cases where the framework hook is not enough.

Compatibility is intentionally explicit: the project currently maps support around SDK 36 / Android 16 QPR2 style internals and logs warnings when signatures do not match expectations.

## Build

Debug builds need no release credentials:

```bash
./gradlew assembleDebug
```

For signed release builds, set `RELEASE_KEYSTORE_PATH` to the release PKCS12 keystore and `RELEASE_KEYSTORE_PASSWORD` to its password. The key alias is `aod-saver-override`, and the key uses the same password as the keystore. Without these credentials, Gradle produces an unsigned release APK.

To build both variants:

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

Version 0.1.2 uses a new release signing key because the previous debug key could not be recovered. To upgrade from 0.1.1, uninstall the old APK first, install 0.1.2, enable the module again, and reboot. Later releases use the same dedicated key and can update 0.1.2 directly.

## Notes

- The main entry point is `ModuleEntry.kt`.
- Framework-level behavior is implemented in `FrameworkHooks.kt`.
- Compatibility mapping is tracked in `compat/VersionMap.kt`.
- The fallback hook is not the primary path and exists for edge cases.

## GitHub Actions

Signed builds use the repository secrets `RELEASE_KEYSTORE_BASE64` and `RELEASE_KEYSTORE_PASSWORD`. The first contains the base64-encoded release keystore. Keep a separate backup of the keystore and password; GitHub secrets cannot be downloaded later.

Download the latest build artifacts from the Actions tab:

- `https://github.com/mirsella/aod-battery-saver-override/actions`
