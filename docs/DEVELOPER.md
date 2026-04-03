# Developer Guide

面向本仓库维护者的发布与更新说明。

## 应用内更新

项目支持基于 Sparkle 的应用内更新，更新源来自 GitHub Releases。

- 稳定版发布工作流会为每个架构生成独立的 `appcast-*.xml`，并作为 release asset 一起上传。
- 安装包只有在构建时注入 `SPARKLE_PUBLIC_ED_KEY` 后才会启用应用内更新；未配置时会自动回退到 GitHub Releases 页面。

要让自动更新真正生效，需要在 GitHub Actions 中配置以下值：

- `vars.SPARKLE_PUBLIC_ED_KEY`
- `secrets.SPARKLE_PRIVATE_ED_KEY`

## 图片资源与内存

菜单栏应用对常驻内存很敏感，静态图片也可能显著放大 footprint。原因通常不是磁盘文件太大，而是图片在运行时会被解码成位图并被 AppKit / CoreGraphics 缓存。

- 不要直接把大图原尺寸加载到小 UI 上。例如 `2048x2048` 的 PNG 即使文件只有几百 KB，解码后单份 RGBA 位图也可能接近 `16MB`。
- 所有用于状态栏、菜单头图、徽标、按钮图标的位图，都应按实际显示尺寸下采样后再加载，避免直接使用 `NSImage(contentsOf:)` 读取原图。
- 状态栏图标、按钮图标建议读入尺寸不超过 `72px`。
- 面板头图建议读入尺寸不超过 `128px`。
- 只有真正需要导出、分享、拖拽或全尺寸预览时，才允许保留原始大图。
- 同一资源如果会出现在多个尺寸场景，应该为每个场景提供单独的加载入口，而不是共享一份大图对象。
- 新增图片资源时，优先检查像素尺寸，而不只看文件大小。

当前仓库的品牌图标加载实现可参考 `Sources/CatBar/Shared/UI/Components/BrandIcon.swift`。该实现使用 `CGImageSourceCreateThumbnailAtIndex` 按用途下采样，避免了大图解码造成的常驻内存放大。

如果怀疑图片导致内存上涨，优先排查：

- `vmmap -summary <pid>` 里的 `CG image`、`CG raster data`
- 是否把大 PNG 直接喂给了 `NSImage(contentsOf:)`
- 是否同一张图被多个 `NSImage` / `NSBitmapImageRep` / 模板渲染流程重复缓存
- 是否为 `1x/2x/3x` 或多个展示位置生成了多份 representation

## 正式版发布

正式版默认通过 GitHub Actions 里的 `Release DMG` 工作流发布，推荐直接使用 `workflow_dispatch` 的 `auto` bump 模式。

- 发布产物仅提供 `no-core` 安装包。
- 首次启动后，可在设置页打开 `~/Library/Application Support/catbar/core/`，并放入 `mihomo`。
- 版本号 `X.Y.Z` 会基于上一个稳定 tag 和最近提交的 Conventional Commits 自动计算。
- `CHANGELOG.md` 会在发布前根据上一个稳定 tag 之后的 commit 自动生成对应版本段落：默认按 scope 聚合、输出简洁统计与摘要，并先提交回当前分支。
- 如需启用 GitHub Copilot 摘要，请在仓库 Secrets 中配置 `COPILOT_GITHUB_TOKEN`。该 token 需要包含 GitHub Copilot 的 `Copilot Requests` 权限；工作流检测到该 secret 后会自动安装 Copilot CLI，并通过 `CHANGELOG_SUMMARY_COMMAND` 为发布摘要生成一句面向用户结果的总结。
- 如果未来要接入其他 AI 提供方，也可以在工作流里自定义 `CHANGELOG_SUMMARY_COMMAND`；脚本会将提示词写入临时文件，并把 `{prompt_file}` 替换为该文件路径后执行。
- `.app` 中的 `CFBundleShortVersionString` 使用语义化版本号，例如 `0.3.0`。
- `.app` 中的 `CFBundleVersion` 使用 GitHub Actions 的 `run number`，便于区分同一版本下的不同构建。
