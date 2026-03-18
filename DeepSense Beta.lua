-- GemiSense | Nursultan Client Style UI
-- Исправлено: Аимбот теперь работает в режиме Toggle (одно нажатие - вкл, второе - выкл).
-- Добавлено: Улучшенный ESP с отображением ников игроков.
-- Добавлено: Kill Aura (10 ударов в секунду, можно бить спиной)
-- Добавлено: Wallbang (стрельба через стены)
-- Добавлено: Misc раздел с Changer и HUD Elements
-- Добавлено: Target HUD с отображением последней цели и головы
-- Добавлено: Target ESP с двумя типами маркеров (частицы и квадрат)
-- Добавлено: Auto Fire Delay слайдер (10-200ms)
-- Добавлено: Защита от тиммейтов
-- Добавлено: РАБОЧИЙ SILENT AIM
-- ИСПРАВЛЕНО: Auto Fire теперь включается по бинду
-- ИСПРАВЛЕНО: Все элементы HUD можно перетаскивать
-- ИСПРАВЛЕНО: Kill Aura работает в любую сторону (даже спиной)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local InsertService = game:GetService("InsertService")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera
local HttpService = game:GetService("HttpService")

-- === ОРИГИНАЛЬНЫЕ ПЕРЕМЕННЫЕ И НАСТРОЙКИ ===
local hitboxSize = 5
local walkspeed = 16
local flySpeed = 50
local noclip = false
local flying = false
local espEnabled = false
local particlesEnabled = false
local targetESPEnabled = false
local targetESPType = "Particles"
local autoFireEnabled = false
local aimbotEnabled = false 
local silentAimEnabled = false
local killAuraEnabled = false
local hudEnabled = true 
local wallbangEnabled = false
local ignoreTeam = true

-- Kill Aura переменные
local killAuraRange = 20
local killAuraDelay = 0.1 -- 10 ударов в секунду
local lastKillAuraTime = 0
local killAuraTarget = nil

-- HUD Elements настройки
local showPlayerInfo = true
local showActiveModules = true
local showWatermark = true
local showTargetHUD = true

-- Позиции HUD элементов (для перетаскивания)
local hudPositions = {
    leftInfo = UDim2.new(0, 10, 0, 10),
    rightModules = UDim2.new(1, -230, 0, 10),
    watermark = UDim2.new(0.5, -100, 0, 20),
    targetHUD = UDim2.new(0, 10, 1, -130)
}

local bhopEnabled = false
local currentBhopSpeed = 16
local bhopBoost = 1 -- Каждый прыжок +1 скорости
local maxBhopSpeed = 150 
local lastJumpTime = 0
local jumpCooldown = 0.2

local flyMode = "Toggle"
local noclipMode = "Toggle"

-- Anti-Aim переменные
local antiAimEnabled = false
local jitterEnabled = false
local pitchMode = "None"
local pitchAngle = 0
local jitterValue = 180
local lastPitchChange = 0
local hitboxPart = "Head" -- для рандомного перемещения хитбокса
local lastHitboxChange = 0

-- Silent Aim переменные
local silentAimTarget = nil
local silentAimFov = 500 -- Увеличено до 500
local originalMouseTarget = nil
local originalMouseHit = nil
local silentAimActiveToggle = false

-- Target ESP переменные
local targetESPParticles = {}
local targetESPSquare = nil
local currentTarget = nil

-- Переменные для Changer
local changerEnabled = false
local currentAssetId = ""
local currentAccessory = nil
local accessoryAttached = false

-- Target HUD переменные
local lastTarget = nil
local lastDamageTime = 0
local targetHealth = 0
local targetMaxHealth = 100
local targetName = ""
local targetDisplayName = ""
local targetDied = false
local ezMessages = {"EZ", "L", "GET REKT", "TOO EASY", "GGEZ", "NOOB", "L BOZO", "COPE", "SEETHE", "MALD"}

local curR, curG, curB = 160, 80, 255
local themeColor = Color3.fromRGB(curR, curG, curB)

local flyKey = Enum.KeyCode.F
local noclipKey = Enum.KeyCode.N
local autoFireKey = Enum.KeyCode.V
local killAuraKey = Enum.KeyCode.R
local aimbotKey = Enum.UserInputType.MouseButton2 
local silentAimKey = Enum.KeyCode.X
local autoFireDelay = 50

local aimbotSmoothness = 0.35 -- Увеличена скорость аима
local aimbotFov = 500 -- Увеличено до 500

local bv, bg = nil, nil
local noclipConnection = nil
local isAimbotting = false 
local aimbotActiveToggle = false

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================
local function isEnemy(player)
    if player == LocalPlayer then return false end
    
    if ignoreTeam then
        if LocalPlayer.Team and player.Team then
            return LocalPlayer.Team ~= player.Team
        end
        
        if player.Neutral == true then
            return true
        end
        
        return true
    end
    
    return true
end

local function getEnemies()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) then
            table.insert(enemies, player)
        end
    end
    return enemies
end

local function getClosestEnemy()
    local closest, dist = nil, aimbotFov
    local enemies = getEnemies()
    
    for _, p in ipairs(enemies) do
        if p.Character and p.Character:FindFirstChild("Head") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(p.Character.Head.Position)
            if onScreen then
                local mag = (Vector2.new(pos.X, pos.Y) - UserInputService:GetMouseLocation()).Magnitude
                if mag < dist then 
                    closest = p
                    dist = mag 
                end
            end
        end
    end
    return closest
end

-- Функция для получения текущего вида камеры (1 лицо / 3 лицо)
local function getCameraMode()
    local char = LocalPlayer.Character
    if not char then return "FirstPerson" end
    
    local head = char:FindFirstChild("Head")
    if not head then return "FirstPerson" end
    
    -- Проверяем расстояние от камеры до головы
    local dist = (Camera.CFrame.Position - head.Position).Magnitude
    if dist < 2 then
        return "FirstPerson"
    else
        return "ThirdPerson"
    end
end

-- Функция для получения случайной части тела для хитбокса
local function getRandomHitboxPart(character)
    local parts = {
        "Head",
        "HumanoidRootPart",
        "Torso",
        "UpperTorso",
        "LowerTorso",
        "LeftUpperArm",
        "RightUpperArm",
        "LeftLowerArm",
        "RightLowerArm",
        "LeftHand",
        "RightHand",
        "LeftUpperLeg",
        "RightUpperLeg",
        "LeftLowerLeg",
        "RightLowerLeg",
        "LeftFoot",
        "RightFoot"
    }
    
    local availableParts = {}
    for _, partName in ipairs(parts) do
        local part = character:FindFirstChild(partName)
        if part then
            table.insert(availableParts, part)
        end
    end
    
    if #availableParts > 0 then
        return availableParts[math.random(#availableParts)]
    end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
end

-- Функция для получения ближайшего врага в радиусе (для Kill Aura)
-- ТЕПЕРЬ НЕ ЗАВИСИТ ОТ НАПРАВЛЕНИЯ ВЗГЛЯДА
local function getClosestEnemyInRange(range)
    local closest = nil
    local closestDist = range
    local myPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.new()
    
    local enemies = getEnemies()
    
    for _, p in ipairs(enemies) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local hrp = p.Character.HumanoidRootPart
            local dist = (hrp.Position - myPos).Magnitude
            
            -- Просто проверяем расстояние, без проверки направления
            if dist < closestDist then
                closest = p
                closestDist = dist
            end
        end
    end
    
    return closest
end

local function getClosestEnemySilent()
    local closest = nil
    local closestDist = silentAimFov
    local myPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.new()
    
    local enemies = getEnemies()
    
    for _, p in ipairs(enemies) do
        if p.Character and p.Character:FindFirstChild("Head") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local headPos = p.Character.Head.Position
            local dist = (headPos - myPos).Magnitude
            
            if dist < closestDist then
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {LocalPlayer.Character}
                
                local result = workspace:Raycast(myPos, (headPos - myPos).Unit * dist, params)
                
                if not result or wallbangEnabled then
                    closest = p
                    closestDist = dist
                end
            end
        end
    end
    
    return closest
end

local function isAimingAtEnemy()
    if not LocalPlayer.Character then return false end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    if wallbangEnabled then
        params.FilterDescendantsInstances = {LocalPlayer.Character}
    else
        params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    end
    
    local result = workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 1000, params)
    
    if result and result.Instance then
        local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
        if hitChar and hitChar:FindFirstChild("Humanoid") then
            local player = Players:GetPlayerFromCharacter(hitChar)
            return player ~= nil and isEnemy(player)
        end
    end
    
    return false
end

-- ==================== ИСПРАВЛЕННАЯ KILL AURA ====================
local function updateKillAura()
    if not killAuraEnabled or not LocalPlayer.Character then return end
    
    local currentTime = tick()
    
    -- Находим ближайшую цель (теперь просто по расстоянию, без проверки направления)
    local target = getClosestEnemyInRange(killAuraRange)
    killAuraTarget = target
    
    if target and target.Character then
        local humanoid = target.Character:FindFirstChild("Humanoid")
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and humanoid.Health > 0 and hrp then
            -- Атакуем с частотой 10 ударов в секунду
            -- УБИРАЕМ проверку направления - атакуем всегда, если цель в радиусе
            if currentTime - lastKillAuraTime >= killAuraDelay then
                -- Используем инструмент если он есть
                local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    -- Активируем инструмент (это и есть удар)
                    tool:Activate()
                    
                    -- Создаем визуальный эффект удара на цели
                    local hitPart = Instance.new("Part")
                    hitPart.Size = Vector3.new(0.5, 0.5, 0.5)
                    hitPart.Shape = Enum.PartType.Ball
                    hitPart.Material = Enum.Material.Neon
                    hitPart.Color = themeColor
                    hitPart.CanCollide = false
                    hitPart.Anchored = true
                    hitPart.Parent = workspace
                    
                    -- Позиция удара - на месте цели
                    local head = target.Character:FindFirstChild("Head")
                    local hitPos = head and head.Position or hrp.Position
                    hitPart.CFrame = CFrame.new(hitPos)
                    
                    -- Удаляем через 0.1 секунды
                    game:GetService("Debris"):AddItem(hitPart, 0.1)
                    
                    -- Добавляем красивый след
                    local trail = Instance.new("Trail", hitPart)
                    local a0 = Instance.new("Attachment", hitPart)
                    a0.Position = Vector3.new(0, 0.2, 0)
                    local a1 = Instance.new("Attachment", hitPart)
                    a1.Position = Vector3.new(0, -0.2, 0)
                    trail.Attachment0 = a0
                    trail.Attachment1 = a1
                    trail.Lifetime = 0.1
                    trail.Color = ColorSequence.new(themeColor)
                    
                    -- Обновляем время последнего удара
                    lastKillAuraTime = currentTime
                    
                    -- Обновляем Target HUD
                    if target ~= lastTarget then
                        lastTarget = target
                        targetDied = false
                    end
                    lastDamageTime = currentTime
                end
            end
        end
    end
end

-- ==================== SILENT AIM FUNCTIONS ====================
local function hookMouse()
    if not silentAimEnabled or not silentAimActiveToggle then
        if originalMouseTarget then
            Mouse.Target = originalMouseTarget
            Mouse.TargetFilter = nil
        end
        if originalMouseHit then
            Mouse.Hit = originalMouseHit
        end
        return
    end
    
    local target = getClosestEnemySilent()
    silentAimTarget = target
    
    if target and target.Character then
        local targetPart = target.Character:FindFirstChild("Head") or 
                          target.Character:FindFirstChild("HumanoidRootPart") or 
                          target.Character:FindFirstChild("Torso") or
                          target.Character:FindFirstChild("UpperTorso")
        
        -- Если есть активный рандом хитбокс, целимся в него
        if hitboxPart and target.Character:FindFirstChild(hitboxPart) then
            targetPart = target.Character:FindFirstChild(hitboxPart)
        end
        
        if targetPart then
            originalMouseTarget = Mouse.Target
            originalMouseHit = Mouse.Hit
            
            Mouse.Target = targetPart
            Mouse.TargetFilter = target.Character
            
            local direction = (targetPart.Position - Camera.CFrame.Position).Unit
            local newHit = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction * 1000)
            Mouse.Hit = newHit
            
            if Mouse.TargetFilter ~= target.Character then
                Mouse.TargetFilter = target.Character
            end
            
            return true
        end
    end
    
    if originalMouseTarget then
        Mouse.Target = originalMouseTarget
        Mouse.TargetFilter = nil
    end
    if originalMouseHit then
        Mouse.Hit = originalMouseHit
    end
    
    return false
end

local function unhookMouse()
    if originalMouseTarget then
        Mouse.Target = originalMouseTarget
        Mouse.TargetFilter = nil
        originalMouseTarget = nil
    end
    if originalMouseHit then
        Mouse.Hit = originalMouseHit
        originalMouseHit = nil
    end
    silentAimTarget = nil
end

-- ==================== TARGET ESP FUNCTIONS ====================
local function createTargetESPParticles(target)
    for _, particle in ipairs(targetESPParticles) do
        pcall(function() particle.obj:Destroy() end)
    end
    targetESPParticles = {}
    
    if not target or not target.Character or not targetESPEnabled or targetESPType ~= "Particles" then return end
    
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for i = 1, 3 do
        local p = Instance.new("Part")
        p.Size = Vector3.new(0.4, 0.4, 0.4)
        p.Shape = Enum.PartType.Ball
        p.CanCollide = false
        p.Anchored = true
        p.Material = Enum.Material.Neon
        p.Color = themeColor
        p.Parent = workspace
        
        local trail = Instance.new("Trail", p)
        local a0 = Instance.new("Attachment", p)
        a0.Position = Vector3.new(0, 0.2, 0)
        local a1 = Instance.new("Attachment", p)
        a1.Position = Vector3.new(0, -0.2, 0)
        trail.Attachment0 = a0
        trail.Attachment1 = a1
        trail.Lifetime = 0.5
        trail.WidthScale = NumberSequence.new(1, 0)
        trail.Color = ColorSequence.new(themeColor)
        
        table.insert(targetESPParticles, {
            obj = p,
            angle = i * 120,
            trail = trail
        })
    end
end

local function createTargetESPSquare(target)
    if targetESPSquare then
        pcall(function() targetESPSquare:Destroy() end)
        targetESPSquare = nil
    end
    
    if not target or not target.Character or not targetESPEnabled or targetESPType ~= "Square" then return end
    
    local head = target.Character:FindFirstChild("Head")
    if not head then return end
    
    local square = Instance.new("BillboardGui")
    square.Name = "TargetESPSquare"
    square.Adornee = head
    square.Size = UDim2.new(0, 60, 0, 80)
    square.StudsOffset = Vector3.new(0, 2, 0)
    square.AlwaysOnTop = true
    square.Parent = head
    
    local frame = Instance.new("Frame", square)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 2
    frame.BorderColor3 = themeColor
    
    local fill = Instance.new("Frame", frame)
    fill.Size = UDim2.new(1, -4, 1, -4)
    fill.Position = UDim2.new(0, 2, 0, 2)
    fill.BackgroundColor3 = themeColor
    fill.BackgroundTransparency = 0.7
    fill.BorderSizePixel = 0
    
    targetESPSquare = square
end

local function clearTargetESP()
    for _, particle in ipairs(targetESPParticles) do
        pcall(function() particle.obj:Destroy() end)
    end
    targetESPParticles = {}
    
    if targetESPSquare then
        pcall(function() targetESPSquare:Destroy() end)
        targetESPSquare = nil
    end
end

local function updateTargetESP()
    if not targetESPEnabled or not currentTarget then
        clearTargetESP()
        return
    end
    
    if targetESPType == "Particles" then
        if #targetESPParticles == 0 then
            createTargetESPParticles(currentTarget)
        end
        
        local targetChar = currentTarget.Character
        if targetChar then
            local hrp = targetChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, data in ipairs(targetESPParticles) do
                    if data.obj and data.obj.Parent then
                        data.angle = data.angle + 5
                        local x = math.cos(math.rad(data.angle)) * 2.5
                        local z = math.sin(math.rad(data.angle)) * 2.5
                        local yOffset = math.sin(tick() * 3) * 1.5
                        data.obj.CFrame = CFrame.new(hrp.Position + Vector3.new(x, yOffset + 2, z))
                        data.obj.Color = themeColor
                        if data.trail then
                            data.trail.Color = ColorSequence.new(themeColor)
                        end
                    end
                end
            end
        end
    elseif targetESPType == "Square" then
        if not targetESPSquare and currentTarget.Character then
            createTargetESPSquare(currentTarget)
        elseif targetESPSquare and currentTarget.Character then
            targetESPSquare.Frame.BorderColor3 = themeColor
            targetESPSquare.Frame.Fill.BackgroundColor3 = themeColor
        end
    end
end

-- ==================== ФУНКЦИИ ДЛЯ ПЕРЕТАСКИВАНИЯ ====================
local function makeDraggable(frame, dragHandle)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            frame.Position = newPos
            
            if frame.Name == "LeftInfo" then
                hudPositions.leftInfo = newPos
            elseif frame.Name == "ActiveModules" then
                hudPositions.rightModules = newPos
            elseif frame.Name == "Watermark" then
                hudPositions.watermark = newPos
            elseif frame.Name == "TargetHUD" then
                hudPositions.targetHUD = newPos
            end
        end
    end)
end

-- ==================== СОЗДАНИЕ GUI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeepSense_NursultanUI"
screenGui.Parent = game:GetService("CoreGui")
screenGui.ResetOnSpawn = false
screenGui.Enabled = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- === HUD В СТИЛЕ NURSULTAN ===
local hudMain = Instance.new("Frame", screenGui)
hudMain.Name = "HUD"
hudMain.Size = UDim2.new(1, 0, 1, 0)
hudMain.BackgroundTransparency = 1
hudMain.Visible = hudEnabled 

-- Левый верхний угол - информация о игроке (ПЕРЕТАСКИВАЕМЫЙ)
local leftInfo = Instance.new("Frame", hudMain)
leftInfo.Name = "LeftInfo"
leftInfo.Size = UDim2.new(0, 250, 0, 100)
leftInfo.Position = hudPositions.leftInfo
leftInfo.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
leftInfo.BackgroundTransparency = 0.2
leftInfo.BorderSizePixel = 0
leftInfo.Visible = showPlayerInfo
Instance.new("UICorner", leftInfo).CornerRadius = UDim.new(0, 8)

local leftInfoStroke = Instance.new("UIStroke", leftInfo)
leftInfoStroke.Thickness = 1
leftInfoStroke.Color = themeColor
leftInfoStroke.Transparency = 0.5

local leftInfoDrag = Instance.new("Frame", leftInfo)
leftInfoDrag.Size = UDim2.new(1, 0, 0, 20)
leftInfoDrag.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
leftInfoDrag.BackgroundTransparency = 0.5
leftInfoDrag.BorderSizePixel = 0
Instance.new("UICorner", leftInfoDrag).CornerRadius = UDim.new(0, 4)

local leftInfoDragText = Instance.new("TextLabel", leftInfoDrag)
leftInfoDragText.Size = UDim2.new(1, -10, 1, 0)
leftInfoDragText.Position = UDim2.new(0, 5, 0, 0)
leftInfoDragText.BackgroundTransparency = 1
leftInfoDragText.Text = "PLAYER INFO"
leftInfoDragText.TextColor3 = themeColor
leftInfoDragText.Font = Enum.Font.GothamBold
leftInfoDragText.TextSize = 10
leftInfoDragText.TextXAlignment = Enum.TextXAlignment.Left

local playerName = Instance.new("TextLabel", leftInfo)
playerName.Size = UDim2.new(1, -10, 0, 25)
playerName.Position = UDim2.new(0, 5, 0, 25)
playerName.BackgroundTransparency = 1
playerName.Text = "Player: " .. LocalPlayer.Name
playerName.TextColor3 = Color3.new(1, 1, 1)
playerName.Font = Enum.Font.GothamBold
playerName.TextSize = 14
playerName.TextXAlignment = Enum.TextXAlignment.Left

local pingText = Instance.new("TextLabel", leftInfo)
pingText.Size = UDim2.new(1, -10, 0, 25)
pingText.Position = UDim2.new(0, 5, 0, 50)
pingText.BackgroundTransparency = 1
pingText.Text = "Ping: 0ms"
pingText.TextColor3 = Color3.new(1, 1, 1)
pingText.Font = Enum.Font.Gotham
pingText.TextSize = 14
pingText.TextXAlignment = Enum.TextXAlignment.Left

local fpsText = Instance.new("TextLabel", leftInfo)
fpsText.Size = UDim2.new(1, -10, 0, 25)
fpsText.Position = UDim2.new(0, 5, 0, 75)
fpsText.BackgroundTransparency = 1
fpsText.Text = "FPS: 60"
fpsText.TextColor3 = Color3.new(1, 1, 1)
fpsText.Font = Enum.Font.Gotham
fpsText.TextSize = 14
fpsText.TextXAlignment = Enum.TextXAlignment.Left

-- Правый верхний угол - активные модули (ПЕРЕТАСКИВАЕМЫЙ)
local rightModules = Instance.new("Frame", hudMain)
rightModules.Name = "ActiveModules"
rightModules.Size = UDim2.new(0, 220, 0, 350)
rightModules.Position = hudPositions.rightModules
rightModules.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
rightModules.BackgroundTransparency = 0.2
rightModules.BorderSizePixel = 0
rightModules.Visible = showActiveModules
Instance.new("UICorner", rightModules).CornerRadius = UDim.new(0, 8)

local rightModulesStroke = Instance.new("UIStroke", rightModules)
rightModulesStroke.Thickness = 1
rightModulesStroke.Color = themeColor
rightModulesStroke.Transparency = 0.5

local rightModulesDrag = Instance.new("Frame", rightModules)
rightModulesDrag.Size = UDim2.new(1, 0, 0, 20)
rightModulesDrag.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
rightModulesDrag.BackgroundTransparency = 0.5
rightModulesDrag.BorderSizePixel = 0
Instance.new("UICorner", rightModulesDrag).CornerRadius = UDim.new(0, 4)

local rightModulesDragText = Instance.new("TextLabel", rightModulesDrag)
rightModulesDragText.Size = UDim2.new(1, -10, 1, 0)
rightModulesDragText.Position = UDim2.new(0, 5, 0, 0)
rightModulesDragText.BackgroundTransparency = 1
rightModulesDragText.Text = "ACTIVE MODULES"
rightModulesDragText.TextColor3 = themeColor
rightModulesDragText.Font = Enum.Font.GothamBold
rightModulesDragText.TextSize = 10
rightModulesDragText.TextXAlignment = Enum.TextXAlignment.Left

local modulesTitle = Instance.new("TextLabel", rightModules)
modulesTitle.Size = UDim2.new(1, -10, 0, 25)
modulesTitle.Position = UDim2.new(0, 5, 0, 25)
modulesTitle.BackgroundTransparency = 1
modulesTitle.Text = "ACTIVE MODULES"
modulesTitle.TextColor3 = themeColor
modulesTitle.Font = Enum.Font.GothamBold
modulesTitle.TextSize = 14
modulesTitle.TextXAlignment = Enum.TextXAlignment.Left

local modulesList = Instance.new("ScrollingFrame", rightModules)
modulesList.Name = "ModulesList"
modulesList.Size = UDim2.new(1, -10, 1, -35)
modulesList.Position = UDim2.new(0, 5, 0, 30)
modulesList.BackgroundTransparency = 1
modulesList.ScrollBarThickness = 2
modulesList.ScrollBarImageColor3 = themeColor
modulesList.CanvasSize = UDim2.new(0, 0, 0, 0)
modulesList.BorderSizePixel = 0

local modulesLayout = Instance.new("UIListLayout", modulesList)
modulesLayout.Padding = UDim.new(0, 4)
modulesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
modulesLayout.SortOrder = Enum.SortOrder.LayoutOrder

modulesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    modulesList.CanvasSize = UDim2.new(0, 0, 0, modulesLayout.AbsoluteContentSize.Y + 5)
end)

-- Центральный водный знак (ПЕРЕТАСКИВАЕМЫЙ)
local watermark = Instance.new("Frame", hudMain)
watermark.Name = "Watermark"
watermark.Size = UDim2.new(0, 200, 0, 35)
watermark.Position = hudPositions.watermark
watermark.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
watermark.BackgroundTransparency = 0.3
watermark.BorderSizePixel = 0
watermark.Visible = showWatermark
Instance.new("UICorner", watermark).CornerRadius = UDim.new(0, 6)

local watermarkStroke = Instance.new("UIStroke", watermark)
watermarkStroke.Thickness = 1.5
watermarkStroke.Color = themeColor
watermarkStroke.Transparency = 0.3

local watermarkDrag = Instance.new("Frame", watermark)
watermarkDrag.Size = UDim2.new(1, 0, 0, 35)
watermarkDrag.BackgroundTransparency = 1

local watermarkText = Instance.new("TextLabel", watermark)
watermarkText.Size = UDim2.new(1, 0, 1, 0)
watermarkText.BackgroundTransparency = 1
watermarkText.Text = "DEEPSENSE | NURSULTAN"
watermarkText.TextColor3 = Color3.new(1, 1, 1)
watermarkText.Font = Enum.Font.GothamBold
watermarkText.TextSize = 16
watermarkText.TextScaled = true

-- Target HUD
local targetHUD = Instance.new("Frame", hudMain)
targetHUD.Name = "TargetHUD"
targetHUD.Size = UDim2.new(0, 250, 0, 120)
targetHUD.Position = hudPositions.targetHUD
targetHUD.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
targetHUD.BackgroundTransparency = 0.2
targetHUD.BorderSizePixel = 0
targetHUD.Visible = false
Instance.new("UICorner", targetHUD).CornerRadius = UDim.new(0, 8)

local targetHUDStroke = Instance.new("UIStroke", targetHUD)
targetHUDStroke.Thickness = 1
targetHUDStroke.Color = themeColor
targetHUDStroke.Transparency = 0.5

local targetHUDDrag = Instance.new("Frame", targetHUD)
targetHUDDrag.Size = UDim2.new(1, 0, 0, 15)
targetHUDDrag.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
targetHUDDrag.BackgroundTransparency = 0.5
targetHUDDrag.BorderSizePixel = 0
Instance.new("UICorner", targetHUDDrag).CornerRadius = UDim.new(0, 4)

local targetHeadIcon = Instance.new("Frame", targetHUD)
targetHeadIcon.Size = UDim2.new(0, 50, 0, 50)
targetHeadIcon.Position = UDim2.new(0, 10, 0, 25)
targetHeadIcon.BackgroundColor3 = Color3.fromRGB(255, 200, 150)
targetHeadIcon.BorderSizePixel = 0
local headIconCorner = Instance.new("UICorner", targetHeadIcon)
headIconCorner.CornerRadius = UDim.new(1, 0)

local headEye1 = Instance.new("Frame", targetHeadIcon)
headEye1.Size = UDim2.new(0.2, 0, 0.2, 0)
headEye1.Position = UDim2.new(0.2, 0, 0.3, 0)
headEye1.BackgroundColor3 = Color3.new(1, 1, 1)
headEye1.BorderSizePixel = 0
local eye1Corner = Instance.new("UICorner", headEye1)
eye1Corner.CornerRadius = UDim.new(1, 0)

local headEye2 = Instance.new("Frame", targetHeadIcon)
headEye2.Size = UDim2.new(0.2, 0, 0.2, 0)
headEye2.Position = UDim2.new(0.6, 0, 0.3, 0)
headEye2.BackgroundColor3 = Color3.new(1, 1, 1)
headEye2.BorderSizePixel = 0
local eye2Corner = Instance.new("UICorner", headEye2)
eye2Corner.CornerRadius = UDim.new(1, 0)

local headPupil1 = Instance.new("Frame", headEye1)
headPupil1.Size = UDim2.new(0.5, 0, 0.5, 0)
headPupil1.Position = UDim2.new(0.25, 0, 0.25, 0)
headPupil1.BackgroundColor3 = Color3.new(0, 0, 0)
headPupil1.BorderSizePixel = 0
local pupil1Corner = Instance.new("UICorner", headPupil1)
pupil1Corner.CornerRadius = UDim.new(1, 0)

local headPupil2 = Instance.new("Frame", headEye2)
headPupil2.Size = UDim2.new(0.5, 0, 0.5, 0)
headPupil2.Position = UDim2.new(0.25, 0, 0.25, 0)
headPupil2.BackgroundColor3 = Color3.new(0, 0, 0)
headPupil2.BorderSizePixel = 0
local pupil2Corner = Instance.new("UICorner", headPupil2)
pupil2Corner.CornerRadius = UDim.new(1, 0)

local targetNameLabel = Instance.new("TextLabel", targetHUD)
targetNameLabel.Size = UDim2.new(0, 150, 0, 20)
targetNameLabel.Position = UDim2.new(0, 70, 0, 25)
targetNameLabel.BackgroundTransparency = 1
targetNameLabel.Text = "No Target"
targetNameLabel.TextColor3 = Color3.new(1, 1, 1)
targetNameLabel.Font = Enum.Font.GothamBold
targetNameLabel.TextSize = 14
targetNameLabel.TextXAlignment = Enum.TextXAlignment.Left

local targetHealthBar = Instance.new("Frame", targetHUD)
targetHealthBar.Size = UDim2.new(0, 170, 0, 8)
targetHealthBar.Position = UDim2.new(0, 70, 0, 47)
targetHealthBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
targetHealthBar.BorderSizePixel = 0
Instance.new("UICorner", targetHealthBar).CornerRadius = UDim.new(0, 4)

local targetHealthFill = Instance.new("Frame", targetHealthBar)
targetHealthFill.Size = UDim2.new(0, 0, 1, 0)
targetHealthFill.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
targetHealthFill.BorderSizePixel = 0
Instance.new("UICorner", targetHealthFill).CornerRadius = UDim.new(0, 4)

local targetHealthText = Instance.new("TextLabel", targetHUD)
targetHealthText.Size = UDim2.new(0, 50, 0, 20)
targetHealthText.Position = UDim2.new(1, -55, 0, 45)
targetHealthText.BackgroundTransparency = 1
targetHealthText.Text = "100%"
targetHealthText.TextColor3 = Color3.new(1, 1, 1)
targetHealthText.Font = Enum.Font.Gotham
targetHealthText.TextSize = 12
targetHealthText.TextXAlignment = Enum.TextXAlignment.Right

local targetEZMessage = Instance.new("TextLabel", targetHUD)
targetEZMessage.Size = UDim2.new(1, -10, 0, 25)
targetEZMessage.Position = UDim2.new(0, 5, 0, 80)
targetEZMessage.BackgroundTransparency = 1
targetEZMessage.Text = ""
targetEZMessage.TextColor3 = themeColor
targetEZMessage.Font = Enum.Font.GothamBold
targetEZMessage.TextSize = 18
targetEZMessage.TextXAlignment = Enum.TextXAlignment.Center
targetEZMessage.Visible = false

makeDraggable(targetHUD, targetHUDDrag)

local ezLabels = {}

-- === ОСНОВНОЕ МЕНЮ (НОВЫЙ ДИЗАЙН) ===
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 700, 0, 600) -- Шире и ниже
mainFrame.Position = UDim2.new(0.5, -350, 0.5, -300)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10) 
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 14)

-- Верхняя панель с названием
local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1, 0, 0, 60)
titleBar.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
titleBar.Parent = mainFrame
local titleBarCorner = Instance.new("UICorner", titleBar)
titleBarCorner.CornerRadius = UDim.new(0, 14)

-- Левый верхний угол - название DeepSense
local title = Instance.new("TextLabel")
title.Text = "  DeepSense"
title.Size = UDim2.new(0.5, 0, 1, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 32
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

task.spawn(function()
    local hue = 0
    while true do
        hue = hue + (1/400)
        if hue > 1 then hue = 0 end
        local rainbow = Color3.fromHSV(hue, 0.6, 1) 
        title.TextColor3 = rainbow
        watermarkStroke.Color = rainbow
        rightModulesStroke.Color = rainbow
        leftInfoStroke.Color = rainbow
        targetHUDStroke.Color = rainbow
        task.wait()
    end
end)

-- Кнопка сворачивания
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 35, 0, 35)
minimizeBtn.Position = UDim2.new(1, -50, 0, 12)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
minimizeBtn.Text = "_"
minimizeBtn.TextColor3 = Color3.new(1, 1, 1)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 8)

local isMinimized = false
minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local targetSize = isMinimized and UDim2.new(0, 700, 0, 60) or UDim2.new(0, 700, 0, 600)
    minimizeBtn.Text = isMinimized and "+" or "_"
    TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
end)

-- Левый сайдбар с табами
local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size = UDim2.new(0, 150, 1, -70)
sidebar.Position = UDim2.new(0, 0, 0, 70)
sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
sidebar.BorderSizePixel = 0

local sidebarCorner = Instance.new("UICorner", sidebar)
sidebarCorner.CornerRadius = UDim.new(0, 8)

-- Контент фрейм (правая часть)
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -160, 1, -80)
contentFrame.Position = UDim2.new(0, 155, 0, 75)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local sections = {}

local function createSection(name)
    local sec = Instance.new("ScrollingFrame")
    sec.Name = name
    sec.Size = UDim2.new(1, 0, 1, 0)
    sec.BackgroundTransparency = 1
    sec.ScrollBarThickness = 2 
    sec.ScrollBarImageColor3 = themeColor
    sec.Visible = false
    sec.Parent = contentFrame
    local list = Instance.new("UIListLayout", sec)
    list.Padding = UDim.new(0, 10) 
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    sections[name] = sec
    return sec
end

local movementSec = createSection("Movement")
local rageSec = createSection("Rage")
local antiAimSec = createSection("Anti-Aim")
local visualSec = createSection("Visual")
local miscSec = createSection("Misc")

-- Кнопки табов в сайдбаре
local tabButtonsSidebar = {}
local function createSidebarTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 45)
    btn.Position = UDim2.new(0, 5, 0, 5 + (#tabButtonsSidebar * 50))
    btn.BackgroundTransparency = 1
    btn.Text = icon .. "  " .. name
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    
    btn.MouseButton1Click:Connect(function()
        -- Переключаем видимость секций
        for _, sec in pairs(sections) do 
            sec.Visible = false 
        end
        if sections[name] then 
            sections[name].Visible = true 
        end
        
        -- Подсветка активной кнопки
        for _, b in pairs(tabButtonsSidebar) do
            b.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
        btn.TextColor3 = themeColor
    end)
    
    table.insert(tabButtonsSidebar, btn)
    return btn
end

-- Создаем табы с иконками
createSidebarTab("Movement", "🏃")
createSidebarTab("Rage", "💢")
createSidebarTab("Anti-Aim", "🎯")
createSidebarTab("Visual", "👁️")
createSidebarTab("Misc", "⚙️")

-- Активируем первый таб
if tabButtonsSidebar[1] then
    tabButtonsSidebar[1].TextColor3 = themeColor
end
if sections["Movement"] then
    sections["Movement"].Visible = true
end

-- HELPERS
local function addLabel(text, parent)
    local l = Instance.new("TextLabel", parent)
    l.Text = text; l.Size = UDim2.new(0.95, 0, 0, 25); l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(200, 200, 200); l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.GothamSemibold; l.TextSize = 14
    return l
end

local function addBox(default, parent, callback)
    local b = Instance.new("TextBox", parent)
    b.Text = tostring(default); b.Size = UDim2.new(0.95, 0, 0, 35); b.BackgroundColor3 = Color3.fromRGB(20, 20, 20) 
    b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamSemibold; b.TextSize = 15
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.FocusLost:Connect(function() callback(b.Text) end)
    return b
end

local function addBtn(text, parent, callback)
    local b = Instance.new("TextButton", parent)
    b.Text = text; b.Size = UDim2.new(0.95, 0, 0, 40); b.BackgroundColor3 = Color3.fromRGB(25, 25, 25) 
    b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold; b.TextSize = 15
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10) 
    b.MouseButton1Click:Connect(callback)
    return b
end

local function addToggle(text, parent, getFunc, setFunc)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0.95, 0, 0, 40)
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    
    local function update()
        local state = getFunc()
        b.Text = text .. (state and ": ON" or ": OFF")
        b.BackgroundColor3 = state and themeColor or Color3.fromRGB(25, 25, 25)
    end
    
    b.MouseButton1Click:Connect(function()
        setFunc(not getFunc())
        update()
        updateModulesList()
    end)
    
    update()
    return b
end

local function addSlider(text, parent, min, max, start, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(0.95, 0, 0, 55); container.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", container)
    label.Text = text .. ": " .. start; label.Size = UDim2.new(1, 0, 0, 25); label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1); label.Font = Enum.Font.GothamSemibold; label.TextSize = 14; label.TextXAlignment = Enum.TextXAlignment.Left
    local slideBack = Instance.new("Frame", container)
    slideBack.Size = UDim2.new(1, 0, 0, 10); slideBack.Position = UDim2.new(0, 0, 0, 30); slideBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30) 
    Instance.new("UICorner", slideBack).CornerRadius = UDim.new(0, 10) 
    local bar = Instance.new("Frame", slideBack)
    bar.Size = UDim2.new((start - min) / (max - min), 0, 1, 0); bar.BackgroundColor3 = themeColor 
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)
    local draggingS = false
    local function move(input)
        local pos = math.clamp((input.Position.X - slideBack.AbsolutePosition.X) / slideBack.AbsoluteSize.X, 0, 1)
        bar.Size = UDim2.new(pos, 0, 1, 0)
        local val = math.floor(min + (max - min) * pos)
        label.Text = text .. ": " .. val; callback(val)
    end
    slideBack.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingS = true end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingS = false end end)
    UserInputService.InputChanged:Connect(function(input) if draggingS and input.UserInputType == Enum.UserInputType.MouseMovement then move(input) end end)
    RunService.RenderStepped:Connect(function() bar.BackgroundColor3 = themeColor end)
end

-- === ФУНКЦИЯ ОБНОВЛЕНИЯ СПИСКА МОДУЛЕЙ ===
local function updateModulesList()
    for _, child in ipairs(modulesList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local activeModules = {}
    
    if flying then table.insert(activeModules, "Fly") end
    if noclip then table.insert(activeModules, "Noclip") end
    if aimbotEnabled and aimbotActiveToggle then table.insert(activeModules, "Aimbot") end
    if silentAimEnabled and silentAimActiveToggle then table.insert(activeModules, "Silent Aim") end
    if killAuraEnabled then table.insert(activeModules, "Kill Aura") end
    if autoFireEnabled then table.insert(activeModules, "Auto Fire") end
    if wallbangEnabled then table.insert(activeModules, "Wallbang") end
    if espEnabled then table.insert(activeModules, "ESP") end
    if targetESPEnabled then 
        table.insert(activeModules, "Target ESP: " .. targetESPType) 
    end
    if particlesEnabled then table.insert(activeModules, "Particles") end
    if antiAimEnabled then 
        table.insert(activeModules, "AntiAim")
        if pitchMode ~= "None" then
            table.insert(activeModules, "  Pitch: " .. pitchMode)
        end
        if jitterEnabled then
            table.insert(activeModules, "  Jitter")
        end
    end
    if bhopEnabled then table.insert(activeModules, "Bunnyhop") end
    if changerEnabled and currentAccessory then table.insert(activeModules, "Changer") end
    
    for i, moduleName in ipairs(activeModules) do
        local moduleFrame = Instance.new("Frame", modulesList)
        moduleFrame.Size = UDim2.new(1, 0, 0, 22)
        moduleFrame.BackgroundTransparency = 1
        
        local dot = Instance.new("Frame", moduleFrame)
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Position = UDim2.new(0, 0, 0.5, -3)
        dot.BackgroundColor3 = themeColor
        dot.BorderSizePixel = 0
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        
        local nameLabel = Instance.new("TextLabel", moduleFrame)
        nameLabel.Size = UDim2.new(1, -15, 1, 0)
        nameLabel.Position = UDim2.new(0, 10, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = moduleName
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    end
end

-- === ФУНКЦИЯ ДЛЯ СОЗДАНИЯ ЛЕТАЮЩИХ EZ НАДПИСЕЙ ===
local function createEZMessage()
    local ez = Instance.new("TextLabel", hudMain)
    ez.Size = UDim2.new(0, 100, 0, 30)
    ez.Position = UDim2.new(math.random(0, 80)/100, 0, math.random(0, 80)/100, 0)
    ez.BackgroundTransparency = 1
    ez.Text = ezMessages[math.random(#ezMessages)]
    ez.TextColor3 = themeColor
    ez.Font = Enum.Font.GothamBold
    ez.TextSize = math.random(16, 24)
    ez.Rotation = math.random(-10, 10)
    ez.TextTransparency = 0
    
    table.insert(ezLabels, {label = ez, time = tick(), velocity = Vector2.new(math.random(-50, 50)/10, math.random(-30, -10)/10)})
    
    task.spawn(function()
        task.wait(3)
        if ez and ez.Parent then
            ez:Destroy()
            for i, v in ipairs(ezLabels) do
                if v.label == ez then
                    table.remove(ezLabels, i)
                    break
                end
            end
        end
    end)
end

-- === ESP HELPER FUNCTIONS ===
local function createNameTag(player)
    if player.Character and player.Character:FindFirstChild("Head") then
        local head = player.Character.Head
        if not head:FindFirstChild("DeepSenseNameTag") then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "DeepSenseNameTag"
            billboard.Adornee = head
            billboard.Size = UDim2.new(0, 100, 0, 50)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = head

            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 1, 0)
            label.Text = player.Name
            label.Font = Enum.Font.GothamBold
            label.TextSize = 14
            label.TextColor3 = themeColor
            label.TextStrokeTransparency = 0.5
            label.Parent = billboard
        end
    end
end

-- === ФУНКЦИИ ДЛЯ ХИТБОКСОВ ===
local function applyHitboxes(char, size)
    local parts = {
        char:FindFirstChild("Head"),
        char:FindFirstChild("HumanoidRootPart"),
        char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"),
        char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm"),
        char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm"),
        char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftUpperLeg"),
        char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg")
    }
    
    for _, part in ipairs(parts) do
        if part then
            if not part:GetAttribute("OriginalSize") then
                part:SetAttribute("OriginalSize", part.Size)
            end
            
            if part == char:FindFirstChild("Head") then
                part.Size = Vector3.new(size, size, size)
            elseif part == char:FindFirstChild("HumanoidRootPart") then
                part.Size = Vector3.new(size, 2, size)
            else
                part.Size = Vector3.new(size, size, size)
            end
            
            part.Transparency = 0.7
            part.CanCollide = false
            part.Material = Enum.Material.Neon
            part.Color = themeColor
        end
    end
end

local function resetHitboxes(char)
    local parts = {
        char:FindFirstChild("Head"),
        char:FindFirstChild("HumanoidRootPart"),
        char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"),
        char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm"),
        char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm"),
        char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftUpperLeg"),
        char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg")
    }
    
    for _, part in ipairs(parts) do
        if part and part:GetAttribute("OriginalSize") then
            part.Size = part:GetAttribute("OriginalSize")
            part.Transparency = 0
            part.Material = Enum.Material.Plastic
        end
    end
end

-- === CHANGER ===
local function clearAccessory()
    if currentAccessory then
        pcall(function() currentAccessory:Destroy() end)
        currentAccessory = nil
    end
    accessoryAttached = false
end

local function loadAssetFromId(assetId)
    clearAccessory()
    
    if not assetId or assetId == "" then 
        print("⚠️ Введите ID предмета")
        return false 
    end
    
    local cleanId = assetId:match("%d+")
    if not cleanId then 
        print("❌ Неверный формат ID")
        return false 
    end
    
    print("🔄 Загрузка предмета с ID: " .. cleanId)
    
    local success, result = pcall(function()
        return InsertService:LoadAsset(tonumber(cleanId))
    end)
    
    if success and result then
        local children = result:GetChildren()
        if #children > 0 then
            local asset = children[1]
            local clone = asset:Clone()
            clone.Parent = workspace
            
            if clone:IsA("BasePart") then
                clone.LocalTransparencyModifier = 0
                clone.Anchored = false
                clone.CanCollide = false
                currentAccessory = clone
                print("✅ Аксессуар загружен")
            elseif clone:IsA("Model") then
                for _, child in ipairs(clone:GetDescendants()) do
                    if child:IsA("BasePart") then
                        child.LocalTransparencyModifier = 0
                        child.Anchored = false
                        child.CanCollide = false
                    end
                end
                currentAccessory = clone
                print("✅ Аксессуар загружен")
            end
            
            if changerEnabled then
                task.wait(0.1)
                attachAccessory()
            end
            
            return true
        end
    else
        print("❌ Ошибка загрузки")
    end
    return false
end

local function attachAccessory()
    if not currentAccessory or not LocalPlayer.Character then return end
    
    local head = LocalPlayer.Character:FindFirstChild("Head")
    if not head then return end
    
    local primaryPart = currentAccessory
    if currentAccessory:IsA("Model") then
        for _, child in ipairs(currentAccessory:GetDescendants()) do
            if child:IsA("BasePart") then
                primaryPart = child
                break
            end
        end
    end
    
    if primaryPart and primaryPart:IsA("BasePart") then
        local weld = Instance.new("Weld")
        weld.Part0 = head
        weld.Part1 = primaryPart
        weld.C0 = CFrame.new(0, 0.5, 0)
        weld.Parent = primaryPart
        accessoryAttached = true
        print("✅ Аксессуар прикреплен")
    end
end

-- ==================== FILLING MENU ====================
-- Movement Tab
addLabel("Walking Speed:", movementSec)
addBox(walkspeed, movementSec, function(t) walkspeed = tonumber(t) or 16; currentBhopSpeed = walkspeed end)

addToggle("Bunnyhop", movementSec, 
    function() return bhopEnabled end,
    function(v) bhopEnabled = v end
)

addLabel("Flying Speed:", movementSec)
addBox(flySpeed, movementSec, function(t) flySpeed = tonumber(t) or 50 end)

local flyB = addBtn("Fly: " .. flyKey.Name, movementSec, function() end)
local noclipB = addBtn("Noclip: " .. noclipKey.Name, movementSec, function() end)

-- Rage Tab
addLabel("Hitbox Size:", rageSec)
addBox(hitboxSize, rageSec, function(t) hitboxSize = tonumber(t) or 5 end)

addToggle("Auto Fire", rageSec,
    function() return autoFireEnabled end,
    function(v) autoFireEnabled = v end
)

local autoFireB = addBtn("Auto Fire Bind: " .. autoFireKey.Name, rageSec, function() end)

addSlider("Auto Fire Delay (ms)", rageSec, 10, 200, autoFireDelay, function(v) autoFireDelay = v end)

-- KILL AURA SECTION
addLabel("=== KILL AURA (БЕЙ В ЛЮБУЮ СТОРОНУ) ===", rageSec)
addToggle("Kill Aura", rageSec,
    function() return killAuraEnabled end,
    function(v) killAuraEnabled = v end
)

local killAuraB = addBtn("Kill Aura Bind: " .. killAuraKey.Name, rageSec, function() end)

addSlider("Kill Aura Range", rageSec, 5, 50, killAuraRange, function(v) killAuraRange = v end)

addLabel("=== WALLBANG ===", rageSec)
addToggle("Wallbang", rageSec,
    function() return wallbangEnabled end,
    function(v) wallbangEnabled = v end
)

addLabel("=== AIMBOT ===", rageSec)
addToggle("Aimbot", rageSec,
    function() return aimbotEnabled end,
    function(v) aimbotEnabled = v end
)
local aimbotB = addBtn("Aimbot Bind: " .. aimbotKey.Name, rageSec, function() end)

addLabel("=== SILENT AIM ===", rageSec)
addToggle("Silent Aim", rageSec,
    function() return silentAimEnabled end,
    function(v) 
        silentAimEnabled = v
        if not v then
            unhookMouse()
        end
    end
)

local silentAimB = addBtn("Silent Aim Bind: " .. silentAimKey.Name, rageSec, function() end)
addSlider("Silent Aim Range", rageSec, 50, 500, silentAimFov, function(v) silentAimFov = v end)

-- Anti-Aim Tab
addToggle("Anti-Aim", antiAimSec,
    function() return antiAimEnabled end,
    function(v) antiAimEnabled = v end
)

addLabel("--- PITCH MODES ---", antiAimSec)

-- Создаем фрейм для кнопок питча
local pitchGrid = Instance.new("Frame", antiAimSec)
pitchGrid.Size = UDim2.new(0.95, 0, 0, 120)
pitchGrid.BackgroundTransparency = 1

local pitchGridLayout = Instance.new("UIGridLayout", pitchGrid)
pitchGridLayout.CellSize = UDim2.new(0.3, 0, 0, 40)
pitchGridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
pitchGridLayout.FillDirection = Enum.FillDirection.Horizontal
pitchGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- Функция для создания кнопки питча
local function createPitchButton(text, mode, angle)
    local btn = Instance.new("TextButton", pitchGrid)
    btn.Size = UDim2.new(0.3, 0, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Text = text
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    -- Добавляем обводку
    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(40, 40, 40)
    
    btn.MouseButton1Click:Connect(function()
        pitchMode = mode
        if mode == "Down" then
            pitchAngle = 0.8 -- Нормальный наклон вниз
        elseif mode == "Up" then
            pitchAngle = -0.5 -- Нормальный наклон вверх
        elseif mode == "Random" then
            pitchAngle = 0
        elseif mode == "None" then
            pitchAngle = 0
        end
        
        -- Визуальное выделение активной кнопки
        for _, child in ipairs(pitchGrid:GetChildren()) do
            if child:IsA("TextButton") and child:FindFirstChild("UIStroke") then
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                child.UIStroke.Color = Color3.fromRGB(40, 40, 40)
            end
        end
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        btn.UIStroke.Color = themeColor
    end)
    
    return btn
end

-- Создаем кнопки
createPitchButton("OFF", "None")
createPitchButton("DOWN", "Down")
createPitchButton("UP", "Up")
createPitchButton("RANDOM 50ms", "Random")

addLabel("--- Jitter (Вращение) ---", antiAimSec)
addToggle("Jitter", antiAimSec,
    function() return jitterEnabled end,
    function(v) jitterEnabled = v end
)
addSlider("Jitter Speed", antiAimSec, 0, 360, 180, function(v) jitterValue = v end)

-- Visual Tab
addToggle("ESP", visualSec,
    function() return espEnabled end,
    function(v) espEnabled = v end
)

addToggle("Particles", visualSec,
    function() return particlesEnabled end,
    function(v) particlesEnabled = v end
)

addLabel("=== TARGET ESP ===", visualSec)
addToggle("Target ESP", visualSec,
    function() return targetESPEnabled end,
    function(v) 
        targetESPEnabled = v
        if not v then
            clearTargetESP()
        end
    end
)

addBtn("Type: Particles", visualSec, function()
    targetESPType = "Particles"
    clearTargetESP()
    if targetESPEnabled then
        createTargetESPParticles(currentTarget)
    end
end)

addBtn("Type: Square", visualSec, function()
    targetESPType = "Square"
    clearTargetESP()
    if targetESPEnabled then
        createTargetESPSquare(currentTarget)
    end
end)

-- Misc Tab
addLabel("=== TEAM CHECK ===", miscSec)
addToggle("Ignore Teammates", miscSec,
    function() return ignoreTeam end,
    function(v) ignoreTeam = v end
)

addLabel("=== HUD ELEMENTS ===", miscSec)

addToggle("Show Player Info", miscSec,
    function() return showPlayerInfo end,
    function(v) 
        showPlayerInfo = v
        leftInfo.Visible = v
    end
)

addToggle("Show Active Modules", miscSec,
    function() return showActiveModules end,
    function(v) 
        showActiveModules = v
        rightModules.Visible = v
    end
)

addToggle("Show Watermark", miscSec,
    function() return showWatermark end,
    function(v) 
        showWatermark = v
        watermark.Visible = v
    end
)

addToggle("Show Target HUD", miscSec,
    function() return showTargetHUD end,
    function(v) 
        showTargetHUD = v
        if not v then
            targetHUD.Visible = false
        end
    end
)

addLabel("=== CHANGER (Локальные предметы) ===", miscSec)

addToggle("Changer", miscSec,
    function() return changerEnabled end,
    function(v) 
        changerEnabled = v
        if v and currentAccessory and not accessoryAttached then
            attachAccessory()
        elseif not v then
            clearAccessory()
        end
        updateModulesList()
    end
)

local assetIdBox = addBox("Введите ID предмета", miscSec, function(text)
    currentAssetId = text
end)

addBtn("📥 Загрузить предмет", miscSec, function()
    if currentAssetId and currentAssetId ~= "" then
        loadAssetFromId(currentAssetId)
    end
end)

addBtn("📌 Прикрепить к голове", miscSec, function()
    if currentAccessory then
        attachAccessory()
    end
end)

addBtn("🗑️ Очистить", miscSec, function()
    clearAccessory()
end)

addLabel("📝 Примеры ID:", miscSec)
addLabel("48474294 - Кепка", miscSec)
addLabel("62234425 - Крылья", miscSec)
addLabel("86510585 - Корона", miscSec)

addLabel("=== НАСТРОЙКИ ===", miscSec)
addToggle("HUD", miscSec,
    function() return hudEnabled end,
    function(v) 
        hudEnabled = v
        hudMain.Visible = hudEnabled
    end
)

addLabel("Theme Color:", miscSec)
addSlider("Red", miscSec, 0, 255, curR, function(v) curR = v; themeColor = Color3.fromRGB(curR, curG, curB) end)
addSlider("Green", miscSec, 0, 255, curG, function(v) curG = v; themeColor = Color3.fromRGB(curR, curG, curB) end)
addSlider("Blue", miscSec, 0, 255, curB, function(v) curB = v; themeColor = Color3.fromRGB(curR, curG, curB) end)

addBtn("💀 Destroy Menu", miscSec, function() screenGui:Destroy() end)

-- CONTEXT MENU
local ctxMenu = Instance.new("Frame")
ctxMenu.Size = UDim2.new(0, 120, 0, 70)
ctxMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 15) 
ctxMenu.BorderSizePixel = 0
ctxMenu.Visible = false
ctxMenu.ZIndex = 10
ctxMenu.Parent = screenGui
Instance.new("UICorner", ctxMenu).CornerRadius = UDim.new(0, 8)
local ctxStroke = Instance.new("UIStroke", ctxMenu)
ctxStroke.Color = themeColor
ctxStroke.Thickness = 1
ctxStroke.Transparency = 0.5
local ctxTarget = "" 

local function createCtxBtn(text, y, mode)
    local b = Instance.new("TextButton", ctxMenu)
    b.Size = UDim2.new(1, -10, 0, 30)
    b.Position = UDim2.new(0, 5, 0, y + 5)
    b.BackgroundTransparency = 1 
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 13
    b.MouseButton1Click:Connect(function()
        if ctxTarget == "fly" then 
            flyMode = mode 
        else 
            noclipMode = mode 
        end
        ctxMenu.Visible = false
    end)
end

createCtxBtn("Toggle Mode", 0, "Toggle")
createCtxBtn("Hold Mode", 30, "Hold")

flyB.MouseButton2Click:Connect(function() 
    ctxTarget = "fly"
    ctxMenu.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y)
    ctxMenu.Visible = true 
end)

noclipB.MouseButton2Click:Connect(function() 
    ctxTarget = "noclip"
    ctxMenu.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y)
    ctxMenu.Visible = true 
end)

-- === SILENT AIM HOOK ===
RunService.RenderStepped:Connect(function()
    hookMouse()
end)

-- PARTICLE LOGIC
local pParts = {}
task.spawn(function()
    while true do
        if particlesEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            if #pParts < 3 then
                local p = Instance.new("Part")
                p.Size = Vector3.new(0.4, 0.4, 0.4)
                p.Shape = Enum.PartType.Ball
                p.CanCollide = false
                p.Anchored = true
                p.Material = Enum.Material.Neon
                p.Parent = workspace
                local trail = Instance.new("Trail", p)
                local a0 = Instance.new("Attachment", p)
                a0.Position = Vector3.new(0,0.2,0)
                local a1 = Instance.new("Attachment", p)
                a1.Position = Vector3.new(0,-0.2,0)
                trail.Attachment0 = a0
                trail.Attachment1 = a1
                trail.Lifetime = 0.5
                trail.WidthScale = NumberSequence.new(1, 0)
                table.insert(pParts, {obj = p, angle = #pParts * 120, trail = trail})
            end
            for _, data in ipairs(pParts) do
                data.angle = data.angle + 5
                local x = math.cos(math.rad(data.angle)) * 3.5
                local z = math.sin(math.rad(data.angle)) * 3.5
                data.obj.CFrame = CFrame.new(hrp.Position + Vector3.new(x, math.sin(tick()*2)*2, z))
                data.obj.Color = themeColor
                data.trail.Color = ColorSequence.new(themeColor)
            end
        else 
            for _, d in ipairs(pParts) do 
                pcall(function() d.obj:Destroy() end)
            end 
            pParts = {} 
        end
        task.wait()
    end
end)

-- CORE LOGIC
local jitterTime = 0
local wasOnGround = false
local lastBhopSpeedUpdate = 0

RunService.RenderStepped:Connect(function()
    local fM = flyMode == "Toggle" and "[T]" or "[H]"
    local nM = noclipMode == "Toggle" and "[T]" or "[H]"
    if not isBindingFly then flyB.Text = fM .. " Fly: " .. flyKey.Name end
    if not isBindingNoclip then noclipB.Text = nM .. " Noclip: " .. noclipKey.Name end

    ctxStroke.Color = themeColor

    -- ОБНОВЛЕНИЕ KILL AURA - ТЕПЕРЬ РАБОТАЕТ В ЛЮБУЮ СТОРОНУ
    updateKillAura()

    -- ОБНОВЛЕНИЕ HUD ИНФОРМАЦИИ
    local ping = LocalPlayer:GetNetworkPing() * 1000
    pingText.Text = string.format("Ping: %.0fms", ping)
    fpsText.Text = string.format("FPS: %.0f", 1/RunService.RenderStepped:Wait())

    -- ОБНОВЛЕНИЕ ТЕКУЩЕЙ ЦЕЛИ
    if autoFireEnabled or aimbotEnabled or silentAimEnabled or killAuraEnabled then
        local target = killAuraTarget or getClosestEnemy()
        if target then
            currentTarget = target
        end
    end

    -- ОБНОВЛЕНИЕ TARGET HUD
    if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("Humanoid") then
        local humanoid = currentTarget.Character.Humanoid
        targetHealth = humanoid.Health
        targetMaxHealth = humanoid.MaxHealth
        targetName = currentTarget.Name
        targetDisplayName = currentTarget.DisplayName or currentTarget.Name
        
        targetNameLabel.Text = targetDisplayName
        targetHealthFill.Size = UDim2.new(targetHealth / targetMaxHealth, 0, 1, 0)
        targetHealthText.Text = math.floor(targetHealth / targetMaxHealth * 100) .. "%"
        
        if targetHealth / targetMaxHealth > 0.6 then
            targetHealthFill.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        elseif targetHealth / targetMaxHealth > 0.3 then
            targetHealthFill.BackgroundColor3 = Color3.fromRGB(255, 255, 50)
        else
            targetHealthFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        end
        
        if showTargetHUD then
            targetHUD.Visible = true
        end
        
        if currentTarget.Character and currentTarget.Character:FindFirstChild("Head") then
            targetHeadIcon.BackgroundColor3 = currentTarget.Character.Head.BrickColor.Color
        end
        
        if targetHealth <= 0 and not targetDied then
            targetDied = true
            targetEZMessage.Text = ezMessages[math.random(#ezMessages)]
            targetEZMessage.Visible = true
            
            for i = 1, 5 do
                task.wait(0.1)
                createEZMessage()
            end
            
            task.spawn(function()
                task.wait(3)
                targetEZMessage.Visible = false
            end)
        end
    else
        targetHUD.Visible = false
        currentTarget = nil
    end

    -- ОБНОВЛЕНИЕ TARGET ESP
    if targetESPEnabled and currentTarget then
        updateTargetESP()
    else
        clearTargetESP()
    end

    -- Анимация летающих EZ надписей
    for i, ez in ipairs(ezLabels) do
        if ez.label and ez.label.Parent then
            local pos = ez.label.Position
            ez.label.Position = UDim2.new(pos.X.Scale, pos.X.Offset + ez.velocity.X, pos.Y.Scale, pos.Y.Offset + ez.velocity.Y)
            ez.velocity = Vector2.new(ez.velocity.X, ez.velocity.Y + 0.2)
            ez.label.TextTransparency = ez.label.TextTransparency + 0.01
            
            if ez.label.TextTransparency >= 1 then
                ez.label:Destroy()
                table.remove(ezLabels, i)
            end
        end
    end

    -- УЛУЧШЕННЫЙ БАНИХОП (ручные прыжки с набором скорости +1)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local hum = LocalPlayer.Character.Humanoid
        local currentTime = tick()
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if bhopEnabled and not flying then
            -- Проверяем, находится ли игрок на земле
            local onGround = hum.FloorMaterial ~= Enum.Material.Air and hum.FloorMaterial ~= nil
            
            -- Если игрок прыгнул (был на земле и теперь в воздухе) и движется
            if wasOnGround and not onGround and hum.MoveDirection.Magnitude > 0 then
                -- Проверяем, прошло ли достаточно времени с последнего прыжка
                if currentTime - lastJumpTime >= jumpCooldown then
                    -- Увеличиваем скорость на 1
                    currentBhopSpeed = math.min(currentBhopSpeed + bhopBoost, maxBhopSpeed)
                    lastJumpTime = currentTime
                    
                    -- Визуальный эффект набора скорости (цифра +1)
                    if rootPart then
                        local billboard = Instance.new("BillboardGui")
                        billboard.Adornee = rootPart
                        billboard.Size = UDim2.new(0, 50, 0, 30)
                        billboard.StudsOffset = Vector3.new(0, 3, 0)
                        billboard.AlwaysOnTop = true
                        billboard.Parent = rootPart
                        
                        local text = Instance.new("TextLabel", billboard)
                        text.Size = UDim2.new(1, 0, 1, 0)
                        text.BackgroundTransparency = 1
                        text.Text = "+1"
                        text.TextColor3 = Color3.fromRGB(0, 255, 0)
                        text.Font = Enum.Font.GothamBold
                        text.TextSize = 20
                        text.TextStrokeTransparency = 0
                        text.TextStrokeColor3 = Color3.new(0, 0, 0)
                        
                        -- Анимация исчезновения
                        task.spawn(function()
                            for i = 1, 10 do
                                text.TextTransparency = text.TextTransparency + 0.1
                                text.Position = text.Position + UDim2.new(0, 0, 0, -1)
                                task.wait(0.03)
                            end
                            billboard:Destroy()
                        end)
                    end
                    
                    -- Создаем маленький шарик эффекта
                    local effect = Instance.new("Part")
                    effect.Size = Vector3.new(0.5, 0.5, 0.5)
                    effect.Shape = Enum.PartType.Ball
                    effect.Color = Color3.fromRGB(0, 255, 0)
                    effect.Material = Enum.Material.Neon
                    effect.CanCollide = false
                    effect.Anchored = true
                    effect.CFrame = rootPart.CFrame * CFrame.new(0, -2, 0)
                    effect.Parent = workspace
                    game:GetService("Debris"):AddItem(effect, 0.2)
                end
            end
            
            -- Применяем скорость
            hum.WalkSpeed = currentBhopSpeed
            
            -- Если игрок не двигается, сбрасываем скорость
            if hum.MoveDirection.Magnitude == 0 then
                currentBhopSpeed = walkspeed
            end
            
            -- Обновляем состояние земли
            wasOnGround = onGround
        else
            -- Если банихоп выключен
            hum.WalkSpeed = walkspeed
            currentBhopSpeed = walkspeed
            wasOnGround = false
        end
    end

    -- ANTI-AIM С ИСПРАВЛЕНИЯМИ
    if LocalPlayer.Character and antiAimEnabled then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local torso = LocalPlayer.Character:FindFirstChild("Torso") or LocalPlayer.Character:FindFirstChild("UpperTorso")
        local head = LocalPlayer.Character:FindFirstChild("Head")
        local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if rootPart and humanoid and humanoid.Health > 0 and humanoidRootPart then
            -- JITTER - крутит все тело
            if jitterEnabled then
                jitterTime = jitterTime + 0.05
                local jitterAmount = math.sin(jitterTime) * math.rad(jitterValue/2)
                -- Крутим все тело через HumanoidRootPart
                humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, jitterAmount, 0)
            end
            
            -- PITCH - только до пояса (верхняя часть тела)
            if pitchMode ~= "None" then
                local currentTime = tick()
                local targetPitch = pitchAngle
                
                if pitchMode == "Down" then
                    targetPitch = 0.8 -- Нормальный наклон вниз (а не откидывание назад)
                    
                elseif pitchMode == "Up" then
                    targetPitch = -0.5 -- Нормальный наклон вверх
                    
                elseif pitchMode == "Random" then
                    -- Меняем каждые 50 мс
                    if currentTime - lastPitchChange >= 0.05 then
                        targetPitch = (math.random() * 1.5) - 0.7
                        
                        -- Рандомное перемещение хитбокса в разные части тела
                        if currentTarget and currentTarget.Character then
                            local newHitboxPart = getRandomHitboxPart(currentTarget.Character)
                            if newHitboxPart then
                                hitboxPart = newHitboxPart.Name
                                
                                -- Создаем визуальный эффект на новой части тела
                                local effect = Instance.new("Part")
                                effect.Size = Vector3.new(1, 1, 1)
                                effect.Shape = Enum.PartType.Ball
                                effect.Color = themeColor
                                effect.Material = Enum.Material.Neon
                                effect.CanCollide = false
                                effect.Anchored = true
                                effect.CFrame = newHitboxPart.CFrame
                                effect.Parent = workspace
                                game:GetService("Debris"):AddItem(effect, 0.1)
                                
                                -- Обновляем таргет для аима
                                if aimbotEnabled or silentAimEnabled then
                                    -- Временно меняем цель для аима
                                    if silentAimEnabled then
                                        silentAimTarget = currentTarget
                                        -- Будем целиться в эту часть тела
                                    end
                                end
                            end
                        end
                        
                        lastPitchChange = currentTime
                    end
                end
                
                -- Применяем питч ТОЛЬКО к верхней части тела (до пояса)
                if pitchMode == "Down" or pitchMode == "Up" then
                    if torso then
                        -- Ищем сустав который соединяет торс с корнем (пояс)
                        local waist = torso:FindFirstChild("Waist") or torso:FindFirstChild("Root")
                        if waist and waist:IsA("Motor6D") then
                            -- Меняем только наклон верхней части тела, ноги остаются прямыми
                            waist.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(targetPitch, 0, 0)
                        end
                    end
                    
                    -- Голова тоже наклоняется но меньше
                    if head then
                        local neck = head:FindFirstChild("Neck")
                        if neck and neck:IsA("Motor6D") then
                            neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(targetPitch * 0.3, 0, 0)
                        end
                    end
                elseif pitchMode == "Random" then
                    -- Для рандома тоже применяем питч только к верхней части
                    if torso then
                        local waist = torso:FindFirstChild("Waist") or torso:FindFirstChild("Root")
                        if waist and waist:IsA("Motor6D") then
                            waist.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(targetPitch, 0, 0)
                        end
                    end
                end
            else
                -- Сброс питча
                if torso then
                    local waist = torso:FindFirstChild("Waist") or torso:FindFirstChild("Root")
                    if waist and waist:IsA("Motor6D") then
                        waist.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, 0)
                    end
                end
                if head then
                    local neck = head:FindFirstChild("Neck")
                    if neck and neck:IsA("Motor6D") then
                        neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, 0)
                    end
                end
            end
        end
    end
    
    -- Исправленный AIMBOT (тянет и камеру и курсор)
    if aimbotEnabled and aimbotActiveToggle then
        local cameraMode = getCameraMode()
        local t = getClosestEnemy()
        
        if t and t.Character then
            local targetPart = t.Character:FindFirstChild("Head")
            
            -- Если есть активный рандом хитбокс, целимся в него
            if hitboxPart and t.Character:FindFirstChild(hitboxPart) then
                targetPart = t.Character:FindFirstChild(hitboxPart)
            end
            
            if targetPart then
                -- Всегда тянем камеру
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPart.Position), aimbotSmoothness)
                
                -- В 3 лице дополнительно тянем курсор
                if cameraMode == "ThirdPerson" then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        -- Двигаем курсор к врагу
                        local currentMousePos = UserInputService:GetMouseLocation()
                        local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                        local newPos = currentMousePos:Lerp(targetPos, aimbotSmoothness)
                        
                        -- Эмулируем движение мыши через mousemoverel
                        local delta = newPos - currentMousePos
                        if delta.Magnitude > 0.5 then
                            mousemoverel(delta.X, delta.Y)
                        end
                    end
                end
            end
        end
    end

    -- ESP
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local char = p.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local humanoid = char:FindFirstChild("Humanoid")
            
            if hrp and humanoid and humanoid.Health > 0 then
                if espEnabled then
                    applyHitboxes(char, hitboxSize)
                    
                    if not char:FindFirstChild("DeepSenseHighlight") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "DeepSenseHighlight"
                        hl.FillColor = themeColor
                        hl.OutlineColor = Color3.new(1, 1, 1)
                        hl.Parent = char
                    else
                        char.DeepSenseHighlight.FillColor = themeColor
                    end
                    
                    if head then
                        createNameTag(p)
                        local tag = head:FindFirstChild("DeepSenseNameTag")
                        if tag and tag:FindFirstChild("TextLabel") then
                            tag.Enabled = true
                            tag.TextLabel.TextColor3 = themeColor
                        end
                    end
                else
                    resetHitboxes(char)
                    if char:FindFirstChild("DeepSenseHighlight") then 
                        char.DeepSenseHighlight:Destroy() 
                    end
                    if head and head:FindFirstChild("DeepSenseNameTag") then 
                        head.DeepSenseNameTag.Enabled = false 
                    end
                end
            end
        end
    end
end)

local lastShot = 0
RunService.Heartbeat:Connect(function()
    if autoFireEnabled and isAimingAtEnemy() and tick() - lastShot > autoFireDelay/1000 then
        lastShot = tick()
        VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
    end
end)

local function toggleFly(force)
    if force ~= nil then 
        flying = force 
    else 
        flying = not flying 
    end
    updateModulesList()
    
    if flying and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = LocalPlayer.Character.HumanoidRootPart
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        
        if bv then pcall(function() bv:Destroy() end) end
        if bg then pcall(function() bg:Destroy() end) end
        
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Parent = root
        
        bg = Instance.new("BodyGyro") 
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.Parent = root
        
        if humanoid then
            humanoid.PlatformStand = true
        end
        
        task.spawn(function()
            while flying and bv and bg and bv.Parent and bg.Parent do
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
                
                if dir.Magnitude > 0 then
                    dir = dir.Unit * flySpeed
                else
                    dir = Vector3.zero
                end
                
                bv.Velocity = dir
                bg.CFrame = Camera.CFrame
                task.wait()
            end
        end)
    else
        if bv then pcall(function() bv:Destroy() end) end
        if bg then pcall(function() bg:Destroy() end) end
        bv, bg = nil, nil
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then 
            LocalPlayer.Character.Humanoid.PlatformStand = false 
        end
    end
end

local function setNoclip(val)
    noclip = val
    updateModulesList()
    
    if noclip then 
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function() 
                if LocalPlayer.Character then 
                    for _, p in pairs(LocalPlayer.Character:GetDescendants()) do 
                        if p:IsA("BasePart") then 
                            p.CanCollide = false 
                        end 
                    end 
                end
            end)
        end
    else 
        if noclipConnection then 
            noclipConnection:Disconnect()
            noclipConnection = nil 
        end
        
        if LocalPlayer.Character then 
            for _, p in pairs(LocalPlayer.Character:GetDescendants()) do 
                if p:IsA("BasePart") then 
                    p.CanCollide = true 
                end 
            end 
        end
    end
end

local isBindingFly, isBindingNoclip, isBindingAuto, isBindingAim, isBindingSilent, isBindingKillAura = false, false, false, false, false, false

flyB.MouseButton1Click:Connect(function() 
    isBindingFly = true
    flyB.Text = "..."
end)

noclipB.MouseButton1Click:Connect(function() 
    isBindingNoclip = true
    noclipB.Text = "..."
end)

autoFireB.MouseButton1Click:Connect(function() 
    isBindingAuto = true
    autoFireB.Text = "..."
end)

killAuraB.MouseButton1Click:Connect(function() 
    isBindingKillAura = true
    killAuraB.Text = "..."
end)

aimbotB.MouseButton1Click:Connect(function() 
    isBindingAim = true
    aimbotB.Text = "..."
end)

silentAimB.MouseButton1Click:Connect(function() 
    isBindingSilent = true
    silentAimB.Text = "..."
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.Insert then 
        mainFrame.Visible = not mainFrame.Visible
        ctxMenu.Visible = false 
        return 
    end
    
    if isBindingFly and input.UserInputType == Enum.UserInputType.Keyboard then 
        flyKey = input.KeyCode
        flyB.Text = "Fly: " .. flyKey.Name
        isBindingFly = false 
        return 
    end
    
    if isBindingNoclip and input.UserInputType == Enum.UserInputType.Keyboard then 
        noclipKey = input.KeyCode
        noclipB.Text = "Noclip: " .. noclipKey.Name
        isBindingNoclip = false 
        return 
    end
    
    if isBindingAuto and input.UserInputType == Enum.UserInputType.Keyboard then 
        autoFireKey = input.KeyCode
        autoFireB.Text = "Auto Fire Bind: " .. autoFireKey.Name
        isBindingAuto = false 
        return 
    end
    
    if isBindingKillAura and input.UserInputType == Enum.UserInputType.Keyboard then
        killAuraKey = input.KeyCode
        killAuraB.Text = "Kill Aura Bind: " .. killAuraKey.Name
        isBindingKillAura = false 
        return 
    end
    
    if isBindingAim then 
        aimbotKey = (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType)
        aimbotB.Text = "Aimbot Bind: " .. aimbotKey.Name
        isBindingAim = false 
        return 
    end
    
    if isBindingSilent then
        silentAimKey = input.KeyCode
        silentAimB.Text = "Silent Aim Bind: " .. silentAimKey.Name
        isBindingSilent = false
        return
    end
    
    if gpe then return end
    
    if input.KeyCode == flyKey then 
        if flyMode == "Toggle" then 
            toggleFly() 
        else 
            toggleFly(true) 
        end 
    end
    
    if input.KeyCode == noclipKey then 
        if noclipMode == "Toggle" then 
            setNoclip(not noclip) 
        else 
            setNoclip(true) 
        end 
    end
    
    if input.KeyCode == autoFireKey then
        autoFireEnabled = not autoFireEnabled
        updateModulesList()
    end
    
    if input.KeyCode == killAuraKey then
        killAuraEnabled = not killAuraEnabled
        updateModulesList()
    end
    
    if input.KeyCode == silentAimKey then
        silentAimActiveToggle = not silentAimActiveToggle
        if not silentAimActiveToggle then
            unhookMouse()
        end
        updateModulesList()
    end
    
    if (input.UserInputType == aimbotKey or input.KeyCode == aimbotKey) and aimbotEnabled then 
        aimbotActiveToggle = not aimbotActiveToggle
        updateModulesList()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == flyKey and flyMode == "Hold" then 
        toggleFly(false) 
    end
    if input.KeyCode == noclipKey and noclipMode == "Hold" then 
        setNoclip(false) 
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and ctxMenu.Visible then 
        task.wait()
        ctxMenu.Visible = false 
    end
end)

-- Очистка при уничтожении GUI
screenGui.Destroying:Connect(function()
    if noclipConnection then noclipConnection:Disconnect() end
    toggleFly(false)
    setNoclip(false)
    clearAccessory()
    unhookMouse()
    clearTargetESP()
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character then
            resetHitboxes(p.Character)
        end
    end
    for _, ez in ipairs(ezLabels) do
        pcall(function() ez.label:Destroy() end)
    end
end)

updateModulesList()