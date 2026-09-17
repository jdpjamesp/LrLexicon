-- Thin wrapper around LrHttp for any OpenAI-compatible chat completions
-- vision endpoint (OpenAI, local Ollama/LM Studio, etc.) - not tied to a
-- single provider.

local LrHttp = import 'LrHttp'

local Json = require 'Json'

local ApiClient = {}

--[[
config = {
	baseUrl = "http://localhost:11434/v1/chat/completions",
	apiKey = nil,        -- omit/empty for endpoints that don't require auth
	model = "llava:latest",
	prompt = "Return 12-15 concise, comma-separated keywords ...",
}

Returns: content (string) on success, or nil, errorMessage on failure.
]]
function ApiClient.generateKeywords(config, base64ImageData)
	local requestBody = Json.encode({
		model = config.model,
		stream = false,
		messages = {
			{
				role = "user",
				content = {
					{ type = "text", text = config.prompt },
					{
						type = "image_url",
						image_url = { url = "data:image/jpeg;base64," .. base64ImageData },
					},
				},
			},
		},
	})

	local headers = {
		{ field = "Content-Type", value = "application/json" },
	}
	if config.apiKey and config.apiKey ~= "" then
		table.insert(headers, { field = "Authorization", value = "Bearer " .. config.apiKey })
	end

	local result, responseHeaders = LrHttp.post(config.baseUrl, requestBody, headers, "POST", 60)

	if not result then
		local reason = (responseHeaders and responseHeaders.error and responseHeaders.error.name)
			or "unknown network error"
		return nil, "Request failed: " .. tostring(reason)
	end

	local status = responseHeaders and responseHeaders.status
	if status and (status < 200 or status >= 300) then
		return nil, string.format("API returned HTTP %d: %s", status, result)
	end

	local ok, parsed = pcall(Json.decode, result)
	if not ok then
		return nil, "Failed to parse API response as JSON: " .. tostring(parsed)
	end

	if parsed.error then
		local message = (type(parsed.error) == "table" and parsed.error.message) or tostring(parsed.error)
		return nil, "API error: " .. tostring(message)
	end

	local choices = parsed.choices
	if not choices or not choices[1] or not choices[1].message or not choices[1].message.content then
		return nil, "Unexpected response shape: " .. result
	end

	return choices[1].message.content, nil
end

return ApiClient
