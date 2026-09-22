--[[
    NyxLine UI Library
    Custom exploit hub UI framework
    Draggable windows, tabs, toggles, sliders, dropdowns, keybinds, notifications
]]

local NyxLine = {}
NyxLine.__index = NyxLine

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Theme
local Theme = {
    Background = Color3.fromRGB(18, 18, 24),
    Surface = Color3.fromRGB(24, 24, 32),
    SurfaceAlt = Color3.fromRGB(30, 30, 40),
    Accent = Color3.fromRGB(138, 43, 226),
    AccentDark = Color3.fromRGB(100, 30, 170),
    Text = Color3.fromRGB(230, 230, 240),
    TextDim = Color3.fromRGB(140, 140, 160),
    Success = Color3.fromRGB(80, 200, 120),
    Error = Color3.fromRGB(220, 60, 60),
    Warning = Color3.fromRGB(240, 180, 40),
    Border = Color3.fromRGB(45, 45, 60),
    Toggle = Color3.fromRGB(50, 50, 65),
    Slider = Color3.fromRGB(40, 40, 55),
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    CornerRadius = UDim.new(0, 6),
    TweenSpeed = 0.2,
}

-- Utilities
local function tween(obj, props, duration)
    local t = TweenService:Create(obj, TweenInfo.new(duration or Theme.TweenSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" and k ~= "Children" then
            inst[k] = v
        end
    end
    if props.Children then
        for _, child in ipairs(props.Children) do
            child.Parent = inst
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = radius or Theme.CornerRadius,
        Parent = parent,
    })
end

local function addStroke(parent, color, thickness)
    return create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Parent = parent,
    })
end

local function addPadding(parent, t, b, l, r)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, t or 8),
        PaddingBottom = UDim.new(0, b or 8),
        PaddingLeft = UDim.new(0, l or 8),
        PaddingRight = UDim.new(0, r or 8),
        Parent = parent,
    })
end

------------------------------------------------------------------------
-- Notification System
------------------------------------------------------------------------

local NotificationHolder

local Notifications = {}

function Notifications:Init(screenGui)
    NotificationHolder = create("Frame", {
        Name = "Notifications",
        Size = UDim2.new(0, 280, 1, 0),
        Position = UDim2.new(1, -290, 0, 0),
        BackgroundTransparency = 1,
        Parent = screenGui,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Parent = NotificationHolder,
    })
    addPadding(NotificationHolder, 0, 10, 0, 0)
end

function Notifications:Notification(config)
    local title = config.Title or "NyxLine"
    local text = config.Text or ""
    local duration = config.Duration or 5

    local notifFrame = create("Frame", {
        Name = "Notification",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface,
        Parent = NotificationHolder,
    })
    addCorner(notifFrame)
    addStroke(notifFrame, Theme.Accent, 1)

    local accent = create("Frame", {
        Size = UDim2.new(0, 3, 1, -8),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = notifFrame,
    })
    addCorner(accent, UDim.new(0, 2))

    local content = create("Frame", {
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Parent = notifFrame,
    })
    addPadding(content, 8, 8, 0, 4)

    create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Accent,
        Font = Theme.FontBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = content,
    })

    create("TextLabel", {
        Name = "Body",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.TextDim,
        Font = Theme.Font,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Parent = content,
    })

    notifFrame.BackgroundTransparency = 1
    tween(notifFrame, {BackgroundTransparency = 0}, 0.3)

    task.delay(duration, function()
        local t = tween(notifFrame, {BackgroundTransparency = 1}, 0.3)
        t.Completed:Wait()
        notifFrame:Destroy()
    end)
end

------------------------------------------------------------------------
-- Main Window
------------------------------------------------------------------------

function NyxLine:CreateWindow(config)
    local windowTitle = config.Title or "NyxLine"
    local windowSize = config.Size or UDim2.new(0, 520, 0, 380)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl

    local screenGui = create("ScreenGui", {
        Name = "NyxLine",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    if syn and syn.protect_gui then
        syn.protect_gui(screenGui)
    end

    screenGui.Parent = (getfenv().gethui and getfenv().gethui()) or game:GetService("CoreGui")

    Notifications:Init(screenGui)

    local window = {
        Gui = screenGui,
        Tabs = {},
        ActiveTab = nil,
        Visible = true,
        Notifications = Notifications,
    }

    -- Main frame
    local mainFrame = create("Frame", {
        Name = "Main",
        Size = windowSize,
        Position = UDim2.new(0.5, -windowSize.X.Offset / 2, 0.5, -windowSize.Y.Offset / 2),
        BackgroundColor3 = Theme.Background,
        Parent = screenGui,
    })
    addCorner(mainFrame, UDim.new(0, 8))
    addStroke(mainFrame, Theme.Border, 1)

    -- Shadow
    create("ImageLabel", {
        Name = "Shadow",
        Size = UDim2.new(1, 30, 1, 30),
        Position = UDim2.new(0, -15, 0, -15),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = -1,
        Parent = mainFrame,
    })

    -- Title bar
    local titleBar = create("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = mainFrame,
    })
    addCorner(titleBar, UDim.new(0, 8))

    -- Square off bottom corners of title bar
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = titleBar,
    })

    -- Title text
    create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = windowTitle,
        TextColor3 = Theme.Accent,
        Font = Theme.FontBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar,
    })

    -- Minimize button
    local minimizeBtn = create("TextButton", {
        Name = "Minimize",
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -68, 0, 4),
        BackgroundColor3 = Theme.SurfaceAlt,
        Text = "—",
        TextColor3 = Theme.TextDim,
        Font = Theme.FontBold,
        TextSize = 14,
        Parent = titleBar,
    })
    addCorner(minimizeBtn, UDim.new(0, 4))

    -- Close button
    local closeBtn = create("TextButton", {
        Name = "Close",
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -36, 0, 4),
        BackgroundColor3 = Theme.Error,
        BackgroundTransparency = 0.7,
        Text = "×",
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 16,
        Parent = titleBar,
    })
    addCorner(closeBtn, UDim.new(0, 4))

    -- Dragging
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Tab sidebar
    local tabSidebar = create("Frame", {
        Name = "TabSidebar",
        Size = UDim2.new(0, 120, 1, -38),
        Position = UDim2.new(0, 0, 0, 37),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = mainFrame,
    })
    addCorner(tabSidebar, UDim.new(0, 8))
    create("Frame", {
        Size = UDim2.new(0, 10, 1, 0),
        Position = UDim2.new(1, -10, 0, 0),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = tabSidebar,
    })

    local tabList = create("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, -4),
        Position = UDim2.new(0, 0, 0, 4),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = tabSidebar,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabList,
    })
    addPadding(tabList, 4, 4, 6, 6)

    -- Content area
    local contentArea = create("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -124, 1, -40),
        Position = UDim2.new(0, 122, 0, 38),
        BackgroundColor3 = Theme.SurfaceAlt,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = mainFrame,
    })
    addCorner(contentArea, UDim.new(0, 6))

    -- Toggle visibility
    local function toggleWindow()
        window.Visible = not window.Visible
        mainFrame.Visible = window.Visible
    end

    minimizeBtn.MouseButton1Click:Connect(toggleWindow)
    closeBtn.MouseButton1Click:Connect(toggleWindow)

    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == toggleKey then
            toggleWindow()
        end
    end)

    -- Tab switching
    local function switchTab(tabName)
        for name, tab in pairs(window.Tabs) do
            tab.Button.BackgroundColor3 = (name == tabName) and Theme.Accent or Theme.Surface
            tab.Button.BackgroundTransparency = (name == tabName) and 0.8 or 1
            local label = tab.Button:FindFirstChild("Label")
            if label then
                label.TextColor3 = (name == tabName) and Theme.Text or Theme.TextDim
            end
            tab.Content.Visible = (name == tabName)
        end
        window.ActiveTab = tabName
    end

    --------------------------------------------------------------------
    -- Tab Creation
    --------------------------------------------------------------------

    function window:CreateTab(config)
        local tabName = config.Name or "Tab"
        local tabIcon = config.Icon or ""

        local tabBtn = create("TextButton", {
            Name = tabName,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = 1,
            Text = "",
            Parent = tabList,
        })
        addCorner(tabBtn, UDim.new(0, 4))

        create("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, -8, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = (tabIcon ~= "" and (tabIcon .. "  ") or "") .. tabName,
            TextColor3 = Theme.TextDim,
            Font = Theme.Font,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = tabBtn,
        })

        tabBtn.MouseEnter:Connect(function()
            if window.ActiveTab ~= tabName then
                tween(tabBtn, {BackgroundTransparency = 0.9}, 0.15)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if window.ActiveTab ~= tabName then
                tween(tabBtn, {BackgroundTransparency = 1}, 0.15)
            end
        end)

        local tabContent = create("ScrollingFrame", {
            Name = tabName,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = contentArea,
        })
        create("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = tabContent,
        })
        addPadding(tabContent, 6, 6, 8, 8)

        window.Tabs[tabName] = {
            Button = tabBtn,
            Content = tabContent,
        }

        tabBtn.MouseButton1Click:Connect(function()
            switchTab(tabName)
        end)

        if not window.ActiveTab then
            switchTab(tabName)
        end

        local tab = {}

        ----------------------------------------------------------------
        -- Section
        ----------------------------------------------------------------

        function tab:CreateSection(name)
            local section = create("Frame", {
                Name = "Section_" .. name,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = tabContent,
            })

            create("TextLabel", {
                Name = "Header",
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Text = name:upper(),
                TextColor3 = Theme.TextDim,
                Font = Theme.FontBold,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = section,
            })

            create("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 0, 20),
                BackgroundColor3 = Theme.Border,
                BorderSizePixel = 0,
                Parent = section,
            })

            return section
        end

        ----------------------------------------------------------------
        -- Toggle
        ----------------------------------------------------------------

        function tab:CreateToggle(config)
            local name = config.Name or "Toggle"
            local default = config.Default or false
            local callback = config.Callback or function() end

            local state = default

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = Theme.Surface,
                Parent = tabContent,
            })
            addCorner(holder)

            create("TextLabel", {
                Size = UDim2.new(1, -60, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Theme.Font,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })

            local toggleFrame = create("Frame", {
                Size = UDim2.new(0, 38, 0, 20),
                Position = UDim2.new(1, -48, 0.5, -10),
                BackgroundColor3 = state and Theme.Accent or Theme.Toggle,
                Parent = holder,
            })
            addCorner(toggleFrame, UDim.new(1, 0))

            local toggleCircle = create("Frame", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                BackgroundColor3 = Theme.Text,
                Parent = toggleFrame,
            })
            addCorner(toggleCircle, UDim.new(1, 0))

            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                Parent = holder,
            })

            local function updateVisual()
                tween(toggleFrame, {BackgroundColor3 = state and Theme.Accent or Theme.Toggle})
                tween(toggleCircle, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)})
            end

            btn.MouseButton1Click:Connect(function()
                state = not state
                updateVisual()
                callback(state)
            end)

            local toggleObj = {}
            function toggleObj:Set(value)
                state = value
                updateVisual()
                callback(state)
            end
            function toggleObj:Get()
                return state
            end
            return toggleObj
        end

        ----------------------------------------------------------------
        -- Slider
        ----------------------------------------------------------------

        function tab:CreateSlider(config)
            local name = config.Name or "Slider"
            local min = config.Min or 0
            local max = config.Max or 100
            local default = config.Default or min
            local increment = config.Increment or 1
            local callback = config.Callback or function() end

            local value = default

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 48),
                BackgroundColor3 = Theme.Surface,
                Parent = tabContent,
            })
            addCorner(holder)

            local valueLabel = create("TextLabel", {
                Size = UDim2.new(0, 40, 0, 20),
                Position = UDim2.new(1, -50, 0, 4),
                BackgroundTransparency = 1,
                Text = tostring(value),
                TextColor3 = Theme.Accent,
                Font = Theme.FontBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = holder,
            })

            create("TextLabel", {
                Size = UDim2.new(1, -60, 0, 20),
                Position = UDim2.new(0, 10, 0, 4),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Theme.Font,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })

            local sliderBg = create("Frame", {
                Size = UDim2.new(1, -20, 0, 6),
                Position = UDim2.new(0, 10, 0, 32),
                BackgroundColor3 = Theme.Slider,
                Parent = holder,
            })
            addCorner(sliderBg, UDim.new(1, 0))

            local sliderFill = create("Frame", {
                Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                Parent = sliderBg,
            })
            addCorner(sliderFill, UDim.new(1, 0))

            local sliding = false

            local inputBtn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                Position = UDim2.new(0, 0, 0, 24),
                BackgroundTransparency = 1,
                Text = "",
                Parent = holder,
            })

            local function update(input)
                local pos = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
                local rawVal = min + (max - min) * pos
                value = math.floor(rawVal / increment + 0.5) * increment
                value = math.clamp(value, min, max)
                valueLabel.Text = tostring(value)
                tween(sliderFill, {Size = UDim2.new((value - min) / (max - min), 0, 1, 0)}, 0.05)
                callback(value)
            end

            inputBtn.MouseButton1Down:Connect(function()
                sliding = true
            end)

            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = false
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
                    update(input)
                end
            end)

            inputBtn.MouseButton1Click:Connect(function()
                local input = {Position = Vector2.new(Mouse.X, Mouse.Y)}
                input.Position = {X = Mouse.X}
                local pos = math.clamp((Mouse.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
                local rawVal = min + (max - min) * pos
                value = math.floor(rawVal / increment + 0.5) * increment
                value = math.clamp(value, min, max)
                valueLabel.Text = tostring(value)
                tween(sliderFill, {Size = UDim2.new((value - min) / (max - min), 0, 1, 0)}, 0.05)
                callback(value)
            end)

            local sliderObj = {}
            function sliderObj:Set(val)
                value = math.clamp(val, min, max)
                valueLabel.Text = tostring(value)
                sliderFill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
                callback(value)
            end
            function sliderObj:Get()
                return value
            end
            return sliderObj
        end

        ----------------------------------------------------------------
        -- Dropdown
        ----------------------------------------------------------------

        function tab:CreateDropdown(config)
            local name = config.Name or "Dropdown"
            local options = config.Options or {}
            local default = config.Default or (options[1] or "")
            local callback = config.Callback or function() end

            local selected = default
            local open = false

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = Theme.Surface,
                ClipsDescendants = true,
                Parent = tabContent,
            })
            addCorner(holder)

            create("TextLabel", {
                Size = UDim2.new(0.5, -10, 0, 32),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Theme.Font,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })

            local selectedLabel = create("TextLabel", {
                Size = UDim2.new(0.5, -20, 0, 32),
                Position = UDim2.new(0.5, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = selected .. "  ▼",
                TextColor3 = Theme.Accent,
                Font = Theme.Font,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = holder,
            })

            local optionList = create("Frame", {
                Size = UDim2.new(1, -8, 0, 0),
                Position = UDim2.new(0, 4, 0, 34),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = holder,
            })
            create("UIListLayout", {
                Padding = UDim.new(0, 2),
                Parent = optionList,
            })

            local function buildOptions()
                for _, child in ipairs(optionList:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for _, opt in ipairs(options) do
                    local optBtn = create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundColor3 = Theme.SurfaceAlt,
                        Text = opt,
                        TextColor3 = (opt == selected) and Theme.Accent or Theme.TextDim,
                        Font = Theme.Font,
                        TextSize = 12,
                        Parent = optionList,
                    })
                    addCorner(optBtn, UDim.new(0, 4))

                    optBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        selectedLabel.Text = selected .. "  ▼"
                        open = false
                        tween(holder, {Size = UDim2.new(1, 0, 0, 32)})
                        buildOptions()
                        callback(selected)
                    end)
                end
            end
            buildOptions()

            local toggleBtn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundTransparency = 1,
                Text = "",
                Parent = holder,
            })

            toggleBtn.MouseButton1Click:Connect(function()
                open = not open
                local targetHeight = open and (34 + #options * 28 + 8) or 32
                tween(holder, {Size = UDim2.new(1, 0, 0, targetHeight)})
            end)

            local dropObj = {}
            function dropObj:Set(val)
                selected = val
                selectedLabel.Text = selected .. "  ▼"
                buildOptions()
                callback(selected)
            end
            function dropObj:Get()
                return selected
            end
            function dropObj:SetOptions(newOpts)
                options = newOpts
                buildOptions()
            end
            return dropObj
        end

        ----------------------------------------------------------------
        -- Button
        ----------------------------------------------------------------

        function tab:CreateButton(config)
            local name = config.Name or "Button"
            local callback = config.Callback or function() end

            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = Theme.Surface,
                Text = "",
                Parent = tabContent,
            })
            addCorner(btn)

            create("TextLabel", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Theme.Font,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = btn,
            })

            btn.MouseEnter:Connect(function()
                tween(btn, {BackgroundColor3 = Theme.SurfaceAlt}, 0.15)
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, {BackgroundColor3 = Theme.Surface}, 0.15)
            end)
            btn.MouseButton1Click:Connect(callback)
        end

        ----------------------------------------------------------------
        -- Label
        ----------------------------------------------------------------

        function tab:CreateLabel(text)
            local label = create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Theme.TextDim,
                Font = Theme.Font,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = tabContent,
            })

            local labelObj = {}
            function labelObj:Set(newText)
                label.Text = newText
            end
            return labelObj
        end

        ----------------------------------------------------------------
        -- Keybind
        ----------------------------------------------------------------

        function tab:CreateKeybind(config)
            local name = config.Name or "Keybind"
            local default = config.Default or Enum.KeyCode.Unknown
            local callback = config.Callback or function() end

            local currentKey = default
            local listening = false

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = Theme.Surface,
                Parent = tabContent,
            })
            addCorner(holder)

            create("TextLabel", {
                Size = UDim2.new(1, -80, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Theme.Font,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })

            local keyBtn = create("TextButton", {
                Size = UDim2.new(0, 60, 0, 22),
                Position = UDim2.new(1, -70, 0.5, -11),
                BackgroundColor3 = Theme.SurfaceAlt,
                Text = currentKey.Name or "None",
                TextColor3 = Theme.Accent,
                Font = Theme.Font,
                TextSize = 11,
                Parent = holder,
            })
            addCorner(keyBtn, UDim.new(0, 4))

            keyBtn.MouseButton1Click:Connect(function()
                listening = true
                keyBtn.Text = "..."
                keyBtn.TextColor3 = Theme.Warning
            end)

            UserInputService.InputBegan:Connect(function(input, processed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    currentKey = input.KeyCode
                    keyBtn.Text = currentKey.Name
                    keyBtn.TextColor3 = Theme.Accent
                    listening = false
                elseif not processed and input.KeyCode == currentKey then
                    callback(currentKey)
                end
            end)

            local bindObj = {}
            function bindObj:Set(key)
                currentKey = key
                keyBtn.Text = key.Name
            end
            function bindObj:Get()
                return currentKey
            end
            return bindObj
        end

        ----------------------------------------------------------------
        -- TextBox
        ----------------------------------------------------------------

        function tab:CreateTextBox(config)
            local name = config.Name or "Input"
            local placeholder = config.Placeholder or ""
            local callback = config.Callback or function() end

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = Theme.Surface,
                Parent = tabContent,
            })
            addCorner(holder)

            create("TextLabel", {
                Size = UDim2.new(0.4, -10, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Theme.Font,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })

            local input = create("TextBox", {
                Size = UDim2.new(0.6, -14, 0, 22),
                Position = UDim2.new(0.4, 4, 0.5, -11),
                BackgroundColor3 = Theme.SurfaceAlt,
                Text = "",
                PlaceholderText = placeholder,
                PlaceholderColor3 = Theme.TextDim,
                TextColor3 = Theme.Text,
                Font = Theme.Font,
                TextSize = 12,
                ClearTextOnFocus = false,
                Parent = holder,
            })
            addCorner(input, UDim.new(0, 4))

            input.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    callback(input.Text)
                end
            end)

            local boxObj = {}
            function boxObj:Set(text)
                input.Text = text
            end
            function boxObj:Get()
                return input.Text
            end
            return boxObj
        end

        return tab
    end

    return window
end

return NyxLine
