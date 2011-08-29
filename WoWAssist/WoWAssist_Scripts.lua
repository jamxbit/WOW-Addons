﻿WA = {}
WA.__version = 1.2

WA.classModules = {}
WA.classModules = {}
WA.cmdList = {}
WA.spell_reg = {}
WA.spell_event = {}

WA.env = setmetatable({}, {__index = _G})  -- add all data functions in this environment and pass them to the exec calls
WA.env2 = setmetatable({}, {__index = _G})  -- use a different one for alerts, events etc

local debug_enabled 			= true
local first_load 				= true
dcount = 0

function WoWAssist_Frame_OnLoad()
	-- WA:Print("Loaded")
end

function WoWAssist_Frame_OnUpdate()
	if (WA:InCombat()) then
		-- Do Stuff --
		if(WA.rotation ~= nil) then
			WA.StartTime = GetTime()
			-- gcd value
			WA.StartGCD = WA:GetGCDStart()
			-- Check for Interrupt Opportunity

			-- Should We Delay
			if (WA.StartGCD > WA.ShowDataTimeFactor) then						-- NOT inside spam window
				-- WA:SetTitle(WA.StartGCD .. "off gcd rotation")
						-- Do OFF GCD Rotation
				if(WA.offgcdrotation ~= nil) then
					WA:SetTitle("Off GCD rotation")
					WA.offgcdrotation(WA.StartTime, WA.StartGCD)
				else
					if ((WA.StartGCD - WA.ShowDataTimeFactor) > .300) then			-- Check Longer Delay
						WA:SpellFire(WA.Delay300, WA.Delay300, WA.Delay300)
					elseif ((WA.StartGCD - WA.ShowDataTimeFactor) > .100) then		-- Check Medium Delay
						WA:SpellFire(WA.Delay100, WA.Delay100, WA.Delay100)
					else
						WA:SpellFire(WA.Delay20, WA.Delay20, WA.Delay20)
					end
				end
			else
				-- WA:SetTitle("Rotation")
				-- Do Rotation
				WA.rotation(WA.StartTime, WA.StartGCD)
			end
		else
			WA:SetText("No Rotation")
		end
	else
		WA:SpellFire(WA.bypassColor, WA.bypassColor, WA.bypassColor)
	end
end -- End OnUpdate 

-- ==================== Get Global Cooldo0n ==============================
-- Outputs: Returns the global Cooldo0n
-- =======================================================================
-- Deprecated
function WA:GetGCDStart()
	local start, duration = GetSpellCooldown(WA.GCDSpell)
	StartGCD = start + duration - WA.StartTime
	if StartGCD < 0 then StartGCD = 0 end
	return StartGCD
end

-- ============================ Actual Spell Cooldown on non GCD duration ============================
-- Outputs: 
-- SpellCD: Returns the cooldown of the Given spell 
-- SpellFinish: Returns when the spell will finish
-- =======================================================================
function WA:GetActualSpellCD(SpellFinishCurrent, SpellName)
	NewSpellCD = 0
	SpellFinish = SpellFinishCurrent
	
	SpellCDStart, SpellCDDuration, _ = GetSpellCooldown(SpellName)
	if (SpellCDStart ~= 0) then
		if (SpellCDDuration > WA.GCD_Duration) then			-- Calc CD based on a non GCD duration 
			SpellFinish = SpellCDStart + SpellCDDuration
			NewSpellCD = SpellFinish - WA.StartTime
		else
			if (SpellFinish - WA.StartTime > 0) then		--check if finish is even relevant, if not cd = 0
				if (SpellFinish - (SpellCDStart + SpellCDDuration) - WA.ShowDataTimeFactor > 0) then
					NewSpellCD = 0
				else
					NewSpellCD = SpellFinish - WA.StartTime
				end
			else
				NewSpellCD = 0
			end
		end
	else
		NewSpellCD = 0
	end
	return NewSpellCD, SpellFinish
end

function WA:GetTargetHealthPercentage() 
    local target_health_max = UnitHealthMax("target")         
    if (target_health_max > 0) then
        return UnitHealth("target") / target_health_max
    else
        -- maximum health
        return 1.0
    end
end

function WA:GetCooldown(id)
	local start, duration = GetSpellCooldown(id)
	local cd = start + duration - WA.StartTime - WA.StartGCD
	if cd < 0 then return 0 end
	return cd
end

function WA:GetBuffCount(buff)
	local BuffName, BuffCount, BuffExpirationTime
	BuffName, _, _,BuffCount, _, _, BuffExpirationTime, _, _, _, _ = UnitBuff("player", buff) 
	if (BuffName == nil) then
		BuffCount = 0
	end
	return BuffCount
end

function WA:GetBuff(buff)
	local left
	_, _, _, _, _, _, expires = UnitBuff("player", buff, nil, "PLAYER")
	if expires then
		left = expires - WA.StartTime - WA.StartGCD
		if left < 0 then left = 0 end
	else
		left = 0
	end
	return left
end

function WA:GetPetBuff(buff)
	local left
	_, _, _, _, _, _, expires = UnitBuff("pet", buff, nil, "PLAYER")
	if expires then
		left = expires - WA.StartTime - WA.StartGCD
		if left < 0 then left = 0 end
	else
		left = 0
	end
	return left
end

function WA:GetPetBuffCount(buff)
	local BuffName, BuffCount
	BuffName, _, _,BuffCount, _, _, _, _, _, _, _ = UnitBuff("pet", buff) 
	if (BuffName == nil) then
		BuffCount = 0
	end
	return BuffCount
end

function WA:GetTargetDebuff(debuff)
	DebuffName, _, _, _, _, DebuffDuration, DebuffExpiration, DebuffUnitCaster, _ = UnitDebuff("target", debuff)
	if (DebuffName ~= nil) then
		DebuffTimeLeft = DebuffExpiration - WA.StartTime
	else
		DebuffTimeLeft = 0
	end	
	return DebuffTimeLeft
end

function WA:GetTargetDebuffStacks(debuff)
	DebuffName, _, _,DebuffCount, _, _, DebuffExpiration, _, _, _, _ = UnitDebuff("target", debuff) 
	if (DebuffName ~= nil) then
		DebuffCount = 0
	end
	return DebuffCount
end


function WA:GetFocusDebuff(debuff)
	DebuffName, _, _, _, _, DebuffDuration, DebuffExpirationTime, UnitCaster, _ = UnitDebuff("focus", debuff)
	DebuffCD = 0
	if (DebuffName ~= nil and UnitCaster == "player") then
		DebuffNameCD = DebuffExpirationTime - WA.StartTime
	end
	return DebuffCD
end

function WA:GetArmorDebuff()
	-- [Faerie Fire] /  [Faerie Fire (Feral)]: -4% per application, stacks up to 3 times, also prevents stealth.
	-- [Tear Armor]: Raptor ability, -4% per application, stacks up to 3 times.
	-- [Corrosive Spit]: Serpent ability, -4% per application, stacks up to 3 times.
	-- [Expose Armor]: -12%.
	-- [Sunder Armor]: -4% per application, stacks up to 3 times.
	
	SACD = WA:GetTargetDebuff("Sunder Armor")
	FFCD = WA:GetTargetDebuff("Faerie Fire")
	TACD = WA:GetTargetDebuff("Tear Armor")
	CSCD = WA:GetTargetDebuff("Corrosive Spit")
	XACD = WA:GetTargetDebuff("Expose Armor")
	return math.max(SACD, FFCD, TACD, CSCD, XACD)
end


function WA:GetAttackPowerDebuff()
	-- [Vindication]: Scales with level, -574 fully talented @ level 80.
	-- [Demoralizing Roar]: -408 @ max rank (~571.2 fully talented with  [Feral Aggression], a tier 1 Feral Combat talent with 5 ranks), Bear Form and Dire Bear form only.
	-- [Demoralizing Screech]: Carrion Bird ability, -410 @ max rank.
	-- [Curse of Weakness]: -478 @ max rank (573 fully talented w/  [Improved Curse of Weakness], a tier 2 Affliction talent with 2 ranks), also reduces armor.
	-- [Demoralizing Shout]: -410 @ max rank (-574 fully talented with  [Improved Demoralizing Shout], a tier 2 Fury talent with 5 ranks).
	
	VICD = WA:GetTargetDebuff("Vindication")
	DRCD = WA:GetTargetDebuff("Demoralizing Roar")
	DSCCD = WA:GetTargetDebuff("Demoralizing Screech")
	CWCD = WA:GetTargetDebuff("Curse of Weakness")
	DSCD = WA:GetTargetDebuff("Demoralizing Shout")
	
	return math.max(VICD, DRCD, DSCCD, CWCD, DSCD)
end

function WA:GetAttackSpeedDebuff()
	--  Frost Fever: Caused by  [Icy Touch],  [Hungering Cold], glyphed  [Howling Blast] and glyphed  [Scourge Strike]. Can also be caused by using  [Pestilence] on a nearby creature that already has Frost Fever. Increases melee and ranged attack intervals by 20%.
	-- [Infected Wounds]: Tier 8 Feral Combat talent, 3 ranks, causes Mangle,  [Maul] and  [Shred] to apply the Infected Wound debuff, which increases melee attack interval by 20% @ max rank, also reduces movement speed.
	-- [Judgements of the Just]: Tier 9 Protection talent, 2 ranks, causes Judgements to increase melee attack intervals 20% @ max rank.
	-- [Earth Shock]: Reduces melee and ranged attack intervals by 10%, 20% when talented.
	-- [Thunder Clap]: Reduces melee and ranged attack intervals by 10%, 20% when talented.
	-- [Slow]: Tier 7 Arcane talent ability, increases melee and ranged attack intervals by 60%, also increases casting time.

	ITCD = WA:GetTargetDebuff("Frost Fever")
	TCCD = WA:GetTargetDebuff("Thunder Clap")
	IWCD = WA:GetTargetDebuff("Infected Wounds")
	JJCD = WA:GetTargetDebuff("Judgements of the Just")
	ESCD = WA:GetTargetDebuff("Earth Shock")
	return math.max(ITCD, TCCD, IWCD, JJCD, ESCD)
	
end

function WA:GetTraumaDebuff()
	-- FBNLite.L["Mangle (Cat)"] = GetSpellInfo(33876)
	-- FBNLite.L["Mangle (Bear)"] = GetSpellInfo(33878)
	-- FBNLite.L["Trauma"] = GetSpellInfo(46857)
	-- FBNLite.L["Hemorrhage"] = GetSpellInfo(16511)
	MAB = WA:GetTargetDebuff("Mangle")
	-- MAC = WA:GetTargetDebuff(33878)
	TRA = WA:GetTargetDebuff("Trauma")
	HEM = WA:GetTargetDebuff("Hemorrhage")
	return math.max(MAB, TRA, HEM)
end

-- ============================ Execute Range ============================
-- Outputs: True / False if Target is in Execute Range
-- =======================================================================
function WA:ExecuteRange()
	ExecutePercent = 20.00
	THealth = UnitHealth("target")
	THealthMax = UnitHealthMax("target")
	THealthPercent = (THealth / THealthMax) * 100
	
	if(THealthPercent < ExecutePercent) then
		return true
	else
		return false
	end
end

-- ================= Register GCDSPell (Spell used to determine the GCD =================
function WA:RegisterGCDSpell(name)
	WA.GCDSpell = name
end

-- ================= Register RangeSpell (Spell used to determine range to target / focus     ================
function WA:RegisterRangeSpell(name)
	WA.RangeSpell = name
end

-- ================= Registration Method Used by Class Modules ============================
function WA:RegisterClassModule(name)
	name = string.lower(name)
	WA.classModules[name] = {}
	return WA.classModules[name]
end

-- ============================ SetTitle ============================
-- Input: Title to set the title field for the addon
-- =======================================================================
function WA:SetTitle(msg)
	WoWAssist_TitleDisplay:SetText(msg)
end

function WA:debug(msg)
	if(debug_enabled) then
		WA:Print(msg)
		-- WoWAssist_T1:SetText(msg)
	end
end
function WA:debugslow(msg)
	if(dcount == 0) then
		WA:debug("dc: " .. dcount .. ": " .. msg)
		dcount = dcount + 1
	else
		if (dcount == 50) then 
			dcount = 0
		else
			dcount = dcount + 1
		end
	end
end

function WA:SetText(msg)
	WoWAssist_TextDisplay:SetText(msg)
end

function WA:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WoWAssist|r: " .. msg)
end

function WA:GetIcon(spellName)
	name, _, texture = GetSpellInfo(spellName)
	return texture
end

function WA:SetToggle(Location, State, Spell)
	-- DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WoWAssist|r: " .. Location .. ":" .. State .. ":" .. Spell)
	Icon = WA:GetIcon(Spell)
	if(Location == 1)then
		WoWAssist_ToggleIcon_1:SetTexture(Icon)
		if(State == 1) then
			WoWAssist_ToggleFrame_1_OnClick()
		end
	elseif(Location == 2) then
		WoWAssist_ToggleIcon_2:SetTexture(Icon)
		if(State == 1) then
			WoWAssist_ToggleFrame_2_OnClick()
		end
	elseif(Location == 3) then
		WoWAssist_ToggleIcon_3:SetTexture(Icon)
		if(State == 1) then
			WoWAssist_ToggleFrame_3_OnClick()
		end
	elseif(Location == 4) then
		WoWAssist_ToggleIcon_4:SetTexture(Icon)
		if(State == 1) then
			WoWAssist_ToggleFrame_4_OnClick()
		end
	end
end

function WA:SetAbilityTexture(texture)
	WoWAssist_Ability:SetTexture(texture)
end

function WA:SpellFire(Spell1, Spell2, Spell3)
	if(Spell1 == WA.spellColor1) then
		WA:SetAbilityTexture(WA.Spell1Icon)
	elseif(Spell1 == WA.spellColor2) then
		WA:SetAbilityTexture(WA.Spell2Icon)
	elseif(Spell1 == WA.spellColor3) then
		WA:SetAbilityTexture(WA.Spell3Icon)
	elseif(Spell1 == WA.spellColor4) then
		WA:SetAbilityTexture(WA.Spell4Icon)
	elseif(Spell1 == WA.spellColor5) then
		WA:SetAbilityTexture(WA.Spell5Icon)
	elseif(Spell1 == WA.spellColor6) then
		WA:SetAbilityTexture(WA.Spell6Icon)
	elseif(Spell1 == WA.spellColor7) then
		WA:SetAbilityTexture(WA.Spell7Icon)
	elseif(Spell1 == WA.spellColor8) then
		WA:SetAbilityTexture(WA.Spell8Icon)
	elseif(Spell1 == WA.spellColor9) then
		WA:SetAbilityTexture(WA.Spell9Icon)
	elseif(Spell1 == WA.spellColor10) then
		WA:SetAbilityTexture(WA.Spell10Icon)
	elseif(Spell1 == WA.spellColor11) then
		WA:SetAbilityTexture(WA.Spell11Icon)
	else
		WA:SetAbilityTexture(nil)
	end
	WoWAssist_Data:SetVertexColor(Spell1,Spell2,Spell3)
end

function WA:RegisterSpell(Position, Spell)
	if(Position == 1) then
		WA.Spell1Icon = WA:GetIcon(Spell)
		return WA.spellColor1
	elseif(Position == 2) then
		WA.Spell2Icon = WA:GetIcon(Spell)
		return WA.spellColor2
	elseif(Position == 3) then
		WA.Spell3Icon = WA:GetIcon(Spell)
		return WA.spellColor3
	elseif(Position == 4) then
		WA.Spell4Icon = WA:GetIcon(Spell)
		return WA.spellColor4
	elseif(Position == 5) then
		WA.Spell5Icon = WA:GetIcon(Spell)
		return WA.spellColor5
	elseif(Position == 6) then
		WA.Spell6Icon = WA:GetIcon(Spell)
		return WA.spellColor6
	elseif(Position == 7) then
		WA.Spell7Icon = WA:GetIcon(Spell)
		return WA.spellColor7
	elseif(Position == 8) then
		WA.Spell8Icon = WA:GetIcon(Spell)
		return WA.spellColor8
	elseif(Position == 9) then
		WA.Spell9Icon = WA:GetIcon(Spell)
		return WA.spellColor9
	elseif(Position == 10) then
		WA.Spell10Icon = WA:GetIcon(Spell)
		return WA.spellColor10
	elseif(Position == 11) then
		WA.Spell11Icon = WA:GetIcon(Spell)
		return WA.spellColor11
	elseif(Position == 12) then
		WA.Spell12Icon = WA:GetIcon(Spell)
		return WA.spellColor12
	end
end

function WA:OnInitialize()
	if(first_load) then
		WA:Print("Initializing WoWAssist [" .. WA.__version .. "]")
		WoWAssist_ToggleIcon_1:SetTexture(nil)
		WoWAssist_ToggleIcon_2:SetTexture(nil)
		WoWAssist_ToggleIcon_3:SetTexture(nil)
		WoWAssist_ToggleIcon_4:SetTexture(nil)
		WA:CombatDisabled()
	end
	
	
	--================= Ability To Key Mappings ===================
	WA.spellColor1 		= 0.1
	WA.spellColor2 		= 0.2
	WA.spellColor3 		= 0.3
	WA.spellColor4 		= 0.4
	WA.spellColor5 		= 0.5
	WA.spellColor6 		= 0.6
	WA.spellColor7		= 0.7
	WA.spellColor8 		= 0.8
	WA.spellColor9 		= 0.9
	WA.spellColor10 	= 1.0
	WA.spellColor11 	= .95
	--================= Set Default Spell Icons ===================
	WA.Spell1Icon	= nil
	WA.Spell2Icon	= nil
	WA.Spell3Icon	= nil
	WA.Spell4Icon	= nil
	WA.Spell5Icon	= nil
	WA.Spell6Icon	= nil
	WA.Spell7Icon	= nil
	WA.Spell8Icon	= nil
	WA.Spell9Icon	= nil
	WA.Spell10Icon	= nil
	WA.Spell11Icon	= nil
	--================= Extra Function Mappings ===================
	WA.Delay20	 	= 0.0
	WA.Delay100 	= 0.01
	WA.Delay300 	= 0.02
	WA.Delay500 	= 0.03
	WA.Delay700 	= 0.04	
	WA.Delay900 	= 0.05
	WA.bypassColor	= 0.05
	--================= Set Delay Icons ===========================
	WA.Delay20Icon	= nil
	WA.Delay100Icon	= nil
	WA.Delay300Icon	= nil
	WA.Delay500Icon	= nil
	WA.Delay700Icon	= nil
	WA.Delay900Icon	= nil
	--================= Global Variables ===================
	WA.Enabled 				= true			-- Enables OnUpdate code execution
	WA.ShowDataTimeFactor 	= 0.150			-- Time prior to a GCD finish when the color box will be shown
	WA.GCD_Duration			= 1.5
	WA.StartGCD				= 0
	WA.StartTime			= GetTime()
	WA.Toggle_Do_1 			= true
	WA.Toggle_Do_2 			= true
	WA.Toggle_Do_3			= true
	WA.Toggle_Do_4			= true
	--================== Special Spell Registrations =================
	WA.GCDSpell				= "Survey"
	WA.RangeSpell			= nil
	
	--================= Initialize Class Modules ===================
	for k in pairs(WA.classModules) do
		if WA.classModules[k].OnInitialize then
			if(first_load) then
				print("Initializing " .. k )
			end
			WA.classModules[k].OnInitialize()
		end
	end
	first_load = false
end

function WA:InCombat()
	return WA.incombat
end

function WA:CombatDisabled()
	WA:SetTitle("Combat Disabled")
	-- WA:Print("Combat Disabled")
	WA.incombat = false
end
function WA:CombatEnabled()
	WA:SetTitle("Combat Enabled")
	-- WA:Print("Combat Enabled")
	WA.incombat = true
end

function WA:OnDisable()
	self:UnregisterAllEvents()		
end

function WoWAssist_ToggleFrame_1_OnClick()
	if (WA.Toggle_Do_1 == true) then
		WA.Toggle_Do_1 = false
		WoWAssist_ToggleIcon_1:SetVertexColor(1, 1,1, 0.2)
	else
		WoWAssist_ToggleIcon_1:SetVertexColor(1, 1,1, 1)
		WA.Toggle_Do_1 = true
	end
end

function WoWAssist_ToggleFrame_2_OnClick()
	if (WA.Toggle_Do_2 == true) then
		WA.Toggle_Do_2 = false
		WoWAssist_ToggleIcon_2:SetVertexColor(1, 1,1, 0.2)
	else
		WoWAssist_ToggleIcon_2:SetVertexColor(1, 1,1, 1)
		WA.Toggle_Do_2 = true
	end
end

function WoWAssist_ToggleFrame_3_OnClick()
	if (WA.Toggle_Do_3 == true) then
		WA.Toggle_Do_3 = false
		WoWAssist_ToggleIcon_3:SetVertexColor(1, 1,1, 0.2)
	else
		WoWAssist_ToggleIcon_3:SetVertexColor(1, 1,1, 1)
		WA.Toggle_Do_3 = true
	end
end

function WoWAssist_ToggleFrame_4_OnClick()
	if (WA.Toggle_Do_4 == true) then
		WA.Toggle_Do_4 = false
		WoWAssist_ToggleIcon_4:SetVertexColor(1, 1,1, 0.2)
	else
		WoWAssist_ToggleIcon_4:SetVertexColor(1, 1,1, 1)
		WA.Toggle_Do_4 = true
	end
end
function WA:setHelp(helpcommand)
	WA.helpcommand=helpcommand
end

function WA:setRotation(rotation, rotationText)
	WA:Print("Rotation Set To " .. rotationText)
	WA.rotation=rotation
	WA:SetText(rotationText)
end

function WA:setOffGCDRotation(rotation)
	WA:Print("enabling off GCD rotation")
	WA.offgcdrotation = rotation
end

local function OnEvent(self, event, ...)
	-- WA[event](WA, event, ...)
	if WA[event] then
		WA[event](WA, event, ...)
	else
		WA:Print(event, "event registered but not handled")
	end
end


-- event frame
WA.eventFrame = CreateFrame("Frame")
WA.eventFrame:Hide()
WA.eventFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ACTIVE_TALENT_GROUP_CHANGED"  then
		-- intialize, unregister, change event function
		WA.eventFrame:UnregisterEvent("QUEST_LOG_UPDATE")
		-- WA.eventFrame:SetScript("OnEvent", OnEvent)
		WA:OnInitialize()
	end
	if event == "PLAYER_REGEN_ENABLED" then
		WA:CombatDisabled()
	end
	if event == "PLAYER_REGEN_DISABLED" then
		WA:CombatEnabled()
	end
end)
-- need an event that fires first time after talents are loaded and fires both at login and reloadui
-- in case this doesn't work have to do with delayed timer
-- using QUEST_LOG_UPDATE atm
WA.eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
WA.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
WA.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
WA.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
WA.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")