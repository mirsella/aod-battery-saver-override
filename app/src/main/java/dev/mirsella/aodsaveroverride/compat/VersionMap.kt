package dev.mirsella.aodsaveroverride.compat

import android.os.Build

object VersionMap {
    private val supportedProfiles = listOf(
        SupportProfile(
            sdkInt = 36,
            releaseBranch = "android16-qpr2-release",
            policyClassName = "com.android.server.power.batterysaver.BatterySaverPolicy",
            policyMethodName = "getBatterySaverPolicy",
            powerSaveStateClassName = "android.os.PowerSaveState",
            aodServiceType = 14,
            allowPixelLikeFallback = false,
        ),
    )

    fun resolveCurrent(): VersionInfo {
        val fingerprint = Build.FINGERPRINT.orEmpty()
        val fingerprintLower = fingerprint.lowercase()
        val branchHints = listOf(
            Build.VERSION.INCREMENTAL.orEmpty(),
            Build.ID.orEmpty(),
            fingerprint,
        )

        val profile = supportedProfiles.firstOrNull { it.sdkInt == Build.VERSION.SDK_INT }
            ?: return VersionInfo.unsupported(
                unsupportedReason = "Unsupported SDK ${Build.VERSION.SDK_INT}",
                fingerprint = fingerprint,
            )

        val isAospLike = fingerprintLower.contains("aosp") || fingerprintLower.contains("generic")
        val isPixelLike = Build.BRAND.equals("google", ignoreCase = true) ||
            Build.MANUFACTURER.equals("google", ignoreCase = true) ||
            fingerprintLower.contains("pixel") ||
            fingerprintLower.contains("google/")
        val branchMatched = branchHints.any { it.contains(profile.releaseBranch, ignoreCase = true) }
        val isConfirmedFrameworkRom = (isAospLike || isPixelLike) && (branchMatched || isPixelLike)
        val supportWarning = if (isConfirmedFrameworkRom) {
            null
        } else {
            "Unconfirmed ROM family or release branch; attempting framework hook with runtime signature checks"
        }

        return VersionInfo(
            sdkInt = profile.sdkInt,
            releaseBranch = profile.releaseBranch,
            isSupported = true,
            unsupportedReason = null,
            supportWarning = supportWarning,
            fingerprint = fingerprint,
            policyClassName = profile.policyClassName,
            policyMethodName = profile.policyMethodName,
            powerSaveStateClassName = profile.powerSaveStateClassName,
            aodServiceType = profile.aodServiceType,
            isConfirmedFrameworkRom = isConfirmedFrameworkRom,
            allowsSystemUiFallback = profile.allowPixelLikeFallback && isConfirmedFrameworkRom,
            isConfirmedFallbackRom = false,
        )
    }

    data class VersionInfo(
        val sdkInt: Int,
        val releaseBranch: String,
        val isSupported: Boolean,
        val unsupportedReason: String?,
        val supportWarning: String?,
        val fingerprint: String,
        val policyClassName: String,
        val policyMethodName: String,
        val powerSaveStateClassName: String,
        val aodServiceType: Int,
        val isConfirmedFrameworkRom: Boolean,
        val allowsSystemUiFallback: Boolean,
        val isConfirmedFallbackRom: Boolean,
    ) {
        fun describeCurrentBuild(): String {
            return "sdk=$sdkInt branch=$releaseBranch fingerprint=$fingerprint"
        }

        companion object {
            fun unsupported(unsupportedReason: String, fingerprint: String): VersionInfo {
                return VersionInfo(
                    sdkInt = Build.VERSION.SDK_INT,
                    releaseBranch = "unknown",
                    isSupported = false,
                    unsupportedReason = unsupportedReason,
                    supportWarning = null,
                    fingerprint = fingerprint,
                    policyClassName = "",
                    policyMethodName = "",
                    powerSaveStateClassName = "",
                    aodServiceType = -1,
                    isConfirmedFrameworkRom = false,
                    allowsSystemUiFallback = false,
                    isConfirmedFallbackRom = false,
                )
            }
        }
    }

    private data class SupportProfile(
        val sdkInt: Int,
        val releaseBranch: String,
        val policyClassName: String,
        val policyMethodName: String,
        val powerSaveStateClassName: String,
        val aodServiceType: Int,
        val allowPixelLikeFallback: Boolean,
    )
}
