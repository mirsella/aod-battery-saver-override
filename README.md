# AOD Battery Saver Override

A script-only KernelSU / Magisk module that keeps Always On Display available while Battery Saver is enabled.

## How it works

After boot, the module sets `disable_aod=false` in Android's global `battery_saver_constants` setting and in the `battery_saver` DeviceConfig namespace. It also adds a local DeviceConfig override. It preserves the other policy entries and leaves Battery Saver enabled. Some ROMs clear `battery_saver_constants` when Battery Saver turns off; DeviceConfig synchronization can remove an ordinary flag value. The override protects against those updates, while writing the ordinary flag notifies Android's Battery Saver policy listener. It does not turn AOD on: enable AOD in your phone's settings.

No Zygisk, LSPosed, APK, system mounts, or resident process is required. The shared `service.sh` entry point waits for boot completion, applies the policy once, and exits. It supports KernelSU, KernelSU Next, and Magisk.

The ROM must honor the AOSP `disable_aod` policy. Tested on a POCO F5 running Android 17 (SDK 37): the effective policy remained `disable_aod=false` through Battery Saver toggles, while other saver restrictions stayed active. An explicit `disable_aod=true` in the global setting takes precedence over DeviceConfig if another writer adds it after boot. The module reapplies the global setting at boot, not continuously.

## Install

1. Enable AOD in Android settings.
2. Install the module ZIP from KernelSU or Magisk's **Modules** page.
3. Reboot.

Install through the root manager, not recovery. No KernelSU mounting metamodule is needed.

### Migrating from 0.1.x

Disable or uninstall the old `dev.mirsella.aodsaveroverride` Xposed APK, install this ZIP, and reboot to unload its hook. Version 0.2.0 replaces the APK architecture entirely. Keep LSPosed or Zygisk installed if other modules need them.

If you previously set `disable_aod=false` manually, restore your original AOD policy before the first module boot. Otherwise, the module correctly records `false` as the value to restore later.

## Restore or uninstall

Use the module's **Action** button to restore the previous global policy, DeviceConfig value, and local override, then disable the module. Re-enable it in the manager and reboot to apply again.

Simply switching the module off prevents its boot script from running but does not undo the persistent Android settings. Use **Action** when you want to undo them.

Uninstall also restores the previous AOD entry, DeviceConfig value, and local override, preserving changes to other policy entries. If another writer has already changed one of these away from the module's value, it leaves that change alone. When removal happens early in boot, a short-lived background task waits for Android before restoring them; it times out after six minutes.

The original global policy, DeviceConfig value, and local override are saved once in `/data/adb/aod-battery-saver-override/`, outside the module directory so updates retain them. Successful uninstall removes this backup. If Android never finishes booting or restoration fails, the backup remains for recovery. Logs use the `AodSaverOverride` logcat tag.

## Build and check

Building needs a POSIX shell and `zip`. Checks also need ShellCheck. No SDK, Gradle, signing key, or secrets are required.

```sh
sh tests/policy.sh
shellcheck -x -s sh module/*.sh scripts/*.sh tests/*.sh
sh scripts/build.sh
```

Or use `just check` and `just build`.

Output: `dist/aod-battery-saver-override-0.2.1.zip`. GitHub Actions runs the same checks and uploads the ZIP as an artifact.
