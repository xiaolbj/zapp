import org.gradle.api.GradleException
import org.gradle.api.tasks.Sync
import java.util.zip.ZipFile

plugins {
    id("com.android.application")
}

fun setting(propertyName: String, environmentName: String) =
    providers.gradleProperty(propertyName).orElse(providers.environmentVariable(environmentName))

val zappVersionCode = setting("zappVersionCode", "ZAPP_VERSION_CODE")
    .orElse("1").get().toIntOrNull()?.takeIf { it in 1..2_100_000_000 }
    ?: throw GradleException("zappVersionCode/ZAPP_VERSION_CODE must be a positive Android version code")
val zappVersionName = setting("zappVersionName", "ZAPP_VERSION_NAME")
    .orElse("0.1.0").get().trim().takeIf(String::isNotEmpty)
    ?: throw GradleException("zappVersionName/ZAPP_VERSION_NAME must not be empty")

val releaseStorePath = setting("zappKeystorePath", "ZAPP_KEYSTORE_PATH").orNull?.takeIf(String::isNotBlank)
val releaseStorePassword = setting("zappKeystorePassword", "ZAPP_KEYSTORE_PASSWORD").orNull?.takeIf(String::isNotBlank)
val releaseKeyAlias = setting("zappKeyAlias", "ZAPP_KEY_ALIAS").orNull?.takeIf(String::isNotBlank)
val releaseKeyPassword = setting("zappKeyPassword", "ZAPP_KEY_PASSWORD").orNull?.takeIf(String::isNotBlank)
val releaseSigningValues = listOf(releaseStorePath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword)
val releaseSigningConfigured = releaseSigningValues.all { it != null }
val releaseSigningPartiallyConfigured = releaseSigningValues.any { it != null } && !releaseSigningConfigured
val requireReleaseSigning = setting("zappRequireReleaseSigning", "ZAPP_REQUIRE_RELEASE_SIGNING")
    .orElse("false").get().toBooleanStrictOrNull()
    ?: throw GradleException("zappRequireReleaseSigning/ZAPP_REQUIRE_RELEASE_SIGNING must be true or false")

if (releaseSigningPartiallyConfigured) {
    throw GradleException(
        "Release signing is only partially configured; provide keystore path, store password, key alias, and key password",
    )
}
if (requireReleaseSigning && !releaseSigningConfigured) {
    throw GradleException("Release signing is required, but no complete external signing configuration was provided")
}

android {
    namespace = "com.xiaolbj.zapp"
    compileSdk = 35
    ndkVersion = "25.2.9519653"

    providers.gradleProperty("zappNdkPath").orNull?.let { ndkPath = it }

    defaultConfig {
        applicationId = "com.xiaolbj.zapp"
        minSdk = 26
        targetSdk = 35
        versionCode = zappVersionCode
        versionName = zappVersionName
        ndk { abiFilters += setOf("arm64-v8a", "x86_64") }
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("externalRelease") {
                storeFile = rootProject.file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        debug { isDebuggable = true }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (releaseSigningConfigured) signingConfig = signingConfigs.getByName("externalRelease")
        }
    }

    sourceSets.getByName("debug").jniLibs.srcDir(layout.buildDirectory.dir("generated/zappJniLibs/debug"))
    sourceSets.getByName("release").jniLibs.srcDir(layout.buildDirectory.dir("generated/zappJniLibs/release"))
}

val repositoryRoot = rootDir.parentFile
val zigExecutable = providers.gradleProperty("zigExecutable").orElse("zig")
val ndkPath = providers.gradleProperty("zappNdkPath")
    .orElse(providers.environmentVariable("ANDROID_NDK_HOME"))

fun registerZigBuild(name: String, variant: String, abi: String, optimize: String) = tasks.register<Exec>(name) {
    group = "build"
    description = "Build the $variant libzapp.so for $abi with Zig $optimize"
    workingDir = repositoryRoot
    doFirst {
        if (!ndkPath.isPresent) {
            throw GradleException(
                "Set -PzappNdkPath=<path-to-ndk> or ANDROID_NDK_HOME before building Android artifacts",
            )
        }
        commandLine(
            zigExecutable.get(), "build", "android-lib", "-Doptimize=$optimize",
            "-Dandroid-ndk=${ndkPath.get()}", "-Dandroid-api=26", "-Dandroid-abi=$abi",
            "-Dandroid-output-dir=android/$variant",
        )
    }
    inputs.files(
        fileTree(repositoryRoot.resolve("src")), fileTree(repositoryRoot.resolve("assets")),
        repositoryRoot.resolve("zapp.zig"), repositoryRoot.resolve("build.zig"),
        repositoryRoot.resolve("build.zig.zon"),
    )
    outputs.file(repositoryRoot.resolve("zig-out/android/$variant/$abi/libzapp.so"))
}

val buildZigDebugArm64 = registerZigBuild("buildZigDebugArm64", "debug", "arm64-v8a", "ReleaseSafe")
val buildZigDebugX64 = registerZigBuild("buildZigDebugX64", "debug", "x86_64", "ReleaseSafe")
val buildZigReleaseArm64 = registerZigBuild("buildZigReleaseArm64", "release", "arm64-v8a", "ReleaseSmall")
val buildZigReleaseX64 = registerZigBuild("buildZigReleaseX64", "release", "x86_64", "ReleaseSmall")

buildZigDebugX64.configure { mustRunAfter(buildZigDebugArm64) }
buildZigReleaseX64.configure { mustRunAfter(buildZigReleaseArm64) }

val syncZigDebugLibraries by tasks.registering(Sync::class) {
    dependsOn(buildZigDebugArm64, buildZigDebugX64)
    from(repositoryRoot.resolve("zig-out/android/debug"))
    into(layout.buildDirectory.dir("generated/zappJniLibs/debug"))
}
val syncZigReleaseLibraries by tasks.registering(Sync::class) {
    dependsOn(buildZigReleaseArm64, buildZigReleaseX64)
    from(repositoryRoot.resolve("zig-out/android/release"))
    into(layout.buildDirectory.dir("generated/zappJniLibs/release"))
}

tasks.matching { it.name == "preDebugBuild" }.configureEach { dependsOn(syncZigDebugLibraries) }
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(syncZigReleaseLibraries) }

tasks.register("verifyReleaseConfiguration") {
    group = "verification"
    description = "Validate Android release version and external signing configuration"
    doLast {
        logger.lifecycle("Release version: $zappVersionName ($zappVersionCode)")
        logger.lifecycle(if (releaseSigningConfigured) "Release signing: externally configured" else "Release signing: unsigned")
    }
}

tasks.register("verifyReleaseSigning") {
    group = "verification"
    description = "Fail unless a complete external release signing configuration is present"
    doLast {
        if (!releaseSigningConfigured) throw GradleException("No external release signing configuration was provided")
        val keyStoreFile = rootProject.file(releaseStorePath!!)
        if (!keyStoreFile.isFile) throw GradleException("Configured release keystore does not exist: $keyStoreFile")
        logger.lifecycle("External release signing configuration is complete")
    }
}

tasks.register("verifyReleaseArtifacts") {
    group = "verification"
    description = "Build and verify the release APK/AAB version and native ABI contents"
    dependsOn("assembleRelease", "bundleRelease", "verifyReleaseConfiguration")
    doLast {
        val metadataFile = layout.buildDirectory.file("outputs/apk/release/output-metadata.json").get().asFile
        if (!metadataFile.isFile) throw GradleException("Release APK metadata is missing: $metadataFile")
        val metadata = metadataFile.readText()
        val actualVersionCode = Regex("\\\"versionCode\\\"\\s*:\\s*(\\d+)")
            .find(metadata)?.groupValues?.get(1)?.toIntOrNull()
        val actualVersionName = Regex("\\\"versionName\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"")
            .find(metadata)?.groupValues?.get(1)
        if (actualVersionCode != zappVersionCode || actualVersionName != zappVersionName) {
            throw GradleException(
                "Release metadata version mismatch: expected $zappVersionName ($zappVersionCode), " +
                    "found $actualVersionName ($actualVersionCode)",
            )
        }

        val apk = layout.buildDirectory.dir("outputs/apk/release").get().asFile
            .listFiles { file -> file.extension == "apk" }?.singleOrNull()
            ?: throw GradleException("Expected exactly one release APK")
        val aab = layout.buildDirectory.file("outputs/bundle/release/app-release.aab").get().asFile
        if (!aab.isFile) throw GradleException("Release AAB is missing: $aab")

        val expectedApkLibraries = setOf("lib/arm64-v8a/libzapp.so", "lib/x86_64/libzapp.so")
        val expectedBundleLibraries = expectedApkLibraries.mapTo(mutableSetOf()) { "base/$it" }
        fun nativeLibraries(archive: java.io.File) = ZipFile(archive).use { zip ->
            zip.entries().asSequence().map { it.name }.filter { it.endsWith("/libzapp.so") }.toSet()
        }
        val apkLibraries = nativeLibraries(apk)
        val bundleLibraries = nativeLibraries(aab)
        if (apkLibraries != expectedApkLibraries) {
            throw GradleException("Unexpected release APK native libraries: $apkLibraries")
        }
        if (bundleLibraries != expectedBundleLibraries) {
            throw GradleException("Unexpected release AAB native libraries: $bundleLibraries")
        }
        logger.lifecycle("Verified release APK/AAB $zappVersionName ($zappVersionCode) with both supported ABIs")
    }
}
