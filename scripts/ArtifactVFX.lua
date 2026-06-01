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
    -- ── Particle FX 1 新贴图 ─────────────────────────────────────────────────
    pfx_fire1        = "Textures/ParticleFX1/Fire_1.png",
    pfx_fire2        = "Textures/ParticleFX1/Fire2.png",
    pfx_fire3        = "Textures/ParticleFX1/Fire_3.png",
    pfx_fire_sparks  = "Textures/ParticleFX1/Fire_Sparks.png",
    pfx_bonfire      = "Textures/ParticleFX1/Bonfire.png",
    pfx_fire_meteor  = "Textures/ParticleFX1/Fire_Meteor.png",
    pfx_smoke1       = "Textures/ParticleFX1/Smoke.png",
    pfx_smoke2       = "Textures/ParticleFX1/Smoke2.png",
    pfx_smoke3       = "Textures/ParticleFX1/Smoke3.png",
    pfx_smoke4       = "Textures/ParticleFX1/Smoke4.png",
    pfx_smoke_simple = "Textures/ParticleFX1/Smoke_Simple_2.png",
    pfx_lightning    = "Textures/ParticleFX1/Lightning_Bolt.png",
    pfx_eletric_a    = "Textures/ParticleFX1/Eletric_A.png",
    pfx_eletric_aura = "Textures/ParticleFX1/Eletric_Aura.png",
    pfx_eletric_exp  = "Textures/ParticleFX1/Eletric_Expansion.png",
    pfx_dark_aura    = "Textures/ParticleFX1/Dark_Aura.png",
    pfx_dark_ritual  = "Textures/ParticleFX1/Dark_Ritual.png",
    pfx_dark_swirl   = "Textures/ParticleFX1/Dark_Swirl.png",
    pfx_holy_aura    = "Textures/ParticleFX1/Holy_Light_Aura.png",
    pfx_holy_burst   = "Textures/ParticleFX1/Holy_Burst_Flame.png",
    pfx_poison       = "Textures/ParticleFX1/Poison_Cloud.png",
    pfx_toxic        = "Textures/ParticleFX1/Toxic_Fireball.png",
    pfx_icicle       = "Textures/ParticleFX1/Icicle_Pike.png",
    pfx_sparks       = "Textures/ParticleFX1/Sparks.png",
    pfx_sparky_flame = "Textures/ParticleFX1/Sparky_Flame.png",
    pfx_star_shine   = "Textures/ParticleFX1/Star_Shine.png",
    pfx_lifestream   = "Textures/ParticleFX1/Lifestream_Particle.png",
    pfx_rock_break   = "Textures/ParticleFX1/Rock_Break.png",
    pfx_splash       = "Textures/ParticleFX1/Splash.png",
    pfx_regen        = "Textures/ParticleFX1/Regen.png",
    pfx_vertical_laser = "Textures/ParticleFX1/Vertical_Laser.png",
    pfx_tail         = "Textures/ParticleFX1/Tail.png",
    pfx_gravity      = "Textures/ParticleFX1/Gravity.png",
    pfx_light_spark  = "Textures/ParticleFX1/Light_Spark.png",
    pfx_bubble_shield= "Textures/ParticleFX1/Bubble_Shield.png",
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
    if cfg.additive and texObj then
        -- 加法混合 + 贴图：DiffAdd → 粒子叠加发光（HDR 颜色值越高越亮）
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffAdd.xml"))
        mat:SetTexture(TU_DIFFUSE, texObj)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(dc.r, dc.g, dc.b, 1.0)))
    elseif cfg.additive then
        -- 加法混合 + 无贴图：使用 DiffAdd + 白色圆点贴图模拟发光软粒子
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffAdd.xml"))
        local fallbackTex = cache:GetResource("Texture2D", "Textures/ParticleFX1/Star_Shine.png")
        if fallbackTex then
            mat:SetTexture(TU_DIFFUSE, fallbackTex)
        end
        mat:SetShaderParameter("MatDiffColor", Variant(Color(dc.r, dc.g, dc.b, 1.0)))
    elseif texObj then
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
-- 弹道型圣器集合（这些圣器的特效在子弹拖尾和命中爆炸上，不挂在塔上）
-- ============================================================================
local BULLET_TYPE_ARTIFACTS = {
    rapid_fire_module = true, fire_seed       = true, ice_crystal  = true,
    corrosion         = true, thunder         = true, splinter     = true,
    piercing_core     = true, sniper_mod      = true, high_explosive = true,
    crit_device       = true, elemental_core  = true, overload_relay = true,
    energy_ammo       = true, charged_hit     = true, feedback_coil  = true,
}

-- ============================================================================
-- VFX 工厂表
-- ============================================================================
local VFX_CREATORS = {}

-- ─── 攻击类 ──────────────────────────────────────────────────────────────────

-- 连射模块: 炮口火花 + 飞溅粒子
VFX_CREATORS["rapid_fire_module"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_sparks,
        tint = Color(2.5, 1.8, 0.2, 1),
        additive = true,
        maxParticles = 30, emitRate = 24,
        life = 0.20,
        sizeMin = 0.040, sizeMax = 0.080,
        gravity = 0.5,
        shapeRadius = 0.05,
        rotSpeed = 240,
        velMin = Vector3(-0.8, 0.3, -0.8), velMax = Vector3(0.8, 1.5, 0.8),
        colors = {
            { time = 0.0, color = Color(3.0, 2.5, 0.3, 1.0) },
            { time = 0.5, color = Color(2.0, 1.5, 0.1, 0.6) },
            { time = 1.0, color = Color(0.8, 0.4, 0.0, 0.0) },
        },
    })
    -- 小火花点缀
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_fire_sparks,
        tint = Color(3.0, 1.5, 0.1, 1),
        maxParticles = 12, emitRate = 10,
        life = 0.15,
        sizeMin = 0.030, sizeMax = 0.060,
        gravity = 0.6,
        shapeRadius = 0.03,
        rotSpeed = 360,
        velMin = Vector3(-1.0, 0.2, -1.0), velMax = Vector3(1.0, 1.2, 1.0),
        colors = {
            { time = 0.0, color = Color(3.5, 2.0, 0.2, 1.0) },
            { time = 1.0, color = Color(1.0, 0.3, 0.0, 0.0) },
        },
    })
    return node
end

-- 火种圣器: 火焰粒子贴图缓慢上升
VFX_CREATORS["fire_seed"] = function(towerNode)
    -- 主火焰（用 Fire_1 贴图）
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_fire1,
        tint = Color(1.5, 0.6, 0.1, 1),
        maxParticles = 20, emitRate = 10,
        lifeMin = 0.5, lifeMax = 1.0,
        sizeMin = 0.100, sizeMax = 0.220,
        gravity = -0.4,
        shapeRadius = 0.06,
        rotSpeed = 90,
        velMin = Vector3(-0.12, 0.3, -0.12), velMax = Vector3(0.12, 0.7, 0.12),
        colors = {
            { time = 0.0, color = Color(2.5, 1.2, 0.1, 1.0) },
            { time = 0.4, color = Color(2.0, 0.5, 0.0, 0.8) },
            { time = 1.0, color = Color(0.4, 0.1, 0.0, 0.0) },
        },
    })
    -- 火花粒子（Sparky_Flame）
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_sparky_flame,
        tint = Color(2.5, 1.5, 0.1, 1),
        maxParticles = 10, emitRate = 6,
        life = 0.35,
        sizeMin = 0.060, sizeMax = 0.110,
        gravity = 0.3,
        shapeRadius = 0.04,
        rotSpeed = 120,
        velMin = Vector3(-0.3, 0.2, -0.3), velMax = Vector3(0.3, 0.6, 0.3),
        colors = {
            { time = 0.0, color = Color(3.0, 2.0, 0.2, 1.0) },
            { time = 1.0, color = Color(1.0, 0.4, 0.0, 0.0) },
        },
    })
    return node
end

-- 冰晶圣器: 冰锥 + 六角冰晶飘散
VFX_CREATORS["ice_crystal"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_icicle,
        tint = Color(0.5, 0.85, 2.0, 1),
        maxParticles = 18, emitRate = 8,
        lifeMin = 0.8, lifeMax = 1.4,
        sizeMin = 0.060, sizeMax = 0.130,
        gravity = 0.2,
        shapeRadius = 0.08,
        rotSpeed = 90,
        velMin = Vector3(-0.2, -0.1, -0.2), velMax = Vector3(0.2, 0.5, 0.2),
        colors = {
            { time = 0.0, color = Color(0.5, 0.9, 2.5, 1.0) },
            { time = 0.5, color = Color(0.7, 1.0, 2.5, 0.7) },
            { time = 1.0, color = Color(1.0, 1.2, 2.0, 0.0) },
        },
    })
    -- 冰晶碎屑
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.hexagon,
        tint = Color(0.7, 1.0, 2.0, 1),
        maxParticles = 14, emitRate = 7,
        life = 0.9,
        sizeMin = 0.030, sizeMax = 0.070,
        gravity = 0.3,
        shapeRadius = 0.1,
        rotSpeed = 180,
        velMin = Vector3(-0.4, 0.1, -0.4), velMax = Vector3(0.4, 0.5, 0.4),
        colors = {
            { time = 0.0, color = Color(0.8, 1.2, 3.0, 1.0) },
            { time = 1.0, color = Color(0.6, 0.8, 1.8, 0.0) },
        },
    })
    return node
end

-- 腐蚀圣器: 毒素液滴滴落
VFX_CREATORS["corrosion"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_toxic,
        tint = Color(0.3, 1.2, 0.1, 1),
        maxParticles = 14, emitRate = 6,
        lifeMin = 0.5, lifeMax = 1.0,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = 1.5,
        shapeRadius = 0.04,
        rotSpeed = 90,
        velMin = Vector3(-0.1, -0.1, -0.1), velMax = Vector3(0.1, 0.3, 0.1),
        colors = {
            { time = 0.0, color = Color(0.3, 2.0, 0.1, 1.0) },
            { time = 0.5, color = Color(0.2, 1.4, 0.0, 0.7) },
            { time = 1.0, color = Color(0.1, 0.5, 0.0, 0.0) },
        },
    })
end

-- 雷鸣圣器: 紫蓝电弧链 — 高亮闪电+电磁脉冲环+微粒电花
VFX_CREATORS["thunder"] = function(towerNode)
    -- 主闪电弧：大尺寸、极短寿命、高频闪烁 → 视觉上"劈啪"感
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_lightning,
        tint = Color(0.6, 0.3, 3.5, 1),
        additive = true,
        maxParticles = 20, emitRate = 18,
        lifeMin = 0.06, lifeMax = 0.14,
        sizeMin = 0.140, sizeMax = 0.300,
        gravity = 0,
        shapeRadius = 0.15,
        rotSpeed = 600,
        velMin = Vector3(-1.0, -0.8, -1.0), velMax = Vector3(1.0, 1.0, 1.0),
        colors = {
            { time = 0.0, color = Color(0.6, 0.4, 5.0, 1.0) },
            { time = 0.3, color = Color(0.9, 0.7, 4.0, 0.9) },
            { time = 0.7, color = Color(0.5, 0.3, 3.0, 0.4) },
            { time = 1.0, color = Color(0.2, 0.1, 1.5, 0.0) },
        },
    })
    -- 电磁脉冲环：向外快速扩散的环形粒子
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_eletric_exp,
        tint = Color(0.4, 0.6, 4.0, 1),
        additive = true,
        maxParticles = 10, emitRate = 6,
        lifeMin = 0.10, lifeMax = 0.22,
        sizeMin = 0.120, sizeMax = 0.250,
        gravity = 0,
        shapeRadius = 0.06,
        rotSpeed = 400,
        velMin = Vector3(-1.5, -1.0, -1.5), velMax = Vector3(1.5, 1.2, 1.5),
        colors = {
            { time = 0.0, color = Color(0.5, 0.8, 5.0, 1.0) },
            { time = 0.5, color = Color(0.7, 0.5, 3.5, 0.6) },
            { time = 1.0, color = Color(0.2, 0.1, 2.0, 0.0) },
        },
    })
    -- 微粒电火花：细小高亮，快速衰减
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_sparks,
        tint = Color(0.7, 0.5, 4.5, 1),
        additive = true,
        maxParticles = 16, emitRate = 12,
        life = 0.08,
        sizeMin = 0.020, sizeMax = 0.050,
        gravity = 0.3,
        shapeRadius = 0.10,
        rotSpeed = 720,
        velMin = Vector3(-1.2, -0.5, -1.2), velMax = Vector3(1.2, 1.5, 1.2),
        colors = {
            { time = 0.0, color = Color(1.0, 0.8, 6.0, 1.0) },
            { time = 1.0, color = Color(0.3, 0.2, 2.0, 0.0) },
        },
    })
    return node
end

-- 裂片圣器: 金属碎片弧线爆裂 — 橙金弹片+火花+重力飞散
VFX_CREATORS["splinter"] = function(towerNode)
    -- 主碎片：金属橙色，有重力弧线，旋转飞散
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_rock_break,
        tint = Color(2.0, 1.2, 0.3, 1),
        additive = true,
        maxParticles = 24, emitRate = 12,
        lifeMin = 0.4, lifeMax = 0.8,
        sizeMin = 0.060, sizeMax = 0.140,
        gravity = 1.8,
        shapeRadius = 0.06,
        rotSpeed = 360,
        velMin = Vector3(-0.8, 0.6, -0.8), velMax = Vector3(0.8, 1.8, 0.8),
        colors = {
            { time = 0.0, color = Color(3.0, 2.0, 0.4, 1.0) },
            { time = 0.3, color = Color(2.5, 1.5, 0.2, 0.9) },
            { time = 0.7, color = Color(1.5, 0.8, 0.1, 0.4) },
            { time = 1.0, color = Color(0.6, 0.3, 0.0, 0.0) },
        },
    })
    -- 溅射火花：高速小粒子，金白色
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_fire_sparks,
        tint = Color(3.0, 2.5, 0.8, 1),
        additive = true,
        maxParticles = 18, emitRate = 14,
        life = 0.15,
        sizeMin = 0.025, sizeMax = 0.055,
        gravity = 0.8,
        shapeRadius = 0.04,
        rotSpeed = 480,
        velMin = Vector3(-1.5, 0.3, -1.5), velMax = Vector3(1.5, 2.2, 1.5),
        colors = {
            { time = 0.0, color = Color(4.0, 3.5, 1.0, 1.0) },
            { time = 0.5, color = Color(3.0, 1.8, 0.3, 0.6) },
            { time = 1.0, color = Color(1.0, 0.4, 0.0, 0.0) },
        },
    })
    return node
end

-- 穿透弹芯: 银蓝高速穿射 — 激光拖尾+能量涟漪+尖锐光点
VFX_CREATORS["piercing_core"] = function(towerNode)
    -- 主拖尾：纵向高速银蓝线条，极窄发射域
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.bullet_trail,
        tint = Color(1.2, 1.8, 4.0, 1),
        additive = true,
        maxParticles = 32, emitRate = 22,
        lifeMin = 0.12, lifeMax = 0.28,
        sizeMin = 0.030, sizeMax = 0.070,
        gravity = 0,
        shapeRadius = 0.02,
        velMin = Vector3(-0.05, 1.5, -0.05), velMax = Vector3(0.05, 3.5, 0.05),
        colors = {
            { time = 0.0, color = Color(1.5, 2.0, 5.0, 1.0) },
            { time = 0.3, color = Color(1.2, 1.5, 4.0, 0.8) },
            { time = 0.7, color = Color(0.8, 1.0, 3.0, 0.3) },
            { time = 1.0, color = Color(0.4, 0.5, 2.0, 0.0) },
        },
    })
    -- 能量涟漪：环形快速扩散
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.ring,
        tint = Color(0.8, 1.2, 3.5, 1),
        additive = true,
        maxParticles = 8, emitRate = 5,
        lifeMin = 0.15, lifeMax = 0.30,
        sizeMin = 0.050, sizeMax = 0.120,
        gravity = 0,
        shapeRadius = 0.02,
        rotSpeed = 200,
        velMin = Vector3(-0.3, 2.0, -0.3), velMax = Vector3(0.3, 3.0, 0.3),
        colors = {
            { time = 0.0, color = Color(1.0, 1.5, 4.5, 1.0) },
            { time = 0.5, color = Color(0.8, 1.0, 3.0, 0.5) },
            { time = 1.0, color = Color(0.4, 0.6, 2.0, 0.0) },
        },
    })
    -- 尖锐光点：极小高亮白蓝点
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.sparkle,
        tint = Color(1.5, 2.0, 5.0, 1),
        additive = true,
        maxParticles = 10, emitRate = 8,
        life = 0.10,
        sizeMin = 0.015, sizeMax = 0.035,
        gravity = 0,
        shapeRadius = 0.03,
        rotSpeed = 360,
        velMin = Vector3(-0.2, 1.0, -0.2), velMax = Vector3(0.2, 2.5, 0.2),
        colors = {
            { time = 0.0, color = Color(2.0, 2.5, 6.0, 1.0) },
            { time = 1.0, color = Color(0.5, 0.8, 2.5, 0.0) },
        },
    })
    return node
end

-- 狙击改装: 深红精准激光 — 聚焦红光束+蓄力旋涡+瞄准闪点
VFX_CREATORS["sniper_mod"] = function(towerNode)
    -- 聚焦激光束：窄且长的红色拖尾线
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.bullet_trail,
        tint = Color(3.5, 0.1, 0.1, 1),
        additive = true,
        maxParticles = 12, emitRate = 6,
        lifeMin = 0.4, lifeMax = 0.8,
        sizeMin = 0.020, sizeMax = 0.045,
        gravity = 0,
        shapeRadius = 0.01,
        velMin = Vector3(-0.02, 0.8, -0.02), velMax = Vector3(0.02, 2.0, 0.02),
        colors = {
            { time = 0.0, color = Color(4.5, 0.2, 0.1, 1.0) },
            { time = 0.3, color = Color(3.5, 0.1, 0.05, 0.8) },
            { time = 0.7, color = Color(2.5, 0.05, 0.0, 0.4) },
            { time = 1.0, color = Color(1.0, 0.0, 0.0, 0.0) },
        },
    })
    -- 蓄力旋涡：红色光圈缓慢收束
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.ring,
        tint = Color(3.0, 0.15, 0.05, 1),
        additive = true,
        maxParticles = 6, emitRate = 3,
        lifeMin = 0.8, lifeMax = 1.5,
        sizeMin = 0.080, sizeMax = 0.160,
        gravity = 0,
        shapeRadius = 0.15,
        rotSpeed = 120,
        velMin = Vector3(-0.3, 0.0, -0.3), velMax = Vector3(0.3, 0.3, 0.3),
        damping = 2.0,
        colors = {
            { time = 0.0, color = Color(4.0, 0.2, 0.1, 0.9) },
            { time = 0.5, color = Color(3.0, 0.1, 0.05, 0.5) },
            { time = 1.0, color = Color(1.5, 0.0, 0.0, 0.0) },
        },
    })
    -- 瞄准闪点：中心高亮白红光点闪烁
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.sparkle,
        tint = Color(5.0, 1.0, 0.5, 1),
        additive = true,
        maxParticles = 4, emitRate = 3,
        lifeMin = 0.15, lifeMax = 0.35,
        sizeMin = 0.030, sizeMax = 0.060,
        gravity = 0,
        shapeRadius = 0.01,
        rotSpeed = 240,
        velMin = Vector3(-0.02, 0.1, -0.02), velMax = Vector3(0.02, 0.4, 0.02),
        colors = {
            { time = 0.0, color = Color(6.0, 2.0, 0.8, 1.0) },
            { time = 0.5, color = Color(4.0, 0.5, 0.2, 0.7) },
            { time = 1.0, color = Color(2.0, 0.1, 0.0, 0.0) },
        },
    })
    return node
end

-- 棱镜圣器: 华丽七彩折射 — 彩虹光环旋转+棱镜碎片飘散+中心白芒
VFX_CREATORS["prism"] = function(towerNode)
    -- 彩虹光环：大尺寸缓慢旋转，形成棱镜折射的氛围感
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.rainbow,
        additive = true,
        maxParticles = 16, emitRate = 7,
        lifeMin = 2.0, lifeMax = 3.5,
        sizeMin = 0.120, sizeMax = 0.220,
        gravity = 0,
        shapeRadius = 0.06,
        rotSpeed = 45,
        velMin = Vector3(-0.05, -0.03, -0.05), velMax = Vector3(0.05, 0.06, 0.05),
        colors = {
            { time = 0.0, color = Color(2.5, 2.5, 2.5, 1.0) },
            { time = 0.3, color = Color(2.0, 2.0, 2.0, 0.9) },
            { time = 0.7, color = Color(1.8, 1.8, 1.8, 0.5) },
            { time = 1.0, color = Color(1.2, 1.2, 1.2, 0.0) },
        },
    })
    -- 七色棱镜碎片：循环变色高亮闪烁，散布范围较大
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.sparkle,
        additive = true,
        maxParticles = 20, emitRate = 12,
        lifeMin = 0.5, lifeMax = 1.0,
        sizeMin = 0.035, sizeMax = 0.080,
        gravity = 0,
        shapeRadius = 0.18,
        rotSpeed = 300,
        velMin = Vector3(-0.3, -0.2, -0.3), velMax = Vector3(0.3, 0.3, 0.3),
        colors = {
            { time = 0.00, color = Color(4.0, 0.3, 0.3, 1.0) },
            { time = 0.20, color = Color(3.5, 2.5, 0.2, 1.0) },
            { time = 0.40, color = Color(0.3, 4.0, 0.3, 1.0) },
            { time = 0.60, color = Color(0.3, 2.0, 4.0, 1.0) },
            { time = 0.80, color = Color(3.0, 0.3, 4.0, 1.0) },
            { time = 1.00, color = Color(2.0, 0.2, 2.0, 0.0) },
        },
    })
    -- 中心白芒：强烈发光核心，营造"能量聚焦"感
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.soft_spot,
        tint = Color(3.0, 3.0, 4.0, 1),
        additive = true,
        maxParticles = 6, emitRate = 4,
        lifeMin = 0.6, lifeMax = 1.2,
        sizeMin = 0.060, sizeMax = 0.110,
        gravity = 0,
        shapeRadius = 0.02,
        velMin = Vector3(-0.02, -0.01, -0.02), velMax = Vector3(0.02, 0.04, 0.02),
        colors = {
            { time = 0.0, color = Color(4.0, 4.0, 5.0, 1.0) },
            { time = 0.4, color = Color(3.0, 3.0, 4.0, 0.8) },
            { time = 1.0, color = Color(1.5, 1.5, 2.5, 0.0) },
        },
    })
    return node
end

-- 高爆圣器: 爆炸火球瞬闪
VFX_CREATORS["high_explosive"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_fire_meteor,
        tint = Color(2.0, 0.8, 0.1, 1),
        maxParticles = 20, emitRate = 10,
        lifeMin = 0.2, lifeMax = 0.45,
        sizeMin = 0.120, sizeMax = 0.240,
        gravity = 0,
        shapeRadius = 0.08,
        rotSpeed = 140,
        velMin = Vector3(-0.9, -0.3, -0.9), velMax = Vector3(0.9, 0.9, 0.9),
        colors = {
            { time = 0.0, color = Color(3.0, 2.0, 0.2, 1.0) },
            { time = 0.3, color = Color(2.5, 0.8, 0.0, 0.8) },
            { time = 1.0, color = Color(0.5, 0.2, 0.1, 0.0) },
        },
    })
    -- 火花（Fire_Sparks）
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        tex = TEX.pfx_fire_sparks,
        maxParticles = 16, emitRate = 10,
        life = 0.22,
        sizeMin = 0.050, sizeMax = 0.100,
        gravity = 0.3,
        shapeRadius = 0.1,
        rotSpeed = 180,
        velMin = Vector3(-1.0, -0.5, -1.0), velMax = Vector3(1.0, 1.0, 1.0),
        colors = {
            { time = 0.0, color = Color(3.5, 2.8, 0.5, 1.0) },
            { time = 1.0, color = Color(1.0, 0.3, 0.0, 0.0) },
        },
    })
    return node
end

-- 暴击装置: 金色星光闪烁
VFX_CREATORS["crit_device"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = Vector3(0, 1.3, 0),
        tex = TEX.pfx_star_shine,
        tint = Color(3.0, 2.5, 0.2, 1),
        additive = true,
        maxParticles = 10, emitRate = 4,
        lifeMin = 0.6, lifeMax = 1.2,
        sizeMin = 0.070, sizeMax = 0.150,
        gravity = 0,
        shapeRadius = 0.05,
        rotSpeed = 180,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.12, 0.05),
        colors = {
            { time = 0.0, color = Color(4.0, 3.5, 0.3, 1.0) },
            { time = 0.5, color = Color(3.5, 3.0, 0.2, 0.8) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
    -- 金色闪光点缀
    CreateParticleNode(towerNode, {
        offset = Vector3(0, 1.3, 0),
        tex = TEX.sparkle,
        tint = Color(3.5, 3.0, 0.1, 1),
        additive = true,
        maxParticles = 6, emitRate = 3,
        life = 0.4,
        sizeMin = 0.040, sizeMax = 0.090,
        gravity = 0,
        shapeRadius = 0.08,
        rotSpeed = 360,
        velMin = Vector3(-0.08, -0.05, -0.08), velMax = Vector3(0.08, 0.08, 0.08),
        colors = {
            { time = 0.0, color = Color(4.5, 4.0, 0.5, 1.0) },
            { time = 1.0, color = Color(2.0, 1.5, 0.0, 0.0) },
        },
    })
    return node
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

-- 元素核心: 4色元素光环环绕旋转
VFX_CREATORS["elemental_core"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = Vector3(0, 1.3, 0),
        tex = TEX.pfx_eletric_aura,
        maxParticles = 16, emitRate = 8,
        lifeMin = 1.0, lifeMax = 1.8,
        sizeMin = 0.080, sizeMax = 0.130,
        gravity = 0,
        shapeRadius = 0.1,
        rotSpeed = 200,
        velMin = Vector3(-0.15, -0.1, -0.15), velMax = Vector3(0.15, 0.1, 0.15),
        colors = {
            { time = 0.0,  color = Color(3.0, 0.5, 0.1, 1.0) },
            { time = 0.33, color = Color(0.2, 0.5, 3.0, 1.0) },
            { time = 0.67, color = Color(0.8, 0.1, 3.0, 1.0) },
            { time = 1.0,  color = Color(0.2, 2.5, 0.2, 0.0) },
        },
    })
    -- 附加电弧爆炸
    CreateParticleNode(towerNode, {
        offset = Vector3(0, 1.3, 0),
        tex = TEX.pfx_eletric_exp,
        maxParticles = 8, emitRate = 4,
        lifeMin = 0.6, lifeMax = 1.0,
        sizeMin = 0.100, sizeMax = 0.180,
        gravity = 0,
        shapeRadius = 0.08,
        rotSpeed = 300,
        velMin = Vector3(-0.2, -0.1, -0.2), velMax = Vector3(0.2, 0.1, 0.2),
        colors = {
            { time = 0.0, color = Color(2.0, 1.5, 0.1, 1.0) },
            { time = 0.5, color = Color(0.2, 0.8, 2.5, 0.8) },
            { time = 1.0, color = Color(0.5, 0.1, 2.0, 0.0) },
        },
    })
    return node
end

-- ─── 增益类 ──────────────────────────────────────────────────────────────────

-- 攻速光环: 电弧光环绕塔基旋转
VFX_CREATORS["aura_attack_speed"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.pfx_eletric_aura,
        tint = Color(2.5, 2.0, 0.2, 1),
        additive = true,
        maxParticles = 28, emitRate = 14,
        lifeMin = 0.7, lifeMax = 1.1,
        sizeMin = 0.070, sizeMax = 0.130,
        gravity = 0,
        shapeRadius = 5.0,
        rotSpeed = 180,
        velMin = Vector3(-0.12, 0.04, -0.12), velMax = Vector3(0.12, 0.22, 0.12),
        colors = {
            { time = 0.0, color = Color(3.0, 2.8, 0.3, 1.0) },
            { time = 0.5, color = Color(2.5, 2.2, 0.1, 0.6) },
            { time = 1.0, color = Color(1.5, 1.5, 0.0, 0.0) },
        },
    })
    -- 风刃辅助
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.wind,
        tint = Color(2.0, 2.0, 0.1, 1),
        additive = true,
        maxParticles = 16, emitRate = 8,
        life = 0.9,
        sizeMin = 0.050, sizeMax = 0.090,
        gravity = 0,
        shapeRadius = 5.0,
        rotSpeed = 90,
        velMin = Vector3(-0.2, 0.0, -0.2), velMax = Vector3(0.2, 0.3, 0.2),
        colors = {
            { time = 0.0, color = Color(2.5, 2.5, 0.2, 0.8) },
            { time = 1.0, color = Color(1.5, 1.5, 0.0, 0.0) },
        },
    })
    return node
end

-- 伤害光环: 暗红电弧光环涌动
VFX_CREATORS["aura_damage"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.pfx_dark_aura,
        tint = Color(2.0, 0.1, 0.1, 1),
        maxParticles = 26, emitRate = 13,
        lifeMin = 1.2, lifeMax = 2.0,
        sizeMin = 0.100, sizeMax = 0.200,
        gravity = -0.2,
        shapeRadius = 5.0,
        rotSpeed = 60,
        velMin = Vector3(-0.08, 0.02, -0.08), velMax = Vector3(0.08, 0.15, 0.08),
        colors = {
            { time = 0.0, color = Color(2.8, 0.1, 0.1, 1.0) },
            { time = 0.5, color = Color(2.0, 0.05, 0.05, 0.6) },
            { time = 1.0, color = Color(0.8, 0.0, 0.0, 0.0) },
        },
    })
    -- 附加电弧扩散
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.pfx_eletric_aura,
        tint = Color(1.5, 0.0, 0.2, 1),
        maxParticles = 10, emitRate = 5,
        lifeMin = 0.5, lifeMax = 0.9,
        sizeMin = 0.080, sizeMax = 0.150,
        gravity = 0,
        shapeRadius = 5.0,
        rotSpeed = 200,
        velMin = Vector3(-0.1, 0.0, -0.1), velMax = Vector3(0.1, 0.1, 0.1),
        colors = {
            { time = 0.0, color = Color(2.5, 0.2, 0.5, 1.0) },
            { time = 1.0, color = Color(0.5, 0.0, 0.1, 0.0) },
        },
    })
    return node
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

-- 暴击光环: 星光粒子随机闪现
VFX_CREATORS["aura_crit"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.pfx_star_shine,
        tint = Color(3.5, 3.0, 0.2, 1),
        additive = true,
        maxParticles = 16, emitRate = 8,
        lifeMin = 0.3, lifeMax = 0.6,
        sizeMin = 0.080, sizeMax = 0.160,
        gravity = 0,
        shapeRadius = 5.0,
        rotSpeed = 240,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.18, 0.05),
        colors = {
            { time = 0.0, color = Color(4.5, 4.0, 0.4, 1.0) },
            { time = 0.5, color = Color(3.5, 3.0, 0.2, 0.7) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
    -- 四芒星点缀
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.sparkle,
        tint = Color(4.0, 3.5, 0.1, 1),
        additive = true,
        maxParticles = 10, emitRate = 5,
        life = 0.25,
        sizeMin = 0.050, sizeMax = 0.100,
        gravity = 0,
        shapeRadius = 5.0,
        rotSpeed = 360,
        velMin = Vector3(-0.06, 0.0, -0.06), velMax = Vector3(0.06, 0.1, 0.06),
        colors = {
            { time = 0.0, color = Color(5.0, 4.5, 0.5, 1.0) },
            { time = 1.0, color = Color(2.0, 1.5, 0.0, 0.0) },
        },
    })
    return node
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

-- 总管塔: 圣光光环悬浮旋转
VFX_CREATORS["master_tower"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.pfx_holy_aura,
        tint = Color(3.0, 2.5, 0.2, 1),
        maxParticles = 10, emitRate = 4,
        lifeMin = 1.8, lifeMax = 3.0,
        sizeMin = 0.120, sizeMax = 0.220,
        gravity = 0,
        shapeRadius = 0.06,
        rotSpeed = 60,
        velMin = Vector3(-0.04, 0.0, -0.04), velMax = Vector3(0.04, 0.08, 0.04),
        colors = {
            { time = 0.0, color = Color(3.5, 3.0, 0.5, 1.0) },
            { time = 0.5, color = Color(3.0, 2.5, 0.3, 0.8) },
            { time = 1.0, color = Color(2.0, 1.5, 0.0, 0.0) },
        },
    })
    -- 圣光粒子点缀
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.pfx_star_shine,
        tint = Color(3.5, 3.0, 0.5, 1),
        additive = true,
        maxParticles = 8, emitRate = 4,
        lifeMin = 0.6, lifeMax = 1.2,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = 0,
        shapeRadius = 0.1,
        rotSpeed = 120,
        velMin = Vector3(-0.1, -0.05, -0.1), velMax = Vector3(0.1, 0.1, 0.1),
        colors = {
            { time = 0.0, color = Color(4.0, 3.5, 0.5, 1.0) },
            { time = 1.0, color = Color(2.0, 1.5, 0.0, 0.0) },
        },
    })
    return node
end

-- 防御阵地塔: 蓝灰烟雾上升 + 地面护盾圆圈
VFX_CREATORS["defense_garrison"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.pfx_smoke4,
        tint = Color(0.4, 0.5, 1.2, 1),
        maxParticles = 18, emitRate = 8,
        lifeMin = 1.4, lifeMax = 2.2,
        sizeMin = 0.090, sizeMax = 0.180,
        gravity = -0.3,
        shapeRadius = 0.18,
        rotSpeed = 50,
        velMin = Vector3(-0.08, 0.3, -0.08), velMax = Vector3(0.08, 0.8, 0.08),
        colors = {
            { time = 0.0, color = Color(0.5, 0.6, 1.5, 0.8) },
            { time = 0.5, color = Color(0.4, 0.5, 1.2, 0.5) },
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

-- 吞噬线: 暗紫漩涡吞噬效果
VFX_CREATORS["devour_line"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.pfx_dark_swirl,
        tint = Color(0.5, 0.0, 0.8, 1),
        maxParticles = 16, emitRate = 8,
        lifeMin = 1.0, lifeMax = 1.8,
        sizeMin = 0.090, sizeMax = 0.180,
        gravity = -0.2,
        shapeRadius = 0.2,
        rotSpeed = 120,
        velMin = Vector3(-0.15, 0.1, -0.15), velMax = Vector3(0.15, 0.4, 0.15),
        colors = {
            { time = 0.0, color = Color(0.7, 0.0, 1.2, 0.9) },
            { time = 0.5, color = Color(0.4, 0.0, 0.8, 0.6) },
            { time = 1.0, color = Color(0.1, 0.0, 0.2, 0.0) },
        },
    })
    -- 暗烟辅助
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.pfx_dark_aura,
        tint = Color(0.3, 0.0, 0.5, 1),
        maxParticles = 10, emitRate = 5,
        lifeMin = 0.6, lifeMax = 1.0,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = -0.3,
        shapeRadius = 0.25,
        rotSpeed = 80,
        velMin = Vector3(-0.2, 0.05, -0.2), velMax = Vector3(0.2, 0.4, 0.2),
        colors = {
            { time = 0.0, color = Color(0.6, 0.0, 1.0, 0.8) },
            { time = 1.0, color = Color(0.05, 0.0, 0.15, 0.0) },
        },
    })
    return node
end

-- 冰晶导管: 冰锥 + 六角冰晶沿链路穿梭
VFX_CREATORS["ice_crystal_conduit"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.pfx_icicle,
        tint = Color(0.5, 0.9, 2.2, 1),
        maxParticles = 16, emitRate = 7,
        lifeMin = 1.0, lifeMax = 1.8,
        sizeMin = 0.060, sizeMax = 0.120,
        gravity = 0,
        shapeRadius = 0.25,
        rotSpeed = 100,
        velMin = Vector3(-0.5, -0.2, -0.5), velMax = Vector3(0.5, 0.2, 0.5),
        colors = {
            { time = 0.0, color = Color(0.5, 0.9, 2.8, 1.0) },
            { time = 0.5, color = Color(0.7, 1.0, 3.0, 0.6) },
            { time = 1.0, color = Color(0.8, 1.0, 2.0, 0.0) },
        },
    })
    -- 冰晶碎片
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.hexagon,
        tint = Color(0.6, 1.0, 2.5, 1),
        maxParticles = 12, emitRate = 6,
        life = 0.8,
        sizeMin = 0.030, sizeMax = 0.065,
        gravity = 0,
        shapeRadius = 0.3,
        rotSpeed = 200,
        velMin = Vector3(-0.7, -0.3, -0.7), velMax = Vector3(0.7, 0.3, 0.7),
        colors = {
            { time = 0.0, color = Color(0.8, 1.2, 3.5, 1.0) },
            { time = 1.0, color = Color(0.5, 0.8, 2.0, 0.0) },
        },
    })
    return node
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

-- 过载继电器: 橙红高压闪电迸射
VFX_CREATORS["overload_relay"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.pfx_lightning,
        tint = Color(3.0, 0.6, 0.1, 1),
        additive = true,
        maxParticles = 14, emitRate = 8,
        lifeMin = 0.15, lifeMax = 0.40,
        sizeMin = 0.080, sizeMax = 0.160,
        gravity = 0,
        shapeRadius = 0.15,
        rotSpeed = 360,
        velMin = Vector3(-1.5, -1.0, -1.5), velMax = Vector3(1.5, 1.5, 1.5),
        colors = {
            { time = 0.0, color = Color(3.5, 0.8, 0.1, 1.0) },
            { time = 0.4, color = Color(3.0, 0.4, 0.0, 0.7) },
            { time = 1.0, color = Color(1.0, 0.1, 0.0, 0.0) },
        },
    })
    -- 电弧火花
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        tex = TEX.pfx_sparks,
        additive = true,
        maxParticles = 14, emitRate = 10,
        life = 0.12,
        sizeMin = 0.040, sizeMax = 0.090,
        gravity = 0.2,
        shapeRadius = 0.1,
        rotSpeed = 480,
        velMin = Vector3(-1.2, -0.6, -1.2), velMax = Vector3(1.2, 1.0, 1.2),
        colors = {
            { time = 0.0, color = Color(4.0, 2.0, 0.3, 1.0) },
            { time = 1.0, color = Color(1.5, 0.4, 0.0, 0.0) },
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

-- 金矿炼化: 金色光粒 + 复苏光环悬浮
VFX_CREATORS["gold_refinery"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.pfx_regen,
        tint = Color(3.0, 2.2, 0.1, 1),
        additive = true,
        maxParticles = 10, emitRate = 4,
        lifeMin = 1.2, lifeMax = 2.0,
        sizeMin = 0.070, sizeMax = 0.140,
        gravity = -0.2,
        shapeRadius = 0.08,
        rotSpeed = 60,
        velMin = Vector3(-0.2, 0.05, -0.2), velMax = Vector3(0.2, 0.3, 0.2),
        colors = {
            { time = 0.0, color = Color(3.5, 2.8, 0.2, 1.0) },
            { time = 0.5, color = Color(3.0, 2.2, 0.0, 0.7) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
    })
    -- 金色光点
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.pfx_star_shine,
        tint = Color(3.5, 2.5, 0.1, 1),
        additive = true,
        maxParticles = 6, emitRate = 3,
        life = 0.8,
        sizeMin = 0.040, sizeMax = 0.090,
        gravity = -0.3,
        shapeRadius = 0.1,
        rotSpeed = 120,
        velMin = Vector3(-0.3, 0.1, -0.3), velMax = Vector3(0.3, 0.5, 0.3),
        colors = {
            { time = 0.0, color = Color(4.5, 3.5, 0.4, 1.0) },
            { time = 1.0, color = Color(2.0, 1.5, 0.0, 0.0) },
        },
    })
    return node
end

-- 充能矩阵: 生命流光 + 能量方格环绕
VFX_CREATORS["energy_matrix"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.pfx_lifestream,
        tint = Color(0.3, 0.7, 2.8, 1),
        additive = true,
        maxParticles = 12, emitRate = 5,
        lifeMin = 2.0, lifeMax = 3.5,
        sizeMin = 0.080, sizeMax = 0.150,
        gravity = 0,
        shapeRadius = 0.08,
        rotSpeed = 80,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.05, 0.05),
        colors = {
            { time = 0.0, color = Color(0.3, 0.8, 3.5, 1.0) },
            { time = 0.5, color = Color(0.5, 1.0, 4.0, 0.8) },
            { time = 1.0, color = Color(0.3, 0.6, 2.0, 0.0) },
        },
    })
    -- 能量方格辅助
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.portal,
        tint = Color(0.4, 0.8, 2.5, 1),
        additive = true,
        maxParticles = 6, emitRate = 3,
        lifeMin = 3.0, lifeMax = 5.0,
        sizeMin = 0.060, sizeMax = 0.100,
        gravity = 0,
        shapeRadius = 0.06,
        rotSpeed = 45,
        velMin = Vector3(-0.03, 0.0, -0.03), velMax = Vector3(0.03, 0.03, 0.03),
        colors = {
            { time = 0.0, color = Color(0.4, 0.9, 3.0, 0.9) },
            { time = 1.0, color = Color(0.3, 0.6, 2.0, 0.0) },
        },
    })
    return node
end

-- 蓄力击: 光火花积聚 + 蓝色能量圈
VFX_CREATORS["charged_hit"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.pfx_light_spark,
        tint = Color(0.3, 0.6, 3.5, 1),
        additive = true,
        maxParticles = 14, emitRate = 6,
        lifeMin = 0.8, lifeMax = 1.5,
        sizeMin = 0.060, sizeMax = 0.130,
        gravity = -0.2,
        shapeRadius = 0.08,
        rotSpeed = 150,
        velMin = Vector3(-0.1, 0.1, -0.1), velMax = Vector3(0.1, 0.5, 0.1),
        colors = {
            { time = 0.0, color = Color(0.4, 0.8, 4.5, 1.0) },
            { time = 0.5, color = Color(0.5, 0.9, 3.5, 0.7) },
            { time = 1.0, color = Color(0.4, 0.6, 2.0, 0.0) },
        },
    })
    -- 能量圈辅助
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.circle,
        tint = Color(0.3, 0.6, 3.0, 1),
        additive = true,
        maxParticles = 8, emitRate = 3,
        lifeMin = 1.5, lifeMax = 2.5,
        sizeMin = 0.070, sizeMax = 0.120,
        gravity = -0.3,
        shapeRadius = 0.10,
        rotSpeed = 60,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.3, 0.05),
        colors = {
            { time = 0.0, color = Color(0.3, 0.7, 3.5, 0.9) },
            { time = 1.0, color = Color(0.3, 0.5, 2.0, 0.0) },
        },
    })
    return node
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

-- 反馈线圈: 暗旋漩涡环脉冲 + 金色光柱
VFX_CREATORS["feedback_coil"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        tex = TEX.pfx_dark_swirl,
        tint = Color(0.8, 0.1, 2.8, 1),
        additive = true,
        maxParticles = 20, emitRate = 10,
        lifeMin = 0.8, lifeMax = 1.4,
        sizeMin = 0.080, sizeMax = 0.150,
        gravity = 0,
        shapeRadius = 1.5,
        rotSpeed = 150,
        velMin = Vector3(-1.5, 0.0, -1.5), velMax = Vector3(1.5, 0.1, 1.5),
        colors = {
            { time = 0.0, color = Color(1.0, 0.1, 3.5, 1.0) },
            { time = 0.5, color = Color(0.6, 0.0, 2.8, 0.6) },
            { time = 1.0, color = Color(0.3, 0.0, 1.5, 0.0) },
        },
    })
    -- 金色光柱上升
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        tex = TEX.pfx_regen,
        tint = Color(3.0, 2.2, 0.1, 1),
        additive = true,
        maxParticles = 12, emitRate = 6,
        lifeMin = 1.0, lifeMax = 1.8,
        sizeMin = 0.050, sizeMax = 0.100,
        gravity = -0.5,
        shapeRadius = 0.05,
        rotSpeed = 60,
        velMin = Vector3(-0.1, 0.5, -0.1), velMax = Vector3(0.1, 1.8, 0.1),
        colors = {
            { time = 0.0, color = Color(3.5, 2.8, 0.2, 1.0) },
            { time = 0.5, color = Color(3.0, 2.2, 0.0, 0.6) },
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

    -- 弹道型圣器: 特效在子弹/命中处生成，塔上不显示
    if BULLET_TYPE_ARTIFACTS[artifactId] then return end

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

-- ============================================================================
-- 子弹拖尾 VFX 配置（每种弹道型圣器一条配置，挂在 projNode 上）
-- ============================================================================
local BULLET_VFX = {}

-- 连射模块弹道: 高频橙黄弹幕火花拖尾
BULLET_VFX["rapid_fire_module"] = {
    tex = TEX.pfx_sparks, tint = Color(3.5, 2.5, 0.3, 1), additive = true,
    maxParticles = 14, emitRate = 50, life = 0.08,
    sizeMin = 0.025, sizeMax = 0.055, shapeRadius = 0.025, gravity = 0.3, rotSpeed = 420,
    velMin = Vector3(-0.25, -0.15, -0.25), velMax = Vector3(0.25, 0.25, 0.25),
    colors = {
        { time = 0.0, color = Color(4.0, 3.5, 0.5, 1.0) },
        { time = 0.25, color = Color(3.5, 2.5, 0.2, 0.9) },
        { time = 0.6, color = Color(2.0, 1.0, 0.1, 0.5) },
        { time = 1.0, color = Color(0.8, 0.3, 0.0, 0.0) },
    },
}
-- 火种圣器弹道: 燃烧火焰拖尾，红橙渐变
BULLET_VFX["fire_seed"] = {
    tex = TEX.pfx_sparky_flame, tint = Color(3.0, 1.5, 0.1, 1), additive = true,
    maxParticles = 12, emitRate = 40, life = 0.15,
    sizeMin = 0.035, sizeMax = 0.075, shapeRadius = 0.025, gravity = -0.2, rotSpeed = 180,
    velMin = Vector3(-0.18, -0.10, -0.18), velMax = Vector3(0.18, 0.20, 0.18),
    colors = {
        { time = 0.0, color = Color(4.0, 2.0, 0.3, 1.0) },
        { time = 0.2, color = Color(3.5, 1.2, 0.1, 0.9) },
        { time = 0.5, color = Color(2.5, 0.6, 0.05, 0.6) },
        { time = 0.8, color = Color(1.2, 0.2, 0.0, 0.3) },
        { time = 1.0, color = Color(0.4, 0.05, 0.0, 0.0) },
    },
}
-- 冰晶圣器弹道: 冰蓝结晶碎片拖尾
BULLET_VFX["ice_crystal"] = {
    tex = TEX.pfx_icicle, tint = Color(0.6, 1.2, 3.5, 1), additive = true,
    maxParticles = 12, emitRate = 38, life = 0.14,
    sizeMin = 0.028, sizeMax = 0.065, shapeRadius = 0.025, gravity = 0.2, rotSpeed = 300,
    velMin = Vector3(-0.15, -0.12, -0.15), velMax = Vector3(0.15, 0.15, 0.15),
    colors = {
        { time = 0.0, color = Color(1.0, 1.5, 4.5, 1.0) },
        { time = 0.2, color = Color(0.7, 1.2, 3.5, 0.9) },
        { time = 0.5, color = Color(0.4, 0.9, 2.5, 0.6) },
        { time = 0.8, color = Color(0.3, 0.7, 1.8, 0.3) },
        { time = 1.0, color = Color(0.2, 0.5, 1.2, 0.0) },
    },
}
-- 腐蚀圣器弹道: 酸绿毒液飞溅拖尾
BULLET_VFX["corrosion"] = {
    tex = TEX.pfx_toxic, tint = Color(0.4, 2.5, 0.2, 1), additive = true,
    maxParticles = 10, emitRate = 32, life = 0.16,
    sizeMin = 0.030, sizeMax = 0.065, shapeRadius = 0.025, gravity = 0.5, rotSpeed = 150,
    velMin = Vector3(-0.15, -0.10, -0.15), velMax = Vector3(0.15, 0.20, 0.15),
    colors = {
        { time = 0.0, color = Color(0.5, 3.5, 0.3, 1.0) },
        { time = 0.25, color = Color(0.3, 2.8, 0.2, 0.9) },
        { time = 0.55, color = Color(0.2, 1.8, 0.1, 0.5) },
        { time = 0.8, color = Color(0.1, 1.0, 0.05, 0.2) },
        { time = 1.0, color = Color(0.05, 0.4, 0.0, 0.0) },
    },
}
BULLET_VFX["thunder"] = {
    tex = TEX.pfx_lightning, tint = Color(0.5, 0.3, 4.0, 1), additive = true,
    maxParticles = 14, emitRate = 45, life = 0.07,
    sizeMin = 0.050, sizeMax = 0.110, shapeRadius = 0.04, gravity = 0, rotSpeed = 720,
    velMin = Vector3(-0.20, -0.20, -0.20), velMax = Vector3(0.20, 0.20, 0.20),
    colors = {
        { time = 0.0, color = Color(0.7, 0.5, 5.0, 1.0) },
        { time = 0.3, color = Color(0.9, 0.6, 4.0, 0.9) },
        { time = 0.6, color = Color(0.5, 0.3, 3.0, 0.5) },
        { time = 1.0, color = Color(0.3, 0.1, 1.5, 0.0) },
    },
}
BULLET_VFX["splinter"] = {
    tex = TEX.pfx_rock_break, tint = Color(1.8, 1.2, 0.4, 1), additive = true,
    maxParticles = 12, emitRate = 35, life = 0.18,
    sizeMin = 0.030, sizeMax = 0.065, shapeRadius = 0.03, gravity = 0.8, rotSpeed = 280,
    velMin = Vector3(-0.25, -0.15, -0.25), velMax = Vector3(0.25, 0.30, 0.25),
    colors = {
        { time = 0.0, color = Color(2.5, 1.8, 0.6, 1.0) },
        { time = 0.4, color = Color(2.0, 1.2, 0.3, 0.8) },
        { time = 0.7, color = Color(1.2, 0.7, 0.2, 0.4) },
        { time = 1.0, color = Color(0.5, 0.3, 0.1, 0.0) },
    },
}
BULLET_VFX["piercing_core"] = {
    tex = TEX.bullet_trail, tint = Color(1.8, 2.0, 3.5, 1), additive = true,
    maxParticles = 16, emitRate = 55, life = 0.10,
    sizeMin = 0.018, sizeMax = 0.040, shapeRadius = 0.008, gravity = 0,
    velMin = Vector3(-0.03, -0.03, -0.03), velMax = Vector3(0.03, 0.03, 0.03),
    colors = {
        { time = 0.0, color = Color(2.5, 2.8, 5.0, 1.0) },
        { time = 0.2, color = Color(2.0, 2.2, 4.0, 0.9) },
        { time = 0.5, color = Color(1.2, 1.5, 3.0, 0.5) },
        { time = 1.0, color = Color(0.5, 0.6, 1.5, 0.0) },
    },
}
BULLET_VFX["sniper_mod"] = {
    tex = TEX.pfx_tail, tint = Color(3.5, 0.2, 0.1, 1), additive = true,
    maxParticles = 10, emitRate = 40, life = 0.14,
    sizeMin = 0.012, sizeMax = 0.028, shapeRadius = 0.005, gravity = 0,
    velMin = Vector3(-0.02, -0.02, -0.02), velMax = Vector3(0.02, 0.02, 0.02),
    colors = {
        { time = 0.0, color = Color(4.0, 0.8, 0.3, 1.0) },
        { time = 0.2, color = Color(3.5, 0.2, 0.1, 0.9) },
        { time = 0.6, color = Color(2.0, 0.1, 0.05, 0.5) },
        { time = 1.0, color = Color(0.8, 0.05, 0.02, 0.0) },
    },
}
-- 高爆圣器弹道: 火焰陨石拖尾，大颗粒翻滚燃烧
BULLET_VFX["high_explosive"] = {
    tex = TEX.pfx_fire_meteor, tint = Color(3.0, 1.5, 0.2, 1), additive = true,
    maxParticles = 16, emitRate = 45, life = 0.18,
    sizeMin = 0.050, sizeMax = 0.110, shapeRadius = 0.04, gravity = 0.3, rotSpeed = 240,
    velMin = Vector3(-0.22, -0.15, -0.22), velMax = Vector3(0.22, 0.25, 0.22),
    colors = {
        { time = 0.0, color = Color(4.5, 3.0, 0.5, 1.0) },
        { time = 0.2, color = Color(3.5, 1.8, 0.2, 0.9) },
        { time = 0.5, color = Color(2.5, 0.8, 0.1, 0.6) },
        { time = 0.8, color = Color(1.2, 0.3, 0.05, 0.3) },
        { time = 1.0, color = Color(0.4, 0.1, 0.0, 0.0) },
    },
}
-- 暴击装置弹道: 金色星芒闪烁拖尾，暗示致命一击
BULLET_VFX["crit_device"] = {
    tex = TEX.pfx_star_shine, tint = Color(4.0, 3.0, 0.3, 1), additive = true,
    maxParticles = 10, emitRate = 35, life = 0.12,
    sizeMin = 0.030, sizeMax = 0.070, shapeRadius = 0.02, gravity = 0, rotSpeed = 540,
    velMin = Vector3(-0.12, -0.12, -0.12), velMax = Vector3(0.12, 0.12, 0.12),
    colors = {
        { time = 0.0, color = Color(5.0, 4.5, 1.0, 1.0) },
        { time = 0.2, color = Color(4.5, 3.5, 0.3, 0.9) },
        { time = 0.5, color = Color(3.0, 2.0, 0.1, 0.5) },
        { time = 0.8, color = Color(1.5, 0.8, 0.0, 0.2) },
        { time = 1.0, color = Color(0.5, 0.3, 0.0, 0.0) },
    },
}
-- 元素核心弹道: 多元素交融光环，红→蓝→紫→绿循环
BULLET_VFX["elemental_core"] = {
    tex = TEX.pfx_eletric_aura, additive = true,
    maxParticles = 14, emitRate = 42, life = 0.13,
    sizeMin = 0.035, sizeMax = 0.075, shapeRadius = 0.03, gravity = 0, rotSpeed = 480,
    velMin = Vector3(-0.16, -0.16, -0.16), velMax = Vector3(0.16, 0.16, 0.16),
    colors = {
        { time = 0.0, color = Color(4.0, 0.8, 0.2, 1.0) },
        { time = 0.2, color = Color(3.0, 0.3, 3.5, 0.9) },
        { time = 0.45, color = Color(0.3, 0.8, 4.0, 0.8) },
        { time = 0.7, color = Color(0.5, 3.0, 0.5, 0.5) },
        { time = 1.0, color = Color(1.0, 0.5, 2.0, 0.0) },
    },
}
-- 过载继电器弹道: 橙红电弧过载，高速旋转闪电
BULLET_VFX["overload_relay"] = {
    tex = TEX.pfx_lightning, tint = Color(4.0, 1.0, 0.1, 1), additive = true,
    maxParticles = 12, emitRate = 40, life = 0.10,
    sizeMin = 0.040, sizeMax = 0.085, shapeRadius = 0.035, gravity = 0, rotSpeed = 800,
    velMin = Vector3(-0.20, -0.20, -0.20), velMax = Vector3(0.20, 0.20, 0.20),
    colors = {
        { time = 0.0, color = Color(5.0, 2.0, 0.3, 1.0) },
        { time = 0.2, color = Color(4.0, 1.0, 0.1, 0.9) },
        { time = 0.5, color = Color(2.5, 0.5, 0.05, 0.6) },
        { time = 0.8, color = Color(1.2, 0.2, 0.0, 0.3) },
        { time = 1.0, color = Color(0.5, 0.1, 0.0, 0.0) },
    },
}
-- 注能弹药弹道: 金黄能量脉冲环，聚拢收束
BULLET_VFX["energy_ammo"] = {
    tex = TEX.circle, tint = Color(3.5, 2.8, 0.3, 1), additive = true,
    maxParticles = 12, emitRate = 38, life = 0.10,
    sizeMin = 0.025, sizeMax = 0.060, shapeRadius = 0.03, gravity = 0, rotSpeed = 360,
    velMin = Vector3(-0.14, -0.14, -0.14), velMax = Vector3(0.14, 0.14, 0.14),
    colors = {
        { time = 0.0, color = Color(4.5, 3.5, 0.5, 1.0) },
        { time = 0.2, color = Color(3.8, 2.8, 0.3, 0.9) },
        { time = 0.5, color = Color(2.5, 1.5, 0.1, 0.6) },
        { time = 0.8, color = Color(1.2, 0.8, 0.0, 0.2) },
        { time = 1.0, color = Color(0.5, 0.3, 0.0, 0.0) },
    },
}
-- 蓄力击弹道: 蓝紫蓄能光芒，逐渐聚拢收缩
BULLET_VFX["charged_hit"] = {
    tex = TEX.pfx_light_spark, tint = Color(0.4, 0.8, 4.5, 1), additive = true,
    maxParticles = 12, emitRate = 38, life = 0.14,
    sizeMin = 0.030, sizeMax = 0.070, shapeRadius = 0.025, gravity = 0, rotSpeed = 320,
    velMin = Vector3(-0.16, -0.16, -0.16), velMax = Vector3(0.16, 0.16, 0.16),
    colors = {
        { time = 0.0, color = Color(0.8, 1.2, 5.5, 1.0) },
        { time = 0.2, color = Color(0.5, 0.9, 4.5, 0.9) },
        { time = 0.5, color = Color(0.6, 0.6, 3.0, 0.6) },
        { time = 0.8, color = Color(0.4, 0.3, 1.8, 0.3) },
        { time = 1.0, color = Color(0.2, 0.2, 0.8, 0.0) },
    },
}
-- 反馈线圈弹道: 暗紫漩涡能量扭曲
BULLET_VFX["feedback_coil"] = {
    tex = TEX.pfx_dark_swirl, tint = Color(1.2, 0.2, 3.5, 1), additive = true,
    maxParticles = 12, emitRate = 36, life = 0.13,
    sizeMin = 0.035, sizeMax = 0.075, shapeRadius = 0.025, gravity = 0, rotSpeed = 600,
    velMin = Vector3(-0.14, -0.14, -0.14), velMax = Vector3(0.14, 0.14, 0.14),
    colors = {
        { time = 0.0, color = Color(1.5, 0.3, 5.0, 1.0) },
        { time = 0.2, color = Color(1.2, 0.2, 4.0, 0.9) },
        { time = 0.5, color = Color(0.8, 0.1, 2.8, 0.6) },
        { time = 0.8, color = Color(0.4, 0.05, 1.5, 0.3) },
        { time = 1.0, color = Color(0.2, 0.0, 0.6, 0.0) },
    },
}

-- ============================================================================
-- 弹道 Sprite Sheet 配置（附加到子弹节点，循环播放至子弹销毁）
-- size 比命中特效小很多（0.25-0.5m），避免遮挡子弹本体
-- ============================================================================
local BULLET_SHEET_VFX = {}

BULLET_SHEET_VFX["rapid_fire_module"] = {
    file="ParticleFX1/Sparks-Sheet.png", cols=3, rows=3, totalFrames=9,
    fps=24, size=0.30,
}
BULLET_SHEET_VFX["fire_seed"] = {
    file="ParticleFX1/Fire 1-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=24, size=0.40,
}
BULLET_SHEET_VFX["ice_crystal"] = {
    file="ParticleFX1/Blue Vortex-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=20, size=0.38,
}
BULLET_SHEET_VFX["corrosion"] = {
    file="ParticleFX1/Poison Cloud-Sheet.png", cols=4, rows=5, totalFrames=20,
    fps=18, size=0.35,
}

BULLET_SHEET_VFX["high_explosive"] = {
    file="ParticleFX1/Fire2-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=22, size=0.50,
}
BULLET_SHEET_VFX["crit_device"] = {
    file="ParticleFX1/Spark4-Sheet.png", cols=5, rows=6, totalFrames=30,
    fps=28, size=0.32,
}
BULLET_SHEET_VFX["elemental_core"] = {
    file="ParticleFX1/Blue Vortex 2-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=22, size=0.40,
}
BULLET_SHEET_VFX["overload_relay"] = {
    file="ParticleFX1/Eletric B-Sheet.png", cols=3, rows=3, totalFrames=9,
    fps=24, size=0.42,
}
BULLET_SHEET_VFX["energy_ammo"] = {
    file="ParticleFX1/Fire 3-Sheet.png", cols=4, rows=3, totalFrames=12,
    fps=22, size=0.38,
}
BULLET_SHEET_VFX["charged_hit"] = {
    file="ParticleFX1/Sparky Flame-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=22, size=0.40,
}
BULLET_SHEET_VFX["feedback_coil"] = {
    file="ParticleFX1/Spark1-Sheet.png", cols=5, rows=6, totalFrames=30,
    fps=28, size=0.30,
}

-- ============================================================================
-- 命中爆炸 VFX 配置（一次性爆发，TTL 到期后删节点）
-- ============================================================================
local HIT_VFX = {}

-- 连射模块命中: 密集金色火花四射
HIT_VFX["rapid_fire_module"] = {
    tex = TEX.pfx_sparks, tint = Color(3.5, 2.5, 0.3, 1), additive = true,
    maxParticles = 22, emitRate = 180, life = 0.20,
    sizeMin = 0.040, sizeMax = 0.090, shapeRadius = 0.08, gravity = 0.6, rotSpeed = 400,
    velMin = Vector3(-1.8, 0.3, -1.8), velMax = Vector3(1.8, 2.5, 1.8), ttl = 0.40,
    colors = {
        { time = 0.0, color = Color(5.0, 4.0, 0.8, 1.0) },
        { time = 0.2, color = Color(4.0, 3.0, 0.4, 0.9) },
        { time = 0.5, color = Color(2.5, 1.5, 0.2, 0.5) },
        { time = 0.8, color = Color(1.2, 0.6, 0.0, 0.2) },
        { time = 1.0, color = Color(0.4, 0.2, 0.0, 0.0) },
    },
}
-- 火种圣器命中: 火焰爆裂，大面积燃烧升腾
HIT_VFX["fire_seed"] = {
    tex = TEX.pfx_fire1, tint = Color(2.5, 1.0, 0.1, 1), additive = true,
    maxParticles = 26, emitRate = 200, life = 0.45,
    sizeMin = 0.100, sizeMax = 0.250, shapeRadius = 0.10, gravity = -0.5, rotSpeed = 120,
    velMin = Vector3(-1.6, 0.5, -1.6), velMax = Vector3(1.6, 3.0, 1.6), ttl = 0.70,
    colors = {
        { time = 0.0, color = Color(4.5, 2.5, 0.5, 1.0) },
        { time = 0.15, color = Color(4.0, 1.5, 0.2, 1.0) },
        { time = 0.4, color = Color(3.0, 0.8, 0.1, 0.7) },
        { time = 0.7, color = Color(1.5, 0.3, 0.0, 0.3) },
        { time = 1.0, color = Color(0.4, 0.08, 0.0, 0.0) },
    },
}
-- 冰晶圣器命中: 冰蓝碎冰爆裂+冰雾扩散
HIT_VFX["ice_crystal"] = {
    tex = TEX.pfx_icicle, tint = Color(0.7, 1.5, 4.0, 1), additive = true,
    maxParticles = 24, emitRate = 180, life = 0.45,
    sizeMin = 0.060, sizeMax = 0.140, shapeRadius = 0.10, gravity = 0.5, rotSpeed = 250,
    velMin = Vector3(-1.8, 0.3, -1.8), velMax = Vector3(1.8, 2.5, 1.8), ttl = 0.65,
    colors = {
        { time = 0.0, color = Color(1.5, 2.5, 6.0, 1.0) },
        { time = 0.15, color = Color(1.0, 2.0, 5.0, 1.0) },
        { time = 0.4, color = Color(0.6, 1.5, 3.5, 0.7) },
        { time = 0.7, color = Color(0.4, 1.0, 2.5, 0.3) },
        { time = 1.0, color = Color(0.2, 0.6, 1.5, 0.0) },
    },
}
-- 腐蚀圣器命中: 毒绿酸液飞溅+腐蚀烟雾
HIT_VFX["corrosion"] = {
    tex = TEX.pfx_toxic, tint = Color(0.5, 2.8, 0.2, 1), additive = true,
    maxParticles = 22, emitRate = 160, life = 0.50,
    sizeMin = 0.065, sizeMax = 0.150, shapeRadius = 0.09, gravity = 1.5, rotSpeed = 100,
    velMin = Vector3(-1.2, 0.3, -1.2), velMax = Vector3(1.2, 2.0, 1.2), ttl = 0.75,
    colors = {
        { time = 0.0, color = Color(0.6, 4.0, 0.4, 1.0) },
        { time = 0.2, color = Color(0.4, 3.2, 0.2, 0.9) },
        { time = 0.5, color = Color(0.3, 2.0, 0.15, 0.6) },
        { time = 0.8, color = Color(0.15, 1.0, 0.05, 0.3) },
        { time = 1.0, color = Color(0.05, 0.4, 0.0, 0.0) },
    },
}
HIT_VFX["thunder"] = {
    tex = TEX.pfx_eletric_exp, tint = Color(0.6, 0.4, 4.5, 1), additive = true,
    maxParticles = 22, emitRate = 180, life = 0.22,
    sizeMin = 0.100, sizeMax = 0.240, shapeRadius = 0.12, gravity = 0, rotSpeed = 600,
    velMin = Vector3(-2.2, -1.2, -2.2), velMax = Vector3(2.2, 2.2, 2.2), ttl = 0.45,
    colors = {
        { time = 0.0, color = Color(1.0, 0.8, 6.0, 1.0) },
        { time = 0.15, color = Color(0.8, 0.5, 5.0, 1.0) },
        { time = 0.4, color = Color(0.6, 0.3, 3.5, 0.7) },
        { time = 0.7, color = Color(0.4, 0.2, 2.0, 0.3) },
        { time = 1.0, color = Color(0.2, 0.1, 1.0, 0.0) },
    },
}
HIT_VFX["splinter"] = {
    tex = TEX.pfx_rock_break, tint = Color(2.2, 1.5, 0.5, 1), additive = true,
    maxParticles = 28, emitRate = 200, life = 0.50,
    sizeMin = 0.065, sizeMax = 0.140, shapeRadius = 0.10, gravity = 2.5, rotSpeed = 350,
    velMin = Vector3(-2.0, 0.8, -2.0), velMax = Vector3(2.0, 3.5, 2.0), ttl = 0.70,
    colors = {
        { time = 0.0, color = Color(3.0, 2.2, 0.8, 1.0) },
        { time = 0.2, color = Color(2.5, 1.6, 0.4, 0.9) },
        { time = 0.5, color = Color(1.5, 0.9, 0.2, 0.6) },
        { time = 0.8, color = Color(0.8, 0.5, 0.1, 0.3) },
        { time = 1.0, color = Color(0.3, 0.2, 0.05, 0.0) },
    },
}
HIT_VFX["piercing_core"] = {
    tex = TEX.pfx_sparks, tint = Color(2.0, 2.2, 4.0, 1), additive = true,
    maxParticles = 18, emitRate = 160, life = 0.18,
    sizeMin = 0.040, sizeMax = 0.090, shapeRadius = 0.04, gravity = 0, rotSpeed = 400,
    velMin = Vector3(-1.5, 0.5, -1.5), velMax = Vector3(1.5, 2.5, 1.5), ttl = 0.35,
    colors = {
        { time = 0.0, color = Color(3.0, 3.5, 6.0, 1.0) },
        { time = 0.15, color = Color(2.5, 2.8, 5.0, 1.0) },
        { time = 0.4, color = Color(1.5, 1.8, 3.5, 0.7) },
        { time = 0.7, color = Color(0.8, 1.0, 2.0, 0.3) },
        { time = 1.0, color = Color(0.3, 0.4, 1.0, 0.0) },
    },
}
HIT_VFX["sniper_mod"] = {
    tex = TEX.pfx_sparky_flame, tint = Color(3.5, 0.3, 0.1, 1), additive = true,
    maxParticles = 16, emitRate = 140, life = 0.25,
    sizeMin = 0.050, sizeMax = 0.120, shapeRadius = 0.03, gravity = 0, rotSpeed = 200,
    velMin = Vector3(-0.8, 0.2, -0.8), velMax = Vector3(0.8, 1.8, 0.8), ttl = 0.40,
    colors = {
        { time = 0.0, color = Color(5.0, 1.5, 0.5, 1.0) },
        { time = 0.15, color = Color(4.0, 0.5, 0.2, 1.0) },
        { time = 0.4, color = Color(3.0, 0.2, 0.1, 0.7) },
        { time = 0.7, color = Color(1.5, 0.1, 0.05, 0.3) },
        { time = 1.0, color = Color(0.5, 0.05, 0.02, 0.0) },
    },
}
-- 高爆圣器命中: 大范围火焰爆炸冲击波
HIT_VFX["high_explosive"] = {
    tex = TEX.pfx_fire_meteor, tint = Color(3.5, 1.5, 0.2, 1), additive = true,
    maxParticles = 36, emitRate = 250, life = 0.45,
    sizeMin = 0.150, sizeMax = 0.350, shapeRadius = 0.18, gravity = -0.2, rotSpeed = 180,
    velMin = Vector3(-2.5, -0.8, -2.5), velMax = Vector3(2.5, 3.5, 2.5), ttl = 0.80,
    colors = {
        { time = 0.0, color = Color(6.0, 4.0, 1.0, 1.0) },
        { time = 0.1, color = Color(5.0, 2.5, 0.3, 1.0) },
        { time = 0.3, color = Color(3.5, 1.2, 0.1, 0.8) },
        { time = 0.6, color = Color(2.0, 0.5, 0.05, 0.5) },
        { time = 0.85, color = Color(0.8, 0.2, 0.0, 0.2) },
        { time = 1.0, color = Color(0.3, 0.08, 0.0, 0.0) },
    },
}
-- 暴击装置命中: 金色星芒爆发+白色闪光核心
HIT_VFX["crit_device"] = {
    tex = TEX.pfx_star_shine, tint = Color(4.5, 3.5, 0.5, 1), additive = true,
    maxParticles = 20, emitRate = 160, life = 0.40,
    sizeMin = 0.080, sizeMax = 0.200, shapeRadius = 0.08, gravity = 0, rotSpeed = 500,
    velMin = Vector3(-1.6, 0.3, -1.6), velMax = Vector3(1.6, 2.8, 1.6), ttl = 0.60,
    colors = {
        { time = 0.0, color = Color(6.0, 5.5, 2.0, 1.0) },
        { time = 0.1, color = Color(5.5, 4.5, 0.8, 1.0) },
        { time = 0.3, color = Color(4.0, 3.0, 0.3, 0.8) },
        { time = 0.6, color = Color(2.5, 1.5, 0.1, 0.4) },
        { time = 0.85, color = Color(1.2, 0.6, 0.0, 0.15) },
        { time = 1.0, color = Color(0.4, 0.2, 0.0, 0.0) },
    },
}
-- 元素核心命中: 多元素交汇爆发，红蓝紫绿循环闪烁
HIT_VFX["elemental_core"] = {
    tex = TEX.pfx_eletric_aura, additive = true,
    maxParticles = 24, emitRate = 180, life = 0.38,
    sizeMin = 0.080, sizeMax = 0.180, shapeRadius = 0.12, gravity = 0, rotSpeed = 450,
    velMin = Vector3(-2.0, -0.6, -2.0), velMax = Vector3(2.0, 2.0, 2.0), ttl = 0.65,
    colors = {
        { time = 0.0, color = Color(5.0, 1.0, 0.3, 1.0) },
        { time = 0.15, color = Color(3.5, 0.5, 4.5, 1.0) },
        { time = 0.35, color = Color(0.5, 1.2, 5.0, 0.9) },
        { time = 0.55, color = Color(0.8, 4.0, 0.8, 0.7) },
        { time = 0.75, color = Color(3.0, 2.0, 0.3, 0.4) },
        { time = 1.0, color = Color(0.5, 0.5, 1.5, 0.0) },
    },
}
-- 过载继电器命中: 橙红电弧过载爆裂+火花飞溅
HIT_VFX["overload_relay"] = {
    tex = TEX.pfx_eletric_exp, tint = Color(4.5, 1.2, 0.2, 1), additive = true,
    maxParticles = 20, emitRate = 170, life = 0.25,
    sizeMin = 0.090, sizeMax = 0.200, shapeRadius = 0.12, gravity = 0, rotSpeed = 700,
    velMin = Vector3(-2.2, -1.2, -2.2), velMax = Vector3(2.2, 2.2, 2.2), ttl = 0.50,
    colors = {
        { time = 0.0, color = Color(6.0, 2.5, 0.5, 1.0) },
        { time = 0.15, color = Color(5.0, 1.5, 0.2, 1.0) },
        { time = 0.4, color = Color(3.0, 0.8, 0.1, 0.7) },
        { time = 0.7, color = Color(1.5, 0.3, 0.0, 0.3) },
        { time = 1.0, color = Color(0.5, 0.1, 0.0, 0.0) },
    },
}
-- 棱镜圣器命中: 七彩棱镜折射爆裂 — 彩虹光芒四射+白色闪光核心
HIT_VFX["prism"] = {
    tex = TEX.pfx_star_shine, tint = Color(2.0, 2.0, 2.0, 1), additive = true,
    maxParticles = 24, emitRate = 180, life = 0.35,
    sizeMin = 0.060, sizeMax = 0.150, shapeRadius = 0.08, gravity = -0.3, rotSpeed = 300,
    velMin = Vector3(-1.8, -0.5, -1.8), velMax = Vector3(1.8, 2.0, 1.8), ttl = 0.55,
    colors = {
        { time = 0.0, color = Color(4.0, 4.0, 5.0, 1.0) },
        { time = 0.1, color = Color(3.0, 1.0, 4.0, 1.0) },
        { time = 0.25, color = Color(1.0, 3.0, 4.0, 0.9) },
        { time = 0.45, color = Color(2.0, 3.5, 1.0, 0.7) },
        { time = 0.65, color = Color(3.5, 2.0, 0.5, 0.4) },
        { time = 0.85, color = Color(2.0, 0.5, 3.0, 0.2) },
        { time = 1.0, color = Color(0.5, 0.5, 1.0, 0.0) },
    },
}
-- 注能弹药命中: 金黄能量脉冲爆发+环形扩散
HIT_VFX["energy_ammo"] = {
    tex = TEX.circle, tint = Color(3.5, 2.8, 0.3, 1), additive = true,
    maxParticles = 20, emitRate = 160, life = 0.35,
    sizeMin = 0.065, sizeMax = 0.160, shapeRadius = 0.10, gravity = 0, rotSpeed = 400,
    velMin = Vector3(-1.8, -0.5, -1.8), velMax = Vector3(1.8, 2.0, 1.8), ttl = 0.55,
    colors = {
        { time = 0.0, color = Color(5.5, 4.5, 1.0, 1.0) },
        { time = 0.15, color = Color(4.5, 3.5, 0.5, 1.0) },
        { time = 0.4, color = Color(3.0, 2.0, 0.2, 0.7) },
        { time = 0.7, color = Color(1.5, 1.0, 0.05, 0.3) },
        { time = 1.0, color = Color(0.5, 0.3, 0.0, 0.0) },
    },
}
-- 蓄力击命中: 蓝紫能量集中释放+向心收缩后爆裂
HIT_VFX["charged_hit"] = {
    tex = TEX.pfx_light_spark, tint = Color(0.5, 0.9, 4.5, 1), additive = true,
    maxParticles = 22, emitRate = 170, life = 0.42,
    sizeMin = 0.075, sizeMax = 0.180, shapeRadius = 0.10, gravity = -0.3, rotSpeed = 380,
    velMin = Vector3(-1.8, 0.3, -1.8), velMax = Vector3(1.8, 2.8, 1.8), ttl = 0.65,
    colors = {
        { time = 0.0, color = Color(1.2, 1.8, 6.5, 1.0) },
        { time = 0.15, color = Color(0.8, 1.2, 5.5, 1.0) },
        { time = 0.35, color = Color(1.0, 0.8, 4.0, 0.8) },
        { time = 0.6, color = Color(0.6, 0.5, 2.5, 0.4) },
        { time = 0.85, color = Color(0.3, 0.3, 1.5, 0.15) },
        { time = 1.0, color = Color(0.15, 0.15, 0.6, 0.0) },
    },
}
-- 反馈线圈命中: 暗紫漩涡能量内爆+扭曲波纹扩散
HIT_VFX["feedback_coil"] = {
    tex = TEX.pfx_dark_swirl, tint = Color(1.2, 0.2, 3.5, 1), additive = true,
    maxParticles = 22, emitRate = 160, life = 0.48,
    sizeMin = 0.085, sizeMax = 0.200, shapeRadius = 0.12, gravity = 0, rotSpeed = 650,
    velMin = Vector3(-1.8, -0.6, -1.8), velMax = Vector3(1.8, 1.8, 1.8), ttl = 0.72,
    colors = {
        { time = 0.0, color = Color(2.0, 0.4, 6.0, 1.0) },
        { time = 0.15, color = Color(1.5, 0.3, 5.0, 1.0) },
        { time = 0.35, color = Color(1.0, 0.15, 3.5, 0.8) },
        { time = 0.6, color = Color(0.6, 0.08, 2.2, 0.5) },
        { time = 0.85, color = Color(0.3, 0.03, 1.2, 0.2) },
        { time = 1.0, color = Color(0.1, 0.0, 0.4, 0.0) },
    },
}

-- ============================================================================
-- Sprite Sheet 命中动画配置
-- 每帧修改 BillboardSet 的 UV 坐标来播放帧动画（替代粒子爆炸）
-- 字段: file=贴图相对路径, cols=列数, rows=行数, totalFrames=总帧数(可<cols*rows),
--       fps=帧率, size=世界空间大小(米), ttl=存活时间(自动=totalFrames/fps+buffer)
-- ============================================================================
local SHEET_VFX = {}

-- 快速火花（rapid_fire_module）: Sparks-Sheet 3x3=9帧
SHEET_VFX["rapid_fire_module"] = {
    file="ParticleFX1/Sparks-Sheet.png", cols=3, rows=3, totalFrames=9,
    fps=18, size=1.2,
}
-- 火焰命中（fire_seed）: Fire 1-Sheet 5x3=15帧
SHEET_VFX["fire_seed"] = {
    file="ParticleFX1/Fire 1-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=20, size=1.6,
}
-- 冰晶命中（ice_crystal）: Splash-Sheet 3x3=9帧（模拟冰碎溅射）
SHEET_VFX["ice_crystal"] = {
    file="ParticleFX1/Splash-Sheet.png", cols=3, rows=3, totalFrames=9,
    fps=16, size=1.4,
}
-- 腐蚀命中（corrosion）: Poison Cloud-Sheet 4x5=20帧
SHEET_VFX["corrosion"] = {
    file="ParticleFX1/Poison Cloud-Sheet.png", cols=4, rows=5, totalFrames=20,
    fps=18, size=1.5,
}

-- 高爆命中（high_explosive）: Fire2-Sheet 5x3=15帧
SHEET_VFX["high_explosive"] = {
    file="ParticleFX1/Fire2-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=20, size=2.2,
}
-- 暴击命中（crit_device）: Sparky Flame-Sheet 5x3=15帧
SHEET_VFX["crit_device"] = {
    file="ParticleFX1/Sparky Flame-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=18, size=1.4,
}
-- 元素命中（elemental_core）: Blue Vortex-Sheet 5x3=15帧
SHEET_VFX["elemental_core"] = {
    file="ParticleFX1/Blue Vortex-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=18, size=1.6,
}
-- 过载命中（overload_relay）: Eletric B-Sheet 3x3=9帧
SHEET_VFX["overload_relay"] = {
    file="ParticleFX1/Eletric B-Sheet.png", cols=3, rows=3, totalFrames=9,
    fps=18, size=1.8,
}
-- 能量弹药（energy_ammo）: Fire 3-Sheet 4x3=12帧
SHEET_VFX["energy_ammo"] = {
    file="ParticleFX1/Fire 3-Sheet.png", cols=4, rows=3, totalFrames=12,
    fps=18, size=1.4,
}
-- 充能命中（charged_hit）: Blue Vortex 2-Sheet 5x3=15帧
SHEET_VFX["charged_hit"] = {
    file="ParticleFX1/Blue Vortex 2-Sheet.png", cols=5, rows=3, totalFrames=15,
    fps=18, size=1.6,
}
-- 反馈线圈（feedback_coil）: Spark4-Sheet 5x6=30帧
SHEET_VFX["feedback_coil"] = {
    file="ParticleFX1/Spark4-Sheet.png", cols=5, rows=6, totalFrames=30,
    fps=24, size=1.2,
}

-- ============================================================================
-- 内部: 在世界坐标生成 Sprite Sheet Billboard 动画（面向相机，一次性播放）
-- ============================================================================
local function CreateSheetBillboard(scene, pos, cfg)
    local node = scene:CreateChild("SheetHitVFX")
    -- 命中位置稍微往上偏移，避免陷入地面/敌人底部
    node.position = Vector3(pos.x, pos.y + 0.4, pos.z)

    local bs = node:CreateComponent("BillboardSet")
    bs:SetNumBillboards(1)
    bs.faceCameraMode = FC_ROTATE_XYZ

    -- 加法混合（DiffAdd）：黑色像素贡献为零（等同透明），彩色叠加发光
    -- 所有 Sheet 文件均为黑底设计，必须用加法混合才可见
    local mat = Material:new()
    local tech = cache:GetResource("Technique", "Techniques/DiffAdd.xml")
    if not tech then
        tech = cache:GetResource("Technique", "Techniques/DiffUnlit.xml")
    end
    mat:SetTechnique(0, tech)
    local tex = cache:GetResource("Texture2D", cfg.file)
    if tex then
        mat:SetTexture(TU_DIFFUSE, tex)
    end
    mat:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    bs:SetMaterial(mat)

    -- 初始化第 0 帧（尺寸放大 1.8 倍，保证在塔防俯视角可见）
    local bbd    = bs:GetBillboard(0)
    local sz     = (cfg.size or 1.5) * 1.8
    bbd.size     = Vector2(sz, sz)
    local fw     = 1.0 / cfg.cols
    local fh     = 1.0 / cfg.rows
    bbd.uv       = Rect(0, 0, fw, fh)
    bbd.color    = Color(1, 1, 1, 1)
    bbd.enabled  = true
    bs:Commit()

    local ttl = (cfg.totalFrames / cfg.fps) + 0.08
    return { type="sheet", node=node, bs=bs, timer=0,
             fps=cfg.fps, cols=cfg.cols, rows=cfg.rows,
             totalFrames=cfg.totalFrames, ttl=ttl }
end

-- ============================================================================
-- 内部: 在子弹节点上创建循环播放的 Sprite Sheet Billboard（随子弹移动）
-- ============================================================================
local function CreateBulletSheetBillboard(projNode, cfg)
    local node = projNode:CreateChild("BulletSheetVFX")

    local bs = node:CreateComponent("BillboardSet")
    bs:SetNumBillboards(1)
    bs.faceCameraMode = FC_ROTATE_XYZ

    -- 加法混合：黑底 sheet 必须用 DiffAdd，黑色像素贡献为零
    local mat = Material:new()
    local tech = cache:GetResource("Technique", "Techniques/DiffAdd.xml")
    if not tech then
        tech = cache:GetResource("Technique", "Techniques/DiffUnlit.xml")
    end
    mat:SetTechnique(0, tech)
    local tex = cache:GetResource("Texture2D", cfg.file)
    if tex then
        mat:SetTexture(TU_DIFFUSE, tex)
    end
    mat:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    bs:SetMaterial(mat)

    local bbd = bs:GetBillboard(0)
    local sz  = (cfg.size or 0.4) * 1.8  -- 放大 1.8 倍增强可见性
    bbd.size  = Vector2(sz, sz)
    local fw  = 1.0 / cfg.cols
    local fh  = 1.0 / cfg.rows
    bbd.uv    = Rect(0, 0, fw, fh)
    bbd.color = Color(1, 1, 1, 1)
    bbd.enabled = true
    bs:Commit()

    -- 返回追踪条目（projNode 是父节点，随子弹销毁自动消失）
    return { projNode=projNode, bs=bs, timer=0,
             fps=cfg.fps, cols=cfg.cols, rows=cfg.rows, totalFrames=cfg.totalFrames }
end

-- 子弹 Sheet 动画追踪列表（节点销毁后在 Update 中自动清除）
local activeBulletSheets = {}

-- 命中特效待清理队列:
--   粒子型: { type="particle", node=Node, ttl=number }
--   Sheet型: { type="sheet", node=Node, bs=BillboardSet, timer=number,
--              fps=number, cols=number, rows=number, totalFrames=number, ttl=number }
local pendingRemovals = {}

--- 在飞行子弹上附加弹道特效（随子弹节点移动，子弹销毁时自动消失）
--- 优先使用 Sprite Sheet Billboard（BULLET_SHEET_VFX），无则回退到粒子拖尾（BULLET_VFX）
--- @param projNode Node
--- @param artifactId string
function M.SpawnBulletVFX(projNode, artifactId)
    if not projNode then return end

    -- 优先: Sprite Sheet 循环帧动画
    local sheetCfg = BULLET_SHEET_VFX[artifactId]
    if sheetCfg then
        local ok, entry = pcall(CreateBulletSheetBillboard, projNode, sheetCfg)
        if ok and entry then
            table.insert(activeBulletSheets, entry)
        else
            print(string.format("[ArtifactVFX] SpawnBulletSheet error (%s): %s", artifactId, tostring(entry)))
        end
        return
    end

    -- 回退: 粒子拖尾
    local cfg = BULLET_VFX[artifactId]
    if not cfg then return end
    local ok, err = pcall(CreateParticleNode, projNode, cfg)
    if not ok then
        print(string.format("[ArtifactVFX] SpawnBulletVFX error (%s): %s", artifactId, tostring(err)))
    end
end

--- 在命中位置生成一次性爆发特效
--- 优先使用 Sprite Sheet 帧动画（SHEET_VFX），无则回退到粒子爆炸（HIT_VFX）
--- @param scene Scene
--- @param hitPos Vector3
--- @param artifactId string
function M.SpawnHitVFX(scene, hitPos, artifactId)
    if not scene or not hitPos then return end

    -- 优先: Sprite Sheet Billboard 帧动画
    local sheetCfg = SHEET_VFX[artifactId]
    if sheetCfg then
        local ok, result = pcall(CreateSheetBillboard, scene, hitPos, sheetCfg)
        if ok and result then
            table.insert(pendingRemovals, result)
        else
            print(string.format("[ArtifactVFX] SpawnSheetHit error (%s): %s", artifactId, tostring(result)))
        end
        return  -- 有 sheet 就不再生成粒子
    end

    -- 回退: 粒子爆炸
    local cfg = HIT_VFX[artifactId]
    if not cfg then return end
    local ok, err = pcall(function()
        local node = scene:CreateChild("HitVFX_" .. artifactId)
        node.position = hitPos
        local oneShotCfg = {}
        for k, v in pairs(cfg) do oneShotCfg[k] = v end
        oneShotCfg.emitting = true
        CreateParticleNode(node, oneShotCfg)
        table.insert(pendingRemovals, { type="particle", node = node, ttl = cfg.ttl or 0.8 })
    end)
    if not ok then
        print(string.format("[ArtifactVFX] SpawnHitVFX error (%s): %s", artifactId, tostring(err)))
    end
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
    -- 更新子弹 Sheet 帧动画（循环播放，节点销毁后自动清除）
    local j = 1
    while j <= #activeBulletSheets do
        local e   = activeBulletSheets[j]
        local ok  = pcall(function()
            -- 尝试访问节点以检测是否已销毁
            local _ = e.projNode.scene
        end)
        if not ok or not e.projNode.scene then
            -- 子弹节点已被销毁，清除追踪条目
            table.remove(activeBulletSheets, j)
        else
            e.timer = e.timer + dt
            local frame = math.floor(e.timer * e.fps) % e.totalFrames
            local col   = frame % e.cols
            local row   = math.floor(frame / e.cols)
            local fw    = 1.0 / e.cols
            local fh    = 1.0 / e.rows
            local bbd   = e.bs:GetBillboard(0)
            bbd.uv      = Rect(col * fw, row * fh, (col + 1) * fw, (row + 1) * fh)
            e.bs:Commit()
            j = j + 1
        end
    end

    -- 更新/清理命中特效节点
    local i = 1
    while i <= #pendingRemovals do
        local entry = pendingRemovals[i]
        entry.ttl = entry.ttl - dt

        if entry.type == "sheet" then
            -- Sprite Sheet 帧动画：每帧更新 UV 坐标
            entry.timer = entry.timer + dt
            local frame = math.floor(entry.timer * entry.fps)
            if frame < entry.totalFrames then
                -- 计算当前帧的 UV Rect（UV 坐标 0-1 空间）
                local col  = frame % entry.cols
                local row  = math.floor(frame / entry.cols)
                local fw   = 1.0 / entry.cols
                local fh   = 1.0 / entry.rows
                local bbd  = entry.bs:GetBillboard(0)
                bbd.uv     = Rect(col * fw, row * fh, (col + 1) * fw, (row + 1) * fh)
                entry.bs:Commit()
            end
        end

        if entry.ttl <= 0 then
            if entry.node then
                if entry.type == "particle" then
                    local em = entry.node:GetComponent("ParticleEmitter")
                    if em then em:SetEmitting(false) end
                end
                entry.node:Remove()
            end
            table.remove(pendingRemovals, i)
        else
            i = i + 1
        end
    end
end

return M
