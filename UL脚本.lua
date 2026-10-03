--============================================================
--  UL 脚本 · WindUI 版本
--  目标环境：执行器（Executor）
--============================================================

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local PhysicsService    = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--============================================================
-- 加载 WindUI
--============================================================
local WindUI
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(
            "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
        ))()
    end)
    if ok and type(result) == "table" then
        WindUI = result
        print("[UL] WindUI 已从在线源加载")
    else
        local mod = ReplicatedStorage:FindFirstChild("WindUI")
        if mod and mod:IsA("ModuleScript") then
            WindUI = require(mod)
            print("[UL] WindUI 已从 ReplicatedStorage 加载")
        else
            error("[UL] 无法加载 WindUI：" .. tostring(result))
        end
    end
end

--============================================================
-- 公告配置
--============================================================
local ANNOUNCE = {
    Title   = "UL 脚本 · 阿尔法版本",
    GroupID = "未设定",
    Lines   = {
        "大家好，这是 UL 脚本阿尔法版本。",
        "这里有 bug 可以反馈，只需要加入群号：（未设定）",
        "自瞄已完善，支持视角自由拉近拉远。",
        "新增自瞄目标选择，可指定玩家 / NPC 锁定。",
        "新增人物无碰撞，别人碰不到你。",
        "优化自瞄性能，减少卡顿。",
    },
    Titles  = {
        "欢迎",
        "反馈渠道",
        "功能更新",
        "新增功能",
        "新增功能",
        "性能优化",
    },
}

--============================================================
-- 状态
--============================================================
local State = {
    Speed          = 16,
    Jump           = 50,
    NightVision    = false,
    ESP            = false,
    Aimbot         = false,
    Noclip         = false,
    Stealth        = false,
    NoPlayerCollide = false,
}

--============================================================
-- 隐身
--============================================================
local stealthRemote = ReplicatedStorage:FindFirstChild("UL_Stealth")
if not stealthRemote then
    stealthRemote = ReplicatedStorage:WaitForChild("UL_Stealth", 3)
end
if not stealthRemote then
    warn("[UL] 未找到 UL_Stealth RemoteEvent，隐身仅本地半透明")
else
    print("[UL] UL_Stealth 已就绪")
end

local stealthConn = nil
local stealthSavedDecals = {}
local stealthSavedParts  = {}

local function applyStealthLocalTick()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if stealthSavedParts[part] == nil then
                stealthSavedParts[part] = part.LocalTransparencyModifier
            end
            part.LocalTransparencyModifier = 1
        elseif part:IsA("Decal") then
            if stealthSavedDecals[part] == nil then
                stealthSavedDecals[part] = part.Transparency
            end
            part.Transparency = 1
        end
    end
end

local function restoreStealthLocal()
    for part, v in pairs(stealthSavedParts) do
        if part.Parent then
            part.LocalTransparencyModifier = v
        end
    end
    for dec, v in pairs(stealthSavedDecals) do
        if dec.Parent then
            dec.Transparency = v
        end
    end
    stealthSavedParts  = {}
    stealthSavedDecals = {}
end

local function setStealth(on)
    State.Stealth = on
    if stealthRemote then
        pcall(function() stealthRemote:FireServer(on) end)
    end
    if on then
        if stealthConn then stealthConn:Disconnect() end
        stealthConn = RunService.Stepped:Connect(applyStealthLocalTick)
        applyStealthLocalTick()
    else
        if stealthConn then
            stealthConn:Disconnect()
            stealthConn = nil
        end
        restoreStealthLocal()
    end
end

--============================================================
-- 夜视
--============================================================
local nvSaved, nvCC = nil, nil

local function setNightVision(on)
    if on then
        if not nvSaved then
            nvSaved = {
                Brightness     = Lighting.Brightness,
                Ambient        = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                FogEnd         = Lighting.FogEnd,
                FogStart       = Lighting.FogStart,
                GlobalShadows  = Lighting.GlobalShadows,
            }
        end
        Lighting.Brightness     = 3
        Lighting.Ambient        = Color3.fromRGB(190, 215, 190)
        Lighting.OutdoorAmbient = Color3.fromRGB(160, 190, 160)
        Lighting.FogEnd         = 1e6
        Lighting.FogStart       = 0
        Lighting.GlobalShadows  = false

        if not nvCC then
            nvCC = Instance.new("ColorCorrectionEffect")
            nvCC.Name       = "UL_NV"
            nvCC.TintColor  = Color3.fromRGB(180, 255, 190)
            nvCC.Brightness = 0.15
            nvCC.Contrast   = 0.12
            nvCC.Saturation = -0.1
            nvCC.Parent     = Lighting
        end
    else
        if nvSaved then
            Lighting.Brightness     = nvSaved.Brightness
            Lighting.Ambient        = nvSaved.Ambient
            Lighting.OutdoorAmbient = nvSaved.OutdoorAmbient
            Lighting.FogEnd         = nvSaved.FogEnd
            Lighting.FogStart       = nvSaved.FogStart
            Lighting.GlobalShadows  = nvSaved.GlobalShadows
            nvSaved = nil
        end
        if nvCC then
            nvCC:Destroy()
            nvCC = nil
        end
    end
end

--============================================================
-- ESP
--============================================================
local espHighlights = {}
local espColor = Color3.fromRGB(90, 170, 255)

local function addESP(char)
    if not char or espHighlights[char] then return end
    local hl = Instance.new("Highlight")
    hl.Name = "UL_ESP"
    hl.FillColor = espColor
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char
    espHighlights[char] = hl
end

local function clearESP()
    for char, hl in pairs(espHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    espHighlights = {}
end

local function refreshESP()
    if not State.ESP then
        clearESP()
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            addESP(plr.Character)
        end
    end
    for char, hl in pairs(espHighlights) do
        if not char.Parent then
            if hl and hl.Parent then hl:Destroy() end
            espHighlights[char] = nil
        end
    end
end

--============================================================
-- 穿墙
--============================================================
local noclipConn  = nil
local noclipSaved = setmetatable({}, { __mode = "k" })

local function applyNoclipTick()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            noclipSaved[part] = true
            part.CanCollide = false
        end
    end
end

local function restoreNoclip()
    for part in pairs(noclipSaved) do
        if part.Parent then
            part.CanCollide = true
        end
    end
    noclipSaved = setmetatable({}, { __mode = "k" })
end

local function setNoclip(on)
    State.Noclip = on
    if on then
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = RunService.Stepped:Connect(applyNoclipTick)
    else
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        restoreNoclip()
    end
end

--============================================================
-- 人物无碰撞
--============================================================
local SELF_GROUP  = "UL_SelfGroup"
local OTHER_GROUP = "UL_OtherGroup"
local noPlayerCollideConn = nil
local collisionGroupsReady = false

local function initCollisionGroups()
    if collisionGroupsReady then return true end
    local ok1 = pcall(function() PhysicsService:RegisterCollisionGroup(SELF_GROUP) end)
    local ok2 = pcall(function() PhysicsService:RegisterCollisionGroup(OTHER_GROUP) end)
    pcall(function()
        PhysicsService:CollisionGroupSetCollidable(SELF_GROUP, OTHER_GROUP, false)
    end)
    collisionGroupsReady = true
    return ok1 or ok2
end

local function setCharGroup(char, group)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CollisionGroup = group end)
        end
    end
end

local function applyNoPlayerCollide()
    setCharGroup(player.Character, SELF_GROUP)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            setCharGroup(plr.Character, OTHER_GROUP)
        end
    end
end

local function setNoPlayerCollide(on)
    State.NoPlayerCollide = on
    if on then
        initCollisionGroups()
        applyNoPlayerCollide()
        if noPlayerCollideConn then noPlayerCollideConn:Disconnect() end
        noPlayerCollideConn = RunService.Stepped:Connect(applyNoPlayerCollide)
    else
        if noPlayerCollideConn then
            noPlayerCollideConn:Disconnect()
            noPlayerCollideConn = nil
        end
        -- 还原
        setCharGroup(player.Character, "Default")
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                setCharGroup(plr.Character, "Default")
            end
        end
    end
end

--============================================================
-- 自瞄
--============================================================
local AIM = {
    ConeRadius     = 260,
    MaxDistance    = 250,
    Smooth         = 10,
    HeadOffset     = 1.6,
    CamDistance    = 12,
    CamMinDistance = 3,
    CamMaxDistance = 120,
    CamHeight      = 2,
    Prediction     = 0.15,
}

local AIM_TARGET_AUTO = "自动（最近目标）"
local AIM_Selected    = AIM_TARGET_AUTO
local AIM_LockNPC     = true

local npcList  = {}
local npcByKey = {}
local NPC_MAX  = 20    -- [FIX] 40 → 20，减轻每帧检测压力

local function getPartFromChar(char)
    if not char then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getTargetPart(plr)
    return getPartFromChar(plr.Character)
end

-- [FIX] NPC 扫描：异步分批，不再卡主线程
local function scanNPCsAsync(onDone)
    task.spawn(function()
        local seen     = {}
        local newList  = {}
        local newByKey = {}
        local count    = 0
        local iter     = 0

        local queue = { workspace }
        local head  = 1

        while head <= #queue and count < NPC_MAX do
            iter = iter + 1
            if iter % 60 == 0 then
                task.wait()   -- 分批让出，避免长卡
            end

            local parent = queue[head]
            head = head + 1
            if parent and parent.Parent then
                local children = parent:GetChildren()
                for _, obj in ipairs(children) do
                    if count >= NPC_MAX then break end

                    if obj:IsA("Humanoid") and obj.Health > 0 then
                        local model = obj.Parent
                        if model and model:IsA("Model") and not seen[model] then
                            seen[model] = true
                            if not Players:GetPlayerFromCharacter(model) then
                                local baseKey  = "NPC: " .. model.Name
                                local finalKey = baseKey
                                local i = 1
                                while newByKey[finalKey] do
                                    i = i + 1
                                    finalKey = baseKey .. " #" .. i
                                end
                                local entry = { model = model, humanoid = obj, key = finalKey }
                                table.insert(newList, entry)
                                newByKey[finalKey] = entry
                                count = count + 1
                            end
                        end
                    elseif obj:IsA("Model") or obj:IsA("Folder") then
                        table.insert(queue, obj)
                    end
                end
            end
        end

        npcList  = newList
        npcByKey = newByKey
        if onDone then onDone() end
    end)
end

local function getSelectedTarget()
    if AIM_Selected == AIM_TARGET_AUTO then return nil end

    local plr = Players:FindFirstChild(AIM_Selected)
    if plr and plr:IsA("Player") then
        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        local tgt = getTargetPart(plr)
        if tgt and hum and hum.Health > 0 then
            return plr, tgt
        end
        return nil
    end

    local entry = npcByKey[AIM_Selected]
    if entry and entry.model and entry.model.Parent then
        local hum = entry.humanoid
        local tgt = getPartFromChar(entry.model)
        if tgt and hum and hum.Health > 0 then
            return entry.model, tgt
        end
    end
    return nil
end

local function findAimTarget()
    local pickedKey, pickedPart = getSelectedTarget()
    if pickedPart then return pickedKey, pickedPart end

    local char = player.Character
    if not char then return nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local bestKey, bestPart, bestScore = nil, nil, math.huge
    local camPos = camera.CFrame.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local tgt = getTargetPart(plr)
            if tgt and hum and hum.Health > 0 then
                local worldDist = (tgt.Position - camPos).Magnitude
                if worldDist <= AIM.MaxDistance then
                    local sp, onScreen = camera:WorldToViewportPoint(tgt.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= AIM.ConeRadius and d < bestScore then
                            bestScore = d
                            bestKey   = plr
                            bestPart  = tgt
                        end
                    end
                end
            end
        end
    end

    if AIM_LockNPC then
        for _, entry in ipairs(npcList) do
            local model = entry.model
            if model and model.Parent then
                local hum = entry.humanoid
                local tgt = getPartFromChar(model)
                if tgt and hum and hum.Health > 0 then
                    local worldDist = (tgt.Position - camPos).Magnitude
                    if worldDist <= AIM.MaxDistance then
                        local sp, onScreen = camera:WorldToViewportPoint(tgt.Position)
                        if onScreen then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if d <= AIM.ConeRadius and d < bestScore then
                                bestScore = d
                                bestKey   = model
                                bestPart  = tgt
                            end
                        end
                    end
                end
            end
        end
    end

    return bestKey, bestPart
end

-- 目标位置平滑 + 速度预测
local trackData = setmetatable({}, { __mode = "k" })

local function getAimPosition(key, part)
    local now  = os.clock()
    local data = trackData[key]

    if not data then
        trackData[key] = {
            lastPos   = part.Position,
            velocity  = Vector3.zero,
            smoothPos = part.Position,
            lastTime  = now,
        }
        return part.Position
    end

    local elapsed = now - data.lastTime
    if elapsed > 0.001 then
        local v = (part.Position - data.lastPos) / elapsed
        data.velocity = data.velocity:Lerp(v, 0.35)
        data.lastPos  = part.Position
        data.lastTime = now
    end

    -- [FIX] 位置低通滤波，抑制抖动传给相机
    data.smoothPos = data.smoothPos:Lerp(part.Position, 0.5)

    if AIM.Prediction <= 0 then
        return data.smoothPos
    end
    return data.smoothPos + data.velocity * AIM.Prediction
end

UserInputService.InputChanged:Connect(function(input)
    if not State.Aimbot then return end
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        AIM.CamDistance = math.clamp(
            AIM.CamDistance - input.Position.Z * 3,
            AIM.CamMinDistance,
            AIM.CamMaxDistance
        )
    end
end)

--============================================================
-- 创建窗口
--============================================================
local Window = WindUI:CreateWindow({
    Title = "UL 脚本",
    Icon = "zap",
    Author = "阿尔法版本",
    Folder = "ULScript",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
    User = { Enabled = true, Callback = function() end },
    SideBarWidth = 180,
    HasOutline = true,
})

WindUI:Notify({
    Title = "UL 脚本",
    Content = "加载完成，欢迎使用阿尔法版本。",
    Duration = 5,
    Icon = "check",
})

--============================================================
-- 主要 Tab
--============================================================
local MainTab = Window:Tab({ Title = "主要", Icon = "gamepad-2" })

MainTab:Section({ Title = "玩家属性", Opened = true })

MainTab:Slider({
    Title = "移动速度",
    Desc  = "调整 WalkSpeed",
    Value = { Min = 8, Max = 300, Default = State.Speed },
    Step = 1,
    Callback = function(v)
        State.Speed = v
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})

MainTab:Slider({
    Title = "跳跃高度",
    Desc  = "调整 JumpPower",
    Value = { Min = 30, Max = 500, Default = State.Jump },
    Step = 1,
    Callback = function(v)
        State.Jump = v
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v
        end
    end,
})

MainTab:Section({ Title = "视觉效果", Opened = true })

MainTab:Toggle({
    Title = "夜视",
    Desc  = "提亮场景、去雾",
    Value = false,
    Callback = function(v)
        State.NightVision = v
        setNightVision(v)
    end,
})

MainTab:Toggle({
    Title = "ESP 透视",
    Desc  = "高亮其他玩家（隔墙可见）",
    Value = false,
    Callback = function(v)
        State.ESP = v
        refreshESP()
    end,
})

--============================================================
-- 战斗
--============================================================
MainTab:Section({ Title = "战斗", Opened = true })

local prevCameraType = nil

MainTab:Toggle({
    Title = "自瞄（视角辅助）",
    Desc  = "相机平滑转向最近目标，开启后可用滚轮拉近拉远",
    Value = false,
    Callback = function(v)
        State.Aimbot = v
        if v then
            prevCameraType = camera.CameraType
            camera.CameraType = Enum.CameraType.Scriptable
        else
            camera.CameraType = prevCameraType or Enum.CameraType.Custom
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then camera.CameraSubject = hum end
        end
    end,
})

MainTab:Slider({
    Title = "自瞄相机距离",
    Desc  = "相机离角色的距离（也可以用滚轮调）",
    Value = { Min = AIM.CamMinDistance, Max = AIM.CamMaxDistance, Default = AIM.CamDistance },
    Step = 1,
    Callback = function(v) AIM.CamDistance = v end,
})

MainTab:Slider({
    Title = "自瞄平滑度",
    Desc  = "越大相机跟得越快，越小越丝滑",
    Value = { Min = 1, Max = 30, Default = AIM.Smooth },
    Step = 1,
    Callback = function(v) AIM.Smooth = v end,
})

MainTab:Slider({
    Title = "预测值",
    Desc  = "预测目标移动的提前量（秒），0 = 不预测；打移动靶调大",
    Value = { Min = 0, Max = 1, Default = AIM.Prediction },
    Step = 0.05,
    Callback = function(v) AIM.Prediction = v end,
})

MainTab:Toggle({
    Title = "自动锁定 NPC",
    Desc  = "开启后「自动」模式也会锁 NPC；关闭只锁玩家",
    Value = true,
    Callback = function(v) AIM_LockNPC = v end,
})

local function getTargetList()
    local list = { AIM_TARGET_AUTO }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            table.insert(list, plr.Name)
        end
    end
    for _, entry in ipairs(npcList) do
        table.insert(list, entry.key)
    end
    table.sort(list, function(a, b)
        if a == AIM_TARGET_AUTO then return true end
        if b == AIM_TARGET_AUTO then return false end
        return a < b
    end)
    return list
end

local function listEqual(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local lastDropdownValue = AIM_TARGET_AUTO
local suppressNotify    = false
local lastTargetListCache = nil

local PlayerDropdown = MainTab:Dropdown({
    Title  = "选择自瞄目标",
    Desc   = "自动 = 锁最近目标；选玩家/NPC = 只锁他",
    Values = getTargetList(),
    Value  = AIM_TARGET_AUTO,
    Callback = function(v)
        AIM_Selected = v
        if suppressNotify then return end
        if v == lastDropdownValue then return end
        lastDropdownValue = v
        WindUI:Notify({
            Title    = "自瞄目标",
            Content  = (v == AIM_TARGET_AUTO) and "已切换为自动锁定" or ("已锁定：" .. v),
            Duration = 2,
            Icon     = "crosshair",
        })
    end,
})

local function safeRefreshDropdown()
    suppressNotify = true
    pcall(function() PlayerDropdown:Refresh(getTargetList()) end)
    task.defer(function() suppressNotify = false end)
end

local function safeSetDropdown(value)
    lastDropdownValue = value
    suppressNotify = true
    pcall(function() PlayerDropdown:Set(value) end)
    task.defer(function() suppressNotify = false end)
end

local function refreshIfChanged()
    local cur = getTargetList()
    if lastTargetListCache and listEqual(lastTargetListCache, cur) then return end
    lastTargetListCache = cur
    safeRefreshDropdown()
end

Players.PlayerAdded:Connect(function(plr)
    task.wait(0.1)
    refreshIfChanged()
    plr.CharacterAdded:Connect(function()
        if State.ESP then refreshESP() end
        task.wait(0.1)
        refreshIfChanged()
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    task.wait(0.1)
    trackData[plr] = nil
    if AIM_Selected == plr.Name then
        AIM_Selected = AIM_TARGET_AUTO
        safeSetDropdown(AIM_TARGET_AUTO)
    end
    refreshIfChanged()
end)

--============================================================
-- 移动 / 隐身
--============================================================
MainTab:Section({ Title = "移动 / 隐身", Opened = true })

MainTab:Toggle({
    Title = "穿墙",
    Desc  = "关闭角色部件碰撞",
    Value = false,
    Callback = function(v) setNoclip(v) end,
})

-- [NEW] 人物无碰撞
MainTab:Toggle({
    Title = "人物无碰撞",
    Desc  = "无碰撞",
    Value = false,
    Callback = function(v) setNoPlayerCollide(v) end,
})

MainTab:Toggle({
    Title = "隐身",
    Desc  = "别人看不到你（需服务端支持 UL_Stealth）",
    Value = false,
    Callback = function(v) setStealth(v) end,
})

--============================================================
-- 设置 Tab
--============================================================
local SettingsTab = Window:Tab({ Title = "设置", Icon = "settings" })

SettingsTab:Section({ Title = "主题", Opened = true })

SettingsTab:Dropdown({
    Title = "主题色",
    Desc  = "选择整个界面的主题",
    Values = {
        "Dark", "Light", "Rose", "Plant", "Red",
        "Indigo", "Sky", "Violet", "Amber", "Emerald",
        "Midnight", "Crimson", "MonokaiPro", "CottonCandy", "Rainbow",
    },
    Value = "Dark",
    Callback = function(v)
        local ok, err = pcall(function() WindUI:SetTheme(v) end)
        if ok then
            WindUI:Notify({
                Title = "主题已切换",
                Content = "当前主题：" .. v,
                Duration = 3,
                Icon = "palette",
            })
        else
            WindUI:Notify({
                Title = "主题切换失败",
                Content = tostring(err),
                Duration = 4,
                Icon = "alert-triangle",
            })
        end
    end,
})

SettingsTab:Section({ Title = "自瞄高级参数", Opened = false })

SettingsTab:Slider({
    Title = "屏幕范围",
    Desc  = "屏幕中心命中半径",
    Value = { Min = 50, Max = 600, Default = AIM.ConeRadius },
    Step = 10,
    Callback = function(v) AIM.ConeRadius = v end,
})

SettingsTab:Slider({
    Title = "最大锁定距离",
    Desc  = "世界坐标最大锁定距离",
    Value = { Min = 50, Max = 800, Default = AIM.MaxDistance },
    Step = 10,
    Callback = function(v) AIM.MaxDistance = v end,
})

SettingsTab:Slider({
    Title = "相机最近距离",
    Desc  = "自瞄相机能贴多近",
    Value = { Min = 1, Max = 20, Default = AIM.CamMinDistance },
    Step = 0.5,
    Callback = function(v)
        AIM.CamMinDistance = v
        AIM.CamDistance = math.clamp(AIM.CamDistance, v, AIM.CamMaxDistance)
    end,
})

SettingsTab:Slider({
    Title = "相机最远距离",
    Desc  = "自瞄相机能拉多远",
    Value = { Min = 20, Max = 800, Default = AIM.CamMaxDistance },
    Step = 10,
    Callback = function(v)
        AIM.CamMaxDistance = v
        AIM.CamDistance = math.clamp(AIM.CamDistance, AIM.CamMinDistance, v)
    end,
})

SettingsTab:Section({ Title = "ESP 颜色", Opened = false })

SettingsTab:Colorpicker({
    Title   = "高亮颜色",
    Default = espColor,
    Callback = function(color)
        espColor = color
        for _, hl in pairs(espHighlights) do
            if hl and hl.Parent then hl.FillColor = color end
        end
    end,
})

--============================================================
-- 公告 Tab
--============================================================
local AnnounceTab = Window:Tab({ Title = "公告", Icon = "megaphone" })

AnnounceTab:Paragraph({
    Title = "✦ " .. ANNOUNCE.Title,
    Desc  = "更新日期：2026年10月3日",
    Image = "sparkles",
})

AnnounceTab:Divider()

for i, line in ipairs(ANNOUNCE.Lines) do
    AnnounceTab:Paragraph({
        Title = tostring(i) .. ". " .. (ANNOUNCE.Titles[i] or "提示"),
        Desc  = line,
    })
end

AnnounceTab:Divider()

AnnounceTab:Paragraph({
    Title = "反馈群号",
    Desc  = ANNOUNCE.GroupID,
    Image = "users",
})

--============================================================
-- 角色应用
--============================================================
local function onCharacter(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = State.Speed
    hum.UseJumpPower = true
    hum.JumpPower = State.Jump

    if State.Stealth then
        task.wait(0.2)
        if stealthRemote then
            pcall(function() stealthRemote:FireServer(true) end)
        end
        applyStealthLocalTick()
        if stealthConn then stealthConn:Disconnect() end
        stealthConn = RunService.Stepped:Connect(applyStealthLocalTick)
    end

    if State.NoPlayerCollide then
        task.wait(0.1)
        setCharGroup(char, SELF_GROUP)
    end
end

if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

--============================================================
-- 循环
--============================================================
local espClock = 0

RunService.RenderStepped:Connect(function(dt)
    if State.ESP then
        espClock = espClock + dt
        if espClock >= 0.4 then
            espClock = 0
            refreshESP()
        end
    end

    if State.Aimbot then
        local char = player.Character
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
        if head then
            local targetKey, targetPart = findAimTarget()

            local focusPos = head.Position + Vector3.new(0, AIM.CamHeight, 0)

            local lookAt
            if targetPart and targetKey then
                local aimPos = getAimPosition(targetKey, targetPart)
                lookAt = aimPos + Vector3.new(0, AIM.HeadOffset, 0)
            else
                lookAt = focusPos + head.CFrame.LookVector * 100
            end

            local dir = lookAt - focusPos
            if dir.Magnitude < 0.01 then
                dir = head.CFrame.LookVector
            else
                dir = dir.Unit
            end

            local camPos = focusPos - dir * AIM.CamDistance
            local desired = CFrame.lookAt(camPos, lookAt)
            -- [FIX] alpha 上限，避免帧率不稳时跳变
            local alpha = math.clamp(dt * AIM.Smooth, 0, 0.35)
            camera.CFrame = camera.CFrame:Lerp(desired, alpha)
        end
    end
end)

-- NPC 扫描循环（异步，不卡主线程）
task.spawn(function()
    task.wait(1)
    while true do
        scanNPCsAsync(function()
            refreshIfChanged()
        end)
        task.wait(1.5)
    end
end)