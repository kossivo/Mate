#!/usr/bin/env python3
import math
from PIL import Image, ImageDraw, ImageFilter

def draw_rounded_pill(draw, p1, p2, width, color):
    """Draws a line with rounded pill ends."""
    draw.line([p1, p2], fill=color, width=width)
    r = width / 2
    draw.ellipse([p1[0] - r, p1[1] - r, p1[0] + r, p1[1] + r], fill=color)
    draw.ellipse([p2[0] - r, p2[1] - r, p2[0] + r, p2[1] + r], fill=color)

# ==============================================================================
# Concept 1: "Momentum M" (Todoist Chevron & Velocity Style)
# Like Todoist's iconic parallel diagonal task chevrons, but forming a bold 'M'
# ==============================================================================
def create_concept_todoist_momentum(output_path, size=1024, dark_mode=False):
    scale = 2
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background
    if dark_mode:
        # Deep Tech Obsidian
        c_top = (15, 23, 42)
        c_bot = (2, 6, 23)
        for y in range(s):
            t = y / s
            r = int(c_top[0] + (c_bot[0] - c_top[0]) * t)
            g = int(c_top[1] + (c_bot[1] - c_top[1]) * t)
            b = int(c_top[2] + (c_bot[2] - c_top[2]) * t)
            draw.line([(0, y), (s, y)], fill=(r, g, b, 255))
        glyph_color = (255, 255, 255)
        accent_color = (255, 90, 95)
    else:
        # Todoist-like Iconic Vibrant Coral-Red Canvas (Bold, energetic, tech)
        c_top = (235, 68, 50)    # #EB4432
        c_bot = (218, 48, 32)    # #DA3020
        for y in range(s):
            t = y / s
            r = int(c_top[0] + (c_bot[0] - c_top[0]) * t)
            g = int(c_top[1] + (c_bot[1] - c_top[1]) * t)
            b = int(c_top[2] + (c_bot[2] - c_top[2]) * t)
            draw.line([(0, y), (s, y)], fill=(r, g, b, 255))
        glyph_color = (255, 255, 255)
        accent_color = (255, 255, 255)

    # Geometric Chevrons forming an energetic M
    # Left check/chevron + Right check/chevron in unified rhythm
    cx = s / 2
    cy = s / 2
    w = s * 0.54
    h = s * 0.44
    stroke = int(s * 0.088)

    # 4 parallel dynamic angled strokes / chevrons:
    # Pillar 1 (Left vertical-angled stroke)
    # Chevron bridge (Middle V)
    # Pillar 2 (Right vertical-angled stroke)
    x1 = cx - w * 0.48
    x2 = cx - w * 0.16
    x3 = cx + w * 0.16
    x4 = cx + w * 0.48

    y_top = cy - h * 0.48
    y_mid = cy + h * 0.15
    y_bot = cy + h * 0.48

    # Subtle drop shadow behind the glyph
    sh_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sh_layer)
    sh_color = (0, 0, 0, 80) if not dark_mode else (0, 0, 0, 180)

    # Left leg
    draw_rounded_pill(sh_draw, (x1, y_top), (x1, y_bot), stroke, sh_color)
    # Left diagonal down
    draw_rounded_pill(sh_draw, (x1, y_top), (cx, y_mid), stroke, sh_color)
    # Right diagonal down
    draw_rounded_pill(sh_draw, (x4, y_top), (cx, y_mid), stroke, sh_color)
    # Right leg
    draw_rounded_pill(sh_draw, (x4, y_top), (x4, y_bot), stroke, sh_color)

    sh_layer = sh_layer.filter(ImageFilter.GaussianBlur(scale * 12))
    img.paste(sh_layer, (0, int(scale * 8)), sh_layer)

    # Draw sharp, crisp glyph strokes
    draw_rounded_pill(draw, (x1, y_top), (x1, y_bot), stroke, glyph_color)
    draw_rounded_pill(draw, (x1, y_top), (cx, y_mid), stroke, glyph_color)
    draw_rounded_pill(draw, (x4, y_top), (cx, y_mid), stroke, glyph_color)
    draw_rounded_pill(draw, (x4, y_top), (x4, y_bot), stroke, glyph_color)

    # Resize smoothly
    final = img.resize((size, size), Image.Resampling.LANCZOS)
    final.save(output_path, "PNG")

# ==============================================================================
# Concept 2: "Companion Checkmarks" (Dual Interlocking Task Checks)
# Two crisp checkmarks (User + Assistant) interlocking to form a tech M
# ==============================================================================
def create_concept_companion_checks(output_path, size=1024):
    scale = 2
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Deep Indigo / Tech Sapphire Background
    c_top = (30, 41, 59)     # Slate 800
    c_bot = (15, 23, 42)     # Slate 900
    for y in range(s):
        t = y / s
        r = int(c_top[0] + (c_bot[0] - c_top[0]) * t)
        g = int(c_top[1] + (c_bot[1] - c_top[1]) * t)
        b = int(c_top[2] + (c_bot[2] - c_top[2]) * t)
        draw.line([(0, y), (s, y)], fill=(r, g, b, 255))

    cx = s / 2
    cy = s * 0.50
    stroke = int(s * 0.092)

    # Left checkmark (User): Coral-Orange
    # Right checkmark (Mate): Electric Cyan-White
    # Combined they form 'M'
    # Checkmark 1: from (-0.28, -0.05) down to (-0.14, +0.22) then up to (0.0, -0.22)
    # Checkmark 2: from (0.0, -0.05) down to (+0.14, +0.22) then up to (+0.28, -0.22)
    p1 = (cx - s * 0.28, cy - s * 0.05)
    p2 = (cx - s * 0.14, cy + s * 0.22)
    p3 = (cx, cy - s * 0.20)
    p4 = (cx + s * 0.14, cy + s * 0.22)
    p5 = (cx + s * 0.28, cy - s * 0.05)

    # Check 1 (Left): (p1 -> p2 -> p3)
    # Check 2 (Right): (p3 -> p4 -> p5)
    # Together: p1 -> p2 -> p3 -> p4 -> p5 forms a precision checkmark 'M'!
    
    # Shadow
    sh = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sh)
    sh_c = (0, 0, 0, 140)
    draw_rounded_pill(sh_draw, p1, p2, stroke, sh_c)
    draw_rounded_pill(sh_draw, p2, p3, stroke, sh_c)
    draw_rounded_pill(sh_draw, p3, p4, stroke, sh_c)
    draw_rounded_pill(sh_draw, p4, p5, stroke, sh_c)
    sh = sh.filter(ImageFilter.GaussianBlur(scale * 14))
    img.paste(sh, (0, int(scale * 8)), sh)

    # Left Check: Coral Red (Todoist energy)
    c_coral = (244, 63, 94)   # Rose 500
    # Right Check: Pure Electric White / Cyan
    c_white = (255, 255, 255)

    draw_rounded_pill(draw, p1, p2, stroke, c_coral)
    draw_rounded_pill(draw, p2, p3, stroke, c_coral)
    draw_rounded_pill(draw, p3, p4, stroke, c_white)
    draw_rounded_pill(draw, p4, p5, stroke, c_white)

    final = img.resize((size, size), Image.Resampling.LANCZOS)
    final.save(output_path, "PNG")

# ==============================================================================
# Concept 3: "Minimal Tech Monogram" (Linear / Things 3 Tech Clean)
# Crisp White Canvas with vibrant energetic Red/Coral/Blue geometric 'M'
# ==============================================================================
def create_concept_clean_tech(output_path, size=1024):
    scale = 2
    s = size * scale
    img = Image.new("RGBA", (s, s), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    # Subtle premium off-white to pearl gradient
    for y in range(s):
        t = y / s
        v = int(255 - 10 * t)
        draw.line([(0, y), (s, y)], fill=(v, v, v + 2, 255))

    cx = s / 2
    cy = s / 2
    w = s * 0.52
    h = s * 0.44
    stroke = int(s * 0.09)

    x1 = cx - w * 0.45
    x4 = cx + w * 0.45
    y_top = cy - h * 0.48
    y_mid = cy + h * 0.16
    y_bot = cy + h * 0.48

    # Shadow
    sh = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sh)
    sh_c = (0, 0, 0, 45)
    draw_rounded_pill(sh_draw, (x1, y_top), (x1, y_bot), stroke, sh_c)
    draw_rounded_pill(sh_draw, (x1, y_top), (cx, y_mid), stroke, sh_c)
    draw_rounded_pill(sh_draw, (x4, y_top), (cx, y_mid), stroke, sh_c)
    draw_rounded_pill(sh_draw, (x4, y_top), (x4, y_bot), stroke, sh_c)
    sh = sh.filter(ImageFilter.GaussianBlur(scale * 16))
    img.paste(sh, (0, int(scale * 10)), sh)

    # Vibrant Todoist Red/Orange gradient across the strokes
    c_red = (235, 68, 50)
    draw_rounded_pill(draw, (x1, y_top), (x1, y_bot), stroke, c_red)
    draw_rounded_pill(draw, (x1, y_top), (cx, y_mid), stroke, c_red)
    draw_rounded_pill(draw, (x4, y_top), (cx, y_mid), stroke, c_red)
    draw_rounded_pill(draw, (x4, y_top), (x4, y_bot), stroke, c_red)

    final = img.resize((size, size), Image.Resampling.LANCZOS)
    final.save(output_path, "PNG")

if __name__ == "__main__":
    create_concept_todoist_momentum("docs/screenshots/mate_tech_concept1_coral.png", dark_mode=False)
    create_concept_todoist_momentum("docs/screenshots/mate_tech_concept1_dark.png", dark_mode=True)
    create_concept_companion_checks("docs/screenshots/mate_tech_concept2_checks.png")
    create_concept_clean_tech("docs/screenshots/mate_tech_concept3_white.png")
    print("Generated 4 tech logo concepts!")

# ==============================================================================
# Concept 4: "Chevron Stride M" (Direct homage to Todoist's task chevrons)
# 3 bold angled chevrons interlocking into a sharp, energetic tech M
# ==============================================================================
def create_concept_todoist_chevrons(output_path, size=1024):
    scale = 2
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Todoist Signature Coral Red
    c_top = (235, 68, 50)
    c_bot = (220, 50, 35)
    for y in range(s):
        t = y / s
        r = int(c_top[0] + (c_bot[0] - c_top[0]) * t)
        g = int(c_top[1] + (c_bot[1] - c_top[1]) * t)
        b = int(c_top[2] + (c_bot[2] - c_top[2]) * t)
        draw.line([(0, y), (s, y)], fill=(r, g, b, 255))

    cx = s / 2
    cy = s / 2
    stroke = int(s * 0.082)

    # 3 diagonal chevrons stepping across the center forming an M
    # Chevron 1 (Left): (x1, y1) -> (x2, y2) -> (x3, y3)
    span = s * 0.52
    h = s * 0.40
    
    # Left check:
    k1 = (cx - span * 0.45, cy + h * 0.20)
    k2 = (cx - span * 0.15, cy + h * 0.50)
    k3 = (cx + span * 0.15, cy - h * 0.50)
    
    # Draw two staggered Todoist-style checkmarks that intersect into an M:
    p1 = (cx - span * 0.46, cy)
    p2 = (cx - span * 0.23, cy + h * 0.45)
    p3 = (cx, cy - h * 0.35)
    p4 = (cx + span * 0.23, cy + h * 0.45)
    p5 = (cx + span * 0.46, cy)

    # Add shadow
    sh = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sh)
    draw_rounded_pill(sh_draw, p1, p2, stroke, (0, 0, 0, 70))
    draw_rounded_pill(sh_draw, p2, p3, stroke, (0, 0, 0, 70))
    draw_rounded_pill(sh_draw, p3, p4, stroke, (0, 0, 0, 70))
    draw_rounded_pill(sh_draw, p4, p5, stroke, (0, 0, 0, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(scale * 12))
    img.paste(sh, (0, int(scale * 8)), sh)

    c_white = (255, 255, 255)
    draw_rounded_pill(draw, p1, p2, stroke, c_white)
    draw_rounded_pill(draw, p2, p3, stroke, c_white)
    draw_rounded_pill(draw, p3, p4, stroke, c_white)
    draw_rounded_pill(draw, p4, p5, stroke, c_white)

    # Companion assistant dot: a clean, geometric dot resting in the top center notch
    dot_r = int(stroke * 0.65)
    dot_y = int(cy - h * 0.38)
    draw.ellipse([cx - dot_r, dot_y - dot_r, cx + dot_r, dot_y + dot_r], fill=c_white)

    final = img.resize((size, size), Image.Resampling.LANCZOS)
    final.save(output_path, "PNG")

if __name__ == "__main__":
    create_concept_todoist_chevrons("docs/screenshots/mate_tech_concept4_todoist_m.png")
