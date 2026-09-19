#!/usr/bin/env python3
# add-caption.py - Add caption text to generated comic
# Dependencies: Pillow (pip3 install Pillow --break-system-packages)
# Usage: python3 add-caption.py input.png "Caption text" [--output path] [--size fontsize]

from PIL import Image, ImageDraw, ImageFont
import argparse
import os


def _load_font(font_paths, size):
    for font_path in font_paths:
        try:
            return ImageFont.truetype(font_path, size)
        except (IOError, OSError):
            continue
    raise OSError(
        "No production serif font found. Install Georgia or pass --font with "
        "a TrueType/OpenType serif font."
    )


def _wrap_lines(draw, caption_text, font, max_width):
    words = caption_text.split()
    lines = []
    current_line = []
    for word in words:
        if draw.textbbox((0, 0), word, font=font)[2] > max_width:
            raise ValueError(f"Caption word is too wide to fit safely: {word}")
        test_line = ' '.join(current_line + [word])
        if draw.textbbox((0, 0), test_line, font=font)[2] > max_width:
            if current_line:
                lines.append(' '.join(current_line))
            current_line = [word]
        else:
            current_line.append(word)
    if current_line:
        lines.append(' '.join(current_line))
    return lines or ['']


def _default_font_size(image_height):
    """Return the locked 3.5%-of-height fallback caption size."""
    return max(14, round(image_height * 0.035))


def add_caption(input_path, caption_text, font_size=None, output_path=None, font_path=None, force=False):
    """Add a centered, safely wrapped caption below a comic image."""
    if font_size is not None and font_size <= 0:
        raise ValueError("Font size must be a positive integer")
    if output_path and os.path.lexists(output_path) and not force:
        raise FileExistsError(f"Refusing to overwrite existing captioned image: {output_path}")
    img = Image.open(input_path)
    width, height = img.size

    # Try Georgia font (New Yorker-esque), fall back to default
    font_paths = [
        font_path,
        "/System/Library/Fonts/Supplemental/Georgia.ttf",
        "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
        "/Library/Fonts/Georgia.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSerif-Regular.ttf",
    ]
    font_paths = [path for path in font_paths if path]
    probe = Image.new('RGB', (width, 1), 'white')
    probe_draw = ImageDraw.Draw(probe)
    max_width = width - max(40, int(width * 0.06))
    size = font_size if font_size is not None else _default_font_size(height)
    while True:
        font = _load_font(font_paths, size)
        try:
            lines = _wrap_lines(probe_draw, caption_text, font, max_width)
            break
        except ValueError:
            if size <= 14:
                raise
            size -= 2

    sample_bbox = probe_draw.textbbox((0, 0), "Ag", font=font)
    line_height = max(1, sample_bbox[3] - sample_bbox[1]) + max(4, size // 5)
    total_text_height = len(lines) * line_height
    vertical_padding = max(24, int(height * 0.025))
    caption_height = max(int(height * 0.12), total_text_height + 2 * vertical_padding)
    new_height = height + caption_height

    new_img = Image.new('RGB', (width, new_height), 'white')
    new_img.paste(img.convert('RGB'), (0, 0))
    draw = ImageDraw.Draw(new_img)
    start_y = height + (caption_height - total_text_height) // 2

    for i, line in enumerate(lines):
        line_bbox = draw.textbbox((0, 0), line, font=font)
        line_width = line_bbox[2] - line_bbox[0]
        line_x = (width - line_width) // 2
        line_y = start_y + i * line_height
        draw.text((line_x, line_y), line, fill='black', font=font)

    # Determine output path
    if not output_path:
        base, ext = os.path.splitext(input_path)
        output_path = f"{base}_captioned{ext}"
        if os.path.lexists(output_path) and not force:
            raise FileExistsError(f"Refusing to overwrite existing captioned image: {output_path}")

    new_img.save(output_path)
    print(f"Saved: {output_path}")
    return output_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add caption to comic image")
    parser.add_argument("input", help="Input image path")
    parser.add_argument("caption", help="Caption text")
    parser.add_argument("--size", type=int,
                        help="Font size in pixels (default: 3.5%% of image height)")
    parser.add_argument("--output", help="Output path (default: input_captioned.ext)")
    parser.add_argument("--font", help="Explicit TrueType/OpenType serif font path")
    parser.add_argument("--force", action="store_true",
                        help="Allow replacement of an existing output path")

    args = parser.parse_args()
    try:
        add_caption(args.input, args.caption, args.size, args.output, args.font, force=args.force)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")
