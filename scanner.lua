local RS  = game:GetService("ReplicatedStorage")
local WS  = game:GetService("Workspace")
local SS  = game:GetService("ServerStorage")
local LP  = game:GetService("Players").LocalPlayer
local GUI = LP.PlayerGui

print("========== REMOTE SCAN START ==========")

local found = {}

local function scan(root, path)
    for _, obj in pairs(root:GetDescendants()) do
        local t = obj.ClassName
        if t == "RemoteEvent" or t == "RemoteFunction" or t == "BindableEvent" or t == "BindableFunction" then
            local fullpath = obj:GetFullName()
            table.insert(found, string.format("[%s]  %s", t, fullpath))
        end
    end
end

scan(RS,  "ReplicatedStorage")
scan(WS,  "Workspace")
scan(LP,  "LocalPlayer")
scan(GUI, "PlayerGui")

print("Total remotes found: " .. #found)
for _, line in pairs(found) do
    print(line)
end

print("")
print("========== GUI SCAN ==========")
-- Also dump all visible GUI text so we can find bite indicator names
local function scanGUI(root)
    for _, obj in pairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("Frame") then
            print(string.format("[GUI:%s] Name='%s' Text='%s' Visible=%s Parent='%s'",
                obj.ClassName,
                obj.Name,
                (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text or "",
                tostring(obj.Visible),
                obj.Parent and obj.Parent.Name or "nil"
            ))
        end
    end
end
scanGUI(GUI)

print("")
print("========== TOOL SCAN ==========")
-- Dump equipped tools and their children
local char = LP.Character
if char then
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            print("TOOL: " .. tool.Name)
            for _, child in pairs(tool:GetDescendants()) do
                print("  └ [" .. child.ClassName .. "] " .. child:GetFullName())
            end
        end
    end
end
for _, tool in pairs(LP.Backpack:GetChildren()) do
    if tool:IsA("Tool") then
        print("BACKPACK TOOL: " .. tool.Name)
        for _, child in pairs(tool:GetDescendants()) do
            print("  └ [" .. child.ClassName .. "] " .. child:GetFullName())
        end
    end
end

print("")
print("========== NPC / PROXIMITY SCAN ==========")
-- Find any part named sell/shop/npc etc in workspace
local sellKeywords = {"sell","shop","market","npc","merchant","vendor","fish","dock","boat","store"}
for _, obj in pairs(WS:GetDescendants()) do
    if obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("ProximityPrompt") then
        local n = obj.Name:lower()
        for _, kw in pairs(sellKeywords) do
            if n:find(kw) then
                print(string.format("[WS:%s] %s", obj.ClassName, obj:GetFullName()))
                break
            end
        end
    end
end

print("========== SCAN DONE ==========")
print("Copy everything above and send it!")
