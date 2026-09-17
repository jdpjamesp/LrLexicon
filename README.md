# LrLexicon

A Lightroom Classic plugin that sends selected photos to a vision-capable AI
API — any OpenAI-compatible endpoint, not locked to a single provider — and
writes the generated keywords onto photo metadata, after a review step.

## Status

Working end to end: select photos, run **File > Plug-in Extras > LrLexicon:
Generate Keywords**, review/edit the generated keywords per photo in a modal
dialog, and write the accepted ones to the catalog.

Not yet built: a settings dialog for the API endpoint/model/key (currently
hardcoded in `GenerateKeywords.lua`) and general polish (rate limiting,
broader error handling).

## Structure

```
LrLexicon.lrplugin/
  Info.lua              -- plugin manifest, menu registration
  GenerateKeywords.lua  -- entry point: preview -> base64 -> API call -> review dialog -> catalog write
  ApiClient.lua         -- generic OpenAI-compatible chat completions client (LrHttp)
  Json.lua              -- minimal hand-written JSON encode/decode (SDK has no bundled JSON library)
  Base64.lua            -- pure-Lua base64 encoder (no bit-library dependency)
```

## Loading the plugin in Lightroom Classic

1. Open Lightroom Classic.
2. File > Plug-in Manager > Add, then select the `LrLexicon.lrplugin` folder.
3. Confirm it shows as "Installed and running".
4. Select one or more photos, then File > Plug-in Extras > LrLexicon:
   Generate Keywords.
5. Review the generated keywords in the dialog (uncheck a photo to skip it,
   edit the text if needed), then click "Write Keywords" (or "Cancel" to
   write nothing).

Logs go to `LrLexicon.log` under
`%LOCALAPPDATA%\Adobe\Lightroom\Logs\LrClassicLogs\` on Windows.

There's no right-click context menu entry — Lightroom Classic's native photo
context menu isn't extensible by third-party plugins via the public Lua SDK.
File > Plug-in Extras is the only menu access point.

## Configuration

`API_CONFIG` at the top of `GenerateKeywords.lua` currently hardcodes the
endpoint, model, and prompt (tested against a local Ollama server running
`llava:latest`). This will move to a proper settings dialog (`LrPrefs` for
endpoint/model, `LrPasswords` — the OS-native credential store — for the API
key) as the next piece of work.

## Known limitations

- **Small local models produce inconsistent output.** The same prompt/image
  against `llava:latest` has produced a clean keyword list, a plain caption,
  a labeled breakdown, and even a literal echo of the prompt's own wording,
  across separate calls. `parseKeywords()` in `GenerateKeywords.lua` tolerates
  line breaks, bullets, and stray label prefixes, but the review dialog is
  the real safety net for whatever slips through — a hosted model (OpenAI,
  Claude via a compatible endpoint) should be far more consistent once the
  settings dialog makes switching providers easy.
- **Preview size.** `photo:requestJpegThumbnail(1024, 1024, ...)` previews
  have run 260KB-1.2MB base64-encoded — larger than expected for a "small
  preview." Worth revisiting if large batches hit payload-size or cost
  limits.
- **`catalog:createKeyword()`'s documented 5th argument (`isPersonKeyword`)
  triggers a generic "assertion failed!"** on this Lightroom Classic build.
  It's omitted; the call only passes `(name, synonyms, includeOnExport,
  parent)`.
