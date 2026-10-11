#!/usr/bin/env python3
"""CI invariants that actionlint cannot see.

Currently one: every step that EXECUTES start.sh must set IOI_ENV_NO_SHELL.
Missing it does not fail loudly — start.sh falls through to
`exec devenv shell < /dev/tty`, finds no TTY under wsl.exe, and the job hangs
until the timeout. That cost 36 minutes once. actionlint validates the workflow
schema and expressions but says nothing about this, so it is checked here.

Reads the real nested shape: wsl-bash steps keep their script under
`with.exec`, ordinary steps under `run`.
"""
import re
import sys

import yaml

PATH = ".github/workflows/ci.yml"

d = yaml.safe_load(open(PATH))
bad = []
for jn, job in d["jobs"].items():
    for step in job.get("steps", []):
        body = step.get("run") or (step.get("with") or {}).get("exec") or ""
        if not body:
            continue
        invocations = [
            line
            for line in body.split("\n")
            if re.search(r"\bbash\s+[^|]*start\.sh\b", line)
        ]
        if invocations and "IOI_ENV_NO_SHELL" not in body:
            bad.append(f"{jn} / {step.get('name', '?')}: {invocations[0].strip()}")

if bad:
    print("CI steps that execute start.sh without setting IOI_ENV_NO_SHELL:")
    for b in bad:
        print("  -", b)
    print("\nWithout it start.sh execs `devenv shell` and hangs with no TTY.")
    sys.exit(1)

print("every CI step that executes start.sh sets IOI_ENV_NO_SHELL OK")
