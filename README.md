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
- Step 5 confirmed working: **File > Plug-in Extras > LrLexicon: Generate
  Keywords** runs the full pipeline — preview export, base64 encode,
  `ApiClient.generateKeywords()` via `LrHttp.post()`, comma-split parsing —
  and logs the parsed keywords per photo.
- Step 6 added, not yet confirmed, with the step-8 review dialog pulled
  forward: after generation, a modal review dialog lists each photo with an
  include/exclude checkbox and an editable, comma-separated keyword text
  field. Only on clicking "Write Keywords" does it write via
  `catalog:withWriteAccessDo()` (`catalog:createKeyword()` +
  `photo:addKeyword()`); "Cancel" writes nothing. API endpoint is currently
  hardcoded in `GenerateKeywords.lua` to the local Ollama setup used in step
  4 testing; step 7 will move this into a settings dialog.

## Structure

```
LrLexicon.lrplugin/
  Info.lua                  -- plugin manifest, menu registration
  LogSelectedPhotos.lua     -- step 1: logs selected photos' filenames/keywords
  ExportPreview.lua         -- step 3: generates + base64-encodes a preview JPEG per photo
  Base64.lua                -- pure-Lua base64 encoder (no bit-library dependency)
  Json.lua                  -- minimal JSON encode/decode (no bundled SDK library, not vendored)
  ApiClient.lua             -- generic OpenAI-compatible chat completions client (LrHttp)
  GenerateKeywords.lua      -- steps 5-6: full pipeline + review dialog + catalog write

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

See project handover notes. Steps 1-5 done and confirmed. Step 6 (catalog
writes) implemented with the step-8 review dialog pulled forward — pending
live confirmation in Lightroom, since this is the first step that touches
real catalog data. Note: the API layer is provider-agnostic — any
OpenAI-compatible endpoint (OpenAI, local Ollama/LM Studio, etc.), not locked
to one vendor. Next after that: step 7, a real settings dialog (`LrPrefs` for
endpoint/model, `LrPasswords` for the API key) instead of the hardcoded
`API_CONFIG` in `GenerateKeywords.lua`.
