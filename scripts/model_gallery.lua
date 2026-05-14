-- ============================================================================
-- 模型验证画廊 - 展示所有导入的 Kenney Tower Defense 模型
-- ============================================================================

local UI = require("urhox-libs/UI")

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
local yaw_ = -30.0
local pitch_ = 25.0

local CONFIG = {
    Title = "TD Model Gallery",
    CameraSpeed = 10.0,
    MouseSensitivity = 0.1,
}

-- 所有导入的模型列表（按类别分组）
local MODEL_GROUPS = {
    {
        name = "Tiles (地图块)",
        models = {
            "tile", "tile-straight", "tile-corner-round", "tile-corner-square",
            "tile-crossing", "tile-split", "tile-end-round",
            "tile-spawn", "tile-spawn-round",
            "tile-crystal", "tile-dirt", "tile-rock", "tile-tree",
        }
    },
    {
        name = "Towers (塔基)",
        models = {
            "tower-round-base", "tower-round-crystals", "tower-round-top-a",
            "tower-square-bottom-a", "tower-square-build-a", "tower-square-top-a",
        }
    },
    {
        name = "Weapons (武器)",
        models = {
            "weapon-cannon", "weapon-ballista", "weapon-catapult", "weapon-turret",
        }
    },
    {
        name = "Ammo (弹药)",
        models = {
            "weapon-ammo-cannonball", "weapon-ammo-boulder",
            "weapon-ammo-arrow", "weapon-ammo-bullet",
        }
    },
    {
        name = "Enemies (敌人)",
        models = {
            "enemy-ufo-a", "enemy-ufo-b", "enemy-ufo-c", "enemy-ufo-d",
        }
    },
    {
        name = "Details (装饰)",
        models = {
            "detail-crystal", "detail-rocks", "detail-tree", "detail-dirt",
            "selection-a",
        }
    },
}

function Start()
    graphics.windowTitle = CONFIG.Title
    InitUI()
    CreateScene()
    SetupCamera()
    CreateGallery()
    CreateUI()
    SubscribeToEvent("Update", "HandleUpdate")
    print("=== Model Gallery Started ===")
end

function Stop()
    UI.Shutdown()
end

function InitUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    -- 光照
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    -- 地面
    local floor = scene_:CreateChild("Floor")
    floor.position = Vector3(0, -0.01, 0)
    floor.scale = Vector3(200, 0.02, 200)
    local floorModel = floor:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.35, 0.38, 0.32, 1.0)))
    floorMat:SetShaderParameter("Roughness", Variant(0.9))
    floorMat:SetShaderParameter("Metallic", Variant(0.0))
    floorModel:SetMaterial(floorMat)
end

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(8, 6, -10)
    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 500.0
    camera.fov = 60.0
    cameraNode_.rotation = Quaternion(pitch_, yaw_, 0)

    renderer:SetViewport(0, Viewport:new(scene_, camera))
    renderer.hdrRendering = true
end

function CreateGallery()
    local spacing = 2.5    -- 模型间距
    local groupSpacing = 4.0  -- 组间距
    local z = 0.0

    for gi, group in ipairs(MODEL_GROUPS) do
        local x = 0.0

        -- 组标题标记（用一个小立方体+颜色标识）
        local markerNode = scene_:CreateChild("GroupMarker_" .. gi)
        markerNode.position = Vector3(-2.0, 0.3, z)
        markerNode.scale = Vector3(0.3, 0.6, 0.3)
        local markerModel = markerNode:CreateComponent("StaticModel")
        markerModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        local markerMat = Material:new()
        markerMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        -- 每组不同颜色
        local groupColors = {
            Color(0.4, 0.7, 0.3, 1),   -- 绿-Tiles
            Color(0.3, 0.5, 0.8, 1),   -- 蓝-Towers
            Color(0.8, 0.4, 0.2, 1),   -- 橙-Weapons
            Color(0.7, 0.7, 0.2, 1),   -- 黄-Ammo
            Color(0.8, 0.2, 0.2, 1),   -- 红-Enemies
            Color(0.6, 0.4, 0.7, 1),   -- 紫-Details
        }
        markerMat:SetShaderParameter("MatDiffColor", Variant(groupColors[gi] or Color(0.5, 0.5, 0.5, 1)))
        markerMat:SetShaderParameter("Roughness", Variant(0.3))
        markerMat:SetShaderParameter("Metallic", Variant(0.8))
        markerModel:SetMaterial(markerMat)

        -- 放置该组的模型
        for mi, modelName in ipairs(group.models) do
            local mdlPath = "Meshes/TD/" .. modelName .. ".mdl"
            local matPath = "Materials/TD/" .. modelName .. "_00_colormap.xml"

            local node = scene_:CreateChild(modelName)
            node.position = Vector3(x, 0, z)

            local staticModel = node:CreateComponent("StaticModel")
            local mdl = cache:GetResource("Model", mdlPath)
            if mdl ~= nil then
                staticModel:SetModel(mdl)
                local mat = cache:GetResource("Material", matPath)
                if mat ~= nil then
                    staticModel:SetMaterial(mat)
                end
                staticModel.castShadows = true

                -- 输出模型尺寸信息
                local bb = staticModel.boundingBox
                print(string.format("  [%s] size=(%.2f, %.2f, %.2f)", 
                    modelName, bb.size.x, bb.size.y, bb.size.z))
            else
                print("  [MISSING] " .. mdlPath)
            end

            x = x + spacing
        end

        print(string.format("=== Group %d: %s (%d models) ===", gi, group.name, #group.models))
        z = z + groupSpacing
    end

    -- 展示塔组合：底座 + 武器叠加
    CreateTowerCombo(Vector3(20, 0, 0), "tower-round-base", "tower-round-crystals", "Round Tower")
    CreateTowerCombo(Vector3(23, 0, 0), "tower-square-bottom-a", "weapon-cannon", "Square + Cannon")
    CreateTowerCombo(Vector3(26, 0, 0), "tower-square-bottom-a", "weapon-ballista", "Square + Ballista")
    CreateTowerCombo(Vector3(29, 0, 0), "tower-square-bottom-a", "weapon-turret", "Square + Turret")
    CreateTowerCombo(Vector3(32, 0, 0), "tower-square-bottom-a", "weapon-catapult", "Square + Catapult")
    print("=== Tower Combos created ===")
end

function CreateTowerCombo(pos, baseName, topName, label)
    -- 底座
    local baseNode = scene_:CreateChild(label .. "_base")
    baseNode.position = pos
    local baseModel = baseNode:CreateComponent("StaticModel")
    local baseMdl = cache:GetResource("Model", "Meshes/TD/" .. baseName .. ".mdl")
    if baseMdl then
        baseModel:SetModel(baseMdl)
        local baseMat = cache:GetResource("Material", "Materials/TD/" .. baseName .. "_00_colormap.xml")
        if baseMat then baseModel:SetMaterial(baseMat) end
        baseModel.castShadows = true

        -- 顶部（叠在底座上方）
        local baseHeight = baseModel.boundingBox.size.y
        local topNode = scene_:CreateChild(label .. "_top")
        topNode.position = Vector3(pos.x, baseHeight, pos.z)
        local topModel = topNode:CreateComponent("StaticModel")
        local topMdl = cache:GetResource("Model", "Meshes/TD/" .. topName .. ".mdl")
        if topMdl then
            topModel:SetModel(topMdl)
            local topMat = cache:GetResource("Material", "Materials/TD/" .. topName .. "_00_colormap.xml")
            if topMat then topModel:SetMaterial(topMat) end
            topModel.castShadows = true
        end
    end
end

function CreateUI()
    local uiRoot = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Label {
                text = "Kenney TD Model Gallery | WASD: Move | RMB: Look | Space/C: Up/Down",
                fontSize = 13,
                fontColor = { 255, 255, 200, 220 },
                position = "absolute",
                top = 8, left = 0, right = 0,
                textAlign = "center",
            },
            -- 组名标签
            UI.Panel {
                position = "absolute", bottom = 10, left = 10,
                padding = 8, borderRadius = 6,
                backgroundColor = { 0, 0, 0, 160 },
                children = {
                    UI.Label { text = "Groups (left to right per row):", fontSize = 12, fontColor = {255,255,255,200} },
                    UI.Label { text = "Row 1: Tiles (13)  |  Row 2: Towers (6)", fontSize = 11, fontColor = {200,255,200,180} },
                    UI.Label { text = "Row 3: Weapons (4) |  Row 4: Ammo (4)", fontSize = 11, fontColor = {255,220,180,180} },
                    UI.Label { text = "Row 5: Enemies (4) |  Row 6: Details (5)", fontSize = 11, fontColor = {255,180,180,180} },
                    UI.Label { text = "Right side: Tower combos (base + weapon)", fontSize = 11, fontColor = {180,200,255,180} },
                }
            },
        }
    }
    UI.SetRoot(uiRoot)
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 鼠标右键控制视角
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        yaw_ = yaw_ + input.mouseMoveX * CONFIG.MouseSensitivity
        pitch_ = pitch_ + input.mouseMoveY * CONFIG.MouseSensitivity
        pitch_ = Clamp(pitch_, -89.0, 89.0)
        cameraNode_.rotation = Quaternion(pitch_, yaw_, 0)
    end

    -- WASD 移动
    local speed = CONFIG.CameraSpeed
    if input:GetKeyDown(KEY_SHIFT) then speed = speed * 3.0 end
    if input:GetKeyDown(KEY_W) then cameraNode_:Translate(Vector3(0,0,1) * dt * speed) end
    if input:GetKeyDown(KEY_S) then cameraNode_:Translate(Vector3(0,0,-1) * dt * speed) end
    if input:GetKeyDown(KEY_A) then cameraNode_:Translate(Vector3(-1,0,0) * dt * speed) end
    if input:GetKeyDown(KEY_D) then cameraNode_:Translate(Vector3(1,0,0) * dt * speed) end
    if input:GetKeyDown(KEY_SPACE) then cameraNode_:Translate(Vector3(0,1,0) * dt * speed, TS_WORLD) end
    if input:GetKeyDown(KEY_C) then cameraNode_:Translate(Vector3(0,-1,0) * dt * speed, TS_WORLD) end

    -- 让敌人缓慢旋转以便观察
    for _, name in ipairs({"enemy-ufo-a","enemy-ufo-b","enemy-ufo-c","enemy-ufo-d"}) do
        local node = scene_:GetChild(name)
        if node then node:Rotate(Quaternion(0, 45 * dt, 0)) end
    end
end

function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
