-- ============================================================================
-- Wave.lua — 数据驱动波次 / 多路径 / spawn_groups / 阶段管理
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Monster = require("Monster")
local Artifact = require("Artifact")

local M = {}

-- ============================================================================
-- 路径定义 (从 waves.json 转换为世界坐标, 能源塔在原点)
-- waves.json 中 energy_tower_position = [10, 7]
-- 世界坐标 = json坐标 - [10, 7]
-- ============================================================================
M.PATHS = {
    path_north = {
        { x = 10, z = -4 },   -- [20, 3] 出生点
        { x = 0,  z = -4 },   -- [10, 3] 拐角
        { x = 0,  z = 0  },   -- [10, 7] 能源塔
    },
    path_south = {
        { x = 10, z = 5 },    -- [20, 12] 出生点
        { x = 0,  z = 5 },    -- [10, 12] 拐角
        { x = 0,  z = 0 },    -- [10, 7] 能源塔
    },
}

-- ============================================================================
-- 20 波配置 (从 waves.json 转换)
-- 每波含 spawn_groups, 每组独立计时
-- ============================================================================
M.WAVES = {
    -- === 开局 (1-5): 教学 ===
    [1] = {
        name = "教学：第一只怪",
        prepTime = 30,
        spawn_groups = {
            { enemy_id = "walker", count = 5, interval = 2.0, path = "path_north", delay = 0 },
        },
    },
    [2] = {
        name = "教学：能源线价值",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "walker", count = 10, interval = 1.5, path = "path_north", delay = 0 },
        },
    },
    [3] = {
        name = "群虫袭来",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "swarm", count = 25, interval = 0.6, path = "path_north", delay = 0 },
        },
    },
    [4] = {
        name = "疾行者突袭",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "walker",   count = 8, interval = 1.5, path = "path_north", delay = 0 },
            { enemy_id = "sprinter", count = 5, interval = 1.0, path = "path_south", delay = 5 },
        },
    },
    [5] = {
        name = "首个精英",
        prepTime = 20,
        spawn_groups = {
            { enemy_id = "walker", count = 12, interval = 1.2, path = "path_north", delay = 0 },
            { enemy_id = "walker", count = 1,  interval = 0,   path = "path_south", delay = 8, elite_affixes = { "thick_armor" } },
        },
    },

    -- === 扩张 (6-10): 双路压力 + Boss ===
    [6] = {
        name = "双路压力",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "walker", count = 15, interval = 1.0, path = "path_north", delay = 0 },
            { enemy_id = "swarm",  count = 20, interval = 0.8, path = "path_south", delay = 3 },
        },
    },
    [7] = {
        name = "甲壳兽登场",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "shellbeast", count = 6,  interval = 2.5, path = "path_north", delay = 0 },
            { enemy_id = "walker",     count = 12, interval = 1.5, path = "path_south", delay = 5 },
        },
    },
    [8] = {
        name = "护盾混合",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "shielded", count = 8,  interval = 2.0, path = "path_north", delay = 0 },
            { enemy_id = "swarm",    count = 30, interval = 0.5, path = "path_south", delay = 8 },
        },
    },
    [9] = {
        name = "迅捷精英",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "walker",   count = 20, interval = 1.0, path = "path_north", delay = 0 },
            { enemy_id = "sprinter", count = 3,  interval = 1.5, path = "path_south", delay = 5, elite_affixes = { "swift" } },
        },
    },
    [10] = {
        name = "Boss: 裂山巨像",
        prepTime = 25,
        spawn_groups = {
            { enemy_id = "shatter_titan", count = 1,  interval = 0,   path = "path_north", delay = 0 },
            { enemy_id = "swarm",         count = 30, interval = 0.5, path = "path_south", delay = 10 },
        },
    },

    -- === 构筑 (11-15): 精英频繁 ===
    [11] = {
        name = "吞能者初现",
        prepTime = 20,
        spawn_groups = {
            { enemy_id = "energy_devourer", count = 5,  interval = 2.5, path = "path_north", delay = 0 },
            { enemy_id = "walker",          count = 25, interval = 1.0, path = "path_south", delay = 5 },
        },
    },
    [12] = {
        name = "抗燃精英",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "shellbeast", count = 8,  interval = 2.0, path = "path_north", delay = 0, elite_affixes = { "burn_resist" } },
            { enemy_id = "swarm",      count = 35, interval = 0.4, path = "path_south", delay = 5 },
        },
    },
    [13] = {
        name = "吸能精英",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "energy_devourer", count = 8,  interval = 2.0, path = "path_north", delay = 0, elite_affixes = { "energy_drinker" } },
            { enemy_id = "sprinter",        count = 10, interval = 1.0, path = "path_south", delay = 8 },
        },
    },
    [14] = {
        name = "全混合波",
        prepTime = 20,
        spawn_groups = {
            { enemy_id = "walker",    count = 15, interval = 1.0, path = "path_north", delay = 0 },
            { enemy_id = "shellbeast", count = 5,  interval = 2.0, path = "path_north", delay = 5 },
            { enemy_id = "shielded",  count = 10, interval = 1.5, path = "path_south", delay = 0 },
            { enemy_id = "sprinter",  count = 8,  interval = 1.2, path = "path_south", delay = 8 },
        },
    },
    [15] = {
        name = "压力测试",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "swarm",           count = 50, interval = 0.3, path = "path_north", delay = 0 },
            { enemy_id = "shellbeast",      count = 4,  interval = 2.0, path = "path_south", delay = 0, elite_affixes = { "thick_armor", "burn_resist" } },
            { enemy_id = "energy_devourer", count = 5,  interval = 1.5, path = "path_south", delay = 10 },
        },
    },

    -- === 压力 (16-19): 大规模混战 ===
    [16] = {
        name = "护盾大军",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "shielded", count = 20, interval = 1.0, path = "path_north", delay = 0 },
            { enemy_id = "shielded", count = 15, interval = 1.0, path = "path_south", delay = 5 },
        },
    },
    [17] = {
        name = "三重精英",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "shellbeast", count = 1, interval = 0, path = "path_north", delay = 0,  elite_affixes = { "thick_armor", "burn_resist", "energy_drinker" } },
            { enemy_id = "sprinter",   count = 1, interval = 0, path = "path_north", delay = 5,  elite_affixes = { "swift", "energy_drinker" } },
            { enemy_id = "walker",     count = 1, interval = 0, path = "path_south", delay = 10, elite_affixes = { "thick_armor", "swift" } },
            { enemy_id = "swarm",      count = 40, interval = 0.4, path = "path_south", delay = 15 },
        },
    },
    [18] = {
        name = "决战前奏",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "walker",          count = 30, interval = 0.8, path = "path_north", delay = 0 },
            { enemy_id = "shellbeast",      count = 10, interval = 1.5, path = "path_north", delay = 5 },
            { enemy_id = "shielded",        count = 15, interval = 1.0, path = "path_south", delay = 0 },
            { enemy_id = "energy_devourer", count = 10, interval = 1.5, path = "path_south", delay = 8 },
        },
    },
    [19] = {
        name = "极限混乱",
        prepTime = 15,
        spawn_groups = {
            { enemy_id = "swarm",      count = 80, interval = 0.25, path = "path_north", delay = 0 },
            { enemy_id = "swarm",      count = 80, interval = 0.25, path = "path_south", delay = 0 },
            { enemy_id = "shellbeast", count = 5,  interval = 1.5,  path = "path_north", delay = 15, elite_affixes = { "thick_armor" } },
            { enemy_id = "sprinter",   count = 10, interval = 0.8,  path = "path_south", delay = 20, elite_affixes = { "swift" } },
        },
    },

    -- === 决战 (20): Boss ===
    [20] = {
        name = "Boss: 吞线母体",
        prepTime = 30,
        spawn_groups = {
            { enemy_id = "line_devourer", count = 1,  interval = 0,   path = "path_north", delay = 0 },
            { enemy_id = "walker",        count = 30, interval = 1.0, path = "path_south", delay = 15 },
        },
    },
}

M.TOTAL_WAVES = 20

-- ============================================================================
-- 波次运行时状态
-- ============================================================================

-- 当前波次活跃的 spawn groups (运行时副本)
local activeGroups_ = {}

-- 当前波次总怪物数 & 已刷数 (用于 UI 显示)
local totalMonstersInWave_ = 0
local spawnedMonstersInWave_ = 0

--- 计算一波的总怪物数
local function CountWaveMonsters(waveDef)
    local total = 0
    for _, sg in ipairs(waveDef.spawn_groups) do
        total = total + sg.count
    end
    return total
end

--- 开始新一波
function M.StartWave()
    GS.currentWave = GS.currentWave + 1
    if GS.currentWave > M.TOTAL_WAVES then
        GS.wavePhase = "victory"
        print("[Wave] All waves cleared! Victory!")
        return
    end

    local waveDef = M.WAVES[GS.currentWave]
    GS.wavePhase = "preparing"
    GS.waveTimer = waveDef.prepTime

    -- 构建活跃 spawn groups
    activeGroups_ = {}
    for _, sg in ipairs(waveDef.spawn_groups) do
        table.insert(activeGroups_, {
            enemy_id = sg.enemy_id,
            count = sg.count,
            interval = sg.interval,
            pathData = M.PATHS[sg.path],
            delay = sg.delay,
            elite_affixes = sg.elite_affixes or {},
            -- 运行时
            spawned = 0,
            timer = 0,
            delayRemaining = sg.delay,
        })
    end

    totalMonstersInWave_ = CountWaveMonsters(waveDef)
    spawnedMonstersInWave_ = 0

    print(string.format("[Wave] Preparing Wave %d/%d \"%s\" (%d monsters, %d groups, %.0fs prep)",
        GS.currentWave, M.TOTAL_WAVES, waveDef.name,
        totalMonstersInWave_, #waveDef.spawn_groups, waveDef.prepTime))
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
    if GS.currentWave == 0 then
        M.StartWave()
        return
    end

    if GS.wavePhase == "victory" then return end

    -- === 准备阶段 ===
    if GS.wavePhase == "preparing" then
        GS.waveTimer = GS.waveTimer - dt

        if input:GetKeyPress(KEY_SPACE) then
            M.SkipPrepare()
        end

        if GS.waveTimer <= 0 then
            GS.wavePhase = "spawning"
            print(string.format("[Wave] Wave %d \"%s\" started!",
                GS.currentWave, M.WAVES[GS.currentWave].name))
        end
        return
    end

    -- === 刷怪阶段 ===
    if GS.wavePhase == "spawning" then
        local allDone = true

        for _, g in ipairs(activeGroups_) do
            if g.spawned < g.count then
                -- 还有怪未刷出
                if g.delayRemaining > 0 then
                    -- 延迟未到
                    g.delayRemaining = g.delayRemaining - dt
                    allDone = false
                else
                    -- 延迟已过，按间隔刷怪
                    g.timer = g.timer + dt

                    -- 首只怪立即刷 (timer 从 0 开始，首帧 interval=0 或累积足够)
                    local threshold = g.interval
                    if g.spawned == 0 then threshold = 0 end

                    if g.timer >= threshold then
                        g.timer = g.timer - math.max(g.interval, 0.01) -- 防止 interval=0 死循环

                        g.spawned = g.spawned + 1
                        spawnedMonstersInWave_ = spawnedMonstersInWave_ + 1

                        Monster.SpawnMonster(g.enemy_id, {
                            path = g.pathData,
                            waveNumber = GS.currentWave,
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
            -- g.spawned >= g.count → 此 group 完成
        end

        if allDone then
            GS.wavePhase = "clearing"
            print(string.format("[Wave] All %d monsters spawned for Wave %d, clearing...",
                totalMonstersInWave_, GS.currentWave))
        end
        return
    end

    -- === 清场阶段 ===
    if GS.wavePhase == "clearing" then
        if #GS.monsters == 0 then
            -- 波次完成，发放波次奖励 (基于波次序号的基础奖励)
            local bonusGold = 20 + GS.currentWave * 10
            local bonusMat = GS.currentWave * 3
            GS.gold = GS.gold + bonusGold
            GS.material = GS.material + bonusMat
            print(string.format("[Wave] Wave %d cleared! Bonus: +%d gold, +%d material",
                GS.currentWave, bonusGold, bonusMat))

            if GS.currentWave >= M.TOTAL_WAVES then
                GS.wavePhase = "victory"
                print("[Wave] All waves cleared! Victory!")
            else
                -- 触发圣器掉落 3选1
                Artifact.TriggerWaveDrop()
                if GS.artifactDropPending then
                    GS.wavePhase = "dropping"
                    print("[Wave] Entering artifact drop selection...")
                else
                    M.StartWave()
                end
            end
        end
        return
    end

    -- === 圣器掉落选择阶段 (等待玩家选择，由 UI 调用 Artifact.PickDrop) ===
    if GS.wavePhase == "dropping" then
        if not GS.artifactDropPending then
            -- 玩家已选择，进入下一波
            M.StartWave()
        end
        return
    end
end

-- ============================================================================
-- UI 信息
-- ============================================================================

--- 获取当前波次名称
function M.GetWaveName()
    if GS.currentWave >= 1 and GS.currentWave <= M.TOTAL_WAVES then
        return M.WAVES[GS.currentWave].name
    end
    return ""
end

--- 获取下一波预告
function M.GetNextWavePreview()
    local next = GS.currentWave + 1
    if next > M.TOTAL_WAVES then return nil end
    local waveDef = M.WAVES[next]
    if not waveDef then return nil end

    -- 统计怪物类型
    local typeCounts = {}
    for _, sg in ipairs(waveDef.spawn_groups) do
        typeCounts[sg.enemy_id] = (typeCounts[sg.enemy_id] or 0) + sg.count
    end

    local parts = {}
    for eid, cnt in pairs(typeCounts) do
        local typeDef = Monster.TYPES[eid] or Monster.BOSSES[eid]
        local name = typeDef and typeDef.name or eid
        table.insert(parts, name .. "×" .. cnt)
    end

    return {
        wave = next,
        name = waveDef.name,
        summary = table.concat(parts, " "),
        totalMonsters = CountWaveMonsters(waveDef),
    }
end

--- 获取波次显示信息
function M.GetWaveInfo()
    local phase = GS.wavePhase
    local wave = GS.currentWave

    if phase == "preparing" then
        local waveName = M.GetWaveName()
        return string.format("第 %d/%d 波 「%s」 | %.0f秒 (空格跳过)",
            wave, M.TOTAL_WAVES, waveName, math.max(0, GS.waveTimer))
    elseif phase == "spawning" then
        return string.format("第 %d/%d 波 | 出怪中 %d/%d",
            wave, M.TOTAL_WAVES, spawnedMonstersInWave_, totalMonstersInWave_)
    elseif phase == "clearing" then
        return string.format("第 %d/%d 波 | 清剿中 (剩余 %d)",
            wave, M.TOTAL_WAVES, #GS.monsters)
    elseif phase == "victory" then
        return "胜利！全部 20 波已通关！"
    else
        return string.format("第 %d/%d 波", wave, M.TOTAL_WAVES)
    end
end

return M
