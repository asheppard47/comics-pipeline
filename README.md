# Comics pipeline

An agent-driven pipeline for single-panel, New Yorker-style cartoons. Idea to
caption to rendered panel to signed final, with offline contract validation
along the way.

The pipeline is bash plus Python. It has no service dependencies and takes its
image generation from a CLI adapter you supply, so the same scripts work
against any image model that can follow a prompt.

## Pipeline

1. **Concept**: write the scene (who, where, what action) and the caption.
2. **Generate**: the image model renders the caption inside the panel, then the
   script applies the signature image.
3. **Review**: check line quality, composition, and caption placement.
4. **Promote**: move the reviewed image and its prompt sidecar into the finals
   tree. Promotion refuses to overwrite an existing final.
5. **Validate**: run the offline production contract checks.

## Requirements

- bash and Python 3
- Pillow (`python3 -m pip install Pillow`) for the caption, signature, and
  validation helpers
- an image-provider CLI adapter (see `providers/README.md`)
- a signature image at `references/signature_transparent.png`. The repository
  ships a placeholder; replace it with your own (see below).

## Quick start

```bash
# 1. Point the pipeline at your image-provider CLI.
export COMICS_PROVIDER_CLI=/path/to/your/image-cli

# 2. Create your signature asset (replace the placeholder).
#    Draw or generate a signature on white, then extract it with a
#    transparent background:
python3 scripts/extract-signature.py my-signature.jpg references/signature_transparent.png

# 3. Generate a signed, captioned panel.
./scripts/generate-comic.sh "Man at an ATM with an angel and a devil on his shoulders" \
  "The fee is for emotional labor."

# 4. Check the output, then promote the reviewed image.
./scripts/promote-final.sh outputs/prototypes/YYYY-MM-DD/<file>_signed.png purpose-slug

# 5. Run the offline production contract checks.
./scripts/validate-production.sh
```

`./scripts/generate-comic.sh --dry-run "concept" "caption" 4:3 2K` prints the
exact prompt and request without calling the provider or writing files.

## Layout

```
.
├── scripts/            generation, caption, signature, promotion, validation
│   └── chassis/        provider-run, literal-write, and manifest-promotion primitives
├── docs/               style guide, production workflow, chassis specification
├── references/style/   approved style anchors passed to the image model
├── skills/             agent instructions for caption ideation and the daily desk
├── tests/fixtures/     offline fixtures used by the validator
└── outputs/            prototypes (ignored) and finals (tracked)
```

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `COMICS_PROVIDER_CLI` | `providers/image-cli` | Your image-provider CLI adapter |
| `COMICS_PROVIDER_ROUTE` | `gemini-image` | Route name passed to the adapter |
| `COMICS_SIGNATURE` | `references/signature_transparent.png` | Signature image applied after render |
| `COMICS_STYLE_REFERENCE` | `references/style/clean-office-linework.jpg` | Style anchor passed to the model |
| `COMICS_STYLE_PROMPT` | locked prompt in `generate-comic.sh` | Deliberate one-off style override |
| `COMICS_OUTPUT_DIR` | `outputs/prototypes/<date>` | Output directory override |
| `COMICS_PROVIDER_WAIT_SECS` | `1900` | Finite wait for one provider call |
| `COMICS_PROVIDER_GRACE_SECS` | `5` | TERM-to-KILL grace during cleanup |

## Outputs

| Type | Pattern |
|---|---|
| Prototype | `outputs/prototypes/YYYY-MM-DD/concept_signed.png` |
| Prompt sidecar | `outputs/prototypes/YYYY-MM-DD/concept_signed.prompt.txt` |
| Final | `outputs/finals/YYYY-MM-DD_slug.png` |
| Final sidecar | `outputs/finals/YYYY-MM-DD_slug.prompt.txt` |

Every generated panel gets a sidecar recording the concept, caption, full
prompt, style reference, and timestamp. Promotion moves the image and the
sidecar together, and `scripts/validate-production.sh` fails on a final whose
sidecar is missing or incomplete.

## Aspect ratios and sizes

| Use | Ratio | Example |
|---|---|---|
| Standard panel | 4:3 (default) | `./scripts/generate-comic.sh "concept" "caption"` |
| Square | 1:1 | `./scripts/generate-comic.sh "concept" "caption" 1:1` |
| Vertical | 9:16 | `./scripts/generate-comic.sh "concept" "caption" 9:16` |

Image size is the fourth argument (`1K`, `2K` default, `4K`).

## Validation

`./scripts/validate-production.sh` is offline. It makes no provider or
publishing calls, and it checks:

- argument validation, literal-safe prompt sidecars, and exactly-one-render selection
- no-image and multi-image provider failure paths
- overwrite protection across the caption, signature, and extraction helpers
- provider-call supervision: deadline propagation, refusal, timeout, and cancellation exit codes
- batch failure propagation and empty-input rejection
- promotion containment, symlink and date rejection, overwrite refusal, and rollback
- finals PNG integrity, supported aspect ratios, minimum dimensions, and one-to-one image and sidecar coverage

Run it before treating any output tree as production-ready.

## Agent skills

`skills/` holds harness-agnostic agent instructions:

- `skills/comic-ideation/` captures the caption method: generate a spread of
  candidate captions, grade them across models, then let the operator pick
  before anything is rendered.
- `skills/daily-comic-desk/` produces a reviewable packet for one postable
  cartoon per day.

## Style rules

See `docs/STYLE_GUIDE.md` for the full guide. The short version:

- clean black ink line work on white, minimal crosshatching, no color
- single panel, caption space at the bottom
- contemporary metropolitan settings, dry observational humor
- two or more foreground characters must differ in age, build, hair, and clothing

## Credits and license

Process and scripts published for reference. Add a license before reuse if you
intend to redistribute.
