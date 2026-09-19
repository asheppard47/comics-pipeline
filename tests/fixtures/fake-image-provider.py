"""Offline provider stand-in that emits one deterministic image-generation result."""

from pathlib import Path
from PIL import Image
import os
import subprocess
import sys
import time


def argument_value(flag):
    try:
        return sys.argv[sys.argv.index(flag) + 1]
    except (ValueError, IndexError) as exc:
        raise SystemExit(f"missing required fixture argument: {flag}") from exc


output_dir = Path(argument_value("--output-dir"))
output_dir.mkdir(parents=True, exist_ok=True)
log_dir_value = os.environ.get("COMICS_FAKE_PROVIDER_LOG_DIR")
log_dir = Path(log_dir_value) if log_dir_value else None
if log_dir:
    log_dir.mkdir(parents=True, exist_ok=True)
    deadline = os.environ.get("PROVIDER_CALLER_DEADLINE_SECS")
    (log_dir / "deadline.txt").write_text(deadline or "missing")
else:
    deadline = os.environ.get("PROVIDER_CALLER_DEADLINE_SECS")

mode = os.environ.get("COMICS_FAKE_PROVIDER_MODE", "success")
if mode == "refuse":
    if not deadline:
        if log_dir:
            (log_dir / "refusal.txt").write_text("missing-deadline")
        raise SystemExit(75)
    required = float(os.environ.get("COMICS_FAKE_PROVIDER_REQUIRED_SECS", "10"))
    if float(deadline) < required:
        if log_dir:
            (log_dir / "refusal.txt").write_text("deadline-refusal")
        raise SystemExit(75)

if mode == "hang":
    if log_dir:
        (log_dir / "provider-pid.txt").write_text(str(os.getpid()))
    grandchild = subprocess.Popen(
        [sys.executable, "-c", "import time; time.sleep(30)"],
    )
    if log_dir:
        (log_dir / "grandchild-pid.txt").write_text(str(grandchild.pid))
    time.sleep(2)
    raise SystemExit(70)

if log_dir:
    (log_dir / "provider-spawned.txt").write_text("yes")
count = int(os.environ.get("COMICS_FAKE_IMAGE_COUNT", "1"))
for index in range(count):
    Image.new("RGB", (1200, 900), "white").save(
        output_dir / f"offline_provider_fixture_{index + 1}.jpg"
    )
