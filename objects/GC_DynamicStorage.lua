--
-- GlobalCompany - Objects - GC_DynamicStorage
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 02.01.2020
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.0.0 (02.01.2020):
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

GC_DynamicStorage = {};
GC_DynamicStorage._mt = Class(GC_DynamicStorage, g_company.gc_class);
InitObjectClass(GC_DynamicStorage, "GC_DynamicStorage");

GC_DynamicStorage.BACKUP_TITLE = ""

GC_DynamicStorage.debugIndex = g_company.debug:registerScriptName("GC_DynamicStorage");

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
    return GC_DynamicStorage:superClass():new(GC_DynamicStorage._mt, isServer, isClient, scriptDebugInfo, xmlFilename, baseDirectory, customEnvironment);
end;

function GC_DynamicStorage:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	GC_PlaceableDigitalDisplay:superClass().load(self)
	local canLoad, addMinuteChange, addHourChange = true, false, false;

	self.rootNode = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.triggerManager = GC_TriggerManager:new(self);
    self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");
    
    local materialPath = getXMLString(xmlFile, xmlKey .. ".materials#materialHolder");
	self.materials = GC_i3dLoader:loadMaterials(materialPath, self.baseDirectory, xmlFile, xmlKey .. ".materials", self.i3dMappings);

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "DynamicStorage_" .. indexName;
    end;
    
    self.guiData = {}
    local dynamicStorageImage = getXMLString(xmlFile, xmlKey .. ".guiInformation#imageFilename")
	if dynamicStorageImage ~= nil then
        self.guiData.dynamicStorageImage = self.baseDirectory .. dynamicStorageImage
    else
        for _,mod in pairs(g_modManager.nameToMod) do
            if mod.modDir == self.baseDirectory then
                self.guiData.dynamicStorageImage = mod.iconFilename
            end
        end
    end

    local dynamicStorageTitle = getXMLString(xmlFile, xmlKey .. ".guiInformation#title")
	if dynamicStorageTitle ~= nil then
		self.guiData.dynamicStorageTitle = g_company.languageManager:getText(dynamicStorageTitle)
	else
		self.guiData.dynamicStorageTitle = g_company.languageManager:getText("GC_gui_dynamicStorage_titleBackup")
	end

    self.fillTypes = {};
    self.places = {};

    self.activeUnloadingBox = 1;
    self.vehicleInteractionInTrigger = false;
    self.vehicleInteractionConter = 0;

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
                    --g_company.debug:writeModding(self.debugData, "[DYNAMICSTORAGE - %s] Unknown fillType ( %s ), ignoring!", fillTypeName);
                else
                    --g_company.debug:writeModding(self.debugData, "[DYNAMICSTORAGE - %s] Duplicate fillType ( %s )!", fillTypeName);
                end;
            end;
        end;
        i = i + 1;
    end;

    local unloadingTriggerKey = string.format("%s.unloadingTrigger", xmlKey);    
    local unloadingTrigger = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.rootNode, self, xmlFile, unloadingTriggerKey, self.fillTypes);
    if unloadingTrigger ~= nil then
        unloadingTrigger.useTargetGetIsFillTypeAllowed = false
        self.unloadingTrigger = unloadingTrigger;
    end;

    local loadingTriggerKey = string.format("%s.loadingTrigger", xmlKey);
    local loadingTrigger = self.triggerManager:addTrigger(GC_LoadingTrigger, self.rootNode, self, xmlFile, loadingTriggerKey, {}, false, true);
    if loadingTrigger ~= nil then        
        loadingTrigger.onActivateObject = function() self:loadingTriggerOnActivateObject() end;
        self.loadingTrigger = loadingTrigger;
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

        place.shovelTrigger = self.triggerManager:addTrigger(GC_ShovelFillTrigger, self.rootNode, self, xmlFile, placeKey .. ".shovelFillTrigger", place.activeFillTypeIndex);
        place.shovelTrigger.extraParamater = place.number;
        
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

        if hasXMLProperty(xmlFile, placeKey .. ".unloadingTrigger") then            
            local unloadingTrigger = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.rootNode, self, xmlFile, placeKey .. ".unloadingTrigger", {})
            if unloadingTrigger ~= nil then
                unloadingTrigger.extraParamater = {isUnloadingTrigger = true, id=place.number}
                place.unloadingTrigger = unloadingTrigger
            end
        end        
        
        if self.isClient then
            place.unloadingEffects = g_effectManager:loadEffect(xmlFile, placeKey .. ".loading.effects", nodeId, self, self.i3dMappings);
            place.unloadingEffectsTimer = 0;
            
			local fillSoundNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".loading.sounds#fillSoundNode"), self.i3dMappings)
            local fillSoundIdentifier = getXMLString(xmlFile, placeKey .. ".loading.sounds#fillSoundIdentifier")
			if fillSoundIdentifier ~= nil then
				local xmlSoundFile = loadXMLFile("mapXML", g_currentMission.missionInfo.mapSoundXmlFilename)
				if xmlSoundFile ~= nil and xmlSoundFile ~= 0 then
					local directory = g_currentMission.baseDirectory
					local modName, baseDirectory = Utils.getModNameAndBaseDirectory(g_currentMission.missionInfo.mapSoundXmlFilename)
					if modName ~= nil then
						directory = baseDirectory .. modName
					end

					place.samplesLoad = g_soundManager:loadSampleFromXML(xmlSoundFile, "sound.object", fillSoundIdentifier, directory, getRootNode(), 0, AudioGroup.ENVIRONMENT, nil, nil)
					if self.samplesLoad ~= nil then
						link(nodeId, self.samplesLoad.soundNode)
						setTranslation(self.samplesLoad.soundNode, 0, 0, 0)
					end

					delete(xmlSoundFile)
                end
            end;

            place.effectIsOn = false
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
        
    g_company.addRaisedUpdateable(self);

    self.globalIndex = g_company.addDynamicStorage(self)

	return true;
end;

function GC_DynamicStorage:finalizePlacement()
	GC_PlaceableDigitalDisplay:superClass().finalizePlacement(self)	
    self.eventId_setActiveUnloadingBox = self:registerEvent(self, self.setActiveUnloadingBoxEvent, false, false)
    self.eventId_setActiveLoadingBox = self:registerEvent(self, self.setActiveLoadingBoxEvent, false, false)
    self.eventId_setEffectState = self:registerEvent(self, self.setEffectStateEvent, false, false)    
end

function GC_DynamicStorage:delete()
    g_company.removeDynamicStorage(self, self.globalIndex)
    
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;
	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers();
    end;
	if self.vehicleInteractionActivation ~= nil then
        self.vehicleInteractionActivation:delete();
    end;

    if self.isClient then  
        for _,place in pairs(self.places) do
            g_effectManager:deleteEffects(place.unloadingEffects);
        end;
    end;

    removeTrigger(self.vehicleInteractionNode);
	GC_DynamicStorage:superClass().delete(self);
end;

function GC_DynamicStorage:readStream(streamId, connection)
	GC_DynamicStorage:superClass().readStream(self, streamId, connection);

    self:setActiveUnloadingBox(streamReadInt8(streamId), false);

	if connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:readStream(streamId, connection)
        end
        
        for _,place in pairs (self.places) do
            local fillLevel =  streamReadFloat32(streamId);
            local fillTypeIndex =  streamReadInt16(streamId);
            self:updatePlace(place, fillLevel, fillTypeIndex);
        end;

		if streamReadBool(streamId) then
			local customTitle = streamReadString(streamId)
			self:setCustomTitle(customTitle, true)
		end

        --local loadingTrigger = NetworkUtil.readNodeObjectId(streamId);
        --g_client:finishRegisterObject(self.loadingTrigger, loadingTrigger);
	end;
end;

function GC_DynamicStorage:writeStream(streamId, connection)
	GC_DynamicStorage:superClass().writeStream(self, streamId, connection);

    streamWriteInt8(streamId, self.activeUnloadingBox);

	if not connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:writeStream(streamId, connection)
		end

        for _,place in pairs (self.places) do     
            streamWriteFloat32(streamId, place.fillLevel);
            streamWriteInt16(streamId, place.activeFillTypeIndex);
        end;

		local customTitle = self:getCustomTitle()
		if streamWriteBool(streamId, customTitle ~= GC_DynamicStorage.BACKUP_TITLE) then
			streamWriteString(streamId, customTitle)
		end

        --NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.loadingTrigger));
        --g_server:registerObjectInStream(connection, self.loadingTrigger);
	end;
end;

function GC_DynamicStorage:readUpdateStream(streamId, timestamp, connection)
	GC_DynamicStorage:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
        if streamReadBool(streamId) then
            for _,place in pairs (self.places) do
                local fillLevel =  streamReadFloat32(streamId);
                local fillTypeIndex =  streamReadInt16(streamId);
                self:updatePlace(place, fillLevel, fillTypeIndex);
            end;
        end;		
	end;
end;

function GC_DynamicStorage:writeUpdateStream(streamId, connection, dirtyMask)
	GC_DynamicStorage:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
		if streamWriteBool(streamId, bitAND(dirtyMask, self.dynamicStorageDirtyFlag) ~= 0) then
            for _,place in pairs (self.places) do     
                streamWriteFloat32(streamId, place.fillLevel);
                streamWriteInt16(streamId, place.activeFillTypeIndex);
            end;
        end;
	end;
end;

function GC_DynamicStorage:loadFromXMLFile(xmlFile, key)
	GC_PlaceableDigitalDisplay:superClass().loadFromXMLFile(self, xmlFile, key)
    if not self.isPlaceable then
		key = string.format("%s.dynamicStorage", key);
    end

    local customTitle = getXMLString(xmlFile, key .. "#customTitle")
    if customTitle ~= nil and customTitle ~= "" then
        self:setCustomTitle(customTitle, true)
    end

    self:setActiveUnloadingBox(getXMLInt(xmlFile, key .. "#activeUnloadingBox"), false);

    local index = 0;
	while true do
		local placeKey = string.format(key .. ".place(%d)", index)
		if not hasXMLProperty(xmlFile, placeKey) then
			break
        end
        
        local num = getXMLInt(xmlFile, placeKey .. "#num");
        local fillLevel = getXMLInt(xmlFile, placeKey .. "#fillLevel");
        local activeFillTypeIndex = getXMLInt(xmlFile, placeKey .. "#activeFillTypeIndex");

        if activeFillTypeIndex ~= -1 then
            for _,place in pairs(self.places) do
                if place.number == num then
                    place.activeFillTypeIndex = activeFillTypeIndex;
                    place.shovelTrigger.fillTypeIndex = activeFillTypeIndex;

                    --place.unloadingTrigger.fillTypes = nil
                    --place.unloadingTrigger:setAcceptedFillTypeState(activeFillTypeIndex, true);

                    local material = self.materials[g_fillTypeManager:getFillTypeNameByIndex(activeFillTypeIndex):lower()];            
                    if material ~= nil then
                        for _,mover in pairs(place.movers.movers) do
                            setMaterial(mover.node, material, 0);
                        end;
                    end;
                    place.fillLevel = fillLevel;
                    place.movers:updateMovers(place.fillLevel);
                    place.digitalDisplays:updateLevelDisplays(place.fillLevel, place.capacity);                
                    break;
                end;
            end;
        end;

        index = index + 1;
    end;

	return true;
end;

function GC_DynamicStorage:saveToXMLFile(xmlFile, key, usedModNames)
	GC_PlaceableDigitalDisplay:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
	if not self.isPlaceable then
		key = string.format("%s.dynamicStorage", key);
		setXMLInt(xmlFile, key .. "#farmId", self:getOwnerFarmId());
    end

    local customTitle = self:getCustomTitle()
	if customTitle ~= GC_DynamicStorage.BACKUP_TITLE then
		setXMLString(xmlFile, key .. "#customTitle", customTitle)
	end
    
    setXMLInt(xmlFile, key .. "#activeUnloadingBox", self.activeUnloadingBox);

	local index = 0;
    for _, place in pairs(self.places) do
        local placeKey = string.format("%s.place(%d)", key, index);
        setXMLInt(xmlFile, placeKey .. "#num", place.number);
        setXMLInt(xmlFile, placeKey .. "#fillLevel", place.fillLevel);
        setXMLInt(xmlFile, placeKey .. "#activeFillTypeIndex", place.activeFillTypeIndex);
        index = index + 1;
    end;
end;

function GC_DynamicStorage:update(dt)     
	GC_PlaceableDigitalDisplay:superClass().update(self, dt)
    if self.isClient then      
        for _,place in pairs(self.places) do  
            if place.unloadingEffectsTimer > 0 then
                place.unloadingEffectsTimer = place.unloadingEffectsTimer - dt;
                if place.unloadingEffectsTimer <= 0 then
                    g_effectManager:stopEffects(place.unloadingEffects);
                    g_soundManager:stopSample(place.samplesLoad);
                    place.effectIsOn = false     
                else
                    self:raiseUpdate();
                end;
            end;
        end;
    end;
end;

function GC_DynamicStorage:getFreeCapacity(fillTypeIndex, farmId, triggerId)        
    local activeUnloadingBox = self.activeUnloadingBox   
    if triggerId ~= nil and triggerId.isUnloadingTrigger then
        activeUnloadingBox = triggerId.id            
    end

    if self.places[activeUnloadingBox].fillLevel > 0 then
        if fillTypeIndex == self.places[activeUnloadingBox].activeFillTypeIndex then
            return self.places[activeUnloadingBox].capacity - self.places[activeUnloadingBox].fillLevel;
        else
            return 0;
        end;
    else
        return self.places[activeUnloadingBox].capacity;
    end;
end;

function GC_DynamicStorage:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
    if fillLevelDelta > 0 then        
        local activeUnloadingBox = self.activeUnloadingBox       
        if triggerId ~= nil and triggerId.isUnloadingTrigger then
            activeUnloadingBox = triggerId.id            
        end

        self:updatePlace(self.places[activeUnloadingBox], self.places[activeUnloadingBox].fillLevel + fillLevelDelta, fillTypeIndex);        
        if triggerId == nil or not triggerId.isUnloadingTrigger then
            self:setEffectStateEvent({activeUnloadingBox})
        end

        if self.isServer then
            self:raiseDirtyFlags(self.dynamicStorageDirtyFlag);
        end;
    end;
end;

function GC_DynamicStorage:removeFillLevel(farmId, fillLevelDelta, fillTypeIndex, extraParamater)
    if fillLevelDelta > 0 then
        local place;
        if extraParamater ~= nil then
            place = self.places[extraParamater];
        else
            place = self.places[self.activeLoadingBox];
        end;
        self:updatePlace(place, place.fillLevel - fillLevelDelta, fillTypeIndex);
        
        if self.isServer then
            self:raiseDirtyFlags(self.dynamicStorageDirtyFlag);
        end;
        return place.fillLevel;
    end;
	return 0;
end;

function GC_DynamicStorage:updatePlace(place, fillLevel, fillTypeIndex)    
    if place.fillLevel == 0 and fillLevel > 0 then        
        place.activeFillTypeIndex = fillTypeIndex;
        place.shovelTrigger.fillTypeIndex = fillTypeIndex;
        local material = self.materials[g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex):lower()];            
        if material ~= nil then
            for _,mover in pairs(place.movers.movers) do
                setMaterial(mover.node, material, 0);
            end;
        end;
    end;
    if place.activeFillTypeIndex == fillTypeIndex then
        place.fillLevel = fillLevel;      
        place.movers:updateMovers(place.fillLevel);
        place.digitalDisplays:updateLevelDisplays(place.fillLevel, place.capacity);        
    end;
end

function GC_DynamicStorage:getProvidedFillTypes()
	return self.fillTypes;
end;

function GC_DynamicStorage:getAllProvidedFillLevels(farmId)
	return {}, 0;
end;

function GC_DynamicStorage:getProvidedFillLevel(fillTypeIndex, farmId, extraParamater)
    if extraParamater ~= nil then
        return self.places[extraParamater].fillLevel;
    end;
	return self.places[self.activeLoadingBox].fillLevel;
end;

function GC_DynamicStorage:getNumOfPlaces()
    return table.getn(self.places);
end;

function GC_DynamicStorage:setActiveUnloadingBox(number, noEventSend)
	self:setActiveUnloadingBoxEvent({number}, noEventSend);
end;

function GC_DynamicStorage:setActiveUnloadingBoxEvent(data, noEventSend) 
    self:raiseEvent(self.eventId_setActiveUnloadingBox, data, noEventSend)
    self.activeUnloadingBox = Utils.getNoNil(data[1], 1);
end;

function GC_DynamicStorage:setActiveLoadingBox(number)
	self:setActiveLoadingBoxEvent({number}, noEventSend);
end;

function GC_DynamicStorage:setActiveLoadingBoxEvent(data, noEventSend)
    self:raiseEvent(self.eventId_setActiveLoadingBox, data, noEventSend)
    self.activeLoadingBox = Utils.getNoNil(data[1], 1);
end;

function GC_DynamicStorage:setEffectStateEvent(data, noEventSend)
    self:raiseEvent(self.eventId_setEffectState, data, noEventSend)
    if self.isClient then
        local place = self.places[data[1]]
        if not place.effectIsOn then
            g_effectManager:setFillType(place.unloadingEffects, place.activeFillTypeIndex)
            g_effectManager:startEffects(place.unloadingEffects)
            g_soundManager:playSample(place.samplesLoad)
            place.effectIsOn = true        
        end
        place.unloadingEffectsTimer = 1000
        self:raiseUpdate()
    end
end;

function GC_DynamicStorage:onActivableObject()
	g_company.gui:openGuiWithData("gc_dynamicStorage", false, self, true, self.activeUnloadingBox);
    self.vehicleInteractionActivation:removeActivatableObject();
    self.vehicleInteractionActivation:addActivatableObject();
end;

function GC_DynamicStorage:vehicleInteractionTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)	
    if onEnter or onLeave then
        if onEnter then
            if self.vehicleInteractionInTrigger then          
                self.vehicleInteractionActivation:removeActivatableObject();
            end;
            self.vehicleInteractionInTrigger = true;
            self.vehicleInteractionActivation:addActivatableObject();
        else
            if self.vehicleInteractionInTrigger then
                self.vehicleInteractionInTrigger = false;
                self.vehicleInteractionActivation:removeActivatableObject();
            end;
        end;
    end;
end;

function GC_DynamicStorage:loadingTriggerOnActivateObject()
    if not self.loadingTrigger.isLoading then
        local gui = g_company.gui:openGuiWithData("gc_dynamicStorage", false, self, false);
        gui.classGui:setCloseCallback(self, self.loadingTriggerOnActivateObjectCallback);
    else
        self.loadingTrigger:setIsLoading(false);
    end;
	g_currentMission:addActivatableObject(self.loadingTrigger);
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

function GC_DynamicStorage:setCustomTitle(customTitle, noEventSend)
	if customTitle ~= nil and customTitle ~= self:getCustomTitle() then
		GC_ProductionDynamicStorageCustomTitleEvent.sendEvent(self, customTitle, noEventSend)

		self.guiData.dynamicStorageCustomTitle = customTitle
	end
end

function GC_DynamicStorage:getCustomTitle()
	local title = self.guiData.dynamicStorageCustomTitle

	if title == nil then
		title = GC_DynamicStorage.BACKUP_TITLE
	end

	return title
end

function GC_DynamicStorage:getIsFillTypeAllowed(fillTypeIndex, triggerData)
    local place = self.places[triggerData.id]
    return place.fillLevel == 0 or place.activeFillTypeIndex == fillTypeIndex
end