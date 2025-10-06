return {
	-- tools
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			vim.list_extend(opts.ensure_installed, {
				"stylua",
				"selene",
				"luacheck",
				"shellcheck",
				"shfmt",
				"tailwindcss-language-server",
				"typescript-language-server",
				"css-lsp",
				"prettier",
				"emmet-ls",
				"eslint-lsp",
				"tflint",
				"terraform-ls",
			})
		end,
	},

	-- lsp servers
	{
		"neovim/nvim-lspconfig",
		opts = {
			inlay_hints = { enabled = false },
			---@type lspconfig.options
			servers = {
				eslint = {
					cmd = { "vscode-eslint-language-server", "--stdio" },
					root_dir = function(fname)
						local util = require("lspconfig.util")
						
						-- For Turborepo: find the workspace root first (turbo.json)
						local workspace_root = util.root_pattern("turbo.json", "pnpm-workspace.yaml", "yarn.workspaces")(fname)
						
						if workspace_root then
							-- Check if current file is in a package with its own eslint config
							local package_root = util.root_pattern("eslint.config.js", "package.json")(fname)
							if package_root and package_root ~= workspace_root then
								return package_root
							end
							return workspace_root
						end
						
						-- Fallback to standard eslint config detection
						return util.root_pattern(
							"eslint.config.js",
							"eslint.config.mjs", 
							"eslint.config.cjs",
							"eslint.config.ts",
							".eslintrc",
							".eslintrc.js",
							".eslintrc.cjs",
							".eslintrc.yaml",
							".eslintrc.yml",
							".eslintrc.json",
							"package.json"
						)(fname)
					end,
					settings = {
						workingDirectories = { mode = "auto" },
						experimental = {
							useFlatConfig = true,
						},
						validate = "on",
						packageManager = "auto",
						problems = {
							shortenToSingleLine = false,
						},
						workspaceFolder = {
							changeProcessCWD = true,
						},
					},
					on_attach = function(client, bufnr)
						-- Disable eslint formatting if you're using prettier
						client.server_capabilities.documentFormattingProvider = false
						client.server_capabilities.documentRangeFormattingProvider = false
					end,
				},
				emmet_ls = {
					filetypes = { "css", "html", "javascriptreact", "typescriptreact" },
				},
				cssls = {},
				tailwindcss = {
					root_dir = function(...)
						return require("lspconfig.util").root_pattern(".git")(...)
					end,
					settings = {
						tailwindCSS = {
							configFile = "tailwind.config.js", -- Ensure this is correct
							classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
							includeLanguages = {
								-- Add these lines for JSX/TSX support
								javascript = "javascript",
								typescript = "typescript",
								javascriptreact = "javascriptreact", -- Explicitly for .jsx
								typescriptreact = "typescriptreact", -- Explicitly for .tsx

								-- Your existing languages
								eelixir = "html-eex",
								elixir = "phoenix-heex",
								eruby = "erb",
								heex = "phoenix-heex",
								html = "html",
								htmlangular = "html",
								tmpl = "html",
							},
							lint = {
								cssConflict = "warning",
								invalidApply = "error",
								invalidConfigPath = "error",
								invalidScreen = "error",
								invalidTailwindDirective = "error",
								invalidVariant = "error",
								recommendedVariantOrder = "warning",
							},
							validate = true,
							hovers = true, -- Recommended to explicitly enable
							suggestions = true, -- Recommended to explicitly enable
							emmet = true, -- Recommended for Emmet
						},
					},
				},
				tsserver = {
					root_dir = function(...)
						return require("lspconfig.util").root_pattern(".git")(...)
					end,
					single_file_support = false,
					settings = {
						typescript = {
							inlayHints = {
								includeInlayParameterNameHints = "literal",
								includeInlayParameterNameHintsWhenArgumentMatchesName = false,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = false,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
						javascript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = false,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
					},
				},
				html = {},
				yamlls = {
					settings = {
						yaml = {
							keyOrdering = false,
						},
					},
				},
				lua_ls = {
					-- enabled = false,
					single_file_support = true,
					settings = {
						Lua = {
							workspace = {
								checkThirdParty = false,
							},
							completion = {
								workspaceWord = true,
								callSnippet = "Both",
							},
							misc = {
								parameters = {
									-- "--log-level=trace",
								},
							},
							hint = {
								enable = true,
								setType = false,
								paramType = true,
								paramName = "Disable",
								semicolon = "Disable",
								arrayIndex = "Disable",
							},
							doc = {
								privateName = { "^_" },
							},
							type = {
								castNumberToInteger = true,
							},
							diagnostics = {
								disable = { "incomplete-signature-doc", "trailing-space" },
								-- enable = false,
								groupSeverity = {
									strong = "Warning",
									strict = "Warning",
								},
								groupFileStatus = {
									["ambiguity"] = "Opened",
									["await"] = "Opened",
									["codestyle"] = "None",
									["duplicate"] = "Opened",
									["global"] = "Opened",
									["luadoc"] = "Opened",
									["redefined"] = "Opened",
									["strict"] = "Opened",
									["strong"] = "Opened",
									["type-check"] = "Opened",
									["unbalanced"] = "Opened",
									["unused"] = "Opened",
								},
								unusedLocalExclude = { "_*" },
							},
							format = {
								enable = true,
								defaultConfig = {
									indent_style = "space",
									indent_size = "2",
									continuation_indent_size = "2",
								},
							},
						},
					},
				},
			},
			setup = {},
		},
	},
	{
		"neovim/nvim-lspconfig",
		opts = function()
			local keys = require("lazyvim.plugins.lsp.keymaps").get()
			vim.list_extend(keys, {
				{
					"gd",
					function()
						-- DO NOT RESUSE WINDOW
						require("telescope.builtin").lsp_definitions({ reuse_win = false })
					end,
					desc = "Goto Definition",
					has = "definition",
				},
			})
		end,
	},
}
