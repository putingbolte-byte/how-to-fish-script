--[[
        FISCH SCANNER — recon tool
        Dumps game structure, rods, bobbers, remotes, sell NPCs, fish models.
        Black & White GUI with COPY ALL button (clipboard).
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

local lines = {}
local function add(s)
        table.insert(lines, s)
end

-- ============ SCAN ============
local function scan()
        lines = {}
        add("=== FISCH SCANNER DUMP ===")
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

        -- character tools + backpack
        add("--- TOOLS (Character + Backpack) ---")
        local seen = {}
        local function scanTools(container, tag)
                if not container then return end
                for _, t in ipairs(container:GetChildren()) do
                        if t:IsA("Tool") then
                                if not seen[t.Name] then
                                        seen[t.Name] = true
                                        add(string.format("[%s] Tool: %s", tag, tostring(t.Name)))
                                end
                                for _, r in ipairs(t:GetDescendants()) do
                                        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                                                add(string.format("    Remote (%s): %s", r.ClassName, tostring(r.Name)))
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
        local interesting = {"bobber", "float", "fish", "rod", "sell", "shop", "npc", "trader", "merchant", "market", "water", "ocean", "sea", "lake", "pond"}
        local function isInteresting(n)
                local nl = string.lower(n)
                for _, k in ipairs(interesting) do
                        if string.find(nl, k, 1, true) then return true end
                end
                return false
        end
        for _, v in ipairs(Workspace:GetChildren()) do
                local flag = isInteresting(v.Name) and "  <--" or ""
                add(string.format("%s: %s%s", v.ClassName, tostring(v.Name), flag))
        end
        add("")

        -- deep scan for remotes anywhere interesting
        add("--- REMOTES UNDER INTERESTING MODELS ---")
        local count = 0
        for _, v in ipairs(Workspace:GetDescendants()) do
                local isMod = v:IsA("Model") and isInteresting(v.Name)
                if isMod then
                        for _, r in ipairs(v:GetDescendants()) do
                                if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
                                        count = count + 1
                                        add(string.format("%s :: %s -> (%s) %s", tostring(v.Name), r.ClassName, tostring(r.Parent and r.Parent.Name or "?"), tostring(r.Name)))
                                end
                        end
                end
        end
        if count == 0 then add("(no remotes found under interesting models)") end
        add("")

        -- NPCs
        add("--- NPC-LIKE MODELS ---")
        local npcCount = 0
        for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and not v:IsA("Tool") then
                        local nl = string.lower(v.Name)
                        if string.find(nl, "npc", 1, true) or string.find(nl, "sell", 1, true) or string.find(nl, "shop", 1, true) or string.find(nl, "trader", 1, true) or string.find(nl, "merchant", 1, true) or string.find(nl, "market", 1, true) then
                                npcCount = npcCount + 1
                                local root = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Part")
                                local pos = root and string.format("(%.0f, %.0f, %.0f)", root.Position.X, root.Position.Y, root.Position.Z) or "(no root)"
                                add(string.format("NPC: %s %s", tostring(v.Name), pos))
                        end
                end
        end
        if npcCount == 0 then add("(no obvious NPC models found)") end
        add("")

        -- player proximity hints: folders/values with interesting content nearby
        add("--- LOCALS/SCRIPTS bearing hints ---")
        local hintCount = 0
        local hintWords = {"sell", "cast", "reel", "bite", "fish", "rod", "chance", "luck", "strength", "rarity"}
        for _, v in ipairs(LocalPlayer:FindFirstChild("PlayerGui"):GetDescendants()) do
                if v:IsA("LocalScript") or v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                        local nl = string.lower(v.Name)
                        for _, k in ipairs(hintWords) do
                                if string.find(nl, k, 1, true) then
                                        hintCount = hintCount + 1
                                        add(string.format("PGui %s: %s", v.ClassName, tostring(v.Name)))
                                        break
                                end
                        end
                end
        end
        if hintCount == 0 then add("(no hint-named objects in PlayerGui)") end
        add("")
        add("=== END DUMP ===")

        return table.concat(lines, "\n")
end

-- ============ CLIPBOARD ============
local function copyToClipboard(text)
        local ok = pcall(function()
                if setclipboard then setclipboard(text) end
        end)
        if ok and setclipboard then
                return true
        end
        local ok2 = pcall(function()
                if getgenv().setclipboard then getgenv().setclipboard(text) end
        end)
        if ok2 and getgenv().setclipboard then
                return true
        end
        local ok3 = pcall(function()
                if getgenv().Clipboard and getgenv().Clipboard.set then getgenv().Clipboard.set(text) end
        end)
        if ok3 and getgenv().Clipboard and getgenv().Clipboard.set then
                return true
        end
        if not ok and not ok2 and not ok3 then
                -- last resort: syn/workspace write helpers
                pcall(function()
                        if writefile then writefile("fisch_scan_dump.txt", text) end
                end)
                pcall(function()
                        if getgenv().writefile then getgenv().writefile("fisch_scan_dump.txt", text) end
                end)
        end
        return false
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

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 420)
frame.Position = UDim2.new(0.5, -150, 0.5, -210)
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
title.Text = "FISCH SCANNER"
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

-- scan button
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1, -16, 0, 34)
scanBtn.Position = UDim2.new(0, 8, 0, 40)
scanBtn.BackgroundColor3 = WHITE
scanBtn.BorderSizePixel = 0
scanBtn.Text = "SCAN GAME"
scanBtn.TextColor3 = BLACK
scanBtn.TextSize = 15
scanBtn.Font = Enum.Font.GothamBold
scanBtn.Parent = frame
local scanCorner = Instance.new("UICorner")
scanCorner.CornerRadius = UDim.new(0, 6)
scanCorner.Parent = scanBtn

-- copy button
local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0.5, -12, 0, 34)
copyBtn.Position = UDim2.new(0, 8, 0, 80)
copyBtn.BackgroundColor3 = GRAY
copyBtn.BorderSizePixel = 0
copyBtn.Text = "COPY ALL"
copyBtn.TextColor3 = WHITE
copyBtn.TextSize = 14
copyBtn.Font = Enum.Font.GothamBold
copyBtn.Parent = frame
local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 6)
copyCorner.Parent = copyBtn

-- status label
local status = Instance.new("TextLabel")
status.Size = UDim2.new(0.5, -4, 0, 34)
status.Position = UDim2.new(0.5, 4, 0, 80)
status.BackgroundTransparency = 1
status.Text = "idle"
status.TextColor3 = WHITE
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

-- dump box
local box = Instance.new("ScrollingFrame")
box.Size = UDim2.new(1, -16, 0, 280)
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
textbox.Text = "Press SCAN GAME"
textbox.TextColor3 = WHITE
textbox.TextSize = 11
textbox.Font = Enum.Font.Code
textbox.TextXAlignment = Enum.TextXAlignment.Left
textbox.TextYAlignment = Enum.TextYAlignment.Top
textbox.TextWrapped = true
textbox.AutomaticSize = Enum.AutomaticSize.Y
textbox.Parent = box

local UIGradient = Instance.new("UIGradient")
UIGradient.Rotation = 90
UIGradient.Color = ColorSequence.new(WHITE, WHITE)
UIGradient.Parent = textbox

scanBtn.MouseButton1Click:Connect(function()
        status.Text = "scanning..."
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
        if text == "Press SCAN GAME" then
                status.Text = "scan first!"
                return
        end
        local usedFile = false
        local ok, err = pcall(copyToClipboard, text)
        if ok then
                status.Text = "copied to clipboard (or wrote fisch_scan_dump.txt)"
                usedFile = true
        else
                status.Text = "clipboard failed: " .. tostring(err)
        end
        if not ((setclipboard and ok) or (getgenv().setclipboard and ok) or (getgenv().Clipboard and ok)) then
                status.Text = "no clipboard - wrote fisch_scan_dump.txt"
        end
end)

-- auto-scan on load
task.wait(0.5)
pcall(function()
        textbox.Text = scan()
        box.CanvasSize = UDim2.new(0, 0, 0, textbox.TextBounds.Y + 12)
        status.Text = "done. " .. #lines .. " lines"
end)
