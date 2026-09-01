# zapp

使用 Zig、sokol-zig 和 Clay 构建的跨平台自绘 App 基础项目。

当前数据流为：

```text
平台输入 -> AppModel -> Clay 布局/控件 -> UI Action -> AppModel
                              |
                              v
                 Clay RenderCommand -> Sokol
```

已接通 Rectangle、圆角、Border、Scissor 和 Unicode Text 渲染；中文字体由 Fontstash、`sokol_fontstash.h` 与内嵌的 Noto Sans SC 提供。所有键盘可交互控件都会使用 Theme 焦点令牌生成 Clay Border 命令，渲染器负责绘制可见焦点环。

主循环内置固定内存的 120 帧性能窗口，每 500 ms 更新 FPS、平均/P95/最慢帧、UI 与渲染提交 CPU 时间、Clay 命令数和语义节点数。统计快照仍通过 Action/reducer 进入 AppModel；高频数字只做视觉显示，避免持续触发 Android 无障碍内容变化事件。

## 开发命令

```powershell
zig build check
zig build test
zig build run
```

Android Debug APK：

```powershell
cd android
.\gradlew.bat assembleDebug '-PzappNdkPath=D:\Android\android-ndk-r25c'
```

Release APK/AAB（未提供外部密钥时生成未签名 APK）：

```powershell
.\gradlew.bat verifyReleaseArtifacts `
  '-PzappNdkPath=D:\Android\android-ndk-r25c' `
  '-PzappVersionCode=1' `
  '-PzappVersionName=0.1.0'
```

该任务同时生成已剥离的 APK/AAB 和按版本命名的独立原生符号 ZIP，并核对双 ABI 的 Build ID、导出符号、归档哈希及源码行解析能力。符号包位于 `android/app/build/outputs/native-debug-symbols/`，详细用法见 [Android 构建说明](android/README.md#原生崩溃符号)。

Android 运行时还会把可捕获的 native 致命信号写入应用私有的固定尺寸记录，下次启动经 PlatformEvent/reducer 恢复并显示诊断信息。用户可主动点击“导出崩溃报告”，通过系统分享面板发送由 Zig 生成的固定容量纯文本；应用不会静默联网或自动上传。记录范围、一次性消费、导出内容和符号化流程见 [运行时 native 崩溃记录](android/README.md#运行时-native-崩溃记录)。

Gradle 会自动调用 `zig build android-lib` 构建 `arm64-v8a` 与 `x86_64`。完整环境变量和安装命令见 [android/README.md](android/README.md)。

## UI 控件

第一批可复用控件位于 `src/ui/widgets`：

- `label.zig`：统一封装 Clay 文本样式。
- `button.zig`：支持 normal、hover、pressed、disabled 状态。
- `checkbox.zig`：受控勾选框，状态由 AppModel 持有。
- `switch.zig`：受控开关，支持启用、关闭和禁用样式。
- `icon_button.zig`：适合工具栏和紧凑操作的圆形图标按钮。
- `progress_bar.zig`：受控进度显示，自动将数值约束到 `0...1`。
- `radio_group.zig`：互斥单选组，支持横/纵布局、方向键循环选择和原生单选语义。
- `select.zig`：受控单选下拉框，支持展开/收起、动态选项焦点、键盘循环选择和原生 Spinner 语义。
- `tabs.zig`：受控标签页导航，支持横/纵布局、方向键自动切换、单一 Tab 停靠点和原生标签语义。
- `menu.zig`：受控操作菜单，支持禁用项、上下键循环、Home/End 首尾跳转、关闭后焦点恢复和原生菜单语义。
- `virtual_list.zig`：固定行高虚拟列表，千行数据只生成可见区与少量预取行，支持选择、方向键/Home/End、稳定行 ID 和原生列表项语义。
- `data_table.zig`：受控数据表格，支持稳定行身份、列排序、行选择、表头/行键盘导航和 Android CollectionInfo 集合语义。
- `scroll_view.zig`：基于 Clay clip/scroll container 的垂直滚动容器。
- `card.zig`：统一页面卡片的内边距、间距、背景和圆角。
- `divider.zig`：用于内容分组的轻量分隔线。
- `slider.zig`：受控拖拽滑块，将指针位置映射为 `0...1` 数值。
- `dialog.zig`：带输入拦截遮罩、取消和确认操作的模态对话框。
- `navigation_bar.zig`：受控导航项选择，支持横向和纵向布局。
- `text_field.zig`：基础受控单行 UTF-8 输入框，支持字符、退格、提交和粘贴。
- `toast.zig`：不拦截输入、按时自动消失的全局提示层。
- `tree_view.zig`：受控层级树，支持展开/折叠、选择、动态焦点顺序、方向键树内导航、折叠后的焦点回收和树语义节点。
- `interaction.zig`：所有指针控件共享的按压捕获与点击判定状态机。

`src/ui/focus_manager.zig` 保存当前焦点、模态焦点和打开弹窗前的焦点。Dialog 关闭后会恢复之前的焦点；Escape 和 Android 返回键统一转成 `back_requested` Action。

`src/ui/semantics.zig` 提供平台无关的帧级语义注册表。交互控件以及 Label、ProgressBar、Toast、Card、ScrollView/List、VirtualList、DataTable、TreeView、RadioGroup、Select、Tabs、Menu 会随 `ui.Frame.semantic_nodes` 输出稳定元素 ID、角色、标签、值、最终布局边界以及 focused/disabled/selected/checked/modal/expanded/level、行列位置等状态；Divider 被明确视为装饰元素，不进入语义树。Android 已通过 `AccessibilityNodeProvider` 将这些数据映射成原生虚拟节点，并把点击、增减、文本设置和展开/折叠动作送回现有 App Action/reducer。TreeView 获得焦点后可用上/下键移动到相邻可见节点、右键展开或进入首个子节点、左键折叠或返回父节点；RadioGroup 使用方向键循环移动并选择互斥项；Select 关闭时方向键直接选择，展开时选项加入焦点和语义树；Tabs 使用与布局方向一致的方向键自动切换活动页；Menu 打开后用上下键或 Home/End 在可用项间导航；VirtualList 使用方向键/Home/End 选择并自动滚动；DataTable 的表头和行支持排序、稳定选择与集合位置语义。

语义注册表会记录最多四层滚动祖先，最终边界统一叠加各层滚动偏移并与每个裁剪视口求交，完全不可见的后代输出空边界。键盘焦点进入外层滚动区域下方的控件时，PrimaryCard 会自动滚动使焦点环可见；VirtualList 同时协调内层行滚动与外层容器显露。

手柄、电视遥控器和辅助输入设备通过平台层的 `NavigationCommand` 接入：`next`/`previous` 移动焦点，`activate` 激活控件，`decrement`/`increment` 调节 Slider，`up`/`down`/`left`/`right` 保留方向语义供 Tabs、TreeView 等复合控件使用，`first`/`last` 支持菜单等集合首尾跳转，`back` 复用 Escape/Android 返回逻辑。Android Activity 已显式把 DPAD、Tab、Move Home/End 和激活键送入该桥；IME 编辑视图持有焦点时仍由文本输入路径处理按键。

路线图第一批控件（Button、IconButton、Label、Checkbox/Switch、Slider、ScrollView/List、Dialog、Toast、NavigationBar、基础单行 TextField）以及补充的 TreeView 均已有可运行实现。TreeView 的展开掩码和选择项由 AppModel 持有，折叠节点会从布局、焦点顺序和语义树中移除。TextField 已支持 UTF-8 光标、鼠标/触摸定位与拖选、Shift 选择、全选、复制、剪切、粘贴、选区替换以及独立的 IME 组合态；Android APK 已通过自定义 `NativeActivity`、`InputConnection` 和 JNI 事件队列接入中文软键盘。权限请求与系统文件选择器也已通过同一异步平台桥接入，文件读取结果包含显示名称、MIME 类型、可选大小和内容预览；大文件可以按 4096 字节分块完整消费、取消并显示进度与增量摘要，所有结果统一回到 App reducer。

交互控件已接入循环键盘焦点顺序：`Tab`/`Shift+Tab` 前后移动，`Enter`/`Space` 激活当前按钮或选择控件，Slider 使用左右方向键按 `0.05` 调整，RadioGroup 使用四向键循环选择，Select 使用上下键选择并可展开进入选项，Tabs 使用横向左右键或纵向上下键自动切换，Menu 使用上下键及 Home/End 在可用项间导航，VirtualList 使用单一 Tab 停靠点和方向键/Home/End 选择并自动滚动，DataTable 使用表头与活动行停靠点完成列排序和稳定行导航；Dialog 打开时焦点顺序被限制在取消和确认按钮内。Button、IconButton、Checkbox、Switch、Slider、TextField、NavigationBar、TreeView、RadioGroup、Select、Tabs、Menu、VirtualList 和 DataTable 均通过统一 Theme 令牌显示焦点环。

所有 `src/ui/widgets` 控件的语义颜色、常用圆角和间距来自 `src/ui/theme.zig` 的共享令牌；Switch 等胶囊形状的半径由控件尺寸计算。
- Button 使用稳定 Clay ID 跟踪按压归属，只有在控件内按下并在控件内释放才触发点击。
- 控件不直接修改业务数据，而是写入 `ui.Frame.actions`，由主循环派发给 App reducer。
- 控件不直接调用平台无障碍 API，而是写入 `ui.Frame.semantic_nodes`，由平台桥按需映射到原生语义节点；Android 模态对话框打开时只暴露模态节点，Card 和 ScrollView 会按实际滚动位置暴露可用的系统翻页动作。
- 指针的 pressed/released 边沿保存在 AppModel 中，UI 构建后通过 `input_consumed` 清除，避免事件发生在两帧之间时丢失点击。

按钮示例：

```zig
if (button.draw(&state.button_state, input, .{
    .id = "PrimaryAction",
    .text = "点击测试",
})) emit(.primary_button_pressed);
```

## 核心约定

- `sokol-zig` 作为固定版本依赖使用，不修改上游源码。
- Clay 是正式产品 UI 的布局层；ImGui 仅作为未来可选的开发调试层。
- UI 发出 Action，由 AppModel/reducer 统一更新业务状态。
- Android、iOS 等系统 API 通过异步平台桥接层接入。
- Android 端已实现相机、麦克风、通知、媒体权限请求和 Storage Access Framework 文件选择；文件结果使用 `content://` URI，不假定存在真实文件路径。选中后会在后台自动读取最多 4096 字节预览，UTF-8 文本直接显示，二进制内容使用十六进制显示并标记截断；也可启动带背压和取消能力的完整分块读取。
- Noto Sans SC 使用 OFL-1.1 许可证，许可证随字体保存在 `assets/fonts`。

完整架构方案见 [docs/sokol-clay-app-plan.md](docs/sokol-clay-app-plan.md)。
