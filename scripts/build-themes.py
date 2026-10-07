"""Generate GRUB text layouts; never edits bitmap backgrounds."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILES = {
    "720p": (18, 12, 62, 9, 36, 10),
    "1080p": (26, 18, 94, 14, 56, 16),
    "1440p": (34, 24, 124, 18, 72, 22),
    "4k": (50, 34, 188, 28, 112, 32),
}

for profile, (menu_font, help_font, row, spacing, icon, pad) in PROFILES.items():
    content = f'''# 550W MOSS / {profile}. Menu titles and countdown come from GRUB.
desktop-image: "background.png"
desktop-color: "#050809"
title-text: ""
message-font: "MOSS Text Regular {help_font}"
message-color: "#ffffff"
message-bg-color: "#050809"
terminal-font: "MOSS CJK Regular {menu_font}"
terminal-box: "terminal_*.png"
terminal-border: "12"

+ boot_menu {{
    left = 58%
    top = 19%
    width = 40%
    height = 44%
    item_font = "MOSS CJK Regular {menu_font}"
    selected_item_font = "inherit"
    item_color = "#dbe0e2"
    selected_item_color = "#ffffff"
    icon_width = {icon}
    icon_height = {icon}
    item_height = {row}
    item_padding = {pad}
    item_icon_space = {pad}
    item_spacing = {spacing}
    item_pixmap_style = "row_*.png"
    selected_item_pixmap_style = "selected_*.png"
    scrollbar = true
    scrollbar_frame = "scrollbar_*.png"
    scrollbar_thumb = "thumb_*.png"
    scrollbar_width = 8
}}
+ label {{
    left = 58%
    top = 67%
    width = 38%
    height = 3%
    text = "MOSS / BOOT CONTROL"
    font = "MOSS Text Regular {help_font}"
    color = "#ff1935"
}}
+ label {{
    left = 58%
    top = 71%
    width = 38%
    height = 3%
    text = "UP / DOWN    Select system"
    font = "MOSS Text Regular {help_font}"
    color = "#dbe0e2"
}}
+ label {{
    left = 58%
    top = 74%
    width = 38%
    height = 3%
    text = "ENTER        Boot selected entry"
    font = "MOSS Text Regular {help_font}"
    color = "#dbe0e2"
}}
+ label {{
    left = 58%
    top = 77%
    width = 38%
    height = 3%
    text = "ESC          Return from submenu"
    font = "MOSS Text Regular {help_font}"
    color = "#dbe0e2"
}}
+ label {{
    left = 58%
    top = 80%
    width = 38%
    height = 3%
    text = "E  Edit entry   /   C  Command line"
    font = "MOSS Text Regular {help_font}"
    color = "#dbe0e2"
}}
+ progress_bar {{
    id = "__timeout__"
    left = 58%
    top = 88%
    width = 38%
    height = 4%
    fg_color = "#ee001d"
    bg_color = "#171e22"
    border_color = "#9fa9ae"
    text_color = "#ffffff"
    font = "MOSS Text Regular {help_font}"
    text = "AUTO BOOT IN %d s"
}}
'''
    (ROOT / "theme" / f"theme-{profile}.txt").write_text(content, encoding="utf-8", newline="\n")
(ROOT / "theme" / "theme.txt").write_bytes((ROOT / "theme" / "theme-1080p.txt").read_bytes())
print("Generated 720p, 1080p, 1440p, 4k GRUB theme layouts")
