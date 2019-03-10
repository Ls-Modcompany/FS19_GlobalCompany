--
-- GlobalCompany - Additionals - GC_Objectinfo
--
-- @Interface: --
-- @Author: LS-Modcompany / aPuehri
-- @Date: 08.03.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
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
	
function GC_ObjectInfo:init()
	local self = setmetatable({}, GC_ObjectInfo_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;
	
	self.debugPrintDone = false;
	
	self.debugData = g_company.debug:getDebugData(GC_ObjectInfo.debugIndex, g_company);

	if self.isClient then
		g_company.addUpdateable(self, self.update);	
	end;
	
	return self;
end;

function GC_ObjectInfo:update(dt)
	if self.isClient then
		self.showInfo = false;
		if g_currentMission.player.isControlled and not g_currentMission.player.isCarryingObject then
			if g_currentMission.player.isObjectInRange then
				if (g_currentMission.player.lastFoundObject ~= nil) then
					local foundObjectId = g_currentMission.player.lastFoundObject;
					if not self.debugPrintDone then
						g_company.debug:writeDevDebug(self.debugData, "New foundObjectId = %s", foundObjectId);
					end;
					if (foundObjectId ~= g_currentMission.terrainDetailId) then	
						if getRigidBodyType(foundObjectId) == "Dynamic" then
							local object = g_currentMission:getNodeObject(foundObjectId);
							if (object~= nil) then
								if (object.fillType ~= nil) and (object.fillLevel ~= nil) then
									self.displayLine1 = g_company.languageManager:getText('GC_ObjectInfo_filltype'):format(Utils.getNoNil(g_fillTypeManager.fillTypes[object.fillType].title,"unknown"));
									self.displayLine2 = g_company.languageManager:getText('GC_ObjectInfo_level'):format(object.fillLevel);
									self.showInfo = true;
								elseif (object.typeName == "pallet") then
									if (object.getFillUnits ~= nil) then
										local fUnit = object:getFillUnits();
										if object:getFillUnitExists(fUnit[1].fillUnitIndex) then
											local lev = Utils.getNoNil(g_company.mathUtils.round(fUnit[1].fillLevel,0.01),0);
											local perc = Utils.getNoNil(g_company.mathUtils.round((object:getFillUnitFillLevelPercentage(fUnit[1].fillUnitIndex) * 100),0.01),0);
											self.displayLine1 = g_company.languageManager:getText('GC_ObjectInfo_filltype'):format(Utils.getNoNil(g_fillTypeManager.fillTypes[fUnit[1].fillType].title,"unknown"));
											self.displayLine2 = g_company.languageManager:getText('GC_ObjectInfo_level2'):format(lev, perc);
											self.showInfo = true;
										end;
									end;
								end;
								self.debugPrintDone = true;
							end;			
						end;
					end;
				end;
			else
				self.debugPrintDone = false;
				local x,y,z = localToWorld(g_currentMission.player.cameraNode, 0,0,1.0)
				local dx,dy,dz = localDirectionToWorld(g_currentMission.player.cameraNode, 0,0,-1)
				raycastAll(x,y,z, dx,dy,dz, "infoObjectRaycastCallback", Player.MAX_PICKABLE_OBJECT_DISTANCE, self)
			end;
		end;
			
		if self.showInfo then
			if self.gui == nil then
				self.gui = g_company.gui:openGuiWithData("gcObjectInfo", false, self.displayLine1, self.displayLine2);
			else
				self.gui.classGui:setData(self.displayLine1, self.displayLine2);
			end;
		elseif self.gui ~= nil then			
			g_company.gui:closeGui("gcObjectInfo");
			self.gui = nil;
		end;
	end;
end;

function GC_ObjectInfo:infoObjectRaycastCallback(hitObjectId, x, y, z, distance)
	if (hitObjectId ~= g_currentMission.terrainDetailId) then
		local locRigidBodyType = getRigidBodyType(hitObjectId);
		if (getRigidBodyType(hitObjectId) ~= "NoRigidBody") then		
			local object = g_currentMission:getNodeObject(hitObjectId);		
			if (object~= nil) then
				if (object.typeName == "pallet") then
					if (object.getFillUnits ~= nil) then
						local fUnit = object:getFillUnits();
						if object:getFillUnitExists(fUnit[1].fillUnitIndex) then							
							local lev = Utils.getNoNil(g_company.mathUtils.round(fUnit[1].fillLevel,0.01),0);
							local perc = Utils.getNoNil(g_company.mathUtils.round((object:getFillUnitFillLevelPercentage(fUnit[1].fillUnitIndex) * 100),0.01),0);
							self.displayLine1 = g_company.languageManager:getText('GC_ObjectInfo_filltype'):format(Utils.getNoNil(g_fillTypeManager.fillTypes[fUnit[1].fillType].title,"unknown"));
							self.displayLine2 = g_company.languageManager:getText('GC_ObjectInfo_level2'):format(lev, perc);
							self.showInfo = true;
						end;
					end;
				end;			
				if not self.debugPrintDone then
					g_company.debug:writeDevDebug(self.debugData, "hitObjectId = %s, locRigidBodyType = %s", hitObjectId, locRigidBodyType);
				end;
				self.debugPrintDone = true;
			end;
		end;
	end;
end;

g_company.addInit(GC_ObjectInfo, GC_ObjectInfo.init);