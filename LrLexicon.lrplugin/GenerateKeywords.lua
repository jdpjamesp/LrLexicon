local LrApplication = import 'LrApplication'
local LrLogger = import 'LrLogger'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'

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
	prompt = "List 12-15 comma-separated keywords describing this photo's subject, setting, "
		.. "mood, and photographic technique. Output only the keywords as a plain "
		.. "comma-separated list, with no labels, headings, or extra text.",
}

local PREVIEW_LONG_EDGE = 1024

-- Tolerates output that doesn't follow the flat comma-separated instruction:
-- strips bullet markers, splits on line breaks as well as commas, and drops
-- a short leading "Label:" prefix (e.g. "Subject:", "Mood:") some models add
-- despite being told not to - keeping whatever follows the colon instead of
-- discarding the line outright.
local function parseKeywords(content)
	local keywords = {}
	local seen = {}

	local function addKeyword(raw)
		local keyword = raw:match("^%s*(.-)%s*$")
		if keyword ~= "" and not seen[keyword:lower()] then
			seen[keyword:lower()] = true
			table.insert(keywords, keyword)
		end
	end

	for line in (content .. "\n"):gmatch("(.-)\n") do
		line = line:match("^%s*(.-)%s*$")
		line = line:gsub("^[%-%*•]+%s*", "")

		local label, rest = line:match("^(%a[%a%s]-):%s*(.+)$")
		if label and #label <= 20 then
			line = rest
		end

		for part in line:gmatch("[^,]+") do
			addKeyword(part)
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

-- Shows the generated keywords per photo for review before anything is
-- written to the catalog. Returns the accepted subset (photo, filename,
-- possibly-edited keywords), or nil if the user cancelled.
local function showReviewDialog(context, results)
	local f = LrView.osFactory()
	local bind = LrView.bind
	local properties = LrBinding.makePropertyTable(context)

	local DIALOG_WIDTH = 600
	local SCROLL_THRESHOLD = 5

	local rows = { spacing = f:control_spacing(), fill_horizontal = 1 }

	for i, entry in ipairs(results) do
		local includeKey = "include_" .. i
		local keywordsKey = "keywords_" .. i

		properties[includeKey] = true
		properties[keywordsKey] = table.concat(entry.keywords, ", ")

		table.insert(rows, f:column{
			fill_horizontal = 1,
			spacing = f:control_spacing(),
			f:row{
				f:checkbox{ value = bind(includeKey) },
				f:static_text{ title = entry.filename },
			},
			f:edit_field{
				value = bind(keywordsKey),
				fill_horizontal = 1,
				width_in_chars = 70,
				height_in_lines = 3,
			},
			f:spacer{ height = 4 },
		})
	end

	local rowsColumn = f:column(rows)

	local reviewArea
	if #results > SCROLL_THRESHOLD then
		reviewArea = f:scrolled_view{
			width = DIALOG_WIDTH,
			height = 420,
			rowsColumn,
		}
	else
		reviewArea = rowsColumn
	end

	local contents = f:column{
		bind_to_object = properties,
		spacing = f:control_spacing(),
		width = DIALOG_WIDTH,
		f:static_text{
			title = "Review keywords before writing them to the catalog. "
				.. "Uncheck a photo to skip it, or edit its keyword text.",
			fill_horizontal = 1,
		},
		reviewArea,
	}

	local result = LrDialogs.presentModalDialog({
		title = "LrLexicon: Review Keywords",
		contents = contents,
		actionVerb = "Write Keywords",
		cancelVerb = "Cancel",
	})

	if result ~= "ok" then
		return nil
	end

	local accepted = {}
	for i, entry in ipairs(results) do
		if properties["include_" .. i] then
			table.insert(accepted, {
				photo = entry.photo,
				filename = entry.filename,
				keywords = parseKeywords(properties["keywords_" .. i]),
			})
		end
	end

	return accepted
end

local function writeKeywords(catalog, accepted)
	catalog:withWriteAccessDo("LrLexicon: Write Keywords", function()
		for _, entry in ipairs(accepted) do
			for _, keywordName in ipairs(entry.keywords) do
				local keyword = catalog:createKeyword(keywordName, {}, true, nil, false)
				entry.photo:addKeyword(keyword)
			end
			logger:infof("Wrote %d keyword(s) to %s", #entry.keywords, entry.filename)
		end
	end)
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

	local results = {}
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
				logger:infof(
					"[%d] %s -> raw response: %q | parsed %d keyword(s): %s",
					i, filename, content, #keywords, table.concat(keywords, ", ")
				)
				table.insert(results, { photo = photo, filename = filename, keywords = keywords })
			end
		end
	end

	if #results == 0 then
		LrDialogs.message(
			"LrLexicon",
			string.format("No keywords generated (%d failed). See LrLexicon.log for details.", failed)
		)
		return
	end

	local accepted = showReviewDialog(context, results)

	if not accepted then
		logger:info("Keyword write cancelled by user.")
		LrDialogs.message("LrLexicon", "Cancelled - no keywords were written.")
		return
	end

	writeKeywords(catalog, accepted)

	LrDialogs.message(
		"LrLexicon",
		string.format(
			"Wrote keywords to %d photo(s) (%d skipped, %d failed before review). See LrLexicon.log for details.",
			#accepted, #results - #accepted, failed
		)
	)
end)
