
local MODE = MODE

MODE.MapSize       = 7500
MODE.ZoneTimeToShrink = 120   -- seconds for the ring to fully close after combat starts
MODE.LOOT_PHASE_DURATION = 60 -- seconds of looting before combat unlocks

-- Zone radius follows the same formula as DM, but the clock doesn't start until
-- ROUND_START + LOOT_PHASE_DURATION (i.e. after the loot phase ends).
function MODE.GetZoneRadius()
    if not zonedistance or not isnumber(zonedistance) then return 0xFFFFFFFF end
    local dist = zonedistance + 2048

    -- How far we are into the shrinking phase (0 = just started, 1 = fully closed)
    local combatStart = (zb.ROUND_START or 0) + MODE.LOOT_PHASE_DURATION
    local elapsed     = math.max(CurTime() - combatStart, 0)
    local frac        = math.max(1 - (elapsed / MODE.ZoneTimeToShrink), 0.025)

    return dist * frac
end

-- Block attacks AND weapon draws during the loot phase
function MODE:HG_MovementCalc_2(mul, ply, cmd, mv)
    local lootPhaseEnd = (zb.ROUND_START or 0) + MODE.LOOT_PHASE_DURATION
    if CurTime() < lootPhaseEnd and cmd then
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
        if mv then
            mv:RemoveKey(IN_ATTACK)
            mv:RemoveKey(IN_ATTACK2)
        end
        -- Keep hands selected so nothing can be accidentally fired
        if IsValid(ply) and IsValid(ply:GetWeapon("weapon_hands_sh")) then
            cmd:SelectWeapon(ply:GetWeapon("weapon_hands_sh"))
            if SERVER then ply:SelectWeapon("weapon_hands_sh") end
        end
    end
end

-- No leg-attacks during loot phase either
function MODE:PlayerCanLegAttack(ply)
    if CurTime() < (zb.ROUND_START or 0) + MODE.LOOT_PHASE_DURATION then
        return false
    end
    return true -- Explicitly allow leg attacks once combat begins
end
