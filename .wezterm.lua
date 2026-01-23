local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ==========================================
-- 1. 基础环境
-- ==========================================
config.default_prog = { 'powershell.exe' }
config.color_scheme = 'Tokyo Night' -- 颜值担当

-- ==========================================
-- 2. 窗口与外观 (关键优化)
-- ==========================================
config.window_decorations = "RESIZE" -- 去掉 Windows 标题栏
config.win32_system_backdrop = 'Acrylic' -- 亚克力模糊
config.window_background_opacity = 0.85 -- 透明度

-- 字体设置 (建议去下载安装 Nerd Font 版本，否则图标可能显示问号)
config.font = wezterm.font_with_fallback {
  'JetBrains Mono', -- 英文主字体
  'Microsoft YaHei', -- 中文兜底
}
config.font_size = 13.0

-- 优化标签栏样式 (更现代，融入背景)
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.colors = {
  tab_bar = {
    -- 让标签栏背景也透明，不仅是窗口内容透明
    background = 'rgba(0,0,0,0)', 
  }
}

-- ==========================================
-- 3. 交互手感
-- ==========================================
config.default_cursor_style = 'BlinkingBar' -- 闪烁竖线光标
config.audible_bell = "Disabled" --哪怕报错也不要发出声音
config.scrollback_lines = 5000 -- 历史回滚行数

-- ==========================================
-- 4. 鼠标行为 (符合 Windows 习惯)
-- ==========================================
config.mouse_bindings = {
  -- 右键粘贴
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- 按住 Ctrl + 鼠标滚轮 = 调整字体大小
  {
    event = { Down = { streak = 1, button = { WheelUp = 1 } } },
    mods = 'CTRL',
    action = wezterm.action.IncreaseFontSize,
  },
  {
    event = { Down = { streak = 1, button = { WheelDown = 1 } } },
    mods = 'CTRL',
    action = wezterm.action.DecreaseFontSize,
  },
}
-- ==========================================
-- 5. 按键绑定 (Tmux 风格：稳健、不冲突)
-- ==========================================

-- 1. 定义“唤醒键” (Leader Key)
-- 设置为 Ctrl + A (如果不习惯，可以改成 Ctrl + B)
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {
  -- 【分屏操作】
  -- 垂直分屏：按 Ctrl+A 松手，再按 - (减号)
  {
    key = '-',
    mods = 'LEADER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  -- 水平分屏：按 Ctrl+A 松手，再按 = (等号，就在减号旁边，不用按Shift)
  {
    key = '=',
    mods = 'LEADER',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  
  -- 【关闭分屏】
  -- 按 Ctrl+A 松手，再按 Backspace
  {
    key = 'Backspace',
    mods = 'LEADER',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  -- 【最大化/恢复当前分屏】
  -- 按 Ctrl+A 松手，再按 z (zoom)
  {
    key = 'z',
    mods = 'LEADER',
    action = wezterm.action.TogglePaneZoomState,
  },
  -- 【强制 Ctrl+V 粘贴】
  -- 警告：这会让您在 Vim 等工具中失去 Ctrl+V (块选择) 的功能
  -- 但如果您不怎么用 Vim 的块选择，这个设置非常爽
  {
    key = 'v',
    mods = 'CTRL',
    action = wezterm.action.PasteFrom 'Clipboard',
  },

  -- 【光标跳转】(在分屏之间切换)
  -- 按 Ctrl+A 松手，再按方向键
  { key = 'LeftArrow', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Down' },
  
  -- 【调整分屏大小】(按住 Alt + 方向键)
  -- 这个不需要 Leader 键，直接按住 Alt 调整即可，非常方便
  { key = 'LeftArrow', mods = 'ALT', action = wezterm.action.AdjustPaneSize { 'Left', 5 } },
  { key = 'RightArrow', mods = 'ALT', action = wezterm.action.AdjustPaneSize { 'Right', 5 } },
  { key = 'UpArrow', mods = 'ALT', action = wezterm.action.AdjustPaneSize { 'Up', 5 } },
  { key = 'DownArrow', mods = 'ALT', action = wezterm.action.AdjustPaneSize { 'Down', 5 } },
}

-- ==========================================
-- 6. 酷炫的状态栏 (显示时间、工作区)
-- ==========================================
wezterm.on('update-right-status', function(window, pane)
  local date = wezterm.strftime '%Y-%m-%d %H:%M:%S'
  
  -- 获取当前窗口名称或工作区名称
  local stat = window:active_workspace()
  if stat == 'default' then
    stat = 'Admin' -- 如果是默认，就显示个更有逼格的名字
  end

  -- 设置颜色 (根据您的 Tokyo Night 主题配色)
  local color_date = { Foreground = { Color = '#c0caf5' } }
  local color_bg = { Background = { Color = '#1a1b26' } }
  
  -- 格式化输出
  window:set_right_status(wezterm.format {
    { Attribute = { Intensity = 'Bold' } },
    { Foreground = { Color = '#7aa2f7' } },
    { Text = ' ❐ ' .. stat .. '  ' }, -- 工作区图标+名称
    { Foreground = { Color = '#9ece6a' } },
    { Text = ' 🕒 ' .. date .. '  ' }, -- 时间图标+时间
  })
end)

-- ==========================================
-- 7. 智能超链接 (让正则文本可点击)
-- ==========================================
config.hyperlink_rules = {
  -- 识别 URL (默认已有，但为了保险加上)
  {
    regex = '\\b\\w+://[\\w.-]+:[0-9]{1,5}\\b',
    format = '$0',
  },
  -- 识别邮箱
  {
    regex = '\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b',
    format = 'mailto:$0',
  },
  -- [进阶] 识别 GitHub 只有 #123 这种 issue 号
  -- 只要终端里出现 #123，点击就会去 GitHub 搜索（您可以改成自己仓库的前缀）
  {
    regex = '#(\\d+)\\b',
    format = 'https://github.com/wez/wezterm/issues/$1',
  },
  -- [进阶] 识别 IP 地址 (方便运维)
  {
    regex = '\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b',
    format = 'https://ipinfo.io/$0',
  },
}


return config