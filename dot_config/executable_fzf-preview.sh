#!/bin/sh
# fzf 预览脚本 - Catppuccin Mocha 风格

file="$1"

# 目录：用 eza 预览（带图标、颜色、git 状态）
if [ -d "$file" ]; then
    eza -lah --color=always --icons=always --git "$file" 2>/dev/null | head -50
    exit 0
fi

# 二进制文件：提示
if file --mime "$file" 2>/dev/null | grep -q "binary"; then
    echo "$file is a binary file"
    exit 0
fi

# 其他文件：用 bat 预览
bat --style=numbers --color=always --theme=Catppuccin-Mocha "$file" 2>/dev/null | head -1000
