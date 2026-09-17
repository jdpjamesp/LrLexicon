local LrApplication = import 'LrApplication'
local LrLogger = import 'LrLogger'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'

local logger = LrLogger('LrLexicon')
logger:enable("logfile")

LrFunctionContext.postAsyncTaskWithContext("LrLexicon_LogSelectedPhotos", function(context)
	context:addFailureHandler(function(status, message)
		logger:errorf("LogSelectedPhotos failed: %s", tostring(message))
		LrDialogs.message("LrLexicon Error", tostring(message), "critical")
	end)

	local catalog = LrApplication.activeCatalog()
	local photos = catalog:getTargetPhotos()

	if #photos == 0 then
		logger:info("No photos selected.")
		LrDialogs.message("LrLexicon", "No photos selected.")
		return
	end

	logger:infof("%d photo(s) selected:", #photos)

	for i, photo in ipairs(photos) do
		local filename = photo:getFormattedMetadata('fileName')
		local keywords = photo:getFormattedMetadata('keywordTagsForExport') or "(none)"
		logger:infof("[%d] %s | keywords: %s", i, filename, keywords)
	end

	LrDialogs.message("LrLexicon", string.format("Logged %d photo(s). See LrLexicon.log for details.", #photos))
end)
