--
-- GlobalCompany - Additionals - GC_Objectinfo
--
-- @Interface: --
-- @Author: LS-Modcompany / aPuehri
-- @Date: 05.03.2019
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
-- optimzed Gui
--
--

GC_ObjectInfo = {};
local GC_ObjectInfo_mt = Class(GC_ObjectInfo);
InitObjectClass(GC_ObjectInfo, "GC_ObjectInfo");

GC_ObjectInfo.debugIndex = g_company.debug:registerScriptName("ObjectInfo");

GC_ObjectInfo.showInfo = false;
-- temporary solution until Gui function finished
-- Text Settings
local uiScale = g_gameSettings:getValue("uiScale");
GC_ObjectInfo.textSetting = {};
GC_ObjectInfo.textSetting.size = 0.02 * uiScale;				-- TextSize
GC_ObjectInfo.textSetting.bold = true;							-- Bold
GC_ObjectInfo.textSetting.alignment = RenderText.ALIGN_CENTER;	-- Text Alignment
GC_ObjectInfo.textSetting.x = 0.5;								-- X-Pos
GC_ObjectInfo.textSetting.y = 0.55;							-- Y-Pos
GC_ObjectInfo.textBackground = Overlay:new("dataS2/menu/white.dds", GC_ObjectInfo.textSetting.x - 0.055 , GC_ObjectInfo.textSetting.y - (GC_ObjectInfo.textSetting.size * 1.4) , 0.11 , (2 * GC_ObjectInfo.textSetting.size * 1.2));
GC_ObjectInfo.textBackground:setColor(0.018, 0.016, 0.015, 0.75);
GC_ObjectInfo.textFrame = Overlay:new(GlobalCompany.dir .. "images/frame.dds", GC_ObjectInfo.textSetting.x - 0.055 , GC_ObjectInfo.textSetting.y - (GC_ObjectInfo.textSetting.size * 1.4) , 0.11 , (2 * GC_ObjectInfo.textSetting.size * 1.2));
GC_ObjectInfo.textFrame:setColor(0.9910, 0.3865, 0.0100, 1);

	
function GC_ObjectInfo:init()
	local self = {};
	setmetatable(self, GC_ObjectInfo_mt);

	self.isServer = g_server ~= nil;
	self.isClient = g_client ~= nil;
	
	self.debugPrintDone = false;
	
	self.debugData = g_company.debug:getDebugData(GC_ObjectInfo.debugIndex, g_company);

	if self.isClient then
		FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, GC_ObjectInfo.drawObject);
		g_company.addUpdateable(self, self.update);	
	end;
	
	return self;
end;


function GC_ObjectInfo:update(dt)
	GC_ObjectInfo.showInfo = false;
	if self.isClient and g_currentMission.player.isControlled and not g_currentMission.player.isCarryingObject then
		if g_currentMission.player.isObjectInRange then
			if (g_currentMission.player.lastFoundObject ~= nil) then
				local foundObjectId = g_currentMission.player.lastFoundObject;
				if not self.debugPrintDone then
					g_company.debug:writeDev(self.debugData, "New foundObjectId = "..tostring(foundObjectId));
				end;
				if (foundObjectId ~= g_currentMission.terrainDetailId) then	
					if getRigidBodyType(foundObjectId) == "Dynamic" then
						local object = g_currentMission:getNodeObject(foundObjectId);
						if (object~= nil) then
							if (object.fillType ~= nil) and (object.fillLevel ~= nil) then
								local name= Utils.getNoNil(g_fillTypeManager.fillTypes[object.fillType].title,"unknown");
								GC_ObjectInfo.showInfoText = g_company.languageManager:getText('GC_ObjectInfo_filltype')..tostring(name).."\n"..g_company.languageManager:getText('GC_ObjectInfo_level')..tostring(object.fillLevel);
								GC_ObjectInfo.showInfo = true;
							elseif (object.typeName == "pallet") then
								if (object.getFillUnits ~= nil) then
									local fUnit = object:getFillUnits();
									if object:getFillUnitExists(fUnit[1].fillUnitIndex) then
										name = Utils.getNoNil(g_fillTypeManager.fillTypes[fUnit[1].fillType].title,"unknown");
										local lev = Utils.getNoNil(g_company.mathUtils.round(fUnit[1].fillLevel,0.01),0);
										local perc = Utils.getNoNil(g_company.mathUtils.round((object:getFillUnitFillLevelPercentage(fUnit[1].fillUnitIndex) * 100),0.01),0);
										GC_ObjectInfo.showInfoText = g_company.languageManager:getText('GC_ObjectInfo_filltype')..tostring(name).."\n"..g_company.languageManager:getText('GC_ObjectInfo_level')..tostring(lev).." / "..tostring(perc).."%";
										GC_ObjectInfo.showInfo = true;
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
							local name= Utils.getNoNil(g_fillTypeManager.fillTypes[fUnit[1].fillType].title,"unknown");
							local lev = Utils.getNoNil(g_company.mathUtils.round(fUnit[1].fillLevel,0.01),0);
							local perc = Utils.getNoNil(g_company.mathUtils.round((object:getFillUnitFillLevelPercentage(fUnit[1].fillUnitIndex) * 100),0.01),0);
							GC_ObjectInfo.showInfoText = g_company.languageManager:getText('GC_ObjectInfo_filltype')..tostring(name).."\n"..g_company.languageManager:getText('GC_ObjectInfo_level')..tostring(lev).." / "..tostring(perc).."%";
							GC_ObjectInfo.showInfo = true;
						end;
					end;
				end;			
				if not self.debugPrintDone then
					g_company.debug:writeDev(self.debugData, "hitObjectId = "..tostring(hitObjectId)..", locRigidBodyType = "..tostring(locRigidBodyType));
				end;
				self.debugPrintDone = true;
			end;
		end;
	end;
end;

function GC_ObjectInfo:drawObject()
	if g_currentMission.paused or not GC_ObjectInfo.showInfo then	
		return;
	end;
	
	--render Info
	GC_ObjectInfo.textBackground:render();
	GC_ObjectInfo.textFrame:render();
	setTextAlignment(GC_ObjectInfo.textSetting.alignment);
	setTextBold(GC_ObjectInfo.textSetting.bold);
	setTextColor(0.6456, 0.6456, 0.6592, 1);
	renderText(GC_ObjectInfo.textSetting.x, GC_ObjectInfo.textSetting.y , GC_ObjectInfo.textSetting.size, GC_ObjectInfo.showInfoText);
	
	--change to StandardValues
	setTextAlignment(0);
	setTextColor(1, 1, 1, 1);
	setTextBold(false);	
end;

g_company.addInit(GC_ObjectInfo, GC_ObjectInfo.init);
