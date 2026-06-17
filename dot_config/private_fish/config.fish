# ==============================================================================
# Fish Shell 配置
# 从 .zshrc 转换而来
# 文件位置: ~/.config/fish/config.fish
# ==============================================================================

# ==============================================================================
# 关闭默认问候语
# ==============================================================================
set -g fish_greeting ""

# ==============================================================================
# Homebrew（必须最先，确保后续所有工具可被找到）
# ==============================================================================
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
end

# ==============================================================================
# 环境变量
# ==============================================================================
set -gx EDITOR nvim

# Go
set -gx GOPATH $HOME/go
set -gx GOROOT /opt/homebrew/opt/go/libexec
set -gx GO111MODULE on
set -gx GOPROXY https://goproxy.cn

# Perl
set -gx PERL5LIB $HOME/perl5/lib/perl5
set -gx PERL_LOCAL_LIB_ROOT $HOME/perl5
set -gx PERL_MB_OPT '--install_base "$HOME/perl5"'
set -gx PERL_MM_OPT "INSTALL_BASE=$HOME/perl5"

# Bun
set -gx BUN_INSTALL $HOME/.bun

# ==============================================================================
# PATH 统一管理
# Fish 自动去重，无需 typeset -U
# ==============================================================================
fish_add_path $HOME/.local/bin
fish_add_path $GOPATH/bin
fish_add_path $HOME/.cargo/bin
fish_add_path /opt/homebrew/opt/mysql-client/bin
fish_add_path /Users/cimer/software/flutter/bin
fish_add_path $BUN_INSTALL/bin
fish_add_path /Users/cimer/.codeium/windsurf/bin

# ==============================================================================
# fzf 配置
# ==============================================================================
if command -q rg
    set -gx FZF_DEFAULT_COMMAND "rg --files --hidden --glob '!.git/*'"
end

set -gx FZF_DEFAULT_OPTS "
  --layout=reverse
  --info=inline
  --border
  --margin=1
  --padding=1
  --ansi
  --preview '[[ \$(file --mime {1}) =~ binary ]] \
      && echo {1} is a binary file \
      || bat --style=numbers --color=always --theme=TwoDark {1} 2>/dev/null | head -1000'
  --bind 'enter:become(nvim {1})'
  --bind 'alt-l:become(ls -lh {1})'
  --bind 'alt-o:become(open {1})'
"

# ==============================================================================
# fzf 集成（由 fzf --fish 生成，需安装 fzf）
# 运行: fzf --fish | source
# 或者安装后执行一次: fzf --fish > ~/.config/fish/conf.d/fzf.fish
# ==============================================================================
# fzf --fish | source  # 取消注释以在启动时动态加载（较慢）

# ==============================================================================
# Fisher 插件（替代 zplug）
# 安装 Fisher: curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
#
# 等价插件安装命令（运行一次即可，无需放在配置文件里）:
#   fisher install PatrickF1/fzf.fish                  # fzf 集成
#   fisher install jorgebucaran/autopair.fish           # 自动括号
#   fisher install franciscolourenco/done               # 长命令完成通知
#   fisher install nickeb96/puffer-fish                 # 常用缩写
#   fisher install meaningful-ooo/sponge                # 历史记录清理
#   fisher install jethrokuan/z                         # z.lua 替代（纯 fish 版）
#   fisher install catppuccin/fish                      # 主题（可选）
#
# Oh-my-fish 等价插件（git / history-substring-search 已内置于 fish）:
#   git        → fish 内置 git 补全，无需插件
#   colored man pages → fish 内置彩色 man
#   history-substring-search → fish 内置，上下方向键即可
#   syntax-highlighting → fish 内置
#   autosuggestions → fish 内置
# ==============================================================================

# ==============================================================================
# History
# ==============================================================================
set -g fish_history_size 10000
# Fish 默认已去重、忽略空格开头的命令，无需额外配置

# ==============================================================================
# 代理函数
# 位置: ~/.config/fish/functions/proxy.fish 或直接写在此处
# ==============================================================================
function proxy
    set -gx http_proxy  http://127.0.0.1:12808
    set -gx https_proxy http://127.0.0.1:12808
    set -gx all_proxy   socks5://127.0.0.1:12809
    echo (set_color green)"已开启终端代理"(set_color normal)
end

function unproxy
    set -e http_proxy
    set -e https_proxy
    set -e all_proxy
    echo (set_color green)"已关闭终端代理"(set_color normal)
end

# ==============================================================================
# fzf 实用函数
# ==============================================================================

# 模糊跳转目录
function fcd
    set dir (fd -t d . / | fzf)
    or return
    cd $dir
end

# 模糊历史命令（fish 内置 Ctrl+R 已很好用，此为额外增强）
function fh
    set cmd (history | fzf +s --tac)
    or return
    commandline -- $cmd
end

# 模糊文件搜索并用 nvim 打开
# 注意：fzf 的 reload 回调运行在 sh/bash 中，不是 fish，所以用 sh 语法
function fsearch
    fzf --ansi --delimiter : \
        --layout=reverse \
        --info=inline \
        --border --margin=1 --padding=1 \
        --preview 'bat --style=numbers --color=always --theme=TwoDark --highlight-line {2} {1} 2>/dev/null | head -1000' \
        --bind 'change:reload:if [ -n {q} ]; then rg --column --line-number --no-heading --color=always --smart-case {q} || true; else rg --files --hidden --glob "!.git/*"; fi' \
        --bind 'enter:become(nvim {1} +{2})' \
        < (rg --files --hidden --glob '!.git/*' | psub)
end

# 清理 Homebrew 补全缓存
function clear_brew_cache
    rm -f ~/.zcompcache/brew_*
    echo "Homebrew 补全缓存已清理"
end

# ==============================================================================
# Obsidian fzf
# ==============================================================================
function obsidian_fzf
    set VAULT GroceryStore
    set VAULT_PATH $HOME/开源项目/瞎鸡儿搞/$VAULT

    set FILE (find $VAULT_PATH -name "*.md" -type f | \
        sed "s|$VAULT_PATH/||" | \
        fzf --preview "bat --color=always --style=plain '$VAULT_PATH/{}'" \
            --preview-window=right:60% \
            --height 80%)
    or return

    open "obsidian://open?vault=$VAULT&file="(string replace -r '\.md$' '' $FILE)
end

# abbr 需在终端运行一次，fish 会持久保存，不要写在 config.fish 里：
#   abbr -a of obsidian_fzf

# ==============================================================================
# Rust / Cargo
# ==============================================================================
# cargo env 是 bash 脚本，fish 不能直接 source
# PATH 已在上方 fish_add_path $HOME/.cargo/bin 处理，无需额外操作

# ==============================================================================
# Bun completions
# ==============================================================================
# bun 补全脚本为 bash 格式，需单独生成 fish 版，在终端运行一次：
#   bun completions fish > ~/.config/fish/completions/bun.fish

# ==============================================================================
# zoxide（替代 z.lua）
# ==============================================================================
if command -q zoxide
    zoxide init fish | source
end

# ==============================================================================
# starship 提示符
# ==============================================================================
if command -q starship
    starship init fish | source
end

# ==============================================================================
# kiro 集成
# ==============================================================================
if test "$TERM_PROGRAM" = kiro
    set kiro_path (kiro --locate-shell-integration-path fish 2>/dev/null)
    if test -n "$kiro_path"
        source $kiro_path
    end
end

# ==============================================================================
# mise（必须最后）
# ==============================================================================
if command -q mise
    mise activate fish | source
end
