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
