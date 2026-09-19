#!/bin/bash
# Promote one reviewed prototype PNG and its prompt sidecar into finals.

set -u

usage() {
    echo "Usage: ./scripts/promote-final.sh SOURCE_PNG SLUG [YYYY-MM-DD]"
    echo "Example: ./scripts/promote-final.sh outputs/prototypes/2026-07-12/example_signed.png example-slug"
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

SOURCE="${1:-}"
SLUG="${2:-}"
FINAL_DATE="${3:-$(date +%Y-%m-%d)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# Root overrides are reserved for the offline validation harness.
PROTOTYPE_ROOT="${COMICS_PROTOTYPE_ROOT:-$REPO_ROOT/outputs/prototypes}"
FINAL_ROOT="${COMICS_FINAL_ROOT:-$REPO_ROOT/outputs/finals}"

if [[ ! -d "$PROTOTYPE_ROOT" ]]; then
    echo "ERROR: prototype root not found: $PROTOTYPE_ROOT" >&2
    exit 1
fi
PROTOTYPE_ROOT="$(cd "$PROTOTYPE_ROOT" && pwd -P)"
mkdir -p "$FINAL_ROOT"
FINAL_ROOT="$(cd "$FINAL_ROOT" && pwd -P)"

if [[ -z "$SOURCE" || -z "$SLUG" ]]; then
    usage
    exit 1
fi

if [[ ! "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "ERROR: slug must use lowercase words separated by hyphens." >&2
    exit 1
fi

if [[ ! "$FINAL_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: date must be YYYY-MM-DD." >&2
    exit 1
fi

if ! python3 - "$FINAL_DATE" <<'PY'
from datetime import date
import sys

date.fromisoformat(sys.argv[1])
PY
then
    echo "ERROR: date is not a real calendar date: $FINAL_DATE" >&2
    exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
    echo "ERROR: source image not found: $SOURCE" >&2
    exit 1
fi

if [[ -L "$SOURCE" ]]; then
    echo "ERROR: source image must be a regular file, not a symlink." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$(dirname "$SOURCE")" && pwd -P)"
SOURCE_ABS="$SOURCE_DIR/$(basename "$SOURCE")"
case "$SOURCE_ABS" in
    "$PROTOTYPE_ROOT"/*) ;;
    *) echo "ERROR: source must be inside $PROTOTYPE_ROOT" >&2; exit 1 ;;
esac

case "$SOURCE_ABS" in
    *.png) ;;
    *) echo "ERROR: source must be a reviewed PNG." >&2; exit 1 ;;
esac

SIDECAR="${SOURCE_ABS%.png}.prompt.txt"
if [[ -L "$SIDECAR" ]]; then
    echo "ERROR: matching prompt sidecar must be a regular file, not a symlink." >&2
    exit 1
fi
if [[ ! -s "$SIDECAR" ]]; then
    echo "ERROR: matching prompt sidecar is missing or empty: $SIDECAR" >&2
    exit 1
fi

for heading in "CONCEPT:" "CAPTION:" "SOURCE OUTPUT:" "NOTES:"; do
    if ! grep -q "^$heading$" "$SIDECAR"; then
        echo "ERROR: sidecar is missing required heading $heading" >&2
        exit 1
    fi
done

TARGET_IMAGE="$FINAL_ROOT/${FINAL_DATE}_${SLUG}.png"
TARGET_SIDECAR="$FINAL_ROOT/${FINAL_DATE}_${SLUG}.prompt.txt"
if [[ -e "$TARGET_IMAGE" || -e "$TARGET_SIDECAR" ]]; then
    echo "ERROR: refusing to overwrite an existing final or sidecar." >&2
    exit 1
fi

if ! python3 - "$SOURCE_ABS" <<'PY'
from PIL import Image
import sys

with Image.open(sys.argv[1]) as image:
    image.verify()
PY
then
    echo "ERROR: source is not a readable image." >&2
    exit 1
fi

CHASSIS_PROMOTE="$SCRIPT_DIR/chassis/promote-manifest"
if [[ ! -f "$CHASSIS_PROMOTE" ]]; then
    echo "ERROR: chassis helper not found: $CHASSIS_PROMOTE" >&2
    exit 1
fi

MANIFEST="$(mktemp "${TMPDIR:-/tmp}/comics-promote-manifest.XXXXXX")"
if ! python3 - "$SOURCE_ABS" "$SIDECAR" "$(basename "$TARGET_IMAGE")" "$(basename "$TARGET_SIDECAR")" "$MANIFEST" <<'PY'
import hashlib
import json
import os
import sys

image_path, sidecar_path, dest_image, dest_sidecar, manifest_path = sys.argv[1:6]


def record(path):
    with open(path, "rb") as handle:
        body = handle.read()
    return len(body), hashlib.sha256(body).hexdigest()


image_size, image_digest = record(image_path)
sidecar_size, sidecar_digest = record(sidecar_path)
item_id = dest_image[:-4] if dest_image.endswith(".png") else dest_image
payload = {
    "schema_version": 1,
    "lane": "cartoon",
    "mode": "flat-set",
    "item_id": item_id,
    "entries": [
        {
            "role": "image",
            "source": os.path.basename(image_path),
            "destination": dest_image,
            "size": image_size,
            "sha256": image_digest,
        },
        {
            "role": "sidecar",
            "source": os.path.basename(sidecar_path),
            "destination": dest_sidecar,
            "size": sidecar_size,
            "sha256": sidecar_digest,
        },
    ],
}
with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY
then
    rm -f "$MANIFEST"
    echo "ERROR: could not write cartoon promotion manifest." >&2
    exit 1
fi

python3 "$CHASSIS_PROMOTE" \
    --manifest "$MANIFEST" \
    --source-root "$SOURCE_DIR" \
    --destination-root "$FINAL_ROOT"
PROMOTE_STATUS=$?
rm -f "$MANIFEST"
if [[ "$PROMOTE_STATUS" -ne 0 ]]; then
    exit "$PROMOTE_STATUS"
fi

echo "Promoted final: $TARGET_IMAGE"
echo "Prompt sidecar: $TARGET_SIDECAR"
