-- ============================================================================
-- Wave.lua — 关卡制波次系统 (每关卡=8小波, 路径刷怪, Boss, 精英)
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local MOEBIUS = Cfg.MOEBIUS
local GS = Cfg.GS
local Monster = require("Monster")
local Artifact = require("Artifact")
local EnergyTower = require("EnergyTower")
local GameUI = require("GameUI")
local LevelData = require("LevelData")

local M = {}

-- ============================================================================
-- 怪物池 (按关卡阶段解锁)
-- ============================================================================

local WAVE_POOLS = {
    [1] = { "walker", "swarm" },
    [2] = { "walker", "swarm", "sprinter" },
    [3] = { "walker", "swarm", "sprinter", "shellbeast" },
    [4] = { "walker", "swarm", "sprinter", "shellbeast", "shielded" },
    [5] = { "walker", "swarm", "sprinter", "shellbeast", "shielded", "energy_devourer" },
}

local AFFIX_POOLS = {
    [1] = {},
    [2] = { "thick_armor" },
    [3] = { "thick_armor", "swift" },
    [4] = { "thick_armor", "swift", "burn_resist" },
    [5] = { "thick_armor", "swift", "burn_resist", "energy_drinker" },
}

local function GetPool(level)
    local idx = math.min(level, #WAVE_POOLS)
    return WAVE_POOLS[idx]
end

local function GetAffixPool(level)
    local idx = math.min(level, #AFFIX_POOLS)
    return AFFIX_POOLS[idx]
end

-- ============================================================================
-- HP 缩放公式
-- ============================================================================

--- 计算 HP 缩放因子
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
-- 当前关卡数据缓存
-- ============================================================================

local currentLevelData_ = nil   -- 当前关卡的路径配置

--- 获取当前关卡路径数据
function M.GetCurrentLevelData()
    return currentLevelData_
end

--- 加载关卡数据
local function LoadLevelData(level)
    currentLevelData_ = LevelData.GetLevel(level)
    print(string.format("[Wave] Level %d loaded: \"%s\" (%d paths)",
        level, currentLevelData_.name, #currentLevelData_.paths))
end

-- ============================================================================
-- 路径起点刷怪: 在路径第一个航点附近, 沿路径宽度随机分布
-- ============================================================================

--- 在路径起点附近生成随机出生位置
--- @param path table 路径数据 { width, waypoints }
--- @return number spawnX, number spawnZ
local function RandomSpawnOnPath(path)
    local wp1 = path.waypoints[1]
    local wp2 = path.waypoints[2]
    if not wp1 then return 0, 0 end
    if not wp2 then return wp1.x, wp1.z end

    -- 路径方向
    local dx = wp2.x - wp1.x
    local dz = wp2.z - wp1.z
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 0.01 then return wp1.x, wp1.z end

    -- 垂直方向 (路径宽度方向)
    local perpX = -dz / len
    local perpZ =  dx / len

    -- 在起点位置 + 路径宽度范围内随机
    local halfW = path.width * 0.5
    local offset = (math.random() - 0.5) * halfW * 2  -- -halfW ~ +halfW
    -- 同时沿路径方向稍微散开 (避免全部挤在同一点)
    local alongOffset = math.random() * 3.0  -- 沿路径方向随机 0~3 格

    local sx = wp1.x + perpX * offset - (dx / len) * alongOffset
    local sz = wp1.z + perpZ * offset - (dz / len) * alongOffset

    return sx, sz
end

--- 将路径航点转换为 Monster.lua 使用的 pathData 格式 {{x,z},...}
--- @param path table 路径数据
--- @return table pathData 航点数组 {{x,z},...}
local function BuildPathData(path)
    local data = {}
    for _, wp in ipairs(path.waypoints) do
        table.insert(data, { wp.x, wp.z })
    end
    return data
end

-- ============================================================================
-- 刷新扇区生成 (基于路径)
-- ============================================================================

--- 每小波基础怪物数量 (关卡制: 怪物更多但更慢)
local function BaseMonsterCount(globalWave)
    return math.min(80, math.floor(8 + globalWave * 2.0))
end

--- 生成本小波次的刷新配置 (基于关卡路径)
--- @return table[] groups { {pathIdx, enemyId, count, interval, delay, eliteAffixes, isBoss}, ... }
local function GenerateSpawnGroups(level, smallWave, globalWave)
    local pool = GetPool(level)
    local affixPool = GetAffixPool(level)
    local levelData = currentLevelData_
    local numPaths = #levelData.paths

    local isBossWave = (smallWave == CONFIG.MiniBossSubWave or smallWave == CONFIG.BigBossSubWave)

    local groups = {}

    if isBossWave then
        -- Boss 从第一条路径出现
        local bossId = (smallWave == CONFIG.MiniBossSubWave) and "shatter_titan" or "line_devourer"
        table.insert(groups, {
            pathIdx = 1,
            enemyId = bossId,
            count = 1,
            interval = 0,
            delay = 0,
            eliteAffixes = {},
            isBoss = true,
        })

        -- 伴随怪从所有路径出现
        local totalCompanion = math.floor(BaseMonsterCount(globalWave) * 0.6)
        local perPath = math.max(3, math.floor(totalCompanion / numPaths))
        for pi = 1, numPaths do
            local eid = pool[math.random(1, #pool)]
            table.insert(groups, {
                pathIdx = pi,
                enemyId = eid,
                count = perPath,
                interval = math.max(0.25, 1.2 - globalWave * 0.015),
                delay = 3.0 + (pi - 1) * 1.5,
                eliteAffixes = {},
                isBoss = false,
            })
        end
    else
        -- 普通波: 根据小波次决定使用几条路径
        local activePaths = math.min(numPaths, math.max(1, math.ceil(smallWave / 3)))
        -- 后期小波使用更多路径
        if smallWave >= 5 then activePaths = numPaths end

        local totalMonsters = BaseMonsterCount(globalWave)
        local remaining = totalMonsters

        -- 选择路径 (循环分配)
        for si = 1, activePaths do
            local pathIdx = ((si - 1) % numPaths) + 1
            local eid = pool[math.random(1, #pool)]
            local count
            if si == activePaths then
                count = math.max(1, remaining)
            else
                count = math.max(2, math.floor(remaining / (activePaths - si + 1) + math.random(-2, 2)))
                count = math.min(count, remaining - (activePaths - si))
            end
            remaining = remaining - count

            -- 精英概率
            local affixes = {}
            if #affixPool > 0 and smallWave >= 3 then
                local eliteChance = 0.05 + (level - 1) * 0.03 + (smallWave - 1) * 0.02
                if math.random() < eliteChance then
                    local numAffixes = (level >= 4 and math.random() < 0.3) and 2 or 1
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

            table.insert(groups, {
                pathIdx = pathIdx,
                enemyId = eid,
                count = count,
                interval = math.max(0.25, 1.2 - globalWave * 0.012),
                delay = (si - 1) * 1.5,
                eliteAffixes = affixes,
                isBoss = false,
            })
        end
    end

    return groups
end

-- ============================================================================
-- 刷新指示器 (简化: 路径起点方向箭头)
-- ============================================================================

local indicatorNodes_ = {}
local indicatorTime_ = 0

--- 创建路径方向指示器 (路径起点处的脉冲三角)
local function CreatePathIndicators()
    ClearIndicators()
    if not currentLevelData_ then return end

    local tech = cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml")
    local y = 0.12  -- 高于路径地块(0.05)和地面

    for _, path in ipairs(currentLevelData_.paths) do
        local wp1 = path.waypoints[1]
        if wp1 then
            -- 三角箭头指向路径行进方向
            local wp2 = path.waypoints[2] or { x = 0, z = 0 }
            local dx = wp2.x - wp1.x
            local dz = wp2.z - wp1.z
            local len = math.sqrt(dx * dx + dz * dz)
            if len < 0.01 then dx, dz, len = 0, 1, 1 end

            local node = GS.scene:CreateChild("PathIndicator")
            node.position = Vector3(wp1.x, y, wp1.z)

            -- 朝路径方向
            local yaw = math.deg(math.atan(dx, dz))
            node.rotation = Quaternion(yaw, Vector3.UP)

            -- 三角形几何 (大号箭头)
            local geom = node:CreateComponent("CustomGeometry")
            geom:BeginGeometry(0, TRIANGLE_LIST)
            local s = 5.0  -- 箭头尺寸（加大）
            -- 朝 +Z 方向的三角 (正面)
            geom:DefineVertex(Vector3(0, 0, s)); geom:DefineNormal(Vector3.UP)
            geom:DefineVertex(Vector3(-s * 0.6, 0, -s * 0.3)); geom:DefineNormal(Vector3.UP)
            geom:DefineVertex(Vector3(s * 0.6, 0, -s * 0.3)); geom:DefineNormal(Vector3.UP)
            -- 背面 (确保俯视角可见)
            geom:DefineVertex(Vector3(0, 0, s)); geom:DefineNormal(Vector3(0, -1, 0))
            geom:DefineVertex(Vector3(s * 0.6, 0, -s * 0.3)); geom:DefineNormal(Vector3(0, -1, 0))
            geom:DefineVertex(Vector3(-s * 0.6, 0, -s * 0.3)); geom:DefineNormal(Vector3(0, -1, 0))
            geom:Commit()

            local mat = Material:new()
            mat:SetTechnique(0, tech)
            mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.2, 0.1, 0.7)))
            mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.5, 0.05, 0.02)))
            mat:SetShaderParameter("Metallic", Variant(0.0))
            mat:SetShaderParameter("Roughness", Variant(1.0))
            geom:SetMaterial(mat)

            table.insert(indicatorNodes_, { node = node, mat = mat })
        end
    end
end

--- 清除指示器
function ClearIndicators()
    for _, item in ipairs(indicatorNodes_) do
        if item.node then item.node:Remove() end
    end
    indicatorNodes_ = {}
    -- 兼容旧系统: 清除 GS 中的指示器
    if GS.indicatorNodes then
        for _, n in ipairs(GS.indicatorNodes) do
            if n then n:Remove() end
        end
        GS.indicatorNodes = {}
    end
    if GS.bossWarnNodes then
        for _, n in ipairs(GS.bossWarnNodes) do
            if n then n:Remove() end
        end
        GS.bossWarnNodes = {}
    end
end

--- 更新指示器动画
local function UpdateIndicatorAnimation(dt)
    indicatorTime_ = indicatorTime_ + dt
    local isPreparing = (GS.wavePhase == "preparing")
    local mul
    if isPreparing then
        mul = 0.5 + 0.5 * math.sin(indicatorTime_ * 6.0 * math.pi)
    else
        mul = 0.7 + 0.3 * math.sin(indicatorTime_ * 1.5 * math.pi)
    end

    for _, item in ipairs(indicatorNodes_) do
        if item.mat then
            item.mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.2, 0.1, 0.7 * mul)))
        end
    end
end

-- ============================================================================
-- 波次运行时状态
-- ============================================================================

local activeGroups_ = {}
local totalMonstersInWave_ = 0
local spawnedMonstersInWave_ = 0
local currentPrepTime_ = 0

-- ============================================================================
-- 核心逻辑
-- ============================================================================

--- 开始新一波
function M.StartWave()
    -- 推进波次编号
    local prevBigWave = GS.bigWave
    GS.smallWave = GS.smallWave + 1
    if GS.smallWave > CONFIG.BigWaveSize then
        GS.smallWave = 1
        GS.bigWave = GS.bigWave + 1
    end
    if GS.bigWave == 0 then GS.bigWave = 1 end

    GS.globalWave = (GS.bigWave - 1) * CONFIG.BigWaveSize + GS.smallWave
    GS.currentWave = GS.globalWave

    -- 新关卡: 加载路径数据
    local isNewLevel = (GS.bigWave ~= prevBigWave or GS.globalWave == 1)
    if isNewLevel then
        LoadLevelData(GS.bigWave)

        -- 通知 Scene 渲染路径
        local Scene = require("Scene")
        if Scene.RenderLevelPaths then
            Scene.RenderLevelPaths(currentLevelData_)
        end

        -- 全屏公告: 新关卡
        GameUI.ShowAnnouncement(
            string.format("关卡 %d", GS.bigWave),
            currentLevelData_.name,
            { 255, 200, 50, 255 }  -- 金色
        )
    end

    -- 准备时间
    local isBossWave = (GS.smallWave == CONFIG.MiniBossSubWave or GS.smallWave == CONFIG.BigBossSubWave)
    if GS.globalWave == 1 then
        currentPrepTime_ = CONFIG.PrepTimeFirst
    elseif isBossWave then
        currentPrepTime_ = CONFIG.PrepTimeBoss
    elseif isNewLevel then
        currentPrepTime_ = CONFIG.PrepTimeFirst  -- 新关卡首波给更多准备时间
    else
        currentPrepTime_ = CONFIG.PrepTimeBase
    end

    GS.wavePhase = "preparing"
    GS.waveTimer = currentPrepTime_
    indicatorTime_ = 0

    -- 生成刷新配置
    GS.spawnSectors = GenerateSpawnGroups(GS.bigWave, GS.smallWave, GS.globalWave)

    -- 构建活跃 spawn groups
    activeGroups_ = {}
    totalMonstersInWave_ = 0
    spawnedMonstersInWave_ = 0

    for _, sector in ipairs(GS.spawnSectors) do
        totalMonstersInWave_ = totalMonstersInWave_ + sector.count
        table.insert(activeGroups_, {
            pathIdx = sector.pathIdx,
            enemy_id = sector.enemyId,
            count = sector.count,
            interval = sector.interval,
            delay = sector.delay,
            elite_affixes = sector.eliteAffixes or {},
            isBoss = sector.isBoss or false,
            -- 运行时
            spawned = 0,
            timer = 0,
            delayRemaining = sector.delay,
        })
    end

    -- 创建指示器
    CreatePathIndicators()

    local waveName = M.GetWaveName()
    print(string.format("[Wave] Preparing Level%d-Wave%d (Global %d) \"%s\" (%d monsters, %.0fs prep)",
        GS.bigWave, GS.smallWave, GS.globalWave, waveName,
        totalMonstersInWave_, currentPrepTime_))
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

    -- 指示器动画
    UpdateIndicatorAnimation(dt)

    -- === 准备阶段 ===
    if GS.wavePhase == "preparing" then
        GS.waveTimer = GS.waveTimer - dt

        if input:GetKeyPress(KEY_SPACE) then
            M.SkipPrepare()
        end

        if GS.waveTimer <= 0 then
            GS.wavePhase = "spawning"
            print(string.format("[Wave] Level%d-Wave%d (Global %d) started!",
                GS.bigWave, GS.smallWave, GS.globalWave))

            local waveLabel = string.format("%d-%d", GS.bigWave, GS.smallWave)
            local waveName = M.GetWaveName()
            GameUI.ShowAnnouncement(
                "敌袭来临",
                string.format("Wave %s「%s」", waveLabel, waveName),
                nil
            )
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

                        -- 路径起点刷怪
                        local path = currentLevelData_.paths[g.pathIdx]
                        if not path then path = currentLevelData_.paths[1] end

                        local sx, sz = RandomSpawnOnPath(path)
                        local pathData = BuildPathData(path)

                        Monster.SpawnMonster(g.enemy_id, {
                            spawnX = sx,
                            spawnZ = sz,
                            waveNumber = GS.globalWave,
                            eliteAffixes = g.elite_affixes,
                            pathData = pathData,
                            pathWidth = path.width,
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
            local waveLabel = string.format("%d-%d", GS.bigWave, GS.smallWave)
            GameUI.ShowAnnouncement(
                "波次完成",
                string.format("Wave %s 已清除", waveLabel),
                { 80, 240, 120, 255 }
            )

            -- 波次完成奖励
            local bonusGold = 20 + GS.globalWave * 10
            local bonusMat = GS.globalWave * 3
            GS.gold = GS.gold + bonusGold
            GS.material = GS.material + bonusMat
            print(string.format("[Wave] Global %d cleared! Bonus: +%d gold, +%d material",
                GS.globalWave, bonusGold, bonusMat))

            -- 检查关卡是否完成 (8波一关)
            if GS.smallWave >= CONFIG.BigWaveSize then
                -- 关卡通关!
                GameUI.ShowAnnouncement(
                    string.format("关卡 %d 通关!", GS.bigWave),
                    string.format("「%s」已征服", currentLevelData_.name),
                    { 255, 215, 0, 255 }  -- 金色
                )
                print(string.format("[Wave] ★ Level %d CLEAR! ★", GS.bigWave))
            end

            -- 触发圣器掉落
            Artifact.TriggerWaveDrop()
            if GS.artifactDropPending then
                GS.wavePhase = "dropping"
                print("[Wave] Entering artifact drop selection...")
            else
                GS.wavePhase = "waiting"
                print("[Wave] Waiting for player to press SPACE...")
            end
        end
        return
    end

    -- === 圣器掉落选择阶段 ===
    if GS.wavePhase == "dropping" then
        if not GS.artifactDropPending then
            GS.wavePhase = "waiting"
            print("[Wave] Artifact done, waiting for player to press SPACE...")
        end
        return
    end

    -- === 等待阶段 ===
    if GS.wavePhase == "waiting" then
        if input:GetKeyPress(KEY_SPACE) then
            M.StartWave()
        end
        return
    end
end

-- ============================================================================
-- UI 信息
-- ============================================================================

function M.GetWaveName()
    local bw = GS.bigWave
    local sw = GS.smallWave
    if sw == CONFIG.MiniBossSubWave then
        return "小Boss: 裂山巨像"
    elseif sw == CONFIG.BigBossSubWave then
        return "大Boss: 吞线母体"
    end

    if bw <= 1 then return "先锋进攻"
    elseif bw <= 2 then return "多路夹击"
    elseif bw <= 3 then return "精英混战"
    elseif bw <= 5 then return "全面攻势"
    else return "无尽浪潮"
    end
end

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
        summary = isBoss and bossName or string.format("~%d 怪物", math.floor(8 + nextGlobal * 2.0)),
        totalMonsters = 0,
    }
end

function M.GetWaveInfo()
    local phase = GS.wavePhase
    local bw = GS.bigWave
    local sw = GS.smallWave

    local waveLabel = string.format("Lv%d W%d", bw, sw)

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
    elseif phase == "waiting" then
        return string.format("%s 已完成 | 按空格开始下一波", waveLabel)
    else
        return string.format("%s", waveLabel)
    end
end

--- 兼容旧接口: 获取出怪方向 (路径起点方向)
function M.GetBigWaveAngles()
    if not currentLevelData_ then return {} end
    local angles = {}
    for _, path in ipairs(currentLevelData_.paths) do
        local wp = path.waypoints[1]
        if wp then
            table.insert(angles, math.atan(wp.z, wp.x))
        end
    end
    return angles
end

function M.GetActiveSpawnAngles()
    return M.GetBigWaveAngles()
end

return M
