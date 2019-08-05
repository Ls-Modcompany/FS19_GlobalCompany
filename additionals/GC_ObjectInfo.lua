--
-- GlobalCompany - Additionals - GC_Objectinfo
--
-- @Interface: --
-- @Author: LS-Modcompany / aPuehri
-- @Date: 23.06.2019
-- @Version: 1.0.2.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.2.0 (23.06.2019)/(aPuehri):
-- 		- changed client detection
-- 		- added bale owner information in multiplayer
-- 		- added delay to fade out Info
--
-- 	v1.0.1.0 (31.05.2019)/(aPuehri):
-- 		- changed debugPrint
-- 		- added Multiplayer-Support
-- 		- improved ObjectDetection
--
-- 	v1.0.0.0 (08.03.2019):
-- 		- initial fs19 (aPuehri)
--
--
-- Notes:
--
--
-- ToDo:
-- 
--
--

GC_ObjectInfo = {};
local GC_ObjectInfo_mt = Class(GC_ObjectInfo);
InitObjectClass(GC_ObjectInfo, "GC_ObjectInfo");

GC_ObjectInfo.debugIndex = g_company.debug:registerScriptName("Gc_ObjectInfo");
GC_ObjectInfo.foundBale = nil;
GC_ObjectInfo.lastFoundBaleNetworkId = nil;
GC_ObjectInfo.supportedTypes = {"pallet","genetix","attachablePallet","FS19_bresselUndLadeBigBagPack.bigBagRack"};

function GC_ObjectInfo:init()
	local self = setmetatable({}, GC_ObjectInfo_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_dedicatedServerInfo == nil;
	self.isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer;		

	self.debugPrintObjectId = 0;
	self.fadeOutDelay = 0;
	
	self.debugData = g_company.debug:getDebugData(GC_ObjectInfo.debugIndex, g_company);

	self.eventId_getFarmId = g_company.eventManager:registerEvent(self, self.getFarmIdEvent);
	self.eventId_sendFarmId = g_company.eventManager:registerEvent(self, self.sendFarmIdEvent, true);

	if self.isClient then
		g_company.addUpdateable(self, self.update);	
	end;

	g_company.settings:initSetting("objectInfo", true);
	
	return self;
end;

function GC_ObjectInfo:update(dt)
	if self.isClient and g_company.settings:getSetting("objectInfo", true) then				
		if g_currentMission.player.isControlled and not g_currentMission.player.isCarryingObject then
			self.showInfo = false;
			GC_ObjectInfo.foundBale = nil;
			-- check objects in front of player
			local x,y,z = localToWorld(g_currentMission.player.cameraNode, 0,0,1.0);
			local dx,dy,dz = localDirectionToWorld(g_currentMission.player.cameraNode, 0,0,-1);
			local distance = Player.MAX_PICKABLE_OBJECT_DISTANCE * 1.75;
			raycastAll(x,y,z, dx,dy,dz, "infoObjectRaycastCallback", distance, self);			
		else
			self.showInfo = false;
			GC_ObjectInfo.foundBale = nil;
		end;
	else
		self.showInfo = false;
		GC_ObjectInfo.foundBale = nil;
	end;

	if self.showInfo then
		if self.gui == nil then
			self.gui = g_company.gui:openGuiWithData("gcObjectInfo", false, self.displayLine1, self.displayLine2, self.displayLine3);
		else
			self.gui.classGui:setData(self.displayLine1, self.displayLine2, self.displayLine3);
		end;
	elseif not self.showInfo and self.gui ~= nil then
		self.fadeOutDelay = self.fadeOutDelay + (dt * 0.001);
		if self.fadeOutDelay > 0.85 then
			g_company.gui:closeGui("gcObjectInfo");
			self.gui = nil;
			self.fadeOutDelay = 0;
		end;
	elseif not self.showInfo and self.gui == nil and self.fadeOutDelay ~= 0 then
		self.fadeOutDelay = 0;
	end;
end;

function GC_ObjectInfo:infoObjectRaycastCallback(hitObjectId, x, y, z, distance)
	if (hitObjectId ~= nil) and (hitObjectId ~= g_currentMission.terrainDetailId) then
		local locRigidBodyType = getRigidBodyType(hitObjectId);
		if (locRigidBodyType == "Dynamic") or (self.isMultiplayer and (locRigidBodyType == "Kinematic")) then
			local object = g_currentMission:getNodeObject(hitObjectId);		
			if (object~= nil) then
				if (object.typeName ~= nil) then					
					GC_ObjectInfo.foundBale = nil;
					for k, v in pairs(GC_ObjectInfo.supportedTypes) do
						if (object.typeName == v) then
							if (object.getFillUnits ~= nil) then
								local fUnit = object:getFillUnits();								
								if object:getFillUnitExists(fUnit[1].fillUnitIndex) then							
									local lev = Utils.getNoNil(g_company.mathUtils.round(fUnit[1].fillLevel,0.01),0);
									local perc = Utils.getNoNil(g_company.mathUtils.round((object:getFillUnitFillLevelPercentage(fUnit[1].fillUnitIndex) * 100),0.01),0);
									local fill = Utils.getNoNil(g_fillTypeManager.fillTypes[fUnit[1].fillType].title,"unknown");
									if (string.lower(fill) ~= "unknown") then
										self.displayLine1 = g_company.languageManager:getText('GC_ObjectInfo_filltype'):format(fill);
										self.displayLine2 = g_company.languageManager:getText('GC_ObjectInfo_level2'):format(lev, perc);
										self.displayLine3 = g_company.languageManager:getText('GC_ObjectInfo_owner'):format(GC_ObjectInfo:getFarmInfo(object, self, false));
										self.showInfo = true;
									end;
								end;
							end;
						end;
					end;
				elseif (object.typeName == nil) and (object.fillType ~= nil) and (object.fillLevel ~= nil) then
					if object:isa(Bale) then
						GC_ObjectInfo.foundBale = object;
						self.displayLine1 = g_company.languageManager:getText('GC_ObjectInfo_filltype'):format(Utils.getNoNil(g_fillTypeManager.fillTypes[object.fillType].title,"unknown"));
						self.displayLine2 = g_company.languageManager:getText('GC_ObjectInfo_level'):format(g_company.mathUtils.round(object.fillLevel,0.01));
						self.displayLine3 = g_company.languageManager:getText('GC_ObjectInfo_owner'):format(GC_ObjectInfo:getFarmInfo(object, self, false));
						self.showInfo = true;						
					end;
				end;

				if (hitObjectId ~= self.debugPrintObjectId) then
					g_company.debug:writeDevDebug(self.debugData, "hitObjectId = %s, locRigidBodyType = %s", hitObjectId, locRigidBodyType);
					if g_company.debug.printLevel[6] then
						gc_debugPrint(object, nil, 1, "ObjectInfo");
					end;
				end;

				self.debugPrintObjectId = hitObjectId;
			end;
		end;
	end;
end;

function GC_ObjectInfo:getFarmInfo(object, ref, noEventSend)
	local self = ref;
	local farmName = "unknown";
	local farmId = nil;

	if self.isClient and self.isMultiplayer and object:isa(Bale) then
		self.foundBaleNetworkId = NetworkUtil.getObjectId(object);
		
		if GC_ObjectInfo.lastFoundBaleNetworkId ~= self.foundBaleNetworkId then
			GC_ObjectInfo.lastFoundBaleNetworkId = self.foundBaleNetworkId;
			self.mpBaleOwnerId = nil;
			self:getFarmIdEvent({self.foundBaleNetworkId}, noEventSend);			
		end;
		farmId = self.mpBaleOwnerId;
	else
		farmId = object.ownerFarmId;
	end;
	
	if (farmId ~= nil) then
		local farm = g_farmManager:getFarmById(farmId);
		if (farm ~= nil) then
			farmName = farm.name;
			return farmName;
		end;
	end;
	return farmName;
end;

function GC_ObjectInfo:getFarmIdEvent(data, noEventSend)
	g_company.eventManager:createEvent(self.eventId_getFarmId, data, false, noEventSend);
	
	if self.isServer then
		local baleObject = NetworkUtil.getObject(data[1]);
		local farm = g_farmManager:getFarmById(baleObject.ownerFarmId);
		if (farm ~= nil) then
			self:sendFarmIdEvent({baleObject.ownerFarmId});
		end;
	end;
end;

function GC_ObjectInfo:sendFarmIdEvent(data, noEventSend)   
	if self.isServer then
		g_company.eventManager:createEvent(self.eventId_sendFarmId, data, false, noEventSend);
	else
		self.mpBaleOwnerId = data[1];
	end;
end;

g_company.addInit(GC_ObjectInfo, GC_ObjectInfo.init);