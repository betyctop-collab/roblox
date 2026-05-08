--!strict
--
-- Open Cloud Assets API uploader.
--
-- For each PNG in `assets/icons/`, POSTs a Decal asset, polls the operation
-- until it reports done, then patches the matching key in
-- `src/shared/IconIds.luau` with the resulting `rbxassetid://...`.
--
-- Required env vars:
--   ROBLOX_OPEN_CLOUD_API_KEY   the API key with `assets:read,write` scope
-- AND one of:
--   ROBLOX_USER_ID              numeric user id when uploading under a user
--   ROBLOX_GROUP_ID             numeric group id when uploading under a group
--
-- Run:
--   lune run scripts/upload_assets.luau

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local API_BASE = "https://apis.roblox.com/assets/v1"

local function getEnv(name: string): string?
	local v = process.env[name]
	if v == nil or v == "" then
		return nil
	end
	return v
end

local apiKey = getEnv("ROBLOX_OPEN_CLOUD_API_KEY")
assert(apiKey, "ROBLOX_OPEN_CLOUD_API_KEY env var is required")

local userId = getEnv("ROBLOX_USER_ID")
local groupId = getEnv("ROBLOX_GROUP_ID")
assert(userId or groupId, "Either ROBLOX_USER_ID or ROBLOX_GROUP_ID env var is required")

local function buildCreator(): { [string]: any }
	if userId then
		return { userId = userId }
	end
	return { groupId = groupId }
end

local BOUNDARY = "----DevinUploadBoundary" .. tostring(os.time())

-- Build a multipart/form-data body. `parts` is a list of part descriptors:
--   { name, value }                      simple text part
--   { name, filename, contentType, value }  file part
local function multipart(parts: { { [string]: string } }): string
	local lines = {}
	for _, part in parts do
		table.insert(lines, "--" .. BOUNDARY)
		if part.filename then
			table.insert(
				lines,
				string.format(
					'Content-Disposition: form-data; name="%s"; filename="%s"',
					part.name,
					part.filename
				)
			)
			table.insert(
				lines,
				"Content-Type: " .. (part.contentType or "application/octet-stream")
			)
		else
			table.insert(
				lines,
				string.format('Content-Disposition: form-data; name="%s"', part.name)
			)
		end
		table.insert(lines, "")
		table.insert(lines, part.value)
	end
	table.insert(lines, "--" .. BOUNDARY .. "--")
	table.insert(lines, "")
	return table.concat(lines, "\r\n")
end

local function pollOperation(opPath: string, timeoutSeconds: number): { [string]: any }?
	local started = os.clock()
	while os.clock() - started < timeoutSeconds do
		task.wait(1.0)
		local response = net.request({
			method = "GET",
			url = "https://apis.roblox.com/assets/v1/" .. opPath,
			headers = { ["x-api-key"] = apiKey :: string },
		})
		if not response.ok then
			print(
				string.format(
					"  poll HTTP %d: %s",
					response.statusCode,
					tostring(response.body):sub(1, 200)
				)
			)
		else
			local data = serde.decode("json", response.body)
			if data.done then
				return data.response
			end
		end
	end
	return nil
end

local function uploadOne(displayName: string, filename: string, fileBytes: string): string?
	print(string.format("[%s] uploading %d bytes", displayName, #fileBytes))
	local request = serde.encode("json", {
		assetType = "Decal",
		displayName = displayName,
		description = displayName .. " (uploaded by Devin)",
		creationContext = {
			creator = buildCreator(),
		},
	})
	local body = multipart({
		{ name = "request", value = request },
		{
			name = "fileContent",
			filename = filename,
			contentType = "image/png",
			value = fileBytes,
		},
	})

	local response = net.request({
		method = "POST",
		url = API_BASE .. "/assets",
		headers = {
			["x-api-key"] = apiKey :: string,
			["Content-Type"] = "multipart/form-data; boundary=" .. BOUNDARY,
		},
		body = body,
	})
	if not response.ok then
		print(
			string.format(
				"[%s] POST failed: HTTP %d %s",
				displayName,
				response.statusCode,
				tostring(response.body):sub(1, 240)
			)
		)
		return nil
	end

	local op = serde.decode("json", response.body)
	if op.path then
		local result = pollOperation(op.path, 60)
		if result and result.assetId then
			return tostring(result.assetId)
		end
		print(string.format("[%s] operation timed out or returned no assetId", displayName))
	else
		print(string.format("[%s] response had no operation path: %s", displayName, response.body))
	end
	return nil
end

local function patchIconIds(map: { [string]: string })
	local path = "src/shared/IconIds.luau"
	local source = fs.readFile(path)
	for key, assetId in pairs(map) do
		local replacement = string.format("%%1thumb(%s)", assetId)
		local pattern = "(IconIds%." .. key .. "%s*=%s*)thumb%(%d+%)"
		local newSource, n = string.gsub(source, pattern, replacement, 1)
		if n == 1 then
			source = newSource
		else
			-- Fall back to replacing any string literal so older versions of
			-- this file (with `rbxassetid://` literals) still get patched.
			pattern = "(IconIds%." .. key .. '%s*=%s*)"[^"]*"'
			source = string.gsub(source, pattern, replacement, 1)
		end
	end
	fs.writeFile(path, source)
end

local entries = fs.readDir("assets/icons")
table.sort(entries)
local map: { [string]: string } = {}
for _, entry in entries do
	if string.match(entry, "%.png$") then
		local key = string.gsub(entry, "%.png$", "")
		local bytes = fs.readFile("assets/icons/" .. entry)
		local assetId = uploadOne(key, entry, bytes)
		if assetId then
			map[key] = assetId
			print(string.format("[%s] ok = %s", key, assetId))
		else
			print(string.format("[%s] FAILED", key))
		end
	end
end
patchIconIds(map)
print(string.format(
	"Patched IconIds.luau with %d entries",
	(function()
		local n = 0
		for _ in pairs(map) do
			n += 1
		end
		return n
	end)()
))
