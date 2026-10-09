function reload -d "Reload fish shell config"
    source ~/.config/fish/config.fish
    echo (set_color green)"配置已重新加载"(set_color normal)
end
