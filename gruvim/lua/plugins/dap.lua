local function kotlin_host()
  local host = vim.fn.input("Host: ", "localhost")
  return host ~= "" and host or require("dap").ABORT
end

local function kotlin_port()
  return tonumber(vim.fn.input("Port: ", "5005")) or require("dap").ABORT
end

local function kotlin_lsp_client()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if client.name == "kotlin_lsp" then
      return client
    end
  end
end

local function kotlin_lsp_command(client, command, arguments, callback)
  client:request("workspace/executeCommand", {
    command = command,
    arguments = arguments,
  }, callback, 0)
end

local function kotlin_dap_adapter(callback)
  local client = kotlin_lsp_client()
  if not client then
    vim.notify("Kotlin DAP: kotlin_lsp is not attached to this buffer", vim.log.levels.ERROR)
    return
  end

  local workspace_uri = client.root_dir and vim.uri_from_fname(client.root_dir)
  kotlin_lsp_command(client, "start_debug_server", { workspace_uri }, function(err, port)
    port = tonumber(port)
    if err or not port then
      vim.notify(("Kotlin DAP: start_debug_server failed: %s"):format(vim.inspect(err or port)), vim.log.levels.ERROR)
      return
    end

    callback({
      type = "server",
      id = "intellij_debugger",
      host = "127.0.0.1",
      port = port,
      options = {
        initialize_timeout_sec = 15,
      },
    })
  end)
end

local keys = {
  {
    "<leader>dB",
    function()
      local condition = vim.fn.input("Breakpoint condition: ")
      if condition ~= "" then
        require("dap").set_breakpoint(condition)
      end
    end,
    desc = "Conditional Breakpoint",
  },
  {
    "<leader>db",
    function()
      require("dap").toggle_breakpoint()
    end,
    desc = "Toggle Breakpoint",
  },
  {
    "<leader>dc",
    function()
      require("dap").continue()
    end,
    desc = "Run/Continue",
  },
  {
    "<leader>dC",
    function()
      require("dap").run_to_cursor()
    end,
    desc = "Run to Cursor",
  },
  {
    "<leader>de",
    function()
      require("dap.ui.widgets").hover()
    end,
    mode = { "n", "x" },
    desc = "Inspect",
  },
  {
    "<leader>di",
    function()
      require("dap").step_into()
    end,
    desc = "Step Into",
  },
  {
    "<leader>dl",
    function()
      require("dap").run_last()
    end,
    desc = "Run Last",
  },
  {
    "<leader>do",
    function()
      require("dap").step_out()
    end,
    desc = "Step Out",
  },
  {
    "<leader>dO",
    function()
      require("dap").step_over()
    end,
    desc = "Step Over",
  },
  {
    "<leader>dp",
    function()
      require("dap").pause()
    end,
    desc = "Pause",
  },
  {
    "<leader>dr",
    function()
      require("dap").repl.toggle()
    end,
    desc = "Toggle REPL",
  },
  {
    "<leader>dt",
    function()
      require("dap").terminate()
    end,
    desc = "Terminate",
  },
}

return {
  {
    "mfussenegger/nvim-dap",
    cmd = {
      "DapContinue",
      "DapPause",
      "DapRestartFrame",
      "DapStepInto",
      "DapStepOut",
      "DapStepOver",
      "DapTerminate",
      "DapToggleBreakpoint",
    },
    keys = keys,
    config = function()
      local dap = require("dap")

      -- Kotlin LSP 262.9593 supports configurationDone but does not advertise it.
      dap.listeners.before.event_initialized.kotlin_lsp_configuration_done = function(session)
        if session.config.type == "intellij_debugger" then
          session.capabilities.supportsConfigurationDoneRequest = true
        end
      end

      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "×", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "Visual" })

      dap.adapters.intellij_debugger = kotlin_dap_adapter

      dap.configurations.kotlin = {
        -- Kotlin LSP 262.9593 exposes its bundled DAP server as attach-only.
        -- https://github.com/Kotlin/kotlin-lsp/blob/3f14bfa6803ae80c9e71e325635aa1307969395b/kotlin-vscode/src/dap.ts
        -- Breakpoint handling is currently affected by https://github.com/Kotlin/kotlin-lsp/issues/198.
        {
          type = "intellij_debugger",
          request = "attach",
          name = "Attach via Kotlin LSP (experimental)",
          hostName = kotlin_host,
          port = kotlin_port,
          timeout = 30000,
        },
      }
    end,
  },
}
