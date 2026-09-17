# LrLexicon

A Lightroom Classic plugin that sends selected photos to a vision-capable AI
API — any OpenAI-compatible endpoint, not locked to a single provider — and
writes the generated keywords onto photo metadata, after a review step.

## Status

Working end to end: configure the API endpoint/model/key in **File >
Plug-in Extras > LrLexicon: Settings**, select photos, run **File >
Plug-in Extras > LrLexicon: Generate Keywords**, review/edit the generated
keywords per photo in a modal dialog, and write the accepted ones to the
catalog.

Also has: retry-with-backoff on rate-limited/server-error API responses,
defensive keyword filtering (length/count caps), and failure messages that
surface the actual last error rather than only pointing at the log.

Not yet built: further polish as issues come up (e.g. per-provider quirks).

## Structure

```
LrLexicon.lrplugin/
  Info.lua              -- plugin manifest, menu registration
  GenerateKeywords.lua  -- entry point: preview -> base64 -> API call -> review dialog -> catalog write
  Preferences.lua       -- settings storage (LrPrefs + LrPasswords) and settings dialog
  OpenSettings.lua      -- thin menu-item script that opens the settings dialog
  ApiClient.lua         -- generic OpenAI-compatible chat completions client (LrHttp)
  Json.lua              -- minimal hand-written JSON encode/decode (SDK has no bundled JSON library)
  Base64.lua            -- pure-Lua base64 encoder (no bit-library dependency)
```

## Loading the plugin in Lightroom Classic

1. Open Lightroom Classic.
2. File > Plug-in Manager > Add, then select the `LrLexicon.lrplugin` folder.
3. Confirm it shows as "Installed and running".
4. File > Plug-in Extras > LrLexicon: Settings — set the endpoint URL,
   model, prompt, and API key (leave the key blank for endpoints that don't
   require auth, e.g. a local Ollama/LM Studio server). Defaults point at a
   local Ollama server running `llava:latest` if left unconfigured.
5. Select one or more photos, then File > Plug-in Extras > LrLexicon:
   Generate Keywords.
6. Review the generated keywords in the dialog (uncheck a photo to skip it,
   edit the text if needed), then click "Write Keywords" (or "Cancel" to
   write nothing).

Logs go to `LrLexicon.log` under
`%LOCALAPPDATA%\Adobe\Lightroom\Logs\LrClassicLogs\` on Windows.

There's no right-click context menu entry — Lightroom Classic's native photo
context menu isn't extensible by third-party plugins via the public Lua SDK.
File > Plug-in Extras is the only menu access point.

## Configuration

Endpoint URL, model, and prompt are stored via `LrPrefs` (the plugin's
plain-text preferences file — fine for non-sensitive settings). The API key
is stored via `LrPasswords`, which uses the OS-native credential store
(Keychain on Mac, Credential Manager on Windows) rather than plain text.
`Preferences.getConfig()` is the single source of truth `GenerateKeywords.lua`
reads from; there's no hardcoded config left in the pipeline itself.

## Known limitations

- **Small local models produce inconsistent output.** The same prompt/image
  against `llava:latest` has produced a clean keyword list, a plain caption,
  a labeled breakdown, and even a literal echo of the prompt's own wording,
  across separate calls. `parseKeywords()` in `GenerateKeywords.lua` tolerates
  line breaks, bullets, stray label prefixes, and caps both individual
  keyword length (60 chars) and count per photo (25), but the review dialog
  is the real safety net for whatever slips through — a hosted model (OpenAI,
  Claude via a compatible endpoint) should be far more consistent, easy to
  try now via the settings dialog.
- **Rate limits/transient errors:** `ApiClient.generateKeywords()` retries up
  to 3 times with exponential backoff (2s, 4s, 8s) on HTTP 429 or 5xx
  responses before giving up on that photo. No proactive throttling between
  requests — this is reactive only, since a fixed delay would just slow down
  local-model usage for no benefit.
- **Preview size.** `photo:requestJpegThumbnail(1024, 1024, ...)` previews
  have run 260KB-1.2MB base64-encoded — larger than expected for a "small
  preview." Worth revisiting if large batches hit payload-size or cost
  limits.
- **`catalog:createKeyword()`'s documented 5th argument (`isPersonKeyword`)
  triggers a generic "assertion failed!"** on this Lightroom Classic build.
  It's omitted; the call only passes `(name, synonyms, includeOnExport,
  parent)`.
