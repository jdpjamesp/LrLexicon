# LrLexicon

A Lightroom Classic plugin that uses AI to generate keywords for your photos.
Select photos, run one command, review the suggested keywords, and write the
ones you want into your catalog.

## Bring your own AI

LrLexicon doesn't include or depend on any specific AI service. You connect
it to whichever vision-capable AI API you want to use:

- A cloud provider you already have an account/API key for (e.g. OpenAI)
- A model running locally on your own machine (e.g. [Ollama](https://ollama.com)
  or [LM Studio](https://lmstudio.ai)) — no API key needed, and no photos
  ever leave your computer
- Any other service that exposes an OpenAI-style "chat completions" API with
  image support

This means any usage costs, rate limits, and terms of service are between you
and whichever provider you choose — LrLexicon itself doesn't charge, meter,
or restrict anything.

## Requirements

- Lightroom Classic (desktop)
- Access to a vision-capable AI API (see above)

## Installation

1. Download or clone this repository somewhere permanent — Lightroom loads
   the plugin directly from this folder, so don't delete or move it later
   (Lightroom will show the plugin as missing if you do).
2. In Lightroom Classic: **File > Plug-in Manager**.
3. Click **Add**, then select the `LrLexicon.lrplugin` folder.
4. Confirm it's listed as "Installed and running."

## Setting up your AI connection

Before generating any keywords, open **File > Plug-in Extras > LrLexicon:
Settings** and fill in:

| Field | What to enter |
|---|---|
| Endpoint URL | The full chat completions API URL for your provider. Examples: `https://api.openai.com/v1/chat/completions` (OpenAI), `http://localhost:11434/v1/chat/completions` (local Ollama), `http://localhost:1234/v1/chat/completions` (local LM Studio) |
| Model | The exact model name your provider expects, e.g. `gpt-4o-mini` or `llava:latest` |
| API Key | Required by most cloud providers; leave blank for local servers that don't need one. Stored in your OS's secure credential store (Keychain on Mac, Credential Manager on Windows) — never saved as plain text |
| Prompt | The instruction sent to the AI describing what to generate. A sensible default is pre-filled; edit it to change the style, number, or focus of the keywords |

## Using it

1. Select one or more photos in the Library grid or filmstrip.
2. **File > Plug-in Extras > LrLexicon: Generate Keywords**.
3. Lightroom's progress area shows each photo being processed (local models
   are noticeably slower than cloud APIs).
4. A review window shows the suggested keywords for every photo. Uncheck any
   photo you don't want to update, or edit the keyword text directly.
5. Click **Write Keywords** to save them to your catalog, or **Cancel** to
   discard everything. Nothing is written to your catalog until you approve
   it here.

There's no right-click menu entry — Lightroom Classic doesn't allow plugins
to add one, so **File > Plug-in Extras** is the only menu location. If you
use LrLexicon often, a third-party shortcut plugin (e.g. "Any Shortcut") can
bind it to a key.

## Things to know

- **Your photos are sent to whichever endpoint you configure**, as compressed
  preview images. With a cloud provider, that means images leave your
  computer and are subject to that provider's terms and privacy policy. A
  local model (Ollama, LM Studio) keeps everything on your machine.
- **AI-generated keywords can be inconsistent**, especially with smaller or
  local models — that's exactly why there's a review step. Always check
  before writing.
- **You pay for what you use.** Any API costs belong to your chosen provider;
  LrLexicon adds no fees of its own.

## Troubleshooting

- Logs are written to `LrLexicon.log` — on Windows, under
  `%LOCALAPPDATA%\Adobe\Lightroom\Logs\LrClassicLogs\`.
- If generation fails, the summary dialog shows the last error message; the
  log has full detail for every photo.
- If your provider rate-limits requests, LrLexicon retries automatically a
  few times with increasing delays before giving up on that photo.

## Repository structure

```
LrLexicon.lrplugin/
  Info.lua              -- plugin manifest, menu registration
  GenerateKeywords.lua  -- main pipeline: preview -> API call -> review -> catalog write
  Preferences.lua       -- settings storage and the Settings dialog
  OpenSettings.lua      -- menu-item script that opens the Settings dialog
  ApiClient.lua         -- OpenAI-compatible chat completions client
  Json.lua              -- minimal JSON encode/decode
  Base64.lua            -- base64 encoder
```
