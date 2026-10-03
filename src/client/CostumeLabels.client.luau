-- Costume Shop labels: shows WEARING / OWNED instead of the price for costumes this player has.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local shop = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("CostumeShop")
local mannequins = shop:WaitForChild("Mannequins")

local GOLD = Color3.fromRGB(255, 200, 80)
local GREEN = Color3.fromRGB(120, 255, 140)
local LAVENDER = Color3.fromRGB(210, 170, 255)

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function refresh()
	local equipped = player:GetAttribute("CostumeEquipped")
	local owned = {}
	for id in string.gmatch(player:GetAttribute("CostumesOwned") or "", "[^,]+") do
		owned[id] = true
	end
	for _, display in mannequins:GetChildren() do
		local id = display:GetAttribute("Costume")
		local costume = id and Config.GetCostume(id)
		local sign = display:FindFirstChild("InfoSign", true)
		local price = sign and sign:FindFirstChild("PriceLabel", true) :: TextLabel?
		if costume and costume.Id == id and price then
			if equipped == id then
				price.Text, price.TextColor3 = "WEARING", GREEN
			elseif owned[id] then
				price.Text, price.TextColor3 = "OWNED - press E to wear", LAVENDER
			else
				price.Text, price.TextColor3 = fmt(costume.Price) .. " Candy", GOLD
			end
		end
	end
end

player:GetAttributeChangedSignal("CostumeEquipped"):Connect(refresh)
player:GetAttributeChangedSignal("CostumesOwned"):Connect(refresh)
refresh()
