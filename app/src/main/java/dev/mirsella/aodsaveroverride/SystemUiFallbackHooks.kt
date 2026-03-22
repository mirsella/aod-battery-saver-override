package dev.mirsella.aodsaveroverride

import android.util.Log
import dev.mirsella.aodsaveroverride.compat.VersionMap
import dev.mirsella.aodsaveroverride.util.LogOnce
import io.github.libxposed.api.XposedInterface
import io.github.libxposed.api.XposedInterface.AfterHookCallback
import java.lang.reflect.Field
import java.util.concurrent.atomic.AtomicBoolean

object SystemUiFallbackHooks {
    private const val CONTROLLER_CLASS_NAME = "com.android.systemui.statusbar.policy.BatteryControllerImpl"
    private const val POWER_SAVE_FIELD_NAME = "mAodPowerSave"
    private const val POWER_SAVE_METHOD_NAME = "setPowerSave"

    private val installed = AtomicBoolean(false)
    @Volatile
    private var aodPowerSaveField: Field? = null

    fun install(module: ModuleEntry, classLoader: ClassLoader, versionInfo: VersionMap.VersionInfo) {
        if (!versionInfo.allowsSystemUiFallback) {
            LogOnce.log(
                module::emitLog,
                Log.DEBUG,
                "systemui-fallback-not-allowed",
                "SystemUI fallback disabled for ${versionInfo.describeCurrentBuild()}",
            )
            return
        }

        if (!installed.compareAndSet(false, true)) {
            return
        }

        val controllerClass = runCatching {
            Class.forName(CONTROLLER_CLASS_NAME, false, classLoader)
        }.getOrElse {
            installed.set(false)
            LogOnce.log(
                module::emitLog,
                Log.WARN,
                "systemui-controller-missing",
                "SystemUI fallback requested but BatteryControllerImpl is missing",
                it,
            )
            return
        }

        val aodField = runCatching {
            controllerClass.getDeclaredField(POWER_SAVE_FIELD_NAME).apply { isAccessible = true }
        }.getOrElse {
            installed.set(false)
            LogOnce.log(
                module::emitLog,
                Log.WARN,
                "systemui-field-missing",
                "SystemUI fallback requested but mAodPowerSave field is missing",
                it,
            )
            return
        }

        val setPowerSaveMethod = controllerClass.declaredMethods.firstOrNull { method ->
            method.name == POWER_SAVE_METHOD_NAME && method.parameterTypes.contentEquals(arrayOf(Boolean::class.javaPrimitiveType))
        }

        if (setPowerSaveMethod == null) {
            installed.set(false)
            LogOnce.log(
                module::emitLog,
                Log.WARN,
                "systemui-method-missing",
                "SystemUI fallback requested but setPowerSave(boolean) is missing",
            )
            return
        }

        aodPowerSaveField = aodField

        runCatching {
            module.hook(setPowerSaveMethod, XposedInterface.PRIORITY_DEFAULT, BatteryControllerHooker::class.java)
            module.emitLog(Log.INFO, "Installed optional SystemUI fallback hook")
        }.onFailure {
            installed.set(false)
            aodPowerSaveField = null
            LogOnce.log(
                module::emitLog,
                Log.ERROR,
                "systemui-hook-install-failed",
                "Failed to install SystemUI fallback hook; disabling it for this process",
                it,
            )
        }
    }

    @JvmStatic
    private fun handleAfterHook(callback: AfterHookCallback) {
        forceAodPowerSaveDisabled(aodPowerSaveField, callback.thisObject)
    }

    private fun forceAodPowerSaveDisabled(field: Field?, instance: Any?) {
        if (field == null || instance == null) {
            return
        }
        runCatching {
            field.setBoolean(instance, false)
        }
    }

    private class BatteryControllerHooker : XposedInterface.Hooker {
        companion object {
            @JvmStatic
            fun after(callback: AfterHookCallback) {
                handleAfterHook(callback)
            }
        }
    }
}
