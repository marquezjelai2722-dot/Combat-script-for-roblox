--!strict
-- CRIMSON COMBAT ONE-DROP INSTALLER
-- Run this ONCE from Roblox Studio's Command Bar.
-- It creates the secure server Script and the client LocalScript
-- in their correct Roblox locations.
--
-- Roblox cannot securely execute server authority and client UI as one
-- LocalScript. This installer is the single file you paste/run; it installs
-- the two required runtime scripts automatically.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

local SERVER_NAME = "CrimsonCombatServer"
local CLIENT_NAME = "CrimsonCombatClient"

local SERVER_SOURCE = [=[
--!strict
-- CRIMSON COMBAT - SINGLE STANDALONE SERVER LUau
--
-- This is intentionally independent of Crimson Hub.
-- Put this Script in ServerScriptService (or another server Script context).
-- It creates the Combat Tools itself, so no existing Tool, GUI, RemoteEvent,
-- tab, or Crimson Hub code is required.
--
-- Roblox security note:
-- A secure server-authoritative combat system cannot literally combine client
-- execution and server execution into one LocalScript. This file therefore
-- puts all combat authority in one server script and uses Roblox Tool input,
-- which already works with mouse/touch/gamepad without a separate client file.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local CONFIG = {
    BasicDamage = 12,
    LungeDamage = 24,
    HammerDamage = 32,
    AOEDamage = 28,
    UltimateDamage = 60,

    LungeRange = 15,
    TargetRange = 60,
    HammerRadius = 10,
    AOERadius = 20,

    HitCharge = 5,
    MaxUltimate = 100,

    DashCooldown = 1.25,
    LungeCooldown = 4,
    HammerCooldown = 6,
    AOECooldown = 8,
    UltimateCooldown = 3,

    BaseSpeed = 16,
    MaxSpeed = 30,
    Knockback = 55,
}

local states: {[Player]: any} = {}

local function stateFor(player: Player)
    local state = states[player]
    if not state then
        state = {
            ultimate = 0,
            power = 0,
            last = {},
            busy = false,
            weapon = nil,
        }
        states[player] = state
    end
    player:SetAttribute("CrimsonUltimate", state.ultimate)
    player:SetAttribute("CrimsonPower", state.power)
    return state
end

local function characterOf(player: Player)
    local character = player.Character
    if not character then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root or humanoid.Health <= 0 then
        return nil
    end

    return character, humanoid, root
end

local function notify(player: Player, message: string)
    -- Server-only feedback that works without a client script.
    print("[Crimson Combat] " .. player.Name .. ": " .. message)
end

local function updateSpeed(player: Player)
    local state = stateFor(player)
    local _, humanoid = characterOf(player)
    if humanoid then
        humanoid.WalkSpeed = math.clamp(
            CONFIG.BaseSpeed + state.power,
            CONFIG.BaseSpeed,
            CONFIG.MaxSpeed
        )
    end
end

local function cooldownReady(state, key: string, duration: number)
    local now = os.clock()
    if now - (state.last[key] or 0) < duration then
        return false
    end
    state.last[key] = now
    return true
end

local function effect(position: Vector3, radius: number)
    local part = Instance.new("Part")
    part.Name = "CrimsonImpact"
    part.Shape = Enum.PartType.Ball
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Transparency = 0.45
    part.Size = Vector3.new(radius, radius, radius)
    part.Position = position
    part.Parent = workspace
    Debris:AddItem(part, 0.25)
end

local function knockback(attackerRoot: BasePart, targetRoot: BasePart)
    local delta = targetRoot.Position - attackerRoot.Position
    if delta.Magnitude < 0.01 then return end
    targetRoot.AssemblyLinearVelocity =
        delta.Unit * CONFIG.Knockback + Vector3.new(0, 20, 0)
end

local function rewardHit(player: Player)
    local state = stateFor(player)
    state.ultimate = math.clamp(
        state.ultimate + CONFIG.HitCharge,
        0,
        CONFIG.MaxUltimate
    )
    state.power += 0.1
    player:SetAttribute("CrimsonUltimate", state.ultimate)
    player:SetAttribute("CrimsonPower", state.power)
    updateSpeed(player)
    if state.ultimate >= CONFIG.MaxUltimate then
        notify(player, "ULTIMATE READY")
    else
        notify(player, string.format("ULTIMATE %d%%", math.floor(state.ultimate)))
    end
end

local function nearestTarget(player: Player, maxDistance: number)
    local _, _, root = characterOf(player)
    if not root then return nil end

    local best: Player? = nil
    local bestDistance = maxDistance

    for _, other in Players:GetPlayers() do
        if other ~= player then
            local _, humanoid, otherRoot = characterOf(other)
            if humanoid and otherRoot then
                local distance = (otherRoot.Position - root.Position).Magnitude
                if distance <= bestDistance then
                    best = other
                    bestDistance = distance
                end
            end
        end
    end

    return best
end

local function hit(player: Player, target: Player?, damageAmount: number)
    if not target or target == player then return false end

    local _, _, attackerRoot = characterOf(player)
    local _, targetHumanoid, targetRoot = characterOf(target)
    if not attackerRoot or not targetHumanoid or not targetRoot then
        return false
    end

    if (targetRoot.Position - attackerRoot.Position).Magnitude > CONFIG.TargetRange then
        return false
    end

    targetHumanoid:TakeDamage(damageAmount)
    knockback(attackerRoot, targetRoot)
    rewardHit(player)
    return true
end

local function makeWeapon(player: Player)
    local character, _, root = characterOf(player)
    if not character then return end

    local old = character:FindFirstChild("CrimsonGreatsword")
    if old then old:Destroy() end

    local model = Instance.new("Model")
    model.Name = "CrimsonGreatsword"

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.35, 1.5, 0.35)
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = model

    local blade = Instance.new("Part")
    blade.Name = "Blade"
    blade.Size = Vector3.new(0.7, 5, 0.3)
    blade.CanCollide = false
    blade.Massless = true
    blade.Material = Enum.Material.Neon
    blade.Parent = model

    handle.CFrame = root.CFrame * CFrame.new(1.1, -0.2, -1)
    blade.CFrame = handle.CFrame * CFrame.new(0, 3.1, 0)

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = root
    weld.Parent = handle

    local bladeWeld = Instance.new("WeldConstraint")
    bladeWeld.Part0 = blade
    bladeWeld.Part1 = handle
    bladeWeld.Parent = blade

    model.Parent = character

    local highlight = Instance.new("Highlight")
    highlight.Name = "CrimsonAura"
    highlight.FillTransparency = 0.7
    highlight.Parent = character
end

local function basic(player: Player)
    local state = stateFor(player)
    if state.busy then return end
    local target = nearestTarget(player, 11)
    if target then hit(player, target, CONFIG.BasicDamage) end
end

local function dash(player: Player)
    local state = stateFor(player)
    if not cooldownReady(state, "dash", CONFIG.DashCooldown) then return end

    local _, _, root = characterOf(player)
    if not root then return end

    root.AssemblyLinearVelocity =
        root.CFrame.LookVector * 90 + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
end

local function lunge(player: Player)
    local state = stateFor(player)
    if state.busy or not cooldownReady(state, "lunge", CONFIG.LungeCooldown) then return end

    local _, _, root = characterOf(player)
    local target = nearestTarget(player, CONFIG.LungeRange)
    if not root or not target then return end

    local _, _, targetRoot = characterOf(target)
    if not targetRoot then return end

    state.busy = true
    root.CFrame = CFrame.lookAt(
        targetRoot.Position - targetRoot.CFrame.LookVector * 3,
        targetRoot.Position
    )
    task.wait(0.12)
    hit(player, target, CONFIG.LungeDamage)
    state.busy = false
end

local function hammer(player: Player)
    local state = stateFor(player)
    if state.busy or not cooldownReady(state, "hammer", CONFIG.HammerCooldown) then return end

    local _, _, root = characterOf(player)
    if not root then return end

    state.busy = true
    task.wait(0.2)
    effect(root.Position, 10)

    for _, target in Players:GetPlayers() do
        if target ~= player then
            local _, humanoid, targetRoot = characterOf(target)
            if humanoid and targetRoot and
                (targetRoot.Position - root.Position).Magnitude <= CONFIG.HammerRadius then
                hit(player, target, CONFIG.HammerDamage)
            end
        end
    end

    state.busy = false
end

local function aoe(player: Player)
    local state = stateFor(player)
    if state.busy or not cooldownReady(state, "aoe", CONFIG.AOECooldown) then return end

    local _, _, root = characterOf(player)
    if not root then return end

    state.busy = true
    effect(root.Position, CONFIG.AOERadius)

    for _, target in Players:GetPlayers() do
        if target ~= player then
            local _, humanoid, targetRoot = characterOf(target)
            if humanoid and targetRoot and
                (targetRoot.Position - root.Position).Magnitude <= CONFIG.AOERadius then
                hit(player, target, CONFIG.AOEDamage)
            end
        end
    end

    state.busy = false
end

local function ultimate(player: Player)
    local state = stateFor(player)
    if state.busy or state.ultimate < CONFIG.MaxUltimate then return end
    if not cooldownReady(state, "ultimate", CONFIG.UltimateCooldown) then return end

    local character, humanoid, root = characterOf(player)
    local target = nearestTarget(player, CONFIG.TargetRange)
    if not character or not humanoid or not root or not target then return end

    local _, targetHumanoid, targetRoot = characterOf(target)
    if not targetHumanoid or not targetRoot then return end

    state.ultimate = 0
    player:SetAttribute("CrimsonUltimate", 0)
    state.busy = true
    notify(player, "ULTIMATE USED - CHARGE RESET TO 0%")

    local oldSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 4

    root.AssemblyLinearVelocity = Vector3.new(0, 65, 0)
    task.wait(0.45)

    if targetHumanoid.Health > 0 then
        root.CFrame = CFrame.lookAt(
            targetRoot.Position - targetRoot.CFrame.LookVector * 3,
            targetRoot.Position
        )
        effect(targetRoot.Position, 14)
        targetHumanoid:TakeDamage(CONFIG.UltimateDamage)
        knockback(root, targetRoot)
        rewardHit(player)
    end

    humanoid.WalkSpeed = oldSpeed
    state.busy = false
end

local function createTool(player: Player, name: string, callback)
    local tool = Instance.new("Tool")
    tool.Name = name
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.ToolTip = "Crimson Combat"
    tool.Activated:Connect(function()
        callback(player)
    end)
    tool.Parent = player:WaitForChild("Backpack")
    return tool
end

local function giveCombat(player: Player)
    local state = stateFor(player)
    if state.weapon then return end
    state.weapon = true

    makeWeapon(player)
    updateSpeed(player)

    createTool(player, "Crimson Attack", basic)
    createTool(player, "Crimson Dash", dash)
    createTool(player, "Crimson Lunge", lunge)
    createTool(player, "Crimson Hammer", hammer)
    createTool(player, "Crimson AOE", aoe)
    createTool(player, "Crimson Ultimate", ultimate)

    notify(player, "CRIMSON COMBAT EQUIPPED")
end

Players.PlayerAdded:Connect(function(player)
    stateFor(player)

    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        local state = stateFor(player)
        if state.weapon then
            makeWeapon(player)
            updateSpeed(player)
        end
    end)

    -- Owner gets the special combat package automatically.
    if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
        giveCombat(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    states[player] = nil
end)

for _, player in Players:GetPlayers() do
    task.spawn(function()
        stateFor(player)
        if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
            giveCombat(player)
        end
    end)
end

]=]
local CLIENT_SOURCE = [=[
--!strict
-- CRIMSON COMBAT UI - standalone client companion
-- Put this LocalScript in StarterPlayerScripts.
-- It is intentionally independent from Crimson Hub.
-- The server-side combat authority remains in Crimson_Combat_Standalone.luau.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("CrimsonCombatUI")
if old then old:Destroy() end

local C = {
    bg = Color3.fromRGB(7, 5, 10),
    panel = Color3.fromRGB(16, 11, 21),
    panel2 = Color3.fromRGB(25, 15, 31),
    red = Color3.fromRGB(205, 35, 62),
    crimson = Color3.fromRGB(132, 17, 42),
    pink = Color3.fromRGB(255, 70, 125),
    gold = Color3.fromRGB(255, 185, 70),
    green = Color3.fromRGB(63, 220, 132),
    text = Color3.fromRGB(248, 242, 248),
    muted = Color3.fromRGB(155, 139, 159),
    line = Color3.fromRGB(87, 34, 53),
}

local function corner(o: Instance, r: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = o
end

local function stroke(o: Instance, color: Color3?, transparency: number?)
    local s = Instance.new("UIStroke")
    s.Color = color or C.line
    s.Transparency = transparency or 0.25
    s.Thickness = 1
    s.Parent = o
    return s
end

local function gradient(o: GuiObject)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.red),
        ColorSequenceKeypoint.new(0.5, C.crimson),
        ColorSequenceKeypoint.new(1, C.panel2),
    })
    g.Rotation = 25
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(1, 0.75),
    })
    g.Parent = o
end

local function label(parent: Instance, text: string, size: number, position: UDim2, dimensions: UDim2)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = C.text
    l.TextSize = size
    l.Font = Enum.Font.GothamBold
    l.Position = position
    l.Size = dimensions
    l.Parent = parent
    return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "CrimsonCombatUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1001
gui.Parent = playerGui

-- Floating launcher. It is draggable independently of the menu.
local launcher = Instance.new("TextButton")
launcher.Name = "CombatLauncher"
launcher.Size = UDim2.fromOffset(62, 62)
launcher.Position = UDim2.new(1, -78, 0.5, -31)
launcher.BackgroundColor3 = C.red
launcher.Text = "⚔"
launcher.TextColor3 = C.text
launcher.TextSize = 27
launcher.Font = Enum.Font.GothamBlack
launcher.AutoButtonColor = false
launcher.Active = true
launcher.Parent = gui
corner(launcher, 31)
stroke(launcher, C.pink, 0.15)

gradient(launcher)

local main = Instance.new("Frame")
main.Name = "CombatMenu"
main.Size = UDim2.new(0, 390, 0, 500)
main.Position = UDim2.new(0.5, -195, 0.5, -250)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Visible = false
main.Active = true
main.Parent = gui
corner(main, 22)
stroke(main, C.red, 0.12)

local glow = Instance.new("Frame")
glow.Size = UDim2.new(1, 0, 0, 86)
glow.BackgroundColor3 = C.crimson
glow.BackgroundTransparency = 0.72
glow.BorderSizePixel = 0
glow.Parent = main
corner(glow, 22)
gradient(glow)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 76)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = main

label(header, "CRIMSON", 22, UDim2.fromOffset(18, 10), UDim2.new(1, -120, 0, 28))
local sub = label(header, "COMBAT CORE  //  ONLINE", 9, UDim2.fromOffset(20, 40), UDim2.new(1, -130, 0, 18))
sub.TextColor3 = C.muted

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(42, 42)
close.Position = UDim2.new(1, -54, 0, 15)
close.BackgroundColor3 = C.panel2
close.Text = "×"
close.TextColor3 = C.text
close.TextSize = 23
close.Font = Enum.Font.GothamBold
close.AutoButtonColor = false
close.Parent = header
corner(close, 14)

local stats = Instance.new("Frame")
stats.Position = UDim2.fromOffset(16, 88)
stats.Size = UDim2.new(1, -32, 0, 92)
stats.BackgroundColor3 = C.panel
stats.BorderSizePixel = 0
stats.Parent = main
corner(stats, 16)
stroke(stats)

local ultTitle = label(stats, "ULTIMATE CHARGE", 9, UDim2.fromOffset(13, 10), UDim2.new(1, -26, 0, 16))
ultTitle.TextColor3 = C.muted
local ultValue = label(stats, "0%", 18, UDim2.fromOffset(13, 28), UDim2.new(0, 70, 0, 30))

local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(86, 33)
barBack.Size = UDim2.new(1, -100, 0, 14)
barBack.BackgroundColor3 = Color3.fromRGB(35, 23, 39)
barBack.BorderSizePixel = 0
barBack.Parent = stats
corner(barBack, 7)

local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = C.red
bar.BorderSizePixel = 0
bar.Parent = barBack
corner(bar, 7)

local powerValue = label(stats, "POWER  0.0", 9, UDim2.fromOffset(13, 61), UDim2.new(0, 120, 0, 18))
powerValue.TextColor3 = C.muted
local stateValue = label(stats, "READY", 9, UDim2.new(1, -130, 0, 61), UDim2.fromOffset(117, 18))
stateValue.TextColor3 = C.green
stateValue.TextXAlignment = Enum.TextXAlignment.Right

local actions = Instance.new("Frame")
actions.Position = UDim2.fromOffset(16, 194)
actions.Size = UDim2.new(1, -32, 0, 240)
actions.BackgroundTransparency = 1
actions.Parent = main

local actionData = {
    {"Crimson Attack", "⚔  ATTACK", C.panel2},
    {"Crimson Dash", "➜  DASH", C.panel2},
    {"Crimson Lunge", "↗  LUNGE", C.panel2},
    {"Crimson Hammer", "⬟  HAMMER", C.panel2},
    {"Crimson AOE", "✦  CRIMSON AOE", C.panel2},
    {"Crimson Ultimate", "☄  ULTIMATE", C.crimson},
}

local buttons = {}
local cols = 2
local gap = 10
local bw = 174
local bh = 68

for i, data in ipairs(actionData) do
    local row = math.floor((i - 1) / cols)
    local col = (i - 1) % cols
    local b = Instance.new("TextButton")
    b.Name = data[1] .. "Button"
    b.Size = UDim2.fromOffset(bw, bh)
    b.Position = UDim2.fromOffset(col * (bw + gap), row * (bh + gap))
    b.BackgroundColor3 = data[3]
    b.Text = data[2]
    b.TextColor3 = C.text
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Active = true
    b.Parent = actions
    corner(b, 15)
    stroke(b, i == 6 and C.pink or C.line, 0.3)
    buttons[data[1]] = b

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = i == 6 and C.red or C.panel2:Lerp(C.red, 0.18)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = data[3]}):Play()
    end)
end

local hint = label(main, "DRAG THE WINDOW OR THE ⚔ BUTTON  •  COMBAT IS INDEPENDENT", 8, UDim2.fromOffset(18, 452), UDim2.new(1, -36, 0, 18))
hint.TextColor3 = C.muted
hint.TextXAlignment = Enum.TextXAlignment.Center

local function clampPosition(frame: GuiObject)
    local viewport = gui.AbsoluteSize
    local size = frame.AbsoluteSize
    local pos = frame.Position
    local x = math.clamp(pos.X.Offset, -viewport.X + 45, viewport.X - 45)
    local y = math.clamp(pos.Y.Offset, -viewport.Y + 45, viewport.Y - 45)
    frame.Position = UDim2.new(pos.X.Scale, x, pos.Y.Scale, y)
end

local function makeDraggable(frame: GuiObject, handle: GuiObject)
    local dragging = false
    local startInput
    local startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startInput = input.Position
            startPos = frame.Position
        end
    end)

    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            clampPosition(frame)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - startInput
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)
end

makeDraggable(main, header)
makeDraggable(launcher, launcher)

local function findTool(name: string): Tool?
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    local tool = (character and character:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
    if tool and tool:IsA("Tool") then return tool end
    return nil
end

local function fireTool(name: string)
    local tool = findTool(name)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not tool or not humanoid then
        stateValue.Text = "WAITING FOR COMBAT"
        stateValue.TextColor3 = C.gold
        return
    end

    humanoid:EquipTool(tool)
    task.wait()
    tool:Activate()
end

for name, button in pairs(buttons) do
    button.Activated:Connect(function()
        fireTool(name)
    end)
end

local function refreshStats()
    local ultimate = tonumber(player:GetAttribute("CrimsonUltimate")) or 0
    local power = tonumber(player:GetAttribute("CrimsonPower")) or 0
    ultValue.Text = string.format("%d%%", math.floor(ultimate))
    bar.Size = UDim2.fromScale(math.clamp(ultimate / 100, 0, 1), 1)
    powerValue.Text = string.format("POWER  %.1f", power)
    if ultimate >= 100 then
        stateValue.Text = "ULTIMATE READY"
        stateValue.TextColor3 = C.gold
    else
        stateValue.Text = "READY"
        stateValue.TextColor3 = C.green
    end
end

player:GetAttributeChangedSignal("CrimsonUltimate"):Connect(refreshStats)
player:GetAttributeChangedSignal("CrimsonPower"):Connect(refreshStats)

launcher.Activated:Connect(function()
    main.Visible = not main.Visible
end)
close.Activated:Connect(function()
    main.Visible = false
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    refreshStats()
end)

refreshStats()
print("[Crimson Combat UI] independent combat menu loaded")

]=]

local oldServer = ServerScriptService:FindFirstChild(SERVER_NAME)
if oldServer then oldServer:Destroy() end

local oldClient = StarterPlayerScripts:FindFirstChild(CLIENT_NAME)
if oldClient then oldClient:Destroy() end

local serverScript = Instance.new("Script")
serverScript.Name = SERVER_NAME
serverScript.Source = SERVER_SOURCE
serverScript.Parent = ServerScriptService

local clientScript = Instance.new("LocalScript")
clientScript.Name = CLIENT_NAME
clientScript.Source = CLIENT_SOURCE
clientScript.Parent = StarterPlayerScripts

print("[CrimsonCombat] Installed successfully.")
print("Server: ServerScriptService/" .. SERVER_NAME)
print("Client: StarterPlayer/StarterPlayerScripts/" .. CLIENT_NAME)
