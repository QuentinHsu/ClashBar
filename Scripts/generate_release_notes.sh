#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <tag> <version> [output_path]" >&2
  exit 1
fi

tag="$1"
version="$2"
output_path="${3:-release.md}"
changelog_path="CHANGELOG.md"

if [[ ! -f "$changelog_path" ]]; then
  echo "Missing $changelog_path" >&2
  exit 1
fi

changelog_section="$(
  python3 - "$changelog_path" "$version" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text(encoding="utf-8")
pattern = re.compile(
    rf"^##\s+v?{re.escape(version)}\s*$\n(.*?)(?=^##\s+|\Z)",
    re.MULTILINE | re.DOTALL,
)
match = pattern.search(text)
if not match:
    sys.exit(1)
section = match.group(1).strip()
sys.stdout.write(section)
PY
)" || {
  previous_tag="$(
    git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname \
      | grep -Fxv "$tag" \
      | head -n 1 || true
  )"

  python3 Scripts/update_changelog.py \
    --version "$version" \
    --from-ref "$previous_tag" \
    --to-ref "$tag" \
    --mode body
}

repo_url="https://github.com/${GITHUB_REPOSITORY}"
download_base="${repo_url}/releases/download/${tag}"

cat >"$output_path" <<EOF
## 更新内容

${changelog_section}

### 📥 下载地址

- 当前发布仅提供无内核安装包。
- 首次启动后，可在 CatBar 设置页打开内核目录并放入 \`mihomo\`。

| 平台架构 | 无内核安装包 |
| :--- | :--- |
| Apple Silicon (arm64) | [CatBar-${version}-apple-silicon-no-core.dmg](${download_base}/CatBar-${version}-apple-silicon-no-core.dmg) |
| Intel (x86_64) | [CatBar-${version}-intel-no-core.dmg](${download_base}/CatBar-${version}-intel-no-core.dmg) |

EOF
