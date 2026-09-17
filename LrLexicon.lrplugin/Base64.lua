local Base64 = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function Base64.encode(data)
	local result = {}
	local len = #data

	for i = 1, len, 3 do
		local b1, b2, b3 = data:byte(i, i + 2)
		b2 = b2 or 0
		b3 = b3 or 0

		local n = b1 * 65536 + b2 * 256 + b3

		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64

		local chunk = ALPHABET:sub(c1 + 1, c1 + 1)
			.. ALPHABET:sub(c2 + 1, c2 + 1)
			.. ALPHABET:sub(c3 + 1, c3 + 1)
			.. ALPHABET:sub(c4 + 1, c4 + 1)

		local remaining = len - i + 1
		if remaining == 1 then
			chunk = chunk:sub(1, 2) .. "=="
		elseif remaining == 2 then
			chunk = chunk:sub(1, 3) .. "="
		end

		table.insert(result, chunk)
	end

	return table.concat(result)
end

return Base64
