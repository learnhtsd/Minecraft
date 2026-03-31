local ESPModule = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game.Workspace.CurrentCamera

-- State Management
local Settings = {
    Enabled = false,
    Boxes = false,
    BoxOutline = false,
    Tracers = false,
    Names = false,
    Chams = false, -- Chams still uses Highlight if supported
    Health = false,
    Distance = false,
    Color = Color3.fromRGB(74, 120, 255)
}

local Cache = {}

-- =========================
-- DRAWING API UTILITIES
-- =========================

local function CreateESP(Player)
    if Player == LocalPlayer then return end
    if Cache[Player] then return end -- Don't duplicate
    
    local Objects = {
        -- Main Box
        Box = Drawing.new("Square"),
        -- Outline for Box
        BoxOutline = Drawing.new("Square"),
        -- Tracer
        Tracer = Drawing.new("Line"),
        -- Text (Names, HP, Distance)
        Text = Drawing.new("Text")
    }
    
    -- Setup Box
    Objects.Box.Thickness = 1
    Objects.Box.Filled = false
    Objects.Box.Color = Settings.Color
    Objects.Box.Visible = false
    Objects.Box.ZIndex = 2

    -- Setup Box Outline
    Objects.BoxOutline.Thickness = 1
    Objects.BoxOutline.Filled = false
    Objects.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    Objects.BoxOutline.Visible = false
    Objects.BoxOutline.ZIndex = 1

    -- Setup Tracer
    Objects.Tracer.Thickness = 1
    Objects.Tracer.Color = Settings.Color
    Objects.Tracer.Visible = false

    -- Setup Text
    Objects.Text.Size = 13
    Objects.Text.Center = true
    Objects.Text.Outline = true
    Objects.Text.OutlineColor = Color3.fromRGB(0, 0, 0)
    Objects.Text.Color = Color3.fromRGB(255, 255, 255)
    Objects.Text.Visible = false

    -- Fallback Cham Highlight (Just in case it works for your executor)
    local Highlight = Instance.new("Highlight")
    Highlight.FillColor = Settings.Color
    Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    Highlight.FillTransparency = 0.5
    Highlight.Enabled = false
    Objects.Highlight = Highlight

    Cache[Player] = Objects
end

local function RemoveESP(Player)
    local Data = Cache[Player]
    if Data then
        Data.Box:Remove()
        Data.BoxOutline:Remove()
        Data.Tracer:Remove()
        Data.Text:Remove()
        if Data.Highlight then Data.Highlight:Destroy() end
        Cache[Player] = nil
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
        local Head = Character and Character:FindFirstChild("Head")
        local Hum = Character and Character:FindFirstChild("Humanoid")

        if Root and Head and Hum and Hum.Health > 0 then
            local RootPos, OnScreen = Camera:WorldToViewportPoint(Root.Position)
            
            if OnScreen then
                -- Calculate 2D Box based on Character Scale
                local HeadPos = Camera:WorldToViewportPoint(Head.Position + Vector3.new(0, 0.5, 0))
                local LegPos = Camera:WorldToViewportPoint(Root.Position - Vector3.new(0, 3, 0))
                
                local Height = math.abs(HeadPos.Y - LegPos.Y)
                local Width = Height / 2
                
                -- Update Box
                if Settings.Boxes then
                    local boxPos = Vector2.new(RootPos.X - Width / 2, RootPos.Y - Height / 2)
                    local boxSize = Vector2.new(Width, Height)
                    
                    Data.Box.Position = boxPos
                    Data.Box.Size = boxSize
                    Data.Box.Visible = true
                    
                    if Settings.BoxOutline then
                        Data.BoxOutline.Position = boxPos - Vector2.new(1, 1)
                        Data.BoxOutline.Size = boxSize + Vector2.new(2, 2)
                        Data.BoxOutline.Visible = true
                    else
                        Data.BoxOutline.Visible = false
                    end
                else
                    Data.Box.Visible = false
                    Data.BoxOutline.Visible = false
                end

                -- Update Tracers
                if Settings.Tracers then
                    Data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    Data.Tracer.To = Vector2.new(RootPos.X, RootPos.Y)
                    Data.Tracer.Visible = true
                else
                    Data.Tracer.Visible = false
                end

                -- Update Text (Names, Health, Distance)
                if Settings.Names or Settings.Health or Settings.Distance then
                    local DisplayStr = ""
                    
                    if Settings.Names then DisplayStr = DisplayStr .. Player.Name .. "\n" end
                    if Settings.Health then DisplayStr = DisplayStr .. "HP: " .. math.floor(Hum.Health) .. "%\n" end
                    if Settings.Distance then
                        local Dist = math.floor((Root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
                        DisplayStr = DisplayStr .. "[" .. Dist .. " studs]"
                    end
                    
                    Data.Text.Text = DisplayStr
                    Data.Text.Position = Vector2.new(RootPos.X, RootPos.Y + (Height / 2) + 5)
                    Data.Text.Visible = true
                else
                    Data.Text.Visible = false
                end
                
                -- Update Chams (Will only work if executor doesn't block Highlights)
                if Settings.Chams then
                    Data.Highlight.Parent = Character
                    Data.Highlight.Enabled = true
                else
                    Data.Highlight.Enabled = false
                end
            else
                -- Offscreen cleanup
                Data.Box.Visible = false
                Data.BoxOutline.Visible = false
                Data.Tracer.Visible = false
                Data.Text.Visible = false
                Data.Highlight.Enabled = false
            end
        else
            -- Dead/Invisible player cleanup
            Data.Box.Visible = false
            Data.BoxOutline.Visible = false
            Data.Tracer.Visible = false
            Data.Text.Visible = false
            Data.Highlight.Enabled = false
        end
    end
end)

-- =========================
-- INITIALIZATION
-- =========================

function ESPModule.Init(Tab, Lib)
    Tab:CreateSection("ESP Master Switch")

    Tab:CreateToggle("Enable ESP", false, function(state)
        Settings.Enabled = state
        if state then
            for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
        else
            for _, p in pairs(Players:GetPlayers()) do RemoveESP(p) end
        end
    end)

    Tab:CreateSection("Visuals")

    Tab:CreateToggle("Boxes", false, function(state)
        Settings.Boxes = state
    end)

    Tab:CreateToggle("Box Outline", false, function(state)
        Settings.BoxOutline = state
    end)

    Tab:CreateToggle("Tracers", false, function(state)
        Settings.Tracers = state
    end)

    Tab:CreateToggle("Chams (Glow)", false, function(state)
        Settings.Chams = state
    end)

    Tab:CreateSection("Text Info")

    Tab:CreateToggle("Show Names", false, function(state)
        Settings.Names = state
    end)

    Tab:CreateToggle("Show Health", false, function(state)
        Settings.Health = state
    end)

    Tab:CreateToggle("Show Distance", false, function(state)
        Settings.Distance = state
    end)

    -- Dynamic listeners for joining/leaving players
    Players.PlayerAdded:Connect(function(p)
        if Settings.Enabled then CreateESP(p) end
    end)
    
    Players.PlayerRemoving:Connect(RemoveESP)
end

return ESPModule
