-- ============================================================
--  HOW TO FISH — GUI SCANNER v2
--  Tap "EXPORT" → full text appears in a TextBox
--  Long-press the box → Select All → Copy
-- ============================================================

local LP  = game:GetService("Players").LocalPlayer
local RS  = game:GetService("ReplicatedStorage")
local WS  = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")

if LP.PlayerGui:FindFirstChild("HTF_SCAN") then
    LP.PlayerGui:FindFirstChild("HTF_SCAN"):Destroy()
end

-- ── root gui ─────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name = "HTF_SCAN"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = LP.PlayerGui

-- ── main frame ───────────────────────────────────────────────
local bg = Instance.new("Frame")
bg.Size = UDim2.new(0,460,0,520)
bg.Position = UDim2.new(0.5,-230,0.5,-260)
bg.BackgroundColor3 = Color3.fromRGB(10,10,15)
bg.BorderSizePixel = 0
bg.Parent = sg
Instance.new("UICorner",bg).CornerRadius = UDim.new(0,8)

-- ── title bar ────────────────────────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,32)
titleBar.BackgroundColor3 = Color3.fromRGB(220,40,60)
titleBar.BorderSizePixel = 0
titleBar.Parent = bg
Instance.new("UICorner",titleBar).CornerRadius = UDim.new(0,8)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-80,1,0)
titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "HTF SCANNER v2"
titleLbl.TextColor3 = Color3.fromRGB(255,255,255)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,30,0,22)
closeBtn.Position = UDim2.new(1,-34,0,5)
closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,40)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,5)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- ── tab buttons (RESULTS / EXPORT) ───────────────────────────
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1,0,0,30)
tabFrame.Position = UDim2.new(0,0,0,32)
tabFrame.BackgroundColor3 = Color3.fromRGB(18,18,24)
tabFrame.BorderSizePixel = 0
tabFrame.Parent = bg

local function MakeTab(label, xpos, active)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5,-2,1,-4)
    btn.Position = UDim2.new(xpos,2,0,2)
    btn.BackgroundColor3 = active
        and Color3.fromRGB(220,40,60)
        or  Color3.fromRGB(30,30,42)
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = tabFrame
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,5)
    return btn
end

local tabScan   = MakeTab("📋 SCAN RESULTS", 0,    true)
local tabExport = MakeTab("📤 EXPORT (copy)", 0.5, false)

-- ── SCAN scroll panel ─────────────────────────────────────────
local scanPanel = Instance.new("Frame")
scanPanel.Size = UDim2.new(1,0,1,-62)
scanPanel.Position = UDim2.new(0,0,0,62)
scanPanel.BackgroundTransparency = 1
scanPanel.Parent = bg

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-4,1,0)
scroll.Position = UDim2.new(0,2,0,0)
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

-- ── EXPORT panel ─────────────────────────────────────────────
local exportPanel = Instance.new("Frame")
exportPanel.Size = UDim2.new(1,0,1,-62)
exportPanel.Position = UDim2.new(0,0,0,62)
exportPanel.BackgroundTransparency = 1
exportPanel.Visible = false
exportPanel.Parent = bg

local exportHint = Instance.new("TextLabel")
exportHint.Size = UDim2.new(1,-8,0,36)
exportHint.Position = UDim2.new(0,4,0,4)
exportHint.BackgroundColor3 = Color3.fromRGB(30,30,42)
exportHint.BorderSizePixel = 0
exportHint.Text = "Tap inside the box below → long-press → Select All → Copy"
exportHint.TextColor3 = Color3.fromRGB(255,220,80)
exportHint.Font = Enum.Font.Gotham
exportHint.TextSize = 12
exportHint.TextWrapped = true
exportHint.Parent = exportPanel
Instance.new("UICorner",exportHint).CornerRadius = UDim.new(0,6)

local exportBox = Instance.new("TextBox")
exportBox.Size = UDim2.new(1,-8,1,-48)
exportBox.Position = UDim2.new(0,4,0,44)
exportBox.BackgroundColor3 = Color3.fromRGB(20,20,28)
exportBox.BorderSizePixel = 0
exportBox.Text = "Press the EXPORT tab to load text here..."
exportBox.TextColor3 = Color3.fromRGB(200,255,200)
exportBox.Font = Enum.Font.Code
exportBox.TextSize = 10
exportBox.MultiLine = true
exportBox.TextWrapped = true
exportBox.TextXAlignment = Enum.TextXAlignment.Left
exportBox.TextYAlignment = Enum.TextYAlignment.Top
exportBox.ClearTextOnFocus = false
exportBox.Parent = exportPanel
Instance.new("UICorner",exportBox).CornerRadius = UDim.new(0,6)

-- ── row builder ───────────────────────────────────────────────
local rows = {}
local rowCount = 0

local function AddRow(text, color)
    color = color or Color3.fromRGB(200,200,210)
    rowCount += 1
    table.insert(rows, text)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-10,0,14)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = false
    lbl.ClipsDescendants = false
    lbl.LayoutOrder = rowCount
    lbl.Parent = scroll
    scroll.CanvasSize = UDim2.new(0,0,0, rowCount * 15 + 10)
end

local function Section(t)
    AddRow("", Color3.fromRGB(60,60,60))
    AddRow("══ " .. t .. " ══", Color3.fromRGB(255,180,50))
end

-- ── RUN SCAN ─────────────────────────────────────────────────
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
AddRow("DONE — tap EXPORT tab → tap box → hold → Select All → Copy",
    Color3.fromRGB(255,50,70))

-- ── Tab switching ─────────────────────────────────────────────
local function ShowScan()
    scanPanel.Visible   = true
    exportPanel.Visible = false
    tabScan.BackgroundColor3   = Color3.fromRGB(220,40,60)
    tabExport.BackgroundColor3 = Color3.fromRGB(30,30,42)
end

local function ShowExport()
    scanPanel.Visible   = false
    exportPanel.Visible = true
    tabScan.BackgroundColor3   = Color3.fromRGB(30,30,42)
    tabExport.BackgroundColor3 = Color3.fromRGB(220,40,60)
    -- dump all rows into the TextBox
    exportBox.Text = table.concat(rows, "\n")
end

tabScan.MouseButton1Click:Connect(ShowScan)
tabExport.MouseButton1Click:Connect(ShowExport)

-- ── Drag ─────────────────────────────────────────────────────
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inp.Position
        startPos  = bg.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - dragStart
        bg.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
