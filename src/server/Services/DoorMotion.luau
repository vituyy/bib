
-- Stable door rig: the closed pose is captured once, mounted parts keep their
-- relative transforms, and a new tween cancels the preceding one.
local Motion={}
local TweenService=game:GetService("TweenService")
local cache=setmetatable({}, {__mode="k"})
function Motion.Get(house,door,owner)
 if cache[door] then return cache[door] end
 local cf,size=door.CFrame,door.Size
 local axes={cf.RightVector,cf.UpVector,-cf.LookVector};local sizes={size.X,size.Y,size.Z}
 local tall=1
 for i=2,3 do if math.abs(axes[i].Y)>math.abs(axes[tall].Y) then tall=i end end
 local thin,wide
 for i=1,3 do if i~=tall then
  if not thin then thin=i elseif sizes[i]<sizes[thin] then wide=thin;thin=i else wide=i end
 end end
 local up=axes[tall].Y<0 and -axes[tall] or axes[tall]
 local inward=axes[thin];local spawnPart=house:FindFirstChild("OwnerSpawn")
 if spawnPart and inward:Dot(spawnPart.Position-cf.Position)<0 then inward=-inward end
 local frame=CFrame.fromMatrix(cf.Position,up:Cross(inward),up,inward)
 local limits={size.X/2,size.Y/2,size.Z/2};limits[thin]+=1.1;limits[tall]-=.5
 local parts={{Part=door,Rel=CFrame.identity,Collide=door.CanCollide}}
 local skip={Structure=true,Yard=true,EggSpots=true,Wall=true,Floor=true}
 for _,d in house:GetDescendants() do
  if d:IsA("BasePart") and d~=door and d.Anchored and not (owner and d:IsDescendantOf(owner)) then
   local mounted=d:IsDescendantOf(door)
   if not mounted and not door:GetAttribute("ExplicitAssembly") then
    local excluded=skip[d.Name] or false;local parent=d.Parent
    while parent and parent~=house and not excluded do excluded=skip[parent.Name] or false;parent=parent.Parent end
    local lp=cf:PointToObjectSpace(d.Position)
    mounted=not excluded and math.abs(lp.X)<=limits[1] and math.abs(lp.Y)<=limits[2] and math.abs(lp.Z)<=limits[3]
   end
   if mounted then table.insert(parts,{Part=d,Rel=cf:ToObjectSpace(d.CFrame),Collide=d.CanCollide}) end
  end
 end
 local setup={Closed=cf,Frame=frame,Width=sizes[wide],Thick=sizes[thin],Inward=inward,Parts=parts,Amount=0,Generation=0}
 cache[door]=setup;return setup
end
function Motion.At(setup,amount)
 local hinge=setup.Frame*CFrame.new(-setup.Width/2,0,0)
 return hinge*CFrame.Angles(0,-math.rad(105)*amount,0)*hinge:Inverse()*setup.Closed
end
local function place(setup,amount)
 setup.Amount=math.clamp(amount,0,1)
 local cf=Motion.At(setup,setup.Amount)
 for _,d in setup.Parts do if d.Part.Parent then d.Part.CFrame=cf*d.Rel end end
end
function Motion.Snap(setup,amount)
 setup.Generation+=1;place(setup,amount)
end
function Motion.Animate(setup,target,duration,style,direction)
 setup.Generation+=1
 local generation,from,t0=setup.Generation,setup.Amount,os.clock()
 while setup.Parts[1].Part.Parent and setup.Generation==generation do
  local a=math.min((os.clock()-t0)/math.max(duration,.001),1)
  place(setup,from+(target-from)*TweenService:GetValue(a,style,direction))
  if a>=1 then return true end
  task.wait()
 end
 return false
end
function Motion.RestoreCollision(setup)
 for _,d in setup.Parts do if d.Part.Parent then d.Part.CanCollide=d.Collide end end
end
return Motion