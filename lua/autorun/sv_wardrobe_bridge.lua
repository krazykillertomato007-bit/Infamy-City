-- ============================================================
--  Wardrobe (Sappy Edition) + Z-City VIP Bridge
--  lua/autorun/server/sv_wardrobe_bridge.lua
-- ============================================================
--[[ Will come back to this, IG

if CLIENT then return end

hook.Add("PostGamemodeLoaded", "WardrobeBridge_Init", function()

    hook.Add("Wardrobe_AccessAllowed", "ZCity_WardrobeGate", function(ply)
        if zb and zb.ROUND_STATE == 1 then
            return false, "Wardrobe is disabled during active rounds."
        end
        if not ply:IsUserGroup("trustedvip")
        and not ply:IsAdmin()
        and not ply:IsSuperAdmin() then
            return false, "Wardrobe is a TrustedVIP feature."
        end
    end)

    hook.Add("PlayerInitialSpawn", "WardrobeBridge_VIPNotify", function(ply)
        timer.Simple(8, function()
            if not IsValid(ply) then return end
            if ply:IsUserGroup("trustedvip")
            or ply:IsAdmin()
            or ply:IsSuperAdmin() then
                ply:ChatPrint("[VIP] Type !wardrobe in chat to open the model selector. (Available between rounds only)")
            end
        end)
    end)

    print("[WardrobeBridge] Wardrobe Sappy Edition VIP gate active.")
end) --]]

print("yay. so garbage!")
end
