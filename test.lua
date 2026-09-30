--[[
    NullLib - Roblox UI Library
    Linoria/Vaderhaack style, built clean
    Usage: local NullLib = loadstring(game:HttpGet("YOUR_URL"))()
]]

local NullLib = {}
NullLib.__index = NullLib

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Theme defaults
local DefaultTheme = {
    Background     = Color3.fromRGB(15, 15, 20),
    Surface        = Color3.fromRGB(22, 22, 30),
    SurfaceHover   = Color3.fromRGB(30, 30, 42),
    Accent         = Color3.fromRGB(120, 80, 255),
    AccentDark     = Color3.fromRGB(80, 50, 200),
    Text           = Color3.fromRGB(230, 230, 240),
    TextDim        = Color3.fromRGB(140, 140, 160),
    Border         = Color3.fromRGB(40, 40, 55),
    Toggle_On      = Color3.fromRGB(120, 80, 255),
    Toggle_Off     = Color3.fromRGB(50, 50, 65),
    Danger         = Color3.fromRGB(220, 60, 60),
    Success        = Color3.fromRGB(60, 200, 100),
    Warning        = Color3.fromRGB(220, 160, 40),
    ScrollBar      = Color3.fromRGB(60, 60, 80),
}

-- Utility functions
local function Tween(obj, props, duration, style, direction)
    local info = TweenInfo.new(duration or 0.15, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    TweenService:Create(obj, info, props):Play()
end

local function Create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            pcall(function() inst[k] = v end)
        end
    end
    for _, child in pairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function MakeRound(obj, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = obj
    return corner
end

local function MakePadding(obj, top, right, bottom, left)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, top    or 6)
    pad.PaddingRight  = UDim.new(0, right  or 8)
    pad.PaddingBottom = UDim.new(0, bottom or 6)
    pad.PaddingLeft   = UDim.new(0, left   or 8)
    pad.Parent = obj
end

local function MakeStroke(obj, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(40,40,55)
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = obj
    return stroke
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function ColorToHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255),
        math.floor(c.G * 255),
        math.floor(c.B * 255))
end

local function HexToColor(hex)
    hex = hex:gsub("#","")
    return Color3.fromRGB(
        tonumber(hex:sub(1,2), 16),
        tonumber(hex:sub(3,4), 16),
        tonumber(hex:sub(5,6), 16))
end

-- Drag function
local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, mousePos, framePos = false, nil, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            frame.Position = UDim2.new(
                framePos.X.Scale, framePos.X.Offset + delta.X,
                framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

-- Notification system
local NotifHolder

local function InitNotifHolder()
    if not NotifHolder then
        NotifHolder = Create("Frame", {
            Name = "NullLib_Notifs",
            Parent = CoreGui:FindFirstChild("NullLib_Root") or CoreGui,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -20, 1, -20),
            AnchorPoint = Vector2.new(1, 1),
            Size = UDim2.new(0, 280, 1, -20),
        })
        Create("UIListLayout", {
            Parent = NotifHolder,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 6),
        })
    end
end

function NullLib:Notify(options)
    InitNotifHolder()
    options = options or {}
    local title    = options.Title   or "NullLib"
    local desc     = options.Desc    or ""
    local duration = options.Duration or 4
    local ntype    = options.Type    or "Info" -- Info, Success, Warning, Error
    local theme    = self.Theme or DefaultTheme

    local typeColor = {
        Info    = theme.Accent,
        Success = theme.Success,
        Warning = theme.Warning,
        Error   = theme.Danger,
    }
    local accent = typeColor[ntype] or theme.Accent

    local notif = Create("Frame", {
        Parent = NotifHolder,
        BackgroundColor3 = theme.Surface,
        Size = UDim2.new(1, 0, 0, 70),
        ClipsDescendants = true,
    })
    MakeRound(notif, 8)
    MakeStroke(notif, theme.Border)

    local bar = Create("Frame", {
        Parent = notif,
        BackgroundColor3 = accent,
        Size = UDim2.new(0, 3, 1, 0),
    })
    MakeRound(bar, 2)

    Create("TextLabel", {
        Parent = notif,
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = theme.Text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 10),
        Size = UDim2.new(1, -20, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    Create("TextLabel", {
        Parent = notif,
        Text = desc,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = theme.TextDim,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 30),
        Size = UDim2.new(1, -20, 0, 30),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })

    -- progress bar
    local prog = Create("Frame", {
        Parent = notif,
        BackgroundColor3 = accent,
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BorderSizePixel = 0,
    })

    notif.BackgroundTransparency = 1
    Tween(notif, {BackgroundTransparency = 0}, 0.3)

    -- shrink progress
    Tween(prog, {Size = UDim2.new(0, 0, 0, 2)}, duration, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        Tween(notif, {BackgroundTransparency = 1}, 0.3)
        task.wait(0.3)
        notif:Destroy()
    end)
end

-- =============================================
--  WINDOW
-- =============================================
function NullLib:Window(options)
    options = options or {}
    local title   = options.Title   or "NullLib"
    local size    = options.Size    or UDim2.new(0, 560, 0, 380)
    local theme   = options.Theme   or DefaultTheme
    local logo    = options.Logo    or nil -- optional image id

    self.Theme = theme

    -- Root screen gui
    local Root = Create("ScreenGui", {
        Name = "NullLib_Root",
        Parent = CoreGui,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    })

    -- Main window frame
    local Main = Create("Frame", {
        Name = "Main",
        Parent = Root,
        BackgroundColor3 = theme.Background,
        Size = size,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ClipsDescendants = false,
    })
    MakeRound(Main, 10)
    MakeStroke(Main, theme.Border, 1)

    -- Drop shadow (fake)
    local Shadow = Create("ImageLabel", {
        Parent = Main,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, -15, 0, -15),
        Size = UDim2.new(1, 30, 1, 30),
        ZIndex = Main.ZIndex - 1,
        Image = "rbxassetid://6015897843",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
    })

    -- Title bar
    local TitleBar = Create("Frame", {
        Name = "TitleBar",
        Parent = Main,
        BackgroundColor3 = theme.Surface,
        Size = UDim2.new(1, 0, 0, 36),
    })
    Create("UICorner", {CornerRadius = UDim.new(0,10), Parent = TitleBar})
    -- flatten bottom corners
    Create("Frame", {
        Parent = TitleBar,
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0,0,0.5,0),
        Size = UDim2.new(1,0,0.5,0),
    })

    -- Logo/Icon
    local logoX = 8
    if logo then
        Create("ImageLabel", {
            Parent = TitleBar,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, 20, 0, 20),
            Image = logo,
        })
        logoX = 34
    end

    Create("TextLabel", {
        Parent = TitleBar,
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = theme.Text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, logoX, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- Watermark label in titlebar (right side)
    local WatermarkLabel = Create("TextLabel", {
        Parent = TitleBar,
        Text = "",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = theme.TextDim,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, -80, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    -- Close / Hide buttons
    local BtnHolder = Create("Frame", {
        Parent = TitleBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -60, 0, 0),
        Size = UDim2.new(0, 60, 1, 0),
    })
    Create("UIListLayout", {
        Parent = BtnHolder,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
    })
    MakePadding(BtnHolder, 0, 6, 0, 6)

    local function MakeBtn(txt, color)
        local b = Create("TextButton", {
            Parent = BtnHolder,
            Text = txt,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = color or theme.TextDim,
            BackgroundColor3 = theme.SurfaceHover,
            Size = UDim2.new(0, 22, 0, 22),
        })
        MakeRound(b, 4)
        return b
    end

    local HideBtn  = MakeBtn("—", theme.TextDim)
    local CloseBtn = MakeBtn("✕", theme.Danger)

    -- Tab bar (left sidebar)
    local TabBar = Create("ScrollingFrame", {
        Parent = Main,
        BackgroundColor3 = theme.Surface,
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(0, 110, 1, -36),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.ScrollBar,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    Create("UIListLayout", {
        Parent = TabBar,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })
    MakePadding(TabBar, 6, 4, 6, 4)

    -- flat right side on tab bar
    Create("Frame", {
        Parent = TabBar,
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -8, 0, 0),
        Size = UDim2.new(0, 8, 1, 0),
    })

    -- Content area
    local ContentArea = Create("Frame", {
        Parent = Main,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 114, 0, 36),
        Size = UDim2.new(1, -114, 1, -36),
        ClipsDescendants = true,
    })

    -- Separator between tab bar and content
    Create("Frame", {
        Parent = Main,
        BackgroundColor3 = theme.Border,
        Position = UDim2.new(0, 110, 0, 36),
        Size = UDim2.new(0, 1, 1, -36),
        BorderSizePixel = 0,
    })

    MakeDraggable(Main, TitleBar)

    local Window = {
        Root         = Root,
        Main         = Main,
        Theme        = theme,
        Tabs         = {},
        ActiveTab    = nil,
        Hidden       = false,
        Watermark    = WatermarkLabel,
    }

    -- Hide toggle
    CloseBtn.MouseButton1Click:Connect(function()
        Root:Destroy()
    end)

    local prevPos
    HideBtn.MouseButton1Click:Connect(function()
        Window.Hidden = not Window.Hidden
        if Window.Hidden then
            prevPos = Main.Position
            Tween(Main, {Size = UDim2.new(0, size.X.Offset, 0, 36)}, 0.2)
        else
            Tween(Main, {Size = size}, 0.2)
        end
    end)

    -- Watermark setter
    function Window:SetWatermark(text)
        WatermarkLabel.Text = text or ""
    end

    -- =============================================
    --  TAB
    -- =============================================
    function Window:Tab(name, icon)
        local tab = {
            Name     = name,
            Sections = {},
            Theme    = theme,
        }

        local TabBtn = Create("TextButton", {
            Parent = TabBar,
            Text = (icon and (icon .. "  ") or "") .. name,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = theme.TextDim,
            BackgroundColor3 = theme.Background,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        })
        MakeRound(TabBtn, 6)
        MakePadding(TabBtn, 0, 4, 0, 8)

        local Indicator = Create("Frame", {
            Parent = TabBtn,
            BackgroundColor3 = theme.Accent,
            Position = UDim2.new(0, 0, 0.15, 0),
            Size = UDim2.new(0, 3, 0.7, 0),
            BackgroundTransparency = 1,
        })
        MakeRound(Indicator, 2)

        -- Tab scroll container
        local TabContent = Create("ScrollingFrame", {
            Parent = ContentArea,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.ScrollBar,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        })

        local TabLayout = Create("UIListLayout", {
            Parent = TabContent,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        })
        MakePadding(TabContent, 10, 10, 10, 10)

        tab.Content = TabContent
        tab.Btn = TabBtn

        local function Activate()
            -- deactivate all
            for _, t in pairs(Window.Tabs) do
                t.Content.Visible = false
                Tween(t.Btn, {TextColor3 = theme.TextDim, BackgroundTransparency = 1}, 0.15)
                if t._indicator then
                    Tween(t._indicator, {BackgroundTransparency = 1}, 0.15)
                end
            end
            -- activate this
            TabContent.Visible = true
            Tween(TabBtn, {TextColor3 = theme.Text, BackgroundTransparency = 0.8}, 0.15)
            Tween(Indicator, {BackgroundTransparency = 0}, 0.15)
            Window.ActiveTab = tab
        end

        tab._indicator = Indicator
        tab._activate = Activate

        TabBtn.MouseButton1Click:Connect(Activate)
        TabBtn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= tab then
                Tween(TabBtn, {BackgroundTransparency = 0.9}, 0.1)
            end
        end)
        TabBtn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= tab then
                Tween(TabBtn, {BackgroundTransparency = 1}, 0.1)
            end
        end)

        table.insert(Window.Tabs, tab)
        if #Window.Tabs == 1 then Activate() end

        -- =============================================
        --  SECTION
        -- =============================================
        function tab:Section(name)
            local section = {Theme = theme}

            local SectionFrame = Create("Frame", {
                Parent = TabContent,
                BackgroundColor3 = theme.Surface,
                Size = UDim2.new(1, 0, 0, 30),
                AutomaticSize = Enum.AutomaticSize.Y,
                ClipsDescendants = false,
            })
            MakeRound(SectionFrame, 8)
            MakeStroke(SectionFrame, theme.Border)

            local SectionTitle = Create("TextLabel", {
                Parent = SectionFrame,
                Text = name or "",
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextColor3 = theme.Accent,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(1, 0, 0, 28),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            MakePadding(SectionTitle, 0, 0, 0, 10)

            Create("Frame", {
                Parent = SectionFrame,
                BackgroundColor3 = theme.Border,
                Position = UDim2.new(0, 10, 0, 28),
                Size = UDim2.new(1, -20, 0, 1),
                BorderSizePixel = 0,
            })

            local ItemHolder = Create("Frame", {
                Parent = SectionFrame,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 32),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            Create("UIListLayout", {
                Parent = ItemHolder,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 1),
            })
            MakePadding(ItemHolder, 4, 8, 8, 8)

            section.Items = ItemHolder
            section.Frame = SectionFrame

            -- =============================================
            --  TOGGLE
            -- =============================================
            function section:Toggle(options)
                options = options or {}
                local lbl     = options.Title   or "Toggle"
                local desc    = options.Desc    or nil
                local default = options.Default or false
                local cb      = options.Callback or function() end
                local flag    = options.Flag    or nil

                local val = default
                local Item = Create("Frame", {
                    Parent = ItemHolder,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                })

                Create("TextLabel", {
                    Parent = Item,
                    Text = lbl,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(1, -48, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })

                if desc then
                    Item.Size = UDim2.new(1, 0, 0, 46)
                    Create("TextLabel", {
                        Parent = Item,
                        Text = desc,
                        Font = Enum.Font.Gotham,
                        TextSize = 10,
                        TextColor3 = theme.TextDim,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 0, 0, 18),
                        Size = UDim2.new(1, -48, 0, 16),
                        TextXAlignment = Enum.TextXAlignment.Left,
                    })
                end

                local Track = Create("TextButton", {
                    Parent = Item,
                    Text = "",
                    BackgroundColor3 = val and theme.Toggle_On or theme.Toggle_Off,
                    Position = UDim2.new(1, -44, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Size = UDim2.new(0, 36, 0, 18),
                    AutoButtonColor = false,
                })
                MakeRound(Track, 9)

                local Knob = Create("Frame", {
                    Parent = Track,
                    BackgroundColor3 = Color3.new(1,1,1),
                    Position = val and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Size = UDim2.new(0, 14, 0, 14),
                })
                MakeRound(Knob, 7)

                local togObj = {Value = val}

                local function SetVal(v, silent)
                    val = v
                    togObj.Value = v
                    Tween(Track, {BackgroundColor3 = v and theme.Toggle_On or theme.Toggle_Off}, 0.15)
                    Tween(Knob, {Position = v and UDim2.new(1,-16,0.5,0) or UDim2.new(0,2,0.5,0)}, 0.15)
                    if not silent then
                        pcall(cb, v)
                    end
                    if flag then NullLib.Flags[flag] = v end
                end

                function togObj:Set(v) SetVal(v) end
                function togObj:Get() return val end

                Track.MouseButton1Click:Connect(function()
                    SetVal(not val)
                end)

                if flag then
                    if not NullLib.Flags then NullLib.Flags = {} end
                    NullLib.Flags[flag] = val
                end

                return togObj
            end

            -- =============================================
            --  BUTTON
            -- =============================================
            function section:Button(options)
                options = options or {}
                local lbl  = options.Title    or "Button"
                local desc = options.Desc     or nil
                local cb   = options.Callback or function() end

                local Item = Create("TextButton", {
                    Parent = ItemHolder,
                    Text = "",
                    BackgroundColor3 = theme.SurfaceHover,
                    Size = UDim2.new(1, 0, 0, 32),
                    AutoButtonColor = false,
                })
                MakeRound(Item, 6)

                Create("TextLabel", {
                    Parent = Item,
                    Text = lbl,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                })

                Item.MouseEnter:Connect(function()
                    Tween(Item, {BackgroundColor3 = theme.Accent}, 0.1)
                end)
                Item.MouseLeave:Connect(function()
                    Tween(Item, {BackgroundColor3 = theme.SurfaceHover}, 0.1)
                end)
                Item.MouseButton1Click:Connect(function()
                    Tween(Item, {BackgroundColor3 = theme.AccentDark}, 0.05)
                    task.delay(0.1, function()
                        Tween(Item, {BackgroundColor3 = theme.Accent}, 0.1)
                    end)
                    pcall(cb)
                end)

                local btnObj = {}
                function btnObj:SetTitle(t) end
                return btnObj
            end

            -- =============================================
            --  SLIDER
            -- =============================================
            function section:Slider(options)
                options = options or {}
                local lbl     = options.Title    or "Slider"
                local min     = options.Min      or 0
                local max     = options.Max      or 100
                local default = options.Default  or min
                local step    = options.Step     or 1
                local suffix  = options.Suffix   or ""
                local cb      = options.Callback or function() end
                local flag    = options.Flag     or nil

                local val = math.clamp(default, min, max)
                local dragging = false

                local Item = Create("Frame", {
                    Parent = ItemHolder,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 48),
                })

                local TopRow = Create("Frame", {
                    Parent = Item,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                })

                Create("TextLabel", {
                    Parent = TopRow,
                    Text = lbl,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -60, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })

                local ValLabel = Create("TextLabel", {
                    Parent = TopRow,
                    Text = tostring(val) .. suffix,
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    TextColor3 = theme.Accent,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -60, 0, 0),
                    Size = UDim2.new(0, 60, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Right,
                })

                local TrackBG = Create("Frame", {
                    Parent = Item,
                    BackgroundColor3 = theme.Border,
                    Position = UDim2.new(0, 0, 0, 28),
                    Size = UDim2.new(1, 0, 0, 6),
                })
                MakeRound(TrackBG, 3)

                local Fill = Create("Frame", {
                    Parent = TrackBG,
                    BackgroundColor3 = theme.Accent,
                    Size = UDim2.new((val - min) / (max - min), 0, 1, 0),
                })
                MakeRound(Fill, 3)

                local Knob = Create("Frame", {
                    Parent = TrackBG,
                    BackgroundColor3 = Color3.new(1,1,1),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new((val - min) / (max - min), 0, 0.5, 0),
                    Size = UDim2.new(0, 14, 0, 14),
                    ZIndex = 2,
                })
                MakeRound(Knob, 7)
                MakeStroke(Knob, theme.Accent, 2)

                local sliderObj = {Value = val}

                local function SetVal(v, silent)
                    if step and step > 0 then
                        v = math.round(v / step) * step
                    end
                    v = math.clamp(v, min, max)
                    val = v
                    sliderObj.Value = v
                    local pct = (v - min) / (max - min)
                    Fill.Size = UDim2.new(pct, 0, 1, 0)
                    Knob.Position = UDim2.new(pct, 0, 0.5, 0)
                    ValLabel.Text = tostring(v) .. suffix
                    if not silent then pcall(cb, v) end
                    if flag then NullLib.Flags[flag] = v end
                end

                function sliderObj:Set(v) SetVal(v) end
                function sliderObj:Get() return val end

                local function Update(input)
                    local pos = input.Position.X
                    local abs = TrackBG.AbsolutePosition.X
                    local wid = TrackBG.AbsoluteSize.X
                    local pct = math.clamp((pos - abs) / wid, 0, 1)
                    SetVal(min + (max - min) * pct)
                end

                TrackBG.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        Update(i)
                    end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                        Update(i)
                    end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)

                if flag then
                    if not NullLib.Flags then NullLib.Flags = {} end
                    NullLib.Flags[flag] = val
                end

                return sliderObj
            end

            -- =============================================
            --  DROPDOWN
            -- =============================================
            function section:Dropdown(options)
                options = options or {}
                local lbl      = options.Title    or "Dropdown"
                local items    = options.Items    or {}
                local default  = options.Default  or nil
                local multi    = options.Multi    or false
                local cb       = options.Callback or function() end
                local flag     = options.Flag     or nil

                local selected = multi and {} or default
                local open = false

                local Item = Create("Frame", {
                    Parent = ItemHolder,
                    BackgroundColor3 = theme.SurfaceHover,
                    Size = UDim2.new(1, 0, 0, 32),
                    ClipsDescendants = false,
                    ZIndex = 5,
                })
                MakeRound(Item, 6)

                Create("TextLabel", {
                    Parent = Item,
                    Text = lbl,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.TextDim,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 0, 0),
                    Size = UDim2.new(0.5, 0, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })

                local ValLabel = Create("TextLabel", {
                    Parent = Item,
                    Text = multi and "None" or (default or "Select..."),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.Text,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.5, 0, 0, 0),
                    Size = UDim2.new(0.5, -28, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ClipsDescendants = true,
                })

                local Arrow = Create("TextLabel", {
                    Parent = Item,
                    Text = "▾",
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    TextColor3 = theme.Accent,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -22, 0, 0),
                    Size = UDim2.new(0, 20, 1, 0),
                })

                -- Dropdown list
                local DropList = Create("Frame", {
                    Parent = Item,
                    BackgroundColor3 = theme.Background,
                    Position = UDim2.new(0, 0, 1, 4),
                    Size = UDim2.new(1, 0, 0, 0),
                    Visible = false,
                    ZIndex = 10,
                    ClipsDescendants = true,
                })
                MakeRound(DropList, 6)
                MakeStroke(DropList, theme.Border)

                local DropLayout = Create("UIListLayout", {
                    Parent = DropList,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 1),
                })
                MakePadding(DropList, 4, 4, 4, 4)

                local dropObj = {Value = selected}
                local itemBtns = {}

                local function UpdateLabel()
                    if multi then
                        local sel = {}
                        for k in pairs(selected) do table.insert(sel, k) end
                        ValLabel.Text = #sel > 0 and table.concat(sel, ", ") or "None"
                    else
                        ValLabel.Text = selected or "Select..."
                    end
                end

                local function BuildItems()
                    for _, b in pairs(itemBtns) do b:Destroy() end
                    itemBtns = {}

                    for _, item in pairs(items) do
                        local isSelected = multi and selected[item] or selected == item
                        local Btn = Create("TextButton", {
                            Parent = DropList,
                            Text = item,
                            Font = Enum.Font.Gotham,
                            TextSize = 12,
                            TextColor3 = isSelected and theme.Accent or theme.Text,
                            BackgroundColor3 = isSelected and theme.SurfaceHover or theme.Surface,
                            BackgroundTransparency = isSelected and 0 or 0.5,
                            Size = UDim2.new(1, 0, 0, 26),
                            ZIndex = 11,
                            AutoButtonColor = false,
                        })
                        MakeRound(Btn, 4)

                        Btn.MouseButton1Click:Connect(function()
                            if multi then
                                if selected[item] then
                                    selected[item] = nil
                                else
                                    selected[item] = true
                                end
                            else
                                selected = item
                                -- close
                                open = false
                                Tween(DropList, {Size = UDim2.new(1, 0, 0, 0)}, 0.15)
                                task.delay(0.15, function() DropList.Visible = false end)
                            end
                            dropObj.Value = selected
                            UpdateLabel()
                            BuildItems()
                            if flag then NullLib.Flags[flag] = selected end
                            pcall(cb, selected)
                        end)

                        table.insert(itemBtns, Btn)
                    end

                    local h = math.min(#items * 27 + 8, 160)
                    DropList.CanvasSize = UDim2.new(0, 0, 0, DropLayout.AbsoluteContentSize.Y + 8)
                    if type(DropList.Size) == "UDim2" and open then
                        Tween(DropList, {Size = UDim2.new(1, 0, 0, h)}, 0.15)
                    end
                end

                BuildItems()

                local ClickBtn = Create("TextButton", {
                    Parent = Item,
                    Text = "",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    ZIndex = 6,
                })

                ClickBtn.MouseButton1Click:Connect(function()
                    open = not open
                    if open then
                        DropList.Visible = true
                        BuildItems()
                        local h = math.min(#items * 27 + 8, 160)
                        Tween(DropList, {Size = UDim2.new(1, 0, 0, h)}, 0.15)
                        Tween(Arrow, {Rotation = 180}, 0.15)
                    else
                        Tween(DropList, {Size = UDim2.new(1, 0, 0, 0)}, 0.15)
                        task.delay(0.15, function() DropList.Visible = false end)
                        Tween(Arrow, {Rotation = 0}, 0.15)
                    end
                end)

                function dropObj:Set(v)
                    selected = v
                    dropObj.Value = v
                    UpdateLabel()
                    BuildItems()
                    if flag then NullLib.Flags[flag] = v end
                end
                function dropObj:Get() return selected end
                function dropObj:Refresh(newItems)
                    items = newItems
                    BuildItems()
                end

                if flag then
                    if not NullLib.Flags then NullLib.Flags = {} end
                    NullLib.Flags[flag] = selected
                end

                return dropObj
            end

            -- =============================================
            --  TEXTBOX
            -- =============================================
            function section:Textbox(options)
                options = options or {}
                local lbl        = options.Title       or "Textbox"
                local placeholder = options.Placeholder or "Type here..."
                local default    = options.Default     or ""
                local numeric    = options.Numeric     or false
                local cb         = options.Callback    or function() end
                local flag       = options.Flag        or nil

                local Item = Create("Frame", {
                    Parent = ItemHolder,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 52),
                })

                Create("TextLabel", {
                    Parent = Item,
                    Text = lbl,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })

                local Box = Create("TextBox", {
                    Parent = Item,
                    Text = default,
                    PlaceholderText = placeholder,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.Text,
                    PlaceholderColor3 = theme.TextDim,
                    BackgroundColor3 = theme.Background,
                    Position = UDim2.new(0, 0, 0, 24),
                    Size = UDim2.new(1, 0, 0, 26),
                    ClearTextOnFocus = false,
                })
                MakeRound(Box, 6)
                MakeStroke(Box, theme.Border)
                MakePadding(Box, 0, 6, 0, 6)

                Box.Focused:Connect(function()
                    Tween(Box, {}, 0.1)
                    MakeStroke(Box, theme.Accent)
                end)
                Box.FocusLost:Connect(function(enter)
                    MakeStroke(Box, theme.Border)
                    if numeric then
                        local n = tonumber(Box.Text)
                        Box.Text = n and tostring(n) or "0"
                    end
                    if flag then NullLib.Flags[flag] = Box.Text end
                    if enter then pcall(cb, Box.Text) end
                end)

                local tbObj = {}
                function tbObj:Set(v) Box.Text = tostring(v) end
                function tbObj:Get() return Box.Text end

                if flag then
                    if not NullLib.Flags then NullLib.Flags = {} end
                    NullLib.Flags[flag] = default
                end

                return tbObj
            end

            -- =============================================
            --  KEYBIND
            -- =============================================
            function section:Keybind(options)
                options = options or {}
                local lbl      = options.Title    or "Keybind"
                local default  = options.Default  or Enum.KeyCode.Unknown
                local mode     = options.Mode     or "Press" -- Press, Hold, Always
                local cb       = options.Callback or function() end
                local flag     = options.Flag     or nil

                local boundKey  = default
                local bindMode  = mode
                local listening = false
                local held      = false
                local alwaysConn

                local Item = Create("Frame", {
                    Parent = ItemHolder,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                })

                Create("TextLabel", {
                    Parent = Item,
                    Text = lbl,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -120, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })

                local KeyBtn = Create("TextButton", {
                    Parent = Item,
                    Text = boundKey.Name,
                    Font = Enum.Font.GothamBold,
                    TextSize = 11,
                    TextColor3 = theme.Accent,
                    BackgroundColor3 = theme.Background,
                    Position = UDim2.new(1, -115, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Size = UDim2.new(0, 60, 0, 22),
                    AutoButtonColor = false,
                })
                MakeRound(KeyBtn, 4)
                MakeStroke(KeyBtn, theme.Border)

                -- Mode button (right-click cycles mode)
                local ModeBtn = Create("TextButton", {
                    Parent = Item,
                    Text = bindMode,
                    Font = Enum.Font.Gotham,
                    TextSize = 10,
                    TextColor3 = theme.TextDim,
                    BackgroundColor3 = theme.Surface,
                    Position = UDim2.new(1, -50, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Size = UDim2.new(0, 48, 0, 22),
                    AutoButtonColor = false,
                })
                MakeRound(ModeBtn, 4)
                MakeStroke(ModeBtn, theme.Border)

                local modes = {"Press", "Hold", "Always"}

                local kbObj = {Key = boundKey, Mode = bindMode}

                local function SetMode(m)
                    bindMode = m
                    kbObj.Mode = m
                    ModeBtn.Text = m
                    if m == "Always" then
                        alwaysConn = RunService.Heartbeat:Connect(function()
                            pcall(cb, true)
                        end)
                    else
                        if alwaysConn then alwaysConn:Disconnect(); alwaysConn = nil end
                    end
                end

                -- Right click = context menu for mode
                ModeBtn.MouseButton2Click:Connect(function()
                    -- cycle
                    local idx = table.find(modes, bindMode) or 1
                    idx = (idx % #modes) + 1
                    SetMode(modes[idx])
                end)
                ModeBtn.MouseButton1Click:Connect(function()
                    local idx = table.find(modes, bindMode) or 1
                    idx = (idx % #modes) + 1
                    SetMode(modes[idx])
                end)

                -- Keybind popup on right click of KeyBtn
                KeyBtn.MouseButton2Click:Connect(function()
                    listening = true
                    KeyBtn.Text = "..."
                    KeyBtn.TextColor3 = theme.Warning
                end)
                KeyBtn.MouseButton1Click:Connect(function()
                    listening = true
                    KeyBtn.Text = "..."
                    KeyBtn.TextColor3 = theme.Warning
                end)

                UserInputService.InputBegan:Connect(function(input, gpe)
                    if listening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            boundKey = input.KeyCode
                            kbObj.Key = boundKey
                            KeyBtn.Text = boundKey.Name
                            KeyBtn.TextColor3 = theme.Accent
                            listening = false
                            if flag then NullLib.Flags[flag] = boundKey end
                        end
                        return
                    end

                    if input.KeyCode == boundKey and not gpe then
                        if bindMode == "Press" then
                            pcall(cb, true)
                        elseif bindMode == "Hold" then
                            held = true
                            pcall(cb, true)
                        end
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.KeyCode == boundKey and bindMode == "Hold" and held then
                        held = false
                        pcall(cb, false)
                    end
                end)

                function kbObj:Set(key) boundKey = key; KeyBtn.Text = key.Name; kbObj.Key = key end
                function kbObj:SetMode(m) SetMode(m) end

                if flag then
                    if not NullLib.Flags then NullLib.Flags = {} end
                    NullLib.Flags[flag] = boundKey
                end

                return kbObj
            end

            -- =============================================
            --  COLOR PICKER
            -- =============================================
            function section:ColorPicker(options)
                options = options or {}
                local lbl     = options.Title    or "Color"
                local default = options.Default  or Color3.fromRGB(255, 80, 80)
                local cb      = options.Callback or function() end
                local flag    = options.Flag     or nil

                local color = default
                local hue, sat, val2 = Color3.toHSV(color)
                local open = false
                local draggingSV, draggingH = false, false

                local Item = Create("Frame", {
                    Parent = ItemHolder,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                    ClipsDescendants = false,
                    ZIndex = 5,
                })

                Create("TextLabel", {
                    Parent = Item,
                    Text = lbl,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = theme.Text,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -44, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })

                local Preview = Create("TextButton", {
                    Parent = Item,
                    Text = "",
                    BackgroundColor3 = color,
                    Position = UDim2.new(1, -36, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Size = UDim2.new(0, 28, 0, 20),
                    AutoButtonColor = false,
                })
                MakeRound(Preview, 4)
                MakeStroke(Preview, theme.Border)

                -- Picker frame
                local Picker = Create("Frame", {
                    Parent = Item,
                    BackgroundColor3 = theme.Background,
                    Position = UDim2.new(0, 0, 1, 6),
                    Size = UDim2.new(1, 0, 0, 160),
                    Visible = false,
                    ZIndex = 15,
                    ClipsDescendants = false,
                })
                MakeRound(Picker, 8)
                MakeStroke(Picker, theme.Border)

                -- SV square
                local SVBox = Create("ImageLabel", {
                    Parent = Picker,
                    Position = UDim2.new(0, 8, 0, 8),
                    Size = UDim2.new(1, -60, 1, -16),
                    Image = "rbxassetid://6020299385",
                    ImageColor3 = Color3.fromHSV(hue, 1, 1),
                    ZIndex = 16,
                })
                MakeRound(SVBox, 4)

                -- white-to-transparent overlay
                Create("ImageLabel", {
                    Parent = SVBox,
                    Size = UDim2.new(1,0,1,0),
                    Image = "rbxassetid://6020299416",
                    ZIndex = 17,
                })
                -- black-to-transparent overlay
                Create("ImageLabel", {
                    Parent = SVBox,
                    Size = UDim2.new(1,0,1,0),
                    Image = "rbxassetid://6020299440",
                    ZIndex = 18,
                })

                local SVCursor = Create("Frame", {
                    Parent = SVBox,
                    BackgroundColor3 = Color3.new(1,1,1),
                    AnchorPoint = Vector2.new(0.5,0.5),
                    Position = UDim2.new(sat, 0, 1 - val2, 0),
                    Size = UDim2.new(0, 10, 0, 10),
                    ZIndex = 19,
                })
                MakeRound(SVCursor, 5)
                MakeStroke(SVCursor, Color3.new(0,0,0), 1)

                -- Hue bar
                local HueBar = Create("ImageLabel", {
                    Parent = Picker,
                    Image = "rbxassetid://6020299499",
                    Position = UDim2.new(1, -44, 0, 8),
                    Size = UDim2.new(0, 14, 1, -50),
                    ZIndex = 16,
                })
                MakeRound(HueBar, 4)

                local HueCursor = Create("Frame", {
                    Parent = HueBar,
                    BackgroundColor3 = Color3.new(1,1,1),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, hue, 0),
                    Size = UDim2.new(1, 4, 0, 4),
                    ZIndex = 17,
                })
                MakeRound(HueCursor, 2)
                MakeStroke(HueCursor, Color3.new(0,0,0), 1)

                -- Hex input
                local HexBox = Create("TextBox", {
                    Parent = Picker,
                    Text = ColorToHex(color),
                    Font = Enum.Font.Code,
                    TextSize = 11,
                    TextColor3 = theme.Text,
                    BackgroundColor3 = theme.Surface,
                    Position = UDim2.new(1, -44, 1, -36),
                    Size = UDim2.new(0, 40, 0, 22),
                    ZIndex = 16,
                })
                MakeRound(HexBox, 4)
                MakeStroke(HexBox, theme.Border)
                MakePadding(HexBox, 0, 4, 0, 4)

                local cpObj = {Value = color}

                local function UpdateColor()
                    color = Color3.fromHSV(hue, sat, val2)
                    cpObj.Value = color
                    Preview.BackgroundColor3 = color
                    SVBox.ImageColor3 = Color3.fromHSV(hue, 1, 1)
                    SVCursor.Position = UDim2.new(sat, 0, 1 - val2, 0)
                    HueCursor.Position = UDim2.new(0.5, 0, hue, 0)
                    HexBox.Text = ColorToHex(color)
                    pcall(cb, color)
                    if flag then NullLib.Flags[flag] = color end
                end

                SVBox.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        draggingSV = true
                    end
                end)
                HueBar.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        draggingH = true
                    end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        draggingSV = false; draggingH = false
                    end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseMovement then
                        if draggingSV then
                            local rel = i.Position - SVBox.AbsolutePosition
                            sat = math.clamp(rel.X / SVBox.AbsoluteSize.X, 0, 1)
                            val2 = 1 - math.clamp(rel.Y / SVBox.AbsoluteSize.Y, 0, 1)
                            UpdateColor()
                        elseif draggingH then
                            local rel = i.Position - HueBar.AbsolutePosition
                            hue = math.clamp(rel.Y / HueBar.AbsoluteSize.Y, 0, 1)
                            UpdateColor()
                        end
                    end
                end)

                HexBox.FocusLost:Connect(function()
                    local ok, c = pcall(HexToColor, HexBox.Text)
                    if ok then
                        color = c
                        hue, sat, val2 = Color3.toHSV(c)
                        UpdateColor()
                    end
                end)

                Preview.MouseButton1Click:Connect(function()
                    open = not open
                    Picker.Visible = open
                end)

                function cpObj:Set(c)
                    color = c; hue, sat, val2 = Color3.toHSV(c)
                    Preview.BackgroundColor3 = c
                    UpdateColor()
                end
                function cpObj:Get() return color end

                if flag then
                    if not NullLib.Flags then NullLib.Flags = {} end
                    NullLib.Flags[flag] = color
                end

                return cpObj
            end

            -- =============================================
            --  LABEL
            -- =============================================
            function section:Label(text, color)
                local lbl = Create("TextLabel", {
                    Parent = ItemHolder,
                    Text = text or "",
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = color or theme.TextDim,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                local lblObj = {}
                function lblObj:Set(t) lbl.Text = t end
                return lblObj
            end

            -- =============================================
            --  SEPARATOR
            -- =============================================
            function section:Separator()
                Create("Frame", {
                    Parent = ItemHolder,
                    BackgroundColor3 = theme.Border,
                    Size = UDim2.new(1, 0, 0, 1),
                    BorderSizePixel = 0,
                })
            end

            return section
        end

        return tab
    end

    -- =============================================
    --  SETTINGS TAB (auto-built in)
    -- =============================================
    local SettingsTab = Window:Tab("⚙ Settings")
    local UISection = SettingsTab:Section("Interface")

    UISection:Toggle({
        Title = "Hide on Key",
        Desc  = "Press RightAlt to toggle UI",
        Default = false,
        Callback = function(v)
            if v then
                UserInputService.InputBegan:Connect(function(i)
                    if i.KeyCode == Enum.KeyCode.RightAlt then
                        Window.Hidden = not Window.Hidden
                        Main.Visible = not Window.Hidden
                    end
                end)
            end
        end,
    })

    UISection:Dropdown({
        Title = "Accent Color",
        Items = {"Purple", "Blue", "Red", "Green", "Orange", "Pink"},
        Default = "Purple",
        Callback = function(v)
            local map = {
                Purple = Color3.fromRGB(120, 80, 255),
                Blue   = Color3.fromRGB(60, 130, 255),
                Red    = Color3.fromRGB(220, 60, 60),
                Green  = Color3.fromRGB(60, 200, 100),
                Orange = Color3.fromRGB(220, 140, 40),
                Pink   = Color3.fromRGB(220, 80, 180),
            }
            theme.Accent = map[v] or theme.Accent
        end,
    })

    UISection:Slider({
        Title   = "UI Transparency",
        Min     = 0, Max = 80, Default = 0, Step = 5,
        Suffix  = "%",
        Callback = function(v)
            Main.BackgroundTransparency = v / 100
        end,
    })

    local WMSection = SettingsTab:Section("Watermark")
    WMSection:Toggle({
        Title = "Show Watermark",
        Default = false,
        Callback = function(v)
            WatermarkLabel.Visible = v
        end,
    })
    WMSection:Textbox({
        Title = "Watermark Text",
        Placeholder = "NullLib | v1.0",
        Callback = function(v)
            WatermarkLabel.Text = v
        end,
    })

    return Window
end

-- Init flags table
NullLib.Flags = {}

return NullLib
