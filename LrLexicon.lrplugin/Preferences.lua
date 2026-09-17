-- Settings storage and dialog for the API endpoint/model/prompt/key.
-- Non-sensitive settings live in LrPrefs (plain-text plugin prefs file);
-- the API key lives in LrPasswords (OS-native credential store: Keychain on
-- Mac, Credential Manager on Windows), never in plain text.

local LrPrefs = import 'LrPrefs'
local LrPasswords = import 'LrPasswords'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'

local Preferences = {}

local PASSWORD_IDENTIFIER = "com.jdpjamesp.lrlexicon.apiKey"
local PASSWORD_USERNAME = "api"

local DEFAULTS = {
	baseUrl = "http://localhost:11434/v1/chat/completions",
	model = "llava:latest",
	prompt = "List 12-15 comma-separated keywords describing this photo's subject, setting, "
		.. "mood, and photographic technique. Output only the keywords as a plain "
		.. "comma-separated list, with no labels, headings, or extra text.",
}

local function prefs()
	return LrPrefs.prefsForPlugin()
end

local function nonEmpty(value, default)
	if value and value ~= "" then
		return value
	end
	return default
end

-- Returns the current { baseUrl, model, prompt, apiKey } config, falling
-- back to defaults for anything unset.
function Preferences.getConfig()
	local p = prefs()
	return {
		baseUrl = nonEmpty(p.baseUrl, DEFAULTS.baseUrl),
		model = nonEmpty(p.model, DEFAULTS.model),
		prompt = nonEmpty(p.prompt, DEFAULTS.prompt),
		apiKey = LrPasswords.retrieve(PASSWORD_USERNAME, PASSWORD_IDENTIFIER),
	}
end

function Preferences.showDialog()
	LrFunctionContext.callWithContext("LrLexicon_Preferences", function(context)
		local f = LrView.osFactory()
		local bind = LrView.bind
		local properties = LrBinding.makePropertyTable(context)

		local config = Preferences.getConfig()
		properties.baseUrl = config.baseUrl
		properties.model = config.model
		properties.prompt = config.prompt
		properties.apiKey = config.apiKey or ""

		local labelWidth = LrView.share("label_width")

		local contents = f:column{
			bind_to_object = properties,
			spacing = f:control_spacing(),
			width = 500,
			f:row{
				f:static_text{ title = "Endpoint URL:", width = labelWidth },
				f:edit_field{ value = bind("baseUrl"), fill_horizontal = 1 },
			},
			f:row{
				f:static_text{ title = "Model:", width = labelWidth },
				f:edit_field{ value = bind("model"), fill_horizontal = 1 },
			},
			f:row{
				f:static_text{ title = "API Key:", width = labelWidth },
				f:password_field{ value = bind("apiKey"), fill_horizontal = 1 },
			},
			f:static_text{
				title = "Leave API Key blank for endpoints that don't require "
					.. "authentication (e.g. a local Ollama/LM Studio server).",
				fill_horizontal = 1,
			},
			f:spacer{ height = 8 },
			f:static_text{ title = "Prompt:" },
			f:edit_field{
				value = bind("prompt"),
				fill_horizontal = 1,
				height_in_lines = 4,
			},
		}

		local result = LrDialogs.presentModalDialog({
			title = "LrLexicon: Settings",
			contents = contents,
			actionVerb = "Save",
			cancelVerb = "Cancel",
		})

		if result == "ok" then
			local p = prefs()
			p.baseUrl = properties.baseUrl
			p.model = properties.model
			p.prompt = properties.prompt
			LrPasswords.store(PASSWORD_USERNAME, properties.apiKey or "", PASSWORD_IDENTIFIER)
		end
	end)
end

return Preferences
