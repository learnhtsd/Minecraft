local ESPModule = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- State Management
local Settings = {
    Enabled = false,
    Boxes = false,
    Tracers = false,
    Names = false,
    Chams = false,
    Health = false,
    Distance = false,
    Color = Color3.fromRGB(74, 120, 255)
}

local Cache = {}

-- =========================
-- CORE UTILITIES
-- =========================

local function CreateESP(Player)
    if Player == LocalPlayer then return end
    
    local Folder = Instance.new("Folder")
    Folder.Name = "ESP_" .. Player.Name
    
    -- Chams (Highlights)
    local Highlight = Instance.new("Highlight")
    Highlight.Name = "Chams"
    Highlight.FillColor = Settings.Color
    Highlight.OutlineColor = Color3.new(1, 1, 1)
    Highlight.FillTransparency = 0.5
    Highlight.Enabled = false
    Highlight.Parent = Folder

    -- Billboard for Text (Name, Health, Distance)
    local Billboard = Instance.new("BillboardGui")
    Billboard.Name = "InfoTag"
    Billboard.Size = UDim2.new(0, 200, 0, 50)
    Billboard.Adornee = nil -- Set in update loop
    Billboard.AlwaysOnTop = true
    Billboard.ExtentsOffset = Vector3.new(0, 3, 0)
    Billboard.Enabled = false
    Billboard.Parent = Folder

    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Size = UDim2.new(1, 0, 1, 0)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.TextColor3 = Color3.new(1, 1, 1)
    InfoLabel.Font = Enum.Font.GothamBold
    InfoLabel.TextSize = 12
    InfoLabel.RichText = true
    InfoLabel.TextYAlignment = Enum.TextYAlignment.Bottom
    InfoLabel.Parent = Billboard

    -- Tracers (Drawing API)
    local Tracer = nil
    if Drawing then
        Tracer = Drawing.new("Line")
        Tracer.Thickness = 1
        Tracer.Color = Settings.Color
        Tracer.Transparency = 1
        Tracer.Visible = false
    end

    Cache[Player] = {
        Folder = Folder,
        Highlight = Highlight,
        Billboard = Billboard,
        Label = InfoLabel,
        Tracer = Tracer
    }
end

local function RemoveESP(Player)
    if Cache[Player] then
        Cache[Player].Folder:Destroy()
        if Cache[Player].Tracer then
            Cache[Player].Tracer:Remove()
        end
        Cache[Player] = nil
    end
end

-- =========================
-- UPDATE LOOP
-- =========================

RunService.RenderStepped:Connect(function()
    for Player, Data in pairs(Cache) do
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Hum = Character and Character:FindFirstChild("Humanoid")

        if Root and Hum and Hum.Health > 0 then
            -- Position Check
            local ScreenPos, OnScreen = game.Workspace.CurrentCamera:WorldToViewportPoint(Root.Position)
            
            -- Update Chams
            Data.Highlight.Enabled = Settings.Chams
            Data.Highlight.Adornee = Character
            
            -- Update Info Tags (Names, Health, Distance)
            if (Settings.Names or Settings.Health or Settings.Distance) and OnScreen then
                Data.Billboard.Enabled = true
                Data.Billboard.Adornee = Root
                
                local Text = ""
                if Settings.Names then Text = Text .. Player.DisplayName .. "\n" end
                if Settings.Health then Text = Text .. "HP: " .. math.floor(Hum.Health) .. "%\n" end
                if Settings.Distance then 
                    local Dist = math.floor((Root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
                    Text = Text .. "[" .. Dist .. "m]"
                end
                Data.Label.Text = Text
            else
                Data.Billboard.Enabled = false
            end

            -- Update Tracers
            if Settings.Tracers and Data.Tracer and OnScreen then
                Data.Tracer.Visible = true
                Data.Tracer.From = Vector2.new(game.Workspace.CurrentCamera.ViewportSize.X / 2, game.Workspace.CurrentCamera.ViewportSize.Y)
                Data.Tracer.To = Vector2.new(ScreenPos.X, ScreenPos.Y)
            elseif Data.Tracer then
                Data.Tracer.Visible = false
            end
        else
            Data.Highlight.Enabled = false
            Data.Billboard.Enabled = false
            if Data.Tracer then Data.Tracer.Visible = false end
        end
    end
end)

-- =========================
-- INITIALIZATION
-- =========================

function ESPModule.Init(Tab, Lib)
    Tab:CreateSection("Visuals")

    Tab:CreateToggle("Player ESP", false, function(state)
        Settings.Enabled = state
        if state then
            for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
        else
            for _, p in pairs(Players:GetPlayers()) do RemoveESP(p) end
        end
    end)

    Tab:CreateToggle("Tracers", false, function(state)
        Settings.Tracers = state
    end)

    Tab:CreateToggle("Chams", false, function(state)
        Settings.Chams = state
    end)

    Tab:CreateSection("Info Display")

    Tab:CreateToggle("Display Names", false, function(state)
        Settings.Names = state
    end)

    Tab:CreateToggle("Display Health", false, function(state)
        Settings.Health = state
    end)

    Tab:CreateToggle("Display Distance", false, function(state)
        Settings.Distance = state
    end)

    -- Handle New Players
    Players.PlayerAdded:Connect(function(p)
        if Settings.Enabled then CreateESP(p) end
    end)
    
    Players.PlayerRemoving:Connect(RemoveESP)
end

return ESPModule
