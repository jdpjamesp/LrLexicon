# LrLexicon

A Lightroom Classic plugin that sends selected photos to a vision-capable AI
API — any OpenAI-compatible endpoint, not locked to a single provider — and
writes back AI-generated keywords onto photo metadata.

## Status

- Step 1 confirmed working: **File > Plug-in Extras > LrLexicon: Log Selected
  Photos** logs the filename and existing keywords of each selected photo.
- Step 3 confirmed working: **File > Plug-in Extras > LrLexicon: Test
  Export Preview** generates a ~1024px JPEG thumbnail per selected photo via
  `photo:requestJpegThumbnail()`, base64-encodes it, and logs byte/base64
  sizes — proving out the exact data shape that will get sent to the vision
  API in step 5.
- Step 4 confirmed working: `scripts/test-api.lua` sends one base64 JPEG to
  an OpenAI-compatible chat completions endpoint (tested against a local
  Ollama server running `llava:latest`) and prints the raw response.
  Response shape is standard OpenAI: `choices[0].message.content`. Note:
  `llava:latest` (a small local model) didn't reliably follow the
  comma-separated-keywords instruction in testing — returned a short
  caption instead. Step 5's response parsing should tolerate free-text
  output, not just strict comma-separated lists, and a stronger model may
  be worth trying for real keyword quality.

## Structure

```
LrLexicon.lrplugin/
  Info.lua                  -- plugin manifest, menu registration
  LogSelectedPhotos.lua     -- step 1: logs selected photos' filenames/keywords
  ExportPreview.lua         -- step 3: generates + base64-encodes a preview JPEG per photo
  Base64.lua                -- pure-Lua base64 encoder (no bit-library dependency)

scripts/
  test-api.lua               -- step 4: standalone (non-Lightroom) test of the vision API call
  Base64.lua                 -- copy of the plugin's encoder, kept decoupled from the plugin runtime
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

See project handover notes. Steps 1-4 done and confirmed. Note: the API layer
is provider-agnostic — any OpenAI-compatible endpoint (OpenAI, local Ollama/LM
Studio, etc.), not locked to one vendor. Next: wire the API call into the
plugin itself (`LrHttp.post()` inside `LrTasks.startAsyncTask`), parsing the
response into a keyword array.
