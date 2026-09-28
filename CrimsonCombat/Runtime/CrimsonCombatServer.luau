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
