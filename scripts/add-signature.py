#!/usr/bin/env python3
# add-signature.py - Add signature overlay to comic images
# Dependencies: Pillow (pip3 install Pillow --break-system-packages)
# Usage: python3 add-signature.py comic.png [--output path] [--position bottom-right]

from PIL import Image
import argparse
import os

# Default signature location
SIGNATURE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references", "signature_transparent.png")

# Signature size as percentage of image width
SIGNATURE_WIDTH_PERCENT = 9

# Margin from edge as percentage of image dimensions
MARGIN_PERCENT = 2


def add_signature(
    comic_path: str,
    output_path: str = None,
    signature_path: str = SIGNATURE_PATH,
    position: str = "top-right",
    size_percent: float = SIGNATURE_WIDTH_PERCENT,
    margin_percent: float = MARGIN_PERCENT,
    white_background: bool = False,
    force: bool = False,
) -> str:
    """
    Add signature overlay to a comic image.

    Args:
        comic_path: Path to the comic image
        output_path: Output path (default: comic_signed.ext)
        signature_path: Path to transparent signature PNG
        position: Where to place signature (top-right, top-left, bottom-right, bottom-left)
        size_percent: Signature width as % of image width (default: 9)
        margin_percent: Margin from edge as % of dimensions (default: 2)
        white_background: Add white oval background behind signature (default: False)
        force: Permit replacement of an existing output path (default: False)

    Returns:
        Path to the signed comic image
    """
    from PIL import ImageDraw

    # Load comic image
    comic = Image.open(comic_path)
    if comic.mode != 'RGBA':
        comic = comic.convert('RGBA')

    comic_width, comic_height = comic.size

    # Load signature
    signature = Image.open(signature_path)
    if signature.mode != 'RGBA':
        signature = signature.convert('RGBA')

    # Resize signature to target width while maintaining aspect ratio
    target_width = int(comic_width * (size_percent / 100))
    sig_ratio = signature.size[1] / signature.size[0]
    target_height = int(target_width * sig_ratio)
    signature = signature.resize((target_width, target_height), Image.Resampling.LANCZOS)

    # Calculate margins
    margin_x = int(comic_width * (margin_percent / 100))
    margin_y = int(comic_height * (margin_percent / 100))

    # Calculate position
    positions = {
        "top-right": (comic_width - target_width - margin_x, margin_y),
        "top-left": (margin_x, margin_y),
        "bottom-right": (comic_width - target_width - margin_x, comic_height - target_height - margin_y),
        "bottom-left": (margin_x, comic_height - target_height - margin_y),
    }

    if position not in positions:
        position = "top-right"

    pos = positions[position]

    # Add white oval background behind signature if requested
    if white_background:
        draw = ImageDraw.Draw(comic)
        # Calculate oval bounds with padding
        padding = int(target_height * 0.3)
        oval_bounds = [
            pos[0] - padding,
            pos[1] - padding // 2,
            pos[0] + target_width + padding,
            pos[1] + target_height + padding // 2
        ]
        draw.ellipse(oval_bounds, fill=(255, 255, 255, 255))

    # Paste signature onto comic using alpha channel as mask
    comic.paste(signature, pos, signature)

    # Determine output path
    if not output_path:
        base, ext = os.path.splitext(comic_path)
        output_path = f"{base}_signed{ext}"

    if os.path.lexists(output_path) and not force:
        raise FileExistsError(f"Refusing to overwrite existing signed image: {output_path}")

    # Save as PNG to preserve quality, or original format
    if output_path.lower().endswith('.png'):
        comic.save(output_path, 'PNG')
    else:
        # Convert to RGB for JPEG
        comic_rgb = Image.new('RGB', comic.size, (255, 255, 255))
        comic_rgb.paste(comic, mask=comic.split()[3] if comic.mode == 'RGBA' else None)
        comic_rgb.save(output_path, quality=95)

    print(f"Signed comic saved: {output_path}")
    return output_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add signature to comic image")
    parser.add_argument("comic", help="Path to comic image")
    parser.add_argument("--output", "-o", help="Output path (default: comic_signed.ext)")
    parser.add_argument("--signature", "-s", default=SIGNATURE_PATH,
                       help=f"Signature image path (default: {SIGNATURE_PATH})")
    parser.add_argument("--position", "-p", default="top-right",
                       choices=["bottom-right", "bottom-left", "top-right", "top-left"],
                       help="Signature position (default: top-right)")
    parser.add_argument("--size", type=float, default=SIGNATURE_WIDTH_PERCENT,
                       help=f"Signature width as %% of image (default: {SIGNATURE_WIDTH_PERCENT})")
    parser.add_argument("--margin", type=float, default=MARGIN_PERCENT,
                       help=f"Margin from edge as %% (default: {MARGIN_PERCENT})")
    parser.add_argument("--white-bg", action="store_true",
                       help="Add white oval background behind signature (default: off; signature blends with cream/off-white comic background)")
    parser.add_argument("--force", action="store_true",
                       help="Allow replacement of an existing output path")

    args = parser.parse_args()

    try:
        add_signature(
            args.comic,
            args.output,
            args.signature,
            args.position,
            args.size,
            args.margin,
            white_background=args.white_bg,
            force=args.force,
        )
    except (OSError, ValueError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")
