-- ============================================================
--  Infamy City - Lobotomite Round Type + Custom Loot Injections
--  Place in: garrysmod/addons/zcity_custom/lua/autorun/server/
-- ============================================================

--[[ hook.Add("PostGamemodeLoaded", "LobotomiteAndLoot_Register", function()
    local mode = zb and zb.modes and zb.modes["hmcd"]
    if not mode then
        print("[InfamyCity] ERROR: hmcd mode not found.")
        return
    end

    -- ══════════════════════════════════════════════════════════
    --  LOBOTOMITE ROUND TYPES
    -- ══════════════════════════════════════════════════════════

    -- ── Standard Lobotomite (small maps only, uncommon) ───────
    mode.Types.lobotomite = {
        Chance = 0.08,
        ChanceFunction = function()
            return (zb.GetWorldSize() < ZBATTLE_BIGMAP) and
                (zb.ModesChances["lobotomite"] or mode.Types.lobotomite.Chance) or 0
        end,
        LootTable = mode.Types.standard and mode.Types.standard.LootTable or nil,
        Messages = {
            [3] = "Something feels... wrong with the traitor.",
            [1] = "The lobotomite walks among you.",
            [0] = "The brainless killer was",
        },
        Message = "The lobotomite was ",
        TraitorLoot = function(ply)
            if ply.SetPlayerClass then ply:SetPlayerClass("Lobotomite") end
            ply:SetNWBool("IsBrainless", true)
            if ply.organism then ply.organism.IsBrainless = true end

            local wep = ply:Give("weapon_ak74")
            if IsValid(wep) then
                ply:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType(), true)
            end
            ply:Give("weapon_hg_machete")
            ply:Give("weapon_adrenaline")
            ply:Give("weapon_traitor_poison1")
            ply:Give("weapon_hg_smokenade_tpik")

            if ply.organism then ply.organism.stamina.max = 300 end

            local inv = ply:GetNetVar("Inventory")
            if inv then
                inv["Weapons"]["hg_flashlight"] = true
                ply:SetNetVar("Inventory", inv)
            end

            ply:ChatPrint("OVERRIDE: Your brain has been replaced with advanced Tesla-technology. You cannot register brain shock.")
        end,
        GunManLoot = mode.Types.standard and mode.Types.standard.GunManLoot or nil,
        PoliceTime    = 120,
        PoliceAllowed = true,
        SkillIssue    = 3,
        PoliceEquipment = mode.Types.standard and mode.Types.standard.PoliceEquipment or function() end,
    }

    -- ── SoE Lobotomite (big maps only, more common) ───────────
    mode.Types.lobotomite_soe = {
        Chance = 0.18,
        ChanceFunction = function()
            return (zb.GetWorldSize() >= ZBATTLE_BIGMAP) and
                (zb.ModesChances["lobotomite_soe"] or mode.Types.lobotomite_soe.Chance) or 0
        end,
        LootTable = mode.Types.soe and mode.Types.soe.LootTable or nil,
        Messages = {
            [3] = "A state of emergency has been declared. The threat is... inhuman.",
            [1] = "The lobotomite cannot be stopped by conventional means.",
            [0] = "The brainless horror was",
        },
        Message = "The abomination was ",
        TraitorLoot = function(ply)
            if ply.SetPlayerClass then ply:SetPlayerClass("Lobotomite") end
            ply:SetNWBool("IsBrainless", true)
            if ply.organism then ply.organism.IsBrainless = true end

            local wep = ply:Give("weapon_m249")
            if IsValid(wep) then
                ply:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType(), true)
            end
            ply:Give("weapon_hg_axe")
            ply:Give("weapon_adrenaline")
            ply:Give("weapon_traitor_poison1")
            ply:Give("weapon_traitor_poison2")
            ply:Give("weapon_hg_smokenade_tpik")
            ply:Give("weapon_traitor_ied")

            if ply.organism then ply.organism.stamina.max = 400 end

            local inv = ply:GetNetVar("Inventory")
            if inv then
                inv["Weapons"]["hg_flashlight"] = true
                ply:SetNetVar("Inventory", inv)
            end

            ply:ChatPrint("OVERRIDE: Your brain has been replaced with advanced Tesla-technology. Maximum combat mode engaged.")
        end,
        GunManLoot    = mode.Types.soe and mode.Types.soe.GunManLoot or nil,
        PoliceTime    = 90,
        PoliceAllowed = true,
        SkillIssue    = 5,
        PoliceEquipment = mode.Types.soe and mode.Types.soe.PoliceEquipment or function() end,
    }

    -- gunfreezone: no lobotomite, enforced by simply not defining it there
    print("[InfamyCity] Lobotomite round types registered.")

    -- ══════════════════════════════════════════════════════════
    --  CUSTOM LOOT INJECTIONS
    --  standard/wildwest/gunfreezone all share LootTableStandard
    --  soe uses LootTable
    --  Pool 1 = medicals/melee (index 1)
    --  Pool 2 = weapons (index 2)
    -- ══════════════════════════════════════════════════════════

    -- Helper: safely insert weapons into a loot pool
    local function Inject(tbl, poolIndex, weapons)
        if not tbl then return end
        local pool = tbl[poolIndex]
        if not pool or not pool[2] then return end
        for _, entry in ipairs(weapons) do
            table.insert(pool[2], entry)
        end
    end

    local standard = mode.Types.standard and mode.Types.standard.LootTable
    local soe      = mode.Types.soe      and mode.Types.soe.LootTable

    -- ── Standard/Wildwest/GunFreeZone: melee pool injections ──
    Inject(standard, 2, {
        -- New melees from the mod
        {0.18, "weapon_hg_spear_knife"},
        {0.15, "weapon_hg_kukri"},
        {0.14, "weapon_kabar"},
        {0.12, "weapon_sogknife"},
        {0.10, "weapon_tomahawk"},
        {0.09, "weapon_hg_cleaver"},
        {0.08, "weapon_hg_pitchfork"},
        {0.07, "weapon_hg_fireaxe"},
        {0.06, "weapon_gymnasticstick"},
        {0.05, "weapon_golfclub"},
        {0.05, "weapon_pan"},
        {0.04, "weapon_hg_shovel"},
        {0.04, "weapon_screwdriver"},
        {0.03, "weapon_drill"},
        {0.03, "weapon_hg_tonfa"},
        {0.02, "weapon_hg_fubar"},
        {0.02, "weapon_hg_wrench"},
        {0.01, "weapon_hg_sledgehammer"},
        -- Throwing weapons (rare finds)
        {0.08, "weapon_hg_shuriken"},
        {0.05, "weapon_tomahawkasspocket"},
    })

    -- ── SoE: melee pool injections ────────────────────────────
    Inject(soe, 2, {
        {0.5,  "weapon_hg_spear_knife"},
        {0.4,  "weapon_hg_kukri"},
        {0.4,  "weapon_kabar"},
        {0.35, "weapon_sogknife"},
        {0.3,  "weapon_tomahawk"},
        {0.3,  "weapon_hg_cleaver"},
        {0.25, "weapon_hg_pitchfork"},
        {0.2,  "weapon_hg_fireaxe"},
        {0.15, "weapon_gymnasticstick"},
        {0.1,  "weapon_pan"},
        {0.1,  "weapon_hg_shovel"},
        {0.08, "weapon_hg_shuriken"},
    })

    -- ── SoE: weapon pool injections (pool 7 = rifles/heavy) ───
    -- SoE pool index 7 is the rare rifles pool
    Inject(soe, 7, {
        -- New rifles from the mod
        {3,   "weapon_lr300"},
        {3,   "weapon_ak101"},
        {3,   "weapon_ak12"},
        {3,   "weapon_ak103d"},
        {3,   "weapon_ak104d"},
        {3,   "weapon_ak105d"},
        {3,   "weapon_ak200"},
        {3,   "weapon_ak203"},
        {2,   "weapon_m16a4"},
        {2,   "weapon_hk416"},
        {2,   "weapon_scarl"},
        {2,   "weapon_scarh"},
        {2,   "weapon_fnfalpara"},
        {2,   "weapon_fnfal"},
        {2,   "weapon_mat49"},
        {2,   "weapon_mp5sd"},
        {2,   "weapon_vz58"},
        {2,   "weapon_sa58"},
        {2,   "weapon_rfb"},
        {1,   "weapon_ksvk"},
        {1,   "weapon_psg1"},
        {1,   "weapon_sakosnip"},
        {1,   "weapon_barret82"},
        {1,   "weapon_m98b"},
        {1,   "weapon_dsr1"},
        {1,   "weapon_t5000"},
        {1,   "weapon_cs5"},
        -- LMGs
        {2,   "weapon_m60"},
        {2,   "weapon_rpk"},
        {2,   "weapon_pkm"},
        {2,   "weapon_m249"},
        {1,   "weapon_stonerlmg"},
        {1,   "weapon_hk21"},
        {1,   "weapon_dp27"},
        {1,   "weapon_rpd"},
        -- Laser rifle (very rare)
        {0.5, "weapon_laserrifle_fo4"},
    })

    -- ── SoE: pistol pool (pool 4) ─────────────────────────────
    Inject(soe, 4, {
        {4,   "weapon_tticglock"},
        {4,   "weapon_glock22"},
        {4,   "weapon_glock26"},
        {3,   "weapon_grach"},
        {3,   "weapon_pl15"},
        {3,   "weapon_browninghp"},
        {3,   "weapon_p38"},
        {3,   "weapon_tokarev"},
        {2,   "weapon_conan357"},
        {2,   "weapon_python"},
        {2,   "weapon_revolverequiem"},
        {2,   "weapon_m712"},
        {1,   "weapon_deagle"},
        {1,   "weapon_zoraki"},
    })

    -- ── Wildwest: override to add period-appropriate extras ───
    -- wildwest shares LootTableStandard so we inject into standard
    -- but we also add a special hook for wildwest-only spawns
    hook.Add("ZB_StartRound", "WildwestExtraWeapons", function()
        if zb.CROUND ~= "hmcd" then return end
        local hmcd = zb.modes["hmcd"]
        if not hmcd or hmcd.Type ~= "wildwest" then return end

        -- Give every player a chance at a period weapon on top of normal loot
        for _, ply in player.Iterator() do
            if ply.isTraitor then continue end
            if math.random(3) == 1 then
                local periodWeapons = {
                    "weapon_bleeding_musket",
                    "weapon_yellowboy",
                    "weapon_winchester",
                    "weapon_flintlock",
                    "weapon_musket",
                    "weapon_mosin",
                    "weapon_kar98",
                }
                ply:Give(periodWeapons[math.random(#periodWeapons)])
            end
        end
    end)

    print("[InfamyCity] Loot table injections applied.")
end)
]]
