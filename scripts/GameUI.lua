-- ============================================================================
-- GameUI.lua — UI 初始化 / HUD 刷新 / 升级面板 / 波次信息 / GameOver
-- ============================================================================

local UI = require("urhox-libs/UI")
local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS

local M = {}

-- UI 控件引用
local goldLabel_ = nil
local materialLabel_ = nil
local energyLabel_ = nil
local costLabel_ = nil
local statsLabel_ = nil
local hintLabel_ = nil
local waveLabel_ = nil

-- 升级面板
local upgradePanel_ = nil
local upgradeLevelLabel_ = nil
local upgradeInfoLabel_ = nil
local upgradeCostLabel_ = nil
local upgradeBtn_ = nil
local upgradePanelVisible_ = false

-- 游戏主 HUD root（用于切换到 GameOver/Victory 时替换）
local hudRoot_ = nil

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
    -- 三资源标签
    goldLabel_ = UI.Label {
        text = "",
        fontSize = 15,
        fontColor = { 255, 215, 0, 255 },
    }
    materialLabel_ = UI.Label {
        text = "",
        fontSize = 15,
        fontColor = { 100, 220, 120, 255 },
    }
    energyLabel_ = UI.Label {
        text = "",
        fontSize = 15,
        fontColor = { 100, 180, 255, 255 },
    }
    costLabel_ = UI.Label {
        text = "",
        fontSize = 12,
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

    -- 升级面板组件
    upgradeLevelLabel_ = UI.Label {
        text = "",
        fontSize = 16,
        fontColor = { 255, 220, 80, 255 },
    }
    upgradeInfoLabel_ = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 200, 220, 240, 220 },
    }
    upgradeCostLabel_ = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 200, 200, 200, 200 },
    }
    upgradeBtn_ = UI.Button {
        text = "Upgrade",
        variant = "primary",
        width = 120,
        height = 32,
        fontSize = 14,
        onClick = function(self)
            local EnergyTower = require("EnergyTower")
            if EnergyTower.Upgrade() then
                M.RefreshUpgradePanel()
                -- 升级后范围可能变化，需要更新范围圈
                local Scene = require("Scene")
                if Scene.UpdateRangeCircle then
                    Scene.UpdateRangeCircle()
                end
            end
        end,
    }

    upgradePanel_ = UI.Panel {
        position = "absolute",
        bottom = 50, left = 8,
        flexDirection = "column", gap = 6,
        backgroundColor = { 15, 20, 35, 210 },
        borderRadius = 8, paddingX = 14, paddingY = 10,
        borderWidth = 1, borderColor = { 80, 140, 200, 180 },
        display = "none",
        children = {
            upgradeLevelLabel_,
            upgradeInfoLabel_,
            upgradeCostLabel_,
            upgradeBtn_,
        }
    }

    hudRoot_ = UI.Panel {
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
                    -- 左：三资源 + 造塔费用
                    UI.Panel {
                        flexDirection = "column", gap = 3,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { goldLabel_, materialLabel_, energyLabel_, costLabel_ }
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
            -- 升级面板 (左下角)
            upgradePanel_,
            -- 底部提示
            hintLabel_,
        }
    }
    UI.SetRoot(hudRoot_)

    M.RefreshUI()
end

-- ============================================================================
-- 升级面板刷新
-- ============================================================================

function M.RefreshUpgradePanel()
    local EnergyTower = require("EnergyTower")
    local stats = EnergyTower.GetLevelStats()

    if upgradeLevelLabel_ then
        upgradeLevelLabel_:SetText(string.format("Energy Tower  Lv.%d", GS.etLevel))
    end

    if upgradeInfoLabel_ then
        upgradeInfoLabel_:SetText(string.format(
            "Power: %d  HP: %d/%d  Range: %d  Eff: %.2f",
            stats.power, GS.etHP, GS.etMaxHP, stats.radius, stats.convEff
        ))
    end

    local cost = EnergyTower.GetUpgradeCost()
    if cost then
        if upgradeCostLabel_ then
            upgradeCostLabel_:SetText(string.format(
                "Cost: %d Gold + %d Material", cost.gold, cost.material
            ))
        end
        if upgradeBtn_ then
            local canUp = EnergyTower.CanUpgrade()
            upgradeBtn_:SetText(canUp and "Upgrade" or "Insufficient")
            upgradeBtn_:SetDisabled(not canUp)
        end
    else
        if upgradeCostLabel_ then
            upgradeCostLabel_:SetText("MAX LEVEL")
        end
        if upgradeBtn_ then
            upgradeBtn_:SetText("Max Lv.")
            upgradeBtn_:SetDisabled(true)
        end
    end
end

function M.ShowUpgradePanel()
    if not upgradePanel_ then return end
    upgradePanel_:SetStyle("display", "flex")
    upgradePanelVisible_ = true
    M.RefreshUpgradePanel()
end

function M.HideUpgradePanel()
    if not upgradePanel_ then return end
    upgradePanel_:SetStyle("display", "none")
    upgradePanelVisible_ = false
end

-- ============================================================================
-- 每帧刷新 HUD
-- ============================================================================

function M.RefreshUI()
    local Tower = require("Tower")
    local Wave = require("Wave")

    local cost = Tower.GetTowerCost()
    local canBuild = GS.gold >= cost

    -- 三资源
    if goldLabel_ then
        goldLabel_:SetText("Gold: " .. GS.gold)
    end
    if materialLabel_ then
        materialLabel_:SetText("Material: " .. GS.material)
    end
    if energyLabel_ then
        energyLabel_:SetText("Energy: " .. GS.energy)
    end
    if costLabel_ then
        local costStr = "Next tower: " .. cost
        if not canBuild then
            costStr = costStr .. "  (insufficient)"
        end
        costLabel_:SetText(costStr)
    end

    -- 能源统计 + 等级
    if statsLabel_ then
        local EnergyTower = require("EnergyTower")
        local n = #GS.towers
        local nm = #GS.monsters
        if n == 0 then
            statsLabel_:SetText(string.format(
                "Lv.%d | HP: %d/%d | Towers: 0 | Mobs: %d",
                GS.etLevel, GS.etHP, GS.etMaxHP, nm
            ))
        else
            local totalDel = 0
            for _, t in ipairs(GS.towers) do
                totalDel = totalDel + t.delivered
            end
            statsLabel_:SetText(string.format(
                "Lv.%d | HP: %d/%d | T: %d | M: %d | Pwr: %.0f",
                GS.etLevel, GS.etHP, GS.etMaxHP, n, nm, totalDel
            ))
        end
    end

    -- 波次信息
    if waveLabel_ then
        waveLabel_:SetText(Wave.GetWaveInfo())
    end

    -- 升级面板实时刷新（如果可见）
    if upgradePanelVisible_ then
        M.RefreshUpgradePanel()
    end

    -- 悬停提示 + 升级面板显隐
    M.UpdateHintLabel()
end

-- ============================================================================
-- 悬停提示文本 + 升级面板触发
-- ============================================================================

function M.UpdateHintLabel()
    if not hintLabel_ then return end

    local Tower = require("Tower")
    local EnergyTower = require("EnergyTower")

    if not GS.hoverOnMap then
        hintLabel_:SetText("Left Click: Build Tower | Middle Drag: Pan | Scroll: Zoom")
        if upgradePanelVisible_ then
            M.HideUpgradePanel()
        end
        return
    end

    local gx, gz = GS.hoverGX, GS.hoverGZ
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
    local canAfford = GS.gold >= Tower.GetTowerCost()

    if isEnergyTower then
        hintLabel_:SetText(string.format(
            "Energy Tower Lv.%d | Power: %d | Range: %d | ConvEff: %.2f | [U] Upgrade",
            GS.etLevel, EnergyTower.GetTotalPower(), EnergyTower.GetEnergyRange(), EnergyTower.GetConvEff()
        ))
        -- 悬停能源塔时显示升级面板
        if not upgradePanelVisible_ then
            M.ShowUpgradePanel()
        end
        -- U 键快捷升级
        if input:GetKeyPress(KEY_U) then
            if EnergyTower.Upgrade() then
                M.RefreshUpgradePanel()
                local Scene = require("Scene")
                if Scene.UpdateRangeCircle then
                    Scene.UpdateRangeCircle()
                end
            end
        end
    elseif isOccupied then
        if upgradePanelVisible_ then M.HideUpgradePanel() end
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
        if upgradePanelVisible_ then M.HideUpgradePanel() end
        hintLabel_:SetText("Out of energy range!")
    elseif not canAfford then
        if upgradePanelVisible_ then M.HideUpgradePanel() end
        hintLabel_:SetText("Not enough gold! Need: " .. Tower.GetTowerCost())
    else
        if upgradePanelVisible_ then M.HideUpgradePanel() end
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
