--
-- GlobalCompany - Objects - GC_AnimalFeeder
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 09.03.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (09.02.2020):
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

GC_AnimalFeeder = {};
GC_AnimalFeeder._mt = Class(GC_AnimalFeeder, g_company.gc_class);
InitObjectClass(GC_AnimalFeeder, "GC_AnimalFeeder");

GC_AnimalFeeder.debugIndex = g_company.debug:registerScriptName("GC_AnimalFeeder");

GC_AnimalFeeder.ANIMSTATE = {}
GC_AnimalFeeder.ANIMSTATE.DEFAULT = 0
GC_AnimalFeeder.ANIMSTATE.RUNNING = 1
GC_AnimalFeeder.ANIMSTATE.LOADING = 2
GC_AnimalFeeder.ANIMSTATE.UNLOADING = 3

function GC_AnimalFeeder:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	local farmlandId = getUserAttribute(transformId, "farmlandId");

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;

		local object = GC_AnimalFeeder:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.animalFeeders.animalFeeder", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);

				g_company.debug:writeOnCreate(object.debugData, "[ANIMALFEEDER - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);

				local warningText = string.format("[ANIMALFEEDER - %s]  Attribute 'farmlandId' is invalid! ANIMALFEEDER will not operate correctly. 'farmlandId' should match area object is located at.", indexName);
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText);
			else
				g_company.debug:writeOnCreate(object.debugData, "[ANIMALFEEDER - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;

			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[ANIMALFEEDER - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[ANIMALFEEDER - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [GC_AnimalFeeder]");
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'ANIMALFEEDER' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId));
		else
			if xmlFilename == nil then
				g_company.debug:print("    ONCREATE: [ANIMALFEEDER - %s]  Attribute 'xmlFilename' is missing!", indexName);
			end;

			if farmlandId == nil then
				g_company.debug:print("    ONCREATE: [ANIMALFEEDER - %s]  Attribute 'farmlandId' is missing!", indexName);
			end;
		end;
	end;
end;

function GC_AnimalFeeder:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)    
    return GC_AnimalFeeder:superClass():new(GC_AnimalFeeder._mt, isServer, isClient, scriptDebugInfo, xmlFilename, baseDirectory, customEnvironment);
end;

function GC_AnimalFeeder:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
    GC_AnimalFeeder:superClass().load(self)    

	self.rootNode = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.debugData = g_company.debug:getDebugData(GC_AnimalFeeder.debugIndex, nil, self.customEnvironment)

	self.triggerManager = GC_TriggerManager:new(self);
    self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");
    
	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "AnimalFeeder_" .. indexName;
    end;
    
    self.guiData = {}
    local animalFeederImage = getXMLString(xmlFile, xmlKey .. ".guiInformation#imageFilename")
	if animalFeederImage ~= nil then
        self.guiData.animalFeederImage = self.baseDirectory .. animalFeederImage
    else
        for _,mod in pairs(g_modManager.nameToMod) do
            if mod.modDir == self.baseDirectory then
                self.guiData.animalFeederImage = mod.iconFilename
            end
        end
    end

    local animalFeederTitle = getXMLString(xmlFile, xmlKey .. "#title")
	if animalFeederTitle ~= nil then
		self.guiData.animalFeederTitle = g_company.languageManager:getText(animalFeederTitle)
	else
		self.guiData.animalFeederTitle = g_company.languageManager:getText("GC_animalFeeder_backupTitie")
    end
    
    self.bunkers = {}
    self.bunkerIdToBunker = {}

    local ratioCount = 0
    local i = 0;
    while true do
        local bunkerKey = string.format("%s.bunkers.bunker(%d)", xmlKey, i);
        if not hasXMLProperty(xmlFile, bunkerKey) then
            break
        end
    
        local bunker = {}
        bunker.id = i + 1

        bunker.fillLevel = 0
        bunker.capacity = Utils.getNoNil(getXMLInt(xmlFile, bunkerKey .. "#capacity"), 10000)
        bunker.title = g_company.languageManager:getText(getXMLString(xmlFile, bunkerKey .. "#title"))
        bunker.fillTypeTitle = g_company.languageManager:getText(getXMLString(xmlFile, bunkerKey .. "#fillTypeTitle"))
        
        bunker.fillTypes = {}
        local fillTypes = g_company.utils.splitString(getXMLString(xmlFile, bunkerKey .. "#fillType"), " ")
        for fillI,fillTypeName in pairs(fillTypes) do
            local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName)
            bunker.fillTypes[fillType.index] = fillType.index
            if fillI == 1 then
                bunker.mainFillType = fillType.index
                bunker.history = 0
                bunker.historyCurrent = 0
            end
        end

        bunker.mixingRatio = {}
        bunker.mixingRatio.min = Utils.getNoNil(getXMLInt(xmlFile, bunkerKey .. ".mixingRatio#min"), 0)
        bunker.mixingRatio.max = Utils.getNoNil(getXMLInt(xmlFile, bunkerKey .. ".mixingRatio#max"), 100)
        bunker.mixingRatio.value = bunker.mixingRatio.min
        ratioCount = ratioCount + bunker.mixingRatio.value

        local unloadingTriggerKey = string.format("%s.unloadingTrigger", bunkerKey)
        local unloadingTrigger = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.rootNode, self, xmlFile, unloadingTriggerKey, bunker.fillTypes)
        if unloadingTrigger ~= nil then
            unloadingTrigger.extraParamater = bunker.id
            bunker.unloadingTrigger = unloadingTrigger
        end


        local operationKey = bunkerKey .. ".operation"
        bunker.operation = {}
        bunker.operation.startTime = getXMLInt(xmlFile, operationKey .. "#startTime")
        bunker.operation.endTime = getXMLInt(xmlFile, operationKey .. "#endTime")

        if self.isClient then
            if hasXMLProperty(xmlFile, bunkerKey .. ".digitalDisplays") then
                local digitalDisplays = GC_DigitalDisplays:new(self.isServer, self.isClient)
                if digitalDisplays:load(self.rootNode, self, xmlFile, bunkerKey, nil, true) then
                    bunker.digitalDisplays = digitalDisplays
                    bunker.digitalDisplays:updateLevelDisplays(bunker.fillLevel, bunker.capacity)
                end            
            end

            if hasXMLProperty(xmlFile, bunkerKey .. ".fillVolumes") then   
                local fillVolumes = GC_FillVolume:new(self.isServer, self.isClient)
                if fillVolumes:load(self.rootNode, self, xmlFile, bunkerKey, bunker.capacity, true, g_fillTypeManager:getFillTypeNameByIndex(bunker.mainFillType)) then
                    bunker.fillVolumes = fillVolumes
                end
            end
            
            local particleEffects = GC_Effects:new(self.isServer, self.isClient)
            if particleEffects:load(self.rootNode, self, xmlFile, operationKey) then
                bunker.operation.particleEffects = particleEffects
            end
            
            local operateSounds = GC_Sounds:new(self.isServer, self.isClient)
            if operateSounds:load(self.rootNode, self, xmlFile, operationKey) then
                bunker.operation.sounds = operateSounds
            end
    
            local shaders = GC_Shaders:new(self.isServer, self.isClient)
            if shaders:load(self.rootNode, self, xmlFile, operationKey) then
                bunker.operation.shaders = shaders
            end

            local animationNodes = GC_AnimationNodes:new(self.isServer, self.isClient)
            if animationNodes:load(self.rootNode, self, xmlFile, operationKey) then
                bunker.operation.animationNodes = animationNodes
            end
        end

        self.bunkerIdToBunker[bunker.id] = bunker
        table.insert(self.bunkers, bunker);
        i = i + 1;
    end

    --set fullratio to 100%
    if ratioCount < 100 then
        local delta = 100 - ratioCount
        for _,bunker in pairs(self.bunkers) do
            local bunkerDelta = bunker.mixingRatio.max - bunker.mixingRatio.value
            bunkerDelta = math.min(delta, bunkerDelta)
            bunker.mixingRatio.value = bunker.mixingRatio.value + bunkerDelta
            delta = delta - bunkerDelta
            if delta == 0 then
                break
            end
        end
    end

    local roboterKey = xmlKey .. ".roboter"
    local operationKey = roboterKey .. ".operation"

    self.roboter = {}
    self.roboter.capacity = Utils.getNoNil(getXMLInt(xmlFile, roboterKey .. "#capacity"), 50000)
    self.roboter.animalModul = Utils.getNoNil(getXMLString(xmlFile, roboterKey .. "#animalModul"), "food")
    self.roboter.animalFillType = g_fillTypeManager:getFillTypeIndexByName(Utils.getNoNil(getXMLString(xmlFile, roboterKey .. "#animalFillType"), "GRASS_WINDROW"))
    
    self.roboter.fillLevel = 0
    self.roboter.fillTypeIndex = -1;
    self.roboter.currentFillLevelDelta = 0
    self.roboter.fillLevels = {}
    for _,bunker in pairs(self.bunkers) do
        self.roboter.fillLevels[bunker.id] = 0
    end

    self.roboter.unloading = {}
    self.roboter.unloading.startTime = getXMLInt(xmlFile, roboterKey .. ".unloading#startTime")
    self.roboter.unloading.endTime = getXMLInt(xmlFile, roboterKey .. ".unloading#endTime")

    self.roboter.fillTypeSwitch = {}
    self.roboter.fillTypeSwitch.time = getXMLInt(xmlFile, roboterKey .. ".fillTypeSwitch#time")
    

    self.roboter.operation = {}
    self.roboter.operation.startTime = getXMLInt(xmlFile, operationKey .. "#startTime")
    self.roboter.operation.endTime = getXMLInt(xmlFile, operationKey .. "#endTime")

    if self.isClient then   
        if hasXMLProperty(xmlFile, roboterKey .. ".digitalDisplays") then
            local digitalDisplays = GC_DigitalDisplays:new(self.isServer, self.isClient)
            if digitalDisplays:load(self.rootNode, self, xmlFile, roboterKey, nil, true) then
                self.roboter.digitalDisplays = digitalDisplays
                self.roboter.digitalDisplays:updateLevelDisplays(self.roboter.fillLevel, self.roboter.capacity)
            end
        end

        if hasXMLProperty(xmlFile, roboterKey .. ".fillVolumes") then   
            local fillVolumes = GC_FillVolume:new(self.isServer, self.isClient)
            if fillVolumes:load(self.rootNode, self, xmlFile, roboterKey, self.roboter.capacity, true, "WHEAT") then
                self.roboter.fillVolumes = fillVolumes
            end
        end
        
        local animationNodes = GC_AnimationNodes:new(self.isServer, self.isClient)
        if animationNodes:load(self.rootNode, self, xmlFile, operationKey) then
            self.roboter.operation.animationNodes = animationNodes
        end
        
        local unloadingKey = roboterKey .. ".unloading"
        local particleEffects = GC_Effects:new(self.isServer, self.isClient)
        if particleEffects:load(self.rootNode, self, xmlFile, unloadingKey) then
            self.roboter.unloading.particleEffects = particleEffects
        end
    end

    if self.isClient then
        self.playerTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.rootNode, self , xmlFile, string.format("%s.playerTrigger", xmlKey), nil, true, g_company.languageManager:getText("GC_animalFeeder_openGui"))
    end

    self.feedingTimes = {
        {time=0, active=false},
        {time=0, active=false},
        {time=0, active=false},
        {time=0, active=false}
    }
    self.feedingDemandPercent = 0
    self.feedingLiterPerDrive = 0

    local animationClips = GC_AnimationClips:new(self.isServer, self.isClient)
    if animationClips:load(self.rootNode, self, xmlFile, xmlKey, true) then
        self.animationClips = animationClips
    end

    --if self.isServer then
        g_currentMission.environment:addHourChangeListener(self)
    --end

    self.anim = {}
    self.anim.isRunning = false
    self.anim.needNewStarts = 0
    self.anim.numberRuns = 0
    self.anim.deltaToFeed = 0
    self.anim.state = GC_AnimalFeeder.ANIMSTATE.DEFAULT
    self.anim.raisedTimes = {}

    self.animalFeederDirtyFlag = self:getNextDirtyFlag();
        
    g_company.addRaisedUpdateable(self);

    self.globalIndex = g_company.addAnimalFeeder(self)

	return true;
end;

function GC_AnimalFeeder:finalizePlacement()
	GC_AnimalFeeder:superClass().finalizePlacement(self)	
    self.eventId_updateRoboter = self:registerEvent(self, self.updateRoboterEvent, false, false)
    self.eventId_resetRoboter = self:registerEvent(self, self.resetRoboterEvent, false, false)
    self.eventId_setFeedingTimes = self:registerEvent(self, self.setFeedingTimesEvent, false, false)
    self.eventId_setFeedingDemandPercent = self:registerEvent(self, self.setFeedingDemandPercentEvent, false, false)
    self.eventId_setFeedingLiterPerDrive = self:registerEvent(self, self.setFeedingLiterPerDriveEvent, false, false)
    self.eventId_setFeedingMixingRatio = self:registerEvent(self, self.setFeedingMixingRatioEvent, false, false)
    self.eventId_setRobotorUnloadingEffects = self:registerEvent(self, self.setRobotorUnloadingEffectsEvent, false, false)
    self.eventId_setRobotorOperationEffects = self:registerEvent(self, self.setRobotorOperationEffectsEvent, false, false)
end

function GC_AnimalFeeder:delete()
    g_company.removeAnimalFeeder(self, self.globalIndex)
    
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
    end;
    
	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers();
    end;

    for _, bunker in pairs(self.bunkers) do
        if bunker.fillVolumes ~= nil then
            bunker.fillVolumes:delete()
        end
        if bunker.operation.sounds ~= nil then
            bunker.operation.sounds:delete()
        end    
        if bunker.operation.shaders ~= nil then
            bunker.operation.shaders:delete()
        end    
        if bunker.operation.particleEffects ~= nil then
            bunker.operation.particleEffects:delete()
        end
        if bunker.operation.animationNodes ~= nil then
            bunker.operation.animationNodes:delete()
        end
    end

    if self.roboter.unloading.particleEffects ~= nil then
        self.roboter.unloading.particleEffects:delete()
    end
    if self.roboter.fillVolumes ~= nil then
        self.roboter.fillVolumes:delete()
    end

	if self.animationClips ~= nil then
        self.animationClips:delete()
	end
	

	GC_AnimalFeeder:superClass().delete(self);
end;

function GC_AnimalFeeder:readStream(streamId, connection)
	GC_AnimalFeeder:superClass().readStream(self, streamId, connection);  

	if connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:readStream(streamId, connection)
        end
        
        --if streamReadBool(streamId) then
		--	local customTitle = streamReadString(streamId)
		--	self:setCustomTitle(customTitle, true)
        --end
        
        for _,bunker in pairs(self.bunkers) do
            bunker.fillLevel = streamReadFloat32(streamId)
            bunker.history = streamReadFloat32(streamId)
            bunker.historyCurrent = streamReadFloat32(streamId)
            self:updateBunkerClient(bunker)
        end

        local fillLevel = streamReadFloat32(streamId)
        local fillTypeIndex = streamReadInt32(streamId)

        if self.roboter.fillVolumes ~= nil then
            if fillLevel > 0 then
                self.roboter.fillVolumes:setFillType(fillTypeIndex)
                self.roboter.fillVolumes:addFillLevel(fillLevel)
            end
        end
    
        if self.roboter.digitalDisplays ~= nil then
            self.roboter.digitalDisplays:updateLevelDisplays(fillLevel, self.roboter.capacity)
        end

        for _,feedingTime in pairs(self.feedingTimes) do
            feedingTime.time = streamReadFloat32(streamId)
            feedingTime.active = streamReadBool(streamId)
        end

        self.feedingDemandPercent = streamReadInt32(streamId)
        self.feedingLiterPerDrive = streamReadInt32(streamId)

        self.anim.isRunning = streamReadBool(streamId)
        self.anim.needNewStarts = streamReadInt32(streamId)
        self.anim.numberRuns = streamReadInt32(streamId)
        self.anim.state = streamReadInt32(streamId)
        local currentAnimTime = streamReadFloat32(streamId)
        self.anim.deltaToFeed = streamReadFloat32(streamId)

        if currentAnimTime > 0 then
            self.animationClips:setTimeByIndex(1, currentAnimTime)
        end
      
        for k,_ in pairs(self.anim.raisedTimes) do
            self.anim.raisedTimes[k] = streamReadBool(streamId)
        end

        local l = streamReadInt8(streamId)
        for i=1, l do
            local time = streamReadInt32(streamId)   
            local val = streamReadBool(streamId)   
            self.anim.raisedTimes[time] = val
        end

	end
end

function GC_AnimalFeeder:writeStream(streamId, connection)
	GC_AnimalFeeder:superClass().writeStream(self, streamId, connection);

	if not connection:getIsServer() then
		if self.triggerManager ~= nil then
			self.triggerManager:writeStream(streamId, connection)
		end        

		--local customTitle = self:getCustomTitle()
		--if streamWriteBool(streamId, customTitle ~= GC_AnimalFeeder.BACKUP_TITLE) then
		--	streamWriteString(streamId, customTitle)
        --end
        
        for _,bunker in pairs (self.bunkers) do     
            streamWriteFloat32(streamId, bunker.fillLevel)
            streamWriteFloat32(streamId, bunker.history)
            streamWriteFloat32(streamId, bunker.historyCurrent)
        end

        streamWriteFloat32(streamId, self.roboter.fillLevel)
        streamWriteInt32(streamId, self.roboter.fillTypeIndex)

        for _,feedingTime in pairs(self.feedingTimes) do
            streamWriteFloat32(streamId, feedingTime.time)
            streamWriteBool(streamId, feedingTime.active)
        end

        streamWriteInt32(streamId, self.feedingDemandPercent)    
        streamWriteInt32(streamId, self.feedingLiterPerDrive)          
        
        streamWriteBool(streamId, self.anim.isRunning)     
        streamWriteInt32(streamId, self.anim.needNewStarts)     
        streamWriteInt32(streamId, self.anim.numberRuns)     
        streamWriteInt32(streamId, self.anim.state)     
        streamWriteFloat32(streamId, self:getCurrentAnimTime())     
        streamWriteFloat32(streamId, self.anim.deltaToFeed)     
        
        streamWriteInt8(streamId, g_company.utils.getTableLength(self.anim.raisedTimes))  
        for time,val in pairs(self.anim.raisedTimes) do
            streamWriteInt32(streamId, time)   
            streamWriteBool(streamId, val)   
        end
        
	end
end

function GC_AnimalFeeder:readUpdateStream(streamId, timestamp, connection)
	GC_AnimalFeeder:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
        if streamReadBool(streamId) then
            for _,bunker in pairs(self.bunkers) do
                bunker.fillLevel = streamReadFloat32(streamId)
                bunker.history = streamReadFloat32(streamId)
                bunker.historyCurrent = streamReadFloat32(streamId)
                self:updateBunkerClient(bunker)
            end                        
        end
	end
end

function GC_AnimalFeeder:writeUpdateStream(streamId, connection, dirtyMask)
	GC_AnimalFeeder:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
		if streamWriteBool(streamId, bitAND(dirtyMask, self.animalFeederDirtyFlag) ~= 0) then
            for _,bunker in pairs (self.bunkers) do     
                streamWriteFloat32(streamId, bunker.fillLevel)
                streamWriteFloat32(streamId, bunker.history)
                streamWriteFloat32(streamId, bunker.historyCurrent)
            end               
        end
	end
end

function GC_AnimalFeeder:loadFromXMLFile(xmlFile, key)
	GC_AnimalFeeder:superClass().loadFromXMLFile(self, xmlFile, key)
    if not self.isPlaceable then
		key = string.format("%s.animalFeeder", key);
    end

    --local customTitle = getXMLString(xmlFile, key .. "#customTitle")
    --if customTitle ~= nil and customTitle ~= "" then
    --    self:setCustomTitle(customTitle, true)
    --end

    local currentAnimTime = getXMLFloat(xmlFile, key .. ".animation#currentTime")
    if currentAnimTime > 0 then
        self.animationClips:setTimeByIndex(1, currentAnimTime)
    end

    local index = 0;
	while true do
		local bunkerKey = string.format(key .. ".bunkers.bunker(%d)", index)
		if not hasXMLProperty(xmlFile, bunkerKey) then
			break
        end

        local id = getXMLInt(xmlFile, bunkerKey .. "#id");
        local fillLevel = getXMLInt(xmlFile, bunkerKey .. "#fillLevel");
        self:updateBunker(id, fillLevel)

        local bunker = self.bunkerIdToBunker[id]
        bunker.history = getXMLInt(xmlFile, bunkerKey .. "#history");
        bunker.historyCurrent = getXMLInt(xmlFile, bunkerKey .. "#historyCurrent");

        bunker.mixingRatio.value = getXMLInt(xmlFile, bunkerKey .. "#mixingRatioValue");
        self:updateRoboter(getXMLInt(xmlFile, bunkerKey .. "#roboterFillLevel"), bunker.mainFillType, id)
       
        if self.isClient and currentAnimTime > bunker.operation.startTime and currentAnimTime < bunker.operation.endTime then
            self:setOperationEffects(bunker.id, true)
        end      

        index = index + 1;
    end

    local robiLevel = getXMLInt(xmlFile, key .. ".roboter#fillLevel");
    if robiLevel > 0 then
        self:updateRoboter(robiLevel, self.roboter.animalFillType)
    end
    self.roboter.currentFillLevelDelta = getXMLFloat(xmlFile, key .. ".roboter#currentFillLevelDelta")
    
    if self.isClient then
        if currentAnimTime > self.roboter.unloading.startTime and currentAnimTime < self.roboter.unloading.endTime then
            self:setRobotorUnloadingEffects(true)
        end
        if currentAnimTime > self.roboter.operation.startTime and currentAnimTime < self.roboter.operation.endTime then
            self:setRobotorOperationEffects(true)
        end
    end      

    index = 0;
	while true do
		local feedingTimeKey = string.format(key .. ".feedingTimes.feedingTime(%d)", index)
		if not hasXMLProperty(xmlFile, feedingTimeKey) then
			break
        end
        local time = getXMLInt(xmlFile, feedingTimeKey .. "#time")
        local active = getXMLBool(xmlFile, feedingTimeKey .. "#active")
        self.feedingTimes[index + 1] = {time=time, active=active}
        index = index + 1;
    end

    self.feedingDemandPercent = getXMLInt(xmlFile, key .. ".feedingTimes#feedingDemandPercent")
    self.feedingLiterPerDrive = getXMLInt(xmlFile, key .. ".feedingTimes#feedingLiterPerDrive")

    self.anim.isRunning = getXMLBool(xmlFile, key .. ".animation#isRunning")
    self.anim.needNewStarts = getXMLInt(xmlFile, key .. ".animation#needNewStarts")
    self.anim.numberRuns = getXMLInt(xmlFile, key .. ".animation#numberRuns")
    self.anim.state = getXMLInt(xmlFile, key .. ".animation#state")
    self.anim.deltaToFeed = getXMLFloat(xmlFile, key .. ".animation#deltaToFeed")

    index = 0;
	while true do
		local timeKey = string.format(key .. ".animation.raiseTime(%d)", index)
		if not hasXMLProperty(xmlFile, timeKey) then
			break
        end

        local time = getXMLInt(xmlFile, timeKey .. "#time")
        local val = getXMLBool(xmlFile, timeKey .. "#val")
        self.anim.raisedTimes[time] = val

        index = index + 1;
    end

    self:raiseUpdate()
 
	return true
end

function GC_AnimalFeeder:saveToXMLFile(xmlFile, key, usedModNames)
	GC_AnimalFeeder:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
	if not self.isPlaceable then
		key = string.format("%s.animalFeeder", key);
		setXMLInt(xmlFile, key .. "#farmId", self:getOwnerFarmId());
    end

    --local customTitle = self:getCustomTitle()
	--if customTitle ~= GC_AnimalFeeder.BACKUP_TITLE then
	--	setXMLString(xmlFile, key .. "#customTitle", customTitle)
    --end
    
	local index = 0;
    for _,bunker in pairs(self.bunkers) do
		local bunkerKey = string.format(key .. ".bunkers.bunker(%d)", index)
        setXMLInt(xmlFile, bunkerKey .. "#id", bunker.id)
        setXMLInt(xmlFile, bunkerKey .. "#fillLevel", bunker.fillLevel)
        setXMLInt(xmlFile, bunkerKey .. "#history", bunker.history)
        setXMLInt(xmlFile, bunkerKey .. "#historyCurrent", bunker.historyCurrent)
        setXMLInt(xmlFile, bunkerKey .. "#mixingRatioValue", bunker.mixingRatio.value)
        setXMLInt(xmlFile, bunkerKey .. "#roboterFillLevel", self.roboter.fillLevels[bunker.id])
        index = index + 1;
    end   

    setXMLInt(xmlFile, key .. ".roboter#fillLevel", self.roboter.fillLevel)
    setXMLFloat(xmlFile, key .. ".roboter#currentFillLevelDelta", self.roboter.currentFillLevelDelta)

	index = 0;
	for _,feedingTime in pairs(self.feedingTimes) do
		local feedingTimeKey = string.format(key .. ".feedingTimes.feedingTime(%d)", index)
        setXMLInt(xmlFile, feedingTimeKey .. "#time", feedingTime.time)
        setXMLBool(xmlFile, feedingTimeKey .. "#active", feedingTime.active)
        index = index + 1;
    end

    setXMLInt(xmlFile, key .. ".feedingTimes#feedingDemandPercent", self.feedingDemandPercent)
    setXMLInt(xmlFile, key .. ".feedingTimes#feedingLiterPerDrive", self.feedingLiterPerDrive)

    setXMLBool(xmlFile, key .. ".animation#isRunning", self.anim.isRunning)
    setXMLInt(xmlFile, key .. ".animation#needNewStarts", self.anim.needNewStarts)
    setXMLInt(xmlFile, key .. ".animation#numberRuns", self.anim.numberRuns)
    setXMLInt(xmlFile, key .. ".animation#state", self.anim.state)
    setXMLFloat(xmlFile, key .. ".animation#currentTime", self:getCurrentAnimTime())
    setXMLFloat(xmlFile, key .. ".animation#deltaToFeed", self.anim.deltaToFeed)

	index = 0;
    for time,val in pairs(self.anim.raisedTimes) do
		local timeKey = string.format(key .. ".animation.raiseTime(%d)", index)
        setXMLInt(xmlFile, timeKey .. "#time", time)     
        setXMLBool(xmlFile, timeKey .. "#val", val)  
        index = index + 1; 
    end
end

function GC_AnimalFeeder:update(dt)     
	GC_AnimalFeeder:superClass().update(self, dt)
    --if self.isServer then      
        if self.anim.isRunning then
            local currentAnimTime = self:getCurrentAnimTime()
            if self.anim.state == GC_AnimalFeeder.ANIMSTATE.DEFAULT then
                self.animationClips:setAnimationClipsState(true)
                self.anim.state = GC_AnimalFeeder.ANIMSTATE.RUNNING
            elseif self.anim.state == GC_AnimalFeeder.ANIMSTATE.RUNNING then
                for _,bunker in pairs(self.bunkers) do                    
                    if self.anim.raisedTimes[bunker.operation.startTime] == nil and currentAnimTime >= bunker.operation.startTime then
                        self.anim.state = GC_AnimalFeeder.ANIMSTATE.LOADING
                        self.anim.loadingBunkerId = bunker.id
                        self.anim.raisedTimes[bunker.operation.startTime] = true
                        self:setOperationEffects(bunker.id, true)
                    end
                end
                if self.anim.state == GC_AnimalFeeder.ANIMSTATE.RUNNING then
                    if self.anim.raisedTimes[self.roboter.unloading.startTime] == nil and currentAnimTime >= self.roboter.unloading.startTime then
                        self.anim.state = GC_AnimalFeeder.ANIMSTATE.UNLOADING
                        self.anim.raisedTimes[self.roboter.unloading.startTime] = true
                        self:setRobotorUnloadingEffects(true)
           
                        local fillDeltaTime = self.roboter.unloading.endTime - self.roboter.unloading.startTime
                        self.roboter.currentFillLevelDelta = self.roboter.fillLevel / fillDeltaTime
                    end
                    if self.anim.raisedTimes[self.roboter.fillTypeSwitch.time] == nil and currentAnimTime >= self.roboter.fillTypeSwitch.time then
                        self.anim.raisedTimes[self.roboter.fillTypeSwitch.time] = true
                        self.roboter.fillLevel = self:getRoboterFillLevel()
                        if self.isServer then
                            self:updateRoboter(0, self.roboter.animalFillType, nil, true)
                        end
                    end
                end
            elseif self.anim.state == GC_AnimalFeeder.ANIMSTATE.LOADING then
                for _,bunker in pairs(self.bunkers) do
                    if self.anim.loadingBunkerId == bunker.id then
                        if self.anim.raisedTimes[bunker.operation.endTime] == nil then 
                            if self.isServer then                                                   
                                local fillDeltaFullTime = self.anim.deltaToFeed * (bunker.mixingRatio.value / 100) * self:getCurrentAnimSpeed()
                                local fillDeltaTime = bunker.operation.endTime - bunker.operation.startTime
                                --print(string.format("loading 1: fillDeltaTime: %s dt: %s", fillDeltaTime, dt))
                                local fillDelta = fillDeltaFullTime / fillDeltaTime * dt
                                fillDelta = math.min(fillDelta, bunker.capacity - bunker.fillLevel)
                                --print(string.format("loading 2: capacity: %s fillLevel: %s fillDelta: %s", bunker.capacity, bunker.fillLevel, fillDelta))
                                local oldFillDelta = self.roboter.fillLevels[bunker.id]                    
                                if self.roboter.fillLevels[bunker.id] + fillDelta > fillDeltaFullTime then
                                    fillDelta = fillDeltaFullTime - self.roboter.fillLevels[bunker.id]
                                end
                                --print(string.format("loading %s %s %s", self.anim.deltaToFeed, fillDelta, fillDeltaFullTime))
                                self:updateRoboter(fillDelta, bunker.mainFillType, bunker.id)
                                self:updateBunker(bunker.id, fillDelta * -1)
                            end
                        end
                        if self.anim.raisedTimes[bunker.operation.endTime] == nil and currentAnimTime >= bunker.operation.endTime then
                            self.anim.state = GC_AnimalFeeder.ANIMSTATE.RUNNING
                            self.anim.raisedTimes[bunker.operation.endTime] = true
                            self:setOperationEffects(bunker.id, false)
                        end
                        break
                    end
                end
            elseif self.anim.state == GC_AnimalFeeder.ANIMSTATE.UNLOADING then
                if self.anim.raisedTimes[self.roboter.unloading.endTime] == nil and currentAnimTime >= self.roboter.unloading.endTime then
                    self.anim.state = GC_AnimalFeeder.ANIMSTATE.RUNNING
                    self.anim.raisedTimes[self.roboter.unloading.endTime] = true                    
                    self:setRobotorUnloadingEffects(false)
                    if self.isServer and self.roboter.fillLevel > 0 then
                        local delta = self:getConnectedHusbandry():changeFillLevels(self.roboter.fillLevel, self.roboter.animalFillType)                
                        self:updateRoboter(delta * -1, self.roboter.animalFillType)
                    end
                end
                if currentAnimTime > self.roboter.unloading.startTime and currentAnimTime < self.roboter.unloading.endTime then  
                    if self.isServer then                                              
                        local delta = self:getConnectedHusbandry():changeFillLevels(math.min(self.roboter.currentFillLevelDelta * dt * self:getCurrentAnimSpeed(), self.roboter.fillLevel), self.roboter.animalFillType)                
                        --print(string.format("unloading %s %s", math.min(self.roboter.currentFillLevelDelta * dt * self:getCurrentAnimSpeed(), self.roboter.fillLevel), delta))
                        self:updateRoboter(delta * -1, self.roboter.animalFillType)
                    end
                end
            end

            if self.anim.raisedTimes[self.roboter.operation.startTime] == nil and currentAnimTime >= self.roboter.operation.startTime then
                self.anim.raisedTimes[self.roboter.operation.startTime] = true
                self:setRobotorOperationEffects(true)
            end
            if self.anim.raisedTimes[self.roboter.operation.endTime] == nil and currentAnimTime >= self.roboter.operation.endTime then
                self.anim.raisedTimes[self.roboter.operation.endTime] = true
                self:setRobotorOperationEffects(false)   
            end

            if currentAnimTime >= self:getCurrentMaxAnimTime() then
                self.anim.isRunning = false
                self.anim.raisedTimes = {}
                self.animationClips:setAnimationClipsState(false)
                self.anim.state = GC_AnimalFeeder.ANIMSTATE.DEFAULT
                self:resetRoboter()
            end
            self:raiseUpdate()
        elseif self.anim.numberRuns > 0 then      
            self.anim.isRunning = true  
            self.anim.numberRuns = self.anim.numberRuns - 1
            self:raiseUpdate()
        elseif self.anim.needNewStarts > 0 then
            local canRun, deltaToFeed, numberRuns = self:checkRun()
            if canRun then
                self.anim.needNewStarts = self.anim.needNewStarts - 1
                self.anim.isRunning = true    
                self.anim.deltaToFeed = deltaToFeed        
                self.anim.numberRuns = self.anim.numberRuns + numberRuns - 1
                self:raiseUpdate()
            end
        end
    --end
end

function GC_AnimalFeeder:playerTriggerCanAddActivatable()
    return true
end

function GC_AnimalFeeder:playerTriggerActivated()
    g_company.gui:openGuiWithData("gc_animalFeeder", false, self)
end

function GC_AnimalFeeder:getFreeCapacity(fillTypeIndex, farmId, triggerId)
    return self.bunkerIdToBunker[triggerId].capacity - self.bunkerIdToBunker[triggerId].fillLevel   
end

function GC_AnimalFeeder:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
    if fillLevelDelta > 0 then        
        self:updateBunker(triggerId, fillLevelDelta)   
    end
end

function GC_AnimalFeeder:removeFillLevel(farmId, fillLevelDelta, fillTypeIndex, triggerId)
    if fillLevelDelta > 0 then
        self:updateBunker(triggerId, fillLevelDelta)  
        return self.bunkerIdToBunker[triggerId].fillLevel
    end
	return 0
end

function GC_AnimalFeeder:updateBunker(bunkerId, fillLevelDelta)
    local bunker = self.bunkerIdToBunker[bunkerId]

    bunker.fillLevel = math.min(math.max(bunker.fillLevel + fillLevelDelta, 0), bunker.capacity)
    bunker.historyCurrent = bunker.historyCurrent + math.abs(fillLevelDelta)

    if self.isServer then
        self:raiseDirtyFlags(self.animalFeederDirtyFlag)
    end

    if self.isClient then
        self:updateBunkerClient(bunker)
    end
end

function GC_AnimalFeeder:updateBunkerClient(bunker)
    if bunker.fillVolumes ~= nil then
        bunker.fillVolumes:addFillLevel(bunker.fillLevel)
    end

    if bunker.digitalDisplays ~= nil then
        bunker.digitalDisplays:updateLevelDisplays(bunker.fillLevel, bunker.capacity)
    end
end

function GC_AnimalFeeder:updateRoboter(fillLevelDelta, fillTypeIndex, bunkerId, resetBunker)
    self:updateRoboterEvent({fillLevelDelta, fillTypeIndex, bunkerId, resetBunker, bunkerId ~= nil})
end

function GC_AnimalFeeder:updateRoboterEvent(data, noEventSend)
    self:raiseEvent(self.eventId_updateRoboter, data, noEventSend)

    local fillLevelDelta = data[1]
    local fillTypeIndex = data[2] 
    local bunkerId = data[3]
    local resetBunker = data[4]
    local useBunker = data[5]

    local fillLevel = 0
    if useBunker and bunkerId ~= nil then
        self.roboter.fillLevels[bunkerId] = self.roboter.fillLevels[bunkerId] + fillLevelDelta
        fillLevel = self:getRoboterFillLevel()
    else
        self.roboter.fillLevel = self.roboter.fillLevel + fillLevelDelta
        fillLevel = self.roboter.fillLevel
    end

    self.roboter.fillTypeIndex = fillTypeIndex

    if resetBunker then
        self.roboter.fillLevels = {}
        for _,bunker in pairs(self.bunkers) do
            self.roboter.fillLevels[bunker.id] = 0
        end
    end

    --if self.isServer then
    --    self:raiseDirtyFlags(self.animalFeederDirtyFlag)
    --end

    if self.isClient then
        if self.roboter.fillVolumes ~= nil then
            self.roboter.fillVolumes:setFillType(fillTypeIndex)
            self.roboter.fillVolumes:addFillLevel(fillLevel)
        end
    
        if self.roboter.digitalDisplays ~= nil then
            self.roboter.digitalDisplays:updateLevelDisplays(fillLevel, self.roboter.capacity)
        end
    end
end

function GC_AnimalFeeder:resetRoboter()    
    self:resetRoboterEvent({})
end

function GC_AnimalFeeder:resetRoboterEvent(data, noEventSend)
    self:raiseEvent(self.eventId_resetRoboter, data, noEventSend)

    self.roboter.fillLevels = {}
    for _,bunker in pairs(self.bunkers) do
        self.roboter.fillLevels[bunker.id] = 0
    end
    self.roboter.fillLevel = 0

    if self.isClient then
        if self.roboter.fillVolumes ~= nil then
            self.roboter.fillVolumes:addFillLevel(0)
        end

        if self.roboter.digitalDisplays ~= nil then
            self.roboter.digitalDisplays:updateLevelDisplays(0, self.roboter.capacity)
        end
    end
end

function GC_AnimalFeeder:onSetFarmlandStateChanged(farmId)
	self:setOwnerFarmId(farmId, false);
end;

function GC_AnimalFeeder:setOwnerFarmId(ownerFarmId, noEventSend)
	GC_AnimalFeeder:superClass().setOwnerFarmId(self, ownerFarmId, noEventSend);
	if self.triggerManager ~= nil then
		self.triggerManager:setAllOwnerFarmIds(ownerFarmId, noEventSend)
	end;
end;

function GC_AnimalFeeder:setCustomTitle(customTitle, noEventSend)
	--if customTitle ~= nil and customTitle ~= self:getCustomTitle() then
		----GC_ProductionDynamicStorageCustomTitleEvent.sendEvent(self, customTitle, noEventSend)

		--self.guiData.animalFeederTitle = customTitle
	--end
end

function GC_AnimalFeeder:getCustomTitle()
	return self.guiData.animalFeederTitle
end

function GC_AnimalFeeder:getFeedingTimes()
	return self.feedingTimes
end

function GC_AnimalFeeder:setFeedingTimes(id, time, active)
    self:setFeedingTimesEvent({id, time, active})
end

function GC_AnimalFeeder:setFeedingTimesEvent(data, noEventSend)
    self:raiseEvent(self.eventId_setFeedingTimes, data, noEventSend)

    self.feedingTimes[data[1]] = {time=data[2], active=data[3]}
end

function GC_AnimalFeeder:getFeedingDemandPercent()
	return self.feedingDemandPercent
end

function GC_AnimalFeeder:setFeedingDemandPercent(value)
    self:setFeedingDemandPercentEvent({value})
end

function GC_AnimalFeeder:setFeedingDemandPercentEvent(data, noEventSend)
    self:raiseEvent(self.eventId_setFeedingDemandPercent, data, noEventSend)

    self.feedingDemandPercent = data[1]
end

function GC_AnimalFeeder:getFeedingLiterPerDrive()
	return self.feedingLiterPerDrive
end

function GC_AnimalFeeder:setFeedingLiterPerDrive(value)
    self:setFeedingLiterPerDriveEvent({value})
end

function GC_AnimalFeeder:setFeedingLiterPerDriveEvent(data, noEventSend)
    self:raiseEvent(self.eventId_setFeedingLiterPerDrive, data, noEventSend)

    self.feedingLiterPerDrive = data[1]
end

function GC_AnimalFeeder:getFeedingBunker()
    return self.bunkers
end

function GC_AnimalFeeder:setFeedingMixingRatio(id, value)
    self:setFeedingMixingRatioEvent({id, value})
end

function GC_AnimalFeeder:setFeedingMixingRatioEvent(data, noEventSend)
    self:raiseEvent(self.eventId_setFeedingMixingRatio, data, noEventSend)

    self.bunkers[data[1]].mixingRatio.value = data[2]
end

function GC_AnimalFeeder:getRoboterCapacity()
    return self.roboter.capacity
end

function GC_AnimalFeeder:getRoboterDriveCapacity()
    return self.roboter.capacity * 2
end

function GC_AnimalFeeder:getRoboterFillLevel()
    local fullLevel = 0
    for _,level in pairs(self.roboter.fillLevels) do
        fullLevel = fullLevel + level
    end  
    return fullLevel 
end

function GC_AnimalFeeder:hourChanged()
    for _,feedTime in pairs(self.feedingTimes) do
        if feedTime.active and feedTime.time == g_currentMission.environment.currentHour then
            self.anim.needNewStarts = self.anim.needNewStarts + 1
            self:raiseUpdate()
        end
    end

    if g_currentMission.environment.currentHour == 0 then
        for _,bunker in pairs(self.bunkers) do
            bunker.history = bunker.historyCurrent
            bunker.historyCurrent = 0
        end
    end
end

function GC_AnimalFeeder:getCurrentAnimTime()
    local animEntry = self.animationClips.standardAnimationClips[1]
    return getAnimTrackTime(animEntry.animCharSet, 0)
end

function GC_AnimalFeeder:getCurrentMaxAnimTime()
    local animEntry = self.animationClips.standardAnimationClips[1]
    return animEntry.animDuration
end

function GC_AnimalFeeder:getCurrentAnimSpeed()
    local animEntry = self.animationClips.standardAnimationClips[1]
    return animEntry.animationSpeedScale
end

function GC_AnimalFeeder:setOperationEffects(bunkerId, state)
    if self.isClient then
        local bunker = self.bunkerIdToBunker[bunkerId]
        if bunker.operation.sounds ~= nil then
            bunker.operation.sounds:setSoundsState(state)
        end
        if bunker.operation.shaders ~= nil then
            bunker.operation.shaders:setShadersState(state)
        end
        if bunker.operation.particleEffects ~= nil then
            bunker.operation.particleEffects:setEffectsState(state)
        end
        if bunker.operation.animationNodes ~= nil then
            bunker.operation.animationNodes:setAnimationNodesState(state)
        end
    end
end

function GC_AnimalFeeder:setRobotorUnloadingEffects(state)
    self:setRobotorUnloadingEffectsEvent({state})
end

function GC_AnimalFeeder:setRobotorUnloadingEffectsEvent(data, noEventSend)
    --self:raiseEvent(self.eventId_setRobotorUnloadingEffects, data, noEventSend)
    
    if self.isClient then
        if self.roboter.unloading.particleEffects ~= nil then
            self.roboter.unloading.particleEffects:setEffectsState(data[1])
        end        
    end
end

function GC_AnimalFeeder:setRobotorOperationEffects(state)
    self:setRobotorOperationEffectsEvent({state})
end

function GC_AnimalFeeder:setRobotorOperationEffectsEvent(data, noEventSend)
    self:raiseEvent(self.eventId_setRobotorOperationEffects, data, noEventSend)

    if self.isClient then
        if  self.roboter.operation.animationNodes ~= nil then
            self.roboter.operation.animationNodes:setAnimationNodesState(data[1])
        end        
    end
end

function GC_AnimalFeeder:checkRun()
    local canRun = true
    local deltaToFeed = math.min(self.feedingLiterPerDrive + (self.feedingLiterPerDrive * self:getFeedingDemandPercent() / 100), self:getRoboterDriveCapacity())
    local numberRuns = 1
    
    if self:getConnectedHusbandry() == nil then
        self:addWarning(g_company.languageManager:getText("GC_animalFeeder_gui_warningText_noConnectedAnimalTrough"))
        return false, 0, 0
    end

    local freeCapacity = self:getConnectedHusbandry():getFreeCapacity(self.roboter.animalFillType)

    if freeCapacity < self.feedingLiterPerDrive then
        self:addWarning(g_company.languageManager:getText("GC_animalFeeder_gui_warningText_toHighDeltaForTroug"))
        deltaToFeed = freeCapacity
    end

    for _,bunker in pairs(self.bunkers) do
        local needDelta = deltaToFeed * bunker.mixingRatio.value * 0.01
        if needDelta > bunker.fillLevel then
            canRun = false
            self:addWarning(string.format(g_company.languageManager:getText("GC_animalFeeder_gui_warningText_bunkerEmpty"), bunker.title, bunker.fillTypeTitle))
        end
    end


    if deltaToFeed <= 0 then
        canRun = false
    end

    numberRuns = math.ceil(deltaToFeed / self.roboter.capacity)
    if numberRuns == 2 then
        deltaToFeed = deltaToFeed / 2
    end

    --print(string.format("checkRun %s %s %s", canRun, deltaToFeed, numberRuns))
    return canRun, deltaToFeed, numberRuns
end

function GC_AnimalFeeder:addWarning(text)
    if g_company.animalFeederWarningGui == nil then
        g_company.animalFeederWarningGui = g_company.gui:openGuiWithData("gc_animalFeederWarning", false).classGui
    end
    g_company.animalFeederWarningGui:addWarning(text, self.guiData.animalFeederTitle)
end

function GC_AnimalFeeder:getConnectedHusbandry()
    if self.connectedFoodTrough == nil then
        self.connectedFoodTrough, _ = g_company.utils.getNextAnimalHusbandry(self.rootNode, self.roboter.animalModul)
    end
    return self.connectedFoodTrough
end