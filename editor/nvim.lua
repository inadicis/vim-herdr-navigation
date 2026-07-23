-- vim-herdr-navigation — Neovim side
--
-- Seamless <C-h/j/k/l> navigation between Neovim splits and herdr panes: move
-- between Neovim splits, and at a split edge hand off to herdr so focus crosses
-- into the neighbouring herdr pane. When not inside herdr it falls back to tmux
-- (if any) or plain wincmd, so a tmux setup keeps working.
--
-- Fork (inadicis): at pane edge with no neighbor, cycles to next/prev workspace.
--
-- Load it so it wins over other <C-h/j/k/l> mappings (e.g. vim-tmux-navigator).
-- The simplest reliable way is to drop it in your config's after/plugin dir:
--   cp editor/nvim.lua ~/.config/nvim/after/plugin/herdr_nav.lua
-- or source it from your config after plugins load:
--   dofile("/path/to/vim-herdr-navigation/editor/nvim.lua")

local function herdr_cycle_workspace(dir)
  if dir ~= "up" and dir ~= "down" then return end
  local herdr = vim.env.HERDR_BIN_PATH or "herdr"
  local offset = (dir == "up") and -1 or 1
  local result = vim.fn.system({ herdr, "workspace", "list" })
  local ok, data = pcall(vim.json.decode, result)
  if not ok or not data or not data.result or not data.result.workspaces then
    return
  end
  local focused_num = nil
  local by_number = {}
  for _, ws in ipairs(data.result.workspaces) do
    by_number[ws.number] = ws.workspace_id
    if ws.focused then focused_num = ws.number end
  end
  if not focused_num then return end
  local target_id = by_number[focused_num + offset]
  if target_id then
    vim.fn.system({ herdr, "workspace", "focus", target_id })
  end
end

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return -- moved within Neovim
  end
  -- At a split edge: cross into the surrounding multiplexer.
  if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= "" then
    local herdr = vim.env.HERDR_BIN_PATH
    if herdr == nil or herdr == "" then
      herdr = "herdr"
    end
    local result = vim.fn.system({ herdr, "pane", "focus", "--direction", dir, "--current" })
    local ok, data = pcall(vim.json.decode, result)
    if ok and data and data.result and data.result.focus and data.result.focus.changed == false then
      herdr_cycle_workspace(dir)
    end
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local tmux = { left = "Left", down = "Down", up = "Up", right = "Right" }
    pcall(vim.cmd, "TmuxNavigate" .. tmux[dir])
  end
end

local function map(lhs, wincmd, dir, desc)
  vim.keymap.set("n", lhs, function()
    nav(wincmd, dir)
  end, { silent = true, noremap = true, desc = desc })
end

map("<C-h>", "h", "left", "Navigate left (vim/herdr)")
map("<C-j>", "j", "down", "Navigate down (vim/herdr)")
map("<C-k>", "k", "up", "Navigate up (vim/herdr)")
map("<C-l>", "l", "right", "Navigate right (vim/herdr)")
