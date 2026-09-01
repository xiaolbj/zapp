import org.gradle.api.tasks.Sync

plugins {
    id("com.android.application")
}

android {
    namespace = "com.xiaolbj.zapp"
    compileSdk = 35
    ndkVersion = "25.2.9519653"

    providers.gradleProperty("zappNdkPath").orNull?.let {
        ndkPath = it
    }

    defaultConfig {
        applicationId = "com.xiaolbj.zapp"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        ndk {
            abiFilters += setOf("arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    sourceSets.getByName("main").jniLibs.srcDir(layout.buildDirectory.dir("generated/zappJniLibs"))
}

val repositoryRoot = rootDir.parentFile
val zigExecutable = providers.gradleProperty("zigExecutable").orElse("zig")
val ndkPath = providers.gradleProperty("zappNdkPath")
    .orElse(providers.environmentVariable("ANDROID_NDK_HOME"))

fun registerZigBuild(name: String, abi: String) = tasks.register<Exec>(name) {
    group = "build"
    description = "Build libzapp.so for $abi with Zig"
    workingDir = repositoryRoot
    doFirst {
        require(ndkPath.isPresent) {
            "Set -PzappNdkPath=<path-to-ndk> or ANDROID_NDK_HOME before building the APK"
        }
        commandLine(
            zigExecutable.get(),
            "build",
            "android-lib",
            "-Doptimize=ReleaseSafe",
            "-Dandroid-ndk=${ndkPath.get()}",
            "-Dandroid-api=26",
            "-Dandroid-abi=$abi",
        )
    }
    inputs.files(
        fileTree(repositoryRoot.resolve("src")),
        fileTree(repositoryRoot.resolve("assets")),
        repositoryRoot.resolve("zapp.zig"),
        repositoryRoot.resolve("build.zig"),
        repositoryRoot.resolve("build.zig.zon"),
    )
    outputs.file(repositoryRoot.resolve("zig-out/android/$abi/libzapp.so"))
}

val buildZigArm64 = registerZigBuild("buildZigArm64", "arm64-v8a")
val buildZigX64 = registerZigBuild("buildZigX64", "x86_64")

val syncZigLibraries by tasks.registering(Sync::class) {
    dependsOn(buildZigArm64, buildZigX64)
    from(repositoryRoot.resolve("zig-out/android"))
    into(layout.buildDirectory.dir("generated/zappJniLibs"))
}

tasks.named("preBuild").configure {
    dependsOn(syncZigLibraries)
}
