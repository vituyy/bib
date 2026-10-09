-- All collection claims use the loaded server profile; UI never supplies rewards.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.IndexCatalog)
local DataService=require(script.Parent.DataService)
local Service={}

function Service.ClaimPet(player,data,id)
	if type(id)~="string" or not Catalog.Reward(id) then return false,"Choose a pet from the Index" end
	if not Catalog.Discovered(data)[id] then return false,"Discover this pet first" end
	if (data.IndexPetClaimed or {})[id] then return false,"Discovery reward already claimed" end
	local reward=Catalog.Reward(id)
	local granted=false
	local updated=DataService.Update(player,function(d)
		d.IndexPetClaimed=d.IndexPetClaimed or {}
		if d.IndexPetClaimed[id] or not Catalog.Discovered(d)[id] then return end
		d.IndexPetClaimed[id]=true
		d.Money+=reward.Money;d.Candy+=reward.Candy;granted=true
	end)
	if not updated or not granted then return false,"Reward is no longer available" end
	return true,"Discovery reward claimed!"
end

function Service.ClaimAll(player,_data)
	local amount=0
	local updated=DataService.Update(player,function(d)
		local pets,milestones=Catalog.Ready(d)
		d.IndexPetClaimed=d.IndexPetClaimed or {}
		for _,id in pets do
			local reward=Catalog.Reward(id)
			d.IndexPetClaimed[id]=true
			d.Money+=reward.Money;d.Candy+=reward.Candy;amount+=1
		end
		for _,reward in milestones do
			table.insert(d.IndexClaimed,reward.Count)
			d.Money+=reward.Money;amount+=1
		end
	end)
	if not updated then return false,"Your data is still loading" end
	if amount==0 then return false,"No Index rewards are ready" end
	return true,string.format("Claimed %d Index reward%s!",amount,if amount==1 then "" else "s")
end
return Service

