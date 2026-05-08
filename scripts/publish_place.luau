--!strict
--
-- Open Cloud Place Management API publisher.
--
-- Reads `build/game.rbxlx` and POSTs it to the universe/place pair.
--
-- Required env vars:
--   ROBLOX_OPEN_CLOUD_API_KEY        API key with `universe-places:write` scope.
--   ROBLOX_UNIVERSE_ID               numeric universe id
--   ROBLOX_PLACE_ID                  numeric place id
-- Optional:
--   ROBLOX_PUBLISH_VERSION_TYPE      "Saved" or "Published" (default Saved).
--
-- Run:
--   lune run scripts/publish_place.luau

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local function getEnv(name: string, default: string?): string?
	local v = process.env[name]
	if v == nil or v == "" then
		return default
	end
	return v
end

local apiKey = getEnv("ROBLOX_OPEN_CLOUD_API_KEY")
assert(apiKey, "ROBLOX_OPEN_CLOUD_API_KEY env var is required")

local universeId = getEnv("ROBLOX_UNIVERSE_ID")
assert(universeId, "ROBLOX_UNIVERSE_ID env var is required")

local placeId = getEnv("ROBLOX_PLACE_ID")
assert(placeId, "ROBLOX_PLACE_ID env var is required")

local versionType = getEnv("ROBLOX_PUBLISH_VERSION_TYPE", "Saved") :: string

local rbxlxPath = "build/game.rbxlx"
local body = fs.readFile(rbxlxPath)
local url = string.format(
	"https://apis.roblox.com/universes/v1/%s/places/%s/versions?versionType=%s",
	universeId,
	placeId,
	versionType
)
print(string.format("POST %s (%d bytes)", url, #body))

local response = net.request({
	method = "POST",
	url = url,
	headers = {
		["x-api-key"] = apiKey :: string,
		["Content-Type"] = "application/xml",
	},
	body = body,
})

print(string.format("HTTP %d", response.statusCode))
print(tostring(response.body):sub(1, 600))

if not response.ok then
	error("publish failed")
end

local data = serde.decode("json", response.body)
print(string.format("Published version: %s", tostring(data.versionNumber)))
print(string.format("https://www.roblox.com/games/%s", placeId))
