--
-- GlobalCompany - Objects - GC_BaleShreader
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.02.2019
-- @Version: 1.0.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (26.02.2019):
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

BaleShreader = {};
BaleShreader_mt = Class(BaleShreader, Object);
InitObjectClass(BaleShreader, "BaleShreader");

BaleShreader.debugIndex = g_company.debug:registerScriptName("BaleShreader");

BaleShreader.STATE_STEER_OFF = 0;
BaleShreader.STATE_STEER_ON = 1;
BaleShreader.STATE_WORKING_OFF = 2;
BaleShreader.STATE_WORKING_ON = 3;
BaleShreader.STATE_WORKLIGHT_OFF = 4;
BaleShreader.STATE_WORKLIGHT_ON = 5;

BaleShreader.WORKING_WORK = 0;
BaleShreader.WORKING_LIGHT = 1;

getfenv(0)["GC_BaleShreader"] = BaleShreader;

function BaleShreader:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	if indexName ~= nil and xmlFilename ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;
		local object = BaleShreader:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.baleShreaders.baleShreader", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);
				g_company.debug:writeOnCreate(object.debugData, "[BALESHREADER - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);
			else
				g_company.debug:writeOnCreate(object.debugData, "[BALESHREADER - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;
			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[BALESHREADER - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[BALESHREADER - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	end;
end;

function BaleShreader:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or BaleShreader_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;

	self.state_steer = BaleShreader.STATE_STEER_OFF;
	self.STATE_working = BaleShreader.STATE_WORKING_OFF;
	self.state_lights = BaleShreader.STATE_WORKLIGHT_OFF;

	self.debugData = g_company.debug:getDebugData(BaleShreader.debugIndex, nil, customEnvironment);

	return self;
end;

function BaleShreader:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	self.nodeId  = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.triggerManager = GC_TriggerManager:new(self);
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "BaleShreader_" .. indexName;
	end;
	
    local workAction = getXMLString(xmlFile, string.format("%s.actions.workingAction#action", xmlKey));
	local lightAction = getXMLString(xmlFile, string.format("%s.actions.lightAction#action", xmlKey));
	
    self.workWorking = g_company.activableObject:new(self.isServer, self.isClient);
    self.workWorking:load(self, BaleShreader.WORKING_WORK, workAction);
    self.workWorking:setToOnText(g_company.languageManager:getText("GC_baleShreader_startWork"));
    self.workWorking:setToOffText(g_company.languageManager:getText("GC_baleShreader_endWork"));
	
    self.lightWorking = g_company.activableObject:new(self.isServer, self.isClient);
    self.lightWorking:load(self, BaleShreader.WORKING_LIGHT, lightAction);
    self.lightWorking:setToOnText(g_company.languageManager:getText("GC_baleShreader_toggleOnWorkLight"));
    self.lightWorking:setToOffText(g_company.languageManager:getText("GC_baleShreader_toggleOffWorkLight"));
	
    self.rotationNodes = g_company.rotationNodes:new(self.isServer, self.isClient);
    self.rotationNodes:load(self.nodeId, self, xmlFile, xmlKey, "rollers");
	
	self.doorAnimation = g_company.animations:new(self.isServer, self.isClient);
	self.doorAnimation:load(nodeId, true, string.format("%s.door", xmlKey), xmlFile, nil, self.i3dMappings);
	
    self.workLight = g_company.lighting:new(self.isServer, self.isClient);
	self.workLight:load(self.nodeId, self, xmlFile, string.format("%s.workingLights", xmlKey), self.basedirectory, false);	
	
    self.beaconLight = g_company.lighting:new(self.isServer, self.isClient);
	self.beaconLight:load(self.nodeId, self, xmlFile, string.format("%s.workLighBeacon", xmlKey), self.basedirectory, false);
	
	self.playerTrigger = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId , xmlFile, string.format("%s.playerTrigger", xmlKey), nil, true);
	self.playerTrigger:setActivateText(g_company.languageManager:getText("GC_baleShreader_openSteer"));




	local fillTypesKey = string.format("%s.fillTypes", xmlKey);
	if not hasXMLProperty(xmlFile, fillTypesKey) then
		--debug
		return false;
	end;

	self.baleFillTypes = {};
	local i = 0;
	while true do
		local fillTypeKey = string.format("%s.fillType(%d)", fillTypesKey, i);
		if not hasXMLProperty(xmlFile, fillTypeKey) then
			break;
		end;

		local fillTypeName = getXMLString(xmlFile, fillTypeKey .. "#name");
		if fillTypeName ~= nil then
			local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName);
			if fillType ~= nil then
				table.insert(self.baleFillTypes, fillType.index)		
			else
				if fillType == nil then
					g_company.debug:writeModding(self.debugData, "[BALESHREADER - %s] Unknown fillType ( %s ) found", indexName, fillTypeName);
				end;
			end;
		end;
		i = i + 1;
	end;
	self.baleTrigger = self.triggerManager:loadTrigger(GC_UnloadingTrigger, self.nodeId , xmlFile, string.format("%s.baleTrigger", xmlKey), self.baleFillTypes, {[1] = "BALE"});
	self.baleTrigger.onlyUpdateOneBale = true;
	self.baleTrigger.baleDeleteLitersPerMS = 0;

	self.BaleShreaderDirtyFlag = self:getNextDirtyFlag();

	return true;
end;

function BaleShreader:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self)

	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;
	
	BaleShreader:superClass().delete(self)
end;


function BaleShreader:readStream(streamId, connection)
	BaleShreader:superClass().readStream(self, streamId, connection);

	if connection:getIsServer() then
		-- Code will be added when 'BaleShreader.lua' is complete.
	end;
end;

function BaleShreader:writeStream(streamId, connection)
	BaleShreader:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
		-- Code will be added when 'BaleShreader.lua' is complete.
	end;
end;

function BaleShreader:readUpdateStream(streamId, timestamp, connection)
	BaleShreader:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
		if streamReadBool(streamId) then
			-- Code will be added when 'BaleShreader.lua' is complete.
		end;
	end;
end;

function BaleShreader:writeUpdateStream(streamId, connection, dirtyMask)
	BaleShreader:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
		if streamWriteBool(streamId, bitAND(dirtyMask, self.BaleShreaderDirtyFlag) ~= 0) then
			-- Code will be added when 'BaleShreader.lua' is complete.
		end;
	end;
end;

function BaleShreader:loadFromXMLFile(xmlFile, key)

	return true;
end;

function BaleShreader:saveToXMLFile(xmlFile, key, usedModNames)
	
end;

function BaleShreader:update(dt)
	
end;

function BaleShreader:playerTriggerActivated(dt)
	local state, text;

	if self.state_steer == BaleShreader.STATE_STEER_OFF then
		self.state_steer = BaleShreader.STATE_STEER_ON;
		text = g_company.languageManager:getText("GC_baleShreader_closeSteer");
		self.doorAnimation:setAnimationsState(true);
		self.workWorking:addActivatableObject();    
		self.lightWorking:addActivatableObject();    
	else
		self.state_steer = BaleShreader.STATE_STEER_OFF;
		text = g_company.languageManager:getText("GC_baleShreader_openSteer");
		self.doorAnimation:setAnimationsState(false);
		self.workWorking:removeActivatableObject();    
		self.lightWorking:removeActivatableObject();     
	end;

	self.playerTrigger:setActivateText(text);

	self:raiseDirtyFlags(self.BaleShreaderDirtyFlag);
end;

function BaleShreader:onActivableObject(reference)
	if reference == BaleShreader.WORKING_WORK then    
		self.beaconLight:setAllLightsState();
	elseif reference == BaleShreader.WORKING_LIGHT then   
		self.workLight:setAllLightsState();     
    end;
end

function BaleShreader:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
	
end;

function BaleShreader:getFreeCapacity()
	return 100000;	
end