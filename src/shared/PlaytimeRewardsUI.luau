-- Native playtime gifts in the shared Settings/Daily Rewards style.
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local Input=game:GetService("UserInputService")
local Context=game:GetService("ContextActionService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.Config)
local Remotes=require(Shared.Remotes)
local Style=require(Shared.MenuStyle)
local C=Style.C
local UI={};UI.__index=UI
local Icons={Money="rbxassetid://75082286323919",Candy="rbxassetid://87026500785235",Xp="rbxassetid://73937136050455",Egg="rbxassetid://126163045923521",Check="rbxassetid://94577908904911"}
local Potions={Xp="rbxassetid://118551182065848",Candy="rbxassetid://139782645048834",Money="rbxassetid://124123062976561",Hatch="rbxassetid://75316663864314"}
local function short(n)
 if n>=1e9 then return string.format("%.1fB",n/1e9) elseif n>=1e6 then return string.format("%.1fM",n/1e6) elseif n>=1000 then return string.format("%.1fK",n/1000) end
 return tostring(math.floor(n))
end
local function clock(n)
 n=math.max(0,math.ceil(n));return string.format("%d:%02d",n//60,n%60)
end
local function text(parent,name,value,size,pos,max,min,color)
 local t=Style.fit(Style.text(parent,name,value,size,pos,max,color or C.White),max,min or 16);return t
end
local function paint(button,caption,enabled,color)
 button.Caption.Text=caption;button.BackgroundColor3=if enabled then color or C.Green else C.Gray
 button.Active=enabled;button.Selectable=enabled;button.Interactable=enabled
end
function UI.new(options)
 local self=setmetatable({options=options,cards={},connections={},busy=false,seconds=0,at=os.clock()},UI)
 self.gui=Style.make("ScreenGui",{Name="PlaytimeRewardsUI",ResetOnSpawn=false,DisplayOrder=14,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},Players.LocalPlayer:WaitForChild("PlayerGui"))
 self.root=Style.make("Frame",{Name="Root",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},self.gui)
 self.overlay=Style.make("TextButton",{Name="Dismiss",Text="",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=0.65,BorderSizePixel=0,AutoButtonColor=false,Selectable=false,Visible=false},self.root)
 self.overlay.Activated:Connect(function()self:Close()end)
 self.panel=Style.make("Frame",{Name="PlaytimeMenu",AnchorPoint=Vector2.one*0.5,Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(1000,690),BackgroundColor3=C.Body,BackgroundTransparency=0.2,BorderSizePixel=0,Visible=false},self.root)
 Style.round(self.panel,5);Style.stroke(self.panel,C.Ink,6);Style.inset(self.panel,Color3.fromRGB(161,149,189),0.2,1);Style.texture(self.panel,0.86,1)
 self.header=Style.make("Frame",{Name="Header",Size=UDim2.new(1,0,0,84),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=4},self.panel)
 Style.round(self.header,4);Style.stroke(self.header,C.Ink,5);Style.gradient(self.header,Color3.fromRGB(192,199,210),Color3.fromRGB(62,65,76));Style.texture(self.header,0.37,4);Style.inset(self.header,C.White,0.22,5)
 self.icon=Style.icon(self.header,"GiftIcon","rbxassetid://115753816614274",UDim2.fromOffset(72,72),UDim2.fromOffset(9,6),6)
 self.title=text(self.header,"Title","Playtime Rewards",UDim2.new(1,-174,0,68),UDim2.fromOffset(86,6),50,24);self.title.ZIndex=6
 self.close=Style.button(self.header,"Close","X",UDim2.fromOffset(58,58),UDim2.new(1,-72,0,13),C.Red,function()self:Close()end)
 self.close.ZIndex=7;for _,v in self.close:GetDescendants() do if v:IsA("GuiObject") then v.ZIndex+=3 end end
 self.close.Caption.TextScaled=false;self.close.Caption.TextSize=46
 self.status=text(self.panel,"NextReward","",UDim2.new(),nil,24,16,C.Gold)
 self.list=Style.make("ScrollingFrame",{Name="Gifts",BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6,ScrollBarImageColor3=C.Cyan,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y,ClipsDescendants=true,ZIndex=2},self.panel)
 Style.make("UIPadding",{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,13),PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,8)},self.list)
 self.grid=Style.make("UIGridLayout",{CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder},self.list)
 self.footer=Style.make("Frame",{Name="Footer",BackgroundTransparency=1,ZIndex=3},self.panel)
 self.note=text(self.footer,"Round","",UDim2.new(0.48,-10,1,0),nil,23,15)
 self.all=Style.button(self.footer,"ClaimAll","Claim All (0)",UDim2.new(0.52,0,0,48),UDim2.new(0.48,0,0,0),C.Green,function()self:Claim(true)end)
 for index,reward in Config.Playtime.Rewards do
  local tile=Style.surface(self.list,"Gift"..index,UDim2.fromOffset(220,204),nil,if index==#Config.Playtime.Rewards then "gold" else nil);tile.LayoutOrder=index
  local edge=tile:FindFirstChildOfClass("UIStroke")
  local time=text(tile,"Time",if reward.Minutes==0 then "Welcome Gift" else reward.Minutes.." MIN",UDim2.new(1,-16,0,28),UDim2.fromOffset(8,5),23,16,C.Gold);time.TextXAlignment=Enum.TextXAlignment.Center
  local picture=Style.icon(tile,"RewardIcon","",UDim2.fromOffset(76,76),UDim2.new(0.5,-38,0,36),4)
  local amount=text(tile,"Amount","",UDim2.new(1,-12,0,30),UDim2.fromOffset(6,101),28,18);amount.TextXAlignment=Enum.TextXAlignment.Center;amount.ZIndex=5
  local kind=text(tile,"RewardName","",UDim2.new(1,-12,0,28),UDim2.fromOffset(6,132),20,14);kind.TextXAlignment=Enum.TextXAlignment.Center;kind.ZIndex=5
  local claim=Style.button(tile,"ClaimGift"..index,"",UDim2.new(1,-20,0,44),UDim2.new(0,10,1,-54),C.Green,function()self:Claim(false,index)end)
  self.cards[index]={Tile=tile,Edge=edge,Time=time,Picture=picture,Amount=amount,Kind=kind,Claim=claim,Reward=reward}
 end
 table.insert(self.connections,self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:Layout()end))
 self:Layout()
 task.spawn(function()while self.gui.Parent do if self.panel.Visible then self:Refresh()end;task.wait(0.5)end end)
 return self
end
function UI:Played()
 local active=self.data and self.data.Playtime.Active
 return self.seconds+(if active then math.clamp(os.clock()-self.at,0,6) else 0)
end
function UI:Layout()
 local bounds=self.root.AbsoluteSize
 local w=math.min(1020,math.max(280,bounds.X-28));local h=math.min(690,math.max(230,bounds.Y-20))
 self.short=h<470;local tiny=h<320
 local header=if tiny then 52 elseif self.short then 64 else 84
 self.panel.Size=UDim2.fromOffset(w,h);self.header.Size=UDim2.new(1,0,0,header)
 self.icon.Size=UDim2.fromOffset(header-12,header-12)
 self.title.Position=UDim2.fromOffset(header+2,6);self.title.Size=UDim2.new(1,-header-90,0,header-14);self.title.UITextSizeConstraint.MaxTextSize=if self.short then 36 else 50
 self.close.Size=UDim2.fromOffset(if self.short then 48 else 58,if self.short then 48 else 58);self.close.Position=UDim2.new(1,if self.short then -60 else -72,0,if tiny then 2 elseif self.short then 8 else 13);self.close.Caption.TextSize=if self.short then 38 else 46
 local padding=if self.short then 12 else 20
 local compact=h<360
 self.status.Position=UDim2.fromOffset(padding,header+(if compact then 4 else 8));self.status.Size=UDim2.new(1,-padding*2,0,if compact then 24 else 28)
 local top=header+(if compact then 36 else 46);local bottom=if compact then 58 else 64
 self.list.Position=UDim2.fromOffset(padding,top);self.list.Size=UDim2.new(1,-padding*2,1,-top-bottom)
 self.footer.Position=UDim2.new(0,padding,1,-54);self.footer.Size=UDim2.new(1,-padding*2,0,44)
 self.all.Size=UDim2.new(0.52,0,0,44)
 local width=w-padding*2-18
 local columns=if width>=720 then 4 elseif width>=510 then 3 else 2
 local cellW=math.floor((width-12*(columns-1))/columns);local cellH=if compact then 136 elseif self.short then 168 else 224
 self.grid.CellSize=UDim2.fromOffset(cellW,cellH)
 for _,card in self.cards do
  local art=if self.short then 52 else 80
  card.Picture.Size=UDim2.fromOffset(art,art);card.Picture.Position=UDim2.new(0.5,-art/2,0,if self.short then 29 else 34)
  card.Amount.Position=UDim2.fromOffset(6,if self.short then 69 else 104);card.Amount.Size=UDim2.new(1,-12,0,if self.short then 25 else 30)
  card.Kind.Position=UDim2.fromOffset(6,if self.short then 92 else 136);card.Kind.Size=UDim2.new(1,-12,0,if self.short then 23 else 28)
  card.Time.UITextSizeConstraint.MaxTextSize=if self.short then 19 else 23
  card.Kind.UITextSizeConstraint.MaxTextSize=if self.short then 16 else 20
  card.Claim.Position=UDim2.new(0,10,1,-50)
  card.Amount.Size=UDim2.new(1,-12,0,if self.short then 25 else 30)
  card.Kind.Size=UDim2.new(1,-12,0,if self.short then 23 else 28)
  if compact then
   card.Picture.Size=UDim2.fromOffset(48,48);card.Picture.Position=UDim2.fromOffset(10,29)
   card.Amount.Position=UDim2.fromOffset(4,65);card.Amount.Size=UDim2.fromOffset(64,22)
   card.Amount.UITextSizeConstraint.MaxTextSize=22
   card.Kind.Position=UDim2.fromOffset(70,31);card.Kind.Size=UDim2.new(1,-76,0,46)
  else card.Amount.UITextSizeConstraint.MaxTextSize=28 end
 end
 if self.data then self:Refresh()end
end
function UI:Refresh()
 if not self.data then return end
 local pt=self.data.Playtime;local seconds=self:Played();local ready=0;local nextAt=nil
 for index,card in self.cards do
  local reward=card.Reward;local resolved=Config.Playtime.Resolve(self.data,reward)
  local done=pt.Claimed[tostring(index)]==true;local unlocked=pt.Seconds>=reward.Minutes*60
  if not done then if unlocked then ready+=1 elseif not nextAt then nextAt=reward.Minutes*60 end end
  local name,value,image
  if resolved.EggId then name=Config.Eggs[resolved.EggId].Name;value="x"..resolved.Count;image=Icons.Egg
  elseif resolved.Potion then name=Config.Potions[resolved.Potion].Name;value="x"..resolved.Count;image=Potions[resolved.Potion]
  else name=if resolved.Money then "Money" elseif resolved.Candy then "Candy" else "Speed XP";value=(if resolved.Money then "$" else "+")..short(resolved.Money or resolved.Candy or resolved.Xp or 0);image=Icons[reward.Kind] end
  card.Picture.Image=if done then Icons.Check else image
  if resolved.EggId and not done and self.options.EggModel then
   if card.EggId~=resolved.EggId then
    if card.EggView then card.EggView:Destroy()end
    card.EggId=resolved.EggId
    card.EggView=self.options.Viewport(self.options.EggModel(resolved.EggId),card.Picture,{Name="EggModel",Size=UDim2.fromScale(1,1),ZIndex=4})
   end
   card.Picture.ImageTransparency=1;card.EggView.Visible=true
  else
   card.Picture.ImageTransparency=0
   if card.EggView then card.EggView.Visible=false end
  end
  card.Picture.ImageColor3=if not done and resolved.EggId then Config.Eggs[resolved.EggId].Color:Lerp(C.White,0.4) else C.White
  card.Amount.Text=value;card.Kind.Text=name
  card.Edge.Color=if done then C.Ink elseif unlocked then C.Green elseif index==#self.cards then C.Gold else C.Ink
  paint(card.Claim,if self.busy then "Claiming..." elseif done then "Claimed" elseif unlocked then "CLAIM!" else clock(reward.Minutes*60-seconds),not self.busy and unlocked and not done)
 end
 self.ready=ready
 self.status.Text=if ready>0 then ready.." gift"..(if ready==1 then "" else "s").." ready!" elseif nextAt then "Next gift in "..clock(nextAt-seconds) else "Round complete!"
 if not pt.Active and nextAt and ready==0 then self.status.Text..="  /  Timer paused" end
 self.note.Text="Round "..(pt.Round or 1).."  /  "..clock(seconds).." played"
 paint(self.all,if self.busy then "Claiming..." else "Claim All ("..ready..")",not self.busy and ready>0)
end
function UI:SetData(data)
 if not data.Playtime then return end
 self.data=data;self.seconds=data.Playtime.Seconds;self.at=os.clock()
 if self.panel.Visible then self:Refresh()end
end
function UI:Claim(all,index)
 if self.busy or not self.data then return end
 local targets={}
 if all then
  for i,reward in Config.Playtime.Rewards do if not self.data.Playtime.Claimed[tostring(i)] and self.data.Playtime.Seconds>=reward.Minutes*60 then table.insert(targets,i)end end
 else table.insert(targets,index)end
 if #targets==0 then return end
 self.busy=true;self:Refresh()
 local count=0;local problem=nil
 for position,i in targets do
  -- ShopService validates all menu requests with a 0.15 second limit.
  if position>1 then task.wait(0.18)end
  local ok,success,message=pcall(function()return Remotes.Request:InvokeServer("ClaimPlaytime",i)end)
  if ok and success then count+=1
  else problem=if ok then message or "Reward unavailable" else "Connection interrupted. Please try again.";break end
 end
 self.busy=false;self:Refresh()
 if count>0 and self.options.Sfx then
  self.options.Sfx("PlaytimeClaim",1.12)
  task.delay(0.1,function()if self.gui.Parent then self.options.Sfx("Buy",1.25)end end)
 end
 if problem then self.options.Notify(problem,C.Red);if count==0 and self.options.Sfx then self.options.Sfx("Error")end
 else self.options.Notify(if count==1 then "Gift claimed!" else count.." gifts claimed!",C.Green)end
end
function UI:Open()
 if not self.data then return end
 if self.options.CloseOthers then self.options.CloseOthers()end
 self.previousFocus=GuiService.SelectedObject;self.panel.Visible=true;self.overlay.Visible=true;self:Layout();self:Refresh()
 Context:BindAction("ClosePlaytimeRewards",function(_,state)if state==Enum.UserInputState.Begin then self:Close()end;return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
 if Input.GamepadEnabled then GuiService.SelectedObject=if self.all.Selectable then self.all else self.close end
 if self.options.Sfx then self.options.Sfx("Open")end
end
function UI:Close()
 local shown=self.panel.Visible;self.panel.Visible=false;self.overlay.Visible=false;Context:UnbindAction("ClosePlaytimeRewards")
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.panel) then GuiService.SelectedObject=if self.previousFocus and self.previousFocus.Parent then self.previousFocus else nil end
 if shown and self.options.Sfx then self.options.Sfx("Close")end
end
function UI:Destroy()
 self:Close();for _,connection in self.connections do connection:Disconnect()end;self.gui:Destroy()
end
return UI
