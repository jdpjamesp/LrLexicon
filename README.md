# LrLexicon

A Lightroom Classic plugin that sends selected photos to a vision-capable AI
API — any OpenAI-compatible endpoint, not locked to a single provider — and
writes back AI-generated keywords onto photo metadata.

## Status

- Step 1 confirmed working: **File > Plug-in Extras > LrLexicon: Log Selected
  Photos** logs the filename and existing keywords of each selected photo.
- Step 3 added, not yet confirmed: **File > Plug-in Extras > LrLexicon: Test
  Export Preview** generates a ~1024px JPEG thumbnail per selected photo via
  `photo:requestJpegThumbnail()`, base64-encodes it, and logs byte/base64
  sizes — proving out the exact data shape that will get sent to the vision
  API in step 5.

## Structure

```
LrLexicon.lrplugin/
  Info.lua                  -- plugin manifest, menu registration
  LogSelectedPhotos.lua     -- step 1: logs selected photos' filenames/keywords
  ExportPreview.lua         -- step 3: generates + base64-encodes a preview JPEG per photo
  Base64.lua                -- pure-Lua base64 encoder (no bit-library dependency)
```

## Loading the plugin in Lightroom Classic

1. Open Lightroom Classic.
2. File > Plug-in Manager.
3. Click "Add", then select the `LrLexicon.lrplugin` folder in this repo.
4. Confirm it shows as "Installed and running" in the manager.
5. Select one or more photos in the Library, then go to
   File > Plug-in Extras > LrLexicon: Log Selected Photos.
6. A confirmation dialog appears; details are written to `LrLexicon.log`
   under `%LOCALAPPDATA%\Adobe\Lightroom\Logs\LrClassicLogs\` on Windows
   (i.e. `C:\Users\<you>\AppData\Local\Adobe\Lightroom\Logs\LrClassicLogs\LrLexicon.log`).

## Build order

See project handover notes. Steps 1-2 done and confirmed. Step 3 (preview
export + base64 encode) implemented, pending live confirmation in Lightroom.
Next after that: standalone test of a vision API call (any OpenAI-compatible
endpoint) with one base64 image, before wiring it into the plugin.
