local ESPModule = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game.Workspace.CurrentCamera

-- State Management
local Settings = {
    Enabled = false,
    Boxes = false,
    Tracers = false,
    Names = false,
    Usernames = false,
    Skeletons = false,
    HealthBars = false,
    Distance = false,
    -- NEW FEATURES
    Chams = false,
    LookLines = false,
    HeadDots = false,
    
    TeamCheck = false,
    FriendCheck = false,
    WallCheck = false,
    Color = Color3.fromRGB(74, 120, 255),
    VisibleColor = Color3.fromRGB(0, 255, 100),
    OccludedColor = Color3.fromRGB(255, 50, 50)
}

local Cache = {}

-- =========================
-- UTILITIES
-- =========================

local function IsVisible(Character, TargetPosition)
    if not Settings.WallCheck then return true end
    
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {LocalPlayer.Character, Character, Camera}

    local Result = workspace:Raycast(Camera.CFrame.Position, (TargetPosition - Camera.CFrame.Position).Unit * 1000, Params)
    return Result == nil
end

local function CreateESP(Player)
    if Player == LocalPlayer or Cache[Player] then return end
    
    local Data = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        HealthBarBG = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
        LookLine = Drawing.new("Line"),
        HeadDot = Drawing.new("Circle"),
        Text = Drawing.new("Text"),
        SkeletonLines = {},
        Highlight = nil
    }

    -- Basic Setup
    Data.Box.Thickness = 1
    Data.BoxOutline.Thickness = 1
    Data.BoxOutline.Color = Color3.new(0,0,0)
    Data.HealthBar.Filled = true
    Data.HealthBarBG.Color = Color3.new(0,0,0)
    Data.HealthBarBG.Filled = true
    Data.Tracer.Thickness = 1
    Data.LookLine.Thickness = 1
    Data.HeadDot.Thickness = 1
    Data.HeadDot.Filled = true
    Data.HeadDot.Radius = 3
    Data.Text.Size = 13
    Data.Text.Center = true
    Data.Text.Outline = true

    for i = 1, 15 do
        local L = Drawing.new("Line")
        L.Thickness = 1
        table.insert(Data.SkeletonLines, L)
    end

    Cache[Player] = Data
end

local function RemoveESP(Player)
    local Data = Cache[Player]
    if Data then
        if Data.Highlight then Data.Highlight:Destroy() end
        for _, v in pairs(Data) do
            if type(v) == "table" then 
                for _, l in pairs(v) do l:Remove() end
            elseif type(v) == "table" and v.Remove then 
                v:Remove() 
            elseif typeof(v) == "userdata" and v.Remove then
                v:Remove()
            end
        end
        Cache[Player] = nil
    end
end

local function HideESP(Data)
    Data.Box.Visible = false
    Data.BoxOutline.Visible = false
    Data.HealthBar.Visible = false
    Data.HealthBarBG.Visible = false
    Data.Tracer.Visible = false
    Data.LookLine.Visible = false
    Data.HeadDot.Visible = false
    Data.Text.Visible = false
    if Data.Highlight then Data.Highlight.Enabled = false end
    for _, L in pairs(Data.SkeletonLines) do L.Visible = false end
end

-- =========================
-- UPDATE LOOP
-- =========================

RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then return end
    
    for Player, Data in pairs(Cache) do
        local Character = Player.Character
        
        -- Check if character exists and has physical parts (bypass strict naming)
        if Character and Character:FindFirstChildWhichIsA("BasePart") then
            -- Get dynamic bounding box for custom models
            local ModelCFrame, ModelSize = Character:GetBoundingBox()
            
            local Hum = Character:FindFirstChildWhichIsA("Humanoid")
            local IsAlive = true
            local HealthScale = 1
            
            -- Dynamic health checking (fallback to 100% if no humanoid is found)
            if Hum then
                if Hum.Health <= 0 then IsAlive = false end
                HealthScale = math.clamp(Hum.Health / Hum.MaxHealth, 0, 1)
            end

            if IsAlive and ModelSize.Magnitude > 0 then
                local RootPos, OnScreen = Camera:WorldToViewportPoint(ModelCFrame.Position)
                local Visible = IsVisible(Character, ModelCFrame.Position)
                local CurrentColor = Visible and Settings.VisibleColor or Settings.OccludedColor
                
                -- CHAMS LOGIC (Highlights)
                if Settings.Chams then
                    if not Data.Highlight then
                        Data.Highlight = Instance.new("Highlight")
                        Data.Highlight.Parent = game:GetService("CoreGui")
                    end
                    Data.Highlight.Adornee = Character
                    Data.Highlight.Enabled = true
                    Data.Highlight.FillColor = CurrentColor
                    Data.Highlight.OutlineColor = Color3.new(1,1,1)
                    Data.Highlight.FillTransparency = 0.5
                elseif Data.Highlight then
                    Data.Highlight.Enabled = false
                end

                if OnScreen and RootPos.Z > 0 then
                    -- Calculate Head and Legs dynamically using the Bounding Box size
                    local Head3D = ModelCFrame.Position + Vector3.new(0, ModelSize.Y / 2, 0)
                    local Leg3D = ModelCFrame.Position - Vector3.new(0, ModelSize.Y / 2, 0)
                    
                    local HeadPos = Camera:WorldToViewportPoint(Head3D)
                    local LegPos = Camera:WorldToViewportPoint(Leg3D)
                    
                    local Height = math.abs(HeadPos.Y - LegPos.Y)
                    local Width = Height / 1.5
                    local TopLeft = Vector2.new(RootPos.X - Width / 2, RootPos.Y - Height / 2)

                    -- 1. Boxes
                    Data.Box.Visible = Settings.Boxes
                    Data.BoxOutline.Visible = Settings.Boxes
                    if Settings.Boxes then
                        Data.Box.Position = TopLeft
                        Data.Box.Size = Vector2.new(Width, Height)
                        Data.Box.Color = CurrentColor
                        Data.BoxOutline.Position = TopLeft - Vector2.new(1,1)
                        Data.BoxOutline.Size = Data.Box.Size + Vector2.new(2,2)
                    end

                    -- 2. Look Lines (Aim Direction)
                    Data.LookLine.Visible = Settings.LookLines
                    if Settings.LookLines then
                        -- Get look vector from actual head if it exists, otherwise use the whole model's LookVector
                        local ActualHead = Character:FindFirstChild("Head")
                        local LookDirection = ActualHead and ActualHead.CFrame.LookVector or ModelCFrame.LookVector
                        
                        local LookAt = Head3D + (LookDirection * 5)
                        local LookPos = Camera:WorldToViewportPoint(LookAt)
                        
                        Data.LookLine.From = Vector2.new(HeadPos.X, HeadPos.Y)
                        Data.LookLine.To = Vector2.new(LookPos.X, LookPos.Y)
                        Data.LookLine.Color = Color3.new(1, 1, 1)
                    end

                    -- 3. Head Dots
                    Data.HeadDot.Visible = Settings.HeadDots
                    if Settings.HeadDots then
                        Data.HeadDot.Position = Vector2.new(HeadPos.X, HeadPos.Y)
                        Data.HeadDot.Color = CurrentColor
                    end

                    -- 4. Health Bar
                    Data.HealthBar.Visible = Settings.HealthBars
                    Data.HealthBarBG.Visible = Settings.HealthBars
                    if Settings.HealthBars then
                        Data.HealthBarBG.Position = Vector2.new(TopLeft.X - 6, TopLeft.Y)
                        Data.HealthBarBG.Size = Vector2.new(4, Height)
                        Data.HealthBar.Position = Vector2.new(TopLeft.X - 5, TopLeft.Y + Height - (Height * HealthScale) + 1)
                        Data.HealthBar.Size = Vector2.new(2, (Height * HealthScale) - 2)
                        Data.HealthBar.Color = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), HealthScale)
                    end

                    -- 5. Text Info
                    Data.Text.Visible = (Settings.Names or Settings.Usernames or Settings.Distance)
                    if Data.Text.Visible then
                        local Content = ""
                        if Settings.Names then Content = Content .. Player.DisplayName .. "\n" end
                        if Settings.Usernames then Content = Content .. "@" .. Player.Name .. "\n" end
                        if Settings.Distance then 
                            Content = Content .. "[" .. math.floor(RootPos.Z) .. "m]"
                        end
                        Data.Text.Text = Content
                        Data.Text.Position = Vector2.new(RootPos.X, RootPos.Y + (Height/2) + 2)
                    end

                    -- Tracers
                    Data.Tracer.Visible = Settings.Tracers
                    if Settings.Tracers then
                        Data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        Data.Tracer.To = Vector2.new(RootPos.X, RootPos.Y)
                        Data.Tracer.Color = CurrentColor
                    end
                else
                    HideESP(Data)
                end
            else
                HideESP(Data)
            end
        else
            HideESP(Data)
        end
    end
end)

-- =========================
-- INITIALIZATION
-- =========================

function ESPModule.Init(Tab, Lib)
    Tab:CreateSection("Main")
    Tab:CreateToggle("Enable ESP", false, function(s) 
        Settings.Enabled = s 
        if s then 
            for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
        else 
            for _, p in pairs(Players:GetPlayers()) do RemoveESP(p) end 
        end
    end)

    Tab:CreateSection("Advanced Visuals")
    Tab:CreateToggle("Chams (Glow)", false, function(s) Settings.Chams = s end)
    Tab:CreateToggle("Look Lines", false, function(s) Settings.LookLines = s end)
    Tab:CreateToggle("Head Dots", false, function(s) Settings.HeadDots = s end)

    Tab:CreateSection("Standard Visuals")
    Tab:CreateToggle("Boxes", false, function(s) Settings.Boxes = s end)
    Tab:CreateToggle("Health Bars", false, function(s) Settings.HealthBars = s end)
    Tab:CreateToggle("Tracers", false, function(s) Settings.Tracers = s end)

    Tab:CreateSection("Text Settings")
    Tab:CreateToggle("Show Name", false, function(s) Settings.Names = s end)
    Tab:CreateToggle("Show Distance", false, function(s) Settings.Distance = s end)

    Tab:CreateSection("Filters")
    Tab:CreateToggle("Wall Check", false, function(s) Settings.WallCheck = s end)
    Tab:CreateToggle("Team Check", false, function(s) Settings.TeamCheck = s end)

    Players.PlayerAdded:Connect(function(p) if Settings.Enabled then CreateESP(p) end end)
    Players.PlayerRemoving:Connect(RemoveESP)
end

return ESPModule
