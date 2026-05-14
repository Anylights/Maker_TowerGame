-- ============================================================================
-- Tower.lua — 基础塔放置 / 攻击 / 炮弹 / 悬停 / 放置输入
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")
local EnergyTower = require("EnergyTower")
local Terrain = require("Terrain")

local M = {}

-- ============================================================================
-- 武器模型列表
-- ============================================================================
local WEAPON_MODELS = {
    "weapon-cannon",
    "weapon-ballista",
    "weapon-catapult",
    "weapon-turret",
}

-- ============================================================================
-- 经济
-- ============================================================================

function M.GetTowerCost()
    local n = #GS.towers
    return CONFIG.BaseCost + CONFIG.CostLinear * n + CONFIG.CostQuad * n * n
end

--- 计算指定塔的建造成本 (根据它是第几座塔时的造价)
--- @param towerIndex number 塔在 GS.towers 中的索引 (1-based)
function M.GetTowerOriginalCost(towerIndex)
    -- 建造第 n 座塔的成本 = BaseCost + CostLinear*(n-1) + CostQuad*(n-1)^2
    local n = towerIndex - 1
    return CONFIG.BaseCost + CONFIG.CostLinear * n + CONFIG.CostQuad * n * n
end

-- ============================================================================
-- 创建塔模型
-- ============================================================================

local function CreateTowerModel(node)
    local baseChild = node:CreateChild("TowerBase")
    local baseModel = baseChild:CreateComponent("StaticModel")
    baseModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-square-bottom-a.mdl"))
    baseModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-square-bottom-a_00_colormap.xml"))
    baseModel.castShadows = true

    local weaponName = WEAPON_MODELS[math.random(1, #WEAPON_MODELS)]
    local weaponChild = node:CreateChild("TowerWeapon")
    weaponChild.position = Vector3(0, 0.5, 0)
    local weaponModel = weaponChild:CreateComponent("StaticModel")
    weaponModel:SetModel(cache:GetResource("Model", "Meshes/TD/" .. weaponName .. ".mdl"))
    weaponModel:SetMaterial(cache:GetResource("Material", "Materials/TD/" .. weaponName .. "_00_colormap.xml"))
    weaponModel.castShadows = true
end

-- ============================================================================
-- 放置塔
-- ============================================================================

function M.PlaceBasicTower(gx, gz)
    local cost = M.GetTowerCost()
    if GS.gold < cost then return end
    GS.gold = GS.gold - cost

    local node = GS.scene:CreateChild("Tower_" .. gx .. "_" .. gz)
    node.position = Vector3(gx, 0, gz)
    CreateTowerModel(node)

    local dist = math.sqrt(gx * gx + gz * gz)
    local tower = {
        node = node,
        gx = gx,
        gz = gz,
        dist = dist,
        delivered = 0,
        linePwr = 0,
        ratio = 0,
        cooldown = 0,
        weaponYaw = 0,
        targetYaw = nil,
    }
    table.insert(GS.towers, tower)

    EnergyTower.RecalculateEnergy()
    EnergyTower.RebuildEnergyLines()

    print(string.format("Tower built at (%d, %d), dist=%.1f, cost=%d, gold=%d",
        gx, gz, dist, cost, GS.gold))
end

-- ============================================================================
-- 塔攻击
-- ============================================================================

local ROTATE_SPEED = 720

function M.UpdateTowerAttacks(dt)
    for _, tower in ipairs(GS.towers) do
        -- 平滑旋转
        if tower.targetYaw then
            local weaponNode = tower.node:GetChild("TowerWeapon", false)
            if weaponNode then
                local diff = Utils.NormalizeAngle(tower.targetYaw - tower.weaponYaw)
                local maxStep = ROTATE_SPEED * dt
                if math.abs(diff) <= maxStep then
                    tower.weaponYaw = tower.targetYaw
                else
                    tower.weaponYaw = tower.weaponYaw + (diff > 0 and maxStep or -maxStep)
                end
                weaponNode.rotation = Quaternion(tower.weaponYaw, Vector3.UP)
            end
        end

        -- 寻找最近怪物
        local bestM = nil
        local bestDist = CONFIG.TowerRange + 1
        for _, m in ipairs(GS.monsters) do
            if m.node and m.hp > 0 then
                local dx = m.node.position.x - tower.gx
                local dz = m.node.position.z - tower.gz
                local d = math.sqrt(dx * dx + dz * dz)
                if d <= CONFIG.TowerRange and d < bestDist then
                    bestDist = d
                    bestM = m
                end
            end
        end

        -- 跟踪方向
        if bestM then
            local tpos = bestM.node.position
            local dx = tpos.x - tower.gx
            local dz = tpos.z - tower.gz
            tower.targetYaw = math.deg(math.atan(dx, dz)) + 180
        end

        -- 没有怪物目标时，寻找范围内的场景物件
        ---@type table|nil
        local bestTerrain = nil
        if not bestM and GS.terrainObjects then
            local bestTerrDist = CONFIG.TowerRange + 1
            for _, tObj in ipairs(GS.terrainObjects) do
                if tObj.node and tObj.hp > 0 then
                    local dx = tObj.gx - tower.gx
                    local dz = tObj.gz - tower.gz
                    local d = math.sqrt(dx * dx + dz * dz)
                    if d <= CONFIG.TowerRange and d < bestTerrDist then
                        bestTerrDist = d
                        bestTerrain = tObj
                    end
                end
            end
            -- 跟踪物件方向
            if bestTerrain then
                local dx = bestTerrain.gx - tower.gx
                local dz = bestTerrain.gz - tower.gz
                tower.targetYaw = math.deg(math.atan(dx, dz)) + 180
            end
        end

        -- 开火 (攻速随功率比线性缩放, 最低 30%)
        tower.cooldown = tower.cooldown - dt
        if tower.cooldown <= 0 and (bestM or bestTerrain) then
            local att = EnergyTower.CalcAttenuation(tower.dist)
            local dmg = CONFIG.TowerBaseDmg * att
            -- 邻接 buff: 水晶 power_bonus 增伤
            local buffs = Terrain.GetAdjacentBuffs(tower.gx, tower.gz)
            if buffs.power_bonus > 0 then
                dmg = dmg * (1.0 + buffs.power_bonus)
            end
            if bestM then
                M.FireProjectile(tower, bestM, dmg)
            elseif bestTerrain then
                M.FireProjectileAtTerrain(tower, bestTerrain, dmg)
            end
            -- 攻速: ratio 越高→interval 越短→攻速越快; 下限 30%
            local speedMult = math.max(0.30, tower.ratio * #GS.towers)
            tower.cooldown = CONFIG.TowerFireInterval / speedMult
        end
    end
end

-- ============================================================================
-- 炮弹
-- ============================================================================

function M.FireProjectile(tower, targetMonster, dmg)
    local node = GS.scene:CreateChild("Projectile")
    local s = CONFIG.ProjectileSize / 0.28
    node.scale = Vector3(s, s, s)
    node.position = Vector3(tower.gx, 1.0, tower.gz)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/weapon-ammo-cannonball.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/TD/weapon-ammo-cannonball_00_colormap.xml"))

    local proj = {
        node = node,
        target = targetMonster,
        speed = CONFIG.ProjectileSpeed,
        damage = dmg,
    }
    table.insert(GS.projectiles, proj)
end

function M.FireProjectileAtTerrain(tower, terrainObj, dmg)
    local node = GS.scene:CreateChild("Projectile")
    local s = CONFIG.ProjectileSize / 0.28
    node.scale = Vector3(s, s, s)
    node.position = Vector3(tower.gx, 1.0, tower.gz)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/weapon-ammo-cannonball.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/TD/weapon-ammo-cannonball_00_colormap.xml"))

    local proj = {
        node = node,
        terrainTarget = terrainObj,  -- 场景物件目标 (区别于 target 怪物)
        speed = CONFIG.ProjectileSpeed,
        damage = dmg,
    }
    table.insert(GS.projectiles, proj)
end

function M.UpdateProjectiles(dt)
    local Monster = require("Monster")
    local i = 1
    while i <= #GS.projectiles do
        local p = GS.projectiles[i]
        if not p.node then
            table.remove(GS.projectiles, i)
        elseif p.terrainTarget then
            -- 场景物件目标
            local tt = p.terrainTarget
            if not tt.node or tt.hp <= 0 then
                p.node:Remove()
                table.remove(GS.projectiles, i)
            else
                local pos = p.node.position
                local tpos = tt.node.position
                local dir = tpos - pos
                local dist = dir:Length()
                if dist < 0.4 then
                    Terrain.DamageObject(tt, p.damage)
                    p.node:Remove()
                    table.remove(GS.projectiles, i)
                else
                    dir = dir / dist
                    pos = pos + dir * p.speed * dt
                    p.node.position = pos
                    i = i + 1
                end
            end
        elseif not p.target or not p.target.node or p.target.hp <= 0 then
            p.node:Remove()
            table.remove(GS.projectiles, i)
        else
            local pos = p.node.position
            local tpos = p.target.node.position
            local dir = tpos - pos
            local dist = dir:Length()
            if dist < 0.3 then
                Monster.DamageMonster(p.target, p.damage)
                p.node:Remove()
                table.remove(GS.projectiles, i)
            else
                dir = dir / dist
                pos = pos + dir * p.speed * dt
                p.node.position = pos
                i = i + 1
            end
        end
    end
end

-- ============================================================================
-- 塔拆除
-- ============================================================================

--- 拆除指定塔并返还资源
--- @param towerIndex number 塔在 GS.towers 中的索引 (1-based)
--- @return boolean 是否拆除成功
function M.DemolishTower(towerIndex)
    if towerIndex < 1 or towerIndex > #GS.towers then return false end
    local tower = GS.towers[towerIndex]

    -- 返还比例: 准备阶段 70%, 战斗阶段 40%
    local ratio = 0.4
    if GS.wavePhase == "preparing" then
        ratio = 0.7
    end

    -- 返还金币 (基于该塔的造价)
    local originalCost = M.GetTowerOriginalCost(towerIndex)
    local refund = math.floor(originalCost * ratio + 0.5)
    GS.gold = GS.gold + refund

    -- 移除节点
    if tower.node then
        tower.node:Remove()
    end

    -- 清除对该塔的炮弹引用 (避免悬挂引用)
    for _, p in ipairs(GS.projectiles) do
        -- 炮弹无需特殊处理，target 是怪物不是塔
    end

    table.remove(GS.towers, towerIndex)

    -- 重新计算供能和线段
    EnergyTower.RecalculateEnergy()
    EnergyTower.RebuildEnergyLines()

    print(string.format("[Tower] Demolished tower at (%d,%d) | Refund: %d gold (%.0f%%)",
        tower.gx, tower.gz, refund, ratio * 100))

    return true
end

--- 查找悬停位置的塔索引
--- @return number|nil 塔索引(1-based) 或 nil
function M.GetTowerAtHover()
    for idx, tower in ipairs(GS.towers) do
        if tower.gx == GS.hoverGX and tower.gz == GS.hoverGZ then
            return idx
        end
    end
    return nil
end

-- ============================================================================
-- 悬停 + 放置输入
-- ============================================================================

function M.HandleGridHover()
    local pos = input.mousePosition
    local sx = pos.x / graphics:GetWidth()
    local sy = pos.y / graphics:GetHeight()
    local ray = GS.camera:GetScreenRay(sx, sy)

    if math.abs(ray.direction.y) < 0.001 then
        GS.hoverNode.enabled = false
        GS.hoverOnMap = false
        return
    end

    local t = -ray.origin.y / ray.direction.y
    if t <= 0 then
        GS.hoverNode.enabled = false
        GS.hoverOnMap = false
        return
    end

    local hit = ray.origin + ray.direction * t
    local gx = math.floor(hit.x + 0.5)
    local gz = math.floor(hit.z + 0.5)

    local hw = CONFIG.MapHalfW
    local hh = CONFIG.MapHalfH
    if gx < -hw or gx > hw or gz < -hh or gz > hh then
        GS.hoverNode.enabled = false
        GS.hoverOnMap = false
        return
    end

    GS.hoverOnMap = true
    GS.hoverGX = gx
    GS.hoverGZ = gz

    local dist = math.sqrt(gx * gx + gz * gz)
    local inRange = dist <= EnergyTower.GetEnergyRange() + 0.01
    local isEnergyTower = (gx == 0 and gz == 0)
    local isOccupied = false
    for _, tower in ipairs(GS.towers) do
        if tower.gx == gx and tower.gz == gz then
            isOccupied = true
            break
        end
    end
    -- 场景物件也阻挡建塔
    if not isOccupied and Terrain.GetObjectAt(gx, gz) then
        isOccupied = true
    end
    local canAfford = GS.gold >= M.GetTowerCost()

    GS.hoverValid = inRange and not isEnergyTower and not isOccupied and canAfford

    GS.hoverNode.enabled = true
    GS.hoverNode.position = Vector3(gx, CONFIG.HoverY, gz)

    local hoverMat = GS.hoverNode:GetComponent("StaticModel"):GetMaterial(0)
    if GS.hoverValid then
        hoverMat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.8, 0.2, 0.45)))
        hoverMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.1, 0.4, 0.1)))
    else
        hoverMat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.2, 0.2, 0.45)))
        hoverMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.4, 0.1, 0.1)))
    end
end

function M.HandlePlacement()
    if input:GetMouseButtonPress(MOUSEB_LEFT) and GS.hoverOnMap and GS.hoverValid then
        M.PlaceBasicTower(GS.hoverGX, GS.hoverGZ)
    end

    -- X 键拆除悬停处的塔
    if input:GetKeyPress(KEY_X) and GS.hoverOnMap then
        local idx = M.GetTowerAtHover()
        if idx then
            M.DemolishTower(idx)
        end
    end
end

return M
