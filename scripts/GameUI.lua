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

local gameRoot_ = nil       -- 持久根面板
local hudLayer_ = nil       -- HUD 层（常驻）
local inventoryPanel_ = nil -- 右侧背包面板
local towerDetailPanel_ = nil -- 左侧塔详情面板
local dropOverlay_ = nil    -- 波次掉落 3 选 1

-- 状态
local dropOverlayVisible_ = false
local artifactPanelVisible_ = false
local towerDetailVisible_ = false
local currentDetailTower_ = nil  -- 当前查看的塔索引

-- ---- 背包面板动画 ----
local INV_PANEL_HEIGHT = 120
local INV_BOTTOM_SHOWN = 8
local INV_BOTTOM_HIDDEN = -(INV_PANEL_HEIGHT + 20)  -- 完全隐藏在屏幕下方
local INV_ANIM_DURATION = 0.35  -- 动画时长(秒)

local invCurrentBottom_ = INV_BOTTOM_HIDDEN
local invAnimStartTime_ = 0
local invAnimFrom_ = INV_BOTTOM_HIDDEN
local invAnimTo_ = INV_BOTTOM_HIDDEN
local invAnimating_ = false
local invAnimDirection_ = "hide"  -- "show" | "hide"

-- ============================================================================
-- 缓动函数
-- ============================================================================

--- ease-out-back: 滑入时带轻微回弹
local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1) * (t - 1) * (t - 1) + c1 * (t - 1) * (t - 1)
end

--- ease-in-cubic: 滑出时加速离开
local function easeInCubic(t)
    return t * t * t
end

-- 拖拽上下文
local dragCtx_ = nil

-- 背包 ItemSlot 列表（刷新用）
local invSlots_ = {}
-- 塔详情中的主/副槽 ItemSlot
local detailMainSlot_ = nil
local detailSubSlot_ = nil
-- 塔详情中的属性标签
local detailTitleLabel_ = nil
local detailStatsLabel_ = nil


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
-- 3D Raycast 辅助：鼠标位置 → 网格坐标 → 找塔
-- ============================================================================

--- 从当前鼠标位置 raycast 到 Y=0 平面，返回 gx, gz
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

--- 在给定网格坐标找到塔索引
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

--- 处理拖拽到 UI 槽位（塔详情面板的主/副槽）
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

--- 处理拖拽到 3D 场景（找塔并装配）
local function handleSceneDrop(itemData, sourceSlot)
    local invIndex = itemData.invIndex
    if not invIndex then return end

    local gx, gz = raycastToGrid()
    if not gx then return end

    local towerIndex = findTowerAt(gx, gz)
    if not towerIndex then return end

    -- 自动选槽：主槽空→主槽；主满副空→副槽；都满→替换主槽
    local tower = GS.towers[towerIndex]
    local slotType = "main"
    if tower.mainSlot then
        if not tower.subSlot then
            slotType = "sub"
        else
            slotType = "main"  -- 替换主槽
        end
    end

    Artifact.EquipToTower(invIndex, towerIndex, slotType)
    M.RefreshInventoryPanel()
    -- 如果详情面板打开且是同一座塔，刷新
    if towerDetailVisible_ and currentDetailTower_ == towerIndex then
        M.RefreshTowerDetail()
    end
end

-- ============================================================================
-- 创建游戏 UI（统一 Root）
-- ============================================================================

function M.CreateGameUI()
    -- ---- HUD 标签 ----
    goldLabel_ = UI.Label {
        text = "", fontSize = 15,
        fontColor = { 255, 215, 0, 255 },
    }
    materialLabel_ = UI.Label {
        text = "", fontSize = 15,
        fontColor = { 100, 220, 120, 255 },
    }
    energyLabel_ = UI.Label {
        text = "", fontSize = 15,
        fontColor = { 100, 180, 255, 255 },
    }
    costLabel_ = UI.Label {
        text = "", fontSize = 12,
        fontColor = { 200, 200, 200, 200 },
    }
    statsLabel_ = UI.Label {
        text = "", fontSize = 13,
        fontColor = { 180, 220, 255, 230 },
    }
    waveLabel_ = UI.Label {
        text = "", fontSize = 14,
        fontColor = { 255, 220, 140, 240 },
    }
    previewLabel_ = UI.Label {
        text = "", fontSize = 11,
        fontColor = { 200, 200, 180, 180 },
    }
    powerLabel_ = UI.Label {
        text = "", fontSize = 12,
        fontColor = { 140, 200, 255, 220 },
    }
    hintLabel_ = UI.Label {
        text = "Left Click: Build | Middle Drag: Pan | Scroll: Zoom",
        fontSize = 12,
        fontColor = { 255, 255, 230, 160 },
        position = "absolute",
        bottom = 10, left = 0, right = 0,
        textAlign = "center",
    }

    -- 速度按钮组
    speedBtn1_ = UI.Button {
        text = "x1", width = 40, height = 26, fontSize = 12,
        variant = "primary",
        onClick = function() GS.gameSpeed = 1 end,
    }
    speedBtn2_ = UI.Button {
        text = "x2", width = 40, height = 26, fontSize = 12,
        onClick = function() GS.gameSpeed = 2 end,
    }
    speedBtn3_ = UI.Button {
        text = "x3", width = 40, height = 26, fontSize = 12,
        onClick = function() GS.gameSpeed = 3 end,
    }
    speedPanel_ = UI.Panel {
        flexDirection = "row", gap = 4, alignItems = "center",
        children = {
            UI.Label { text = "Speed:", fontSize = 11, fontColor = { 160, 170, 190, 200 } },
            speedBtn1_, speedBtn2_, speedBtn3_,
        },
    }

    -- 布线按钮
    wiringBtn_ = UI.Button {
        text = "Wire [E]", width = 72, height = 28, fontSize = 12,
        onClick = function()
            local EnergyTower = require("EnergyTower")
            EnergyTower.ToggleWiringMode()
        end,
    }

    -- 升级面板
    upgradeLevelLabel_ = UI.Label {
        text = "", fontSize = 16,
        fontColor = { 255, 220, 80, 255 },
    }
    upgradeInfoLabel_ = UI.Label {
        text = "", fontSize = 12,
        fontColor = { 200, 220, 240, 220 },
    }
    upgradeCostLabel_ = UI.Label {
        text = "", fontSize = 12,
        fontColor = { 200, 200, 200, 200 },
    }
    upgradeBtn_ = UI.Button {
        text = "Upgrade", variant = "primary",
        width = 120, height = 32, fontSize = 14,
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
        backgroundColor = { 15, 20, 35, 210 },
        borderRadius = 8, paddingX = 14, paddingY = 10,
        borderWidth = 1, borderColor = { 80, 140, 200, 180 },
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
                    UI.Panel {
                        flexDirection = "column", gap = 3,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { goldLabel_, materialLabel_, energyLabel_, costLabel_, wiringBtn_ },
                    },
                    UI.Panel {
                        flexDirection = "column", gap = 3,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        alignItems = "center",
                        children = { waveLabel_, previewLabel_, speedPanel_ },
                    },
                    UI.Panel {
                        flexDirection = "column", gap = 3,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
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

    -- ---- 背包面板（右侧，初始隐藏）----
    inventoryPanel_ = M.BuildInventoryPanel()

    -- ---- 塔详情面板（悬浮，初始隐藏）----
    towerDetailPanel_ = M.BuildTowerDetailPanel()

    -- ---- 统一 Root ----
    gameRoot_ = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            hudLayer_,
            inventoryPanel_,
            towerDetailPanel_,
            dragCtx_,  -- 最上层，渲染拖拽图标
        },
    }

    UI.SetRoot(gameRoot_)

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
    -- 创建槽位列表（水平排列）
    invSlots_ = {}
    local slotChildren = {}

    if #GS.artifactInventory == 0 then
        table.insert(slotChildren, UI.Panel {
            height = "100%",
            justifyContent = "center", alignItems = "center",
            paddingX = 20,
            children = {
                UI.Label {
                    text = "No artifacts yet",
                    fontSize = 12, fontColor = { 100, 110, 130, 160 },
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

            -- 已装配的圣器：在槽位下方显示状态
            local statusText = ""
            if entry.equipped then
                local tower = GS.towers[entry.towerIndex]
                local slotName = entry.slotType == "main" and "M" or "S"
                local posStr = tower and string.format("(%d,%d)", tower.gx, tower.gz) or "?"
                statusText = slotName .. " " .. posStr
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
                        fontSize = 7, fontColor = { 120, 255, 180, 200 },
                        textAlign = "center",
                    } or nil,
                },
            }

            invSlots_[i] = slot
            table.insert(slotChildren, slotWrapper)
        end
    end

    -- 底部水平面板：初始 bottom = INV_BOTTOM_HIDDEN（屏幕外）
    local panel = UI.Panel {
        position = "absolute",
        bottom = INV_BOTTOM_HIDDEN,
        left = 60, right = 60,
        height = INV_PANEL_HEIGHT,
        flexDirection = "row", gap = 0,
        backgroundColor = { 8, 12, 25, 230 },
        borderRadius = 12,
        borderWidth = 1, borderColor = { 60, 100, 160, 180 },
        overflow = "hidden",
        children = {
            -- 左侧标签区（紧凑）
            UI.Panel {
                height = "100%", width = 50,
                flexDirection = "column", justifyContent = "center",
                alignItems = "center", gap = 4,
                backgroundColor = { 20, 30, 55, 255 },
                borderRightWidth = 1, borderRightColor = { 50, 80, 140, 180 },
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = "BAG",
                        fontSize = 11, fontColor = { 255, 220, 80, 255 },
                    },
                    UI.Label {
                        text = "[B]",
                        fontSize = 9, fontColor = { 140, 150, 170, 160 },
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
            -- 右侧提示区（紧凑）
            UI.Panel {
                height = "100%", width = 50,
                flexDirection = "column", justifyContent = "center",
                alignItems = "center",
                backgroundColor = { 15, 20, 40, 220 },
                borderLeftWidth = 1, borderLeftColor = { 50, 80, 140, 140 },
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = "Drag\nto\nTower",
                        fontSize = 8, fontColor = { 130, 140, 160, 160 },
                        textAlign = "center",
                    },
                },
            },
        },
    }

    return panel
end

-- ============================================================================
-- 背包面板刷新（重建内容）
-- ============================================================================

function M.RefreshInventoryPanel()
    if not gameRoot_ or not inventoryPanel_ then return end

    -- 移除旧面板
    gameRoot_:RemoveChild(inventoryPanel_)

    -- 重建
    inventoryPanel_ = M.BuildInventoryPanel()
    -- 保持当前动画位置（面板用 bottom 定位，不再依赖 display:none）
    inventoryPanel_:SetStyle({ bottom = math.floor(invCurrentBottom_) })

    -- 重排子节点：hudLayer_, inventoryPanel_, towerDetailPanel_, dragCtx_
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
        text = "Tower Detail",
        fontSize = 14, fontColor = { 255, 220, 80, 255 },
        textAlign = "center",
    }
    detailStatsLabel_ = UI.Label {
        text = "",
        fontSize = 10, fontColor = { 200, 210, 220, 220 },
        whiteSpace = "normal", wordBreak = "break-word",
        textAlign = "center",
        maxWidth = 220,
    }

    -- 主槽 ItemSlot
    detailMainSlot_ = ItemSlot {
        slotId = "detail_main",
        slotCategory = "equipment",
        slotType = "artifact",
        item = nil,
        dragContext = dragCtx_,
        size = 46,
        slotTypeIcon = "M",
        showTypeIcon = true,
    }

    -- 副槽 ItemSlot
    detailSubSlot_ = ItemSlot {
        slotId = "detail_sub",
        slotCategory = "equipment",
        slotType = "artifact",
        item = nil,
        dragContext = dragCtx_,
        size = 46,
        slotTypeIcon = "S",
        showTypeIcon = true,
    }

    local panel = UI.Panel {
        position = "absolute", top = -999, left = -999,
        width = 240,
        flexDirection = "column", gap = 4,
        backgroundColor = { 8, 12, 25, 230 },
        borderRadius = 8, paddingX = 10, paddingY = 8,
        borderWidth = 1, borderColor = { 60, 100, 160, 180 },
        display = "none",  -- 初始隐藏
        pointerEvents = "box-none",  -- 面板本身不拦截点击，子控件仍可交互
        alignItems = "center",
        children = {
            detailTitleLabel_,
            -- 分割线
            UI.Panel { width = "90%", height = 1, backgroundColor = { 50, 80, 140, 120 } },
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
                            UI.Label { text = "Main 100%", fontSize = 9, fontColor = { 140, 200, 140, 200 } },
                            detailMainSlot_,
                            UI.Button {
                                text = "Unequip", width = 52, height = 20, fontSize = 8,
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
                            UI.Label { text = "Sub 60%", fontSize = 9, fontColor = { 180, 160, 100, 200 } },
                            detailSubSlot_,
                            UI.Button {
                                text = "Unequip", width = 52, height = 20, fontSize = 8,
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
-- 塔详情面板：显示 / 隐藏 / 刷新
-- ============================================================================

function M.ShowTowerDetail(towerIndex)
    if towerIndex < 1 or towerIndex > #GS.towers then return end

    -- 点击同一座塔 → 关闭面板 (toggle)
    if towerDetailVisible_ and currentDetailTower_ == towerIndex then
        M.HideTowerDetail()
        return
    end

    currentDetailTower_ = towerIndex
    towerDetailVisible_ = true
    if towerDetailPanel_ then
        towerDetailPanel_:SetStyle({ display = "flex" })
    end
    M.RefreshTowerDetail()
    M.UpdateTowerDetailPosition()

    -- 联动：打开塔详情时同时打开背包面板
    M.ShowArtifactPanel()
end

function M.HideTowerDetail()
    towerDetailVisible_ = false
    currentDetailTower_ = nil
    if towerDetailPanel_ then
        towerDetailPanel_:SetStyle({ display = "none", top = -9999, left = -9999 })
    end

    -- 联动：关闭塔详情时同时关闭背包面板
    M.HideArtifactPanel()
end

--- 每帧更新塔详情面板的屏幕位置（跟随塔的 3D 坐标）
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

    -- 塔上方约 1.5 米处作为锚点
    local worldPos = Vector3(tower.gx, 1.5, tower.gz)
    local screenNorm = GS.camera:WorldToScreenPoint(worldPos)

    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr

    local sx = screenNorm.x * screenW
    local sy = screenNorm.y * screenH

    -- 面板宽度 240，居中放置在锚点上方
    local panelW = 240
    local panelH = 200  -- 近似高度
    local px = sx - panelW * 0.5
    local py = sy - panelH - 10  -- 在锚点上方留出间距

    -- 边界约束
    px = math.max(4, math.min(screenW - panelW - 4, px))
    py = math.max(4, math.min(screenH - panelH - 4, py))

    local newTop = math.floor(py)
    local newLeft = math.floor(px)

    if towerDetailPanel_ then
        -- 只在位置实际变化时更新，避免不必要的布局重算
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

    -- 标题
    if detailTitleLabel_ then
        detailTitleLabel_:SetText(string.format("Tower (%d, %d)", tower.gx, tower.gz))
    end

    -- 属性
    if detailStatsLabel_ then
        local dmgBonus = dmg - baseDmg
        local dmgBonusStr = ""
        if math.abs(dmgBonus) > 0.1 then
            dmgBonusStr = string.format(" (%+.1f)", dmgBonus)
        end
        detailStatsLabel_:SetText(string.format(
            "Damage: %.1f%s\nAttack Speed: %.2fs\nPower: %.0f%%\nRange: %.1f",
            dmg, dmgBonusStr, fireInt, tower.ratio * 100, CONFIG.TowerRange
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
    -- 启动滑入动画
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
    -- 启动滑出动画
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
            upgradeCostLabel_:SetText(string.format("Cost: %d Gold + %d Material", cost.gold, cost.material))
        end
        if upgradeBtn_ then
            local canUp = EnergyTower.CanUpgrade()
            upgradeBtn_:SetText(canUp and "Upgrade" or "Insufficient")
            upgradeBtn_:SetDisabled(not canUp)
        end
    else
        if upgradeCostLabel_ then upgradeCostLabel_:SetText("MAX LEVEL") end
        if upgradeBtn_ then upgradeBtn_:SetText("Max Lv."); upgradeBtn_:SetDisabled(true) end
    end
end

function M.ShowUpgradePanel()
    if not upgradePanel_ then return end
    upgradePanel_:SetStyle({ display = "flex" })
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

    if goldLabel_ then goldLabel_:SetText("Gold: " .. GS.gold) end
    if materialLabel_ then materialLabel_:SetText("Material: " .. GS.material) end
    if energyLabel_ then energyLabel_:SetText("Energy: " .. GS.energy) end
    if costLabel_ then
        local costStr = "Next tower: " .. cost
        if not canBuild then costStr = costStr .. "  (insufficient)" end
        costLabel_:SetText(costStr)
    end

    local EnergyTower = require("EnergyTower")
    if statsLabel_ then
        local n = #GS.towers
        local nm = #GS.monsters
        if n == 0 then
            statsLabel_:SetText(string.format(
                "Lv.%d | HP: %d/%d | Towers: 0 | Mobs: %d",
                GS.etLevel, GS.etHP, GS.etMaxHP, nm
            ))
        else
            statsLabel_:SetText(string.format(
                "Lv.%d | HP: %d/%d | T: %d | M: %d",
                GS.etLevel, GS.etHP, GS.etMaxHP, n, nm
            ))
        end
    end

    if powerLabel_ then
        local n = #GS.towers
        local totalP = EnergyTower.GetTotalPower()
        if n == 0 then
            powerLabel_:SetText(string.format("P_total: %d | Idle", totalP))
        else
            -- 统计边数和总 DPS (图模型)
            local convEff = EnergyTower.GetConvEff()
            local numEdges = GS.energyGraph.edgeCount
            local totalDps = 0
            for ek, pwr in pairs(GS.energyNetwork.edgePower) do
                totalDps = totalDps + pwr * CONFIG.CircuitDmgCoeff * convEff
            end
            local scStr = GS.shortCircuit.active and " | SHORT!" or ""
            powerLabel_:SetText(string.format(
                "P: %d | E: %d | DPS: %.1f%s",
                totalP, numEdges, totalDps, scStr
            ))
        end
    end

    -- 布线按钮高亮
    if wiringBtn_ then
        wiringBtn_:SetVariant(GS.wiringMode and "primary" or "default")
        wiringBtn_:SetText(GS.wiringMode and "Wire ON [E]" or "Wire [E]")
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

    if waveLabel_ then waveLabel_:SetText(Wave.GetWaveInfo()) end
    if previewLabel_ then
        local preview = Wave.GetNextWavePreview()
        if preview then
            previewLabel_:SetText(string.format("Next: %s (%d)", preview.summary, preview.totalMonsters))
        else
            previewLabel_:SetText("")
        end
    end

    if upgradePanelVisible_ then M.RefreshUpgradePanel() end

    M.UpdateHintLabel()
    M.CheckDropOverlay()

    -- 塔详情面板：跟踪位置 + 自动关闭（塔被拆除时）
    if towerDetailVisible_ and currentDetailTower_ then
        if currentDetailTower_ > #GS.towers then
            M.HideTowerDetail()
        else
            M.UpdateTowerDetailPosition()
        end
    end

    -- ---- 背包面板滑入/滑出动画驱动 ----
    if invAnimating_ and inventoryPanel_ then
        local elapsed = time.elapsedTime - invAnimStartTime_
        local progress = math.min(elapsed / INV_ANIM_DURATION, 1.0)

        -- 根据方向选择缓动函数
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
-- 悬停提示
-- ============================================================================

function M.UpdateHintLabel()
    if not hintLabel_ then return end

    local Tower = require("Tower")
    local EnergyTower = require("EnergyTower")

    if GS.wiringMode then
        local base = "WIRING: LDrag draw | RClick remove | E exit | " .. CONFIG.LineCostPerSegment .. "g/seg"
        if GS.wiringHintMsg then
            base = base .. "  |  " .. GS.wiringHintMsg
        end
        hintLabel_:SetText(base)
        return
    end

    if not GS.hoverOnMap then
        hintLabel_:SetText("LClick: Build | Click Tower: Detail | X: Sell | U: Upgrade | E: Wire | B: Bag | Tab: Speed | MMB: Pan")
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
            "Energy Tower Lv.%d | Power: %d | Range: %d | ConvEff: %.2f | Click to Upgrade",
            GS.etLevel, EnergyTower.GetTotalPower(), EnergyTower.GetEnergyRange(), EnergyTower.GetConvEff()
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
                local artInfo = Artifact.GetTowerArtifactInfo(idx)
                local artStr = ""
                if artInfo.main then artStr = artStr .. " M:" .. artInfo.main.name end
                if artInfo.sub then artStr = artStr .. " S:" .. artInfo.sub.name end
                hintLabel_:SetText(string.format(
                    "Tower (%d,%d) | Dmg: %.1f | ASpd: %.2fs | Pwr: %.0f%%%s | [X] Sell: %d | LClick: Detail",
                    gx, gz, dmg, fireInt, tower.ratio * 100, artStr, refund
                ))
                break
            end
        end
    elseif not canAfford then
        hintLabel_:SetText("Not enough gold! Need: " .. Tower.GetTowerCost())
    else
        -- 新塔尚未连线，显示建造成本和提示
        hintLabel_:SetText(string.format(
            "Build | Cost: %d | Need wiring to activate",
            Tower.GetTowerCost()
        ))
    end
end

-- ============================================================================
-- 圣器掉落 3 选 1
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
                local statName = ds.stat == "damage" and "DMG" or
                                 ds.stat == "attack_speed" and "ASPD" or ds.stat
                dsText = dsText .. string.format("-%d%% %s  ", pct, statName)
            end
        end
        if dsText == "" then dsText = "No downside" end

        local idx = i
        local card = UI.Panel {
            width = 190, flexDirection = "column", gap = 8,
            backgroundColor = bg,
            borderRadius = 12, paddingX = 16, paddingY = 16,
            borderWidth = 2, borderColor = bc,
            alignItems = "center",
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
                    fontColor = { 200, 210, 220, 200 },
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
                    text = "Pick [" .. idx .. "]",
                    variant = "primary",
                    width = 130, height = 34, fontSize = 14,
                    onClick = function() M.OnDropPick(idx) end,
                },
            },
        }
        table.insert(cards, card)
    end

    local skipBtn = UI.Button {
        text = "Skip (+50 Gold) [0]",
        width = 160, height = 34, fontSize = 13,
        onClick = function() M.OnDropPick(0) end,
    }

    dropOverlay_ = UI.Panel {
        width = "100%", height = "100%",
        position = "absolute", top = 0, left = 0,
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 180 },
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 20,
                children = {
                    UI.Panel {
                        flexDirection = "column", alignItems = "center", gap = 4,
                        children = {
                            UI.Label {
                                text = "Wave Clear!", fontSize = 14,
                                fontColor = { 180, 200, 220, 200 },
                            },
                            UI.Label {
                                text = "Choose Your Artifact", fontSize = 24,
                                fontColor = { 255, 220, 80, 255 },
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

    -- 将掉落覆盖层添加到 gameRoot_（在 dragCtx_ 之前）
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
-- UI 面板命中检测（鼠标是否在背包 / 塔详情面板上）
-- ============================================================================

--- 检查鼠标是否在某个绝对定位面板的矩形范围内
--- @param panelProps table 面板的 props（包含 top/left/right/bottom/width/height）
--- @param screenW number 逻辑屏幕宽度
--- @param screenH number 逻辑屏幕高度
--- @return boolean
local function isMouseInPanel(panelProps, screenW, screenH)
    if not panelProps then return false end

    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr

    -- 计算面板在屏幕上的矩形区域
    local pLeft = panelProps.left or 0
    local pTop = panelProps.top or 0
    local pWidth = panelProps.width or 0
    local pHeight = panelProps.height or 0

    -- 如果使用 right 定位（背包面板）
    if panelProps.right and not panelProps.left then
        pLeft = screenW - (panelProps.right or 0) - pWidth
    end

    -- 如果使用 bottom 定位确定高度范围
    if panelProps.bottom and panelProps.top then
        pHeight = screenH - pTop - panelProps.bottom
    end

    return mx >= pLeft and mx <= pLeft + pWidth
       and my >= pTop and my <= pTop + pHeight
end

--- 检查鼠标是否在任何 UI 面板上（背包面板或塔详情面板）
local function isMouseOverUIPanel()
    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr

    -- 检查背包面板（底部水平面板，position=absolute, bottom=动画值, left=60, right=60, height=INV_PANEL_HEIGHT）
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

    -- 检查塔详情面板（动态定位，width=240, height≈220）
    if towerDetailVisible_ and towerDetailPanel_ and towerDetailPanel_.props then
        local tp = towerDetailPanel_.props
        if tp.top and tp.top > -9000 and tp.left and tp.left > -9000 then
            local detailProps = { top = tp.top, left = tp.left, width = 240, height = 220 }
            if isMouseInPanel(detailProps, screenW, screenH) then
                return true
            end
        end
    end

    return false
end

--- 公开 API：供 Tower.lua 等外部模块查询
function M.IsMouseOverUIPanel()
    return isMouseOverUIPanel()
end

-- ============================================================================
-- 圣器键盘操作（精简版：只保留 I 键和掉落快捷键）
-- ============================================================================

function M.HandleArtifactInput()
    -- E 键切换布线模式
    if input:GetKeyPress(KEY_E) then
        local EnergyTower = require("EnergyTower")
        EnergyTower.ToggleWiringMode()
        return
    end

    -- B 键切换背包面板
    if input:GetKeyPress(KEY_B) then
        M.ToggleArtifactPanel()
        return
    end

    -- 掉落选择快捷键
    if dropOverlayVisible_ then
        if input:GetKeyPress(KEY_1) then M.OnDropPick(1); return end
        if input:GetKeyPress(KEY_2) then M.OnDropPick(2); return end
        if input:GetKeyPress(KEY_3) then M.OnDropPick(3); return end
        if input:GetKeyPress(KEY_0) then M.OnDropPick(0); return end
        return
    end

    -- 左键点击：处理能源塔升级面板 / 塔详情面板 open / toggle / switch
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        -- 如果鼠标在 UI 面板上，吞掉点击事件，不做任何关闭/切换
        -- 这样拖拽圣器到面板槽位才能正常工作
        if isMouseOverUIPanel() then
            return
        end

        -- 点击能源塔 (0,0) → 切换升级面板
        if GS.hoverOnMap and GS.hoverGX == 0 and GS.hoverGZ == 0 then
            M.ToggleUpgradePanel()
            return
        end

        if towerDetailVisible_ then
            -- 面板已打开：检查是否切换到另一座塔
            if GS.hoverOnMap and not GS.hoverValid then
                local Tower = require("Tower")
                local idx = Tower.GetTowerAtHover()
                if idx and idx ~= currentDetailTower_ then
                    M.ShowTowerDetail(idx)
                    return
                end
            end
            -- 点击非塔的空白区域 → 关闭面板
            M.HideTowerDetail()
            -- 同时关闭升级面板
            if upgradePanelVisible_ then M.HideUpgradePanel() end
            return
        else
            -- 面板未打开：点击塔 → 打开详情
            if GS.hoverOnMap and not GS.hoverValid then
                local Tower = require("Tower")
                local idx = Tower.GetTowerAtHover()
                if idx then
                    M.ShowTowerDetail(idx)
                    return
                end
            end
        end

        -- 点击空白区域，关闭升级面板
        if upgradePanelVisible_ then M.HideUpgradePanel() end
    end

    -- Escape 关闭面板（优先关闭升级面板，再关闭塔详情，再关闭背包）
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
-- GameOver / Victory
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
                        text = "GAME OVER", fontSize = 36,
                        fontColor = { 255, 60, 60, 255 },
                    },
                    UI.Label {
                        text = string.format("Wave: %d/%d | Towers Built: %d | Monsters Killed: %d",
                            GS.currentWave, 20, #GS.towers, GS.monstersKilled),
                        fontSize = 16, fontColor = { 200, 200, 200, 220 },
                    },
                    UI.Label {
                        text = "Energy Tower Destroyed", fontSize = 14,
                        fontColor = { 255, 180, 100, 200 },
                    },
                },
            },
        },
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
                        text = "VICTORY!", fontSize = 36,
                        fontColor = { 60, 255, 60, 255 },
                    },
                    UI.Label {
                        text = string.format("All 20 waves cleared! | Towers: %d | Gold: %d",
                            #GS.towers, GS.gold),
                        fontSize = 16, fontColor = { 200, 255, 200, 220 },
                    },
                    UI.Label {
                        text = "Congratulations, Commander!", fontSize = 14,
                        fontColor = { 255, 220, 100, 200 },
                    },
                },
            },
        },
    }
    UI.SetRoot(overlay)
end

function M.Shutdown()
    UI.Shutdown()
end

return M
