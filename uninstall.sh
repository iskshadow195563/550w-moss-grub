#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly SYS_ROOT=""
THEME="$SYS_ROOT/boot/grub/themes/550w-moss"
DROPIN="$SYS_ROOT/etc/default/grub.d/zzzz-550w-moss.cfg"
STATE="$SYS_ROOT/var/lib/550w-moss"
CFG="$SYS_ROOT/boot/grub/grub.cfg"
fail() { printf '错误：%s\n' "$*" >&2; exit 1; }
(( $# == 0 )) || fail '用法：sudo bash uninstall.sh'
[[ $(uname -s) == Linux ]] || fail '请在 Ubuntu 中运行'
if grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease; then fail '请在已安装的 Ubuntu 中运行，不能在 WSL 中卸载'; fi
((EUID == 0)) || fail '请使用 sudo bash uninstall.sh'
[[ -f "$STATE/managed" && $(cat "$STATE/managed") == '550w-moss-v1' ]] || fail '没有找到本安装包的安装记录'
for cmd in grub-mkconfig grub-script-check flock; do command -v "$cmd" >/dev/null || fail "缺少工具：$cmd"; done
exec 9>"$SYS_ROOT/run/lock/550w-moss.lock"
flock -n 9 || fail '另一个 MOSS 安装或卸载进程正在运行'
WORK=$(mktemp -d "$SYS_ROOT/var/tmp/550w-moss-remove.XXXXXX")
HAD_DROPIN=0; COMMITTED=0
[[ ! -f "$DROPIN" ]] || { HAD_DROPIN=1; cp -a -- "$DROPIN" "$WORK/dropin"; }
CANDIDATE=$(mktemp "$SYS_ROOT/boot/grub/.moss-remove.cfg.XXXXXX")
cleanup() {
    local code=$?
    trap - EXIT
    if (( ! COMMITTED && HAD_DROPIN )); then cp -a -- "$WORK/dropin" "$DROPIN"; fi
    rm -f -- "$CANDIDATE"
    rm -rf -- "$WORK"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
rm -f -- "$DROPIN"
grub-mkconfig -o "$CANDIDATE"
grub-script-check "$CANDIDATE"
grep -Eq '^[[:space:]]*menuentry[[:space:]]' "$CANDIDATE" || fail '生成的配置没有启动项，已恢复主题配置'
if grep -qiE '^[[:space:]]*menuentry.*Windows' "$CFG"; then
    grep -qiE '^[[:space:]]*menuentry.*Windows' "$CANDIDATE" || fail '新配置缺少 Windows 入口，已恢复主题配置'
fi
if grep -Eq '^[[:space:]]*linux(efi)?[[:space:]]' "$CFG"; then
    grep -Eq '^[[:space:]]*linux(efi)?[[:space:]]' "$CANDIDATE" || fail '新配置缺少 Linux 内核入口，已恢复主题配置'
fi
chmod --reference="$CFG" "$CANDIDATE"
chown --reference="$CFG" "$CANDIDATE"
mv -f -- "$CANDIDATE" "$CFG"
COMMITTED=1
rm -rf -- "$THEME"
printf '主题已卸载，已使用当前内核与原有设置重新生成菜单。\n'
printf '保留初始备份：%s/grub.cfg.before-install\n' "$STATE"
