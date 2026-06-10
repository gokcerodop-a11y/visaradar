#!/usr/bin/env python3
"""Copy the 4 required secrets from refakat-proxy/.dev.vars into the
visaradar-proxy Worker as production secrets. Values are never printed."""
import subprocess
import sys
import os

SRC = os.path.expanduser(
    "~/Projects/apps/refakat_ai/workers/refakat-proxy/.dev.vars"
)
WORKER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SINGLE = ["ANTHROPIC_API_KEY", "APPLE_API_KEY_ID", "APPLE_API_ISSUER_ID"]

with open(SRC) as f:
    lines = f.read().splitlines()

values = {}

# Single-line keys
for ln in lines:
    for k in SINGLE:
        if ln.startswith(k + "="):
            values[k] = ln[len(k) + 1:].strip()

# Multiline P8: from "APPLE_API_KEY_P8=" until "-----END PRIVATE KEY-----"
p8 = []
collecting = False
for ln in lines:
    if ln.startswith("APPLE_API_KEY_P8="):
        collecting = True
        p8.append(ln[len("APPLE_API_KEY_P8="):])
        continue
    if collecting:
        p8.append(ln)
        if "END PRIVATE KEY" in ln:
            break
if p8:
    values["APPLE_API_KEY_P8"] = "\n".join(p8).strip()

required = ["ANTHROPIC_API_KEY", "APPLE_API_KEY_P8", "APPLE_API_KEY_ID",
            "APPLE_API_ISSUER_ID"]
missing = [k for k in required if not values.get(k)]
if missing:
    print("MISSING from source:", missing)
    sys.exit(1)

for name in required:
    res = subprocess.run(
        ["npx", "wrangler", "secret", "put", name],
        input=values[name], text=True, cwd=WORKER_DIR,
        capture_output=True,
    )
    ok = res.returncode == 0
    tail = (res.stdout + res.stderr).strip().splitlines()
    status = "OK" if ok else "FAIL"
    last = tail[-1] if tail else ""
    # Print only name + status (never the value)
    print(f"{name}: {status}  ({last[:80]})")
    if not ok:
        sys.exit(2)

print("All 4 secrets set.")
