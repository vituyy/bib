-- Shared collection definitions and deterministic discovery rewards.
local Config = require(script.Parent.Config)
local Catalog = {}
local definitions = {
	{Id="Swamp",Name="Swamp",Egg="SwampEgg",Color=Color3.fromRGB(99,191,111),Pets={"BogToad","BlackCat","MushroomImp","CauldronSlime","HexedOwl"}},
	{Id="Pyramid",Name="Pyramid",Egg="PyramidEgg",Color=Color3.fromRGB(239,187,75),Pets={"SandScarab","Camel","CanopicJar","MiniSphinx","AnubisPup"}},
	{Id="Harvest",Name="Harvest",Egg="HarvestEgg",Color=Color3.fromRGB(239,148,68),Pets={"HayMouse","Crow","CiderRaccoon","LanternMoth","StrawGolem"}},
	{Id="Bakery",Name="Bakery",Egg="BakeryEgg",Color=Color3.fromRGB(235,137,180),Pets={"CroissantBat","CupcakeGhost","DonutSpider","GingerbreadZombie"}},
	{Id="Graveyard",Name="Graveyard",Egg="GraveyardEgg",Color=Color3.fromRGB(135,174,180),Pets={"GraveRat","TombTurtle","SkeletonHound","CoffinMimic"}},
	{Id="Castle",Name="Castle",Egg="CastleEgg",Color=Color3.fromRGB(176,112,235),Pets={"GargoyleImp","CandleWraith","NobleBat","DreadWolf"}},
	{Id="Nightfall",Name="Nightfall",Egg="GhostEgg",Color=Color3.fromRGB(103,141,242),Pets={"Bat","Spider","Pumpkling","CandyCorn","VampBat","Zombie","Tralalero","Ghosty","Wraith","TungTung","Werewolf","Bombardiro","BloodBat","LichCat","Ballerina","ShadowClown","HeadlessHorse","PumpkinKing"}},
	{Id="BloodMoon",Name="Blood Moon",Egg="BloodySwampEgg",Color=Color3.fromRGB(230,74,100),Pets={"BloodyHexedOwl","BloodyAnubisPup","BloodyStrawGolem","BloodyGingerbread","BloodyMimic","BloodyWolf"}},
}
Catalog.Groups, Catalog.GroupFor = {}, {}
for _, group in definitions do
	local pets = {}
	for _, id in group.Pets do
		if rawget(Config.Pets,id) and not Catalog.GroupFor[id] then
			table.insert(pets,id); Catalog.GroupFor[id]=group
		end
	end
	group.Pets=pets
	if #pets>0 then table.insert(Catalog.Groups,group) end
end
local extra={Id="Other",Name="Other pets",Egg="CandyEgg",Color=Color3.fromRGB(117,186,230),Pets={}}
for _,id in Config.PetOrder do
	if not Catalog.GroupFor[id] then table.insert(extra.Pets,id);Catalog.GroupFor[id]=extra end
end
if #extra.Pets>0 then table.insert(Catalog.Groups,extra) end

function Catalog.Discovered(data)
	local found={}
	for _,id in data.Discovered or {} do
		if type(id)=="string" then
			local base=Config.SplitPet(id)
			if rawget(Config.Pets,base) then found[base]=true end
		end
	end
	return found
end
function Catalog.Reward(id)
	local pet=rawget(Config.Pets,id)
	if not pet then return nil end
	local rarity=Config.Rarities[pet.Rarity]
	return {Money=math.max(100,math.floor(pet.MoneyPerSecond*60)),Candy=10*(if rarity then rarity.Order else 1)}
end
function Catalog.Ready(data)
	local found=Catalog.Discovered(data)
	local pets,milestones={},{}
	local count=0
	for _,id in Config.PetOrder do
		if found[id] then
			count+=1
			if not (data.IndexPetClaimed or {})[id] then table.insert(pets,id) end
		end
	end
	for _,reward in Config.IndexRewards do
		if count>=reward.Count and not table.find(data.IndexClaimed or {},reward.Count) then table.insert(milestones,reward) end
	end
	return pets,milestones,count
end
return Catalog

