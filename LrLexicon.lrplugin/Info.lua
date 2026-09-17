return {
	LrSdkVersion = 13.0,
	LrSdkMinimumVersion = 6.0,

	LrToolkitIdentifier = 'com.jdpjamesp.lrlexicon',
	LrPluginName = "LrLexicon",
	LrPluginInfoUrl = "https://github.com/jdpjamesp/LrLexicon",

	LrExportMenuItems = {
		{
			title = "LrLexicon: Log Selected Photos",
			file = "LogSelectedPhotos.lua",
		},
		{
			title = "LrLexicon: Test Export Preview",
			file = "ExportPreview.lua",
		},
		{
			title = "LrLexicon: Generate Keywords",
			file = "GenerateKeywords.lua",
		},
	},

	VERSION = { major = 0, minor = 1, revision = 0, build = 1 },
}
