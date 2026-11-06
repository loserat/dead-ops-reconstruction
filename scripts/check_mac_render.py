#!/usr/bin/env python3
"""Build and run the windowless Mac animation/lighting comparison. Requires Metal."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path, help="New output directory for images and measurements")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve()
if output.exists():
    parser.error("Use a new output directory; existing evidence is never overwritten")
work = root / "Build" / "RenderChecks"
work.mkdir(parents=True, exist_ok=True)
entry = root / "Sources" / "App.swift"
text = entry.read_text()
if text.count("@main struct NativeLauncher") != 1:
    raise SystemExit("Unexpected production entry point")
wrapper = work / "AppWithoutMain.swift"
wrapper.write_text(text.replace("@main struct NativeLauncher", "struct NativeLauncher"))
assets = work / "Assets"
if not assets.exists():
    assets.symlink_to(root / "Assets", target_is_directory=True)
if assets.resolve() != root / "Assets":
    raise SystemExit("Unexpected resource path")
sources = [p for p in sorted((root / "Sources").glob("*.swift")) if p != entry]
sources += [wrapper, root / "Tests" / "MacRenderProbe.swift"]
binary = work / "MacRenderProbe"
command = ["xcrun", "--sdk", "macosx", "swiftc", "-O", "-swift-version", "5",
           "-module-cache-path", str(work / "modules"), "-target", "arm64-apple-macosx14.0",
           *map(str, sources), "-o", str(binary)]
environment = dict(os.environ, DEVELOPER_DIR=os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"))
inputs = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
subprocess.run(command, cwd=root, env=environment, check=True)
subprocess.run([str(binary), str(output)], cwd=root, env=environment, check=True)
(output / "compile-inputs.json").write_text(json.dumps(inputs, indent=2) + "\n")
print(f"Native comparison passed: {output}")
