-- Standalone test for an OpenAI-compatible chat completions vision API.
-- Run outside Lightroom: lua test-api.lua <path-to-jpg>
--
-- Shells out to curl for the HTTP request (no LuaSocket dependency assumed)
-- and writes the request body to a temp file to avoid command-line length
-- limits with large base64 payloads.

local Base64 = require 'Base64'

local API_BASE_URL = "http://localhost:11434/v1/chat/completions"
local MODEL = "llava:latest"
local PROMPT = "List 12-15 comma-separated keywords describing this photo's subject, setting, "
	.. "mood, and photographic technique. Output only the keywords as a plain "
	.. "comma-separated list, with no labels, headings, or extra text."

local imagePath = arg[1]
if not imagePath then
	io.stderr:write("Usage: lua test-api.lua <path-to-jpg>\n")
	os.exit(1)
end

local imageFile = io.open(imagePath, "rb")
if not imageFile then
	io.stderr:write("Could not open image: " .. imagePath .. "\n")
	os.exit(1)
end
local imageData = imageFile:read("*a")
imageFile:close()

local base64Data = Base64.encode(imageData)

-- Hand-rolled JSON: the prompt is a fixed literal and the base64 alphabet
-- needs no escaping, so a full JSON encoder isn't needed for this test.
local payload = string.format(
	[[{"model":"%s","messages":[{"role":"user","content":[{"type":"text","text":"%s"},{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,%s"}}]}]}]],
	MODEL, PROMPT, base64Data
)

local payloadPath = os.tmpname()
local responsePath = os.tmpname()

local payloadFile = io.open(payloadPath, "w")
payloadFile:write(payload)
payloadFile:close()

local curlCommand = string.format(
	'curl -s -X POST "%s" -H "Content-Type: application/json" --data "@%s" -o "%s" -w "HTTP status: %%{http_code}\\n"',
	API_BASE_URL, payloadPath, responsePath
)

print("Sending request to " .. API_BASE_URL .. " ...")
os.execute(curlCommand)

local responseFile = io.open(responsePath, "r")
local responseBody = responseFile:read("*a")
responseFile:close()

print("\nRaw response:")
print(responseBody)

os.remove(payloadPath)
os.remove(responsePath)
