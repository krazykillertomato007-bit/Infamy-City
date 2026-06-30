local MODE = MODE

MODE.name        = "expie_dm"
MODE.PrintName   = "Expie Deathmatch"
MODE.LootSpawn   = true   -- re-use the map's existing loot containers
MODE.GuiltDisabled = true
MODE.randomSpawns  = true
MODE.ForBigMaps    = false
MODE.Chance        = 0.04

util.AddNetworkString("expie_dm_start")
util.AddNetworkString("expie_dm_end")
util.AddNetworkString("expie_dm_combat_start") -- fired when loot phase ends

function MODE:CanLaunch()
    return true
end

-- Class assignment is handled in MODE:RoundStart() via hg.SetPlayerClass —
-- removed the duplicate PlayerSpawn hook that was racing it and double-firing
-- CLASS.On (causing appearance/bodygroup resets mid-round).

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function MakeDissolver(ent, position, dissolveType)
    local d = ents.Create("env_entity_dissolver")
    timer.Simple(5, function() if IsValid(d) then d:Remove() end end)
    if not IsValid(d) then return end
    d.Target = "edm_dissolve" .. ent:EntIndex()
    d:SetKeyValue("dissolvetype", dissolveType)
    d:SetKeyValue("magnitude", 0)
    d:SetPos(position)
    
    -- Fixed: Only set physics attacker if the entity is actually a valid player
    if IsValid(ent) and ent:IsPlayer() then
        d:SetPhysicsAttacker(ent)
    end
    
    d:Spawn()
    ent:SetName(d.Target)
    ent:Fire("Open")
    d:Fire("Dissolve", d.Target, 0)
    d:Fire("Kill", "", 0.1)
    return d
end

-- ─── Intermission (called by round system just before RoundStart) ─────────────

function MODE:Intermission()
    game.CleanUpMap()

    local poses = {}
    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        ply:SetupTeam(0)
        table.insert(poses, ply:GetPos())
    end

    local centerpoint = Vector(0, 0, 0)
    for _, pos in ipairs(poses) do centerpoint:Add(pos) end
    if #poses > 0 then centerpoint:Div(#poses) end

    local dist = 0
    for _, pos in ipairs(poses) do
        local d = pos:Distance(centerpoint)
        if d > dist then dist = d end
    end

    zonepoint    = centerpoint
    zonedistance = dist

    net.Start("expie_dm_start")
        net.WriteVector(zonepoint)
        net.WriteFloat(zonedistance)
    net.Broadcast()
end

-- ─── Round Start ─────────────────────────────────────────────────────────────

function MODE:RoundStart()
    for _, ply in player.Iterator() do
        if not ply:Alive() then continue end

        -- Force expie playerclass
        if hg and hg.SetPlayerClass then
            hg.SetPlayerClass(ply, "expie", {instant = true})
        end

        ply:SetSuppressPickupNotices(true)
        ply.noSound = true

        -- Give hands only – weapons come from looting
        ply:Give("weapon_hands_sh")

        -- Sling so dropped weapons can be picked up
        local inv = ply:GetNetVar("Inventory")
        if inv and inv["Weapons"] then
            inv["Weapons"]["hg_sling"] = true
            ply:SetNetVar("Inventory", inv)
        end

        -- Give walkie-talkie so they can at least communicate
        ply:Give("weapon_walkie_talkie")
        ply:SelectWeapon("weapon_hands_sh")

        -- Slightly reduced recoil (expie instinct)
        if ply.organism then ply.organism.recoilmul = 0.65 end

        timer.Simple(0.1, function() if IsValid(ply) then ply.noSound = false end end)
        ply:SetSuppressPickupNotices(false)

        zb.GiveRole(ply, "Experiment", Color(200, 170, 20))
        ply:SetNetVar("CurPluv", "pluvboss")
    end

    -- Schedule the "combat starts" announcement
    timer.Create("ExpiedmCombatStart", MODE.LOOT_PHASE_DURATION, 1, function()
        net.Start("expie_dm_combat_start")
        net.Broadcast()

        -- Give a melee weapon to anyone who found absolutely nothing
        for _, ply in player.Iterator() do
            if not ply:Alive() then continue end
            local hasWeapon = false
            for _, wep in ipairs(ply:GetWeapons()) do
                local c = wep:GetClass()
                if c ~= "weapon_hands_sh" and c ~= "weapon_walkie_talkie" then
                    hasWeapon = true
                    break
                end
            end
            if not hasWeapon then
                ply:Give("weapon_pocketknife")
            end
        end
    end)
end

-- ─── Round End ────────────────────────────────────────────────────────────────

function MODE:ShouldRoundEnd()
    return (#zb:CheckAlive(true) <= 1)
end

function MODE:EndRound()
    timer.Remove("ExpiedmCombatStart")

    local playersharm = {}
    for ply, tbl in pairs(zb.HarmDone) do
        for attacker, harm in pairs(tbl) do
            playersharm[attacker] = (playersharm[attacker] or 0) + harm
        end
    end

    local mvp, curharm = nil, 0
    for ply, harm in pairs(playersharm) do
        if harm > curharm then mvp = ply ; curharm = harm end
    end

    timer.Simple(2, function()
        net.Start("expie_dm_end")
        local winner = zb:CheckAlive(true)[1]

        if IsValid(winner) then
            winner:GiveExp(math.random(150, 200))
            winner:GiveSkill(math.Rand(0.2, 0.3))
        end
        if IsValid(mvp) then
            mvp:GiveExp(math.random(150, 200))
            mvp:GiveSkill(math.Rand(0.2, 0.3))
        end

        net.WriteEntity(IsValid(winner) and winner:Alive() and winner or NULL)
        net.WriteEntity(IsValid(mvp) and mvp or NULL)
        net.Broadcast()
    end)
end

function MODE:PlayerDeath(ply)
    if zb.ROUND_STATE == 1 then
        ply:GiveSkill(-0.1)
    end
end

-- ─── Zone Think (only active after loot phase) ────────────────────────────────

local zoneCooldown = 0

hook.Add("Think", "expie_dm_zone", function()
    local rnd = CurrentRound()
    if not rnd or rnd.name ~= "expie_dm" then return end
    
    -- Safety check: Ensure zonepoint exists
    if not zonepoint or not isvector(zonepoint) then return end

    local combatStart = (zb.ROUND_START or 0) + MODE.LOOT_PHASE_DURATION
    if CurTime() < combatStart then return end
    if CurTime() < zoneCooldown then return end
    zoneCooldown = CurTime() + 0.5

    local pos      = zonepoint
    local radius   = MODE.GetZoneRadius()
    local radiusSqr = radius * radius

    for _, ent in ents.Iterator() do
        if pos:DistToSqr(ent:GetPos()) > radiusSqr then
            if ent:IsPlayer() then
                hg.LightStunPlayer(ent)
                continue
            end

            if hgIsDoor(ent) then
                if not ent:GetNoDraw() then hgBlastThatDoor(ent) end
                continue
            end

            if string.find(ent:GetClass(), "prop_") and not hg.expItems[ent:GetModel()] then
                MakeDissolver(ent, ent:GetPos(), 0)
            end
        end
    end
end)

-- ─── Stubs required by the round system ──────────────────────────────────────

function MODE:GiveWeapons()   end
function MODE:GiveEquipment() end
function MODE:RoundThink()    end
function MODE:CanSpawn()      end

MODE.LootTable = {
		{12,"weapon_bigconsumable"},
		{8,"weapon_tourniquet"},
		{8,"weapon_bandage_sh"},
		{7,"weapon_ducttape"},
		{6,"weapon_painkillers"},
		{5,"weapon_bloodbag"},
		{4,"weapon_walkie_talkie"},
		{3,"hg_flashlight"},
		{3,"weapon_bigbandage_sh"},
		{2,"weapon_medkit_sh"},
	{50, {
		{4,"weapon_leadpipe"},
		{3,"weapon_hg_crowbar"},
		{2,"weapon_tomahawk"},
		{2,"weapon_hatchet"},
		{1,"weapon_hg_axe"},
		{1,"weapon_hg_crossbow"},
	}},
	{50, {
		{9,"*ammo*"},
		{9,"weapon_hk_usp"},
		{8,"weapon_revolver357"},
		{8,"weapon_deagle"},
		{8,"weapon_doublebarrel_short"},
		{8,"weapon_doublebarrel"},
		{8,"weapon_remington870"},
		{8,"weapon_glock18c"},
		{7,"weapon_mp5"},
		{6,"weapon_xm1014"},

		{6,"ent_armor_vest3"},
		{5,"ent_armor_helmet1"},

		{5,"weapon_mp7"},
		{5,"weapon_sks"},

		{5,"weapon_dr_meth"},

		{5,"weapon_hg_molotov_tpik"},
		{5,"weapon_hg_pipebomb_tpik"},
		{5,"weapon_claymore"},
		{5,"weapon_hg_f1_tpik"},
		{5,"weapon_traitor_ied"},
		{5,"weapon_hg_slam"},
		{5,"weapon_hg_legacy_grenade_shg"},
		{5,"weapon_hg_grenade_tpik"},

		{5,"weapon_ptrd"},
		{1,"weapon_fury13"},
		{9,"weapon_fury16"},
		{5,"weapon_akm"},
		{5,"a202"},
		{5,"weapon_hk21"},
		{5,"weapon_m98b"},
		{2,"weapon_hg_rpg"},
		{3,"weapon_sr25"},
	}},
}
