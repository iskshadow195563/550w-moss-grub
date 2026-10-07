#!/usr/bin/env bash
# Read-only diagnostics; does not mount partitions or change boot settings.
set -u
printf '550W MOSS / GRUB 只读检查\n\n'
if [[ $(uname -s) != Linux ]]; then printf '请在已安装的 Ubuntu 中运行本脚本。\n'; exit 1; fi
if grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease; then
    printf '当前环境是 WSL，无法检查电脑固件启动菜单。请重启进入 Ubuntu。\n'; exit 1
fi
if [[ -d /sys/firmware/efi ]]; then printf '[OK] 当前以 UEFI 模式启动\n'; else printf '[提示] 当前以 Legacy BIOS 模式启动；背景中的 UEFI 是装饰文字\n'; fi
for cmd in grub-mkconfig grub-script-check; do
    if command -v "$cmd" >/dev/null; then printf '[OK] %s 可用\n' "$cmd"; else printf '[缺少] %s\n' "$cmd"; fi
done
if [[ -r /boot/grub/grub.cfg ]]; then
    printf '\n现有启动项：\n'
    grep -E '^[[:space:]]*(menuentry|submenu)[[:space:]]' /boot/grub/grub.cfg || true
    printf '\n'
    if grep -qiE '^[[:space:]]*menuentry.*Windows' /boot/grub/grub.cfg; then printf '[OK] 菜单包含 Windows 入口\n'; else printf '[提示] 未找到名称包含 Windows 的入口\n'; fi
else
    printf '[提示] 无法读取 /boot/grub/grub.cfg，可用 sudo bash check.sh 再检查\n'
fi
if [[ -f /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi ]]; then
    printf '[OK] Ubuntu 的已挂载 EFI 分区中存在 Windows EFI 文件\n'
else
    printf '[提示] /boot/efi 中未找到 Windows EFI 文件；它可能位于另一块磁盘的 EFI 分区\n'
fi
printf '\n显示模式请在 GRUB 中按 C，运行 videoinfo 查询（按 Esc 返回）。\n'
printf '本脚本不会调整 EFI 启动顺序、启用 os-prober 或添加启动项。\n'
