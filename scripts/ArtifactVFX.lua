-- ============================================================================
-- ArtifactVFX.lua — 36 件圣器的粒子特效系统 v2
-- 使用 PolygonParticles PNG 贴图升级所有特效
-- ============================================================================

local M = {}

-- ============================================================================
-- 贴图路径常量
-- ============================================================================
local TEX = {
    sparkle      = "PolygonParticles/Textures/PolygonParticles_Sparkle.png",
    smoke        = "PolygonParticles/Textures/PolygonParticles_Smoke_01.png",
    circle       = "PolygonParticles/Textures/PolygonParticles_Circle_01.png",
    circle2      = "PolygonParticles/Textures/PolygonParticles_Circle_02.png",
    bubble       = "PolygonParticles/Textures/PolygonParticles_Bubble.png",
    bubble2      = "PolygonParticles/Textures/PolygonParticles_Bubble_02.png",
    soft_spot    = "PolygonParticles/Textures/PolygonParticles_Soft_Spot.png",
    soft_dark    = "PolygonParticles/Textures/PolygonParticles_Soft_Spot_Dark.png",
    lightning    = "PolygonParticles/Textures/PolygonParticles_Lightning_02.png",
    fumes        = "PolygonParticles/Textures/PolygonParticles_Fumes_02.png",
    fumes4       = "PolygonParticles/Textures/PolygonParticles_Fumes_04.png",
    ring         = "PolygonParticles/Textures/PolygonParticles_Ring_02.png",
    hexagon      = "PolygonParticles/Textures/PolygonParticles_Hexagon.png",
    wind         = "PolygonParticles/Textures/PolygonParticles_Wind.png",
    swipe        = "PolygonParticles/Textures/PolygonParticles_Swipe_01.png",
    swipe2       = "PolygonParticles/Textures/PolygonParticles_Swipe_02.png",
    shell        = "PolygonParticles/Textures/PolygonParticles_Shell_01.png",
    ritual       = "PolygonParticles/Textures/PolygonParticles_RitualCircle_01.png",
    rainbow      = "PolygonParticles/Textures/PolygonParticles_RainbowCircle.png",
    half_circle  = "PolygonParticles/Textures/PolygonParticles_HalfCircle.png",
    semi_circle  = "PolygonParticles/Textures/PolygonParticles_SemiCircle.png",
    portal       = "PolygonParticles/Textures/PolygonParticles_Portal_Single_Chipped.png",
    ground_break = "PolygonParticles/Textures/PolygonParticles_GroundBreak.png",
    bullet_trail = "PolygonParticles/Textures/PolygonParticles_BulletTrail.png",
    texture01    = "PolygonParticles/Textures/PolygonParticles_Texture_01_A.png",
    wings        = "PolygonParticles/Textures/PolygonParticles_Wings_Grid.png",
}

-- ============================================================================
-- 通用粒子创建辅助（对齐 EnergyTower.lua 可工作模式，向后兼容旧参数）
-- ============================================================================

local function CreateParticleNode(parentNode, cfg)
    local node = parentNode:CreateChild("VFX")
    node.position = cfg.offset or Vector3(0, 0, 0)

    local emitter = node:CreateComponent("ParticleEmitter")
    local effect  = ParticleEffect()   -- 用 () 不用 :new()，GC 行为更安全

    effect:SetEmitterType(cfg.shape or EMITTER_SPHERE)
    local r = cfg.shapeRadius or 0.15
    effect:SetEmitterSize(Vector3(r, r, r))

    effect:SetNumParticles(cfg.maxParticles or 32)
    effect:SetMinEmissionRate(cfg.emitRateMin or cfg.emitRate or 8)
    effect:SetMaxEmissionRate(cfg.emitRateMax or cfg.emitRate or 8)
    effect:SetMinParticleSize(Vector2(cfg.sizeMin or 0.04, cfg.sizeMin or 0.04))
    effect:SetMaxParticleSize(Vector2(cfg.sizeMax or 0.08, cfg.sizeMax or 0.08))
    effect:SetMinTimeToLive(cfg.lifeMin or cfg.life or 0.8)
    effect:SetMaxTimeToLive(cfg.lifeMax or cfg.life or 0.8)
    effect:SetDampingForce(cfg.damping or 0.3)

    -- 方向 + 速度：兼容两种格式
    --   Vector3 格式: velMin/velMax = Vector3（方向+速度合一，检测 .x 字段）
    --   标量格式: dirMin/dirMax = Vector3方向, velMin/velMax = 标量速度
    -- 注意：不使用 type()=="userdata"，该引擎中 Vector3 的 type() 不返回 "userdata"
    local velMinV = cfg.velMin
    local velMaxV = cfg.velMax
    if velMinV ~= nil and type(velMinV) ~= "number" then
        -- Vector3 格式：用 Vector3 同时表示方向和速度大小
        effect:SetMinDirection(velMinV)
        effect:SetMaxDirection(velMaxV or velMinV)
        effect:SetMinVelocity(velMinV:Length())
        effect:SetMaxVelocity((velMaxV or velMinV):Length())
    else
        -- 标量格式或默认（方向单独指定，速度为标量）
        effect:SetMinDirection(cfg.dirMin or Vector3(-0.4, 0.8, -0.4))
        effect:SetMaxDirection(cfg.dirMax or Vector3( 0.4, 2.0,  0.4))
        effect:SetMinVelocity(velMinV or 0.5)
        effect:SetMaxVelocity(velMaxV or 1.5)
    end

    -- 重力（旧用 gravity 字段，转为 SetConstantForce）
    local grav = cfg.gravity or 0
    if grav ~= 0 then
        effect:SetConstantForce(Vector3(0, -grav, 0))
    end

    -- 自旋
    if cfg.rotSpeed then
        effect:SetMinRotationSpeed(cfg.rotSpeed)
        effect:SetMaxRotationSpeed(cfg.rotSpeed * 1.5)
    end

    -- 颜色关键帧（驱动粒子颜色 + Alpha 淡出）
    local colors = cfg.colors or {
        { time = 0.0, color = Color(1, 1, 1, 0.0) },
        { time = 0.1, color = Color(1, 1, 1, 1.0) },
        { time = 1.0, color = Color(1, 1, 1, 0.0) },
    }
    for _, kf in ipairs(colors) do
        effect:AddColorTime(kf.color, kf.time)
    end

    -- 材质
    -- DiffAlpha.xml 使用 alpha testing（丢弃低 alpha 像素），适合硬边贴图
    -- 软边贴图（烟雾/泡泡/软光斑）需要 alpha blending → 跳过贴图改用 PBRNoTextureAlpha
    local SOFT_TEX_PATTERNS = {
        "Smoke", "Fumes", "Soft_Spot", "Bubble",
    }
    local function isSoftTex(texPath)
        if not texPath then return false end
        for _, pat in ipairs(SOFT_TEX_PATTERNS) do
            if texPath:find(pat, 1, true) then return true end
        end
        return false
    end

    local mat = Material:new()
    local dc  = cfg.diffColor or cfg.tint or cfg.matColor or Color(1, 1, 1, 1)
    local useTex = cfg.tex and not isSoftTex(cfg.tex)
    local texObj = useTex and cache:GetResource("Texture2D", cfg.tex)
    if texObj then
        -- 硬边贴图：DiffAlpha alpha testing，不需要 IBL/Zone
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffAlpha.xml"))
        mat:SetTexture(TU_DIFFUSE, texObj)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(dc.r, dc.g, dc.b, 1.0)))
    else
        -- 软边 / 无贴图：PBRNoTextureAlpha alpha blending（需要 Zone，EnergyTower 已验证有效）
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        mat:SetShaderParameter("MatDiffColor",     Variant(Color(dc.r, dc.g, dc.b, 1)))
        local em = cfg.emissive or Color(dc.r * 1.2, dc.g * 1.2, dc.b * 1.2)
        mat:SetShaderParameter("MatEmissiveColor", Variant(em))
        mat:SetShaderParameter("Metallic",  Variant(0.0))
        mat:SetShaderParameter("Roughness", Variant(1.0))
    end
    effect:SetMaterial(mat)

    emitter:SetEffect(effect)
    emitter:SetEmitting(cfg.emitting ~= false)

    return node
end

-- ============================================================================
-- 锚点偏移
-- ============================================================================
local ANCHOR_OFFSETS = {
    muzzle           = Vector3(0, 1.2, 0),
    tower_top        = Vector3(0, 2.0, 0),
    tower_base_ring  = Vector3(0, 0.05, 0),
    tower_body       = Vector3(0, 0.8, 0),
}

-- ============================================================================
-- VFX 工厂表
-- ============================================================================
local VFX_CREATORS = {}

-- ─── 攻击类 ──────────────────────────────────────────────────────────────────

-- 连射模块: 金属弹壳从炮口喷出
VFX_CREATORS["rapid_fire_module"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.shell,
        tint = Color(1.5, 1.5, 0.2, 1),
        additive = true,
        maxParticles = 40, emitRate = 30,
        life = 0.25,
        sizeMin = 0.050, sizeMax = 0.090,
        gravity = 0.8,
        shapeRadius = 0.06,
        rotSpeed = 180,
        velMin = Vector3(-0.5, 0.5, -0.5), velMax = Vector3(0.5, 1.2, 0.5),
        colors = {
            { time = 0.0, color = Color(1.8, 1.5, 0.2, 1.0) },
            { time = 0.5, color = Color(1.2, 0.9, 0.1, 0.7) },
            { time = 1.0, color = Color(0.6, 0.3, 0.0, 0.0) },
        },
    })
end

-- 火种圣器: 火焰烟雾缓慢上升
VFX_CREATORS["fire_seed"] = function(towerNode)
    -- 火焰粒子
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.fumes,
        tint = Color(1.5, 0.6, 0.1, 1),
        maxParticles = 20, emitRate = 10,
        lifeMin = 0.6, lifeMax = 1.2,
        sizeMin = 0.080, sizeMax = 0.180,
        gravity = -0.4,
        shapeRadius = 0.05,
        rotSpeed = 90,
        velMin = Vector3(-0.15, 0.3, -0.15), velMax = Vector3(0.15, 0.7, 0.15),
        colors = {
            { time = 0.0, color = Color(2.0, 0.8, 0.1, 1.0) },
            { time = 0.4, color = Color(1.5, 0.3, 0.0, 0.8) },
            { time = 1.0, color = Color(0.3, 0.1, 0.0, 0.0) },
        },
    })
    -- 火花点
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.sparkle,
        tint = Color(2, 1, 0.1, 1),
        additive = true,
        maxParticles = 10, emitRate = 6,
        life = 0.3,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = 0.3,
        shapeRadius = 0.04,
        velMin = Vector3(-0.3, 0.2, -0.3), velMax = Vector3(0.3, 0.6, 0.3),
        colors = {
            { time = 0.0, color = Color(2.5, 1.5, 0.1, 1.0) },
            { time = 1.0, color = Color(1.0, 0.4, 0.0, 0.0) },
        },
    })
    return node
end

-- 冰晶圣器: 六角冰晶飘散
VFX_CREATORS["ice_crystal"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.hexagon,
        tint = Color(0.6, 0.9, 1.5, 1),
        maxParticles = 30, emitRate = 14,
        lifeMin = 0.8, lifeMax = 1.6,
        sizeMin = 0.050, sizeMax = 0.100,
        gravity = 0.15,
        shapeRadius = 0.1,
        rotSpeed = 120,
        velMin = Vector3(-0.3, -0.1, -0.3), velMax = Vector3(0.3, 0.4, 0.3),
        colors = {
            { time = 0.0, color = Color(0.6, 0.95, 2.0, 1.0) },
            { time = 0.5, color = Color(0.8, 1.0, 2.0, 0.7) },
            { time = 1.0, color = Color(1.0, 1.0, 1.5, 0.0) },
        },
    })
end

-- 腐蚀圣器: 绿色烟雾液滴滴落
VFX_CREATORS["corrosion"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.bubble,
        tint = Color(0.3, 1.2, 0.1, 1),
        maxParticles = 12, emitRate = 5,
        lifeMin = 0.5, lifeMax = 0.9,
        sizeMin = 0.050, sizeMax = 0.100,
        gravity = 1.5,
        shapeRadius = 0.04,
        velMin = Vector3(-0.1, -0.1, -0.1), velMax = Vector3(0.1, 0.3, 0.1),
        colors = {
            { time = 0.0, color = Color(0.4, 1.8, 0.1, 1.0) },
            { time = 0.5, color = Color(0.2, 1.2, 0.0, 0.7) },
            { time = 1.0, color = Color(0.1, 0.5, 0.0, 0.0) },
        },
    })
end

-- 雷鸣圣器: 闪电弧粒子在炮口闪烁
VFX_CREATORS["thunder"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.lightning,
        tint = Color(0.8, 0.3, 2.0, 1),
        additive = true,
        maxParticles = 12, emitRate = 6,
        life = 0.15,
        sizeMin = 0.080, sizeMax = 0.200,
        gravity = 0,
        shapeRadius = 0.12,
        rotSpeed = 360,
        velMin = Vector3(-0.6, -0.4, -0.6), velMax = Vector3(0.6, 0.6, 0.6),
        colors = {
            { time = 0.0, color = Color(0.8, 0.3, 2.5, 1.0) },
            { time = 0.4, color = Color(1.0, 0.6, 2.0, 0.7) },
            { time = 1.0, color = Color(0.5, 0.2, 1.0, 0.0) },
        },
    })
end

-- 裂片圣器: 灰白岩石碎屑弧线掉落
VFX_CREATORS["splinter"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.ground_break,
        tint = Color(0.8, 0.8, 0.8, 1),
        maxParticles = 16, emitRate = 6,
        life = 0.7,
        sizeMin = 0.050, sizeMax = 0.090,
        gravity = 1.0,
        shapeRadius = 0.08,
        rotSpeed = 200,
        velMin = Vector3(-0.5, 0.3, -0.5), velMax = Vector3(0.5, 0.7, 0.5),
        colors = {
            { time = 0.0, color = Color(1.0, 0.95, 0.85, 1.0) },
            { time = 0.5, color = Color(0.8, 0.75, 0.65, 0.6) },
            { time = 1.0, color = Color(0.5, 0.45, 0.40, 0.0) },
        },
    })
end

-- 穿透弹芯: 银白色子弹拖尾从炮口高速喷出
VFX_CREATORS["piercing_core"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.bullet_trail,
        tint = Color(1.5, 1.5, 2.0, 1),
        additive = true,
        maxParticles = 24, emitRate = 14,
        life = 0.25,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = 0,
        shapeRadius = 0.03,
        velMin = Vector3(-0.1, 1.0, -0.1), velMax = Vector3(0.1, 2.5, 0.1),
        colors = {
            { time = 0.0, color = Color(1.5, 1.5, 2.5, 1.0) },
            { time = 0.5, color = Color(1.0, 1.0, 2.0, 0.5) },
            { time = 1.0, color = Color(0.8, 0.8, 1.5, 0.0) },
        },
    })
end

-- 狙击改装: 红色激光瞄准粒子
VFX_CREATORS["sniper_mod"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.soft_spot,
        tint = Color(2, 0.1, 0.1, 1),
        additive = true,
        maxParticles = 6, emitRate = 2,
        lifeMin = 1.2, lifeMax = 2.0,
        sizeMin = 0.040, sizeMax = 0.070,
        gravity = 0,
        shapeRadius = 0.02,
        velMin = Vector3(-0.03, 0.3, -0.03), velMax = Vector3(0.03, 0.8, 0.03),
        colors = {
            { time = 0.0, color = Color(2.0, 0.1, 0.1, 0.9) },
            { time = 0.5, color = Color(1.5, 0.1, 0.1, 0.5) },
            { time = 1.0, color = Color(1.0, 0.1, 0.1, 0.0) },
        },
    })
end

-- 棱镜圣器: 七彩环形光斑
VFX_CREATORS["prism"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.rainbow,
        additive = true,
        maxParticles = 20, emitRate = 8,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.080, sizeMax = 0.140,
        gravity = 0,
        shapeRadius = 0.08,
        rotSpeed = 60,
        velMin = Vector3(-0.1, -0.1, -0.1), velMax = Vector3(0.1, 0.1, 0.1),
        colors = {
            { time = 0.0, color = Color(1.5, 1.5, 1.5, 1.0) },
            { time = 0.5, color = Color(1.5, 1.5, 1.5, 0.7) },
            { time = 1.0, color = Color(1.5, 1.5, 1.5, 0.0) },
        },
    })
    -- 附加：七色碎片闪烁
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.sparkle,
        additive = true,
        maxParticles = 12, emitRate = 6,
        life = 0.8,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = 0,
        shapeRadius = 0.12,
        rotSpeed = 180,
        velMin = Vector3(-0.2, -0.1, -0.2), velMax = Vector3(0.2, 0.1, 0.2),
        colors = {
            { time = 0.00, color = Color(2.5, 0.2, 0.2, 1.0) },
            { time = 0.25, color = Color(0.2, 2.5, 0.2, 1.0) },
            { time = 0.50, color = Color(0.2, 0.2, 2.5, 1.0) },
            { time = 0.75, color = Color(2.5, 2.0, 0.2, 1.0) },
            { time = 1.00, color = Color(2.0, 0.2, 2.0, 0.0) },
        },
    })
    return node
end

-- 高爆圣器: 爆炸烟雾瞬闪
VFX_CREATORS["high_explosive"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.fumes4,
        tint = Color(1.5, 0.6, 0.1, 1),
        maxParticles = 18, emitRate = 8,
        lifeMin = 0.2, lifeMax = 0.4,
        sizeMin = 0.100, sizeMax = 0.200,
        gravity = 0,
        shapeRadius = 0.08,
        rotSpeed = 120,
        velMin = Vector3(-0.8, -0.3, -0.8), velMax = Vector3(0.8, 0.8, 0.8),
        colors = {
            { time = 0.0, color = Color(2.5, 1.5, 0.1, 1.0) },
            { time = 0.3, color = Color(2.0, 0.8, 0.0, 0.8) },
            { time = 1.0, color = Color(0.4, 0.2, 0.1, 0.0) },
        },
    })
    -- 火花
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.sparkle,
        additive = true,
        maxParticles = 14, emitRate = 8,
        life = 0.2,
        sizeMin = 0.030, sizeMax = 0.070,
        gravity = 0.3,
        shapeRadius = 0.1,
        velMin = Vector3(-1.0, -0.5, -1.0), velMax = Vector3(1.0, 1.0, 1.0),
        colors = {
            { time = 0.0, color = Color(3.0, 2.5, 0.5, 1.0) },
            { time = 1.0, color = Color(1.0, 0.3, 0.0, 0.0) },
        },
    })
    return node
end

-- 暴击装置: 金色四芒星闪烁
VFX_CREATORS["crit_device"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = Vector3(0, 1.3, 0),
        tex = TEX.sparkle,
        tint = Color(2.5, 2.0, 0.1, 1),
        additive = true,
        maxParticles = 10, emitRate = 4,
        lifeMin = 0.8, lifeMax = 1.5,
        sizeMin = 0.080, sizeMax = 0.160,
        gravity = 0,
        shapeRadius = 0.05,
        rotSpeed = 90,
        velMin = Vector3(-0.04, 0.0, -0.04), velMax = Vector3(0.04, 0.1, 0.04),
        colors = {
            { time = 0.0, color = Color(3.0, 2.5, 0.2, 1.0) },
            { time = 0.4, color = Color(3.0, 2.5, 0.1, 1.0) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
end

-- 共振触发: 蓝白色环形脉冲
VFX_CREATORS["resonance_trigger"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.ring,
        tint = Color(0.5, 0.8, 2.0, 1),
        additive = true,
        maxParticles = 30, emitRate = 15,
        lifeMin = 0.6, lifeMax = 1.0,
        sizeMin = 0.080, sizeMax = 0.140,
        gravity = 0,
        shapeRadius = 0.15,
        rotSpeed = 60,
        velMin = Vector3(-0.3, -0.1, -0.3), velMax = Vector3(0.3, 0.1, 0.3),
        colors = {
            { time = 0.0, color = Color(0.5, 0.8, 2.5, 0.9) },
            { time = 0.5, color = Color(0.7, 1.0, 2.5, 0.5) },
            { time = 1.0, color = Color(1.0, 1.0, 2.0, 0.0) },
        },
    })
end

-- 元素核心: 4色圆圈环绕旋转
VFX_CREATORS["elemental_core"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = Vector3(0, 1.3, 0),
        tex = TEX.circle,
        additive = true,
        maxParticles = 16, emitRate = 8,
        lifeMin = 1.2, lifeMax = 2.0,
        sizeMin = 0.060, sizeMax = 0.100,
        gravity = 0,
        shapeRadius = 0.1,
        rotSpeed = 180,
        velMin = Vector3(-0.15, -0.1, -0.15), velMax = Vector3(0.15, 0.1, 0.15),
        colors = {
            { time = 0.0,  color = Color(2.5, 0.5, 0.1, 1.0) },
            { time = 0.33, color = Color(0.2, 0.5, 2.5, 1.0) },
            { time = 0.67, color = Color(0.8, 0.1, 2.5, 1.0) },
            { time = 1.0,  color = Color(0.2, 2.0, 0.2, 0.0) },
        },
    })
end

-- ─── 增益类 ──────────────────────────────────────────────────────────────────

-- 攻速光环: 黄色风刃粒子绕塔基旋转
VFX_CREATORS["aura_attack_speed"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.wind,
        tint = Color(2.0, 2.0, 0.2, 1),
        additive = true,
        maxParticles = 36, emitRate = 18,
        lifeMin = 0.8, lifeMax = 1.2,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = 0,
        shapeRadius = 5.0,
        rotSpeed = 120,
        velMin = Vector3(-0.15, 0.05, -0.15), velMax = Vector3(0.15, 0.25, 0.15),
        colors = {
            { time = 0.0, color = Color(2.5, 2.5, 0.2, 1.0) },
            { time = 0.5, color = Color(2.0, 2.0, 0.1, 0.5) },
            { time = 1.0, color = Color(1.5, 1.5, 0.0, 0.0) },
        },
    })
end

-- 伤害光环: 深红色烟雾逆时针涌动
VFX_CREATORS["aura_damage"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.smoke,
        tint = Color(2.0, 0.1, 0.1, 1),
        maxParticles = 24, emitRate = 12,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.100, sizeMax = 0.180,
        gravity = -0.2,
        shapeRadius = 5.0,
        rotSpeed = 60,
        velMin = Vector3(-0.08, 0.02, -0.08), velMax = Vector3(0.08, 0.15, 0.08),
        colors = {
            { time = 0.0, color = Color(2.5, 0.1, 0.1, 0.9) },
            { time = 0.5, color = Color(1.8, 0.05, 0.05, 0.5) },
            { time = 1.0, color = Color(0.8, 0.0, 0.0, 0.0) },
        },
    })
end

-- 射程光环: 亮绿色圆圈向外扩散
VFX_CREATORS["aura_range"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.circle2,
        tint = Color(0.2, 2.5, 0.2, 1),
        additive = true,
        maxParticles = 48, emitRate = 24,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = 0,
        shapeRadius = 0.3,
        rotSpeed = 90,
        velMin = Vector3(-3.0, 0.0, -3.0), velMax = Vector3(3.0, 0.05, 3.0),
        colors = {
            { time = 0.0, color = Color(0.2, 3.0, 0.2, 1.0) },
            { time = 0.6, color = Color(0.1, 2.0, 0.1, 0.5) },
            { time = 1.0, color = Color(0.0, 1.0, 0.0, 0.0) },
        },
    })
end

-- 暴击光环: 金色星形粒子随机闪现
VFX_CREATORS["aura_crit"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.sparkle,
        tint = Color(3.0, 2.5, 0.1, 1),
        additive = true,
        maxParticles = 16, emitRate = 8,
        lifeMin = 0.2, lifeMax = 0.4,
        sizeMin = 0.080, sizeMax = 0.140,
        gravity = 0,
        shapeRadius = 5.0,
        rotSpeed = 180,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.15, 0.05),
        colors = {
            { time = 0.0, color = Color(3.5, 3.0, 0.2, 1.0) },
            { time = 0.5, color = Color(3.0, 2.5, 0.1, 0.8) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
end

-- 远程压缩: 紫色半圆弧粒子沿塔体下沉
VFX_CREATORS["range_compression"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.semi_circle,
        tint = Color(0.6, 0.1, 2.0, 1),
        additive = true,
        maxParticles = 18, emitRate = 8,
        lifeMin = 0.8, lifeMax = 1.5,
        sizeMin = 0.050, sizeMax = 0.090,
        gravity = 0.5,
        shapeRadius = 0.12,
        rotSpeed = 150,
        velMin = Vector3(-0.15, -0.6, -0.15), velMax = Vector3(0.15, -0.2, 0.15),
        colors = {
            { time = 0.0, color = Color(0.6, 0.1, 2.5, 0.8) },
            { time = 0.5, color = Color(0.8, 0.2, 2.5, 0.5) },
            { time = 1.0, color = Color(0.3, 0.0, 1.5, 0.0) },
        },
    })
end

-- 借力圣器: 金色风羽从远处汇聚塔顶
VFX_CREATORS["power_borrow"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.swipe,
        tint = Color(2.5, 2.0, 0.1, 1),
        additive = true,
        maxParticles = 20, emitRate = 10,
        lifeMin = 0.8, lifeMax = 1.4,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = -0.5,
        shapeRadius = 4.0,
        rotSpeed = 90,
        velMin = Vector3(-3.0, -0.5, -3.0), velMax = Vector3(3.0, 0.2, 3.0),
        colors = {
            { time = 0.0, color = Color(3.0, 2.5, 0.1, 0.9) },
            { time = 0.5, color = Color(2.5, 2.0, 0.1, 0.5) },
            { time = 1.0, color = Color(2.0, 1.5, 0.0, 0.0) },
        },
    })
end

-- 总管塔: 金色软光斑悬浮缓慢旋转
VFX_CREATORS["master_tower"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.soft_spot,
        tint = Color(3.0, 2.5, 0.2, 1),
        additive = true,
        maxParticles = 8, emitRate = 3,
        lifeMin = 2.0, lifeMax = 3.0,
        sizeMin = 0.100, sizeMax = 0.180,
        gravity = 0,
        shapeRadius = 0.05,
        velMin = Vector3(-0.04, 0.0, -0.04), velMax = Vector3(0.04, 0.08, 0.04),
        colors = {
            { time = 0.0, color = Color(3.5, 3.0, 0.3, 1.0) },
            { time = 0.5, color = Color(3.0, 2.5, 0.2, 0.8) },
            { time = 1.0, color = Color(2.0, 1.5, 0.0, 0.0) },
        },
    })
end

-- 防御阵地塔: 蓝灰烟雾上升 + 地面护盾圆圈
VFX_CREATORS["defense_garrison"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.smoke,
        tint = Color(0.4, 0.5, 1.0, 1),
        maxParticles = 20, emitRate = 10,
        lifeMin = 1.2, lifeMax = 2.0,
        sizeMin = 0.080, sizeMax = 0.160,
        gravity = -0.4,
        shapeRadius = 0.18,
        rotSpeed = 45,
        velMin = Vector3(-0.1, 0.3, -0.1), velMax = Vector3(0.1, 0.7, 0.1),
        colors = {
            { time = 0.0, color = Color(0.4, 0.5, 1.2, 0.8) },
            { time = 0.5, color = Color(0.5, 0.6, 1.2, 0.5) },
            { time = 1.0, color = Color(0.3, 0.4, 0.8, 0.0) },
        },
    })
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.circle,
        tint = Color(0.3, 0.4, 2.0, 1),
        additive = true,
        maxParticles = 24, emitRate = 12,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.060, sizeMax = 0.100,
        gravity = 0,
        shapeRadius = 5.0,
        velMin = Vector3(-0.1, 0.0, -0.1), velMax = Vector3(0.1, 0.06, 0.1),
        colors = {
            { time = 0.0, color = Color(0.3, 0.4, 2.5, 0.9) },
            { time = 0.5, color = Color(0.2, 0.3, 2.0, 0.5) },
            { time = 1.0, color = Color(0.1, 0.2, 1.5, 0.0) },
        },
    })
    return node
end

-- 网络圣器: 蓝色气泡双向扩散
VFX_CREATORS["network"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.bubble2,
        tint = Color(0.3, 0.8, 2.0, 1),
        maxParticles = 28, emitRate = 14,
        lifeMin = 0.8, lifeMax = 1.4,
        sizeMin = 0.050, sizeMax = 0.090,
        gravity = 0,
        shapeRadius = 0.5,
        velMin = Vector3(-1.8, -0.3, -1.8), velMax = Vector3(1.8, 0.3, 1.8),
        colors = {
            { time = 0.0, color = Color(0.3, 0.8, 2.5, 0.9) },
            { time = 0.5, color = Color(0.5, 1.0, 3.0, 0.5) },
            { time = 1.0, color = Color(0.8, 1.0, 2.0, 0.0) },
        },
    })
end

-- 吞噬线: 暗紫烟雾从四周涌入
VFX_CREATORS["devour_line"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.fumes4,
        tint = Color(0.4, 0.0, 0.6, 1),
        maxParticles = 20, emitRate = 12,
        lifeMin = 0.8, lifeMax = 1.4,
        sizeMin = 0.080, sizeMax = 0.160,
        gravity = -0.3,
        shapeRadius = 0.2,
        rotSpeed = 60,
        velMin = Vector3(-0.2, 0.1, -0.2), velMax = Vector3(0.2, 0.5, 0.2),
        colors = {
            { time = 0.0, color = Color(0.5, 0.0, 0.8, 0.9) },
            { time = 0.5, color = Color(0.3, 0.0, 0.5, 0.6) },
            { time = 1.0, color = Color(0.05, 0.0, 0.1, 0.0) },
        },
    })
end

-- 冰晶导管: 六角冰晶沿链路穿梭
VFX_CREATORS["ice_crystal_conduit"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.hexagon,
        tint = Color(0.5, 0.9, 2.0, 1),
        maxParticles = 22, emitRate = 10,
        lifeMin = 1.0, lifeMax = 1.8,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = 0,
        shapeRadius = 0.3,
        rotSpeed = 150,
        velMin = Vector3(-0.6, -0.2, -0.6), velMax = Vector3(0.6, 0.2, 0.6),
        colors = {
            { time = 0.0, color = Color(0.5, 0.9, 2.5, 1.0) },
            { time = 0.5, color = Color(0.7, 1.0, 3.0, 0.6) },
            { time = 1.0, color = Color(0.8, 1.0, 2.0, 0.0) },
        },
    })
end

-- 共鸣放大器: 粉色半圆环向外爆发
VFX_CREATORS["resonance_amplifier"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.half_circle,
        tint = Color(2.5, 0.3, 1.2, 1),
        additive = true,
        maxParticles = 32, emitRate = 16,
        lifeMin = 1.0, lifeMax = 1.8,
        sizeMin = 0.080, sizeMax = 0.140,
        gravity = 0,
        shapeRadius = 0.3,
        rotSpeed = 120,
        velMin = Vector3(-3.0, 0.0, -3.0), velMax = Vector3(3.0, 0.1, 3.0),
        colors = {
            { time = 0.0, color = Color(3.0, 0.3, 1.5, 0.9) },
            { time = 0.5, color = Color(2.5, 0.2, 1.0, 0.5) },
            { time = 1.0, color = Color(1.5, 0.1, 0.6, 0.0) },
        },
    })
end

-- 元素反应: 4色漩涡缭绕塔顶
VFX_CREATORS["elemental_reaction"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = Vector3(0, 2.1, 0),
        tex = TEX.swipe2,
        additive = true,
        maxParticles = 28, emitRate = 12,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = 0,
        shapeRadius = 0.1,
        rotSpeed = 200,
        velMin = Vector3(-0.2, -0.1, -0.2), velMax = Vector3(0.2, 0.1, 0.2),
        colors = {
            { time = 0.0,  color = Color(2.5, 0.5, 0.1, 1.0) },
            { time = 0.25, color = Color(0.2, 0.5, 2.5, 1.0) },
            { time = 0.50, color = Color(1.0, 0.1, 2.5, 1.0) },
            { time = 0.75, color = Color(0.2, 2.0, 0.2, 1.0) },
            { time = 1.00, color = Color(1.0, 0.3, 0.5, 0.0) },
        },
    })
end

-- 过载继电器: 橙红高压电弧迸射
VFX_CREATORS["overload_relay"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.lightning,
        tint = Color(2.5, 0.5, 0.1, 1),
        additive = true,
        maxParticles = 16, emitRate = 8,
        lifeMin = 0.2, lifeMax = 0.5,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = 0,
        shapeRadius = 0.15,
        rotSpeed = 360,
        velMin = Vector3(-1.5, -1.0, -1.5), velMax = Vector3(1.5, 1.5, 1.5),
        colors = {
            { time = 0.0, color = Color(3.0, 0.6, 0.1, 1.0) },
            { time = 0.4, color = Color(2.5, 0.3, 0.0, 0.7) },
            { time = 1.0, color = Color(1.0, 0.1, 0.0, 0.0) },
        },
    })
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.sparkle,
        additive = true,
        maxParticles = 12, emitRate = 8,
        life = 0.15,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = 0.3,
        shapeRadius = 0.1,
        velMin = Vector3(-0.8, -0.5, -0.8), velMax = Vector3(0.8, 0.8, 0.8),
        colors = {
            { time = 0.0, color = Color(3.5, 1.5, 0.2, 1.0) },
            { time = 1.0, color = Color(1.0, 0.3, 0.0, 0.0) },
        },
    })
    return node
end

-- 注能弹药: 亮黄弹药环绕塔顶
VFX_CREATORS["energy_ammo"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.circle,
        tint = Color(2.5, 2.0, 0.2, 1),
        additive = true,
        maxParticles = 16, emitRate = 8,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.060, sizeMax = 0.110,
        gravity = 0,
        shapeRadius = 0.08,
        rotSpeed = 90,
        velMin = Vector3(-0.1, -0.05, -0.1), velMax = Vector3(0.1, 0.05, 0.1),
        colors = {
            { time = 0.0, color = Color(3.0, 2.5, 0.2, 1.0) },
            { time = 0.5, color = Color(2.5, 2.0, 0.1, 0.8) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
end

-- ─── 收集类 ──────────────────────────────────────────────────────────────────

-- 磁币圣器: 金色漩涡向外撒出
VFX_CREATORS["coin_magnet"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.swipe,
        tint = Color(2.5, 1.8, 0.1, 1),
        additive = true,
        maxParticles = 32, emitRate = 16,
        lifeMin = 1.0, lifeMax = 1.8,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = 0.4,
        shapeRadius = 0.1,
        rotSpeed = 120,
        velMin = Vector3(-3.5, 0.2, -3.5), velMax = Vector3(3.5, 0.8, 3.5),
        colors = {
            { time = 0.0, color = Color(3.0, 2.2, 0.1, 1.0) },
            { time = 0.5, color = Color(2.5, 1.8, 0.0, 0.6) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
end

-- 金矿炼化: 金色软光斑悬浮塔顶
VFX_CREATORS["gold_refinery"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.soft_spot,
        tint = Color(2.5, 1.8, 0.1, 1),
        additive = true,
        maxParticles = 10, emitRate = 4,
        lifeMin = 1.0, lifeMax = 1.8,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = -0.2,
        shapeRadius = 0.08,
        velMin = Vector3(-0.3, 0.05, -0.3), velMax = Vector3(0.3, 0.35, 0.3),
        colors = {
            { time = 0.0, color = Color(3.0, 2.2, 0.1, 1.0) },
            { time = 0.5, color = Color(2.5, 1.8, 0.0, 0.6) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
end

-- 充能矩阵: 蓝色方形闪烁缓慢旋转
VFX_CREATORS["energy_matrix"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.portal,
        tint = Color(0.4, 0.8, 2.5, 1),
        additive = true,
        maxParticles = 10, emitRate = 4,
        lifeMin = 3.0, lifeMax = 5.0,
        sizeMin = 0.080, sizeMax = 0.120,
        gravity = 0,
        shapeRadius = 0.06,
        rotSpeed = 60,
        velMin = Vector3(-0.04, 0.0, -0.04), velMax = Vector3(0.04, 0.04, 0.04),
        colors = {
            { time = 0.0, color = Color(0.4, 0.8, 3.0, 1.0) },
            { time = 0.5, color = Color(0.5, 1.0, 3.5, 0.8) },
            { time = 1.0, color = Color(0.3, 0.6, 2.0, 0.0) },
        },
    })
end

-- 蓄力击: 蓝色能量在塔顶积聚放大
VFX_CREATORS["charged_hit"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.circle,
        tint = Color(0.3, 0.6, 3.0, 1),
        additive = true,
        maxParticles = 14, emitRate = 5,
        lifeMin = 1.2, lifeMax = 2.0,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = -0.3,
        shapeRadius = 0.08,
        rotSpeed = 90,
        velMin = Vector3(-0.1, 0.1, -0.1), velMax = Vector3(0.1, 0.5, 0.1),
        colors = {
            { time = 0.0, color = Color(0.3, 0.6, 3.5, 1.0) },
            { time = 0.5, color = Color(0.5, 0.8, 3.0, 0.7) },
            { time = 1.0, color = Color(0.4, 0.6, 2.0, 0.0) },
        },
    })
end

-- 凝聚塔: 蓝色粒子从塔体飘升聚顶
VFX_CREATORS["condenser"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.bubble,
        tint = Color(0.3, 0.6, 3.0, 1),
        maxParticles = 28, emitRate = 14,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = -1.0,
        shapeRadius = 0.14,
        velMin = Vector3(-0.1, 0.3, -0.1), velMax = Vector3(0.1, 0.9, 0.1),
        colors = {
            { time = 0.0, color = Color(0.3, 0.6, 3.5, 1.0) },
            { time = 0.5, color = Color(0.4, 0.8, 3.0, 0.7) },
            { time = 1.0, color = Color(0.5, 1.0, 2.0, 0.0) },
        },
    })
end

-- 资源富集: 棕黄土壤颗粒缓慢流向塔基
VFX_CREATORS["resource_enrichment"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.texture01,
        tint = Color(1.2, 0.8, 0.2, 1),
        maxParticles = 18, emitRate = 8,
        lifeMin = 1.2, lifeMax = 2.0,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = 0.2,
        shapeRadius = 1.5,
        rotSpeed = 60,
        velMin = Vector3(-0.5, 0.0, -0.5), velMax = Vector3(0.5, 0.3, 0.5),
        colors = {
            { time = 0.0, color = Color(1.5, 1.0, 0.2, 1.0) },
            { time = 0.5, color = Color(1.0, 0.7, 0.1, 0.6) },
            { time = 1.0, color = Color(0.7, 0.4, 0.0, 0.0) },
        },
    })
end

-- 复利圣器: 金色气泡螺旋上升
VFX_CREATORS["compound_interest"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.bubble,
        tint = Color(2.5, 1.8, 0.1, 1),
        maxParticles = 14, emitRate = 5,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.050, sizeMax = 0.090,
        gravity = -0.5,
        shapeRadius = 0.07,
        velMin = Vector3(-0.2, 0.4, -0.2), velMax = Vector3(0.2, 1.0, 0.2),
        colors = {
            { time = 0.0, color = Color(3.0, 2.2, 0.1, 1.0) },
            { time = 0.5, color = Color(2.5, 1.8, 0.0, 0.7) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
end

-- 反馈线圈: 紫色环脉冲 + 金光柱
VFX_CREATORS["feedback_coil"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.ring,
        tint = Color(0.7, 0.1, 2.5, 1),
        additive = true,
        maxParticles = 24, emitRate = 12,
        lifeMin = 0.8, lifeMax = 1.4,
        sizeMin = 0.080, sizeMax = 0.140,
        gravity = 0,
        shapeRadius = 1.5,
        rotSpeed = 90,
        velMin = Vector3(-1.5, 0.0, -1.5), velMax = Vector3(1.5, 0.1, 1.5),
        colors = {
            { time = 0.0, color = Color(0.8, 0.1, 3.0, 1.0) },
            { time = 0.5, color = Color(0.5, 0.0, 2.5, 0.6) },
            { time = 1.0, color = Color(0.3, 0.0, 1.5, 0.0) },
        },
    })
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.soft_spot,
        tint = Color(2.5, 1.8, 0.1, 1),
        additive = true,
        maxParticles = 14, emitRate = 7,
        lifeMin = 1.2, lifeMax = 2.0,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = -0.7,
        shapeRadius = 0.05,
        velMin = Vector3(-0.1, 0.6, -0.1), velMax = Vector3(0.1, 1.8, 0.1),
        colors = {
            { time = 0.0, color = Color(3.0, 2.2, 0.1, 1.0) },
            { time = 0.5, color = Color(2.5, 1.8, 0.0, 0.6) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
    return node
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 圣器装备时调用
function M.OnEquip(tower, artifactId)
    if not tower or not tower.node then return end
    M.OnUnequip(tower, artifactId)

    local creator = VFX_CREATORS[artifactId]
    if not creator then
        creator = function(n)
            return CreateParticleNode(n, {
                offset = ANCHOR_OFFSETS.tower_top,
                tex = TEX.sparkle,
                tint = Color(1, 1, 1, 1),
                maxParticles = 8, emitRate = 4, life = 1.0,
                sizeMin = 0.040, sizeMax = 0.070, gravity = -0.3,
                shapeRadius = 0.1,
                velMin = Vector3(-0.2, 0.2, -0.2), velMax = Vector3(0.2, 0.6, 0.2),
                colors = {
                    { time = 0.0, color = Color(1, 1, 1, 0.8) },
                    { time = 1.0, color = Color(1, 1, 1, 0.0) },
                },
            })
        end
    end

    local ok, vfxNode = pcall(creator, tower.node)
    if ok and vfxNode then
        if not tower.vfxNodes then tower.vfxNodes = {} end
        tower.vfxNodes[artifactId] = vfxNode
        print(string.format("[ArtifactVFX] OnEquip: %s → tower(%d,%d)", artifactId, tower.gx, tower.gz))
    else
        print(string.format("[ArtifactVFX] ERROR creating VFX for %s: %s", artifactId, tostring(vfxNode)))
    end
end

--- 圣器卸除时调用
function M.OnUnequip(tower, artifactId)
    if not tower or not tower.vfxNodes then return end
    local vfxNode = tower.vfxNodes[artifactId]
    if vfxNode then
        vfxNode:Remove()
        tower.vfxNodes[artifactId] = nil
        print(string.format("[ArtifactVFX] OnUnequip: %s → tower(%d,%d)", artifactId, tower.gx or 0, tower.gz or 0))
    end
end

--- 移除塔上所有圣器 VFX
function M.OnTowerRemoved(tower)
    if not tower or not tower.vfxNodes then return end
    for id, node in pairs(tower.vfxNodes) do
        if node then node:Remove() end
    end
    tower.vfxNodes = {}
end

--- 预览模式专用：直接在指定节点创建 VFX（不绑定塔）
--- @param parentNode Node
--- @param artifactId string
--- @return Node|nil
function M.CreatePreviewVFX(parentNode, artifactId)
    local creator = VFX_CREATORS[artifactId]
    if not creator then return nil end
    local ok, node = pcall(creator, parentNode)
    if ok then return node end
    return nil
end

--- 获取所有圣器 ID 列表
function M.GetAllArtifactIds()
    local ids = {}
    for id in pairs(VFX_CREATORS) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end

--- 每帧更新
function M.Update(dt)
    for _, tower in ipairs(require("Config").GS.towers) do
        if tower.vfxNodes and tower.artPassiveEnergyRate and tower.artPassiveEnergyRate > 0 then
            tower.artPassiveEnergyTimer = (tower.artPassiveEnergyTimer or 0) + dt
            if tower.artPassiveEnergyTimer >= 1.0 / tower.artPassiveEnergyRate then
                tower.artPassiveEnergyTimer = tower.artPassiveEnergyTimer - 1.0 / tower.artPassiveEnergyRate
                require("Config").GS.activeEnergy = math.min(
                    require("Config").GS.activeEnergy + 1,
                    require("Config").CONFIG.MaxActiveEnergy or 100
                )
            end
        end
    end
end

return M
