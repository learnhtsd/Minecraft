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
    Color = Color3.fromRGB(74, 120, 255),
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
    
    local CastPoints = {Part.Position}
    local IgnoreList = {LocalPlayer.Character, Character, Camera}
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = IgnoreList

    local Result = workspace:Raycast(Camera.CFrame.Position, (Part.Position - Camera.CFrame.Position).Unit * 1000, Params)
    return Result == nil or Result.Instance:IsDescendantOf(Character)
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
    Data.Box.Filled = false
    Data.Box.ZIndex = 3
    
    Data.BoxOutline.Thickness = 1
    Data.BoxOutline.Color = Color3.new(0,0,0)
    Data.BoxOutline.ZIndex = 2

    Data.HealthBar.Thickness = 1
    Data.HealthBar.Filled = true
    Data.HealthBar.ZIndex = 4
    
    Data.HealthBarBG.Thickness = 1
    Data.HealthBarBG.Filled = true
    Data.HealthBarBG.Color = Color3.new(0,0,0)
    Data.HealthBarBG.ZIndex = 3

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
            if type(v) == "table" then 
                for _, l in pairs(v) do l:Remove() end
            elseif v.Remove then 
                v:Remove() 
            end
        end
        Cache[Player] = nil
    end
end

-- Dedicated helper to safely hide ESP without crashing/freezing
local function HideESP(Data)
    Data.Box.Visible = false
    Data.BoxOutline.Visible = false
    Data.HealthBar.Visible = false
    Data.HealthBarBG.Visible = false
    Data.Tracer.Visible = false
    Data.Text.Visible = false
    for _, L in pairs(Data.SkeletonLines) do 
        L.Visible = false 
    end
end

-- =========================
-- UPDATE LOOP
-- =========================

RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then return end
    
    for Player, Data in pairs(Cache) do
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Hum = Character and Character:FindFirstChild("Humanoid")

        local IsTeammate = Player.Team == LocalPlayer.Team
        local IsFriend = LocalPlayer:IsFriendsWith(Player.UserId)
        local ShouldShow = true

        if Settings.TeamCheck and IsTeammate then ShouldShow = false end
        if Settings.FriendCheck and IsFriend then ShouldShow = false end

        if Root and Hum and Hum.Health > 0 and ShouldShow then
            local RootPos, OnScreen = Camera:WorldToViewportPoint(Root.Position)
            local Visible = IsVisible(Character)
            local CurrentColor = Visible and Settings.VisibleColor or Settings.OccludedColor
            
            -- RootPos.Z > 0 ensures the player isn't actively behind the camera's near-plane
            if OnScreen and RootPos.Z > 0 then
                local Head = Character:FindFirstChild("Head")
                local HeadPos = Camera:WorldToViewportPoint(Head.Position + Vector3.new(0, 0.5, 0))
                local LegPos = Camera:WorldToViewportPoint(Root.Position - Vector3.new(0, 3, 0))
                
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

                -- 2. Health Bar (Fixed Layout Math)
                Data.HealthBar.Visible = Settings.HealthBars
                Data.HealthBarBG.Visible = Settings.HealthBars
                if Settings.HealthBars then
                    -- Clamp health to prevent bar from growing outside box if overhealed
                    local HealthScale = math.clamp(Hum.Health / Hum.MaxHealth, 0, 1)
                    local BarHeight = Height * HealthScale
                    
                    -- Background (Black Outline)
                    Data.HealthBarBG.Position = Vector2.new(TopLeft.X - 6, TopLeft.Y)
                    Data.HealthBarBG.Size = Vector2.new(4, Height)
                    
                    -- Inner Health Bar (Green/Red)
                    Data.HealthBar.Position = Vector2.new(TopLeft.X - 5, TopLeft.Y + Height - BarHeight + 1)
                    Data.HealthBar.Size = Vector2.new(2, BarHeight - 2)
                    Data.HealthBar.Color = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), HealthScale)
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

                -- 4. Text
                Data.Text.Visible = (Settings.Names or Settings.Usernames or Settings.Distance)
                if Data.Text.Visible then
                    local Content = ""
                    if Settings.Names then Content = Content .. Player.DisplayName .. "\n" end
                    if Settings.Usernames then Content = Content .. "@" .. Player.Name .. "\n" end
                    if Settings.Distance then 
                        local Dist = math.floor((Root.Position - Camera.CFrame.Position).Magnitude)
                        Content = Content .. "[" .. Dist .. " studs]"
                    end
                    Data.Text.Text = Content
                    Data.Text.Position = Vector2.new(RootPos.X, RootPos.Y + (Height/2) + 2)
                    Data.Text.Color = Color3.new(1,1,1)
                end

                -- 5. Tracers
                Data.Tracer.Visible = Settings.Tracers
                if Settings.Tracers then
                    Data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    Data.Tracer.To = Vector2.new(RootPos.X, RootPos.Y)
                    Data.Tracer.Color = CurrentColor
                end
            else
                HideESP(Data) -- Properly hide when offscreen
            end
        else
            HideESP(Data) -- Properly hide when dead or filtered
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

    Tab:CreateSection("Quick Actions")
    
    -- Using CreateAction(Title, ButtonText, Callback) per your UI Engine
    Tab:CreateAction("Master Toggle", "Enable All", function()
        Settings.Boxes = true
        Settings.Skeletons = true
        Settings.HealthBars = true
        Settings.Tracers = true
        Settings.Names = true
        Settings.Usernames = true
        Settings.Distance = true
        -- Note: Toggles in the UI won't visually slide 'On', 
        -- but the features will start working immediately.
    end)

    Tab:CreateAction("Master Toggle", "Disable All", function()
        Settings.Boxes = false
        Settings.Skeletons = false
        Settings.HealthBars = false
        Settings.Tracers = false
        Settings.Names = false
        Settings.Usernames = false
        Settings.Distance = false
    end)

    Tab:CreateSection("Visuals")
    Tab:CreateToggle("Boxes (Outlined)", false, function(s) Settings.Boxes = s end)
    Tab:CreateToggle("Skeleton", false, function(s) Settings.Skeletons = s end)
    Tab:CreateToggle("Health Bars", false, function(s) Settings.HealthBars = s end)
    Tab:CreateToggle("Tracers", false, function(s) Settings.Tracers = s end)

    Tab:CreateSection("Text Info")
    Tab:CreateToggle("Show Display Name", false, function(s) Settings.Names = s end)
    Tab:CreateToggle("Show Username (@)", false, function(s) Settings.Usernames = s end)
    Tab:CreateToggle("Show Distance", false, function(s) Settings.Distance = s end)

    Tab:CreateSection("Filters & Performance")
    Tab:CreateToggle("Wall Check (Visible Only)", false, function(s) Settings.WallCheck = s end)
    Tab:CreateToggle("Team Check", false, function(s) Settings.TeamCheck = s end)
    Tab:CreateToggle("Friend Check", false, function(s) Settings.FriendCheck = s end)

    -- Player Event Listeners
    Players.PlayerAdded:Connect(function(p) 
        if Settings.Enabled then CreateESP(p) end 
    end)
    
    Players.PlayerRemoving:Connect(RemoveESP)
end

return ESPModule
