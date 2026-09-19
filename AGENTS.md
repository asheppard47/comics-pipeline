# Comics Pipeline — Agent Rules

This repository is a single-panel, New Yorker-style cartoon pipeline. It is
operated by an agent harness and validated offline.

## Pipeline rules

1. **One panel per render.** `generate-comic.sh` accepts exactly one image from
   the provider per call. Zero images or multiple images fail closed before
   signing or sidecar creation.
2. **Never overwrite a signed output.** Every helper refuses an existing output
   path unless `--force` is passed, and production generation never passes it.
3. **Caption in the prompt, not on the image.** The caption is passed to
   `generate-comic.sh` as its own argument so the model renders it and the
   `.prompt.txt` sidecar records it separately. Do not put caption or signature
   instructions inside the scene description.
4. **Promote only through the script.** `promote-final.sh` moves one reviewed
   image plus its matching sidecar and refuses to overwrite. Never move
   image/sidecar pairs by hand or with a glob.
5. **Validate before closeout.** `validate-production.sh` is offline and
   mandatory. A final without its prompt sidecar is incomplete.
6. **Style is locked.** The style prompt lives in `scripts/generate-comic.sh`.
   Do not keep a second copy of it, and treat `COMICS_STYLE_PROMPT` as a
   deliberate one-off override, not a default.
7. **Distinct characters.** Any two or more foreground characters must differ in
   age, build, hair, and outfit. Describe each separately. A shared description
   ("two men in blazers") renders twins.
8. **No hue words in scene prompts.** Differentiate outfits by garment type,
   pattern, and light-versus-dark tone. Hue cues pull the model into color.
9. **Publishing is human.** The agent may draft and stage; a person clicks the
   final public post control.

## Environment

| Variable | Purpose |
|---|---|
| `COMICS_PROVIDER_CLI` | Image-provider CLI adapter (see `providers/README.md`) |
| `COMICS_PROVIDER_ROUTE` | Route name passed to the adapter |
| `COMICS_SIGNATURE` | Signature PNG applied after render |
| `COMICS_STYLE_REFERENCE` | Style anchor image |
| `COMICS_STYLE_PROMPT` | One-off style override |
| `COMICS_OUTPUT_DIR` | Output directory override |

## Output contract

- Prototype: `outputs/prototypes/YYYY-MM-DD/name_signed.png` plus `.prompt.txt`
- Final: `outputs/finals/YYYY-MM-DD_slug.png` plus `YYYY-MM-DD_slug.prompt.txt`

Sidecar headings: `CONCEPT:`, `CAPTION:`, `GENERATION COMMAND:`, `FULL PROMPT SENT:`,
`STYLE REFERENCE:`, `SOURCE OUTPUT:`, `GENERATED:`, `NOTES:`.

## Skills

- `skills/comic-ideation/` — route pass, five candidates, multi-model grading, operator pick before render
- `skills/daily-comic-desk/` — one reviewable packet for a single postable panel per day

## Commands

```bash
./scripts/generate-comic.sh --dry-run "concept" "caption" 4:3 2K   # validate the request
./scripts/generate-comic.sh "concept" "caption"                   # render and sign
./scripts/promote-final.sh SOURCE_PNG purpose-slug                # promote a reviewed panel
./scripts/validate-production.sh                                  # offline contract checks
```
