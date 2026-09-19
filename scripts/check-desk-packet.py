#!/usr/bin/env python3
"""Check a daily-desk packet for required sections and ship-day gates."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


REQUIRED_HEADINGS = (
    "Run",
    "Pulse",
    "Risk kills",
    "Survivors",
    "Captions",
    "Archive bar",
    "Choice",
    "Renders",
    "Outcome",
)
FIELD_RE = re.compile(r"^\|\s*([A-Za-z_]+)\s*\|\s*(.*?)\s*\|", re.MULTILINE)
SECTION_RE = re.compile(r"^## (.+?)\s*$", re.MULTILINE)
PNG_RE = re.compile(r"\S+\.png")


def usage_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate a daily-comic-desk packet. Does not judge joke quality."
    )
    parser.add_argument("--packet", required=True, help="Path to packet.md.")
    return parser


def fail(message: str) -> int:
    print(f"ERROR: {message}")
    return 1


def field(body: str, name: str) -> str | int:
    values = []
    for match in FIELD_RE.finditer(body):
        if match.group(1) == name:
            values.append(match.group(2).strip())
    unique = {item for item in values if item}
    if len(unique) > 1:
        return fail(f"conflicting {name} values: {', '.join(sorted(unique))}")
    return next(iter(unique), "")


def section(body: str, title: str) -> str:
    starts = list(SECTION_RE.finditer(body))
    for index, match in enumerate(starts):
        if match.group(1) != title:
            continue
        end = starts[index + 1].start() if index + 1 < len(starts) else len(body)
        return body[match.end() : end].strip()
    return ""


def heading_present(body: str, title: str) -> bool:
    return any(match.group(1) == title for match in SECTION_RE.finditer(body))


def main() -> int:
    args = usage_parser().parse_args()
    path = Path(args.packet)
    if path.is_symlink() or not path.is_file():
        return fail(f"packet must be a regular file: {path}")
    body = path.read_text(encoding="utf-8")
    missing = [title for title in REQUIRED_HEADINGS if not heading_present(body, title)]
    if missing:
        return fail(f"packet missing headings: {', '.join(missing)}")
    outcome = field(body, "outcome")
    if isinstance(outcome, int):
        return outcome
    if outcome not in {"pending", "kill", "ship"}:
        return fail("outcome must be pending, kill, or ship")
    if outcome == "pending":
        return 0
    if outcome == "kill":
        if not section(body, "Choice") and not section(body, "Outcome"):
            return fail("kill requires a reason in Choice or Outcome")
        return 0
    archive = field(body, "archive_bar")
    if isinstance(archive, int):
        return archive
    if archive not in {"pass", "override"}:
        return fail("ship requires archive_bar pass or override")
    if not section(body, "Archive bar"):
        return fail("ship requires archive comparison notes")
    if archive == "override" and "override" not in section(body, "Choice").lower():
        return fail("archive override must be recorded in Choice")
    caption = field(body, "caption_choice")
    if isinstance(caption, int):
        return caption
    if not caption or caption in {"pending", "-"}:
        return fail("ship requires a caption_choice")
    words = [part for part in re.split(r"\s+", caption) if part]
    if len(words) > 10:
        return fail(f"ship caption must be 10 words or fewer; got {len(words)}")
    drawing = field(body, "drawing_choice")
    if isinstance(drawing, int):
        return drawing
    if not drawing or drawing in {"pending", "-"}:
        return fail("ship requires a drawing_choice")
    slug = field(body, "promotion_slug")
    if isinstance(slug, int):
        return slug
    if not slug or slug in {"pending", "-"}:
        return fail("ship requires a promotion_slug")
    renders = PNG_RE.findall(section(body, "Renders"))
    if len(renders) < 2:
        return fail("ship requires two signed render paths")
    outcome_text = section(body, "Outcome").lower()
    if "validate-production" not in outcome_text and "validator" not in outcome_text:
        return fail("ship requires a validator result in Outcome")
    post_url = field(body, "post_url")
    if isinstance(post_url, int):
        return post_url
    is_url = post_url.startswith(("http://", "https://")) if post_url else False
    if not (is_url or post_url == "posted outside pipeline"):
        return fail("ship requires a post_url (an http(s) URL, or the literal 'posted outside pipeline')")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
