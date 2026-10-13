#!/usr/bin/env python3
"""Insert a file into project.pbxproj: build file, file ref, group child, sources phase.

Usage:
  pbxproj-add.py <project.pbxproj> <path/File.swift> [--group Name] [--app]

The Glance app target and its GlanceTests target BOTH have a build phase whose
build files are commented "in Sources", so comments cannot distinguish them. The
owning target is resolved by walking PBXNativeTarget.buildPhases.
"""
import re
import subprocess
import sys


def make_id(seed, taken, prefix):
    n = 1
    while True:
        candidate = "%s%024X" % (prefix, (seed + n) & 0xFFFFFFFFFFFFFFFFFF)
        if candidate not in taken:
            taken.add(candidate)
            return candidate
        n += 1


def sources_phase_for(src, product):
    for m in re.finditer(r"([0-9A-F]{24}) /\* [^*]*? \*/ = \{\n\t\t\tisa = PBXNativeTarget;", src):
        block = re.match(r"([0-9A-F]{24}) /\* [^*]*? \*/ = \{\n\t\t\tisa = PBXNativeTarget;((?:.|\n)*?)\n\t\t\};",
                         src[m.start():])
        if not block:
            continue
        if product not in block.group(2):
            continue
        phases = re.search(r"buildPhases = \(\n((?:.|\n)*?)\t\t\t\);", block.group(2))
        if not phases:
            continue
        for pid in re.findall(r"([0-9A-F]{24})", phases.group(1)):
            pm = re.search(r"%s /\* [^*]*? \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;" % pid, src)
            if pm:
                return pid
    return None


def main():
    path, rel = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]
    group_name = args[args.index("--group") + 1] if "--group" in args else "GlanceTests"
    app = "--app" in args

    name = rel.rsplit("/", 1)[-1]
    src = open(path).read()
    if name in src:
        print("already present: %s" % name)
        return 0

    product = "Glance.app" if app else "GlanceTests.xctest"
    phase_id = sources_phase_for(src, product)
    if not phase_id:
        print("no PBXSourcesBuildPhase found for %s" % product)
        return 1

    taken = set(re.findall(r"\b[0-9A-F]{24}\b", src))
    seed = sum(ord(c) * (i + 1) for i, c in enumerate(rel))
    file_ref = make_id(seed, taken, "BB")
    build_file = make_id(seed * 3 + 11, taken, "CC")
    phase_label = "Sources"

    build_line = '\t\t%s /* %s in %s */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };' % (
        build_file, name, phase_label, file_ref, name)
    anchor = "/* Begin PBXBuildFile section */"
    src = src.replace(anchor, anchor + "\n" + build_line, 1)

    ftype = "sourcecode.swift"
    ref_line = '\t\t%s /* %s */ = {isa = PBXFileReference; explicitFileType = %s; path = %s; sourceTree = "<group>"; };' % (
        file_ref, name, ftype, name)
    anchor = "/* Begin PBXFileReference section */"
    src = src.replace(anchor, anchor + "\n" + ref_line, 1)

    gm = re.search(r"[0-9A-F]{24} /\* %s \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n" % re.escape(group_name), src)
    if not gm:
        print("group %s not found" % group_name)
        return 1
    at = gm.end()
    src = src[:at] + "\t\t\t\t%s /* %s */,\n" % (file_ref, name) + src[at:]

    # Resolved LAST: the three insertions above all shift byte offsets, so an
    # anchor computed before them would land in the wrong place.
    files_anchor = re.search(
        r"%s /\* [^*]*? \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;\n(?:.|\n)*?\t\t\tfiles = \(\n" % phase_id, src)
    if not files_anchor:
        print("could not locate files list for phase %s" % phase_id)
        return 1
    at = files_anchor.end()
    src = src[:at] + "\t\t\t\t%s /* %s in %s */,\n" % (build_file, name, phase_label) + src[at:]

    open(path, "w").write(src)
    r = subprocess.run(["plutil", "-lint", path], capture_output=True, text=True)
    print(r.stdout.strip() or r.stderr.strip())
    return 0 if r.returncode == 0 else 1


if __name__ == "__main__":
    sys.exit(main())