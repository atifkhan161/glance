#!/usr/bin/env python3
# Bump Glance's version in Glance/Resources/Info.plist.
#
#   scripts/bump-version.py patch      # 1.4.6 -> 1.4.7
#   scripts/bump-version.py minor      # 1.4.7 -> 1.5.0
#   scripts/bump-version.py major      # 1.5.0 -> 2.0.0
#   scripts/bump-version.py 2.0.0      # explicit version
#
# This replaces the PlistBuddy one-liners the old AGENTS.md documented:
# PlistBuddy is macOS-only and the dev box is now Linux. Bump rules mirror
# scripts/release.sh exactly (a two-part version like 1.2 counts as 1.2.0 for
# patch math; no-op and backwards bumps are refused) so both tools agree.
#
# Bumping is a local step in the CI release flow: bump here, commit, push,
# then `gh workflow run release.yml` - the runner releases whatever the plist
# says. `scripts/release.sh` still bumps by itself when given a version the
# plist does not have yet (the old Mac-local flow).

import argparse
import plistlib
import re
import sys
from pathlib import Path

PLIST = Path(__file__).resolve().parent.parent / "Glance" / "Resources" / "Info.plist"

VERSION_RE = re.compile(r"\d+\.\d+(?:\.\d+)?")


def bump(part: str, current: str) -> str:
    match = re.fullmatch(r"(\d+)\.(\d+)(?:\.(\d+))?", current)
    if not match:
        sys.exit(f"unrecognised current version: {current}")
    maj, mino, pat = int(match[1]), int(match[2]), int(match[3] or 0)
    if part == "patch":
        return f"{maj}.{mino}.{pat + 1}"
    if part == "minor":
        return f"{maj}.{mino + 1}.0"
    if part == "major":
        return f"{maj + 1}.0.0"
    return part


def version_key(version: str):
    return [int(p) for p in version.split(".")]


def main() -> None:
    parser = argparse.ArgumentParser(description="Bump the version in Info.plist")
    parser.add_argument("part", help="patch | minor | major | explicit X.Y[.Z]")
    args = parser.parse_args()

    if args.part not in ("patch", "minor", "major") and not VERSION_RE.fullmatch(args.part):
        sys.exit(f"unrecognised version argument: {args.part}")

    raw = PLIST.read_bytes()
    plist = plistlib.loads(raw)
    current = str(plist["CFBundleShortVersionString"])
    build = str(plist["CFBundleVersion"])

    version = bump(args.part, current)

    if version == current:
        sys.exit(f"already at {version} (build {build}) - nothing to bump")
    if version_key(version) < version_key(current):
        sys.exit(f"refusing to go backwards: {current} -> {version}")

    plist["CFBundleShortVersionString"] = version
    plist["CFBundleVersion"] = str(int(build) + 1)
    with PLIST.open("wb") as fh:
        plistlib.dump(plist, fh, sort_keys=False)

    # Validate the result by reading it back before claiming success.
    check = plistlib.loads(PLIST.read_bytes())
    new_version = str(check["CFBundleShortVersionString"])
    new_build = str(check["CFBundleVersion"])
    if new_version != version or new_build != str(int(build) + 1):
        sys.exit("plist did not round-trip; refusing to leave it half-written")

    print(f"{current} (build {build})  ->  {version} (build {new_build})")
    print(f"next: commit Info.plist, push, then gh workflow run release.yml")


if __name__ == "__main__":
    main()
