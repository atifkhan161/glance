#!/usr/bin/env python3
"""Insert a file into project.pbxproj: build file, file ref, group child, Sources phase.

Usage:
  pbxproj-add.py <project.pbxproj> <relative/path/File.swift> [--group <name>] [--target-sources-only] [--resources]

Group is matched by the group comment block name (e.g. GlanceTests, DesignSystem).
"""
import re
import subprocess
import sys


def new_id(seed, taken, prefix="AA"):
    n = 1
    while True:
        candidate = "%s%024X" % (prefix, (seed + n) & 0xFFFFFFFFFFFFFFFFFF)
        if candidate not in taken:
            taken.add(candidate)
            return candidate
        n += 1


def main():
    path = sys.argv[1]
    rel = sys.argv[2]
    group_name = "GlanceTests"
    resources = False
    args = sys.argv[3:]
    if "--group" in args:
        group_name = args[args.index("--group") + 1]
    if "--resources" in args:
        resources = True

    name = rel.rsplit("/", 1)[-1]
    src = open(path).read()

    if name in src:
        print("already present: %s" % name)
        return 0

    taken = set(re.findall(r"\b[0-9A-F]{24}\b", src))
    seed = sum(ord(c) * (i + 1) for i, c in enumerate(name))
    file_ref = new_id(seed, taken, "BB")
    build_file = new_id(seed + 7, taken, "CC")
    seed2 = sum(ord(c) * (i + 7) for i, c in enumerate(rel))
    build_file = new_id(seed2, taken, "CC")
    file_ref = new_id(seed, taken, "BB")

    phase = "PBXResourcesBuildPhase" if resources else "PBXSourcesBuildPhase"

    # 1. PBXBuildFile
    anchor = "/* Begin %s section */" % phase
    line = "\t\t%s /* %s in %s */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n" % (
        build_file, name, phase, file_ref, name)
    src = src.replace(anchor, anchor + "\n" + line.rstrip("\n"), 1)

    # 2. PBXFileReference
    ref_anchor = "/* Begin PBXFileReference section */"
    ref_line = "\t\t%s /* %s */ = {isa = PBXFileReference; explicitFileType = %s; path = %s; sourceTree = \"<group>\"; };" % (
        file_ref, name,
        "text.html" if name.endswith(".html") else "sourcecode.swift",
        name)
    src = src.replace(ref_anchor, ref_anchor + "\n" + ref_line, 1)

    # 3. group child
    m = re.search(r"([0-9A-F]{24}) /\* %s \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n" % re.escape(group_name), src)
    if not m:
        print("group %s not found" % group_name)
        return 1
    insert_at = m.end()
    src = src[:insert_at] + "\t\t\t\t%s /* %s */,\n" % (file_ref, name) + src[insert_at:]

    # 4. phase file entry
    m2 = re.search(r"isa = %s;\n(?:.*\n)*?\t\t\tfiles = \(\n" % re.escape(phase), src)
    if not m2:
        print("phase %s not found" % phase)
        return 1
    insert_at = m2.end()
    src = src[:insert_at] + "\t\t\t\t%s /* %s in %s */,\n" % (build_file, name, phase) + src[insert_at:]

    open(path, "w").write(src)
    r = subprocess.run(["plutil", "-lint", path], capture_output=True, text=True)
    print(r.stdout.strip() or r.stderr.strip())
    return 0 if r.returncode == 0 else 1


if __name__ == "__main__":
    sys.exit(main())