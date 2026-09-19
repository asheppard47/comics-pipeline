#!/bin/bash
# generate-comic.sh - Generate single-panel New Yorker style comic
# Usage: ./generate-comic.sh [--dry-run] "concept description" ["caption"] [aspect_ratio] [size]
# Examples:
#   ./generate-comic.sh "Man at ATM with angel and devil on shoulders"
#   ./generate-comic.sh "Two cats at therapist office" "We need to talk about the scratching."
#   ./generate-comic.sh "Person at coffee shop" "caption text" 1:1 4K

usage() {
    echo "Usage: ./generate-comic.sh [--dry-run] \"concept description\" [\"caption\"] [aspect_ratio] [size]"
    echo ""
    echo "Generates a single-panel New Yorker-style comic via Gemini Image Pro."
    echo "When a caption is provided, the image model renders it directly in the"
    echo "panel; this script then auto-adds the production signature."
    echo ""
    echo "Arguments:"
    echo "  concept description   Scene description (who, where, action) [required]"
    echo "  caption                Caption text to render at bottom [optional]"
    echo "  aspect_ratio           4:3 (default), 1:1, 9:16 [optional]"
    echo "  size                   Image size, e.g. 2K (default), 4K [optional]"
    echo "  --dry-run              Validate and print the production request without calling provider"
    echo ""
    echo "Environment:"
    echo "  COMICS_PROVIDER_CLI                   Image-provider CLI adapter (see providers/README.md)"
    echo "  COMICS_SIGNATURE                    Signature PNG to apply (default: references/signature_transparent.png)"
    echo "  COMICS_STYLE_REFERENCE              Style anchor image (default: references/style/clean-office-linework.jpg)"
    echo "  COMICS_PROVIDER_ROUTE               Provider route passed to the adapter (default: gemini-image)"
    echo "  COMICS_OUTPUT_DIR                   Output directory override"
    echo "  COMICS_PROVIDER_WAIT_SECS          Finite provider wait (default: 1900)"
    echo "  COMICS_PROVIDER_GRACE_SECS   TERM-to-KILL cleanup grace (default: 5)"
    echo ""
    echo "Examples:"
    echo "  ./generate-comic.sh \"Man at ATM with angel and devil on shoulders\""
    echo "  ./generate-comic.sh \"Two cats at therapist office\" \"We need to talk about the scratching.\""
    echo "  ./generate-comic.sh \"Person at coffee shop\" \"caption text\" 1:1 4K"
}

set -u
set -o pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

CONCEPT="${1:-}"
CAPTION="${2:-}"
ASPECT="${3:-4:3}"
SIZE="${4:-2K}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Write outputs inside the repo (SCRIPT_DIR/../outputs).
# outputs/prototypes/ is gitignored work-in-progress; finals are tracked.
# COMICS_OUTPUT_DIR overrides the destination (offline validation harness).
OUTPUT_DIR="${COMICS_OUTPUT_DIR:-$SCRIPT_DIR/../outputs/prototypes/$(date +%Y-%m-%d)}"
SIGNATURE="${COMICS_SIGNATURE:-$SCRIPT_DIR/../references/signature_transparent.png}"
# Image-provider CLI adapter. Point COMICS_PROVIDER_CLI at your own adapter;
# see providers/README.md for the required command contract.
PROVIDER_CLI="${COMICS_PROVIDER_CLI:-$SCRIPT_DIR/../providers/image-cli}"
STYLE_REFERENCE="${COMICS_STYLE_REFERENCE:-$SCRIPT_DIR/../references/style/clean-office-linework.jpg}"
PROVIDER_ROUTE="${COMICS_PROVIDER_ROUTE:-gemini-image}"

if [[ -z "$CONCEPT" ]]; then
    usage
    exit 1
fi

case "$ASPECT" in
    4:3|1:1|9:16) ;;
    *) echo "ERROR: unsupported aspect ratio '$ASPECT' (expected 4:3, 1:1, or 9:16)." >&2; exit 1 ;;
esac

case "$SIZE" in
    1K|2K|4K) ;;
    *) echo "ERROR: unsupported image size '$SIZE' (expected 1K, 2K, or 4K)." >&2; exit 1 ;;
esac

if [[ ! -f "$SIGNATURE" ]]; then
    echo "ERROR: production signature not found: $SIGNATURE" >&2
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/add-signature.py" ]]; then
    echo "ERROR: signature helper not found: $SCRIPT_DIR/add-signature.py" >&2
    exit 1
fi

if [[ ! -f "$STYLE_REFERENCE" ]]; then
    echo "ERROR: approved style reference not found: $STYLE_REFERENCE" >&2
    exit 1
fi

CHASSIS_DIR="$SCRIPT_DIR/chassis"
for chassis in write-literal-file run-image-provider; do
    if [[ ! -f "$CHASSIS_DIR/$chassis" ]]; then
        echo "ERROR: chassis helper not found: $CHASSIS_DIR/$chassis" >&2
        exit 1
    fi
done

# Locked style prompt - refined for New Yorker aesthetic.
# COMICS_STYLE_PROMPT is a per-invocation opt-in override (same pattern as
# COMICS_STYLE_REFERENCE): unset leaves the locked default untouched for
# every normal run; set it only for a deliberate, explicitly-requested
# one-off style break (e.g. a painting-parody piece that must match the
# source artwork's actual medium instead of the house ink-line look).
STYLE_PROMPT="${COMICS_STYLE_PROMPT:-Single-panel cartoon in sophisticated New Yorker magazine style. Use the attached approved reference only for line quality, restrained shading, naturalistic character proportions, and caption treatment; do not reproduce its subject, layout, text, or signature. Clean black ink line work on white background with minimal crosshatching. Strictly black and white with light grey wash only; no color of any kind. Static composition with economical linework and no motion lines. Contemporary metropolitan setting. When two or more foreground characters appear, each must be visibly distinct in age, build, hair, and clothing. Keep incidental insignia such as crests, logos, and badges small and pocket-scale, never enlarged into a floating badge or given a face. Do not draw or imitate an artist signature because the production signature is applied separately.}"

# Caption instruction (Gemini renders text well)
if [[ -n "$CAPTION" ]]; then
    CAPTION_PROMPT=" Caption text at bottom in classic New Yorker italic serif font reads: \"$CAPTION\""
else
    CAPTION_PROMPT=""
fi

FULL_PROMPT="$CONCEPT. $STYLE_PROMPT$CAPTION_PROMPT"

echo "Generating comic..."
echo "  Concept: $CONCEPT"
[[ -n "$CAPTION" ]] && echo "  Caption: $CAPTION"
echo "  Aspect: $ASPECT"
echo "  Size: $SIZE"
echo "  Style reference: $STYLE_REFERENCE"
echo "  Output: $OUTPUT_DIR"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY RUN: no API call or output write performed."
    echo "Full prompt: $FULL_PROMPT"
    exit 0
fi

if [[ ! -f "$PROVIDER_CLI" ]]; then
    echo "ERROR: image-provider CLI not found: $PROVIDER_CLI" >&2
    echo "Set COMICS_PROVIDER_CLI to your provider adapter; see providers/README.md." >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

PROMPT_FILE="$OUTPUT_DIR/.chassis-prompt-$$.txt"
PROVIDER_JSON="$OUTPUT_DIR/.chassis-result-$$.json"
PROVIDER_SUPERVISOR_PID=""
cleanup_chassis_temps() {
    [[ -e "$PROMPT_FILE" ]] && rm -f "$PROMPT_FILE"
    [[ -e "$PROVIDER_JSON" ]] && rm -f "$PROVIDER_JSON"
}
cancel_provider_supervisor() {
    local signal_name="$1"
    local exit_status="$2"
    if [[ -n "$PROVIDER_SUPERVISOR_PID" ]] && kill -0 "$PROVIDER_SUPERVISOR_PID" 2>/dev/null; then
        kill -"$signal_name" "$PROVIDER_SUPERVISOR_PID" 2>/dev/null || true
        wait "$PROVIDER_SUPERVISOR_PID" 2>/dev/null || true
    fi
    exit "$exit_status"
}
trap cleanup_chassis_temps EXIT
trap 'cancel_provider_supervisor INT 130' INT
trap 'cancel_provider_supervisor TERM 143' TERM

if ! printf '%s' "$FULL_PROMPT" | python3 "$CHASSIS_DIR/write-literal-file" --output "$PROMPT_FILE"; then
    echo "ERROR: could not write provider prompt file: $PROMPT_FILE" >&2
    exit 1
fi

python3 "$CHASSIS_DIR/run-image-provider" \
    --provider-cli "$PROVIDER_CLI" \
    --prompt-file "$PROMPT_FILE" \
    --style-reference "$STYLE_REFERENCE" \
    --provider-route "$PROVIDER_ROUTE" \
    --aspect-ratio "$ASPECT" \
    --image-size "$SIZE" \
    --output-parent "$OUTPUT_DIR" \
    > "$PROVIDER_JSON" &
PROVIDER_SUPERVISOR_PID=$!
wait "$PROVIDER_SUPERVISOR_PID"
PROVIDER_STATUS=$?
PROVIDER_SUPERVISOR_PID=""

if [[ "$PROVIDER_STATUS" -ne 0 ]]; then
    echo "ERROR: image generation failed with exit $PROVIDER_STATUS." >&2
    exit "$PROVIDER_STATUS"
fi

if ! LATEST="$(python3 - "$PROVIDER_JSON" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text())
image = payload.get("image")
if not isinstance(image, str) or not image:
    raise SystemExit("provider result missing image path")
print(image)
PY
)"; then
    echo "ERROR: could not parse provider result: $PROVIDER_JSON" >&2
    exit 1
fi

INSTALLED="$OUTPUT_DIR/$(basename "$LATEST")"
if ! python3 "$CHASSIS_DIR/write-literal-file" --output "$INSTALLED" < "$LATEST"; then
    echo "ERROR: refusing to install raw render over an existing path: $INSTALLED" >&2
    echo "Nothing to sign or log — not writing a sidecar for a stale/missing render." >&2
    exit 1
fi
if ! rm -f "$LATEST"; then
    echo "ERROR: installed raw render but could not remove it from the provider run directory." >&2
    exit 1
fi
LATEST="$INSTALLED"
trap - INT TERM

echo ""
echo "Adding signature..."
SIGNED="${LATEST%.*}_signed.png"
if ! python3 "$SCRIPT_DIR/add-signature.py" "$LATEST" --output "$SIGNED" --size 9 --position top-right; then
    echo "ERROR: signature application failed; no prompt sidecar was written." >&2
    exit 1
fi
if [[ ! -s "$SIGNED" ]]; then
    echo "ERROR: signature command returned success but produced no signed image: $SIGNED" >&2
    exit 1
fi
echo ""
echo "Final output: $SIGNED"

# Persist the generation prompt as a sidecar next to the FINAL output (the
# signed file when one exists, matching whatever "Final output:" reported
# above — not the pre-signature raw render).
# When a render is promoted to outputs/finals/, move this sidecar with it
# (renamed to match the final slug: YYYY-MM-DD_slug.prompt.txt).
FINAL_IMAGE="$SIGNED"
PROMPT_SIDECAR="${FINAL_IMAGE%.*}.prompt.txt"
CAPTION_VALUE="${CAPTION:-(none)}"
SOURCE_BASENAME="$(basename "$FINAL_IMAGE")"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"
if ! {
    printf 'CONCEPT:\n%s\n\n' "$CONCEPT"
    printf 'CAPTION:\n%s\n\n' "$CAPTION_VALUE"
    printf 'GENERATION COMMAND:\n'
    printf './scripts/generate-comic.sh "<CONCEPT above>" "<CAPTION above>" %s %s\n\n' "$ASPECT" "$SIZE"
    printf 'FULL PROMPT SENT:\n%s\n\n' "$FULL_PROMPT"
    printf 'STYLE REFERENCE:\n%s\n\n' "$STYLE_REFERENCE"
    printf 'SOURCE OUTPUT:\n%s\n\n' "$SOURCE_BASENAME"
    printf 'GENERATED:\n%s\n\n' "$GENERATED_AT"
    printf '%s\n' 'NOTES:'
    printf '%s\n' '- gemini-image generation is stochastic; re-running verbatim is not guaranteed'
    printf '%s\n' '  to reproduce this result.'
} | python3 "$CHASSIS_DIR/write-literal-file" --output "$PROMPT_SIDECAR"
then
    echo "ERROR: could not write prompt sidecar: $PROMPT_SIDECAR" >&2
    exit 1
fi
echo "Prompt sidecar: $PROMPT_SIDECAR"
