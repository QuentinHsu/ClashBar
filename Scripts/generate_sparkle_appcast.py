#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a single-item Sparkle appcast for a DMG asset.")
    parser.add_argument("--dmg", required=True, help="Path to the DMG asset")
    parser.add_argument("--sign-update-tool", required=True, help="Path to Sparkle's sign_update tool")
    parser.add_argument("--private-key-file", help="Path to the Sparkle private EdDSA key file")
    parser.add_argument("--private-key-stdin", help="Sparkle private EdDSA key content passed via standard input")
    parser.add_argument("--download-url", required=True, help="Release asset download URL")
    parser.add_argument("--release-notes-url", required=True, help="Release notes URL")
    parser.add_argument("--version", required=True, help="CFBundleShortVersionString value")
    parser.add_argument("--build-version", required=True, help="CFBundleVersion value")
    parser.add_argument("--minimum-system-version", required=True, help="Minimum macOS version")
    parser.add_argument("--title", required=True, help="Appcast item title")
    parser.add_argument("--output", required=True, help="Output appcast XML path")
    return parser.parse_args()


def sign_update(
    sign_update_tool: str,
    private_key_file: str | None,
    private_key_stdin: str | None,
    dmg_path: pathlib.Path,
) -> str:
    if bool(private_key_file) == bool(private_key_stdin):
        raise ValueError("Provide exactly one of --private-key-file or --private-key-stdin")

    ed_key_file = private_key_file if private_key_file else "-"
    command = [sign_update_tool, "--ed-key-file", ed_key_file, str(dmg_path)]
    completed = subprocess.run(
        command,
        input=private_key_stdin,
        capture_output=True,
        text=True,
        check=False,
    )
    output = "\n".join(part for part in [completed.stdout.strip(), completed.stderr.strip()] if part)
    if completed.returncode != 0:
        raise RuntimeError(f"sign_update failed with exit code {completed.returncode}:\n{output}")
    return output


def parse_signature(command_output: str) -> str:
    match = re.search(r'sparkle:edSignature="([^"]+)"', command_output)
    if not match:
        raise ValueError(f"Unable to find sparkle:edSignature in sign_update output:\n{command_output}")
    return match.group(1)


def indent_xml(element: ET.Element, level: int = 0) -> None:
    indent = "\n" + ("  " * level)
    if len(element):
        if not element.text or not element.text.strip():
            element.text = indent + "  "
        for child in element:
            indent_xml(child, level + 1)
        if not element[-1].tail or not element[-1].tail.strip():
            element[-1].tail = indent
    elif level and (not element.tail or not element.tail.strip()):
        element.tail = indent


def main() -> int:
    args = parse_args()

    dmg_path = pathlib.Path(args.dmg)
    if not dmg_path.is_file():
        raise FileNotFoundError(f"DMG not found: {dmg_path}")

    signature_output = sign_update(
        args.sign_update_tool,
        args.private_key_file,
        args.private_key_stdin,
        dmg_path,
    )
    ed_signature = parse_signature(signature_output)
    enclosure_length = str(dmg_path.stat().st_size)
    pub_date = dt.datetime.now(dt.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S %z")

    ET.register_namespace("sparkle", "http://www.andymatuschak.org/xml-namespaces/sparkle")
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = args.title
    ET.SubElement(channel, "link").text = args.release_notes_url
    ET.SubElement(channel, "description").text = f"CatBar {args.version} updates"
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = args.title
    ET.SubElement(item, "pubDate").text = pub_date
    ET.SubElement(
        item,
        "{http://www.andymatuschak.org/xml-namespaces/sparkle}releaseNotesLink",
    ).text = args.release_notes_url
    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", args.download_url)
    enclosure.set("type", "application/octet-stream")
    enclosure.set("length", enclosure_length)
    enclosure.set(
        "{http://www.andymatuschak.org/xml-namespaces/sparkle}version",
        args.build_version,
    )
    enclosure.set(
        "{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString",
        args.version,
    )
    enclosure.set(
        "{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature",
        ed_signature,
    )
    enclosure.set(
        "{http://www.andymatuschak.org/xml-namespaces/sparkle}minimumSystemVersion",
        args.minimum_system_version,
    )

    indent_xml(rss)
    output_path = pathlib.Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    xml_body = ET.tostring(rss, encoding="unicode")
    output_path.write_text('<?xml version="1.0" encoding="utf-8"?>\n' + xml_body + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - command-line failure path
        print(str(exc), file=sys.stderr)
        raise
