require "PremiumPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"

local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

local function GetInventorySlotItem(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
        if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
    end
    return nil
end

local function IsNearEnemyTurret(pos, distance)
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= distance+915 and turret.team == 300-myHero.team then
            return turret
        end
    end
end

local function IsUnderEnemyTurret(pos)
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= 915 and turret.team == 300-myHero.team then
            return turret
        end
    end
end

function GetDifference(a,b)
    local Sa = a^2
    local Sb = b^2
    local Sdif = (a-b)^2
    return math.sqrt(Sdif)
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

function DrawTextOnHero(hero, text, color)
    local pos2D = hero.pos:To2D()
    local posX = pos2D.x - 50
    local posY = pos2D.y
    Draw.Text(text, 28, posX + 50, posY - 15, color)
end

function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function IsImmobile(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 30 or buff.name == "recall" then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsCleanse(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 31 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsChainable(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 32 or BuffType == 10 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function GetEnemyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
end

function GetEnemyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if not object.isAlly and object.type == Obj_AI_SpawnPoint then 
            EnemySpawnPos = object
            break
        end
    end
end

function GetAllyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if object.isAlly and object.type == Obj_AI_SpawnPoint then 
            AllySpawnPos = object
            break
        end
    end
end

function GetAllyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isAlly and Hero.charName ~= myHero.charName then
            table.insert(AllyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
end

function GetBuffStart(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.startTime
        end
    end
    return nil
end

function GetBuffExpire(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.expireTime
        end
    end
    return nil
end

function GetBuffDuration(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.duration
        end
    end
    return 0
end

function GetBuffStacks(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

local function GetWaypoints(unit)
    local waypoints = {}
    local pathData = unit.pathing
    table.insert(waypoints, unit.pos)
    local PathStart = pathData.pathIndex
    local PathEnd = pathData.pathCount
    if PathStart and PathEnd and PathStart >= 0 and PathEnd <= 20 and pathData.hasMovePath then
        for i = pathData.pathIndex, pathData.pathCount do
            table.insert(waypoints, unit:GetPath(i))
        end
    end
    return waypoints
end

local function GetUnitPositionNext(unit)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return nil
    end
    return waypoints[2]
end

local function GetUnitPositionAfterTime(unit, time)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return unit.pos
    end
    local max = unit.ms * time
    for i = 1, #waypoints - 1 do
        local a, b = waypoints[i], waypoints[i + 1]
        local dist = GetDistance(a, b)
        if dist >= max then
            return Vector(a):Extended(b, dist)
        end
        max = max - dist
    end
    return waypoints[#waypoints]
end

function GetTarget(range)
    if _G.SDK then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
    else
        return _G.GOS:GetTarget(range,"AD")
    end
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

function BuffActive(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return true
        end
    end
    return false
end

function IsReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function Mode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] or Orbwalker.Key.Harass:Value() then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or Orbwalker.Key.Clear:Value() then
            return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] or Orbwalker.Key.LastHit:Value() then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
end

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function IsMyHeroFacing(unit)
    local V = Vector((myHero.pos - unit.pos))
    local D = Vector(myHero.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function SetMovement(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)
        _G.PremiumOrbwalker:SetMovement(bool)       
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end


local function CheckHPPred(unit, SpellSpeed)
     local speed = SpellSpeed
     local range = myHero.pos:DistanceTo(unit.pos)
     local time = range / speed
     if _G.SDK and _G.SDK.Orbwalker then
         return _G.SDK.HealthPrediction:GetPrediction(unit, time)
     elseif _G.PremiumOrbwalker then
         return _G.PremiumOrbwalker:GetHealthPrediction(unit, time)
    end
end

function EnableMovement()
    SetMovement(true)
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
    return {x = ax + t * bxax, z = az + t * bzaz}, true
end

local function ValidTarget(unit, range)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        if range then
            if GetDistance(unit.pos) <= range then
                return true;
            end
        else
            return true
        end
    end
    return false;
end

local function GetQDmg(unit)
    local Qdmg = getdmg("Q", unit, myHero, 1)
end 

local function GetEnemyCount(range, pos)
    local pos = pos.pos
    local count = 0
    for i, hero in pairs(EnemyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

local function GetAllyCount(range, pos)
    local pos = pos.pos
    local count = 0
    for i, hero in pairs(AllyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

class "Manager"

function Manager:__init()
	if myHero.charName == "Teemo" then
		DelayAction(function () self:LoadTeemo() end, 1.05)
	end
end

function Manager:LoadTeemo()
	Teemo:Spells()
	Teemo:Menu()
	Callback.Add("Tick", function() Teemo:Tick() end)
	Callback.Add("Draw", function() Teemo:Draws() end)
end

class "Teemo"

local EnemyLoaded = false
local AARange = 500
local QRange = 680
local RRange = 0

--icons
local HeroIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/17.png"
local QIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BlindingDart.png"
local PassiveIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/d/d2/Guerrilla_Warfare.png/revision/latest/scale-to-width-down/64?cb=20171221034119"
local WIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/MoveQuick.png"
local EIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/ToxicShot.png"
local RIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/TeemoRCast.png"


function Teemo:Menu()
    self.Menu = MenuElement({type = MENU, id = "Teemo", name = "Nisses Teemo", leftIcon = HeroIcon})
        
--Combo 
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "ComboUseQ", name = "[Q]", leftIcon = QIcon, value = true})
    self.Menu.Combo:MenuElement({id = "ComboUseQMana", name = "[Q] Min% Mana for Q", leftIcon = QIcon, value = 10, min = 0, max = 100, step = 1, identifier = "%"})
    self.Menu.Combo:MenuElement({id = "ComboUseW", name = "[W]", leftIcon = WIcon, value = false})
    self.Menu.Combo:MenuElement({id = "ComboUseWMana", name = "[W] Min% Mana for W", leftIcon = WIcon, value = 60, min = 0, max = 100, step = 1, identifier = "%"})
    self.Menu.Combo:MenuElement({id = "ComboUseR", name = "[R]", leftIcon = RIcon, value = false})
    self.Menu.Combo:MenuElement({id = "ComboUseRMana", name = "[R] Min% Mana for R", leftIcon = RIcon, value = 60, min = 0, max = 100, step = 1, identifier = "%"})
    self.Menu.Combo:MenuElement({id = "ComboRAmmo", name = "[R] Keep R stacks", leftIcon = RIcon, value = 2, min = 0, max = 5, step = 1})

--Harass
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "HarassUseQ", name = "[Q]", leftIcon = QIcon, value = true})
    self.Menu.Harass:MenuElement({id = "HarassUseQMana", name = "[Q] Min% Mana for Q", leftIcon = QIcon, value = 10, min = 0, max = 100, step = 1, identifier = "%"})

--Laneclear
    self.Menu:MenuElement({type = MENU, id = "LaneClear", name = "Laneclear"})
    self.Menu.LaneClear:MenuElement({id = "LastHitQ", name = "[Q] Lasthit cannon with Q", leftIcon = QIcon, value = true})
    self.Menu.LaneClear:MenuElement({id = "LastHitQMana", name = "[Q] Min% Mana for Q", leftIcon = QIcon, value = 25, min = 0, max = 100, step = 1, identifier = "%"})
 --   self.Menu:LaneClear:MenuElement({id = "LaneclearUseQ", name = "[Q]", leftIcon = QIcon, value = false})
 --   self.Menu:LaneClear:MenuElement({id = "LaneclearUseR", name = "[R]", leftIcon = RIcon, value = false})

--Auto  
    self.Menu:MenuElement({type = MENU, id = "Killsteal", name = "Auto"})
    self.Menu.Killsteal:MenuElement({id = "KillstealUseQ", name = "[Q] Auto Q for Killsteal", leftIcon = QIcon, value = true})
    self.Menu.Killsteal:MenuElement({id = "KillstealUseQMana", name = "[Q] Min% Mana for Q", leftIcon = QIcon, value = 20, min = 0, max = 100, step = 1, identifier = "%"})
    self.Menu.Killsteal:MenuElement({id = "RImmobile", name = "[R] Auto R on Immobile", leftIcon = RIcon, value = true })
    self.Menu.Killsteal:MenuElement({id = "RImmobileMana", name = "[R] Min% Mana for R", leftIcon = RIcon, value = 60, min = 0, max = 100, step = 1, identifier = "%"})
    self.Menu.Killsteal:MenuElement({id = "ComboRAmmo", name = "[R] Keep x stacks", leftIcon = RIcon, value = 2, min = 0, max = 5, step = 1})

--Drawing 
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", leftIcon = QIcon, value = true})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", leftIcon = RIcon, value = true})
end

--Draws
function Teemo:Draws()
    if self.Menu.Drawing.DrawQ:Value() then
        Draw.Circle(myHero, 680, 1, Draw.Color(255, 0, 255, 255))
    end

    local RRange = self:GetRRange()
    if self.Menu.Drawing.DrawR:Value() then
        Draw.Circle(myHero, RRange, 1, Draw.Color(255, 255, 0, 0))
    end
end

--Combospells
function Teemo:ComboUseQ()
    local QTarget = GetTarget(QRange)
    if ValidTarget(target, QRange) and self:CanUse(_Q, "Combo") and self:SmoothChecks() then
        Control.CastSpell(HK_Q, target)
    end
end

function Teemo:ComboUseW()
    local wtarget = GetTarget(800)
    if ValidTarget(wtarget) and self:CanUse(_W, "Combo") and self:SmoothChecks() and IsMyHeroFacing(wtarget) then
        Control.KeyDown(HK_W)
        Control.KeyUp(HK_W)
    end
end

function Teemo:ComboUseR()
    local rtarget = GetTarget(RRange)
    if ValidTarget(rtarget) and myHero:GetSpellData(_R).ammo > self.Menu.Combo.ComboRAmmo:Value() and self:CanUse(_R, "Combo") and self:SmoothChecks() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, rtarget, RspellData)
        if pred.CastPos and pred.HitChance >= 0.15 then
        Control.CastSpell(HK_R, pred.CastPos)
    end
  end
end

--Harass
function Teemo:HarassUseQ()
    local QTarget = GetTarget(QRange)
    if ValidTarget(target, QRange) and self:CanUse(_Q, "Harass") and self:SmoothChecks() then
        Control.CastSpell(HK_Q, target)
    end
end

--Laneclear
function Teemo:QLastHit(minion)
    local Qrange = 680
    local QDmg = getdmg("Q", minion, myHero, myHero:GetSpellData(_Q).level)
    if ValidTarget(minion, Qrange) and self:CanUse(_Q, "LastHit") and self:SmoothChecks() and (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
        if minion.health < QDmg then
                Control.CastSpell(HK_Q, minion)
        end
    end
end

--Autospells
function Teemo:QKillsteal(enemy)
    local Qrange = 680
    if ValidTarget(enemy, Qrange) then
	local Qdmg = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
		if self:CanUse(_Q, "Killsteal") and GetDistance(enemy.pos, myHero.pos) < Qrange and self.Menu.Killsteal.KillstealUseQ:Value() and enemy.health < Qdmg and ActiveSpell ~= "BlindingDart" then
		     Control.CastSpell(HK_Q, enemy)
		end
	end
end

function Teemo:AutoRImmobile(enemy) 
    if ValidTarget(enemy, RRange) and myHero:GetSpellData(_R).ammo > self.Menu.Killsteal.ComboRAmmo:Value() and self:CanUse(_R, "RImmobile") and self:CastingChecks() and (IsImmobile(enemy)) >= 0.5 and self.Menu.Killsteal.RImmobile:Value() then
    local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, RspellData)
        if pred.CastPos and pred.HitChance >= 1 then
        Control.CastSpell(HK_R, pred.CastPos)
        end
    end
end

function Teemo:CastingChecks()
    if not CastingQ or not CastingW or not CastingE or not CastingR then
        return true
    else
        return false
    end
end

function Teemo:SmoothChecks()
    if self:CastingChecks() and _G.SDK.Cursor.Step == 0 and _G.SDK.Spell:CanTakeAction({q = 0.33, w = 0.33, e = 0.33, r = 0.33}) then
        return true
    else
        return false
    end
end

function Teemo:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end

    if spell == _Q then
        if mode == "Combo" and IsReady(_Q) and self.Menu.Combo.ComboUseQ:Value() and myHero.mana / myHero.maxMana >= self.Menu.Combo.ComboUseQMana:Value() / 100 then
            return true
        end
        if mode == "Harass" and IsReady(_Q) and self.Menu.Harass.HarassUseQ:Value() and myHero.mana / myHero.maxMana >= self.Menu.Harass.HarassUseQMana:Value() / 100 then
            return true
        end
        if mode == "Killsteal" and IsReady(spell) and self.Menu.Killsteal.KillstealUseQ:Value() and myHero.mana / myHero.maxMana >= self.Menu.Killsteal.KillstealUseQMana:Value() / 100 then
			return true
		end
        if mode == "LastHit" and IsReady(spell) and self.Menu.LaneClear.LastHitQ:Value() and myHero.mana / myHero.maxMana >= self.Menu.LaneClear.LastHitQMana:Value() / 100 then
			return true
        end

    elseif spell == _W then
        if mode == "Combo" and IsReady(_W) and self.Menu.Combo.ComboUseW:Value() and myHero.mana / myHero.maxMana >= self.Menu.Combo.ComboUseWMana:Value() / 100 then
            return true
        end
    
    elseif spell == _R then
        if mode == "Combo" and IsReady(_R) and self.Menu.Combo.ComboUseR:Value() and myHero.mana / myHero.maxMana >= self.Menu.Combo.ComboUseRMana:Value() / 100 then
            return true
        end
        if mode == "RImmobile" and IsReady(spell) and self.Menu.Killsteal.RImmobile:Value() and myHero.mana / myHero.maxMana >= self.Menu.Killsteal.RImmobileMana:Value() / 100 then
            return true
        end
    end
end

function Teemo:Spells()
 RspellData = {speed = 1600, range = RRange, delay = 1, radius = 75, collision = {}, type = "circular"}
end

function Teemo:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    
    RRange = self:GetRRange()
    RspellData.range = self:GetRRange()
    
    target = GetTarget(myHero.range + myHero.boundingRadius)

    CastingQ = myHero.activeSpell.name == "BlindingDart"
    CastingW = myHero.activeSpell.name == "MoveQuick"
    CastingE = myHero.activeSpell.name == "ToxicShot"
    CastingR = myHero.activeSpell.name == "TeemoRCast"

    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
    end
    self:Logic()
    self:Auto()
    self:Minions()
end

function Teemo:GetRRange()
    if myHero:GetSpellData(_R).level > 0 then
        return 150 + (250 * myHero:GetSpellData(_R).level)
    else
        return 0
    end
end

function Teemo:Logic()
    if Mode() == "Combo" then
        self:ComboUseQ()
    end

    if Mode() == "Combo" then
        self:ComboUseW()
    end

    if Mode() == "Combo" then
        self:ComboUseR()
    end

    if Mode() == "Harass" then
        self:HarassUseQ()
    end
end

function Teemo:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        self:QKillsteal(enemy)
        self:AutoRImmobile(enemy)
    end
end

function Teemo:Minions()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(1400)
    for i = 1, #minions do
        local minion = minions[i]
        if Mode() == "LaneClear" then
            self:QLastHit(minion)
        end
        if Mode() == "Harass" then
            self:QLastHit(minion)
        end
        if Mode() == "LastHit" then
            self:QLastHit(minion)
        end
    end
end

function OnLoad()
    Manager()
end