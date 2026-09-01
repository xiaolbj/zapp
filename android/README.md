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

JNI 层直接把 Java UTF-16 转成标准 UTF-8，并正确合并代理项；每个 IME 事件最多携带 256 字节文本，队列最多保存 64 个事件。普通事件在队列完全占满时丢弃当前新事件并写入 `zapp-platform` 警告日志，不会破坏已经入队的有序流块。

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
- 选择成功后，Java 后台单线程通过 `ContentResolver.openInputStream()` 自动读取最多 4096 字节；渲染线程只消费 JNI 事件队列，不执行阻塞 I/O。
- 同一个后台任务通过 `OpenableColumns.DISPLAY_NAME`/`SIZE` 和 `ContentResolver.getType()` 查询显示名称、可选文件大小与 MIME 类型；provider 不支持元数据查询时仍继续读取内容。
- provider 未返回大小但内容完整读到 EOF 时，以实际读取字节数补全大小；内容已截断时不会把预览长度误报成文件大小。
- 原始字节通过 JNI `byte[]` 返回。UTF-8 内容会清理换行等控制字符后预览，二进制内容显示前 64 字节十六进制；超过上限会显示“已截断”。
- “读取完整文件”使用 4096 字节有序块，每块携带请求 ID 和绝对偏移；reducer 拒绝不连续数据，并增量统计字节数、块数和 FNV-1a 摘要，不把完整文件保存在内存中。
- native 队列为普通交互保留 8 个槽位；流式后台线程在 56 个待消费事件处通过条件变量背压。主循环每帧最多消费 32 个平台事件，避免生产者淹没队列或一次读取长期占用渲染帧。
- 完整读取支持显式取消。已成功入队的块仍按顺序消费，随后以取消事件和实际消费总数收尾；Activity 清理会唤醒等待中的 native 回调。
- 无效 URI、文件不存在、权限拒绝、I/O 错误和平台不支持均映射为稳定的 `FileReadError`，陈旧请求结果会按 request ID 丢弃。

## 原生无障碍语义

Clay 完成每帧布局后，Zig 会为最多 64 个语义节点补齐最终边界，并序列化为固定容量 native 快照。快照内容不变时不会触发 JNI 更新。`AccessibilityBridgeView` 使用 `AccessibilityNodeProvider` 将快照暴露为 Android 虚拟子节点：

- 角色映射到 Button、CheckBox、Switch、SeekBar、EditText、ProgressBar、Dialog 等系统类名。
- 中文标签、值、勾选/选中/禁用、焦点、范围、树层级和展开状态均随快照更新。
- 节点边界转换到屏幕坐标，完全位于视口外的节点不会暴露给系统服务。
- 点击、滑块增减、TextField 设置文本、TreeView 展开/折叠，以及 Card/ScrollView 的向前、向后翻页均通过线程安全事件队列回到 Zig，再复用 UI Action 和 reducer。
- 可滚动节点只暴露当前方向实际可用的 `ACTION_SCROLL_FORWARD`/`BACKWARD` 与 `ACTION_SCROLL_DOWN`/`UP`；动作按可视高度的 80% 移动目标 Clay 容器，并在内容边界处夹紧。
- 模态对话框打开时仅暴露 Dialog 及其按钮，避免读屏焦点进入被遮挡内容。
- 全屏透明语义 View 不绘制内容，也不消费普通触摸；IME 仍由独立的 1×1 编辑 View 提供。

## 安装与日志

连接设备后：

```powershell
adb install -r app\build\outputs\apk\debug\app-debug.apk
adb logcat -s zapp sokol app
```

当前 APK 已验证 Java 编译、Manifest、自定义 NativeActivity、双 ABI 打包、JNI 导出、`sokol_main` 和 `ANativeActivity_onCreate` 入口符号。在 API 28 x86_64 模拟器上已实际验证应用启动、Sokol/Clay 渲染、相机权限允许回调、系统文件选择器拉起/取消/成功选择、`content://` 文本与 PNG 二进制预览、文件名称/MIME/大小元数据、完整流式读取与取消、Home 暂停后同进程恢复，以及原生无障碍节点树。17,772,300 字节字体样本完整读取为 4,339 块，App 摘要 `2adecf5b9049c2ad` 与本地独立 FNV-1a 计算一致；取消验证在 3,719,168 字节、908 块处有序结束，读取期间 UI 保持响应，日志无丢块或崩溃。UIAutomator 可发现中文导航、Button、Checkbox、Switch、SeekBar、TextField、TreeView、流式控制和两个可滚动容器；模态对话框打开后只保留 Dialog、取消和确认三个虚拟节点。中文 IME 仍需覆盖不同厂商输入法，无障碍桥仍需 TalkBack 真机体验验收。

Android 动态库构建会捆绑 Zig compiler-rt，并显式链接 `libaaudio`；链接器启用 `--no-undefined`，使缺少运行库或系统库的问题在构建期失败，而不是安装后才在动态加载阶段崩溃。`ZappActivity` 还会显式加载 `libzapp.so`，保证 Java 声明的 native 回调由正确的应用 ClassLoader 解析。
