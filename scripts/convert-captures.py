"""Losslessly encode QEMU's PPM screenshots as PNG, without changing pixels."""
from pathlib import Path
from PIL import Image

docs = Path(__file__).resolve().parents[1] / "docs"
for path in docs.glob("preview-*.ppm"):
    with Image.open(path) as screenshot:
        screenshot.save(path.with_suffix(".png"))
        print(f"{path.stem}: {screenshot.size}")
