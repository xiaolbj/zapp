# zapp

使用 Zig、sokol-zig 和 Clay 构建的跨平台自绘 App 基础项目。

当前数据流为：

```text
平台输入 -> AppModel -> Clay 布局/控件 -> UI Action -> AppModel
                              |
                              v
                 Clay RenderCommand -> Sokol
```

已接通 Rectangle、圆角、Border、Scissor、Image 和 Unicode Text 渲染；Image 支持 stretch/contain/cover、颜色 tint 与圆角纹理网格，内嵌 PNG/JPEG 由固定版本的 `stb_image` 在资源注册表初始化时解码一次，中文字体由 Fontstash、`sokol_fontstash.h` 与内嵌的 Noto Sans SC 提供。所有键盘可交互控件都会使用 Theme 焦点令牌生成 Clay Border 命令，渲染器负责绘制可见焦点环。

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
- `chip_group.zig`：受控多选筛选标签组，支持禁用项、方向键循环、Home/End 首尾定位和原生 ToggleButton 语义。
- `select.zig`：受控单选下拉框，支持展开/收起、动态选项焦点、键盘循环选择和原生 Spinner 语义。
- `tabs.zig`：受控标签页导航，支持横/纵布局、方向键自动切换、单一 Tab 停靠点和原生标签语义。
- `menu.zig`：受控操作菜单，支持禁用项、上下键循环、Home/End 首尾跳转、关闭后焦点恢复和原生菜单语义。
- `virtual_list.zig`：固定行高虚拟列表，千行数据只生成可见区与少量预取行，支持选择、方向键/Home/End、稳定行 ID 和原生列表项语义。
- `data_table.zig`：受控数据表格，支持稳定行身份、列排序、行选择、表头/行键盘导航和 Android CollectionInfo 集合语义。
- `pagination.zig`：受控分页栏，支持首页/末页、省略号页码窗口、边界禁用、键盘首尾导航和原生按钮语义。
- `accordion.zig`：受控折叠面板，支持单开/多开模式、调用方组合任意 Clay 内容、方向键导航和原生展开/折叠语义。
- `scroll_view.zig`：基于 Clay clip/scroll container 的垂直滚动容器。
- `card.zig`：统一页面卡片的内边距、间距、背景和圆角。
- `divider.zig`：用于内容分组的轻量分隔线。
- `slider.zig`：受控拖拽滑块，将指针位置映射为 `0...1` 数值。
- `number_stepper.zig`：受控整数步进器，支持可配置范围/步长、边界按钮禁用、方向键与 Home/End，以及原生 NumberPicker 语义。
- `dialog.zig`：带输入拦截遮罩、取消和确认操作的模态对话框。
- `navigation_bar.zig`：受控导航项选择，支持横向和纵向布局。
- `text_field.zig`：基础受控单行 UTF-8 输入框，支持字符、退格、提交和粘贴。
- `search_field.zig`：在 TextField 上组合可访问的清除操作，保持独立文本、光标、选区和 IME 组合态；示例实时筛选 DataTable，并同步修复分页、选中项与焦点顺序。
- `form_field.zig`：组合 Label、TextField 与 supporting text 的受控表单字段，支持必填标记、帮助文本、错误边框、验证消息和原生无障碍错误语义。
- `toast.zig`：不拦截输入、按时自动消失的全局提示层。
- `tree_view.zig`：受控层级树，支持展开/折叠、选择、动态焦点顺序、方向键树内导航、折叠后的焦点回收和树语义节点。
- `image_view.zig`：平台无关的图片资源引用，支持 stretch、contain、cover、tint、圆角与原生 ImageView 语义。
- `interaction.zig`：所有指针控件共享的按压捕获与点击判定状态机。

`src/ui/focus_manager.zig` 保存当前焦点、模态焦点和打开弹窗前的焦点。Dialog 关闭后会恢复之前的焦点；Escape 和 Android 返回键统一转成 `back_requested` Action。

应用壳已具备受控三页路由：首页保留完整控件与平台桥示例，活动页展示独立开发事件流，设置页组合 Accordion、Checkbox、Switch 和 RadioGroup。当前页仍由 AppModel/reducer 管理；换页会关闭页面级 Dialog、Select、Menu 与 IME 编辑状态，焦点迁移到新页面对应的导航项，已卸载页面的布局和语义节点不会残留。设置值离开页面后仍由 AppModel 保留。

`src/ui/semantics.zig` 提供平台无关的帧级语义注册表。交互控件以及 Label、ProgressBar、Toast、Card、ScrollView/List、VirtualList、DataTable、Pagination、TreeView、Accordion、RadioGroup、ChipGroup、NumberStepper、Select、Tabs、Menu、FormField 会随 `ui.Frame.semantic_nodes` 输出稳定元素 ID、角色、标签、值与 min/max/step 范围、最终布局边界以及 focused/disabled/selected/checked/modal/expanded/required/invalid、错误文本、层级和行列位置等状态；Divider 被明确视为装饰元素，不进入语义树。Android 已通过 `AccessibilityNodeProvider` 将这些数据映射成原生虚拟节点，并把点击、增减、文本设置和展开/折叠动作送回现有 App Action/reducer。TreeView 获得焦点后可用上/下键移动到相邻可见节点、右键展开或进入首个子节点、左键折叠或返回父节点；Accordion 使用上/下/Home/End 在标题间移动、右键展开、左键收起，收起内容不进入布局与语义树；RadioGroup 使用方向键循环移动并选择互斥项；ChipGroup 使用方向键循环且跳过禁用项，以 Enter/Space 独立切换多个筛选值；NumberStepper 使用方向键按步长增减并以 Home/End 跳到边界；Select 关闭时方向键直接选择，展开时选项加入焦点和语义树；Tabs 使用与布局方向一致的方向键自动切换活动页；Menu 打开后用上下键或 Home/End 在可用项间导航；VirtualList 使用方向键/Home/End 选择并自动滚动；DataTable 的表头和行支持排序、稳定选择与集合位置语义；Pagination 使用原生按钮语义暴露当前页和禁用边界。

Clay 滚动容器把 `Clay_GetScrollOffset()` 作为 clip 的 `childOffset` 应用到视觉布局；语义注册表直接读取 Clay 已计算完偏移的最终元素边界，再与最多四层祖先裁剪视口逐层求交，完全不可见的后代输出空边界。这样渲染、命中测试和 Android 虚拟节点保持同一坐标系。键盘焦点进入外层滚动区域下方的控件时，PrimaryCard 会自动滚动使焦点环可见；VirtualList 同时协调内层行滚动与外层容器显露，FormField 验证失败时还会把错误 supporting text 一并显露。

手柄、电视遥控器和辅助输入设备通过平台层的 `NavigationCommand` 接入：`next`/`previous` 移动焦点，`activate` 激活控件，`decrement`/`increment` 调节 Slider，`up`/`down`/`left`/`right` 保留方向语义供 Tabs、TreeView 等复合控件使用，`first`/`last` 支持菜单等集合首尾跳转，`back` 复用 Escape/Android 返回逻辑。Android Activity 已显式把 DPAD、Tab、Move Home/End 和激活键送入该桥；IME 编辑视图持有焦点时仍由文本输入路径处理按键。

路线图第一批控件（Button、IconButton、Label、Checkbox/Switch、Slider、ScrollView/List、Dialog、Toast、NavigationBar、基础单行 TextField）以及补充的 TreeView、FormField 和 ImageView 均已有可运行实现。图片控件只携带稳定资源 ID、固有尺寸和 fit 策略；Catalog 保存内嵌资源，Registry 统一创建、解析和销毁 GPU Image/View 及共享 Sampler。运行时图片复用平台的 4096 字节有序分块流，在主线程以 16 MiB 编码上限组装后执行受限 PNG/JPEG 解码；缓存提供 4 个动态 GPU 槽，设置页可把实际预算配置为 1–4 槽，使用 SHA-256 内容键与 LRU 淘汰，相同内容直接命中且不重复解码上传。Android 通过专用异步网络线程读取 HTTPS PNG/JPEG；Windows、Linux 和 macOS 则共用 Zig `std.http.Client` 后台 transport。两条路径都强制 HTTPS、校验 2xx 状态与 MIME、限制 16 MiB，并通过同一有序分块协议回到主线程，因此文件图片与远程图片共享解码器和 GPU Registry。桌面实现允许最多 5 次重定向，并在最终响应处再次拒绝非 HTTPS 地址；取消不会阻塞渲染线程。缩减预算会立即按 LRU 释放超额槽，若当前预览仍在幸存集合中则继续显示。未命中时，新 Image/View 全部创建成功后才提交索引并替换 victim，失败时保留上一张有效纹理。用户可显式清空全部动态图片槽；Android 的 `onTrimMemory`/`onLowMemory` 也会把内存压力排入平台事件队列，并在渲染主线程安全释放动态 GPU 资源，内嵌图片与共享 Sampler 不受影响。业务 UI 不依赖 Sokol 类型，普通渲染帧不进行图片文件 I/O、解码或堆分配。TreeView 的展开掩码和选择项由 AppModel 持有，折叠节点会从布局、焦点顺序和语义树中移除。TextField 已支持 UTF-8 光标、鼠标/触摸定位与拖选、Shift 选择、全选、复制、剪切、粘贴、选区替换以及独立的 IME 组合态；FormField 在其上组合标签、帮助/错误文本和受控验证状态。Android APK 已通过自定义 `NativeActivity`、`InputConnection` 和 JNI 事件队列接入中文软键盘。权限请求与系统文件选择器也已通过同一异步平台桥接入，文件读取结果包含显示名称、MIME 类型、可选大小和内容预览；大文件可以按 4096 字节分块完整消费、取消并显示进度与增量摘要，所有结果统一回到 App reducer。

交互控件已接入循环键盘焦点顺序：`Tab`/`Shift+Tab` 前后移动，`Enter`/`Space` 激活当前按钮或选择控件，Slider 使用左右方向键按 `0.05` 调整，NumberStepper 使用四向键增减和 Home/End 边界跳转，RadioGroup 使用四向键循环选择，ChipGroup 使用四向键/Home/End 移动并以 Enter/Space 切换，Select 使用上下键选择并可展开进入选项，Tabs 使用横向左右键或纵向上下键自动切换，Menu 使用上下键及 Home/End 在可用项间导航，VirtualList 使用单一 Tab 停靠点和方向键/Home/End 选择并自动滚动，DataTable 使用表头与活动行停靠点完成列排序和稳定行导航，Pagination 使用左右/Home/End 切页并在边界移除不可用停靠点，Accordion 使用上/下/Home/End 在标题间移动并以左右键展开或收起；Dialog 打开时焦点顺序被限制在取消和确认按钮内。Button、IconButton、Checkbox、Switch、Slider、NumberStepper、TextField、NavigationBar、TreeView、Accordion、RadioGroup、ChipGroup、Select、Tabs、Menu、VirtualList、DataTable 和 Pagination 均通过统一 Theme 令牌显示焦点环。

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

滚动容器的渲染裁切使用显式 scissor 栈：嵌套裁切先与父区域求交，结束时恢复父区域。由于当前 Clay 版本在可见性剔除时可能保留屏幕外 clip 的结束命令却省略开始命令，项目关闭 Clay 的命令级剔除以保持裁切对完整，并在渲染器中按当前有效裁切区域跳过完全不可见的几何、文字和图片；长列表仍由 VirtualList 控制可见行数量。所有内容超出视口的 Card、ScrollView 和页面容器都会显示可拖拽纵向滚动条；轨道点击可跳转，滑块位置与 Clay 的 `0…-maxScroll` 精确双向映射，因此即使手势落在嵌套 VirtualList 上，也可以通过外层滚动条直接到达页面首尾。

## 核心约定

- `sokol-zig` 作为固定版本依赖使用，不修改上游源码。
- Clay 是正式产品 UI 的布局层；ImGui 仅作为未来可选的开发调试层。
- UI 发出 Action，由 AppModel/reducer 统一更新业务状态。
- Android、iOS 等系统 API 通过异步平台桥接层接入。
- Android 端已实现相机、麦克风、通知、媒体权限请求和 Storage Access Framework 文件选择；文件结果使用 `content://` URI，不假定存在真实文件路径。选中后会在后台自动读取最多 4096 字节预览，UTF-8 文本直接显示，二进制内容使用十六进制显示并标记截断；也可启动带背压和取消能力的完整分块读取，或把受限 PNG/JPEG 动态上传到 Sokol 图片 Registry。动态图片缓存支持用户主动释放，并在 `RUNNING_LOW`、`RUNNING_CRITICAL` 以及后台级别的 Android 内存压力下自动释放；`UI_HIDDEN` 单独发生时保留缓存。
- Noto Sans SC 使用 OFL-1.1 许可证，许可证随字体保存在 `assets/fonts`。
- PNG/JPEG 解码使用固定到提交 `2c980bb59875b0d32144a71867fbdebb2f77cd20` 的 `stb_image`；来源、文件哈希和许可证保存在 `third_party/stb`。

完整架构方案见 [docs/sokol-clay-app-plan.md](docs/sokol-clay-app-plan.md)。
