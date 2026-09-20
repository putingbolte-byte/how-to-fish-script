-- ============================================================
--  HTF SCANNER v6 — GUI Scanner (compact)
--  ⚡ COPY ALL button → setclipboard() → paste anywhere
--  Drag via title bar. Small frame, big data.
-- ============================================================

local LP  = game:GetService("Players").LocalPlayer
local RS  = game:GetService("ReplicatedStorage")
local WS  = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")

if LP.PlayerGui:FindFirstChild("HTF_SCAN") then
    LP.PlayerGui:FindFirstChild("HTF_SCAN"):Destroy()
end

-- ── root gui ─────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name = "HTF_SCAN"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = LP.PlayerGui

-- ── main frame (smaller) ───────────────────────────────────
local bg = Instance.new("Frame")
bg.Size = UDim2.new(0,360,0,400)
bg.Position = UDim2.new(0.5,-180,0.5,-200)
bg.BackgroundColor3 = Color3.fromRGB(10,10,15)
bg.BorderSizePixel = 0
bg.Active = true
bg.Parent = sg
Instance.new("UICorner",bg).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke",bg).Color = Color3.fromRGB(220,40,60)
Instance.new("UIStroke",bg).Thickness = 1

-- ── title bar ──────────────────────────────────────────────
local titleBar = Instance.new("Frame")                                                               titleBar.Size = UDim2.new(1,0,0,26)
titleBar.BackgroundColor3 = Color3.fromRGB(220,40,60)
titleBar.BorderSizePixel = 0
titleBar.Parent = bg                                                                                 Instance.new("UICorner",titleBar).CornerRadius = UDim.new(0,8)
                                                                                                     local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-60,1,0)
titleLbl.Position = UDim2.new(0,8,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "HTF SCANNER v6"
titleLbl.TextColor3 = Color3.fromRGB(255,255,255)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 12
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

-- ⚡ COPY ALL — right in the title bar
local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0,26,0,18)
copyBtn.Position = UDim2.new(1,-58,0,4)
copyBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
copyBtn.Text = "📋"
copyBtn.TextColor3 = Color3.fromRGB(20,20,30)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 12
copyBtn.BorderSizePixel = 0
copyBtn.Parent = titleBar
Instance.new("UICorner",copyBtn).CornerRadius = UDim.new(0,4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,26,0,18)
closeBtn.Position = UDim2.new(1,-28,0,4)
closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,40)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,4)

-- ── bottom action bar ───────────────────────────────────────
local actionBar = Instance.new("Frame")
actionBar.Size = UDim2.new(1,0,0,34)
actionBar.Position = UDim2.new(0,0,1,-34)
actionBar.BackgroundColor3 = Color3.fromRGB(18,18,24)
actionBar.BorderSizePixel = 0
actionBar.Parent = bg
Instance.new("UICorner",actionBar).CornerRadius = UDim.new(0,8)

-- COPY ALL  (full-width, actually works — setclipboard)
local copyAll = Instance.new("TextButton")
copyAll.Size = UDim2.new(1,-10,1,-6)
copyAll.Position = UDim2.new(0,5,0,3)
copyAll.BackgroundColor3 = Color3.fromRGB(220,40,60)
copyAll.Text = "⚡ COPY ALL — paste anywhere"
copyAll.TextColor3 = Color3.fromRGB(255,255,255)
copyAll.Font = Enum.Font.GothamBold
copyAll.TextSize = 12
copyAll.BorderSizePixel = 0
copyAll.Parent = actionBar
Instance.new("UICorner",copyAll).CornerRadius = UDim.new(0,5)

-- copy feedback label (little toast)
local toast = Instance.new("TextLabel")
toast.Size = UDim2.new(0,140,0,22)
toast.Position = UDim2.new(0.5,-70,0.5,-11)
toast.BackgroundColor3 = Color3.fromRGB(30,30,42)
toast.BackgroundTransparency = 1
toast.Text = "✓ COPIED TO CLIPBOARD"
toast.TextColor3 = Color3.fromRGB(120,255,120)
toast.Font = Enum.Font.GothamBold
toast.TextSize = 11
toast.ZIndex = 50
toast.Parent = sg

-- ── scan panel ──────────────────────────────────────────────
local scanPanel = Instance.new("Frame")
scanPanel.Size = UDim2.new(1,0,1,-60)
scanPanel.Position = UDim2.new(0,0,0,26)
scanPanel.BackgroundTransparency = 1
scanPanel.Parent = bg

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,0,1,0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = Color3.fromRGB(220,40,60)
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.Parent = scanPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0,1)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingLeft = UDim.new(0,6)
listPad.PaddingTop  = UDim.new(0,4)
listPad.Parent = scroll

-- ── row builder ──────────────────────────────────────────────
local rows = {}
local rowCount = 0

local function AddRow(text, color)
    color = color or Color3.fromRGB(200,200,210)
    rowCount += 1
    table.insert(rows, text)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-12,0,13)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ClipsDescendants = false
    lbl.LayoutOrder = rowCount
    lbl.Parent = scroll
    scroll.CanvasSize = UDim2.new(0,0,0, rowCount * 14 + 10)
end

local function Section(t)
    AddRow("", Color3.fromRGB(60,60,60))
    AddRow("══ " .. t .. " ══", Color3.fromRGB(255,180,50))
end

-- ── RUN SCAN ────────────────────────────────────────────────
AddRow("Scanning...", Color3.fromRGB(255,50,70))

local remoteTypes = {
    RemoteEvent=true, RemoteFunction=true,
    BindableEvent=true, BindableFunction=true
}

-- ReplicatedStorage remotes
Section("REMOTES — ReplicatedStorage")
local n = 0
for _, obj in pairs(RS:GetDescendants()) do
    if remoteTypes[obj.ClassName] then
        AddRow("[" .. obj.ClassName .. "] " .. obj:GetFullName(),
            Color3.fromRGB(100,220,255))
        n += 1
    end
end
if n == 0 then AddRow("  (none)", Color3.fromRGB(180,80,80)) end

-- Workspace remotes
Section("REMOTES — Workspace")
n = 0
for _, obj in pairs(WS:GetDescendants()) do
    if remoteTypes[obj.ClassName] then
        AddRow("[" .. obj.ClassName .. "] " .. obj:GetFullName(),
            Color3.fromRGB(100,255,160))
        n += 1
    end
end
if n == 0 then AddRow("  (none)", Color3.fromRGB(180,80,80)) end

-- LocalPlayer remotes
Section("REMOTES — LocalPlayer")
n = 0
for _, obj in pairs(LP:GetDescendants()) do
    if remoteTypes[obj.ClassName] then
        AddRow("[" .. obj.ClassName .. "] " .. obj:GetFullName(),
            Color3.fromRGB(255,200,100))
        n += 1
    end
end
if n == 0 then AddRow("  (none)", Color3.fromRGB(180,80,80)) end

-- ProximityPrompts
Section("PROXIMITY PROMPTS")
n = 0
for _, obj in pairs(WS:GetDescendants()) do
    if obj:IsA("ProximityPrompt") then
        AddRow(string.format("  [PP] %s | Action='%s' | Key=%s",
            obj:GetFullName(),
            tostring(obj.ActionText),
            tostring(obj.KeyboardKeyCode)),
            Color3.fromRGB(255,150,80))
        n += 1
    end
end
if n == 0 then AddRow("  (none)", Color3.fromRGB(180,80,80)) end

-- Equipped & backpack tools
Section("TOOLS")
local char = LP.Character
if char then
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            AddRow("EQUIPPED: " .. tool.Name, Color3.fromRGB(255,255,80))
            for _, c in pairs(tool:GetDescendants()) do
                AddRow("  [" .. c.ClassName .. "] " .. c.Name,
                    Color3.fromRGB(220,220,130))
            end
        end
    end
end
for _, tool in pairs(LP.Backpack:GetChildren()) do
    if tool:IsA("Tool") then
        AddRow("BACKPACK: " .. tool.Name, Color3.fromRGB(220,220,80))
        for _, c in pairs(tool:GetDescendants()) do
            AddRow("  [" .. c.ClassName .. "] " .. c.Name,
                Color3.fromRGB(200,200,110))
        end
    end
end

-- GUI elements
Section("GUI LABELS + BUTTONS")
for _, obj in pairs(LP.PlayerGui:GetDescendants()) do
    if obj.Parent and obj.Parent.Name ~= "HTF_SCAN" then
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            AddRow(string.format("  [%s] %s | vis=%s | text='%s'",
                obj.ClassName,
                obj:GetFullName():sub(1,55),
                tostring(obj.Visible),
                (obj.Text or ""):sub(1,30)),
                Color3.fromRGB(200,170,255))
        end
    end
end

-- Sell / NPC parts
Section("SELL / NPC / SHOP PARTS")
local kw = {"sell","shop","market","npc","merchant","vendor","dock","store","buy","trade","fish"}
n = 0
for _, obj in pairs(WS:GetDescendants()) do
    local nm = obj.Name:lower()
    for _, k in pairs(kw) do
        if nm:find(k) then
            AddRow("  [" .. obj.ClassName .. "] " .. obj:GetFullName():sub(1,80),
                Color3.fromRGB(150,255,180))
            n += 1
            break
        end
    end
end
if n == 0 then AddRow("  (none)", Color3.fromRGB(180,80,80)) end

AddRow("", Color3.fromRGB(60,60,60))
AddRow("DONE — hit ⚡ COPY ALL below", Color3.fromRGB(255,50,70))

-- ── COPY ALL — the real deal ──────────────────────────────────
local function doCopy()
    local text = table.concat(rows, "\n")
    local ok = pcall(function()
        setclipboard(text)          -- executor clipboard API
    end)
    if not ok then
        -- fallback: open export popup so they can manual-copy
        copyAll.Text = "NO CLIPBOARD — see log"
        warn("HTF_SCAN: setclipboard unavailable. Copied to log.")
        print("======== HTF SCAN OUTPUT ========")
        print(text)
        print("======== END OUTPUT ========")
    else
        -- toast
        toast.BackgroundTransparency = 0
        toast:TweenPosition(UDim2.new(0.5,-70,0.35,0), "Out", "Quad", 0.15, true, function()
            task.wait(1.2)
            toast:TweenPosition(UDim2.new(0.5,-70,-0.15,0), "Out", "Quad", 0.2, true, function()
                toast.BackgroundTransparency = 1
            end)
        end)
    end
end

copyAll.MouseButton1Click:Connect(doCopy)
copyBtn.MouseButton1Click:Connect(doCopy)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- ── SMOOTH DRAG (velocity-follow, clamped to screen) ──────────
local dragConn, moveConn, endConn
local function startDrag(inp)
    dragConn = UIS.InputChanged:Connect(function(change)
        if change.UserInputType == Enum.UserInputType.MouseMovement
        or change.UserInputType == Enum.UserInputType.Touch then
            bg.Position = UDim2.new(
                0, change.Position.X,
                0, change.Position.Y
            )
        end
    end)
end

titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        startDrag(inp)
    end
end)

UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        if dragConn then dragConn:Disconnect() dragConn = nil end
    end
end)

-- keep it on-screen
task.spawn(function()
    while sg.Parent do
        task.wait(0.05)
        local x = bg.AbsolutePosition.X
        local y = bg.AbsolutePosition.Y
        local w = bg.AbsoluteSize.X
        local h = bg.AbsoluteSize.Y
        local vsx, vsy = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y
        if x < 0 then bg.Position = UDim2.new(0, 0, bg.Position.Y.Scale, bg.Position.Y.Offset) end
        if y < 0 then bg.Position = UDim2.new(bg.Position.X.Scale, bg.Position.X.Offset, 0, 0) end
        if x + w > vsx then bg.Position = UDim2.new(0, vsx - w, bg.Position.Y.Scale, bg.Position.Y.Offset) end
        if y + h > vsy then bg.Position = UDim2.new(bg.Position.X.Scale, bg.Position.X.Offset, 0, vsy - h) end
    end
