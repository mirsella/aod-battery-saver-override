# Changelog

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
