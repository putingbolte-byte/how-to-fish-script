--[[
    HTF SCANNER — FULL RECON
    Fisch-style GUI + full HTF scan:
    remotes, proximity prompts, tools, GUI labels,
    sell NPCs, workspace parts, attributes, connections
    Delta / mobile safe — auto-scans on load
]]

if getgenv().HTFScan_Loaded then
    local old = game:FindFirstChild("HTFScan_GUI")
    if old then old:Destroy() end
    local old2 = (game:GetService("Players").LocalPlayer.PlayerGui):FindFirstChild("HTFScan_GUI")
    if old2 then old2:Destroy() end
    getgenv().HTFScan_Loaded = false
end
getgenv().HTFScan_Loaded = true

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LP        = Players.LocalPlayer
local UIS       = game:GetService("UserInputService")
local Rep       = game:GetService("ReplicatedStorage")

local lines = {}
local function add(s) table.insert(lines, tostring(s)) end

-- ── helpers ─────────────────────────────────────────────────
local function pathOf(obj)
    local parts = {}
    local cur = obj
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, " > ")
end

local function clamp(s, n)
    s = tostring(s)
    return #s > n and (s:sub(1, n-3) .. "...") or s
end

local KEYWORDS = {
    "bobber","float","fish","rod","sell","shop","npc","trader","merchant",
    "market","water","ocean","sea","lake","pond","cast","reel","bite","hook",
    "catch","vault","inventory","luck","chance","rarity","price","value",
    "bait","lure","buy","trade","dock","boat","store","vendor","prompt",
    "collect","reward","chest","quest","mission","equip","drop","spawn",
    "minigame","mini","game","action","interact","trigger","zone","area"
}

local function interesting(n)
    local nl = string.lower(tostring(n))
    for _, k in ipairs(KEYWORDS) do
        if string.find(nl, k, 1, true) then return true end
    end
    return false
end

local REMOTE_TYPES = {
    RemoteEvent=true, RemoteFunction=true,
    BindableEvent=true, BindableFunction=true
}

-- ── main scan ───────────────────────────────────────────────
local function scan()
    lines = {}
    add("=== HTF FULL SCANNER DUMP ===")
    add("Game: " .. tostring(game.Name))
    add("PlaceId: " .. tostring(game.PlaceId))
    add("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    add("")

    -- ── player info ─────────────────────────────────────────
    add("--- LOCAL PLAYER ---")
    add("Name: " .. tostring(LP.Name))
    add("UserId: " .. tostring(LP.UserId))
    add("Char: " .. tostring(LP.Character and LP.Character.Name or "NONE"))
    add("")

    -- ── tools (char + backpack) ──────────────────────────────
    add("--- TOOLS (Equipped + Backpack) ---")
    local function scanTools(container, tag)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then
                local hpos = ""
                local h = t:FindFirstChild("Handle")
                if h then
                    hpos = string.format(" @ (%.0f,%.0f,%.0f)", h.Position.X, h.Position.Y, h.Position.Z)
                end
                add(string.format("[%s] Tool: %s%s", tag, t.Name, hpos))
                for _, d in ipairs(t:GetDescendants()) do
                    if REMOTE_TYPES[d.ClassName] then
                        add(string.format("    [%s] %s  path=%s", d.ClassName, d.Name, pathOf(d)))
                    end
                    if d:IsA("Configuration") or d:IsA("ValueBase") then
                        local v = d:IsA("ValueBase") and tostring(d.Value) or "?"
                        add(string.format("    [Cfg] %s = %s", d.Name, clamp(v, 60)))
                    end
                end
            end
        end
    end
    scanTools(LP.Character, "CHAR")
    scanTools(LP.Backpack, "BP")
    add("")

    -- ── ALL remotes — full game tree ─────────────────────────
    add("--- ALL REMOTES (full game tree) ---")
    local remoteCount = 0
    local hotspots = {}
    local function walkRemotes(obj, depth)
        if depth > 12 then return end
        local ok, children = pcall(function() return obj:GetChildren() end)
        if not ok then return end
        for _, child in ipairs(children) do
            if REMOTE_TYPES[child.ClassName] then
                remoteCount += 1
                local flag = interesting(child.Name) and "  <-- INTERESTING" or ""
                add(string.format("[%s] %s  parent=%s%s",
                    child.ClassName, child.Name, pathOf(child.Parent), flag))
                local loc = pathOf(child.Parent)
                hotspots[loc] = (hotspots[loc] or 0) + 1
            end
            walkRemotes(child, depth + 1)
        end
    end
    walkRemotes(game, 0)
    if remoteCount == 0 then add("(none found anywhere)") end
    add(string.format("total remotes: %d", remoteCount))
    add("")

    -- ── remote hotspots ─────────────────────────────────────
    add("--- REMOTE HOTSPOTS (containers with most remotes) ---")
    local spots = {}
    for loc, n in pairs(hotspots) do
        table.insert(spots, {loc=loc, n=n})
    end
    table.sort(spots, function(a,b) return a.n > b.n end)
    for _, s in ipairs(spots) do
        add(string.format("%4d remotes in: %s", s.n, s.loc))
    end
    if #spots == 0 then add("(none)") end
    add("")

    -- ── proximity prompts ────────────────────────────────────
    add("--- PROXIMITY PROMPTS ---")
    local ppCount = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            ppCount += 1
            add(string.format("[PP] %s  Action='%s'  Key=%s  Hold=%.1fs  path=%s",
                obj.Name,
                tostring(obj.ActionText),
                tostring(obj.KeyboardKeyCode),
                obj.HoldDuration,
                pathOf(obj)))
        end
    end
    if ppCount == 0 then add("(none found in Workspace)") end
    add(string.format("total ProximityPrompts: %d", ppCount))
    add("")

    -- ── NPC models (Humanoid) ────────────────────────────────
    add("--- NPC MODELS (have Humanoid) ---")
    local npcCount = 0
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
            npcCount += 1
            local root = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
            local pos = root
                and string.format("(%.0f,%.0f,%.0f)", root.Position.X, root.Position.Y, root.Position.Z)
                or "(no root)"
            local flag = ""
            local nl = string.lower(v.Name)
            for _, kw in ipairs({"sell","merchant","trader","shop","vendor","buy","npc","fish"}) do
                if string.find(nl, kw, 1, true) then flag = "  <-- VENDOR?"; break end
            end
            add(string.format("NPC: %s %s%s", v.Name, pos, flag))
            -- check for remotes inside NPC
            for _, d in ipairs(v:GetDescendants()) do
                if REMOTE_TYPES[d.ClassName] then
                    add(string.format("    [%s] %s", d.ClassName, d.Name))
                end
                if d:IsA("ProximityPrompt") then
                    add(string.format("    [PP] Action='%s'", d.ActionText))
                end
            end
        end
    end
    if npcCount == 0 then add("(none)") end
    add("")

    -- ── sell/shop/npc parts (keyword scan) ───────────────────
    add("--- SELL / SHOP / NPC PARTS in Workspace (keyword) ---")
    local sellKw = {"sell","shop","market","npc","merchant","vendor","dock",
                    "store","buy","trade","fish","collect","reward","vault"}
    local sellCount = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local nl = string.lower(obj.Name)
        for _, kw in ipairs(sellKw) do
            if string.find(nl, kw, 1, true) then
                sellCount += 1
                local pos = ""
                if obj:IsA("BasePart") then
                    pos = string.format(" @ (%.0f,%.0f,%.0f)", obj.Position.X, obj.Position.Y, obj.Position.Z)
                end
                add(string.format("[%s] %s%s  path=%s",
                    obj.ClassName, obj.Name, pos, pathOf(obj)))
                break
            end
        end
    end
    if sellCount == 0 then add("(none)") end
    add("")

    -- ── GUI labels/buttons (bite detector, reel bar) ─────────
    add("--- GUI LABELS + BUTTONS (all screens except this one) ---")
    local guiCount = 0
    for _, obj in ipairs(LP.PlayerGui:GetDescendants()) do
        if obj.Parent and obj.Parent.Name ~= "HTFScan_GUI" and obj.Name ~= "HTFScan_GUI" then
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("ImageButton") then
                guiCount += 1
                local txt = ""
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    txt = string.format(' text="%s"', clamp(obj.Text, 40))
                end
                local flag = interesting(obj.Name) or interesting(obj:IsA("TextLabel") and obj.Text or "") and "  <--" or ""
                add(string.format("[%s] %s  vis=%s%s%s",
                    obj.ClassName,
                    clamp(obj:GetFullName(), 65),
                    tostring(obj.Visible),
                    txt,
                    flag ~= "" and "  <-- INTERESTING" or ""))
            end
        end
    end
    if guiCount == 0 then add("(none)") end
    add("")

    -- ── attributes on interesting workspace objects ──────────
    add("--- ATTRIBUTES ON INTERESTING WORKSPACE OBJECTS ---")
    local attrCount = 0
    for _, v in ipairs(Workspace:GetDescendants()) do
        local ok, attrs = pcall(function() return v:GetAttributes() end)
        if ok and next(attrs) and interesting(v.Name) then
            attrCount += 1
            local parts = {}
            for k, val in pairs(attrs) do
                table.insert(parts, string.format("%s=%s", k, clamp(val,25)))
            end
            add(string.format("%s [%d]: %s", pathOf(v), #parts, table.concat(parts, " | ")))
        end
    end
    if attrCount == 0 then add("(none)") end
    add("")

    -- ── fish/water/world folders ─────────────────────────────
    add("--- FISH/WATER/WORLD/BOAT FOLDERS (first 50 children each) ---")
    local folderKw = {"fish","water","world","boat","runtime","ocean","lake","sea","pond"}
    local foundFolders = {}
    for _, f in ipairs(Workspace:GetChildren()) do
        if f:IsA("Folder") or f:IsA("Model") then
            local nl = string.lower(f.Name)
            for _, kw in ipairs(folderKw) do
                if string.find(nl, kw, 1, true) then
                    table.insert(foundFolders, f); break
                end
            end
        end
    end
    for _, f in ipairs(foundFolders) do
        local kids = f:GetChildren()
        add(string.format("Folder/Model '%s' (%d children):", f.Name, #kids))
        local show = math.min(#kids, 50)
        for i = 1, show do
            local c = kids[i]
            local ok, attrs = pcall(function() return c:GetAttributes() end)
            local attrStr = ""
            if ok and next(attrs) then
                local parts = {}
                for k, val in pairs(attrs) do
                    table.insert(parts, string.format("%s=%s", k, clamp(val,18)))
                end
                attrStr = "  {" .. table.concat(parts, ", ") .. "}"
            end
            add(string.format("   [%s] %s%s", c.ClassName, c.Name, attrStr))
        end
        if #kids > show then add(string.format("   ... +%d more", #kids-show)) end
    end
    if #foundFolders == 0 then add("(none)") end
    add("")

    -- ── workspace top-level ──────────────────────────────────
    add("--- WORKSPACE TOP-LEVEL ---")
    for _, v in ipairs(Workspace:GetChildren()) do
        local flag = interesting(v.Name) and "  <--" or ""
        add(string.format("[%s] %s%s", v.ClassName, v.Name, flag))
    end
    add("")

    -- ── ReplicatedStorage top-level ─────────────────────────
    add("--- REPLICATEDSTORAGE TOP-LEVEL ---")
    if Rep then
        for _, v in ipairs(Rep:GetChildren()) do
            local flag = (v:IsA("RemoteEvent") or v:IsA("RemoteFunction"))
                and "  <-- REMOTE" or ""
            add(string.format("[%s] %s%s", v.ClassName, v.Name, flag))
        end
    end
    add("")

    -- ── signal connections on remotes ───────────────────────
    add("--- REMOTE OnClientEvent CONNECTIONS (getconnections) ---")
    local connTotal = 0
    pcall(function()
        for _, r in ipairs(game:GetDescendants()) do
            if r:IsA("RemoteEvent") then
                local ok, conns = pcall(function() return getconnections(r.OnClientEvent) end)
                if ok and #conns > 0 then
                    connTotal += #conns
                    add(string.format("[%d conns] %s", #conns, pathOf(r)))
                end
            end
        end
    end)
    if connTotal == 0 then add("(getconnections unavailable or 0 connections)") end
    add("")

    -- ── hint localscripts ───────────────────────────────────
    add("--- LOCALSCRIPTS with interesting names ---")
    local lsCount = 0
    local lsRoots = {LP, Rep}
    for _, root in ipairs(lsRoots) do
        if root then
            pcall(function()
                for _, v in ipairs(root:GetDescendants()) do
                    if v:IsA("LocalScript") and interesting(v.Name) then
                        lsCount += 1
                        add("LS: " .. pathOf(v))
                    end
                end
            end)
        end
    end
    if lsCount == 0 then add("(none)") end
    add("")

    -- ── gc closure scan ──────────────────────────────────────
    add("--- GC CLOSURE SCAN (debug.getregistry) ---")
    pcall(function()
        local gcHits = {}
        local ok, registry = pcall(debug.getregistry)
        if ok then
            for _, reg in ipairs(registry) do
                if type(reg) == "function" then
                    local ok2, info = pcall(debug.getinfo, reg)
                    if ok2 and info and info.source then
                        local src = info.source
                        for _, k in ipairs(KEYWORDS) do
                            if string.find(src:lower(), k, 1, true) then
                                gcHits[src] = (gcHits[src] or 0) + 1
                            end
                        end
                    end
                end
            end
            local shown = 0
            for src, n in pairs(gcHits) do
                if n >= 2 then
                    add(string.format("%dx hits: %s", n, clamp(src,80)))
                    shown += 1
                    if shown >= 30 then add("(capped at 30)"); break end
                end
            end
            if shown == 0 then add("(no hot closures)") end
        else
            add("(debug.getregistry unavailable)")
        end
    end)
    add("")

    add("=== END DUMP ===")
    add(string.format("total lines: %d", #lines))
    return table.concat(lines, "\n")
end

-- ── export ───────────────────────────────────────────────────
local function exportText(text)
    local wrote, clipped = false, false
    pcall(function()
        if writefile then writefile("htf_scan.txt", text); wrote = true end
    end)
    pcall(function()
        if getgenv().writefile then getgenv().writefile("htf_scan.txt", text); wrote = true end
    end)
    pcall(function()
        if setclipboard then setclipboard(text); clipped = true end
    end)
    pcall(function()
        if getgenv().setclipboard then getgenv().setclipboard(text); clipped = true end
    end)
    return wrote, clipped
end

-- ── GUI ──────────────────────────────────────────────────────
local BLACK  = Color3.fromRGB(10,10,10)
local WHITE  = Color3.fromRGB(245,245,245)
local GRAY   = Color3.fromRGB(60,60,60)
local DGRAY  = Color3.fromRGB(30,30,30)
local ACCENT = Color3.fromRGB(90,180,120)

local gui = Instance.new("ScreenGui")
gui.Name = "HTFScan_GUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent or not gui.Parent:IsA("CoreGui") then
    gui.Parent = LP:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,320,0,450)
frame.Position = UDim2.new(0.5,-160,0.5,-225)
frame.BackgroundColor3 = BLACK
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner",frame).CornerRadius = UDim.new(0,8)

-- topbar
local topbar = Instance.new("Frame")
topbar.Size = UDim2.new(1,0,0,34)
topbar.BackgroundColor3 = WHITE
topbar.BorderSizePixel = 0
topbar.Parent = frame
Instance.new("UICorner",topbar).CornerRadius = UDim.new(0,8)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,-42,1,0)
titleLbl.Position = UDim2.new(0,8,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "HTF SCANNER — FULL RECON"
titleLbl.TextColor3 = BLACK
titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Font = Enum.Font.GothamBold
titleLbl.Parent = topbar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,28,0,28)
closeBtn.Position = UDim2.new(1,-32,0,3)
closeBtn.BackgroundColor3 = GRAY
closeBtn.Text = "X"
closeBtn.TextColor3 = WHITE
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topbar
Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,5)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- drag
local dragging, dragOff
topbar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragOff  = inp.Position - frame.AbsolutePosition
    end
end)
topbar.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch) then
        local p = inp.Position - dragOff
        pcall(function() frame.Position = UDim2.fromOffset(p.X, p.Y) end)
    end
end)

-- scan button
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1,-16,0,34)
scanBtn.Position = UDim2.new(0,8,0,40)
scanBtn.BackgroundColor3 = WHITE
scanBtn.BorderSizePixel = 0
scanBtn.Text = "SCAN GAME (FULL)"
scanBtn.TextColor3 = BLACK
scanBtn.TextSize = 15
scanBtn.Font = Enum.Font.GothamBold
scanBtn.Parent = frame
Instance.new("UICorner",scanBtn).CornerRadius = UDim.new(0,6)

-- export + status row
local exportBtn = Instance.new("TextButton")
exportBtn.Size = UDim2.new(0.5,-12,0,34)
exportBtn.Position = UDim2.new(0,8,0,80)
exportBtn.BackgroundColor3 = ACCENT
exportBtn.BorderSizePixel = 0
exportBtn.Text = "EXPORT (file+clip)"
exportBtn.TextColor3 = BLACK
exportBtn.TextSize = 13
exportBtn.Font = Enum.Font.GothamBold
exportBtn.Parent = frame
Instance.new("UICorner",exportBtn).CornerRadius = UDim.new(0,6)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(0.5,-4,0,34)
statusLbl.Position = UDim2.new(0.5,4,0,80)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "idle"
statusLbl.TextColor3 = WHITE
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextWrapped = true
statusLbl.Parent = frame

-- scroll box
local box = Instance.new("ScrollingFrame")
box.Size = UDim2.new(1,-16,0,290)
box.Position = UDim2.new(0,8,0,122)
box.BackgroundColor3 = DGRAY
box.BorderSizePixel = 0
box.ScrollBarThickness = 4
box.ScrollBarImageColor3 = WHITE
box.Parent = frame
Instance.new("UICorner",box).CornerRadius = UDim.new(0,6)

-- TextBox so user can tap + select all + copy on mobile
local textbox = Instance.new("TextBox")
textbox.Size = UDim2.new(1,-12,0,0)
textbox.Position = UDim2.new(0,6,0,6)
textbox.BackgroundTransparency = 1
textbox.Text = "Press SCAN GAME to begin..."
textbox.TextColor3 = WHITE
textbox.TextSize = 10
textbox.Font = Enum.Font.Code
textbox.TextXAlignment = Enum.TextXAlignment.Left
textbox.TextYAlignment = Enum.TextYAlignment.Top
textbox.TextWrapped = true
textbox.MultiLine = true
textbox.ClearTextOnFocus = false
textbox.AutomaticSize = Enum.AutomaticSize.Y
textbox.Parent = box

-- ── hint label ───────────────────────────────────────────────
local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.new(1,-16,0,18)
hintLbl.Position = UDim2.new(0,8,1,-22)
hintLbl.BackgroundTransparency = 1
hintLbl.Text = "Tap box → hold → Select All → Copy"
hintLbl.TextColor3 = Color3.fromRGB(130,130,130)
hintLbl.TextSize = 10
hintLbl.Font = Enum.Font.Gotham
hintLbl.Parent = frame

-- ── button logic ─────────────────────────────────────────────
local lastResult = ""

scanBtn.MouseButton1Click:Connect(function()
    statusLbl.Text = "scanning... hang on"
    task.wait(0.05)
    local ok, result = pcall(scan)
    if ok then
        lastResult = result
        textbox.Text = result
        box.CanvasSize = UDim2.new(0,0,0, textbox.TextBounds.Y + 12)
        statusLbl.Text = "done — " .. #lines .. " lines"
    else
        statusLbl.Text = "error: " .. clamp(tostring(result),60)
    end
end)

exportBtn.MouseButton1Click:Connect(function()
    if lastResult == "" then
        statusLbl.Text = "scan first!"
        return
    end
    local wrote, clipped = exportText(lastResult)
    if wrote and clipped then
        statusLbl.Text = "htf_scan.txt + clipboard"
    elseif wrote then
        statusLbl.Text = "htf_scan.txt written (tap box to copy)"
    elseif clipped then
        statusLbl.Text = "clipboard OK"
    else
        statusLbl.Text = "no file/clip — tap box, Select All, Copy"
    end
end)

-- ── auto-scan on load ─────────────────────────────────────────
task.wait(0.5)
pcall(function()
    statusLbl.Text = "auto-scanning..."
    local result = scan()
    lastResult = result
    textbox.Text = result
    box.CanvasSize = UDim2.new(0,0,0, textbox.TextBounds.Y + 12)
    statusLbl.Text = "done — " .. #lines .. " lines"
end)
