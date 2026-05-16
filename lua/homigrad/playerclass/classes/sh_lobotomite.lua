local CLASS = player.RegClass("Lobotomite")

function CLASS.On(self)
    if CLIENT then return end
    
    -- Apply your server's default visuals/outfits
    ApplyAppearance(self)

    -- Inject our special identifiers into the player and their organism
    self.IsBrainless = true
    if self.organism then
        self.organism.IsBrainless = true
    end

    self:ChatPrint("OVERRIDE: Your brain has been replaced with advanced Tesla-technology. You cannot register brain shock, but you will still drain of blood.")
end

function CLASS.Off(self)
    if CLIENT then return end
    self.IsBrainless = nil
    if self.organism then
        self.organism.IsBrainless = nil
    end
end

CLASS.CanUseDefaultPhrase = false
CLASS.CanEmitRNDSound = true
CLASS.CanUseGestures = true

function CLASS.Guilt(self, Victim)
    if CLIENT then return end
end
