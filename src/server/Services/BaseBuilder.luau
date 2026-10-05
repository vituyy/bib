-- Classic studded Halloween courtyards. The entrance and treadmill stay fixed;
-- capacity upgrades extend the courtyard backward and hatch upgrades extend the pavilion.
local Config = require(game.ReplicatedStorage.Shared.Config)
local BaseBuilder = {}
local W = 44
local BUILT = {"Structure","Base","PetArea","Incubators","PlayerSpawn","TreadmillSpot","PetSlots"}
local C = {
 Stone=Color3.fromRGB(84,72,103), Floor=Color3.fromRGB(148,137,164),
 Edge=Color3.fromRGB(114,96,138), Wood=Color3.fromRGB(133,77,47),
 Trim=Color3.fromRGB(214,117,56), Orange=Color3.fromRGB(234,125,41),
 Purple=Color3.fromRGB(116,62,157), Roof=Color3.fromRGB(139,80,189),
 Lavender=Color3.fromRGB(204,161,240), Warm=Color3.fromRGB(255,194,88),
 Dark=Color3.fromRGB(51,36,68)
}
function BaseBuilder.Depth(level)
 return Config.BaseDepth + Config.BaseDepthStep * level
end
local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- Sign text for the next upgrade of a kind ("Pets" or "Pads") at the given level: "6 > 9  |  $2,000" or "MAX 18".
function BaseBuilder.UpgradeText(kind: string, level: number): string
	local isPets = kind == "Pets"
	local upgrades = if isPets then Config.PetCapacityUpgrades else Config.HatchPadUpgrades
	local now = if isPets then Config.PetSlotsFor(level) else Config.IncubatorsFor(level)
	local nextUpgrade = upgrades[level + 1]
	if not nextUpgrade then
		return string.format("MAX  %d", now)
	end
	return string.format("%d > %d  |  $%s", now, nextUpgrade.Capacity, fmt(nextUpgrade.Price))
end


local function textFace(board, rows)
 local gui=Instance.new("SurfaceGui")
 gui.Name="SurfaceGui" gui.Face=Enum.NormalId.Front gui.LightInfluence=0
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud gui.PixelsPerStud=50
 local layout=Instance.new("UIListLayout") layout.SortOrder=Enum.SortOrder.LayoutOrder layout.VerticalAlignment=Enum.VerticalAlignment.Center layout.Parent=gui
 for i,row in rows do
  local t=Instance.new("TextLabel") t.Name=row[1] t.Text=row[2]
  t.Size=UDim2.fromScale(1,row[4]) t.BackgroundTransparency=1
  t.Font=Enum.Font.FredokaOne t.TextScaled=true t.TextColor3=row[3]
  t.TextStrokeColor3=C.Dark t.TextStrokeTransparency=.1 t.LayoutOrder=i t.Parent=gui
 end
 gui.Parent=board return gui
end
local function padLayout(n)
 local spots={}
 local function row(xs,z) for _,x in xs do table.insert(spots,Vector2.new(x,z)) end end
 if n==2 then row({-6.2,6.2},6.4)
 elseif n==3 then row({-10.2,0,10.2},6.4)
 elseif n==4 then row({-14.4,-4.8,4.8,14.4},6.4)
 elseif n==5 then row({-14.4,-4.8,4.8,14.4},6.4) row({0},16)
 elseif n==6 then row({-10.2,0,10.2},6.4) row({-10.2,0,10.2},16)
 else row({-14.4,-4.8,4.8,14.4},6.4) row({-10.2,0,10.2},16) end
 return spots,n>=5
end
function BaseBuilder.Build(plot,petCapLevel,padLevel)
 for _,name in BUILT do
  for _,old in plot:GetChildren() do if old.Name==name then old:Destroy() end end
 end
 local origin=assert(plot:GetAttribute("Origin"),"Plot needs Origin")
 local D=BaseBuilder.Depth(petCapLevel)
 local count=Config.IncubatorsFor(padLevel)
 local spots,twoRows=padLayout(count)
 local pavilionDepth=if twoRows then 22 else 12
 local front=D-pavilionDepth
 plot:SetAttribute("PetCapLevel",petCapLevel) plot:SetAttribute("PadLevel",padLevel)
 plot:SetAttribute("BaseDesign","BalancedHalloweenStuds")
 local structure=Instance.new("Model") structure.Name="Structure" structure.Parent=plot
 local function group(name) local m=Instance.new("Model") m.Name=name m.Parent=structure return m end
 local function p(parent,name,size,x,y,z,color,rotation,collide,shape)
  local b=Instance.new("Part") b.Name=name b.Size=size
  b.CFrame=origin*CFrame.new(x,y,z)*(rotation or CFrame.identity)
  b.Color=color b.Material=Enum.Material.Plastic b.Anchored=true
  b.TopSurface=Enum.SurfaceType.Studs b.BottomSurface=Enum.SurfaceType.Inlet
  b.CanCollide=collide~=false b.CanTouch=false
  if shape then b.Shape=shape b.TopSurface=Enum.SurfaceType.Smooth b.BottomSurface=Enum.SurfaceType.Smooth end
  b.Parent=parent return b
 end
 local function block(parent,name,s,x,y,z,color,rot,collide)
  return p(parent,name,Vector3.new(s[1],s[2],s[3]),x,y,z,color,rot,collide)
 end
 local function decor(parent,name,s,x,y,z,color,rot)
  local b=block(parent,name,s,x,y,z,color,rot,false) b.CanQuery=false return b
 end
 local function beam(parent,name,a,b,width,color)
  local mid=(a+b)/2
  local q=decor(parent,name,{width,width,(b-a).Magnitude},mid.X,mid.Y,mid.Z,color)
  q.CFrame=origin*CFrame.lookAt(mid,b) q.TopSurface=Enum.SurfaceType.Smooth
  return q
 end
 local function marker(name,s,x,y,z)
  local b=block(plot,name,s,x,y,z,C.Dark,nil,false)
  b.Transparency=1 b.CanQuery=false return b
 end
 local base=marker("Base",{W,1,D},0,-.4,D/2)
 local roam=math.max(front-5,12)
 marker("PetArea",{W-12,1,roam},0,-.2,3+roam/2)
 marker("PlayerSpawn",{1,1,1},0,4,7)
 marker("TreadmillSpot",{1,1,1},14,1,-14)
 plot.PrimaryPart=base
 -- A soft local fill keeps the courtyard readable at night without extra decorative lamps.
 local fill=marker("CourtyardFill",{W-4,.1,D-4},0,15,D/2)
 fill.Parent=structure
 local light=Instance.new("SurfaceLight") light.Name="SoftCourtyardLight"
 light.Face=Enum.NormalId.Bottom light.Angle=120 light.Range=22 light.Brightness=.3
 light.Color=Color3.fromRGB(223,210,244) light.Shadows=false light.Parent=fill

 local floor=group("Courtyard")
 block(floor,"Foundation",{W,1.4,D},0,-.4,D/2,C.Stone)
 block(floor,"StuddedFloor",{W-2,.25,D-2},0,.18,D/2,C.Floor)
 for _,x in {-21,21} do block(floor,"Border",{1,.4,D},x,.35,D/2,C.Edge) end
 for _,z in {0,D} do block(floor,"Border",{W,.4,1},0,.35,z,C.Edge) end
 -- A quiet central path keeps the pet area visually open.
 block(floor,"EntryRunner",{9,.06,math.max(front-3,10)},0,.34,(front-3)/2,C.Floor:Lerp(C.Lavender,.12))
 for i=1,3 do
  block(floor,"EntranceStep"..i,{10+i*1.1,.3,1.45},0,.35-i*.22,-i*1.28,C.Edge:Lerp(C.Orange,.12))
 end

 local fence=group("GardenFence")
 local function post(x,z)
  block(fence,"StoneFoot",{2.5,.7,2.5},x,.65,z,C.Stone)
  block(fence,"Pillar",{1.65,3.1,1.65},x,2.2,z,C.Edge)
  block(fence,"PillarBand",{1.85,.35,1.85},x,3.4,z,C.Trim)
  block(fence,"PillarCap",{2.15,.5,2.15},x,3.95,z,C.Stone)
 end
 local function rail(a,b)
  local delta=b-a local len=delta.Magnitude
  local mid=(a+b)/2 local rot=CFrame.lookAt(mid,b)
  for _,yy in {1.4,2.9} do
   local r=block(fence,"TimberRail",{.55,.65,len},mid.X,yy,mid.Z,C.Trim)
   r.CFrame=origin*rot*CFrame.new(0,yy-mid.Y,0)
  end
  local number=math.max(1,math.floor(len/2.6))
  for i=1,number do
   local pos=a+delta*(i/(number+1))
   local q=block(fence,"FenceBoard",{.65,2.15,1.3},pos.X,2.1,pos.Z,C.Wood)
   q.CFrame=origin*CFrame.new(pos.X,2.1,pos.Z)*rot.Rotation
  end
 end
 local sideSegments=math.ceil(D/10)
 for _,x in {-21,21} do
  for i=0,sideSegments do
   local z=D*i/sideSegments post(x,z)
   if i>0 then rail(Vector3.new(x,0,D*(i-1)/sideSegments),Vector3.new(x,0,z)) end
  end
 end
 for _,side in {-1,1} do
  post(side*6,0) post(side*13.5,0)
  rail(Vector3.new(side*6,0,0),Vector3.new(side*13.5,0,0))
  rail(Vector3.new(side*13.5,0,0),Vector3.new(side*21,0,0))
 end
 rail(Vector3.new(-21,0,D),Vector3.new(21,0,D))
 local function lantern(parent,x,y,z)
  decor(parent,"LanternFoot",{1.8,.4,1.8},x,y,z,C.Dark)
  local glow=decor(parent,"WarmGlass",{1.1,1.5,1.1},x,y+1,z,C.Warm)
  glow.Material=Enum.Material.Neon
  local l=Instance.new("PointLight") l.Color=C.Warm l.Range=14 l.Brightness=1.05 l.Shadows=false l.Parent=glow
  for _,dx in {-.65,.65} do for _,dz in {-.65,.65} do decor(parent,"LanternBar",{.16,1.7,.16},x+dx,y+1,z+dz,C.Dark) end end
  decor(parent,"LanternRoof",{1.8,.4,1.8},x,y+1.95,z,C.Dark)
  decor(parent,"LanternTop",{.7,.45,.7},x,y+2.3,z,C.Trim)
 end
 lantern(fence,-6,4.3,0) lantern(fence,6,4.3,0)

 local hatch=group("HatchingPavilion")
 block(hatch,"Platform",{38,.9,pavilionDepth},0,.85,D-pavilionDepth/2,C.Stone)
 block(hatch,"Deck",{36.7,.22,pavilionDepth-.8},0,1.4,D-pavilionDepth/2,C.Wood)
 block(hatch,"StageStep",{35,.55,1.5},0,.55,front-.7,C.Trim)
 block(hatch,"StageStep",{35,.4,1.25},0,1,front-.1,C.Wood)
 block(hatch,"BackWall",{36,10.4,.7},0,6.7,D-.7,C.Purple)
 for x=-17,17,2 do
  block(hatch,"WallUpright",{.2,10.4,.2},x,6.7,D-1.12,C.Roof)
 end
 block(hatch,"WallSkirting",{36,.65,1},0,1.85,D-.8,C.Trim)
 block(hatch,"WallCrown",{37,.7,1.3},0,11.7,D-.7,C.Trim)
 -- Three framed diamond-window panels give the rear wall a finished interior.
 for _,x in {-12,0,12} do
  block(hatch,"WindowFrame",{6.2,6,.45},x,7.15,D-1.2,C.Dark)
  block(hatch,"WindowGlass",{5.4,5.25,.15},x,7.15,D-1.47,C.Roof:Lerp(C.Lavender,.38))
  block(hatch,"WindowMullion",{.35,5.4,.2},x,7.15,D-1.6,C.Trim)
  block(hatch,"WindowCrossbar",{5.5,.35,.2},x,7.15,D-1.6,C.Trim)
  for _,s in {-1,1} do
   decor(hatch,"DiamondPane",{1.2,1.2,.12},x+s*1.35,7.15,D-1.75,C.Lavender,CFrame.Angles(0,0,math.rad(45)))
  end
  block(hatch,"WindowSill",{6.7,.45,1},x,4.1,D-1.3,C.Trim)
 end
 for _,x in {-18,18} do
  for _,z in {front+.8,D-1} do
   block(hatch,"PostFoot",{2.1,.65,2.1},x,1.7,z,C.Stone)
   block(hatch,"PorchPost",{1.15,10.1,1.15},x,6.5,z,C.Wood)
   block(hatch,"PostBand",{1.6,.5,1.6},x,3.3,z,C.Trim)
   block(hatch,"PostCapital",{1.75,.7,1.75},x,11.35,z,C.Trim)
  end
  block(hatch,"SideBeam",{1,1,pavilionDepth+.8},x,11.95,D-pavilionDepth/2,C.Trim)
  beam(hatch,"PorchBrace",Vector3.new(x,9.4,front+.8),Vector3.new(x,11.7,front+3.2),.6,C.Trim)
 end
 block(hatch,"FrontHeader",{38,1.1,1.2},0,11.85,front+.4,C.Trim)
 local roofDepth=pavilionDepth+4
 local half=roofDepth/2 local rise=4.6
 local slope=math.atan(rise/half) local length=math.sqrt(half*half+rise*rise)
 local ridgeZ=D-pavilionDepth/2
 for _,side in {-1,1} do
  for col=1,8 do
   local color=C.Roof:Lerp(C.Purple,(col%3)*.09)
   block(hatch,"StuddedRoofPanel",{5,.65,length+.1},-20+(col-.5)*5,12.1+rise/2,ridgeZ+side*half/2,color,CFrame.Angles(side*slope,0,0),false)
  end
  block(hatch,"OrangeEave",{40.6,.65,.8},0,11.95,ridgeZ+side*half,C.Trim,nil,false)
 end
 block(hatch,"RidgeCap",{40.6,.65,.85},0,16.85,ridgeZ,C.Purple,nil,false)
 for _,x in {-19.6,19.6} do
  beam(hatch,"GableTrim",Vector3.new(x,11.9,ridgeZ-half),Vector3.new(x,16.8,ridgeZ),.65,C.Trim)
  beam(hatch,"GableTrim",Vector3.new(x,16.8,ridgeZ),Vector3.new(x,11.9,ridgeZ+half),.65,C.Trim)
 end
 -- Wood plaque and a crooked, entirely native-part witch hat.
 local signZ=front-3.1
 block(hatch,"HatchSignFrame",{25.2,4.5,1},0,12.9,signZ,C.Wood,nil,false)
 for _,x in {-10,10} do block(hatch,"SignBracket",{.5,.5,3.2},x,13,front-1.2,C.Wood,nil,false) end
 local board=block(hatch,"HatchSign",{23.8,3.35,.3},0,13,signZ-.65,C.Purple,nil,false)
 textFace(board,{{"Title","HATCH EGGS",C.Lavender,.78}})
 for _,x in {-11.4,11.4} do for _,y in {11.5,14.4} do decor(hatch,"PlaqueBolt",{.23,.23,.15},x,y,signZ-.9,C.Trim) end end
 local hat=group("WitchHat")
 decor(hat,"Brim",{8,.55,4.4},0,15.45,signZ+.2,C.Dark)
 decor(hat,"PurpleBrim",{7,.3,3.6},0,15.83,signZ+.2,C.Purple)
 for i=0,5 do
  local width=4.8-i*.65
  decor(hat,"CrookedCrown",{width,.85,math.max(1,3.2-i*.4)},i*.22,16.3+i*.73,signZ+.2,C.Purple,CFrame.Angles(0,0,math.rad(-i*3)))
 end
 decor(hat,"HatBand",{4.6,.8,3.4},.05,16.55,signZ+.15,C.Orange)
 decor(hat,"Buckle",{1,.65,.15},.05,16.6,signZ-1.65,C.Warm)
 decor(hat,"BuckleInset",{.5,.35,.16},.05,16.6,signZ-1.74,C.Dark)
 decor(hat,"BentTip",{1.8,.7,1},1.7,20.65,signZ+.2,C.Purple,CFrame.Angles(0,0,math.rad(-25)))
 -- Short bunting only under the pavilion eaves.
 for i=0,9 do
  local x=-16+i*3.55
  local q=Instance.new("WedgePart") q.Name="Bunting"
  q.Size=Vector3.new(.16,1.6,1.7) q.CFrame=origin*CFrame.new(x,10.1,front-.3)*CFrame.Angles(0,math.rad(90),math.rad(180))
  q.Color=if i%2==0 then C.Orange else C.Lavender q.Material=Enum.Material.Plastic
  q.Anchored=true q.CanCollide=false q.CanQuery=false q.Parent=hatch
 end
 lantern(hatch,-18,8.4,front-.7) lantern(hatch,18,8.4,front-.7)

 local pads=Instance.new("Folder") pads.Name="Incubators" pads.Parent=plot
 for i,spot in spots do
  local x,z=spot.X,D-spot.Y
  local color=({C.Orange,C.Roof,C.Lavender})[(i-1)%3+1]
  block(hatch,"PadPlinth",{7.5,.45,7.5},x,1.65,z,C.Dark)
  block(hatch,"PadTrim",{6.8,.3,6.8},x,2.02,z,color)
  local pad=block(pads,"Incubator"..i,{5.9,.42,5.9},x,2.36,z,C.Purple)
  pad:SetAttribute("Index",i)
  local number=block(hatch,"PadNumber",{2.1,.75,.15},x,1.8,z-3.85,C.Dark,nil,false)
  textFace(number,{{"Number",string.format("%02d",i),C.Lavender,.9}})
 end

 local details=group("HalloweenVignettes")
 local function pumpkin(x,z,scale)
  local source=game.ServerStorage.BaseDecorAssets:FindFirstChild("WitchPumpkin")
  assert(source,"Witch house pumpkin template missing")
  local model=source:Clone() model.Name="WitchPumpkin"
  local _,size=model:GetBoundingBox()
  model:ScaleTo(model:GetScale() * (3.4*scale)/size.Y)
  model:PivotTo(origin*CFrame.new(x,.35,z)*CFrame.Angles(0,.2*x,0))
  model.Parent=details
 end
 pumpkin(-17,-2.6,1.2,true)
 pumpkin(-18,front-3,1,true) pumpkin(-15.7,front-2.2,.65,false)
 local function crate(x,z)
  block(details,"Crate",{2.9,2.8,2.9},x,1.75,z,C.Wood,nil,false)
  for _,dx in {-1.2,1.2} do decor(details,"CrateFrame",{.35,2.9,.2},x+dx,1.75,z-1.5,C.Trim) end
  for _,y in {.5,3} do decor(details,"CrateFrame",{2.9,.35,.2},x,y,z-1.5,C.Trim) end
  beam(details,"CrateX",Vector3.new(x-1.2,.5,z-1.62),Vector3.new(x+1.2,3,z-1.62),.3,C.Trim)
  beam(details,"CrateX",Vector3.new(x+1.2,.5,z-1.63),Vector3.new(x-1.2,3,z-1.63),.3,C.Trim)
  for i=1,3 do
   local h=({1.5,2.1,1})[i] local dx=(i-2)*.65
   decor(details,"Candle",{.45,h,.45},x+dx,3.2+h/2,z,C.Warm)
   local flame=p(details,"Flame",Vector3.new(.25,.55,.25),x+dx,3.25+h,z,C.Orange,nil,false,Enum.PartType.Ball)
   flame.Material=Enum.Material.Neon
  end
 end
 crate(-19,front-5.8) crate(21.5,-3.1)
 local function tree(x,z,mirror)
  local stem=Vector3.new(x,.4,z) local top=Vector3.new(x+mirror*.5,9,z+.2)
  beam(details,"BareTrunk",stem,top,.95,C.Wood)
  for _,r in {{4.5,-2.8,7.2,-.7},{6,3,9,1},{7.5,-1.8,11,-.5}} do
   local a=Vector3.new(x+mirror*.3,r[1],z)
   local b=Vector3.new(x+mirror*r[2],r[3],z+r[4])
   beam(details,"BareBranch",a,b,.55,C.Wood)
   beam(details,"Twig",b,b+Vector3.new(mirror*.6,1.3,-.8),.3,C.Wood)
  end
  block(details,"TreeBed",{3.2,.45,4.6},x,.35,z,C.Stone,nil,false)
 end
 tree(-24,D-4,-1) tree(24,D-4,1)
 local function web(x,y,z,r)
  local center=Vector3.new(x,y,z)
  for k=0,5 do
   local angle=math.rad(k*60)
   beam(details,"WebSpoke",center,center+Vector3.new(math.cos(angle)*r,math.sin(angle)*r,0),.045,C.Lavender)
  end
  for _,radius in {r*.35,r*.7,r} do for k=0,5 do
   local a=math.rad(k*60) local b=math.rad((k+1)*60)
   beam(details,"WebThread",center+Vector3.new(math.cos(a)*radius,math.sin(a)*radius,0),center+Vector3.new(math.cos(b)*radius,math.sin(b)*radius,0),.04,C.Lavender)
  end end
 end
 web(-18,4.8,front-1.1,1.75) web(19,2.5,-.6,1.5)
 -- Sparse violet shrubs, kept out of the pets' roaming rectangle.
 for _,where in {{-19,9},{19,9},{-20,D-2},{20,D-2}} do
  for i=1,3 do
   decor(details,"VioletPlant",{.4,1.8,.65},where[1]+(i-2)*.6,1.1,where[2],C.Purple:Lerp(C.Lavender,i*.09),CFrame.Angles(0,0,(i-2)*.45))
  end
 end

 local upgrades=group("EntranceUpgradeBoard")
 for _,x in {8.8,17.2} do block(upgrades,"SignPost",{.75,6.4,.8},x,3.4,-1.1,C.Wood,nil,false) end
 block(upgrades,"SignFrame",{13.3,7.3,.9},13,5.7,-1.3,C.Wood,nil,false)
 local title=block(upgrades,"UpgradeTitle",{12.3,1.35,.22},13,8.5,-1.85,C.Purple,nil,false)
 textFace(title,{{"Title","UPGRADE BASE",C.Warm,.86}})
 for i,kind in {"Pets","Pads"} do
  local level=if kind=="Pets" then petCapLevel else padLevel
  local board=block(upgrades,kind.."UpgradeBoard",{12.3,2.25,.22},13,6.4-(i-1)*2.5,-1.87,C.Dark,nil,false)
  board:SetAttribute("UpgradeKind",kind)
  local list=if kind=="Pets" then Config.PetCapacityUpgrades else Config.HatchPadUpgrades
  local nextUpgrade=list[level+1]
  board:SetAttribute("CanUpgrade",nextUpgrade~=nil)
  board.CanQuery=true
  local gui=Instance.new("SurfaceGui") gui.Name="UpgradeSurface"
  gui.Face=Enum.NormalId.Front gui.LightInfluence=0 gui.Active=true gui.ResetOnSpawn=false
  gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud gui.PixelsPerStud=60 gui.MaxDistance=70
  local function label(name,text,y,height,color)
   local t=Instance.new("TextLabel") t.Name=name t.Text=text
   t.Position=UDim2.fromScale(.025,y) t.Size=UDim2.fromScale(.63,height)
   t.BackgroundTransparency=1 t.Font=Enum.Font.FredokaOne t.TextScaled=true
   t.TextColor3=color t.TextStrokeTransparency=.15 t.TextStrokeColor3=C.Dark t.Parent=gui
  end
  label("Title",if kind=="Pets" then "PET CAPACITY" else "HATCHING PADS",.08,.35,C.Lavender)
  local capacity=if kind=="Pets" then Config.PetSlotsFor(level) else Config.IncubatorsFor(level)
  label("Info",if nextUpgrade then string.format("%d > %d",capacity,nextUpgrade.Capacity) else "MAX "..capacity,.49,.39,C.Warm)
  local button=Instance.new("TextButton") button.Name="BuyButton"
  button.Position=UDim2.fromScale(.69,.12) button.Size=UDim2.fromScale(.285,.76)
  button.BackgroundColor3=if nextUpgrade then Color3.fromRGB(75,202,72) else Color3.fromRGB(101,108,118)
  button.BorderSizePixel=0 button.Font=Enum.Font.FredokaOne button.TextScaled=true
  button.TextColor3=Color3.new(1,1,1) button.TextStrokeColor3=Color3.fromRGB(25,70,28) button.TextStrokeTransparency=.1
  button.Text=if nextUpgrade then "BUY\n$"..fmt(nextUpgrade.Price) else "MAXED"
  button.Active=nextUpgrade~=nil button.AutoButtonColor=nextUpgrade~=nil
  local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(.14,0) corner.Parent=button
  local stroke=Instance.new("UIStroke") stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
  stroke.Color=Color3.fromRGB(28,90,36) stroke.Thickness=3 stroke.Parent=button
  local padding=Instance.new("UIPadding") padding.PaddingLeft=UDim.new(.06,0) padding.PaddingRight=UDim.new(.06,0)
  padding.PaddingTop=UDim.new(.06,0) padding.PaddingBottom=UDim.new(.06,0) padding.Parent=button
  button.Parent=gui gui.Parent=board
 end
 local anchor=decor(hatch,"OwnerNameAnchor",{.2,.2,.2},0,22,front,C.Dark) anchor.Transparency=1
 local owner=Instance.new("BillboardGui") owner.Name="OwnerSign" owner.Adornee=anchor
 owner.Size=UDim2.fromOffset(280,50) owner.MaxDistance=110 owner.Parent=base
 local label=Instance.new("TextLabel") label.Name="Label" label.Size=UDim2.fromScale(1,1)
 label.BackgroundTransparency=1 label.Font=Enum.Font.FredokaOne label.TextSize=26
 label.TextColor3=Color3.new(1,1,1) label.TextStrokeTransparency=0 label.Text="Empty Plot" label.Parent=owner
 return plot
end
return BaseBuilder
