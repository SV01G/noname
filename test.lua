--[[
    NullLib v2 - Proper Roblox UI Library
    Inspired by Linoria/BBot/Vaderhaack architecture
    
    Key patterns sourced from:
    - violin-suzutsuki/LinoriaLib (Inori, Wally, Stefanuk)
    - Proper Registry system for theme updates
    - Real pixel-border flat style (no rounded corners on main boxes)
    - Toggles + Options globals accessible via getgenv()
    - GroupBox system (left/right column layout)
    - Dependency boxes
    - Proper color picker attached to toggles/options
    - SaveManager + ThemeManager compatible structure
    
    Usage:
    local Toggles, Options = getgenv().Toggles, getgenv().Options
    
    local Library = loadstring(game:HttpGet("RAW_URL"))()
    local Window = Library:CreateWindow({ Title = "Hub", Center = true, AutoShow = true, Size = UDim2.fromOffset(550, 440) })
    local Tabs = Window:AddTabSection()
    local Tab = Tabs:AddTab("Combat")
    local Left, Right = Tab:AddLeftGroupBox("Aimbot"), Tab:AddRightGroupBox("Settings")
    Left:AddToggle("AimbotEnabled", { Text = "Aimbot", Default = false })
    Left:AddSlider("FOV", { Text = "FOV", Default = 80, Min = 10, Max = 300, Suffix = "°" })
    Left:AddDropdown("Hitpart", { Text = "Hitpart", Values = {"Head","Torso","HRP"}, Default = 1 })
    Left:AddKeybind("AimKey", { Text = "Aim Key", Default = Enum.KeyCode.Q, Mode = "Hold" })
    Left:AddColorPicker("ESPColor", { Text = "Color", Default = Color3.fromRGB(255,80,80) })
    Toggles.AimbotEnabled:OnChanged(function() print(Toggles.AimbotEnabled.Value) end)
]]

-- ══════════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════════
local InputService  = game:GetService('UserInputService')
local TextService   = game:GetService('TextService')
local CoreGui       = game:GetService('CoreGui')
local Players       = game:GetService('Players')
local RunService    = game:GetService('RunService')
local TweenService  = game:GetService('TweenService')

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ══════════════════════════════════════════════════
--  GLOBALS (Linoria-style)
-- ══════════════════════════════════════════════════
local Toggles = {}
local Options  = {}
getgenv().Toggles = Toggles
getgenv().Options  = Options

-- ══════════════════════════════════════════════════
--  SCREENGUI
-- ══════════════════════════════════════════════════
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'NullLib'
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.ResetOnSpawn = false
local ProtectGui = (syn and syn.protect_gui) or (protectgui) or function() end
pcall(ProtectGui, ScreenGui)
ScreenGui.Parent = CoreGui

-- ══════════════════════════════════════════════════
--  LIBRARY TABLE
-- ══════════════════════════════════════════════════
local Library = {
    -- Registry for live theme re-coloring
    Registry    = {};
    RegistryMap = {};
    -- Theme (flat pixel aesthetic, Linoria-inspired dark)
    FontColor       = Color3.fromRGB(255, 255, 255);
    MainColor       = Color3.fromRGB(30, 30, 30);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor     = Color3.fromRGB(0, 90, 255);
    OutlineColor    = Color3.fromRGB(55, 55, 55);
    ToggleColor     = Color3.fromRGB(0, 90, 255);
    Font            = Enum.Font.Code;
    -- State
    OpenedFrames    = {};
    DependencyBoxes = {};
    Signals         = {};
    ScreenGui       = ScreenGui;
    Hidden          = false;
    WindowShown     = false;
    -- Addon refs
    SaveManager     = nil;
    ThemeManager    = nil;
    Watermark       = nil;
    -- Notification queue
    NotifQueue      = {};
}

-- ══════════════════════════════════════════════════
--  UTILITY
-- ══════════════════════════════════════════════════
function Library:Create(Class, Props)
    local inst = type(Class) == 'string' and Instance.new(Class) or Class
    for k, v in next, Props do inst[k] = v end
    return inst
end

function Library:AddToRegistry(Inst, Props)
    local data = { Instance = Inst, Properties = Props }
    table.insert(self.Registry, data)
    self.RegistryMap[Inst] = data
end

function Library:RemoveFromRegistry(Inst)
    local data = self.RegistryMap[Inst]
    if not data then return end
    for i = #self.Registry, 1, -1 do
        if self.Registry[i] == data then table.remove(self.Registry, i) end
    end
    self.RegistryMap[Inst] = nil
end

Library:Create(ScreenGui, {}):DescendantRemoving:Connect(function(inst)
    if Library.RegistryMap[inst] then Library:RemoveFromRegistry(inst) end
end)
-- actually wire it:
Library.Signals[#Library.Signals+1] = ScreenGui.DescendantRemoving:Connect(function(i)
    if Library.RegistryMap[i] then Library:RemoveFromRegistry(i) end
end)

function Library:UpdateColors()
    for _, obj in next, self.Registry do
        for prop, colorKey in next, obj.Properties do
            if type(colorKey) == 'string' then
                obj.Instance[prop] = self[colorKey]
            elseif type(colorKey) == 'function' then
                obj.Instance[prop] = colorKey()
            end
        end
    end
end

function Library:ApplyStroke(inst)
    inst.TextStrokeTransparency = 1
    local s = Instance.new('UIStroke')
    s.Color = Color3.new()
    s.Thickness = 1
    s.LineJoinMode = Enum.LineJoinMode.Miter
    s.Parent = inst
end

function Library:MakeLabel(props)
    local lbl = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font  = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 13;
    })
    Library:ApplyStroke(lbl)
    Library:AddToRegistry(lbl, { TextColor3 = 'FontColor' })
    return Library:Create(lbl, props)
end

function Library:GetTextBounds(text, font, size)
    return TextService:GetTextSize(text, size, font, Vector2.new(1920,1080))
end

function Library:GetDarkerColor(c)
    local h,s,v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, v/1.5)
end

function Library:SafeCallback(f, ...)
    if not f then return end
    local ok, err = pcall(f, ...)
    if not ok then
        warn('[NullLib] Callback error: ' .. tostring(err))
    end
end

function Library:AttemptSave()
    if self.SaveManager then self.SaveManager:Save() end
end

function Library:MouseIsOverOpenedFrame()
    for frame in next, self.OpenedFrames do
        local ap, as = frame.AbsolutePosition, frame.AbsoluteSize
        if Mouse.X >= ap.X and Mouse.X <= ap.X + as.X
        and Mouse.Y >= ap.Y and Mouse.Y <= ap.Y + as.Y then
            return true
        end
    end
end

function Library:IsMouseOverFrame(frame)
    local ap, as = frame.AbsolutePosition, frame.AbsoluteSize
    return Mouse.X >= ap.X and Mouse.X <= ap.X + as.X
       and Mouse.Y >= ap.Y and Mouse.Y <= ap.Y + as.Y
end

function Library:UpdateDependencyBoxes()
    for _, db in next, self.DependencyBoxes do db:Update() end
end

-- ══════════════════════════════════════════════════
--  DRAGGABLE
-- ══════════════════════════════════════════════════
function Library:MakeDraggable(frame, cutoff)
    frame.Active = true
    frame.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local objPos = Vector2.new(Mouse.X - frame.AbsolutePosition.X, Mouse.Y - frame.AbsolutePosition.Y)
        if objPos.Y > (cutoff or 9999) then return end
        while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            frame.Position = UDim2.fromOffset(
                Mouse.X - objPos.X + (frame.Size.X.Offset * frame.AnchorPoint.X),
                Mouse.Y - objPos.Y + (frame.Size.Y.Offset * frame.AnchorPoint.Y)
            )
            RunService.RenderStepped:Wait()
        end
    end)
end

-- ══════════════════════════════════════════════════
--  NOTIFICATIONS
-- ══════════════════════════════════════════════════
local NotifFrame = Library:Create('Frame', {
    Name = 'NotifHolder';
    BackgroundTransparency = 1;
    Size = UDim2.new(0, 220, 1, 0);
    Position = UDim2.new(1, -228, 0, 0);
    Parent = ScreenGui;
})
Library:Create('UIListLayout', {
    VerticalAlignment = Enum.VerticalAlignment.Bottom;
    SortOrder = Enum.SortOrder.LayoutOrder;
    Padding = UDim.new(0, 4);
    Parent = NotifFrame;
})

function Library:Notify(text, duration)
    duration = duration or 3
    local notif = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Size = UDim2.fromOffset(216, 42);
        Parent = NotifFrame;
    })
    Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(0, 3, 1, 0);
        Parent = notif;
    })
    Library:MakeLabel({
        Text = text;
        TextSize = 12;
        TextWrapped = true;
        TextXAlignment = Enum.TextXAlignment.Left;
        Position = UDim2.fromOffset(8, 0);
        Size = UDim2.new(1, -12, 1, 0);
        Parent = notif;
    })
    Library:AddToRegistry(notif, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    task.delay(duration, function()
        if notif and notif.Parent then notif:Destroy() end
    end)
end

-- ══════════════════════════════════════════════════
--  WATERMARK
-- ══════════════════════════════════════════════════
function Library:SetWatermarkVisibility(v)
    if self.Watermark then self.Watermark.Visible = v end
end

function Library:SetWatermark(text)
    if not self.Watermark then
        local wm = Library:Create('Frame', {
            Name = 'Watermark';
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            Position = UDim2.fromOffset(4, 4);
            Size = UDim2.fromOffset(1, 22);
            AutomaticSize = Enum.AutomaticSize.X;
            Parent = ScreenGui;
        })
        Library:MakeLabel({
            Text = '';
            TextSize = 13;
            Position = UDim2.fromOffset(6, 0);
            Size = UDim2.new(1, -10, 1, 0);
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = wm;
        })
        Library:AddToRegistry(wm, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        self.Watermark = wm
        self.WatermarkLabel = wm:FindFirstChildOfClass('TextLabel')
    end
    if self.WatermarkLabel then
        self.WatermarkLabel.Text = text or ''
    end
end

-- ══════════════════════════════════════════════════
--  UNLOAD
-- ══════════════════════════════════════════════════
function Library:Unload()
    for i = #self.Signals, 1, -1 do
        local s = table.remove(self.Signals, i)
        s:Disconnect()
    end
    if self.OnUnloadCallback then self.OnUnloadCallback() end
    ScreenGui:Destroy()
end

function Library:GiveSignal(sig)
    table.insert(self.Signals, sig)
end

-- ══════════════════════════════════════════════════
--  KEYBIND ELEMENT (shared builder)
-- ══════════════════════════════════════════════════
local function BuildKeybind(Idx, Info, ParentLabel)
    assert(Info.Default ~= nil, 'AddKeybind: missing Default')
    local modes = { 'Always', 'Toggle', 'Hold' }
    local kb = {
        Value    = Info.Default;
        Mode     = Info.Mode or 'Always'; -- Always, Toggle, Hold
        Type     = 'Keybind';
        Text     = Info.Text or 'Keybind';
        Callback = Info.Callback or function() end;
        _toggled = false;
        _held    = false;
        _conn    = nil;
    }
    -- label on right side
    local KeyLabel = Library:MakeLabel({
        Text = '[' .. kb.Value.Name .. ']';
        TextSize = 12;
        Size = UDim2.fromOffset(1, 14);
        AutomaticSize = Enum.AutomaticSize.X;
        TextXAlignment = Enum.TextXAlignment.Right;
        AnchorPoint = Vector2.new(1, 0.5);
        Position = UDim2.new(1, -2, 0.5, 0);
        ZIndex = ParentLabel.ZIndex + 1;
        Parent = ParentLabel;
    })

    local ModeLabel = Library:MakeLabel({
        Text = '(' .. kb.Mode .. ')';
        TextSize = 11;
        TextColor3 = Color3.fromRGB(170,170,170);
        Size = UDim2.fromOffset(1, 14);
        AutomaticSize = Enum.AutomaticSize.X;
        AnchorPoint = Vector2.new(1, 0.5);
        Position = UDim2.new(1, -2, 1, 0);
        ZIndex = ParentLabel.ZIndex + 1;
        Parent = ParentLabel;
    })

    local listening = false

    local function UpdateLabel()
        KeyLabel.Text = listening and '...' or ('[' .. kb.Value.Name .. ']')
        ModeLabel.Text = '(' .. kb.Mode .. ')'
    end

    -- click to rebind
    local hitbox = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Text = '';
        Size = UDim2.fromOffset(60, 22);
        AnchorPoint = Vector2.new(1, 0.5);
        Position = UDim2.new(1, -2, 0.5, 0);
        ZIndex = ParentLabel.ZIndex + 2;
        Parent = ParentLabel;
    })
    hitbox.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        UpdateLabel()
    end)
    -- right click cycles mode
    hitbox.MouseButton2Click:Connect(function()
        local idx = table.find(modes, kb.Mode) or 1
        kb.Mode = modes[(idx % #modes) + 1]
        UpdateLabel()
        Library:AttemptSave()
    end)

    Library:GiveSignal(InputService.InputBegan:Connect(function(inp, gpe)
        if listening then
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                kb.Value = inp.KeyCode
                listening = false
                UpdateLabel()
                Library:AttemptSave()
            end
            return
        end
        if inp.KeyCode ~= kb.Value then return end
        if kb.Mode == 'Always' then
            Library:SafeCallback(kb.Callback, true)
        elseif kb.Mode == 'Toggle' then
            kb._toggled = not kb._toggled
            Library:SafeCallback(kb.Callback, kb._toggled)
        elseif kb.Mode == 'Hold' then
            kb._held = true
            Library:SafeCallback(kb.Callback, true)
        end
    end))
    Library:GiveSignal(InputService.InputEnded:Connect(function(inp)
        if inp.KeyCode == kb.Value and kb.Mode == 'Hold' and kb._held then
            kb._held = false
            Library:SafeCallback(kb.Callback, false)
        end
    end))

    function kb:SetValue(key, mode)
        self.Value = key or self.Value
        self.Mode  = mode or self.Mode
        UpdateLabel()
    end
    function kb:OnChanged(f) self.Changed = f end

    Options[Idx] = kb
    return kb
end

-- ══════════════════════════════════════════════════
--  COLOR PICKER (shared builder, Linoria-style)
-- ══════════════════════════════════════════════════
local function BuildColorPicker(Idx, Info, ParentLabel)
    assert(Info.Default, 'AddColorPicker: missing Default')
    local cp = {
        Value        = Info.Default;
        Transparency = Info.Transparency or 0;
        Type         = 'ColorPicker';
        Title        = Info.Text or 'Color';
        Callback     = Info.Callback or function() end;
    }

    -- inline HSV
    local h, s, v = Color3.toHSV(cp.Value)
    cp.Hue = h; cp.Sat = s; cp.Vib = v

    -- small swatch on parent row
    local DisplayFrame = Library:Create('Frame', {
        BackgroundColor3 = cp.Value;
        BorderColor3 = Library:GetDarkerColor(cp.Value);
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.fromOffset(28, 14);
        AnchorPoint = Vector2.new(1, 0.5);
        Position = UDim2.new(1, -2, 0.5, 0);
        ZIndex = ParentLabel.ZIndex + 1;
        Parent = ParentLabel;
    })

    -- picker popup in ScreenGui (so it floats above everything)
    local PickerOuter = Library:Create('Frame', {
        Name = 'NullLib_ColorPicker';
        BackgroundColor3 = Color3.new(1,1,1);
        BorderColor3 = Color3.new();
        Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
        Visible = false;
        ZIndex = 30;
        Parent = ScreenGui;
    })
    DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
        PickerOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18)
    end)

    local PickerInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 31;
        Parent = PickerOuter;
    })
    Library:AddToRegistry(PickerInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })

    -- accent bar top
    local AccentBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 32;
        Parent = PickerInner;
    })
    Library:AddToRegistry(AccentBar, { BackgroundColor3 = 'AccentColor' })

    -- title
    Library:MakeLabel({
        Text = cp.Title;
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        Position = UDim2.fromOffset(5, 5);
        Size = UDim2.new(1,0,0,14);
        ZIndex = 32;
        Parent = PickerInner;
    })

    -- SV map
    local SVOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new();
        Position = UDim2.fromOffset(4, 25);
        Size = UDim2.fromOffset(200, 200);
        ZIndex = 32;
        Parent = PickerInner;
    })
    local SVInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 33;
        Parent = SVOuter;
    })
    Library:AddToRegistry(SVInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })

    -- white-black gradient map (standard Linoria asset)
    local SVMap = Library:Create('ImageLabel', {
        BorderSizePixel = 0;
        Size = UDim2.new(1,0,1,0);
        Image = 'rbxassetid://4155801252';
        ZIndex = 33;
        Parent = SVInner;
    })

    local SVCursorOuter = Library:Create('ImageLabel', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        Size = UDim2.fromOffset(6,6);
        BackgroundTransparency = 1;
        Image = 'http://www.roblox.com/asset/?id=9619665977';
        ImageColor3 = Color3.new();
        ZIndex = 34;
        Parent = SVMap;
    })
    Library:Create('ImageLabel', {
        Size = UDim2.fromOffset(4,4);
        Position = UDim2.fromOffset(1,1);
        BackgroundTransparency = 1;
        Image = 'http://www.roblox.com/asset/?id=9619665977';
        ZIndex = 35;
        Parent = SVCursorOuter;
    })

    -- Hue bar
    local HueOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new();
        Position = UDim2.fromOffset(208, 25);
        Size = UDim2.fromOffset(15, 200);
        ZIndex = 32;
        Parent = PickerInner;
    })
    local HueInner = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1,1,1);
        BorderSizePixel = 0;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 33;
        Parent = HueOuter;
    })
    local seqTable = {}
    for i = 0, 1, 0.1 do
        table.insert(seqTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
    end
    Library:Create('UIGradient', { Color = ColorSequence.new(seqTable); Rotation = 90; Parent = HueInner })
    local HueCursor = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1,1,1);
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new();
        Size = UDim2.new(1, 0, 0, 1);
        ZIndex = 34;
        Parent = HueInner;
    })

    -- Hex box
    local HexOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new();
        Position = UDim2.fromOffset(4, 228);
        Size = UDim2.new(0.5, -6, 0, 20);
        ZIndex = 32;
        Parent = PickerInner;
    })
    local HexInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 33;
        Parent = HexOuter;
    })
    Library:AddToRegistry(HexInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212))
        });
        Rotation = 90;
        Parent = HexInner;
    })
    local HexBox = Library:Create('TextBox', {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(5, 0);
        Size = UDim2.new(1,-5,1,0);
        Font = Library.Font;
        PlaceholderText = 'Hex';
        Text = '#FFFFFF';
        TextColor3 = Library.FontColor;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 34;
        Parent = HexInner;
    })
    Library:ApplyStroke(HexBox)
    Library:AddToRegistry(HexBox, { TextColor3 = 'FontColor' })

    -- RGB box
    local RGBOuter = Library:Create(HexOuter:Clone(), {
        Position = UDim2.new(0.5, 2, 0, 228);
        Size = UDim2.new(0.5, -6, 0, 20);
        Parent = PickerInner;
    })
    local RGBInner = RGBOuter:FindFirstChildOfClass('Frame')
    if RGBInner then
        Library:AddToRegistry(RGBInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    end
    local RGBBox = Library:Create('TextBox', {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(5, 0);
        Size = UDim2.new(1,-5,1,0);
        Font = Library.Font;
        PlaceholderText = 'R, G, B';
        Text = '255, 255, 255';
        TextColor3 = Library.FontColor;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 34;
        Parent = RGBInner or RGBOuter;
    })
    Library:ApplyStroke(RGBBox)
    Library:AddToRegistry(RGBBox, { TextColor3 = 'FontColor' })

    -- Transparency bar (optional)
    local TransOuter, TransInner, TransCursor
    if Info.Transparency then
        TransOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new();
            Position = UDim2.fromOffset(4, 251);
            Size = UDim2.new(1,-8,0,15);
            ZIndex = 32;
            Parent = PickerInner;
        })
        TransInner = Library:Create('Frame', {
            BackgroundColor3 = cp.Value;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1,0,1,0);
            ZIndex = 33;
            Parent = TransOuter;
        })
        Library:AddToRegistry(TransInner, { BorderColor3 = 'OutlineColor' })
        Library:Create('ImageLabel', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1,0,1,0);
            Image = 'http://www.roblox.com/asset/?id=12978095818';
            ZIndex = 34;
            Parent = TransInner;
        })
        TransCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1,1,1);
            AnchorPoint = Vector2.new(0.5, 0);
            BorderColor3 = Color3.new();
            Size = UDim2.fromOffset(1,15);
            ZIndex = 35;
            Parent = TransInner;
        })
    end

    -- Display / update
    function cp:Display()
        self.Value = Color3.fromHSV(self.Hue, self.Sat, self.Vib)
        SVMap.BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1)
        Library:Create(DisplayFrame, {
            BackgroundColor3 = self.Value;
            BackgroundTransparency = self.Transparency;
            BorderColor3 = Library:GetDarkerColor(self.Value);
        })
        if TransInner then
            TransInner.BackgroundColor3 = self.Value
            TransCursor.Position = UDim2.new(1 - self.Transparency, 0, 0, 0)
        end
        SVCursorOuter.Position = UDim2.new(self.Sat, 0, 1 - self.Vib, 0)
        HueCursor.Position = UDim2.new(0, 0, self.Hue, 0)
        HexBox.Text = '#' .. self.Value:ToHex()
        RGBBox.Text = string.format('%d, %d, %d',
            math.floor(self.Value.R*255), math.floor(self.Value.G*255), math.floor(self.Value.B*255))
        Library:SafeCallback(self.Callback, self.Value)
        Library:SafeCallback(self.Changed, self.Value)
    end

    function cp:SetHSVFromRGB(color)
        self.Hue, self.Sat, self.Vib = Color3.toHSV(color)
    end

    function cp:SetValueRGB(color, trans)
        self.Transparency = trans or 0
        self:SetHSVFromRGB(color)
        self:Display()
    end

    function cp:SetValue(hsv, trans)
        self:SetValueRGB(Color3.fromHSV(hsv[1], hsv[2], hsv[3]), trans)
    end

    function cp:OnChanged(f) self.Changed = f; f(self.Value) end

    function cp:Show()
        for frame in next, Library.OpenedFrames do
            if frame.Name == 'NullLib_ColorPicker' then
                frame.Visible = false
                Library.OpenedFrames[frame] = nil
            end
        end
        PickerOuter.Visible = true
        Library.OpenedFrames[PickerOuter] = true
    end

    function cp:Hide()
        PickerOuter.Visible = false
        Library.OpenedFrames[PickerOuter] = nil
    end

    -- Input handlers
    SVMap.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local mx = math.clamp(Mouse.X, SVMap.AbsolutePosition.X, SVMap.AbsolutePosition.X + SVMap.AbsoluteSize.X)
            local my = math.clamp(Mouse.Y, SVMap.AbsolutePosition.Y, SVMap.AbsolutePosition.Y + SVMap.AbsoluteSize.Y)
            cp.Sat = (mx - SVMap.AbsolutePosition.X) / SVMap.AbsoluteSize.X
            cp.Vib = 1 - (my - SVMap.AbsolutePosition.Y) / SVMap.AbsoluteSize.Y
            cp:Display(); RunService.RenderStepped:Wait()
        end
        Library:AttemptSave()
    end)

    HueInner.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local my = math.clamp(Mouse.Y, HueInner.AbsolutePosition.Y, HueInner.AbsolutePosition.Y + HueInner.AbsoluteSize.Y)
            cp.Hue = (my - HueInner.AbsolutePosition.Y) / HueInner.AbsoluteSize.Y
            cp:Display(); RunService.RenderStepped:Wait()
        end
        Library:AttemptSave()
    end)

    if TransInner then
        TransInner.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mx = math.clamp(Mouse.X, TransInner.AbsolutePosition.X, TransInner.AbsolutePosition.X + TransInner.AbsoluteSize.X)
                cp.Transparency = 1 - (mx - TransInner.AbsolutePosition.X) / TransInner.AbsoluteSize.X
                cp:Display(); RunService.RenderStepped:Wait()
            end
            Library:AttemptSave()
        end)
    end

    HexBox.FocusLost:Connect(function(enter)
        if enter then
            local ok, col = pcall(Color3.fromHex, HexBox.Text)
            if ok then cp:SetHSVFromRGB(col) end
        end
        cp:Display()
    end)

    RGBBox.FocusLost:Connect(function(enter)
        if enter then
            local r,g,b = RGBBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
            if r then cp:SetHSVFromRGB(Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))) end
        end
        cp:Display()
    end)

    DisplayFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
            if PickerOuter.Visible then cp:Hide() else cp:Show() end
        end
    end)

    Library:GiveSignal(InputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            local ap, as = PickerOuter.AbsolutePosition, PickerOuter.AbsoluteSize
            if Mouse.X < ap.X or Mouse.X > ap.X+as.X
            or Mouse.Y < (ap.Y-21) or Mouse.Y > ap.Y+as.Y then
                cp:Hide()
            end
        end
    end))

    cp:Display()
    Options[Idx] = cp
    return cp
end

-- ══════════════════════════════════════════════════
--  GROUPBOX / ELEMENT BUILDER
-- ══════════════════════════════════════════════════
local ElementFuncs = {}

function ElementFuncs:AddToggle(Idx, Info)
    assert(Info.Default ~= nil, 'AddToggle: missing Default')
    local toggle = {
        Value    = Info.Default;
        Type     = 'Toggle';
        Text     = Info.Text or Idx;
        Callback = Info.Callback or function() end;
        _signals = {};
    }

    -- row frame
    local Row = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 18);
        Parent = self.Container;
    })

    local RowLabel = Library:MakeLabel({
        Text = Info.Text or Idx;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        Position = UDim2.fromOffset(20, 0);
        Size = UDim2.new(1, -22, 1, 0);
        ZIndex = 5;
        Parent = Row;
    })

    -- checkbox (Linoria style - square pixel checkbox)
    local CheckOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Size = UDim2.fromOffset(14, 14);
        Position = UDim2.fromOffset(2, 2);
        ZIndex = 5;
        Parent = Row;
    })
    Library:AddToRegistry(CheckOuter, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

    local CheckFill = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.fromOffset(10, 10);
        Position = UDim2.fromOffset(2, 2);
        Visible = Info.Default;
        ZIndex = 6;
        Parent = CheckOuter;
    })
    Library:AddToRegistry(CheckFill, { BackgroundColor3 = 'AccentColor' })

    -- tooltip
    if Info.Tooltip then Library:AddToolTip(Info.Tooltip, Row) end

    -- dependency box support (rigged into toggle)
    local DepBox
    if Info.Rigged then DepBox = Info.Rigged end

    local function SetValue(v, silent)
        toggle.Value = v
        CheckFill.Visible = v
        if not silent then
            Library:SafeCallback(toggle.Callback, v)
            Library:SafeCallback(toggle.Changed, v)
        end
        Library:UpdateDependencyBoxes()
        Library:AttemptSave()
    end

    function toggle:SetValue(v) SetValue(v) end
    function toggle:OnChanged(f) self.Changed = f; f(self.Value) end

    local hitbox = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Text = '';
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 7;
        Parent = Row;
    })
    hitbox.MouseButton1Click:Connect(function()
        SetValue(not toggle.Value)
    end)

    -- keybind inline (optional)
    if Info.Keybind then
        BuildKeybind(Idx .. '_Keybind', Info.Keybind, RowLabel)
    end

    -- color picker inline (optional)
    if Info.ColorPicker then
        BuildColorPicker(Idx .. '_Color', Info.ColorPicker, RowLabel)
    end

    Toggles[Idx] = toggle
    return toggle
end

function ElementFuncs:AddSlider(Idx, Info)
    assert(Info.Min and Info.Max and Info.Default ~= nil, 'AddSlider: missing Min/Max/Default')
    local slider = {
        Value    = math.clamp(Info.Default, Info.Min, Info.Max);
        Type     = 'Slider';
        Text     = Info.Text or Idx;
        Min      = Info.Min;
        Max      = Info.Max;
        Callback = Info.Callback or function() end;
    }
    local suffix = Info.Suffix or ''
    local step   = Info.Step   or 1

    local Row = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 32);
        Parent = self.Container;
    })

    Library:MakeLabel({
        Text = Info.Text or Idx;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        Size = UDim2.new(1, 0, 0, 14);
        ZIndex = 5;
        Parent = Row;
    })

    local ValLabel = Library:MakeLabel({
        Text = tostring(slider.Value) .. suffix;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Right;
        Size = UDim2.new(1, 0, 0, 14);
        ZIndex = 5;
        Parent = Row;
    })

    -- track
    local TrackOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new();
        Position = UDim2.fromOffset(0, 17);
        Size = UDim2.new(1, 0, 0, 10);
        ZIndex = 5;
        Parent = Row;
    })
    local TrackInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 6;
        Parent = TrackOuter;
    })
    Library:AddToRegistry(TrackInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

    local Fill = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new((slider.Value - Info.Min)/(Info.Max-Info.Min), 0, 1, 0);
        ZIndex = 7;
        Parent = TrackInner;
    })
    Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' })

    local function SetValue(v, silent)
        if step > 0 then v = math.round(v / step) * step end
        v = math.clamp(v, Info.Min, Info.Max)
        slider.Value = v
        Fill.Size = UDim2.new((v - Info.Min)/(Info.Max - Info.Min), 0, 1, 0)
        ValLabel.Text = tostring(v) .. suffix
        if not silent then
            Library:SafeCallback(slider.Callback, v)
            Library:SafeCallback(slider.Changed, v)
        end
        Library:AttemptSave()
    end

    function slider:SetValue(v) SetValue(v) end
    function slider:OnChanged(f) self.Changed = f; f(self.Value) end

    TrackInner.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local mx = math.clamp(Mouse.X, TrackInner.AbsolutePosition.X, TrackInner.AbsolutePosition.X + TrackInner.AbsoluteSize.X)
            local pct = (mx - TrackInner.AbsolutePosition.X) / TrackInner.AbsoluteSize.X
            SetValue(Info.Min + (Info.Max - Info.Min) * pct)
            RunService.RenderStepped:Wait()
        end
    end)

    Options[Idx] = slider
    return slider
end

function ElementFuncs:AddDropdown(Idx, Info)
    assert(Info.Values, 'AddDropdown: missing Values')
    local items = Info.Values
    local multi = Info.Multi or false
    local sel   = multi and {} or (Info.Default and items[Info.Default] or items[1])
    local open  = false

    local dd = {
        Value    = sel;
        Type     = 'Dropdown';
        Text     = Info.Text or Idx;
        Callback = Info.Callback or function() end;
    }

    local Row = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 32);
        Parent = self.Container;
        ClipsDescendants = false;
    })

    Library:MakeLabel({
        Text = Info.Text or Idx;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        Size = UDim2.new(1, 0, 0, 14);
        ZIndex = 5;
        Parent = Row;
    })

    local DDOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new();
        Position = UDim2.fromOffset(0, 16);
        Size = UDim2.new(1, 0, 0, 16);
        ZIndex = 5;
        Parent = Row;
    })
    local DDInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 6;
        Parent = DDOuter;
    })
    Library:AddToRegistry(DDInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

    local ValLabel = Library:MakeLabel({
        Text = multi and 'None' or (sel or 'None');
        TextSize = 12;
        TextXAlignment = Enum.TextXAlignment.Left;
        Position = UDim2.fromOffset(3, 0);
        Size = UDim2.new(1,-14,1,0);
        ZIndex = 7;
        Parent = DDInner;
    })

    Library:MakeLabel({
        Text = '▾';
        TextSize = 13;
        AnchorPoint = Vector2.new(1,0.5);
        Position = UDim2.new(1,-2,0.5,0);
        Size = UDim2.fromOffset(12,14);
        ZIndex = 7;
        Parent = DDInner;
    })

    -- List popup in ScreenGui
    local ListFrame = Library:Create('Frame', {
        Name = 'NullLib_Dropdown';
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.fromOffset(DDInner.AbsolutePosition.X, DDInner.AbsolutePosition.Y + 18);
        Size = UDim2.fromOffset(DDInner.AbsoluteSize.X, 0);
        Visible = false;
        ZIndex = 20;
        Parent = ScreenGui;
    })
    Library:AddToRegistry(ListFrame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    DDInner:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
        ListFrame.Position = UDim2.fromOffset(DDInner.AbsolutePosition.X, DDInner.AbsolutePosition.Y + 18)
        ListFrame.Size = UDim2.fromOffset(DDInner.AbsoluteSize.X, ListFrame.Size.Y.Offset)
    end)

    local ListLayout = Library:Create('UIListLayout', {
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = ListFrame;
    })

    local function UpdateLabel()
        if multi then
            local sel2 = {}
            for k in next, dd.Value do table.insert(sel2, k) end
            ValLabel.Text = #sel2 > 0 and table.concat(sel2, ', ') or 'None'
        else
            ValLabel.Text = dd.Value or 'None'
        end
    end

    local function BuildList()
        for _, c in next, ListFrame:GetChildren() do
            if c:IsA('TextButton') then c:Destroy() end
        end
        for _, item in next, items do
            local isSelected = multi and dd.Value[item] or dd.Value == item
            local Btn = Library:Create('TextButton', {
                BackgroundColor3 = isSelected and Library.AccentColor or Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                Text = '';
                Size = UDim2.new(1, 0, 0, 16);
                ZIndex = 21;
                Parent = ListFrame;
                AutoButtonColor = false;
            })
            Library:MakeLabel({
                Text = item;
                TextSize = 12;
                TextXAlignment = Enum.TextXAlignment.Left;
                Position = UDim2.fromOffset(3, 0);
                Size = UDim2.new(1,-3,1,0);
                ZIndex = 22;
                Parent = Btn;
            })
            Btn.MouseButton1Click:Connect(function()
                if multi then
                    if dd.Value[item] then dd.Value[item] = nil
                    else dd.Value[item] = true end
                else
                    dd.Value = item
                    open = false
                    ListFrame.Visible = false
                    Library.OpenedFrames[ListFrame] = nil
                end
                UpdateLabel()
                BuildList()
                Library:SafeCallback(dd.Callback, dd.Value)
                Library:SafeCallback(dd.Changed, dd.Value)
                Library:AttemptSave()
            end)
            Btn.MouseEnter:Connect(function()
                if not (multi and dd.Value[item]) and dd.Value ~= item then
                    Btn.BackgroundColor3 = Library:GetDarkerColor(Library.AccentColor)
                end
            end)
            Btn.MouseLeave:Connect(function()
                local isSel = multi and dd.Value[item] or dd.Value == item
                Btn.BackgroundColor3 = isSel and Library.AccentColor or Library.MainColor
            end)
        end
        ListFrame.Size = UDim2.fromOffset(
            ListFrame.Size.X.Offset,
            math.min(#items * 16, 120)
        )
    end

    BuildList()

    local ClickBtn = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Text = '';
        Size = UDim2.new(1,0,1,0);
        ZIndex = 8;
        Parent = DDInner;
    })
    ClickBtn.MouseButton1Click:Connect(function()
        open = not open
        ListFrame.Visible = open
        if open then
            Library.OpenedFrames[ListFrame] = true
        else
            Library.OpenedFrames[ListFrame] = nil
        end
    end)

    Library:GiveSignal(InputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            if not Library:IsMouseOverFrame(ListFrame) and not Library:IsMouseOverFrame(DDInner) then
                open = false
                ListFrame.Visible = false
                Library.OpenedFrames[ListFrame] = nil
            end
        end
    end))

    function dd:SetValue(v)
        self.Value = v
        UpdateLabel()
        BuildList()
    end
    function dd:Refresh(newItems)
        items = newItems
        BuildList()
    end
    function dd:OnChanged(f) self.Changed = f end

    Options[Idx] = dd
    return dd
end

function ElementFuncs:AddButton(Info)
    assert(Info.Text, 'AddButton: missing Text')
    local Row = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 20);
        Parent = self.Container;
    })
    local Btn = Library:Create('TextButton', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Text = '';
        Size = UDim2.new(1,0,1,0);
        ZIndex = 5;
        AutoButtonColor = false;
        Parent = Row;
    })
    Library:AddToRegistry(Btn, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    Library:MakeLabel({
        Text = Info.Text;
        TextSize = 13;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 6;
        Parent = Btn;
    })
    Btn.MouseEnter:Connect(function()
        Btn.BackgroundColor3 = Library.AccentColor
    end)
    Btn.MouseLeave:Connect(function()
        Btn.BackgroundColor3 = Library.MainColor
    end)
    Btn.MouseButton1Click:Connect(function()
        Library:SafeCallback(Info.Callback)
    end)
    local btnObj = {}
    function btnObj:AddButton(i2)
        -- double button (split row)
        local Btn2 = Library:Create('TextButton', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            Text = '';
            Size = UDim2.new(0.5, 0, 1, 0);
            Position = UDim2.new(0.5, 0, 0, 0);
            ZIndex = 5;
            AutoButtonColor = false;
            Parent = Row;
        })
        Btn.Size = UDim2.new(0.5, 0, 1, 0)
        Library:AddToRegistry(Btn2, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        Library:MakeLabel({ Text = i2.Text; TextSize = 13; Size = UDim2.new(1,0,1,0); ZIndex = 6; Parent = Btn2 })
        Btn2.MouseEnter:Connect(function() Btn2.BackgroundColor3 = Library.AccentColor end)
        Btn2.MouseLeave:Connect(function() Btn2.BackgroundColor3 = Library.MainColor end)
        Btn2.MouseButton1Click:Connect(function() Library:SafeCallback(i2.Callback) end)
    end
    return btnObj
end

function ElementFuncs:AddInput(Idx, Info)
    local inp = {
        Value    = Info.Default or '';
        Type     = 'Input';
        Callback = Info.Callback or function() end;
    }
    local Row = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 32);
        Parent = self.Container;
    })
    Library:MakeLabel({
        Text = Info.Text or Idx;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        Size = UDim2.new(1,0,0,14);
        ZIndex = 5;
        Parent = Row;
    })
    local BoxOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new();
        Position = UDim2.fromOffset(0, 16);
        Size = UDim2.new(1,0,0,16);
        ZIndex = 5;
        Parent = Row;
    })
    local BoxInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 6;
        Parent = BoxOuter;
    })
    Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    local Box = Library:Create('TextBox', {
        BackgroundTransparency = 1;
        Text = inp.Value;
        PlaceholderText = Info.Placeholder or '';
        PlaceholderColor3 = Color3.fromRGB(160,160,160);
        Font = Library.Font;
        TextSize = 13;
        TextColor3 = Library.FontColor;
        TextXAlignment = Enum.TextXAlignment.Left;
        ClearTextOnFocus = Info.ClearText or false;
        Position = UDim2.fromOffset(4,0);
        Size = UDim2.new(1,-6,1,0);
        ZIndex = 7;
        Parent = BoxInner;
    })
    Library:ApplyStroke(Box)
    Library:AddToRegistry(Box, { TextColor3 = 'FontColor' })
    Box.FocusLost:Connect(function(enter)
        inp.Value = Box.Text
        if enter then Library:SafeCallback(inp.Callback, Box.Text) end
        Library:AttemptSave()
    end)
    function inp:SetValue(v) Box.Text = v; self.Value = v end
    function inp:OnChanged(f) self.Changed = f end
    Box:GetPropertyChangedSignal('Text'):Connect(function()
        Library:SafeCallback(inp.Changed, Box.Text)
    end)
    Options[Idx] = inp
    return inp
end

function ElementFuncs:AddKeybind(Idx, Info)
    local Row = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 18);
        Parent = self.Container;
    })
    local RowLabel = Library:MakeLabel({
        Text = Info.Text or Idx;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 5;
        Parent = Row;
    })
    return BuildKeybind(Idx, Info, RowLabel)
end

function ElementFuncs:AddColorPicker(Idx, Info)
    local Row = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 18);
        Parent = self.Container;
    })
    local RowLabel = Library:MakeLabel({
        Text = Info.Text or Idx;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        Size = UDim2.new(1,0,1,0);
        ZIndex = 5;
        Parent = Row;
    })
    return BuildColorPicker(Idx, Info, RowLabel)
end

function ElementFuncs:AddLabel(text)
    local lbl = Library:MakeLabel({
        Text = text or '';
        TextSize = 12;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextColor3 = Color3.fromRGB(200,200,200);
        Size = UDim2.new(1,0,0,14);
        Parent = self.Container;
    })
    local obj = {}
    function obj:Set(t) lbl.Text = t end
    return obj
end

function ElementFuncs:AddDivider()
    Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 1);
        Parent = self.Container;
    })
end

function ElementFuncs:AddDependencyBox()
    -- A container whose children can be shown/hidden based on toggle/option states
    local depBox = {
        _conditions = {};
        _content    = {};
    }

    local ContentFrame = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 0);
        AutomaticSize = Enum.AutomaticSize.Y;
        ClipsDescendants = true;
        Parent = self.Container;
    })
    Library:Create('UIListLayout', {
        SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 2);
        Parent = ContentFrame;
    })

    depBox.Container = ContentFrame

    function depBox:SetupCondition(conditions)
        self._conditions = conditions
        Library.DependencyBoxes[#Library.DependencyBoxes+1] = self
    end

    function depBox:Update()
        local show = true
        for _, cond in next, self._conditions do
            local obj = Toggles[cond.Idx] or Options[cond.Idx]
            if obj then
                if cond.Value ~= nil and obj.Value ~= cond.Value then show = false end
            end
        end
        ContentFrame.Visible = show
    end

    -- Copy element methods onto depbox
    for k, v in next, ElementFuncs do
        depBox[k] = v
    end

    depBox:Update()
    return depBox
end

function ElementFuncs:AddToolTip(text)
    -- tooltip for the last added element – stub, can be wired later
end

-- ══════════════════════════════════════════════════
--  GROUPBOX CONSTRUCTOR
-- ══════════════════════════════════════════════════
local function MakeGroupBox(name, parent, zindex)
    local gb = {}

    -- outer wrapper
    local BoxOuter = Library:Create('Frame', {
        BackgroundColor3 = Color3.new();
        BorderColor3 = Color3.new();
        Size = UDim2.new(1, 0, 0, 0);
        AutomaticSize = Enum.AutomaticSize.Y;
        ZIndex = zindex or 3;
        Parent = parent;
    })
    local BoxInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,-1,1,-1);
        Position = UDim2.fromOffset(1,1);
        ZIndex = (zindex or 3) + 1;
        AutomaticSize = Enum.AutomaticSize.Y;
        Parent = BoxOuter;
    })
    Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })

    -- title bar
    local TitleRow = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,0,0,18);
        ZIndex = (zindex or 3) + 2;
        Parent = BoxInner;
    })
    Library:AddToRegistry(TitleRow, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

    Library:MakeLabel({
        Text = name or '';
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        Position = UDim2.fromOffset(5,0);
        Size = UDim2.new(1,-5,1,0);
        ZIndex = (zindex or 3) + 3;
        Parent = TitleRow;
    })

    -- content scroll
    local Scroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Position = UDim2.fromOffset(0, 20);
        Size = UDim2.new(1,0,0,0);
        AutomaticSize = Enum.AutomaticSize.Y;
        CanvasSize = UDim2.new(0,0,0,0);
        AutomaticCanvasSize = Enum.AutomaticSize.Y;
        ScrollBarThickness = 3;
        ScrollBarImageColor3 = Library.OutlineColor;
        ZIndex = (zindex or 3) + 2;
        Parent = BoxInner;
    })

    local Layout = Library:Create('UIListLayout', {
        SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 2);
        Parent = Scroll;
    })
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0,4);
        PaddingRight = UDim.new(0,4);
        PaddingTop = UDim.new(0,4);
        PaddingBottom = UDim.new(0,4);
        Parent = Scroll;
    })

    gb.Container = Scroll
    gb.Outer = BoxOuter
    gb.Inner = BoxInner

    -- copy all element funcs
    for k, v in next, ElementFuncs do
        gb[k] = v
    end

    return gb
end

-- ══════════════════════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════════════════════
local function MakeTabSection(tabBar, contentArea)
    local tabSection = { Tabs = {} }

    function tabSection:AddTab(name)
        local tab = { GroupBoxes = {} }

        -- tab button
        local TabBtn = Library:Create('TextButton', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            Text = '';
            Size = UDim2.fromOffset(1, 22);
            AutomaticSize = Enum.AutomaticSize.X;
            AutoButtonColor = false;
            ZIndex = 8;
            Parent = tabBar;
        })
        Library:AddToRegistry(TabBtn, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

        local TabLabel = Library:MakeLabel({
            Text = name;
            TextSize = 13;
            Position = UDim2.fromOffset(6,0);
            Size = UDim2.new(1,-12,1,0);
            ZIndex = 9;
            Parent = TabBtn;
        })

        -- content frame (two columns: left + right)
        local ContentFrame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1,0,1,0);
            Visible = false;
            ZIndex = 3;
            Parent = contentArea;
        })

        local ColLayout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal;
            Padding = UDim.new(0, 4);
            VerticalAlignment = Enum.VerticalAlignment.Top;
            Parent = ContentFrame;
        })
        Library:Create('UIPadding', {
            PaddingLeft = UDim.new(0, 4);
            PaddingRight = UDim.new(0, 4);
            PaddingTop = UDim.new(0, 4);
            Parent = ContentFrame;
        })

        -- Left column scroll
        local LeftCol = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(0.5,-2,1,0);
            CanvasSize = UDim2.new(0,0,0,0);
            AutomaticCanvasSize = Enum.AutomaticSize.Y;
            ScrollBarThickness = 3;
            ScrollBarImageColor3 = Library.OutlineColor;
            ZIndex = 3;
            Parent = ContentFrame;
        })
        Library:Create('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder;
            Padding = UDim.new(0,4);
            Parent = LeftCol;
        })

        -- Right column scroll
        local RightCol = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(0.5,-2,1,0);
            CanvasSize = UDim2.new(0,0,0,0);
            AutomaticCanvasSize = Enum.AutomaticSize.Y;
            ScrollBarThickness = 3;
            ScrollBarImageColor3 = Library.OutlineColor;
            ZIndex = 3;
            Parent = ContentFrame;
        })
        Library:Create('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder;
            Padding = UDim.new(0,4);
            Parent = RightCol;
        })

        tab.ContentFrame = ContentFrame
        tab.LeftCol      = LeftCol
        tab.RightCol     = RightCol
        tab.Btn          = TabBtn

        function tab:AddLeftGroupBox(name)
            return MakeGroupBox(name, LeftCol, 3)
        end
        function tab:AddRightGroupBox(name)
            return MakeGroupBox(name, RightCol, 3)
        end
        -- tab boxes (popout style within a column)
        function tab:AddLeftTabbox()
            local tbx = { Tabs = {} }
            local wrapper = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1,0,0,0);
                AutomaticSize = Enum.AutomaticSize.Y;
                Parent = LeftCol;
            })
            local btnBar = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1,0,0,18);
                Parent = wrapper;
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                Parent = btnBar;
            })
            local contentWrap = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1,0,0,0);
                AutomaticSize = Enum.AutomaticSize.Y;
                Position = UDim2.fromOffset(0,18);
                Parent = wrapper;
            })
            function tbx:AddTab(tname)
                local isFirst = #tbx.Tabs == 0
                local tb = {}
                local TBtn = Library:Create('TextButton', {
                    BackgroundColor3 = isFirst and Library.AccentColor or Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    Text = '';
                    Size = UDim2.fromOffset(1,18);
                    AutomaticSize = Enum.AutomaticSize.X;
                    AutoButtonColor = false;
                    ZIndex = 4;
                    Parent = btnBar;
                })
                Library:AddToRegistry(TBtn, { BorderColor3 = 'OutlineColor' })
                Library:MakeLabel({ Text = tname; TextSize = 12; Position = UDim2.fromOffset(4,0); Size = UDim2.new(1,-8,1,0); ZIndex = 5; Parent = TBtn })
                local TContent = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1,0,0,0);
                    AutomaticSize = Enum.AutomaticSize.Y;
                    Visible = isFirst;
                    Parent = contentWrap;
                })
                Library:Create('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder; Padding = UDim.new(0,2); Parent = TContent })
                local gbInner = MakeGroupBox(nil, TContent, 3)
                gbInner.Outer.BackgroundColor3 = Color3.fromRGB(0,0,0)
                tb.Container = gbInner.Container
                for k,v in next, ElementFuncs do tb[k] = v end
                table.insert(tbx.Tabs, { btn = TBtn, content = TContent })
                TBtn.MouseButton1Click:Connect(function()
                    for _, t in next, tbx.Tabs do
                        t.content.Visible = false
                        t.btn.BackgroundColor3 = Library.MainColor
                    end
                    TContent.Visible = true
                    TBtn.BackgroundColor3 = Library.AccentColor
                end)
                return tb
            end
            return tbx
        end

        function tab:AddRightTabbox()
            -- same as left but RightCol
            local save = LeftCol
            LeftCol = RightCol
            local r = tab:AddLeftTabbox()
            LeftCol = save
            return r
        end

        table.insert(tabSection.Tabs, tab)
        if #tabSection.Tabs == 1 then
            ContentFrame.Visible = true
            TabBtn.BackgroundColor3 = Library.AccentColor
        end

        TabBtn.MouseButton1Click:Connect(function()
            for _, t in next, tabSection.Tabs do
                t.ContentFrame.Visible = false
                t.Btn.BackgroundColor3 = Library.MainColor
            end
            ContentFrame.Visible = true
            TabBtn.BackgroundColor3 = Library.AccentColor
        end)
        Library:AddToRegistry(TabBtn, { BorderColor3 = 'OutlineColor' })

        return tab
    end

    return tabSection
end

-- ══════════════════════════════════════════════════
--  CREATE WINDOW
-- ══════════════════════════════════════════════════
function Library:CreateWindow(options)
    options = options or {}
    local title    = options.Title    or 'NullLib'
    local size     = options.Size     or UDim2.fromOffset(550, 440)
    local center   = options.Center   or false
    local autoShow = options.AutoShow or true
    local toggleKey = options.ToggleKey or Enum.KeyCode.RightAlt
    local hideBtnToggleKey = options.HideKey

    local win = {}

    -- outer border
    local WindowOuter = Library:Create('Frame', {
        Name = 'NullLib_Window';
        BackgroundColor3 = Color3.new();
        BorderColor3 = Color3.new();
        AnchorPoint = center and Vector2.new(0.5,0.5) or Vector2.new(0,0);
        Position = center and UDim2.new(0.5,0,0.5,0) or UDim2.fromOffset(100,100);
        Size = size;
        ZIndex = 1;
        Parent = ScreenGui;
    })
    local WindowInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,-1,1,-1);
        Position = UDim2.fromOffset(1,1);
        ZIndex = 2;
        Parent = WindowOuter;
    })
    Library:AddToRegistry(WindowInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })

    -- title bar
    local TitleBar = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1,0,0,22);
        ZIndex = 3;
        Parent = WindowInner;
    })
    Library:AddToRegistry(TitleBar, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

    Library:MakeLabel({
        Text = title;
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        Position = UDim2.fromOffset(5,0);
        Size = UDim2.new(1,-40,1,0);
        ZIndex = 4;
        Parent = TitleBar;
    })

    -- close / minimize
    local function MakeTitleBtn(txt, pos)
        local b = Library:Create('TextButton', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            Text = txt;
            Font = Library.Font;
            TextSize = 12;
            TextColor3 = Library.FontColor;
            Size = UDim2.fromOffset(18,18);
            Position = pos;
            AnchorPoint = Vector2.new(0,0.5);
            ZIndex = 4;
            AutoButtonColor = false;
            Parent = TitleBar;
        })
        Library:AddToRegistry(b, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; TextColor3 = 'FontColor' })
        b.MouseEnter:Connect(function() b.BackgroundColor3 = Library.AccentColor end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = Library.MainColor end)
        return b
    end

    local CloseBtn = MakeTitleBtn('x', UDim2.new(1,-20,0.5,0))
    local MinBtn   = MakeTitleBtn('_', UDim2.new(1,-40,0.5,0))

    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        WindowInner.ClipsDescendants = minimized
        if minimized then
            WindowOuter.Size = UDim2.fromOffset(size.X.Offset, 24)
        else
            WindowOuter.Size = size
        end
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        WindowOuter.Visible = false
        Library.WindowShown = false
    end)

    Library:MakeDraggable(WindowOuter, 22)

    -- tab bar (horizontal, below title)
    local TabBar = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.fromOffset(0, 22);
        Size = UDim2.new(1,0,0,22);
        ZIndex = 3;
        Parent = WindowInner;
    })
    Library:AddToRegistry(TabBar, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabBar;
    })
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0,2);
        PaddingTop  = UDim.new(0,2);
        Parent = TabBar;
    })

    -- content area
    local ContentArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(0,44);
        Size = UDim2.new(1,0,1,-44);
        ZIndex = 2;
        Parent = WindowInner;
    })

    if not autoShow then WindowOuter.Visible = false end
    Library.WindowShown = autoShow

    -- toggle visibility
    Library:GiveSignal(InputService.InputBegan:Connect(function(inp)
        if inp.KeyCode == toggleKey then
            Library.WindowShown = not Library.WindowShown
            WindowOuter.Visible = Library.WindowShown
        end
    end))

    function win:Show() WindowOuter.Visible = true; Library.WindowShown = true end
    function win:Hide() WindowOuter.Visible = false; Library.WindowShown = false end
    function win:IsVisible() return Library.WindowShown end

    function win:AddTabSection()
        return MakeTabSection(TabBar, ContentArea)
    end

    -- compatibility aliases
    function win:SetTitle(t)
        -- find label
        for _, c in next, TitleBar:GetChildren() do
            if c:IsA('TextLabel') then c.Text = t end
        end
    end

    return win
end

-- ══════════════════════════════════════════════════
--  ADD TOOLTIP (used by ElementFuncs)
-- ══════════════════════════════════════════════════
function Library:AddToolTip(infoStr, hoverInst)
    local bounds = Library:GetTextBounds(infoStr, Library.Font, 13)
    local tip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Size = UDim2.fromOffset(bounds.X + 8, bounds.Y + 4);
        ZIndex = 50;
        Visible = false;
        Parent = ScreenGui;
    })
    Library:AddToRegistry(tip, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    Library:MakeLabel({
        Text = infoStr;
        TextSize = 13;
        Position = UDim2.fromOffset(4, 2);
        Size = UDim2.fromOffset(bounds.X, bounds.Y);
        ZIndex = 51;
        Parent = tip;
    })
    local hovering = false
    hoverInst.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        hovering = true
        tip.Position = UDim2.fromOffset(Mouse.X + 14, Mouse.Y + 10)
        tip.Visible = true
        while hovering do
            RunService.Heartbeat:Wait()
            tip.Position = UDim2.fromOffset(Mouse.X + 14, Mouse.Y + 10)
        end
    end)
    hoverInst.MouseLeave:Connect(function()
        hovering = false
        tip.Visible = false
    end)
end

return Library
