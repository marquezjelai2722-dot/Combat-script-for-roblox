--[[
    CRIMSON COMBAT - PERFECT DELTA / EXECUTOR VERSION
    =================================================
    Fully self-contained. Creates tools, UI, effects, movement & animations
    at runtime. Nothing needs to exist in the game's official files.

    How to use:
    1. Paste this entire script into Delta and execute
    2. Or host it on a raw GitHub/Gist and run:
       loadstring(game:HttpGet("YOUR_RAW_URL"))()

    Features:
    - Floating crimson launcher + full menu
    - Tools created locally (Attack, Dash, Lunge, Hammer, AOE, Ultimate)
    - Smooth local movement / dash / lunge
    - Client-side hit detection + visual feedback
    - Ultimate charge system (local)
    - Clean UI with drag, stats, buttons
    - No external dependencies

    Note: Real damage to other players is limited by Roblox FilteringEnabled.
    This version gives strong local control, visuals, and hit feedback.
]]

--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Config
local CONFIG = {
    BasicDamage = 12,
    LungeDamage = 24,
    HammerDamage = 32,
    AOEDamage = 28,
    UltimateDamage = 60,

    LungeRange = 18,
    TargetRange = 70,
    HammerRadius = 12,
    AOERadius = 22,

    HitCharge = 6,
    MaxUltimate = 100,

    DashCooldown = 1.1,
    LungeCooldown = 3.5,
    HammerCooldown = 5.5,
    AOECooldown = 7.5,
    UltimateCooldown = 2.5,

    BaseSpeed = 16,
    MaxSpeed = 32,
    KnockbackForce = 60,
}

--// State
local State = {
    Ultimate = 0,
    Power = 0,
    Busy = false,
    Last = {
        Dash = 0,
        Lunge = 0,
        Hammer = 0,
        AOE = 0,
        Ultimate = 0,
    },
    ToolsGiven = false,
}

--// Colors
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

--// Helpers
local function notify(msg)
    print("[Crimson Combat] " .. tostring(msg))
end

local function getCharacter()
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return nil end
    return char, humanoid, root
end

local function canUse(name)
    local now = tick()
    local last = State.Last[name] or 0
    local cd = CONFIG[name .. "Cooldown"] or 1
    return (now - last) >= cd and not State.Busy
end

local function setCooldown(name)
    State.Last[name] = tick()
end

local function addUltimate(amount)
    State.Ultimate = math.clamp(State.Ultimate + amount, 0, CONFIG.MaxUltimate)
    LocalPlayer:SetAttribute("CrimsonUltimate", State.Ultimate)
end

local function addPower(amount)
    State.Power = math.clamp(State.Power + amount, 0, 20)
    LocalPlayer:SetAttribute("CrimsonPower", State.Power)
end

--// Visual Effects
local function createEffect(position, size, color)
    size = size or 8
    color = color or C.red

    local part = Instance.new("Part")
    part.Name = "CrimsonEffect"
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Size = Vector3.new(0.4, 0.4, 0.4)
    part.CFrame = CFrame.new(position)
    part.Transparency = 0.2
    part.Parent = Workspace

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = part

    local tween = TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(size, size, size),
        Transparency = 1
    })
    tween:Play()
    Debris:AddItem(part, 0.5)
end

local function createShockwave(position, radius)
    local ring = Instance.new("Part")
    ring.Name = "CrimsonShockwave"
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = C.pink
    ring.Size = Vector3.new(1, 0.2, 1)
    ring.CFrame = CFrame.new(position)
    ring.Transparency = 0.3
    ring.Parent = Workspace

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Parent = ring

    local tween = TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(radius * 2, 0.15, radius * 2),
        Transparency = 1
    })
    tween:Play()
    Debris:AddItem(ring, 0.6)
end

--// Hit Detection (client-side visual + local feedback)
local function getClosestTarget(range)
    local char, humanoid, root = getCharacter()
    if not root then return nil end

    local closest, closestDist = nil, range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local targetRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if targetRoot and targetHum and targetHum.Health > 0 then
                local dist = (targetRoot.Position - root.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = plr
                end
            end
        end
    end
    return closest, closestDist
end

local function applyLocalKnockback(fromRoot, targetRoot)
    if not targetRoot or not fromRoot then return end
    local direction = (targetRoot.Position - fromRoot.Position).Unit
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVel.Velocity = direction * CONFIG.KnockbackForce + Vector3.new(0, 35, 0)
    bodyVel.Parent = targetRoot
    Debris:AddItem(bodyVel, 0.25)
end

--// Abilities
local function basicAttack()
    if not canUse("Dash") then return end -- reuse timing feel
    local char, humanoid, root = getCharacter()
    if not root then return end

    State.Busy = true
    setCooldown("Dash") -- light cooldown feel

    createEffect(root.Position + root.CFrame.LookVector * 4, 6, C.red)

    local target = select(1, getClosestTarget(8))
    if target and target.Character then
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot then
            createEffect(tRoot.Position, 7, C.pink)
            addUltimate(CONFIG.HitCharge)
            addPower(0.4)
        end
    end

    task.wait(0.25)
    State.Busy = false
end

local function dash()
    if not canUse("Dash") then return end
    local char, humanoid, root = getCharacter()
    if not root then return end

    State.Busy = true
    setCooldown("Dash")

    local direction = root.CFrame.LookVector
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e5, 0, 1e5)
    bodyVel.Velocity = direction * 85
    bodyVel.Parent = root
    Debris:AddItem(bodyVel, 0.18)

    createEffect(root.Position, 5, C.crimson)
    addUltimate(2)

    task.wait(0.2)
    State.Busy = false
end

local function lunge()
    if not canUse("Lunge") then return end
    local char, humanoid, root = getCharacter()
    if not root then return end

    State.Busy = true
    setCooldown("Lunge")

    local target, dist = getClosestTarget(CONFIG.LungeRange)
    if target and target.Character then
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot then
            local goal = tRoot.Position - tRoot.CFrame.LookVector * 3
            local bodyPos = Instance.new("BodyPosition")
            bodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bodyPos.Position = goal
            bodyPos.P = 12000
            bodyPos.Parent = root
            Debris:AddItem(bodyPos, 0.35)

            createEffect(tRoot.Position, 9, C.gold)
            addUltimate(CONFIG.HitCharge + 3)
            addPower(0.8)
        end
    else
        -- forward lunge
        local bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(1e5, 0, 1e5)
        bodyVel.Velocity = root.CFrame.LookVector * 95
        bodyVel.Parent = root
        Debris:AddItem(bodyVel, 0.22)
        createEffect(root.Position + root.CFrame.LookVector * 6, 7, C.red)
    end

    task.wait(0.4)
    State.Busy = false
end

local function hammer()
    if not canUse("Hammer") then return end
    local char, humanoid, root = getCharacter()
    if not root then return end

    State.Busy = true
    setCooldown("Hammer")

    createShockwave(root.Position, CONFIG.HammerRadius)
    createEffect(root.Position, 14, C.crimson)

    local target = select(1, getClosestTarget(CONFIG.HammerRadius))
    if target then
        addUltimate(CONFIG.HitCharge + 4)
        addPower(1.2)
    end

    task.wait(0.45)
    State.Busy = false
end

local function aoe()
    if not canUse("AOE") then return end
    local char, humanoid, root = getCharacter()
    if not root then return end

    State.Busy = true
    setCooldown("AOE")

    createShockwave(root.Position, CONFIG.AOERadius)
    createEffect(root.Position, 18, C.pink)

    local hitCount = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and tHum and tHum.Health > 0 then
                local dist = (tRoot.Position - root.Position).Magnitude
                if dist <= CONFIG.AOERadius then
                    hitCount += 1
                    createEffect(tRoot.Position, 6, C.gold)
                end
            end
        end
    end

    if hitCount > 0 then
        addUltimate(CONFIG.HitCharge * hitCount)
        addPower(1.5)
    end

    task.wait(0.5)
    State.Busy = false
end

local function ultimate()
    if not canUse("Ultimate") or State.Ultimate < 100 then
        notify("Ultimate not ready (" .. math.floor(State.Ultimate) .. "%)")
        return
    end

    local char, humanoid, root = getCharacter()
    if not root then return end

    State.Busy = true
    setCooldown("Ultimate")
    State.Ultimate = 0
    LocalPlayer:SetAttribute("CrimsonUltimate", 0)

    -- launch up
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVel.Velocity = Vector3.new(0, 80, 0)
    bodyVel.Parent = root
    Debris:AddItem(bodyVel, 0.35)

    createEffect(root.Position, 10, C.gold)
    task.wait(0.4)

    local target = select(1, getClosestTarget(CONFIG.TargetRange))
    if target and target.Character then
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot then
            local bodyPos = Instance.new("BodyPosition")
            bodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bodyPos.Position = tRoot.Position - tRoot.CFrame.LookVector * 3.5
            bodyPos.P = 18000
            bodyPos.Parent = root
            Debris:AddItem(bodyPos, 0.4)

            createEffect(tRoot.Position, 16, C.gold)
            createShockwave(tRoot.Position, 14)
            addPower(3)
        end
    end

    task.wait(0.55)
    State.Busy = false
    notify("ULTIMATE USED")
end

--// Create Tools
local function createTool(name, callback)
    local tool = Instance.new("Tool")
    tool.Name = name
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.ToolTip = "Crimson Combat"
    tool.Activated:Connect(function()
        callback()
    end)
    tool.Parent = LocalPlayer:WaitForChild("Backpack")
    return tool
end

local function giveTools()
    if State.ToolsGiven then return end
    State.ToolsGiven = true

    createTool("Crimson Attack", basicAttack)
    createTool("Crimson Dash", dash)
    createTool("Crimson Lunge", lunge)
    createTool("Crimson Hammer", hammer)
    createTool("Crimson AOE", aoe)
    createTool("Crimson Ultimate", ultimate)

    notify("Combat tools created")
end

--// UI
local function createUI()
    local old = PlayerGui:FindFirstChild("CrimsonCombatUI")
    if old then old:Destroy() end

    local function corner(obj, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r)
        c.Parent = obj
    end

    local function stroke(obj, color, transparency)
        local s = Instance.new("UIStroke")
        s.Color = color or C.line
        s.Transparency = transparency or 0.25
        s.Thickness = 1.2
        s.Parent = obj
        return s
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "CrimsonCombatUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = PlayerGui

    -- Launcher
    local launcher = Instance.new("TextButton")
    launcher.Name = "CombatLauncher"
    launcher.Size = UDim2.fromOffset(64, 64)
    launcher.Position = UDim2.new(1, -80, 0.5, -32)
    launcher.BackgroundColor3 = C.red
    launcher.Text = "⚔"
    launcher.TextColor3 = C.text
    launcher.TextSize = 28
    launcher.Font = Enum.Font.GothamBlack
    launcher.AutoButtonColor = false
    launcher.Parent = gui
    corner(launcher, 32)
    stroke(launcher, C.pink, 0.15)

    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(280, 420)
    main.Position = UDim2.new(1, -310, 0.5, -210)
    main.BackgroundColor3 = C.bg
    main.Visible = false
    main.Parent = gui
    corner(main, 14)
    stroke(main, C.line, 0.2)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = C.panel
    header.Parent = main
    corner(header, 14)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.fromOffset(16, 0)
    title.Text = "CRIMSON COMBAT"
    title.TextColor3 = C.text
    title.TextSize = 18
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(36, 36)
    close.Position = UDim2.new(1, -42, 0.5, -18)
    close.BackgroundColor3 = C.crimson
    close.Text = "✕"
    close.TextColor3 = C.text
    close.TextSize = 16
    close.Font = Enum.Font.GothamBold
    close.Parent = header
    corner(close, 8)

    -- Stats
    local stats = Instance.new("Frame")
    stats.Size = UDim2.new(1, -24, 0, 70)
    stats.Position = UDim2.fromOffset(12, 58)
    stats.BackgroundColor3 = C.panel
    stats.Parent = main
    corner(stats, 10)

    local ultLabel = Instance.new("TextLabel")
    ultLabel.BackgroundTransparency = 1
    ultLabel.Size = UDim2.new(1, -16, 0, 20)
    ultLabel.Position = UDim2.fromOffset(10, 8)
    ultLabel.Text = "ULTIMATE"
    ultLabel.TextColor3 = C.muted
    ultLabel.TextSize = 12
    ultLabel.Font = Enum.Font.GothamBold
    ultLabel.TextXAlignment = Enum.TextXAlignment.Left
    ultLabel.Parent = stats

    local ultValue = Instance.new("TextLabel")
    ultValue.Name = "UltValue"
    ultValue.BackgroundTransparency = 1
    ultValue.Size = UDim2.new(0, 60, 0, 20)
    ultValue.Position = UDim2.new(1, -70, 0, 8)
    ultValue.Text = "0%"
    ultValue.TextColor3 = C.gold
    ultValue.TextSize = 14
    ultValue.Font = Enum.Font.GothamBlack
    ultValue.Parent = stats

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -20, 0, 10)
    barBg.Position = UDim2.fromOffset(10, 32)
    barBg.BackgroundColor3 = C.panel2
    barBg.Parent = stats
    corner(barBg, 5)

    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.fromScale(0, 1)
    bar.BackgroundColor3 = C.red
    bar.Parent = barBg
    corner(bar, 5)

    local powerValue = Instance.new("TextLabel")
    powerValue.Name = "PowerValue"
    powerValue.BackgroundTransparency = 1
    powerValue.Size = UDim2.new(1, -16, 0, 18)
    powerValue.Position = UDim2.fromOffset(10, 46)
    powerValue.Text = "POWER  0.0"
    powerValue.TextColor3 = C.muted
    powerValue.TextSize = 12
    powerValue.Font = Enum.Font.Gotham
    powerValue.TextXAlignment = Enum.TextXAlignment.Left
    powerValue.Parent = stats

    local stateValue = Instance.new("TextLabel")
    stateValue.Name = "StateValue"
    stateValue.BackgroundTransparency = 1
    stateValue.Size = UDim2.new(1, -16, 0, 18)
    stateValue.Position = UDim2.fromOffset(10, 0)
    stateValue.Text = "READY"
    stateValue.TextColor3 = C.green
    stateValue.TextSize = 13
    stateValue.Font = Enum.Font.GothamBold
    stateValue.Visible = false -- we use the header feel
    stateValue.Parent = stats

    -- Buttons
    local buttonsFrame = Instance.new("Frame")
    buttonsFrame.Size = UDim2.new(1, -24, 0, 260)
    buttonsFrame.Position = UDim2.fromOffset(12, 140)
    buttonsFrame.BackgroundTransparency = 1
    buttonsFrame.Parent = main

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.Parent = buttonsFrame

    local function makeButton(text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = C.text
        btn.TextSize = 15
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = true
        btn.Parent = buttonsFrame
        corner(btn, 9)
        stroke(btn, C.line, 0.35)
        btn.Activated:Connect(callback)
        return btn
    end

    makeButton("⚔  ATTACK", C.red, basicAttack)
    makeButton("💨  DASH", C.crimson, dash)
    makeButton("⚡  LUNGE", C.panel2, lunge)
    makeButton("🔨  HAMMER", C.panel2, hammer)
    makeButton("💥  AOE", C.panel2, aoe)
    makeButton("🌟  ULTIMATE", C.gold, ultimate)

    -- Drag support
    local function makeDraggable(frame, handle)
        local dragging, startPos, startInput
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                startPos = frame.Position
                startInput = input.Position
            end
        end)
        handle.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - startInput
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    makeDraggable(main, header)
    makeDraggable(launcher, launcher)

    -- Toggle
    launcher.Activated:Connect(function()
        main.Visible = not main.Visible
    end)
    close.Activated:Connect(function()
        main.Visible = false
    end)

    -- Live stats
    local function refresh()
        local ult = State.Ultimate
        ultValue.Text = string.format("%d%%", math.floor(ult))
        bar.Size = UDim2.fromScale(math.clamp(ult / 100, 0, 1), 1)
        powerValue.Text = string.format("POWER  %.1f", State.Power)
        if ult >= 100 then
            ultValue.TextColor3 = C.gold
        else
            ultValue.TextColor3 = C.text
        end
    end

    RunService.Heartbeat:Connect(refresh)
    refresh()

    return gui
end

--// Init
local function init()
    createUI()
    giveTools()

    LocalPlayer.CharacterAdded:Connect(function()
        State.ToolsGiven = false
        task.wait(0.8)
        giveTools()
    end)

    -- Keep tools after death
    if LocalPlayer.Character then
        giveTools()
    end

    notify("Crimson Combat Delta version loaded successfully")
    print("Crimson Combat | Tools + UI ready | Everything created at runtime")
end

init()
