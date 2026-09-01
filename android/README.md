# Android packaging

TextField 的平台无关 IME 契约已定义为 `ime_composition_changed`、`ime_composition_committed` 和 `ime_composition_cancelled`。未来 Kotlin/JNI 桥必须在更新线程同步调用 `App.dispatchPlatformEvent`，并保证事件中的 UTF-8 切片在调用返回前有效；未确认组合文本不得直接写入正式文本缓冲区。

此目录预留给 P2 阶段的 Gradle、Manifest、NativeActivity 和 Kotlin/JNI Bridge。

当前 P0 只建立可跨平台编译的 Zig 主体，不提前生成未经验证的 Android 工程。后续 Android 构建将：

1. 让 Zig 为 `arm64-v8a` 和 `x86_64` 生成 `libzapp.so`。
2. 将共享库放入 `app/src/main/jniLibs/<abi>/`。
3. 使用 Gradle 打包 Debug APK 和 Release AAB。
4. 使用 Kotlin/JNI Bridge 实现权限、文件选择、输入法等系统能力。
