#!/usr/bin/env python3
"""
Build a signed iOS Release archive for Merge Empire FM and open it in Xcode Organizer.

Usage:
  python3 ios-build-and-release.py            # archive + .ipa, then open Organizer
  python3 ios-build-and-release.py --no-open  # archive + .ipa only

Requires macOS with Xcode, CocoaPods, the Flutter in .fvmrc on PATH, and
ios/Runner/GoogleService-Info.plist (git-ignored; see docs/RELEASE.md §3).
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent
WORKSPACE = ROOT / "ios" / "Runner.xcworkspace"
FIREBASE_PLIST = ROOT / "ios" / "Runner" / "GoogleService-Info.plist"
FLUTTER_ARCHIVE = ROOT / "build" / "ios" / "archive" / "Runner.xcarchive"
ARCHIVES_DIR = ROOT / "build" / "ios" / "archives"


def run(cmd, capture=False):
    print(f"\n▶  {' '.join(str(c) for c in cmd)}")
    result = subprocess.run(cmd, cwd=ROOT, capture_output=capture, text=True)
    if result.returncode != 0:
        if capture:
            print(result.stderr or result.stdout)
        print(f"\n✗  Command failed with exit code {result.returncode}", file=sys.stderr)
        sys.exit(result.returncode)
    return result


def check_prerequisites():
    print("── Checking prerequisites ──────────────────────")
    if sys.platform != "darwin":
        print("✗  iOS builds only run on macOS.")
        sys.exit(1)

    missing = [t for t in ("xcodebuild", "pod", "flutter") if not shutil.which(t)]
    if missing:
        print(f"✗  Missing tools: {', '.join(missing)}")
        sys.exit(1)

    # The PATH flutter is often the Homebrew one, not the pinned SDK the suite is green on.
    pinned = json.loads((ROOT / ".fvmrc").read_text())["flutter"]
    version = subprocess.run(["flutter", "--version", "--machine"], capture_output=True, text=True, cwd=ROOT)
    found = json.loads(version.stdout).get("frameworkVersion", "?") if version.returncode == 0 else "?"
    if found != pinned:
        print(f"✗  flutter on PATH is {found}; .fvmrc pins {pinned} ({shutil.which('flutter')}).")
        print("   export PATH=~/sdk/flutter/bin:$PATH, or use fvm.")
        sys.exit(1)

    if not WORKSPACE.exists():
        print(f"✗  Xcode workspace not found at {WORKSPACE}")
        sys.exit(1)
    if not FIREBASE_PLIST.exists():
        print(f"✗  {FIREBASE_PLIST.relative_to(ROOT)} is missing — copy it from the old repo (docs/RELEASE.md §3).")
        sys.exit(1)

    print(f"✓  All prerequisites found (Flutter {found}).")


def app_version():
    m = re.search(r"^version:\s*(\S+)", (ROOT / "pubspec.yaml").read_text(), re.M)
    return m.group(1) if m else "?"


def build_archive():
    print("\n── Archiving (Release) ─────────────────────────")
    # `flutter build ipa` runs pub get and pod install, archives and exports an
    # App Store .ipa; it always writes to the same path, so the archive is moved
    # out before the next build clobbers it.
    if FLUTTER_ARCHIVE.exists():
        shutil.rmtree(FLUTTER_ARCHIVE)
    run(["flutter", "build", "ipa", "--release", "--export-method", "app-store"])

    if not FLUTTER_ARCHIVE.exists():
        print(f"✗  Archive not found at expected path: {FLUTTER_ARCHIVE}")
        sys.exit(1)

    ARCHIVES_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive_path = ARCHIVES_DIR / f"MergeEmpireFM_{app_version()}_{stamp}.xcarchive"
    shutil.move(str(FLUTTER_ARCHIVE), archive_path)
    print(f"✓  Archive: {archive_path}")

    ipas = sorted((ROOT / "build" / "ios" / "ipa").glob("*.ipa"), key=lambda f: f.stat().st_mtime)
    if ipas:
        print(f"✓  IPA: {ipas[-1]}  (for Transporter, if not using Organizer)")
    return archive_path


def open_organizer(archive_path):
    print("\n── Opening Xcode Organizer ─────────────────────")
    run(["open", str(archive_path)])
    print("✓  Xcode Organizer opened.")


def main():
    parser = argparse.ArgumentParser(description="Archive Merge Empire FM for App Store distribution.")
    parser.add_argument("--no-open", action="store_true", help="Do not open the archive in Xcode Organizer")
    args = parser.parse_args()

    print("═══════════════════════════════════════════════")
    print(f"  Merge Empire FM — iOS Archive & Release  ({app_version()})")
    print("═══════════════════════════════════════════════")

    check_prerequisites()
    archive_path = build_archive()
    if not args.no_open:
        open_organizer(archive_path)

    print("\n═══════════════════════════════════════════════")
    print("  ✓  Archive ready.")
    print("     In Xcode Organizer:")
    print("     Distribute App → App Store Connect → upload")
    print("═══════════════════════════════════════════════\n")


if __name__ == "__main__":
    main()
