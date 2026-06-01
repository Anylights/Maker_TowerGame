-- ============================================================================
-- PathRenderer.lua — 棕色路径地块渲染
-- ============================================================================
-- 将关卡路径数据渲染为棕色地面方块。
-- 使用 StaticModel + Box.mdl 来渲染每个格子（与地板相同方式，确保可见）。
-- 为了性能，使用 2x2 的格子大小而非 1x1。
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS

local M = {}

-- 路径渲染父节点
local pathParentNode_ = nil

-- 记录哪些格子属于路径
-- pathCells_["x,z"] = true (原始1x1坐标)
local pathCells_ = {}

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 计算点到线段的最短距离
local function PointToSegmentDist(px, pz, ax, az, bx, bz)
    local dx = bx - ax
    local dz = bz - az
    local lenSq = dx * dx + dz * dz
    if lenSq < 0.0001 then
        local ex = px - ax
        local ez = pz - az
        return math.sqrt(ex * ex + ez * ez)
    end
    local t = ((px - ax) * dx + (pz - az) * dz) / lenSq
    t = math.max(0, math.min(1, t))
    local projX = ax + t * dx
    local projZ = az + t * dz
    local ex = px - projX
    local ez = pz - projZ
    return math.sqrt(ex * ex + ez * ez)
end

--- 判断一个格子中心是否在路径走廊内
local function IsInPathCorridor(gx, gz, path)
    local halfW = path.width * 0.5
    local wps = path.waypoints
    for i = 1, #wps - 1 do
        local a = wps[i]
        local b = wps[i + 1]
        local dist = PointToSegmentDist(gx, gz, a.x, a.z, b.x, b.z)
        if dist <= halfW then
            return true
        end
    end
    return false
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 渲染路径（传入当前关卡的路径列表）
--- @param levelData table 关卡数据（包含 paths 字段）
function M.RenderPaths(levelData)
    M.Clear()

    if not levelData or not levelData.paths then
        print("[PathRenderer] ERROR: levelData or paths is nil!")
        return
    end
    print(string.format("[PathRenderer] RenderPaths: %d paths", #levelData.paths))

    pathCells_ = {}

    -- 使用 1x1 网格
    local step = 1
    local allCells = {}

    for _, path in ipairs(levelData.paths) do
        local minX, maxX = math.huge, -math.huge
        local minZ, maxZ = math.huge, -math.huge
        for _, wp in ipairs(path.waypoints) do
            minX = math.min(minX, wp.x)
            maxX = math.max(maxX, wp.x)
            minZ = math.min(minZ, wp.z)
            maxZ = math.max(maxZ, wp.z)
        end
        local halfW = path.width * 0.5
        minX = math.floor((minX - halfW) / step) * step
        maxX = math.ceil((maxX + halfW) / step) * step
        minZ = math.floor((minZ - halfW) / step) * step
        maxZ = math.ceil((maxZ + halfW) / step) * step

        -- 裁剪到地图范围
        minX = math.max(-CONFIG.MapHalfW, minX)
        maxX = math.min(CONFIG.MapHalfW, maxX)
        minZ = math.max(-CONFIG.MapHalfH, minZ)
        maxZ = math.min(CONFIG.MapHalfH, maxZ)

        for gx = minX, maxX, step do
            for gz = minZ, maxZ, step do
                local key = gx .. "," .. gz
                if not pathCells_[key] then
                    -- 检查格子中心是否在走廊内
                    if IsInPathCorridor(gx, gz, path) then
                        pathCells_[key] = true
                        table.insert(allCells, { x = gx, z = gz })
                    end
                end
            end
        end
    end

    print(string.format("[PathRenderer] Found %d path cells (step=%d)", #allCells, step))
    if #allCells == 0 then return end

    -- 创建父节点
    pathParentNode_ = GS.scene:CreateChild("PathTiles")

    -- 共享材质 — 棕色无光照（和地板完全相同方式）
    local pathMat = Material:new()
    pathMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    -- 明亮的棕色: sRGB约(0.72, 0.50, 0.30) → linear
    pathMat:SetShaderParameter("MatDiffColor", Variant(Vector4(0.48, 0.21, 0.07, 1.0)))

    -- 用 Box.mdl 渲染每个格子（和地板完全相同的方式，确保可见）
    local boxModel = cache:GetResource("Model", "Models/Box.mdl")
    local tileHeight = 0.12  -- 格子厚度
    local tileScale = step * 0.95  -- 略小于step，留缝隙

    for _, cell in ipairs(allCells) do
        local tileNode = pathParentNode_:CreateChild("Tile")
        -- Box.mdl 中心在原点，尺寸1x1x1，缩放后高度=tileHeight
        -- 放在 Y = tileHeight/2 使底面在 Y=0（地板顶面）
        tileNode.position = Vector3(cell.x, tileHeight * 0.5, cell.z)
        tileNode.scale = Vector3(tileScale, tileHeight, tileScale)

        local sm = tileNode:CreateComponent("StaticModel")
        sm:SetModel(boxModel)
        sm:SetMaterial(pathMat)
        sm.castShadows = false
    end

    print(string.format("[PathRenderer] Rendered %d tiles as Box.mdl", #allCells))

    -- 同时记录1x1网格用于IsPathCell查询
    for _, path in ipairs(levelData.paths) do
        local minX2, maxX2 = math.huge, -math.huge
        local minZ2, maxZ2 = math.huge, -math.huge
        for _, wp in ipairs(path.waypoints) do
            minX2 = math.min(minX2, wp.x)
            maxX2 = math.max(maxX2, wp.x)
            minZ2 = math.min(minZ2, wp.z)
            maxZ2 = math.max(maxZ2, wp.z)
        end
        local halfW2 = path.width * 0.5
        minX2 = math.floor(minX2 - halfW2)
        maxX2 = math.ceil(maxX2 + halfW2)
        minZ2 = math.floor(minZ2 - halfW2)
        maxZ2 = math.ceil(maxZ2 + halfW2)
        for gx = minX2, maxX2 do
            for gz = minZ2, maxZ2 do
                if IsInPathCorridor(gx, gz, path) then
                    pathCells_[gx .. "," .. gz] = true
                end
            end
        end
    end
end

--- 清除路径渲染
function M.Clear()
    if pathParentNode_ then
        pathParentNode_:Remove()
        pathParentNode_ = nil
    end
    pathCells_ = {}
end

--- 查询某格子是否属于路径
function M.IsPathCell(gx, gz)
    return pathCells_[gx .. "," .. gz] == true
end

--- 获取路径格子集合
function M.GetPathCells()
    return pathCells_
end

return M
