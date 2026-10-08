-- Toy-like settings, using the supplied transparent gear and a reusable stud tile.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Context = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Schema = require(Shared.PlayerSettings)
local Remotes = require(Shared.Remotes)
local MenuStyle = require(Shared.MenuStyle)
local SettingsUI = {}
SettingsUI.__index = SettingsUI
local WHITE = Color3.fromRGB(255,253,249)
local MUTED = Color3.fromRGB(218,232,250)
local INK = Color3.fromRGB(12,10,18)
local CYAN = Color3.fromRGB(105,222,255)
local GREEN = Color3.fromRGB(115,244,43)
local RED = Color3.fromRGB(255,71,112)
local TILE = "rbxassetid://90900957304274"
local function new(class,properties,parent)
	local v=Instance.new(class)
	for k,x in properties do v[k]=x end
	v.Parent=parent
	return v
end
local function round(parent,n) new("UICorner",{CornerRadius=UDim.new(0,n or 5)},parent) end
local function outline(parent,color,width) return new("UIStroke",{Color=color or INK,Thickness=width or 4,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent) end
local function gradient(parent,top,bottom)
	return new("UIGradient",{Color=ColorSequence.new(top,bottom),Rotation=90},parent)
end
local function texture(parent,transparency,z)
	return new("ImageLabel",{Name="StudTexture",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=TILE,ImageTransparency=transparency or 0.55,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(32,32),ZIndex=z or 1},parent)
end
local function inset(parent,color,alpha,z)
	local rim=new("Frame",{Name="InnerRim",Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),BackgroundTransparency=1,ZIndex=z or 2},parent)
	round(rim,3);outline(rim,color or WHITE,2).Transparency=alpha or 0.2
end
local function label(parent,name,value,size,position,fontSize,color)
	local t=new("TextLabel",{Name=name,Text=value,Size=size,Position=position,BackgroundTransparency=1,TextColor3=color or WHITE,Font=Enum.Font.FredokaOne,TextSize=fontSize or 28,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},parent)
	new("UIStroke",{Color=INK,Thickness=if (fontSize or 28)>=26 then 2.5 else 1.4,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual},t)
	return t
end
local function fitText(t,maxSize,minSize)
	t.TextScaled=true
	new("UITextSizeConstraint",{MaxTextSize=maxSize,MinTextSize=minSize or 18},t)
end
local function button(parent,name,title,size,position,callback)
	local b=new("TextButton",{Name=name,Text="",Size=size,Position=position,BackgroundColor3=GREEN,BorderSizePixel=0,AutoButtonColor=false,ZIndex=4},parent)
	round(b,4);local edge=outline(b,INK,3)
	gradient(b,Color3.new(1,1,1),Color3.fromRGB(164,182,157));texture(b,0.68,4);inset(b,WHITE,0.35,5)
	local t=label(b,"Caption",title,UDim2.new(1,-10,1,-6),UDim2.fromOffset(5,2),34);t.TextXAlignment=Enum.TextXAlignment.Center;t.ZIndex=6;fitText(t,34,18)
	local scale=new("UIScale",{Scale=1},b)
	local tween
	local function animate(value)
		if tween then tween:Cancel() end
		tween=TweenService:Create(scale,TweenInfo.new(0.1),{Scale=value});tween:Play()
	end
	b.MouseEnter:Connect(function() edge.Color=CYAN end)
	b.MouseLeave:Connect(function() edge.Color=INK;animate(1) end)
	b.SelectionGained:Connect(function() edge.Color=CYAN end)
	b.SelectionLost:Connect(function() edge.Color=INK;animate(1) end)
	b.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA then animate(0.96) end
	end)
	b.InputEnded:Connect(function() animate(1) end)
	b.Activated:Connect(callback)
	return b
end
function SettingsUI.new(options)
	local self=setmetatable({options=options,values=Schema.Normalize(nil),controls={},version=0,dirty=false,loaded=false},SettingsUI)
	local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui=new("ScreenGui",{Name="PlayerSettingsUI",DisplayOrder=15,ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
	self.root=new("Frame",{Name="Root",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},self.gui)
	self.gear=MenuStyle.hudButton("SettingsButton",options.Icon,0,function() if self.panel.Visible then self:Close() else self:Open() end end)
	self.overlay=new("TextButton",{Name="Dimmer",Text="",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=0.65,AutoButtonColor=false,Visible=false,Selectable=false,BorderSizePixel=0},self.root)
	self.overlay.Activated:Connect(function() self:Close() end)
	self.panel=new("Frame",{Name="SettingsPanel",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(680,650),BackgroundColor3=Color3.fromRGB(38,20,57),BackgroundTransparency=0.2,BorderSizePixel=0,Visible=false},self.root)
	round(self.panel,5);outline(self.panel,INK,6);inset(self.panel,Color3.fromRGB(161,149,189),0.2,1);texture(self.panel,0.86,1)
	local header=new("Frame",{Name="Header",Size=UDim2.new(1,0,0,84),BackgroundColor3=WHITE,BorderSizePixel=0,ZIndex=4},self.panel)
	round(header,4);outline(header,INK,5);gradient(header,Color3.fromRGB(192,199,210),Color3.fromRGB(62,65,76));texture(header,0.37,4);inset(header,WHITE,0.22,5)
	new("ImageLabel",{Name="Gear",Image=options.Icon,Size=UDim2.fromOffset(72,72),Position=UDim2.fromOffset(9,6),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,ZIndex=6},header)
	local title=label(header,"Title","Settings",UDim2.new(1,-174,0,68),UDim2.fromOffset(86,8),54);title.ZIndex=6;fitText(title,54,26)
	self.close=button(header,"Close","X",UDim2.fromOffset(58,58),UDim2.new(1,-72,0,13),function() self:Close() end)
	self.close.BackgroundColor3=Color3.fromRGB(255,36,65);self.close.ZIndex=7
	for _,v in self.close:GetDescendants() do if v:IsA("GuiObject") then v.ZIndex+=3 end end
	self.close.Caption.UITextSizeConstraint.MaxTextSize=46;self.close.Caption.TextScaled=false;self.close.Caption.TextSize=46
	self.list=new("ScrollingFrame",{Name="Controls",Position=UDim2.fromOffset(22,104),Size=UDim2.new(1,-44,1,-174),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=6,ScrollBarImageColor3=Color3.fromRGB(200,237,255),ZIndex=2},self.panel)
	new("UIListLayout",{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder},self.list)
	new("UIPadding",{PaddingRight=UDim.new(0,12),PaddingLeft=UDim.new(0,4),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,6)},self.list)
	self:Slider("MusicVolume","Music",1)
	self:Slider("SfxVolume","Sound effects",2)
	self:Toggle("ShowGains","Reward popups","+Candy and +XP",3)
	self:Toggle("EventEffects","Event effects","Embers and timer animation",4)
	self.status=label(self.panel,"Status","Loading...",UDim2.new(1,-220,0,44),UDim2.new(0,24,1,-56),15,MUTED)
	self.reset=button(self.panel,"ResetDefaults","Reset",UDim2.fromOffset(156,44),UDim2.new(1,-180,1,-56),function()
		if not self.loaded then return end
		self.values=Schema.Normalize(nil);self:Changed()
	end)
	self.reset.BackgroundColor3=Color3.fromRGB(67,190,255)
	Input.InputBegan:Connect(function(input)
		if not self.panel.Visible then return end
		local key=input.KeyCode
		if key~=Enum.KeyCode.Left and key~=Enum.KeyCode.Right and key~=Enum.KeyCode.DPadLeft and key~=Enum.KeyCode.DPadRight then return end
		for name,control in self.controls do
			if control.track and GuiService.SelectedObject==control.track then
				self:Set(name,self.values[name]+(if key==Enum.KeyCode.Left or key==Enum.KeyCode.DPadLeft then -0.05 else 0.05))
			end
		end
	end)
	Input.InputChanged:Connect(function(input)
		if self.drag and (input==self.drag.input or input.UserInputType==Enum.UserInputType.MouseMovement and self.drag.mouse) then self:Slide(self.drag.key,input.Position.X) end
	end)
	Input.InputEnded:Connect(function(input)
		if self.drag and (input==self.drag.input or input.UserInputType==Enum.UserInputType.MouseButton1 and self.drag.mouse) then self.drag=nil;self.list.ScrollingEnabled=true end
	end)
	self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end)
	self:Layout();self:Refresh()
	return self
end
function SettingsUI:Layout()
	local sz=self.root.AbsoluteSize
	self.panel.Size=UDim2.fromOffset(math.min(680,math.max(280,sz.X-28)),math.min(650,math.max(250,sz.Y-20)))
	local compact=self.panel.AbsoluteSize.X<440
	local short=self.panel.AbsoluteSize.Y<470
	local tiny=self.panel.AbsoluteSize.Y<300
	local header=self.panel.Header
	header.Size=UDim2.new(1,0,0,if tiny then 52 elseif short then 64 else 84)
	header.Gear.Size=UDim2.fromOffset(if tiny then 40 elseif short then 52 else 72,if tiny then 40 elseif short then 52 else 72)
	header.Title.Position=UDim2.fromOffset(if tiny then 56 elseif short then 68 else 86,6)
	header.Title.Size=UDim2.new(1,if tiny then -134 elseif short then -146 else -174,0,if tiny then 40 elseif short then 52 else 68)
	header.Title.UITextSizeConstraint.MaxTextSize=if tiny then 34 elseif short then 44 else 54
	self.close.Size=UDim2.fromOffset(if short then 48 else 58,if short then 48 else 58)
	self.close.Position=UDim2.new(1,if short then -60 else -72,0,if tiny then 2 elseif short then 8 else 13)
	self.close.Caption.TextSize=if short then 38 else 46
	self.list.Position=UDim2.fromOffset(22,if tiny then 70 elseif short then 82 else 104)
	self.list.Size=UDim2.new(1,-44,1,if tiny then -134 elseif short then -152 else -174)
	for _,control in self.controls do
		if control.button then
			control.button.Size=UDim2.fromOffset(if compact then 86 else 144,52)
			control.button.Position=UDim2.new(1,if compact then -98 else -158,0.5,-26)
			control.title.Size=UDim2.new(1,if compact then -126 else -186,0,42)
			control.hint.Size=UDim2.new(1,if compact then -126 else -186,0,27)
		end
	end
	self.status.Size=UDim2.new(1,if compact then -158 else -220,0,44)
	self.reset.Size=UDim2.fromOffset(if compact then 110 else 156,44)
	self.reset.Position=UDim2.new(1,if compact then -134 else -180,1,-56)
end
function SettingsUI:Row(key,height,order)
	local f=new("Frame",{Name=key,Size=UDim2.new(1,-1,0,height),BackgroundColor3=WHITE,BorderSizePixel=0,LayoutOrder=order,ZIndex=2},self.list)
	round(f,7);outline(f,INK,4);gradient(f,Color3.fromRGB(147,221,255),Color3.fromRGB(58,141,213));texture(f,0.66,2);inset(f,Color3.fromRGB(221,246,255),0.05,2)
	return f
end
function SettingsUI:Slider(key,title,order)
	local row=self:Row(key,116,order)
	local titleLabel=label(row,"Label",title,UDim2.new(1,-128,0,44),UDim2.fromOffset(16,6),38);fitText(titleLabel,38,20)
	local value=label(row,"Value","100%",UDim2.fromOffset(98,44),UDim2.new(1,-114,0,6),28,Color3.fromRGB(255,229,106));value.TextXAlignment=Enum.TextXAlignment.Right;fitText(value,28,20)
	local minus=button(row,"Decrease","-",UDim2.fromOffset(46,46),UDim2.fromOffset(14,58),function() self:Set(key,self.values[key]-0.1) end)
	local plus=button(row,"Increase","+",UDim2.fromOffset(46,46),UDim2.new(1,-60,0,58),function() self:Set(key,self.values[key]+0.1) end)
	minus.BackgroundColor3=Color3.fromRGB(100,197,255);plus.BackgroundColor3=Color3.fromRGB(100,197,255)
	local track=new("TextButton",{Name="Slider",Text="",Size=UDim2.new(1,-164,0,48),Position=UDim2.fromOffset(82,57),BackgroundTransparency=1,AutoButtonColor=false,Selectable=true,ZIndex=4},row)
	local rail=new("Frame",{Name="Rail",Size=UDim2.new(1,0,0,22),Position=UDim2.new(0,0,0.5,-11),BackgroundColor3=Color3.fromRGB(41,62,87),BorderSizePixel=0,ZIndex=4},track);round(rail,4);outline(rail,INK,3)
	local fill=new("Frame",{Name="Fill",Size=UDim2.fromScale(1,1),BackgroundColor3=GREEN,BorderSizePixel=0,ZIndex=5},rail);round(fill,4);gradient(fill,Color3.new(1,1,1),Color3.fromRGB(159,202,120))
	local knob=new("Frame",{Name="Thumb",Size=UDim2.fromOffset(25,36),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(1,0.5),BackgroundColor3=WHITE,BorderSizePixel=0,ZIndex=6},rail);round(knob,4);outline(knob,INK,3);gradient(knob,Color3.new(1,1,1),Color3.fromRGB(170,213,237))
	new("Frame",{Name="Grip",Size=UDim2.fromOffset(3,17),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=Color3.fromRGB(83,118,150),BorderSizePixel=0,ZIndex=7},knob)
	track.NextSelectionLeft=track; track.NextSelectionRight=track
	track.InputBegan:Connect(function(input)
		if not self.loaded then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			self.drag={key=key,input=input,mouse=input.UserInputType==Enum.UserInputType.MouseButton1}; self.list.ScrollingEnabled=false;self:Slide(key,input.Position.X)
		end
	end)
	track.SelectionGained:Connect(function() knob.BackgroundColor3=CYAN end)
	track.SelectionLost:Connect(function() knob.BackgroundColor3=WHITE end)
	self.controls[key]={value=value,fill=fill,knob=knob,track=track,minus=minus,plus=plus}
end
function SettingsUI:Toggle(key,title,description,order)
	local row=self:Row(key,94,order)
	local titleLabel=label(row,"Label",title,UDim2.new(1,-186,0,42),UDim2.fromOffset(16,8),38);fitText(titleLabel,38,18)
	local hint=label(row,"Hint",description,UDim2.new(1,-186,0,27),UDim2.fromOffset(16,51),16,MUTED);fitText(hint,16,13)
	local b=button(row,"Toggle","ON",UDim2.fromOffset(144,52),UDim2.new(1,-158,0.5,-26),function() self:Set(key,not self.values[key]) end)
	self.controls[key]={button=b,title=titleLabel,hint=hint}
end
function SettingsUI:Slide(key,x)
	local track=self.controls[key].track
	self:Set(key,math.floor(math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)*100+0.5)/100)
end
function SettingsUI:Set(key,value)
	if not self.loaded then return end
	if type(value)=="number" then value=math.floor(math.clamp(value,0,1)*100+0.5)/100 end
	if self.values[key]==value then return end
	self.values[key]=value;self:Changed()
end
function SettingsUI:Changed()
	self.version+=1;self.dirty=true
	self.options.Apply(self.values);self:Refresh()
	self.status.Text="Saving..."
	local version=self.version
	task.delay(0.6,function() if self.version==version then self:Flush() end end)
end
function SettingsUI:Flush()
	if self.sending or not self.dirty then return end
	self.sending=true
	local version=self.version;local values=table.clone(self.values)
	local success=false
	for attempt=1,3 do
		local ok,result=pcall(function() return Remotes.Request:InvokeServer("SetSettings",values) end)
		if ok and result then success=true;break end
		task.wait(attempt*0.4)
	end
	self.sending=false
	if version~=self.version then self:Flush();return end
	self.dirty=not success
	self.status.Text=if success then "Saved" else "Close to retry saving"
end
function SettingsUI:Refresh()
	for key,control in self.controls do
		local v=self.values[key]
		if control.track then
			control.value.Text=if v==0 then "Muted" else math.floor(v*100+0.5).."%"
			control.fill.Size=UDim2.fromScale(v,1);control.knob.Position=UDim2.fromScale(v,0.5)
		else
			control.button.Caption.Text=if v then "ON" else "OFF"
			control.button.BackgroundColor3=if v then GREEN else RED
		end
	end
end
function SettingsUI:SetData(data)
	if self.dirty then return end
	self.loaded=true;self.values=Schema.Normalize(data.Settings)
	self.options.Apply(self.values);self:Refresh();self.status.Text="Changes save automatically"
end
function SettingsUI:Open()
	self.options.CloseOthers()
	self.previousFocus=GuiService.SelectedObject
	self.panel.Visible=true;self.overlay.Visible=true;self.gear.Visible=true
	self.gui:SetAttribute("Open",true)
	Context:BindAction("SettingsBack",function(_,state)
		if state==Enum.UserInputState.Begin then self:Close() end
		return Enum.ContextActionResult.Sink
	end,false,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)

	if Input.GamepadEnabled then GuiService.SelectedObject=self.controls.MusicVolume.track end
end
function SettingsUI:Close()
	self.panel.Visible=false;self.overlay.Visible=false;self.gear.Visible=true;self.drag=nil;self.list.ScrollingEnabled=true
	self.gui:SetAttribute("Open",false)
	Context:UnbindAction("SettingsBack");Context:UnbindAction("SettingsAdjust")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.panel) then
		GuiService.SelectedObject=if self.previousFocus and self.previousFocus.Parent then self.previousFocus else nil
	end
	if self.dirty then task.spawn(function() self:Flush() end) end
end
return SettingsUI