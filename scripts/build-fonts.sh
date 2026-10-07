#!/usr/bin/env bash
# Set GRUB_MKFONT and MOSS_FONT_SOURCE when rebuilding with extracted tools.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
FONT=${MOSS_FONT_SOURCE:-/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc}
MKFONT=${GRUB_MKFONT:-grub-mkfont}
[[ -r "$FONT" ]] || { printf '需要 Noto Sans CJK 字体，或设置 MOSS_FONT_SOURCE。\n' >&2; exit 1; }
for size in 18 26 34 50; do
    "$MKFONT" -n 'MOSS CJK' -s "$size" -r '0x20-0x24f,0x2000-0x206f,0x2190-0x21ff,0x3000-0x303f,0x4e00-0x9fff,0xff00-0xffef' -o "$ROOT/theme/moss-cjk-$size.pf2" "$FONT"
done
for size in 12 18 24 34; do
    "$MKFONT" -n 'MOSS Text' -s "$size" -r '0x20-0x7e' -o "$ROOT/theme/moss-text-$size.pf2" "$FONT"
done
printf '已生成中英文字体。\n'
