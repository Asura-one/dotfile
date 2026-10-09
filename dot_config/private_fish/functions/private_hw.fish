function hw -d "Open Herdr workspace for a project"
    set -l project $argv[1]

    if test -z "$project"
        echo "用法: hw <项目名>"
        echo "示例: hw DiJiang"
        return 1
    end

    # 常见项目路径映射
    switch $project
        case DiJiang
            set -l path ~/Project/DiJiang
        case WWYD
            set -l path ~/Project/WWYD
        case XuanShu
            set -l path ~/Project/XuanShu
        case Cheermee
            set -l path ~/Project/Cheermee
        case chain
            set -l path ~/Work/chain-telecom
        case pentest
            set -l path ~/Work/chain-telecom/project/AI智能渗透平台/pentest-core
        case *
            # 直接用输入作为路径
            set -l path $project
    end

    if not test -d "$path"
        echo (set_color red)"目录不存在: $path"(set_color normal)
        return 1
    end

    # 创建或打开工作区
    herdr workspace create --cwd "$path" --label "$project" --no-focus 2>/dev/null
    herdr workspace focus "$project" 2>/dev/null

    echo (set_color green)"✅ 已打开工作区: $project ($path)"(set_color normal)
end
