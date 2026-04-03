# Developer Guide

面向本仓库维护者的发布与更新说明。

## 应用内更新

项目支持基于 Sparkle 的应用内更新，更新源来自 GitHub Releases。

- 稳定版发布工作流会为每个架构生成独立的 `appcast-*.xml`，并作为 release asset 一起上传。
- 安装包只有在构建时注入 `SPARKLE_PUBLIC_ED_KEY` 后才会启用应用内更新；未配置时会自动回退到 GitHub Releases 页面。

要让自动更新真正生效，需要在 GitHub Actions 中配置以下值：

- `vars.SPARKLE_PUBLIC_ED_KEY`
- `secrets.SPARKLE_PRIVATE_ED_KEY`

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