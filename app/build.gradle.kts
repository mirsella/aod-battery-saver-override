import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "dev.mirsella.aodsaveroverride"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.mirsella.aodsaveroverride"
        minSdk = 28
        targetSdk = 36
        versionCode = 3
        versionName = "0.1.2"
    }

    signingConfigs {
        create("release") {
            storeFile = providers.environmentVariable("RELEASE_KEYSTORE_PATH").orNull?.let { rootProject.file(it) }
            storePassword = providers.environmentVariable("RELEASE_KEYSTORE_PASSWORD").orNull
            keyAlias = "aod-saver-override"
            keyPassword = storePassword
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    compileOnly("io.github.libxposed:api:102.0.0")
}
