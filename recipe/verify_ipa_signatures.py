"""Check that every installed IPA module matches its .sign file.

libcamera only loads IPA modules in-process when their signature verifies
against the public key compiled into libcamera.so; otherwise it runs them
isolated in a proxy worker process (conda-forge/libcamera-feedstock#19).
Any post-install modification of a module (e.g. RPATH patching) silently
breaks this, so verify the shipped files exactly as libcamera would.
"""

import glob
import os
import subprocess
import sys
import tempfile

prefix = os.environ.get("PREFIX") or os.environ["CONDA_PREFIX"]

# DER SubjectPublicKeyInfo header of an RSA-2048 key, which is what
# libcamera's gen-ipa-priv-key.sh generates and gen-ipa-pub-key.py embeds.
SPKI_HEADER = bytes.fromhex("30820122300d06092a864886f70d0101010500")
SPKI_LEN = 0x126

(lib,) = glob.glob(os.path.join(prefix, "lib", "libcamera.so.*.*.*"))
data = open(lib, "rb").read()
if data.count(SPKI_HEADER) != 1:
    sys.exit(f"expected exactly one embedded IPA public key in {lib}")
start = data.index(SPKI_HEADER)

modules = sorted(glob.glob(os.path.join(prefix, "lib", "libcamera", "ipa", "*.so")))
if not modules:
    sys.exit("no IPA modules found")

failed = []
with tempfile.NamedTemporaryFile(suffix=".der") as key:
    key.write(data[start : start + SPKI_LEN])
    key.flush()
    for module in modules:
        res = subprocess.run(
            ["openssl", "dgst", "-sha256", "-verify", key.name, "-keyform", "DER",
             "-signature", module + ".sign", module],
            capture_output=True, text=True,
        )
        ok = res.returncode == 0
        print(f"{os.path.basename(module)}: {'OK' if ok else 'BAD SIGNATURE'}")
        if not ok:
            failed.append(module)

if failed:
    sys.exit(f"{len(failed)} IPA module(s) have invalid signatures")
