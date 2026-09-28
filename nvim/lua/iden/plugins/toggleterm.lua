return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      size = 20,
      open_mapping = [[<C-\>]],
      direction = "float",
      float_opts = {
        border = "curved",
      },
    })

    local Terminal = require("toggleterm.terminal").Terminal

    local lazygit = Terminal:new({ cmd = "lazygit", direction = "float", hidden = true })
    vim.keymap.set("n", "<leader>gg", function()
      lazygit:toggle()
    end, { desc = "Toggle lazygit" })

    local ncspot = Terminal:new({ cmd = "ncspot", direction = "float", hidden = true })
    vim.keymap.set("n", "<leader>sp", function()
      ncspot:toggle()
    end, { desc = "Toggle ncspot" })
  end,
}
