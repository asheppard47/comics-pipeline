---
name: daily-comic-desk
description: >
  Use when the operator wants the daily cartoon desk, a pulse of premises, or
  one non-clickbait postable cartoon. Not for caption-only ideation or posting.
execution_mode: checklist
---

# Daily Comic Desk

Produce one postable single-panel cartoon most days, better than the archive
median, without cheap heat. A kill day is a success. Silence is not approval.

A discovery model may pulse premises, score risk, and critique. It does not
write final captions, does not write final post copy, and never clicks a public
post control.

## Execution contract

- Write `outputs/prototypes/YYYY-MM-DD/desk/packet.md` from
  `references/packet-template.md`. Do not overwrite an existing desk packet;
  use `desk_r2` when today's folder exists.
- Call `comic-ideation` after the operator picks a premise. Do not replace its
  caption pause.
- Call `generate-comic.sh` twice after the caption pick. Do not fork its style
  prompt.
- Close with `promote-final.sh` and `validate-production.sh` only after the
  operator picks a drawing.
- Publishing stays human: the operator clicks the final post control.

## Do not use for

- Caption brainstorming with no desk → `comic-ideation`
- Autoposting, skipped caption picks, or style-prompt edits

## Flow

```
PULSE -> RISK KILL -> PREMISE PICK -> comic-ideation
  -> ARCHIVE BAR -> OPERATOR PICKS OR KILLS -> TWO RENDERS
  -> DRAWING PICK -> PROMOTE + VALIDATE -> POST COPY PAUSE
```

1. **Pulse.** Eight to twelve observational premises from work, domestic life,
   technology as lived, and metropolitan manners. Treat the last 24 hours as
   cultural weather, not dunk targets. Score controversy, clickbait, and style
   fit.
2. **Risk kill.** Drop partisan pile-on, tragedy, cruelty, confidential
   material, employer or client exposure, ragebait, and "you won't believe."
   Record each kill.
3. **Premise pick.** Surface three survivors. The operator picks one, supplies
   their own, or kills the day. Stop on silence.
4. **Ideation.** Run `comic-ideation` on the chosen premise.
5. **Archive bar.** Compare the graded winner to the three most similar finals
   in `outputs/finals/`. Ship only when it beats the archive median on humor and
   distinctiveness, or the operator overrides in the packet.
6. **Viral screen, inverted.** Kill cheap heat and generic routes. A 9 that
   depends on dunking loses to a 7 a stranger would still share.
7. **Two renders.** Run `./scripts/generate-comic.sh` twice with the same
   caption and two scene phrasings. Do not overwrite either signed file.
8. **Closeout.** The operator picks a drawing, then run `promote-final.sh` and
   `validate-production.sh`. Draft post lines through your designated drafting
   model, stage them, and let the operator post.
9. **Amplification.** Optional, and only after the original post URL exists.

## Quality bar

A ship day needs all of these. Otherwise record a kill.

- Declarative caption, 10 words or fewer, that does not describe the image
- At least four distinct routes; the shipped caption is not the obvious first
  route unless the operator overrides
- Archive bar is `pass` or `override`
- Risk kill ran; the shipped premise is not banned
- Signed PNG plus sidecar; `validate-production.sh` passes

`check-desk-packet.py` enforces `post_url` on every `ship` outcome. Fill it with
the live post URL, or the literal `posted outside pipeline` when the operator
posted through another surface.

Check the packet with:

```bash
python3 scripts/check-desk-packet.py --packet outputs/prototypes/YYYY-MM-DD/desk/packet.md
```

## Examples

- "Run the daily desk" → pulse, then stop for premise pick.
- "Just give me captions for today" with no desk packet → `comic-ideation`.

## Error handling

| Failure | Action |
|---------|--------|
| All premises fail risk kill | Kill the day. Do not stretch. |
| Operator is silent | Stop. Do not generate. |
| Archive bar fails and no override | Kill the day. |
| Asked to autopost or skip the caption pick | Refuse. |
| Asked to change the locked style prompt | Refuse. |
