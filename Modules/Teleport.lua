local TeleportModule = {}

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

function TeleportModule.Init(Tab)
    local Waypoints = {}
    local WaypointNames = {}

    -- ==========================================
    -- WAYPOINT SECTION
    -- ==========================================
    Tab:CreateSection("Waypoints")

    Tab:CreateInfoBox("About Waypoints", "Save your current position to return to it later. Waypoints are session-based.")

    -- Logic to refresh the dropdown whenever a waypoint is added
    local function GetWaypointList()
        local list = {}
        for name, _ in pairs(Waypoints) do
            table.insert(list, name)
        end
        return #list > 0 and list or {"No Waypoints"}
    end

    Tab:CreateAction("Create Waypoint", "Save Pos", function()
        local Character = LocalPlayer.Character
        if Character and Character:FindFirstChild("HumanoidRootPart") then
            -- Simple popup simulation or prompt could go here, 
            -- but for this engine we'll use a timestamped name
            local Name = "Point " .. os.date("%X")
            Waypoints[Name] = Character.HumanoidRootPart.CFrame
            
            -- Note: Since the UI Engine's dropdown doesn't support dynamic 
            -- 'live' refreshing easily without re-creating, we notify the user.
            print("Saved Waypoint: " .. Name)
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Waypoint Saved",
                Text = "Saved: " .. Name,
                Duration = 3
            })
        end
    end)

    Tab:CreateDropdown("Teleport to Waypoint", GetWaypointList(), "Select...", function(Selected)
        if Waypoints[Selected] and LocalPlayer.Character then
            LocalPlayer.Character:SetPrimaryPartCFrame(Waypoints[Selected])
        end
    end)

    -- ==========================================
    -- PLAYER TELEPORT SECTION
    -- ==========================================
    Tab:CreateSection("Player Teleport")

    local function GetPlayerList()
        local list = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(list, p.Name)
            end
        end
        return list
    end

    local SelectedPlayer = nil

    Tab:CreateDropdown("Select Player", GetPlayerList(), "Select...", function(Selected)
        SelectedPlayer = Selected
    end)

    Tab:CreateAction("Teleport to Player", "TP Now", function()
        if SelectedPlayer then
            local Target = Players:FindFirstChild(SelectedPlayer)
            if Target and Target.Character and Target.Character:FindFirstChild("HumanoidRootPart") then
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = Target.Character.HumanoidRootPart.CFrame
                end
            end
        end
    end)

    Tab:CreateAction("Refresh Player List", "Refresh", function()
        -- Note: To update the dropdown, the user would usually re-open the tab 
        -- or you'd need to add a Refresh method to your Library's dropdown.
        print("Player list updated in console: ", table.concat(GetPlayerList(), ", "))
    end)
end

return TeleportModule
