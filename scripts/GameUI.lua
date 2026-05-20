-- ============================================================================
-- GameUI.lua — UI 初始化 / HUD 刷新 / 升级面板 / 波次信息 / GameOver
--              / 圣器拖拽装配 / 塔详情面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local DragDropContext = require("urhox-libs/UI/Components/DragDropContext")
local ItemSlot = require("urhox-libs/UI/Components/ItemSlot")
local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Artifact = require("Artifact")

local M = {}

-- ============================================================================
-- 颜色层级系统 (CLR)
-- ============================================================================

local CLR = {
    -- 信息层级
    gold       = { 255, 215, 50, 255 },   -- 关键 (金币、标题)
    energy     = { 80, 220, 255, 255 },    -- 能量主题 (青蓝)
    success    = { 80, 240, 120, 255 },    -- 正面 (材料、满血)
    danger     = { 255, 80, 80, 255 },     -- 警告 (不足、危险)
    warning    = { 255, 180, 60, 255 },    -- 注意 (中等重要)
    secondary  = { 190, 200, 220, 200 },   -- 次要描述
    muted      = { 130, 140, 160, 150 },   -- 提示 / 禁用
    bright     = { 240, 245, 255, 240 },   -- 高亮白

    -- 面板样式
    panelBg    = { 10, 14, 30, 220 },
    panelBorder = { 55, 90, 150, 160 },
    panelShadow = {{ x = 0, y = 2, blur = 12, spread = 0, color = { 0, 0, 0, 80 } }},
    divider    = { 50, 80, 140, 100 },
}

-- ============================================================================
-- 动画追踪
-- ============================================================================

local prevGold_ = 0
local prevMaterial_ = 0
local prevEnergy_ = 0
local prevHP_ = 0

-- ============================================================================
-- UI 控件引用
-- ============================================================================

local goldLabel_ = nil
local materialLabel_ = nil
local energyLabel_ = nil
local costLabel_ = nil
local statsLabel_ = nil
local hintLabel_ = nil
local waveLabel_ = nil
local powerLabel_ = nil
local previewLabel_ = nil

-- 布线按钮
local wiringBtn_ = nil

-- 速度按钮
local speedBtn1_ = nil
local speedBtn2_ = nil
local speedBtn3_ = nil
local speedPanel_ = nil

-- 升级面板
local upgradePanel_ = nil
local upgradeLevelLabel_ = nil
local upgradeInfoLabel_ = nil
local upgradeCostLabel_ = nil
local upgradeBtn_ = nil
local upgradePanelVisible_ = false

-- ============================================================================
-- 统一 Root 管理（单一 gameRoot_，子面板 Show/Hide）
-- ============================================================================

local gameRoot_ = nil
local hudLayer_ = nil
local inventoryPanel_ = nil
local towerDetailPanel_ = nil
local dropOverlay_ = nil

-- 状态
local dropOverlayVisible_ = false
local artifactPanelVisible_ = false
local towerDetailVisible_ = false
local currentDetailTower_ = nil

-- ---- 背包面板动画 ----
local INV_PANEL_HEIGHT = 120
local INV_BOTTOM_SHOWN = 8
local INV_BOTTOM_HIDDEN = -(INV_PANEL_HEIGHT + 20)
local INV_ANIM_DURATION = 0.35

local invCurrentBottom_ = INV_BOTTOM_HIDDEN
local invAnimStartTime_ = 0
local invAnimFrom_ = INV_BOTTOM_HIDDEN
local invAnimTo_ = INV_BOTTOM_HIDDEN
local invAnimating_ = false
local invAnimDirection_ = "hide"

-- ============================================================================
-- 缓动函数
-- ============================================================================

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1) * (t - 1) * (t - 1) + c1 * (t - 1) * (t - 1)
end

local function easeInCubic(t)
    return t * t * t
end

-- 拖拽上下文
local dragCtx_ = nil

-- 背包 ItemSlot 列表
local invSlots_ = {}
local detailMainSlot_ = nil
local detailSubSlot_ = nil
local detailTitleLabel_ = nil
local detailStatsLabel_ = nil

-- 建塔确认气泡
local placementBubble_ = nil
local placementBubbleCostLabel_ = nil

-- ============================================================================
-- 圣器视觉映射
-- ============================================================================

local ARTIFACT_ICONS = {
    fire_seed      = "火",
    ice_crystal    = "冰",
    coin_magnet    = "磁",
    thunder        = "雷",
    corrosion      = "蚀",
    high_explosive = "爆",
}

local ARTIFACT_BG = {
    fire_seed      = { 60, 20, 10, 230 },
    ice_crystal    = { 15, 30, 60, 230 },
    coin_magnet    = { 45, 40, 10, 230 },
    thunder        = { 30, 20, 55, 230 },
    corrosion      = { 20, 40, 15, 230 },
    high_explosive = { 55, 25, 10, 230 },
}

local function rarityColor(rarity)
    return Artifact.RARITY_COLORS[rarity] or { 200, 200, 200, 255 }
end

local function rarityBorderColor(rarity)
    if rarity == "blue" then return { 80, 160, 255, 200 } end
    if rarity == "purple" then return { 180, 80, 255, 200 } end
    if rarity == "gold" then return { 255, 200, 50, 200 } end
    return { 120, 120, 120, 180 }
end

-- ============================================================================
-- 脉冲动画辅助
-- ============================================================================

local function pulseWidget(widget)
    if not widget then return end
    widget:Animate({
        keyframes = {
            [0]   = { scale = 1.0 },
            [0.4] = { scale = 1.25 },
            [1]   = { scale = 1.0 },
        },
        duration = 0.3,
        easing = "easeOut",
        fillMode = "backwards",
    })
end

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

-- ============================================================================
-- 3D Raycast 辅助
-- ============================================================================

local function raycastToGrid()
    local pos = input.mousePosition
    local sx = pos.x / graphics:GetWidth()
    local sy = pos.y / graphics:GetHeight()
    local ray = GS.camera:GetScreenRay(sx, sy)
    if math.abs(ray.direction.y) < 0.001 then return nil, nil end
    local t = -ray.origin.y / ray.direction.y
    if t <= 0 then return nil, nil end
    local hit = ray.origin + ray.direction * t
    return math.floor(hit.x + 0.5), math.floor(hit.z + 0.5)
end

local function findTowerAt(gx, gz)
    for idx, tower in ipairs(GS.towers) do
        if tower.gx == gx and tower.gz == gz then
            return idx
        end
    end
    return nil
end

-- ============================================================================
-- 拖拽回调
-- ============================================================================

local function handleUISlotDrop(itemData, sourceSlot, targetSlot)
    if not currentDetailTower_ then return end
    local invIndex = itemData.invIndex
    if not invIndex then return end

    local slotId = targetSlot:GetSlotId()
    local slotType = nil
    if slotId == "detail_main" then
        slotType = "main"
    elseif slotId == "detail_sub" then
        slotType = "sub"
    end
    if not slotType then return end

    Artifact.EquipToTower(invIndex, currentDetailTower_, slotType)
    M.RefreshInventoryPanel()
    M.RefreshTowerDetail()
end

local function handleSceneDrop(itemData, sourceSlot)
    local invIndex = itemData.invIndex
    if not invIndex then return end

    local gx, gz = raycastToGrid()
    if not gx then return end

    local towerIndex = findTowerAt(gx, gz)
    if not towerIndex then return end

    local tower = GS.towers[towerIndex]
    local slotType = "main"
    if tower.mainSlot then
        if not tower.subSlot then
            slotType = "sub"
        else
            slotType = "main"
        end
    end

    Artifact.EquipToTower(invIndex, towerIndex, slotType)
    M.RefreshInventoryPanel()
    if towerDetailVisible_ and currentDetailTower_ == towerIndex then
        M.RefreshTowerDetail()
    end
end

-- ============================================================================
-- 创建游戏 UI
-- ============================================================================

function M.CreateGameUI()
    -- ---- HUD 标签 ----
    goldLabel_ = UI.Label {
        text = "", fontSize = 15,
        fontColor = CLR.gold,
        transition = "scale 0.2s easeOut",
    }
    materialLabel_ = UI.Label {
        text = "", fontSize = 15,
        fontColor = CLR.success,
        transition = "scale 0.2s easeOut",
    }
    energyLabel_ = UI.Label {
        text = "", fontSize = 15,
        fontColor = CLR.energy,
        transition = "scale 0.2s easeOut",
    }
    costLabel_ = UI.Label {
        text = "", fontSize = 12,
        fontColor = CLR.secondary,
    }
    statsLabel_ = UI.Label {
        text = "", fontSize = 13,
        fontColor = CLR.bright,
    }
    waveLabel_ = UI.Label {
        text = "", fontSize = 15,
        fontColor = CLR.warning,
        transition = "scale 0.25s easeOut",
    }
    previewLabel_ = UI.Label {
        text = "", fontSize = 11,
        fontColor = CLR.muted,
    }
    powerLabel_ = UI.Label {
        text = "", fontSize = 12,
        fontColor = CLR.energy,
    }
    hintLabel_ = UI.Label {
        text = "左键: 建塔 | 中键拖动: 移动视角 | 滚轮: 缩放",
        fontSize = 12,
        fontColor = { 255, 255, 230, 140 },
        position = "absolute",
        bottom = 10, left = 0, right = 0,
        textAlign = "center",
    }

    -- 速度按钮组
    speedBtn1_ = UI.Button {
        text = "x1", width = 40, height = 26, fontSize = 12,
        variant = "primary",
        transition = "backgroundColor 0.15s easeOut, borderColor 0.15s easeOut",
        onClick = function() GS.gameSpeed = 1 end,
    }
    speedBtn2_ = UI.Button {
        text = "x2", width = 40, height = 26, fontSize = 12,
        transition = "backgroundColor 0.15s easeOut, borderColor 0.15s easeOut",
        onClick = function() GS.gameSpeed = 2 end,
    }
    speedBtn3_ = UI.Button {
        text = "x3", width = 40, height = 26, fontSize = 12,
        transition = "backgroundColor 0.15s easeOut, borderColor 0.15s easeOut",
        onClick = function() GS.gameSpeed = 3 end,
    }
    speedPanel_ = UI.Panel {
        flexDirection = "row", gap = 4, alignItems = "center",
        children = {
            UI.Label { text = "速度:", fontSize = 11, fontColor = CLR.muted },
            speedBtn1_, speedBtn2_, speedBtn3_,
        },
    }

    -- 布线按钮
    wiringBtn_ = UI.Button {
        text = "布线 [E]", width = 76, height = 28, fontSize = 12,
        transition = "backgroundColor 0.15s easeOut",
        onClick = function()
            local EnergyTower = require("EnergyTower")
            EnergyTower.ToggleWiringMode()
        end,
    }

    -- 升级面板
    upgradeLevelLabel_ = UI.Label {
        text = "", fontSize = 16,
        fontColor = CLR.gold,
    }
    upgradeInfoLabel_ = UI.Label {
        text = "", fontSize = 12,
        fontColor = CLR.secondary,
    }
    upgradeCostLabel_ = UI.Label {
        text = "", fontSize = 12,
        fontColor = CLR.secondary,
    }
    upgradeBtn_ = UI.Button {
        text = "升级", variant = "primary",
        width = 120, height = 32, fontSize = 14,
        transition = "opacity 0.2s easeOut",
        onClick = function(self)
            local EnergyTower = require("EnergyTower")
            if EnergyTower.Upgrade() then
                M.RefreshUpgradePanel()
                local Scene = require("Scene")
                if Scene.UpdateRangeCircle then Scene.UpdateRangeCircle() end
            end
        end,
    }
    upgradePanel_ = UI.Panel {
        position = "absolute",
        bottom = 50, left = 8,
        flexDirection = "column", gap = 6,
        backgroundColor = CLR.panelBg,
        borderRadius = 10, paddingX = 16, paddingY = 12,
        borderWidth = 1, borderColor = CLR.panelBorder,
        boxShadow = CLR.panelShadow,
        display = "none",
        children = { upgradeLevelLabel_, upgradeInfoLabel_, upgradeCostLabel_, upgradeBtn_ },
    }

    -- ---- HUD 层 ----
    hudLayer_ = UI.Panel {
        width = "100%", height = "100%",
        position = "absolute", top = 0, left = 0,
        pointerEvents = "box-none",
        children = {
            -- 顶部状态栏
            UI.Panel {
                position = "absolute", top = 8, left = 8, right = 8,
                flexDirection = "row", justifyContent = "space-between",
                alignItems = "flex-start",
                pointerEvents = "box-none",
                children = {
                    -- 左上: 资源面板
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = CLR.panelBg,
                        borderRadius = 10, paddingX = 14, paddingY = 10,
                        borderWidth = 1, borderColor = CLR.panelBorder,
                        boxShadow = CLR.panelShadow,
                        children = { goldLabel_, materialLabel_, energyLabel_, costLabel_, wiringBtn_ },
                    },
                    -- 中上: 波次面板
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = CLR.panelBg,
                        borderRadius = 10, paddingX = 14, paddingY = 10,
                        borderWidth = 1, borderColor = CLR.panelBorder,
                        boxShadow = CLR.panelShadow,
                        alignItems = "center",
                        children = { waveLabel_, previewLabel_, speedPanel_ },
                    },
                    -- 右上: 状态面板
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = CLR.panelBg,
                        borderRadius = 10, paddingX = 14, paddingY = 10,
                        borderWidth = 1, borderColor = CLR.panelBorder,
                        boxShadow = CLR.panelShadow,
                        children = { statsLabel_, powerLabel_ },
                    },
                },
            },
            upgradePanel_,
            hintLabel_,
        },
    }

    -- ---- 创建 DragDropContext ----
    dragCtx_ = DragDropContext {
        onDragEnd = function(itemData, sourceSlot, targetSlot, success)
            if targetSlot then
                handleUISlotDrop(itemData, sourceSlot, targetSlot)
            else
                handleSceneDrop(itemData, sourceSlot)
            end
        end,
        canDrop = function(itemData, sourceSlot, targetSlot)
            return true
        end,
    }

    -- ---- 背包面板 ----
    inventoryPanel_ = M.BuildInventoryPanel()

    -- ---- 塔详情面板 ----
    towerDetailPanel_ = M.BuildTowerDetailPanel()

    -- ---- 建塔确认气泡 ----
    placementBubble_ = M.BuildPlacementBubble()

    -- ---- 统一 Root ----
    gameRoot_ = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            hudLayer_,
            inventoryPanel_,
            towerDetailPanel_,
            placementBubble_,
            dragCtx_,
        },
    }

    UI.SetRoot(gameRoot_)

    -- 初始化动画追踪
    prevGold_ = GS.gold
    prevMaterial_ = GS.material
    prevEnergy_ = GS.energy
    prevHP_ = GS.etHP

    -- 强制确保面板初始隐藏
    artifactPanelVisible_ = false
    towerDetailVisible_ = false
    currentDetailTower_ = nil
    invCurrentBottom_ = INV_BOTTOM_HIDDEN
    invAnimating_ = false
    if inventoryPanel_ then
        inventoryPanel_:SetStyle({ bottom = INV_BOTTOM_HIDDEN })
    end
    if towerDetailPanel_ then
        towerDetailPanel_:SetStyle({ display = "none", top = -9999, left = -9999 })
    end

    M.RefreshUI()
end

-- ============================================================================
-- 背包面板构建
-- ============================================================================

function M.BuildInventoryPanel()
    invSlots_ = {}
    local slotChildren = {}

    if #GS.artifactInventory == 0 then
        table.insert(slotChildren, UI.Panel {
            height = "100%",
            justifyContent = "center", alignItems = "center",
            paddingX = 20,
            children = {
                UI.Label {
                    text = "暂无圣器",
                    fontSize = 12, fontColor = CLR.muted,
                },
            },
        })
    else
        for i, entry in ipairs(GS.artifactInventory) do
            local icon = ARTIFACT_ICONS[entry.id] or "?"
            local rc = rarityColor(entry.def.rarity)

            local itemData = nil
            if not entry.equipped then
                itemData = {
                    id = entry.id,
                    name = entry.def.name,
                    icon = icon,
                    type = "artifact",
                    invIndex = i,
                }
            end

            local slot = ItemSlot {
                slotId = "inv_" .. i,
                slotCategory = "inventory",
                slotType = "any",
                item = itemData,
                dragContext = dragCtx_,
                size = 52,
            }

            local statusText = ""
            if entry.equipped then
                local tower = GS.towers[entry.towerIndex]
                local slotName = entry.slotType == "main" and "主" or "副"
                statusText = slotName .. "槽"
            end

            local slotWrapper = UI.Panel {
                flexDirection = "column", gap = 1, alignItems = "center",
                width = 58, flexShrink = 0,
                children = {
                    slot,
                    UI.Label {
                        text = entry.def.name,
                        fontSize = 8, fontColor = rc,
                        textAlign = "center", maxWidth = 56,
                    },
                    entry.equipped and UI.Label {
                        text = statusText,
                        fontSize = 7, fontColor = CLR.success,
                        textAlign = "center",
                    } or nil,
                },
            }

            invSlots_[i] = slot
            table.insert(slotChildren, slotWrapper)
        end
    end

    local panel = UI.Panel {
        position = "absolute",
        bottom = INV_BOTTOM_HIDDEN,
        left = 60, right = 60,
        height = INV_PANEL_HEIGHT,
        flexDirection = "row", gap = 0,
        backgroundColor = CLR.panelBg,
        borderRadius = 12,
        borderWidth = 1, borderColor = CLR.panelBorder,
        boxShadow = CLR.panelShadow,
        overflow = "hidden",
        children = {
            -- 左侧标签区
            UI.Panel {
                height = "100%", width = 50,
                flexDirection = "column", justifyContent = "center",
                alignItems = "center", gap = 4,
                backgroundColor = { 18, 24, 48, 255 },
                borderRightWidth = 1, borderRightColor = CLR.divider,
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = "背包",
                        fontSize = 11, fontColor = CLR.gold,
                    },
                    UI.Label {
                        text = "[B]",
                        fontSize = 9, fontColor = CLR.muted,
                    },
                },
            },
            -- 水平可滚动槽位区
            UI.ScrollView {
                height = "100%",
                flexGrow = 1, flexBasis = 0,
                scrollX = true,
                children = {
                    UI.Panel {
                        flexDirection = "row", gap = 6,
                        alignItems = "center",
                        paddingX = 8, paddingY = 6,
                        height = "100%",
                        children = slotChildren,
                    },
                },
            },
            -- 右侧提示区
            UI.Panel {
                height = "100%", width = 50,
                flexDirection = "column", justifyContent = "center",
                alignItems = "center",
                backgroundColor = { 14, 18, 38, 220 },
                borderLeftWidth = 1, borderLeftColor = CLR.divider,
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = "拖拽\n到\n塔上",
                        fontSize = 8, fontColor = CLR.muted,
                        textAlign = "center",
                    },
                },
            },
        },
    }

    return panel
end

-- ============================================================================
-- 背包面板刷新
-- ============================================================================

function M.RefreshInventoryPanel()
    if not gameRoot_ or not inventoryPanel_ then return end

    gameRoot_:RemoveChild(inventoryPanel_)
    inventoryPanel_ = M.BuildInventoryPanel()
    inventoryPanel_:SetStyle({ bottom = math.floor(invCurrentBottom_) })

    gameRoot_:RemoveChild(dragCtx_)
    gameRoot_:RemoveChild(towerDetailPanel_)
    gameRoot_:AddChild(inventoryPanel_)
    gameRoot_:AddChild(towerDetailPanel_)
    gameRoot_:AddChild(dragCtx_)
end

-- ============================================================================
-- 塔详情面板构建
-- ============================================================================

function M.BuildTowerDetailPanel()
    detailTitleLabel_ = UI.Label {
        text = "塔详情",
        fontSize = 14, fontColor = CLR.gold,
        textAlign = "center",
    }
    detailStatsLabel_ = UI.Label {
        text = "",
        fontSize = 10, fontColor = CLR.secondary,
        whiteSpace = "normal", wordBreak = "break-word",
        textAlign = "center",
        maxWidth = 220,
    }

    detailMainSlot_ = ItemSlot {
        slotId = "detail_main",
        slotCategory = "equipment",
        slotType = "artifact",
        item = nil,
        dragContext = dragCtx_,
        size = 46,
        slotTypeIcon = "主",
        showTypeIcon = true,
    }

    detailSubSlot_ = ItemSlot {
        slotId = "detail_sub",
        slotCategory = "equipment",
        slotType = "artifact",
        item = nil,
        dragContext = dragCtx_,
        size = 46,
        slotTypeIcon = "副",
        showTypeIcon = true,
    }

    local panel = UI.Panel {
        position = "absolute", top = -999, left = -999,
        width = 240,
        flexDirection = "column", gap = 4,
        backgroundColor = CLR.panelBg,
        borderRadius = 10, paddingX = 12, paddingY = 10,
        borderWidth = 1, borderColor = CLR.panelBorder,
        boxShadow = CLR.panelShadow,
        display = "none",
        pointerEvents = "box-none",
        alignItems = "center",
        children = {
            detailTitleLabel_,
            UI.Panel { width = "90%", height = 1, backgroundColor = CLR.divider },
            detailStatsLabel_,
            -- 槽位区
            UI.Panel {
                flexDirection = "row", gap = 8,
                alignItems = "flex-start",
                children = {
                    -- 主槽
                    UI.Panel {
                        flexDirection = "column", gap = 2, alignItems = "center",
                        children = {
                            UI.Label { text = "主槽 100%", fontSize = 9, fontColor = CLR.success },
                            detailMainSlot_,
                            UI.Button {
                                text = "卸下", width = 52, height = 20, fontSize = 8,
                                onClick = function()
                                    if not currentDetailTower_ then return end
                                    local tower = GS.towers[currentDetailTower_]
                                    if tower and tower.mainSlot then
                                        Artifact.UnequipFromTower(tower.mainSlot)
                                        M.RefreshTowerDetail()
                                        M.RefreshInventoryPanel()
                                    end
                                end,
                            },
                        },
                    },
                    -- 副槽
                    UI.Panel {
                        flexDirection = "column", gap = 2, alignItems = "center",
                        children = {
                            UI.Label { text = "副槽 60%", fontSize = 9, fontColor = CLR.warning },
                            detailSubSlot_,
                            UI.Button {
                                text = "卸下", width = 52, height = 20, fontSize = 8,
                                onClick = function()
                                    if not currentDetailTower_ then return end
                                    local tower = GS.towers[currentDetailTower_]
                                    if tower and tower.subSlot then
                                        Artifact.UnequipFromTower(tower.subSlot)
                                        M.RefreshTowerDetail()
                                        M.RefreshInventoryPanel()
                                    end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    return panel
end

-- ============================================================================
-- 建塔确认气泡
-- ============================================================================

function M.BuildPlacementBubble()
    placementBubbleCostLabel_ = UI.Label {
        text = "", fontSize = 11,
        fontColor = CLR.gold,
        textAlign = "center",
    }

    placementBubble_ = UI.Panel {
        position = "absolute",
        top = -9999, left = -9999,
        display = "none",
        flexDirection = "column", gap = 3,
        alignItems = "center",
        children = {
            UI.Button {
                text = "+",
                width = 50, height = 50,
                fontSize = 32,
                variant = "primary",
                onClick = function()
                    M.ConfirmPlacement()
                end,
            },
            UI.Panel {
                backgroundColor = { 0, 0, 0, 170 },
                borderRadius = 6, paddingX = 8, paddingY = 2,
                children = { placementBubbleCostLabel_ },
            },
        },
    }

    return placementBubble_
end

function M.ConfirmPlacement()
    if not GS.placementPending then return end
    local Tower = require("Tower")
    local gx, gz = GS.placementGX, GS.placementGZ
    Tower.CancelPlacement()
    M.HideTowerDetail()
    Tower.PlaceBasicTower(gx, gz)
end

function M.UpdatePlacementBubble()
    if not placementBubble_ then return end

    if not GS.placementPending then
        placementBubble_:SetStyle({ display = "none", top = -9999, left = -9999 })
        return
    end

    local worldPos = Vector3(GS.placementGX, 1.0, GS.placementGZ)
    local screenNorm = GS.camera:WorldToScreenPoint(worldPos)

    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr

    local sx = screenNorm.x * screenW
    local sy = screenNorm.y * screenH

    local bubbleW = 56
    local bubbleH = 76
    local px = sx - bubbleW * 0.5
    local py = sy - bubbleH - 6

    px = math.max(4, math.min(screenW - bubbleW - 4, px))
    py = math.max(4, math.min(screenH - bubbleH - 4, py))

    local newTop = math.floor(py)
    local newLeft = math.floor(px)

    local Tower = require("Tower")
    if placementBubbleCostLabel_ then
        placementBubbleCostLabel_:SetText(Tower.GetTowerCost() .. " 金")
    end

    placementBubble_:SetStyle({ display = "flex", top = newTop, left = newLeft })
end

-- ============================================================================
-- 塔详情面板：显示 / 隐藏 / 刷新
-- ============================================================================

function M.ShowTowerDetail(towerIndex)
    if towerIndex < 1 or towerIndex > #GS.towers then return end

    if towerDetailVisible_ and currentDetailTower_ == towerIndex then
        M.HideTowerDetail()
        return
    end

    currentDetailTower_ = towerIndex
    towerDetailVisible_ = true
    if towerDetailPanel_ then
        towerDetailPanel_:SetStyle({ display = "flex", opacity = 0 })
        towerDetailPanel_:Animate({
            keyframes = {
                [0] = { opacity = 0, translateY = 8 },
                [1] = { opacity = 1, translateY = 0 },
            },
            duration = 0.2,
            easing = "easeOut",
            fillMode = "forwards",
        })
    end
    M.RefreshTowerDetail()
    M.UpdateTowerDetailPosition()

    M.ShowArtifactPanel()
end

function M.HideTowerDetail()
    towerDetailVisible_ = false
    currentDetailTower_ = nil
    if towerDetailPanel_ then
        towerDetailPanel_:SetStyle({ display = "none", top = -9999, left = -9999 })
    end

    M.HideArtifactPanel()
end

function M.UpdateTowerDetailPosition()
    if not towerDetailVisible_ or not currentDetailTower_ then return end
    if currentDetailTower_ > #GS.towers then
        M.HideTowerDetail()
        return
    end

    local tower = GS.towers[currentDetailTower_]
    if not tower then
        M.HideTowerDetail()
        return
    end

    local worldPos = Vector3(tower.gx, 1.5, tower.gz)
    local screenNorm = GS.camera:WorldToScreenPoint(worldPos)

    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr

    local sx = screenNorm.x * screenW
    local sy = screenNorm.y * screenH

    local panelW = 240
    local panelH = 200
    local px = sx - panelW * 0.5
    local py = sy - panelH - 10

    px = math.max(4, math.min(screenW - panelW - 4, px))
    py = math.max(4, math.min(screenH - panelH - 4, py))

    local newTop = math.floor(py)
    local newLeft = math.floor(px)

    if towerDetailPanel_ then
        local curTop = towerDetailPanel_.props.top
        local curLeft = towerDetailPanel_.props.left
        if curTop ~= newTop or curLeft ~= newLeft then
            towerDetailPanel_:SetStyle({ top = newTop, left = newLeft })
        end
    end
end

function M.RefreshTowerDetail()
    if not towerDetailVisible_ or not currentDetailTower_ then return end
    local ti = currentDetailTower_
    if ti < 1 or ti > #GS.towers then
        M.HideTowerDetail()
        return
    end

    local tower = GS.towers[ti]
    local EnergyTower = require("EnergyTower")
    local att = EnergyTower.CalcAttenuation(tower.dist)
    local baseDmg = CONFIG.TowerBaseDmg * att
    local dmg = baseDmg * (tower.artDmgMult or 1.0)
    local spdMult = math.max(0.30, tower.ratio * #GS.towers) * (tower.artAtkSpdMult or 1.0)
    local fireInt = CONFIG.TowerFireInterval / math.max(0.10, spdMult)

    if detailTitleLabel_ then
        detailTitleLabel_:SetText(string.format("防御塔 (%d, %d)", tower.gx, tower.gz))
    end

    if detailStatsLabel_ then
        local dmgBonus = dmg - baseDmg
        local dmgBonusStr = ""
        if math.abs(dmgBonus) > 0.1 then
            dmgBonusStr = string.format(" (%+.1f)", dmgBonus)
        end
        detailStatsLabel_:SetText(string.format(
            "伤害: %.1f%s\n攻速: %.2f秒\n功率: %.0f%%",
            dmg, dmgBonusStr, fireInt, tower.ratio * 100
        ))
    end

    -- 主槽
    if detailMainSlot_ then
        if tower.mainSlot then
            local entry = GS.artifactInventory[tower.mainSlot]
            if entry then
                detailMainSlot_:SetItem({
                    id = entry.id,
                    name = entry.def.name,
                    icon = ARTIFACT_ICONS[entry.id] or "?",
                    type = "artifact",
                    invIndex = tower.mainSlot,
                })
            else
                detailMainSlot_:SetItem(nil)
            end
        else
            detailMainSlot_:SetItem(nil)
        end
    end

    -- 副槽
    if detailSubSlot_ then
        if tower.subSlot then
            local entry = GS.artifactInventory[tower.subSlot]
            if entry then
                detailSubSlot_:SetItem({
                    id = entry.id,
                    name = entry.def.name,
                    icon = ARTIFACT_ICONS[entry.id] or "?",
                    type = "artifact",
                    invIndex = tower.subSlot,
                })
            else
                detailSubSlot_:SetItem(nil)
            end
        else
            detailSubSlot_:SetItem(nil)
        end
    end
end

-- ============================================================================
-- 背包面板：显示 / 隐藏
-- ============================================================================

function M.ShowArtifactPanel()
    if artifactPanelVisible_ then return end
    artifactPanelVisible_ = true
    M.RefreshInventoryPanel()
    invAnimFrom_ = invCurrentBottom_
    invAnimTo_ = INV_BOTTOM_SHOWN
    invAnimStartTime_ = time.elapsedTime
    invAnimating_ = true
    invAnimDirection_ = "show"
    if inventoryPanel_ then
        inventoryPanel_:SetStyle({ bottom = math.floor(invCurrentBottom_) })
    end
end

function M.HideArtifactPanel()
    if not artifactPanelVisible_ then return end
    artifactPanelVisible_ = false
    invAnimFrom_ = invCurrentBottom_
    invAnimTo_ = INV_BOTTOM_HIDDEN
    invAnimStartTime_ = time.elapsedTime
    invAnimating_ = true
    invAnimDirection_ = "hide"
end

function M.ToggleArtifactPanel()
    if artifactPanelVisible_ then
        M.HideArtifactPanel()
    else
        M.ShowArtifactPanel()
    end
end

-- ============================================================================
-- 升级面板
-- ============================================================================

function M.RefreshUpgradePanel()
    local EnergyTower = require("EnergyTower")
    local stats = EnergyTower.GetLevelStats()

    if upgradeLevelLabel_ then
        upgradeLevelLabel_:SetText(string.format("能源塔  Lv.%d", GS.etLevel))
    end
    if upgradeInfoLabel_ then
        upgradeInfoLabel_:SetText(string.format(
            "功率: %d  |  生命: %d/%d  |  范围: %d",
            stats.power, GS.etHP, GS.etMaxHP, stats.radius
        ))
    end

    local cost = EnergyTower.GetUpgradeCost()
    if cost then
        if upgradeCostLabel_ then
            upgradeCostLabel_:SetText(string.format("消耗: %d 金 + %d 材料", cost.gold, cost.material))
        end
        if upgradeBtn_ then
            local canUp = EnergyTower.CanUpgrade()
            upgradeBtn_:SetText(canUp and "升级" or "资源不足")
            upgradeBtn_:SetDisabled(not canUp)
            if not canUp then
                upgradeCostLabel_:SetStyle({ fontColor = CLR.danger })
            else
                upgradeCostLabel_:SetStyle({ fontColor = CLR.secondary })
            end
        end
    else
        if upgradeCostLabel_ then upgradeCostLabel_:SetText("已满级") end
        if upgradeBtn_ then upgradeBtn_:SetText("满级"); upgradeBtn_:SetDisabled(true) end
    end
end

function M.ShowUpgradePanel()
    if not upgradePanel_ then return end
    upgradePanel_:SetStyle({ display = "flex", opacity = 0 })
    upgradePanel_:Animate({
        keyframes = {
            [0] = { opacity = 0, translateY = 10 },
            [1] = { opacity = 1, translateY = 0 },
        },
        duration = 0.25,
        easing = "easeOut",
        fillMode = "forwards",
    })
    upgradePanelVisible_ = true
    M.RefreshUpgradePanel()
end

function M.HideUpgradePanel()
    if not upgradePanel_ then return end
    upgradePanel_:SetStyle({ display = "none" })
    upgradePanelVisible_ = false
end

function M.ToggleUpgradePanel()
    if upgradePanelVisible_ then
        M.HideUpgradePanel()
    else
        M.ShowUpgradePanel()
    end
end

-- ============================================================================
-- 每帧刷新 HUD
-- ============================================================================

function M.RefreshUI()
    local Tower = require("Tower")
    local Wave = require("Wave")

    local cost = Tower.GetTowerCost()
    local canBuild = GS.gold >= cost

    -- 金币
    if goldLabel_ then
        goldLabel_:SetText("金币: " .. GS.gold)
        if GS.gold ~= prevGold_ then
            pulseWidget(goldLabel_)
            prevGold_ = GS.gold
        end
    end
    -- 材料
    if materialLabel_ then
        materialLabel_:SetText("材料: " .. GS.material)
        if GS.material ~= prevMaterial_ then
            pulseWidget(materialLabel_)
            prevMaterial_ = GS.material
        end
    end
    -- 能量
    if energyLabel_ then
        energyLabel_:SetText("能量: " .. GS.energy)
        if GS.energy ~= prevEnergy_ then
            pulseWidget(energyLabel_)
            prevEnergy_ = GS.energy
        end
    end
    -- 造价
    if costLabel_ then
        local costStr = "造价: " .. cost
        if not canBuild then
            costStr = costStr .. "  (不足)"
            costLabel_:SetStyle({ fontColor = CLR.danger })
        else
            costLabel_:SetStyle({ fontColor = CLR.secondary })
        end
        costLabel_:SetText(costStr)
    end

    local EnergyTower = require("EnergyTower")
    -- 状态标签: 简洁的关键信息
    if statsLabel_ then
        local n = #GS.towers
        local nm = #GS.monsters
        -- HP 变化动画
        if GS.etHP ~= prevHP_ then
            pulseWidget(statsLabel_)
            prevHP_ = GS.etHP
        end
        -- HP 颜色
        local hpRatio = GS.etMaxHP > 0 and (GS.etHP / GS.etMaxHP) or 1
        local hpColor = CLR.bright
        if hpRatio < 0.3 then
            hpColor = CLR.danger
        elseif hpRatio < 0.6 then
            hpColor = CLR.warning
        end
        statsLabel_:SetStyle({ fontColor = hpColor })
        statsLabel_:SetText(string.format(
            "Lv.%d | 生命: %d/%d | 塔: %d | 怪: %d",
            GS.etLevel, GS.etHP, GS.etMaxHP, n, nm
        ))
    end

    -- 功率标签: 精简版
    if powerLabel_ then
        local totalP = EnergyTower.GetTotalPower()
        local n = #GS.towers
        if n == 0 then
            powerLabel_:SetText(string.format("总功率: %d | 空闲", totalP))
            powerLabel_:SetStyle({ fontColor = CLR.energy })
        else
            local scStr = ""
            if GS.shortCircuit and GS.shortCircuit.active then
                scStr = " | 短路!"
                powerLabel_:SetStyle({ fontColor = CLR.danger })
            else
                powerLabel_:SetStyle({ fontColor = CLR.energy })
            end
            powerLabel_:SetText(string.format("总功率: %d | 塔: %d%s", totalP, n, scStr))
        end
    end

    -- 布线按钮
    if wiringBtn_ then
        wiringBtn_:SetVariant(GS.wiringMode and "primary" or "default")
        wiringBtn_:SetText(GS.wiringMode and "布线中 [E]" or "布线 [E]")
    end

    -- 速度按钮高亮
    if speedBtn1_ then
        local spd = GS.gameSpeed
        local function applyBtn(btn, level)
            btn:SetVariant(spd == level and "primary" or "default")
        end
        applyBtn(speedBtn1_, 1)
        applyBtn(speedBtn2_, 2)
        applyBtn(speedBtn3_, 3)
    end

    -- 波次
    if waveLabel_ then
        waveLabel_:SetText(Wave.GetWaveInfo())
    end
    if previewLabel_ then
        local preview = Wave.GetNextWavePreview()
        if preview then
            previewLabel_:SetText(string.format("下一波: %s (%d只)", preview.summary, preview.totalMonsters))
        else
            previewLabel_:SetText("")
        end
    end

    if upgradePanelVisible_ then M.RefreshUpgradePanel() end

    M.UpdateHintLabel()
    M.CheckDropOverlay()

    -- 塔详情面板跟踪
    if towerDetailVisible_ and currentDetailTower_ then
        if currentDetailTower_ > #GS.towers then
            M.HideTowerDetail()
        else
            M.UpdateTowerDetailPosition()
        end
    end

    M.UpdatePlacementBubble()

    -- ---- 背包面板滑入/滑出动画 ----
    if invAnimating_ and inventoryPanel_ then
        local elapsed = time.elapsedTime - invAnimStartTime_
        local progress = math.min(elapsed / INV_ANIM_DURATION, 1.0)

        local easedT
        if invAnimDirection_ == "show" then
            easedT = easeOutBack(progress)
        else
            easedT = easeInCubic(progress)
        end

        invCurrentBottom_ = invAnimFrom_ + (invAnimTo_ - invAnimFrom_) * easedT
        inventoryPanel_:SetStyle({ bottom = math.floor(invCurrentBottom_) })

        if progress >= 1.0 then
            invAnimating_ = false
            invCurrentBottom_ = invAnimTo_
            inventoryPanel_:SetStyle({ bottom = math.floor(invCurrentBottom_) })
        end
    end
end

-- ============================================================================
-- 悬停提示 (全中文 + 精简)
-- ============================================================================

function M.UpdateHintLabel()
    if not hintLabel_ then return end

    local Tower = require("Tower")
    local EnergyTower = require("EnergyTower")

    if GS.wiringMode then
        local base = "布线中: 左键拖画线 | 右键删线 | E 退出 | " .. CONFIG.LineCostPerSegment .. "金/段"
        if GS.wiringHintMsg then
            base = base .. "  |  " .. GS.wiringHintMsg
        end
        hintLabel_:SetText(base)
        return
    end

    if not GS.hoverOnMap then
        if GS.placementPending then
            hintLabel_:SetText("点击 [+] 确认建塔 | 点击其他位置取消 | E: 布线 | B: 背包")
        else
            hintLabel_:SetText("左键: 放置标记 | 点击塔: 详情 | X: 出售 | U: 升级 | E: 布线 | B: 背包")
        end
        return
    end

    local gx, gz = GS.hoverGX, GS.hoverGZ
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
            "能源塔 Lv.%d | 功率: %d | 范围: %d | 点击升级",
            GS.etLevel, EnergyTower.GetTotalPower(), EnergyTower.GetEnergyRange()
        ))
        if input:GetKeyPress(KEY_U) then
            if EnergyTower.Upgrade() then
                M.RefreshUpgradePanel()
                local Scene = require("Scene")
                if Scene.UpdateRangeCircle then Scene.UpdateRangeCircle() end
            end
        end
    elseif isOccupied then
        for idx, tower in ipairs(GS.towers) do
            if tower.gx == gx and tower.gz == gz then
                local att = EnergyTower.CalcAttenuation(tower.dist)
                local dmg = CONFIG.TowerBaseDmg * att * (tower.artDmgMult or 1.0)
                local spdMult = math.max(0.30, tower.ratio * #GS.towers) * (tower.artAtkSpdMult or 1.0)
                local fireInt = CONFIG.TowerFireInterval / spdMult
                local ratio = GS.wavePhase == "preparing" and 0.7 or 0.4
                local origCost = Tower.GetTowerOriginalCost(idx)
                local refund = math.floor(origCost * ratio + 0.5)
                hintLabel_:SetText(string.format(
                    "防御塔 | 伤害: %.1f | 攻速: %.2fs | [X] 出售: %d金 | 左键: 详情",
                    dmg, fireInt, refund
                ))
                break
            end
        end
    elseif not canAfford then
        hintLabel_:SetText("金币不足! 需要: " .. Tower.GetTowerCost())
        hintLabel_:SetStyle({ fontColor = CLR.danger })
        return
    else
        if GS.placementPending and gx == GS.placementGX and gz == GS.placementGZ then
            hintLabel_:SetText("再次点击确认建造 | 造价: " .. Tower.GetTowerCost())
        else
            hintLabel_:SetText("点击放置标记 | 造价: " .. Tower.GetTowerCost())
        end
    end
    hintLabel_:SetStyle({ fontColor = { 255, 255, 230, 140 } })
end

-- ============================================================================
-- 圣器掉落 3 选 1 (全中文 + 交错动画)
-- ============================================================================

function M.ShowDropOverlay()
    if dropOverlayVisible_ then return end

    local candidates = GS.artifactDropCandidates
    if not candidates or #candidates == 0 then return end

    local cards = {}
    for i, cand in ipairs(candidates) do
        local def = cand.def
        local rc = rarityColor(def.rarity)
        local bc = rarityBorderColor(def.rarity)
        local bg = ARTIFACT_BG[def.id] or { 25, 30, 45, 230 }
        local icon = ARTIFACT_ICONS[def.id] or "?"

        local dsText = ""
        for _, ds in ipairs(def.downsides) do
            if ds.type == "stat_modifier" then
                local pct = math.abs(ds.modifier) * 100
                local statName = ds.stat == "damage" and "伤害" or
                                 ds.stat == "attack_speed" and "攻速" or ds.stat
                dsText = dsText .. string.format("-%d%% %s  ", pct, statName)
            end
        end
        if dsText == "" then dsText = "无副作用" end

        local idx = i
        local card = UI.Panel {
            width = 190, flexDirection = "column", gap = 8,
            backgroundColor = bg,
            borderRadius = 12, paddingX = 16, paddingY = 16,
            borderWidth = 2, borderColor = bc,
            boxShadow = {{ x = 0, y = 4, blur = 16, spread = 0, color = { bc[1], bc[2], bc[3], 60 } }},
            alignItems = "center",
            opacity = 0,
            children = {
                UI.Label {
                    text = Artifact.RARITY_NAMES[def.rarity] or "?",
                    fontSize = 10, fontColor = { rc[1], rc[2], rc[3], 160 },
                    textAlign = "center",
                },
                UI.Panel {
                    width = 48, height = 48, borderRadius = 24,
                    backgroundColor = { rc[1], rc[2], rc[3], 50 },
                    justifyContent = "center", alignItems = "center",
                    borderWidth = 2, borderColor = { rc[1], rc[2], rc[3], 140 },
                    children = {
                        UI.Label { text = icon, fontSize = 24, fontColor = rc },
                    },
                },
                UI.Label {
                    text = def.name, fontSize = 17, fontColor = rc,
                    textAlign = "center",
                },
                UI.Panel {
                    width = "80%", height = 1,
                    backgroundColor = { rc[1], rc[2], rc[3], 60 },
                },
                UI.Label {
                    text = def.description, fontSize = 11,
                    fontColor = CLR.secondary,
                    maxWidth = 165, textAlign = "center",
                    whiteSpace = "normal", wordBreak = "break-word",
                },
                UI.Panel {
                    backgroundColor = { 255, 60, 60, 30 },
                    borderRadius = 4, paddingX = 8, paddingY = 3,
                    children = {
                        UI.Label {
                            text = dsText, fontSize = 10,
                            fontColor = { 255, 120, 100, 220 },
                        },
                    },
                },
                UI.Button {
                    text = "选择 [" .. idx .. "]",
                    variant = "primary",
                    width = 130, height = 34, fontSize = 14,
                    onClick = function() M.OnDropPick(idx) end,
                },
            },
        }
        -- 交错入场动画
        card:Animate({
            keyframes = {
                [0] = { opacity = 0, translateY = 30 },
                [1] = { opacity = 1, translateY = 0 },
            },
            duration = 0.35,
            easing = "easeOutBack",
            fillMode = "forwards",
            delay = (i - 1) * 0.1,
        })
        table.insert(cards, card)
    end

    local skipBtn = UI.Button {
        text = "跳过 (+50金) [0]",
        width = 160, height = 34, fontSize = 13,
        onClick = function() M.OnDropPick(0) end,
    }

    dropOverlay_ = UI.Panel {
        width = "100%", height = "100%",
        position = "absolute", top = 0, left = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 180 },
        opacity = 0,
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 20,
                children = {
                    UI.Panel {
                        flexDirection = "column", alignItems = "center", gap = 4,
                        children = {
                            UI.Label {
                                text = "波次通过!",
                                fontSize = 14, fontColor = CLR.secondary,
                            },
                            UI.Label {
                                text = "选择你的圣器",
                                fontSize = 24, fontColor = CLR.gold,
                            },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row", gap = 16,
                        children = cards,
                    },
                    skipBtn,
                },
            },
        },
    }

    -- 整体淡入
    dropOverlay_:Animate({
        keyframes = {
            [0] = { opacity = 0 },
            [1] = { opacity = 1 },
        },
        duration = 0.25,
        easing = "easeOut",
        fillMode = "forwards",
    })

    if gameRoot_ then
        gameRoot_:RemoveChild(dragCtx_)
        gameRoot_:AddChild(dropOverlay_)
        gameRoot_:AddChild(dragCtx_)
    end

    dropOverlayVisible_ = true
end

function M.OnDropPick(choiceIndex)
    Artifact.PickDrop(choiceIndex)
    M.HideDropOverlay()
end

function M.HideDropOverlay()
    if not dropOverlayVisible_ then return end
    dropOverlayVisible_ = false
    if dropOverlay_ and gameRoot_ then
        gameRoot_:RemoveChild(dropOverlay_)
    end
    dropOverlay_ = nil
end

function M.CheckDropOverlay()
    if GS.artifactDropPending and not dropOverlayVisible_ then
        M.ShowDropOverlay()
    end
end

-- ============================================================================
-- UI 面板命中检测
-- ============================================================================

local function isMouseInPanel(panelProps, screenW, screenH)
    if not panelProps then return false end

    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr

    local pLeft = panelProps.left or 0
    local pTop = panelProps.top or 0
    local pWidth = panelProps.width or 0
    local pHeight = panelProps.height or 0

    if panelProps.right and not panelProps.left then
        pLeft = screenW - (panelProps.right or 0) - pWidth
    end

    if panelProps.bottom and panelProps.top then
        pHeight = screenH - pTop - panelProps.bottom
    end

    return mx >= pLeft and mx <= pLeft + pWidth
       and my >= pTop and my <= pTop + pHeight
end

local function isMouseOverUIPanel()
    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr

    if (artifactPanelVisible_ or invAnimating_) and inventoryPanel_ then
        local panelLeft = 60
        local panelRight = screenW - 60
        local panelBottom = screenH - invCurrentBottom_
        local panelTop = panelBottom - INV_PANEL_HEIGHT

        local mx = input.mousePosition.x / dpr
        local my = input.mousePosition.y / dpr

        if mx >= panelLeft and mx <= panelRight
           and my >= panelTop and my <= panelBottom then
            return true
        end
    end

    if towerDetailVisible_ and towerDetailPanel_ and towerDetailPanel_.props then
        local tp = towerDetailPanel_.props
        if tp.top and tp.top > -9000 and tp.left and tp.left > -9000 then
            local detailProps = { top = tp.top, left = tp.left, width = 240, height = 220 }
            if isMouseInPanel(detailProps, screenW, screenH) then
                return true
            end
        end
    end

    if GS.placementPending and placementBubble_ and placementBubble_.props then
        local bp = placementBubble_.props
        if bp.top and bp.top > -9000 and bp.left and bp.left > -9000 then
            local bubbleProps = { top = bp.top, left = bp.left, width = 56, height = 76 }
            if isMouseInPanel(bubbleProps, screenW, screenH) then
                return true
            end
        end
    end

    return false
end

function M.IsMouseOverUIPanel()
    return isMouseOverUIPanel()
end

-- ============================================================================
-- 键盘操作
-- ============================================================================

function M.HandleArtifactInput()
    if input:GetKeyPress(KEY_E) then
        local EnergyTower = require("EnergyTower")
        EnergyTower.ToggleWiringMode()
        return
    end

    if input:GetKeyPress(KEY_B) then
        M.ToggleArtifactPanel()
        return
    end

    if dropOverlayVisible_ then
        if input:GetKeyPress(KEY_1) then M.OnDropPick(1); return end
        if input:GetKeyPress(KEY_2) then M.OnDropPick(2); return end
        if input:GetKeyPress(KEY_3) then M.OnDropPick(3); return end
        if input:GetKeyPress(KEY_0) then M.OnDropPick(0); return end
        return
    end

    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if isMouseOverUIPanel() then
            return
        end

        if GS.hoverOnMap and GS.hoverGX == 0 and GS.hoverGZ == 0 then
            M.ToggleUpgradePanel()
            return
        end

        if towerDetailVisible_ then
            if GS.hoverOnMap and not GS.hoverValid then
                local Tower = require("Tower")
                local idx = Tower.GetTowerAtHover()
                if idx and idx ~= currentDetailTower_ then
                    M.ShowTowerDetail(idx)
                    return
                end
            end
            M.HideTowerDetail()
            if upgradePanelVisible_ then M.HideUpgradePanel() end
            return
        else
            if GS.hoverOnMap and not GS.hoverValid then
                local Tower = require("Tower")
                local idx = Tower.GetTowerAtHover()
                if idx then
                    M.ShowTowerDetail(idx)
                    return
                end
            end
        end

        if upgradePanelVisible_ then M.HideUpgradePanel() end
    end

    if input:GetKeyPress(KEY_ESCAPE) then
        if upgradePanelVisible_ then
            M.HideUpgradePanel()
            return
        end
        if towerDetailVisible_ then
            M.HideTowerDetail()
            return
        end
        if artifactPanelVisible_ then
            M.HideArtifactPanel()
            return
        end
    end
end

-- ============================================================================
-- GameOver / Victory (全中文 + 淡入动画)
-- ============================================================================

function M.ShowGameOver()
    local titleLabel = UI.Label {
        text = "游戏结束", fontSize = 36,
        fontColor = CLR.danger,
    }
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 0 },
        opacity = 0,
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 14,
                backgroundColor = { 30, 10, 10, 220 },
                borderRadius = 14, paddingX = 44, paddingY = 34,
                borderWidth = 1, borderColor = { 180, 40, 40, 120 },
                boxShadow = {{ x = 0, y = 4, blur = 24, spread = 0, color = { 255, 0, 0, 40 } }},
                children = {
                    titleLabel,
                    UI.Label {
                        text = string.format("波次: %d/%d  |  建塔: %d  |  击杀: %d",
                            GS.currentWave, 20, #GS.towers, GS.monstersKilled),
                        fontSize = 16, fontColor = CLR.secondary,
                    },
                    UI.Label {
                        text = "能源塔被摧毁",
                        fontSize = 14, fontColor = CLR.warning,
                    },
                    UI.Button {
                        text = "重新开始", variant = "primary",
                        width = 160, height = 42, fontSize = 18,
                        onClick = function()
                            M.Shutdown()
                            Start()
                        end,
                    },
                },
            },
        },
    }
    UI.SetRoot(overlay)

    -- 淡入动画
    overlay:Animate({
        keyframes = {
            [0] = { opacity = 0 },
            [1] = { opacity = 1 },
        },
        duration = 0.5,
        easing = "easeOut",
        fillMode = "forwards",
    })
    -- 标题脉冲
    titleLabel:Animate({
        keyframes = {
            [0]   = { scale = 0.7, opacity = 0 },
            [0.6] = { scale = 1.1 },
            [1]   = { scale = 1.0, opacity = 1 },
        },
        duration = 0.6,
        easing = "easeOutBack",
        fillMode = "forwards",
        delay = 0.2,
    })
end

function M.ShowVictory()
    local titleLabel = UI.Label {
        text = "胜利!", fontSize = 36,
        fontColor = CLR.success,
    }
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 0 },
        opacity = 0,
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 14,
                backgroundColor = { 10, 30, 10, 220 },
                borderRadius = 14, paddingX = 44, paddingY = 34,
                borderWidth = 1, borderColor = { 40, 180, 40, 120 },
                boxShadow = {{ x = 0, y = 4, blur = 24, spread = 0, color = { 0, 255, 0, 40 } }},
                children = {
                    titleLabel,
                    UI.Label {
                        text = string.format("全部 20 波通关!  |  防御塔: %d  |  金币: %d",
                            #GS.towers, GS.gold),
                        fontSize = 16, fontColor = { 200, 255, 200, 220 },
                    },
                    UI.Label {
                        text = "恭喜指挥官!",
                        fontSize = 14, fontColor = CLR.gold,
                    },
                    UI.Button {
                        text = "再来一局", variant = "primary",
                        width = 160, height = 42, fontSize = 18,
                        onClick = function()
                            M.Shutdown()
                            Start()
                        end,
                    },
                },
            },
        },
    }
    UI.SetRoot(overlay)

    -- 淡入动画
    overlay:Animate({
        keyframes = {
            [0] = { opacity = 0 },
            [1] = { opacity = 1 },
        },
        duration = 0.5,
        easing = "easeOut",
        fillMode = "forwards",
    })
    -- 标题脉冲
    titleLabel:Animate({
        keyframes = {
            [0]   = { scale = 0.7, opacity = 0 },
            [0.6] = { scale = 1.15 },
            [1]   = { scale = 1.0, opacity = 1 },
        },
        duration = 0.7,
        easing = "easeOutBack",
        fillMode = "forwards",
        delay = 0.2,
    })
end

function M.Shutdown()
    UI.Shutdown()
end

return M
