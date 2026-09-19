---
name: comic-ideation
description: Use when a user shares a comic idea, asks for comic captions, or wants a New Yorker-style scene prompt. Applies verbalized sampling and multi-model caption grading before any render.
---

# Comic Ideation

Turn a rough idea into a polished single-panel comic concept through structured
caption generation and multi-model grading.

## Caption quality standard

See [`references/caption-best-practices.md`](references/caption-best-practices.md)
for the full principles. The constraints applied here:

- Target 10 words or fewer; shortlisted captions average 8.7 words
- No commas, question marks, or exclamation points; declarative statements only
- Do not describe the image; address the incongruity
- Prefer the abstract angle over the literal one
- Write 10 to 20 candidates internally, discard the obvious first 3 to 5, and surface the best 5

## Workflow

### Step 1: Route pass

For an open-ended idea, first generate a compact route distribution:

- List 8 to 12 distinct caption routes with approximate probabilities.
- Give a sample caption for each route.
- Mark the obvious, high-probability routes that risk feeling generic.
- Include at least 2 lower-probability routes that use a different comic mechanism.

Treat the probabilities as ideation priors, not quality scores. They exist to
stop you returning five versions of the same joke. Skip this pass when the user
supplies an exact caption or asks for a narrow rewrite.

### Step 2: Write five candidates

From the user's idea, generate exactly 5 caption candidates labeled A through E:

- Vary length from ultra-short to medium
- Vary tone across dry, absurd, deadpan, observational, and self-aware
- Draw from at least 4 distinct routes from Step 1
- Include at least one lower-probability route if it still fits the scene
- At least one candidate under 10 words
- Present them to the user before proceeding

### Step 3: Multi-model grading

Write one grading document containing:

- Context: the scene and the core joke
- Route diversity record: the distribution and which routes A through E came from
- Criteria scored 1 to 10: humor, conciseness, relatability, style fit, distinctiveness, overall
- The five candidates with full caption text
- Instructions: score every criterion, rank 1st through 5th, suggest at most one better version, stay under 300 words

Then send that same document to five models of your choice and collect the
responses. Two rules keep this useful:

1. Grade with the same document and rubric for every model, including any
   later candidate F.
2. Final human-facing copy is written by you, not copied from grader output.
   Use grader suggestions as idea seeds, then rewrite them.

Any model CLI works, including a shell loop over adapters:

```bash
for model in "$MODEL_A" "$MODEL_B" "$MODEL_C" "$MODEL_D" "$MODEL_E"; do
  your_model_cli grade "$GRADING_DOC" --model "$model" > "grades/$model.md"
done
```

Long graders need a bounded wait. If your CLI has job or batch mode, submit all
five and collect afterwards instead of blocking on each call.

### Step 4: Compile results

Present a summary table:

| Caption | Grader 1 | Grader 2 | Grader 3 | Grader 4 | Grader 5 | **Avg** |
|---------|----------|----------|----------|----------|----------|---------|

Include:

- Winner and runner-up with reasoning
- Reinforced alternatives: when three or more graders suggest the same angle,
  rewrite that angle into one new line, grade it with the same document, and
  present it as candidate F with its scores next to the winner. Never offer an
  ungraded line as an equal candidate
- A note when graders converged on a generic route despite the diversity pass
- A request for the user to pick the caption to proceed with

### Step 5: Generate

Once the user picks a caption:

- Write the scene description: who, where, body language, props, setting detail
- Run `./scripts/generate-comic.sh "scene description" "winning caption"`
- Open the signed output for the user
- Keep hue words out of scene prompts. Differentiate outfits by garment type,
  pattern, and light-versus-dark tone ("dark blazer", "pale sweater", "striped
  tie"). The locked style prompt forces black ink and grey wash, but a hue cue
  in the scene text still pulls an image model into full color.

### Step 5b: Editor pass on every render

Review each render before presenting a verdict:

1. Downscale the image to a review size your model accepts.
2. Write the review prompt to a file so the caption never passes through shell
   quoting.
3. Ask the editor model for: does the joke land on first read; does the
   composition guide the eye; are there visual errors, logic problems, clutter,
   or explanatory labels that spoon-feed the premise; is the style black ink and
   grey wash; and a verdict of publish as is, publish with a tweak, or
   regenerate, naming the tweak.
4. Present the image and the critique together. Apply a "tweak" verdict by
   regenerating, then re-review.

The editor model critiques; it does not write the caption or the final scene
prompt.

### Step 6: Finalize

- On approval, promote with `./scripts/promote-final.sh SOURCE_PNG purpose-slug`.
  It moves the reviewed image and its `.prompt.txt` sidecar together, and a
  final without its sidecar fails validation.
- On change requests, regenerate with a tweaked prompt.
- Save approved style anchors to `references/style/`.

### Step 7: Social copy

After the comic is final, draft 5 short text post options:

- One designated drafting model writes the final copy; graders do not
- No hashtags or emojis, no joke explanation, no hype adjectives
- Sketch a route distribution first: deadpan label, dry aside, faux earnest,
  visual callback, undercut, one-word fragment
- Vary from 3 to 5 words up to a one-line observation
- Present all 5 and let the user pick

## Scene prompt tips

- Specify character positions and body language
- Describe each foreground character separately, with a distinct age, build,
  hair, and outfit. A shared description such as "two men in blazers" renders
  near-identical twins
- Include environmental detail: posters, furniture, props
- Note expressions and any visual gag that supports the caption
- Keep the caption out of the scene description; pass it as its own argument

## Examples

**Rough idea**: "Two startup founders are pitching a haunted house."

Expected behavior: run the route pass, then return 5 captions from distinct
routes such as investor jargon, supernatural labor issues, customer discovery,
understated dread, and mundane SaaS metrics. Do not return five versions of "our
traction is spooky."

**Exact caption supplied**: "Our burn rate is mostly candles."

Expected behavior: skip the route pass, build the scene prompt around the
supplied caption, and proceed to generation.

## Error handling

| Failure | Recovery |
|---|---|
| All candidates cluster around one joke | Re-run Step 1 with a stronger route spread and replace at least 2 candidates before grading |
| Caption is funny but visually unsupported | Revise the scene prompt or reject the caption before generation |
| Graders prefer the generic route | Surface the tradeoff; do not hide the more original runner-up |
| Social copy explains the joke | Rewrite as labels, asides, or fragments |
