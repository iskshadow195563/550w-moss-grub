#!/usr/bin/env bash
# 550W MOSS: install only a GRUB theme, using existing boot entries.
set -Eeuo pipefail
umask 022
readonly SYS_ROOT=""
PACKAGE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
THEME="$SYS_ROOT/boot/grub/themes/550w-moss"
DROPIN="$SYS_ROOT/etc/default/grub.d/zzzz-550w-moss.cfg"
CFG="$SYS_ROOT/boot/grub/grub.cfg"
STATE="$SYS_ROOT/var/lib/550w-moss"
PROFILE=1080p
TIMEOUT=8
DRY_RUN=0

usage() {
    cat <<'EOF'
用法：sudo bash install.sh [--resolution 720p|1080p|1440p|4k] [--timeout 秒数] [--dry-run]
默认：1080p、8 秒。--timeout -1 表示始终等待选择。
仅设置主题、图形菜单和等待时间，保留现有默认系统与启动项。
EOF
}
fail() { printf '错误：%s\n' "$*" >&2; exit 1; }
while (($#)); do
    case "$1" in
        --resolution) (($# >= 2)) || fail '缺少分辨率参数'; PROFILE=$2; shift 2 ;;
        --timeout) (($# >= 2)) || fail '缺少等待时间参数'; TIMEOUT=$2; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "未知参数：$1" ;;
    esac
done
case "$PROFILE" in
    720p) MODE='1280x720,1280x800,1024x768,auto'; FONT=18 ;;
    1080p) MODE='1920x1080,1280x720,1280x800,1024x768,auto'; FONT=26 ;;
    1440p) MODE='2560x1440,1920x1080,auto'; FONT=34 ;;
    4k) MODE='3840x2160,2560x1440,1920x1080,auto'; FONT=50 ;;
    *) fail '分辨率必须为 720p、1080p、1440p 或 4k' ;;
esac
[[ "$TIMEOUT" == '-1' || "$TIMEOUT" =~ ^[1-9][0-9]{0,2}$ ]] || fail '等待时间必须为 1–999 秒，或 -1'
[[ $(uname -s) == Linux ]] || fail '请在已安装的 Ubuntu 中运行，不能在 Windows 或 WSL 中安装'
if [[ -r /proc/sys/kernel/osrelease ]] && grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease; then
    fail 'WSL 不控制电脑的启动菜单；请重启进入已安装的 Ubuntu 后运行'
fi
[[ -r "$SYS_ROOT/etc/default/grub" && -r "$CFG" ]] || fail '没有找到现有 Ubuntu GRUB 配置'
[[ -d "$SYS_ROOT/etc/default/grub.d" ]] || fail '缺少 /etc/default/grub.d，暂不支持此 GRUB 配置方式'
for cmd in grub-mkconfig grub-script-check flock mktemp cp mv install; do
    command -v "$cmd" >/dev/null || fail "缺少工具：$cmd（Ubuntu 中通常由 grub-common 提供 GRUB 工具）"
done
grep -q 'default/grub.d/' "$(command -v grub-mkconfig)" || fail '当前 grub-mkconfig 不支持配置片段目录'
for asset in background.png "theme-$PROFILE.txt" "moss-cjk-$FONT.pf2" icons/ubuntu.png selected_c.png terminal_c.png; do
    [[ -r "$PACKAGE/theme/$asset" ]] || fail "主题文件缺失：$asset"
done
if [[ -e "$THEME" || -e "$DROPIN" ]]; then
    [[ -f "$STATE/managed" && $(cat "$STATE/managed") == '550w-moss-v1' ]] || fail '目标位置已存在非本安装包管理的文件，已停止以避免覆盖'
fi
if [[ -e "$STATE" ]]; then
    [[ -f "$STATE/managed" && $(cat "$STATE/managed") == '550w-moss-v1' ]] || fail '备份目录状态不完整，请先人工检查 /var/lib/550w-moss'
fi
printf '主题：%s\n显示模式：%s\n等待：%s 秒\n' "$PROFILE" "$MODE" "$TIMEOUT"
printf '保留当前默认系统、Windows / Ubuntu 入口、内核与恢复模式。\n'
if ((DRY_RUN)); then
    printf '预检查完成；未修改任何文件。正式安装后仍需验证生成的菜单。\n'
    exit 0
fi
((EUID == 0)) || fail '请使用 sudo bash install.sh'
exec 9>"$SYS_ROOT/run/lock/550w-moss.lock"
flock -n 9 || fail '另一个 MOSS 安装或卸载进程正在运行'
WORK=$(mktemp -d "$SYS_ROOT/var/tmp/550w-moss.XXXXXX")
HAD_THEME=0; HAD_DROPIN=0; NEW_STATE=0; CHANGED=0; COMMITTED=0; CANDIDATE=''
[[ ! -d "$THEME" ]] || { HAD_THEME=1; cp -a -- "$THEME" "$WORK/previous-theme"; }
[[ ! -f "$DROPIN" ]] || { HAD_DROPIN=1; cp -a -- "$DROPIN" "$WORK/previous-dropin"; }
cp -a -- "$CFG" "$WORK/previous-grub.cfg"
cleanup() {
    local code=$?
    trap - EXIT
    if (( ! COMMITTED && CHANGED )); then
        printf '安装未完成，正在恢复安装前的主题与配置……\n' >&2
        rm -rf -- "$THEME"
        if ((HAD_THEME)); then cp -a -- "$WORK/previous-theme" "$THEME"; fi
        rm -f -- "$DROPIN"
        if ((HAD_DROPIN)); then cp -a -- "$WORK/previous-dropin" "$DROPIN"; fi
        cp -a -- "$WORK/previous-grub.cfg" "$CFG"
        if ((NEW_STATE)); then rm -rf -- "$STATE"; fi
    fi
    [[ -z "$CANDIDATE" ]] || rm -f -- "$CANDIDATE"
    rm -rf -- "$WORK"
    exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -- "$WORK/theme"
cp -a -- "$PACKAGE/theme/." "$WORK/theme/"
cp -- "$WORK/theme/theme-$PROFILE.txt" "$WORK/theme/theme.txt"
if [[ ! -e "$STATE" ]]; then
    NEW_STATE=1
    CHANGED=1
    install -d -m 700 -- "$STATE"
    cp -a -- "$CFG" "$STATE/grub.cfg.before-install"
    printf '550w-moss-v1\n' > "$STATE/managed"
fi
CHANGED=1
install -d -- "$(dirname -- "$THEME")"
rm -rf -- "$THEME"
mv -- "$WORK/theme" "$THEME"
find "$THEME" -type d -exec chmod 755 {} +
find "$THEME" -type f -exec chmod 644 {} +
cat > "$DROPIN" <<EOF
# Managed by 550W MOSS. Remove with uninstall.sh.
GRUB_THEME="/boot/grub/themes/550w-moss/theme.txt"
GRUB_FONT="/boot/grub/themes/550w-moss/moss-cjk-$FONT.pf2"
GRUB_GFXMODE="$MODE"
if [ -n "\${GRUB_TERMINAL:-}" ]; then
    GRUB_TERMINAL_INPUT="\${GRUB_TERMINAL_INPUT:-\$GRUB_TERMINAL}"
    unset GRUB_TERMINAL
fi
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_TIMEOUT_STYLE="menu"
GRUB_TIMEOUT=$TIMEOUT
GRUB_RECORDFAIL_TIMEOUT=$TIMEOUT
EOF
# Build beside the live file, validate first, then atomically activate.
CANDIDATE=$(mktemp "$SYS_ROOT/boot/grub/.moss-grub.cfg.XXXXXX")
grub-mkconfig -o "$CANDIDATE"
grub-script-check "$CANDIDATE"
grep -Eq '^[[:space:]]*set theme=.*[/]550w-moss/theme[.]txt' "$CANDIDATE" || fail '新配置没有加载 MOSS 主题，可能被其他配置覆盖'
grep -Eq '^[[:space:]]*menuentry[[:space:]]' "$CANDIDATE" || fail '生成的配置中没有启动项'
if grep -qiE '^[[:space:]]*menuentry.*Windows' "$WORK/previous-grub.cfg"; then
    grep -qiE '^[[:space:]]*menuentry.*Windows' "$CANDIDATE" || fail '重新生成菜单后 Windows 入口丢失，已取消安装'
fi
if grep -Eq '^[[:space:]]*linux(efi)?[[:space:]]' "$WORK/previous-grub.cfg"; then
    grep -Eq '^[[:space:]]*linux(efi)?[[:space:]]' "$CANDIDATE" || fail '重新生成菜单后 Linux 内核入口丢失，已取消安装'
fi
chmod --reference="$CFG" "$CANDIDATE"
chown --reference="$CFG" "$CANDIDATE"
mv -f -- "$CANDIDATE" "$CFG"
COMMITTED=1
printf '\n安装完成。下次通过 Ubuntu 的 GRUB 启动时显示主题。\n'
printf '卸载：sudo bash uninstall.sh\n初始配置备份：%s/grub.cfg.before-install\n' "$STATE"
if ! grep -qiE '^[[:space:]]*menuentry.*Windows' "$CFG"; then
    printf '提醒：当前 GRUB 菜单中没有找到名为 Windows 的入口，请运行 bash check.sh 检查原有双系统配置。\n'
fi
