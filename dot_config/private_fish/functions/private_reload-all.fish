function reload-all -d "Reload fish config in all Herdr panes"
    # 获取所有 pane 的 id（用 jq 解析 JSON）
    set -l panes (herdr pane list | jq -r '.result.panes[].pane_id')

    if test -z "$panes"
        echo (set_color red)"没有找到任何 pane"(set_color normal)
        return 1
    end

    echo (set_color blue)"正在给 (count $panes) 个 pane 发送 reload..."(set_color normal)

    for pane in $panes
        herdr pane run $pane "source ~/.config/fish/config.fish > /dev/null" 2>/dev/null
    end

    echo (set_color green)"✅ 已给所有 pane 发送 reload 命令"(set_color normal)
end
