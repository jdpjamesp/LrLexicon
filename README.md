# LrLexicon

A Lightroom Classic plugin that sends selected photos to the Claude API
(vision-capable model) and writes back AI-generated keywords onto photo
metadata.

## Status

Step 1 scaffolded: bare plugin with a single menu item under
**File > Plug-in Extras > LrLexicon: Log Selected Photos** that logs the
filename and existing keywords of each selected photo.

## Structure

```
LrLexicon.lrplugin/
  Info.lua                  -- plugin manifest, menu registration
  LogSelectedPhotos.lua     -- step 1: logs selected photos' filenames/keywords
```

## Loading the plugin in Lightroom Classic

1. Open Lightroom Classic.
2. File > Plug-in Manager.
3. Click "Add", then select the `LrLexicon.lrplugin` folder in this repo.
4. Confirm it shows as "Installed and running" in the manager.
5. Select one or more photos in the Library, then go to
   File > Plug-in Extras > LrLexicon: Log Selected Photos.
6. A confirmation dialog appears; details are written to `LrLexicon.log`
   (Lightroom writes plugin logs to the user's home/Documents folder —
   exact location depends on OS; search for `LrLexicon.log` if unsure).

## Build order

See project handover notes. Current step: 1 (scaffold + selection logging).
Next: export a small preview per photo for the Claude API call.
