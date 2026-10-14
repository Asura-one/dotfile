#!/usr/bin/env bash
# =============================================================================
# brew-audit.sh — brew 安装包使用情况审计，辅助卸载决策 (bash 3.2 兼容)
#
# 用法:
#   brew-audit.sh            # 全量审计并输出报告 + 建议
#   brew-audit.sh --uninstall-list   # 只输出建议卸载的包名（每行一个）
#
# 设计:
#   - 只审计"顶层包"(brew leaves, 用户直接安装的), 依赖库自动保留
#   - 证据来源:
#     ① shell 历史使用次数 (fish/zsh/bash + git 子命令特判)
#     ② 配置文件/目录引用 (含 包名→命令名/配置目录 映射, 覆盖 yazi/fzf/nvim 等)
#     ③ brew services 状态
#     ④ 反向依赖复查 (被依赖 → 保留)
#     ⑤ 攻防工具白名单 + 编译工具链白名单(归入需确认)
#   - 输出分级: 🟢在用 / 🟡可能不用 / 🔴推荐卸载
#   - 卸载命令生成到文件, 不自动执行
#
# 注意:
#   - shell 历史可能被轮换/清理, 脚本内调用/别名/容器内使用统计不到
#   - 攻防工具即使 0 次也可能是关键资产, 卸载前务必人工确认
# =============================================================================
set -o pipefail

# ---------- 配置 ----------
HIST_FISH="${FISH_HISTORY:-$HOME/.local/share/fish/fish_history}"
HIST_ZSH="${ZSH_HISTORY:-$HOME/.zsh_history}"
HIST_BASH="${BASH_HISTORY:-$HOME/.bash_history}"
UNINSTALL_FILE="${BREW_AUDIT_OUT:-/tmp/brew-uninstall-list.txt}"

# 攻防/专业工具白名单: 历史统计不到但可能关键, 一律保留
PROTECTED="subfinder|sshpass|ffuf|nmap|telnet|mihomo|mole|aria2|sqlmap|hydra|john|hashcat|metasploit|msfconsole|nuclei|masscan|responder|impacket|wpscan|gobuster|dirb|wfuzz|nikto|amass|crackmapexec|evil-winrm|yazi|lazygit|herdr|mise|chezmoi|starship"

# yazi 运行时预览依赖: yazi 启动时自动检测系统命令, 不写入配置, 必须保留
YAZI_DEPS="ffmpeg|imagemagick|poppler|sevenzip|tesseract|ripgrep"

# 编译/开发工具链: 历史统计不到但可能是项目依赖, 归入"需确认"而非"推荐卸载"
BUILD_TOOLS="cmake|llvm@19|luarocks|openjdk@17|librsvg|libgit2@1.8|coreutils|goreleaser|go|rust"

# 包名 → 配置目录名 映射 (neovim->nvim 等)
config_dir_name() {
    case "$1" in
        neovim) echo "nvim" ;;
        *) echo "$1" ;;
    esac
}

# 包名 → 实际命令名列表 (用于在配置文件中匹配)
cmd_names() {
    case "$1" in
        imagemagick)    echo -e "magick\nconvert\nidentify" ;;
        poppler)        echo -e "pdftoppm\npdftotext\npdfinfo\npdftocairo" ;;
        sevenzip)       echo -e "7z\n7zz\n7za" ;;
        ffmpeg)         echo -e "ffmpeg\nffmpegthumbnailer" ;;
        ripgrep-all)    echo "rga" ;;
        git-xet)        echo "xet" ;;
        neovim)         echo -e "nvim\nneovim" ;;
        python@3.13)    echo -e "python3.13\npython3" ;;
        openjdk@17)     echo "java" ;;
        aria2)          echo "aria2c" ;;
        mercurial)      echo -e "hg\nmercurial" ;;
        zsh-autosuggestions) echo "zsh-autosuggestions" ;;
        zsh-completions)     echo "zsh-completions" ;;
        jj)             echo "jj" ;;
        zplug)          echo "zplug" ;;
        *)              echo "${1##*/}" ;;
    esac
}

# git 子命令形式: "git filter-repo" / "git delta", 历史里按子命令出现
git_subcmd_usage() {
    local c=0
    case "$1" in
        git-filter-repo) c=$(grep -c -- "git filter-repo" "$HIST_FISH" 2>/dev/null || true) ;;
        git-delta)       c=$(grep -c -- "git delta" "$HIST_FISH" 2>/dev/null || true) ;;
        *) c=0 ;;
    esac
    echo "${c:-0}"
}

# 统计某命令在历史中的使用次数
count_usage() {
    local cmd="$1" n=0 c=0
    if [ -f "$HIST_FISH" ]; then
        c=$(grep -c -- "- cmd: ${cmd}" "$HIST_FISH" 2>/dev/null || true); n=$(( n + ${c:-0} ))
    fi
    if [ -f "$HIST_ZSH" ]; then
        c=$(grep -c -- ";${cmd}" "$HIST_ZSH" 2>/dev/null || true); n=$(( n + ${c:-0} ))
    fi
    if [ -f "$HIST_BASH" ]; then
        c=$(grep -c -- "^${cmd}" "$HIST_BASH" 2>/dev/null || true); n=$(( n + ${c:-0} ))
    fi
    n=$(( n + $(git_subcmd_usage "$cmd") ))
    echo "$n"
}

# 检查是否有配置引用 (目录 / dotfile / shell 配置 / 工具链配置中的命令名)
has_config_ref() {
    local pkg="$1" dir_name cmd f
    dir_name="$(config_dir_name "$pkg")"

    # 1. 专属配置目录
    [ -d "$HOME/.config/$dir_name" ] && return 0
    [ -d "$HOME/.$dir_name" ] && return 0

    # 2. 专属配置文件
    for f in "$HOME/.${dir_name}rc" "$HOME/.${dir_name}config" "$HOME/.config/${dir_name}/config"; do
        [ -f "$f" ] && return 0
    done

    # 3. 核心 shell/git 配置中的包名或命令名
    if grep -qE "(${pkg##*/}|${dir_name})" \
        "$HOME/.config/fish/config.fish" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.gitconfig" 2>/dev/null; then
        return 0
    fi

    # 4. 工具链配置文件中的实际命令名 (yazi/fzf/lazygit/starship/nvim)
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if grep -qE "(^|[^a-z0-9_-])${cmd}([^a-z0-9_-]|$)" \
            "$HOME/.config/yazi/yazi.toml" "$HOME/.config/yazi/init.lua" \
            "$HOME/.config/fzf-preview.sh" "$HOME/.config/lazygit/config.yml" \
            "$HOME/.config/starship.toml" 2>/dev/null; then
            return 0
        fi
        if [ -d "$HOME/.config/nvim" ]; then
            grep -rqE "(^|[^a-z0-9_-])${cmd}([^a-z0-9_-]|$)" \
                "$HOME/.config/nvim" --include="*.lua" --include="*.vim" 2>/dev/null && return 0
        fi
    done < <(cmd_names "$pkg")

    return 1
}

# ---------- 主逻辑 ----------
MODE="${1:-normal}"

REMOVE_FILE="/tmp/brew-audit-remove.txt"
MAYBE_FILE="/tmp/brew-audit-maybe.txt"
KEEP_FILE="/tmp/brew-audit-keep.txt"
: > "$REMOVE_FILE"; : > "$MAYBE_FILE"; : > "$KEEP_FILE"

while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    base="${pkg##*/}"

    # ① 受保护工具 → 保留
    if echo "$base" | grep -qE "^(${PROTECTED})$"; then
        echo "$pkg" >> "$KEEP_FILE"; continue
    fi

    # ② 反向依赖复查: 被其他已安装包依赖 → 保留
    if [ -n "$(brew uses --installed "$base" 2>/dev/null)" ]; then
        echo "$pkg" >> "$KEEP_FILE"; continue
    fi

    # ②b yazi 运行时预览依赖 → 保留
    if echo "$base" | grep -qE "^(${YAZI_DEPS})$"; then
        echo "$pkg" >> "$KEEP_FILE"; continue
    fi

    svc="$(brew services list 2>/dev/null | awk -v p="$base" '$1==p {print $2}')"
    uses="$(count_usage "$base")"
    if has_config_ref "$base"; then has_conf="yes"; else has_conf="no"; fi

    # ③ 分级
    if [ "$uses" -ge 5 ] || [ "$svc" = "started" ] || [ "$has_conf" = "yes" ]; then
        echo "$pkg" >> "$KEEP_FILE"
    elif echo "$base" | grep -qE "^(${BUILD_TOOLS})$"; then
        echo "$pkg" >> "$MAYBE_FILE"
    elif [ "$uses" -eq 0 ] && [ "$has_conf" = "no" ] && [ -z "$svc" ]; then
        echo "$pkg" >> "$REMOVE_FILE"
    else
        echo "$pkg" >> "$MAYBE_FILE"
    fi
done < <(brew leaves 2>/dev/null | sort)

# ---------- 输出 ----------
if [ "$MODE" = "--uninstall-list" ]; then
    cat "$REMOVE_FILE"
    exit 0
fi

: > "$UNINSTALL_FILE"
while IFS= read -r p; do
    [ -n "$p" ] && echo "brew uninstall --force $p" >> "$UNINSTALL_FILE"
done < "$REMOVE_FILE"

info() { printf '\033[36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }

info "════════════════════════════════════════════════════════════"
info " brew 顶层包使用审计报告  ($(date '+%Y-%m-%d %H:%M'))"
info " (仅审计 brew leaves 顶层包, 依赖库不在审计范围)"
info "════════════════════════════════════════════════════════════"

echo
err "🔴 推荐卸载（0 使用 + 无配置引用 + 无依赖 + 非工具链）"
err "──────────────────────────────────────────────"
if [ -s "$REMOVE_FILE" ]; then
    while IFS= read -r p; do printf '   %-28s\n' "$p"; done < "$REMOVE_FILE"
else
    echo "   (无)"
fi

echo
warn "🟡 可能不用（有少量痕迹/编译工具链, 需人工确认）"
warn "──────────────────────────────────────────────"
if [ -s "$MAYBE_FILE" ]; then
    while IFS= read -r p; do printf '   %-28s\n' "$p"; done < "$MAYBE_FILE"
else
    echo "   (无)"
fi

echo
ok "🟢 保留（在用 / 有配置引用 / 被依赖 / 受保护）"
ok "──────────────────────────────────────────────"
while IFS= read -r p; do printf '   %-28s\n' "$p"; done < "$KEEP_FILE"

echo
info "────────── 卸载命令已生成到: $UNINSTALL_FILE ──────────"
info "  查看: cat $UNINSTALL_FILE"
info "  执行: bash $UNINSTALL_FILE   (自行确认后运行)"
echo
info "提示: 历史统计可能遗漏脚本/别名/容器内调用, 攻防工具请人工复核。"
