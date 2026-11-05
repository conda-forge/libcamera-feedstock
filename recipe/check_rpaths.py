"""Check that every ELF file shipped by libcamera has only $ORIGIN-relative rpaths.

recipe.yaml relocates only an explicit list of paths (build.dynamic_linking.
binary_relocation), so that the signed IPA modules are left untouched (#19).
A binary that a future libcamera release installs somewhere else would silently
miss relocation; this test fails the build instead.
"""

import glob
import json
import os
import subprocess
import sys

prefix = os.environ.get("PREFIX") or os.environ["CONDA_PREFIX"]

(meta,) = glob.glob(os.path.join(prefix, "conda-meta", "libcamera-[0-9]*.json"))
files = json.load(open(meta))["files"]

checked = 0
bad = []
for rel in files:
    path = os.path.join(prefix, rel)
    if os.path.islink(path) or not os.path.isfile(path):
        continue
    with open(path, "rb") as f:
        if f.read(4) != b"\x7fELF":
            continue
    checked += 1
    rpath = subprocess.run(
        ["patchelf", "--print-rpath", path], capture_output=True, text=True, check=True
    ).stdout.strip()
    entries = [e for e in rpath.split(":") if e]
    if not entries or any(not e.startswith("$ORIGIN") for e in entries):
        bad.append(f"{rel}: {rpath!r}")

print(f"checked {checked} ELF files")
if not checked:
    sys.exit("no ELF files found in the libcamera package")
if bad:
    sys.exit("not relocated (extend binary_relocation in recipe.yaml):\n  " + "\n  ".join(bad))
