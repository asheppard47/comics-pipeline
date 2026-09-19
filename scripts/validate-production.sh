#!/bin/bash
# Offline production contract validation. Makes no model or publishing calls.

set -u

usage() {
    echo "Usage: ./scripts/validate-production.sh"
    echo "Offline production contract validation. Makes no model or publishing calls."
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FAILED=0

fail() {
    echo "FAIL: $*" >&2
    FAILED=$((FAILED + 1))
}

is_allowed_final_entry() {
    case "$1" in
        *.png|*.prompt.txt) return 0 ;;
        *) return 1 ;;
    esac
}

if is_allowed_final_entry "unexpected-final.jpg"; then
    fail "unexpected finals extension classifier"
fi

for script in "$SCRIPT_DIR/generate-comic.sh" "$SCRIPT_DIR/batch-generate.sh" "$SCRIPT_DIR/promote-final.sh"; do
    bash -n "$script" || fail "shell syntax: $script"
    [[ -x "$script" ]] || fail "script is not executable: $script"
done

if ! "$SCRIPT_DIR/batch-generate.sh" --help >/dev/null; then
    fail "batch generator --help"
fi

for chassis in write-literal-file run-image-provider promote-manifest; do
    path="$SCRIPT_DIR/chassis/$chassis"
    [[ -x "$path" ]] || fail "chassis script is not executable: $path"
    python3 "$path" --help >/dev/null || fail "chassis --help failed: $path"
done

if ! python3 - "$SCRIPT_DIR" <<'PY'
import ast
import importlib.util
import inspect
from pathlib import Path
import sys

sys.dont_write_bytecode = True

for path in Path(sys.argv[1]).glob("*.py"):
    ast.parse(path.read_text(), filename=str(path))

chassis_dir = Path(sys.argv[1]) / "chassis"
for path in chassis_dir.iterdir():
    if path.is_file() and not path.name.startswith("."):
        ast.parse(path.read_text(), filename=str(path))

caption_path = Path(sys.argv[1]) / "add-caption.py"
spec = importlib.util.spec_from_file_location("add_caption_fixture", caption_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
try:
    module._load_font([], 32)
except OSError:
    pass
else:
    raise AssertionError("font loader silently accepted an empty font set")

assert module._default_font_size(900) == 32
assert module._default_font_size(4000) == 140

signature_path = Path(sys.argv[1]) / "add-signature.py"
sig_spec = importlib.util.spec_from_file_location("add_signature_fixture", signature_path)
sig_module = importlib.util.module_from_spec(sig_spec)
sig_spec.loader.exec_module(sig_module)
default_position = inspect.signature(sig_module.add_signature).parameters["position"].default
if default_position != "top-right":
    raise AssertionError(f"add_signature() default position drifted from production: {default_position!r}")
PY
then
    fail "Python syntax validation"
fi

if ! python3 "$SCRIPT_DIR/add-signature.py" --help | grep -Fq "default: top-right"; then
    fail "add-signature.py CLI default position drifted from production top-right"
fi

if [[ ! -s "$REPO_ROOT/references/signature_transparent.png" ]]; then
    fail "production signature asset is missing"
fi

STYLE_COUNT=$(find "$REPO_ROOT/references/style" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | wc -l | tr -d ' ')
if [[ "$STYLE_COUNT" -lt 3 ]]; then
    fail "expected at least 3 approved style references; found $STYLE_COUNT"
fi

if ! "$SCRIPT_DIR/generate-comic.sh" --dry-run "Production validator scene" "Production validator caption" 4:3 1K >/dev/null; then
    fail "generator dry-run"
fi

if "$SCRIPT_DIR/generate-comic.sh" --dry-run "Invalid aspect scene" "caption" 16:9 1K >/dev/null 2>&1; then
    fail "generator accepted an unsupported aspect ratio"
fi

if "$SCRIPT_DIR/generate-comic.sh" --dry-run "Invalid size scene" "caption" 4:3 8K >/dev/null 2>&1; then
    fail "generator accepted an unsupported image size"
fi

STYLE_OVERRIDE="$REPO_ROOT/references/style/minimal-domestic-scene.jpg"
if ! COMICS_STYLE_REFERENCE="$STYLE_OVERRIDE" \
    "$SCRIPT_DIR/generate-comic.sh" --dry-run "Style override scene" "caption" 4:3 1K | grep -Fq "Style reference: $STYLE_OVERRIDE"; then
    fail "generator did not honor COMICS_STYLE_REFERENCE"
fi

if "$SCRIPT_DIR/generate-comic.sh" --dry-run "Dry-run should not write" "caption" 4:3 1K | grep -Fq ".provider-run."; then
    fail "dry-run mentioned a provider-run directory"
fi

if ! python3 "$SCRIPT_DIR/check-desk-packet.py" --help >/dev/null; then
    fail "desk packet checker --help"
fi
if ! python3 "$SCRIPT_DIR/check-desk-packet.py" --packet "$REPO_ROOT/tests/fixtures/desk-packet-ship.md"; then
    fail "desk packet checker rejected a valid ship packet"
fi
if ! python3 "$SCRIPT_DIR/check-desk-packet.py" --packet "$REPO_ROOT/tests/fixtures/desk-packet-kill.md"; then
    fail "desk packet checker rejected a valid kill packet"
fi
if python3 "$SCRIPT_DIR/check-desk-packet.py" --packet "$REPO_ROOT/tests/fixtures/desk-packet-bad.md" >/dev/null 2>&1; then
    fail "desk packet checker accepted a ship without archive pass"
fi
if python3 "$SCRIPT_DIR/check-desk-packet.py" --packet "$REPO_ROOT/tests/fixtures/desk-packet-ship-no-post.md" >/dev/null 2>&1; then
    fail "desk packet checker accepted a ship with an empty post_url"
fi

CHASSIS_TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comics-chassis.XXXXXX")
printf 'literal $PATH and $(uname) bytes\n' | python3 "$SCRIPT_DIR/chassis/write-literal-file" --output "$CHASSIS_TEST_DIR/literal.txt"
grep -Fq 'literal $PATH and $(uname) bytes' "$CHASSIS_TEST_DIR/literal.txt" || fail "literal writer did not preserve raw bytes"
if printf 'overwrite' | python3 "$SCRIPT_DIR/chassis/write-literal-file" --output "$CHASSIS_TEST_DIR/literal.txt" >/dev/null 2>&1; then
    fail "literal writer overwrote an existing file"
fi
grep -Fq 'literal $PATH and $(uname) bytes' "$CHASSIS_TEST_DIR/literal.txt" || fail "literal writer mutated an existing file after refusal"

CHASSIS_PROMPT="$CHASSIS_TEST_DIR/provider-prompt.txt"
printf 'chassis exclusive-dir prompt' | python3 "$SCRIPT_DIR/chassis/write-literal-file" --output "$CHASSIS_PROMPT"
python3 "$SCRIPT_DIR/chassis/write-literal-file" --output "$CHASSIS_TEST_DIR/parent-stale.jpg" < "$REPO_ROOT/references/style/clean-office-linework.jpg"
if ! COMICS_FAKE_PROVIDER_LOG_DIR="$CHASSIS_TEST_DIR/provider-log" \
    python3 "$SCRIPT_DIR/chassis/run-image-provider" \
    --provider-cli "$REPO_ROOT/tests/fixtures/fake-image-provider.py" \
    --prompt-file "$CHASSIS_PROMPT" \
    --style-reference "$REPO_ROOT/references/style/clean-office-linework.jpg" \
    --provider-route gemini-image \
    --aspect-ratio 4:3 \
    --image-size 1K \
    --output-parent "$CHASSIS_TEST_DIR" \
    --outer-wait-secs 5 \
    --termination-grace-secs 1 > "$CHASSIS_TEST_DIR/provider.json"; then
    fail "chassis provider-run success path"
else
    python3 - "$CHASSIS_TEST_DIR/provider.json" "$CHASSIS_TEST_DIR" <<'PY' || fail "chassis provider-run did not isolate the exclusive directory"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text())
image = Path(payload["image"])
parent = Path(sys.argv[2])
if image.parent.parent != parent.resolve() or not image.parent.name.startswith(".provider-run."):
    raise SystemExit(f"image was not written into an exclusive child: {image}")
if image.name != "offline_provider_fixture_1.jpg":
    raise SystemExit(f"unexpected provider image name: {image.name}")
PY
fi

python3 - "$SCRIPT_DIR/chassis/promote-manifest" "$CHASSIS_TEST_DIR" <<'PY' || fail "chassis promote-manifest contract"
import hashlib
import json
import subprocess
import sys
from pathlib import Path

promote = sys.argv[1]
root = Path(sys.argv[2])
source_root = root / "promote-src"
dest_root = root / "promote-dst"
packet = source_root / "packet"
source_root.mkdir()
dest_root.mkdir()
packet.mkdir()


def write(path: Path, body: bytes) -> tuple[int, str]:
    path.write_bytes(body)
    return path.stat().st_size, hashlib.sha256(body).hexdigest()


img_size, img_hash = write(packet / "panel.png", b"png-bytes")
brief_size, brief_hash = write(packet / "brief.md", b"brief")
side_size, side_hash = write(packet / "notes.txt", b"notes")
(packet / "passenger.txt").write_text("extra")
bad = {
    "schema_version": 1,
    "lane": "cartoon",
    "item_id": "packet-passenger",
    "mode": "directory",
    "destination": "shipped-packet",
    "entries": [
        {"role": "image", "source": "packet/panel.png", "size": img_size, "sha256": img_hash},
        {"role": "brief", "source": "packet/brief.md", "size": brief_size, "sha256": brief_hash},
        {"role": "sidecar", "source": "packet/notes.txt", "size": side_size, "sha256": side_hash},
    ],
}
bad_path = root / "bad-manifest.json"
bad_path.write_text(json.dumps(bad))
bad_run = subprocess.run(
    [sys.executable, promote, "--manifest", str(bad_path), "--source-root", str(source_root), "--destination-root", str(dest_root)],
    capture_output=True,
    text=True,
)
if bad_run.returncode == 0:
    raise SystemExit("directory promotion accepted unmanifested passengers")
(packet / "passenger.txt").unlink()

good_path = root / "good-manifest.json"
good_path.write_text(json.dumps(bad | {"item_id": "packet-ok"}))
good_run = subprocess.run(
    [sys.executable, promote, "--manifest", str(good_path), "--source-root", str(source_root), "--destination-root", str(dest_root)],
    capture_output=True,
    text=True,
)
if good_run.returncode != 0:
    raise SystemExit(good_run.stderr)
shipped = dest_root / "shipped-packet"
if not (shipped / "panel.png").is_file() or (packet / "panel.png").exists():
    raise SystemExit("directory promotion did not atomically install and consume sources")

mismatch = {
    "schema_version": 1,
    "lane": "cartoon",
    "item_id": "hash-mismatch",
    "mode": "flat-set",
    "entries": [
        {
            "role": "image",
            "source": "panel.png",
            "destination": "hash.png",
            "size": img_size,
            "sha256": "0" * 64,
        }
    ],
}
(source_root / "panel.png").write_bytes(b"png-bytes")
mismatch_path = root / "mismatch.json"
mismatch_path.write_text(json.dumps(mismatch))
mismatch_run = subprocess.run(
    [sys.executable, promote, "--manifest", str(mismatch_path), "--source-root", str(source_root), "--destination-root", str(dest_root)],
    capture_output=True,
    text=True,
)
if mismatch_run.returncode == 0 or (dest_root / "hash.png").exists():
    raise SystemExit("promotion accepted a digest mismatch")

missing_dest = {
    "schema_version": 1,
    "lane": "cartoon",
    "item_id": "missing-destination",
    "mode": "flat-set",
    "entries": [
        {"role": "image", "source": "panel.png", "size": img_size, "sha256": img_hash}
    ],
}
missing_dest_path = root / "missing-dest-manifest.json"
missing_dest_path.write_text(json.dumps(missing_dest))
missing_dest_run = subprocess.run(
    [sys.executable, promote, "--manifest", str(missing_dest_path), "--source-root", str(source_root), "--destination-root", str(dest_root)],
    capture_output=True,
    text=True,
)
if missing_dest_run.returncode == 0 or (dest_root / "None").exists():
    raise SystemExit("flat-set promotion accepted an entry missing a destination path")
PY
find "$CHASSIS_TEST_DIR" -type f -delete
find "$CHASSIS_TEST_DIR" -depth -type d -empty -delete

CALLER_TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comics-air-caller.XXXXXX")
CALLER_SUCCESS_OUTPUT="$CALLER_TEST_DIR/success-output"
CALLER_SUCCESS_LOG="$CALLER_TEST_DIR/success-log"
if ! COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/fake-image-provider.py" \
    COMICS_PROVIDER_WAIT_SECS=5 \
    COMICS_FAKE_PROVIDER_LOG_DIR="$CALLER_SUCCESS_LOG" \
    COMICS_OUTPUT_DIR="$CALLER_SUCCESS_OUTPUT" \
    "$SCRIPT_DIR/generate-comic.sh" "Caller deadline success" "caption" 4:3 1K >/dev/null 2>&1; then
    fail "provider caller wrapper sufficient-deadline success path"
elif ! python3 - "$CALLER_SUCCESS_LOG/deadline.txt" <<'PY'
from pathlib import Path
import sys

value = float(Path(sys.argv[1]).read_text())
if not 0 < value <= 5:
    raise SystemExit(f"invalid propagated remaining deadline: {value}")
PY
then
    fail "provider caller wrapper did not propagate bounded remaining capacity"
fi
[[ -s "$CALLER_SUCCESS_LOG/provider-spawned.txt" ]] || fail "provider caller success fixture did not reach provider marker"

CALLER_REFUSAL_LOG="$CALLER_TEST_DIR/refusal-log"
COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/fake-image-provider.py" \
    COMICS_PROVIDER_WAIT_SECS=1 \
    COMICS_FAKE_PROVIDER_LOG_DIR="$CALLER_REFUSAL_LOG" \
    COMICS_FAKE_PROVIDER_MODE=refuse \
    COMICS_FAKE_PROVIDER_REQUIRED_SECS=10 \
    COMICS_OUTPUT_DIR="$CALLER_TEST_DIR/refusal-output" \
    "$SCRIPT_DIR/generate-comic.sh" "Caller deadline refusal" "caption" 4:3 1K >/dev/null 2>&1
CALLER_REFUSAL_STATUS=$?
[[ "$CALLER_REFUSAL_STATUS" -eq 75 ]] || fail "provider caller wrapper did not propagate refusal exit 75 (got $CALLER_REFUSAL_STATUS)"
[[ "$(cat "$CALLER_REFUSAL_LOG/refusal.txt" 2>/dev/null)" == "deadline-refusal" ]] || fail "provider refusal was not based on propagated remaining capacity"
[[ ! -e "$CALLER_REFUSAL_LOG/provider-spawned.txt" ]] || fail "provider refusal fixture reached provider marker"

CALLER_TIMEOUT_LOG="$CALLER_TEST_DIR/timeout-log"
COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/fake-image-provider.py" \
    COMICS_PROVIDER_WAIT_SECS=0.25 \
    COMICS_PROVIDER_GRACE_SECS=0.1 \
    COMICS_FAKE_PROVIDER_LOG_DIR="$CALLER_TIMEOUT_LOG" \
    COMICS_FAKE_PROVIDER_MODE=hang \
    COMICS_OUTPUT_DIR="$CALLER_TEST_DIR/timeout-output" \
    "$SCRIPT_DIR/generate-comic.sh" "Caller timeout and reap" "caption" 4:3 1K >/dev/null 2>&1
CALLER_TIMEOUT_STATUS=$?
[[ "$CALLER_TIMEOUT_STATUS" -eq 124 ]] || fail "provider caller wrapper did not classify timeout as exit 124 (got $CALLER_TIMEOUT_STATUS)"
for pid_file in "$CALLER_TIMEOUT_LOG/provider-pid.txt" "$CALLER_TIMEOUT_LOG/grandchild-pid.txt"; do
    if [[ ! -s "$pid_file" ]]; then
        fail "provider timeout fixture did not record $(basename "$pid_file")"
        continue
    fi
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
        fail "provider caller wrapper left process $pid alive after timeout"
        kill -KILL "$pid" 2>/dev/null || true
    fi
done

CALLER_CANCEL_LOG="$CALLER_TEST_DIR/cancel-log"
COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/fake-image-provider.py" \
    COMICS_PROVIDER_WAIT_SECS=5 \
    COMICS_PROVIDER_GRACE_SECS=0.1 \
    COMICS_FAKE_PROVIDER_LOG_DIR="$CALLER_CANCEL_LOG" \
    COMICS_FAKE_PROVIDER_MODE=hang \
    COMICS_OUTPUT_DIR="$CALLER_TEST_DIR/cancel-output" \
    "$SCRIPT_DIR/generate-comic.sh" "Caller cancellation and reap" "caption" 4:3 1K >/dev/null 2>&1 &
CALLER_WRAPPER_PID=$!
for _ in {1..50}; do
    [[ -s "$CALLER_CANCEL_LOG/grandchild-pid.txt" ]] && break
    sleep 0.02
done
kill -TERM "$CALLER_WRAPPER_PID" 2>/dev/null || true
wait "$CALLER_WRAPPER_PID"
CALLER_CANCEL_STATUS=$?
[[ "$CALLER_CANCEL_STATUS" -eq 143 ]] || fail "provider caller wrapper did not classify cancellation as exit 143 (got $CALLER_CANCEL_STATUS)"
for pid_file in "$CALLER_CANCEL_LOG/provider-pid.txt" "$CALLER_CANCEL_LOG/grandchild-pid.txt"; do
    if [[ ! -s "$pid_file" ]]; then
        fail "provider cancellation fixture did not record $(basename "$pid_file")"
        continue
    fi
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
        fail "provider caller wrapper left process $pid alive after cancellation"
        kill -KILL "$pid" 2>/dev/null || true
    fi
done
find "$CALLER_TEST_DIR" -type f -delete
find "$CALLER_TEST_DIR" -depth -type d -empty -delete

if COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/noop-provider.py" \
    "$SCRIPT_DIR/generate-comic.sh" "Failure-path scene" "Failure-path caption" 4:3 1K >/dev/null 2>&1; then
    fail "generator accepted a successful provider exit with no new image"
fi

if COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/noop-provider.py" \
    "$SCRIPT_DIR/batch-generate.sh" "$REPO_ROOT/tests/fixtures/batch-one-concept.txt" >/dev/null 2>&1; then
    fail "batch generator concealed an item failure"
fi

if "$SCRIPT_DIR/batch-generate.sh" "$REPO_ROOT/tests/fixtures/empty-concepts.txt" >/dev/null 2>&1; then
    fail "batch generator accepted an empty concept file"
fi

BATCH_EDGE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comics-batch.XXXXXX")
printf 'First fixture concept\nSecond fixture concept' > "$BATCH_EDGE_DIR/no-trailing-newline.txt"
if COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/noop-provider.py" \
    "$SCRIPT_DIR/batch-generate.sh" "$BATCH_EDGE_DIR/no-trailing-newline.txt" > "$BATCH_EDGE_DIR/run.log" 2>&1; then
    fail "batch no-newline fixture unexpectedly succeeded despite forced provider failures"
fi
grep -Fq '2 attempted' "$BATCH_EDGE_DIR/run.log" || fail "batch skipped a final concept without a trailing newline"
find "$BATCH_EDGE_DIR" -type f -delete
find "$BATCH_EDGE_DIR" -depth -type d -empty -delete

FIXTURE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comics-production.XXXXXX")
if ! COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/fake-image-provider.py" \
    COMICS_OUTPUT_DIR="$FIXTURE_DIR" \
    "$SCRIPT_DIR/generate-comic.sh" 'Offline $(printf injected) `uname` $HOME scene' 'Literal $PATH caption' 4:3 1K >/dev/null 2>&1; then
    fail "offline generation, signing, and sidecar pipeline"
else
    SIGNED_COUNT=$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name '*_signed.png' | wc -l | tr -d ' ')
    SIDECAR_COUNT=$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name '*_signed.prompt.txt' | wc -l | tr -d ' ')
    [[ "$SIGNED_COUNT" -eq 1 ]] || fail "offline pipeline did not produce exactly one signed image"
    [[ "$SIDECAR_COUNT" -eq 1 ]] || fail "offline pipeline did not produce exactly one signed sidecar"
    RUN_DIR_COUNT=$(find "$FIXTURE_DIR" -maxdepth 1 -type d -name '.provider-run.*' | wc -l | tr -d ' ')
    [[ "$RUN_DIR_COUNT" -eq 1 ]] || fail "offline pipeline did not leave exactly one exclusive provider-run directory"
fi

FIXTURE_SIDECAR=$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name '*_signed.prompt.txt' -print | head -1)
grep -Fq 'Offline $(printf injected) `uname` $HOME scene' "$FIXTURE_SIDECAR" || fail "sidecar did not preserve literal shell metacharacters"
grep -Fq 'Literal $PATH caption' "$FIXTURE_SIDECAR" || fail "sidecar did not preserve literal caption metacharacters"


if COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/fake-image-provider.py" \
    COMICS_FAKE_IMAGE_COUNT=2 \
    COMICS_OUTPUT_DIR="$FIXTURE_DIR" \
    "$SCRIPT_DIR/generate-comic.sh" "Ambiguous output scene" "Ambiguous output caption" 4:3 1K >/dev/null 2>&1; then
    fail "generator accepted multiple new images from one provider invocation"
fi

STALE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comics-stale-parent.XXXXXX")
printf 'stale-canary\n' > "$STALE_DIR/offline_provider_fixture_1.jpg"
STALE_HASH=$(python3 -c 'import hashlib,pathlib,sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$STALE_DIR/offline_provider_fixture_1.jpg")
if COMICS_PROVIDER_CLI="$REPO_ROOT/tests/fixtures/fake-image-provider.py" \
    COMICS_OUTPUT_DIR="$STALE_DIR" \
    "$SCRIPT_DIR/generate-comic.sh" "Stale parent collision" "caption" 4:3 1K >/dev/null 2>&1; then
    fail "generator installed a raw render over a pre-existing parent file"
fi
AFTER_HASH=$(python3 -c 'import hashlib,pathlib,sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$STALE_DIR/offline_provider_fixture_1.jpg")
[[ "$STALE_HASH" == "$AFTER_HASH" ]] || fail "exclusive-dir install mutated a pre-existing parent image"
[[ ! -e "$STALE_DIR/offline_provider_fixture_1_signed.png" ]] || fail "stale-parent collision still produced a signed image"
find "$STALE_DIR" -type f -delete
find "$STALE_DIR" -depth -type d -empty -delete

FIXTURE_RAW=$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name 'offline_provider_fixture_1.jpg' -print | head -1)
FIXTURE_SIGNED=$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name 'offline_provider_fixture_1_signed.png' -print | head -1)
FIXTURE_SIDECAR=$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name 'offline_provider_fixture_1_signed.prompt.txt' -print | head -1)
if python3 "$SCRIPT_DIR/add-signature.py" "$FIXTURE_RAW" --output "$FIXTURE_SIGNED" >/dev/null 2>&1; then
    fail "signature helper overwrote an existing signed image without --force"
fi
if ! python3 "$SCRIPT_DIR/add-signature.py" "$FIXTURE_RAW" --output "$FIXTURE_SIGNED" --force >/dev/null 2>&1; then
    fail "signature helper --force did not permit explicit replacement"
fi

EXTRACT_TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comics-extract-signature.XXXXXX")
python3 - "$EXTRACT_TEST_DIR/all-white.png" <<'PY'
from PIL import Image
import sys
Image.new("RGB", (40, 40), (255, 255, 255)).save(sys.argv[1])
PY
if python3 "$SCRIPT_DIR/extract-signature.py" "$EXTRACT_TEST_DIR/all-white.png" "$EXTRACT_TEST_DIR/out.png" >/dev/null 2>&1; then
    fail "extract-signature accepted an all-white image with no dark pixels"
fi
python3 - "$EXTRACT_TEST_DIR/has-signature.png" <<'PY'
from PIL import Image, ImageDraw
import sys
img = Image.new("RGB", (60, 40), (255, 255, 255))
draw = ImageDraw.Draw(img)
draw.rectangle([10, 10, 30, 30], fill=(0, 0, 0))
img.save(sys.argv[1])
PY
if ! python3 "$SCRIPT_DIR/extract-signature.py" "$EXTRACT_TEST_DIR/has-signature.png" "$EXTRACT_TEST_DIR/extracted.png" >/dev/null 2>&1; then
    fail "extract-signature failed on a valid signature image"
fi
if python3 "$SCRIPT_DIR/extract-signature.py" "$EXTRACT_TEST_DIR/has-signature.png" "$EXTRACT_TEST_DIR/extracted.png" >/dev/null 2>&1; then
    fail "extract-signature overwrote an existing output without --force"
fi
find "$EXTRACT_TEST_DIR" -type f -delete
find "$EXTRACT_TEST_DIR" -depth -type d -empty -delete

PROCESS_TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comics-process-signature.XXXXXX")
cp "$REPO_ROOT/references/signature_transparent.png" "$PROCESS_TEST_DIR/input.png"
if ! python3 "$SCRIPT_DIR/process-signature.py" "$PROCESS_TEST_DIR/input.png" "$PROCESS_TEST_DIR/out.png" >/dev/null 2>&1; then
    fail "process-signature failed on a valid signature image"
fi
if python3 "$SCRIPT_DIR/process-signature.py" "$PROCESS_TEST_DIR/input.png" "$PROCESS_TEST_DIR/out.png" >/dev/null 2>&1; then
    fail "process-signature overwrote an existing output without --force"
fi
find "$PROCESS_TEST_DIR" -type f -delete
find "$PROCESS_TEST_DIR" -depth -type d -empty -delete

if python3 "$SCRIPT_DIR/add-caption.py" "$FIXTURE_RAW" "Invalid size fixture" --size 0 --output "$FIXTURE_DIR/invalid-caption.png" >/dev/null 2>&1; then
    fail "caption helper accepted a zero font size"
fi

if ! python3 "$SCRIPT_DIR/add-caption.py" "$FIXTURE_RAW" "Overwrite guard fixture" --output "$FIXTURE_DIR/caption-overwrite.png" >/dev/null 2>&1; then
    fail "caption helper failed on a valid caption request"
fi
if python3 "$SCRIPT_DIR/add-caption.py" "$FIXTURE_RAW" "Overwrite guard fixture" --output "$FIXTURE_DIR/caption-overwrite.png" >/dev/null 2>&1; then
    fail "caption helper overwrote an existing output without --force"
fi

PROMOTION_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comics-promotion.XXXXXX")
PROMOTION_PROTOTYPES="$PROMOTION_DIR/prototypes"
PROMOTION_FINALS="$PROMOTION_DIR/finals"
mkdir -p "$PROMOTION_PROTOTYPES" "$PROMOTION_FINALS"

cp "$FIXTURE_SIGNED" "$PROMOTION_PROTOTYPES/reviewed.png"
cp "$FIXTURE_SIDECAR" "$PROMOTION_PROTOTYPES/reviewed.prompt.txt"

if COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/reviewed.png" Invalid_Slug 2026-07-12 >/dev/null 2>&1; then
    fail "promotion accepted an invalid slug"
fi

if COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/reviewed.png" valid-slug 2026-02-30 >/dev/null 2>&1; then
    fail "promotion accepted an invalid calendar date"
fi

cp "$FIXTURE_SIGNED" "$PROMOTION_PROTOTYPES/incomplete.png"
cp "$REPO_ROOT/tests/fixtures/incomplete-sidecar.prompt.txt" "$PROMOTION_PROTOTYPES/incomplete.prompt.txt"
if COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/incomplete.png" incomplete-sidecar 2026-07-12 >/dev/null 2>&1; then
    fail "promotion accepted an incomplete sidecar"
fi

ln -s "$FIXTURE_SIGNED" "$PROMOTION_PROTOTYPES/symlink.png"
if COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/symlink.png" symlink-source 2026-07-12 >/dev/null 2>&1; then
    fail "promotion accepted a symlink source"
fi

cp "$FIXTURE_SIGNED" "$PROMOTION_PROTOTYPES/sidecar-link.png"
ln -s "$FIXTURE_SIDECAR" "$PROMOTION_PROTOTYPES/sidecar-link.prompt.txt"
if COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/sidecar-link.png" sidecar-symlink 2026-07-12 >/dev/null 2>&1; then
    fail "promotion accepted a symlink sidecar"
fi

mkdir -p "$PROMOTION_DIR/external"
cp "$FIXTURE_SIGNED" "$PROMOTION_DIR/external/intermediate.png"
cp "$FIXTURE_SIDECAR" "$PROMOTION_DIR/external/intermediate.prompt.txt"
ln -s "$PROMOTION_DIR/external" "$PROMOTION_PROTOTYPES/linked-date"
if COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/linked-date/intermediate.png" intermediate-symlink 2026-07-12 >/dev/null 2>&1; then
    fail "promotion accepted a source through a symlinked intermediate directory"
fi

if ! COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/reviewed.png" reviewed-fixture 2026-07-12 >/dev/null 2>&1; then
    fail "valid promotion fixture"
fi

cp "$FIXTURE_SIGNED" "$PROMOTION_PROTOTYPES/overwrite.png"
cp "$FIXTURE_SIDECAR" "$PROMOTION_PROTOTYPES/overwrite.prompt.txt"
if COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/overwrite.png" reviewed-fixture 2026-07-12 >/dev/null 2>&1; then
    fail "promotion overwrote an existing final"
fi

cp "$FIXTURE_SIGNED" "$PROMOTION_PROTOTYPES/rollback.png"
cp "$FIXTURE_SIDECAR" "$PROMOTION_PROTOTYPES/rollback.prompt.txt"
if COMICS_TEST_FAIL_SIDECAR_MOVE=1 COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/rollback.png" rollback-fixture 2026-07-12 >/dev/null 2>&1; then
    fail "promotion test hook did not force a sidecar failure"
fi
[[ -s "$PROMOTION_PROTOTYPES/rollback.png" ]] || fail "promotion did not roll back the image after sidecar failure"
[[ -s "$PROMOTION_PROTOTYPES/rollback.prompt.txt" ]] || fail "promotion disturbed the sidecar after rollback"
[[ ! -e "$PROMOTION_FINALS/2026-07-12_rollback-fixture.png" ]] || fail "promotion left a final image after rollback"

cp "$FIXTURE_SIGNED" "$PROMOTION_PROTOTYPES/image-move-failure.png"
cp "$FIXTURE_SIDECAR" "$PROMOTION_PROTOTYPES/image-move-failure.prompt.txt"
if COMICS_TEST_FAIL_IMAGE_MOVE=1 COMICS_PROTOTYPE_ROOT="$PROMOTION_PROTOTYPES" COMICS_FINAL_ROOT="$PROMOTION_FINALS" \
    "$SCRIPT_DIR/promote-final.sh" "$PROMOTION_PROTOTYPES/image-move-failure.png" image-move-failure 2026-07-12 >/dev/null 2>&1; then
    fail "promotion test hook did not force an image move failure"
fi
[[ -s "$PROMOTION_PROTOTYPES/image-move-failure.png" ]] || fail "image move failure disturbed the source image"
[[ -s "$PROMOTION_PROTOTYPES/image-move-failure.prompt.txt" ]] || fail "image move failure disturbed the source sidecar"
[[ ! -e "$PROMOTION_FINALS/2026-07-12_image-move-failure.png" ]] || fail "image move failure left a final image"

find "$FIXTURE_DIR" -type f -delete
find "$FIXTURE_DIR" -depth -type d -empty -delete
find "$PROMOTION_DIR" -type f -delete
find "$PROMOTION_DIR" -type l -delete
find "$PROMOTION_DIR" -depth -type d -empty -delete

if [[ -d "$REPO_ROOT/outputs/finals" ]]; then
    while IFS= read -r -d '' item; do
        is_allowed_final_entry "$item" || fail "unexpected file type in finals: $(basename "$item")"
    done < <(find "$REPO_ROOT/outputs/finals" -mindepth 1 -maxdepth 1 -print0)
fi

FINAL_COUNT=0
for image in "$REPO_ROOT"/outputs/finals/*.png; do
    [[ -e "$image" ]] || continue
    FINAL_COUNT=$((FINAL_COUNT + 1))
    sidecar="${image%.png}.prompt.txt"
    if [[ ! -s "$sidecar" ]]; then
        fail "missing prompt sidecar for $(basename "$image")"
        continue
    fi
    for heading in "CONCEPT:" "CAPTION:" "SOURCE OUTPUT:" "NOTES:"; do
        grep -q "^$heading$" "$sidecar" || fail "$(basename "$sidecar") missing $heading"
    done
done

for sidecar in "$REPO_ROOT"/outputs/finals/*.prompt.txt; do
    [[ -e "$sidecar" ]] || continue
    image="${sidecar%.prompt.txt}.png"
    [[ -s "$image" ]] || fail "orphan prompt sidecar: $(basename "$sidecar")"
done

if ! python3 - "$REPO_ROOT/outputs/finals" "$REPO_ROOT/references/signature_transparent.png" <<'PY'
from pathlib import Path
from PIL import Image
import sys

SUPPORTED_RATIOS = (4 / 3, 1.0, 9 / 16)


def validate_dimensions(label, width, height):
    if max(width, height) < 1000 or min(width, height) < 560:
        raise ValueError(f"undersized final: {label} ({width}x{height})")
    ratio = width / height
    if not any(abs(ratio - expected) / expected <= 0.03 for expected in SUPPORTED_RATIOS):
        raise ValueError(f"unsupported final aspect ratio: {label} ({width}x{height})")


# Regression coverage for every supported production aspect ratio at 1K scale.
validate_dimensions("4:3 fixture", 1024, 768)
validate_dimensions("1:1 fixture", 1024, 1024)
validate_dimensions("9:16 fixture", 576, 1024)
try:
    validate_dimensions("unsupported fixture", 1000, 2000)
except ValueError:
    pass
else:
    raise AssertionError("unsupported aspect ratio fixture was accepted")

paths = list(Path(sys.argv[1]).glob("*.png")) + [Path(sys.argv[2])]
for path in paths:
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        if path.parent.name == "finals" and image.format != "PNG":
            raise ValueError(f"final does not contain PNG data: {path}")
        if path.parent.name == "finals":
            validate_dimensions(path, image.width, image.height)
PY
then
    fail "image integrity or minimum final dimensions"
fi

if [[ "$FAILED" -gt 0 ]]; then
    echo "Production validation failed: $FAILED issue(s)." >&2
    exit 1
fi

echo "Production validation passed: $FINAL_COUNT finals, $STYLE_COUNT style references, generation/promotion/failure paths healthy."
