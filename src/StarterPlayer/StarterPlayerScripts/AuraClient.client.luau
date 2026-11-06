-- Aura Legends — Client v0.3
-- Sends intents to the server and renders the HUD. Never decides the economy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("AuraConfig"))

----------------------------------------------------------------
-- HUD state
----------------------------------------------------------------
local hud = {}
local state = {
    Energy = 0,
    Power = 0,
    Stamina = 0,
    Magnet = 0,
    Zone = 1,
    MaxZone = 1,
    Streak = 0,
    HP = 0,
    MaxHP = 0,
    Boss = nil,
    Dead = false,
    AuraIds = {},
}

local remotes = nil

----------------------------------------------------------------
-- Helpers (declared before anything that calls them)
----------------------------------------------------------------
local function newLabel(props)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.4
    for key, value in pairs(props) do
        label[key] = value
    end
    return label
end

local function newButton(text, position, size, color)
    local button = Instance.new("TextButton")
    button.BackgroundColor3 = color
    button.Font = Enum.Font.GothamBold
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = text
    button.Position = position
    button.Size = size
    button.AutoButtonColor = true
    button.TextStrokeTransparency = 0.3
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    return button
end

-- A bar is a Frame with a Fill child and a Text child.
local function newBar(width, height, fillColor)
    local background = Instance.new("Frame")
    background.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    background.BackgroundTransparency = 0.15
    background.BorderSizePixel = 0
    local backgroundCorner = Instance.new("UICorner")
    backgroundCorner.CornerRadius = UDim.new(0, 6)
    backgroundCorner.Parent = background

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = fillColor
    fill.BorderSizePixel = 0
    fill.Parent = background
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = fill

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.5
    label.Text = ""
    label.Parent = background

    return background
end

local function setBar(background, fraction, text)
    if not background then
        return
    end
    local fill = background:FindFirstChild("Fill")
    local label = background:FindFirstChild("Text")
    if fill then
        fill.Size = UDim2.new(math.clamp(fraction or 0, 0, 1), 0, 1, 0)
    end
    if label then
        label.Text = text or ""
    end
end

local function hasAura(list, id)
    for _, value in ipairs(list) do
        if value == id then
            return true
        end
    end
    return false
end

local function refresh()
    if hud.Energy then
        hud.Energy.Text = "Energy  " .. tostring(state.Energy)
    end
    if hud.Power then
        hud.Power.Text = "Power  Lv " .. tostring(state.Power)
    end
    if hud.Stamina then
        hud.Stamina.Text = "Stamina  Lv " .. tostring(state.Stamina)
    end
    if hud.Zone then
        hud.Zone.Text = "Zone  " .. Config.ZONES[state.Zone].Name
    end
    if hud.Streak then
        hud.Streak.Text = "Streak  " .. tostring(state.Streak) .. "d"
    end
    if hud.Fight then
        hud.Fight.Text = "FIGHT: " .. Config.ZONES[state.Zone].Boss
    end
    if hud.Attack then
        hud.Attack.Visible = state.Boss ~= nil
    end
    if hud.ZoneButtons then
        for i, button in ipairs(hud.ZoneButtons) do
            if i <= state.MaxZone then
                button.BackgroundColor3 = Color3.fromRGB(80, 80, 105)
            else
                button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            end
            if i == state.Zone then
                button.Text = "[ " .. tostring(i) .. " ]"
            else
                button.Text = tostring(i)
            end
        end
    end
    if hud.AuraSlots then
        for i, aura in ipairs(Config.AURAS) do
            local slot = hud.AuraSlots[i]
            if slot then
                local owned = hasAura(state.AuraIds, aura.Id)
                slot.BackgroundColor3 = owned and aura.Color or Color3.fromRGB(45, 45, 55)
                local label = slot:FindFirstChild("Label")
                if label then
                    label.Text = owned and aura.Id or "???"
                end
            end
        end
    end
end

local function flash(text)
    if not hud.Message then
        return
    end
    hud.Message.Text = text
    task.delay(2, function()
        if hud.Message then
            hud.Message.Text = ""
        end
    end)
end

local function getRemotes()
    if remotes then
        return remotes
    end
    local folder = ReplicatedStorage:FindFirstChild("AuraRemotes")
    if folder then
        local found = {
            Train = folder:FindFirstChild("Train"),
            BuyUpgrade = folder:FindFirstChild("BuyUpgrade"),
            ClaimDaily = folder:FindFirstChild("ClaimDaily"),
            EnterZone = folder:FindFirstChild("EnterZone"),
            Attack = folder:FindFirstChild("Attack"),
            State = folder:FindFirstChild("State"),
        }
        local complete = true
        for _, remote in pairs(found) do
            if not remote then
                complete = false
            end
        end
        if complete then
            remotes = found
        end
    end
    return remotes
end

----------------------------------------------------------------
-- HUD construction
----------------------------------------------------------------
local buildGui

buildGui = function(r)
    local screen = Instance.new("ScreenGui")
    screen.Name = "AuraHud"
    screen.ResetOnSpawn = false
    screen.Parent = playerGui

    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 46)
    topBar.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    topBar.BackgroundTransparency = 0.25
    topBar.Parent = screen

    hud.Energy = newLabel({
        Name = "Energy", Text = "Energy  0", Size = UDim2.new(0, 240, 1, 0),
        Position = UDim2.new(0, 14, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18,
        Parent = topBar,
    })
    hud.Power = newLabel({
        Name = "Power", Text = "Power  Lv 0", Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 260, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18,
        Parent = topBar,
    })
    hud.Stamina = newLabel({
        Name = "Stamina", Text = "Stamina  Lv 0", Size = UDim2.new(0, 210, 1, 0),
        Position = UDim2.new(0, 470, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18,
        Parent = topBar,
    })
    hud.Zone = newLabel({
        Name = "Zone", Text = "Zone  " .. Config.ZONES[1].Name, Size = UDim2.new(0, 300, 1, 0),
        Position = UDim2.new(0, 690, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18,
        Parent = topBar,
    })
    hud.Streak = newLabel({
        Name = "Streak", Text = "Streak  0d", Size = UDim2.new(0, 180, 1, 0),
        Position = UDim2.new(1, -190, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 18,
        Parent = topBar,
    })

    -- Player health
    hud.PlayerBar = newBar(300, 26, Color3.fromRGB(90, 200, 90))
    hud.PlayerBar.Name = "PlayerBar"
    hud.PlayerBar.Position = UDim2.new(0, 20, 0, 56)
    hud.PlayerBar.Parent = screen

    -- Boss health (hidden until a fight starts)
    hud.BossBar = newBar(420, 60, Color3.fromRGB(230, 70, 70))
    hud.BossBar.Name = "BossBar"
    hud.BossBar.Position = UDim2.new(0.5, -210, 0, 200)
    hud.BossBar.Visible = false
    hud.BossBar.Parent = screen

    hud.Message = newLabel({
        Name = "Message", Text = "", Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.new(0, 0, 0, 130), TextSize = 16,
        Parent = screen,
    })

    -- Zone selector
    hud.ZoneButtons = {}
    for i, zone in ipairs(Config.ZONES) do
        local button = newButton(tostring(i), UDim2.new(0, 20 + (i - 1) * 70, 0, 96), UDim2.new(0, 60, 0, 36), Color3.fromRGB(60, 60, 80))
        button.Name = "ZoneButton_" .. i
        button.Parent = screen
        hud.ZoneButtons[i] = button
        button.MouseButton1Click:Connect(function()
            state.Zone = i
            refresh()
        end)
    end

    -- Aura collection (endowment effect — visible ownership)
    hud.CollectionButton = newButton("AURAS", UDim2.new(0, 560, 0, 56), UDim2.new(0, 120, 0, 26), Color3.fromRGB(90, 70, 140))
    hud.CollectionButton.Name = "CollectionButton"
    hud.CollectionButton.Parent = screen

    hud.Collection = Instance.new("Frame")
    hud.Collection.Name = "Collection"
    hud.Collection.Size = UDim2.new(0, 430, 0, 84)
    hud.Collection.Position = UDim2.new(0.5, -215, 0, 278)
    hud.Collection.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    hud.Collection.BackgroundTransparency = 0.1
    hud.Collection.Visible = false
    hud.Collection.Parent = screen
    local collectionCorner = Instance.new("UICorner")
    collectionCorner.CornerRadius = UDim.new(0, 10)
    collectionCorner.Parent = hud.Collection

    hud.AuraSlots = {}
    for i, aura in ipairs(Config.AURAS) do
        local slot = Instance.new("Frame")
        slot.Name = "Slot_" .. i
        slot.Size = UDim2.new(0, 74, 0, 74)
        slot.Position = UDim2.new(0, 8 + (i - 1) * 84, 0, 5)
        slot.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        slot.Parent = hud.Collection
        local slotCorner = Instance.new("UICorner")
        slotCorner.CornerRadius = UDim.new(0, 8)
        slotCorner.Parent = slot
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.5
        label.Text = "???"
        label.Parent = slot
        hud.AuraSlots[i] = slot
    end

    -- Attack (visible only during a fight)
    hud.Attack = newButton("ATTACK", UDim2.new(0.5, -120, 1, -190), UDim2.new(0, 240, 0, 60), Color3.fromRGB(220, 60, 60))
    hud.Attack.Name = "Attack"
    hud.Attack.Visible = false
    hud.Attack.Parent = screen

    hud.Train = newButton("TRAIN", UDim2.new(0, 20, 1, -70), UDim2.new(0, 180, 0, 50), Color3.fromRGB(46, 160, 90))
    hud.Train.Name = "Train"
    hud.Train.Parent = screen

    hud.PowerUp = newButton("POWER +", UDim2.new(0, 210, 1, -70), UDim2.new(0, 180, 0, 50), Color3.fromRGB(190, 60, 60))
    hud.PowerUp.Name = "PowerUp"
    hud.PowerUp.Parent = screen

    hud.Daily = newButton("DAILY REWARD", UDim2.new(0, 400, 1, -70), UDim2.new(0, 180, 0, 50), Color3.fromRGB(70, 110, 220))
    hud.Daily.Name = "Daily"
    hud.Daily.Parent = screen

    hud.Fight = newButton("FIGHT BOSS", UDim2.new(0, 590, 1, -70), UDim2.new(0, 200, 0, 50), Color3.fromRGB(200, 120, 40))
    hud.Fight.Name = "Fight"
    hud.Fight.Parent = screen

    -- Death overlay
    hud.Death = Instance.new("Frame")
    hud.Death.Name = "DeathOverlay"
    hud.Death.Size = UDim2.new(1, 0, 1, 0)
    hud.Death.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
    hud.Death.BackgroundTransparency = 0.35
    hud.Death.Visible = false
    hud.Death.Parent = screen
    hud.DeathText = newLabel({
        Name = "DeathText", Text = "YOU DIED", Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 0.5, -60), TextSize = 48,
        Parent = hud.Death,
    })

    hud.Train.MouseButton1Click:Connect(function()
        r.Train:FireServer()
    end)
    hud.PowerUp.MouseButton1Click:Connect(function()
        r.BuyUpgrade:FireServer("Power")
    end)
    hud.Daily.MouseButton1Click:Connect(function()
        r.ClaimDaily:FireServer()
    end)
    hud.Fight.MouseButton1Click:Connect(function()
        r.EnterZone:FireServer(state.Zone)
    end)
    hud.Attack.MouseButton1Click:Connect(function()
        if state.Boss and state.Boss.Alive then
            r.Attack:FireServer(state.Boss.Zone)
        end
    end)
    hud.CollectionButton.MouseButton1Click:Connect(function()
        hud.Collection.Visible = not hud.Collection.Visible
        refresh()
    end)

    refresh()
end

----------------------------------------------------------------
-- Server messages
----------------------------------------------------------------
local function onState(message, a, b, c, d, e, f)
    if message == "Loaded" then
        state.Energy = a.Energy
        state.Power = a.Power
        state.Stamina = a.Stamina
        state.Magnet = a.Magnet
        state.Zone = a.CurrentZone
        state.MaxZone = a.MaxZone
        state.Streak = a.DailyStreak
        state.HP = a.HP
        state.MaxHP = a.MaxHP
        state.AuraIds = a.Auras or {}
        setBar(hud.PlayerBar, a.HP / a.MaxHP, tostring(a.HP) .. "/" .. tostring(a.MaxHP))
        refresh()
    elseif message == "EnergyChanged" then
        state.Energy = a
        refresh()
        if b and b > 0 then
            flash("+" .. tostring(b) .. " Energy  (" .. tostring(c) .. ")")
        end
    elseif message == "Trained" then
        state.Energy = b
        refresh()
        flash("+" .. tostring(a) .. " Energy")
    elseif message == "UpgradeChanged" then
        if a == "Power" then
            state.Power = b
        elseif a == "Stamina" then
            state.Stamina = b
        elseif a == "Magnet" then
            state.Magnet = b
        end
        state.Energy = d
        refresh()
        flash(tostring(a) .. " upgraded to Lv " .. tostring(b))
    elseif message == "UpgradeFailed" then
        flash(tostring(b))
    elseif message == "DailyClaimed" then
        state.Streak = c
        refresh()
        flash("Day " .. tostring(a) .. " reward: +" .. tostring(b) .. " Energy")
    elseif message == "DailyFailed" then
        flash(tostring(a))
    elseif message == "AuraUnlocked" then
        state.AuraIds[#state.AuraIds + 1] = a
        refresh()
        flash(tostring(a) .. " (" .. tostring(b) .. ") unlocked!")
    elseif message == "ZoneLocked" then
        flash("Locked — need " .. tostring(b) .. " damage, you have " .. tostring(c) .. " (max zone " .. tostring(d) .. ")")
    elseif message == "ZoneEntered" then
        state.Zone = a
        state.Boss = { Zone = a, Name = b.Boss, HP = c, MaxHP = d, Alive = true }
        state.HP = e
        state.MaxHP = f
        hud.BossBar.Visible = true
        setBar(hud.BossBar, c / d, tostring(b.Boss) .. "  " .. tostring(c) .. "/" .. tostring(d))
        setBar(hud.PlayerBar, e / f, tostring(e) .. "/" .. tostring(f))
        refresh()
        flash("Entered " .. tostring(b.Name))
    elseif message == "BossDamaged" then
        if state.Boss then
            state.Boss.HP = a
            state.Boss.MaxHP = b
            setBar(hud.BossBar, a / b, tostring(state.Boss.Name) .. "  " .. tostring(a) .. "/" .. tostring(b))
        end
    elseif message == "BossDied" then
        state.Boss = nil
        hud.BossBar.Visible = false
        state.MaxZone = d
        refresh()
        flash(tostring(b) .. " defeated!  +" .. tostring(c) .. " Energy")
    elseif message == "PlayerDamaged" then
        state.HP = a
        state.MaxHP = b
        setBar(hud.PlayerBar, a / b, tostring(a) .. "/" .. tostring(b))
    elseif message == "PlayerDied" then
        state.Dead = true
        state.Boss = nil
        hud.BossBar.Visible = false
        hud.Death.Visible = true
        hud.DeathText.Text = "YOU DIED"
        task.delay(1, function()
            if hud.DeathText then
                hud.DeathText.Text = "Respawning..."
            end
        end)
    elseif message == "PlayerRespawned" then
        state.Dead = false
        state.Boss = nil
        state.HP = a
        state.MaxHP = b
        hud.BossBar.Visible = false
        hud.Death.Visible = false
        setBar(hud.PlayerBar, a / b, tostring(a) .. "/" .. tostring(b))
    end
end

----------------------------------------------------------------
-- Boot (retries until the server has created the remotes)
----------------------------------------------------------------
local function setup()
    local r = getRemotes()
    if not r then
        task.delay(0.5, setup)
        return
    end
    buildGui(r)
    r.State.OnClientEvent:Connect(onState)
end

setup()
