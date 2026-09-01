# Android packaging

该目录是 zapp 的 Android NativeActivity APK 壳。主界面和业务逻辑仍由 Zig、Clay 与 Sokol 实现；Gradle 负责调用 Zig 构建两个 ABI 的 `libzapp.so`，同步到生成的 `jniLibs` 目录并打包 APK。

## 已验证工具链

- Android Gradle Plugin 8.6.1
- Gradle 8.7
- JDK 17
- compileSdk / targetSdk 35
- minSdk 26
- Android NDK r25c (`25.2.9519653`)
- ABI：`arm64-v8a`、`x86_64`

AGP 8.6 官方支持 Gradle 8.7、JDK 17 和最高 API 35。NDK 路径不写入仓库，通过 `zappNdkPath` Gradle property 或 `ANDROID_NDK_HOME` 提供。

## 构建

PowerShell 示例：

```powershell
$env:JAVA_HOME = 'D:\Android\jdk-17.0.2'
$env:ANDROID_SDK_ROOT = 'D:\Android\SDK'
$env:ANDROID_HOME = 'D:\Android\SDK'
cd android
.\gradlew.bat assembleDebug '-PzappNdkPath=D:\Android\android-ndk-r25c'
```

APK 输出：

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

也可以只构建一个 Zig 动态库：

```powershell
zig build android-lib `
  -Dandroid-ndk=D:\Android\android-ndk-r25c `
  -Dandroid-abi=arm64-v8a `
  -Dandroid-api=26
```

输出位置为 `zig-out/android/<abi>/libzapp.so`。

## 安装与日志

连接设备后：

```powershell
adb install -r app\build\outputs\apk\debug\app-debug.apk
adb logcat -s zapp sokol app
```

当前 APK 壳已经验证构建、Manifest、双 ABI 打包和 NativeActivity 入口符号。软键盘中文 IME、权限、文件选择、无障碍节点映射与设备生命周期仍在后续平台桥阶段接入。
