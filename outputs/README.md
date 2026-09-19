# Outputs

`prototypes/` holds work in progress: one dated directory per session, holding
the signed panel and its `.prompt.txt` sidecar. This tree is gitignored.

`finals/` holds promoted panels, tracked in git, named
`YYYY-MM-DD_slug.png` with a matching `YYYY-MM-DD_slug.prompt.txt` sidecar.
Promote with `./scripts/promote-final.sh`, which moves the image and sidecar
together and refuses to overwrite. A final without its sidecar fails
`./scripts/validate-production.sh`.
