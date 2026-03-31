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
    TeamCheck = false,
    FriendCheck = false,
    WallCheck = false,
    VisibleColor = Color3.fromRGB(0, 255, 100),
    OccludedColor = Color3.fromRGB(255, 50, 50)
}

local Cache = {}

-- Skeleton Connection Map
local SkeletonConnections = {
    R15 = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
    },
    R6 = {
        {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
        {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
    }
}

-- =========================
-- UTILITIES
-- =========================

local function IsVisible(Character)
    if not Settings.WallCheck then return true end
    local Part = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Head")
    if not Part then return false end
    
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {LocalPlayer.Character, Character, Camera}

    local Result = workspace:Raycast(Camera.CFrame.Position, (Part.Position - Camera.CFrame.Position).Unit * 1000, Params)
    return Result == nil
end

local function HideESP(Data)
    Data.Box.Visible = false
    Data.BoxOutline.Visible = false
    Data.HealthBar.Visible = false
    Data.HealthBarBG.Visible = false
    Data.Tracer.Visible = false
    Data.Text.Visible = false
    for _, L in pairs(Data.SkeletonLines) do L.Visible = false end
end

local function CreateESP(Player)
    if Player == LocalPlayer or Cache[Player] then return end
    
    local Data = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        HealthBarBG = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
        Text = Drawing.new("Text"),
        SkeletonLines = {}
    }

    Data.Box.Thickness = 1
    Data.Box.ZIndex = 10
    Data.BoxOutline.Thickness = 1
    Data.BoxOutline.Color = Color3.new(0,0,0)
    Data.BoxOutline.ZIndex = 9

    Data.HealthBar.Filled = true
    Data.HealthBar.ZIndex = 12
    Data.HealthBarBG.Filled = true
    Data.HealthBarBG.Color = Color3.new(0,0,0)
    Data.HealthBarBG.ZIndex = 11

    Data.Tracer.Thickness = 1
    Data.Text.Size = 13
    Data.Text.Center = true
    Data.Text.Outline = true

    for i = 1, 15 do
        local L = Drawing.new("Line")
        L.Thickness = 1
        L.Visible = false
        table.insert(Data.SkeletonLines, L)
    end

    Cache[Player] = Data
end

local function RemoveESP(Player)
    local Data = Cache[Player]
    if Data then
        for _, v in pairs(Data) do
            if type(v) == "table" then for _, l in pairs(v) do l:Remove() end
            elseif v.Remove then v:Remove() end
        end
        Cache[Player] = nil
    end
end

-- =========================
-- UPDATE LOOP
-- =========================

RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then 
        for _, Data in pairs(Cache) do HideESP(Data) end
        return 
    end
    
    for Player, Data in pairs(Cache) do
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Hum = Character and Character:FindFirstChild("Humanoid")

        if Root and Hum and Hum.Health > 0 then
            local RootPos, OnScreen = Camera:WorldToViewportPoint(Root.Position)
            
            -- Filter Logic
            local IsTeammate = Player.Team == LocalPlayer.Team
            local IsFriend = LocalPlayer:IsFriendsWith(Player.UserId)
            local BlockedByFilter = (Settings.TeamCheck and IsTeammate) or (Settings.FriendCheck and IsFriend)

            if OnScreen and not BlockedByFilter then
                local Visible = IsVisible(Character)
                local CurrentColor = Visible and Settings.VisibleColor or Settings.OccludedColor
                
                local Head = Character:FindFirstChild("Head")
                local HeadPos = Camera:WorldToViewportPoint(Head.Position + Vector3.new(0, 0.5, 0))
                local LegPos = Camera:WorldToViewportPoint(Root.Position - Vector3.new(0, 3, 0))
                local Height = math.abs(HeadPos.Y - LegPos.Y)
                local Width = Height / 1.5
                local TopLeft = Vector2.new(RootPos.X - Width / 2, RootPos.Y - Height / 2)

                -- 1. Boxes (Default Outlined)
                if Settings.Boxes then
                    Data.Box.Position = TopLeft
                    Data.Box.Size = Vector2.new(Width, Height)
                    Data.Box.Color = CurrentColor
                    Data.Box.Visible = true

                    Data.BoxOutline.Position = TopLeft - Vector2.new(1,1)
                    Data.BoxOutline.Size = Data.Box.Size + Vector2.new(2,2)
                    Data.BoxOutline.Visible = true
                else
                    Data.Box.Visible = false
                    Data.BoxOutline.Visible = false
                end

                -- 2. Health Bar (Improved Visuals)
                if Settings.HealthBars then
                    local HealthPercent = Hum.Health / Hum.MaxHealth
                    local BarHeight = Height * HealthPercent
                    
                    -- Background (The black border)
                    Data.HealthBarBG.Position = TopLeft - Vector2.new(5, 0)
                    Data.HealthBarBG.Size = Vector2.new(3, Height)
                    Data.HealthBarBG.Visible = true
                    
                    -- Foreground (The actual health)
                    Data.HealthBar.Position = TopLeft - Vector2.new(4, -Height + BarHeight - 1)
                    Data.HealthBar.Size = Vector2.new(1, -BarHeight + 2)
                    Data.HealthBar.Color = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), HealthPercent)
                    Data.HealthBar.Visible = true
                else
                    Data.HealthBar.Visible = false
                    Data.HealthBarBG.Visible = false
                end

                -- 3. Skeleton
                if Settings.Skeletons then
                    local RigType = (Hum.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6"
                    local Connections = SkeletonConnections[RigType]
                    for i, Pair in pairs(Connections) do
                        local PartA, PartB = Character:FindFirstChild(Pair[1]), Character:FindFirstChild(Pair[2])
                        local Line = Data.SkeletonLines[i]
                        if PartA and PartB then
                            local PosA = Camera:WorldToViewportPoint(PartA.Position)
                            local PosB = Camera:WorldToViewportPoint(PartB.Position)
                            Line.From = Vector2.new(PosA.X, PosA.Y)
                            Line.To = Vector2.new(PosB.X, PosB.Y)
                            Line.Color = CurrentColor
                            Line.Visible = true
                        else
                            Line.Visible = false
                        end
                    end
                else
                    for _, L in pairs(Data.SkeletonLines) do L.Visible = false end
                end

                -- 4. Text (Username + Display Name)
                if Settings.Names or Settings.Usernames or Settings.Distance then
                    local Content = ""
                    if Settings.Names then Content = Content .. Player.DisplayName .. "\n" end
                    if Settings.Usernames then Content = Content .. "@" .. Player.Name .. "\n" end
                    if Settings.Distance then 
                        local Dist = math.floor((Root.Position - Camera.CFrame.Position).Magnitude)
                        Content = Content .. "[" .. Dist .. " studs]"
                    end
                    Data.Text.Text = Content
                    Data.Text.Position = Vector2.new(RootPos.X, RootPos.Y + (Height/2) + 2)
                    Data.Text.Visible = true
                else
                    Data.Text.Visible = false
                end

                -- 5. Tracers
                if Settings.Tracers then
                    Data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    Data.Tracer.To = Vector2.new(RootPos.X, RootPos.Y)
                    Data.Tracer.Color = CurrentColor
                    Data.Tracer.Visible = true
                else
                    Data.Tracer.Visible = false
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
    Tab:CreateSection("Master Controls")

    Tab:CreateButton("Enable All Visuals", function()
        Settings.Enabled = true
        Settings.Boxes = true
        Settings.Skeletons = true
        Settings.HealthBars = true
        Settings.Tracers = true
        Settings.Names = true
        Settings.Usernames = true
        Settings.Distance = true
        -- Note: This won't visually update toggle UI state unless your library supports it, 
        -- but the logic will activate immediately.
    end)

    Tab:CreateButton("Disable All Visuals", function()
        Settings.Enabled = false
        Settings.Boxes = false
        Settings.Skeletons = false
        Settings.HealthBars = false
        Settings.Tracers = false
        Settings.Names = false
        Settings.Usernames = false
        Settings.Distance = false
    end)

    Tab:CreateToggle("Master Enable", false, function(s) Settings.Enabled = s end)

    Tab:CreateSection("Visuals")
    Tab:CreateToggle("Boxes", false, function(s) Settings.Boxes = s end)
    Tab:CreateToggle("Skeleton", false, function(s) Settings.Skeletons = s end)
    Tab:CreateToggle("Health Bars", false, function(s) Settings.HealthBars = s end)
    Tab:CreateToggle("Tracers", false, function(s) Settings.Tracers = s end)

    Tab:CreateSection("Text Info")
    Tab:CreateToggle("Display Name", false, function(s) Settings.Names = s end)
    Tab:CreateToggle("Username (@)", false, function(s) Settings.Usernames = s end)
    Tab:CreateToggle("Distance", false, function(s) Settings.Distance = s end)

    Tab:CreateSection("Filters")
    Tab:CreateToggle("Wall Check", false, function(s) Settings.WallCheck = s end)
    Tab:CreateToggle("Team Check", false, function(s) Settings.TeamCheck = s end)
    Tab:CreateToggle("Friend Check", false, function(s) Settings.FriendCheck = s end)

    Players.PlayerAdded:Connect(function(p) CreateESP(p) end)
    Players.PlayerRemoving:Connect(RemoveESP)
    for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
end

return ESPModule
