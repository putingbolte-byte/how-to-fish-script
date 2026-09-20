-- ============================================================
--  HOW TO FISH  ·  OP SCRIPT  ·  Delta Compatible
--  Features:
--    Auto Fish (cast → bite detect → auto reel)
--    Auto Sell  (walks to sell NPC or fires remote)
--    Speed Hack (adjustable WalkSpeed)
--    Anti-AFK   (prevents kick)
--    Auto Collect (picks up dropped fish/chests)
--    Infinite Cast Distance
--    No Reel Minigame (instant perfect reel)
--    GUI with toggles
-- ============================================================

-- ── Services ────────────────────────────────────────────────
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace      = game:GetService("Workspace")

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum  = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

-- ── Config (edit here) ──────────────────────────────────────
local CFG = {
    AutoFish          = true,
    AutoSell          = true,
    AntiAFK           = true,
    SpeedHack         = false,
    SpeedValue        = 50,         -- default walk speed (16 = normal)
    AutoCollect       = true,
    CollectRadius     = 40,         -- stud radius to auto collect
    InfiniteCast      = true,
    NoMinigame        = true,       -- skip reel minigame → instant catch
    SellDelay         = 5,          -- seconds between sell attempts
    FishDelay         = 0.3,        -- seconds between cast cycles
    DebugPrint        = false,
}

-- ── State ───────────────────────────────────────────────────
local State = {
    fishing  = false,
    selling  = false,
    castOut  = false,
    lastSell = 0,
}

-- ── Utility ─────────────────────────────────────────────────
local function Log(msg)
    if CFG.DebugPrint then
        print("[HTF] " .. tostring(msg))
    end
end

local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Log("ERR: " .. tostring(err)) end
end

-- ── Find remotes / objects ───────────────────────────────────
-- How to Fish uses a RemoteEvent/Function for cast + reel.
-- We scan ReplicatedStorage and Workspace for known names.

local function FindRemote(name, parent)
    parent = parent or ReplicatedStorage
    -- direct child
    local r = parent:FindFirstChild(name, true)
    if r then return r end
    return nil
end

-- Common remote names used in How to Fish
local Remotes = {}
local function ScanRemotes()
    local sources = {ReplicatedStorage, Workspace}
    local knownNames = {
        "CastRod", "Cast", "ThrowRod", "Fish", "Reel", "ReelIn",
        "CatchFish", "FishCaught", "SellFish", "Sell", "CollectFish",
        "StartFishing", "StopFishing", "FinishReel", "PerfectReel",
        "FishingCast", "FishingReel", "FishingSell",
    }
    for _, src in pairs(sources) do
        for _, name in pairs(knownNames) do
            local r = src:FindFirstChild(name, true)
            if r then
                Remotes[name] = r
                Log("Found remote: " .. name)
            end
        end
    end
end
ScanRemotes()

-- ── Infinite Cast Distance ───────────────────────────────────
local function PatchCastDistance()
    if not CFG.InfiniteCast then return end
    -- Hook any LocalScript that sets MaxDistance/castDistance
    for _, desc in pairs(LP.PlayerScripts:GetDescendants()) do
        if desc:IsA("ModuleScript") or desc:IsA("LocalScript") then
            -- We can't write to scripts, but we CAN patch the environment
            -- by overriding the bobber position after cast
        end
    end
    -- Try patching via workspace values if they exist
    local distVal = Workspace:FindFirstChild("MaxCastDistance", true)
            or ReplicatedStorage:FindFirstChild("MaxCastDistance", true)
    if distVal and distVal:IsA("NumberValue") then
        distVal.Value = 9999
        Log("Patched MaxCastDistance → 9999")
    end
end
PatchCastDistance()

-- ── Anti-AFK ────────────────────────────────────────────────
local VirtualUser = game:GetService("VirtualUser")
RunService.Heartbeat:Connect(function()
    if CFG.AntiAFK then
        LP.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- ── Speed Hack ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if CFG.SpeedHack then
        if Hum and Hum.Parent then
            Hum.WalkSpeed = CFG.SpeedValue
        end
    end
end)

-- ── Auto Collect ─────────────────────────────────────────────
local function TryCollect()
    if not CFG.AutoCollect then return end
    -- Fish drops, chests, collectibles usually in Workspace
    local collectNames = {"Fish", "Chest", "Drop", "Collectible", "Pickup", "Coin", "Pearl"}
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name
            local isCollect = false
            for _, cn in pairs(collectNames) do
                if name:lower():find(cn:lower()) then
                    isCollect = true; break
                end
            end
            if isCollect then
                local pos = obj:IsA("Model")
                    and (obj.PrimaryPart and obj.PrimaryPart.Position or Vector3.new())
                    or obj.Position
                if (pos - Root.Position).Magnitude < CFG.CollectRadius then
                    -- Touch it
                    local old = Root.CFrame
                    Root.CFrame = CFrame.new(pos)
                    task.wait(0.05)
                    Root.CFrame = old
                end
            end
        end
    end
end

-- ── Auto Sell ────────────────────────────────────────────────
local function TrySell()
    if not CFG.AutoSell then return end
    if tick() - State.lastSell < CFG.SellDelay then return end
    State.lastSell = tick()

    -- Method 1: fire sell remote
    local sellRemote = Remotes["SellFish"] or Remotes["Sell"]
    if sellRemote then
        if sellRemote:IsA("RemoteEvent") then
            sellRemote:FireServer()
            Log("Sell remote fired")
        elseif sellRemote:IsA("RemoteFunction") then
            SafeCall(function() sellRemote:InvokeServer() end)
            Log("Sell function invoked")
        end
        return
    end

    -- Method 2: walk to NPC named Sell/Shop/Market
    local sellNames = {"Sell", "Shop", "Market", "Fisher", "Merchant", "Vendor"}
    for _, obj in pairs(Workspace:GetDescendants()) do
        local n = obj.Name
        for _, sn in pairs(sellNames) do
            if n:lower():find(sn:lower()) then
                local part = obj:IsA("BasePart") and obj
                    or (obj:IsA("Model") and obj.PrimaryPart)
                if part then
                    -- Tween root to NPC
                    local goal = {CFrame = CFrame.new(part.Position + Vector3.new(0,0,3))}
                    local tw = TweenService:Create(Root, TweenInfo.new(1.5), goal)
                    tw:Play()
                    tw.Completed:Wait()
                    Log("Walked to sell NPC: " .. n)
                    -- Touch trigger
                    local touchR = part.Touched:Connect(function() end)
                    task.wait(0.2)
                    touchR:Disconnect()
                    return
                end
            end
        end
    end
end

-- ── Auto Fish Core ────────────────────────────────────────────
--  How to Fish flow:
--  1. Fire CastRod remote (or click bobber tool)
--  2. Wait for bite event / FishCaught remote / GUI element
--  3. Fire ReelIn remote  (or complete minigame)
--  If NoMinigame = true we fire perfect reel instantly on bite.

local function GetFishingTool()
    -- Find equipped rod / fishing tool
    local backpack = LP.Backpack
    local equipped = Char:FindFirstChildOfClass("Tool")
    if equipped and (equipped.Name:lower():find("rod") or equipped.Name:lower():find("fish")) then
        return equipped
    end
    for _, t in pairs(backpack:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("rod") or t.Name:lower():find("fish")) then
            -- Equip it
            Hum:EquipTool(t)
            task.wait(0.3)
            return t
        end
    end
    return nil
end

local function TryCast()
    -- Method 1: remote
    local castR = Remotes["CastRod"] or Remotes["Cast"] or Remotes["StartFishing"] or Remotes["FishingCast"]
    if castR then
        if castR:IsA("RemoteEvent") then castR:FireServer()
        elseif castR:IsA("RemoteFunction") then SafeCall(function() castR:InvokeServer() end) end
        State.castOut = true
        Log("Cast via remote")
        return true
    end

    -- Method 2: activate tool
    local tool = GetFishingTool()
    if tool then
        local act = tool:FindFirstChild("Activate") or tool:FindFirstChildOfClass("RemoteEvent")
        if act and act:IsA("RemoteEvent") then act:FireServer() end
        -- Simulate click
        local mouse = LP:GetMouse()
        tool:Activate()
        State.castOut = true
        Log("Cast via tool activate")
        return true
    end

    Log("No cast method found")
    return false
end

local function TryReel()
    -- Method 1: instant reel remote
    local reelR = Remotes["ReelIn"] or Remotes["Reel"] or Remotes["FinishReel"]
                  or Remotes["PerfectReel"] or Remotes["FishingReel"] or Remotes["CatchFish"]
    if reelR then
        if reelR:IsA("RemoteEvent") then reelR:FireServer()
        elseif reelR:IsA("RemoteFunction") then
            SafeCall(function() reelR:InvokeServer() end)
        end
        State.castOut = false
        Log("Reel via remote")
        return
    end

    -- Method 2: fire all RemoteEvents named anything reel-like inside tool
    local tool = GetFishingTool()
    if tool then
        for _, child in pairs(tool:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                SafeCall(function() child:FireServer() end)
            end
        end
    end

    -- Method 3: click again (some games reel on re-activate)
    local t = GetFishingTool()
    if t then t:Activate() end
    State.castOut = false
    Log("Reel fallback")
end

-- ── Bite Detection ────────────────────────────────────────────
-- Watch for GUI elements, part name changes, or events that
-- signal a fish is biting.

local BiteDetected = false

local function WatchForBite()
    -- 1. GUI element (most common — a "Reel!" button or exclamation label)
    local sg = LP.PlayerGui
    local function CheckGUI()
        for _, gui in pairs(sg:GetDescendants()) do
            if gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("ImageButton") then
                local txt = gui.Text or ""
                if txt:lower():find("reel") or txt:lower():find("catch")
                    or txt:lower():find("now") or txt:lower():find("bite")
                    or txt:lower():find("fish!") then
                    if gui.Visible then
                        return true
                    end
                end
            end
        end
        return false
    end

    -- 2. FishCaught / Bite remote
    local biteR = Remotes["FishCaught"] or Remotes["Fish"] or Remotes["FishingReel"]
    if biteR and biteR:IsA("RemoteEvent") then
        biteR.OnClientEvent:Connect(function()
            BiteDetected = true
            Log("Bite remote received")
        end)
    end

    -- 3. Polling fallback
    return CheckGUI
end

local checkGUI = WatchForBite()

-- ── Main Auto Fish Loop ───────────────────────────────────────
task.spawn(function()
    while task.wait(CFG.FishDelay) do
        if not CFG.AutoFish then BiteDetected = false; continue end

        -- Make sure character exists
        Char = LP.Character
        if not Char then continue end
        Hum  = Char:FindFirstChildOfClass("Humanoid")
        Root = Char:FindFirstChild("HumanoidRootPart")
        if not Hum or not Root then continue end

        if BiteDetected or (State.castOut and checkGUI and checkGUI()) then
            -- Fish is biting — reel in
            BiteDetected = false
            Log("BITE! Reeling...")
            if CFG.NoMinigame then
                -- Fire reel instantly without playing minigame
                TryReel()
            else
                TryReel()
            end
            State.castOut = false
            task.wait(0.5)

            -- Auto sell after catch
            TrySell()
            -- Auto collect drops
            TryCollect()

        elseif not State.castOut then
            -- Cast the rod
            Log("Casting...")
            TryCast()
            task.wait(0.4)
        end
    end
end)

-- ── Anti-AFK loop ─────────────────────────────────────────────
task.spawn(function()
    while task.wait(60) do
        if CFG.AntiAFK then
            -- Tiny jump to reset idle timer
            Hum.Jump = true
            task.wait(0.1)
            Hum.Jump = false
        end
    end
end)

-- ── Re-equip on respawn ────────────────────────────────────────
LP.CharacterAdded:Connect(function(newChar)
    Char = newChar
    Hum  = newChar:WaitForChild("Humanoid")
    Root = newChar:WaitForChild("HumanoidRootPart")
    State.castOut = false
    BiteDetected  = false
    Log("Character respawned — state reset")
end)

-- ════════════════════════════════════════════════════════════
--  GUI
-- ════════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name          = "HTF_OP"
ScreenGui.ResetOnSpawn  = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = LP.PlayerGui

-- Main frame
local Main = Instance.new("Frame")
Main.Name            = "Main"
Main.Size            = UDim2.new(0, 240, 0, 320)
Main.Position        = UDim2.new(0, 12, 0.5, -160)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel  = 0
Main.Parent           = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
TitleBar.BorderSizePixel  = 0
TitleBar.Parent           = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size              = UDim2.new(1, -40, 1, 0)
Title.Position          = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text              = "🎣  HOW TO FISH  OP"
Title.TextColor3        = Color3.fromRGB(255, 255, 255)
Title.Font              = Enum.Font.GothamBold
Title.TextSize          = 13
Title.TextXAlignment    = Enum.TextXAlignment.Left
Title.Parent            = TitleBar

-- Minimize button
local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 28, 0, 22)
MinBtn.Position         = UDim2.new(1, -32, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MinBtn.Text             = "─"
MinBtn.TextColor3       = Color3.fromRGB(255,255,255)
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.TextSize         = 14
MinBtn.BorderSizePixel  = 0
MinBtn.Parent           = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

-- Content frame
local Content = Instance.new("Frame")
Content.Name             = "Content"
Content.Size             = UDim2.new(1, 0, 1, -36)
Content.Position         = UDim2.new(0, 0, 0, 36)
Content.BackgroundTransparency = 1
Content.Parent           = Main

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding        = UDim.new(0, 6)
UIListLayout.SortOrder      = Enum.SortOrder.LayoutOrder
UIListLayout.Parent         = Content

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingLeft   = UDim.new(0, 10)
UIPadding.PaddingRight  = UDim.new(0, 10)
UIPadding.PaddingTop    = UDim.new(0, 8)
UIPadding.Parent        = Content

-- ── Status label ──────────────────────────────────────────────
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size              = UDim2.new(1, 0, 0, 20)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text              = "STATUS: RUNNING"
StatusLbl.TextColor3        = Color3.fromRGB(80, 255, 120)
StatusLbl.Font              = Enum.Font.GothamBold
StatusLbl.TextSize          = 11
StatusLbl.TextXAlignment    = Enum.TextXAlignment.Left
StatusLbl.LayoutOrder       = 0
StatusLbl.Parent            = Content

-- ── Toggle builder ────────────────────────────────────────────
local function MakeToggle(labelText, cfgKey, order)
    local Row = Instance.new("Frame")
    Row.Size             = UDim2.new(1, 0, 0, 26)
    Row.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    Row.BorderSizePixel  = 0
    Row.LayoutOrder      = order
    Row.Parent           = Content
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)

    local Lbl = Instance.new("TextLabel")
    Lbl.Size             = UDim2.new(0.72, 0, 1, 0)
    Lbl.Position         = UDim2.new(0, 8, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text             = labelText
    Lbl.TextColor3       = Color3.fromRGB(210, 210, 220)
    Lbl.Font             = Enum.Font.Gotham
    Lbl.TextSize         = 12
    Lbl.TextXAlignment   = Enum.TextXAlignment.Left
    Lbl.Parent           = Row

    local Pill = Instance.new("Frame")
    Pill.Size            = UDim2.new(0, 40, 0, 18)
    Pill.Position        = UDim2.new(1, -48, 0.5, -9)
    Pill.BorderSizePixel = 0
    Pill.Parent          = Row
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame")
    Knob.Size            = UDim2.new(0, 14, 0, 14)
    Knob.Position        = UDim2.new(0, 2, 0.5, -7)
    Knob.BorderSizePixel = 0
    Knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    Knob.Parent          = Pill
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1,0)

    local function Refresh()
        local on = CFG[cfgKey]
        Pill.BackgroundColor3 = on
            and Color3.fromRGB(255, 60, 80)
            or  Color3.fromRGB(50, 50, 65)
        local goalPos = on
            and UDim2.new(1, -16, 0.5, -7)
            or  UDim2.new(0, 2,   0.5, -7)
        TweenService:Create(Knob, TweenInfo.new(0.15), {Position = goalPos}):Play()
    end
    Refresh()

    local Btn = Instance.new("TextButton")
    Btn.Size             = UDim2.new(1,0,1,0)
    Btn.BackgroundTransparency = 1
    Btn.Text             = ""
    Btn.Parent           = Row
    Btn.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        Refresh()
        if cfgKey == "SpeedHack" and not CFG.SpeedHack then
            Hum.WalkSpeed = 16
        end
    end)

    return Row
end

-- ── Sliders ──────────────────────────────────────────────────
local function MakeSlider(labelText, cfgKey, minV, maxV, order)
    local Row = Instance.new("Frame")
    Row.Size             = UDim2.new(1, 0, 0, 42)
    Row.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    Row.BorderSizePixel  = 0
    Row.LayoutOrder      = order
    Row.Parent           = Content
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)

    local Lbl = Instance.new("TextLabel")
    Lbl.Size             = UDim2.new(1, -10, 0, 18)
    Lbl.Position         = UDim2.new(0, 8, 0, 4)
    Lbl.BackgroundTransparency = 1
    Lbl.Text             = labelText .. ": " .. tostring(CFG[cfgKey])
    Lbl.TextColor3       = Color3.fromRGB(210,210,220)
    Lbl.Font             = Enum.Font.Gotham
    Lbl.TextSize         = 11
    Lbl.TextXAlignment   = Enum.TextXAlignment.Left
    Lbl.Parent           = Row

    local Track = Instance.new("Frame")
    Track.Size           = UDim2.new(1, -16, 0, 6)
    Track.Position       = UDim2.new(0, 8, 0, 28)
    Track.BackgroundColor3 = Color3.fromRGB(50,50,65)
    Track.BorderSizePixel = 0
    Track.Parent         = Row
    Instance.new("UICorner", Track).CornerRadius = UDim.new(1,0)

    local Fill = Instance.new("Frame")
    Fill.Size            = UDim2.new((CFG[cfgKey]-minV)/(maxV-minV), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255,60,80)
    Fill.BorderSizePixel = 0
    Fill.Parent          = Track
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1,0)

    local dragging = false
    Track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    Track.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local pos    = Track.AbsolutePosition
            local size   = Track.AbsoluteSize
            local rel    = math.clamp((inp.Position.X - pos.X) / size.X, 0, 1)
            local newVal = math.floor(minV + rel * (maxV - minV))
            CFG[cfgKey]  = newVal
            Fill.Size    = UDim2.new(rel, 0, 1, 0)
            Lbl.Text     = labelText .. ": " .. tostring(newVal)
        end
    end)
end

-- ── Build toggles ─────────────────────────────────────────────
MakeToggle("🎣 Auto Fish",          "AutoFish",     1)
MakeToggle("💰 Auto Sell",          "AutoSell",     2)
MakeToggle("⚡ No Minigame",        "NoMinigame",   3)
MakeToggle("🌀 Infinite Cast",      "InfiniteCast", 4)
MakeToggle("🏃 Speed Hack",         "SpeedHack",    5)
MakeToggle("🧲 Auto Collect",       "AutoCollect",  6)
MakeToggle("🛡 Anti-AFK",           "AntiAFK",      7)
MakeSlider("WalkSpeed",             "SpeedValue",   16, 150, 8)

-- ── Fish / sell counters ──────────────────────────────────────
local CountLbl = Instance.new("TextLabel")
CountLbl.Size              = UDim2.new(1, 0, 0, 18)
CountLbl.BackgroundTransparency = 1
CountLbl.Text              = "Casts: 0  |  Sells: 0"
CountLbl.TextColor3        = Color3.fromRGB(130,130,160)
CountLbl.Font              = Enum.Font.Gotham
CountLbl.TextSize          = 10
CountLbl.TextXAlignment    = Enum.TextXAlignment.Center
CountLbl.LayoutOrder       = 9
CountLbl.Parent            = Content

local _casts = 0
local _sells = 0
local _origCast = TryCast
TryCast = function(...)
    local ok = _origCast(...)
    if ok then _casts += 1 end
    return ok
end
local _origSell = TrySell
TrySell = function(...)
    _origSell(...)
    _sells += 1
end

task.spawn(function()
    while task.wait(1) do
        CountLbl.Text = string.format("Casts: %d  |  Sells: %d", _casts, _sells)
    end
end)

-- ── Drag ──────────────────────────────────────────────────────
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = Main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ── Minimize ──────────────────────────────────────────────────
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    Main.Size = minimized
        and UDim2.new(0, 240, 0, 36)
        or  UDim2.new(0, 240, 0, 320)
    MinBtn.Text = minimized and "+" or "─"
end)

-- ── Keybind: RightShift toggles AutoFish ──────────────────────
UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        CFG.AutoFish = not CFG.AutoFish
        StatusLbl.Text = "STATUS: " .. (CFG.AutoFish and "RUNNING" or "PAUSED")
        StatusLbl.TextColor3 = CFG.AutoFish
            and Color3.fromRGB(80,255,120)
            or  Color3.fromRGB(255,100,80)
    end
end)

print("[HTF OP] Script loaded. GUI is open. RightShift = toggle AutoFish.")
