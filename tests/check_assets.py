"""Check real PF2 metadata and every layout's asset/font references."""
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
THEME = ROOT / "theme"
font_names = set()
for path in THEME.glob("*.pf2"):
    data = path.read_bytes()
    assert data[:12] == b"FILE\x00\x00\x00\x04PFF2", path
    offset = 0
    name = None
    glyphs = set()
    while offset + 8 <= len(data):
        tag = data[offset:offset+4]
        length = struct.unpack_from(">I", data, offset+4)[0]
        block = data[offset+8:offset+8+length]
        if tag == b"NAME":
            name = block.rstrip(b"\0").decode("ascii")
            font_names.add(name)
        if tag == b"CHIX":
            glyphs = {struct.unpack_from(">I", block, i)[0] for i in range(0, length, 9)}
        if tag == b"DATA":
            break
        offset += 8 + length
    assert name and ord("U") in glyphs, path
    if "cjk" in path.name:
        assert all(ord(char) in glyphs for char in "的高级选项恢复模式韌體設定—…"), path
    print(f"OK {path.name}: {name}, {len(glyphs)} glyphs")

for path in THEME.glob("theme*.txt"):
    content = path.read_text()
    for name in re.findall(r'(?:item_font|font|message-font|terminal-font):?\s*=?:?\s*"([^"]+)"', content):
        if name != "inherit":
            assert name in font_names, (path, name)
    assert content.count('id = "__timeout__"') == 1
    for pattern in re.findall(r'(?:pixmap_style|scrollbar_frame|scrollbar_thumb)\s*=\s*"([^"]+)"', content):
        for suffix in ("c", "n", "s", "e", "w", "nw", "ne", "sw", "se"):
            assert (THEME / pattern.replace("*", suffix)).is_file(), (path, pattern, suffix)
    print(f"OK {path.name}: asset and font references")
print("All theme assets verified")
