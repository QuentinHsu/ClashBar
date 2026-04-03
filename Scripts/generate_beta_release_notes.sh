#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <tag> <version> [output_path]" >&2
  exit 1
fi

tag="$1"
version="$2"
output_path="${3:-release.md}"
source_branch="${SOURCE_BRANCH:-beta}"

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

commit_sha="$(git rev-parse --short HEAD)"
commit_subject="$(git log -1 --pretty=%s)"
commit_date="$(git log -1 --date=iso-strict --pretty=%cd)"
repo_url="https://github.com/${GITHUB_REPOSITORY}"
download_base="${repo_url}/releases/download/${tag}"

cat >"$output_path" <<EOF
## Beta 预览

该构建由 GitHub Actions 在 \`${source_branch}\` 分支手动触发生成。

- 发布标签：\`${tag}\`
- 版本号：\`${version}\`
- 提交：\`${commit_sha}\` ${commit_subject}
- 提交时间：${commit_date}

### 📥 下载地址

- 当前 Beta 仅提供无内核安装包。
- 首次启动后，可在 CatBar 设置页打开内核目录并放入 \`mihomo\`。

| 平台架构 | 无内核安装包 |
| :--- | :--- |
| Apple Silicon (arm64) | [CatBar-${version}-apple-silicon-no-core.dmg](${download_base}/CatBar-${version}-apple-silicon-no-core.dmg) |
| Intel (x86_64) | [CatBar-${version}-intel-no-core.dmg](${download_base}/CatBar-${version}-intel-no-core.dmg) |
EOF
