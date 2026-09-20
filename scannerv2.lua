-- ============================================================
--  HOW TO FISH — GUI SCANNER
--  Shows ALL remotes + GUI elements + tools on screen
--  Scroll through the list inside the game
-- ============================================================

local LP  = game:GetService("Players").LocalPlayer
local RS  = game:GetService("ReplicatedStorage")
local WS  = game:GetService("Workspace")

-- ── destroy old scanner if re-ran ────────────────────────────
if LP.PlayerGui:FindFirstChild("HTF_SCAN") then
    LP.PlayerGui:FindFirstChild("HTF_SCAN"):Destroy()
end

-- ── build GUI ────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name = "HTF_SCAN"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = LP.PlayerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(0,480,0,500)
bg.Position = UDim2.new(0.5,-240,0.5,-250)
bg.BackgroundColor3 = Color3.fromRGB(10,10,15)
bg.BorderSizePixel = 0
bg.Parent = sg
Instance.new("UICorner",bg).CornerRadius = UDim.new(0,8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.BackgroundColor3 = Color3.fromRGB(255,50,70)
title.BorderSizePixel = 0
title.Text = "  HTF SCANNER — scroll to read, close = X"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bg
Instance.new("UICorner",title).CornerRadius = UDim.new(0,8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,28,0,22)
closeBtn.Position = UDim2.new(1,-32,0,4)
closeBtn.BackgroundColor3 = Color3.fromRGB(40,40,55)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0
closeBtn.Parent = title
Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,4)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- scrolling list
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-4,1,-34)
scroll.Position = UDim2.new(0,2,0,32)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(255,50,70)
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.Parent = bg

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0,2)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0,6)
pad.PaddingRight = UDim.new(0,8)
pad.PaddingTop = UDim.new(0,4)
pad.Parent = scroll

local rowCount = 0

local function AddRow(text, color)
    color = color or Color3.fromRGB(200,200,210)
    rowCount += 1
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,16)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.LayoutOrder = rowCount
    lbl.Parent = scroll
    -- update canvas
    scroll.CanvasSize = UDim2.new(0,0,0, rowCount*18+10)
end

local function Section(title)
    AddRow("", Color3.fromRGB(80,80,80))
    AddRow("══ " .. title .. " ══", Color3.fromRGB(255,180,50))
end

-- ── SCAN REMOTES ─────────────────────────────────────────────
Section("REMOTES in ReplicatedStorage")
local remoteTypes = {RemoteEvent=true, RemoteFunction=true, BindableEvent=true, BindableFunction=true}
local totalR = 0
for _, obj in pairs(RS:GetDescendants()) do
    if remoteTypes[obj.ClassName] then
        AddRow("[" .. obj.ClassName .. "] " .. obj:GetFullName(), Color3.fromRGB(100,220,255))
        totalR += 1
    end
end
if totalR == 0 then AddRow("  (none found)", Color3.fromRGB(180,100,100)) end

Section("REMOTES in Workspace")
local totalW = 0
for _, obj in pairs(WS:GetDescendants()) do
    if remoteTypes[obj.ClassName] then
        AddRow("[" .. obj.ClassName .. "] " .. obj:GetFullName(), Color3.fromRGB(100,255,160))
        totalW += 1
    end
end
if totalW == 0 then AddRow("  (none found)", Color3.fromRGB(180,100,100)) end

-- ── SCAN PLAYER SCRIPTS ───────────────────────────────────────
Section("REMOTES in PlayerScripts / LocalPlayer")
local totalP = 0
for _, obj in pairs(LP:GetDescendants()) do
    if remoteTypes[obj.ClassName] then
        AddRow("[" .. obj.ClassName .. "] " .. obj:GetFullName(), Color3.fromRGB(255,200,100))
        totalP += 1
    end
end
if totalP == 0 then AddRow("  (none found)", Color3.fromRGB(180,100,100)) end

-- ── SCAN GUI ─────────────────────────────────────────────────
Section("GUI FRAMES + LABELS (visible or not)")
for _, obj in pairs(LP.PlayerGui:GetDescendants()) do
    if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("Frame")) then
        local txt = ""
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            txt = ' text="' .. obj.Text:sub(1,40) .. '"'
        end
        AddRow(string.format("[%s] %s vis=%s%s",
            obj.ClassName, obj:GetFullName():sub(1,60),
            tostring(obj.Visible), txt),
            Color3.fromRGB(200,180,255))
    end
end

-- ── SCAN TOOLS ───────────────────────────────────────────────
Section("TOOLS (equipped + backpack)")
local char = LP.Character
if char then
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            AddRow("EQUIPPED TOOL: " .. tool.Name, Color3.fromRGB(255,255,100))
            for _, c in pairs(tool:GetDescendants()) do
                AddRow("  └[" .. c.ClassName .. "] " .. c.Name, Color3.fromRGB(220,220,150))
            end
        end
    end
end
for _, tool in pairs(LP.Backpack:GetChildren()) do
    if tool:IsA("Tool") then
        AddRow("BACKPACK TOOL: " .. tool.Name, Color3.fromRGB(255,220,100))
        for _, c in pairs(tool:GetDescendants()) do
            AddRow("  └[" .. c.ClassName .. "] " .. c.Name, Color3.fromRGB(200,200,130))
        end
    end
end

-- ── SCAN PROXIMITY PROMPTS ────────────────────────────────────
Section("PROXIMITY PROMPTS in Workspace")
local totalPP = 0
for _, obj in pairs(WS:GetDescendants()) do
    if obj:IsA("ProximityPrompt") then
        AddRow(string.format("[ProximityPrompt] %s  Action='%s'  Key=%s",
            obj:GetFullName():sub(1,70),
            obj.ActionText,
            tostring(obj.KeyboardKeyCode)),
            Color3.fromRGB(255,150,100))
        totalPP += 1
    end
end
if totalPP == 0 then AddRow("  (none found)", Color3.fromRGB(180,100,100)) end

-- ── SCAN NPC / SELL PARTS ─────────────────────────────────────
Section("SELL / SHOP / NPC PARTS in Workspace")
local kw = {"sell","shop","market","npc","merchant","vendor","fish","dock","store","buy","trade"}
local totalNPC = 0
for _, obj in pairs(WS:GetDescendants()) do
    local n = obj.Name:lower()
    for _, k in pairs(kw) do
        if n:find(k) then
            AddRow("[" .. obj.ClassName .. "] " .. obj:GetFullName():sub(1,80),
                Color3.fromRGB(150,255,180))
            totalNPC += 1
            break
        end
    end
end
if totalNPC == 0 then AddRow("  (none found)", Color3.fromRGB(180,100,100)) end

-- ── COPY BUTTON ───────────────────────────────────────────────
-- Collect all text into clipboard
local allText = {}
for _, child in pairs(scroll:GetChildren()) do
    if child:IsA("TextLabel") then
        table.insert(allText, child.Text)
    end
end

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0,100,0,22)
copyBtn.Position = UDim2.new(1,-108,0,4)
copyBtn.BackgroundColor3 = Color3.fromRGB(40,40,55)
copyBtn.Text = "📋 COPY ALL"
copyBtn.TextColor3 = Color3.fromRGB(255,255,255)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 11
copyBtn.BorderSizePixel = 0
copyBtn.Parent = title
Instance.new("UICorner",copyBtn).CornerRadius = UDim.new(0,4)
copyBtn.MouseButton1Click:Connect(function()
    local out = table.concat(allText, "\n")
    setclipboard(out)
    copyBtn.Text = "✅ COPIED!"
    task.wait(2)
    copyBtn.Text = "📋 COPY ALL"
end)

-- ── drag ──────────────────────────────────────────────────────
local UIS = game:GetService("UserInputService")
local dragging, dragStart, startPos
title.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = inp.Position; startPos = bg.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d = inp.Position - dragStart
        bg.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

AddRow("", Color3.fromRGB(80,80,80))
AddRow("SCAN COMPLETE — hit COPY ALL then paste here", Color3.fromRGB(255,50,70))
