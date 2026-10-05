-- Road candy: candy icons scattered all along the road. Run through one to grab it.
-- Each pickup gives BASE_CANDY times your costume's CandyMultiplier (no costume = x1), then respawns elsewhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local RoadCandyService = {}

local COUNT = 160 -- candies on the road at once (about one every 13 studs)
local BASE_CANDY = 2
local RESPAWN_SECONDS = 4
local ICON = "rbxassetid://124163550546581" -- the HUD candy in white, tinted per candy
local COLORS = {
	Color3.fromRGB(255, 80, 170), Color3.fromRGB(255, 150, 40), Color3.fromRGB(150, 70, 230),
	Color3.fromRGB(80, 220, 120), Color3.fromRGB(255, 220, 60),
}

local function makeCandy(): Model
	local color = COLORS[math.random(#COLORS)]
	local model = Instance.new("Model")
	model.Name = "RoadCandy"
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(4, 5, 4)
	hitbox.Transparency = 1
	hitbox.Anchored, hitbox.CanCollide, hitbox.CanQuery = true, false, false
	hitbox.Parent = model
	model.PrimaryPart = hitbox
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(3.5, 3.5) -- studs
	board.StudsOffset = Vector3.new(0, -0.6, 0)
	board.LightInfluence = 0
	board.MaxDistance = 250
	board.Parent = hitbox
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = ICON
	image.ImageColor3 = color
	image.Parent = board
	return model
end

local function randomRoadCFrame(asphalt: BasePart): CFrame
	local size = asphalt.Size
	local x = (math.random() - 0.5) * (size.X - 6)
	local z = (math.random() - 0.5) * (size.Z - 10)
	local top = asphalt.Position.Y + size.Y / 2
	local at = asphalt.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
	return CFrame.new(at.X, top + 1.6, at.Z) * CFrame.Angles(0, math.random() * math.pi * 2, math.rad(20))
end

function RoadCandyService.Start(map: Instance)
	-- The road is a model of asphalt strips; use the biggest one as the area to scatter over.
	local road = map:FindFirstChild("Road", true)
	if not road then
		warn("[RoadCandy] no Road in the map")
		return
	end
	local cf, size = (road:FindFirstChild("Asphalt") or road):GetBoundingBox()
	local area = Instance.new("Part") -- never parented, only used for its CFrame and Size
	area.CFrame, area.Size = cf, size

	local folder = Instance.new("Folder")
	folder.Name = "RoadCandy"
	folder.Parent = workspace

	local function place(candy: Model)
		local hitbox = candy.PrimaryPart :: BasePart
		hitbox.CFrame = CFrame.new(randomRoadCFrame(area).Position)
		candy.Parent = folder
	end

	for _ = 1, COUNT do
		local candy = makeCandy()
		place(candy)
		local taken = false
		;(candy.PrimaryPart :: BasePart).Touched:Connect(function(hit)
			if taken then
				return
			end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local data = player and DataService.Get(player)
			if not data then
				return
			end
			taken = true
			local amount = BASE_CANDY * Config.GetCostume(data.EquippedCostume).CandyMultiplier
			DataService.Update(player :: Player, function(d)
				d.Candy += amount
			end)
			candy.Parent = nil
			task.delay(RESPAWN_SECONDS, function()
				place(candy)
				taken = false
			end)
		end)
	end
end

return RoadCandyService
