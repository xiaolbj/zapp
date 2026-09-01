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

## 权限与文件选择

平台调用采用异步请求/结果模型，UI 和 reducer 不直接依赖 Android 类型：

```text
App Action -> PlatformRequest -> Zig/C JNI -> ZappActivity
ZappActivity callback -> C 事件队列 -> PlatformEvent -> App reducer
```

- 权限桥支持相机、麦克风、通知和媒体访问，并按 Android 版本选择对应运行时权限。
- 相机和麦克风在 Manifest 中声明为非必需硬件，避免仅使用部分功能时被应用商店错误过滤设备。
- 文件选择使用系统 Storage Access Framework 的 `ACTION_OPEN_DOCUMENT`。
- 成功结果是可持久化读取的 `content://` URI；业务层应通过平台桥读取内容，不应把 URI 当作文件系统路径。
- 用户返回或取消时会产生明确的取消事件，不会阻塞渲染线程。

## 安装与日志

连接设备后：

```powershell
adb install -r app\build\outputs\apk\debug\app-debug.apk
adb logcat -s zapp sokol app
```

当前 APK 已验证 Java 编译、Manifest、自定义 NativeActivity、双 ABI 打包、JNI 导出、`sokol_main` 和 `ANativeActivity_onCreate` 入口符号。在 API 28 x86_64 模拟器上已实际验证应用启动、Sokol/Clay 渲染、相机权限允许回调、系统文件选择器拉起与取消回调；回调后应用保持前台运行且无崩溃日志。中文 IME 仍需覆盖不同厂商输入法，无障碍节点映射仍属于后续平台桥工作。

Android 动态库构建会捆绑 Zig compiler-rt，并显式链接 `libaaudio`；链接器启用 `--no-undefined`，使缺少运行库或系统库的问题在构建期失败，而不是安装后才在动态加载阶段崩溃。`ZappActivity` 还会显式加载 `libzapp.so`，保证 Java 声明的 native 回调由正确的应用 ClassLoader 解析。
