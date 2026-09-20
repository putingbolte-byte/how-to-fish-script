--[[
        FISCH SCANNER v2 — FAT RECON
        Dumps everything: tree, remotes (deep), attributes, NPCs,
        rods, fish models, signal connections, gc hint closures.
        COPY ALL writes fisch_scan_v2.txt first, clipboard second.
        Delta / mobile safe.
]]

if getgenv().FischScan_Loaded then
        local old = game:FindFirstChild("FischScan_GUI")
        if old then old:Destroy() end
        getgenv().FischScan_Loaded = false
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local Rep = game:GetService("ReplicatedStorage")

local lines = {}
local function add(s) table.insert(lines, s) end

-- ============ HELPERS ============
local function pathOf(obj)
        local parts = {}
        local cur = obj
        while cur and cur ~= game do
                table.insert(parts, 1, cur.Name)
                cur = cur.Parent
        end
        return table.concat(parts, " > ")
end

local function clampStr(s, maxLen)
        s = tostring(s)
        if #s > maxLen then return s:sub(1, maxLen - 3) .. "..." end
        return s
end

local RARE_WORDS = {"bobber", "float", "fish", "rod", "sell", "shop", "npc",
        "trader", "merchant", "market", "water", "ocean", "sea", "lake", "pond",
        "cast", "reel", "bite", "hook", "catch", "vault", "inventory", "luck",
        "chance", "rarity", "price", "value", "bait", "lure"}

local function isInteresting(n)
        local nl = string.lower(n)
        for _, k in ipairs(RARE_WORDS) do
                if string.find(nl, k, 1, true) then return true end
        end
        return false
end

-- ============ SCAN ============
local function scan()
        lines = {}
        add("=== FISCH SCANNER v2 DUMP ===")
        add("Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
        add("Game: " .. tostring(game.Name))
        add("PlaceId: " .. tostring(game.PlaceId))
        add("JobId: " .. tostring(game.JobId))
        add("Exec: " .. tostring(getgenv().executor or "unknown"))
        add("")

        -- player
        add("--- LOCAL PLAYER ---")
        add("Name: " .. tostring(LocalPlayer.Name))
        add("UserId: " .. tostring(LocalPlayer.UserId))
        add("Character: " .. tostring(LocalPlayer.Character and LocalPlayer.Character.Name or "NONE"))
        add("")

        -- tools + remotes inside
        add("--- TOOLS (Character + Backpack) + THEIR REMOTES ---")
        local seenTools = {}
        local function scanTools(container, tag)
                if not container then return end
                for _, t in ipairs(container:GetChildren()) do
                        if t:IsA("Tool") then
                                if not seenTools[t.Name] then
                                        seenTools[t.Name] = true
                                        add(string.format("[%s] Tool: %s %s", tag, tostring(t.Name),
                                                t:FindFirstChild("Handle") and ("@ " .. string.format("(%.0f, %.0f, %.0f)", t.Handle.Position.X, t.Handle.Position.Y, t.Handle.Position.Z)) or ""))
                                end
                                for _, r in ipairs(t:GetDescendants()) do
                                        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                                                add(string.format("    Remote (%s): %s [%s]", r.ClassName, tostring(r.Name), pathOf(r)))
                                        end
                                end
                                for _, a in ipairs(t:GetDescendants()) do
                                        if a:IsA("Configuration") or a:IsA("ValueBase") then
                                                add(string.format("    Cfg: %s = %s", tostring(a.Name), clampStr(a:IsA("ValueBase") and tostring(a.Value) or "?", 60)))
                                        end
                                end
                        end
                end
        end
        scanTools(LocalPlayer.Character, "CHAR")
        scanTools(LocalPlayer.Backpack, "BP")
        add("")

        -- workspace top level
        add("--- WORKSPACE TOP-LEVEL (class: name) ---")
        local topMarked = 0
        for _, v in ipairs(Workspace:GetChildren()) do
                local flag = isInteresting(v.Name) and "  <--" or ""
                if flag ~= "" then topMarked = topMarked + 1 end
                add(string.format("%s: %s%s", v.ClassName, tostring(v.Name), flag))
        end
        add(string.format("(%d interesting top-level marked)", topMarked))
        add("")

        -- deep tree scan for remotes + attributes (depth-limited)
        add("--- DEEP REMOTE SWEEP (full tree, interesting marked) ---")
        local remoteCount = 0
        local remoteByLoc = {}
        local function walkRemotes(obj, depth)
                if depth > 10 then return end
                for _, child in ipairs(obj:GetChildren()) do
                        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                                remoteCount = remoteCount + 1
                                local interesting = isInteresting(child.Name) and "  <--" or ""
                                add(string.format("(%s) %s < %s%s", child.ClassName, tostring(child.Name), pathOf(child.Parent), interesting))
                                remoteByLoc[pathOf(child.Parent)] = (remoteByLoc[pathOf(child.Parent)] or 0) + 1
                        end
                        walkRemotes(child, depth + 1)
                end
        end
        walkRemotes(game, 0)
        if remoteCount == 0 then add("(no remotes found anywhere in game tree)") end
        add(string.format("total remotes: %d", remoteCount))
        add("")

        -- remote hotspots (containers holding many remotes)
        add("--- REMOTE HOTSPOTS (by parent container) ---")
        local hotCount = 0
        for loc, n in pairs(remoteByLoc) do
                add(string.format("%4d remotes under %s", n, loc))
                hotCount = hotCount + 1
        end
        if hotCount == 0 then add("(no containers with remotes)") end
        add("")

        -- attributes on interesting objects
        add("--- ATTRIBUTES ON INTERESTING OBJECTS ---")
        local attrCount = 0
        for _, v in ipairs(Workspace:GetDescendants()) do
                local attrs = v:GetAttributes()
                if next(attrs) then
                        local root = v.Name
                        local interesting = isInteresting(root)
                        if interesting then
                                local parts = {}
                                for k, val in pairs(attrs) do
                                        table.insert(parts, string.format("%s=%s", tostring(k), clampStr(val, 30)))
                                end
                                add(string.format("%s [%d attrs]: %s", pathOf(v), #parts, table.concat(parts, " | ")))
                                attrCount = attrCount + 1
                        end
                end
        end
        if attrCount == 0 then add("(no attributes on interesting objects)") end
        add("")

        -- NPCs (with Humanoid/HRP)
        add("--- NPC-LIKE MODELS ---")
        local npcCount = 0
        for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and not v:IsA("Tool") then
                        local root = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Part")
                        local pos = root and string.format("(%.0f, %.0f, %.0f)", root.Position.X, root.Position.Y, root.Position.Z) or "(no root)"
                        local nl = string.lower(v.Name)
                        local tag = ""
                        if string.find(nl, "sell", 1, true) or string.find(nl, "merchant", 1, true)
                        or string.find(nl, "trader", 1, true) or string.find(nl, "shop", 1, true) then
                                tag = "  <-- vendor"
                        end
                        npcCount = npcCount + 1
                        add(string.format("NPC: %s %s%s", tostring(v.Name), pos, tag))
                end
        end
        if npcCount == 0 then add("(no NPC models with Humanoid found)") end
        add("")

        -- fish models in FishWorld-ish folders
        add("--- FISH-WORLD / WATER / BOAT FOLDER CONTENTS (first 40 children each) ---")
        local worldFolders = {}
        for _, f in ipairs(Workspace:GetChildren()) do
                if f:IsA("Folder") then
                        local nl = string.lower(f.Name)
                        if string.find(nl, "fish", 1, true) or string.find(nl, "water", 1, true)
                        or string.find(nl, "world", 1, true) or string.find(nl, "boat", 1, true)
                        or string.find(nl, "runtime", 1, true) then
                                table.insert(worldFolders, f)
                        end
                end
        end
        for _, f in ipairs(worldFolders) do
                local kids = f:GetChildren()
                add(string.format("Folder %s (%d children):", tostring(f.Name), #kids))
                local shown = math.min(#kids, 40)
                for i = 1, shown do
                        local c = kids[i]
                        local attrs = c:GetAttributes()
                        local attrStr = ""
                        if next(attrs) then
                                local parts = {}
                                for k, val in pairs(attrs) do
                                        table.insert(parts, string.format("%s=%s", tostring(k), clampStr(val, 20)))
                                end
                                attrStr = "  {" .. table.concat(parts, ", ") .. "}"
                        end
                        add(string.format("   %s: %s%s", c.ClassName, tostring(c.Name), attrStr))
                end
                if #kids > shown then add(string.format("   ... +%d more", #kids - shown)) end
        end
        if #worldFolders == 0 then add("(no fish/water/world-folders found)") end
        add("")

        -- signal connection counts on every remote (hookability)
        add("--- REMOTE SIGNAL-PULL POTENTIAL (getconnections) ---")
        local connTotal = 0
        for _, r in ipairs(game:GetDescendants()) do
                if r:IsA("RemoteEvent") then
                        local ok, conns = pcall(function() return getconnections(r.OnClientEvent) end)
                        if ok and #conns > 0 then
                                connTotal = connTotal + #conns
                                add(string.format("OnClientEvent[%d] %s", #conns, pathOf(r)))
                        end
                end
        end
        if connTotal == 0 then add("(getconnections unavailable or zero conns)") end
        add("")

        -- localscripts with hint names (find where logic lives)
        add("--- LOCAL SCRIPTS with hint names ---")
        local lsCount = 0
        local roots = {game:GetService("Players"), Rep, game:GetService("ServerStorage"), game:GetService("ServerScriptService")}
        for _, root in ipairs(roots) do
                if root then
                        for _, v in ipairs(root:GetDescendants()) do
                                if v:IsA("LocalScript") then
                                        local nl = string.lower(v.Name)
                                        if isInteresting(nl) then
                                                lsCount = lsCount + 1
                                                add(string.format("LS: %s", pathOf(v)))
                                        end
                                end
                        end
                end
        end
        if lsCount == 0 then add("(no hint-named localscripts found)") end
        add("")

        -- gc closure scan for remote names (executors with debug.getregistry)
        add("--- GC CLOSURE REMOTE-REF SCAN (debug.getregistry) ---")
        local gcHits = {}
        local okRegistry, registry = pcall(debug.getregistry)
        if okRegistry then
                for _, reg in ipairs(registry) do
                        if type(reg) == "function" then
                                local okInfo = pcall(debug.getinfo, reg)
                                if okInfo then
                                        local info = debug.getinfo(reg)
                                        if info and info.source and info.source:find("=") then
                                                local src = info.source
                                                for _, k in ipairs(RARE_WORDS) do
                                                        if string.find(src:lower(), k, 1, true) then
                                                                if not gcHits[src] then gcHits[src] = 0 end
                                                                gcHits[src] = gcHits[src] + 1
                                                        end
                                                end
                                        end
                                end
                        end
                end
                local shown = 0
                for src, n in pairs(gcHits) do
                        if n >= 3 then
                                add(string.format("%dx refs in %s", n, clampStr(src, 80)))
                                shown = shown + 1
                                if shown >= 25 then add("(clamped gc display at 25)") break end
                        end
                end
                if shown == 0 then add("(no hot closure sources found)") end
        else
                add("(debug.getregistry unavailable on this exec)")
        end
        add("")

        -- ReplicatedStorage top-level (remotes usually live here)
        add("--- REPLICATEDSTORAGE TOP-LEVEL ---")
        if Rep then
                for _, v in ipairs(Rep:GetChildren()) do
                        local flag = (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and "  <-- REMOTE" or ""
                        add(string.format("%s: %s%s", v.ClassName, tostring(v.Name), flag))
                end
        end
        add("")

        add("=== END DUMP ===")
        return table.concat(lines, "\n")
end

-- ============ EXPORT ============
local function exportText(text)
        -- 1) writefile first (always works on most execs)
        local wrote = false
        pcall(function()
                if writefile then
                        writefile("fisch_scan_v2.txt", text)
                        wrote = true
                end
        end)
        pcall(function()
                if getgenv().writefile then
                        getgenv().writefile("fisch_scan_v2.txt", text)
                        wrote = true
                end
        end)
        -- 2) clipboard second
        local clipped = false
        pcall(function()
                if setclipboard then
                        setclipboard(text)
                        clipped = true
                end
        end)
        pcall(function()
                if getgenv().setclipboard then
                        getgenv().setclipboard(text)
                        clipped = true
                end
        end)
        return wrote, clipped
end

-- ============ GUI ============
local gui = Instance.new("ScreenGui")
gui.Name = "FischScan_GUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local BLACK = Color3.fromRGB(10, 10, 10)
local WHITE = Color3.fromRGB(245, 245, 245)
local GRAY = Color3.fromRGB(60, 60, 60)
local DGRAY = Color3.fromRGB(30, 30, 30)
local ACCENT = Color3.fromRGB(90, 180, 120)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 440)
frame.Position = UDim2.new(0.5, -160, 0.5, -220)
frame.BackgroundColor3 = BLACK
frame.BorderSizePixel = 0
frame.Parent = gui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = frame

local topbar = Instance.new("Frame")
topbar.Size = UDim2.new(1, 0, 0, 34)
topbar.BackgroundColor3 = WHITE
topbar.BorderSizePixel = 0
topbar.Parent = frame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 8)
topCorner.Parent = topbar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 8, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FISCH SCANNER v2"
title.TextColor3 = BLACK
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.Parent = topbar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 3)
closeBtn.BackgroundColor3 = GRAY
closeBtn.Text = "X"
closeBtn.TextColor3 = WHITE
closeBtn.TextSize = 15
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topbar
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

local dragging, dragOffset
topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragOffset = input.Position - frame.AbsolutePosition
        end
end)
topbar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
        end
end)
UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local pos = input.Position - dragOffset
                pcall(function() frame.Position = UDim2.fromOffset(pos.X, pos.Y) end)
        end
end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1, -16, 0, 34)
scanBtn.Position = UDim2.new(0, 8, 0, 40)
scanBtn.BackgroundColor3 = WHITE
scanBtn.BorderSizePixel = 0
scanBtn.Text = "SCAN GAME (FULL)"
scanBtn.TextColor3 = BLACK
scanBtn.TextSize = 15
scanBtn.Font = Enum.Font.GothamBold
scanBtn.Parent = frame
local scanCorner = Instance.new("UICorner")
scanCorner.CornerRadius = UDim.new(0, 6)
scanCorner.Parent = scanBtn

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0.5, -12, 0, 34)
copyBtn.Position = UDim2.new(0, 8, 0, 80)
copyBtn.BackgroundColor3 = ACCENT
copyBtn.BorderSizePixel = 0
copyBtn.Text = "EXPORT (file + clip)"
copyBtn.TextColor3 = BLACK
copyBtn.TextSize = 13
copyBtn.Font = Enum.Font.GothamBold
copyBtn.Parent = frame
local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 6)
copyCorner.Parent = copyBtn

local status = Instance.new("TextLabel")
status.Size = UDim2.new(0.5, -4, 0, 34)
status.Position = UDim2.new(0.5, 4, 0, 80)
status.BackgroundTransparency = 1
status.Text = "idle"
status.TextColor3 = WHITE
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local box = Instance.new("ScrollingFrame")
box.Size = UDim2.new(1, -16, 0, 290)
box.Position = UDim2.new(0, 8, 0, 122)
box.BackgroundColor3 = DGRAY
box.BorderSizePixel = 0
box.ScrollBarThickness = 4
box.ScrollBarImageColor3 = WHITE
box.Parent = frame

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 6)
boxCorner.Parent = box

local textbox = Instance.new("TextLabel")
textbox.Size = UDim2.new(1, -12, 0, 0)
textbox.Position = UDim2.new(0, 6, 0, 6)
textbox.BackgroundTransparency = 1
textbox.Text = "Press SCAN GAME (FULL)"
textbox.TextColor3 = WHITE
textbox.TextSize = 11
textbox.Font = Enum.Font.Code
textbox.TextXAlignment = Enum.TextXAlignment.Left
textbox.TextYAlignment = Enum.TextYAlignment.Top
textbox.TextWrapped = true
textbox.AutomaticSize = Enum.AutomaticSize.Y
textbox.Parent = box

scanBtn.MouseButton1Click:Connect(function()
        status.Text = "scanning... (deep sweep, hang on)"
        task.wait(0.05)
        local ok, result = pcall(scan)
        if ok then
                textbox.Text = result
                box.CanvasSize = UDim2.new(0, 0, 0, textbox.TextBounds.Y + 12)
                status.Text = "done. " .. #lines .. " lines"
        else
                status.Text = "scan error: " .. tostring(result)
        end
end)

copyBtn.MouseButton1Click:Connect(function()
        local text = textbox.Text
        if text == "Press SCAN GAME (FULL)" then
                status.Text = "scan first!"
                return
        end
        local wrote, clipped = exportText(text)
        if wrote and clipped then
                status.Text = "wrote fisch_scan_v2.txt + clipboard"
        elseif wrote then
                status.Text = "wrote fisch_scan_v2.txt (no clipboard)"
        elseif clipped then
                status.Text = "clipboard only (no writefile)"
        else
                status.Text = "export unavailable - copy from box"
        end
end)

-- auto-scan on load
task.wait(0.5)
pcall(function()
        textbox.Text = scan()
        box.CanvasSize = UDim2.new(0, 0, 0, textbox.TextBounds.Y + 12)
        status.Text = "done. " .. #lines .. " lines"
end)
