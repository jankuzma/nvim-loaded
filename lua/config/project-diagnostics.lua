-- Project-wide diagnostics for Turborepo
local M = {}

-- Run ESLint on entire project
function M.lint_project()
	local clients = vim.lsp.get_active_clients({ name = "eslint" })
	if #clients > 0 then
		local client = clients[1]
		local workspace_folders = client.workspace_folders
		if workspace_folders and #workspace_folders > 0 then
			client.request("workspace/executeCommand", {
				command = "eslint.lintProject",
				arguments = {},
			}, function(err, result)
				if err then
					vim.notify("ESLint project lint failed: " .. vim.inspect(err), vim.log.levels.ERROR)
				else
					vim.notify("ESLint project lint completed", vim.log.levels.INFO)
					-- Force refresh diagnostics after a delay
					vim.defer_fn(function()
						vim.diagnostic.reset()
						vim.cmd("checktime")
						M.show_all_diagnostics()
					end, 1000)
				end
			end)
		else
			vim.notify("No workspace folders found for ESLint", vim.log.levels.WARN)
		end
	else
		vim.notify("ESLint language server not found", vim.log.levels.WARN)
	end
end

-- Run TypeScript diagnostics on project
function M.typescript_project_diagnostics()
	-- Try different possible TypeScript server names
	local ts_clients = vim.lsp.get_active_clients({ name = "vtsls" }) or 
	                  vim.lsp.get_active_clients({ name = "tsserver" }) or
	                  vim.lsp.get_active_clients({ name = "typescript-language-server" })
	
	if #ts_clients > 0 then
		for _, client in ipairs(ts_clients) do
			-- Restart the client to reload project diagnostics
			vim.lsp.stop_client(client.id)
			vim.cmd("LspRestart")
		end
		vim.notify("Restarting TypeScript language server...", vim.log.levels.INFO)
	else
		-- Show all active clients for debugging
		local all_clients = vim.lsp.get_active_clients()
		local client_names = {}
		for _, client in ipairs(all_clients) do
			table.insert(client_names, client.name)
		end
		vim.notify("Available LSP clients: " .. table.concat(client_names, ", "), vim.log.levels.INFO)
	end
end

-- Collect all diagnostics and show in quickfix
function M.show_all_diagnostics()
	vim.diagnostic.setqflist({ severity = { min = vim.diagnostic.severity.HINT } })
	vim.cmd("copen")
end

-- Run turbo lint command and populate diagnostics
function M.turbo_lint()
	vim.notify("Running turbo lint...", vim.log.levels.INFO)
	
	vim.fn.jobstart({ "npm", "run", "lint" }, {
		cwd = "/Users/jankuzma/firma/projects/golfbites",
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				M.parse_lint_output(data)
			end
		end,
		on_stderr = function(_, data)
			if data then
				M.parse_lint_output(data)
			end
		end,
		on_exit = function(_, code)
			if code == 0 then
				vim.notify("Lint completed successfully", vim.log.levels.INFO)
			else
				vim.notify("Lint completed with issues", vim.log.levels.WARN)
			end
			-- Show results in Trouble
			vim.cmd("Trouble diagnostics")
		end,
	})
end

-- Parse lint output and set diagnostics
function M.parse_lint_output(data)
	local qf_list = {}
	local diagnostics_by_file = {}
	
	-- Debug: print raw output
	vim.notify("Raw lint output: " .. vim.inspect(data), vim.log.levels.DEBUG)
	
	for _, line in ipairs(data) do
		if line and line ~= "" then
			-- Debug: print each line
			print("Processing line:", line)
			
			-- Try multiple ESLint output formats
			local file, lnum, col, severity, msg = line:match("([^:]+):(%d+):(%d+):%s*(%w+)%s*(.+)")
			
			-- Alternative format: file.js:10:5 error message
			if not file then
				file, lnum, col, msg = line:match("([^:]+):(%d+):(%d+)%s+(.+)")
				severity = "error" -- default
			end
			
			-- Alternative format: /path/to/file.js(10,5): error message
			if not file then
				file, lnum, col, msg = line:match("([^%(]+)%((%d+),(%d+)%):%s*(.+)")
				severity = "error" -- default
			end
			
			if file and lnum and col and msg then
				print("Matched:", file, lnum, col, severity, msg)
				local abs_file = file
				if not vim.startswith(file, "/") then
					abs_file = "/Users/jankuzma/firma/projects/golfbites/" .. file
				end
				
				-- Add to quickfix
				table.insert(qf_list, {
					filename = abs_file,
					lnum = tonumber(lnum),
					col = tonumber(col),
					text = msg,
					type = severity:upper(),
				})
				
				-- Prepare for diagnostics
				if not diagnostics_by_file[abs_file] then
					diagnostics_by_file[abs_file] = {}
				end
				
				local diagnostic_severity = vim.diagnostic.severity.ERROR
				if severity == "warning" then
					diagnostic_severity = vim.diagnostic.severity.WARN
				elseif severity == "info" then
					diagnostic_severity = vim.diagnostic.severity.INFO
				end
				
				table.insert(diagnostics_by_file[abs_file], {
					lnum = tonumber(lnum) - 1, -- 0-indexed
					col = tonumber(col) - 1,   -- 0-indexed
					message = msg,
					severity = diagnostic_severity,
					source = "eslint",
				})
			end
		end
	end
	
	-- Set quickfix
	if #qf_list > 0 then
		vim.fn.setqflist(qf_list)
	end
	
	-- Set diagnostics for each file
	local namespace = vim.api.nvim_create_namespace("turbo-lint")
	
	for file, file_diagnostics in pairs(diagnostics_by_file) do
		-- Load the buffer to make it available for diagnostics
		local bufnr = vim.fn.bufnr(file, true)
		if bufnr ~= -1 then
			-- Load the buffer content if it's not already loaded
			if not vim.api.nvim_buf_is_loaded(bufnr) then
				vim.fn.bufload(bufnr)
			end
			
			-- Set diagnostics for this buffer
			vim.diagnostic.set(namespace, bufnr, file_diagnostics)
			vim.notify("Set " .. #file_diagnostics .. " diagnostics for " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.DEBUG)
		end
	end
	
	-- Force diagnostics refresh
	vim.diagnostic.show(namespace)
	
	vim.notify("Total files with diagnostics: " .. vim.tbl_count(diagnostics_by_file), vim.log.levels.INFO)
end

-- Test function to see raw output
function M.test_lint_output()
	vim.cmd("new")
	vim.cmd("term cd /Users/jankuzma/firma/projects/golfbites && npm run lint")
end

-- Simple diagnostic test
function M.test_diagnostics()
	local ns = vim.api.nvim_create_namespace("test-diagnostics")
	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostics = {
		{
			lnum = 0,
			col = 0,
			message = "Test diagnostic message",
			severity = vim.diagnostic.severity.ERROR,
			source = "test",
		}
	}
	vim.diagnostic.set(ns, bufnr, diagnostics)
	vim.notify("Set test diagnostic", vim.log.levels.INFO)
end

-- Setup keybindings
function M.setup()
	vim.keymap.set("n", "<leader>xe", M.lint_project, { desc = "Lint entire project" })
	vim.keymap.set("n", "<leader>xr", M.typescript_project_diagnostics, { desc = "TypeScript project diagnostics" })
	vim.keymap.set("n", "<leader>xd", M.show_all_diagnostics, { desc = "Show all diagnostics" })
	vim.keymap.set("n", "<leader>xw", M.turbo_lint, { desc = "Run turbo lint" })
	vim.keymap.set("n", "<leader>xt", M.test_lint_output, { desc = "Test lint output" })
	vim.keymap.set("n", "<leader>xz", M.test_diagnostics, { desc = "Test diagnostics" })
end

return M