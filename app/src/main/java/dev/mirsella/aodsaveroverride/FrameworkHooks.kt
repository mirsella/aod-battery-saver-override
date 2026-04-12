package dev.mirsella.aodsaveroverride

import android.util.Log
import dev.mirsella.aodsaveroverride.compat.VersionMap
import dev.mirsella.aodsaveroverride.util.LogOnce
import io.github.libxposed.api.XposedInterface
import java.lang.reflect.Constructor
import java.lang.reflect.Field
import java.lang.reflect.Method
import java.util.concurrent.atomic.AtomicBoolean

object FrameworkHooks {
    private val installed = AtomicBoolean(false)

    fun install(module: ModuleEntry, classLoader: ClassLoader, versionInfo: VersionMap.VersionInfo) {
        if (!installed.compareAndSet(false, true)) {
            return
        }

        val reflectionProfile = resolveReflectionProfile(classLoader, versionInfo)
        if (reflectionProfile == null) {
            LogOnce.log(
                module::emitLog,
                Log.WARN,
                "framework-method-missing",
                "Framework signatures missing for ${versionInfo.describeCurrentBuild()}; disabling framework hook",
            )
            installed.set(false)
            return
        }

        runCatching {
            module.deoptimize(reflectionProfile.policyMethod)
        }.onFailure {
            LogOnce.log(
                module::emitLog,
                Log.WARN,
                "framework-deopt-failed",
                "Failed to deoptimize ${reflectionProfile.policyMethod.declaringClass.name}#${reflectionProfile.policyMethod.name}; continuing with hook install",
                it,
            )
        }

        runCatching {
            module.hook(reflectionProfile.policyMethod)
                .setPriority(XposedInterface.PRIORITY_DEFAULT)
                .intercept(BatterySaverPolicyHooker(module, reflectionProfile))
            module.emitLog(Log.INFO, "Installed framework hook for AOD Battery Saver override")
        }.onFailure {
            installed.set(false)
            LogOnce.log(
                module::emitLog,
                Log.ERROR,
                "framework-hook-install-failed",
                "Failed to install framework hook; disabling feature for this process",
                it,
            )
        }
    }

    private fun resolveReflectionProfile(
        classLoader: ClassLoader,
        versionInfo: VersionMap.VersionInfo,
    ): ReflectionProfile? {
        val policyMethod = resolvePolicyMethod(classLoader, versionInfo) ?: return null
        val powerSaveStateClass = runCatching {
            Class.forName(versionInfo.powerSaveStateClassName, false, classLoader)
        }.getOrNull() ?: return null
        val builderClass = runCatching {
            Class.forName("${versionInfo.powerSaveStateClassName}\$Builder", false, classLoader)
        }.getOrNull() ?: return null

        val builderConstructor = runCatching {
            builderClass.getDeclaredConstructor().apply { isAccessible = true }
        }.getOrNull() ?: return null

        val batterySaverEnabledField = runCatching {
            powerSaveStateClass.getDeclaredField("batterySaverEnabled").apply { isAccessible = true }
        }.getOrNull() ?: return null
        val globalBatterySaverEnabledField = runCatching {
            powerSaveStateClass.getDeclaredField("globalBatterySaverEnabled").apply { isAccessible = true }
        }.getOrNull() ?: return null
        val locationModeField = runCatching {
            powerSaveStateClass.getDeclaredField("locationMode").apply { isAccessible = true }
        }.getOrNull() ?: return null
        val soundTriggerModeField = runCatching {
            powerSaveStateClass.getDeclaredField("soundTriggerMode").apply { isAccessible = true }
        }.getOrNull() ?: return null
        val brightnessFactorField = runCatching {
            powerSaveStateClass.getDeclaredField("brightnessFactor").apply { isAccessible = true }
        }.getOrNull() ?: return null

        val setBatterySaverEnabledMethod = resolveBuilderMethod(builderClass, "setBatterySaverEnabled", Boolean::class.javaPrimitiveType)
            ?: return null
        val setGlobalBatterySaverEnabledMethod = resolveBuilderMethod(builderClass, "setGlobalBatterySaverEnabled", Boolean::class.javaPrimitiveType)
            ?: return null
        val setLocationModeMethod = resolveBuilderMethod(builderClass, "setLocationMode", Int::class.javaPrimitiveType)
            ?: return null
        val setSoundTriggerModeMethod = resolveBuilderMethod(builderClass, "setSoundTriggerMode", Int::class.javaPrimitiveType)
            ?: return null
        val setBrightnessFactorMethod = resolveBuilderMethod(builderClass, "setBrightnessFactor", Float::class.javaPrimitiveType)
            ?: return null
        val buildMethod = resolveBuilderMethod(builderClass, "build") ?: return null

        return ReflectionProfile(
            policyMethod = policyMethod,
            powerSaveStateClass = powerSaveStateClass,
            builderConstructor = builderConstructor,
            batterySaverEnabledField = batterySaverEnabledField,
            globalBatterySaverEnabledField = globalBatterySaverEnabledField,
            locationModeField = locationModeField,
            soundTriggerModeField = soundTriggerModeField,
            brightnessFactorField = brightnessFactorField,
            setBatterySaverEnabledMethod = setBatterySaverEnabledMethod,
            setGlobalBatterySaverEnabledMethod = setGlobalBatterySaverEnabledMethod,
            setLocationModeMethod = setLocationModeMethod,
            setSoundTriggerModeMethod = setSoundTriggerModeMethod,
            setBrightnessFactorMethod = setBrightnessFactorMethod,
            buildMethod = buildMethod,
            aodServiceType = versionInfo.aodServiceType,
        )
    }

    private fun resolvePolicyMethod(
        classLoader: ClassLoader,
        versionInfo: VersionMap.VersionInfo,
    ): Method? {
        val policyClass = runCatching {
            Class.forName(versionInfo.policyClassName, false, classLoader)
        }.getOrNull() ?: return null

        return policyClass.declaredMethods.firstOrNull { method ->
            method.name == versionInfo.policyMethodName &&
                method.returnType.name == versionInfo.powerSaveStateClassName &&
                method.parameterTypes.contentEquals(arrayOf(Int::class.javaPrimitiveType))
        }
    }

    private fun resolveBuilderMethod(clazz: Class<*>, name: String, vararg parameterTypes: Class<*>?): Method? {
        return runCatching {
            clazz.getDeclaredMethod(name, *parameterTypes).apply { isAccessible = true }
        }.getOrNull()
    }

    private data class ReflectionProfile(
        val policyMethod: Method,
        val powerSaveStateClass: Class<*>,
        val builderConstructor: Constructor<*>,
        val batterySaverEnabledField: Field,
        val globalBatterySaverEnabledField: Field,
        val locationModeField: Field,
        val soundTriggerModeField: Field,
        val brightnessFactorField: Field,
        val setBatterySaverEnabledMethod: Method,
        val setGlobalBatterySaverEnabledMethod: Method,
        val setLocationModeMethod: Method,
        val setSoundTriggerModeMethod: Method,
        val setBrightnessFactorMethod: Method,
        val buildMethod: Method,
        val aodServiceType: Int,
    ) {
        fun copyWithBatterySaverDisabled(original: Any): Any {
            val builder = builderConstructor.newInstance()
            setBatterySaverEnabledMethod.invoke(builder, false)
            setGlobalBatterySaverEnabledMethod.invoke(builder, globalBatterySaverEnabledField.getBoolean(original))
            setLocationModeMethod.invoke(builder, locationModeField.getInt(original))
            setSoundTriggerModeMethod.invoke(builder, soundTriggerModeField.getInt(original))
            setBrightnessFactorMethod.invoke(builder, brightnessFactorField.getFloat(original))
            return buildMethod.invoke(builder)
        }
    }

    private class BatterySaverPolicyHooker(
        private val module: ModuleEntry,
        private val reflectionProfile: ReflectionProfile,
    ) : XposedInterface.Hooker {
        override fun intercept(chain: XposedInterface.Chain): Any? {
            val serviceType = chain.getArgs().firstOrNull() as? Int ?: return chain.proceed()
            val original = chain.proceed()

            if (serviceType != reflectionProfile.aodServiceType) {
                return original
            }

            if (original == null || !reflectionProfile.powerSaveStateClass.isInstance(original)) {
                LogOnce.log(
                    module::emitLog,
                    Log.WARN,
                    "framework-null-state",
                    "Framework hook received unexpected AOD state result; leaving original value untouched",
                )
                return original
            }

            if (!reflectionProfile.batterySaverEnabledField.getBoolean(original)) {
                return original
            }

            return reflectionProfile.copyWithBatterySaverDisabled(original)
        }
    }
}
