-- Server entry point. Starts every service in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes) -- creates the remotes before any client asks for them

local Services = script.Parent.Services
local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local CharacterService = require(Services.CharacterService)
local PlotService = require(Services.PlotService)
local SpeedService = require(Services.SpeedService)
local HouseService = require(Services.HouseService)
local ShopService = require(Services.ShopService)
local DayNightService = require(Services.DayNightService)
local RoadCandyService = require(Services.RoadCandyService)

-- The model gallery is only for looking at the art in Studio; players never see it.
local gallery = workspace:FindFirstChild("ModelGallery")
if gallery then
	gallery:Destroy()
end

local map = MapBuilder.EnsureMap()
task.spawn(function() -- stop flat surfaces in the houses and hub from flickering (in the background)
	local ok, err = pcall(MapBuilder.FixFlicker, map)
	if not ok then
		warn("[SpookySteal] flicker fix failed:", err)
	end
end)

task.spawn(function() -- the platform that compares pet sizes, floating in the void to the right of the map
	local ok, err = pcall(MapBuilder.BuildSizeStage)
	if not ok then
		warn("[SpookySteal] size platform failed:", err)
	end
end)

ShopService.Start(map)
DataService.Start()
game:GetService("MarketplaceService").ProcessReceipt = DataService.ProcessReceipt
CharacterService.Start()
PlotService.Start(map)
SpeedService.Start()
HouseService.Start(map) -- registers its night/day callbacks before the cycle starts
DayNightService.Start(map)
RoadCandyService.Start(map)

print("[SpookySteal] Server ready")
