package dev.mirsella.aodsaveroverride

import dev.mirsella.aodsaveroverride.compat.VersionMap

data class Config(
    val enabled: Boolean = true,
    val enableFrameworkHook: Boolean = true,
    val enableSystemUiFallback: Boolean = false,
    val requireConfirmedRomForFallback: Boolean = true,
    val verboseLogging: Boolean = false,
) {
    fun allowsFallback(versionInfo: VersionMap.VersionInfo): Boolean {
        if (!enableSystemUiFallback) {
            return false
        }
        if (!versionInfo.allowsSystemUiFallback) {
            return false
        }
        return !requireConfirmedRomForFallback || versionInfo.isConfirmedFallbackRom
    }

    companion object {
        fun load(): Config = Config()
    }
}
