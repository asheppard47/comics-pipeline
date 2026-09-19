# Approved Style References

These are production anchors, not alternate finals. They were derived from
approved unsigned prototype renders and are intentionally named by the visual
quality they demonstrate:

- `clean-office-linework.jpg` — default generator reference for clean ink,
  naturalistic figures, restrained gray shading, and metropolitan detail.
- `minimal-domestic-scene.jpg` — sparse composition and economical linework.
- `complex-cutaway-composition.jpg` — dense multi-level composition that
  remains legible.

`generate-comic.sh` passes `clean-office-linework.jpg` to the image provider by default. The
prompt tells the image model to borrow only visual treatment, never the source
subject, layout, caption, or marks. To test another approved anchor without
changing the canonical script, set `COMICS_STYLE_REFERENCE` to one of the other
files for that invocation.

Do not add an image here merely because it is a final. Add it only after visual
review confirms that it demonstrates a reusable part of the locked style.
