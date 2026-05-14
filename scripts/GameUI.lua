-- ============================================================================
-- GameUI.lua — UI 初始化 / HUD 刷新 / 波次信息 / GameOver
-- ============================================================================

local UI = require("urhox-libs/UI")
local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS

local M = {}

-- UI 控件引用
local goldLabel_ = nil
local costLabel_ = nil
local statsLabel_ = nil
local hintLabel_ = nil
local waveLabel_ = nil

-- ============================================================================
-- 初始化
-- ============================================================================

function M.InitUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })
end

function M.CreateGameUI()
    goldLabel_ = UI.Label {
        text = "",
        fontSize = 16,
        fontColor = { 255, 215, 0, 255 },
    }
    costLabel_ = UI.Label {
        text = "",
        fontSize = 13,
        fontColor = { 200, 200, 200, 200 },
    }
    statsLabel_ = UI.Label {
        text = "",
        fontSize = 13,
        fontColor = { 180, 220, 255, 230 },
    }
    waveLabel_ = UI.Label {
        text = "",
        fontSize = 14,
        fontColor = { 255, 220, 140, 240 },
    }
    hintLabel_ = UI.Label {
        text = "Left Click: Build Tower | Middle Drag: Pan | Scroll: Zoom",
        fontSize = 12,
        fontColor = { 255, 255, 230, 160 },
        position = "absolute",
        bottom = 10, left = 0, right = 0,
        textAlign = "center",
    }

    local root = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            -- 顶部状态栏
            UI.Panel {
                position = "absolute", top = 8, left = 8, right = 8,
                flexDirection = "row", justifyContent = "space-between",
                alignItems = "flex-start",
                pointerEvents = "box-none",
                children = {
                    -- 左：金币 + 造塔费用
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { goldLabel_, costLabel_ }
                    },
                    -- 中：波次信息
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { waveLabel_ }
                    },
                    -- 右：能源统计
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { statsLabel_ }
                    },
                }
            },
            -- 底部提示
            hintLabel_,
        }
    }
    UI.SetRoot(root)

    M.RefreshUI()
end

-- ============================================================================
-- 每帧刷新 HUD
-- ============================================================================

function M.RefreshUI()
    -- 需要 Tower 模块获取造塔费用，延迟 require 避免循环
    local Tower = require("Tower")
    local Wave = require("Wave")

    local cost = Tower.GetTowerCost()
    local canBuild = GS.gold >= cost

    if goldLabel_ then
        goldLabel_:SetText("Gold: " .. GS.gold)
    end
    if costLabel_ then
        local costStr = "Next tower: " .. cost
        if not canBuild then
            costStr = costStr .. "  (insufficient)"
        end
        costLabel_:SetText(costStr)
    end

    -- 能源统计
    if statsLabel_ then
        local n = #GS.towers
        local nm = #GS.monsters
        if n == 0 then
            statsLabel_:SetText(string.format(
                "Base HP: %d/%d | Towers: 0 | Monsters: %d",
                GS.etHP, GS.etMaxHP, nm
            ))
        else
            local totalDel = 0
            for _, t in ipairs(GS.towers) do
                totalDel = totalDel + t.delivered
            end
            statsLabel_:SetText(string.format(
                "Base HP: %d/%d | Towers: %d | Monsters: %d | Eff: %.0f",
                GS.etHP, GS.etMaxHP, n, nm, totalDel
            ))
        end
    end

    -- 波次信息
    if waveLabel_ then
        waveLabel_:SetText(Wave.GetWaveInfo())
    end

    -- 悬停提示
    M.UpdateHintLabel()
end

-- ============================================================================
-- 悬停提示文本
-- ============================================================================

function M.UpdateHintLabel()
    if not hintLabel_ then return end

    local Tower = require("Tower")
    local EnergyTower = require("EnergyTower")

    if not GS.hoverOnMap then
        hintLabel_:SetText("Left Click: Build Tower | Middle Drag: Pan | Scroll: Zoom")
        return
    end

    local gx, gz = GS.hoverGX, GS.hoverGZ
    local dist = math.sqrt(gx * gx + gz * gz)
    local inRange = dist <= CONFIG.EnergyRange + 0.01
    local isEnergyTower = (gx == 0 and gz == 0)
    local isOccupied = false
    for _, tower in ipairs(GS.towers) do
        if tower.gx == gx and tower.gz == gz then
            isOccupied = true
            break
        end
    end
    local canAfford = GS.gold >= Tower.GetTowerCost()

    if isEnergyTower then
        hintLabel_:SetText(string.format(
            "Energy Tower | Total Power: %d | Range: %d | Base Dmg: %d",
            CONFIG.TotalPower, CONFIG.EnergyRange, CONFIG.TowerBaseDmg
        ))
    elseif isOccupied then
        for _, tower in ipairs(GS.towers) do
            if tower.gx == gx and tower.gz == gz then
                local att = EnergyTower.CalcAttenuation(tower.dist)
                local dmg = CONFIG.TowerBaseDmg * att
                hintLabel_:SetText(string.format(
                    "Tower (%d,%d) | Dist: %.1f | Attn: %.0f%% | Dmg: %.1f | Power: %.0f%%",
                    gx, gz, tower.dist, att * 100, dmg, tower.ratio * 100
                ))
                break
            end
        end
    elseif not inRange then
        hintLabel_:SetText("Out of energy range!")
    elseif not canAfford then
        hintLabel_:SetText("Not enough gold! Need: " .. Tower.GetTowerCost())
    else
        local att = EnergyTower.CalcAttenuation(dist)
        local dmg = CONFIG.TowerBaseDmg * att
        hintLabel_:SetText(string.format(
            "Click to build | Cost: %d | Dist: %.1f | Attn: %.0f%% | Dmg: %.1f",
            Tower.GetTowerCost(), dist, att * 100, dmg
        ))
    end
end

-- ============================================================================
-- GameOver / Victory 覆盖层
-- ============================================================================

function M.ShowGameOver()
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 12,
                backgroundColor = { 30, 10, 10, 220 },
                borderRadius = 12, paddingX = 40, paddingY = 30,
                children = {
                    UI.Label {
                        text = "GAME OVER",
                        fontSize = 36,
                        fontColor = { 255, 60, 60, 255 },
                    },
                    UI.Label {
                        text = string.format("Wave: %d/%d | Towers Built: %d | Monsters Killed: %d",
                            GS.currentWave, 20, #GS.towers, GS.monstersKilled),
                        fontSize = 16,
                        fontColor = { 200, 200, 200, 220 },
                    },
                    UI.Label {
                        text = "Energy Tower Destroyed",
                        fontSize = 14,
                        fontColor = { 255, 180, 100, 200 },
                    },
                }
            }
        }
    }
    UI.SetRoot(overlay)
end

function M.ShowVictory()
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 12,
                backgroundColor = { 10, 30, 10, 220 },
                borderRadius = 12, paddingX = 40, paddingY = 30,
                children = {
                    UI.Label {
                        text = "VICTORY!",
                        fontSize = 36,
                        fontColor = { 60, 255, 60, 255 },
                    },
                    UI.Label {
                        text = string.format("All 20 waves cleared! | Towers: %d | Gold: %d",
                            #GS.towers, GS.gold),
                        fontSize = 16,
                        fontColor = { 200, 255, 200, 220 },
                    },
                    UI.Label {
                        text = "Congratulations, Commander!",
                        fontSize = 14,
                        fontColor = { 255, 220, 100, 200 },
                    },
                }
            }
        }
    }
    UI.SetRoot(overlay)
end

function M.Shutdown()
    UI.Shutdown()
end

return M
