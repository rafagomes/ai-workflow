#!/usr/bin/env python3
"""Offline check of relative links and anchors in the repository's Markdown.

External URLs are not checked (they are flaky and need the network). Run from
anywhere: python3 tests/check_links.py [file.md ...]. Without arguments it
checks every tracked *.md file.
"""
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
FENCE = re.compile(r"^\s*(```|~~~)")
MD_LINK = re.compile(r"(?<!\!)\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)|!\[[^\]]*\]\(\s*<?([^)\s>]+)")
HTML_LINK = re.compile(r"""(?:href|src)=["']([^"']+)["']""")
HEADING = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$")
HTML_ID = re.compile(r"""(?:id|name)=["']([^"']+)["']""")


def slug(text: str) -> str:
    """GitHub's heading anchor: lowercase, drop punctuation, spaces to hyphens."""
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = text.replace("`", "").lower()
    text = re.sub(r"[^\w\- ]", "", text, flags=re.UNICODE)
    return text.replace(" ", "-")


def strip_fences(text: str) -> list[str]:
    out, in_fence = [], False
    for line in text.splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            out.append("")
        else:
            out.append("" if in_fence else line)
    return out


_anchor_cache: dict[Path, set[str]] = {}


def anchors(path: Path) -> set[str]:
    if path not in _anchor_cache:
        found: set[str] = set()
        seen: dict[str, int] = {}
        lines = strip_fences(path.read_text(encoding="utf-8"))
        for line in lines:
            m = HEADING.match(line)
            if m:
                base = slug(m.group(1))
                n = seen.get(base, 0)
                seen[base] = n + 1
                found.add(base if n == 0 else f"{base}-{n}")
            found.update(HTML_ID.findall(line))
        _anchor_cache[path] = found
    return _anchor_cache[path]


def check_file(md: Path) -> list[str]:
    errors = []
    for lineno, line in enumerate(strip_fences(md.read_text(encoding="utf-8")), 1):
        line = re.sub(r"`[^`]*`", "", line)  # inline code is not a link
        targets = [a or b for a, b in MD_LINK.findall(line)] + HTML_LINK.findall(line)
        for target in targets:
            if re.match(r"^[a-zA-Z][a-zA-Z0-9+.\-]*:", target) or target.startswith("//"):
                continue  # external or mailto: not checked
            path_part, _, frag = target.partition("#")
            dest = (md.parent / unquote(path_part)).resolve() if path_part else md
            where = f"{md.relative_to(ROOT)}:{lineno}: {target}"
            if not dest.exists():
                errors.append(f"{where} (no such file)")
            elif frag and dest.suffix.lower() == ".md" and unquote(frag).lower() not in {
                a.lower() for a in anchors(dest)
            }:
                errors.append(f"{where} (no such anchor)")
    return errors


def main() -> int:
    if len(sys.argv) > 1:
        files = [Path(a).resolve() for a in sys.argv[1:]]
    else:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "*.md"],
            check=True, capture_output=True, text=True,
        ).stdout.split()
        files = [ROOT / f for f in out]
    errors = [e for f in files for e in check_file(f)]
    for e in errors:
        print(e, file=sys.stderr)
    print(f"check_links: {len(files)} files, {len(errors)} broken")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
