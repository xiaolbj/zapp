import org.gradle.api.GradleException
import org.gradle.api.tasks.Sync
import org.gradle.api.tasks.bundling.Zip
import java.io.File
import java.io.InputStream
import java.security.MessageDigest
import java.util.zip.ZipFile

plugins {
    id("com.android.application")
}

fun setting(propertyName: String, environmentName: String) =
    providers.gradleProperty(propertyName).orElse(providers.environmentVariable(environmentName))

fun sha256(stream: InputStream): String {
    val digest = MessageDigest.getInstance("SHA-256")
    val buffer = ByteArray(64 * 1024)
    while (true) {
        val count = stream.read(buffer)
        if (count < 0) break
        digest.update(buffer, 0, count)
    }
    return digest.digest().joinToString("") { "%02x".format(it) }
}

fun sha256(file: File): String = file.inputStream().use { input -> sha256(input) }

fun archiveEntrySha256(archive: File, entryName: String): String = ZipFile(archive).use { zip ->
    val entry = zip.getEntry(entryName) ?: throw GradleException("Archive entry is missing: $entryName in $archive")
    zip.getInputStream(entry).use { input -> sha256(input) }
}

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

fun ndkTool(name: String): File {
    if (!ndkPath.isPresent) throw GradleException("Android NDK path is required to inspect native symbols")
    val host = when {
        System.getProperty("os.name").startsWith("Windows", ignoreCase = true) -> "windows-x86_64"
        System.getProperty("os.name").startsWith("Mac", ignoreCase = true) -> "darwin-x86_64"
        else -> "linux-x86_64"
    }
    val suffix = if (host.startsWith("windows")) ".exe" else ""
    val tool = File(ndkPath.get(), "toolchains/llvm/prebuilt/$host/bin/$name$suffix")
    if (!tool.isFile) throw GradleException("Required NDK tool is missing: $tool")
    return tool
}

fun llvmOutput(tool: String, vararg arguments: Any): String = providers.exec {
    commandLine(listOf(ndkTool(tool).absolutePath) + arguments.map(Any::toString))
}.standardOutput.asText.get()

val expectedNativeExports = setOf(
    "ANativeActivity_onCreate",
    "sokol_main",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeAccessibilityAction",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeAccessibilityNodeAt",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeAccessibilityNodeCount",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeBackspace",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionCancelled",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionChanged",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionCommitted",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeCrashReportExportResult",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeFileReadCompleted",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeFileReadFailed",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeFileSelected",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeFileSelectionCancelled",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeFileStreamCancelled",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeFileStreamChunk",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeFileStreamCompleted",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeFileStreamFailed",
    "Java_com_xiaolbj_zapp_ZappActivity_nativePermissionResult",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeSubmit",
    "Java_com_xiaolbj_zapp_ZappActivity_nativeNavigationRequested",
)

fun registerZigBuild(
    name: String,
    variant: String,
    abi: String,
    optimize: String,
    splitDebugSymbols: Boolean = false,
) = tasks.register<Exec>(name) {
    group = "build"
    description = "Build the $variant libzapp.so for $abi with Zig $optimize"
    workingDir = repositoryRoot
    doFirst {
        if (!ndkPath.isPresent) {
            throw GradleException(
                "Set -PzappNdkPath=<path-to-ndk> or ANDROID_NDK_HOME before building Android artifacts",
            )
        }
        val arguments = mutableListOf(
            zigExecutable.get(), "build", "android-lib", "-Doptimize=$optimize",
            "-Dandroid-ndk=${ndkPath.get()}", "-Dandroid-api=26", "-Dandroid-abi=$abi",
            "-Dandroid-output-dir=android/$variant",
        )
        if (splitDebugSymbols) {
            arguments += "-Dandroid-split-debug-symbols=true"
            arguments += "-Dandroid-symbols-dir=android-symbols/$variant"
        }
        commandLine(arguments)
    }
    inputs.files(
        fileTree(repositoryRoot.resolve("src")), fileTree(repositoryRoot.resolve("assets")),
        fileTree(repositoryRoot.resolve("third_party")),
        repositoryRoot.resolve("zapp.zig"), repositoryRoot.resolve("build.zig"),
        repositoryRoot.resolve("build.zig.zon"),
    )
    outputs.file(repositoryRoot.resolve("zig-out/android/$variant/$abi/libzapp.so"))
    if (splitDebugSymbols) {
        outputs.file(repositoryRoot.resolve("zig-out/android-symbols/$variant/$abi/libzapp.so.debug"))
    }
}

val buildZigDebugArm64 = registerZigBuild("buildZigDebugArm64", "debug", "arm64-v8a", "ReleaseSafe")
val buildZigDebugX64 = registerZigBuild("buildZigDebugX64", "debug", "x86_64", "ReleaseSafe")
val buildZigReleaseArm64 = registerZigBuild(
    "buildZigReleaseArm64", "release", "arm64-v8a", "ReleaseSmall", splitDebugSymbols = true,
)
val buildZigReleaseX64 = registerZigBuild(
    "buildZigReleaseX64", "release", "x86_64", "ReleaseSmall", splitDebugSymbols = true,
)

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

val packageReleaseNativeSymbols by tasks.registering(Zip::class) {
    group = "build"
    description = "Package separated Android native debug symbols for crash symbolication"
    dependsOn(buildZigReleaseArm64, buildZigReleaseX64)
    from(repositoryRoot.resolve("zig-out/android-symbols/release"))
    include("arm64-v8a/libzapp.so.debug", "x86_64/libzapp.so.debug")
    includeEmptyDirs = false
    archiveFileName.set("zapp-native-symbols-$zappVersionName-$zappVersionCode.zip")
    destinationDirectory.set(layout.buildDirectory.dir("outputs/native-debug-symbols"))
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
    dependsOn("assembleRelease", "bundleRelease", "verifyReleaseConfiguration", packageReleaseNativeSymbols)
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
        fun nativeLibraries(archive: File) = ZipFile(archive).use { zip ->
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

        val symbolArchive = packageReleaseNativeSymbols.get().archiveFile.get().asFile
        if (!symbolArchive.isFile) throw GradleException("Native symbol archive is missing: $symbolArchive")
        val expectedSymbolEntries = setOf(
            "arm64-v8a/libzapp.so.debug",
            "x86_64/libzapp.so.debug",
        )
        val actualSymbolEntries = ZipFile(symbolArchive).use { zip ->
            zip.entries().asSequence().filterNot { it.isDirectory }.map { it.name }.toSet()
        }
        if (actualSymbolEntries != expectedSymbolEntries) {
            throw GradleException("Unexpected native symbol archive entries: $actualSymbolEntries")
        }

        val buildIdPattern = Regex("Build ID:\\s*([0-9a-fA-F]{40})")
        for (abi in listOf("arm64-v8a", "x86_64")) {
            val library = repositoryRoot.resolve("zig-out/android/release/$abi/libzapp.so")
            val symbols = repositoryRoot.resolve("zig-out/android-symbols/release/$abi/libzapp.so.debug")
            if (!library.isFile || !symbols.isFile) {
                throw GradleException("Release library or debug symbols are missing for $abi")
            }

            val libraryNotes = llvmOutput("llvm-readelf", "-n", library)
            val symbolNotes = llvmOutput("llvm-readelf", "-n", symbols)
            val libraryBuildId = buildIdPattern.find(libraryNotes)?.groupValues?.get(1)?.lowercase()
                ?: throw GradleException("Release library has no SHA-1 Build ID for $abi")
            val symbolBuildId = buildIdPattern.find(symbolNotes)?.groupValues?.get(1)?.lowercase()
                ?: throw GradleException("Debug symbols have no SHA-1 Build ID for $abi")
            if (libraryBuildId != symbolBuildId) {
                throw GradleException("Build ID mismatch for $abi: $libraryBuildId != $symbolBuildId")
            }

            val librarySections = llvmOutput("llvm-readelf", "-SW", library)
            val symbolSections = llvmOutput("llvm-readelf", "-SW", symbols)
            if (!librarySections.contains(".gnu_debuglink") ||
                librarySections.contains(".debug_info") || librarySections.contains(".symtab")) {
                throw GradleException("Packaged $abi library is not correctly stripped/debug-linked")
            }
            if (!symbolSections.contains(".debug_info") || !symbolSections.contains(".debug_line") ||
                !symbolSections.contains(".symtab")) {
                throw GradleException("Separated $abi symbols do not contain DWARF line information")
            }

            val dynamicSymbols = llvmOutput("llvm-nm", "-D", "--defined-only", library)
            val exportedNames = dynamicSymbols.lineSequence().mapNotNull { line ->
                Regex("^[0-9a-fA-F]+\\s+\\w\\s+(\\S+)").find(line)?.groupValues?.get(1)?.substringBefore("@")
            }.toSet()
            if (exportedNames != expectedNativeExports) {
                throw GradleException("Unexpected exported native symbols for $abi: $exportedNames")
            }
            val sokolMainAddress = Regex("^([0-9a-fA-F]+)\\s+\\w\\s+sokol_main(?:@\\S+)?$", RegexOption.MULTILINE)
                .find(dynamicSymbols)?.groupValues?.get(1)
                ?: throw GradleException("Cannot locate sokol_main in $abi dynamic symbols")
            val symbolicated = llvmOutput("llvm-addr2line", "-e", symbols, "-f", "-C", sokolMainAddress)
            if (!symbolicated.contains("sokol_main") || !symbolicated.contains("main.zig:")) {
                throw GradleException("$abi symbols cannot resolve sokol_main to a Zig source line: $symbolicated")
            }

            val apkEntry = "lib/$abi/libzapp.so"
            val bundleEntry = "base/$apkEntry"
            val symbolEntry = "$abi/libzapp.so.debug"
            val libraryHash = sha256(library)
            val symbolHash = sha256(symbols)
            if (archiveEntrySha256(apk, apkEntry) != libraryHash ||
                archiveEntrySha256(aab, bundleEntry) != libraryHash) {
                throw GradleException("Packaged native library hash mismatch for $abi")
            }
            if (archiveEntrySha256(symbolArchive, symbolEntry) != symbolHash) {
                throw GradleException("Native symbol archive hash mismatch for $abi")
            }
            logger.lifecycle("Verified $abi native Build ID $libraryBuildId and source-level symbols")
        }
        logger.lifecycle(
            "Verified release APK/AAB $zappVersionName ($zappVersionCode), both ABIs, and ${symbolArchive.name}",
        )
    }
}
