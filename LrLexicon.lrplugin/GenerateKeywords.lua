local LrApplication = import 'LrApplication'
local LrLogger = import 'LrLogger'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'

local Base64 = require 'Base64'
local ApiClient = require 'ApiClient'

local logger = LrLogger('LrLexicon')
logger:enable("logfile")

-- TODO (step 7): move into a settings dialog backed by LrPrefs / LrPasswords
-- instead of being hardcoded here.
local API_CONFIG = {
	baseUrl = "http://localhost:11434/v1/chat/completions",
	apiKey = nil,
	model = "llava:latest",
	prompt = "Return 12-15 concise, comma-separated keywords for this photo, "
		.. "covering subject, location type, mood, and technique. No commentary.",
}

local PREVIEW_LONG_EDGE = 1024

local function parseKeywords(content)
	local keywords = {}
	for keyword in content:gmatch("[^,]+") do
		keyword = keyword:match("^%s*(.-)%s*$")
		if keyword ~= "" then
			table.insert(keywords, keyword)
		end
	end
	return keywords
end

-- Bridges the callback-based requestJpegThumbnail into sequential,
-- yield-friendly code by polling a flag with LrTasks.sleep, so photos are
-- processed one at a time inside this task.
local function requestPreviewSync(photo, size)
	local jpegData, errorMsg
	local done = false

	photo:requestJpegThumbnail(size, size, function(data, err)
		jpegData = data
		errorMsg = err
		done = true
	end)

	while not done do
		LrTasks.sleep(0.05)
	end

	return jpegData, errorMsg
end

LrFunctionContext.postAsyncTaskWithContext("LrLexicon_GenerateKeywords", function(context)
	context:addFailureHandler(function(status, message)
		logger:errorf("GenerateKeywords failed: %s", tostring(message))
		LrDialogs.message("LrLexicon Error", tostring(message), "critical")
	end)

	local catalog = LrApplication.activeCatalog()
	local photos = catalog:getTargetPhotos()

	if #photos == 0 then
		LrDialogs.message("LrLexicon", "No photos selected.")
		return
	end

	local succeeded = 0
	local failed = 0

	for i, photo in ipairs(photos) do
		local filename = photo:getFormattedMetadata('fileName')
		local jpegData, thumbError = requestPreviewSync(photo, PREVIEW_LONG_EDGE)

		if not jpegData then
			failed = failed + 1
			logger:errorf("[%d] %s -> preview failed: %s", i, filename, tostring(thumbError))
		else
			local base64Data = Base64.encode(jpegData)
			local content, apiError = ApiClient.generateKeywords(API_CONFIG, base64Data)

			if not content then
				failed = failed + 1
				logger:errorf("[%d] %s -> API call failed: %s", i, filename, tostring(apiError))
			else
				local keywords = parseKeywords(content)
				succeeded = succeeded + 1
				logger:infof(
					"[%d] %s -> raw response: %q | parsed %d keyword(s): %s",
					i, filename, content, #keywords, table.concat(keywords, ", ")
				)
			end
		end
	end

	LrDialogs.message(
		"LrLexicon",
		string.format(
			"Generated keywords for %d/%d photo(s) (%d failed). See LrLexicon.log for details. "
				.. "Keywords are logged only - not yet written to the catalog.",
			succeeded, #photos, failed
		)
	)
end)
