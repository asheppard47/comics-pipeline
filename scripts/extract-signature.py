#!/usr/bin/env python3
# extract-signature.py - Extract signature from generated image, make background transparent
# Dependencies: Pillow
# Usage: python3 extract-signature.py input.jpg output.png

from PIL import Image
import argparse
import os


def extract_signature(input_path, output_path, threshold=220, force=False):
    """
    Extract signature from image and make background transparent.
    Works with signatures on light/white backgrounds.
    """
    if os.path.lexists(output_path) and not force:
        raise FileExistsError(f"Refusing to overwrite existing extracted signature: {output_path}")

    img = Image.open(input_path)

    # Convert to RGBA
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    width, height = img.size
    pixels = img.load()

    # Find the bounding box of dark pixels (the signature)
    min_x, min_y = width, height
    max_x, max_y = 0, 0

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # Check if pixel is dark (part of signature)
            if r < threshold and g < threshold and b < threshold:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if max_x < min_x or max_y < min_y:
        raise ValueError(
            f"No pixels below darkness threshold {threshold} found in {input_path}"
        )

    # Add padding
    padding = 20
    min_x = max(0, min_x - padding)
    min_y = max(0, min_y - padding)
    max_x = min(width, max_x + padding)
    max_y = min(height, max_y + padding)

    # Crop to signature area
    cropped = img.crop((min_x, min_y, max_x, max_y))

    # Make light pixels transparent
    cropped_pixels = cropped.load()
    crop_width, crop_height = cropped.size

    for y in range(crop_height):
        for x in range(crop_width):
            r, g, b, a = cropped_pixels[x, y]

            # Calculate luminance
            lum = (r + g + b) / 3

            if lum > threshold:
                # Light pixel - make transparent
                cropped_pixels[x, y] = (255, 255, 255, 0)
            else:
                # Dark pixel - make it black with alpha based on darkness
                # Darker = more opaque
                alpha = int(255 * (1 - lum / threshold))
                alpha = max(0, min(255, alpha))
                cropped_pixels[x, y] = (0, 0, 0, alpha)

    # Save
    cropped.save(output_path, 'PNG')
    print(f"Signature extracted: {output_path}")
    print(f"Size: {crop_width}x{crop_height} pixels")
    return output_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract signature with transparent background")
    parser.add_argument("input", help="Input image with signature")
    parser.add_argument("output", nargs="?", help="Output PNG path")
    parser.add_argument("--threshold", type=int, default=220,
                       help="Light/dark threshold 0-255 (default: 220)")
    parser.add_argument("--force", action="store_true",
                       help="Allow replacement of an existing output path")

    args = parser.parse_args()

    output = args.output or os.path.join(
        os.path.dirname(args.input) or ".",
        "signature_transparent.png"
    )

    try:
        extract_signature(args.input, output, args.threshold, force=args.force)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")
