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

-- The model gallery is only for looking at the art in Studio; players never see it.
local gallery = workspace:FindFirstChild("ModelGallery")
if gallery then
	gallery:Destroy()
end

local map = MapBuilder.EnsureMap()

ShopService.Start(map)
DataService.Start()
CharacterService.Start()
PlotService.Start(map)
SpeedService.Start()
HouseService.Start(map) -- registers its night/day callbacks before the cycle starts
DayNightService.Start(map)

print("[SpookySteal] Server ready")
