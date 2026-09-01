# zapp

使用 Zig、sokol-zig 和 Clay 构建的跨平台自绘 App。

当前阶段已完成项目骨架、Clay 初始化和首个响应式页面。页面通过
`AppModel → Clay RenderCommand → Sokol` 数据流绘制。Rectangle、Scissor 和
Unicode Text 已接通；中文字体由 Fontstash、`sokol_fontstash` 和内嵌的 Noto Sans SC 提供。

## 开发命令

```powershell
zig build check
zig build run
zig build test
```

## 核心约定

- `sokol-zig` 作为依赖使用，不修改上游源码。
- Fontstash 与提供 `sokol_fontstash.h` 的 Sokol 官方源码分别固定到具体提交。
- Noto Sans SC 使用 OFL-1.1 许可，许可证随字体保存在 `assets/fonts`。
- Clay 是正式产品 UI 的布局层。
- ImGui 只作为未来可选的开发调试层。
- UI 发出 Action，由 AppModel 统一更新业务状态。
- Android/iOS 等系统 API 通过异步平台桥接层接入。

完整方案见 [docs/sokol-clay-app-plan.md](docs/sokol-clay-app-plan.md)。
