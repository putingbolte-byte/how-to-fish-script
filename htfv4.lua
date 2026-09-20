--[[
    HTF v4  —  "how to fisch" for UGC (Place 130925859181789)
    Black/White mobile-friendly UI, drag-supported, Delta ready.

    Features:
      ▪ Auto Fish (cast → wait bite → auto reel, state machine on FishingPresentation)
      ▪ Auto Sell (controller-scan + sell-NPC prompt fallback)
      ▪ Fish ESP / Seagull ESP / Boss ESP (grayscale)
      ▪ Kill Aura (brass knuckles melee vs gulls & bosses)
      ▪ Click-to-Teleport overlay (touch + mouse)
      ▪ Island TP buttons (docks), Sell NPC TP
      ▪ Fly, NoClip, WalkSpeed / JumpPower sliders
      ▪ Boat speed multiplier (seated)
      ▪ Auto Wheel Spin (free daily spin)
      ▪ Auto Daily Claim
      ▪ Auto Chomp (keeps hunger up via ZombieChompPrompt)
    Grayscale palette only. Every module pcall-guarded against missing executor APIs.
--]]

-- ===== EXECUTOR API DETECTION =====
local Players = game:GetService("Players")                                                           local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")                                                 local player = Players.LocalPlayer
                                                                                                     local GENV = getgenv and getgenv() or _G
local hasGC  = pcall(function() return getgc(true) ~= nil end)
local hasConns = pcall(function() return getconnections(game:GetService("RunService").RenderStepped) ~= nil end)
local DrawingOK = pcall(function() return Drawing.new("Line") end)
if DrawingOK then pcall(function() Drawing.new("Line"):Remove() end) end

local function wrap(fn) --> run fn in a background thread
    coroutine.resume(coroutine.create(fn))
end

local CONFIG = {
    autoFish = false, autoSell = false, autoWheel = false, autoDaily = false,
    autoChomp = false,
    fishESP = false, gullESP = false, killAura = false,
    clickTP = false, fly = false, noclip = false,
    walkSpeed = 16, jumpPower = 50, boatMult = 1,
}
GENV.htfv4 = CONFIG

-- ===== UI THEME (strict black & white) =====
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GRAY  = Color3.fromRGB(140, 140, 140)
local DGRAY = Color3.fromRGB(50, 50, 50)

local function getMousePos()
    local ok, v = pcall(function() return UIS:GetMouseLocation() end)
    return ok and v or Vector2.new(0, 0)
end

local function mk(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props) do inst[k] = v end
    return inst
end

local function mkTextButton(parent, text, size, fg, bg)
    local b = mk("TextButton", {
        Parent = parent, Size = size, BackgroundColor3 = bg or WHITE,
        Text = text, TextColor3 = fg or BLACK,
        TextSize = 14, Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    })
    return b
end

local function mkToggle(parent, text, stateRef)
    local b = mkTextButton(parent, text, UDim2.new(1, 0, 0, 34), WHITE, DGRAY)
    local function paint()
        if stateRef.active then
            b.BackgroundColor3 = WHITE
            b.TextColor3 = BLACK
        else
            b.BackgroundColor3 = DGRAY
            b.TextColor3 = WHITE
        end
    end
    paint()
    b.MouseButton1Click:Connect(paint)
    b.Activated:Connect(function()
        stateRef.active = not stateRef.active
        paint()
    end)
    return b
end

-- ===== MAIN PANEL (draggable by title bar) =====
local screen
do
    local sOk, s = pcall(function()
        if gethui then return gethui() end
        return game:GetService("CoreGui")
    end)
    screen = sOk and s or nil
end
if not screen then screen = player:WaitForChild("PlayerGui") end

local rootGui = mk("ScreenGui", {Name = "HTFv4Gui", Parent = screen, DisplayOrder = 999, IgnoreGuiInset = true, ResetOnSpawn = false})
local panel = mk("Frame", {
    Parent = rootGui, Name = "Main", Size = UDim2.new(0, 210, 0, 400),
    Position = UDim2.new(0.02, 0, 0.25, 0), BackgroundColor3 = BLACK,
    BorderSizePixel = 0, ZIndex = 2,
})
mk("UIStroke", {Parent = panel, Color = WHITE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})

local titleBar = mkTextButton(panel, "HTF v4  ─  UGC", UDim2.new(1, 0, 0, 30), BLACK, WHITE)
titleBar.ZIndex = 3

local body = mk("ScrollingFrame", {
    Parent = panel, Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -30),
    BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = WHITE,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
})
local layout = mk("UIListLayout", {Parent = body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)})
mk("UIPadding", {Parent = body, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)})

local sectionLabel = function(name)
    mk("TextLabel", {
        Parent = body, Size = UDim2.new(1, 0, 0, 20), Text = name,
        TextColor3 = WHITE, TextSize = 13, Font = Enum.Font.GothamBold,
        BackgroundTransparency = 1,
    })
end

-- drag (mouse + touch) by title bar
do
    local dragging = false
    local offset = Vector2.new(0, 0)
    titleBar.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            offset = getMousePos() - Vector2.new(panel.AbsolutePosition.X, panel.AbsolutePosition.Y)
        end
    end)
    UIS.InputChanged:Connect(function(input, gpe)
        if gpe or not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            if input.UserInputType == Enum.UserInputType.Touch then
                offset = Vector2.new(input.Position.X, input.Position.Y) -
                         Vector2.new(panel.AbsolutePosition.X, panel.AbsolutePosition.Y)
            end
            local m = getMousePos()
            panel.Position = UDim2.fromOffset(m.X - offset.X, m.Y - offset.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- collapse button in title bar
local collapseBtn = mkTextButton(panel, "━", UDim2.new(0, 26, 0, 26), WHITE, DGRAY)
collapseBtn.Position = UDim2.new(1, -30, 0, 2)
collapseBtn.ZIndex = 4
local collapsed = false
collapseBtn.Activated:Connect(function()
    collapsed = not collapsed
    panel.Size = collapsed and UDim2.new(0, 210, 0, 34) or UDim2.new(0, 210, 0, 400)
    collapseBtn.Text = collapsed and "+" or "━"
end)

-- ===== SIMPLE SLIDER (touch drag) =====
local function mkSlider(parent, nameLabel, min, max, default, onChanged, fmt)
    local row = mk("Frame", {Parent = parent, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1})
    local lbl = mk("TextLabel", {
        Parent = row, Size = UDim2.new(0.6, 0, 1, 0), Text = nameLabel,
        TextColor3 = WHITE, TextSize = 12, Font = Enum.Font.GothamBold,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local val = mk("TextLabel", {
        Parent = row, Size = UDim2.new(0.4, 0, 1, 0), Text = "0",
        TextColor3 = WHITE, TextSize = 12, Font = Enum.Font.Gotham,
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = mk("Frame", {Parent = row, Position = UDim2.new(0, 0, 0.75, 0), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = DGRAY})
    local fill = mk("Frame", {Parent = track, Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = WHITE})
    local knob = mk("TextButton", {Parent = track, Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.new(0, 12, 0, 13), BackgroundColor3 = WHITE, Text = ""})
    local value = default
    local function setFromFraction(frac)
        value = math.clamp(frac, 0, 1) * (max - min) + min
        if fmt then value = fmt(value) end
        val.Text = tostring(value)
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        knob.Position = UDim2.new((value - min) / (max - min), -6, 0, -4)
        onChanged(value)
    end
    local function fromMouse(input)
        if not input or input.UserInputType == Enum.UserInputType.Touch then
            local p = input and input.Position or getMousePos()
            setFromFraction((p.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1))
        elseif input.UserInputType == Enum.UserInputType.MouseMovement then
            local p = input.Position
            setFromFraction((p.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1))
        end
    end
    knob.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.Touch then
            fromMouse(input)
            local conn
            conn = UIS.InputChanged:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.Touch then fromMouse(i2) end
            end)
            UIS.InputEnded:Connect(function(i3)
                if i3.UserInputType == Enum.UserInputType.Touch then
                    conn:Disconnect()
                end
            end)
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            local conn
            conn = UIS.InputChanged:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.MouseMovement then fromMouse(i2) end
            end)
            UIS.InputEnded:Connect(function(i3)
                if i3.UserInputType == Enum.UserInputType.MouseButton1 then conn:Disconnect() end
            end)
        end
    end)
    setFromFraction(0.5)
    return row
end

-- ===== TOGGLE BINDINGS =====
local function boolToggle(name)
    local ref = {active = false}
    local b = mkToggle(body, name, ref)
    b.LayoutOrder = 0
    return ref
end

sectionLabel("COMBAT / FARM")
local tAutofish = boolToggle("Auto Fish")
local tAutosell = boolToggle("Auto Sell")
local tKillAura = boolToggle("Kill Aura")
local tAutoChomp = boolToggle("Auto Chomp (Hunger)")

sectionLabel("WORLD")
local tFishESP = boolToggle("Fish ESP")
local tGullESP = boolToggle("Seagull / Boss ESP")
local tClickTP = boolToggle("Click Teleport")
local tNoClip = boolToggle("NoClip")
local tFly = boolToggle("Fly  [wasd + shift/space]")

sectionLabel("PERKS")
local tAutoWheel = boolToggle("Auto Wheel Spin")
local tAutoDaily = boolToggle("Auto Daily Claim")
mkSlider(body, "Walk Speed", 16, 120, 16, function(v) CONFIG.walkSpeed = v end)
mkSlider(body, "Jump Power", 50, 350, 50, function(v) CONFIG.jumpPower = v end)
mkSlider(body, "Boat Speed x", 1, 5, 1, function(v) CONFIG.boatMult = v end)

sectionLabel("TELEPORT")
local islandKeys = {"Starter", "Island_2", "Island_3", "Island_4", "Island_5 (Volcano)", "Island_6 (Artic_Tundra)", "Boss", "Pearl Machine"}
local function islandPos(k)
    local map = Workspace:FindFirstChild("!! MAP")
    if map then
        for _, m in pairs(map:GetChildren()) do
            if m.Name:find(k, 1, true) or m.Name == k then
                local dock = m:FindFirstChild("Dock", true)
                if dock then
                    local p = dock:IsA("BasePart") and dock or dock:FindFirstChildWhichIsA("BasePart")
                    if p then return p.Position end
                end
                local any = m:FindFirstChildWhichIsA("BasePart")
                if any then return any.Position end
            end
        end
    end
    return nil
end
local function tpto(pos)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    pcall(function() char.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) end)
end
for _, k in ipairs(islandKeys) do
    local b = mkTextButton(body, k, UDim2.new(1, 0, 0, 28), WHITE, GRAY)
    b.BorderColor3 = BLACK
    b.LayoutOrder = 1
    b.Activated:Connect(function()
        local pos
        if k == "Boss" then
            local bw = Workspace:FindFirstChild("BossWorld")
            local any = bw and bw:FindFirstChildWhichIsA("BasePart", true)
            pos = any and any.Position or Vector3.new(0, 5, 0)
        elseif k == "Pearl Machine" then
            local pm = Workspace:FindFirstChild("PearlMachines")
            local first = pm and pm:FindFirstChildWhichIsA("Model")
            local any = first and first:FindFirstChildWhichIsA("BasePart", true)
            pos = any and any.Position or Vector3.new(0, 5, 0)
        else
            pos = islandPos(k)
        end
        if not pos then
            mk("TextLabel", {Parent = body, Text = "⚠ unknown island", TextColor3 = WHITE, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 2})
            return
        end
        tpto(pos)
    end)
end
local sellTP = mkTextButton(body, "Sell NPC", UDim2.new(1, 0, 0, 28), WHITE, GRAY)
sellTP.LayoutOrder = 1
sellTP.Activated:Connect(function()
    local npcs = Workspace:FindFirstChild("NPCs")
    local sell = npcs and npcs:FindFirstChild("Starter") and npcs.Starter:FindFirstChild("Sell")
    if sell then
        local any = sell:FindFirstChildWhichIsA("BasePart")
        if any then tpto(any.Position) end
    end
end)

sectionLabel("STATUS")
local statusBar = mk("TextLabel", {
    Parent = body, Size = UDim2.new(1, 0, 0, 30), Text = "idle.",
    TextColor3 = WHITE, TextSize = 12, Font = Enum.Font.Gotham,
    BackgroundTransparency = 1, TextWrapped = true, LayoutOrder = 0,
})

local function setStatus(s)
    statusBar.Text = s
end

-- ===== CLICK TELEPORT OVERLAY =====
local overlay = mk("TextButton", {Parent = rootGui, Text = "", BackgroundTransparency = 1, Visible = false, ZIndex = 1})
overlay.AutoButtonColor = false
overlay.InputBegan:Connect(function(input, gpe)
    if gpe or not tClickTP.active then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local p = input.UserInputType == Enum.UserInputType.Touch and input.Position or getMousePos()
    local cam = Workspace.CurrentCamera
    local ray = cam:ScreenPointToRay(p.X, p.Y)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {player.Character, Workspace:FindFirstChild("FishWorld")}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local res = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
    if res then
        tpto(res.Position)
        setStatus("tp → " .. tostring(res.Position))
    end
end)
RunService.Heartbeat:Connect(function()
    overlay.Visible = tClickTP.active
end)

-- ===== FLY / NOCLIP / SPEED / BOAT =====
local function isAlive()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") ~= nil
end

RunService.Heartbeat:Connect(function(dt)
    if not isAlive() then return end
    local char = player.Character
    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChildOfClass("Humanoid")

    -- walk / jump client override
    hum.WalkSpeed = CONFIG.walkSpeed
    hum.JumpPower = CONFIG.jumpPower

    -- noclip
    if tNoClip.active then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end

    -- fly
    if tFly.active then
        local input = Vector3.new(0, 0, 0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then input = input + Vector3.new(0, 0, -1) end
        if UIS:IsKeyDown(Enum.KeyCode.S) then input = input + Vector3.new(0, 0, 1) end
        if UIS:IsKeyDown(Enum.KeyCode.A) then input = input + Vector3.new(-1, 0, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.D) then input = input + Vector3.new(1, 0, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then input = input + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then input = input + Vector3.new(0, -1, 0) end
        local cam = Workspace.CurrentCamera
        local rel = cam.CFrame:VectorToWorldSpace(input)
        if rel.Magnitude > 0 then rel = rel.Unit * CONFIG.walkSpeed * 1.8 end
        hrp.AssemblyLinearVelocity = Vector3.new(rel.X, rel.Y + (input.Y > 0 and 0 or 0) + (input.Y < 0 and -6 or 0), rel.Z)
    end

    -- boat speed
    if CONFIG.boatMult > 1 and hum.SeatPart then
        local boat = hum.SeatPart:FindFirstAncestorOfClass("Model")
        if boat then
            local root = boat:FindFirstChild("BoatRoot") or boat.PrimaryPart
            if root then
                root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * CONFIG.boatMult
            end
        end
    end
end)

-- ===== TOOL HELPERS =====
local function equipTool(nameFrag)
    local char = player.Character
    local bp = player.Backpack
    local best
    for _, t in pairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find(nameFrag, 1, true) then best = t end
    end
    if best and char then
        best.Parent = char
        return best
    end
    -- already equipped?
    if char then
        for _, t in pairs(char:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(nameFrag, 1, true) then return t end
        end
    end
    return nil
end

local function clickButton(inst)
    if not inst or not hasConns then return false end
    local ok = pcall(function()
        local cons = getconnections(inst.Activated)
        if #cons > 0 then
            for _, c in pairs(cons) do c.Function() end
        end
        local cons2 = getconnections(inst.MouseButton1Click)
        for _, c in pairs(cons2) do c.Function() end
    end)
    return ok
end

local function triggerPrompt(inst)
    if not inst or not hasConns then return false end
    local ok = pcall(function()
        for _, c in pairs(getconnections(inst.Triggered)) do
            c.Function(inst, player)
        end
    end)
    return ok
end

local function simulateClick()
    -- VirtualUser mouse down/up: triggers Tool.Activated as a real click
    local ok = pcall(function()
        VU:CaptureController()
        VU:Button1Down(Vector2.new(0, 0))
    end)
    wait(0.06)
    pcall(function() VU:Button1Up(Vector2.new(0, 0)) end)
    return ok
end

-- ===== FISHING STATE MACHINE (driven by FishingPresentation labels) =====
local function getFishGui()
    local hud = player:WaitForChild("PlayerGui"):WaitForChild("HudGui", 5)
    return hud and hud:FindFirstChild("FishingPresentation")
end

local function fishingText()
    local g = getFishGui()
    if not g then return "" end
    for _, v in pairs(g:GetDescendants()) do
        if v:IsA("TextLabel") and v.Visible and v.Text ~= "" then
            local t = v.Text
            if t == "RELEASE TO CAST" or t == "WAIT FOR A BITE..." or t:find("REEL IN", 1, true) or t:find("FISH", 1, true) or t == "I GOT A" or t:find("CHARGE", 1, true) or t == "TAP" then
                return t
            end
        end
    end
    return ""
end

local function visibleButton(textFrag)
    local g = getFishGui()
    if not g then return nil end
    for _, v in pairs(g:GetDescendants()) do
        if (v:IsA("TextButton") or v:IsA("ImageButton")) and v.Visible and v:FindFirstChildWhichIsA("TextLabel")
            and v:FindFirstChildWhichIsA("TextLabel").Text:find(textFrag, 1, true) then
            return v
        end
    end
    return nil
end

local function doCast()
    -- hold ~0.35s charge, release
    simulateClick()
    wait(0.1)
end

local function doReel()
    -- STOP first (one-shot reel), fall back to TAP spam
    local stopBtn = visibleButton("STOP")
    if stopBtn then
        clickButton(stopBtn)
        wait(0.4)
        local txt = fishingText()
        if not txt:find("REEL IN", 1, true) then return true end
    end
    local tapBtn = visibleButton("TAP")
    if tapBtn then
        local start = tick()
        while tick() - start < 4 do
            local txt = fishingText()
            if not txt:find("REEL IN", 1, true) then return true end
            clickButton(tapBtn)
            wait(0.12)
        end
    end
    return false
end

local function fishTick()
    local rod = equipTool("rod")
    if not rod then
        -- maybe a free rod already equipped under different name
        local char = player.Character
        local rr = char and char:FindFirstChildOfClass("Tool")
        if not rr then
            setStatus("no fishing rod — buy one first")
            wait(3)
            return
        end
        rod = rr
    end
    local txt = fishingText()
    if txt == "" then
        wait(0.5)
        return
    end
    if txt == "RELEASE TO CAST" then
        simulateClick() -- begin charge
        wait(0.4)
        simulateClick() -- release (second click acts as release on most rod setups)
    elseif txt:find("WAIT FOR A BITE", 1, true) then
        wait(0.4) -- idle, wait state change
    elseif txt:find("REEL IN", 1, true) then
        doReel()
        wait(1.2)
    elseif txt:find("FISH", 1, true) or txt == "I GOT A" then
        -- catch announced → hand off to autosell; short pause so server finishes reward
        wait(1.5)
    elseif txt == "CHARGE" then
        wait(0.2)
    else
        wait(0.4)
    end
end

-- ===== AUTO SELL (controller scan → sell NPC prompt fallback) =====
local sellTriedCache = {}

local function tryGCControllerSell()
    if not hasGC then return false end
    local candidates = {}
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            for k, fn in pairs(v) do
                if type(fn) == "function" then
                    local ok, info = pcall(function() return debug.getinfo(fn, "S") end)
                    if ok and info and info.source then
                        local src = info.source:lower()
                        if src:find("sellanywhere", 1, true) or src:find("fishsale", 1, true)
                           or src:find("sellcontroller", 1, true) then
                            local name = tostring(k):lower()
                            if name:find("sell", 1, true) then
                                candidates[#candidates + 1] = {tbl = v, key = k, fn = fn}
                            end
                        end
                    end
                end
            end
        end
    end
    for _, c in pairs(candidates) do
        local ok = pcall(function()
            local m = c.tbl[c.key]
            if type(m) == "function" then m(c.tbl) else m() end
        end)
        if ok then return true end
    end
    return false
end

local function doSell()
    if tryGCControllerSell() then
        setStatus("sold via controller")
        return
    end
    -- fallback: walk to fallback seller, trigger prompts
    local npcs = Workspace:FindFirstChild("NPCs")
    local starter = npcs and npcs:FindFirstChild("Starter")
    local sell = starter and starter:FindFirstChild("Sell")
    if not sell then
        for _, s in pairs(Workspace:GetDescendants()) do
            if s:IsA("Model") and s:GetAttribute("FishNpcRole") == "Sell" then sell = s break end
        end
    end
    if not sell then
        setStatus("no seller found")
        return
    end
    local posPart = sell:FindFirstChildWhichIsA("BasePart")
    if posPart then tpto(posPart.Position) end
    wait(0.8)
    local all = sell:FindFirstChild("SellAllFishPrompt", true)
    local one = sell:FindFirstChild("SellFishPrompt", true)
    if all then triggerPrompt(all) end
    wait(0.4)
    if one then triggerPrompt(one) end
    setStatus("sell prompts fired")
end

-- ===== ESP (grayscale) =====
local espObjs = {}
local function makeEsp()
    local line1 = Drawing.new("Line")
    local line2 = Drawing.new("Line")
    local line3 = Drawing.new("Line")
    local line4 = Drawing.new("Line")
    local txt = Drawing.new("Text")
    txt.Size = 12
    txt.Center = true
    txt.Outline = false
    txt.Color = WHITE
    for _, l in pairs({line1, line2, line3, line4}) do
        l.Thickness = 1
        l.Color = WHITE
        l.Transparency = 1
    end
    return {line1 = line1, line2 = line2, line3 = line3, line4 = line4, txt = txt}
end

local function freeEsp()
    for e, _ in pairs(espObjs) do
        pcall(function() e:Remove() end)
    end
    espObjs = {}
end

local function updateEsp()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local targets = {}
    if tFishESP.active then
        local fishes = Workspace:FindFirstChild("FishWorld") and Workspace.FishWorld:FindFirstChild("Fishes")
        if fishes then
            for _, m in pairs(fishes:GetChildren()) do
                if m:IsA("Model") and m:FindFirstChild("Root") or m:FindFirstChild("MinimumCombatHitbox") then
                    targets[#targets + 1] = {m = m, tag = "FISH"}
                end
            end
        end
    end
    if tGullESP.active then
        local gulls = Workspace:FindFirstChild("Seagulls")
        if gulls then
            for _, m in pairs(gulls:GetChildren()) do
                if m:IsA("Model") then
                    targets[#targets + 1] = {m = m, tag = "GULL"}
                end
            end
        end
        local bw = Workspace:FindFirstChild("BossWorld")
        local bosses = bw and bw:FindFirstChild("Bosses")
        if bosses then
            for _, m in pairs(bosses:GetChildren()) do
                if m:IsA("Model") then targets[#targets + 1] = {m = m, tag = "BOSS"} end
            end
        end
    end
    -- prune stale esp
    local seen = {}
    for _, t in pairs(targets) do
        local key = tostring(t.m)
        seen[key] = true
        local e = espObjs[key]
        if not e then
            e = makeEsp()
            espObjs[key] = e
        end
        local ok, pos = pcall(function()
            local primary = t.m:FindFirstChild("Root") or t.m.PrimaryPart or t.m:FindFirstChildWhichIsA("BasePart")
            return primary and primary.Position or t.m:GetPivot().Position
        end)
        if ok and pos then
            local sv, on = cam:WorldToViewportPoint(pos)
            if on then
                local size = math.clamp(500 / sv.Z, 30, 400)
                local half = size / 2
                e.line1.From = Vector2.new(sv.X - half, sv.Y - half)
                e.line1.To = Vector2.new(sv.X + half, sv.Y - half)
                e.line2.From = Vector2.new(sv.X + half, sv.Y - half)
                e.line2.To = Vector2.new(sv.X + half, sv.Y + half)
                e.line3.From = Vector2.new(sv.X + half, sv.Y + half)
                e.line3.To = Vector2.new(sv.X - half, sv.Y + half)
                e.line4.From = Vector2.new(sv.X - half, sv.Y + half)
                e.line4.To = Vector2.new(sv.X - half, sv.Y - half)
                e.txt.Position = Vector2.new(sv.X, sv.Y - half - 12)
                e.txt.Text = t.tag .. (t.m.Name ~= "" and (" · " .. t.m.Name) or "")
            end
        end
    end
    for key, e in pairs(espObjs) do
        if not seen[key] then
            pcall(function() e:Remove() end)
            espObjs[key] = nil
        end
    end
end
RunService.Heartbeat:Connect(function()
    if not DrawingOK then return end
    if tFishESP.active or tGullESP.active then updateEsp() else freeEsp() end
end)

-- ===== KILL AURA =====
local function findMeleeTool()
    return equipTool("knuckle") or equipTool("knife") or equipTool("bat")
end

local function attackTarget(m)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local targetPos = m:GetPivot().Position
    local combatPart = m:FindFirstChild("SeagullDamageHitbox", true) or
                       m:FindFirstChild("MinimumCombatHitbox", true) or
                       m:FindFirstChildWhichIsA("BasePart")
    local dist = (targetPos - hrp.Position).Magnitude
    if dist > 8 then
        tpto(targetPos)
        wait(0.15)
    end
    local tool = findMeleeTool()
    if tool then
        tool:Activate()
        wait(0.1)
        -- extra clicks push dps when no cooldown linger
        simulateClick()
        simulateClick()
    else
        simulateClick() -- bare-handed punch
        simulateClick()
    end
end

wrap(function()
    while true do
        if tKillAura.active and isAlive() then
            local zombies = Workspace:FindFirstChild("Seagulls")
            local hit = nil
            if zombies then
                for _, m in pairs(zombies:GetChildren()) do
                    if m:IsA("Model") and m:GetAttribute("Alive") and (m:GetAttribute("Health") or 0) > 0 then
                        hit = m
                        break
                    end
                end
            end
            local bw = Workspace:FindFirstChild("BossWorld")
            local bosses = bw and bw:FindFirstChild("Bosses")
            if bosses and not hit then
                for _, m in pairs(bosses:GetChildren()) do
                    if m:IsA("Model") then hit = m break end
                end
            end
            if hit then
                attackTarget(hit)
                setStatus("killing " .. hit.Name)
            end
            wait(0.6)
        else
            wait(1)
        end
    end
end)

-- ===== AUTO FISH MAIN LOOP =====
wrap(function()
    while true do
        if tAutofish.active and isAlive() then
            pcall(fishTick)
        else
            wait(1)
        end
    end
end)

-- ===== AUTO SELL LOOP =====
wrap(function()
    while true do
        wait(25)
        if tAutosell.active and isAlive() then
            pcall(doSell)
        end
    end
end)

-- ===== AUTO CHORMP (hunger) =====
local function getHunger()
    local hud = player:WaitForChild("PlayerGui"):FindFirstChild("HudGui")
    local c = hud and hud:FindFirstChild("HungerCounter")
    local vl = c and c:FindFirstChild("ValueLabel")
    return vl and tonumber(vl.Text) or 100
end
wrap(function()
    while true do
        wait(8)
        if tAutoChomp.active and isAlive() then
            local h = getHunger()
            if h < 45 then
                local char = player.Character
                local pr = char and char:FindFirstChild("HumanoidRootPart")
                local prompt = pr and pr:FindFirstChild("ZombieChompPrompt")
                if prompt then
                    triggerPrompt(prompt) --> hold-based prompt; also fire connection
                    wait(2.5)
                    setStatus("chomped (hunger " .. tostring(h) .. ")")
                end
            end
        end
    end
end)

-- ===== AUTO WHEEL SPIN =====
wrap(function()
    while true do
        wait(6)
        if tAutoWheel.active then
            local wg = player:WaitForChild("PlayerGui"):FindFirstChild("WheelGui")
            if wg then
                local free = wg:FindFirstChild("FreeSpinButton", true) or
                             (wg:FindFirstChild("Main") and wg.Main:FindFirstChildWhichIsA("TextButton"))
                if free and free.Visible then
                    clickButton(free)
                    setStatus("wheel spun")
                end
            end
        end
    end
end)

-- ===== AUTO DAILY CLAIM =====
wrap(function()
    while true do
        wait(10)
        if tAutoDaily.active then
            local dg = player:WaitForChild("PlayerGui"):FindFirstChild("DailyGui")
            if dg and dg:FindFirstChild("Main") then
                local claim = dg.Main:FindFirstChild("ClaimButton", true) or dg:FindFirstChild("ClaimButton", true)
                if claim and claim.Visible then
                    clickButton(claim)
                    setStatus("daily claimed")
                end
            end
        end
    end
end)

-- ===== PER-HEARTBEAT GUARD LOOP =====
wrap(function()
    while true do
        wait(1)
        if hasGC and DrawingOK and isAlive() then
            -- placeholder hook for future heartbeat features
        end
    end
end)

-- ===== LOCAL PLAYER HUD VALUE (pearl/cash readout) =====
local lastPearls = ""
RunService.Heartbeat:Connect(function()
    local hud = player:WaitForChild("PlayerGui"):FindFirstChild("HudGui")
    if hud then
        local pc = hud:FindFirstChild("PearlCounter")
        local vl = pc and (pc:FindFirstChildWhichIsA("TextLabel"))
        if vl and vl.Text ~= "" and vl.Text ~= lastPearls then
            lastPearls = "● pearls: " .. vl.Text
            setStatus(lastPearls)
        end
    end
end)

setStatus("loaded. htfv4 ready — toggle Auto Fish & stand by water.")

GENV.htfv4.ui = panel
print("[htfv4] loaded — Auto Fish, ESP, TP, Kill Aura, B/W mobile UI")
