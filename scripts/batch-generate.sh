#!/bin/bash
# batch-generate.sh - Generate multiple comics from concept file
# Usage: ./batch-generate.sh concepts.txt
# File format: One concept per line, # for comments, blank lines ignored

usage() {
    echo "Usage: ./batch-generate.sh concepts.txt"
    echo ""
    echo "File format (one concept per line):"
    echo "  # This is a comment"
    echo "  Man waiting for elevator, checking watch"
    echo "  Two cats at therapist, one is the therapist"
}

set -u

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

CONCEPT_FILE="${1:-}"

if [[ -z "$CONCEPT_FILE" || ! -f "$CONCEPT_FILE" ]]; then
    usage
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COUNT=0
TOTAL=$(awk '!/^[[:space:]]*(#|$)/ { count++ } END { print count + 0 }' "$CONCEPT_FILE")
FAILED=0

if [[ "$TOTAL" -eq 0 ]]; then
    echo "ERROR: concept file contains no runnable concepts: $CONCEPT_FILE" >&2
    exit 1
fi

echo "Batch generating $TOTAL comics..."
echo ""

while IFS= read -r concept || [[ -n "$concept" ]]; do
    # Skip comments and empty lines
    [[ "$concept" =~ ^[[:space:]]*$ || "$concept" =~ ^[[:space:]]*# ]] && continue

    COUNT=$((COUNT + 1))
    echo "[$COUNT/$TOTAL] $concept"

    if ! "$SCRIPT_DIR/generate-comic.sh" "$concept" </dev/null; then
        echo "ERROR: generation failed for item $COUNT: $concept" >&2
        FAILED=$((FAILED + 1))
    fi

    # Rate limiting between API calls
    if [[ $COUNT -lt $TOTAL ]]; then
        echo "Waiting 2 seconds..."
        sleep 2
    fi
    echo ""
done < "$CONCEPT_FILE"

SUCCEEDED=$((COUNT - FAILED))
echo "Batch complete: $SUCCEEDED succeeded, $FAILED failed, $COUNT attempted"

if [[ "$COUNT" -ne "$TOTAL" ]]; then
    echo "ERROR: batch accounting mismatch: expected $TOTAL concepts, attempted $COUNT." >&2
    exit 1
fi

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
