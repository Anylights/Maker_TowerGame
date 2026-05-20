-- ============================================================================
-- Wave.lua — 程序化无限波次系统 (大波次/小波次 + 径向刷新 + 指示器)
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local MOEBIUS = Cfg.MOEBIUS
local GS = Cfg.GS
local Monster = require("Monster")
local Artifact = require("Artifact")
local EnergyTower = require("EnergyTower")

local M = {}

-- ============================================================================
-- 怪物池 (按大波次阶段解锁)
-- ============================================================================

-- 每个大波次阶段可用的普通怪物 ID
local WAVE_POOLS = {
    [1] = { "walker", "swarm" },
    [2] = { "walker", "swarm", "sprinter" },
    [3] = { "walker", "swarm", "sprinter", "shellbeast" },
    [4] = { "walker", "swarm", "sprinter", "shellbeast", "shielded" },
    [5] = { "walker", "swarm", "sprinter", "shellbeast", "shielded", "energy_devourer" },
}

-- 精英词缀池 (按大波次解锁)
local AFFIX_POOLS = {
    [1] = {},
    [2] = { "thick_armor" },
    [3] = { "thick_armor", "swift" },
    [4] = { "thick_armor", "swift", "burn_resist" },
    [5] = { "thick_armor", "swift", "burn_resist", "energy_drinker" },
}

--- 获取当前大波次对应的怪物池
local function GetPool(bigWave)
    local idx = math.min(bigWave, #WAVE_POOLS)
    return WAVE_POOLS[idx]
end

--- 获取当前大波次对应的词缀池
local function GetAffixPool(bigWave)
    local idx = math.min(bigWave, #AFFIX_POOLS)
    return AFFIX_POOLS[idx]
end

-- ============================================================================
-- HP 缩放公式
-- ============================================================================

--- 计算 HP 缩放因子 (基于全局波次)
--- 公式: 1.0 + A * sqrt(w-1) + B * (w-1)
--- @param globalWave number 全局波次 (1-based)
--- @param isBoss boolean 是否为 Boss
--- @return number 缩放因子
function M.HPScaleFactor(globalWave, isBoss)
    if globalWave <= 1 then return 1.0 end
    local w = globalWave - 1
    if isBoss then
        return 1.0 + CONFIG.BossHPScaleA * math.sqrt(w) + CONFIG.BossHPScaleB * w
    else
        return 1.0 + CONFIG.HPScaleA * math.sqrt(w) + CONFIG.HPScaleB * w
    end
end

-- ============================================================================
-- 径向刷新：扇区计算
-- ============================================================================

--- 获取当前大波次允许的最大刷新点数
local function GetMaxSpawnPoints(bigWave)
    local tbl = CONFIG.MaxSpawnPoints
    local idx = math.min(bigWave, #tbl)
    return tbl[idx]
end

--- 生成本小波次的刷新扇区列表
--- @return table[] sectors { {angle, enemyId, count, interval, delay, eliteAffixes}, ... }
local function GenerateSpawnSectors(bigWave, smallWave, globalWave)
    local pool = GetPool(bigWave)
    local affixPool = GetAffixPool(bigWave)
    local maxPts = GetMaxSpawnPoints(bigWave)
    local isBossWave = (smallWave == CONFIG.MiniBossSubWave or smallWave == CONFIG.BigBossSubWave)

    -- Boss 波只有 1 个扇区用于 Boss
    -- 加上 1-2 个普通怪扇区
    local sectors = {}
    local usedAngles = {}

    --- 选择一个不与已有角度太近的随机角度
    local function PickAngle()
        local minSep = CONFIG.SectorAngleRad * 1.2 -- 最小间隔 > 扇区角度
        for attempt = 1, 20 do
            local a = math.random() * math.pi * 2
            local ok = true
            for _, ua in ipairs(usedAngles) do
                local diff = math.abs(a - ua)
                if diff > math.pi then diff = math.pi * 2 - diff end
                if diff < minSep then
                    ok = false
                    break
                end
            end
            if ok then
                table.insert(usedAngles, a)
                return a
            end
        end
        -- 回退: 均匀分布
        local a = (#usedAngles) * (math.pi * 2 / maxPts) + math.random() * 0.3
        table.insert(usedAngles, a)
        return a
    end

    --- 决定普通波怪物数量 (随波次递增)
    local function BaseMonsterCount()
        -- 基础 5 + 全局波次 * 1.5, 上限约 60
        return math.min(60, math.floor(5 + globalWave * 1.5))
    end

    if isBossWave then
        -- Boss 扇区
        local bossId = (smallWave == CONFIG.MiniBossSubWave) and "shatter_titan" or "line_devourer"
        local bossAngle = PickAngle()
        table.insert(sectors, {
            angle = bossAngle,
            enemyId = bossId,
            count = 1,
            interval = 0,
            delay = 0,
            eliteAffixes = {},
            isBoss = true,
        })

        -- 伴随怪: 1-2 个普通扇区
        local companionPts = math.min(maxPts - 1, math.max(1, math.floor(maxPts * 0.5)))
        local totalCompanion = math.floor(BaseMonsterCount() * 0.6)
        local perSector = math.max(3, math.floor(totalCompanion / companionPts))
        for ci = 1, companionPts do
            local eid = pool[math.random(1, #pool)]
            table.insert(sectors, {
                angle = PickAngle(),
                enemyId = eid,
                count = perSector,
                interval = math.max(0.3, 1.5 - globalWave * 0.02),
                delay = 3.0 + ci * 2.0,
                eliteAffixes = {},
                isBoss = false,
            })
        end
    else
        -- 普通波: 随机分配多个扇区
        local numSectors = math.max(1, math.min(maxPts, math.random(
            math.ceil(maxPts * 0.5), maxPts
        )))
        local totalMonsters = BaseMonsterCount()
        local remaining = totalMonsters

        for si = 1, numSectors do
            local eid = pool[math.random(1, #pool)]
            local count
            if si == numSectors then
                count = remaining
            else
                count = math.max(2, math.floor(remaining / (numSectors - si + 1) + math.random(-2, 2)))
                count = math.min(count, remaining - (numSectors - si))
            end
            remaining = remaining - count

            -- 精英概率: 大波次3+ 开始，小波次越后越高
            local affixes = {}
            if #affixPool > 0 and smallWave >= 3 then
                local eliteChance = 0.05 + (bigWave - 1) * 0.03 + (smallWave - 1) * 0.02
                if math.random() < eliteChance then
                    -- 1-2 个词缀
                    local numAffixes = (bigWave >= 4 and math.random() < 0.3) and 2 or 1
                    local shuffled = {}
                    for _, a in ipairs(affixPool) do table.insert(shuffled, a) end
                    for j = #shuffled, 2, -1 do
                        local k = math.random(1, j)
                        shuffled[j], shuffled[k] = shuffled[k], shuffled[j]
                    end
                    for j = 1, math.min(numAffixes, #shuffled) do
                        table.insert(affixes, shuffled[j])
                    end
                end
            end

            table.insert(sectors, {
                angle = PickAngle(),
                enemyId = eid,
                count = count,
                interval = math.max(0.3, 1.5 - globalWave * 0.015),
                delay = (si - 1) * 2.0,
                eliteAffixes = affixes,
                isBoss = false,
            })
        end
    end

    return sectors
end

-- ============================================================================
-- 刷新指示器 (CustomGeometry 扇环 / Boss 三角警告)
-- ============================================================================

--- 创建一个扇环指示器 (地面贴合)
--- @param angle number 中心角度 (弧度)
--- @param isBoss boolean 是否为 Boss 警告
--- @return Node 指示器节点
local function CreateSectorIndicator(angle, isBoss)
    local range = EnergyTower.GetEnergyRange()
    local spawnDist = range * CONFIG.SpawnDistanceFactor
    local innerR = spawnDist - CONFIG.IndicatorArcWidth * 0.5
    local outerR = spawnDist + CONFIG.IndicatorArcWidth * 0.5
    local halfAngle = CONFIG.SectorAngleRad * 0.5
    local segments = 12
    local y = CONFIG.GridY + 0.01

    local node = GS.scene:CreateChild("SectorIndicator")
    node.position = Vector3(0, y, 0)

    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)

    -- 构建扇环: segments 个梯形, 每个梯形 2 个三角形
    for s = 0, segments - 1 do
        local a0 = angle - halfAngle + (s / segments) * halfAngle * 2
        local a1 = angle - halfAngle + ((s + 1) / segments) * halfAngle * 2
        local cos0, sin0 = math.cos(a0), math.sin(a0)
        local cos1, sin1 = math.cos(a1), math.sin(a1)

        -- 4 个顶点: 内左, 内右, 外右, 外左
        local il = Vector3(cos0 * innerR, 0, sin0 * innerR)
        local ir = Vector3(cos1 * innerR, 0, sin1 * innerR)
        local or_ = Vector3(cos1 * outerR, 0, sin1 * outerR)
        local ol = Vector3(cos0 * outerR, 0, sin0 * outerR)

        -- 三角形1: il, ir, or_
        geom:DefineVertex(il); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(ir); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(or_); geom:DefineNormal(Vector3.UP)

        -- 三角形2: il, or_, ol
        geom:DefineVertex(il); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(or_); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(ol); geom:DefineNormal(Vector3.UP)
    end

    geom:Commit()

    -- 材质
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    local diffColor, emitColor
    if isBoss then
        diffColor = MOEBIUS.BossWarnDiff
        emitColor = MOEBIUS.BossWarnEmit
    else
        diffColor = MOEBIUS.IndicatorDiff
        emitColor = MOEBIUS.IndicatorEmit
    end
    mat:SetShaderParameter("MatDiffColor", Variant(Color(diffColor.r, diffColor.g, diffColor.b, diffColor.a)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(emitColor))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    geom:SetMaterial(mat)

    return node
end

--- 创建 Boss 三角警告标记
--- @param angle number 中心角度 (弧度)
--- @return Node
local function CreateBossWarning(angle)
    local range = EnergyTower.GetEnergyRange()
    local dist = range * CONFIG.SpawnDistanceFactor + CONFIG.IndicatorArcWidth + 0.5
    local cx = math.cos(angle) * dist
    local cz = math.sin(angle) * dist
    local y = CONFIG.GridY + 0.02
    local s = CONFIG.BossWarnTriSize

    local node = GS.scene:CreateChild("BossWarning")
    node.position = Vector3(cx, y, cz)

    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)

    -- 等边三角形 (顶部朝上)
    local h = s * math.sqrt(3) * 0.5
    local top = Vector3(0, h * 0.67, 0)
    local bl = Vector3(-s * 0.5, -h * 0.33, 0)
    local br = Vector3(s * 0.5, -h * 0.33, 0)

    -- 正面
    geom:DefineVertex(top); geom:DefineNormal(Vector3.FORWARD)
    geom:DefineVertex(bl);  geom:DefineNormal(Vector3.FORWARD)
    geom:DefineVertex(br);  geom:DefineNormal(Vector3.FORWARD)
    -- 背面
    geom:DefineVertex(top); geom:DefineNormal(Vector3.BACK)
    geom:DefineVertex(br);  geom:DefineNormal(Vector3.BACK)
    geom:DefineVertex(bl);  geom:DefineNormal(Vector3.BACK)

    geom:Commit()

    -- 让三角形面向能源塔中心
    local yaw = math.deg(math.atan(cx, cz)) + 180
    node.rotation = Quaternion(yaw, Vector3.UP)

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(
        MOEBIUS.BossWarnDiff.r, MOEBIUS.BossWarnDiff.g, MOEBIUS.BossWarnDiff.b, MOEBIUS.BossWarnDiff.a)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.BossWarnEmit))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    geom:SetMaterial(mat)

    return node
end

--- 清除所有指示器和警告节点
local function ClearIndicators()
    for _, n in ipairs(GS.indicatorNodes) do
        if n then n:Remove() end
    end
    GS.indicatorNodes = {}
    for _, n in ipairs(GS.bossWarnNodes) do
        if n then n:Remove() end
    end
    GS.bossWarnNodes = {}
end



-- ============================================================================
-- 波次运行时状态
-- ============================================================================

-- 当前波次活跃的 spawn groups (运行时副本)
local activeGroups_ = {}

-- 当前波次总怪物数 & 已刷数 (用于 UI 显示)
local totalMonstersInWave_ = 0
local spawnedMonstersInWave_ = 0

-- 当前波次准备时间 (缓存)
local currentPrepTime_ = 0

-- ============================================================================
-- 核心逻辑
-- ============================================================================

--- 获取刷新距离 (基于能源塔范围)
local function GetSpawnDistance()
    local range = EnergyTower.GetEnergyRange()
    return range * CONFIG.SpawnDistanceFactor
end

--- 开始新一波
function M.StartWave()
    -- 推进波次编号
    GS.smallWave = GS.smallWave + 1
    if GS.smallWave > CONFIG.BigWaveSize then
        GS.smallWave = 1
        GS.bigWave = GS.bigWave + 1
    end
    if GS.bigWave == 0 then GS.bigWave = 1 end

    GS.globalWave = (GS.bigWave - 1) * CONFIG.BigWaveSize + GS.smallWave
    GS.currentWave = GS.globalWave -- 向后兼容

    -- 准备时间
    local isBossWave = (GS.smallWave == CONFIG.MiniBossSubWave or GS.smallWave == CONFIG.BigBossSubWave)
    if GS.globalWave == 1 then
        currentPrepTime_ = CONFIG.PrepTimeFirst
    elseif isBossWave then
        currentPrepTime_ = CONFIG.PrepTimeBoss
    else
        currentPrepTime_ = CONFIG.PrepTimeBase
    end

    GS.wavePhase = "preparing"
    GS.waveTimer = currentPrepTime_

    -- 生成刷新扇区
    GS.spawnSectors = GenerateSpawnSectors(GS.bigWave, GS.smallWave, GS.globalWave)

    -- 构建活跃 spawn groups (从扇区生成)
    activeGroups_ = {}
    totalMonstersInWave_ = 0
    spawnedMonstersInWave_ = 0

    local spawnDist = GetSpawnDistance()

    for _, sector in ipairs(GS.spawnSectors) do
        totalMonstersInWave_ = totalMonstersInWave_ + sector.count
        table.insert(activeGroups_, {
            enemy_id = sector.enemyId,
            count = sector.count,
            interval = sector.interval,
            delay = sector.delay,
            elite_affixes = sector.eliteAffixes or {},
            isBoss = sector.isBoss or false,
            -- 刷新位置信息
            sectorAngle = sector.angle,
            spawnDist = spawnDist,
            -- 运行时
            spawned = 0,
            timer = 0,
            delayRemaining = sector.delay,
        })
    end

    -- 清除旧指示器, 创建新指示器
    ClearIndicators()
    for _, sector in ipairs(GS.spawnSectors) do
        local indNode = CreateSectorIndicator(sector.angle, sector.isBoss)
        table.insert(GS.indicatorNodes, indNode)

        -- 如果是 Boss 扇区, 额外创建三角警告
        if sector.isBoss then
            local warnNode = CreateBossWarning(sector.angle)
            table.insert(GS.bossWarnNodes, warnNode)
        end
    end

    -- 检查下一小波是否有 Boss (提前预警)
    local nextSmall = GS.smallWave + 1
    if nextSmall <= CONFIG.BigWaveSize then
        if nextSmall == CONFIG.MiniBossSubWave or nextSmall == CONFIG.BigBossSubWave then
            -- 预告: 下波有 Boss, 暂不创建警告 (等下波 preparing 时再创建)
        end
    end

    local waveName = M.GetWaveName()
    print(string.format("[Wave] Preparing Big%d-Small%d (Global %d) \"%s\" (%d monsters, %d sectors, %.0fs prep)",
        GS.bigWave, GS.smallWave, GS.globalWave, waveName,
        totalMonstersInWave_, #GS.spawnSectors, currentPrepTime_))
end

--- 跳过准备阶段
function M.SkipPrepare()
    if GS.wavePhase == "preparing" then
        GS.waveTimer = 0
        print("[Wave] Preparation skipped!")
    end
end

--- 波次更新 (每帧调用)
function M.Update(dt)
    if GS.gameOver then return end

    -- 游戏尚未开始: 自动开始第一波
    if GS.globalWave == 0 then
        M.StartWave()
        return
    end

    -- === 准备阶段 ===
    if GS.wavePhase == "preparing" then
        GS.waveTimer = GS.waveTimer - dt

        if input:GetKeyPress(KEY_SPACE) then
            M.SkipPrepare()
        end

        if GS.waveTimer <= 0 then
            GS.wavePhase = "spawning"
            print(string.format("[Wave] Big%d-Small%d (Global %d) started!",
                GS.bigWave, GS.smallWave, GS.globalWave))
        end
        return
    end

    -- === 刷怪阶段 ===
    if GS.wavePhase == "spawning" then
        local allDone = true

        for _, g in ipairs(activeGroups_) do
            if g.spawned < g.count then
                if g.delayRemaining > 0 then
                    g.delayRemaining = g.delayRemaining - dt
                    allDone = false
                else
                    g.timer = g.timer + dt
                    local threshold = g.interval
                    if g.spawned == 0 then threshold = 0 end

                    if g.timer >= threshold then
                        g.timer = g.timer - math.max(g.interval, 0.01)

                        g.spawned = g.spawned + 1
                        spawnedMonstersInWave_ = spawnedMonstersInWave_ + 1

                        -- 计算扇区内随机偏移位置
                        local angleOffset = (math.random() - 0.5) * CONFIG.SectorAngleRad * 0.8
                        local spawnAngle = g.sectorAngle + angleOffset
                        local distJitter = g.spawnDist + (math.random() - 0.5) * 2.0
                        local sx = math.cos(spawnAngle) * distJitter
                        local sz = math.sin(spawnAngle) * distJitter

                        Monster.SpawnMonster(g.enemy_id, {
                            spawnX = sx,
                            spawnZ = sz,
                            waveNumber = GS.globalWave,
                            eliteAffixes = g.elite_affixes,
                        })

                        if g.spawned < g.count then
                            allDone = false
                        end
                    else
                        allDone = false
                    end
                end
            end
        end

        if allDone then
            GS.wavePhase = "clearing"
            print(string.format("[Wave] All %d monsters spawned for Global %d, clearing...",
                totalMonstersInWave_, GS.globalWave))
        end
        return
    end

    -- === 清场阶段 ===
    if GS.wavePhase == "clearing" then
        if #GS.monsters == 0 then
            -- 波次完成奖励
            local bonusGold = 20 + GS.globalWave * 10
            local bonusMat = GS.globalWave * 3
            GS.gold = GS.gold + bonusGold
            GS.material = GS.material + bonusMat
            print(string.format("[Wave] Global %d cleared! Bonus: +%d gold, +%d material",
                GS.globalWave, bonusGold, bonusMat))

            -- 触发圣器掉落 (每小波结束都有)
            Artifact.TriggerWaveDrop()
            if GS.artifactDropPending then
                GS.wavePhase = "dropping"
                print("[Wave] Entering artifact drop selection...")
            else
                M.StartWave()
            end
        end
        return
    end

    -- === 圣器掉落选择阶段 ===
    if GS.wavePhase == "dropping" then
        if not GS.artifactDropPending then
            M.StartWave()
        end
        return
    end
end

-- ============================================================================
-- UI 信息
-- ============================================================================

--- 获取当前波次名称 (程序化生成)
function M.GetWaveName()
    local bw = GS.bigWave
    local sw = GS.smallWave
    if sw == CONFIG.MiniBossSubWave then
        return "小Boss: 裂山巨像"
    elseif sw == CONFIG.BigBossSubWave then
        return "大Boss: 吞线母体"
    end

    -- 普通波: 基于内容生成简短名称
    local pool = GetPool(bw)
    if bw <= 1 then return "先锋进攻"
    elseif bw <= 2 then return "多路夹击"
    elseif bw <= 3 then return "精英混战"
    elseif bw <= 5 then return "全面攻势"
    else return "无尽浪潮"
    end
end

--- 获取下一波预告
function M.GetNextWavePreview()
    local nextSmall = GS.smallWave + 1
    local nextBig = GS.bigWave
    if nextSmall > CONFIG.BigWaveSize then
        nextSmall = 1
        nextBig = nextBig + 1
    end
    local nextGlobal = (nextBig - 1) * CONFIG.BigWaveSize + nextSmall

    local isBoss = (nextSmall == CONFIG.MiniBossSubWave or nextSmall == CONFIG.BigBossSubWave)
    local bossName = ""
    if nextSmall == CONFIG.MiniBossSubWave then bossName = "裂山巨像"
    elseif nextSmall == CONFIG.BigBossSubWave then bossName = "吞线母体"
    end

    return {
        wave = nextGlobal,
        bigWave = nextBig,
        smallWave = nextSmall,
        name = isBoss and ("Boss: " .. bossName) or "普通波",
        isBoss = isBoss,
        summary = isBoss and bossName or string.format("~%d 怪物", math.floor(5 + nextGlobal * 1.5)),
        totalMonsters = 0, -- 程序化生成，具体数未知
    }
end

--- 获取波次显示信息
function M.GetWaveInfo()
    local phase = GS.wavePhase
    local bw = GS.bigWave
    local sw = GS.smallWave
    local gw = GS.globalWave

    local waveLabel = string.format("大%d·%d/%d (第%d波)", bw, sw, CONFIG.BigWaveSize, gw)

    if phase == "preparing" then
        local waveName = M.GetWaveName()
        return string.format("%s「%s」| %.0f秒 (空格跳过)",
            waveLabel, waveName, math.max(0, GS.waveTimer))
    elseif phase == "spawning" then
        return string.format("%s | 出怪中 %d/%d",
            waveLabel, spawnedMonstersInWave_, totalMonstersInWave_)
    elseif phase == "clearing" then
        return string.format("%s | 清剿中 (剩余 %d)",
            waveLabel, #GS.monsters)
    else
        return waveLabel
    end
end

return M
