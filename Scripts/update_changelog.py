#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import pathlib
import re
import subprocess
import sys
import tempfile
from collections import OrderedDict
from dataclasses import dataclass


CATEGORY_TITLES = {
    "feature": "新增",
    "improvement": "优化",
    "fix": "修复",
}


TYPE_TO_CATEGORY = {
    "feat": "feature",
    "fix": "fix",
    "perf": "improvement",
    "refactor": "improvement",
    "build": "improvement",
    "ci": "improvement",
    "docs": "improvement",
    "style": "improvement",
    "test": "improvement",
    "chore": "improvement",
    "revert": "fix",
}


SCOPE_ALIASES = {
    "menubar": "menu-bar",
    "remote": "remote-machine",
}


IGNORED_SUBJECT_PREFIXES = (
    "merge ",
)


CONVENTIONAL_COMMIT_PATTERN = re.compile(
    r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]+)\))?(?P<breaking>!)?:\s*(?P<description>.+)$"
)


@dataclass
class CommitEntry:
    category: str
    scope: str | None
    description: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate or update CHANGELOG.md from git commits.")
    parser.add_argument("--version", required=True, help="Release version without leading v")
    parser.add_argument("--to-ref", default="HEAD", help="Ending git ref for the changelog range")
    parser.add_argument("--from-ref", default="", help="Starting git ref (exclusive) for the changelog range")
    parser.add_argument("--changelog", default="CHANGELOG.md", help="Path to CHANGELOG.md")
    parser.add_argument(
        "--mode",
        choices=["section", "body", "write"],
        default="section",
        help="Print full section, body only, or write back to CHANGELOG.md",
    )
    return parser.parse_args()


def run_git(*args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout


def build_revision_range(from_ref: str, to_ref: str) -> str:
    if from_ref:
        return f"{from_ref}..{to_ref}"
    return to_ref


def normalize_scope(scope: str | None) -> str | None:
    if scope is None:
        return None

    normalized = scope.strip().lower().replace("_", "-")
    if not normalized:
        return None
    return SCOPE_ALIASES.get(normalized, normalized)


def normalize_description(description: str) -> str:
    cleaned = re.sub(r"\s+", " ", description.strip())
    return cleaned.rstrip("。.;；")


def collect_commits(from_ref: str, to_ref: str) -> list[tuple[str, str, str]]:
    revision_range = build_revision_range(from_ref, to_ref)
    raw_log = run_git("log", "--reverse", "--format=%s%x1f%b%x1e", revision_range)
    commits: list[tuple[str, str, str]] = []

    for record in raw_log.strip("\x1e").split("\x1e"):
        if not record.strip():
            continue
        subject, body = (record.split("\x1f", maxsplit=1) + [""])[:2]
        normalized_subject = subject.strip()
        normalized_body = body.strip()
        lower_subject = normalized_subject.lower()
        if any(lower_subject.startswith(prefix) for prefix in IGNORED_SUBJECT_PREFIXES):
            continue
        commits.append((normalized_subject, normalized_body, lower_subject))

    return commits


def classify_commit(subject: str, body: str, lower_subject: str) -> CommitEntry:
    match = CONVENTIONAL_COMMIT_PATTERN.match(subject)

    if match:
        commit_type = match.group("type").lower()
        scope = normalize_scope(match.group("scope"))
        description = normalize_description(match.group("description"))
        breaking = bool(match.group("breaking")) or "BREAKING CHANGE" in body
        category = TYPE_TO_CATEGORY.get(commit_type, "improvement")
        if breaking:
            description = f"Breaking: {description}"
        return CommitEntry(category=category, scope=scope, description=description)

    fallback_category = "fix" if any(keyword in lower_subject for keyword in ("fix", "bug")) else "improvement"
    return CommitEntry(
        category=fallback_category,
        scope=None,
        description=normalize_description(subject),
    )


def group_entries(entries: list[CommitEntry]) -> OrderedDict[str, dict[str, list[str]]]:
    grouped: OrderedDict[str, dict[str, list[str]]] = OrderedDict()

    for entry in entries:
        scope_key = entry.scope or "other"
        if scope_key not in grouped:
            grouped[scope_key] = {
                "feature": [],
                "improvement": [],
                "fix": [],
            }
        grouped[scope_key][entry.category].append(entry.description)

    return grouped


def dedupe_items(items: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        result.append(item)
    return result


def format_scope_label(scope: str) -> str:
    if scope == "other":
        return "其他"
    return f"`{scope}`"


def format_descriptions(items: list[str]) -> str:
    return "；".join(dedupe_items(items))


def build_summary(entries: list[CommitEntry]) -> str:
    counts = {
        "feature": 0,
        "improvement": 0,
        "fix": 0,
    }
    scope_counts: OrderedDict[str, int] = OrderedDict()
    scope_order: dict[str, int] = {}

    for index, entry in enumerate(entries):
        counts[entry.category] += 1
        scope_key = entry.scope or "other"
        if scope_key not in scope_order:
            scope_order[scope_key] = index
        scope_counts[scope_key] = scope_counts.get(scope_key, 0) + 1

    ranked_scopes = [
        scope
        for scope, _ in sorted(
            scope_counts.items(),
            key=lambda item: (-item[1], scope_order[item[0]]),
        )
    ]
    display_scopes = [format_scope_label(scope) for scope in ranked_scopes if scope != "other"][:3]
    scope_text = "、".join(display_scopes) if display_scopes else "多个模块"

    if counts["feature"] and counts["improvement"] and counts["fix"]:
        result_text = "同时包含能力补齐、交互整理和稳定性修复。"
    elif counts["feature"] and counts["improvement"]:
        result_text = "主要补齐能力并整理交互体验。"
    elif counts["feature"] and counts["fix"]:
        result_text = "主要补齐功能并修复关键问题。"
    elif counts["improvement"] and counts["fix"]:
        result_text = "主要提升交互表现并修复稳定性问题。"
    elif counts["feature"]:
        result_text = "以新能力补齐为主。"
    elif counts["improvement"]:
        result_text = "主要是一次体验与交互整理。"
    else:
        result_text = "以稳定性修复为主。"

    return f"> 本次更新重点覆盖 {scope_text}，{result_text}"


def build_summary_prompt(version: str, entries: list[CommitEntry]) -> str:
    grouped_changes = render_grouped_changes(entries)
    stats = render_stats(entries)
    return (
        f"请为 CatBar v{version} 生成一句中文发布摘要。\n"
        "要求：\n"
        "1. 只输出一句话，不要标题，不要列表。\n"
        "2. 重点说明这次更新给用户带来的结果。\n"
        "3. 不要虚构未出现的能力，不要提及 Git commit、scope 或统计数字。\n"
        "4. 语气克制、简洁，适合放在 GitHub Release 顶部。\n"
        "5. 不要提及版本号，用「本次更新」作为主语开头。\n\n"
        f"{stats}\n\n{grouped_changes}\n"
    )


TOOL_LOG_PATTERN = re.compile(
    r"^\s*[●○◆◇▶▷→⟶⏵\-\*]\s+(?:Read|Write|Search|View|Execute|Open|Fetch|Load)\s+.+$"
    r"|^\s*[└├│─┌┐┘┤┬┴┼╠╣╔╗╚╝]\s*.*$"
    r"|^\s*L\d+:\d+\s*\(.*\)$",
    re.MULTILINE | re.IGNORECASE,
)


def _sanitize_summary_output(text: str) -> str:
    """Remove tool operation logs that leak into external command stdout."""
    cleaned = TOOL_LOG_PATTERN.sub("", text)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned.strip()


def build_summary_with_optional_command(version: str, entries: list[CommitEntry]) -> str:
    command_template = os.getenv("CHANGELOG_SUMMARY_COMMAND", "").strip()
    if not command_template:
        return build_summary(entries)

    prompt = build_summary_prompt(version, entries)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as prompt_file:
        prompt_file.write(prompt)
        prompt_path = prompt_file.name

    try:
        command = command_template.replace("{prompt_file}", prompt_path)
        completed = subprocess.run(
            ["/bin/sh", "-lc", command],
            capture_output=True,
            text=True,
        )
    finally:
        pathlib.Path(prompt_path).unlink(missing_ok=True)

    if completed.returncode != 0:
        print(
            f"Warning: summary command failed, falling back to local summary: {completed.stderr.strip()}",
            file=sys.stderr,
        )
        return build_summary(entries)

    summary = _sanitize_summary_output(completed.stdout)
    summary = re.sub(r"^```(?:markdown|md)?\s*", "", summary)
    summary = re.sub(r"\s*```$", "", summary).strip()
    if not summary:
        return build_summary(entries)

    summary = summary.lstrip("> ").strip()
    return f"> {summary}"


def render_stats(entries: list[CommitEntry]) -> str:
    counts = {
        "feature": 0,
        "improvement": 0,
        "fix": 0,
    }
    for entry in entries:
        counts[entry.category] += 1

    return "\n".join(
        [
            "### 变更统计",
            "",
            f"- 新增功能：{counts['feature']} 项",
            f"- 优化改进：{counts['improvement']} 项",
            f"- 问题修复：{counts['fix']} 项",
        ]
    )


def render_grouped_changes(entries: list[CommitEntry]) -> str:
    grouped = group_entries(entries)
    lines = ["### 按模块归纳", ""]

    if not grouped:
        lines.append("- 暂无独立条目。")
        return "\n".join(lines)

    for scope, categories in grouped.items():
        lines.append(f"- {format_scope_label(scope)}")
        for category in ("feature", "improvement", "fix"):
            descriptions = categories[category]
            if not descriptions:
                continue
            lines.append(f"  - {CATEGORY_TITLES[category]}：{format_descriptions(descriptions)}")

    return "\n".join(lines)


CATEGORY_EMOJI_HEADERS = {
    "feature": "### ✨ 新增功能",
    "improvement": "### 🚀 优化改进",
    "fix": "### 🐞 问题修复",
}


def render_by_category(entries: list[CommitEntry]) -> str:
    """Render entries grouped by category with emoji headers, omitting empty categories."""
    categories: dict[str, list[str]] = {
        "feature": [],
        "improvement": [],
        "fix": [],
    }

    for entry in entries:
        scope_prefix = f"**{entry.scope}**：" if entry.scope else ""
        categories[entry.category].append(f"- {scope_prefix}{entry.description}")

    lines: list[str] = []
    for cat in ("feature", "improvement", "fix"):
        items = dedupe_items(categories[cat])
        if not items:
            continue
        if lines:
            lines.append("")
        lines.append(CATEGORY_EMOJI_HEADERS[cat])
        lines.append("")
        lines.extend(items)

    return "\n".join(lines)


def render_section(version: str, entries: list[CommitEntry]) -> str:
    section_parts = [
        f"## v{version}",
        "",
        build_summary_with_optional_command(version, entries),
        "",
        render_by_category(entries),
    ]
    return "\n".join(section_parts).strip() + "\n"


def write_changelog(changelog_path: pathlib.Path, version: str, section: str) -> None:
    existing = changelog_path.read_text(encoding="utf-8") if changelog_path.exists() else ""
    pattern = re.compile(rf"^##\s+v?{re.escape(version)}\s*$\n(.*?)(?=^##\s+|\Z)", re.MULTILINE | re.DOTALL)

    if pattern.search(existing):
        updated = pattern.sub(section.rstrip() + "\n\n", existing, count=1)
    else:
        updated = section.rstrip() + "\n\n" + existing.lstrip()

    changelog_path.write_text(updated.rstrip() + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()

    commits = collect_commits(args.from_ref, args.to_ref)
    if not commits:
        print("No commits found for changelog generation.", file=sys.stderr)
        return 1

    entries = [classify_commit(subject, body, lower_subject) for subject, body, lower_subject in commits]
    section = render_section(args.version, entries)

    if args.mode == "section":
        sys.stdout.write(section)
        return 0

    if args.mode == "body":
        body = section.split("\n", maxsplit=1)[1]
        sys.stdout.write(body.lstrip())
        return 0

    changelog_path = pathlib.Path(args.changelog)
    write_changelog(changelog_path, args.version, section)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
