-- 
-- GC_HorseHelper 
-- 
-- @Interface: 1.1.2.0 b3108
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.03.2019
-- @Version: 1.1.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--
-- 	v1.1.0.0 (26.03.2019):
-- 		- add script to gc
--		- this function can dis-/enabled in the gc-settings
--		- 
--
-- 	v1.0.0.0 (25.1.2018):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--
--
-- ToDo:
-- 
--
--

GC_HorseHelper = {};
local GC_HorseHelper_mt = Class(GC_HorseHelper);
InitObjectClass(GC_HorseHelper, "GC_HorseHelper");

GC_HorseHelper.debugIndex = g_company.debug:registerScriptName("GC_HorseHelper");

GC_HorseHelper.price = 300;

function GC_HorseHelper:init()
	local self = setmetatable({}, GC_HorseHelper_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;	
	
	self.debugData = g_company.debug:getDebugData(GC_HorseHelper.debugIndex, g_company);

	g_currentMission.environment:addHourChangeListener(self);		
    g_company.settings:initSetting(self, "horseHelper", true);
end;

function GC_HorseHelper:hourChanged()
	if g_company.settings:getSetting("horseHelper", true) and g_currentMission.environment.currentHour == 23 then		
		local moneyToOwner = {};
		for _,husbandry in pairs(g_currentMission.husbandries) do
			for _,animal in pairs(husbandry:getAnimals()) do
				if animal.module.animalType == "HORSE" then
					local owner = animal.owner.ownerFarmId;
					if moneyToOwner[owner] == nil then
						moneyToOwner[owner] = 0;
					end;				
					moneyToOwner[owner] = moneyToOwner[owner] + ((animal.DAILY_TARGET_RIDING_TIME - animal.ridingTimer) / animal.DAILY_TARGET_RIDING_TIME);

					animal.ridingTimerSent  = animal.DAILY_TARGET_RIDING_TIME;
					animal.ridingTimer  = animal.DAILY_TARGET_RIDING_TIME;
				end;
			end;	
		end;
		for owner, factor in pairs(moneyToOwner) do
			if g_server ~= nil then
				g_currentMission:addMoney(factor * GC_HorseHelper.price * -1, owner, "animalUpkeep");
			end;
		end;	
	end;
end;

g_company.addInit(GC_HorseHelper, GC_HorseHelper.init);