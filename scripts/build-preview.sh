#!/usr/bin/env bash
# Creates a bootable demo ISO without accessing host disks or boot settings.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PROFILE=${1:-1080p}
case "$PROFILE" in
    compat) MODE=1024x768,800x600,640x480; FONT=14; HELP_FONT=12 ;;
    720p) MODE=1280x720,1280x800,1024x768; FONT=18; HELP_FONT=12 ;;
    1080p) MODE=1920x1080; FONT=26; HELP_FONT=18 ;;
    1440p) MODE=2560x1440; FONT=34; HELP_FONT=24 ;;
    4k) MODE=3840x2160; FONT=50; HELP_FONT=34 ;;
    *) printf '用法：bash scripts/build-preview.sh [compat|720p|1080p|1440p|4k]\n' >&2; exit 1 ;;
esac
# Used by isolated VM tests to exercise firmware resolution fallback.
MODE=${MOSS_PREVIEW_GFXMODE:-$MODE}
command -v grub-mkrescue >/dev/null
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/boot/grub/themes/550w-moss" "$ROOT/dist"
cp -a -- "$ROOT/theme/." "$WORK/boot/grub/themes/550w-moss/"
cp -- "$ROOT/theme/theme-$PROFILE.txt" "$WORK/boot/grub/themes/550w-moss/theme.txt"
for font_file in "$WORK/boot/grub/themes/550w-moss"/*.pf2; do
    case "${font_file##*/}" in
        "moss-cjk-$FONT.pf2"|moss-cjk-14.pf2|"moss-text-$HELP_FONT.pf2") ;;
        *) rm -f -- "$font_file" ;;
    esac
done
cat > "$WORK/boot/grub/grub.cfg" <<EOF
insmod all_video
insmod gfxterm
insmod gfxmenu
insmod png
loadfont /boot/grub/themes/550w-moss/moss-cjk-14.pf2
set gfxterm_font="MOSS CJK Regular 14"
export gfxterm_font
EOF
for font in "$WORK/boot/grub/themes/550w-moss"/*.pf2; do
    printf 'loadfont /boot/grub/themes/550w-moss/%s\n' "$(basename -- "$font")" >> "$WORK/boot/grub/grub.cfg"
done
cat >> "$WORK/boot/grub/grub.cfg" <<EOF
set gfxmode=$MODE,auto
terminal_output gfxterm
set theme=/boot/grub/themes/550w-moss/theme.txt
export theme
set default=0
set timeout_style=menu
set timeout=30
menuentry 'Ubuntu' --class ubuntu {
    echo 'DEMO ONLY - no real operating system is loaded.'
    sleep --interruptible 30
}
submenu 'Ubuntu 的高级选项' --class submenu {
    menuentry 'Ubuntu — latest kernel' --class ubuntu { echo 'DEMO ONLY'; sleep --interruptible 30; }
    menuentry 'Ubuntu — recovery mode' --class recovery { echo 'DEMO ONLY'; sleep --interruptible 30; }
    menuentry 'Ubuntu — previous kernel' --class ubuntu { echo 'DEMO ONLY'; sleep --interruptible 30; }
    menuentry 'Ubuntu — previous recovery mode' --class recovery { echo 'DEMO ONLY'; sleep --interruptible 30; }
    menuentry 'Ubuntu — older kernel' --class ubuntu { echo 'DEMO ONLY'; sleep --interruptible 30; }
    menuentry 'Ubuntu — older recovery mode' --class recovery { echo 'DEMO ONLY'; sleep --interruptible 30; }
}
menuentry 'Windows 11 / Windows Boot Manager' --class windows {
    echo 'DEMO ONLY - the installer preserves your real Windows entry.'
    sleep --interruptible 30
}
menuentry 'UEFI Firmware Settings' --class uefi {
    echo 'DEMO ONLY - no firmware settings are changed.'
    sleep --interruptible 30
}
EOF
grub-script-check "$WORK/boot/grub/grub.cfg"
args=(--fonts= --themes= --locales=)
if [[ -n "${GRUB_MODULES_DIR:-}" ]]; then args+=(-d "$GRUB_MODULES_DIR"); fi
grub-mkrescue "${args[@]}" -o "$ROOT/dist/moss-preview-$PROFILE.iso" "$WORK"
printf '演示 ISO：%s/dist/moss-preview-%s.iso\n' "$ROOT" "$PROFILE"
