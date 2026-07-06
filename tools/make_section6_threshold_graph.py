from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


OUT = Path("assets/section6_threshold_graph.png")
SCALE = 3
W, H = 2600, 800


def font(size, bold=False):
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/malgunbd.ttf" if bold else "C:/Windows/Fonts/malgun.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size * SCALE)
    return ImageFont.load_default(size * SCALE)


def text_center(draw, xy, text, fnt, fill):
    bbox = draw.textbbox((0, 0), text, font=fnt)
    x = xy[0] - (bbox[2] - bbox[0]) / 2
    y = xy[1] - (bbox[3] - bbox[1]) / 2
    draw.text((x, y), text, font=fnt, fill=fill)


def main():
    img = Image.new("RGB", (W * SCALE, H * SCALE), "white")
    draw = ImageDraw.Draw(img)

    navy = "#12396B"
    dark = "#1E2F47"
    red = "#D64242"
    blue_line = "#244C7F"
    border = "#B6C8DF"

    title_font = font(42, True)
    zone_font = font(40, True)
    rule_font = font(26)
    small_font = font(24)
    metric_name_font = font(23)
    metric_value_font = font(38, True)
    note_font = font(24)

    def sx(x):
        return int(x * SCALE)

    # Title
    draw.text((sx(40), sx(36)), "Decision logic with quantified performance", font=title_font, fill="#0E2E5A")

    # Probability band
    band_x0, band_x1 = 80, 2520
    band_y0, band_y1 = 230, 405
    axis_y = 470

    def px(p):
        return band_x0 + (band_x1 - band_x0) * p

    zones = [
        (0.00, 0.50, "#DDEBFA", "NO-FALL", "p < 0.50"),
        (0.50, 0.55, "#FFE6B3", "Rescue", "0.50 <= p < 0.55"),
        (0.55, 1.00, "#F5C6C6", "FALL", "p >= 0.55"),
    ]

    for p0, p1, color, label, rule in zones:
        x0, x1 = sx(px(p0)), sx(px(p1))
        y0, y1 = sx(band_y0), sx(band_y1)
        draw.rectangle((x0, y0, x1, y1), fill=color, outline="white", width=sx(5))
        if label == "Rescue":
            text_center(draw, ((x0 + x1) / 2, sx(band_y0 + 94)), "0.50-0.55", font(18, True), navy)
        else:
            text_center(draw, ((x0 + x1) / 2, sx(band_y0 + 70)), label, zone_font, navy)
            text_center(draw, ((x0 + x1) / 2, sx(band_y0 + 125)), rule, rule_font, dark)

    # Border around the whole band
    draw.rounded_rectangle(
        (sx(band_x0), sx(band_y0), sx(band_x1), sx(band_y1)),
        radius=sx(8),
        outline="#A9BDD7",
        width=sx(2),
    )

    # Axis with ticks and threshold markers
    draw.line((sx(band_x0), sx(axis_y), sx(band_x1), sx(axis_y)), fill=blue_line, width=sx(5))
    arrow = [(sx(band_x1), sx(axis_y)), (sx(band_x1 - 26), sx(axis_y - 14)), (sx(band_x1 - 26), sx(axis_y + 14))]
    draw.polygon(arrow, fill=blue_line)

    for p in [0, 0.25, 0.50, 0.55, 0.75, 1.00]:
        x = sx(px(p))
        draw.line((x, sx(axis_y - 22), x, sx(axis_y + 22)), fill=blue_line, width=sx(3))
        text_center(draw, (x, sx(axis_y + 62)), f"{p:.2f}", small_font, dark)

    for p, label, dx in [(0.50, "p=0.50", -95), (0.55, "p=0.55", 95)]:
        x = sx(px(p))
        draw.line((x, sx(band_y0 - 55), x, sx(band_y1 + 18)), fill=red, width=sx(5))
        text_center(draw, (x + sx(dx), sx(band_y0 - 100)), label, small_font, "#B32020")

    # Rescue callout, kept outside the narrow probability interval for readability.
    callout = (sx(1160), sx(70), sx(1440), sx(150))
    draw.rounded_rectangle(callout, radius=sx(10), fill="white", outline="#D64242", width=sx(3))
    text_center(draw, (sx(1300), sx(110)), "Rescue band", small_font, "#B32020")
    draw.line((sx(1300), sx(150), sx(px(0.525)), sx(band_y0)), fill="#D64242", width=sx(3))

    text_center(draw, (sx((band_x0 + band_x1) / 2), sx(axis_y + 128)), "Fall probability p", small_font, navy)

    # Metric cards
    metrics = [
        ("Accuracy", "98.7%", navy),
        ("Precision", "95%", navy),
        ("Recall", "96%", red),
        ("Fall F1", "95.5%", red),
    ]
    card_x, card_y, card_w, card_h, gap = 80, 655, 360, 92, 34
    for idx, (name, value, color) in enumerate(metrics):
        x0 = card_x + idx * (card_w + gap)
        box = (sx(x0), sx(card_y), sx(x0 + card_w), sx(card_y + card_h))
        draw.rounded_rectangle(box, radius=sx(8), fill="white", outline=border, width=sx(3))
        draw.text((sx(x0 + 30), sx(card_y + 18)), name, font=metric_name_font, fill="#48576A")
        vb = draw.textbbox((0, 0), value, font=metric_value_font)
        draw.text((sx(x0 + card_w - 30) - (vb[2] - vb[0]), sx(card_y + 37)), value, font=metric_value_font, fill=color)

    note = "Physics Rescue narrows the uncertain interval\nand reduces false alarms."
    lines = note.split("\n")
    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=note_font)
        draw.text((sx(2520) - (bbox[2] - bbox[0]), sx(665 + i * 34)), line, font=note_font, fill="#334155")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = img.resize((W, H), Image.Resampling.LANCZOS)
    img.save(OUT)


if __name__ == "__main__":
    main()
