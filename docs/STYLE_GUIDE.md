---
schema_version: 2
title: Comics Style Guide
doc_type: detail
version: "1.3.0"
created: "2025-12-01"
last_updated: "2026-07-12"
last_audit: "2026-07-12"
audit_status: current
domain: personal
parent: INDEX.md
triggers:
  - "style guide"
  - "visual style"
  - "line work"
---

# Comics Style Guide

## Overview

Single-panel cartoons in the tradition of The New Yorker magazine. Sophisticated visual humor with clean execution.

## Visual Characteristics

### Line Work
- **Stroke**: Clean black ink on white background
- **Weight**: Consistent medium weight, slightly varied for emphasis
- **Shading**: Minimal crosshatching, subtle gray washes acceptable
- **Quality**: Economical - every line serves a purpose

### Composition
- **Format**: Single panel, 4:3 aspect ratio (default)
- **Layout**: Static composition, no motion lines or action effects
- **Caption Space**: White area at bottom (~10-12% of image height)
- **Signature**: Top-right of the illustration, 2% edge margin

### Characters
- **Proportions**: Naturalistic with slight stylization
- **Faces**: Expressive features, not exaggerated
- **Variety**: Different characters per comic (no recurring cast)
- **Dress**: Contemporary clothing, era-appropriate

### Setting
- **Environment**: Contemporary metropolitan life
- **Details**: Authentic backgrounds (offices, homes, streets, restaurants)
- **Props**: Recognizable modern objects (phones, laptops, coffee cups)

## Locked Style System

The canonical prompt is embedded only in `scripts/generate-comic.sh` so the
documentation cannot drift from production code. Every production generation
also passes `references/style/clean-office-linework.jpg` as a visual reference.
The model is instructed to borrow line quality, restrained shading, proportions,
and caption treatment only, never the reference subject, layout, text, or marks.

The remaining approved anchors and their intended uses are documented in
`references/style/README.md`. Override the default for a specific run with
`COMICS_STYLE_REFERENCE=/absolute/path/to/approved-reference.jpg`.

## Joke Structure

### Eye Path
The viewer reads in this order:
1. **Image** (top to bottom, left to right)
2. **Speech bubbles** (setup)
3. **Caption** (punchline)

### Setup → Punchline
- **Speech bubble**: Delivers the setup (what the character is saying/thinking)
- **Caption**: Delivers the punchline (the twist, the "tell")
- The caption should recontextualize everything above it

### Character Differentiation
- Characters should be visually distinct (age, dress, demeanor)
- The "straight man" vs "subject of the joke" must be clear
- Expressions are critical - the knowing smirk, the oblivious rant

### Prompt Construction
Don't just describe the scene - describe the joke mechanics:
- ❌ "Two men at a bar talking"
- ✅ "Older disheveled man ranting with speech bubble 'AI is useless', younger polished man with knowing smirk"

### Example
**Concept**: ChatGPT users think AI sucks, everyone else knows better
**Setup** (speech bubble): "AI is completely useless. It just makes things up."
**Visual beat**: Younger guy's knowing smirk
**Punchline** (caption): "He still uses Yahoo."

## Advanced Techniques

### Composition
- **Middle Distance**: Avoid dramatic angles. Characters in profile or three-quarters view, several feet apart. Creates emotional detachment matching dry wit.
- **Negative Space**: Don't over-render. White space isolates characters and focuses attention.
- **Scale Irony**: Small character in imposing setting (vast boardroom, giant's kitchen). Humor from maintaining dignity while dwarfed.

### Caption Craft
- **Last Word Rule**: Punchline word MUST be final word. Never bury it mid-sentence.
  - ❌ "The guillotine is broken so we're using a stapler today."
  - ✅ "Since the guillotine is broken, today we'll be using a **stapler**."
- **Specificity**: "Gruyère" not "cheese". "LinkedIn request" not "internet".
- **Corporate Absurdism**: Apply business language to absurd contexts ("bandwidth", "metrics", "optics" in a dungeon or desert island).
- **The Beat**: Create timing through syntax and word order. New generated
  candidates should not rely on commas, question marks, or exclamation points.

### Joke Engines
- **Anachronism**: Modern anxieties in historical/mythological settings (Sisyphus checking his step count)
- **Literalized Metaphor**: Idiom made physical ("can of worms" literally opened in boardroom)
- **Cliché Subversion**: Standard trope + one changed variable (Grim Reaper forgot his phone charger)

### The 10% Rule
Great cartoons require reader to do 10% of the work. Too obvious = newspaper strip. The "click" when visual and verbal lock together should feel earned.

### Delivery
- **Deadpan over Drama**: Characters deliver insane lines with bored expressions. Avoid wide-open "yelling" mouths.
- **Visual Easter Eggs**: Place visual clue slightly off-center. Reader discovers it, then caption recontextualizes.

## Caption Style

### Tone
- Dry wit, understated delivery
- Observational humor about modern life
- Never explains the joke directly
- One-liner format preferred

### Format
- Target: 10 words or fewer for new generated candidates
- Punctuation: declarative; no commas, question marks, or exclamation points
- Font: Georgia (serif, sophisticated)
- Size: ~3-4% of image height
- Position: Centered in caption area
- Color: Black on white

### Examples
- "He still uses Yahoo"
- "The monkeys were closer"
- "The simulation is performing within normal parameters"

Exact user-supplied captions and historical finals may use other punctuation;
the declarative rule governs newly generated candidate sets.

## Signature

### Specifications
- **Style**: Felt-tip marker with natural stroke variation
- **Position**: Top-right without a generated background shape
- **Size**: 9% of image width
- **File**: `references/signature_transparent.png` (override with `COMICS_SIGNATURE`)

### Preventing a Generated Signature
`generate-comic.sh` automatically tells the image model not to draw or imitate a
signature. Do not add a second signature instruction to the concept text.

### Making the Asset
Draw or generate the signature in black on a plain white background, then key
the background out:
```bash
python3 scripts/extract-signature.py signature-source.jpg references/signature_transparent.png
```
Generating the signature with real alpha is preferable when your provider
supports transparency.

## What to Avoid

### Visual
- Motion lines or speed effects
- Manga/anime style exaggeration
- Photorealistic rendering
- Busy or cluttered backgrounds
- Random text (speech bubbles for setup are encouraged)

### Content
- Slapstick or physical comedy
- Punchlines that explain the joke
- Dated references
- Controversial political figures
- Labels on objects ("DEBT" on boulder = failure)
- Starting captions with "Well..." or "So..."
- Over-explaining (if reader needs a label, the image failed)

## Aspect Ratios

| Platform | Ratio | Use |
|----------|-------|-----|
| Standard | 4:3 | Default, print-ready |
| Instagram Feed | 1:1 | Square format |
| Instagram Story | 9:16 | Vertical format |

## Quality Checklist

Before approving a comic for finals:

- [ ] Line work is clean and consistent
- [ ] Composition is balanced
- [ ] Caption space is clear
- [ ] Characters have expressive faces
- [ ] Setting is recognizable
- [ ] Signature is properly placed
- [ ] No text rendering errors in illustration
- [ ] No second model-generated signature or stray artist mark
- [ ] Matching prompt sidecar exists before promotion
