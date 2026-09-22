# AOD Battery Saver Override

LSPosed module that keeps Always On Display available while Battery Saver is enabled.

Targets modern Xposed API 102 and requires a framework with API 102 support.

## How It Works

The module does not disable Battery Saver globally. Instead, it hooks the framework code that returns `PowerSaveState` and only rewrites the AOD-related answer so Android behaves as if Battery Saver is not blocking Always On Display.

The main path lives in the framework hook. There is also a narrower SystemUI fallback hook in the project for cases where the framework hook is not enough.

The compatibility map supports Android 16 QPR2 (SDK 36) and Android 17 (SDK 37). The module checks framework signatures before installing the hook and logs warnings for unsupported SDKs or missing signatures.

## Build

Debug builds need no release credentials:

```bash
./gradlew assembleDebug
```

### Signed releases with SecretSpec

Install `just`, SecretSpec, and Proton Pass CLI, then sign in with `pass-cli login`. Configure the Android SDK through `ANDROID_HOME` or Android Studio's `local.properties`.

```bash
just build-release
```

`secretspec.toml` resolves these required secrets through the `protonpass` provider, which uses `pass-cli`. They are note items in the `secretspec` vault:

- `aod-battery-saver-override/default/RELEASE_KEYSTORE_BASE64`: the base64-encoded release PKCS12 keystore.
- `aod-battery-saver-override/default/RELEASE_KEYSTORE_PASSWORD`: the password for both the keystore and its `aod-saver-override` key.

The release recipe decodes the key into a private temporary directory under `dist/`, signs the APK, and removes the temporary key when the build exits. It uses the same signing key as version 0.1.2. The original backup is in the Personal vault under `AOD Battery Saver Override release signing`.

To build both variants:

```bash
just build
```

For Gradle directly, provide an existing keystore:

```bash
RELEASE_KEYSTORE_PATH=/path/to/release.p12 \
RELEASE_KEYSTORE_PASSWORD="$KEYSTORE_PASSWORD" \
./gradlew assembleRelease
```

Without these credentials, Gradle produces an unsigned release APK.

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
