"""Validate real framebuffer sizes and observable keyboard/countdown behavior."""
from pathlib import Path
from PIL import Image

DOCS = Path(__file__).resolve().parents[1] / "docs"
for profile, dimensions in {"720p": (1280,720), "1080p": (1920,1080), "1440p": (2560,1440), "4k": (3840,2160)}.items():
    pictures = {}
    for scene in ("ubuntu", "countdown", "windows", "submenu", "scroll", "terminal"):
        with Image.open(DOCS / f"preview-{profile}-{scene}.png") as source:
            assert source.size == dimensions, (profile, scene, source.size)
            pictures[scene] = source.convert("RGB")
    w, h = dimensions
    def is_red(picture, y):
        r,g,b = picture.getpixel((int(w * .9), int(h * y)))
        return r > 30 and r > g * 3 and r > b * 3
    assert is_red(pictures["ubuntu"], .26), (profile, "initial selected row")
    assert not is_red(pictures["windows"], .26), (profile, "selection did not leave Ubuntu")
    assert is_red(pictures["windows"], .46), (profile, "Windows was not selected")
    region = (int(w*.58), int(h*.88), int(w*.98), int(h*.92))
    assert pictures["ubuntu"].crop(region).tobytes() != pictures["countdown"].crop(region).tobytes(), (profile, "countdown did not update")
    assert pictures["submenu"].tobytes() != pictures["scroll"].tobytes(), (profile, "submenu did not scroll")
    print(f"OK {profile}: {w}x{h}, selected row moves, countdown updates, submenu scrolls")

# The reported regression hides every row except an oversized selected entry.
# Check all four real icons remain visible, including after returning to the menu.
for scene in ("initial", "switched", "returned", "entry-returned"):
    with Image.open(DOCS / f"compat-640-{scene}.png") as source:
        assert source.size == (640, 480), (scene, source.size)
        picture = source.convert("RGB")
        x = int(640 * .58) + 4 + 4  # menu x + padding + compact left slice
        y = int(480 * .19) + 4 + 4  # menu y + padding + compact top slice
        for row in range(4):
            icon = picture.crop((x, y + row * 40 + 4, x + 24, y + row * 40 + 28))
            white = sum(min(pixel) > 180 for pixel in icon.getdata())
            assert white > 15, (scene, row, "menu icon missing / hidden")
        red_rows = []
        for py in range(int(480 * .19), int(480 * .63)):
            r, g, b = picture.getpixel((int(640 * .9), py))
            if r > 30 and r > g * 3 and r > b * 2:
                red_rows.append(py)
        assert red_rows and max(red_rows) - min(red_rows) < 80, (scene, "oversized selection")
    print(f"OK compat 640x480 {scene}: four icons visible, compact selection")
