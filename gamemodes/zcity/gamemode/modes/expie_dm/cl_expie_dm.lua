local MODE = MODE

MODE.name = "expie_dm"

local ZonePos     = Vector(0, 0, 0)
local zonedistance = 0
local roundend    = false
local inCombat    = false   
local sw, sh      = ScrW, ScrH  

-- ─── Local Soundtrack Files ──────────────────────────────────────────────────
local snds = {
    "expie_dm/ProxyOST-CU.mp3",
    "expie_dm/ChaseItDownOST-CU.mp3"
}

if SERVER then
    resource.AddFile("sound/expie_dm/ProxyOST-CU.mp3")
    resource.AddFile("sound/expie_dm/ChaseItDownOST-CU.mp3")
end

-- ─── Network receivers ────────────────────────────────────────────────────────
net.Receive("expie_dm_start", function()
    roundend  = false
    inCombat  = false

    hg.DynaMusic:Start("mirrors_edge")
    zb.RemoveFade()

    ZonePos      = net.ReadVector()
    zonedistance = net.ReadFloat()

    -- Play local files safely via sound.PlayFile
    local randomTrack = snds[math.random(#snds)]
    sound.PlayFile(randomTrack, "noplay mono", function(station, errCode)
        if IsValid(station) then
            station:SetVolume(0.6)
            station:Play()
            MODE.MusicStation = station
        else
            print("[Expie DM] Failed to play local track: " .. tostring(errCode))
        end
    end)
end)

net.Receive("expie_dm_end", function()
    local winner   = net.ReadEntity()
    local mvp      = net.ReadEntity()

    if IsValid(winner) then winner.won              = true end
    if IsValid(mvp)    then mvp.most_violent_player = true end

    roundend = CurTime()

    if IsValid(zb.SoundStation)    then zb.SoundStation:Stop()    ; zb.SoundStation    = nil end
    if IsValid(MODE.MusicStation)  then MODE.MusicStation:Stop()  ; MODE.MusicStation  = nil end

    CreateEndMenu(winner, mvp)
end)

-- ─── Zone: proximity volume swell ─────────────────────────────────────────────

hook.Add("Think", "expie_dm_zone_sound", function()
    if not CurrentRound() or CurrentRound().name ~= "expie_dm" then return end
    local station = zb.SoundStation
    if not IsValid(station) then return end

    local radius = MODE.GetZoneRadius()
    local vol    = math.Clamp((LocalPlayer():GetPos():Distance(ZonePos) - radius) + 200, 0, 200) / 200
    station:SetVolume(vol)
end)

-- ─── Zone: 3-D sphere render ──────────────────────────────────────────────────

function MODE:PostDrawTranslucentRenderables(bDepth, bSkybox, isDraw3DSkybox)
    if not bSkybox and not isDraw3DSkybox and inCombat then
        local radius = MODE.GetZoneRadius()
        render.SetMaterial(mat)
        render.DrawSphere(ZonePos, -radius, 60, 60, color_white)
    end
end

-- ─── Fade-in on round start ────────────────────────────────────────────────────

function MODE:RenderScreenspaceEffects()
    if zb.ROUND_START + 7.5 < CurTime() then return end
    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(), 0, 1)
    surface.SetDrawColor(0, 0, 0, 255 * fade)
    surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

-- ─── HUD ──────────────────────────────────────────────────────────────────────

local colTitle    = Color(220, 170, 20)
local colWhite    = Color(255, 255, 255)
local colRed      = Color(255, 60,  60)
local colCombat   = Color(230, 80,  40)
local colLoot     = Color(100, 220, 100)

function MODE:HUDPaint()
    local W, H = ScrW(), ScrH()
    local lootEnd = (zb.ROUND_START or 0) + MODE.LOOT_PHASE_DURATION

    -- ── Round intro banner (first ~8 seconds) ──
    if zb.ROUND_START + 8.5 > CurTime() then
        zb.RemoveFade()
        local fade = math.Clamp(zb.ROUND_START + 8 - CurTime(), 0, 1)
        draw.SimpleText("Expie Deathmatch", "ZB_HomicideMediumLarge",
            W * 0.5, H * 0.1,
            Color(colTitle.r, colTitle.g, colTitle.b, 255 * fade),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("You are an Experiment.", "ZB_HomicideMediumLarge",
            W * 0.5, H * 0.5,
            Color(colWhite.r, colWhite.g, colWhite.b, 255 * fade),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("As part of our research, you must find and exterminate other experiments to dertermine the effectiveness of certain weapons.", "ZB_HomicideMedium",
            W * 0.5, H * 0.9,
            Color(colLoot.r, colLoot.g, colLoot.b, 255 * fade),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    -- ── Loot phase countdown ──
    if CurTime() < lootEnd then
        local remaining = lootEnd - CurTime()
        local urgency   = remaining < 10  -- last 10 seconds

        local pulse = urgency and (math.sin(CurTime() * 8) * 0.5 + 0.5) or 1
        local alpha = 200 + math.floor(55 * pulse)
        local col   = urgency and Color(colRed.r, colRed.g, colRed.b, alpha)
                                or Color(colLoot.r, colLoot.g, colLoot.b, 210)

        draw.SimpleText(
            string.format("LOOT PHASE — %02d", math.ceil(remaining)),
            "ZB_HomicideMediumLarge",
            W * 0.5, H * 0.07,
            col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            "Weapons cannot be drawn yet.",
            "ZB_HomicideMedium",
            W * 0.5, H * 0.13,
            Color(200, 200, 200, 180),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
        return
    end

    -- ── Combat phase: show ring timer ──
    if inCombat then
        local combatStart   = lootEnd
        local ringCloseTime = combatStart + MODE.ZoneTimeToShrink
        local ringLeft      = math.max(ringCloseTime - CurTime(), 0)

        if ringLeft > 0 then
            draw.SimpleText(
                string.format("Ring closes in %02d:%02d",
                    math.floor(ringLeft / 60),
                    math.floor(ringLeft % 60)),
                "ZB_HomicideMedium",
                W * 0.5, H * 0.07,
                Color(colCombat.r, colCombat.g, colCombat.b, 190),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )
        end
    end
end

-- ─── Round start (client side) ────────────────────────────────────────────────

function MODE:RoundStart()
    inCombat = false
    roundend = false

    if IsValid(hmcdEndMenu) then hmcdEndMenu:Remove() ; hmcdEndMenu = nil end

    for _, ply in player.Iterator() do
        ply.won              = nil
        ply.most_violent_player = nil
    end
end

-- ─── End Screen ───────────────────────────────────────────────────────────────

local colGray      = Color(85,  85,  85,  255)
local colGold      = Color(217, 201, 99,  255)
local colGoldUp    = Color(207, 181, 59,  255)
local colBlue      = Color(10,  10,  160, 255)
local colBlueUp    = Color(40,  40,  160, 255)
local colSpect1    = Color(75,  75,  75,  255)
local colSpect2    = Color(255, 255, 255, 255)
local blurMat      = Material("pp/blurscreen")

function CreateEndMenu(wonEnt, mvpEnt)
    if IsValid(hmcdEndMenu) then hmcdEndMenu:Remove() ; hmcdEndMenu = nil end

    surface.PlaySound("ambient/alarms/warningbell1.wav")

    local sizeX = ScrW() / 2.5
    local sizeY = ScrH() / 1.2
    local posX  = ScrW() / 1.3 - sizeX / 2
    local posY  = ScrH() / 2   - sizeY / 2

    hmcdEndMenu = vgui.Create("ZFrame")
    hmcdEndMenu:SetPos(posX, posY)
    hmcdEndMenu:SetSize(sizeX, sizeY)
    hmcdEndMenu:MakePopup()
    hmcdEndMenu:SetKeyboardInputEnabled(false)
    hmcdEndMenu:ShowCloseButton(false)

    hmcdEndMenu.PaintOver = function(self, w, h)
        local txt = (IsValid(wonEnt) and wonEnt:GetPlayerName() or "ALL EXPERIEMNTS ARE DEAD: Issuing staff for clean up. NULL has") .. " won!"
        surface.SetFont("ZB_InterfaceMediumLarge")
        surface.SetTextColor(255, 255, 255, 255)
        local lx = surface.GetTextSize(txt)
        surface.SetTextPos(w / 2 - lx / 2, 20)
        surface.DrawText(txt)
    end

    local closeBtn = vgui.Create("DButton", hmcdEndMenu)
    closeBtn:SetPos(5, 5)
    closeBtn:SetSize(ScrW() / 20, ScrH() / 30)
    closeBtn:SetText("")
    closeBtn.DoClick = function()
        if IsValid(hmcdEndMenu) then hmcdEndMenu:Close() ; hmcdEndMenu = nil end
    end
    closeBtn.Paint = function(self, w, h)
        surface.SetDrawColor(122, 122, 122, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
        surface.SetFont("ZB_InterfaceMedium")
        surface.SetTextColor(255, 255, 255, 255)
        local lx = surface.GetTextSize("Close")
        surface.SetTextPos(lx - lx / 1.1, 4)
        surface.DrawText("Close")
    end

    local scroll = vgui.Create("DScrollPanel", hmcdEndMenu)
    scroll:SetPos(10, 80)
    scroll:SetSize(sizeX - 20, sizeY - 90)

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        local but = vgui.Create("DButton", scroll)
        but:SetSize(100, 50)
        but:Dock(TOP)
        but:DockMargin(8, 6, 8, -1)
        but:SetText("")

        but.Paint = function(self, w, h)
            local isWinner = ply.won or ply.most_violent_player
            local c1 = isWinner and colGold   or (ply:Alive() and colBlue  or colGray)
            local c2 = isWinner and colGoldUp or (ply:Alive() and colBlueUp or colSpect1)
            surface.SetDrawColor(c1.r, c1.g, c1.b, c1.a) ; surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(c2.r, c2.g, c2.b, c2.a) ; surface.DrawRect(0, h/2, w, h/2)

            local pCol = ply:GetPlayerColor():ToColor()
            surface.SetFont("ZB_InterfaceMediumLarge")
            surface.SetTextColor(pCol.r, pCol.g, pCol.b, 255)
            local lx, ly = surface.GetTextSize(ply:GetPlayerName() or "?")
            surface.SetTextPos(w / 2 - lx / 2, h / 2 - ly / 2)
            surface.DrawText(ply:GetPlayerName() or "?")

            -- Left: name + status
            surface.SetTextColor(colSpect2.r, colSpect2.g, colSpect2.b, 255)
            local tag = ply.most_violent_player and " - MVP"
                     or (not ply:Alive()         and " - died" or "")
            surface.SetTextPos(15, h/2 - ly/2)
            surface.DrawText((ply:Name() or "?") .. tag)

            -- Right: frags
            local fragStr = tostring(ply:Frags() or 0)
            local fx = surface.GetTextSize(fragStr)
            surface.SetTextPos(w - fx - 15, h/2 - ly/2)
            surface.DrawText(fragStr)
        end

        but.DoClick = function()
            if ply:IsBot() then chat.AddText(Color(255,0,0), "no, you can't") return end
            gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
        end

        scroll:AddItem(but)
    end
end
