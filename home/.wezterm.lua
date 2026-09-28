-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

config.color_scheme = "Catppuccin Mocha"

-- This is where you actually apply your config choices
config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 17

config.enable_tab_bar = false

config.window_decorations = "RESIZE"

config.window_background_opacity = 1
config.macos_window_background_blur = 0

config.inactive_pane_hsb = {
	saturation = 0.8,
	brightness = 0.65,
}

config.window_padding = {
	left = 6,
	right = 6,
	top = 6,
	bottom = 6,
}

config.keys = {
	-- CMD+Z → Undo (Ctrl+_)
	{
		key = "z",
		mods = "CMD",
		action = wezterm.action.SendKey({
			key = "_",
			mods = "CTRL",
		}),
	},

	-- CMD+SHIFT+Z → Redo (Ctrl+X, Ctrl+_)
	{
		key = "Z",
		mods = "CMD|SHIFT",
		action = wezterm.action.Multiple({
			wezterm.action.SendKey({ key = "x", mods = "CTRL" }),
			wezterm.action.SendKey({ key = "_", mods = "CTRL" }),
		}),
	},
}

wezterm.on("format-tab-title", function(tab)
	local cwd = tab.active_pane.current_working_dir
	if cwd then
		cwd = cwd.file_path
		cwd = string.gsub(cwd, ".*/", "")
	else
		cwd = "?"
	end

	return {
		{ Text = "  " .. cwd .. "  " },
	}
end)

-- and finally, return the configuration to wezterm
return config
