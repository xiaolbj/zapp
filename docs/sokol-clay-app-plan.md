# Sokol-Zig + Clay 跨平台 App 技术方案

> 状态：已确认，作为项目当前实施基线  
> 建立日期：2026-09-01  
> 当前工具链：Zig 0.16.0  
> 目标平台：Windows、macOS、Linux、Android，后续支持 iOS 与 Web

## 1. 项目目标

使用 Zig 建立一套以单一业务代码库为核心的跨平台 App 开发环境：

- Sokol 负责窗口、输入、GPU、音频等底层能力。
- Clay 负责正式产品 UI 的响应式布局。
- Zig 负责业务逻辑、状态管理、控件行为和渲染器。
- Android、iOS 等系统功能通过薄平台桥接层接入。
- ImGui 仅作为可选的开发和调试工具，不作为正式产品 UI。

这套方案优先服务高度自定义视觉、全屏自绘、游戏化或实时图形类 App，而不是追求原生 Android/iOS 控件外观。

## 2. 已确认的技术决策

### 2.1 正式 UI 使用 Clay

Clay 适合作为本项目的主 UI 布局引擎，原因如下：

- 渲染器无关，可以统一覆盖桌面、移动端和 Web。
- 布局和视觉完全由应用控制，适合品牌化界面。
- 与 Sokol 的逐帧 GPU 渲染模型匹配。
- 不依赖 Android Compose、iOS SwiftUI 或桌面系统控件。
- 业务、布局和渲染代码可以主要保留在 Zig 中。

Clay 只负责布局和生成渲染命令，不是完整控件框架。Button、TextField、焦点、导航、动画和输入法适配都属于项目自身的 UI 层。

### 2.2 ImGui 只用于开发工具

ImGui 适合：

- AppModel Inspector
- 日志控制台
- GPU 和内存统计
- Clay 元素边界查看
- 字体图集检查
- 网络请求调试
- 页面快速跳转
- Theme 参数实时调整

正式发布时通过构建选项禁用：

```zig
if (build_options.enable_debug_ui) {
    debug_ui.draw(&app);
}
```

第一阶段不要求集成 ImGui，避免同时引入 Clay Renderer 与 cimgui 两条依赖链。

### 2.3 Compose 排除出当前方案

Jetpack Compose 不作为正式 UI 技术栈：

- 当前目标是 Zig/Sokol 主导的多平台单代码库。
- Compose 会引入 Kotlin/JVM 为中心的第二套 UI 架构。
- 即使使用 Compose Multiplatform，权限、支付、通知和输入法仍需要平台适配。
- Compose 与 `sokol_app` 对窗口和 Surface 的所有权模型不能直接无缝组合。

Kotlin仍可存在于 Android 平台桥接层，但不负责主界面。

### 2.4 依赖必须固定版本

当前建议基线：

| 组件 | 基线 | 说明 |
|---|---|---|
| Zig | 0.16.0 | 当前开发机已安装 |
| sokol-zig | 固定 commit | 主仓库支持 Zig 0.16+，不可跟随浮动 master |
| zclay | `v0.2.2+0.14` | 对应 Clay 0.14，已在本机 Zig 0.16.0 上验证 `zig build` |
| Clay | 0.14 | 由 zclay 依赖固定 |

依赖更新必须作为单独变更处理，并同时验证桌面、Android、布局快照和 ABI。

不采用 `raugl/clay-zig` 当前版本：其构建清单仍使用旧 Zig 格式，在 Zig 0.16.0 下无法直接构建。

## 3. 总体架构

```text
Platform Events
      │
      ▼
Input / PlatformEvent
      │
      ▼
Action ───────────────► AppModel
                           │
                           ▼
                    Clay UI Layout
                           │
                    []RenderCommand
                           │
                           ▼
                  Clay Sokol Renderer
                    │       │       │
                    ▼       ▼       ▼
                  Shape    Text    Image
                    └───────┬───────┘
                            ▼
                        sokol.gfx
```

核心原则：

1. 业务状态不保存在临时 UI 调用中。
2. UI 产生 Action，由业务层更新 AppModel。
3. Clay 根据 AppModel 声明当前帧界面。
4. Renderer 只消费 RenderCommand，不执行业务逻辑。
5. 平台 API 使用异步请求和 PlatformEvent 返回结果。

## 4. 建议目录结构

```text
zapp/
├─ build.zig
├─ build.zig.zon
├─ docs/
│  └─ sokol-clay-app-plan.md
├─ src/
│  ├─ main.zig
│  ├─ app/
│  │  ├─ app.zig
│  │  ├─ model.zig
│  │  ├─ action.zig
│  │  ├─ reducer.zig
│  │  └─ route.zig
│  ├─ ui/
│  │  ├─ root.zig
│  │  ├─ theme.zig
│  │  ├─ focus.zig
│  │  ├─ navigation.zig
│  │  ├─ animation.zig
│  │  ├─ widgets/
│  │  │  ├─ button.zig
│  │  │  ├─ label.zig
│  │  │  ├─ toggle.zig
│  │  │  ├─ slider.zig
│  │  │  ├─ scroll_view.zig
│  │  │  ├─ dialog.zig
│  │  │  └─ text_field.zig
│  │  └─ screens/
│  ├─ render/
│  │  ├─ clay_renderer.zig
│  │  ├─ shape_batch.zig
│  │  ├─ font_atlas.zig
│  │  ├─ image_cache.zig
│  │  └─ shaders/
│  │     └─ ui.glsl
│  ├─ services/
│  │  ├─ storage.zig
│  │  ├─ network.zig
│  │  └─ assets.zig
│  ├─ platform/
│  │  ├─ platform.zig
│  │  ├─ desktop.zig
│  │  ├─ android/
│  │  │  ├─ android.zig
│  │  │  ├─ jni.zig
│  │  │  └─ messages.zig
│  │  ├─ ios/
│  │  └─ web/
│  └─ debug/
│     └─ debug_ui.zig
├─ assets/
│  ├─ fonts/
│  └─ images/
├─ tests/
│  ├─ reducer_test.zig
│  ├─ layout_test.zig
│  └─ widget_test.zig
└─ android/
   ├─ settings.gradle.kts
   ├─ build.gradle.kts
   └─ app/
      ├─ build.gradle.kts
      └─ src/main/
         ├─ AndroidManifest.xml
         ├─ java/.../MainActivity.kt
         ├─ assets/
         └─ jniLibs/
            ├─ arm64-v8a/libzapp.so
            └─ x86_64/libzapp.so
```

目录按阶段创建，不要求第一天建立所有空文件。

## 5. App 状态与事件模型

业务层使用单向数据流：

```zig
pub const Action = union(enum) {
    navigate: Route,
    back,
    login_submitted: LoginForm,
    toggle_setting: SettingId,
    file_picker_requested,
    file_selected: FileResult,
    permission_result: PermissionResult,
    dialog_closed,
};
```

推荐流程：

```text
用户输入 → Action → reducer/update → AppModel → UI
平台结果 → PlatformEvent → Action → AppModel → UI
```

好处：

- UI 和业务逻辑可以独立测试。
- 平台异步操作不会阻塞渲染线程。
- 页面切换、日志记录和问题复现更清晰。
- 后续可以增加撤销、重做或状态回放。

## 6. Clay Renderer 范围

`clay_renderer.zig` 按 Clay 提供的顺序处理：

- Rectangle：纯色和圆角矩形。
- Border：四边及圆角边框。
- Text：字体图集中的 glyph quads。
- Image：纹理矩形。
- Scissor Start/End：滚动区域与裁剪。
- Custom：图表、视频、Canvas 或特殊内容。

渲染策略：

- 使用动态 vertex/index buffer。
- 按 pipeline、texture、scissor 状态批处理。
- UI shader 通过 `sokol-shdc` 在构建阶段生成 Zig 模块。
- 每帧禁止加载资源或重建字体图集。
- Renderer 不持有页面或控件业务状态。

不直接采用 Clay 官方 `sokol_clay.h` 作为长期实现。该实现还依赖 `sokol_gl`、`sokol_fontstash` 和 `fontstash`，容易产生 Clay、Sokol、字体库之间的版本同步问题；可以把它作为渲染实现参考。

## 7. 字体和文本

第一阶段目标：英文、数字和基础中文显示。

当前实现：

- Fontstash 使用 stb_truetype 解析内存中的字体并按需生成 glyph atlas。
- `sokol_fontstash.h` 把字体图集与绘制命令接入现有 `sokol.gl` 管线。
- 测量和绘制共享同一个字体缓存与字形指标。
- 当前字体为 Noto Sans SC 可变字体，使用 OFL-1.1 许可并随应用嵌入。
- 初始 R8 图集为 2048×2048，图集满时最多扩展到 4096×4096。
- 初始化时使用 stb_truetype 验证字体包含 U+4E2D“中”字形。

当前内嵌字体约 17.8 MB。进入发布优化阶段后，应根据产品实际字符集评估静态子集、字体分包或按语言下载，不能在功能尚未确定时提前裁掉字符。

后续需求：

- 中文输入法组合状态。
- 光标、选区、删除、复制和粘贴。
- 字体 fallback。
- 阿拉伯语等复杂文字需要 FreeType/HarfBuzz 或平台文字服务。

TextField 是 UI 控件中风险最高的部分，应晚于 Button、导航、滚动和主题系统实现。

## 8. 控件系统

第一批控件：

- Button
- IconButton
- Label
- Checkbox/Switch
- Slider
- ScrollView/List
- Dialog
- Toast
- NavigationBar
- 基础单行 TextField
- TreeView（后续补充）

统一交互状态：

```zig
pub const WidgetState = enum {
    normal,
    hovered,
    pressed,
    focused,
    disabled,
};
```

所有控件必须：

- 使用稳定 Clay ID。
- 从 Theme 读取颜色、字体、圆角和间距。
- 支持鼠标和触摸。
- 为键盘、手柄和无障碍扩展预留语义信息。
- 不直接执行文件、网络或权限操作，只产生 Action。

## 9. 主题、DPI 与响应式布局

主题集中定义：

```zig
pub const Theme = struct {
    colors: Colors,
    typography: Typography,
    spacing: Spacing,
    radius: Radius,
    animation: AnimationTokens,
};
```

第一阶段可统一使用 framebuffer pixel。稳定后切换为逻辑单位：

```text
logical_size = framebuffer_size / dpi_scale
render_position = logical_position * dpi_scale
```

禁止在不同页面混用逻辑像素和物理像素。响应式断点由应用统一定义，不在页面中散落平台判断。

## 10. 平台 API 抽象

跨平台不等于没有平台代码。以下能力必须使用平台实现：

- 权限
- 文件选择器
- 通知
- 分享
- 支付
- 剪贴板
- 输入法
- 生物识别
- 系统设置
- 应用生命周期

统一 Zig 接口示例：

```zig
pub const Platform = struct {
    pub fn openFilePicker(options: FilePickerOptions) RequestId;
    pub fn requestPermission(permission: Permission) RequestId;
    pub fn setClipboardText(text: []const u8) void;
    pub fn showKeyboard(config: KeyboardConfig) void;
    pub fn share(payload: SharePayload) RequestId;
};

pub const PlatformEvent = union(enum) {
    permission_result: PermissionResult,
    file_selected: FileResult,
    keyboard_changed: KeyboardState,
    share_completed: ShareResult,
};
```

所有可能弹出系统界面或等待用户响应的 API 都必须异步化。

## 11. Android APK 方案

### 11.1 运行模型

- Zig 生成 `libzapp.so`。
- Sokol 使用 Android NativeActivity 和 GLES3。
- Gradle 负责 Manifest、Kotlin、资源、ABI、签名和 APK/AAB。
- Kotlin Bridge 负责 Android Framework API。

首期 ABI：

- `arm64-v8a`：真机与发布主目标。
- `x86_64`：Android Emulator。

### 11.2 JNI 边界

Sokol 提供：

```zig
sokol.app.androidGetNativeActivity()
sokol.app.androidGetNativeWindow()
```

`ANativeActivity` 可提供 JavaVM、Activity 对象、AssetManager 和应用数据目录。

线程规则：

- 不得跨线程缓存或使用 `JNIEnv`。
- 保存 `JavaVM`，在线程内通过 `GetEnv` 获取环境。
- 必要时使用 `AttachCurrentThread`。
- Android UI 操作必须调度到主线程。
- JNI 回调结果写入线程安全事件队列，在下一帧转成 Action。

### 11.3 APK 构建链

```text
zig build android-lib
        ↓
android/app/src/main/jniLibs/<abi>/libzapp.so
        ↓
Gradle assembleDebug / bundleRelease
        ↓
APK / AAB
```

最终以实际实现的 Zig build step 名称为准。

## 12. 平台覆盖计划

| 平台 | 图形后端 | 当前优先级 | 平台桥接 |
|---|---|---:|---|
| Windows | D3D11 | P0 | Win32 |
| Android | GLES3 | P0 | JNI + Kotlin |
| macOS | Metal | P1 | Objective-C |
| Linux | OpenGL | P1 | 系统 API/桌面门户 |
| Web | WebGL2/Emscripten | P2 | JavaScript Bridge |
| iOS | Metal | P2 | Objective-C/Swift Bridge |

桌面端先用于快速开发和调试，Android 必须在早期持续真机验证，避免最后才暴露触摸、DPI、生命周期和 GLES 差异。

## 13. 性能策略

Clay 和 Sokol 都适合逐帧渲染，但 App 在静止时不应永久满速消耗资源。

建议状态：

```text
Active:   触摸、滚动、动画、实时内容 → 60 FPS
Idle:     界面静止但需要周期更新       → 10～15 FPS
Sleeping: 无可见变化或应用在后台       → 停止渲染
```

初期监控指标：

| 指标 | 目标 |
|---|---:|
| UI CPU 时间 | `< 2 ms/frame` |
| 60 FPS 总帧时间 | `< 16.6 ms`，推荐保留余量 |
| 常态 Draw Calls | `< 100` |
| UI 顶点 | `< 200k/frame` |
| 每帧堆分配 | 接近 0 |
| 后台刷新 | 0 FPS |

大型列表必须进行可见区域裁剪，不能为不可见条目生成全部控件和文字。

## 14. 构建与开发命令目标

桌面端预期：

```powershell
zig build
zig build run
zig build test
zig build -Doptimize=ReleaseFast
```

Android 预期：

```powershell
zig build android-lib -Dabi=arm64-v8a
./gradlew assembleDebug
./gradlew bundleRelease
```

Web 后续使用 sokol-zig 的 Emscripten 链接步骤：

```powershell
zig build install-emsdk
zig build -Dtarget=wasm32-emscripten
```

所有命令都应最终封装成 Zig build step 或仓库脚本，避免依赖个人机器上的手工复制。

## 15. 测试策略

### 单元测试

- reducer/action 状态转换。
- 页面导航。
- Theme 和响应式断点。
- 控件交互状态机。
- 字体测量和换行。

### 布局测试

- 固定 AppModel、窗口尺寸和 DPI。
- 生成 Clay RenderCommand。
- 对命令序列或关键 bounding box 做快照比较。

### 渲染测试

- Windows GPU smoke test。
- Android Emulator 构建测试。
- Android 真机启动、旋转、暂停和恢复。
- 必要时进行截图 golden test。

### 平台测试

- 权限允许和拒绝。
- 文件选择取消。
- 软键盘显示、隐藏和中文输入。
- 应用切后台后恢复。
- 低内存事件。

## 16. 分阶段路线

### P0：可运行骨架

- 初始化项目和固定依赖。
- 创建 Sokol 窗口与 GPU context。
- 初始化 Clay arena。
- 实现纯色 Rectangle Renderer。
- 接入鼠标/触摸位置和点击。
- Windows 上运行第一个响应式页面。

完成标准：窗口可缩放，Clay 布局正确，无资源泄漏或验证错误。

### P1：最小 App 闭环

- Text Renderer 和基础中英文字体。
- Image、Scissor、Border、圆角。
- Theme。
- Button、ScrollView、Dialog。
- AppModel、Action、Navigation。
- 两个页面之间可交互跳转。

完成标准：能够实现真实的首页、设置页和弹窗流程。

### P2：Android APK

- Zig 输出 Android `.so`。
- Gradle/Manifest/NativeActivity。
- arm64-v8a 和 x86_64。
- 触摸、DPI、旋转、暂停和恢复。
- JNI Bridge 示例：权限或文件选择器。

完成标准：Debug APK 可在模拟器和至少一台真机上安装运行。

### P3：App 控件能力

- FocusManager。
- 键盘和手柄导航。
- 基础 TextField。
- Android 软键盘和中文 IME。
- 剪贴板。
- Toast 和平台错误反馈。

### P4：工程化与发布

- Windows、Android、macOS、Linux CI。
- Release 优化与符号管理。
- APK/AAB 签名。
- 崩溃日志。
- 性能基线。
- 可选 ImGui 调试层。
- Web/iOS 验证。

## 17. 主要风险

| 风险 | 影响 | 应对 |
|---|---|---|
| Clay 不是完整控件库 | 控件开发量较大 | 严格控制第一批控件范围 |
| TextField/IME 复杂 | 移动端输入体验风险 | 尽早 Android 真机验证，平台桥接辅助 |
| zclay 与 Clay 版本耦合 | 升级可能破坏 ABI/API | 固定版本，升级单独评审 |
| 字体与中文覆盖 | 包体、图集和测量压力 | 按需 glyph atlas、字体 fallback |
| Android 生命周期 | 暂停恢复可能丢失 GPU 资源 | 集中管理资源生命周期并做恢复测试 |
| 无障碍能力不足 | 部分产品不可接受 | 立项阶段确认无障碍等级，必要时增加平台语义桥 |
| 静止界面持续渲染 | 移动端耗电发热 | Active/Idle/Sleeping 调度 |
| 平台 API 逐渐扩张 | 跨平台层失控 | 保持窄接口、异步事件、禁止平台类型泄漏 |

## 18. 不适用场景

出现以下核心需求时，需要重新评估自绘 UI：

- 大量复杂富文本编辑。
- 必须达到完整系统无障碍支持。
- 强依赖原生控件外观和系统导航。
- 产品主体是表单、聊天或系统设置式页面。
- 要求使用大量嵌入式 WebView。

这不代表项目无法实现，而是平台适配成本可能超过跨平台收益。

## 19. 下一步

P0 骨架、Rectangle Renderer 与 Unicode/中文 Text 数据流已经完成。后续仍按单线推进，不同时展开 Android、控件和 ImGui：

1. 实现圆角、边框与图片命令。
2. 建立 Button 等第一批正式交互控件。
3. 补充布局和渲染回归测试。
4. 桌面 UI 基线稳定后，再建立 Android APK 壳与 JNI 桥。
5. 发布优化阶段再处理中文字体子集或按语言分包。

任何改变“Clay 作为正式 UI、ImGui 仅作调试、平台能力走薄桥接层”这三个核心决策的变更，都应先更新本文档并记录理由。

## 20. UI 控件实施状态

截至 2026-09-01，正式 UI 已具备以下可复用控件：

- `Label`：统一文本样式入口。
- `Button` 与 `IconButton`：支持 normal、hover、pressed、disabled 状态。
- `Checkbox` 与 `Switch`：受控选择控件，值由 AppModel 持有。
- `ProgressBar`：受控进度显示，输入值约束到 `0...1`。
- `ScrollView`：使用 Clay clip/scroll container，支持鼠标滚轮与触摸拖动。
- `Card` 与 `Divider`：统一容器视觉和内容分组。
- `Slider`：受控拖拽输入，通过元素边界将指针位置映射到 `0...1`。
- `Dialog`：模态浮层，包含遮罩输入捕获、确认/取消和返回键关闭。
- `FocusManager`：保存模态前焦点、设置初始焦点并在关闭后恢复。
- `NavigationBar`：受控页面选择，支持横向和纵向排列。
- `Toast`：非模态、输入穿透、定时消失的反馈浮层。
- `TextField`：受控单行 UTF-8 文本，支持字符输入、完整码点退格、Enter 提交、系统粘贴和移动软键盘显示。

所有可点击控件共享一个指针捕获状态机。平台输入先进入 AppModel，UI 构建时生成语义 Action，再由 reducer 更新业务状态。滚轮输入与按下/释放边沿一样保留到 UI 消费完成，避免事件发生在两帧之间时丢失。

Clay 0.14 context 按应用生命周期单次初始化：启动时 `setup()`，最终退出时 `shutdown()`。当前绑定没有 context destroy/null API，因此测试中的多个 UI 场景必须复用同一个 Clay context，不能释放 arena 后在同一进程内重新初始化。

路线图第一批控件已经全部具备可运行实现。TextField 已具备 UTF-8 光标移动、鼠标/触摸点击定位与拖选、Shift 选择、Home/End、全选、复制、剪切、粘贴、删除、选区替换和独立 IME 组合态。平台事件可同步更新、提交或取消组合文本；Android Java/JNI 桥已接入系统输入法，后续继续覆盖不同厂商输入法。

补充控件 TreeView 已实现：使用父索引描述扁平树数据，展开掩码与选择项由 AppModel/reducer 控制；仅为可见节点生成 Clay 布局，鼠标点击箭头可折叠/展开，键盘或统一导航命令可用左右方向进入子节点、返回父节点或改变展开状态。Tree/tree_item 语义包含层级、选中和展开状态。

键盘基础导航已接入：普通页面和 Dialog 分别维护焦点顺序，`Tab`/`Shift+Tab` 循环移动，`Enter`/`Space` 激活当前控件，Slider 支持左右键步进。可见焦点环已经使用 Theme 令牌统一接入 Button、IconButton、Checkbox、Switch、Slider、TextField、NavigationBar 和 TreeView，并由 Border RenderCommand 渲染。

平台层已定义统一 `NavigationCommand`，手柄、电视遥控器或辅助输入设备可以投递 next/previous/activate/decrement/increment/back，并复用键盘的 FocusManager 和一帧请求状态。Sokol 本身不提供统一 gamepad 事件，Windows XInput、Android KeyEvent/InputDevice 与 Apple GameController 的原生采集属于各平台壳实现。

控件语义元数据已接入：`ui.Frame.semantic_nodes` 每帧输出稳定 Clay 元素 ID、角色、标签、值/勾选值、最终布局边界以及 disabled、focused、selected、modal 状态。交互控件以及 Label、ProgressBar、Toast、Card、ScrollView/List 均通过同一注册表写入；Divider 作为纯装饰元素不进入语义树。Android 已用 `AccessibilityNodeProvider` 映射虚拟节点与动作回传，Card/ScrollView 还会根据 Clay 的实际滚动位置暴露可用方向并执行 80% 视口高度的系统翻页动作；iOS 原生无障碍桥仍负责将同一份数据映射到 UIAccessibility。

控件主题一致性已完成：widgets 的状态颜色、文字颜色、常用圆角和间距统一引用 Theme 令牌，不再在各控件内维护独立调色板。

## 21. 当前实施状态

截至 2026-09-01，P0 主体骨架和首个可渲染页面已经建立：

- 独立 `zapp` Zig package，不修改或 fork sokol-zig。
- sokol-zig 固定到 commit `e371234960812882406a296c4f3154321a16ee4d`。
- zclay 固定到 commit `e0286c488a303b93501944ccde10730cc74ecd58`，包版本为 `0.2.2`，对应 Clay 0.14。
- Fontstash 固定到 commit `b5ddc9741061343740d85d636d782ed3e07cf7be`。
- 提供 `sokol_fontstash.h` 的 Sokol 官方源码固定到 commit `1847290135f95e57e6d220b0a41208306aafc0dd`。
- 已建立 Sokol 初始化、frame、event 和 cleanup 生命周期。
- 已建立桌面 `main() + sapp.run()` 与 Android 条件导出 `sokol_main` 的入口边界。
- 已建立 AppModel、Action、reducer、UI Frame、ClayRenderer 和 PlatformEvent 接口。
- 已初始化 Clay arena，并在每帧同步视口尺寸和鼠标/触摸指针状态。
- 已建立桌面与窄屏两种布局方向的响应式页面骨架。
- ClayRenderer 已通过 `sokol.gl` 绘制 Rectangle，并处理 Scissor Start/End。
- 已注册 Clay 文本测量回调并处理 Text RenderCommand，页面包含标题、导航和卡片说明文本。
- 已移除临时 `sokol_debugtext` 后端，改用独立 C 桥接的 Fontstash 与 `sokol_fontstash.h`。
- 已内嵌 Noto Sans SC，并在首屏实际使用中文标题、导航和说明文字。
- Clay 测量与绘制共享 Fontstash 字体上下文，UTF-8 文本不再替换为占位字符。
- `sokol.gl` 与窗口 swapchain 都显式使用无深度格式，避免默认深度写入导致图形验证失败。
- `zig build check` 和 `zig build test` 已在 Zig 0.16.0/Windows 上通过。
- 已实际启动桌面窗口并保持正常响应；当前窗口自动化层未能枚举该原生窗口，因此本轮没有截图验收。

Rectangle 圆角、Border RenderCommand、首批控件、平台无关语义元数据和统一导航命令均已实现。Android NativeActivity APK 壳也已建立：`android-lib` 使用 Zig 生成 PIC 静态归档并由 NDK Clang 链接 `libzapp.so`，Gradle 自动构建和打包 `arm64-v8a`/`x86_64`。Debug APK、Manifest、双 ABI 和入口符号已在 Windows + NDK r25c 上验证；API 28 x86_64 模拟器已验证启动渲染、相机权限结果、系统文件选择器启动/取消/成功结果、`content://` URI 异步文本/二进制读取、Home 暂停恢复、原生虚拟无障碍节点树和滚动容器系统动作映射。下一阶段继续进行 TalkBack 与不同厂商中文 IME 真机体验验收，并接入文件元数据/完整流式消费和发布工程化。
