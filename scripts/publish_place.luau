--!strict
--
-- Publishes `build/game.rbxlx` to a place via the Open Cloud
-- "Place Management" / "Universes" API.
--
-- Required env:
--   ROBLOX_OPEN_CLOUD_API_KEY  - the API key (Place Management:Write scope)
--   ROBLOX_UNIVERSE_ID         - the universe (experience) id
--   ROBLOX_PLACE_ID            - the place id within that universe
--
-- Optional env:
--   ROBLOX_PUBLISH_VERSION_TYPE - "Saved" (default) or "Published"
--
-- Run with: ``lune run scripts/publish_place.luau``

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local apiKey = process.env.ROBLOX_OPEN_CLOUD_API_KEY
local universeId = process.env.ROBLOX_UNIVERSE_ID
local placeId = process.env.ROBLOX_PLACE_ID
local versionType = process.env.ROBLOX_PUBLISH_VERSION_TYPE or "Saved"

assert(apiKey and apiKey ~= "", "ROBLOX_OPEN_CLOUD_API_KEY is required")
assert(universeId and universeId ~= "", "ROBLOX_UNIVERSE_ID is required")
assert(placeId and placeId ~= "", "ROBLOX_PLACE_ID is required")

local rbxlxPath = "build/game.rbxlx"
if not fs.isFile(rbxlxPath) then
	error("Run `rojo build -o build/game.rbxlx` before publishing.")
end

local fileBytes = fs.readFile(rbxlxPath)

local url = string.format(
	"https://apis.roblox.com/universes/v1/%s/places/%s/versions?versionType=%s",
	universeId,
	placeId,
	versionType
)

print(string.format("POST %s (%d bytes)", url, #fileBytes))

local resp = net.request({
	url = url,
	method = "POST",
	headers = {
		["x-api-key"] = apiKey,
		["Content-Type"] = "application/xml",
	},
	body = fileBytes,
})

print(string.format("HTTP %d", resp.statusCode))

if not resp.ok then
	print(resp.body)
	error("publish failed")
end

local json = serde.decode("json", resp.body)
print("Published version: " .. tostring(json.versionNumber))
print(string.format("https://www.roblox.com/games/%s", placeId))
