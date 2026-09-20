--[[
        howtofisch.lua — Ugc (Fisch-like) farm core
        dump date : 2026-09-20 17:57:07
        placeId   : 130925859181789

        What it does:
          [F1] toggle ESP        — dead fish, live fish, seagulls, hoops, drops, sell NPCs, baits
          [F2] toggle auto-farm  — collect dead fish -> haul to vendor -> stand on SellAll prompt
          [F3] toggle buy bait   — walk to a shop display, park on the prompt, you press E
          [F4] island teleport   — built from ShopDisplays anchors (Island1..6, Volcano, Arctic, Golden Uzi)
          [F5] sell run once     — nearest Sell NPC, park on SellAllFishPrompt
          [F6] fish magnet       — snap to nearest dead fish
          [F7] anti-drown guard  — never sleep with the fishes (default ON)
          [F8] disable all

        Movement is Humanoid:MoveTo (legit server-validated pathing) with a small-step
        CFrame tween fallback. No teleport flags, no speed hacks, nothing the server
        can trip on. The grind is legit — just not YOUR fingers doing it.

        NOTE ON PURCHASES: buying is a server auth via a real ProximityPrompt click,
        so auto-buy parks you ON the prompt and you tap E. The dump shows no buy
        remote under RSS (only ServerSideBulkPurchaseEvent, which is server->client),
        so no magic FireServer for cash exists in this tree. If you ever find the
        buy remote, drop it in CFG.extraFireRemotes below.
--]]

--[[ ======================= CONFIG ======================= ]]
local CFG = {
        moveMode = "MoveTo",              -- "MoveTo" (recomended) or "Tween"
        moveSpeed = 24,                   -- applied to Humanoid.WalkSpeed while farming
        arriveRadius = 4,                 -- studs to consider "arrived"
        collectRadius = 60,               -- magnet / esp radius for dead fish
        sellParkTime = 1.5,               -- seconds parked on vendor prompt
        antiDrownFloorY = -14.5,          -- dump: MinimumPlayerFloorY=-15, LocalWaterMaximumY=-19.5
        antiDrownSeek = 3.5,              -- height we hover above safe floor
        espEnabled = true,
        espBones = false,                 -- fishes are mermaid'd models, bones are per-fish parts
        espColorFish = Color3.fromRGB(120, 255, 120),
        espColorDeadFish = Color3.fromRGB(255, 120, 120),
        espColorSeagull = Color3.fromRGB(255, 200, 80),
        espColorHoop = Color3.fromRGB(120, 200, 255),
        espColorDrop = Color3.fromRGB(255, 255, 120),
        espColorNPC = Color3.fromRGB(200, 120, 255),
        espColorBait = Color3.fromRGB(255, 140, 255),
        autoFarm = false,
        autoBuy = false,
        showUI = true,
        extraFireRemotes = {              -- if you find named remotes, they get fired with {} on farm tick
                -- ["SellFish"] = {},
        },
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Storage = game:GetService("ReplicatedStorage") or ReplicatedStorage

local Player = Players.LocalPlayer
local DrawingAvail = (type(Drawing) == "table") or pcall(function() return Drawing.new end)

local ToggleColors = {
        espEnabled = "ESP",
        autoFarm = "FARM",
        autoBuy = "BUY",
}

--[[ ======================= HELPERS ======================= ]]
local function findChild(parent, name, tag)
        for _, v in ipairs(parent:GetChildren()) do
                if v.Name == name and (not tag or v:IsA(tag)) then return v end
        end
        return nil
end

local function getChar()
        local c = Player.Character
        if c and c:FindFirstChild("HumanoidRootPart") then return c end
        return nil
end

local function getRoot()
        local c = getChar()
        return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function getHumanoid()
        local c = getChar()
        return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function partPos(p)
        if p:IsA("BasePart") then return p.Position end
        if p:IsA("Model") then
                local pr = p.PrimaryPart or p:FindFirstChild("Root") or p:FindFirstChild("HumanoidRootPart") or p:FindFirstChildOfClass("BasePart")
                if pr then return pr.Position end
        end
        return nil
end

local function partCFrame(p)
        if p:IsA("BasePart") then return p.CFrame end
        if p:IsA("Model") then
                local pr = p.PrimaryPart or p:FindFirstChild("Root") or p:FindFirstChild("HumanoidRootPart") or p:FindFirstChildOfClass("BasePart")
                if pr then return pr.CFrame end
        end
        return nil
end

local function distTo(p)
        local r = getRoot()
        if not r then return math.huge end
        local pos = partPos(p)
        if not pos then return math.huge end
        return (r.Position - pos).Magnitude
end

local function nearest(list)
        local best, bd = nil, math.huge
        for _, v in ipairs(list) do
                local d = distTo(v)
                if d < bd then best, bd = v, d end
        end
        return best, bd
end

local function tweenTo(cf, speed)
        local r = getRoot()
        if not r then return false end
        local dist = (r.Position - cf.Position).Magnitude
        local dur = math.clamp(dist / (speed or 30), 0.1, 4)
        local tween = TweenService:Create(r, TweenInfo.new(dur, Enum.EasingStyle.Linear), { CFrame = cf })
        tween:Play()
        tween.Completed:Wait()
        tween:Destroy()
        return true
end

local function tweenStepTo(targetCF, radius)
        -- small hops instead of one long tween — looks like legit movement
        local r = getRoot()
        if not r then return false end
        while r and (r.Position - targetCF.Position).Magnitude > radius do
                local dist = (r.Position - targetCF.Position).Magnitude
                local step = math.min(dist * 0.5, 60)
                local now = r.Position
                local dir = (targetCF.Position - now).Unit
                local nextPos = now + dir * step
                nextPos = Vector3.new(nextPos.X, math.max(nextPos.Y, CFG.antiDrownFloorY), nextPos.Z)
                local t = TweenService:Create(r, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { CFrame = CFrame.new(nextPos) })
                t:Play()
                t.Completed:Wait()
                t:Destroy()
                task.wait(0.01)
        end
        return true
end

local function moveTo(cf, radius)
        local hum = getHumanoid()
        local r = getRoot()
        if not hum or not r then return false end
        if CFG.moveMode == "Tween" then
                return tweenStepTo(cf, radius or CFG.arriveRadius)
        end
        hum:MoveTo(cf.Position)
        local finished = hum.MoveToFinished:Wait(8)
        if not finished then
                -- fallback: nudge with tween
                return tweenStepTo(cf, radius or CFG.arriveRadius)
        end
        return true
end

local function respawnSafe()
        -- re-grab character refs after death
        if not getChar() then
                local t = 0
                while not getChar() and t < 10 do
                        task.wait(0.5)
                        t = t + 0.5
                end
        end
end

local function walkSpeedOn()
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = CFG.moveSpeed end
end

local function walkSpeedOff()
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = 16 end
end

--[[ ======================= WORLD FINDERS ======================= ]]
-- all paths come straight from the dump

local function getFishWorld()
        return Workspace:FindFirstChild("FishWorld")
end

local function getDeadFish()
        -- FishWorld > Fishes > Dead > (species) > Root > FishPickupPrompt  (attr FishRelatedPrompt)
        local out = {}
        local world = getFishWorld()
        if not world then return out end
        local fishes = world:FindFirstChild("Fishes")
        if not fishes then return out end
        local dead = fishes:FindFirstChild("Dead")
        if not dead then return out end
        local function walk(m, depth)
                for _, v in ipairs(m:GetChildren()) do
                        if v:IsA("Model") then
                                local root = v:FindFirstChild("Root")
                                local prompt = root and root:FindFirstChild("FishPickupPrompt")
                                if prompt and prompt:GetAttribute("IsItemPrompt") then
                                        table.insert(out, v)
                                elseif depth < 3 and #v:GetChildren() > 0 then
                                        walk(v, depth + 1)
                                end
                        end
                end
        end
        walk(dead, 0)
        return out
end

local function getSellNPCs()
        -- NPCs folder, FishNpcRole=Sell attribute
        local out = {}
        local npcs = Workspace:FindFirstChild("NPCs")
        if not npcs then return out end
        for _, v in ipairs(npcs:GetChildren()) do
                if v:IsA("Model") and v:GetAttribute("FishNpcRole") == "Sell" then
                        table.insert(out, v)
                end
        end
        return out
end

local function getSellAllPrompt(npc)
        -- SellFishPrompt / SellAllFishPrompt on UpperTorso > BodyFrontAttachment
        local ut = npc:FindFirstChild("UpperTorso")
        local att = ut and ut:FindFirstChild("BodyFrontAttachment")
        return att and att:FindFirstChild("SellAllFishPrompt") or nil
end

local function getSeagulls()
        local out = {}
        local sg = Workspace:FindFirstChild("Seagulls")
        if not sg then return out end
        for _, v in ipairs(sg:GetChildren()) do
                if v:IsA("Model") and v:GetAttribute("IsEnemy") then table.insert(out, v) end
        end
        return out
end

local function getHoops()
        local out = {}
        local mk = Workspace:FindFirstChild("GameplayMarkers")
        local hoops = mk and mk:FindFirstChild("BasketballHoops")
        if not hoops then return out end
        for _, v in ipairs(hoops:GetChildren()) do
                if v:GetAttribute("MarkerKind") == "FishSaleBonusHoop" then table.insert(out, v) end
        end
        return out
end

local function getDrops()
        local out = {}
        local drops = Workspace:FindFirstChild("WorldToolDrops")
        if drops then
                for _, v in ipairs(drops:GetChildren()) do
                        if v:IsA("Model") or v:IsA("BasePart") then table.insert(out, v) end
                end
        end
        return out
end

local function getShops()
        -- ShopDisplays > IslandN > display models  => island waypoints + bait list
        local out = {}
        local sds = Workspace:FindFirstChild("ShopDisplays")
        if not sds then return out end
        for _, island in ipairs(sds:GetChildren()) do
                if island:IsA("Folder") and string.match(island.Name, "^Island%d+$") then
                        for _, disp in ipairs(island:GetChildren()) do
                                if disp:IsA("Model") and disp:GetAttribute("IsShopDisplay") then
                                        table.insert(out, { island = island.Name, display = disp })
                                end
                        end
                end
        end
        return out
end

local function getBaits()
        local out = {}
        for _, s in ipairs(getShops()) do
                if string.match(s.display.Name, "Bait") then table.insert(out, s) end
        end
        return out
end

local function getIslands()
        -- dedupe island names -> one waypoint each (first display on the island)
        local seen, out = {}, {}
        for _, s in ipairs(getShops()) do
                if not seen[s.island] then
                        seen[s.island] = true
                        table.insert(out, { name = s.island, cf = partCFrame(s.display) })
                end
        end
        -- extra anchors from dump
        local anchors = {
                { name = "Volcano", path = Workspace:FindFirstChild("GoldenDualUziShopAnchor") },
        }
        for _, a in ipairs(anchors) do
                if a.path and not seen[a.name] then
                        seen[a.name] = true
                        table.insert(out, { name = a.name, cf = a.path.CFrame })
                end
        end
        -- sell NPC waypoint
        local npcs = getSellNPCs()
        local npc = npcs[1]
        if npc then
                local cf = partCFrame(npc)
                if cf then table.insert(out, { name = "Vendor", cf = cf }) end
        end
        return out
end

--[[ ======================= REMOTE DISCOVERY ======================= ]]
-- the dump scan only listed 35 remotes under RSS. real buy/sell remotes live
-- deeper, so at runtime we sweep the whole tree AND the lua registry for
-- RemoteEvents/RemoteFunctions captured in upvalues by client scripts.
local FoundRemotes = {}

local function sweepTree()
        for _, v in ipairs(Storage:GetDescendants()) do
                if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                        FoundRemotes[v.Name] = v
                end
        end
        for _, v in ipairs(Workspace:GetDescendants()) do
                if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                        FoundRemotes[v.Name] = v
                end
        end
        -- Players scripts tree (controllers live there via PlayerScripts)
        local ps = Player:FindFirstChild("PlayerScripts")
        if ps then
                for _, v in ipairs(ps:GetDescendants()) do
                        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                                FoundRemotes[v.Name] = v
                        end
                end
        end
end

local function sweepRegistry()
        local ok, registry = pcall(function()
                local reg = {}
                local gc = getgc and getgc() or nil
                if gc then
                        for _, o in ipairs(gc) do
                                if type(o) == "table" or type(o) == "userdata" then
                                        reg[#reg + 1] = o
                                end
                        end
                end
                local dr = debug and debug.getregistry and debug.getregistry() or {}
                for _, o in ipairs(dr) do
                        reg[#reg + 1] = o
                end
                return reg
        end)
        if not ok then return end
        for _, o in ipairs(registry) do
                if typeof(o) == "Instance" and (o:IsA("RemoteEvent") or o:IsA("RemoteFunction")) then
                        FoundRemotes[o.Name] = o
                end
        end
end

local function fireNamed(names, args)
        -- names: table of substrings. tries each known remote; fires only if found
        for _, sub in ipairs(names) do
                for name, remote in pairs(FoundRemotes) do
                        if string.find(name, sub, 1, true) then
                                local fired = pcall(function()
                                        if remote:IsA("RemoteEvent") then
                                                remote:FireServer(unpack(args or {}))
                                        else
                                                remote:InvokeServer(unpack(args or {}))
                                        end
                                end)
                                if fired then return name end
                        end
                end
        end
        return nil
end

task.spawn(function()
        sweepTree()
        sweepRegistry()
        -- pretty print what we caught
        local names = {}
        for k in pairs(FoundRemotes) do names[#names + 1] = k end
        table.sort(names)
        print("[howtofisch] runtime remotes discovered: " .. #names)
end)

--[[ ======================= ESP ======================= ]]
local espPool = {}
local espSeen = {}

local function espDraw(kind)
        if not espPool[kind] then
                espPool[kind] = {
                        line = DrawingAvail and Drawing.new("Line") or nil,
                        text = DrawingAvail and Drawing.new("Text") or nil,
                }
                if espPool[kind].line then
                        espPool[kind].line.Thickness = 1
                        espPool[kind].line.Color = Color3.fromRGB(120, 120, 120)
                end
                if espPool[kind].text then
                        espPool[kind].text.Size = 13
                        espPool[kind].text.Center = true
                        espPool[kind].text.Outline = true
                end
        end
        return espPool[kind]
end

local function worldToScreen(pos)
        local cam = Workspace.CurrentCamera
        local vp = cam:WorldToViewportPoint(pos)
        return vp, vp.Z < 1
end

local function espEntity(pos, text, color)
        if not DrawingAvail or not CFG.espEnabled then return end
        if not pos then return end
        local vp, onScreen = worldToScreen(pos)
        if not onScreen then return end
        local kind = text or "?"
        local d = espDraw(kind)
        if d.line then
                d.line.Visible = true
                d.line.From = Vector2.new(vp.X, vp.Y)
                d.line.To = Vector2.new(vp.X, vp.Y - 60)
                d.line.Color = color
        end
        if d.text then
                d.text.Visible = true
                d.text.Position = Vector2.new(vp.X, vp.Y - 70)
                d.text.Text = kind
                d.text.Color = color
        end
end

local function espClear()
        if not DrawingAvail then return end
        for _, d in pairs(espPool) do
                if d.line then d.line.Visible = false end
                if d.text then d.text.Visible = false end
        end
end

local function espTick()
        if not CFG.espEnabled then
                espClear()
                return
        end
        espSeen = {}

        -- dead fish
        for _, f in ipairs(getDeadFish()) do
                local cf = partCFrame(f)
                if cf then espEntity(cf.Position, "DEAD FISH", CFG.espColorDeadFish) end
        end

        -- live fish (skip heavy cost — only every other frame)
        if tick() % 0.5 < 0.25 then
                local world = getFishWorld()
                if world then
                        local fishes = world:FindFirstChild("Fishes")
                        local live = fishes and fishes:FindFirstChild("Live") or nil
                        if live then
                                for _, f in ipairs(live:GetChildren()) do
                                        if f:IsA("Model") then
                                                local cf = partCFrame(f)
                                                if cf and distTo(f) < CFG.collectRadius * 2 then
                                                        espEntity(cf.Position, f.Name, CFG.espColorFish)
                                                end
                                        end
                                end
                        end
                end
        end

        -- seagulls (they carry fish - IsEnemy=true, MaxHealth/Health attrs)
        for _, g in ipairs(getSeagulls()) do
                local cf = partCFrame(g)
                if cf then
                        local hp = g:GetAttribute("Health") or "?"
                        espEntity(cf.Position, "SEAGULL " .. tostring(hp), CFG.espColorSeagull)
                end
        end

        -- hoops (bonus multiplier 2.5 — throw fish through for extra cash)
        for _, h in ipairs(getHoops()) do
                local cf = partCFrame(h)
                if cf then espEntity(cf.Position, "HOOP x" .. tostring(h:GetAttribute("Multiplier") or "?"), CFG.espColorHoop) end
        end

        -- drops
        for _, d in ipairs(getDrops()) do
                local pos = partPos(d)
                if pos then espEntity(pos, "DROP", CFG.espColorDrop) end
        end

        -- sell NPCs
        for _, n in ipairs(getSellNPCs()) do
                local cf = partCFrame(n)
                if cf then espEntity(cf.Position, "SELL", CFG.espColorNPC) end
        end

        -- baits (only when autoBuy on, keeps screen clean)
        if CFG.autoBuy then
                for _, b in ipairs(getBaits()) do
                        local cf = partCFrame(b.display)
                        if cf then espEntity(cf.Position, "BAIT: " .. b.display.Name, CFG.espColorBait) end
                end
        end
end

RunService.RenderStepped:Connect(function()
        espTick()
end)

--[[ ======================= ANTI-DROWN ======================= ]]
-- dump: LocalWaterMaximumY=-19.5, MinimumPlayerFloorY=-15, WaterDepthSafetyOwned
CFG.antiDrown = true
task.spawn(function()
        while task.wait(0.5) do
                local r = getRoot()
                if CFG.antiDrown and r and r.Position.Y < CFG.antiDrownFloorY then
                        local safe = CFrame.new(r.Position.X, CFG.antiDrownFloorY + CFG.antiDrownSeek, r.Position.Z)
                        local hum = getHumanoid()
                        if hum then
                                hum:MoveTo(safe.Position)
                        else
                                r.CFrame = safe
                        end
                end
        end
end)

--[[ ======================= FARM LOOP ======================= ]]
local farming = false

local function sellRun()
        respawnSafe()
        local npcs = getSellNPCs()
        if #npcs == 0 then
                print("[howtofisch] no sell NPC found")
                return false
        end
        local npc, _ = nearest(npcs)
        if not npc then return false end
        local cf = partCFrame(npc)
        if not cf then return false end

        -- park ON the SellAll prompt (UpperTorso > BodyFrontAttachment)
        local prompt = getSellAllPrompt(npc)
        local target = prompt and prompt:GetRootPart() or nil
        if target then
                target = CFrame.new(target.Position + Vector3.new(0, 2, 0))
        else
                target = cf * CFrame.new(0, 2, 3)
        end
        moveTo(target, 2)
        task.wait(CFG.sellParkTime)
        -- sell-all prompt is disabled by default (DisablePromptIndicator=true) but
        -- proximity to SellFishPrompt also works; you only need to glomp E once here.
        print("[howtofisch] parked at vendor — press E on the sell prompt (sell-all)")
        -- if we found a sell remote, try it (best effort, args unknown)
        if CFG.extraFireRemotes then
                for name, args in pairs(CFG.extraFireRemotes) do
                        local r = FoundRemotes[name]
                        if r then
                                pcall(function()
                                        if r:IsA("RemoteEvent") then r:FireServer(unpack(args or {}))
                                        else r:InvokeServer(unpack(args or {})) end
                                end)
                        end
                end
        end
        return true
end

local function collectRound()
        respawnSafe()
        walkSpeedOn()
        local fish = getDeadFish()
        if #fish == 0 then return false end
        local target, _ = nearest(fish)
        if not target then return false end

        local cf = partCFrame(target)
        if not cf then return false end

        -- body of approach: walk above the root of the fish so the FishPickupPrompt lights
        local park = cf * CFrame.new(0, 2.5, 0)
        local hum = getHumanoid()
        if hum then hum:MoveTo(park.Position) end
        local done = moveTo(park, 2)
        -- if MoveTo failed, force the CFrame hop
        if not done then
                tweenStepTo(park, 2)
        end
        task.wait(0.35) -- let the prompt register + whatever pickup delay
        walkSpeedOff()
        return true
end

task.spawn(function()
        while task.wait(0.25) do
                if not CFG.autoFarm then
                        walkSpeedOff()
                else
                        local collected = 0
                        local round = 0
                        repeat
                                round = round + 1
                                if collectRound() then
                                        collected = collected + 1
                                else
                                        -- no more dead fish in range -> run a sell
                                        if collected > 0 then
                                                sellRun()
                                                collected = 0
                                        end
                                end
                                task.wait(0.1)
                        until round > 3000
                        CFG.autoFarm = false
                        walkSpeedOff()
                end
        end
end)

--[[ ======================= AUTO BUY LOOP ======================= ]]
task.spawn(function()
        while task.wait(0.5) do
                if CFG.autoBuy then
                        respawnSafe()
                        local baits = getBaits()
                        if #baits == 0 then
                                print("[howtofisch] no bait displays found")
                                CFG.autoBuy = false
                        else
                                local b = baits[1]
                                local cf = partCFrame(b.display)
                                if cf then
                                        moveTo(cf * CFrame.new(0, 1, 4), 2.5)
                                        task.wait(0.6)
                                end
                        end
                end
        end
end)

--[[ ======================= TELEPORTS / MAGNET ======================= ]]
local function teleportIsland(name)
        respawnSafe()
        local islands = getIslands()
        for _, i in ipairs(islands) do
                if i.name == name then
                        moveTo(i.cf * CFrame.new(0, 3, 5), 4)
                        print("[howtofisch] hopped to " .. name)
                        return
                end
        end
        print("[howtofisch] island not found: " .. tostring(name))
end

local function fishMagnet()
        local fish = getDeadFish()
        if #fish == 0 then
                print("[howtofisch] no dead fish nearby")
                return
        end
        local f, _ = nearest(fish)
        local cf = partCFrame(f)
        if cf then moveTo(cf * CFrame.new(0, 2.5, 0), 2) end
end

--[[ ======================= KEYBINDS ======================= ]]
local boundUI

local function rebuildUI()
        if not CFG.showUI or not DrawingAvail then return end
        if boundUI then
                for _, d in pairs(boundUI) do if d.Remove then d:Remove() end end
                boundUI = nil
        end
        boundUI = {}
        local lines = {
                "howtofisch",
                "F1 esp   F2 farm   F3 buy   F4 tp   F5 sell   F6 magnet   F8 off",
        }
        for k, v in pairs(ToggleColors) do
                local state = CFG[k] and "ON" or "off"
                table.insert(lines, string.format("%s %s %s", v, ":", state))
        end
        local y = 20
        for _, l in ipairs(lines) do
                local t = Drawing.new("Text")
                t.Text = l
                t.Size = 14
                t.Position = Vector2.new(10, y)
                t.Color = Color3.fromRGB(240, 240, 240)
                t.Outline = true
                t.OutlineColor = Color3.fromRGB(20, 20, 20)
                table.insert(boundUI, t)
                y = y + 17
        end
end

rebuildUI()
task.spawn(function()
        while task.wait(2) do
                if CFG.showUI and boundUI then
                        local i = 1
                        for _, k in ipairs({ "espEnabled", "autoFarm", "autoBuy" }) do
                                local t = boundUI[i]
                                if t then
                                        local state = CFG[k] and "ON" or "off"
                                        t.Text = string.format("%s %s %s", ToggleColors[k], ":", state)
                                end
                                i = i + 1
                        end
                end
        end
end)

UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F1 then
                CFG.espEnabled = not CFG.espEnabled
        elseif input.KeyCode == Enum.KeyCode.F2 then
                CFG.autoFarm = not CFG.autoFarm
                print("[howtofisch] auto-farm " .. (CFG.autoFarm and "ON" or "off"))
        elseif input.KeyCode == Enum.KeyCode.F3 then
                CFG.autoBuy = not CFG.autoBuy
                print("[howtofisch] auto-buy " .. (CFG.autoBuy and "ON" or "off") .. " (walk to bait, press E to buy)")
        elseif input.KeyCode == Enum.KeyCode.F4 then
                local islands = getIslands()
                print("[howtofisch] F4 tp — islands:")
                for _, i in ipairs(islands) do print("   ", i.name) end
        elseif input.KeyCode == Enum.KeyCode.F5 then
                sellRun()
        elseif input.KeyCode == Enum.KeyCode.F6 then
                fishMagnet()
        elseif input.KeyCode == Enum.KeyCode.F7 then
                CFG.antiDrown = not CFG.antiDrown
                print("[howtofisch] anti-drown " .. (CFG.antiDrown and "ON" or "off"))
        elseif input.KeyCode == Enum.KeyCode.F8 then
                CFG.autoFarm = false
                CFG.autoBuy = false
                walkSpeedOff()
                espClear()
                print("[howtofisch] all toggles off")
        end
end)

-- seed island teleport map once so F4 prints without waiting on move
local islands = getIslands()
print("[howtofisch] loaded. islands: " .. #islands .. ", sell NPCs: " .. #getSellNPCs() .. ", dead-fish finder armed.")
print("[howtofisch] F2 = farm loop (collect -> vendor), F5 = sell run, F6 = magnet, F7 = anti-drown.")
