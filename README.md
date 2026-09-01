# zapp

使用 Zig、sokol-zig 和 Clay 构建的跨平台自绘 App 基础项目。

当前数据流为：

```text
平台输入 -> AppModel -> Clay 布局/控件 -> UI Action -> AppModel
                              |
                              v
                 Clay RenderCommand -> Sokol
```

已接通 Rectangle、圆角、Scissor 和 Unicode Text 渲染；中文字体由 Fontstash、`sokol_fontstash.h` 与内嵌的 Noto Sans SC 提供。

## 开发命令

```powershell
zig build check
zig build test
zig build run
```

## UI 控件

第一批可复用控件位于 `src/ui/widgets`：

- `label.zig`：统一封装 Clay 文本样式。
- `button.zig`：支持 normal、hover、pressed、disabled 状态。
- `checkbox.zig`：受控勾选框，状态由 AppModel 持有。
- `switch.zig`：受控开关，支持启用、关闭和禁用样式。
- `icon_button.zig`：适合工具栏和紧凑操作的圆形图标按钮。
- `progress_bar.zig`：受控进度显示，自动将数值约束到 `0...1`。
- `scroll_view.zig`：基于 Clay clip/scroll container 的垂直滚动容器。
- `card.zig`：统一页面卡片的内边距、间距、背景和圆角。
- `divider.zig`：用于内容分组的轻量分隔线。
- `slider.zig`：受控拖拽滑块，将指针位置映射为 `0...1` 数值。
- `dialog.zig`：带输入拦截遮罩、取消和确认操作的模态对话框。
- `navigation_bar.zig`：受控导航项选择，支持横向和纵向布局。
- `text_field.zig`：基础受控单行 UTF-8 输入框，支持字符、退格、提交和粘贴。
- `toast.zig`：不拦截输入、按时自动消失的全局提示层。
- `interaction.zig`：所有指针控件共享的按压捕获与点击判定状态机。

`src/ui/focus_manager.zig` 保存当前焦点、模态焦点和打开弹窗前的焦点。Dialog 关闭后会恢复之前的焦点；Escape 和 Android 返回键统一转成 `back_requested` Action。

路线图第一批控件（Button、IconButton、Label、Checkbox/Switch、Slider、ScrollView/List、Dialog、Toast、NavigationBar、基础单行 TextField）均已有可运行实现。TextField 当前是基础版本，后续仍需补光标定位、选择、复制/剪切和 Android IME 组合文本。

交互控件已接入循环键盘焦点顺序：`Tab`/`Shift+Tab` 前后移动，`Enter`/`Space` 激活当前按钮或选择控件，Slider 使用左右方向键按 `0.05` 调整；Dialog 打开时焦点顺序被限制在取消和确认按钮内。
- Button 使用稳定 Clay ID 跟踪按压归属，只有在控件内按下并在控件内释放才触发点击。
- 控件不直接修改业务数据，而是写入 `ui.Frame.actions`，由主循环派发给 App reducer。
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
- Noto Sans SC 使用 OFL-1.1 许可证，许可证随字体保存在 `assets/fonts`。

完整架构方案见 [docs/sokol-clay-app-plan.md](docs/sokol-clay-app-plan.md)。
