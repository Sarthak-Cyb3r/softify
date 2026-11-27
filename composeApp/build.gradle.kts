import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import java.time.LocalDate
import java.time.ZoneOffset

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.jetbrainsCompose)
    alias(libs.plugins.compose.compiler)
}

fun readGitCommitCount(): Int {
    return try {
        val proc = ProcessBuilder("git", "rev-list", "--count", "HEAD")
            .directory(rootProject.projectDir)
            .redirectErrorStream(true)
            .start()
        val out = proc.inputStream.bufferedReader().readText().trim()
        if (proc.waitFor() == 0) out.toIntOrNull() ?: 1 else 1
    } catch (_: Exception) {
        1
    }
}

val gitCommitCount = readGitCommitCount()
val computedVersionCode = System.getenv("SOFTIFY_VERSION_CODE")?.toIntOrNull()
    ?: (40300 + gitCommitCount)
val computedVersionName = System.getenv("SOFTIFY_VERSION_NAME")?.takeIf { it.isNotBlank() }
    ?: run {
        val refType = System.getenv("GITHUB_REF_TYPE")
        val refName = System.getenv("GITHUB_REF_NAME")
        if (refType == "tag" && !refName.isNullOrBlank()) {
            refName.removePrefix("v")
        } else {
            "4.3.$gitCommitCount-${LocalDate.now(ZoneOffset.UTC)}"
        }
    }

val generateBuildMeta by tasks.registering {
    val outDir = layout.buildDirectory.dir("generated/source/softifyMeta/kotlin")
    val vCode = computedVersionCode
    val vName = computedVersionName
    inputs.property("versionCode", vCode)
    inputs.property("versionName", vName)
    outputs.dir(outDir)
    doLast {
        val pkgDir = outDir.get().asFile.resolve("com/softify/app")
        pkgDir.mkdirs()
        pkgDir.resolve("BuildMeta.kt").writeText(
            """
            package com.softify.app

            object BuildMeta {
                const val VERSION_CODE: Int = $vCode
                const val VERSION_NAME: String = "$vName"
            }
            """.trimIndent() + "\n"
        )
    }
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
    
    jvm("desktop")
    
    sourceSets {
        val commonMain by getting {
            kotlin.srcDir(generateBuildMeta)
            dependencies {
                implementation(compose.runtime)
                implementation(compose.foundation)
                implementation(compose.material3)
                implementation(compose.materialIconsExtended)
                implementation(compose.ui)
                implementation(compose.components.resources)
                implementation(compose.components.uiToolingPreview)
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
                implementation("io.coil-kt.coil3:coil-compose:3.0.4")
                implementation("io.coil-kt.coil3:coil-network-okhttp:3.0.4")
                implementation("com.squareup.okio:okio:3.9.1")
            }
        }
        val androidMain by getting {
            dependencies {
                implementation("androidx.activity:activity-compose:1.9.1")
                implementation("androidx.appcompat:appcompat:1.7.0")
                implementation("androidx.core:core-ktx:1.13.1")
                implementation("androidx.documentfile:documentfile:1.0.1")
                implementation("androidx.work:work-runtime-ktx:2.9.1")
                implementation("androidx.media3:media3-exoplayer:1.3.1")
                implementation("androidx.media3:media3-session:1.3.1")
                implementation("androidx.media3:media3-common:1.3.1")
                implementation("androidx.media3:media3-datasource:1.3.1")
                implementation("androidx.metrics:metrics-performance:1.0.0-beta01")
                implementation("com.squareup.okhttp3:okhttp:4.12.0")
                implementation("net.java.dev.jna:jna:5.14.0@aar")
            }
        }
        val desktopMain by getting {
            dependencies {
                implementation(compose.desktop.currentOs)
                implementation("com.squareup.okhttp3:okhttp:4.12.0")
                implementation("net.java.dev.jna:jna:5.14.0")
            }
        }
        val desktopTest by getting {
            dependencies {
                implementation(kotlin("test"))
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
                implementation("com.squareup.okhttp3:mockwebserver:4.12.0")
            }
        }
    }
}

android {
    namespace = "com.softify.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.softify.app"
        minSdk = 24
        targetSdk = 34
        versionCode = computedVersionCode
        versionName = computedVersionName
    }

    val keystoreFile = file(
        System.getenv("ANDROID_KEYSTORE_PATH")
            ?: "${System.getProperty("user.home")}/.softify-keys/softify-release.jks"
    )
    val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
    val keyAliasName = System.getenv("ANDROID_KEY_ALIAS") ?: "softify"
    val keyPass = System.getenv("ANDROID_KEY_PASSWORD")
    val hasReleaseKeystore = keystoreFile.exists() && !keystorePassword.isNullOrBlank() && !keyPass.isNullOrBlank()

    signingConfigs {
        if (hasReleaseKeystore) {
            create("softifyRelease") {
                storeFile = keystoreFile
                storePassword = keystorePassword
                keyAlias = keyAliasName
                keyPassword = keyPass
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("softifyRelease")
            }
        }
        getByName("debug") {
            isMinifyEnabled = false
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("softifyRelease")
            }
        }
    }

    if (System.getenv("CI") == "true" &&
        gradle.startParameter.taskNames.any { it.contains("assemble", ignoreCase = true) } &&
        !hasReleaseKeystore
    ) {
        throw GradleException("CI APK builds must configure release keystore secrets (ANDROID_KEYSTORE_PATH / password / alias)")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

compose.desktop {
    application {
        mainClass = "MainKt"
        nativeDistributions {
            targetFormats(TargetFormat.Dmg, TargetFormat.Msi, TargetFormat.Deb)
            packageName = "Softify"
            packageVersion = "4.3.0"
        }
    }
}

tasks.withType<Test> {
    systemProperty("jna.library.path", "${rootProject.projectDir}/rust/softify_core/target/debug")
}

val verifyNativeLibsExist = tasks.register("verifyNativeLibsExist") {
    description = "Fails build if libsoftify_core.so is missing for target ABIs"
    doLast {
        val requiredAbis = listOf("arm64-v8a", "x86_64")
        val jniLibsDir = file("src/androidMain/jniLibs")
        for (abi in requiredAbis) {
            val soFile = File(jniLibsDir, "$abi/libsoftify_core.so")
            if (!soFile.exists()) {
                throw GradleException(
                    "\n================================================================================\n" +
                    "FATAL ERROR: libsoftify_core.so is missing for ABI '$abi'!\n" +
                    "Expected path: ${soFile.absolutePath}\n" +
                    "Please build the native libraries first using:\n" +
                    "    tools/build_android_libs.sh\n" +
                    "================================================================================"
                )
            }
        }
    }
}

tasks.matching {
    it.name.startsWith("package") ||
        it.name.startsWith("mergeDebugNativeLibs") ||
        it.name.startsWith("mergeReleaseNativeLibs")
}.configureEach {
    dependsOn(verifyNativeLibsExist)
}
