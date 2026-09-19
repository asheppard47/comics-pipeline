---
schema_version: 2
title: Comics Shared Chassis Specification
doc_type: detail
version: "1.0.0"
created: "2026-08-13"
last_updated: "2026-08-13"
last_audit: "2026-08-13"
audit_status: current
domain: personal
parent: INDEX.md
triggers:
  - comics chassis
  - shared chassis
  - promote-manifest
  - run-image-provider
---

# Comics Shared Chassis

Lane-neutral primitives used by the cartoon generation and promotion
pipeline. The chassis does not own style, captions, facts, sidecars,
destinations, or posting.

## Primitives

| CLI | Job |
|-----|-----|
| `scripts/chassis/run-image-provider` | One image-provider call in a new exclusive `.provider-run.*` directory |
| `scripts/chassis/write-literal-file` | Write stdin bytes to a new path; refuse overwrite |
| `scripts/chassis/promote-manifest` | Promote a hash-bound manifest with no overwrite and rollback |

Every chassis CLI implements `--help`. None of them choose a style, lane, or
output tree.

## Provider run

`run-image-provider` creates an empty exclusive child under `--output-parent`,
runs one image-provider call into that child, and accepts exactly one regular
`.jpg` / `.jpeg` / `.png` direct child. Success prints one JSON object on
stdout: `run_dir`, `image`, `provider_exit`, `provider_route`. Provider logs go
to stderr.

Exit codes that cartoon tests already rely on stay unchanged: `0`, `1`,
`124`, `130`, `143`, plus the provider's own nonzero status.

## Literal write

`write-literal-file --output PATH` persists stdin bytes with no interpolation
and no overwrite. The caller owns sidecar schemas.

## Manifest promotion

`promote-manifest` rechecks schema, containment, named-path symlink refusal,
size, and SHA-256 before mutation, then rehashes the staged copy before the
no-replace commit. `schema_version` is `1`. Required labels: `lane`,
`item_id`, `mode` (`flat-set` or `directory`). Source symlink checks use the
path as named, not the resolved target. Flat-set records each destination
before consuming its source so a failed source unlink can still roll back.

Cartoon promotion stays `promote-final.sh`. After its existing slug, date, PNG,
and sidecar checks it emits a two-entry `flat-set` manifest (`image`,
`sidecar`) and calls this primitive. The chassis does not scan `outputs/`
itself.

`COMICS_TEST_FAIL_IMAGE_MOVE` and `COMICS_TEST_FAIL_SIDECAR_MOVE` still force
the same observable rollback failures.

## What stays outside the chassis

- `generate-comic.sh` owns the locked prompt, signature timing, and sidecar headings.
- Publishing and any social workflow live outside this repository.
- `validate-production.sh` scans only the finals tree it is given.

## Adapter notes

`generate-comic.sh` forwards `INT`/`TERM` to the chassis runner so the existing
cancellation test still sees exit `143`. After a successful provider result it
installs the raw image into the dated prototype directory with no overwrite,
then signs and writes the sidecar through `write-literal-file`. `--dry-run`
creates no provider-run directory.
