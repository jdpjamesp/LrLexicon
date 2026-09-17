local LrApplication = import 'LrApplication'
local LrLogger = import 'LrLogger'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrProgressScope = import 'LrProgressScope'

local Base64 = require 'Base64'
local ApiClient = require 'ApiClient'
local Preferences = require 'Preferences'

local logger = LrLogger('LrLexicon')
logger:enable("logfile")

local PREVIEW_LONG_EDGE = 1024
local MAX_KEYWORD_LENGTH = 60
local MAX_KEYWORDS_PER_PHOTO = 25

-- Tolerates output that doesn't follow the flat comma-separated instruction:
-- strips bullet markers, splits on line breaks as well as commas, and drops
-- a short leading "Label:" prefix (e.g. "Subject:", "Mood:") some models add
-- despite being told not to - keeping whatever follows the colon instead of
-- discarding the line outright. Also guards against a model that ignores the
-- format entirely and rambles: candidates over MAX_KEYWORD_LENGTH chars are
-- dropped (a real keyword is never a sentence), and the result is capped at
-- MAX_KEYWORDS_PER_PHOTO.
local function parseKeywords(content)
	local keywords = {}
	local seen = {}

	local function addKeyword(raw)
		if #keywords >= MAX_KEYWORDS_PER_PHOTO then
			return
		end

		local keyword = raw:match("^%s*(.-)%s*$")
		-- A trimmed candidate ending in ':' is a leftover label/preamble
		-- fragment (e.g. "comma-separated keywords:"), never a real keyword.
		if keyword ~= ""
			and #keyword <= MAX_KEYWORD_LENGTH
			and not keyword:match(":$")
			and not seen[keyword:lower()]
		then
			seen[keyword:lower()] = true
			table.insert(keywords, keyword)
		end
	end

	for line in (content .. "\n"):gmatch("(.-)\n") do
		line = line:match("^%s*(.-)%s*$")
		line = line:gsub("^[%-%*•]+%s*", "")

		local label, rest = line:match("^([%a%-][%a%s%-]-):%s*(.+)$")
		if label and #label <= 30 then
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

-- On this Lightroom Classic build, catalog:createKeyword() returns nil for
-- a name that already exists, rather than the existing keyword as the SDK
-- docs describe - confirmed via the log (e.g. 'stone arch' succeeded once,
-- then returned nil every time after once it existed). So look up existing
-- top-level keywords first and only create genuinely new ones. Cached by
-- lowercased name for the duration of one write batch to avoid rescanning
-- catalog:getKeywords() for every repeated keyword across many photos.
local function findOrCreateKeyword(catalog, cache, name)
	local key = name:lower()
	local cached = cache[key]
	if cached then
		return cached
	end

	for _, existing in ipairs(catalog:getKeywords()) do
		if existing:getName():lower() == key then
			cache[key] = existing
			return existing
		end
	end

	local created = catalog:createKeyword(name, {}, true, nil)
	if created then
		cache[key] = created
	end
	return created
end

local function writeKeywords(context, catalog, accepted)
	local total = #accepted
	local progressScope = LrProgressScope({
		title = "LrLexicon: Writing Keywords",
		functionContext = context,
	})

	catalog:withWriteAccessDo("LrLexicon: Write Keywords", function()
		local keywordCache = {}

		for i, entry in ipairs(accepted) do
			progressScope:setCaption(string.format("%s (%d/%d)", entry.filename, i, total))
			progressScope:setPortionComplete(i - 1, total)

			local written = 0
			for _, keywordName in ipairs(entry.keywords) do
				local keyword = findOrCreateKeyword(catalog, keywordCache, keywordName)

				if keyword then
					entry.photo:addKeyword(keyword)
					written = written + 1
				else
					logger:errorf("Could not find or create keyword '%s' (%s) - skipped", keywordName, entry.filename)
				end
			end
			logger:infof("Wrote %d/%d keyword(s) to %s", written, #entry.keywords, entry.filename)

			progressScope:setPortionComplete(i, total)
		end
	end)

	progressScope:done()
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

	local API_CONFIG = Preferences.getConfig()

	local results = {}
	local failed = 0
	local lastError = nil

	local progressScope = LrProgressScope({
		title = "LrLexicon: Generating Keywords",
		functionContext = context,
	})
	progressScope:setCancelable(true)

	for i, photo in ipairs(photos) do
		if progressScope:isCanceled() then
			logger:infof("Generation cancelled after %d/%d photo(s).", i - 1, #photos)
			break
		end

		local filename = photo:getFormattedMetadata('fileName')
		progressScope:setCaption(string.format("%s (%d/%d)", filename, i, #photos))
		progressScope:setPortionComplete(i - 1, #photos)

		local jpegData, thumbError = requestPreviewSync(photo, PREVIEW_LONG_EDGE)

		if not jpegData then
			failed = failed + 1
			lastError = string.format("%s: %s", filename, tostring(thumbError))
			logger:errorf("[%d] %s -> preview failed: %s", i, filename, tostring(thumbError))
		else
			local base64Data = Base64.encode(jpegData)
			local content, apiError = ApiClient.generateKeywords(API_CONFIG, base64Data)

			if not content then
				failed = failed + 1
				lastError = string.format("%s: %s", filename, tostring(apiError))
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

		progressScope:setPortionComplete(i, #photos)
	end

	progressScope:done()

	if #results == 0 then
		LrDialogs.message(
			"LrLexicon",
			string.format(
				"No keywords generated (%d failed).%s",
				failed, lastError and ("\n\nLast error: " .. lastError) or ""
			)
		)
		return
	end

	local accepted = showReviewDialog(context, results)

	if not accepted then
		logger:info("Keyword write cancelled by user.")
		LrDialogs.message("LrLexicon", "Cancelled - no keywords were written.")
		return
	end

	writeKeywords(context, catalog, accepted)

	LrDialogs.message(
		"LrLexicon",
		string.format(
			"Wrote keywords to %d photo(s) (%d skipped, %d failed before review).%s",
			#accepted, #results - #accepted, failed,
			(failed > 0 and lastError) and ("\n\nLast error: " .. lastError) or ""
		)
	)
end)
