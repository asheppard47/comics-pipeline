#!/usr/bin/env python3
# process-signature.py - Convert signature to felt-tip marker style with transparent background
# Dependencies: Pillow (pip3 install Pillow --break-system-packages)
# Usage: python3 process-signature.py input.png output.png --style marker

from PIL import Image, ImageFilter, ImageOps, ImageDraw
import argparse
import os
import random

# Default felt-tip stroke-edge variation amount (0-1); the function default
# and the CLI default both point at this one constant.
DEFAULT_VARIATION = 0.25


def add_stroke_variation(img, intensity=0.3):
    """
    Add natural variation to strokes to simulate felt-tip marker.
    Uses morphological operations with slight randomization.
    """
    # Convert to grayscale for processing
    if img.mode != 'L':
        gray = img.convert('L')
    else:
        gray = img.copy()

    width, height = gray.size
    pixels = gray.load()

    # Add slight edge variation by random erosion/dilation
    # This simulates the natural variation in felt-tip marker strokes
    result = gray.copy()
    result_pixels = result.load()

    for y in range(1, height - 1):
        for x in range(1, width - 1):
            if pixels[x, y] < 128:  # Dark pixel (stroke)
                # Check neighbors
                neighbors = [
                    pixels[x-1, y], pixels[x+1, y],
                    pixels[x, y-1], pixels[x, y+1]
                ]
                dark_neighbors = sum(1 for n in neighbors if n < 128)

                # Edge pixels (have some white neighbors) get random variation
                if dark_neighbors < 4:
                    if random.random() < intensity:
                        # Randomly erode or dilate edge
                        if random.random() < 0.3:
                            result_pixels[x, y] = 255  # Erode
                        else:
                            # Dilate into a random neighbor
                            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                                nx, ny = x + dx, y + dy
                                if 0 <= nx < width and 0 <= ny < height:
                                    if pixels[nx, ny] > 200 and random.random() < 0.5:
                                        result_pixels[nx, ny] = 0

    return result


def process_signature_marker(input_path, output_path, threshold=180, dilate=4, variation=DEFAULT_VARIATION):
    """
    Process signature to look like felt-tip marker with natural variation.

    Args:
        input_path: Path to input signature image
        output_path: Path for output transparent PNG
        threshold: Grayscale threshold (0-255)
        dilate: Base number of dilation passes
        variation: Amount of stroke edge variation (0-1)
    """
    # Load image
    img = Image.open(input_path)

    # Convert to grayscale
    gray = img.convert('L')

    # Apply slight gaussian blur to soften before threshold (simulates ink bleed)
    gray = gray.filter(ImageFilter.GaussianBlur(radius=0.5))

    # Threshold to black and white
    bw = gray.point(lambda x: 0 if x < threshold else 255, 'L')

    # Multiple dilation passes with slight variation
    dilated = bw
    for i in range(dilate):
        # Alternate between MinFilter sizes for variation
        if i % 2 == 0:
            dilated = dilated.filter(ImageFilter.MinFilter(3))
        else:
            # Slightly different kernel for variation
            dilated = dilated.filter(ImageFilter.MinFilter(3))
            # Add micro variation
            dilated = add_stroke_variation(dilated, intensity=variation)

    # Add final edge variation for organic look
    dilated = add_stroke_variation(dilated, intensity=variation * 1.5)

    # Slight blur to soften harsh edges (like real ink)
    dilated = dilated.filter(ImageFilter.GaussianBlur(radius=0.3))

    # Re-threshold after blur to keep edges crisp but soft
    dilated = dilated.point(lambda x: 0 if x < 200 else 255, 'L')

    # Convert to RGBA for transparency
    rgba = dilated.convert('RGBA')

    # Make white pixels transparent
    data = rgba.getdata()
    new_data = []
    for item in data:
        if item[0] > 240:  # White
            new_data.append((255, 255, 255, 0))  # Transparent
        else:
            # Black with slight alpha variation for softer edges
            alpha = 255 if item[0] < 50 else int(255 * (1 - item[0] / 255))
            new_data.append((0, 0, 0, alpha))

    rgba.putdata(new_data)

    # Crop to content
    bbox = rgba.getbbox()
    if bbox:
        rgba = rgba.crop(bbox)

    # Save
    rgba.save(output_path, 'PNG')
    print(f"Processed signature saved: {output_path}")
    print(f"Size: {rgba.size[0]}x{rgba.size[1]} pixels")
    return output_path


def process_signature_brush(input_path, output_path, threshold=180, dilate=3):
    """
    Alternative: Process signature with brush-like strokes.
    Creates more dramatic variation in stroke width.
    """
    img = Image.open(input_path)
    gray = img.convert('L')

    # Invert so strokes are white on black (easier to process)
    inverted = ImageOps.invert(gray)

    # Apply max filter to expand strokes
    expanded = inverted
    for _ in range(dilate):
        expanded = expanded.filter(ImageFilter.MaxFilter(3))

    # Apply gaussian blur for brush effect
    expanded = expanded.filter(ImageFilter.GaussianBlur(radius=1.5))

    # Threshold back to binary
    binary = expanded.point(lambda x: 255 if x > 80 else 0, 'L')

    # Invert back
    final = ImageOps.invert(binary)

    # Add edge variation
    final = add_stroke_variation(final, intensity=0.15)

    # Convert to RGBA with transparency
    rgba = final.convert('RGBA')
    data = rgba.getdata()
    new_data = []
    for item in data:
        if item[0] > 200:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append((0, 0, 0, 255))
    rgba.putdata(new_data)

    # Crop
    bbox = rgba.getbbox()
    if bbox:
        rgba = rgba.crop(bbox)

    rgba.save(output_path, 'PNG')
    print(f"Processed signature saved: {output_path}")
    print(f"Size: {rgba.size[0]}x{rgba.size[1]} pixels")
    return output_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process signature to felt-tip marker style")
    parser.add_argument("input", help="Input signature image")
    parser.add_argument("output", nargs="?", help="Output PNG path")
    parser.add_argument("--threshold", type=int, default=180,
                       help="Black/white threshold 0-255 (default: 180)")
    parser.add_argument("--dilate", type=int, default=4,
                       help="Stroke thickness passes (default: 4)")
    parser.add_argument("--variation", type=float, default=DEFAULT_VARIATION,
                       help=f"Edge variation amount 0-1 (default: {DEFAULT_VARIATION})")
    parser.add_argument("--style", choices=["marker", "brush"], default="marker",
                       help="Processing style (default: marker)")
    parser.add_argument("--force", action="store_true",
                       help="Allow replacement of an existing output path")

    args = parser.parse_args()

    output = args.output or os.path.join(
        os.path.dirname(args.input) or ".",
        "signature_transparent.png"
    )

    if os.path.lexists(output) and not args.force:
        parser.exit(1, f"ERROR: Refusing to overwrite existing processed signature: {output}\n")

    if args.style == "brush":
        process_signature_brush(args.input, output, args.threshold, args.dilate)
    else:
        process_signature_marker(args.input, output, args.threshold, args.dilate, args.variation)
