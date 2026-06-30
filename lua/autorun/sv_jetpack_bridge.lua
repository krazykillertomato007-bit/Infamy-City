-- ============================================================
--  UNSC Jetpack + Z-City Compatibility Bridge
--  lua/autorun/server/sv_jetpack_bridge.lua
-- ============================================================

if CLIENT then return end

-- Track which players are wearing/using a jetpack so we can
-- suppress fall damage from the abrupt thrust cutoff.
local jetpackUsers = {}

hook.Add("PostGamemodeLoaded", "JetpackBridge_Init", function()

    -- Detect when a player equips/activates the jetpack entity
    -- (jetpack_base / mk1 networks "Active" as a bool)
    hook.Add("Think", "JetpackBridge_Track", function()
        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end

            local wep = ply:GetActiveWeapon()
            local usingJet = false

            -- Check worn entities for an active jetpack
            local jet = ply.Jetpack or (IsValid(wep) and wep.Jetpack)
            if IsValid(jet) and jet.GetActive and jet:GetActive() then
                usingJet = true
            end

            if usingJet then
                jetpackUsers[ply] = CurTime()
            end
        end
    end)

    -- Suppress fall-damage related leg fractures shortly after
    -- jetpack use cuts off, since the engine drops you fast
    hook.Add("EntityTakeDamage", "JetpackBridge_NoFallBreak", function(ent, dmginfo)
        if not IsValid(ent) or not ent:IsPlayer() then return end
        if not dmginfo:IsDamageType(DMG_FALL) then return end

        local lastJetTime = jetpackUsers[ent]
        if lastJetTime and (CurTime() - lastJetTime) < 2 then
            -- Within 2 seconds of jetpack use - cushion the landing
            dmginfo:ScaleDamage(0.1)
        end
    end)

    -- Z-City "fake system" (fake ragdoll/third person body) compatibility:
    -- the jetpack entity attaches to the player's physical body, which can
    -- desync from the fake render position. Force a re-sync after landing.
    hook.Add("PlayerNoClip", "JetpackBridge_FakeSync", function(ply)
        -- placeholder hook point, no-op currently, kept for future use
    end)

    print("[JetpackBridge] Z-City jetpack compatibility loaded.")
end)

-- Clean up tracking table on disconnect
hook.Add("PlayerDisconnected", "JetpackBridge_Cleanup", function(ply)
    jetpackUsers[ply] = nil
end)
