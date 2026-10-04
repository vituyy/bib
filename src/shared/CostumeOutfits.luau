-- Costume looks made from real Roblox Marketplace items. Each costume is a full avatar look: a bundle's official
-- outfit (body parts, clothing, hats) plus an optional head and extra accessories. The server applies it with
-- Humanoid:ApplyDescription, so it replaces the player's whole avatar, and restores their own look afterwards.
--   Outfit: the UserOutfit id of the bundle (Players:GetHumanoidDescriptionFromOutfitId)
--   Head: a head asset to use instead of the outfit's head
--   Accessories: { AssetId, AccessoryType, IsLayered }
--   BodyColor: every body part this colour (for looks that start from a plain body)

local Players = game:GetService("Players")

local AT = Enum.AccessoryType

local CostumeOutfits = {}

CostumeOutfits.Looks = {
	-- Plain body under "Sheet Ghost Costume [Fits all bodies]"
	Ghost = { Accessories = { { 107086871629651, AT.Jacket, true } }, BodyColor = Color3.fromRGB(245, 245, 250) },
	-- Roblox "Pumpkin Reaper" bundle (368)
	Pumpkin = { Outfit = 342230531 },
	-- Roblox "Halloween Witch" bundle (203) with the "Grinning Witch Face" dynamic head
	Witch = { Outfit = 131929451, Head = 132963385492213 },
	-- Roblox "Vampire" bundle (293) with the "Vampire" dynamic head
	Vampire = { Outfit = 131929557, Head = 125927789751863 },
	-- "Classic Skeleton" bundle
	Skeleton = { Outfit = 4004053220946277 },
	-- Roblox "Werewolf" bundle (292) with the "Dynamic Werewolf Head"
	Werewolf = { Outfit = 131929556, Head = 74783776939913 },
	-- "Classic Skeleton" body in a "Grim Reaper Hooded Robe"
	Reaper = { Outfit = 4004053220946277, Accessories = { { 135336389839889, AT.Jacket, true } } },
	-- Roblox "Mummy" bundle (294) with the "Mummy Bandage Head" hat
	Mummy = { Outfit = 131929558, Accessories = { { 126404210003432, AT.Hat, false } } },
	-- Roblox "Frankenstein" bundle (263) with the "Frankenstein Head" hat
	Frankenstein = { Outfit = 131929525, Accessories = { { 126285675150620, AT.Hat, false } } },
	-- "Demon" bundle
	Devil = { Outfit = 1527778570665434 },
}

function CostumeOutfits.Has(id: string): boolean
	return CostumeOutfits.Looks[id] ~= nil
end

local cache: { [string]: HumanoidDescription } = {}

-- A fresh HumanoidDescription for this costume (server only; yields while it loads). nil if it can't load.
function CostumeOutfits.Description(id: string): HumanoidDescription?
	local look = CostumeOutfits.Looks[id]
	if not look then
		return nil
	end
	if cache[id] then
		return cache[id]:Clone()
	end
	local ok, desc = pcall(function()
		local d = if look.Outfit then Players:GetHumanoidDescriptionFromOutfitId(look.Outfit) else Instance.new("HumanoidDescription")
		if look.BodyColor then
			for _, key in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
				(d :: any)[key] = look.BodyColor
			end
		end
		if look.Head then
			d.Head = look.Head
		end
		if look.Accessories then
			local list = d:GetAccessories(true)
			for i, a in look.Accessories do
				table.insert(list, { AssetId = a[1], AccessoryType = a[2], IsLayered = a[3], Order = if a[3] then 10 + i else nil })
			end
			d:SetAccessories(list, true)
		end
		return d
	end)
	if not ok then
		warn("[CostumeOutfits] could not load", id, desc)
		return nil
	end
	cache[id] = desc
	return desc:Clone()
end

return CostumeOutfits
