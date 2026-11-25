#!/usr/bin/env python3
import math
from PIL import Image, ImageDraw, ImageFilter

def create_app_icon(output_path="docs/screenshots/mate_concept_icon.png", size=1024):
    # 1. Canvas with supersampling for anti-aliasing
    scale = 2
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 2. Rich Apple HIG Gradient Background
    # Deep midnight indigo to vibrant sapphire / cobalt
    top_color = (12, 18, 48)      # #0C1230 deep navy indigo
    bottom_color = (24, 52, 138)  # #18348A vibrant royal blue
    accent_glow = (56, 189, 248)  # #38BDF8 electric cyan

    for y in range(s):
        t = y / float(s)
        # S-curve ease
        t_ease = t * t * (3 - 2 * t)
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * t_ease)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * t_ease)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * t_ease)
        draw.line([(0, y), (s, y)], fill=(r, g, b, 255))

    # 3. Soft ambient radial glow in the center / upper-right (Apple Intelligence aura)
    glow_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    center_x, center_y = int(s * 0.55), int(s * 0.45)
    radius = int(s * 0.45)
    for r_i in range(radius, 0, -8):
        alpha = int(45 * (1.0 - r_i / radius) ** 1.5)
        glow_draw.ellipse(
            [center_x - r_i, center_y - r_i, center_x + r_i, center_y + r_i],
            fill=(59, 130, 246, alpha)
        )
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=scale * 20))
    img = Image.alpha_composite(img, glow_layer)

    # 4. Draw Friendly Companion 'M' Mark (Solid, rounded, tactile)
    # The 'M' represents two companions side-by-side with joined focus
    glyph_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glyph_layer)

    cx = s // 2
    cy = int(s * 0.53)
    span = int(s * 0.62)
    left = cx - span // 2
    right = cx + span // 2
    top = int(cy - s * 0.22)
    bottom = int(cy + s * 0.24)
    stroke_w = int(s * 0.105)
    r_cap = stroke_w // 2

    col1 = left + r_cap
    col2 = left + int(span * 0.35)
    col3 = cx
    col4 = right - int(span * 0.35)
    col5 = right - r_cap

    # Draw smooth drop shadow for the glyph
    shadow_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(shadow_layer)

    # Draw left pillar, center dip, right pillar
    points = [
        (col1, bottom),
        (col1, top + r_cap * 2),
        (col3, int(cy + s * 0.08)),
        (col5, top + r_cap * 2),
        (col5, bottom)
    ]

    # Two fluid arched ribbons for the companion 'M'
    # Arch 1 (Left User pillar -> center)
    # Arch 2 (Center -> Right Assistant pillar)
    # Let's draw thick smooth lines with rounded joints
    sh_draw.line([(col1, bottom), (col1, top + stroke_w)], fill=(0, 0, 20, 160), width=stroke_w)
    sh_draw.line([(col1, top + stroke_w), (col3, int(cy + s * 0.08))], fill=(0, 0, 20, 160), width=stroke_w)
    sh_draw.line([(col3, int(cy + s * 0.08)), (col5, top + stroke_w)], fill=(0, 0, 20, 160), width=stroke_w)
    sh_draw.line([(col5, top + stroke_w), (col5, bottom)], fill=(0, 0, 20, 160), width=stroke_w)
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=scale * 16))

    # Offset shadow down
    offset_shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    offset_shadow.paste(shadow_layer, (0, int(scale * 12)))
    img = Image.alpha_composite(img, offset_shadow)

    # Gradient for the 'M' glyph: Electric Cyan -> Vibrant Sky -> Apple Lilac
    # Draw the ribbon shapes
    ribbon_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rb_draw = ImageDraw.Draw(ribbon_layer)

    # Left pillar
    rb_draw.rounded_rectangle(
        [col1 - r_cap, top + stroke_w // 2, col1 + r_cap, bottom],
        radius=r_cap,
        fill=(255, 255, 255, 255)
    )
    # Right pillar
    rb_draw.rounded_rectangle(
        [col5 - r_cap, top + stroke_w // 2, col5 + r_cap, bottom],
        radius=r_cap,
        fill=(255, 255, 255, 255)
    )

    # Left arch down to center
    rb_draw.line([(col1, top + stroke_w), (col3, int(cy + s * 0.08))], fill=(255, 255, 255, 255), width=stroke_w)
    # Right arch up from center
    rb_draw.line([(col3, int(cy + s * 0.08)), (col5, top + stroke_w)], fill=(255, 255, 255, 255), width=stroke_w)

    # Joint caps
    rb_draw.ellipse([col1 - r_cap, top + stroke_w // 2, col1 + r_cap, top + stroke_w // 2 + stroke_w], fill=(255, 255, 255, 255))
    rb_draw.ellipse([col5 - r_cap, top + stroke_w // 2, col5 + r_cap, top + stroke_w // 2 + stroke_w], fill=(255, 255, 255, 255))
    rb_draw.ellipse([col3 - r_cap, int(cy + s * 0.08) - r_cap, col3 + r_cap, int(cy + s * 0.08) + r_cap], fill=(255, 255, 255, 255))

    # Colorize the ribbon with an Apple Intelligence gradient (Cyan to Coral/Lilac)
    ribbon_gradient = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rg_draw = ImageDraw.Draw(ribbon_gradient)
    c_start = (255, 255, 255)    # pure brilliant white highlight
    c_mid = (125, 211, 252)      # electric sky blue
    c_end = (224, 231, 255)      # soft lavender white

    for x in range(s):
        prog = (x - left) / float(span)
        prog = max(0.0, min(1.0, prog))
        # subtle chromatic shift across the arches
        r = int(240 + 15 * math.sin(prog * math.pi))
        g = int(245 + 10 * math.cos(prog * math.pi))
        b = 255
        rg_draw.line([(x, 0), (x, s)], fill=(r, g, b, 255))

    # Mask ribbon
    colored_ribbon = Image.composite(ribbon_gradient, Image.new("RGBA", (s, s), (0, 0, 0, 0)), ribbon_layer)
    img = Image.alpha_composite(img, colored_ribbon)

    # 5. Add Radiant Apple Intelligence Companion Spark (4-point sparkle in the upper center-right)
    spark_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sp_draw = ImageDraw.Draw(spark_layer)
    sx = int(cx + span * 0.32)
    sy = int(top - s * 0.04)
    s_size = int(s * 0.10)

    # Outer glow
    for r_i in range(s_size * 2, 0, -4):
        alpha = int(70 * (1.0 - r_i / (s_size * 2)) ** 2)
        sp_draw.ellipse([sx - r_i, sy - r_i, sx + r_i, sy + r_i], fill=(96, 165, 250, alpha))

    # Sparkle points
    sparkle_pts = [
        (sx, sy - s_size),
        (sx + int(s_size * 0.28), sy - int(s_size * 0.28)),
        (sx + s_size, sy),
        (sx + int(s_size * 0.28), sy + int(s_size * 0.28)),
        (sx, sy + s_size),
        (sx - int(s_size * 0.28), sy + int(s_size * 0.28)),
        (sx - s_size, sy),
        (sx - int(s_size * 0.28), sy - int(s_size * 0.28))
    ]
    sp_draw.polygon(sparkle_pts, fill=(255, 255, 255, 255))
    sp_draw.ellipse([sx - int(s_size * 0.25), sy - int(s_size * 0.25), sx + int(s_size * 0.25), sy + int(s_size * 0.25)], fill=(255, 240, 180, 255))

    img = Image.alpha_composite(img, spark_layer)

    # 6. Downsample smoothly with Lanczos to final 1024x1024
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    final_img.save(output_path, "PNG")
    print(f"Generated AppIcon at: {output_path}")

if __name__ == "__main__":
    create_app_icon()
