-- Settings-matched collection browser: selectable pets, discoveries and milestone claims.
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local Input=game:GetService("UserInputService")
local Context=game:GetService("ContextActionService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.IndexCatalog)
local BannerArt=require(Shared.IndexBannerArt)
local Remotes=require(Shared.Remotes)
local Style=require(Shared.MenuStyle)
local C=Style.C
local UI={};UI.__index=UI
local ICON="rbxassetid://120727874564424"
local MONEY="rbxassetid://75082286323919"
local CANDY="rbxassetid://87026500785235"
local CHECK="rbxassetid://94577908904911"
local function short(n)
	if n>=1e9 then return string.format("%.1fB",n/1e9) elseif n>=1e6 then return string.format("%.1fM",n/1e6) elseif n>=1000 then return string.format("%.1fK",n/1000) end
	return tostring(math.floor(n))
end
local function text(parent,name,value,size,pos,fontSize,color,min)
	return Style.fit(Style.text(parent,name,value,size,pos,fontSize,color),fontSize,min or 16)
end
local function clear(parent)
	for _,child in parent:GetChildren() do child:Destroy() end
end
local function progress(parent,name)
	local bar=Style.make("Frame",{Name=name,BackgroundColor3=Color3.fromRGB(34,38,60),BorderSizePixel=0,ZIndex=3},parent)
	Style.round(bar,4);Style.stroke(bar,C.Ink,3)
	local fill=Style.make("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=C.Green,BorderSizePixel=0,ZIndex=4},bar)
	Style.round(fill,4);Style.gradient(fill,Color3.new(1,1,1),Color3.fromRGB(155,194,130))
	local label=text(bar,"Count","",UDim2.fromScale(1,1),nil,22,C.White,16);label.TextXAlignment=Enum.TextXAlignment.Center;label.ZIndex=5
	return bar
end
local function paint(button,caption,available,color)
	button:SetAttribute("Available",available)
	button.Active=available;button.Selectable=available;button.Interactable=available
	button.BackgroundColor3=if available then color or C.Green else C.Gray
	button.Caption.Text=caption
	button.Caption.TextColor3=if available then C.White else Color3.fromRGB(220,228,240)
end
function UI:Button(parent,name,caption,fn)
	local button
	button=Style.button(parent,name,caption,UDim2.fromOffset(160,48),UDim2.new(),C.Green,function()
		if button:GetAttribute("Available") and not self.busy then fn() end
	end)
	button:SetAttribute("Available",true)
	return button
end
function UI.new(options)
	local self=setmetatable({options=options,tab="Collection",selected=Catalog.Groups[1].Pets[1],mobileDetail=false,busy=false,cards={},sections={},milestones={},connections={}},UI)
	self.gui=Style.make("ScreenGui",{Name="PetIndexUI",ResetOnSpawn=false,DisplayOrder=14,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.root=Style.make("Frame",{Name="Root",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},self.gui)
	self.overlay=Style.make("TextButton",{Name="Dismiss",Text="",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=0.65,BorderSizePixel=0,AutoButtonColor=false,Selectable=false,Visible=false},self.root)
	self.overlay.Activated:Connect(function()self:Close()end)
	self.panel=Style.make("Frame",{Name="IndexMenu",AnchorPoint=Vector2.one*0.5,Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(1080,690),BackgroundColor3=C.Body,BackgroundTransparency=0.2,BorderSizePixel=0,Visible=false},self.root)
	Style.round(self.panel,5);Style.stroke(self.panel,C.Ink,6);Style.inset(self.panel,Color3.fromRGB(161,149,189),0.2,1);Style.texture(self.panel,0.86,1)
	self.header=Style.make("Frame",{Name="Header",Size=UDim2.new(1,0,0,84),BackgroundColor3=C.White,BorderSizePixel=0,ZIndex=4},self.panel)
	Style.round(self.header,4);Style.stroke(self.header,C.Ink,5);Style.gradient(self.header,Color3.fromRGB(192,199,210),Color3.fromRGB(62,65,76));Style.texture(self.header,0.37,4);Style.inset(self.header,C.White,0.22,5)
	self.icon=Style.icon(self.header,"IndexIcon",ICON,UDim2.fromOffset(72,72),UDim2.fromOffset(9,6),6)
	self.title=text(self.header,"Title","Pet Index",UDim2.new(1,-174,0,68),UDim2.fromOffset(86,6),54,C.White,26);self.title.ZIndex=6
	self.close=self:Button(self.header,"Close","X",function()self:Close()end)
	self.close.BackgroundColor3=Color3.fromRGB(255,36,65);self.close.ZIndex=7
	for _,v in self.close:GetDescendants() do if v:IsA("GuiObject") then v.ZIndex+=3 end end
	self.close.Caption.TextScaled=false;self.close.Caption.TextSize=46
	self.toolbar=Style.make("Frame",{Name="Navigation",BackgroundTransparency=1},self.panel)
	self.collectionTab=self:Button(self.toolbar,"CollectionTab","Collection",function()self:SetTab("Collection")end)
	self.milestoneTab=self:Button(self.toolbar,"MilestonesTab","Milestones",function()self:SetTab("Milestones")end)
	self.back=self:Button(self.toolbar,"BackToCollection","< Collection",function()self.mobileDetail=false;self:Layout();self:RefreshVisible()end)
	self.body=Style.make("Frame",{Name="Body",BackgroundTransparency=1},self.panel)
	self.details=Style.make("Frame",{Name="SelectedPet",BackgroundTransparency=1,ZIndex=3},self.body)
	self.preview=Style.surface(self.details,"PetPreview",UDim2.fromScale(1,0.6),nil,"purple")
	self.preview.StudTexture:Destroy()
	self.previewArt=Style.make("Frame",{Name="Art",BackgroundTransparency=1,ZIndex=3},self.preview)
	self.petName=text(self.preview,"PetName","???",UDim2.new(1,-24,0,44),UDim2.fromOffset(12,12),34,C.White,20)
	self.petName.TextXAlignment=Enum.TextXAlignment.Center
	self.rarity=text(self.preview,"Rarity","",UDim2.new(1,-24,0,24),UDim2.new(),22,C.Gold,16);self.rarity.TextXAlignment=Enum.TextXAlignment.Center
	self.income=text(self.preview,"Income","??? /s",UDim2.new(1,-24,0,26),UDim2.new(),24,C.Green,16);self.income.TextXAlignment=Enum.TextXAlignment.Center
	self.reward=Style.surface(self.details,"DiscoveryReward",UDim2.fromScale(1,0.4),nil,"purple")
	self.rewardTitle=text(self.reward,"Title","Discovery reward",UDim2.new(1,-24,0,30),UDim2.fromOffset(12,8),24,C.Gold,16)
	self.moneyIcon=Style.icon(self.reward,"Money",MONEY,UDim2.fromOffset(40,40),UDim2.new())
	self.candyIcon=Style.icon(self.reward,"Candy",CANDY,UDim2.fromOffset(40,40),UDim2.new())
	self.moneyAmount=text(self.reward,"MoneyAmount","",UDim2.new(),nil,24,C.White,16)
	self.candyAmount=text(self.reward,"CandyAmount","",UDim2.new(),nil,24,C.White,16)
	self.claim=self:Button(self.reward,"ClaimPet","Discover first",function()self:Request("ClaimIndexPet",self.selected)end)
	self.scroll=Style.make("ScrollingFrame",{Name="Collections",BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6,ScrollBarImageColor3=Color3.fromRGB(200,237,255),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ClipsDescendants=true,ZIndex=2},self.body)
	Style.make("UIPadding",{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,13),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,8)},self.scroll)
	Style.make("UIListLayout",{Padding=UDim.new(0,14),SortOrder=Enum.SortOrder.LayoutOrder},self.scroll)
	self.milestoneScroll=Style.make("ScrollingFrame",{Name="MilestoneRewards",BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6,ScrollBarImageColor3=Color3.fromRGB(200,237,255),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ClipsDescendants=true,Size=UDim2.fromScale(1,1),Visible=false,ZIndex=2},self.body)
	Style.make("UIPadding",{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,13),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,8)},self.milestoneScroll)
	Style.make("UIListLayout",{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder},self.milestoneScroll)
	self.footer=Style.make("Frame",{Name="Footer",BackgroundTransparency=1,ZIndex=3},self.panel)
	self.total=text(self.footer,"Collected","0 / 51 Collected",UDim2.new(),nil,26,C.White,17)
	self.all=self:Button(self.footer,"ClaimAll","Claim All (0)",function()self:Request("ClaimAllIndex")end)
	self:Build()
	table.insert(self.connections,self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:Layout();self:ScheduleVisible()end))
	table.insert(self.connections,self.scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()self:ScheduleVisible()end))
	self:Layout()
	return self
end
function UI:Build()
	for order,group in Catalog.Groups do
		local row=Style.surface(self.scroll,"Collection"..group.Id,UDim2.new(1,-2,0,230),nil,"purple");row.LayoutOrder=order
		local title=text(row,"CollectionName",group.Name,UDim2.new(),nil,26,C.Gold,18)
		local grid=Style.make("Frame",{Name="Pets",BackgroundTransparency=1,ZIndex=3},row)
		local layout=Style.make("UIGridLayout",{CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder},grid)
		local banner=Style.surface(row,"AreaBanner",UDim2.new(),nil,"purple")
		banner.BackgroundColor3=group.Color
		banner.UIGradient.Color=ColorSequence.new(group.Color:Lerp(Color3.new(1,1,1),0.32),group.Color:Lerp(C.Ink,0.35))
		local bannerImage=BannerArt[group.Id]
		if bannerImage then
			local artwork=Style.make("ImageLabel",{Name="AreaArtwork",Image=bannerImage,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,ZIndex=3},banner)
			Style.round(artwork,7)
			Style.make("Frame",{Name="TitleShade",Size=UDim2.new(1,0,0,52),BackgroundColor3=C.Ink,BackgroundTransparency=0.5,BorderSizePixel=0,ZIndex=4},banner)
			Style.make("Frame",{Name="CountShade",Size=UDim2.new(1,0,0,34),Position=UDim2.new(0,0,1,-34),BackgroundColor3=C.Ink,BackgroundTransparency=0.4,BorderSizePixel=0,ZIndex=4},banner)
		end
		local bannerTitle=text(banner,"AreaName",group.Name,UDim2.new(1,-12,0,46),UDim2.fromOffset(6,6),26,C.White,18);bannerTitle.TextXAlignment=Enum.TextXAlignment.Center;bannerTitle.ZIndex=5
		local eggArt=Style.make("Frame",{Name="EggArt",Size=UDim2.new(1,-12,1,-88),Position=UDim2.fromOffset(6,50),BackgroundTransparency=1,ZIndex=3},banner)
		local subtitle=text(banner,"SetCount",#group.Pets.." pets",UDim2.new(1,-12,0,28),UDim2.new(0,6,1,-34),20,C.White,16);subtitle.TextXAlignment=Enum.TextXAlignment.Center;subtitle.ZIndex=5
		local bar=progress(row,"CollectionProgress")
		self.sections[order]={Group=group,Row=row,Title=title,Grid=grid,Layout=layout,Banner=banner,EggArt=eggArt,HasBanner=bannerImage~=nil,Bar=bar}
		for n,id in group.Pets do
			local pet=Config.Pets[id];local rarity=Config.Rarities[pet.Rarity]
			local button=Style.make("TextButton",{Name="Pet_"..id,Text="",AutoButtonColor=false,BackgroundColor3=rarity.Color:Lerp(C.White,0.2),BorderSizePixel=0,LayoutOrder=n,ZIndex=3},grid)
			Style.round(button,5);local edge=Style.stroke(button,C.Ink,3)
			Style.gradient(button,Color3.new(1,1,1),Color3.fromRGB(145,158,187));Style.inset(button,C.White,0.35,3)
			button.SelectionImageObject=Style.selection()
			local art=Style.make("Frame",{Name="Art",Size=UDim2.new(1,-8,1,-39),Position=UDim2.fromOffset(4,2),BackgroundTransparency=1,ZIndex=4},button)
			local name=text(button,"PetName","???",UDim2.new(1,-8,0,34),UDim2.new(0,4,1,-37),17,C.White,14);name.TextXAlignment=Enum.TextXAlignment.Center;name.ZIndex=5
			local badge=text(button,"ClaimStatus","!",UDim2.fromOffset(21,22),UDim2.new(1,-25,0,3),20,C.White,18)
			badge.BackgroundTransparency=0;badge.BackgroundColor3=C.Green;badge.TextXAlignment=Enum.TextXAlignment.Center;badge.ZIndex=6;Style.round(badge,4);Style.stroke(badge,C.Ink,2)
			button.Activated:Connect(function()self:Select(id,true)end)
			button.MouseEnter:Connect(function()if self.selected~=id then edge.Color=C.Cyan end end)
			button.MouseLeave:Connect(function()edge.Color=if self.selected==id then C.Gold else C.Ink end)
			self.cards[id]={Button=button,Art=art,Name=name,Badge=badge,Edge=edge}
		end
	end
	for i,reward in Config.IndexRewards do
		local row=Style.surface(self.milestoneScroll,"Milestone"..reward.Count,UDim2.new(1,-2,0,130),nil);row.LayoutOrder=i
		text(row,"Title",reward.Count.." pets discovered",UDim2.new(1,-32,0,32),UDim2.fromOffset(16,8),30,C.White,20)
		Style.icon(row,"Money",MONEY,UDim2.fromOffset(44,44),UDim2.fromOffset(16,48))
		text(row,"Reward","$"..short(reward.Money),UDim2.new(0.5,-50,0,38),UDim2.fromOffset(66,51),28,C.Gold,18)
		local state=text(row,"Progress","",UDim2.new(0.55,-24,0,22),UDim2.fromOffset(16,98),18,C.White,16)
		local claim=self:Button(row,"ClaimMilestone","Claim",function()self:Request("ClaimIndex",reward.Count)end)
		claim.Size=UDim2.fromOffset(152,48);claim.Position=UDim2.new(1,-168,0,60)
		self.milestones[i]={Reward=reward,State=state,Claim=claim}
	end
end
function UI:Layout()
	local bounds=self.root.AbsoluteSize
	local w=math.min(1100,math.max(280,bounds.X-28));local h=math.min(690,math.max(230,bounds.Y-20))
	self.width=w;self.height=h;self.short=h<470;self.mobile=w<900
	local header=if h<320 then 52 elseif self.short then 64 else 84
	self.panel.Size=UDim2.fromOffset(w,h);self.header.Size=UDim2.new(1,0,0,header)
	self.icon.Size=UDim2.fromOffset(header-12,header-12);self.title.Position=UDim2.fromOffset(header+2,6);self.title.Size=UDim2.new(1,-header-90,0,header-14)
	self.title.UITextSizeConstraint.MaxTextSize=if self.short then 38 else 54
	self.close.Size=UDim2.fromOffset(if self.short then 48 else 58,if self.short then 48 else 58)
	self.close.Position=UDim2.new(1,if self.short then -60 else -72,0,if header==52 then 2 elseif self.short then 8 else 13);self.close.Caption.TextSize=if self.short then 38 else 46
	local padding=if self.short then 12 else 20
	self.toolbar.Position=UDim2.fromOffset(padding,header+8);self.toolbar.Size=UDim2.new(1,-padding*2,0,44)
	self.collectionTab.Size=UDim2.fromOffset(if self.mobile then 140 else 166,44);self.collectionTab.Position=UDim2.new()
	self.milestoneTab.Size=UDim2.fromOffset(if self.mobile then 140 else 166,44);self.milestoneTab.Position=UDim2.fromOffset(if self.mobile then 150 else 178,0)
	self.back.Size=UDim2.fromOffset(math.min(w-24,210),44);self.back.Position=UDim2.new()
	self.back.Visible=self.mobile and self.mobileDetail and self.tab=="Collection"
	self.collectionTab.Visible=not self.back.Visible;self.milestoneTab.Visible=not self.back.Visible
	local top=header+60;local bottom=if self.short then 62 else 84
	self.body.Position=UDim2.fromOffset(padding,top);self.body.Size=UDim2.new(1,-padding*2,1,-top-bottom)
	local contentW=w-padding*2;local contentH=h-top-bottom
	local detailW=if self.mobile then contentW else math.clamp(math.floor(contentW*0.285),250,300)
	self.details.Position=UDim2.new();self.details.Size=UDim2.fromOffset(detailW,contentH)
	local collectionW=if self.mobile then contentW else contentW-detailW-18
	self.scroll.Position=if self.mobile then UDim2.new() else UDim2.fromOffset(detailW+18,0);self.scroll.Size=UDim2.fromOffset(collectionW,contentH)
	self.details.Visible=self.tab=="Collection" and (not self.mobile or self.mobileDetail)
	self.scroll.Visible=self.tab=="Collection" and (not self.mobile or not self.mobileDetail)
	self.milestoneScroll.Visible=self.tab=="Milestones"
	self.footer.Position=UDim2.new(0,padding,1,-bottom+8);self.footer.Size=UDim2.new(1,-padding*2,0,bottom-16)
	self.total.Position=UDim2.new();self.total.Size=UDim2.new(0.43,-10,1,0);self.total.UITextSizeConstraint.MaxTextSize=if self.short then 20 else 26
	self.all.Size=UDim2.new(0.57,0,0,if self.short then 44 else 52);self.all.Position=UDim2.new(0.43,0,0.5,if self.short then -22 else -26)
	local horizontal=self.mobile or contentH<390
	if horizontal then
		local artW=math.clamp(math.floor(detailW*0.34),100,200)
		self.preview.Position=UDim2.new();self.preview.Size=UDim2.fromOffset(artW,contentH)
		self.previewArt.Position=UDim2.fromOffset(6,6);self.previewArt.Size=UDim2.new(1,-12,1,-72)
		self.petName.Position=UDim2.new(0,8,1,-68);self.petName.Size=UDim2.new(1,-16,0,40);self.petName.UITextSizeConstraint.MaxTextSize=22
		self.rarity.Position=UDim2.new(0,6,1,-28);self.rarity.Size=UDim2.new(1,-12,0,22);self.rarity.UITextSizeConstraint.MaxTextSize=18
		self.income.Visible=false
		self.reward.Position=UDim2.fromOffset(artW+12,0);self.reward.Size=UDim2.fromOffset(detailW-artW-12,contentH)
		self.rewardTitle.Position=UDim2.fromOffset(10,6);self.rewardTitle.Size=UDim2.new(1,-20,0,26);self.rewardTitle.UITextSizeConstraint.MaxTextSize=22
		local compact=contentH<190
		local rowY=if compact then 34 else 58;local size=if compact then 26 else 40
		local rewardW=detailW-artW-12
		self.moneyIcon.Position=UDim2.fromOffset(8,rowY);self.moneyIcon.Size=UDim2.fromOffset(size,size)
		self.moneyAmount.Position=UDim2.fromOffset(10+size,rowY);self.moneyAmount.Size=if compact then UDim2.fromOffset(rewardW/2-size-14,size) else UDim2.new(1,-size-24,0,size)
		self.candyIcon.Position=if compact then UDim2.fromOffset(rewardW/2+2,rowY) else UDim2.fromOffset(8,rowY+size+2);self.candyIcon.Size=UDim2.fromOffset(size,size)
		self.candyAmount.Position=if compact then UDim2.fromOffset(rewardW/2+size+4,rowY) else UDim2.fromOffset(10+size,rowY+size+2);self.candyAmount.Size=if compact then UDim2.fromOffset(rewardW/2-size-12,size) else UDim2.new(1,-size-24,0,size)
		self.moneyAmount.TextXAlignment=Enum.TextXAlignment.Left;self.candyAmount.TextXAlignment=Enum.TextXAlignment.Left
		self.claim.Size=UDim2.new(1,-20,0,44);self.claim.Position=UDim2.new(0,10,1,-54)
	else
		local previewH=math.floor(contentH*0.61)
		self.preview.Position=UDim2.new();self.preview.Size=UDim2.fromOffset(detailW,previewH)
		self.previewArt.Position=UDim2.fromOffset(10,8);self.previewArt.Size=UDim2.new(1,-20,1,-114)
		self.petName.Position=UDim2.new(0,12,1,-100);self.petName.Size=UDim2.new(1,-24,0,44);self.petName.UITextSizeConstraint.MaxTextSize=34
		self.rarity.Position=UDim2.new(0,12,1,-53);self.rarity.Size=UDim2.new(1,-24,0,24);self.rarity.UITextSizeConstraint.MaxTextSize=22
		self.income.Visible=true;self.income.Position=UDim2.new(0,12,1,-29)
		self.reward.Position=UDim2.fromOffset(0,previewH+14);self.reward.Size=UDim2.fromOffset(detailW,contentH-previewH-14)
		self.rewardTitle.Position=UDim2.fromOffset(12,8);self.rewardTitle.Size=UDim2.new(1,-24,0,30);self.rewardTitle.UITextSizeConstraint.MaxTextSize=24
		self.moneyIcon.Position=UDim2.fromOffset(12,42);self.moneyIcon.Size=UDim2.fromOffset(36,36)
		self.candyIcon.Position=UDim2.fromOffset(detailW/2+4,42);self.candyIcon.Size=UDim2.fromOffset(36,36)
		self.moneyAmount.Position=UDim2.fromOffset(10,80);self.moneyAmount.Size=UDim2.fromOffset(detailW/2-12,26)
		self.candyAmount.Position=UDim2.fromOffset(detailW/2,80);self.candyAmount.Size=UDim2.fromOffset(detailW/2-12,26)
		self.moneyAmount.TextXAlignment=Enum.TextXAlignment.Center;self.candyAmount.TextXAlignment=Enum.TextXAlignment.Center
		self.claim.Size=UDim2.new(1,-24,0,48);self.claim.Position=UDim2.new(0,12,1,-58)
	end
	-- Keep amounts attached to the same center as their reward icon on every layout.
	local rewardW=self.reward.Size.X.Offset
	local compactReward=self.reward.Size.Y.Offset<140
	local artSize=if compactReward then 26 else 44
	local artY=if compactReward then 33 else 42
	local amountY=if compactReward then 48 else 74
	local amountH=if compactReward then 18 else 26
	for i,pair in {{self.moneyIcon,self.moneyAmount},{self.candyIcon,self.candyAmount}} do
		local center=rewardW*(if i==1 then 0.25 else 0.75)
		pair[1].Position=UDim2.fromOffset(center-artSize/2,artY);pair[1].Size=UDim2.fromOffset(artSize,artSize)
		pair[2].Position=UDim2.fromOffset(center-rewardW/4+4,amountY);pair[2].Size=UDim2.fromOffset(rewardW/2-8,amountH)
		pair[2].TextXAlignment=Enum.TextXAlignment.Center;pair[2].ZIndex=5
		pair[2].UITextSizeConstraint.MaxTextSize=if compactReward then 18 else 24
	end
	local rowWidth=collectionW-20
	for _,section in self.sections do
		local bannerW=if self.mobile then 94 else 130
		local gridW=rowWidth-bannerW-40
		local columns=math.max(1,math.min(4,math.floor((gridW+8)/94)))
		local cell=math.floor((gridW-(columns-1)*8)/columns)
		local cellH=if self.short then 80 else math.min(116,cell+18)
		local rows=math.ceil(#section.Group.Pets/columns)
		local gridH=rows*cellH+(rows-1)*8
		local gridTop=if self.short then 30 else 40
		local rowH=math.max(gridH+gridTop+38,bannerW*2+20)
		section.Row.Size=UDim2.new(1,-2,0,rowH)
		section.Title.Position=UDim2.fromOffset(12,4);section.Title.Size=UDim2.fromOffset(gridW,if self.short then 22 else 28)
		section.Grid.Position=UDim2.fromOffset(12,gridTop);section.Grid.Size=UDim2.fromOffset(gridW,gridH)
		section.Layout.CellSize=UDim2.fromOffset(cell,cellH)
		section.Banner.Position=UDim2.new(1,-bannerW-12,0,10);section.Banner.Size=UDim2.fromOffset(bannerW,math.min(rowH-20,bannerW*2))
		section.Bar.Position=UDim2.fromOffset(12,rowH-30);section.Bar.Size=UDim2.fromOffset(gridW,24)
	end
	if self.data then self:Refresh() end
end
function UI:View(model,parent,known)
	if model then
		for _,child in model:GetDescendants() do
			if child:IsA("LuaSourceContainer") or child:IsA("ProximityPrompt") or child:IsA("LayerCollector") or child:IsA("ParticleEmitter") or child:IsA("Beam") or child:IsA("Trail") then child:Destroy()
			elseif child:IsA("BasePart") then child.Anchored=true;child.CanCollide=false;child.CanTouch=false end
		end
	end
	local view=self.options.Viewport(model,parent,{Name="Model",Size=UDim2.fromScale(1,1),ImageColor3=if known then C.White else Color3.new(),ZIndex=4})
	if model and view.CurrentCamera then
		local center,size=model:GetBoundingBox()
		local direction=(view.CurrentCamera.CFrame.Position-center.Position).Unit
		local function fit()
			local bounds=view.AbsoluteSize
			if bounds.Y<=0 or bounds.X<=0 then return end
			local aspect=math.min(1,bounds.X/bounds.Y)
			local distance=size.Magnitude/2/math.tan(math.rad(view.CurrentCamera.FieldOfView/2))/aspect*1.06
			view.CurrentCamera.CFrame=CFrame.lookAt(center.Position+direction*distance,center.Position)
		end
		view:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit);task.defer(function()if view.Parent then fit()end end)
	end
	return view
end
function UI:ScheduleVisible()
	if self.pendingVisible then return end
	self.pendingVisible=true
	task.defer(function()self.pendingVisible=false;if self.gui.Parent then self:RefreshVisible() end end)
end
function UI:RefreshVisible()
	local shown=self.panel.Visible and self.scroll.Visible
	local top=self.scroll.AbsolutePosition.Y-60;local bottom=top+self.scroll.AbsoluteSize.Y+120
	for id,card in self.cards do
		local pos=card.Button.AbsolutePosition.Y;local visible=shown and pos+card.Button.AbsoluteSize.Y>=top and pos<=bottom
		if visible and not card.View then card.View=self:View(self.options.Model(id),card.Art,self.found and self.found[id])
		elseif not visible and card.View then card.View:Destroy();card.View=nil end
	end
	for _,section in self.sections do
		local pos=section.Row.AbsolutePosition.Y;local visible=shown and pos+section.Row.AbsoluteSize.Y>=top and pos<=bottom
		if visible and not section.HasBanner and not section.View then section.View=self:View(self.options.EggModel(section.Group),section.EggArt,true)
		elseif not visible and section.View then section.View:Destroy();section.View=nil end
	end
end
function UI:Refresh()
	if not self.data then return end
	local pets,milestones,count=Catalog.Ready(self.data)
	self.found=Catalog.Discovered(self.data)
	self.total.Text=string.format("%d / %d Collected",count,#Config.PetOrder)
	paint(self.all,if self.busy then "Claiming..." else string.format("Claim All (%d)",#pets+#milestones),not self.busy and #pets+#milestones>0,C.Blue)
	paint(self.collectionTab,"Collection",true,if self.tab=="Collection" then C.Blue else C.Gray)
	paint(self.milestoneTab,"Milestones",true,if self.tab=="Milestones" then C.Blue else C.Gray)
	for id,card in self.cards do
		local known=self.found[id];local claimed=(self.data.IndexPetClaimed or {})[id]
		card.Name.Text=if known then Config.Pets[id].Name else "???"
		card.Badge.Visible=known==true;card.Badge.Text=if claimed then "✓" else "!";card.Badge.BackgroundColor3=if claimed then C.Gray else C.Green
		card.Edge.Color=if self.selected==id then C.Gold else C.Ink
		card.Edge.Thickness=if self.selected==id then 4 else 3
		if card.View then card.View.ImageColor3=if known then C.White else Color3.new() end
	end
	for _,section in self.sections do
		local discovered=0;for _,id in section.Group.Pets do if self.found[id] then discovered+=1 end end
		section.Bar.Fill.Size=UDim2.fromScale(discovered/#section.Group.Pets,1)
		section.Bar.Count.Text=string.format("%d / %d collected",discovered,#section.Group.Pets)
	end
	for _,entry in self.milestones do
		local claimed=table.find(self.data.IndexClaimed or {},entry.Reward.Count)~=nil
		local ready=count>=entry.Reward.Count and not claimed
		entry.State.Text=if claimed then "REWARD CLAIMED" else string.format("%d / %d discovered",math.min(count,entry.Reward.Count),entry.Reward.Count)
		paint(entry.Claim,if claimed then "Claimed" elseif ready then "CLAIM" else "Locked",ready and not self.busy)
	end
	self:RefreshDetail()
end
function UI:RefreshDetail()
	local pet=Config.Pets[self.selected];local known=self.found and self.found[self.selected]
	local claimed=(self.data.IndexPetClaimed or {})[self.selected];local reward=Catalog.Reward(self.selected)
	self.petName.Text=if known then pet.Name else "???"
	self.rarity.Text=pet.Rarity;self.rarity.TextColor3=Config.Rarities[pet.Rarity].Color:Lerp(C.White,0.3)
	self.income.Text=if known then "$"..short(pet.MoneyPerSecond).." /s" else "??? /s"
	self.moneyAmount.Text="$"..short(reward.Money);self.candyAmount.Text=short(reward.Candy)
	paint(self.claim,if self.busy then "Claiming..." elseif claimed then "Claimed" elseif known then "CLAIM!" else "Discover first",known==true and not claimed and not self.busy)
	if self.details.Visible and self.panel.Visible then
		if self.previewId~=self.selected then
			clear(self.previewArt);self.previewView=self:View(self.options.Model(self.selected),self.previewArt,known);self.previewId=self.selected
		elseif self.previewView then self.previewView.ImageColor3=if known then C.White else Color3.new() end
	end
end
function UI:SetData(data)
	self.data=data
	local parts={table.concat(data.Discovered or {},","),table.concat(data.IndexClaimed or {},",")}
	for _,id in Config.PetOrder do if (data.IndexPetClaimed or {})[id] then table.insert(parts,id) end end
	local signature=table.concat(parts,"|")
	if signature~=self.signature then
		self.signature=signature
		if self.panel.Visible then self:Refresh();self:ScheduleVisible() end
	end
end
function UI:Select(id,fromInput)
	self.selected=id
	if fromInput and self.mobile then self.mobileDetail=true;self:Layout() end
	self:Refresh();self:RefreshVisible()
	if fromInput and Input.GamepadEnabled and self.mobile then GuiService.SelectedObject=if self.claim.Selectable then self.claim else self.back end
	if fromInput and self.options.Sfx then self.options.Sfx("Click") end
end
function UI:SetTab(tab)
	self.tab=tab;self.mobileDetail=false;self:Layout();self:RefreshVisible()
	if self.options.Sfx then self.options.Sfx("Click") end
end
function UI:Request(action,arg)
	if self.busy then return end
	self.busy=true;self:Refresh()
	local ok,success,message=pcall(function()return Remotes.Request:InvokeServer(action,arg)end)
	self.busy=false
	self.options.Notify(if ok then message or "" else "Connection interrupted. Please try again.",if ok and success then C.Green else C.Red)
	if self.options.Sfx then self.options.Sfx(if ok and success then "Buy" else "Error") end
	if self.panel.Visible then self:Refresh();self:ScheduleVisible() end
end
function UI:Open()
	if not self.data then return end
	if self.options.CloseOthers then self.options.CloseOthers() end
	self.previousFocus=GuiService.SelectedObject;self.mobileDetail=false
	self.panel.Visible=true;self.overlay.Visible=true
	self:Layout();self:Refresh();self:ScheduleVisible()
	Context:BindAction("ClosePetIndex",function(_,state)
		if state==Enum.UserInputState.Begin then
			if self.mobile and self.mobileDetail then self.mobileDetail=false;self:Layout();self:RefreshVisible();if Input.GamepadEnabled then GuiService.SelectedObject=self.cards[self.selected].Button end
			else self:Close() end
		end
		return Enum.ContextActionResult.Sink
	end,false,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
	if Input.GamepadEnabled then GuiService.SelectedObject=self.collectionTab end
	if self.options.Sfx then self.options.Sfx("Open") end
end
function UI:Close()
	local wasVisible=self.panel.Visible
	self.panel.Visible=false;self.overlay.Visible=false;Context:UnbindAction("ClosePetIndex")
	self:RefreshVisible();clear(self.previewArt);self.previewId=nil;self.previewView=nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.panel) then GuiService.SelectedObject=if self.previousFocus and self.previousFocus.Parent then self.previousFocus else nil end
	if wasVisible and self.options.Sfx then self.options.Sfx("Close") end
end
function UI:Destroy()
	self:Close();for _,connection in self.connections do connection:Disconnect() end;self.gui:Destroy()
end
return UI

