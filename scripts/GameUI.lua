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
    -- 信息层级 (BrawlForge Sci-Fi HUD)
    gold       = { 255, 198, 26, 255 },    -- 关键 (金币、标题) $warning
    energy     = { 31, 162, 255, 255 },    -- 能量主题 (青蓝) $primary
    success    = { 67, 213, 44, 255 },     -- 正面 (材料、满血) $success
    danger     = { 245, 50, 45, 255 },     -- 警告 (不足、危险) $error
    warning    = { 255, 198, 26, 255 },    -- 注意 (中等重要) $warning
    secondary  = { 213, 226, 255, 255 },   -- 次要描述 $textSecondary
    muted      = { 157, 166, 198, 255 },   -- 提示 / 禁用 $textDisabled
    bright     = { 255, 255, 255, 255 },   -- 高亮白 $text

    -- 面板样式 (BrawlForge: 深蓝面板 + 黑色边框 + 零模糊阴影)
    panelBg    = { 33, 69, 138, 245 },     -- $surface
    panelBorder = { 10, 16, 32, 255 },     -- $border (黑色)
    panelShadow = {{ x = 6, y = 6, blur = 0, color = { 0, 0, 0, 64 } }},
    divider    = { 10, 16, 32, 180 },      -- 深色分割线

    -- BrawlForge 额外
    panelBgDark = { 21, 45, 100, 255 },    -- 深色面板 (侧栏)
    accent     = { 14, 137, 255, 255 },    -- 强调色 (头部条)
    borderFocus = { 111, 231, 255, 255 },  -- 聚焦高亮 $borderFocus
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
local detailSlots_ = { nil, nil, nil }  -- 三个等效配件槽 ItemSlot
local detailTitleLabel_ = nil
local detailEnergyLabel_ = nil
local detailStatsLabel_ = nil
local detailDemolishLabel_ = nil
local detailDemolishBtn_ = nil

-- 建塔确认气泡
local placementBubble_ = nil
local placementBubbleCostLabel_ = nil

-- 圣器 Hover Tooltip
local tooltipPanel_ = nil
local tooltipNameLabel_ = nil
local tooltipRarityLabel_ = nil
local tooltipDescLabel_ = nil
local tooltipDownsideLabel_ = nil

-- ============================================================================
-- 圣器视觉映射
-- ============================================================================

-- 全圣器图标（1~2汉字缩写）
local ARTIFACT_ICONS = {
    -- 攻击类
    rapid_fire_module  = "速射",
    fire_seed          = "火种",
    ice_crystal        = "冰晶",
    corrosion          = "腐蚀",
    thunder            = "雷鸣",
    splinter           = "裂片",
    piercing_core      = "穿透",
    sniper_mod         = "狙击",
    prism              = "棱镜",
    high_explosive     = "高爆",
    crit_device        = "暴击",
    resonance_trigger  = "共振",
    elemental_core     = "元素",
    -- 增益类
    aura_attack_speed  = "攻环",
    aura_damage        = "伤环",
    aura_range         = "程环",
    aura_crit          = "暴环",
    range_compression  = "远压",
    power_borrow       = "借力",
    master_tower       = "总管",
    defense_garrison   = "防阵",
    network            = "网络",
    devour_line        = "吞线",
    ice_crystal_conduit = "冰管",
    resonance_amplifier = "放大",
    elemental_reaction = "元反",
    overload_relay     = "过载",
    energy_ammo        = "注能",
    -- 收集类
    coin_magnet        = "磁币",
    gold_refinery      = "炼金",
    energy_matrix      = "充能",
    charged_hit        = "蓄力",
    condenser          = "凝聚",
    resource_enrichment = "富集",
    compound_interest  = "复利",
    feedback_coil      = "反馈",
}

-- 背景色按 category 区分: 攻击=暗红, 增益=深蓝, 收集=暗绿
local _CAT_BG = {
    attack     = { 70, 20, 15, 230 },
    buff       = { 15, 25, 70, 230 },
    collection = { 15, 55, 25, 230 },
}

local function artifactBg(def)
    if not def then return { 30, 30, 50, 230 } end
    return _CAT_BG[def.category] or { 30, 30, 50, 230 }
end

-- 保留旧表兼容（空，逻辑改用 artifactBg()）
local ARTIFACT_BG = {}

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
    -- BrawlForge Sci-Fi HUD 主题
    local BTN_SHADOW = {
        { x = 6, y = 6, blur = 0, color = {0, 0, 0, 51} },
    }
    local HUD_SHADOW = {
        { x = 6, y = 6, blur = 0, color = {0, 0, 0, 64} },
    }
    local TOAST_SHADOW = {
        { x = 8, y = 8, blur = 0, color = {0, 0, 0, 64} },
    }

    local BrawlForgeTheme = UI.Theme.ExtendTheme(UI.Theme.defaultTheme, {
        colors = {
            primary = {31, 162, 255, 255},
            primaryHover = {70, 183, 255, 255},
            primaryPressed = {13, 126, 230, 255},
            secondary = {214, 53, 255, 255},
            secondaryHover = {224, 97, 255, 255},
            secondaryPressed = {181, 35, 232, 255},
            background = {34, 89, 183, 255},
            surface = {33, 69, 138, 255},
            surfaceHover = {45, 102, 200, 255},
            text = {255, 255, 255, 255},
            textSecondary = {213, 226, 255, 255},
            textDisabled = {157, 166, 198, 255},
            border = {10, 16, 32, 255},
            borderFocus = {111, 231, 255, 255},
            disabled = {57, 71, 107, 255},
            disabledText = {139, 150, 184, 255},
            success = {67, 213, 44, 255},
            successHover = {98, 232, 78, 255},
            warning = {255, 198, 26, 255},
            warningHover = {255, 215, 85, 255},
            error = {245, 50, 45, 255},
            errorHover = {255, 90, 71, 255},
            info = {70, 199, 255, 255},
            overlay = {7, 16, 28, 187},
            hover = {255, 255, 255, 25},
        },
        radius = {
            none = 0, sm = 4, md = 6, lg = 10, xl = 14, full = 9999,
        },
        componentDefaults = {
            borderRadius = 0,
            fontWeight = "bold",
        },
        components = {
            Button = {
                borderWidth = {2, 4, 4, 2},
                borderRadius = 0, fontWeight = "bold",
                height = 50, fontSize = 15,
                padding = {4, 6, 10, 4},
                boxShadow = BTN_SHADOW,
                decorations = {
                    primary = {
                        { position = "absolute", top = 2, left = 2, right = 4, bottom = 4,
                          borderWidth = {2, 2, 6, 2}, borderColor = {27, 115, 227, 255},
                          hoverBorderColor = {43, 143, 240, 255},
                          pressedBorderColor = {8, 79, 146, 255} },
                    },
                    secondary = {
                        { position = "absolute", top = 2, left = 2, right = 4, bottom = 4,
                          borderWidth = {2, 2, 6, 2}, borderColor = {142, 45, 226, 255},
                          hoverBorderColor = {163, 71, 244, 255},
                          pressedBorderColor = {101, 16, 171, 255} },
                    },
                    danger = {
                        { position = "absolute", top = 2, left = 2, right = 4, bottom = 4,
                          borderWidth = {2, 2, 6, 2}, borderColor = {169, 27, 23, 255},
                          hoverBorderColor = {196, 42, 38, 255},
                          pressedBorderColor = {132, 17, 14, 255} },
                    },
                    success = {
                        { position = "absolute", top = 2, left = 2, right = 4, bottom = 4,
                          borderWidth = {2, 2, 6, 2}, borderColor = {35, 116, 24, 255},
                          hoverBorderColor = {53, 181, 33, 255},
                          pressedBorderColor = {22, 111, 9, 255} },
                    },
                },
            },
            TextField = { borderWidth = 3, borderRadius = 0, fontWeight = "bold" },
            Checkbox = {
                borderWidth = 3, borderRadius = 0,
                checkedBgColor = {31, 162, 255, 255},
                checkedBorderColor = {10, 100, 183, 255},
                hoverBorderColor = {31, 162, 255, 255},
                checkmarkColor = {255, 255, 255, 255},
            },
            Toggle = {
                borderWidth = 3, borderRadius = 0,
                thumbColor = {213, 226, 255, 255},
                thumbCheckedColor = {255, 255, 255, 255},
                trackBg = {33, 69, 138, 255},
                trackBorderColor = {10, 16, 32, 255},
                trackCheckedBgColor = {31, 162, 255, 255},
                trackCheckedBorderColor = {10, 100, 183, 255},
            },
            Slider = {
                borderRadius = 0, trackHeight = 4,
                trackBgColor = {33, 69, 138, 255},
                trackFillColor = {31, 162, 255, 255},
                thumbColor = {31, 162, 255, 255},
                thumbSize = 18, thumbBorderWidth = 3,
                thumbBorderColor = {10, 100, 183, 255},
                thumbBorderRadius = 0,
            },
            Card = {
                borderWidth = 2, borderRadius = 0,
                boxShadow = { { x = 4, y = 4, blur = 0, color = {0, 0, 0, 64} } },
            },
            Badge = { borderWidth = 2, borderRadius = 0 },
            Alert = { borderWidth = 3, borderRadius = 0 },
            ProgressBar = { borderRadius = 0, height = 8 },
            Modal = {
                borderWidth = 3, borderRadius = 0,
                boxShadow = HUD_SHADOW,
                headerBgColor = {14, 137, 255, 255},
                contentBgColor = {33, 69, 139, 255},
                headerBorderWidth = 5,
                footerBorderWidth = 0,
                headerFullWidthBorder = true,
            },
            Toast = {
                borderWidth = 2, borderRadius = 0,
                boxShadow = TOAST_SHADOW,
                accentBarWidth = 4,
                showIcon = false,
            },
            Tooltip = {
                borderWidth = 2, borderRadius = 0,
                boxShadow = HUD_SHADOW,
                tooltipBgColor = {254, 160, 2, 255},
                borderColor = {249, 95, 3, 255},
            },
        },
    })

    UI.Init({
        theme = BrawlForgeTheme,
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/NotoSansSC-Black.ttf",
                bold = "Fonts/NotoSansSC-Black.ttf",
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
    -- 将 UI slot ID 映射到 Artifact 槽位 key
    local slotType = nil
    if slotId == "detail_slot1" then slotType = "slot1"
    elseif slotId == "detail_slot2" then slotType = "slot2"
    elseif slotId == "detail_slot3" then slotType = "slot3"
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
    -- 找第一个空槽
    local slotType = "slot1"
    for i = 1, 3 do
        if not tower.slots[i] then
            slotType = "slot" .. i
            break
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
        fontSize = 11,
        fontColor = CLR.muted,
        position = "absolute",
        bottom = 10, left = 0, right = 0,
        textAlign = "center",
    }

    -- 速度按钮组
    speedBtn1_ = UI.Button {
        text = "x1", width = 44, height = 28, fontSize = 11,
        variant = "primary",
        transition = "backgroundColor 0.15s easeOut, borderColor 0.15s easeOut",
        onClick = function() GS.gameSpeed = 1 end,
    }
    speedBtn2_ = UI.Button {
        text = "x2", width = 44, height = 28, fontSize = 11,
        transition = "backgroundColor 0.15s easeOut, borderColor 0.15s easeOut",
        onClick = function() GS.gameSpeed = 2 end,
    }
    speedBtn3_ = UI.Button {
        text = "x3", width = 44, height = 28, fontSize = 11,
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
        text = "布线 [E]", width = 80, height = 30, fontSize = 11,
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
        borderRadius = 0, paddingX = 16, paddingY = 12,
        borderWidth = 2, borderColor = CLR.panelBorder,
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
                        borderRadius = 0, paddingX = 14, paddingY = 10,
                        borderWidth = 2, borderColor = CLR.panelBorder,
                        boxShadow = CLR.panelShadow,
                        children = { goldLabel_, materialLabel_, energyLabel_, costLabel_, wiringBtn_ },
                    },
                    -- 中上: 波次面板
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = CLR.panelBg,
                        borderRadius = 0, paddingX = 14, paddingY = 10,
                        borderWidth = 2, borderColor = CLR.panelBorder,
                        boxShadow = CLR.panelShadow,
                        alignItems = "center",
                        children = { waveLabel_, previewLabel_, speedPanel_ },
                    },
                    -- 右上: 状态面板
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = CLR.panelBg,
                        borderRadius = 0, paddingX = 14, paddingY = 10,
                        borderWidth = 2, borderColor = CLR.panelBorder,
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
    -- Tooltip 面板（最后添加，保证在最顶层）
    tooltipPanel_ = M.BuildTooltipPanel()

    gameRoot_ = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            hudLayer_,
            inventoryPanel_,
            towerDetailPanel_,
            placementBubble_,
            dragCtx_,
            tooltipPanel_,
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
        -- 按 id 分组堆叠：{ id -> { unequippedIdx, equippedCount, totalCount } }
        local groups = {}   -- 保序列表：{ id, firstUnequippedIdx, unequippedCount, equippedCount }
        local order = {}    -- 保持首次出现顺序
        local seen = {}
        for i, entry in ipairs(GS.artifactInventory) do
            local id = entry.id
            if not seen[id] then
                seen[id] = true
                table.insert(order, id)
                groups[id] = { id = id, firstUnequippedIdx = nil, unequippedCount = 0, equippedCount = 0 }
            end
            if entry.equipped then
                groups[id].equippedCount = groups[id].equippedCount + 1
            else
                groups[id].unequippedCount = groups[id].unequippedCount + 1
                if not groups[id].firstUnequippedIdx then
                    groups[id].firstUnequippedIdx = i
                end
            end
        end

        local slotCounter = 0
        for _, id in ipairs(order) do
            local g = groups[id]
            local entry = GS.artifactInventory[g.firstUnequippedIdx or 1]
            -- 若全部已装备则用任意一个 entry 显示（置灰）
            if not entry then
                for _, e in ipairs(GS.artifactInventory) do
                    if e.id == id then entry = e; break end
                end
            end
            if not entry then goto continue end

            local icon = ARTIFACT_ICONS[entry.id] or entry.def.name:sub(1, 4)
            local rc = rarityColor(entry.def.rarity)
            local totalCount = g.unequippedCount + g.equippedCount

            -- 可拖拽 itemData 只在有未装备时提供
            local itemData = nil
            if g.firstUnequippedIdx then
                itemData = {
                    id = entry.id,
                    name = entry.def.name,
                    icon = icon,
                    type = "artifact",
                    invIndex = g.firstUnequippedIdx,
                }
            end

            slotCounter = slotCounter + 1
            local slot = ItemSlot {
                slotId = "inv_grp_" .. slotCounter,
                slotCategory = "inventory",
                slotType = "any",
                item = itemData,
                dragContext = dragCtx_,
                size = 52,
            }

            -- 数量徽章（叠在图标右下角）
            local badgeNode = (totalCount > 1) and UI.Panel {
                position = "absolute",
                bottom = 1, right = 1,
                paddingX = 3, paddingY = 1,
                backgroundColor = { 0, 0, 0, 200 },
                borderRadius = 3,
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = "×" .. totalCount,
                        fontSize = 9, fontColor = CLR.gold,
                        pointerEvents = "none",
                    },
                },
            } or nil

            -- 装备状态文字（有装备时显示）
            local statusNode = (g.equippedCount > 0) and UI.Label {
                text = "已装" .. g.equippedCount,
                fontSize = 7, fontColor = CLR.success,
                textAlign = "center",
            } or nil

            -- 图标容器（相对定位，用于放置数量徽章）
            local iconContainer = UI.Panel {
                position = "relative",
                width = 52, height = 52,
                flexShrink = 0,
                children = badgeNode and { slot, badgeNode } or { slot },
            }

            local def = entry.def
            local slotWrapper = UI.Panel {
                flexDirection = "column", gap = 1, alignItems = "center",
                width = 58, flexShrink = 0,
                onPointerEnter = function(evt, _)
                    M.ShowArtifactTooltip(def, evt.x, evt.y)
                end,
                onPointerLeave = function(_, _)
                    M.HideArtifactTooltip()
                end,
                children = {
                    iconContainer,
                    UI.Label {
                        text = entry.def.name,
                        fontSize = 8, fontColor = rc,
                        textAlign = "center", maxWidth = 56,
                    },
                    statusNode,
                },
            }

            invSlots_[slotCounter] = slot
            table.insert(slotChildren, slotWrapper)
            ::continue::
        end
    end

    local panel = UI.Panel {
        position = "absolute",
        bottom = INV_BOTTOM_HIDDEN,
        left = 60, right = 60,
        height = INV_PANEL_HEIGHT,
        flexDirection = "row", gap = 0,
        backgroundColor = CLR.panelBg,
        borderRadius = 0,
        borderWidth = 2, borderColor = CLR.panelBorder,
        boxShadow = CLR.panelShadow,
        overflow = "hidden",
        children = {
            -- 左侧标签区
            UI.Panel {
                height = "100%", width = 50,
                flexDirection = "column", justifyContent = "center",
                alignItems = "center", gap = 4,
                backgroundColor = CLR.panelBgDark,
                borderRightWidth = 2, borderRightColor = CLR.panelBorder,
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
                backgroundColor = CLR.panelBgDark,
                borderLeftWidth = 2, borderLeftColor = CLR.panelBorder,
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
    -- 用 Panel+Label 手动实现按钮，彻底绕开 UI.Button 的阴影层渲染问题

    detailTitleLabel_ = UI.Label {
        text = "防御塔", fontSize = 13, fontColor = CLR.gold,
    }
    detailEnergyLabel_ = UI.Label {
        text = "能量: 0%", fontSize = 11, fontColor = { 120, 220, 180, 255 },
    }
    detailStatsLabel_ = UI.Label {
        text = "", fontSize = 11, fontColor = CLR.secondary, textAlign = "center",
    }

    -- 回收按钮文字 label（用于动态更新金额）
    detailDemolishBtn_ = UI.Label {
        text = "回收 +-- 🪙", fontSize = 12,
        fontColor = { 255, 255, 255, 255 }, textAlign = "center",
        pointerEvents = "none",
    }

    local slotLabels = { "①", "②", "③" }
    for i = 1, 3 do
        detailSlots_[i] = ItemSlot {
            slotId = "detail_slot" .. i,
            slotCategory = "equipment",
            slotType = "artifact",
            item = nil,
            dragContext = dragCtx_,
            size = 42,
            slotTypeIcon = slotLabels[i],
            showTypeIcon = true,
        }
    end

    -- 构建"卸下"按钮（Panel+Label 手动实现）
    local function makeUnequipBtn(idx)
        return UI.Panel {
            width = 54, height = 22,
            backgroundColor = { 55, 75, 120, 230 },
            borderRadius = 3,
            borderWidth = 1, borderColor = { 90, 120, 185, 255 },
            justifyContent = "center", alignItems = "center",
            cursor = "pointer",
            onClick = function()
                if not currentDetailTower_ then return end
                local tower = GS.towers[currentDetailTower_]
                if tower and tower.slots and tower.slots[idx] then
                    Artifact.UnequipFromTower(tower.slots[idx])
                    M.RefreshTowerDetail()
                    M.RefreshInventoryPanel()
                end
            end,
            children = {
                UI.Label { text = "卸下", fontSize = 9, fontColor = { 255, 255, 255, 255 } },
            },
        }
    end

    -- 回收按钮容器（Panel+Label 手动实现）
    local demolishContainer = UI.Panel {
        width = 200, height = 30,
        backgroundColor = { 185, 40, 40, 255 },
        borderRadius = 4,
        justifyContent = "center", alignItems = "center",
        cursor = "pointer",
        onClick = function()
            if not currentDetailTower_ then return end
            local Tower = require("Tower")
            Tower.DemolishTower(currentDetailTower_)
            M.HideTowerDetail()
            local GameUI = require("GameUI")
            GameUI.RefreshUpgradePanel()
        end,
        children = { detailDemolishBtn_ },
    }

    local panel = UI.Panel {
        position = "absolute", top = -999, left = -999,
        width = 240,
        flexDirection = "column", gap = 6,
        backgroundColor = CLR.panelBg,
        borderRadius = 4, paddingX = 12, paddingY = 10,
        borderWidth = 2, borderColor = CLR.panelBorder,
        boxShadow = CLR.panelShadow,
        display = "none",
        pointerEvents = "box-none",
        alignItems = "center",
        children = {
            -- 标题行：防御塔（左） | 能量（右），两侧有内边距
            UI.Panel {
                flexDirection = "row", width = "100%",
                paddingX = 4,
                justifyContent = "space-between", alignItems = "center",
                children = { detailTitleLabel_, detailEnergyLabel_ },
            },
            UI.Panel { width = "92%", height = 1, backgroundColor = CLR.divider },
            -- 属性：伤害 | 攻速（单行，| 分隔）
            detailStatsLabel_,
            UI.Panel { width = "92%", height = 1, backgroundColor = CLR.divider },
            -- 三个装备槽（无标签）
            UI.Panel {
                flexDirection = "row", gap = 10,
                alignItems = "flex-start",
                children = {
                    UI.Panel { flexDirection = "column", gap = 4, alignItems = "center",
                        onPointerEnter = function(evt, _)
                            if not currentDetailTower_ then return end
                            local t = GS.towers[currentDetailTower_]
                            local idx = t and t.slots and t.slots[1]
                            local e = idx and GS.artifactInventory[idx]
                            if e then M.ShowArtifactTooltip(e.def, evt.x, evt.y) end
                        end,
                        onPointerLeave = function() M.HideArtifactTooltip() end,
                        children = { detailSlots_[1], makeUnequipBtn(1) } },
                    UI.Panel { flexDirection = "column", gap = 4, alignItems = "center",
                        onPointerEnter = function(evt, _)
                            if not currentDetailTower_ then return end
                            local t = GS.towers[currentDetailTower_]
                            local idx = t and t.slots and t.slots[2]
                            local e = idx and GS.artifactInventory[idx]
                            if e then M.ShowArtifactTooltip(e.def, evt.x, evt.y) end
                        end,
                        onPointerLeave = function() M.HideArtifactTooltip() end,
                        children = { detailSlots_[2], makeUnequipBtn(2) } },
                    UI.Panel { flexDirection = "column", gap = 4, alignItems = "center",
                        onPointerEnter = function(evt, _)
                            if not currentDetailTower_ then return end
                            local t = GS.towers[currentDetailTower_]
                            local idx = t and t.slots and t.slots[3]
                            local e = idx and GS.artifactInventory[idx]
                            if e then M.ShowArtifactTooltip(e.def, evt.x, evt.y) end
                        end,
                        onPointerLeave = function() M.HideArtifactTooltip() end,
                        children = { detailSlots_[3], makeUnequipBtn(3) } },
                },
            },
            -- 回收按钮
            UI.Panel { width = "92%", height = 1, backgroundColor = CLR.divider },
            demolishContainer,
        },
    }

    return panel
end

-- ============================================================================
-- 圣器 Hover Tooltip
-- ============================================================================

function M.BuildTooltipPanel()
    tooltipNameLabel_ = UI.Label {
        text = "名称", fontSize = 13, fontColor = CLR.gold,
        textAlign = "left",
    }
    tooltipRarityLabel_ = UI.Label {
        text = "稀有度", fontSize = 10, fontColor = CLR.muted,
        textAlign = "left",
    }
    tooltipDescLabel_ = UI.Label {
        text = "描述", fontSize = 11, fontColor = CLR.secondary,
        textAlign = "left", maxWidth = 200,
    }
    tooltipDownsideLabel_ = UI.Label {
        text = "", fontSize = 10, fontColor = CLR.danger,
        textAlign = "left", maxWidth = 200,
    }

    local panel = UI.Panel {
        position = "absolute",
        top = -9999, left = -9999,
        display = "none",
        flexDirection = "column", gap = 5,
        paddingX = 12, paddingY = 10,
        backgroundColor = { 18, 30, 60, 242 },
        borderRadius = 5,
        borderWidth = 2, borderColor = CLR.panelBorder,
        boxShadow = {{ x = 4, y = 4, blur = 0, color = { 0, 0, 0, 120 } }},
        pointerEvents = "none",
        minWidth = 170, maxWidth = 220,
        children = {
            tooltipNameLabel_,
            tooltipRarityLabel_,
            UI.Panel { width = "100%", height = 1, backgroundColor = CLR.divider },
            tooltipDescLabel_,
            tooltipDownsideLabel_,
        },
    }
    return panel
end

--- 在指定屏幕位置显示圣器 tooltip
--- @param def table 圣器定义
--- @param screenX number 屏幕 X（像素）
--- @param screenY number 屏幕 Y（像素）
function M.ShowArtifactTooltip(def, screenX, screenY)
    if not tooltipPanel_ or not def then return end

    local rarityNames = { white = "普通", blue = "精良", purple = "史诗", gold = "传说" }
    local rarityName = rarityNames[def.rarity] or def.rarity

    tooltipNameLabel_:SetStyle({ text = def.name, fontColor = rarityColor(def.rarity) })
    tooltipRarityLabel_:SetStyle({ text = "[ " .. rarityName .. " · " .. (def.category or "") .. " ]" })
    tooltipDescLabel_:SetStyle({ text = def.description or "" })

    -- 负面效果汇总
    local downsides = {}
    if def.downsides then
        for _, d in ipairs(def.downsides) do
            if d.type == "stat_modifier" and d.modifier and d.modifier < 0 then
                local pct = math.floor(math.abs(d.modifier) * 100 + 0.5)
                local statNames = {
                    damage = "单发伤害", attack_speed = "攻速",
                    range = "射程", range_flat = "射程",
                }
                local sn = statNames[d.stat] or d.stat
                table.insert(downsides, sn .. " -" .. pct .. "%")
            end
        end
    end
    if #downsides > 0 then
        tooltipDownsideLabel_:SetStyle({ text = "▼ " .. table.concat(downsides, "  "), display = "flex" })
    else
        tooltipDownsideLabel_:SetStyle({ display = "none" })
    end

    -- 位置：优先显示在光标右侧，靠近屏幕边缘时左移
    local w = graphics:GetWidth() / graphics:GetDPR()
    local tipW = 220
    local tipX = screenX + 14
    if tipX + tipW > w - 10 then
        tipX = screenX - tipW - 14
    end
    local tipY = screenY - 10

    tooltipPanel_:SetStyle({ display = "flex", top = math.floor(tipY), left = math.floor(tipX) })
end

--- 隐藏 tooltip
function M.HideArtifactTooltip()
    if tooltipPanel_ then
        tooltipPanel_:SetStyle({ display = "none", top = -9999, left = -9999 })
    end
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
                backgroundColor = CLR.panelBg,
                borderRadius = 0, paddingX = 8, paddingY = 2,
                borderWidth = 1, borderColor = CLR.panelBorder,
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

    local panelW = 230
    local panelH = 280
    local px = sx - panelW * 0.5
    local py = sy - panelH - 20

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
    local Tower = require("Tower")
    local dmg = Tower.CalcTowerDamage(tower)
    local baseDmg = (tower.delivered or 0) * CONFIG.TowerDmgRate
    local spdMult = math.max(0.30, tower.ratio * #GS.towers) * (tower.artAtkSpdMult or 1.0)
    local fireInt = CONFIG.TowerFireInterval / math.max(0.10, spdMult)

    -- 能量标签（标题行右侧）
    if detailEnergyLabel_ then
        detailEnergyLabel_:SetText(string.format("能量: %.0f%%", tower.ratio * 100))
    end

    -- 属性：伤害 + 攻速（单行）
    if detailStatsLabel_ then
        local dmgBonus = dmg - baseDmg
        local dmgBonusStr = ""
        if math.abs(dmgBonus) > 0.1 then
            dmgBonusStr = string.format("(%+.1f) ", dmgBonus)
        end
        detailStatsLabel_:SetText(string.format(
            "伤害: %.1f %s | 攻速: %.2f秒",
            dmg, dmgBonusStr, fireInt
        ))
    end

    -- 回收按钮文字（统一 60%）
    if detailDemolishBtn_ then
        local origCost = Tower.GetTowerOriginalCost(ti)
        local refund = math.floor(origCost * 0.6 + 0.5)
        detailDemolishBtn_:SetText(string.format("回收 +%d 🪙", refund))
    end

    -- 三个配件槽
    for i = 1, 3 do
        local slot = detailSlots_[i]
        if slot then
            local invIdx = tower.slots and tower.slots[i]
            if invIdx then
                local entry = GS.artifactInventory[invIdx]
                if entry then
                    slot:SetItem({
                        id = entry.id,
                        name = entry.def.name,
                        icon = ARTIFACT_ICONS[entry.id] or entry.def.name:sub(1, 4),
                        type = "artifact",
                        invIndex = invIdx,
                    })
                else
                    slot:SetItem(nil)
                end
            else
                slot:SetItem(nil)
            end
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
            M.RefreshTowerDetail()
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
                local dmg = Tower.CalcTowerDamage(tower)
                local spdMult = math.max(0.30, tower.ratio * #GS.towers) * (tower.artAtkSpdMult or 1.0)
                local fireInt = CONFIG.TowerFireInterval / spdMult
                local origCost = Tower.GetTowerOriginalCost(idx)
                local refund = math.floor(origCost * 0.6 + 0.5)
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
    hintLabel_:SetStyle({ fontColor = CLR.muted })
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
        local bg = artifactBg(def)
        local icon = ARTIFACT_ICONS[def.id] or def.name:sub(1, 4) or "?"

        local dsText = ""
        for _, ds in ipairs(def.downsides) do
            if ds.type == "stat_modifier" then
                local pct = math.floor(math.abs(ds.modifier) * 100 + 0.5)
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
            borderRadius = 0, paddingX = 16, paddingY = 16,
            borderWidth = 2, borderColor = bc,
            boxShadow = {{ x = 6, y = 6, blur = 0, color = { 0, 0, 0, 64 } }},
            alignItems = "center",
            opacity = 0,
            children = {
                UI.Label {
                    text = Artifact.RARITY_NAMES[def.rarity] or "?",
                    fontSize = 10, fontColor = { rc[1], rc[2], rc[3], 160 },
                    textAlign = "center",
                },
                UI.Panel {
                    width = 48, height = 48, borderRadius = 0,
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
                    borderRadius = 0, paddingX = 8, paddingY = 3,
                    borderWidth = 1, borderColor = { 255, 60, 60, 60 },
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
        backgroundColor = { 7, 16, 28, 187 },  -- $overlay
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
            local detailProps = { top = tp.top, left = tp.left, width = 230, height = 280 }
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
        -- 优先判断：点击同一座塔 → 关闭面板（放在 isMouseOverUIPanel 之前，防止面板遮住塔时被拦截）
        if towerDetailVisible_ and GS.hoverOnMap and not GS.hoverValid then
            local Tower = require("Tower")
            local idx = Tower.GetTowerAtHover()
            if idx then
                if idx == currentDetailTower_ then
                    M.HideTowerDetail()
                    return
                else
                    M.ShowTowerDetail(idx)
                    return
                end
            end
        end

        if isMouseOverUIPanel() then
            return
        end

        if GS.hoverOnMap and GS.hoverGX == 0 and GS.hoverGZ == 0 then
            M.ToggleUpgradePanel()
            return
        end

        if towerDetailVisible_ then
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
-- 全屏波次公告 (Wave Announcement)
-- ============================================================================

local announcementOverlay_ = nil
local announcementTimer_ = 0
local ANNOUNCEMENT_DURATION = 2.0   -- 显示时长(秒)

-- 摄像头拉近效果
local zoomOriginal_ = nil          -- 公告前的 orthoSize
local zoomTarget_ = nil            -- 拉近目标值
local zoomActive_ = false          -- 是否正在做缩放动画
local ZOOM_IN_AMOUNT = 2.5         -- 拉近幅度
local ZOOM_SPEED = 4.0             -- 缩放 lerp 速度

--- 显示全屏波次公告
--- @param title string 大标题 (如 "敌袭来临")
--- @param subtitle string|nil 副标题 (如 "Wave 1.2「多路夹击」")
--- @param titleColor table|nil 标题颜色 (默认红色警告)
function M.ShowAnnouncement(title, subtitle, titleColor)
    -- 移除旧公告
    M.HideAnnouncement()

    titleColor = titleColor or CLR.danger

    local titleLabel = UI.Label {
        text = title,
        fontSize = 42,
        fontColor = titleColor,
        textAlign = "center",
        opacity = 0,
    }

    local subtitleLabel = nil
    if subtitle and subtitle ~= "" then
        subtitleLabel = UI.Label {
            text = subtitle,
            fontSize = 18,
            fontColor = CLR.secondary,
            textAlign = "center",
            opacity = 0,
        }
    end

    local contentChildren = { titleLabel }
    if subtitleLabel then
        table.insert(contentChildren, subtitleLabel)
    end

    announcementOverlay_ = UI.Panel {
        width = "100%", height = "100%",
        position = "absolute", top = 0, left = 0,
        justifyContent = "center", alignItems = "center",
        pointerEvents = "none",
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 8,
                children = contentChildren,
            },
        },
    }

    -- 标题动画: 放大入场 → 稳定 → 缩小退出
    titleLabel:Animate({
        keyframes = {
            [0]    = { opacity = 0, scale = 0.5 },
            [0.15] = { opacity = 1, scale = 1.05 },
            [0.25] = { scale = 1.0 },
            [0.75] = { opacity = 1, scale = 1.0 },
            [1]    = { opacity = 0, scale = 0.9 },
        },
        duration = ANNOUNCEMENT_DURATION,
        easing = "easeOut",
        fillMode = "forwards",
    })

    -- 副标题动画: 稍延迟淡入
    if subtitleLabel then
        subtitleLabel:Animate({
            keyframes = {
                [0]    = { opacity = 0, translateY = 10 },
                [0.2]  = { opacity = 0, translateY = 10 },
                [0.35] = { opacity = 1, translateY = 0 },
                [0.75] = { opacity = 1 },
                [1]    = { opacity = 0 },
            },
            duration = ANNOUNCEMENT_DURATION,
            easing = "easeOut",
            fillMode = "forwards",
        })
    end

    announcementTimer_ = ANNOUNCEMENT_DURATION

    -- 启动摄像头拉近效果
    if GS.camera and not zoomActive_ then
        zoomOriginal_ = GS.camera.orthoSize
        zoomTarget_ = math.max(CONFIG.ZoomMin, zoomOriginal_ - ZOOM_IN_AMOUNT)
        zoomActive_ = true
    end

    -- 添加到 gameRoot_
    if gameRoot_ then
        gameRoot_:RemoveChild(dragCtx_)
        gameRoot_:AddChild(announcementOverlay_)
        gameRoot_:AddChild(dragCtx_)
    end
end

--- 隐藏公告
function M.HideAnnouncement()
    if announcementOverlay_ and gameRoot_ then
        gameRoot_:RemoveChild(announcementOverlay_)
    end
    announcementOverlay_ = nil
    announcementTimer_ = 0
end

--- 每帧更新公告计时 (由 RefreshUI 调用)
function M.UpdateAnnouncement(dt)
    if announcementTimer_ > 0 then
        announcementTimer_ = announcementTimer_ - dt
        if announcementTimer_ <= 0 then
            M.HideAnnouncement()
        end
    end

    -- 摄像头缩放动画
    if zoomActive_ and GS.camera then
        local progress = 1.0 - math.max(0, announcementTimer_) / ANNOUNCEMENT_DURATION
        local currentTarget
        if progress < 0.6 then
            -- 前60%时间: 拉近
            currentTarget = zoomTarget_
        else
            -- 后40%时间: 恢复原始
            currentTarget = zoomOriginal_
        end
        if currentTarget then
            local cur = GS.camera.orthoSize
            GS.camera.orthoSize = cur + (currentTarget - cur) * math.min(1.0, ZOOM_SPEED * dt)
        end

        -- 公告结束后确保恢复并停止
        if announcementTimer_ <= 0 and zoomOriginal_ then
            GS.camera.orthoSize = zoomOriginal_
            zoomActive_ = false
            zoomOriginal_ = nil
            zoomTarget_ = nil
        end
    end
end

-- ============================================================================
-- GameOver / Victory (全中文 + 淡入动画)
-- ============================================================================

function M.ShowGameOver()
    local titleLabel = UI.Label {
        text = "GAME OVER", fontSize = 36,
        fontColor = CLR.danger,
    }
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 7, 16, 28, 0 },  -- $overlay base
        opacity = 0,
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 14,
                backgroundColor = { 33, 69, 138, 240 },   -- $surface
                borderRadius = 0, paddingX = 44, paddingY = 34,
                borderWidth = 3, borderColor = CLR.panelBorder,
                boxShadow = {{ x = 8, y = 8, blur = 0, color = { 0, 0, 0, 80 } }},
                children = {
                    -- 顶部红色强调条
                    UI.Panel {
                        position = "absolute", top = 0, left = 0, right = 0,
                        height = 4,
                        backgroundColor = CLR.danger,
                    },
                    titleLabel,
                    UI.Panel { width = "80%", height = 1, backgroundColor = CLR.divider },
                    UI.Label {
                        text = string.format("抵达 Wave %d.%d  |  建塔: %d  |  击杀: %d",
                            GS.bigWave, GS.smallWave, #GS.towers, GS.monstersKilled),
                        fontSize = 16, fontColor = CLR.secondary,
                    },
                    UI.Label {
                        text = "能源塔被摧毁",
                        fontSize = 14, fontColor = CLR.warning,
                    },
                    UI.Button {
                        text = "重新开始", variant = "primary",
                        width = 180, height = 50, fontSize = 15,
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

function M.Shutdown()
    UI.Shutdown()
end

return M
