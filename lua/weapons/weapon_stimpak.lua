if SERVER then AddCSLuaFile() end

-- Use the same standard medical weapon base configuration as your system's items
SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Stimpak"
SWEP.Instructions = "An old-world tactical military stimulant syringe. Accelerates immediate wound clotting and delivers a surge of pain-nullifying chemicals. Warning: Causes deep metabolic exhaustion when the cocktail wears off."
SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
-- Using the standard adrenaline model style used by other combat syringes in your code
SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_adrenaline.mdl"

if CLIENT then
    -- Set up custom weapon selector display parameters
    SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_morphine")
    SWEP.IconOverride = "vgui/wep_jack_hmcd_morphine.png"
    SWEP.BounceWeaponIcon = false
end

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 2
SWEP.WorkWithFake = true

-- Positioning vectors matching your framework's weapon alignment metrics
SWEP.offsetVec = Vector(3, -2.5, -1)
SWEP.offsetAng = Angle(-30, 20, -90)
SWEP.ModelScale = 0.7
SWEP.Color = Color(200, 50, 50) -- Crimson fluid color identifier

-- Single functional option mode
SWEP.modes = 1
SWEP.modeNames = {
    [1] = "inject stimpak"
}

function SWEP:InitializeAdd()
    self:SetHold(self.HoldType)
    -- Configured with exactly 1 charge capacity
    self.modeValues = {
        [1] = 1
    }
end

SWEP.modeValuesdef = {
    [1] = {1, false}
}
SWEP.ShouldDeleteOnFullUse = true

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

function SWEP:Think()
    -- Smoothly decrease the bone animation parameter if the key is released
    if not self:GetOwner():KeyDown(IN_ATTACK) and hg_healanims:GetBool() then
        self:SetHolding(math.max(self:GetHolding() - 12, 0))
    end
end

function SWEP:Animation()
    local owner = self:GetOwner()
    if (owner.zmanipstart ~= nil and not owner.organism.larmamputated) then return end

    local hold = self:GetHolding()
    -- Mirroring structural arm lifting parameters from your medical animations
    self:BoneSet("r_upperarm", vector_origin, Angle(0, -hold + (100 * (hold / 100)), 0))
    self:BoneSet("r_forearm", vector_origin, Angle(-hold / 6, -hold * 2, -15))
end

function SWEP:OwnerChanged()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:IsNPC() then
        self:SpawnGarbage()
        self:NPCHeal(owner, 0.5, "snd_jack_hmcd_needleprick.wav")
    end
end

if SERVER then
    function SWEP:Heal(ent, mode)
        if ent:IsNPC() then
            self:SpawnGarbage()
            self:NPCHeal(ent, 0.5, "snd_jack_hmcd_needleprick.wav")
            return
        end

        local org = ent.organism
        if not org then return end

        if self.modeValues[1] <= 0 then return end

        local owner = self:GetOwner()
        -- Handle animations matching your system constraints
        if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
            self:SetHolding(math.min(self:GetHolding() + 50, 100))
            if self:GetHolding() < 100 then return end
        end

        local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
        
        -----------------------------------------------------------------
        -- BIOMEDICAL ACTION CODE
        -----------------------------------------------------------------
        -- Play old-world injection hydraulic pressure sounds
        entOwner:EmitSound("snd_jack_hmcd_needleprick.wav", 75, 95)
        entOwner:EmitSound("snds_jack_gmod/ez_medical/15.wav", 65, 110)

        -- 1. Pain Blockers & Shock Reset
        -- Add into analgesiaAdd pool, mirroring the behavior found in medkit_sh.lua
        org.analgesiaAdd = math.min(org.analgesiaAdd + 1.8, 4)
        org.painkiller = math.min(org.painkiller + 2.0, 4)
        org.shock = math.max(org.shock - 200, 0) -- Drop shock points to avoid knockouts

        -- 2. Vascular Clotting & Blood Refill
        org.blood = math.min(org.blood + 500, 5000) -- Instant volume correction

        -- Process wound tables if registered on the player character model
        if ent:GetNetVar("wounds") then
            local currentWounds = ent:GetNetVar("wounds")
            if #currentWounds > 0 then
                local closedWounds = {}
                for _, wound in ipairs(currentWounds) do
                    -- Mitigate external bleed factors
                    if wound.amount then wound.amount = wound.amount * 0.25 end
                    if wound.bleed then wound.bleed = wound.bleed * 0.15 end
                    if wound.amount and wound.amount > 0.05 then
                        table.insert(closedWounds, wound)
                    end
                end
                ent:SetNetVar("wounds", closedWounds)
            end
        end

        -- Clear raw generic wound counters from internal modules
        org.bulletwounds = math.max(org.bulletwounds - 2, 0)
        org.slashwounds = math.max(org.slashwounds - 2, 0)
        org.stabwounds = math.max(org.stabwounds - 2, 0)

        -- 3. Combat Stimulant Pulse (Triggers your custom post-processing effect shaders)
        org.noradrenaline = math.min(org.noradrenaline + 1.5, 4)
        org.adrenalineAdd = math.min(org.adrenalineAdd + 2.0, 4)

        -- 4. The Crash Cycle Delay (Metabolic Drawback)
        local targetPly = ent
        local targetUID = targetPly:UserID()
        local timerName = "Stimpak_Crash_ZCity_" .. targetUID

        -- Stop any active crash timer if they chain-inject multiple stimpaks
        if timer.Exists(timerName) then timer.Remove(timerName) end

        timer.Create(timerName, 15, 1, function()
            if IsValid(targetPly) and targetPly:Alive() and targetPly.organism then
                local o = targetPly.organism
                
                -- Force visual/audio post-process disorientation tracking variables
                o.disorientation = math.min(o.disorientation + 30, 100)
                
                -- Heavy nutrition cost drain matching your sv_metabolism.lua loops
                if o.hungry then
                    o.hungry = math.min(o.hungry + 25, 100)
                end

                -- Exhaust the stamina array
                if o.stamina and o.stamina[1] then
                    o.stamina[1] = math.max(o.stamina[1] - 100, 0)
                end

                targetPly:EmitSound("player/breathe1.wav", 65, 85)
                targetPly:Notify("The stimpak's stimulant effects have collapsed... I feel incredibly drained.", true, "stimpak_crash", 5)
            end
        end)

        -- Consume weapon ammo charges
        self.modeValues[1] = 0
        targetPly:Notify("Stimpak applied: Bleeding stanched, shock suppressed.", false, "stimpak_inject", 4)

        -- Handle weapon removal loop matching your medkit script
        if self.modeValues[1] == 0 and self.ShouldDeleteOnFullUse then
            owner:SelectWeapon("weapon_hands_sh")
            self:Remove()
        end
    end
end