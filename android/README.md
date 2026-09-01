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

## 中文输入法桥接

Android 入口使用 `ZappActivity`（`NativeActivity` 子类），渲染、布局和应用状态仍由 Zig、Clay 与 Sokol 持有。Activity 只增加一个 1×1 的透明文本编辑 View，为系统输入法提供 `InputConnection`：

```text
Android IME
    -> ZappActivity.BridgeInputConnection
    -> JNI (android_bridge.c)
    -> 固定容量、互斥保护的事件队列
    -> Zig frame() 消费 PlatformEvent
    -> App reducer
```

当前桥接支持：

- 拼音等组合文本的实时显示；
- 中文、Emoji 等 Unicode 文本提交；
- 退格和软键盘“完成”操作；
- 文本框获得/失去焦点时显示或隐藏软键盘；
- UI 线程与 Sokol 渲染线程隔离，JNI 回调不会直接修改 AppModel。

JNI 层直接把 Java UTF-16 转成标准 UTF-8，并正确合并代理项；每个事件最多携带 256 字节文本，队列最多保存 64 个事件。队列满时丢弃最旧事件并写入 `zapp-ime` 警告日志，避免阻塞 UI 线程。

## 安装与日志

连接设备后：

```powershell
adb install -r app\build\outputs\apk\debug\app-debug.apk
adb logcat -s zapp sokol app
```

当前 APK 已验证 Java 编译、Manifest、自定义 NativeActivity、双 ABI 打包、JNI 导出、`sokol_main` 和 `ANativeActivity_onCreate` 入口符号。Sokol 已提供暂停/恢复生命周期事件；中文 IME 桥接已完成构建级验证，仍需连接 Android 设备验证不同厂商输入法的运行时行为。权限、文件选择和无障碍节点映射仍在后续平台桥阶段接入。
