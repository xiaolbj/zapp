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

默认输出位置为 `zig-out/android/<abi>/libzapp.so`；Gradle 会使用 `android-output-dir` 将 Debug 和 Release 分别写入 `zig-out/android/debug/<abi>` 与 `zig-out/android/release/<abi>`，避免变体之间复用错误的原生库。Android Debug 使用保留运行时安全检查且兼容 NDK 双 ABI 的 Zig `ReleaseSafe`，Release 使用 `ReleaseSmall`；Gradle Debug APK 本身仍保持 `debuggable=true`。

## 发布构建

版本号可以通过 Gradle property 或环境变量提供：

```powershell
.\gradlew.bat verifyReleaseArtifacts `
  '-PzappNdkPath=D:\Android\android-ndk-r25c' `
  '-PzappVersionCode=42' `
  '-PzappVersionName=0.2.0-rc1'
```

该任务会构建经过 R8/资源收缩的 Release APK 和 AAB，并检查版本元数据以及 `arm64-v8a`、`x86_64` 两个 `libzapp.so`。输出位于：

```text
android/app/build/outputs/apk/release/
android/app/build/outputs/bundle/release/app-release.aab
android/app/build/outputs/native-debug-symbols/zapp-native-symbols-<versionName>-<versionCode>.zip
```

### 原生崩溃符号

Release 构建为每个 ABI 生成稳定的 SHA-1 GNU Build ID。APK/AAB 中只打包经过 `llvm-strip --strip-unneeded` 处理的 `libzapp.so`；完整的压缩 DWARF 行号和符号表单独保存在原生符号 ZIP 中，不随 App 发布。

`verifyReleaseArtifacts` 会自动验证：

- `arm64-v8a`、`x86_64` 的已剥离库与 `.debug` 文件 Build ID 完全一致；
- APK/AAB 内原生库与 Zig 输出逐字节 SHA-256 一致；
- 符号 ZIP 内容与独立 `.debug` 文件逐字节一致；
- 发布库不含 `.debug_info`/`.symtab`，但保留 `.gnu_debuglink`；
- 动态导出只包含 Sokol 入口和项目实际使用的 JNI 入口；
- `llvm-addr2line` 能把 `sokol_main` 地址解析回 Zig 源码行。

每次发布必须按 `versionName`、`versionCode` 和 Build ID 永久保存对应符号 ZIP。分析 tombstone 时先确认崩溃模块的 Build ID 与符号文件匹配，再使用其中对应 ABI 的文件：

```powershell
D:\Android\android-ndk-r25c\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-addr2line.exe `
  -e .\libzapp.so.debug -f -C 0x<relative-pc>
```

这里应传入 tombstone 中 `libzapp.so` 的相对 PC，而不是进程加载后的绝对虚拟地址。符号 ZIP 属于发布诊断资产，不应放进 APK、公开下载目录或应用资源中。

### 运行时 native 崩溃记录

`src/platform/android_crash_report.c` 在 NativeActivity 初始化时为当前进程安装最小致命信号处理器，覆盖 `SIGABRT`、`SIGBUS`、`SIGFPE`、`SIGILL`、`SIGSEGV`、`SIGTRAP` 和 `SIGSYS`。记录文件预先创建在 `ANativeActivity.internalDataPath`，权限为 `0600`；信号处理阶段不分配内存、不调用 JNI，也不进行日志或字符串格式化，只写入固定 88 字节二进制结构、同步文件并把信号转交给原处理器，Android 仍可生成标准 tombstone。

记录包含信号、`si_code`、ABI、绝对 PC、故障地址、PID/TID、Unix 时间戳，以及从已加载 ELF 的 PT_NOTE 读取的 GNU Build ID。若指令地址落在当前 `libzapp.so` 的 PT_LOAD 范围内，还会保存可直接交给对应符号文件的相对 PC。下次启动会校验 magic、版本和结构尺寸，一次性消费有效记录并通过 PlatformEvent → Action → reducer 写入 AppModel；UI 和原生无障碍树会显示“上次运行发生 native 崩溃”及 Build ID。无效、截断或旧版本记录会被忽略。

Debug APK 可用下面的命令验证真实信号恢复流程：

```powershell
$pid = (adb shell pidof com.xiaolbj.zapp).Trim()
adb shell run-as com.xiaolbj.zapp kill -11 $pid
# 确认旧进程终止后再次启动 App
```

如果恢复信息包含 `libzapp+0x...`，使用同一 APK 版本、ABI 和 Build ID 对应的 `.debug` 文件执行 `llvm-addr2line`。外部 `kill` 发出的异步信号通常会中断在系统库中，因此可能只有绝对 PC；真实的 `libzapp` 非法访问才会产生可直接符号化的 App 相对 PC。

该机制是 tombstone/线上崩溃服务的补充，不捕获 `SIGKILL`、低内存终止、断电或处理器安装前发生的崩溃，也不会尝试在损坏进程中上传网络数据。

恢复记录后，UI 会启用“导出崩溃报告”。点击时 Zig 将信号名称/编号、`si_code`、ABI、Build ID、App 相对 PC、绝对 PC、故障地址、PID/TID 和 Unix 时间戳格式化到固定 1024 字节自持有请求中，经 PlatformRequest → C/JNI 调用 Android `ACTION_SEND` 与系统 chooser。Java 层只转交 `text/plain`，不读取、修改或记录正文；chooser 是否成功打开再通过 PlatformEvent → reducer 回到 UI。此状态不代表用户已经选择接收方或完成发送，因为 Android 分享协议不提供可靠的最终发送回执。

导出完全由用户触发，不写入公共存储、不声明网络权限、不自动选择接收方，也不静默上传。若未来接入线上崩溃服务，应另设明确授权、脱敏、保留期和重试策略，而不是复用当前系统分享结果作为上传成功信号。

正式发布签名只从外部注入，仓库不保存密钥或密码：

```powershell
$env:ZAPP_KEYSTORE_PATH = 'D:\keys\zapp-release.jks'
$env:ZAPP_KEYSTORE_PASSWORD = '<store password>'
$env:ZAPP_KEY_ALIAS = '<key alias>'
$env:ZAPP_KEY_PASSWORD = '<key password>'
$env:ZAPP_REQUIRE_RELEASE_SIGNING = 'true'
.\gradlew.bat verifyReleaseSigning verifyReleaseArtifacts
```

也可以使用对应的 `-PzappKeystorePath`、`-PzappKeystorePassword`、`-PzappKeyAlias`、`-PzappKeyPassword` 和 `-PzappRequireReleaseSigning=true`。四项签名参数必须全部提供，否则配置阶段会失败。CI 刻意只生成未签名发布产物，不接触发布密钥；商店上传应在受保护环境中完成签名构建。

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

## 性能基线

`src/performance/frame_metrics.zig` 使用固定 120 帧滚动窗口，不进行帧级堆分配，并每 500 ms 向 AppModel 发布一次快照：

- 帧间隔：来自 `sapp.frameDuration()`，用于 FPS、平均值、P95、最慢帧和超过 16.67 ms 的慢帧比例。
- UI CPU：Clay 布局、控件构建和语义注册耗时。
- 渲染 CPU：RenderCommand 录制、Sokol 提交与 `sg.commit()` 的 CPU 侧耗时，不代表 GPU 完成时间。
- 总 CPU：本帧平台事件、reducer、UI、平台请求和渲染提交的合计耗时。
- 复杂度：平均/峰值 Clay 命令数和平均语义节点数。

2026-09-02 的 API 28 x86_64 模拟器烟雾测试快照为约 60.2 FPS、平均帧间隔 16.60 ms、P95 18.83 ms、UI 0.16 ms、渲染提交 0.33 ms、总 CPU 0.52 ms、84 条命令和 46 个语义节点。该结果只用于确认采样链路和建立当前环境基准，不代表真实设备性能结论。实时数字不进入无障碍语义树，只保留静态“性能基线”标题，避免高频 `TYPE_WINDOW_CONTENT_CHANGED` 让辅助服务无法进入空闲状态。
