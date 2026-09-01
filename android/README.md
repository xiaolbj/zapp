# Android packaging

此目录预留给 P2 阶段的 Gradle、Manifest、NativeActivity 和 Kotlin/JNI Bridge。

当前 P0 只建立可跨平台编译的 Zig 主体，不提前生成未经验证的 Android 工程。后续 Android 构建将：

1. 让 Zig 为 `arm64-v8a` 和 `x86_64` 生成 `libzapp.so`。
2. 将共享库放入 `app/src/main/jniLibs/<abi>/`。
3. 使用 Gradle 打包 Debug APK 和 Release AAB。
4. 使用 Kotlin/JNI Bridge 实现权限、文件选择、输入法等系统能力。

