# LrLexicon — AI Auto-Keywording Plugin for Lightroom Classic

LrLexicon is a free, open-source Lightroom Classic plugin that automatically
generates photo keywords using AI. Select photos, run one command, and get
AI-suggested keywords covering subject, setting, mood, and photographic
technique — reviewed and editable before anything is written to your
catalog.

It works with OpenAI, any OpenAI-compatible API, or a fully local/offline AI
model such as [Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai)
— you choose the provider, so your photos and API costs stay under your
control.

## Features

- **Automatic AI keywording** for Lightroom Classic — describe a photo's
  subject, setting, mood, and technique without typing a single tag by hand
- **Bring your own AI** — OpenAI, any OpenAI-compatible endpoint, or a local
  model (Ollama, LM Studio) for private, offline keyword generation with no
  photos ever leaving your computer
- **Review before you commit** — a built-in review step means nothing is
  written to your Lightroom catalog without your approval
- **No vendor lock-in** — switch AI providers any time from the Settings
  dialog, no code changes required
- **Free and open source**

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

## Frequently asked questions

**Can I use ChatGPT/OpenAI to automatically tag or keyword my Lightroom
photos?**
Yes. Point LrLexicon's Settings at `https://api.openai.com/v1/chat/completions`
with your OpenAI API key and a vision-capable model (e.g. `gpt-4o-mini`), and
it will generate keywords for any photos you select.

**Does this work offline, with a local AI model?**
Yes. LrLexicon works with local model servers like Ollama and LM Studio —
point the Endpoint URL at your local server (e.g.
`http://localhost:11434/v1/chat/completions` for Ollama) and leave the API
Key blank. No photos leave your computer and there's no usage cost.

**Is my photo data private?**
Only if you use a local model. With any cloud/hosted AI provider, a
compressed preview of each selected photo is sent to that provider's API and
is subject to their terms and privacy policy — LrLexicon itself doesn't
store or transmit anything beyond that single request.

**Does this plugin cost money?**
LrLexicon itself is free. If you use a paid AI provider (like OpenAI), you
pay that provider directly for API usage — LrLexicon adds no fees of its
own. A local model via Ollama or LM Studio is free to run.

**What Lightroom versions does this support?**
Lightroom Classic (desktop). It is not compatible with Lightroom (cloud) or
mobile.

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

## Disclaimer

LrLexicon is provided **as-is, with no warranty of any kind**, express or
implied — see the [LICENSE](LICENSE) for the full legal text. Using it is
entirely at your own risk. In particular:

- It writes to your Lightroom catalog. **Back up your catalog** before
  running it on photos you care about, as you would before using any
  third-party plugin.
- AI-generated keywords can be wrong, irrelevant, or nonsensical — the
  review step exists so you can catch this, but ultimately you're
  responsible for whatever gets written to your catalog.
- This project isn't affiliated with or endorsed by Adobe, OpenAI, Ollama,
  or any AI provider it happens to connect to.
- **No support is offered.** This is a personal project shared as-is, with
  no guarantee of bug fixes, updates, or response to issues. Pull requests
  may be reviewed from time to time, but there's no commitment to do so —
  feel free to fork it if you need changes.

## License

[GNU General Public License v3.0](LICENSE) © 2026 James Palmer. You're free
to use, modify, and redistribute this software under the terms of the GPLv3;
see the [LICENSE](LICENSE) file for the full text.
