# Image-provider CLI adapter

`scripts/generate-comic.sh` and `scripts/chassis/run-image-provider` never talk
to a model directly. They shell out to one adapter, chosen by
`COMICS_PROVIDER_CLI` (default `providers/image-cli`, which does not ship). Write
your own adapter against the contract below.

## Contract

One invocation generates exactly one image:

```bash
"$COMICS_PROVIDER_CLI" single <style-reference-image> <prompt-text> <route> \
    --aspect-ratio <4:3|1:1|9:16> \
    --image-size <1K|2K|4K> \
    --output-dir <directory>
```

Arguments:

| Argument | Meaning |
|---|---|
| `single` | Subcommand. One call, one image. |
| `style-reference-image` | Path to a PNG or JPEG style anchor. Pass it to the model as a reference image. |
| `prompt-text` | The full prompt, caption instruction included. Pass it unchanged. |
| `route` | Provider route name, from `COMICS_PROVIDER_ROUTE` (default `gemini-image`). Use it to pick a backend or model. |
| `--aspect-ratio` | Requested panel ratio. |
| `--image-size` | Requested size class. |

Behavior:

1. Write exactly one `.png`, `.jpg`, or `.jpeg` file into `--output-dir`. The
   wrapper rejects zero files, multiple files, zero-byte files, and symlinks.
2. Exit `0` on success and print nothing that the wrapper must parse. The
   wrapper finds the image by scanning `--output-dir`.
3. Exit non-zero on failure. Send diagnostics to stderr.
4. Optional but supported: read `PROVIDER_CALLER_DEADLINE_SECS` from the
   environment. When it is set, the caller can wait at most that many seconds
   and will terminate your process group on expiry.

Reserved exit codes used by the supervisor:

| Code | Meaning |
|---|---|
| `75` | Refused before spend (for example, not enough deadline left) |
| `124` | Exceeded the caller's outer wait |
| `143` | Cancelled by TERM |

## Minimal adapter

```python
#!/usr/bin/env python3
"""Adapter skeleton: single <style> <prompt> <route> --aspect-ratio ... --image-size ... --output-dir ..."""
import argparse
import pathlib
import sys

parser = argparse.ArgumentParser()
parser.add_argument("command")
parser.add_argument("style_reference")
parser.add_argument("prompt")
parser.add_argument("route")
parser.add_argument("--aspect-ratio", required=True)
parser.add_argument("--image-size", required=True)
parser.add_argument("--output-dir", required=True)
args = parser.parse_args()

prompt = pathlib.Path(args.prompt).read_text() if pathlib.Path(args.prompt).is_file() else args.prompt
out_dir = pathlib.Path(args.output_dir)
out_dir.mkdir(parents=True, exist_ok=True)
image_bytes = your_model_call(prompt, args.style_reference, args.route,
                              args.aspect_ratio, args.image_size)
(out_dir / "render.png").write_bytes(image_bytes)
sys.exit(0)
```

Keep one image per call. The wrapper treats anything else as a provider fault,
because a silent second image or a stale file is how the wrong panel reaches a
final.

## Testing an adapter

`tests/fixtures/fake-image-provider.py` is an offline adapter that writes a fixture
image and records the deadline it received. Point `COMICS_PROVIDER_CLI` at it to
exercise the wrapper without spending a model call:

```bash
COMICS_PROVIDER_CLI=tests/fixtures/fake-image-provider.py COMICS_OUTPUT_DIR=/tmp/panel \
  ./scripts/generate-comic.sh "fixture scene" "fixture caption" 4:3 1K
```
