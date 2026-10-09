#!/usr/bin/env python3
"""Register a .swift file in project.pbxproj (four edits, no external deps).

    scripts/add-file.py FILE GROUP [--target app|tests|uitests]

GROUP is a group path such as Core/Logging, Core/Network, Settings, or
GlanceTests. The group must already exist.
"""
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBX = ROOT / "Glance" / "Glance.xcodeproj" / "project.pbxproj"

TARGET_PHASE = {
    "app": "EBCDFE4FC64A11F71EA4B02E",
    "tests": "15A885ECB27CC8627B5F3B25",
    "uitests": "3DBB368CD5652076C0E21630",
}


def make_id(seed: str) -> str:
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()


def ensure_group(text: str, group_path: str) -> tuple[str, str]:
    """Return (text, group_id) with `group_path` guaranteed to exist as a group."""
    parts = group_path.split("/")
    leaf = parts[-1]
    parent_path = "/".join(parts[:-1]) if len(parts) > 1 else "Core"

    probe = re.compile(r"[0-9A-F]{24} /\* " + re.escape(leaf) + r" \*/ = \{\n\t+isa = PBXGroup;")
    if probe.search(text):
        return text, ""

    parent_leaf = parent_path.split("/")[-1]
    parent_re = re.compile(
        r"([0-9A-F]{24}) /\* " + re.escape(parent_leaf) + r" \*/ = \{\n"
        r"\t+isa = PBXGroup;\n\t+children = \(\n(.*?)(\t+\);)",
        re.DOTALL,
    )
    pm = parent_re.search(text)
    if pm is None:
        sys.exit(f"error: parent group {parent_path} not found; create it manually")
    parent_id = pm.group(1)

    gid = make_id(group_path + "::group")
    block = (
        f"\t\t{gid} /* {leaf} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = {leaf};\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )
    insert_at = text.index(f"\t\t{parent_id} /* {parent_leaf} */ = {{")
    text = text[:insert_at] + block + text[insert_at:]

    pm = parent_re.search(text)
    text = text[: pm.start(2)] + f"\t\t\t\t{gid} /* {leaf} */,\n" + text[pm.start(2) :]
    return text, gid


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2

    rel = sys.argv[1]
    group_path = sys.argv[2]
    target = sys.argv[3] if len(sys.argv) > 3 else "app"

    name = Path(rel).name
    if not (ROOT / "Glance" / rel).exists():
        print(f"error: {ROOT / 'Glance' / rel} does not exist on disk")
        return 1

    text = PBX.read_text()

    if f"/* {name} */" in text:
        print(f"skip: {name} already registered")
        return 0

    text, created = ensure_group(text, group_path)
    if created:
        print(f"created group {group_path} ({created})")

    file_ref = make_id(name + "::ref")
    build_file = make_id(name + "::build")
    if file_ref == build_file:
        build_file = make_id(name + "::build2")

# Locate the group block by its `path = <leaf>;` and take its children list.
    # The children list may be empty (`children = (\n\t\t\t);`), so match either
    # the empty form or one or more entry lines.
    leaf = group_path.split("/")[-1]
    children_re = r"(?:\n(?:\t+[0-9A-F]{24} /\* .*? \*/,)*)?\n\t+\);"
    group_re = re.compile(
        r"([0-9A-F]{24}) /\* " + re.escape(leaf) + r" \*/ = \{\n"
        r"\t+isa = PBXGroup;\n"
        r"\t+children = \(" + children_re + r"\n"
        r"\t+path = " + re.escape(leaf) + r";",
        re.DOTALL,
    )
    matches = group_re.findall(text)
    if not matches:
        print(f"error: no PBXGroup with path = {leaf}")
        return 1
    group_id = matches[0]

    # 1. PBXBuildFile entry, inserted after the first one.
    build_entry = (
        f"\t\t{build_file} /* {name} in Sources */ = {{isa = PBXBuildFile; "
        f"fileRef = {file_ref} /* {name} */; }};\n"
    )
    anchor = re.search(r"\t\t[0-9A-F]{24} /\* .*? in Sources \*/ = \{isa = PBXBuildFile;", text)
    text = text[: anchor.start()] + build_entry + text[anchor.start() :]

    # 2. PBXFileReference entry, inserted after the first one.
    ref_entry = (
        f"\t\t{file_ref} /* {name} */ = {{isa = PBXFileReference; "
        f"explicitFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
    )
    anchor = re.search(r"\t\t[0-9A-F]{24} /\* .*? \*/ = \{isa = PBXFileReference;", text)
    text = text[: anchor.start()] + ref_entry + text[anchor.start() :]

    # 3. Group children entry. subn replaces the WHOLE matched span, so the
    #    replacement must re-emit the captured header (group 1), the existing
    #    children (group 2), and the closing `);` (group 3). Dropping any of
    #    them silently destroys the group while still linting as valid plist.
    def add_to_children(match: "re.Match[str]") -> str:
        line = f"\t\t\t\t{file_ref} /* {name} */,\n"
        return match.group(1) + line + match.group(2) + match.group(3)

    target_group = re.compile(
        r"(" + group_id + r" /\* " + re.escape(leaf) + r" \*/ = \{\n"
        r"\t+isa = PBXGroup;\n\t+children = \(\n)(.*?)(\t+\);)",
        re.DOTALL,
    )
    text, n = target_group.subn(add_to_children, text, count=1)
    if n != 1:
        print(f"error: failed to add {name} to group children")
        return 1

    # 4. Sources phase entry for the chosen target.
    phase_id = TARGET_PHASE[target]
    phase_re = re.compile(
        r"(" + phase_id + r" /\* Sources \*/ = \{\n"
        r"\t+isa = PBXSourcesBuildPhase;\n"
        r"\t+buildActionMask = 2147483647;\n\t+files = \(\n)(.*?)(\t+\);)",
        re.DOTALL,
    )

    def add_to_phase(match: "re.Match[str]") -> str:
        line = f"\t\t\t\t{build_file} /* {name} in Sources */,\n"
        return match.group(1) + line + match.group(2) + match.group(3)

    text, n = phase_re.subn(add_to_phase, text, count=1)
    if n != 1:
        print(f"error: phase {phase_id} ({target}) not found")
        return 1

    PBX.write_text(text)

    hits = text.count(name)
    print(f"ok: {name} -> group {group_id} ({group_path}), target {target}, {hits} hits")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())