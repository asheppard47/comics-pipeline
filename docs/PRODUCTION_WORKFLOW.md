---
schema_version: 2
title: Comics Production Workflow
doc_type: detail
version: "1.5.0"
created: "2025-12-18"
last_updated: "2026-08-13"
last_audit: "2026-08-13"
audit_status: current
domain: personal
parent: INDEX.md
triggers:
  - "production workflow"
  - "comic pipeline"
  - "end-to-end comic"
---

# Comics Production Workflow

## End-to-End Pipeline

```
IDEA → BRAINSTORM → GRADE → USER CHOICE → GENERATE → REVIEW → PROMOTE → VALIDATE → HUMAN-APPROVED X HANDOFF
```

*Note: caption text is rendered directly by the image provider during generation, with no post-process step*
*Note: `comic-ideation` runs the ideation and grading stages, then pauses for the user to choose a caption before generation.*

---

## Stage 1: Concept Development

### Recommended: Comic Ideation Skill
Share a rough idea and the `comic-ideation` skill handles the interactive pipeline:
1. Brainstorms 5 caption variations (varied length/tone)
2. Sends the document to 5 models of your choice for grading
3. Compiles ranked results with averages
4. Presents results and waits for the user's caption selection
5. Generates only after selection; optional X copy follows final approval

### Writing a Good Concept
Structure: **WHO** + **WHERE** + **WHAT** (+ implied punchline)

**Examples**:
- "Two cats in a therapist's office, one cat is the therapist"
- "Person at ATM with angel and devil on their shoulders"
- "Dog at job interview wearing a tie"

### Concept Bank
Store ideas in `captions/caption-bank.md` organized by theme:
- Modern Life / Technology
- Work / Office
- Relationships
- Animals
- Existential / Absurd

---

## Stage 2: Generation

### Single Comic (Basic)
```bash
./scripts/generate-comic.sh "Your concept description here"
```

### Single Comic with Caption (Recommended)
Pass the scene and caption as separate arguments so the prompt sidecar records
them separately:
```bash
./scripts/generate-comic.sh "Two robots watching humans type" "Your caption here"
```

Do not put caption or signature instructions inside the scene description. The
generator adds both instructions and records the caption separately.

**What happens**:
1. The configured image provider renders the illustration with the caption
2. The approved style prompt and default visual reference are applied
3. The signature image is added to top-right (9% width)
4. Signed output and matching `.prompt.txt` sidecar are saved together under `outputs/prototypes/YYYY-MM-DD/`

The generator accepts exactly one raw image from each provider invocation. Zero or
multiple new images fail closed before signing or sidecar creation. Existing
signed paths are never replaced implicitly.

### Options
```bash
# Different aspect ratio
./scripts/generate-comic.sh "concept" "caption" 1:1      # Instagram square
./scripts/generate-comic.sh "concept" "caption" 9:16     # Story format

# Different quality
./scripts/generate-comic.sh "concept" "caption" 4:3 4K   # Higher resolution

# No caption with a non-default aspect ratio requires an explicit empty slot
./scripts/generate-comic.sh "concept" "" 1:1 2K

# Offline request validation; no model call and no files written
./scripts/generate-comic.sh --dry-run "concept" "caption" 4:3 2K
```

### Batch Generation
Create a file with one concept per line:
```
# concepts.txt
Two cats at therapist, one is therapist
Person at ATM with angel and devil
Dog at job interview wearing tie
```

Run batch:
```bash
./scripts/batch-generate.sh concepts.txt
```

Batch mode rejects a file with no runnable concepts, isolates the generator's
stdin from the concept reader, processes the final concept even when the file
has no trailing newline, and exits non-zero if any item fails or attempted-count
accounting diverges.

---

## Stage 3: Review

### Quality Checklist
- [ ] **Line work**: Clean, consistent weight
- [ ] **Composition**: Balanced, not cluttered
- [ ] **Characters**: Expressive, naturalistic
- [ ] **Caption space**: Clear white area at bottom
- [ ] **Signature**: Properly placed, visible
- [ ] **Text integrity**: Caption is exact; no stray labels or malformed words
- [ ] **Signature integrity**: No second model-generated signature or artist mark
- [ ] **Provenance**: Signed image has a non-empty matching `.prompt.txt` sidecar

### If Iteration Needed
Re-run with modified concept:
```bash
# More specific
./scripts/generate-comic.sh "Two cats in therapist office, one cat wearing glasses sitting in chair with notepad, other cat on couch looking anxious"

# Different angle
./scripts/generate-comic.sh "Dog at job interview, viewed from behind interviewer's desk"
```

---

## Stage 4: Caption Fallback

The image provider normally renders the caption during generation. Use this only for an
existing image that genuinely lacks a caption; record the post-generation edit
in the prompt sidecar.

### Add Caption to Signed Image
```bash
python3 scripts/add-caption.py \
  outputs/prototypes/2025-12-18/comic_signed.png \
  "Your caption text here"
```

### Options
```bash
# Custom font size (the default is 3.5% of image height)
python3 scripts/add-caption.py image.png "Caption" --size 40

# Explicit cross-platform serif font
python3 scripts/add-caption.py image.png "Caption" --font /path/to/serif-font.ttf

# Custom output path inside prototypes; never bypass guarded promotion
python3 scripts/add-caption.py image.png "Caption" --output outputs/prototypes/2026-07-12/example_captioned.png
```

### Caption Writing Tips
- Keep it short (one sentence)
- Dry delivery - state absurd as normal
- Don't explain the joke
- Consider what the character would actually say

---

## Stage 5: Finalize

### Guarded Promotion — image + prompt sidecar together
`generate-comic.sh` writes a `.prompt.txt` sidecar (concept, caption, full prompt,
command, source filename) next to every render. Promoting a render to finals means
moving exactly one reviewed pair. Use the promotion script:

```bash
./scripts/promote-final.sh \
  outputs/prototypes/2026-07-12/comic_signed.png \
  concept-slug
```

The script validates the reviewed PNG and sidecar headings, refuses paths outside
`outputs/prototypes/` after physical path resolution, rejects symlinked sources,
and refuses to overwrite any existing final. If the sidecar move fails after the
image move, the image is rolled back to prototypes. Do not use manual `mv`
commands or globs for promotion.

**A final without its `.prompt.txt` sidecar is incomplete.** If the winning render's
sidecar is missing (pre-2026-07-07 renders, external edits like gpt-image fixes),
reconstruct it from session context before closing out: CONCEPT, CAPTION,
GENERATION COMMAND, and NOTES on any post-generation edits.

Run the offline contract check after promotion:

```bash
./scripts/validate-production.sh
```

Current final/sidecar counts and the last validator run live in
`AGENTS.md` § Production Integrity Gate, not here. The published June 26
AI-regulation comic was restored from its verified X-recovered media with an
honestly reconstructed provenance record.

### Naming Convention
```
YYYY-MM-DD_short-description.png
YYYY-MM-DD_short-description.prompt.txt
```
Examples:
- `2025-12-18_cat-therapist.png` + `2025-12-18_cat-therapist.prompt.txt`
- `2025-12-18_atm-angel-devil.png` + `2025-12-18_atm-angel-devil.prompt.txt`

### Location (MANDATORY)
Finals live in the repository under `outputs/finals/`, tracked in git. Do not
promote finals into a synced or scratch copy of the tree; it drifts from the
repository.

---

## Stage 7: Archive And Style Curation

### Save Reference Images
If a comic demonstrates a reusable visual quality, review its unsigned original,
give the anchor a purpose-based name, and document it in
`references/style/README.md`:
```bash
cp outputs/prototypes/YYYY-MM-DD/unsigned-source.jpg \
  references/style/purpose-based-style-anchor.jpg
```

### Clean Up Prototypes
Do not bulk-move signed renders into finals and do not delete raw renders as part
of promotion. `promote-final.sh` moves only the selected signed image and its
sidecar. Preserve active style-search experiments; review older prototype bulk
separately when it is genuinely stale.

---

## Script Reference

### generate-comic.sh
```bash
./scripts/generate-comic.sh [--dry-run] "concept" ["caption"] [aspect] [size]
```
- **concept**: Scene description (required)
- **caption**: Caption rendered by the image provider (optional; use `""` to skip it while setting later arguments)
- **aspect**: 4:3 (default), 1:1, 9:16
- **size**: 2K (default), 1K, 4K
- **--dry-run**: Validate and print the request without an API call or file write
- Calls `scripts/chassis/run-image-provider` and `write-literal-file` internally. The New Yorker prompt, signature, and sidecar headings stay here. See `docs/chassis-spec.md`.

### add-caption.py
```bash
python3 scripts/add-caption.py input.png "caption" [options]
```
- **--size**: Font size in pixels (default: 3.5% of image height)
- **--font**: Explicit TrueType/OpenType serif font; the command fails rather
  than silently using Pillow's tiny bitmap fallback when no production font exists
- **--output**: Output path (default: input_captioned.png)
- **--force**: Explicitly permit replacement; production generation never uses it

### add-signature.py
```bash
python3 scripts/add-signature.py input.png [options]
```
- **--position**: bottom-right, bottom-left, top-right (default), top-left
- **--size**: Signature width as % of image (default: 9)
- **--output**: Output path
- **--force**: Explicitly permit replacement; production generation never uses it

### batch-generate.sh
```bash
./scripts/batch-generate.sh concepts.txt
```
- One concept per line
- Lines starting with # are comments
- Final concept is processed even without a trailing newline
- 2-second delay between generations
- Returns non-zero if any item fails and prints succeeded/failed counts
- Returns non-zero when the file contains no runnable concepts
- `--help`/`-h` prints usage and exits 0

### promote-final.sh
```bash
./scripts/promote-final.sh SOURCE_PNG purpose-slug [YYYY-MM-DD]
```
- Requires a reviewed PNG and matching prompt sidecar under `outputs/prototypes/`
- Refuses invalid slugs, missing provenance, and overwrite
- After those checks, emits a two-entry cartoon manifest and calls `scripts/chassis/promote-manifest`
- Rolls back the image move if the sidecar move fails

### daily-comic-desk
Interactive skill. Pulse → risk kill → the operator picks or kills →
`comic-ideation` → archive bar → two `generate-comic.sh` renders → promote.
Packet: `outputs/prototypes/YYYY-MM-DD/desk/packet.md`.
`python3 scripts/check-desk-packet.py --packet PATH` checks structure only.

### validate-production.sh
```bash
./scripts/validate-production.sh
```
- Offline only: shell/Python syntax, dry-run, assets, sidecars, and image integrity
- Exercises ambiguous render rejection, signature overwrite refusal, promotion
  validation/overwrite/rollback guards, supported aspect ratios, unexpected
  finals file types, chassis primitives, and exclusive provider-run directories
- Makes no model call and does not publish

### extract-signature.py
```bash
python3 scripts/extract-signature.py input.jpg output.png [--threshold 220]
```
- Extracts a signature from a generated image
- Makes the background transparent with a luminance key. Generating the signature with real alpha is preferable when your provider supports it.
- **--force**: Explicitly permit replacement; production generation never uses it
- Exits non-zero when no pixels fall below the threshold, rather than producing an inverted crop

### process-signature.py
```bash
python3 scripts/process-signature.py input.png output.png --style marker
```
- Signature-development utility for adding felt-tip/brush stroke treatment
- Not used by the production generation path; `references/signature_transparent.png`
  remains the locked production asset
- **--force**: Explicitly permit replacement; production generation never uses it
- **--variation**: Edge variation amount 0-1 (default: 0.25)

---

## Troubleshooting

### Generation Issues

**Problem**: Comic doesn't match style
**Solution**: Run `validate-production.sh`, then verify both the canonical prompt
and `references/style/clean-office-linework.jpg`. Use a different approved
anchor only through `COMICS_STYLE_REFERENCE`.

**Problem**: Signature not appearing
**Solution**: Verify `references/signature_transparent.png` exists

**Problem**: Caption text looks wrong
**Solution**: Regenerate with the exact caption as the second generator argument.
For a manual fallback, run `add-caption.py` on a prototype and record that edit
in its prompt sidecar before promotion.

**Problem**: Manual captioning reports that no production serif font exists
**Solution**: Install Georgia or pass a known TrueType/OpenType serif font with
`--font`. The helper intentionally fails instead of silently rendering a tiny
bitmap fallback.

### Rate Limiting

Your image provider has rate limits. If you hit them:
- Wait 60 seconds between retries
- Retry individual failures deliberately; batch mode reports failures but does not conceal rate limits
- Reduce generation frequency

### File Size

Generated images can be large (2-5MB). For sharing:
```bash
# Compress for web
python3 - <<'PY'
from PIL import Image
image = Image.open("large_image.png")
image.thumbnail((1600, 1600))
image.save("large_image_web.png", optimize=True)
PY
```

---

## Quick Reference

```bash
# Full workflow example

# 1. Develop concept and caption
CONCEPT="Dog at job interview wearing tie"
CAPTION="My greatest weakness is excessive loyalty"

# 2. Validate the request offline, then generate with separate caption metadata
./scripts/generate-comic.sh --dry-run "$CONCEPT" "$CAPTION" 4:3 2K
./scripts/generate-comic.sh "$CONCEPT" "$CAPTION" 4:3 2K

# 3. Review output
open outputs/prototypes/$(date +%Y-%m-%d)/

# 4. Promote exactly the reviewed signed render and validate all finals
./scripts/promote-final.sh \
  outputs/prototypes/$(date +%Y-%m-%d)/REVIEWED_RENDER_signed.png \
  dog-interview
./scripts/validate-production.sh
```
