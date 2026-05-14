-- ============================================================================
-- Wave.lua — 波次配置 / 刷怪调度 / 阶段管理
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Monster = require("Monster")

local M = {}

-- ============================================================================
-- 波次配置: 20 波
-- ============================================================================
-- 阶段: 开局(1-5) / 扩张(6-10) / 构筑(11-15) / 压力(16-19) / 决战(20)
M.WAVES = {
    -- === 开局 (1-5): 学会建塔、供能 ===
    [1]  = { monsters = { { type = "zombie", count = 5 } },                              interval = 3.0,  prepTime = 10, reward = { gold = 30 } },
    [2]  = { monsters = { { type = "zombie", count = 8 } },                              interval = 2.5,  prepTime = 8,  reward = { gold = 40 } },
    [3]  = { monsters = { { type = "zombie", count = 6 }, { type = "swarm", count = 8 } }, interval = 2.0, prepTime = 8,  reward = { gold = 50 } },
    [4]  = { monsters = { { type = "swarm", count = 15 } },                              interval = 1.2,  prepTime = 8,  reward = { gold = 40 } },
    [5]  = { monsters = { { type = "zombie", count = 8 }, { type = "sprinter", count = 3 } }, interval = 2.0, prepTime = 10, reward = { gold = 60 } },

    -- === 扩张 (6-10): 引入更多怪物类型 ===
    [6]  = { monsters = { { type = "armored", count = 4 }, { type = "zombie", count = 6 } },    interval = 2.0, prepTime = 10, reward = { gold = 70 } },
    [7]  = { monsters = { { type = "sprinter", count = 8 }, { type = "swarm", count = 10 } },   interval = 1.5, prepTime = 8,  reward = { gold = 80 } },
    [8]  = { monsters = { { type = "shielded", count = 4 }, { type = "zombie", count = 8 } },   interval = 2.0, prepTime = 8,  reward = { gold = 90 } },
    [9]  = { monsters = { { type = "energyEater", count = 3 }, { type = "armored", count = 4 }, { type = "swarm", count = 8 } }, interval = 1.8, prepTime = 10, reward = { gold = 100 } },
    [10] = { monsters = { { type = "armored", count = 6 }, { type = "shielded", count = 4 }, { type = "sprinter", count = 5 } }, interval = 1.5, prepTime = 12, reward = { gold = 120 } },

    -- === 构筑 (11-15): 流派成型，压力上升 ===
    [11] = { monsters = { { type = "zombie", count = 12 }, { type = "swarm", count = 15 }, { type = "sprinter", count = 5 } }, interval = 1.2, prepTime = 10, reward = { gold = 130 } },
    [12] = { monsters = { { type = "armored", count = 8 }, { type = "energyEater", count = 4 } },  interval = 1.8, prepTime = 8,  reward = { gold = 140 } },
    [13] = { monsters = { { type = "shielded", count = 6 }, { type = "sprinter", count = 8 }, { type = "swarm", count = 12 } }, interval = 1.0, prepTime = 10, reward = { gold = 150 } },
    [14] = { monsters = { { type = "energyEater", count = 6 }, { type = "armored", count = 6 }, { type = "zombie", count = 10 } }, interval = 1.2, prepTime = 8, reward = { gold = 160 } },
    [15] = { monsters = { { type = "shielded", count = 8 }, { type = "armored", count = 8 }, { type = "sprinter", count = 6 } }, interval = 1.0, prepTime = 12, reward = { gold = 180 } },

    -- === 压力 (16-19): 大量混合 ===
    [16] = { monsters = { { type = "swarm", count = 25 }, { type = "sprinter", count = 8 }, { type = "energyEater", count = 4 } }, interval = 0.8, prepTime = 10, reward = { gold = 200 } },
    [17] = { monsters = { { type = "armored", count = 10 }, { type = "shielded", count = 6 }, { type = "zombie", count = 15 } }, interval = 1.0, prepTime = 10, reward = { gold = 220 } },
    [18] = { monsters = { { type = "energyEater", count = 8 }, { type = "sprinter", count = 10 }, { type = "swarm", count = 20 } }, interval = 0.8, prepTime = 10, reward = { gold = 250 } },
    [19] = { monsters = { { type = "armored", count = 12 }, { type = "shielded", count = 8 }, { type = "energyEater", count = 6 }, { type = "sprinter", count = 8 } }, interval = 0.8, prepTime = 12, reward = { gold = 300 } },

    -- === 决战 (20): Boss 波 ===
    [20] = { monsters = { { type = "armored", count = 15 }, { type = "shielded", count = 10 }, { type = "energyEater", count = 8 }, { type = "sprinter", count = 10 }, { type = "swarm", count = 20 } }, interval = 0.6, prepTime = 15, reward = { gold = 500 } },
}

M.TOTAL_WAVES = 20

-- ============================================================================
-- 波次状态管理
-- ============================================================================

--- 展开当前波次的怪物列表到有序队列
---@return table 形如 { "zombie", "zombie", "swarm", ... }
local function BuildSpawnQueue(waveIndex)
    local waveDef = M.WAVES[waveIndex]
    if not waveDef then return {} end

    local queue = {}
    for _, group in ipairs(waveDef.monsters) do
        for _ = 1, group.count do
            table.insert(queue, group.type)
        end
    end

    -- 打乱顺序（避免同类型怪物扎堆）
    for i = #queue, 2, -1 do
        local j = math.random(1, i)
        queue[i], queue[j] = queue[j], queue[i]
    end

    return queue
end

-- 当前波次的刷怪队列
local spawnQueue_ = {}

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
    GS.waveSpawnIndex = 0
    GS.waveSpawnTimer = 0
    spawnQueue_ = BuildSpawnQueue(GS.currentWave)

    print(string.format("[Wave] Preparing Wave %d/%d (%d monsters, %.1fs prep)",
        GS.currentWave, M.TOTAL_WAVES, #spawnQueue_, waveDef.prepTime))
end

--- 跳过准备阶段（手动开波）
function M.SkipPrepare()
    if GS.wavePhase == "preparing" then
        GS.waveTimer = 0
        print("[Wave] Preparation skipped!")
    end
end

--- 波次更新（在 HandleUpdate 中每帧调用）
function M.Update(dt)
    if GS.gameOver then return end

    -- 游戏尚未开始：自动开始第一波
    if GS.currentWave == 0 then
        M.StartWave()
        return
    end

    if GS.wavePhase == "victory" then return end

    if GS.wavePhase == "preparing" then
        GS.waveTimer = GS.waveTimer - dt

        -- 空格键跳过准备
        if input:GetKeyPress(KEY_SPACE) then
            M.SkipPrepare()
        end

        if GS.waveTimer <= 0 then
            GS.wavePhase = "spawning"
            GS.waveSpawnTimer = 0
            print(string.format("[Wave] Wave %d started!", GS.currentWave))
        end
        return
    end

    if GS.wavePhase == "spawning" then
        local waveDef = M.WAVES[GS.currentWave]
        GS.waveSpawnTimer = GS.waveSpawnTimer + dt

        if GS.waveSpawnTimer >= waveDef.interval then
            GS.waveSpawnTimer = GS.waveSpawnTimer - waveDef.interval
            GS.waveSpawnIndex = GS.waveSpawnIndex + 1

            if GS.waveSpawnIndex <= #spawnQueue_ then
                Monster.SpawnMonster(spawnQueue_[GS.waveSpawnIndex])
            end

            if GS.waveSpawnIndex >= #spawnQueue_ then
                GS.wavePhase = "clearing"
                print(string.format("[Wave] All monsters spawned for Wave %d, clearing...", GS.currentWave))
            end
        end
        return
    end

    if GS.wavePhase == "clearing" then
        -- 等所有怪物死亡或到达
        if #GS.monsters == 0 then
            -- 波次完成，发放奖励
            local waveDef = M.WAVES[GS.currentWave]
            if waveDef.reward then
                if waveDef.reward.gold then
                    GS.gold = GS.gold + waveDef.reward.gold
                    print(string.format("[Wave] Wave %d cleared! Reward: +%d gold", GS.currentWave, waveDef.reward.gold))
                end
            end

            -- 是否是最后一波
            if GS.currentWave >= M.TOTAL_WAVES then
                GS.wavePhase = "victory"
                print("[Wave] All waves cleared! Victory!")
            else
                -- 开始下一波
                M.StartWave()
            end
        end
        return
    end
end

--- 获取当前波次的显示信息
function M.GetWaveInfo()
    local phase = GS.wavePhase
    local wave = GS.currentWave

    if phase == "preparing" then
        return string.format("Wave %d/%d | Starting in %.0fs (SPACE to skip)",
            wave, M.TOTAL_WAVES, math.max(0, GS.waveTimer))
    elseif phase == "spawning" then
        return string.format("Wave %d/%d | Spawning... (%d/%d)",
            wave, M.TOTAL_WAVES, GS.waveSpawnIndex, #spawnQueue_)
    elseif phase == "clearing" then
        return string.format("Wave %d/%d | Clearing... (%d remaining)",
            wave, M.TOTAL_WAVES, #GS.monsters)
    elseif phase == "victory" then
        return "VICTORY! All 20 waves cleared!"
    else
        return string.format("Wave %d/%d", wave, M.TOTAL_WAVES)
    end
end

return M
