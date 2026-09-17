local LrApplication = import 'LrApplication'
local LrLogger = import 'LrLogger'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'

local Base64 = require 'Base64'

local logger = LrLogger('LrLexicon')
logger:enable("logfile")

local PREVIEW_LONG_EDGE = 1024

LrFunctionContext.postAsyncTaskWithContext("LrLexicon_ExportPreview", function(context)
	context:addFailureHandler(function(status, message)
		logger:errorf("ExportPreview failed: %s", tostring(message))
		LrDialogs.message("LrLexicon Error", tostring(message), "critical")
	end)

	local catalog = LrApplication.activeCatalog()
	local photos = catalog:getTargetPhotos()

	if #photos == 0 then
		LrDialogs.message("LrLexicon", "No photos selected.")
		return
	end

	local total = #photos
	local completed = 0
	local succeeded = 0

	for i, photo in ipairs(photos) do
		local filename = photo:getFormattedMetadata('fileName')

		photo:requestJpegThumbnail(PREVIEW_LONG_EDGE, PREVIEW_LONG_EDGE, function(jpegData, errorMsg)
			completed = completed + 1

			if jpegData then
				succeeded = succeeded + 1
				local base64Data = Base64.encode(jpegData)
				logger:infof(
					"[%d] %s -> %d byte JPEG, base64 length %d",
					i, filename, #jpegData, #base64Data
				)
			else
				logger:errorf("[%d] %s -> thumbnail request failed: %s", i, filename, tostring(errorMsg))
			end

			if completed == total then
				LrDialogs.message(
					"LrLexicon",
					string.format(
						"Generated previews for %d/%d photo(s). See LrLexicon.log for details.",
						succeeded, total
					)
				)
			end
		end)
	end
end)
