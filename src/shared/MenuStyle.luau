-- Shared materials and top-right navigation for the native-size menus.
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local GuiService=game:GetService("GuiService")
local S={}
S.C={Ink=Color3.fromRGB(12,10,18),White=Color3.fromRGB(255,253,249),Body=Color3.fromRGB(38,20,57),Blue=Color3.fromRGB(80,177,241),Cyan=Color3.fromRGB(105,222,255),Green=Color3.fromRGB(115,244,43),Red=Color3.fromRGB(255,71,112),Gold=Color3.fromRGB(255,229,106),Gray=Color3.fromRGB(110,130,158)}
S.DailyIcon="rbxassetid://106908444381353"
S.Tile="rbxassetid://90900957304274"
function S.make(class,props,parent)
	local v=Instance.new(class);for k,x in props do v[k]=x end;v.Parent=parent;return v
end
function S.round(parent,n) S.make("UICorner",{CornerRadius=UDim.new(0,n or 5)},parent) end
function S.stroke(parent,color,width)
	return S.make("UIStroke",{Color=color or S.C.Ink,Thickness=width or 4,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent)
end
function S.gradient(parent,top,bottom)
	return S.make("UIGradient",{Color=ColorSequence.new(top,bottom),Rotation=90},parent)
end
function S.texture(parent,alpha,z)
	return S.make("ImageLabel",{Name="StudTexture",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=S.Tile,ImageTransparency=alpha or 0.66,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(32,32),ZIndex=z or 2},parent)
end
function S.inset(parent,color,alpha,z)
	local f=S.make("Frame",{Name="InnerRim",Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),BackgroundTransparency=1,ZIndex=z or 2},parent)
	S.round(f,3);S.stroke(f,color or S.C.White,2).Transparency=alpha or 0.2
end
function S.text(parent,name,value,size,pos,fontSize,color)
	local t=S.make("TextLabel",{Name=name,Text=value,Size=size,Position=pos or UDim2.new(),BackgroundTransparency=1,TextColor3=color or S.C.White,Font=Enum.Font.FredokaOne,TextSize=fontSize or 28,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3},parent)
	S.make("UIStroke",{Color=S.C.Ink,Thickness=if (fontSize or 28)>=26 then 2.5 else 1.4,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual},t)
	return t
end
function S.fit(t,maxSize,minSize)
	t.TextScaled=true;S.make("UITextSizeConstraint",{MaxTextSize=maxSize,MinTextSize=minSize or 18},t);return t
end
function S.icon(parent,name,id,size,pos,z)
	return S.make("ImageLabel",{Name=name,Image=id,Size=size,Position=pos or UDim2.new(),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,ZIndex=z or 3},parent)
end
function S.selection()
	local f=S.make("Frame",{Name="FocusRing",Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
	S.round(f,4);S.stroke(f,S.C.Cyan,3);return f
end
function S.button(parent,name,title,size,pos,color,fn,enabled)
	local b=S.make("TextButton",{Name=name,Text="",Size=size,Position=pos,BackgroundColor3=color or S.C.Green,BorderSizePixel=0,AutoButtonColor=false,Active=enabled~=false,Selectable=enabled~=false,ZIndex=4},parent)
	S.round(b,4);local edge=S.stroke(b,S.C.Ink,3)
	S.gradient(b,Color3.new(1,1,1),Color3.fromRGB(164,182,157));S.texture(b,0.68,4);S.inset(b,S.C.White,0.35,5)
	local t=S.fit(S.text(b,"Caption",title,UDim2.new(1,-12,1,-8),UDim2.fromOffset(6,4),32),32,16);t.TextXAlignment=Enum.TextXAlignment.Center;t.ZIndex=6
	b.SelectionImageObject=S.selection()
	local scale=S.make("UIScale",{Scale=1},b);local tween
	local function animate(value)
		if tween then tween:Cancel() end
		tween=TweenService:Create(scale,TweenInfo.new(0.1),{Scale=value});tween:Play()
	end
	local function focus(on) edge.Color=if on and enabled~=false then S.C.Cyan else S.C.Ink end
	b.MouseEnter:Connect(function()focus(true)end);b.MouseLeave:Connect(function()focus(false);animate(1)end)
	b.SelectionGained:Connect(function()focus(true)end);b.SelectionLost:Connect(function()focus(false);animate(1)end)
	b.InputBegan:Connect(function(input)
		if enabled~=false and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA) then animate(0.96) end
	end)
	b.InputEnded:Connect(function()animate(1)end)
	b.Activated:Connect(function()if enabled~=false then fn() end end)
	if enabled==false then t.TextColor3=Color3.fromRGB(221,230,243) end
	return b
end
function S.surface(parent,name,size,pos,kind)
	local f=S.make("Frame",{Name=name,Size=size,Position=pos or UDim2.new(),BackgroundColor3=S.C.White,BorderSizePixel=0,ZIndex=2},parent)
	S.round(f,7);S.stroke(f,S.C.Ink,4)
	local top,bottom=Color3.fromRGB(147,221,255),Color3.fromRGB(58,141,213)
	if kind=="gold" then top,bottom=Color3.fromRGB(255,229,117),Color3.fromRGB(211,138,35)
	elseif kind=="claimed" then top,bottom=Color3.fromRGB(144,172,195),Color3.fromRGB(66,102,136)
	elseif kind=="purple" then top,bottom=Color3.fromRGB(208,173,250),Color3.fromRGB(128,76,182) end
	S.gradient(f,top,bottom);S.texture(f,0.66,2);S.inset(f,Color3.fromRGB(221,246,255),0.05,2)
	return f
end
function S.hudButton(name,id,slot,callback)
	local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui=pg:FindFirstChild("TopRightMenuButtons")
	if not gui then
		gui=S.make("ScreenGui",{Name="TopRightMenuButtons",ResetOnSpawn=false,DisplayOrder=16,IgnoreGuiInset=true,ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
		S.make("Frame",{Name="Root",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
	end
	local b=S.make("ImageButton",{Name=name,Image=id,Size=UDim2.fromOffset(60,60),Position=UDim2.new(1,-12-slot*68,0,4),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,BorderSizePixel=0,ScaleType=Enum.ScaleType.Fit,AutoButtonColor=false,SelectionImageObject=S.selection()},gui.Root)
	local function layout()
		local tv=GuiService:IsTenFootInterface();local bounds=gui.Root.AbsoluteSize
		local side=if tv then math.max(48,math.floor(bounds.X*0.045)) else 12
		local top=if tv then math.max(24,math.floor(bounds.Y*0.035)) else 4
		b.Size=UDim2.fromOffset(if tv then 72 else 60,if tv then 72 else 60)
		b.Position=UDim2.new(1,-side-slot*(if tv then 80 else 68),0,top)
	end
	gui.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout);layout()
	local daily=gui.Root:FindFirstChild("DailyLoginButton");local settings=gui.Root:FindFirstChild("SettingsButton")
	if daily and settings then daily.NextSelectionRight=settings;settings.NextSelectionLeft=daily end
	b.MouseEnter:Connect(function()b.ImageColor3=Color3.fromRGB(210,240,255)end)
	b.MouseLeave:Connect(function()b.ImageColor3=Color3.new(1,1,1)end)
	b.Activated:Connect(callback)
	return b
end
return S