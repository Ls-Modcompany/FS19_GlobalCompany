--
-- GlobalCompany - Objects - GC_FillTypeConstructor
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 21.04.2019
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (21.04.2019):
-- 		- initial fs19 (GtX)
--
--
-- Notes:
--	
--
-- ToDo:
--		- Save game data
--		- GUI popup
--		- player trigger
--		- Integrate with other placeables.
--		- Delay texts ;-)
--
--

GC_FillTypeConstructor = {};
local GC_FillTypeConstructor_mt = Class(GC_FillTypeConstructor, Object);
InitObjectClass(GC_FillTypeConstructor, "GC_FillTypeConstructor");

GC_FillTypeConstructor.debugIndex = g_company.debug:registerScriptName("GC_FillTypeConstructor");

getfenv(0)["GC_FillTypeConstructor"] = GC_FillTypeConstructor;

function GC_FillTypeConstructor:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	local farmlandId = getUserAttribute(transformId, "farmlandId");

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;

		local object = GC_FillTypeConstructor:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.fillTypeConstructors.fillTypeConstructor", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);

				g_company.debug:writeOnCreate(object.debugData, "[FILLTYPE_CONSTRUCTOR - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);

				local warningText = string.format("[FILLTYPE_CONSTRUCTOR - %s]  Attribute 'farmlandId' is invalid! FillTypeConstructor will not operate correctly. 'farmlandId' should match area object is located at.", indexName);
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText);
			else
				g_company.debug:writeOnCreate(object.debugData, "[FILLTYPE_CONSTRUCTOR - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;

			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[FILLTYPE_CONSTRUCTOR - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[FILLTYPE_CONSTRUCTOR - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [GC_FillTypeConstructor]");
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'FILLTYPE_CONSTRUCTOR' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId));
		else
			if xmlFilename == nil then
				g_company.debug:print("    ONCREATE: [FILLTYPE_CONSTRUCTOR - %s]  Attribute 'xmlFilename' is missing!", indexName);
			end;

			if farmlandId == nil then
				g_company.debug:print("    ONCREATE: [FILLTYPE_CONSTRUCTOR - %s]  Attribute 'farmlandId' is missing!", indexName);
			end;
		end;
	end;
end;

function GC_FillTypeConstructor:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or GC_FillTypeConstructor_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;	
	
	self.currentConstructionTime = 0;
	self.totalConstructionTime = 0;
	
	self.stages = {};
	self.numStages = 0;
	self.currentStage = 1;
	
	self.fillTypeIndexToStageIndex = {};
	
	self.randomDelay = {
		startTime = 0,
		duration = -1,
		time = 0,
		isActive = false,
		textId = 1
	};
	
	self.randomTexts = {
		"Work is delayed due to rain!",
		"A John Deere 7R has caught on fire on a local street! Your employees have left work to watch.",
		"A fly landed in the someones lunch. Your employees have gone home in protest.",
		"Your employees decided they would prefer to leave early and head to the beach for the rest of today."
	};

	self.debugData = g_company.debug:getDebugData(GC_FillTypeConstructor.debugIndex, nil, customEnvironment);

	return self;
end;

function GC_FillTypeConstructor:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	self.rootNode = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.triggerManager = GC_TriggerManager:new(self);
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "Constructor_" .. indexName;
	end;
	
	local capacities = {};
	local usedFillTypeNames = {};
	local chanceOfDelay = math.min(math.max(Utils.getNoNil(getXMLInt(xmlFile, xmlKey .. "#chanceOfDelay"), 50), 0), 100);
	
	self.workerStartTime = Utils.getNoNil(getXMLFloat(xmlFile, xmlKey .. ".workers#startTime"), 8);
	self.workerEndTime = Utils.getNoNil(getXMLFloat(xmlFile, xmlKey .. ".workers#endTime"), 16);	
	self.stopForWeather = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. ".workers#stopForWeather"), false);
	
	local i = 0;
	while true do
		local stageKey = string.format("%s.constructionStages.constructionStage(%d)", xmlKey, i);
		if not hasXMLProperty(xmlFile, stageKey) then
			break;
		end;
		
		local stage = {};
		stage.progress = 0;
		stage.started = false;
		stage.complete = false;
		
		local title = Utils.getNoNil(getXMLString(xmlFile, stageKey .. "#name"), "Stage " .. #self.stages + 1);
		stage.title = title;
		stage.currentBuildTime = 0;		
		stage.buildTime = Utils.getNoNil(getXMLInt(xmlFile, stageKey .. "#buildTime"), 8);
		
		stage.fillTypes = {};
		stage.sortedFillTypes = {};

		local j = 0;
		while true do
			local fillTypesKey = string.format("%s.inputs.fillType(%d)", stageKey, j);
			if not hasXMLProperty(xmlFile, fillTypesKey) then
				break;
			end;

			local fillTypeName = getXMLString(xmlFile, fillTypesKey .. "#name");
			if fillTypeName ~= nil then
				local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
				if fillTypeIndex ~= nil and usedFillTypeNames[fillTypeName] == nil then
					usedFillTypeNames[fillTypeName] = stage.title;				
					
					local capacity = Utils.getNoNil(getXMLInt(xmlFile, fillTypesKey .. "#needed"), 10000);
					local neededPerHour = capacity / stage.buildTime;
					stage.fillTypes[fillTypeIndex] = {fillLevel = 0, capacity = capacity, neededPerHour = neededPerHour, used = 0};
					capacities[fillTypeIndex] = capacity;
					
					table.insert(stage.sortedFillTypes, fillTypeIndex);
					
					self.fillTypeIndexToStageIndex[fillTypeIndex] = #self.stages + 1;
				else
					if fillType == nil then
						g_company.debug:writeModding(self.debugData, "[CONSTRUCTOR - %s] Unknown fillType ( %s ) found in 'constructionStage' ( %s ) at %s, ignoring!", indexName, fillTypeName, fillTypesKey);
					else
						g_company.debug:writeModding(self.debugData, "[CONSTRUCTOR - %s] Duplicate 'constructionStage' fillType ( %s ) in '%s', FillType already used at '%s'!", indexName, fillTypeName, stage.title, usedFillTypeNames[fillTypeName]);
					end;
				end;
			end;

			j = j + 1;
		end;

		if stage.fillTypes ~= nil then
			table.sort(stage.sortedFillTypes);
			
			if self.isClient then	
				local completedPartsKey = stageKey .. ".completedParts"				
				local visibilityNodes = GC_VisibilityNodes:new(self.isServer, self.isClient);
				if visibilityNodes:load(nodeId, self, xmlFile, completedPartsKey, self.baseDirectory, stage.buildTime, true) then
					stage.visibilityNodes = visibilityNodes;
				else
					visibilityNodes:delete();
				end;
				
				local movers = GC_Movers:new(self.isServer, self.isClient);
				if movers:load(nodeId, self, xmlFile, completedPartsKey, self.baseDirectory, stage.buildTime, true) then
					stage.movers = movers;
				end;
			end;

			self.totalConstructionTime = self.totalConstructionTime + stage.buildTime;
			
			table.insert(self.stages, stage);
		end;

		i = i + 1;
	end;

	self.numStages = #self.stages;
	if self.numStages > 0 then
		if self.isServer and self.totalConstructionTime > 2 and chanceOfDelay > 0 then
			if math.random(1, 100) <= chanceOfDelay then
				self.randomDelay.startTime = math.random(1, self.totalConstructionTime - 1);
				self.randomDelay.textId = math.random(2, #self.randomTexts);
				self.randomDelay.duration = 0;
			end;			
		end;

		if self.isClient then
			local partId = 0;		
			while true do
				local decoKey = string.format("%s.decorationParts.part(%d)", xmlKey, partId);
				if not hasXMLProperty(xmlFile, decoKey) then
					break;
				end;

				local parentNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, decoKey .. "#groupNode"), self.i3dMappings);
				if parentNode ~= nil then
					local numInGroup = getNumOfChildren(parentNode);
					if numInGroup > 0 then
						local filename = getXMLString(xmlFile, decoKey .. "#filename");
						local sharedI3dNode = Utils.getNoNil(getXMLString(xmlFile, decoKey .. "#sharedI3dNode"), "0");
						if filename ~= nil and sharedI3dNode ~= nil then
							for id = 0, numInGroup - 1 do
								local node = getChildAt(parentNode, id);
								local i3dNode = g_i3DManager:loadSharedI3DFile(filename, self.baseDirectory, false, false, false);
								if i3dNode ~= 0 then
									local sharedRootNode = I3DUtil.indexToObject(i3dNode, sharedI3dNode);
									if sharedRootNode ~= nil then
										local part = {};
										part.node = sharedRootNode;
										part.filename = filename;
										link(node, sharedRootNode);
										addToPhysics(sharedRootNode);
										
										if self.buildParts == nil then
											self.buildParts = {};
										end;
			
										-- We allow multiple so that you can have different parts. e.g fences, rubbish piles, pipes etc.
										table.insert(self.buildParts, part);
									else
										g_company.debug:writeWarning(self.debugData, "sharedI3dNode '%s' could not be found in i3d file '%s' at ( %s )", sharedI3dNode, filename, decoKey);
									end;
	
									delete(i3dNode);
								else
									g_company.debug:writeWarning(self.debugData, "Could not load file '%s' at ( %s )", filename, decoKey);
								end;
							end;
						end;
					end;
				end;
				
				partId = partId + 1;
			end;
	
			local inputsPartsKey = xmlKey .. ".inputsParts"				
			local visibilityNodes = GC_VisibilityNodes:new(self.isServer, self.isClient);
			if visibilityNodes:load(nodeId, self, xmlFile, inputsPartsKey, self.baseDirectory, capacities) then
				self.visibilityNodes = visibilityNodes;
			else
				visibilityNodes:delete();
			end;
			
			local movers = GC_Movers:new(self.isServer, self.isClient);
			if movers:load(nodeId, self, xmlFile, inputsPartsKey, self.baseDirectory, capacities) then
				self.movers = movers;
			end;
		end;
		
		local triggerId = 0;
		while true do
			local unloadingTriggerKey = string.format("%s.unloadingTriggers.unloadingTrigger(%d)", xmlKey, triggerId);
			if not hasXMLProperty(xmlFile, unloadingTriggerKey) then
				break;
			end;
			
			local unloadingTrigger = self.triggerManager:loadTrigger(GC_UnloadingTrigger, nodeId, xmlFile, unloadingTriggerKey);
			if unloadingTrigger == nil then
				-- ERROR
			end;			
			
			triggerId = triggerId + 1;
		end;		
	end;
	
	if self.triggerManager ~= nil and self.triggerManager:getNumberTriggers() > 0 then
		if self.isServer then
			self.isRaining = self.stopForWeather and g_currentMission.environment.weather:getIsRaining();
			g_currentMission.environment:addHourChangeListener(self);
		end;

		self.constructorDirtyFlag = self:getNextDirtyFlag();
		
		return true;
	else
		-- ERROR
	end;
	
	return false;
end;
	
function GC_FillTypeConstructor:delete()
	if not self.isPlaceable then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;

	if self.isServer then
		g_currentMission.environment:removeHourChangeListener(self);
	end;

	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;

	if self.isClient then
		for _, stage in ipairs (self.stages) do			
			if stage.visibilityNodes ~= nil then
				stage.visibilityNodes:delete();
			end;
		end;

		if self.visibilityNodes ~= nil then
			self.visibilityNodes:delete();
		end;
	end;
		
	self:deleteDecorationParts();

	GC_FillTypeConstructor:superClass().delete(self);
end;
	
function GC_FillTypeConstructor:deleteDecorationParts(activeDelete)
	if self.isClient and self.buildParts ~= nil then
		for _, part in pairs(self.buildParts) do
			if activeDelete and part.node ~= nil then
				delete(part.node);
				part.node = nil;
			end;

			if part.filename ~= nil then
				g_i3DManager:releaseSharedI3DFile(part.filename, self.baseDirectory, true);
			end;
		end;
		
		self.buildParts = nil;
	end;
end;

function GC_FillTypeConstructor:readStream(streamId, connection)
    GC_FillTypeConstructor:superClass().readStream(self, streamId, connection)
    
	for id, stage in ipairs (self.stages) do
		for _, fillTypeIndex in ipairs(stage.sortedFillTypes) do
			local fillLevel = 0;
			if streamReadBool(streamId) then
				fillLevel = streamReadFloat32(streamId);
			end;
			
			self:setInputLevel(stage, fillTypeIndex, fillLevel);
		end;
		
		local progress = 0;
		if streamReadBool(streamId) then
			progress = streamReadFloat32(streamId);
		end;
		self:setProgress(id, progress);
	end;
	
	self.randomDelay.isActive = streamReadBool(streamId);
	self.randomDelay.textId = streamReadUInt8(streamId);
end;

function GC_FillTypeConstructor:writeStream(streamId, connection)
    GC_FillTypeConstructor:superClass().writeStream(self, streamId, connection)
	
	for _, stage in ipairs (self.stages) do
		for _, fillTypeIndex in ipairs(stage.sortedFillTypes) do
			local fillLevel = stage.fillTypes[fillTypeIndex].fillLevel;
			if streamWriteBool(streamId, fillLevel > 0) then
				streamWriteFloat32(streamId, fillLevel)
			end;
		end;

		local progress = stage.progress;
		if streamWriteBool(streamId, progress > 0) then
			streamWriteFloat32(streamId, progress);
		end;
	end;

	streamWriteBool(streamId, self.randomDelay.isActive);
	streamWriteUInt8(streamId, self.randomDelay.textId);	
end;

function GC_FillTypeConstructor:writeUpdateStream(streamId, connection, dirtyMask)
    GC_FillTypeConstructor:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.constructorDirtyFlag) ~= 0) then
            for _, stage in ipairs (self.stages) do
				for _, fillTypeIndex in ipairs(stage.sortedFillTypes) do
					local fillLevel = stage.fillTypes[fillTypeIndex].fillLevel;
					if streamWriteBool(streamId, fillLevel > 0) then
						streamWriteFloat32(streamId, fillLevel)
					end;
				end;
		
				local progress = stage.progress;
				if streamWriteBool(streamId, progress > 0) then
					streamWriteFloat32(streamId, progress);
				end;
			end;
        end;
    end;
end;

function GC_FillTypeConstructor:readUpdateStream(streamId, timestamp, connection)
    GC_FillTypeConstructor:superClass().readUpdateStream(self, streamId, timestamp, connection)
    if connection:getIsServer() then
        if streamReadBool(streamId) then
            for id, stage in ipairs (self.stages) do
				for _, fillTypeIndex in ipairs(stage.sortedFillTypes) do
					local fillLevel = 0;
					if streamReadBool(streamId) then
						fillLevel = streamReadFloat32(streamId);
					end;
					
					self:setInputLevel(stage, fillTypeIndex, fillLevel);
				end;
				
				local progress = 0;
				if streamReadBool(streamId) then
					progress = streamReadFloat32(streamId);
				end;
				self:setProgress(id, progress);
			end;
        end;
    end;
end;

function GC_FillTypeConstructor:update(dt)
	if self.randomDelay.isActive then
		g_currentMission:addExtraPrintText(self.randomTexts[self.randomDelay.textId]);
		g_currentMission:addExtraPrintText(tostring(self.randomDelay.time));
		g_currentMission:addExtraPrintText(tostring(self.randomDelay.duration));
		self:raiseActive();
	else
		if self:getIsRaining() then
			g_currentMission:addExtraPrintText(self.randomTexts[1]);		
			self:raiseActive();
		end;
	end;	
end;

function GC_FillTypeConstructor:hourChanged()
    if self.isServer then		
		local currentStage = 0;
		for id, stage in ipairs (self.stages) do
			if stage.progress < stage.buildTime then
				currentStage = id;
				self.currentStage = id;
				break
			end;
		end;
	
		if currentStage ~= 0 and self.currentConstructionTime < self.totalConstructionTime then	
			local canWork = self:getIsWorkHours();
			if canWork then
				local stage = self.stages[self.currentStage];
				if self:getCanWork(stage) then
					if not self:getIsRaining() then
						if self.randomDelay.duration >= 0 then	
							if self.randomDelay.isActive then
								canWork = false;
								self.randomDelay.time = self.randomDelay.time + 1;
								
								if self.randomDelay.time >= self.randomDelay.duration then
									self.randomDelay.isActive = false;
									self.randomDelay.duration = -1;
								end;							
							else
								if self.currentConstructionTime >= self.randomDelay.startTime then
									self.randomDelay.duration = self.workerEndTime - g_currentMission.environment.currentHour
									self.randomDelay.isActive = true;
									canWork = false;
									self:raiseActive();
								end;
							end;
						end;					
			
						if canWork then
							for fillTypeIndex, data in pairs (stage.fillTypes) do
								local fillLevel = math.max(data.fillLevel - data.neededPerHour, 0);							
								data.used = math.min(data.used + data.neededPerHour, data.capacity);
								self:setInputLevel(stage, fillTypeIndex, fillLevel, false);
							end;
							
							local progress = math.min(stage.progress + 1, stage.buildTime);
							self.currentConstructionTime = self.currentConstructionTime + 1;
							self:setProgress(currentStage, progress);
	
							self:raiseDirtyFlags(self.constructorDirtyFlag);
						end;
					else
						self:raiseActive();
					end;
				end;
			end;
		else
			g_currentMission.environment:removeHourChangeListener(self);			
			
			for id, stage in ipairs (self.stages) do
				for fillTypeIndex, data in pairs (stage.fillTypes) do
					self:setInputLevel(stage, fillTypeIndex, 0, false);
				end;
				
				self:setProgress(id, stage.buildTime);
			end;
			
			self:raiseDirtyFlags(self.constructorDirtyFlag);
		end;
    end;
end;
	
function GC_FillTypeConstructor:getCanWork(stage)
	for _, data in pairs (stage.fillTypes) do
		local fillLevel = data.fillLevel;
		if fillLevel < data.neededPerHour then
			return false;
		end;
	end;
	
	return true;
end;

function GC_FillTypeConstructor:getIsWorkHours()
	local currentHour = g_currentMission.environment.currentHour;
	return currentHour > self.workerStartTime and currentHour <= self.workerEndTime;
end;

function GC_FillTypeConstructor:getIsRaining()
	if self.stopForWeather then
		return g_currentMission.environment.weather:getIsRaining();
	end;	
	
	return false;
end;

function GC_FillTypeConstructor:setProgress(stageId, progress)
	local stage = self.stages[stageId];
	if stage ~= nil then
		stage.progress = progress;
		
		if self.isClient then	
			if stage.visibilityNodes ~= nil then
				stage.visibilityNodes:updateNodes(progress);
			end;
			
			if self.movers ~= nil then
				self.movers:updateMovers(progress);
			end;
		end;
		
		if stageId == self.numStages and stage.progress >= stage.buildTime then
			self:deleteDecorationParts(true);
		end;
	end;
end;

function GC_FillTypeConstructor:setInputLevel(stage, fillTypeIndex, fillLevel, raiseFlags)
	stage.fillTypes[fillTypeIndex].fillLevel = fillLevel;
	
	if self.isClient then
		if self.visibilityNodes ~= nil then
			self.visibilityNodes:updateNodes(fillLevel, fillTypeIndex);
		end;
		
		if self.movers ~= nil then
			self.movers:updateMovers(fillLevel, fillTypeIndex);
		end;
	end;
	
	if self.isServer and raiseFlags == true then
		self:raiseDirtyFlags(self.constructorDirtyFlag);
	end;
end;

function GC_FillTypeConstructor:getFreeCapacity(fillTypeIndex, farmId, spare)
	local fillLevel, capacity = 0, 0;

	-- Block fillTypes we are not ready for.
	if self.fillTypeIndexToStageIndex[fillTypeIndex] == self.currentStage then	
		local stage = self.stages[self.currentStage];
		local fillType = stage.fillTypes[fillTypeIndex];
		if fillType ~= nil then
			fillLevel = fillType.fillLevel;
			capacity = fillType.capacity - fillType.used;
		end;
	end;

	return capacity - fillLevel;
end;

function GC_FillTypeConstructor:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, spare)
	local stageId = self.fillTypeIndexToStageIndex[fillTypeIndex];
	local stage = self.stages[stageId];
	if stage ~= nil and stage.fillTypes[fillTypeIndex] ~= nil then
		local fillType = stage.fillTypes[fillTypeIndex];
		self:setInputLevel(stage, fillTypeIndex, fillType.fillLevel + fillLevelDelta, true);
	end;
end;



