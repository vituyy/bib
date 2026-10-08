-- Settings-matched menus; profile snapshots and authoritative claim requests.
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
local Icons={Money="rbxassetid://75082286323919",Candy="rbxassetid://87026500785235",Xp="rbxassetid://73937136050455",Gift="rbxassetid://139515933174863",Check="rbxassetid://94577908904911",Lock="rbxassetid://116171143100263"}
local Potions={Xp="rbxassetid://118551182065848",Candy="rbxassetid://139782645048834",Money="rbxassetid://124123062976561",Hatch="rbxassetid://115553653261371"}
local function short(n)
	if n>=1e9 then return string.format("%.1fB",n/1e9) elseif n>=1e6 then return string.format("%.1fM",n/1e6) elseif n>=1000 then return string.format("%.1fK",n/1000) end
	return tostring(math.floor(n))
end
local function clock(s)
	s=math.max(0,math.floor(s));return string.format("%02dh %02dm %02ds",s//3600,s%3600//60,s%60)
end
local function text(parent,name,value,size,pos,fontSize,color,minSize)
	return Style.fit(Style.text(parent,name,value,size,pos,fontSize,color),fontSize,minSize or math.min(fontSize,18))
end
local function rewards(parent,reward,y,width,compact)
	local entries={}
	for _,kind in {"Money","Candy","Xp"} do
		if reward[kind] then table.insert(entries,{Icons[kind],(if kind=="Money" then "$" else "")..short(reward[kind])..(if kind=="Xp" then " XP" else "")}) end
	end
	local each=width/math.max(1,#entries)
	for i,e in entries do
		local x=16+(i-1)*each
		local h=if compact then 28 else 32
		Style.icon(parent,"RewardIcon"..i,e[1],UDim2.fromOffset(h,h),UDim2.fromOffset(x,y))
		text(parent,"RewardAmount"..i,e[2],UDim2.fromOffset(each-36,h),UDim2.fromOffset(x+h+4,y),if compact then 19 else 22,C.White,15)
	end
end
function UI.new(options)
	local self=setmetatable({options=options,tab="Daily",shownDay=-1,busy=false},UI)
	self.gui=Style.make("ScreenGui",{Name="QuestAndLoginMenus",ResetOnSpawn=false,DisplayOrder=14,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false},Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.root=Style.make("Frame",{Name="Root",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},self.gui)
	self.overlay=Style.make("TextButton",{Name="Dismiss",Size=UDim2.fromScale(1,1),Text="",BackgroundColor3=Color3.new(),BackgroundTransparency=0.65,BorderSizePixel=0,Visible=false,AutoButtonColor=false,Selectable=false},self.root)
	self.overlay.Activated:Connect(function()self:Close()end)
	self.panel=Style.make("Frame",{Name="Menu",Size=UDim2.fromOffset(900,680),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=C.Body,BackgroundTransparency=0.2,BorderSizePixel=0,Visible=false},self.root)
	Style.round(self.panel,5);Style.stroke(self.panel,C.Ink,6);Style.inset(self.panel,Color3.fromRGB(161,149,189),0.2,1);Style.texture(self.panel,0.86,1)
	self.header=Style.make("Frame",{Name="Header",Size=UDim2.new(1,0,0,84),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=4},self.panel)
	Style.round(self.header,4);Style.stroke(self.header,C.Ink,5);Style.gradient(self.header,Color3.fromRGB(192,199,210),Color3.fromRGB(62,65,76));Style.texture(self.header,0.37,4);Style.inset(self.header,C.White,0.22,5)
	self.headerIcon=Style.icon(self.header,"MenuIcon",Icons.Gift,UDim2.fromOffset(72,72),UDim2.fromOffset(9,6),6)
	self.title=text(self.header,"Title","Daily Quests",UDim2.new(1,-174,0,68),UDim2.fromOffset(86,6),54,C.White,24);self.title.ZIndex=6
	self.close=Style.button(self.header,"Close","X",UDim2.fromOffset(58,58),UDim2.new(1,-72,0,13),Color3.fromRGB(255,36,65),function()self:Close()end)
	self.close.ZIndex=7;for _,v in self.close:GetDescendants() do if v:IsA("GuiObject") then v.ZIndex+=3 end end
	self.close.Caption.UITextSizeConstraint.MaxTextSize=46;self.close.Caption.TextScaled=false;self.close.Caption.TextSize=46
	self.tabs=Style.make("Frame",{Name="Tabs",Size=UDim2.new(1,-44,0,48),Position=UDim2.fromOffset(22,104),BackgroundTransparency=1,ZIndex=2},self.panel)
	self.timer=text(self.panel,"ResetTimer","",UDim2.new(1,-48,0,28),UDim2.fromOffset(24,164),23,C.Gold,16)
	self.list=Style.make("ScrollingFrame",{Name="Content",Size=UDim2.new(1,-44,1,-282),Position=UDim2.fromOffset(22,202),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6,ScrollBarImageColor3=Color3.fromRGB(200,237,255),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y,ClipsDescendants=true,ZIndex=2},self.panel)
	Style.make("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,6)},self.list)
	Style.make("UIListLayout",{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder},self.list)
	self.footer=Style.make("Frame",{Name="Footer",Size=UDim2.new(1,-48,0,52),Position=UDim2.new(0,24,1,-64),BackgroundTransparency=1,ZIndex=3},self.panel)
	self.calendar=Style.hudButton("DailyLoginButton",Style.DailyIcon,1,function()if self.panel.Visible and self.tab=="Login" then self:Close() else self:Open("Login") end end)
	self.badge=text(self.calendar,"AvailableBadge","!",UDim2.fromOffset(20,22),UDim2.new(1,-18,0,1),20,C.White,20)
	self.badge.TextXAlignment=Enum.TextXAlignment.Center;self.badge.BackgroundTransparency=0;self.badge.BackgroundColor3=C.Red;Style.round(self.badge,4);Style.stroke(self.badge,C.Ink,2)
	self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:Layout();if self.panel.Visible then self:Render()end end)
	self:Layout()
	task.spawn(function()while self.gui.Parent do self:Tick();task.wait(1)end end)
	return self
end
function UI:Layout()
	local size=self.root.AbsoluteSize
	local w=math.min(920,math.max(280,size.X-28));local h=math.min(680,math.max(250,size.Y-20))
	self.narrow=w<620;self.short=h<470;self.tiny=h<300;self.width=w;self.height=h
	self.panel.Size=UDim2.fromOffset(w,h)
	local bar=if self.tiny then 52 elseif self.short then 64 else 84
	self.header.Size=UDim2.new(1,0,0,bar)
	self.headerIcon.Size=UDim2.fromOffset(bar-12,bar-12);self.headerIcon.Position=UDim2.fromOffset(9,6)
	self.title.Position=UDim2.fromOffset(bar+2,6);self.title.Size=UDim2.new(1,-(bar+90),0,bar-16)
	self.title.UITextSizeConstraint.MaxTextSize=if self.tiny then 32 elseif self.short then 40 else 54
	self.close.Size=UDim2.fromOffset(if self.short then 48 else 58,if self.short then 48 else 58)
	self.close.Position=UDim2.new(1,if self.short then -60 else -72,0,if self.tiny then 2 elseif self.short then 8 else 13)
	self.close.Caption.TextSize=if self.short then 38 else 46
	local login=self.tab=="Login"
	self.tabs.Visible=not login;self.tabs.Position=UDim2.fromOffset(22,bar+(if self.short then 8 else 18))
	self.tabs.Size=UDim2.new(1,-44,0,if self.short then 44 else 48)
	local timerY=bar+(if login then (if self.short then 8 else 14) else (if self.short then 56 else 80))
	self.timer.Position=UDim2.fromOffset(24,timerY)
	self.timer.Size=UDim2.new(1,-48,0,if self.short then 24 else 28)
	self.timer.UITextSizeConstraint.MaxTextSize=if self.short then 19 else 23
	local top=timerY+(if self.short then 28 else 38);local bottom=if login then 76 elseif self.short then 12 else 52
	self.footer.Visible=login or not self.short
	self.list.Position=UDim2.fromOffset(22,top);self.list.Size=UDim2.new(1,-44,1,-(top+bottom))
	self.footer.Position=UDim2.new(0,24,1,if login then -64 else -42)
	self.footer.Size=UDim2.new(1,-48,0,if login then 52 else 30)
end
function UI:Close()
	self.panel.Visible=false;self.overlay.Visible=false;Context:UnbindAction("CloseQuestLogin")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.panel) then GuiService.SelectedObject=if self.previousFocus and self.previousFocus.Parent then self.previousFocus else nil end
end
function UI:Open(tab)
	if not self.data then return end
	if self.options.CloseOthers then self.options.CloseOthers() end
	self.tab=if tab=="Quests" then "Daily" else tab
	if self.tab=="Login" then self.shownDay=Config.Quests.DayKey(workspace:GetServerTimeNow()) end
	self.previousFocus=GuiService.SelectedObject
	self.overlay.Visible=true;self.panel.Visible=true;self.list.CanvasPosition=Vector2.zero;self:Render()
	Context:BindAction("CloseQuestLogin",function(_,state)if state==Enum.UserInputState.Begin then self:Close()end;return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.ButtonB,Enum.KeyCode.Escape)
	if Input.GamepadEnabled then
		local claim=self.footer:FindFirstChild("ClaimLogin")
		GuiService.SelectedObject=if self.tab=="Login" then (if claim and claim.Selectable then claim else self.close) else self.tabs:FindFirstChild("TabDaily") or self.close
	end
end
function UI:Request(action,arg)
	if self.busy then return end
	self.busy=true;local ok,success,message=pcall(function()return Remotes.Request:InvokeServer(action,arg)end);self.busy=false
	self.options.Notify(if ok then (message or "") else "Connection interrupted. Please try again.",if ok and success then C.Green else C.Red)
	if self.panel.Visible then self:Render()end
end
function UI:Row(name,height,order,kind)
	local f=Style.surface(self.list,name,UDim2.new(1,-1,0,height),nil,kind);f.LayoutOrder=order;return f
end
function UI:Quest(q,index)
	local ready=q.Progress>=q.Target;local small=self.narrow and not self.short;local compact=self.short
	local row=self:Row("Quest"..index,if self.tiny then 108 elseif compact then 136 elseif small then 214 else 170,index,if q.Claimed then "claimed" else nil)
	text(row,"QuestTitle",Config.Quests.Describe(q),UDim2.new(1,-32,0,if self.tiny then 28 elseif compact then 34 else 48),UDim2.fromOffset(16,if compact then 3 else 6),if self.tiny then 26 elseif compact then 30 else 34,C.White,22)
	local status=if q.Claimed then "CLAIMED" elseif ready then "READY TO CLAIM" else string.upper(q.Slot).."  /  ~"..q.Minutes.." MIN"
	text(row,"QuestStatus",status,UDim2.new(1,-32,0,if self.tiny then 16 elseif compact then 18 else 23),UDim2.fromOffset(16,if self.tiny then 31 elseif compact then 38 else 55),if compact then 14 else 16,if ready then C.Gold else C.White,14)
	local progress=Style.make("Frame",{Name="Progress",Size=UDim2.new(1,if compact then -184 elseif small then -32 else -220,0,if self.tiny then 24 elseif compact then 28 else 32),Position=UDim2.fromOffset(16,if self.tiny then 51 elseif compact then 63 else 86),BackgroundColor3=Color3.fromRGB(41,62,87),BorderSizePixel=0,ZIndex=3},row)
	Style.round(progress,4);Style.stroke(progress,C.Ink,3)
	local fill=Style.make("Frame",{Name="Fill",Size=UDim2.fromScale(math.clamp(q.Progress/math.max(1,q.Target),0,1),1),BackgroundColor3=if ready then C.Green else C.Cyan,BorderSizePixel=0,ZIndex=4},progress);Style.round(fill,4);Style.gradient(fill,Color3.new(1,1,1),Color3.fromRGB(159,202,190))
	local counter=text(progress,"ProgressText",Config.Quests.ProgressText(q),UDim2.fromScale(1,1),nil,24,C.White,18);counter.TextXAlignment=Enum.TextXAlignment.Center;counter.ZIndex=5
	rewards(row,q.Reward,if self.tiny then 78 elseif compact then 99 else 130,self.width-(if compact then 216 elseif small then 100 else 260),self.tiny)
	local caption=if q.Claimed then "Claimed" elseif ready then "CLAIM" elseif self.tab=="Daily" and q.Progress<=0 and not q.Rerolled then "Swap" else "In progress"
	local enabled=not q.Claimed and (ready or caption=="Swap")
	Style.button(row,"QuestAction"..index,caption,UDim2.fromOffset(if compact then 128 elseif small then 142 else 164,48),if compact then UDim2.new(1,-144,0,if self.tiny then 48 else 61) elseif small then UDim2.new(1,-158,1,-56) else UDim2.new(1,-180,0,81),if ready then C.Green elseif caption=="Swap" then C.Blue else C.Gray,function()self:Request(if ready then "ClaimQuest" else "RerollQuest",if ready then {List=self.tab,Index=index} else index)end,enabled and not self.busy)
end
function UI:Chest()
	local quests=self.data.Quests;local set=quests[self.tab];local claimed=0
	for _,q in set do if q.Claimed then claimed+=1 end end
	local opened=quests[self.tab.."Chest"]
	local streak=if self.tab=="Daily" then Config.Quests.NextStreak(quests,Config.Quests.DayKey(workspace:GetServerTimeNow())) else 1
	local reward=Config.Quests.ChestReward(set,streak)
	local row=self:Row("CompletionBonus",if self.tiny then 112 elseif self.short then 136 elseif self.narrow then 210 else 150,20,"purple")
	Style.icon(row,"Gift",Icons.Gift,UDim2.fromOffset(64,64),UDim2.fromOffset(10,8))
	text(row,"Title","Complete the set",UDim2.new(1,-106,0,if self.tiny then 32 else 42),UDim2.fromOffset(80,if self.tiny then 4 else 10),if self.tiny then 28 else 32,C.White,20)
	text(row,"Progress",string.format("%d / %d claimed  /  +25%% set bonus",claimed,#set),UDim2.new(1,-106,0,if self.tiny then 22 else 26),UDim2.fromOffset(80,if self.tiny then 40 else 55),if self.tiny then 16 else 18,C.Gold,15)
	rewards(row,reward,if self.tiny then 77 elseif self.short then 95 elseif self.narrow then 94 else 100,self.width-(if self.short then 216 elseif self.narrow then 100 else 260),self.tiny)
	Style.button(row,"ClaimChest",if opened then "Claimed" else "BONUS",UDim2.fromOffset(if self.short then 128 else 164,48),UDim2.new(1,if self.short then -144 else -180,1,-58),if claimed==#set and not opened then C.Green else C.Gray,function()self:Request("ClaimChest",self.tab)end,claimed==#set and not opened and not self.busy)
end
function UI:Goals()
	for i,a in Config.Quests.Achievements do
		local claimed,value,target,ready=Config.Quests.AchievementState(self.data,a)
		local compact=self.short;local small=self.narrow and not compact
		local row=self:Row("Goal"..i,if self.tiny then 108 elseif compact then 136 elseif small then 228 else 174,i,if not target then "claimed" else nil)
		text(row,"Title",a.Title,UDim2.new(1,-32,0,if self.tiny then 28 elseif compact then 34 else 40),UDim2.fromOffset(16,if compact then 3 else 8),if self.tiny then 26 elseif compact then 30 else 34,C.White,22)
		text(row,"Task",if target then string.format(a.Text,target) else "All milestones complete",UDim2.new(1,-32,0,if self.tiny then 20 elseif compact then 24 else 32),UDim2.fromOffset(16,if self.tiny then 31 elseif compact then 38 else 51),if self.tiny then 18 elseif compact then 20 else 22,C.White,18)
		text(row,"Progress",if target then short(value).." / "..short(target) else "COMPLETED",UDim2.new(1,if compact then -184 else -220,0,if self.tiny then 24 elseif compact then 28 else 32),UDim2.fromOffset(16,if self.tiny then 52 elseif compact then 66 else 92),if self.tiny then 20 else 24,C.Gold,18)
		if target then rewards(row,Config.Quests.Reward(self.data,Config.Quests.AchievementMinutes[claimed+1],{Money=0.5,Candy=0.3,Xp=0.2},1),if self.tiny then 78 elseif compact then 99 else 134,self.width-(if compact then 216 elseif small then 100 else 260),self.tiny)end
		Style.button(row,"GoalAction"..i,if ready then "CLAIM" elseif not target then "Complete" else "Locked",UDim2.fromOffset(if compact then 128 else 164,48),if compact then UDim2.new(1,-144,0,if self.tiny then 48 else 62) else UDim2.new(1,-180,if small then 1 else 0,if small then -56 else 84),if ready then C.Green else C.Gray,function()self:Request("ClaimAchievement",a.Id)end,ready and not self.busy)
	end
end
local function rewardInfo(reward)
	local image=if reward.Potion then Potions[reward.Potion] elseif reward.Candy then Icons.Candy else Icons.Money
	local amount=if reward.Potion then reward.Count.."x "..Config.Potions[reward.Potion].Name elseif reward.Money then "$"..short(reward.Money) else short(reward.Candy or 0).." Candy"
	if reward.Potion and reward.Money then amount..="\n+$"..short(reward.Money)end
	return image,amount
end
function UI:Login()
	local login=self.data.LoginRewards;local index,available=Config.LoginRewards.State(login,workspace:GetServerTimeNow())
	local width=self.width-62;local wide=width>=700 and not self.short
	local columns=if wide then 3 elseif width>=540 then 3 else 2
	local tileW=if wide then (width*0.66-24)/3 else (width-(columns-1)*12)/columns
	local gridHeight=if wide then 416 else math.ceil(6/columns)*204+224
	local rowH=if self.tiny then 74 else 112
	local holder=Style.make("Frame",{Name="SevenDayCalendar",Size=UDim2.new(1,-1,0,if self.short then 7*(rowH+12)-12 else gridHeight),BackgroundTransparency=1,ZIndex=2},self.list)
	for i=1,7 do
		local featured=i==7;local current=i==index;local done=i<index or (current and not available)
		local reward=login.Offers[i] or {};local image,amount=rewardInfo(reward)
		local size,pos
		if self.short then size,pos=UDim2.new(1,0,0,rowH),UDim2.fromOffset(0,(i-1)*(rowH+12))
		elseif wide and featured then size,pos=UDim2.fromOffset(width*0.34-12,416),UDim2.fromOffset(width*0.66+12,0)
		elseif featured then size,pos=UDim2.new(1,0,0,212),UDim2.fromOffset(0,math.ceil(6/columns)*204)
		else size,pos=UDim2.fromOffset(tileW,192),UDim2.fromOffset((i-1)%columns*(tileW+12),math.floor((i-1)/columns)*204)end
		local tile=Style.surface(holder,"Day"..i,size,pos,if done then "claimed" elseif featured then "gold" else nil)
		if current and available then local focus=Style.stroke(tile,C.Gold,4);focus.Name="TodayRim"end
		if self.short then
			local art=if self.tiny then 56 else 80
			Style.icon(tile,"RewardArt",if done then Icons.Check else image,UDim2.fromOffset(art,art),UDim2.fromOffset(12,if self.tiny then 9 else 16))
			text(tile,"Day","Day "..i..(if featured then "  /  BONUS" else ""),UDim2.new(1,if self.tiny then -244 else -270,0,if self.tiny then 28 else 35),UDim2.fromOffset(if self.tiny then 78 else 106,if self.tiny then 4 else 8),if self.tiny then 24 else 30,C.White,20)
			text(tile,"Reward",amount,UDim2.new(1,if self.tiny then -244 else -270,0,if self.tiny then 34 else 52),UDim2.fromOffset(if self.tiny then 78 else 106,if self.tiny then 33 else 47),if self.tiny then 20 else 24,C.White,16)
			local state=if done then "CLAIMED" elseif current then "TODAY" else "UPCOMING"
			local tag=text(tile,"State",state,UDim2.fromOffset(130,46),UDim2.new(1,-146,0.5,-23),22,if current and available then C.Gold else C.White,16);tag.TextXAlignment=Enum.TextXAlignment.Center
		else
			local large=featured and wide
			local header=Style.make("Frame",{Name="DayHeader",Size=UDim2.new(1,0,0,38),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=3},tile)
			Style.round(header,5);Style.gradient(header,Color3.fromRGB(177,191,205),Color3.fromRGB(70,82,99));Style.stroke(header,C.Ink,3)
			local day=text(header,"Day","Day "..i..(if featured then "  /  BONUS" else ""),UDim2.new(1,-16,1,-2),UDim2.fromOffset(8,0),if featured then 28 else 26,C.White,18);day.TextXAlignment=Enum.TextXAlignment.Center;day.ZIndex=4
			local artSize=if large then 180 else 82
			Style.icon(tile,"RewardArt",if done then Icons.Check else image,UDim2.fromOffset(artSize,artSize),UDim2.new(0.5,-artSize/2,0,if large then 60 else 46),4)
			local description=text(tile,"Reward",amount,UDim2.new(1,-16,0,if large then 94 else 43),UDim2.new(0,8,0,if large then 251 else 130),if large then 30 else 21,C.White,17);description.TextXAlignment=Enum.TextXAlignment.Center
			local state=if done then "CLAIMED" elseif current then "TODAY'S GIFT" else "UPCOMING"
			local status=text(tile,"State",state,UDim2.new(1,-16,0,26),UDim2.new(0,8,1,-31),18,if current and available then C.Gold else C.White,14);status.TextXAlignment=Enum.TextXAlignment.Center
		end
	end
	local claimW=if self.narrow then 156 else 210
	text(self.footer,"LoginNote",if available then "Your daily gift is ready!" else "Come back tomorrow!",UDim2.new(1,-claimW-16,1,0),nil,26,C.White,16)
	Style.button(self.footer,"ClaimLogin",if available then "CLAIM DAY "..index else "CLAIMED",UDim2.fromOffset(claimW,48),UDim2.new(1,-claimW,0,2),if available then C.Green else C.Gray,function()self:Request("ClaimLogin")end,available and not self.busy)
end
function UI:Render()
	if not self.data or not self.panel.Visible then return end
	self:Layout()
	local selected=GuiService.SelectedObject;local focusName=selected and selected:IsDescendantOf(self.panel) and selected.Name
	for _,container in {self.list,self.tabs,self.footer}do for _,v in container:GetChildren()do if v:IsA("GuiObject")then v:Destroy()end end end
	if self.tab~="Login"then
		for i,name in {"Daily","Weekly","Goals"}do
			local active=self.tab==name
			local b=Style.button(self.tabs,"Tab"..name,name,UDim2.new(1/3,-8,1,0),UDim2.new((i-1)/3,4,0,0),if active then C.Blue else C.Gray,function()self.tab=name;self.list.CanvasPosition=Vector2.zero;self:Render()end)
			if active then Style.stroke(b,C.White,2);b.Caption.TextColor3=C.Gold end
		end
	end
	self.headerIcon.Image=if self.tab=="Login"then Style.DailyIcon else Icons.Gift
	self.title.Text=if self.tab=="Login"then "Daily Rewards"elseif self.tab=="Goals"then "Lifetime Goals"else self.tab.." Quests"
	if self.tab=="Login"then self:Login()elseif self.tab=="Goals"then self:Goals()else for i,q in self.data.Quests[self.tab]do self:Quest(q,i)end;self:Chest()end
	if self.tab~="Login"then text(self.footer,"Hint",if self.tab=="Goals"then "Permanent milestones  /  Claim each tier once"else "Claim the full set to unlock your bonus!",UDim2.fromScale(1,1),nil,20,C.White,16)end
	self:Tick()
	if focusName then
		local target=self.panel:FindFirstChild(focusName,true)
		GuiService.SelectedObject=if target and target:IsA("GuiObject") and target.Selectable then target else self.close
	end
end
function UI:Tick()
	if not self.data then return end
	local now=workspace:GetServerTimeNow();local login=self.data.LoginRewards
	local _,available=Config.LoginRewards.State(login,now);self.badge.Visible=available
	if self.tab=="Login"then self.timer.Text="Resets in "..clock(Config.Quests.SecondsToDaily(now)).."  /  Progress kept if you miss a day"
	elseif self.tab=="Goals"then self.timer.Text="No reset  /  Progress at your own pace"
	else self.timer.Text="New quests in "..clock((if self.tab=="Weekly"then Config.Quests.SecondsToWeekly else Config.Quests.SecondsToDaily)(now))end
	local day=Config.Quests.DayKey(now)
	if available and login.OfferDay==day and self.shownDay~=day and not self.panel.Visible and self.options.CanAutoOpen()then self.shownDay=day;self:Open("Login")end
end
function UI:SetData(data)
	if not data.LoginRewards or not data.Quests then return end
	self.data=data
	local key={tostring(data.LoginRewards.ClaimCount),tostring(data.LoginRewards.LastClaimDay),tostring(data.LoginRewards.OfferDay),tostring(data.Quests.Day),tostring(data.Quests.Week),tostring(data.Quests.DailyChest),tostring(data.Quests.WeeklyChest)}
	for _,name in {"Daily","Weekly"}do for _,q in data.Quests[name]do table.insert(key,q.Id..":"..q.Target..":"..math.floor(q.Progress)..":"..tostring(q.Claimed)..":"..tostring(q.Rerolled))end end
	if self.tab=="Goals"then for _,a in Config.Quests.Achievements do table.insert(key,tostring(Config.Quests.Stat(data,a.Stat))..":"..tostring(data.Achieved[a.Id]))end end
	local sig=table.concat(key,"|");if sig~=self.signature then self.signature=sig;self:Render()end
end
return UI