--
-- GlobalCompany - Objects - GC_Greenhouse
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 22.03.2018
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (26.04.2019):
-- 		- initial fs17 (GtX)
--
--
-- Notes:
--
--
-- ToDo:
--
--
--


GC_Greenhouse = {};
local GC_Greenhouse_mt = Class(GC_Greenhouse, Object);
InitObjectClass(GC_Greenhouse, "GC_Greenhouse");

GC_Greenhouse.debugIndex = g_company.debug:registerScriptName("GC_Greenhouse");

GC_Greenhouse.DOORTRIGGER = 0;
GC_Greenhouse.GREENHOUSETRIGGER = 1;
GC_Greenhouse.VENTILATOR = 2;
GC_Greenhouse.palletExtendedTrigger = 3;

getfenv(0)["GC_Greenhouse"] = GC_Greenhouse;

function GC_Greenhouse:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	local farmlandId = getUserAttribute(transformId, "farmlandId");

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;

		local object = GC_Greenhouse:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.greenhouses.greenhouse", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);

				g_company.debug:writeOnCreate(object.debugData, "[GREENHOUSE - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);

				local warningText = string.format("[GREENHOUSE - %s]  Attribute 'farmlandId' is invalid! Greenhouse will not operate correctly. 'farmlandId' should match area object is located at.", indexName);
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText);
			else
				g_company.debug:writeOnCreate(object.debugData, "[GREENHOUSE - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;

			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[GREENHOUSE - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[GREENHOUSE - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [GC_Greenhouse]");
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'GREENHOUSE' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId));
		else
			if xmlFilename == nil then
				g_company.debug:print("    ONCREATE: [GREENHOUSE - %s]  Attribute 'xmlFilename' is missing!", indexName);
			end;

			if farmlandId == nil then
				g_company.debug:print("    ONCREATE: [GREENHOUSE - %s]  Attribute 'farmlandId' is missing!", indexName);
			end;
		end;
	end;
end;

function GC_Greenhouse:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or GC_Greenhouse_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;


	self.debugData = g_company.debug:getDebugData(GC_Greenhouse.debugIndex, nil, customEnvironment);

	return self;
end;

function GC_Greenhouse:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	local canLoad, addMinuteChange, addHourChange = true, false, false;

	self.rootNode = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "GC_Greenhouse_mt_" .. indexName;
	end;

	self.triggerManager = GC_TriggerManager:new(self);
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");

	local animationManager = GC_AnimationManager:new(self.isServer, self.isClient);
	if animationManager:load(self.rootNode, self, xmlFile, xmlKey, true) then
		animationManager:register(true);
		self.animationManager = animationManager;
	else
		animationManager:delete();
	end;


	local doorKey = string.format("%s.door", xmlKey);
	if hasXMLProperty(xmlFile, doorKey) then
		self.doorTrigger = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.rootNode, xmlFile, doorKey, GC_Greenhouse.DOORTRIGGER, true);
		self.doorAnimationName = getXMLString(xmlFile, doorKey .. "#animationName");
	end;

	local greenhouseTriggerKey = string.format("%s.greenhouseTrigger", xmlKey);
	if hasXMLProperty(xmlFile, greenhouseTriggerKey) then
		self.greenhouseTrigger = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.rootNode, xmlFile, greenhouseTriggerKey, GC_Greenhouse.GREENHOUSETRIGGER);
	end;

	self.activableObjects = {};
	local i = 0;
	while true do
		local key = string.format("%s.action(%d)", greenhouseTriggerKey, i);
		if not hasXMLProperty(xmlFile, key) then
			break;
		end;

		local name = getXMLString(xmlFile, key .. "#name");
		local turnAction = getXMLString(xmlFile, key .. "#turnAction");
		local onText = getXMLString(xmlFile, key .. "#onText");
		local offText = getXMLString(xmlFile, key .. "#offText");

		local activableObject = g_company.activableObject:new(self.isServer, self.isClient);
		local ref = self[name:upper()];
		activableObject:load(self, ref, turnAction);
		activableObject:setToOnText(g_company.languageManager:getText(onText));
		activableObject:setToOffText(g_company.languageManager:getText(offText));

		activableObject.canActivable = function (self)
			return true;
		end

		self.activableObjects[ref] = activableObject;
		i = i + 1;
	end;

	local palletExtendedTriggerKey = string.format("%s.palletExtendedTrigger", xmlKey);
	if hasXMLProperty(xmlFile, palletExtendedTriggerKey) then
		self.palletExtendedTrigger = self.triggerManager:loadTrigger(GC_PalletExtendedTrigger, self.rootNode, xmlFile, palletExtendedTriggerKey, GC_Greenhouse.palletExtendedTrigger);
	end;
	

	local waterTriggerKey = string.format("%s.watertrigger", xmlKey);
	if hasXMLProperty(xmlFile, palletExtendedTriggerKey) then
		self.waterTrigger = self.triggerManager:loadTrigger(GC_UnloadingTrigger, self.rootNode, xmlFile, waterTriggerKey);
	end;
	
	--[[
	if self.isServer and canLoad then
		if addMinuteChange then
			g_currentMission.environment:addMinuteChangeListener(self);
		end;

		if addHourChange then
			g_currentMission.environment:addHourChangeListener(self);
		end;
	end;
	]]--

	self.greenhouseDirtyFlag = self:getNextDirtyFlag();
	

	return true;
end;



function GC_Greenhouse:delete()
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;

	if self.isServer then
		g_currentMission.environment:removeMinuteChangeListener(self);
		g_currentMission.environment:removeHourChangeListener(self);
	end;

	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;

	if self.animationManager ~= nil then
		self.animationManager:delete();
	end;

	if self.isClient then
	
		
	end;

	GC_Greenhouse:superClass().delete(self);
end;


function GC_Greenhouse:readStream(streamId, connection)
	GC_Greenhouse:superClass().readStream(self, streamId, connection);

	if connection:getIsServer() then
		
		
	end;
end;

function GC_Greenhouse:writeStream(streamId, connection)
	GC_Greenhouse:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
		
		
	end;
end;

function GC_Greenhouse:readUpdateStream(streamId, timestamp, connection)
	GC_Greenhouse:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
		
		
	end;
end;

function GC_Greenhouse:writeUpdateStream(streamId, connection, dirtyMask)
	GC_Greenhouse:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
		
		
	end;
end;

function GC_Greenhouse:loadFromXMLFile(xmlFile, key)
	
	
	
	

	return true;
end;

function GC_Greenhouse:saveToXMLFile(xmlFile, key, usedModNames)
	
	
end;

function GC_Greenhouse:update(dt)
	
	
end;


function GC_Greenhouse:playerTriggerActivated(ref)
	if GC_Greenhouse.DOORTRIGGER == ref then
		if self.animationManager:getAnimationTime(self.doorAnimationName) > 0 then
			self.animationManager:setAnimationByState(self.doorAnimationName, false);
		else
			self.animationManager:setAnimationByState(self.doorAnimationName, true);
		end;
	end;
end;

function GC_Greenhouse:playerTriggerGetActivateText(ref)
	if GC_Greenhouse.DOORTRIGGER == ref then
		if self.animationManager:getAnimationTime(self.doorAnimationName) > 0 then
			return g_company.languageManager:getText("GlobalCompanyPlaceable_Greenhouses_closeDoor");
		else
			return g_company.languageManager:getText("GlobalCompanyPlaceable_Greenhouses_openDoor");
		end;
	end;
end;

function GC_Greenhouse:playerTriggerOnEnter(ref)
	if ref == GC_Greenhouse.GREENHOUSETRIGGER then
		for _, activableObject in pairs(self.activableObjects) do
			if activableObject.canActivable(activableObject) then
				activableObject:addActivatableObject();   
			end;
		end;
	end;
end;

function GC_Greenhouse:playerTriggerOnLeave(ref)
	if ref == GC_Greenhouse.GREENHOUSETRIGGER then
		for _, activableObject in pairs(self.activableObjects) do
			activableObject:removeActivatableObject();
		end;
	end;
end;

function GC_Greenhouse:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, extraParamater)
	print(fillLevelDelta)
	
end;

function GC_Greenhouse:getFreeCapacity()
	return 500;
	
end;

