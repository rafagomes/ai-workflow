#!/usr/bin/env python3
"""Offline check of the Codex packaging: manifests, marketplace, skills, openai.yaml.

Standard library only. Run from anywhere: python3 -I tests/check_codex.py [root].
The optional root (default: the repository) lets the self-test point it at a
broken copy.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
errors = []


def err(msg):
    errors.append(msg)


def load_json(path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        err(f"{path.relative_to(ROOT)}: not valid JSON ({e})")
        return None
    if not isinstance(data, dict):
        err(f"{path.relative_to(ROOT)}: top level must be an object")
        return None
    return data


def need(data, keys, where):
    for k in keys:
        if not isinstance(data.get(k), str) or not data[k].strip():
            err(f"{where}: missing or empty string field '{k}'")


def inside(root, rel):
    """Resolve a ./-prefixed path under root; None when it is not one or escapes root."""
    if not rel.startswith("./"):
        return None
    p = (root / rel).resolve()
    return p if p == root or root in p.parents else None


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\r?\n(.*?)\r?\n---\r?\n", text, re.DOTALL)
    if not m:
        return None
    fields = {}
    for line in m.group(1).splitlines():
        km = re.match(r"([A-Za-z][\w-]*):\s*(.*)$", line)
        if km:
            fields[km.group(1)] = km.group(2).strip()
    return fields


def parse_yaml(text):
    """The small YAML subset openai.yaml uses: nested mappings, scalars, comments.

    Raises ValueError on anything else (tabs, lists, odd indentation, no colon).
    """
    root = {}
    stack = [(-1, root)]
    for n, raw in enumerate(text.splitlines(), 1):
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if "\t" in raw[: len(raw) - len(raw.lstrip())]:
            raise ValueError(f"line {n}: tab indentation")
        indent = len(raw) - len(raw.lstrip(" "))
        m = re.match(r"([A-Za-z_][\w-]*):(?:\s+(.*))?$", raw.strip())
        if not m:
            raise ValueError(f"line {n}: not a 'key: value' line")
        while stack[-1][0] >= indent:
            stack.pop()
        parent = stack[-1][1]
        key, val = m.group(1), m.group(2)
        if val is None or val == "":
            child = {}
            parent[key] = child
            stack.append((indent, child))
        else:
            val = val.strip()
            if val[0] in "\"'":
                if len(val) < 2 or val[-1] != val[0]:
                    raise ValueError(f"line {n}: unterminated quoted string")
                val = val[1:-1]
            else:
                val = re.sub(r"\s+#.*$", "", val)
            if val in ("true", "false"):
                val = val == "true"
            parent[key] = val
    return root


def main():
    # 1. The compatibility manifest.
    mpath = ROOT / ".codex-plugin" / "plugin.json"
    manifest = load_json(mpath) if mpath.is_file() else err(".codex-plugin/plugin.json: missing")
    if manifest:
        need(manifest, ["name", "description", "license"], ".codex-plugin/plugin.json")
        if "version" in manifest:
            err(".codex-plugin/plugin.json: must not set 'version' (the version lives in CHANGELOG.md)")
        for field in ("skills", "hooks"):
            rel = manifest.get(field)
            if rel is None:
                continue
            target = inside(ROOT, rel) if isinstance(rel, str) else None
            if target is None or not target.exists():
                err(f".codex-plugin/plugin.json: '{field}' must be a ./-prefixed path to something that exists inside the plugin")
        # The hook command must resolve a path Codex sets.
        hooks = ROOT / "hooks" / "hooks.json"
        if hooks.is_file():
            hdata = load_json(hooks)
            if hdata and "CLAUDE_PLUGIN_ROOT" not in json.dumps(hdata):
                err("hooks/hooks.json: commands must use ${CLAUDE_PLUGIN_ROOT} (Codex sets it for plugin hooks)")

    # 2. The marketplace.
    kpath = ROOT / ".agents" / "plugins" / "marketplace.json"
    market = load_json(kpath) if kpath.is_file() else err(".agents/plugins/marketplace.json: missing")
    if market:
        need(market, ["name"], ".agents/plugins/marketplace.json")
        plugins = market.get("plugins")
        if not isinstance(plugins, list) or not plugins:
            err(".agents/plugins/marketplace.json: 'plugins' must be a non-empty array")
            plugins = []
        for i, p in enumerate(plugins):
            where = f".agents/plugins/marketplace.json plugins[{i}]"
            if not isinstance(p, dict):
                err(f"{where}: must be an object")
                continue
            need(p, ["name", "category"], where)
            src = p.get("source")
            path = src.get("path") if isinstance(src, dict) else src
            if isinstance(src, dict) and src.get("source") != "local":
                err(f"{where}: source.source must be 'local'")
            target = inside(ROOT, path) if isinstance(path, str) else None
            if target is None or not target.is_dir():
                err(f"{where}: source path must be a ./-prefixed directory inside the marketplace root")
            elif not (target / ".codex-plugin" / "plugin.json").is_file() and not (target / "plugin.json").is_file():
                err(f"{where}: the source directory has no plugin manifest")
            else:
                pm = target / ".codex-plugin" / "plugin.json"
                if pm.is_file():
                    d = load_json(pm)
                    if d and d.get("name") != p.get("name"):
                        err(f"{where}: name '{p.get('name')}' differs from the manifest name '{d.get('name')}'")
            pol = p.get("policy")
            if not isinstance(pol, dict) or not pol.get("installation") or not pol.get("authentication"):
                err(f"{where}: policy needs 'installation' and 'authentication'")

    # 3. Every skill has name and description frontmatter; name matches its folder.
    skills = sorted((ROOT / "skills").glob("*/SKILL.md"))
    if not skills:
        err("skills/: no SKILL.md found")
    for s in skills:
        where = str(s.relative_to(ROOT))
        fm = frontmatter(s)
        if fm is None:
            err(f"{where}: no frontmatter")
            continue
        for k in ("name", "description"):
            if not fm.get(k):
                err(f"{where}: frontmatter lacks '{k}'")
        if fm.get("name") and fm["name"] != s.parent.name:
            err(f"{where}: name '{fm['name']}' differs from its folder '{s.parent.name}'")

    # 4. Every openai.yaml parses; a skill that disables model invocation in
    #    Claude Code disables implicit invocation in Codex too.
    for s in skills:
        y = s.parent / "agents" / "openai.yaml"
        fm = frontmatter(s) or {}
        disabled = fm.get("disable-model-invocation") == "true"
        if y.is_file():
            where = str(y.relative_to(ROOT))
            try:
                data = parse_yaml(y.read_text(encoding="utf-8"))
            except ValueError as e:
                err(f"{where}: {e}")
                continue
            implicit = data.get("policy", {}).get("allow_implicit_invocation") if isinstance(data.get("policy"), dict) else None
            if disabled and implicit is not False:
                err(f"{where}: the skill sets disable-model-invocation, so policy.allow_implicit_invocation must be false")
            if not disabled and implicit is False:
                err(f"{where}: allow_implicit_invocation is false but SKILL.md does not set disable-model-invocation")
        elif disabled:
            err(f"{s.parent.relative_to(ROOT)}: disable-model-invocation without agents/openai.yaml")


main()
if errors:
    for e in errors:
        print("FAIL:", e, file=sys.stderr)
    sys.exit(1)
print("check_codex: ok")
