# Changelog

## 0.2.1

- Keep `disable_aod=false` in DeviceConfig and as a local override. The ordinary value notifies Android's policy listener; the override survives server updates.
- Restore the original DeviceConfig value and override on Action or uninstall, including when upgrading from 0.2.0.

## 0.2.0

- Replace the Xposed APK with a script-only KernelSU / Magisk module.
- Merge `disable_aod=false` into the Battery Saver policy after boot, preserving other settings.
- Save the original AOD policy across updates and restore it on Action or uninstall.
- Remove Kotlin hooks, Gradle, Android SDK dependencies, APK signing, and SecretSpec configuration.
- Build a module ZIP with shell tools and test policy merging and restoration in CI.

## 0.1.3

- Support Android 17 (SDK 37). Earlier versions skipped the framework hook on SDK 37, leaving AOD blocked by Battery Saver.
- Add SecretSpec and Proton Pass integration for local signed release builds.

## 0.1.2

- Require modern Xposed API 102 and build against `io.github.libxposed:api:102.0.0`
- Use a dedicated release signing key for local and CI builds. The previous debug signing key could not be recovered, so upgrading from 0.1.1 requires uninstalling the old APK and installing 0.1.2, then enabling the module again.

## 0.1.1

- Bump modern LSPosed module metadata to API 101
- Build against `io.github.libxposed:api:101.0.1` from Maven Central

## 0.1.0

- Initial scaffold for Android 16 framework hook
- `system_server` hook for `BatterySaverPolicy#getBatterySaverPolicy(int)`
- Static `system` LSPosed scope
- Optional SystemUI fallback stub kept disabled
