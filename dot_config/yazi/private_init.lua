-- ============================================================
-- Yazi Lua 初始化脚本
-- 文档: https://yazi-rs.github.io/docs/plugins/overview/
-- ============================================================

-- ------------------------------------------------------------
-- 插件初始化（网络恢复后用 ya pkg add 安装）
-- 安装命令:
--   ya pkg add yazi-rs/plugins:full-border
--   ya pkg add yazi-rs/plugins:git
--   ya pkg add yazi-rs/plugins:toggle-pane
--   ya pkg add yazi-rs/flavors:catppuccin-mocha
-- ------------------------------------------------------------

-- full-border: 为所有面板添加圆角边框
-- require("full-border"):setup({
-- 	type = "rounded", -- 可选: "bordered" | "rounded" | "double" | "heavy" | "none"
-- })

-- git: 文件列表显示 git 状态
require("git"):setup()

-- starship: 在状态栏显示 starship 提示符
-- require("starship"):setup()

-- ------------------------------------------------------------
-- 自定义 Linemode: 同时显示文件大小和修改时间
-- ------------------------------------------------------------
function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	local size = self._file:size()

	local time_str = ""
	if time > 0 then
		if os.date("%Y", time) == os.date("%Y") then
			-- 同一年显示: "10/08 14:30"
			time_str = os.date("%m/%d %H:%M", time)
		else
			-- 跨年显示: "2025/10/08"
			time_str = os.date("%Y/%m/%d", time)
		end
	end

	local size_str = size and ya.readable_size(size) or "-"
	return string.format("%s  %s", size_str, time_str)
end

-- ------------------------------------------------------------
-- 自定义 Header（已移除：不显示用户名/设备名，恢复 yazi 默认时间显示）
-- ------------------------------------------------------------
