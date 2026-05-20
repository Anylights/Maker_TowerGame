-- ============================================================================
-- Tower.lua — 基础塔放置 / 攻击 / 炮弹 / 悬停 / 放置输入
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")
local EnergyTower = require("EnergyTower")
local Artifact = require("Artifact")
local StatusEffect = require("StatusEffect")

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

    local weaponName = "weapon-ballista"  -- 统一使用弩炮模型
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
        activated = false,  -- 需要通过能源线连接才激活
    }
    -- 初始化圣器槽位
    Artifact.InitTowerSlots(tower)
    table.insert(GS.towers, tower)

    -- 重新计算连通性 (新塔可能已经在已有线网上)
    EnergyTower.RecalculateConnectivity()
    EnergyTower.RebuildEnergyLines()

    -- 设置未激活视觉
    M.UpdateTowerActivationVisual(tower)

    print(string.format("Tower built at (%d, %d), dist=%.1f, cost=%d, gold=%d",
        gx, gz, dist, cost, GS.gold))
end

-- ============================================================================
-- 塔攻击
-- ============================================================================

local ROTATE_SPEED = 720

--- 更新塔的激活状态视觉
function M.UpdateTowerActivationVisual(tower)
    if not tower.node then return end
    local weaponNode = tower.node:GetChild("TowerWeapon", false)
    if not weaponNode then return end

    local model = weaponNode:GetComponent("StaticModel")
    if not model then return end

    if tower.activated then
        -- 恢复正常材质
        model:SetMaterial(cache:GetResource("Material",
            "Materials/TD/weapon-ballista_00_colormap.xml"))
    else
        -- 灰色半透明材质表示未激活
        if not tower.inactiveMat then
            tower.inactiveMat = Material:new()
            tower.inactiveMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
            tower.inactiveMat:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.3, 0.35, 1.0)))
            tower.inactiveMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.0, 0.0, 0.0)))
            tower.inactiveMat:SetShaderParameter("Metallic", Variant(0.0))
            tower.inactiveMat:SetShaderParameter("Roughness", Variant(0.8))
        end
        model:SetMaterial(tower.inactiveMat)
    end
end

--- 批量更新所有塔的激活视觉
function M.UpdateAllActivationVisuals()
    for _, tower in ipairs(GS.towers) do
        M.UpdateTowerActivationVisual(tower)
    end
end

function M.UpdateTowerAttacks(dt)
    for _, tower in ipairs(GS.towers) do
        -- 未激活的塔不攻击
        if not tower.activated then goto continue_tower end

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

        -- 开火 (攻速随功率比线性缩放, 最低 30%)
        tower.cooldown = tower.cooldown - dt
        if tower.cooldown <= 0 and bestM then
            local att = EnergyTower.CalcAttenuation(tower.dist)
            local dmg = CONFIG.TowerBaseDmg * att
            -- 圣器伤害乘数
            dmg = dmg * (tower.artDmgMult or 1.0)
            -- 圣器弹道形态: area → AOE 爆炸弹
            if tower.artBulletForm == "area" and tower.artAreaRadius > 0 then
                M.FireAreaProjectile(tower, bestM, dmg, tower.artAreaRadius)
            else
                M.FireProjectile(tower, bestM, dmg)
            end
            -- 攻速: ratio 越高→interval 越短→攻速越快; 下限 30%
            local speedMult = math.max(0.30, tower.ratio * #GS.towers)
            -- 圣器攻速乘数
            speedMult = speedMult * (tower.artAtkSpdMult or 1.0)
            tower.cooldown = CONFIG.TowerFireInterval / math.max(0.10, speedMult)
        end

        ::continue_tower::
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
        sourceTower = tower,  -- 圣器命中效果需要
    }
    table.insert(GS.projectiles, proj)
end

--- AOE 范围爆炸弹 (高爆圣器)
function M.FireAreaProjectile(tower, targetMonster, dmg, radius)
    local node = GS.scene:CreateChild("Projectile")
    local s = CONFIG.ProjectileSize / 0.28 * 1.4 -- 稍大
    node.scale = Vector3(s, s, s)
    node.position = Vector3(tower.gx, 1.0, tower.gz)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/weapon-ammo-cannonball.mdl"))
    -- 使用红色发光材质区分 AOE
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.9, 0.3, 0.1, 1)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8, 0.2, 0.05)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    model:SetMaterial(mat)

    local proj = {
        node = node,
        target = targetMonster,
        speed = CONFIG.ProjectileSpeed * 0.8,  -- 稍慢
        damage = dmg,
        sourceTower = tower,
        isArea = true,
        areaRadius = radius,
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
        elseif not p.target or not p.target.node or p.target.hp <= 0 then
            p.node:Remove()
            table.remove(GS.projectiles, i)
        else
            local pos = p.node.position
            local tpos = p.target.node.position
            local dir = tpos - pos
            local dist = dir:Length()
            if dist < 0.3 then
                if p.isArea and p.areaRadius and p.areaRadius > 0 then
                    -- AOE 爆炸: 伤害范围内所有怪物
                    local hitPos = p.target.node.position
                    for _, m in ipairs(GS.monsters) do
                        if m.node and m.hp > 0 then
                            local dx = m.node.position.x - hitPos.x
                            local dz = m.node.position.z - hitPos.z
                            local d = math.sqrt(dx * dx + dz * dz)
                            if d <= p.areaRadius then
                                Monster.DamageMonster(m, p.damage)
                                -- 圣器命中效果
                                if p.sourceTower then
                                    StatusEffect.ProcessOnHitEffects(m, p.damage, p.sourceTower)
                                end
                            end
                        end
                    end
                else
                    -- 单体命中
                    Monster.DamageMonster(p.target, p.damage)
                    -- 圣器命中效果
                    if p.sourceTower then
                        StatusEffect.ProcessOnHitEffects(p.target, p.damage, p.sourceTower)
                    end
                end
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

    -- 删除该塔所在格子的所有能源线边 (图模型)
    EnergyTower.RemoveEdgesAtCell(tower.gx, tower.gz)

    -- 卸下该塔上的圣器 (归还背包)
    if tower.mainSlot then
        Artifact.UnequipFromTower(tower.mainSlot)
    end
    if tower.subSlot then
        Artifact.UnequipFromTower(tower.subSlot)
    end

    -- 移除节点
    if tower.node then
        tower.node:Remove()
    end

    -- 拆除后需要更新所有背包中指向后续塔的 towerIndex
    -- (因为 table.remove 会导致后续塔索引前移)
    table.remove(GS.towers, towerIndex)

    -- 修正背包中的 towerIndex 引用
    for _, entry in ipairs(GS.artifactInventory) do
        if entry.equipped and entry.towerIndex then
            if entry.towerIndex > towerIndex then
                entry.towerIndex = entry.towerIndex - 1
            end
        end
    end

    -- 重新计算连通性和线段
    EnergyTower.RecalculateConnectivity()
    EnergyTower.RebuildEnergyLines()

    -- 更新所有塔的激活视觉
    M.UpdateAllActivationVisuals()

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

    local isEnergyTower = (gx == 0 and gz == 0)
    local isOccupied = false
    for _, tower in ipairs(GS.towers) do
        if tower.gx == gx and tower.gz == gz then
            isOccupied = true
            break
        end
    end
    local canAfford = GS.gold >= M.GetTowerCost()

    -- 不再要求在能源范围内，任何空地都可以建塔
    GS.hoverValid = not isEnergyTower and not isOccupied and canAfford

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

--- 显示放置确认标记（3D 四角框 + UI 气泡由 GameUI 渲染）
local function ShowPlacementPlus(gx, gz)
    GS.placementPending = true
    GS.placementGX = gx
    GS.placementGZ = gz
    if GS.placementMarker then
        GS.placementMarker.position = Vector3(gx, CONFIG.HoverY, gz)
        GS.placementMarker.enabled = true
    end
end

--- 隐藏放置确认标记
local function HidePlacementPlus()
    GS.placementPending = false
    if GS.placementMarker then
        GS.placementMarker.enabled = false
    end
end

--- 公开 API：取消待确认的放置（布线模式切换时调用）
function M.CancelPlacement()
    HidePlacementPlus()
end

function M.HandlePlacement()
    local GameUI = require("GameUI")

    if input:GetMouseButtonPress(MOUSEB_LEFT) and GS.hoverOnMap then
        -- 如果鼠标在 UI 面板上，不做任何操作（防止穿透建塔）
        if GameUI.IsMouseOverUIPanel() then
            return
        end

        local gx, gz = GS.hoverGX, GS.hoverGZ

        -- ---- 两步确认流程（确认通过 UI 气泡按钮）----
        if GS.placementPending then
            -- 已有待确认位置
            if gx == GS.placementGX and gz == GS.placementGZ then
                -- 再次点击同一位置 → 取消（确认改由气泡按钮触发）
                HidePlacementPlus()
                return
            else
                -- 点击了其他位置 → 取消当前加号，如果新位置有效则移动到新位置
                HidePlacementPlus()
                if GS.hoverValid then
                    ShowPlacementPlus(gx, gz)
                end
                return
            end
        else
            -- 无待确认位置
            if GS.hoverValid then
                -- 点击有效空地 → 显示加号
                ShowPlacementPlus(gx, gz)
                return
            end
        end
        -- 塔详情 open/toggle/switch 由 GameUI.HandleArtifactInput 统一处理
    end

    -- 右键或 Escape 取消待确认放置
    if GS.placementPending then
        if input:GetMouseButtonPress(MOUSEB_RIGHT) or input:GetKeyPress(KEY_ESCAPE) then
            HidePlacementPlus()
            return
        end
    end

    -- X 键拆除悬停处的塔
    if input:GetKeyPress(KEY_X) and GS.hoverOnMap then
        HidePlacementPlus()
        local idx = M.GetTowerAtHover()
        if idx then
            M.DemolishTower(idx)
        end
    end
end

return M
