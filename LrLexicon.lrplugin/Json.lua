-- Minimal, self-contained JSON encoder/decoder.
-- Purpose-built for API request/response bodies rather than vendored, since
-- the Lightroom SDK bundles no JSON library and no third-party one could be
-- verified byte-for-byte against this environment.

local Json = {}

Json.null = setmetatable({}, { __tostring = function() return "null" end })

-- ENCODE

local encodeValue

local function escapeString(s)
	return (s:gsub('[%c\\"]', function(c)
		if c == "\\" then return "\\\\"
		elseif c == '"' then return '\\"'
		elseif c == "\n" then return "\\n"
		elseif c == "\r" then return "\\r"
		elseif c == "\t" then return "\\t"
		else return string.format("\\u%04x", c:byte())
		end
	end))
end

local function isArray(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	for i = 1, count do
		if t[i] == nil then
			return false
		end
	end
	return count > 0
end

local function encodeTable(t)
	if isArray(t) then
		local parts = {}
		for i, v in ipairs(t) do
			parts[i] = encodeValue(v)
		end
		return "[" .. table.concat(parts, ",") .. "]"
	else
		local parts = {}
		for k, v in pairs(t) do
			table.insert(parts, '"' .. escapeString(tostring(k)) .. '":' .. encodeValue(v))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
end

encodeValue = function(v)
	if v == Json.null then
		return "null"
	end

	local t = type(v)
	if t == "string" then
		return '"' .. escapeString(v) .. '"'
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		return encodeTable(v)
	elseif t == "nil" then
		return "null"
	else
		error("Cannot encode value of type " .. t)
	end
end

Json.encode = encodeValue

-- DECODE

local function decodeError(str, pos, msg)
	error(string.format("JSON decode error at position %d: %s", pos, msg))
end

local function skipWhitespace(str, pos)
	local _, e = str:find("^%s*", pos)
	return e + 1
end

local decodeValue

local function decodeString(str, pos)
	local i = pos + 1
	local parts = {}
	while true do
		local startI = i
		local matchPos = str:find('[\\"]', i)
		if not matchPos then
			decodeError(str, i, "unterminated string")
		end
		if matchPos > startI then
			table.insert(parts, str:sub(startI, matchPos - 1))
		end

		local c = str:sub(matchPos, matchPos)
		if c == '"' then
			return table.concat(parts), matchPos + 1
		end

		local nc = str:sub(matchPos + 1, matchPos + 1)
		if nc == '"' then table.insert(parts, '"'); i = matchPos + 2
		elseif nc == "\\" then table.insert(parts, "\\"); i = matchPos + 2
		elseif nc == "/" then table.insert(parts, "/"); i = matchPos + 2
		elseif nc == "n" then table.insert(parts, "\n"); i = matchPos + 2
		elseif nc == "t" then table.insert(parts, "\t"); i = matchPos + 2
		elseif nc == "r" then table.insert(parts, "\r"); i = matchPos + 2
		elseif nc == "b" then table.insert(parts, "\b"); i = matchPos + 2
		elseif nc == "f" then table.insert(parts, "\f"); i = matchPos + 2
		elseif nc == "u" then
			local hex = str:sub(matchPos + 2, matchPos + 5)
			local codepoint = tonumber(hex, 16)
			if not codepoint then
				decodeError(str, matchPos, "invalid unicode escape")
			end
			if codepoint < 0x80 then
				table.insert(parts, string.char(codepoint))
			elseif codepoint < 0x800 then
				table.insert(parts, string.char(
					0xC0 + math.floor(codepoint / 0x40),
					0x80 + (codepoint % 0x40)
				))
			else
				table.insert(parts, string.char(
					0xE0 + math.floor(codepoint / 0x1000),
					0x80 + (math.floor(codepoint / 0x40) % 0x40),
					0x80 + (codepoint % 0x40)
				))
			end
			i = matchPos + 6
		else
			decodeError(str, matchPos, "invalid escape character")
		end
	end
end

local function decodeNumber(str, pos)
	local matchStart, matchEnd, numStr = str:find("^(-?%d+%.?%d*[eE]?[+-]?%d*)", pos)
	if not numStr then
		decodeError(str, pos, "invalid number")
	end
	return tonumber(numStr), matchEnd + 1
end

local function decodeArray(str, pos)
	local result = {}
	local i = skipWhitespace(str, pos + 1)
	if str:sub(i, i) == "]" then
		return result, i + 1
	end

	local idx = 1
	while true do
		local value
		value, i = decodeValue(str, i)
		result[idx] = value
		idx = idx + 1

		i = skipWhitespace(str, i)
		local c = str:sub(i, i)
		if c == "," then
			i = skipWhitespace(str, i + 1)
		elseif c == "]" then
			return result, i + 1
		else
			decodeError(str, i, "expected ',' or ']'")
		end
	end
end

local function decodeObject(str, pos)
	local result = {}
	local i = skipWhitespace(str, pos + 1)
	if str:sub(i, i) == "}" then
		return result, i + 1
	end

	while true do
		if str:sub(i, i) ~= '"' then
			decodeError(str, i, "expected string key")
		end
		local key
		key, i = decodeString(str, i)

		i = skipWhitespace(str, i)
		if str:sub(i, i) ~= ":" then
			decodeError(str, i, "expected ':'")
		end
		i = skipWhitespace(str, i + 1)

		local value
		value, i = decodeValue(str, i)
		result[key] = value

		i = skipWhitespace(str, i)
		local c = str:sub(i, i)
		if c == "," then
			i = skipWhitespace(str, i + 1)
		elseif c == "}" then
			return result, i + 1
		else
			decodeError(str, i, "expected ',' or '}'")
		end
	end
end

decodeValue = function(str, pos)
	pos = skipWhitespace(str, pos)
	local c = str:sub(pos, pos)

	if c == '"' then
		return decodeString(str, pos)
	elseif c == "{" then
		return decodeObject(str, pos)
	elseif c == "[" then
		return decodeArray(str, pos)
	elseif c == "t" then
		if str:sub(pos, pos + 3) == "true" then
			return true, pos + 4
		end
		decodeError(str, pos, "invalid literal")
	elseif c == "f" then
		if str:sub(pos, pos + 4) == "false" then
			return false, pos + 5
		end
		decodeError(str, pos, "invalid literal")
	elseif c == "n" then
		if str:sub(pos, pos + 3) == "null" then
			return Json.null, pos + 4
		end
		decodeError(str, pos, "invalid literal")
	elseif c == "-" or c:match("%d") then
		return decodeNumber(str, pos)
	else
		decodeError(str, pos, "unexpected character '" .. c .. "'")
	end
end

function Json.decode(str)
	local value = decodeValue(str, 1)
	return value
end

return Json
