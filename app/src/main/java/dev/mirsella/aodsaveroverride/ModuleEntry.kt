package dev.mirsella.aodsaveroverride

import android.util.Log
import dev.mirsella.aodsaveroverride.compat.VersionMap
import dev.mirsella.aodsaveroverride.util.LogOnce
import io.github.libxposed.api.XposedInterface
import io.github.libxposed.api.XposedModule
import io.github.libxposed.api.XposedModuleInterface

class ModuleEntry(
    base: XposedInterface,
    private val moduleLoadedParam: XposedModuleInterface.ModuleLoadedParam,
) : XposedModule(base, moduleLoadedParam) {
    @Volatile
    private var config: Config = Config.load()

    @Volatile
    private var versionInfo: VersionMap.VersionInfo? = null

    init {
        config = Config.load()
        if (!config.enabled) {
            LogOnce.log(::emitLog, Log.INFO, "module-disabled", "Module disabled by config")
        } else if (!moduleLoadedParam.isSystemServer) {
            if (config.verboseLogging) {
                emitLog(Log.DEBUG, "Ignoring non-system process ${moduleLoadedParam.processName}")
            }
        } else {
            versionInfo = VersionMap.resolveCurrent()
            val currentVersionInfo = versionInfo
            if (currentVersionInfo != null && !currentVersionInfo.isSupported) {
                LogOnce.log(
                    ::emitLog,
                    Log.WARN,
                    "unsupported-build",
                    "Unsupported build for framework hook: ${currentVersionInfo.describeCurrentBuild()} (${currentVersionInfo.unsupportedReason})",
                )
            } else if (currentVersionInfo?.supportWarning != null) {
                LogOnce.log(
                    ::emitLog,
                    Log.WARN,
                    "unconfirmed-build",
                    "${currentVersionInfo.supportWarning}: ${currentVersionInfo.describeCurrentBuild()}",
                )
            }
        }
    }

    override fun onSystemServerLoaded(param: XposedModuleInterface.SystemServerLoadedParam) {
        if (!config.enabled || !config.enableFrameworkHook) {
            return
        }

        val currentVersionInfo = versionInfo ?: VersionMap.resolveCurrent().also { versionInfo = it }
        if (!currentVersionInfo.isSupported) {
            return
        }

        FrameworkHooks.install(this, param.classLoader, currentVersionInfo)
    }

    override fun onPackageLoaded(param: XposedModuleInterface.PackageLoadedParam) {
        if (!param.isFirstPackage || param.packageName != SYSTEM_UI_PACKAGE) {
            return
        }

        val currentVersionInfo = versionInfo ?: VersionMap.resolveCurrent().also { versionInfo = it }
        if (!config.allowsFallback(currentVersionInfo)) {
            return
        }

        SystemUiFallbackHooks.install(this, param.defaultClassLoader, currentVersionInfo)
    }

    internal fun emitLog(priority: Int, message: String, throwable: Throwable? = null) {
        val level = when (priority) {
            Log.ERROR -> "E"
            Log.WARN -> "W"
            Log.INFO -> "I"
            Log.DEBUG -> "D"
            else -> priority.toString()
        }
        val formatted = "[$level] $TAG: $message"
        if (throwable == null) {
            log(formatted)
        } else {
            log(formatted, throwable)
        }
    }

    companion object {
        internal const val TAG = "AodSaverOverride"
        private const val SYSTEM_UI_PACKAGE = "com.android.systemui"
    }
}
