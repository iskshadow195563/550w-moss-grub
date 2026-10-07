#!/usr/bin/env bash
# Creates a bootable demo ISO without accessing host disks or boot settings.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PROFILE=${1:-1080p}
case "$PROFILE" in
    720p) MODE=1280x720,1280x800,1024x768; FONT=18 ;;
    1080p) MODE=1920x1080; FONT=26 ;;
    1440p) MODE=2560x1440; FONT=34 ;;
    4k) MODE=3840x2160; FONT=50 ;;
    *) printf '用法：bash scripts/build-preview.sh [720p|1080p|1440p|4k]\n' >&2; exit 1 ;;
esac
command -v grub-mkrescue >/dev/null
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/boot/grub/themes/550w-moss" "$ROOT/dist"
cp -a -- "$ROOT/theme/." "$WORK/boot/grub/themes/550w-moss/"
cp -- "$ROOT/theme/theme-$PROFILE.txt" "$WORK/boot/grub/themes/550w-moss/theme.txt"
cat > "$WORK/boot/grub/grub.cfg" <<EOF
insmod all_video
insmod gfxterm
insmod gfxmenu
insmod png
EOF
for font in "$ROOT/theme"/*.pf2; do
    printf 'loadfont /boot/grub/themes/550w-moss/%s\n' "$(basename -- "$font")" >> "$WORK/boot/grub/grub.cfg"
done
cat >> "$WORK/boot/grub/grub.cfg" <<EOF
set gfxmode=$MODE,auto
set gfxterm_font="MOSS CJK Regular $FONT"
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
