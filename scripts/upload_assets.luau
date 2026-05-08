--!strict
--
-- Uploads every PNG in `assets/icons/` to Roblox as a Decal via Open Cloud.
-- Requires `ROBLOX_OPEN_CLOUD_API_KEY` in the environment, plus
-- `ROBLOX_USER_ID` (or `ROBLOX_GROUP_ID`) describing who to upload as.
--
-- After every successful upload the corresponding entry in
-- `src/shared/IconIds.luau` is replaced with the resulting `rbxassetid://...`.
--
-- Run with: ``lune run scripts/upload_assets.luau``

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local API_BASE = "https://apis.roblox.com/assets/v1/assets"

local apiKey = process.env.ROBLOX_OPEN_CLOUD_API_KEY
if not apiKey or apiKey == "" then
	error("ROBLOX_OPEN_CLOUD_API_KEY is not set")
end

local userId = process.env.ROBLOX_USER_ID
local groupId = process.env.ROBLOX_GROUP_ID

if (not userId or userId == "") and (not groupId or groupId == "") then
	error("Set ROBLOX_USER_ID or ROBLOX_GROUP_ID")
end

-- The mapping of file stem -> entry name in IconIds.luau.
-- Filenames in `assets/icons/` are e.g. `Heart.png`; the matching key in
-- `IconIds.luau` is `Heart`. We just iterate the directory.

local iconDir = "assets/icons"
local iconIdsPath = "src/shared/IconIds.luau"

local files = {}
for _, entry in fs.readDir(iconDir) do
	if string.sub(entry, -4) == ".png" then
		table.insert(files, entry)
	end
end
table.sort(files)
print(string.format("Found %d PNG icons in %s", #files, iconDir))

-- Build multipart form body. Lune's `net.request` doesn't have multipart support
-- baked in so we serialise the body manually.
local function multipart(parts: { { name: string, value: string, filename: string?, contentType: string? } })
	local boundary = "----LuneBoundary" .. tostring(os.time()) .. tostring(math.random(1, 1e9))
	local pieces: { string } = {}
	for _, part in parts do
		table.insert(pieces, "--" .. boundary)
		if part.filename then
			table.insert(
				pieces,
				string.format(
					'Content-Disposition: form-data; name="%s"; filename="%s"',
					part.name,
					part.filename
				)
			)
			table.insert(
				pieces,
				"Content-Type: " .. (part.contentType or "application/octet-stream")
			)
		else
			table.insert(pieces, string.format('Content-Disposition: form-data; name="%s"', part.name))
		end
		table.insert(pieces, "")
		table.insert(pieces, part.value)
	end
	table.insert(pieces, "--" .. boundary .. "--")
	table.insert(pieces, "")
	return table.concat(pieces, "\r\n"), boundary
end

local function buildCreator(): { [string]: any }
	if groupId and groupId ~= "" then
		return { groupId = tonumber(groupId) }
	end
	return { userId = tonumber(userId) }
end

local function pollOperation(opPath: string, timeoutSeconds: number?): any
	local timeout = timeoutSeconds or 60
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local resp = net.request({
			url = "https://apis.roblox.com/assets/v1/" .. opPath,
			method = "GET",
			headers = { ["x-api-key"] = apiKey },
		})
		if not resp.ok then
			error(string.format("operation poll failed: HTTP %d - %s", resp.statusCode, resp.body))
		end
		local body = serde.decode("json", resp.body)
		if body.done then
			if body.error then
				error("operation failed: " .. tostring(body.error.message or body.error))
			end
			return body.response
		end
		task.wait(1)
	end
	error("operation timed out after " .. tostring(timeout) .. "s")
end

local function uploadOne(displayName: string, filename: string, fileBytes: string): string?
	local request = {
		assetType = "Decal",
		displayName = displayName,
		description = displayName .. " icon (Devin/Figma export)",
		creationContext = {
			creator = buildCreator(),
		},
	}
	local body, boundary = multipart({
		{
			name = "request",
			value = serde.encode("json", request),
		},
		{
			name = "fileContent",
			value = fileBytes,
			filename = filename,
			contentType = "image/png",
		},
	})
	local resp = net.request({
		url = API_BASE,
		method = "POST",
		headers = {
			["x-api-key"] = apiKey,
			["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
		},
		body = body,
	})
	if not resp.ok then
		print(string.format("  ! upload failed: HTTP %d - %s", resp.statusCode, resp.body))
		return nil
	end
	local json = serde.decode("json", resp.body)
	if json.path then
		local op = pollOperation(json.path)
		-- Decals upload as a Decal asset whose `assetId` is the rbxassetid.
		local assetId: any = op and op.assetId
		if assetId then
			return tostring(assetId)
		end
		if op and op.response and op.response.assetId then
			return tostring(op.response.assetId)
		end
	end
	return nil
end

local function readFileBytes(path: string): string
	return fs.readFile(path)
end

-- Patch the matching `IconIds.<key> = ""` line in IconIds.luau in-place.
local function patchIconIds(map: { [string]: string })
	local source = fs.readFile(iconIdsPath)
	for key, assetId in pairs(map) do
		local pattern = string.format('IconIds%%.%s = ""', key)
		local replacement = string.format('IconIds.%s = "rbxassetid://%s"', key, assetId)
		local replaced, count = string.gsub(source, pattern, replacement, 1)
		if count == 0 then
			print(string.format("warning: no IconIds.%s = \"\" line found", key))
		else
			source = replaced
		end
	end
	fs.writeFile(iconIdsPath, source)
end

local results: { [string]: string } = {}
for _, file in files do
	local key = string.sub(file, 1, -5)
	io.write(string.format("[%s] uploading... ", key))
	local bytes = readFileBytes(iconDir .. "/" .. file)
	local assetId = uploadOne(key, file, bytes)
	if assetId then
		print("ok = " .. assetId)
		results[key] = assetId
	else
		print("FAILED")
	end
end

if next(results) then
	patchIconIds(results)
	print(string.format("Patched %s with %d new IDs", iconIdsPath, (function()
		local n = 0
		for _ in pairs(results) do
			n += 1
		end
		return n
	end)()))
else
	print("No assets uploaded; IconIds.luau left untouched")
end
