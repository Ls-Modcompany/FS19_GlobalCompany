--
-- GlobalCompany - Objects - GC_DynamicStorage
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 04.06.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (04.06.2019):
-- 		- initial fs19 (kevink98)
--
--
-- Notes:
--      - some parts from productionFactory
--
-- ToDo:
--
--
--

GC_DynamicStorage = {};
local GC_DynamicStorage_mt = Class(GC_DynamicStorage, Object);
InitObjectClass(GC_DynamicStorage, "GC_DynamicStorage");

GC_DynamicStorage.debugIndex = g_company.debug:registerScriptName("GC_DynamicStorage");

getfenv(0)["GC_DynamicStorage"] = GC_DynamicStorage;

function GC_DynamicStorage:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	local farmlandId = getUserAttribute(transformId, "farmlandId");

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;

		local object = GC_DynamicStorage:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.dynamicStorages.dynamicStorage", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);

				g_company.debug:writeOnCreate(object.debugData, "[DYNAMICSTORAGE - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);

				local warningText = string.format("[DYNAMICSTORAGE - %s]  Attribute 'farmlandId' is invalid! DYNAMICSTORAGE will not operate correctly. 'farmlandId' should match area object is located at.", indexName);
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText);
			else
				g_company.debug:writeOnCreate(object.debugData, "[DYNAMICSTORAGE - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;

			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[DYNAMICSTORAGE - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[DYNAMICSTORAGE - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [GC_DynamicStorage]");
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'DYNAMICSTORAGE' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId));
		else
			if xmlFilename == nil then
				g_company.debug:print("    ONCREATE: [DYNAMICSTORAGE - %s]  Attribute 'xmlFilename' is missing!", indexName);
			end;

			if farmlandId == nil then
				g_company.debug:print("    ONCREATE: [DYNAMICSTORAGE - %s]  Attribute 'farmlandId' is missing!", indexName);
			end;
		end;
	end;
end;

function GC_DynamicStorage:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or GC_DynamicStorage_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;

	self.debugData = g_company.debug:getDebugData(GC_DynamicStorage.debugIndex, nil, customEnvironment);

	return self;
end;

function GC_DynamicStorage:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	local canLoad, addMinuteChange, addHourChange = true, false, false;

	self.rootNode = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.triggerManager = GC_TriggerManager:new(self);
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "DynamicStorage_" .. indexName;
	end;

    self.fillTypes = {};
    self.places = {};

    self:setActiveUnloadingBox();
    self.vehicleInteractionInTrigger = false;

    local usedFillTypeNames = {};
    local i = 0;
    while true do
        local fillTypesKey = string.format("%s.fillTypes.fillType(%d)", xmlKey, i);
        if not hasXMLProperty(xmlFile, fillTypesKey) then
            break;
        end;

        local fillTypeName = getXMLString(xmlFile, fillTypesKey .. "#name");
        if fillTypeName ~= nil then
            local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName);
            if fillType ~= nil and usedFillTypeNames[fillTypeName] == nil then
                usedFillTypeNames[fillTypeName] = true;
                self.fillTypes[fillType.index] = fillType.index;
            else
                if fillType == nil then
                    g_company.debug:writeModding(self.debugData, "[DYNAMICSTORAGE - %s] Unknown fillType ( %s ), ignoring!", fillTypeName);
                else
                    g_company.debug:writeModding(self.debugData, "[DYNAMICSTORAGE - %s] Duplicate fillType ( %s )!", fillTypeName);
                end;
            end;
        end;
        i = i + 1;
    end;

    local unloadingTriggerKey = string.format("%s.unloadingTrigger", xmlKey);
    local name = getXMLString(xmlFile, unloadingTriggerKey .. "#name");
    if name ~= nil then
        local unloadingTrigger = self.triggerManager:loadTrigger(GC_UnloadingTrigger, self.rootNode, xmlFile, unloadingTriggerKey, self.fillTypes);
        if unloadingTrigger ~= nil then
            self.unloadingTrigger = unloadingTrigger;
        end;
    end;

    local loadingTriggerKey = string.format("%s.loadingTrigger", xmlKey);
    local name = getXMLString(xmlFile, loadingTriggerKey .. "#name");
    if name ~= nil then
        local loadingTrigger = self.triggerManager:loadTrigger(GC_LoadingTrigger, self.rootNode, xmlFile, loadingTriggerKey, {}, false, true);
        if loadingTrigger ~= nil then
            
            loadingTrigger.onActivateObject = function() self:loadingTriggerOnActivateObject() end;
            self.loadingTrigger = loadingTrigger;
        end;
    end;
  
    i = 0;
    while true do
        local placeKey = string.format("%s.places.place(%d)", xmlKey, i);
        if not hasXMLProperty(xmlFile, placeKey) then
            break;
        end;
        
        local place = {};
        place.number = i + 1;
        place.fillLevel = 0;
        place.capacity = getXMLInt(xmlFile, placeKey .. "#capacity");
        place.activeFillTypeIndex = -1;

        if hasXMLProperty(xmlFile, placeKey .. ".movers") then
            local movers = GC_Movers:new(self.isServer, self.isClient);
            if movers:load(self.rootNode, self, xmlFile, placeKey, self.baseDirectory, place.capacity, true) then
                place.movers = movers;
                place.movers:updateMovers(place.fillLevel);
            end;
        end;

        if hasXMLProperty(xmlFile, placeKey .. ".digitalDisplays") then
            local digitalDisplays = GC_DigitalDisplays:new(self.isServer, self.isClient);
            if digitalDisplays:load(self.rootNode, self, xmlFile, placeKey, nil, true) then
                place.digitalDisplays = digitalDisplays;
                place.digitalDisplays:updateLevelDisplays(place.fillLevel, place.capacity);
            end;
        end;
        table.insert(self.places, place);
        i = i + 1;
    end;

    local vehicleInteractionNode = getXMLString(xmlFile, string.format("%s.vehicleInteraction#triggerNode", xmlKey));
    self.vehicleInteractionNode = I3DUtil.indexToObject(self.rootNode, vehicleInteractionNode, self.i3dMappings);
    addTrigger(self.vehicleInteractionNode, "vehicleInteractionTriggerCallback", self);
		
	self.vehicleInteractionActivation = g_company.activableObject:new(self.isServer, self.isClient);
	self.vehicleInteractionActivation:load(self);
	self.vehicleInteractionActivation:loadFromXML(xmlFile, string.format("%s.vehicleInteraction", xmlKey));

    self.dynamicStorageDirtyFlag = self:getNextDirtyFlag();
        
	return true;
end;

function GC_DynamicStorage:delete()
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;
	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
    end;
	if self.vehicleInteractionActivation ~= nil then
        self.vehicleInteractionActivation:delete();
    end;   
	GC_DynamicStorage:superClass().delete(self);
end;

function GC_DynamicStorage:readStream(streamId, connection)
	GC_DynamicStorage:superClass().readStream(self, streamId, connection);

	if connection:getIsServer() then
                
	end;
end;

function GC_DynamicStorage:writeStream(streamId, connection)
	GC_DynamicStorage:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
                
	end;
end;

function GC_DynamicStorage:readUpdateStream(streamId, timestamp, connection)
	GC_DynamicStorage:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
		
	end;
end;

function GC_DynamicStorage:writeUpdateStream(streamId, connection, dirtyMask)
	GC_DynamicStorage:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
		
	end;
end;

function GC_DynamicStorage:loadFromXMLFile(xmlFile, key)
	

	return true;
end;

function GC_DynamicStorage:saveToXMLFile(xmlFile, key, usedModNames)
	
end;

function GC_DynamicStorage:update(dt) end;

function GC_DynamicStorage:getFreeCapacity(fillTypeIndex, farmId, triggerId)
    if self.places[self.activeUnloadingBox].fillLevel > 0 then
        if fillTypeIndex == self.places[self.activeUnloadingBox].activeFillTypeIndex then
            return self.places[self.activeUnloadingBox].capacity - self.places[self.activeUnloadingBox].fillLevel;
        else
            return 0;
        end;
    else
        return self.places[self.activeUnloadingBox].capacity;
    end;
end;

function GC_DynamicStorage:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
    if fillLevelDelta > 0 then
        local place = self.places[self.activeUnloadingBox];
        if place.fillLevel == 0 then
            place.activeFillTypeIndex = fillTypeIndex;
        end;
        if place.activeFillTypeIndex == fillTypeIndex then
            place.fillLevel = place.fillLevel + fillLevelDelta;      
            place.movers:updateMovers(place.fillLevel);
            place.digitalDisplays:updateLevelDisplays(place.fillLevel, place.capacity);
            
            if self.isServer and raiseFlags ~= false then
                self:raiseDirtyFlags(self.dynamicStorageDirtyFlag);
            end;
        end;
    end;
end;

function GC_DynamicStorage:removeFillLevel(farmId, fillLevelDelta, fillTypeIndex, triggerId)
    if fillLevelDelta > 0 then
        local place = self.places[self.activeLoadingBox];
        place.fillLevel = place.fillLevel - fillLevelDelta;      
        place.movers:updateMovers(place.fillLevel);
        place.digitalDisplays:updateLevelDisplays(place.fillLevel, place.capacity);
        
        if self.isServer and raiseFlags ~= false then
            self:raiseDirtyFlags(self.dynamicStorageDirtyFlag);
        end;
        return place.fillLevel;
    end;
	return 0;
end;

function GC_DynamicStorage:getProvidedFillTypes()
	return self.fillTypes;
end;

function GC_DynamicStorage:getAllProvidedFillLevels(farmId)
	return {}, 0;
end;

function GC_DynamicStorage:getProvidedFillLevel(fillTypeIndex, farmId, triggerId)
	return self.places[self.activeLoadingBox].fillLevel;
end;

function GC_DynamicStorage:getNumOfPlaces()
    return table.getn(self.places);
end;

function GC_DynamicStorage:setActiveUnloadingBox(number)
    self.activeUnloadingBox = Utils.getNoNil(number, 1);
end;

function GC_DynamicStorage:setActiveLoadingBox(number)
    self.activeLoadingBox = Utils.getNoNil(number, 1);
end;

function GC_DynamicStorage:onActivableObject()
	g_company.gui:openGuiWithData("gc_dynamicStorage", false, self, true, self.activeUnloadingBox);
    self.vehicleInteractionActivation:removeActivatableObject();
    self.vehicleInteractionActivation:addActivatableObject();
end;

function GC_DynamicStorage:vehicleInteractionTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)	
    if onEnter or onLeave then
        if onEnter then
            if not self.vehicleInteractionInTrigger then
                --if g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), self.target) then				
                    self.vehicleInteractionInTrigger = true;
                    self.vehicleInteractionActivation:addActivatableObject();
                --end;
            end;
        else
            if self.vehicleInteractionInTrigger then
                self.vehicleInteractionInTrigger = false;
                self.vehicleInteractionActivation:removeActivatableObject();
            end;
        end;
    end;
end;

function GC_DynamicStorage:loadingTriggerOnActivateObject()
    local gui = g_company.gui:openGuiWithData("gc_dynamicStorage", false, self, false);
    gui.classGui:setCloseCallback(self, self.loadingTriggerOnActivateObjectCallback);
end

function GC_DynamicStorage:loadingTriggerOnActivateObjectCallback()
    self.loadingTrigger:onFillTypeSelection(self.places[self.activeLoadingBox].activeFillTypeIndex);
end

function GC_DynamicStorage:onSetFarmlandStateChanged(farmId)
	self:setOwnerFarmId(farmId, false);
end;

function GC_DynamicStorage:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_DynamicStorage:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend);
	if self.triggerManager ~= nil then
		self.triggerManager:setAllOwnerFarmIds(ownerFarmId, noEventSend)
	end;
end;