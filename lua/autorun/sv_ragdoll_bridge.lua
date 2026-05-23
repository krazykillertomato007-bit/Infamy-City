-- Bridge Zippy's Active Ragdoll system with Z-City's damage hook
hook.Add("PostEntityTakeDamage", "ZippyRagdoll_ZCityBridge", function(ent, dmginfo, took)
    if not IsValid(ent) then return end
    if not ent:IsNPC() then return end
    if not took then return end
    if ent:IsPlayer() then return end

    -- Respect the enabled convar
    local enabled = GetConVar("active_ragdoll_enabled")
    if not enabled or not enabled:GetBool() then return end

    -- Cooldown check
    if ent._lastRagdollTime and CurTime() - ent._lastRagdollTime < (GetConVar("active_ragdoll_cooldown"):GetInt()) then return end

    local dmg = dmginfo:GetDamage()
    local dmgType = dmginfo:GetDamageType()

    -- Always ragdoll on explosion, burn, crush if convars say so
    local alwaysExplode = GetConVar("active_ragdoll_always_on_explosion")
    local alwaysBurn    = GetConVar("active_ragdoll_always_on_burn")
    local alwaysCrush   = GetConVar("active_ragdoll_always_on_crush")

    local forceRagdoll = false
    if alwaysExplode and alwaysExplode:GetBool() and bit.band(dmgType, DMG_BLAST) ~= 0 then forceRagdoll = true end
    if alway