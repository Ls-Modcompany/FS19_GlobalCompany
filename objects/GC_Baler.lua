--
-- GlobalCompany - Objects - GC_Baler
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

Baler = {};
Baler_mt = Class(Baler, Object);
InitObjectClass(Baler, "Baler");

Baler.debugIndex = g_company.debug:registerScriptName("Baler");

Baler.PLAYERTRIGGER_MAIN = 0;
Baler.PLAYERTRIGGER_CLEAN = 1;

Baler.BALETRIGGER_MAIN = 0;
Baler.BALETRIGGER_MOVER = 1;

Baler.STATE_OFF = 0;
Baler.STATE_ON = 1;

Baler.ANIMATION_CANSTACK = 0;
Baler.ANIMATION_ISSTACKING = 1;
Baler.ANIMATION_CANSTACKEND = 2;
Baler.ANIMATION_ISSTACKINGEND = 3;

getfenv(0)["GC_Baler"] = Baler;

function Baler:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName");
	local xmlFilename = getUserAttribute(transformId, "xmlFile");
	if indexName ~= nil and xmlFilename ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName;
		local baseDirectory = g_currentMission.loadingMapBaseDirectory;
		local object = Baler:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment);
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.balers.baler", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object);
				g_currentMission:addOnCreateLoadedObjectToSave(object);
				g_company.debug:writeOnCreate(object.debugData, "[Baler - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex);
				object:register(true);
			else
				g_company.debug:writeOnCreate(object.debugData, "[Baler - %s]  Failed to load from '%s'!", indexName, xmlFilename);
				object:delete();
			end;
			delete(xmlFile);
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[Baler - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename);
			else
				g_company.debug:writeModding(object.debugData, "[Baler - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename);
			end;
		end;
	end;
end;

function Baler:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	local self = Object:new(isServer, isClient, customMt or Baler_mt);

	self.xmlFilename = xmlFilename;
	self.baseDirectory = baseDirectory;
	self.customEnvironment = customEnvironment;

	self.debugData = g_company.debug:getDebugData(Baler.debugIndex, nil, customEnvironment);

	self.state_baler = Baler.STATE_OFF;
	self.state_stacker = Baler.STATE_OFF;
	self.state_balerMove = Baler.STATE_OFF;

	self.shouldTurnOff = false;

	self.synch_fillLevel = false;
	self.synch_fillLevelBunker = false;

	return self;
end;

function Baler:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	self.nodeId  = nodeId;
	self.indexName = indexName;
	self.isPlaceable = isPlaceable;

	self.triggerManager = GC_TriggerManager:new(self);
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings");

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId");
	if self.saveId == nil then
		self.saveId = "baler_" .. indexName;
	end;

	--if self.isServer then
		self.dirtyObject = GC_DirtyObjects:new(self.isServer, self.isClient, nil, self.baseDirectory, self.customEnvironment);
		self.dirtyObject:load(self.nodeId);
	--end;

	self.title = Utils.getNoNil(getXMLString(xmlFile, xmlKey .. "#title"), true);
	self.autoOn = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. "#autoOn"), true);

	
	local animationManager = GC_AnimationManager:new(self.isServer, self.isClient);
	if animationManager:load(self.nodeId, self, xmlFile, xmlKey, true) then
		animationManager:register(true);
		self.animationManager = animationManager;
	else
		animationManager:delete();
	end;

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------MainPart--------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	local mainPartKey = xmlKey .. ".mainPart";
	
    local fillTypesKey = string.format("%s.fillTypes", mainPartKey);
	if not hasXMLProperty(xmlFile, fillTypesKey) then
		--debug
		return false;
    end;
    
	self.fillLevel = 0;    
	self.fillLevelBunker = 0;
    self.capacity = Utils.getNoNil(getXMLInt(xmlFile, mainPartKey .. "#capacity"), 50000);
	self.pressPerSecond = Utils.getNoNil(getXMLInt(xmlFile, mainPartKey .. "#pressPerSecond"), 400);
	self.baleCounter = 0;
    
    local capacities = {};
	self.fillTypes = {};
	self.fillTypeToBaleType = {};
	local i = 0;
	while true do
		local fillTypeKey = string.format("%s.fillType(%d)", fillTypesKey, i);
		if not hasXMLProperty(xmlFile, fillTypeKey) then
			break;
        end;

        local fillTypeName = getXMLString(xmlFile, fillTypeKey .. "#name");
        local baleTypeName = getXMLString(xmlFile, fillTypeKey .. "#baleTypeName");
		if fillTypeName ~= nil then
			local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName);
			if fillType ~= nil then
                self.fillTypes[fillType.index] = fillType;
				capacities[fillType.index] = self.capacity;
				self.fillTypeToBaleType[fillType.index] = g_baleTypeManager.nameToBaleType[baleTypeName];
                if self.activeFillTypeIndex == nil then
                    self:setFillTyp(fillType.index, true, true);
                end;
			else
				if fillType == nil then
					g_company.debug:writeModding(self.debugData, "[BALER - %s] Unknown fillType ( %s ) found", indexName, fillTypeName);
				end;
			end;
		end;
		i = i + 1;
	end;
	
	--self.baleAnimation = GC_Animations:new(self.isServer, self.isClient)
	--self.baleAnimation:load(self.nodeId, self, true, nil, xmlFile, string.format("%s.baleAnimation", mainPartKey));


	if self.isClient then
		self.unloadTrigger = self.triggerManager:loadTrigger(GC_UnloadingTrigger, self.nodeId , xmlFile, string.format("%s.unloadTrigger", mainPartKey), {[1] = self.fillTypes[self.activeFillTypeIndex].index}, {[1] = "DISCHARGEABLE"});
		self.cleanHeap = self.triggerManager:loadTrigger(GC_DynamicHeap, self.nodeId , xmlFile, string.format("%s.cleanHeap", mainPartKey), self.fillTypes[self.activeFillTypeIndex].name, nil, false);
		
		self.playerTrigger = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId , xmlFile, string.format("%s.playerTrigger", mainPartKey), Baler.PLAYERTRIGGER_MAIN, true, g_company.languageManager:getText("GC_baler_openGui"), true);
		self.playerTriggerClean = self.triggerManager:loadTrigger(GC_PlayerTrigger, self.nodeId , xmlFile, string.format("%s.playerTriggerClean", mainPartKey), Baler.PLAYERTRIGGER_CLEAN, true, g_company.languageManager:getText("GC_baler_cleaner"), true);
		
		self.movers = GC_Movers:new(self.isServer, self.isClient);
		self.movers:load(self.nodeId , self, xmlFile, mainPartKey, self.baseDirectory, capacities);
		
		self.conveyorFillType = GC_Conveyor:new(self.isServer, self.isClient);
		self.conveyorFillType:load(self.nodeId, self, xmlFile, string.format("%s.conveyor", mainPartKey));
		self.conveyorFillTypeEffect = GC_ConveyorEffekt:new(self.isServer, self.isClient);
		self.conveyorFillTypeEffect:load(self.nodeId, self, xmlFile, string.format("%s.conveyor.effect", mainPartKey));

		
		self.baleAnimationObjectNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.baleAnimation.objects#node", mainPartKey)), self.i3dMappings);
		self.baleAnimationObjects = {};
		
		i = 0;
		while true do
			local objectKey = string.format("%s.baleAnimation.objects.object(%d)", mainPartKey, i);
			if not hasXMLProperty(xmlFile, objectKey) then
				break;
			end;

			local node = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, objectKey .. "#node"), self.i3dMappings);
			local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(getXMLString(xmlFile, objectKey .. "#fillTypeName"));
			
			setVisibility(node, false);
			table.insert(self.baleAnimationObjects, {node=node, fillTypeIndex=fillTypeIndex});
			
			i = i + 1;
		end;
		
		self.soundMain = g_company.sounds:new(self.isServer, self.isClient);
		self.soundMain:load(self.nodeId, self, xmlFile, string.format("%s", mainPartKey), self.basedirectory);
	end;

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------Stacker--------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	local stackPartKey = xmlKey .. ".stack";
	self.hasStack = hasXMLProperty(xmlFile, stackPartKey);
	if self.hasStack then
		self.animationState = Baler.ANIMATION_CANSTACK;
		self.stackBalesTarget = 3;
		self.stackBales = {};
		
		self.forkNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, stackPartKey .. "#forkNode"), self.i3dMappings);		
		
		self.stackerBaleTrigger = self.triggerManager:loadTrigger(GC_BaleTrigger, self.nodeId , xmlFile, string.format("%s.baleTrigger", stackPartKey), Baler.BALETRIGGER_MAIN, GC_BaleTrigger.MODE_COUNTER);
				
		self.conveyorStacker = GC_Conveyor:new(self.isServer, self.isClient);
		self.conveyorStacker:load(self.nodeId, self, xmlFile, string.format("%s.conveyor", stackPartKey));

		self.raisedAnimationKeys = {};
		--self.doStackAnimationEnd = GC_Animations:new(self.isServer, self.isClient)
		--self.doStackAnimationEnd:load(self.nodeId, self, true, string.format("%s.doStackAnimationEnd", stackPartKey), xmlFile);
		--self.doStackAnimationStart = GC_Animations:new(self.isServer, self.isClient)
		--self.doStackAnimationStart:load(self.nodeId, self, true, string.format("%s.doStackAnimationStart", stackPartKey), xmlFile);
		
		if self.isClient then
			self.soundStacker = g_company.sounds:new(self.isServer, self.isClient);
			self.soundStacker:load(self.nodeId, self, xmlFile, string.format("%s", stackPartKey), self.basedirectory);
		end;
	end;

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------BaleMover-------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	local baleMoverKey = xmlKey .. ".baleMover";
	self.movedMeters = 0;

	self.baleMoveCollision = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.moveCollision#node", baleMoverKey)), self.i3dMappings);
	setPairCollision(self.nodeId, self.baleMoveCollision, false);

	self.conveyorMover = GC_Conveyor:new(self.isServer, self.isClient);
	self.conveyorMover:load(self.nodeId, self, xmlFile, string.format("%s.conveyor", baleMoverKey));

	--self.moveCollisionAnimation = GC_Animations:new(self.isServer, self.isClient)
	--self.moveCollisionAnimation:load(self.nodeId, self, true, string.format("%s.moveCollisionAnimation", baleMoverKey), xmlFile);

	self.moveCollisionAnimationNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.moveCollisionAnimation#node", baleMoverKey)), self.i3dMappings);
	self.moveCollisionAnimationColliMask = getCollisionMask(self.moveCollisionAnimationNode);
	setCollisionMask(self.moveCollisionAnimationNode, 0);
		
	self.moverBaleTrigger = self.triggerManager:loadTrigger(GC_BaleTrigger, self.nodeId , xmlFile, string.format("%s.baleTriggerMover", baleMoverKey), Baler.BALETRIGGER_MOVER, GC_BaleTrigger.MODE_COUNTER);
	
	if self.isClient then
		self.soundMover = g_company.sounds:new(self.isServer, self.isClient);
		self.soundMover:load(self.nodeId, self, xmlFile, string.format("%s", baleMoverKey), self.basedirectory);
	end;

	self.balerDirtyFlag = self:getNextDirtyFlag();
	return true;
end;

function Baler:finalizePlacement()
	self.eventId_setFillLevelBunker = g_company.eventManager:registerEvent(self, self.setFillLevelBunkerEvent);
	self.eventId_setFillLevel = g_company.eventManager:registerEvent(self, self.setFillLevelEvent);
	self.eventId_setFillTyp = g_company.eventManager:registerEvent(self, self.setFillTypEvent);
	self.eventId_onTurnOnBaler = g_company.eventManager:registerEvent(self, self.onTurnOnBalerEvent);
	self.eventId_onTurnOffBaler = g_company.eventManager:registerEvent(self, self.onTurnOffBalerEvent);
	self.eventId_onTurnOnStacker = g_company.eventManager:registerEvent(self, self.onTurnOnStackerEvent);
	self.eventId_onTurnOffStacker = g_company.eventManager:registerEvent(self, self.onTurnOffStackerEvent);
	self.eventId_onTurnOnBaleMover = g_company.eventManager:registerEvent(self, self.onTurnOnBaleMoverEvent);
	self.eventId_onTurnOffBaleMover = g_company.eventManager:registerEvent(self, self.onTurnOffBaleMoverEvent);
	self.eventId_baleTarget = g_company.eventManager:registerEvent(self, self.setStackBalesTargetEvent);
	self.eventId_setAutoOn = g_company.eventManager:registerEvent(self, self.setAutoOnEvent);
	self.eventId_setBaleObjectToAnimation = g_company.eventManager:registerEvent(self, self.setBaleObjectToAnimationEvent);
	self.eventId_setBaleObjectToFork = g_company.eventManager:registerEvent(self, self.setBaleObjectToForkEvent);
	self.eventId_removeBaleObjectFromForkEvent = g_company.eventManager:registerEvent(self, self.removeBaleObjectFromForkEvent);
end

function Baler:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self)

	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;
	if self.conveyorFillType ~= nil then
		self.conveyorFillType:delete();
	end;
	if self.conveyorFillTypeEffect ~= nil then
		self.conveyorFillTypeEffect:delete();
	end;
	if self.animationManager ~= nil then
		self.animationManager:delete();
	end;
	if self.soundMain ~= nil then
		self.soundMain:delete();
	end;
	if self.soundStacker ~= nil then
		self.soundStacker:delete();
	end;
	if self.soundMover ~= nil then
		self.soundMover:delete();
	end;
	if self.conveyorStacker ~= nil then
		self.conveyorStacker:delete();
	end;
	if self.conveyorMover ~= nil then
		self.conveyorMover:delete();
	end;
	if self.dirtyObject ~= nil then
		self.dirtyObject:delete();
	end;
	
	Baler:superClass().delete(self)
end;

function Baler:readStream(streamId, connection)
	Baler:superClass().readStream(self, streamId, connection);

    if connection:getIsServer() then		
		self.state_baler = streamReadInt16(streamId);
		self.shouldTurnOff = streamReadBool(streamId);
		self:setFillTyp(streamReadInt16(streamId), true);
		self:setFillLevel(streamReadFloat32(streamId), true);
		self:setFillLevelBunker(streamReadFloat32(streamId), true, true);
		self.baleCounter = streamReadInt16(streamId);
		self.autoOn = streamReadBool(streamId);
		self.animationManager:setAnimationTime("baleAnimation", streamReadFloat32(streamId));
		if self.animationManager:getAnimationTime("baleAnimation") > 0 then	
			self:setBaleObjectToAnimation(true);	
			self.animationManager:setAnimationByState("baleAnimation", true);
		end;
		
		if self.hasStack then
			self.state_stacker = streamReadInt16(streamId);
			self.stackBalesTarget = streamReadInt16(streamId);
			self.animationState = streamReadInt16(streamId);

			local forkNodeNums = streamReadInt16(streamId);
			for _,info in pairs (self.baleAnimationObjects) do
				if info.fillTypeIndex == self.activeFillTypeIndex then
					for i=1, forkNodeNums do
						local newBale = clone(info.node, false, false, false);
						setVisibility(newBale, true);
						setTranslation(newBale, 0.015, 0.958 + (i-1)*0.8,-0.063);
						link(self.forkNode, newBale);		
					end;
					break;
				end;
			end;

			self.animationManager:setAnimationTime("doStackAnimationEnd", streamReadFloat32(streamId));
			local time = self.animationManager:getAnimationTime("doStackAnimationEnd");
			if time > 0  and time < 1 then		
				self.animationManager:setAnimationByState("doStackAnimationEnd", true);
			end;
			
			self.animationManager:setAnimationTime("doStackAnimationStart", streamReadFloat32(streamId));
			local time = self.animationManager:getAnimationTime("doStackAnimationStart");
			if time > 0  and time < 1 then		
				self.animationManager:setAnimationByState("doStackAnimationStart", true);
			end;
		end;

		self.state_balerMove = streamReadInt16(streamId);
		
		self.dirtyObject:readStream(streamId, connection);		
	end;
end;

function Baler:writeStream(streamId, connection)
	Baler:superClass().writeStream(self, streamId, connection);

    if not connection:getIsServer() then	
		streamWriteInt16(streamId, self.state_baler);
		streamWriteBool(streamId, self.shouldTurnOff);
		streamWriteInt16(streamId, self.activeFillTypeIndex);
		streamWriteFloat32(streamId, self.fillLevel);
		streamWriteFloat32(streamId, self.fillLevelBunker);
		streamWriteInt16(streamId, self.baleCounter);
		streamWriteBool(streamId, self.autoOn);
		streamWriteFloat32(streamId, self.animationManager:getAnimationTime("baleAnimation"));
		
		if self.hasStack then
			streamWriteInt16(streamId, self.state_stacker);
			streamWriteInt16(streamId, self.stackBalesTarget);
			streamWriteInt16(streamId, self.animationState);
			streamWriteInt16(streamId, getNumOfChildren(self.forkNode));
			streamWriteFloat32(streamId, self.animationManager:getAnimationTime("doStackAnimationStart"));
			streamWriteFloat32(streamId, self.animationManager:getAnimationTime("doStackAnimationEnd"));
		end;

		streamWriteInt16(streamId, self.state_balerMove);
		
		self.dirtyObject:writeStream(streamId, connection);
	end;
end;

function Baler:readUpdateStream(streamId, timestamp, connection)
	Baler:superClass().readUpdateStream(self, streamId, timestamp, connection);

	if connection:getIsServer() then
		if streamReadBool(streamId) then
			
			
		
        
		end;
	end;
end;

function Baler:writeUpdateStream(streamId, connection, dirtyMask)
	Baler:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);

	if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.BalerDirtyFlag) ~= 0) then
        
		end;
	end;
end;

function Baler:loadFromXMLFile(xmlFile, key)	
	self.state_baler = getXMLInt(xmlFile, key..".baler#state");
	self.shouldTurnOff = getXMLBool(xmlFile, key..".baler#shouldTurnOff");
	self:setFillTyp(getXMLInt(xmlFile, key..".baler#fillType"), true);
	self:setFillLevel(getXMLFloat(xmlFile, key..".baler#fillLevel"), true);
	self:setFillLevelBunker(getXMLFloat(xmlFile, key..".baler#fillLevelBunker"), true, true);
	self.baleCounter = getXMLFloat(xmlFile, key..".baler#counter");
	self.autoOn = getXMLBool(xmlFile, key..".baler#autoOn");
	
	self.animationManager:setAnimationTime("baleAnimation", getXMLFloat(xmlFile, key..".baler#animationTime"));
	if self.animationManager:getAnimationTime("baleAnimation") > 0 then	
		self:setBaleObjectToAnimation(true);	
		self.animationManager:setAnimationByState("baleAnimation", true);
	end;

	self.state_stacker = getXMLInt(xmlFile, key..".stacker#state");
	self.stackBalesTarget = getXMLInt(xmlFile, key..".stacker#stackBalesTarget");
	self.animationState = getXMLInt(xmlFile, key..".stacker#animationState");

	local forkNodeNums = getXMLInt(xmlFile, key..".stacker#forkNodeNums");
	for _,info in pairs (self.baleAnimationObjects) do
		if info.fillTypeIndex == self.activeFillTypeIndex then
			for i=1, forkNodeNums do
				local newBale = clone(info.node, false, false, false);
				setVisibility(newBale, true);
				setTranslation(newBale, 0.015, 0.958 + (i-1)*0.8,-0.063);
				link(self.forkNode, newBale);		
			end;
			break;
		end;
	end;
	
	self.animationManager:setAnimationTime("doStackAnimationEnd", getXMLFloat(xmlFile, key..".stacker#doStackAnimationEndTime"));
	local time = self.animationManager:getAnimationTime("doStackAnimationEnd");
	if time > 0  and time < 1 then		
		self.animationManager:setAnimationByState("doStackAnimationEnd", true);
	end;
	
	self.animationManager:setAnimationTime("doStackAnimationStart", getXMLFloat(xmlFile, key..".stacker#doStackAnimationStartTime"));
	local time = self.animationManager:getAnimationTime("doStackAnimationStart");
	if time > 0  and time < 1 then		
		self.animationManager:setAnimationByState("doStackAnimationStart", true);
	end;

	self.state_balerMove = getXMLInt(xmlFile, key..".mover#state");
	
	self.dirtyObject:loadFromXMLFile(xmlFile, key..".dirtNodes");

	return true;
end;

function Baler:saveToXMLFile(xmlFile, key, usedModNames)
	setXMLInt(xmlFile, key .. ".baler#state", self.state_baler);
	setXMLBool(xmlFile, key .. ".baler#shouldTurnOff", self.shouldTurnOff);
	setXMLFloat(xmlFile, key .. ".baler#fillLevel", self.fillLevel);
	setXMLFloat(xmlFile, key .. ".baler#fillLevelBunker", self.fillLevelBunker);
	setXMLInt(xmlFile, key .. ".baler#fillType", self.activeFillTypeIndex);
	setXMLFloat(xmlFile, key .. ".baler#counter", self.baleCounter);
	setXMLBool(xmlFile, key .. ".baler#autoOn", self.autoOn);
	setXMLFloat(xmlFile, key .. ".baler#animationTime", self.animationManager:getAnimationTime("baleAnimation"));

	setXMLInt(xmlFile, key .. ".stacker#state", self.state_stacker);
	setXMLInt(xmlFile, key .. ".stacker#stackBalesTarget", self.stackBalesTarget);
	setXMLInt(xmlFile, key .. ".stacker#animationState", self.animationState);
	setXMLInt(xmlFile, key .. ".stacker#forkNodeNums", getNumOfChildren(self.forkNode));	
	setXMLFloat(xmlFile, key .. ".stacker#doStackAnimationStartTime", self.animationManager:getAnimationTime("doStackAnimationStart"));
	setXMLFloat(xmlFile, key .. ".stacker#doStackAnimationEndTime", self.animationManager:getAnimationTime("doStackAnimationEnd"));

	setXMLInt(xmlFile, key .. ".mover#state", self.state_balerMove);

	self.dirtyObject:saveToXMLFile(xmlFile, key..".dirtNodes", usedModNames);
end;

function Baler:update(dt)
	if self.isServer then

		if self.state_baler == Baler.STATE_ON then
			if self.fillLevelBunker >= 4000 then
				if self:canUnloadBale() then					
					self:setBaleObjectToAnimation();
					self.baleAnimation:setAnimationsState(true);
					self.baleCounter = self.baleCounter + 1;
					self:setFillLevelBunker(self.fillLevelBunker * -1, true);
					if self.shouldTurnOff then
						self:onTurnOffBaler();
						self.shouldTurnOff = false;
					end;
				end;
			elseif self.fillLevel + self.fillLevelBunker >= 4000 then
				self:setFillLevelBunker(math.min(dt / 1000 * self.pressPerSecond, 4000 - self.fillLevelBunker, self.fillLevel));
			elseif self.baleAnimation:getAnimationTime() == 0 then
				self:onTurnOffBaler();
			end;
		end;
		if self.baleAnimation:getAnimationTime() == 1 then
			if self.moveCollisionAnimation:getAnimationTime() == 1 then
				self.moveCollisionAnimation:setAnimTime(0);	
				setCollisionMask(self.moveCollisionAnimationNode, 0);
			end;
			self:createBale(self.baleAnimationObjectNode);
			self.baleAnimation:setAnimTime(0);
			delete(getChildAt(self.baleAnimationObjectNode, 0));
		end;
		
		if self.hasStack and self.state_stacker == Baler.STATE_ON then
			if self.animationState == Baler.ANIMATION_CANSTACK then
				if self.stackerBaleTrigger:getTriggerNotEmpty() and self.fillLevelBunker > 0 then		
					if self.stackerBaleTrigger:getNum() < self.stackBalesTarget and self.state_balerMove == Baler.STATE_OFF then
						self.animationState = Baler.ANIMATION_ISSTACKING;
						self.doStackAnimationStart:setAnimationsState(true);
					else
						if self.state_balerMove == Baler.STATE_OFF and self.moverBaleTrigger:getTriggerEmpty() then
							self:onTurnOnBaleMover();
							self.stackBales = {};
							setCollisionMask(self.moveCollisionAnimationNode, self.moveCollisionAnimationColliMask);
							self.moveCollisionAnimation:setAnimationsState(true);
						end;
						if self.moveCollisionAnimation:getAnimationTime() == 1 then
							self.moveCollisionAnimation:setAnimTime(0);	
							setCollisionMask(self.moveCollisionAnimationNode, 0);
						end;
					end;
				end;
				if self.state_balerMove == Baler.STATE_ON then
					if self.movedMeters >= 2.6 then
						self.movedMeters = 0;
						self.stackerBaleTrigger:reset();
						self:onTurnOffBaleMover();
						if self.state_baler == Baler.STATE_OFF then
							self:onTurnOffStacker();
						end;
					else
						self.movedMeters = self.movedMeters + (dt / 1000 * 0.8);
					end;
				end;
			elseif self.animationState == Baler.ANIMATION_ISSTACKING then
				if self.doStackAnimationStart:getAnimationTime() == 1 then
					self.animationState = Baler.ANIMATION_CANSTACKEND;
					self.raisedAnimationKeys = {};
					self.stackerBaleTrigger:reset();
				elseif self.doStackAnimationStart:getAnimationTime() >= 0.6 and self.raisedAnimationKeys["0.6"] == nil then
					self:setBaleObjectToFork();
					for _,bale in pairs(self.stackBales) do
						bale:delete();
					end;
					self.stackBales = {};
					self.raisedAnimationKeys["0.6"] = true;
				end;
			elseif self.animationState == Baler.ANIMATION_CANSTACKEND then
				if self.stackerBaleTrigger:getTriggerNotEmpty() then
					self.animationState = Baler.ANIMATION_ISSTACKINGEND;
					self.doStackAnimationEnd:setAnimationsState(true);
				end
			elseif self.animationState == Baler.ANIMATION_ISSTACKINGEND then
				if self.doStackAnimationEnd:getAnimationTime() == 1 then
					self.animationState = Baler.ANIMATION_CANSTACK;
					self.raisedAnimationKeys = {};				
					self.doStackAnimationEnd:setAnimTime(0);	
					self.doStackAnimationStart:setAnimTime(0);	
				elseif self.doStackAnimationEnd:getAnimationTime() >= 0.3 and self.raisedAnimationKeys["0.3"] == nil then
					self:removeBaleObjectFromFork();
					self.raisedAnimationKeys["0.3"] = true;
				end;
			end;
		end;
	end;

	if self.isClient then
		self.soundMain:setSoundsState(self.state_baler == Baler.STATE_ON); 
		self.soundStacker:setSoundsState(self.animationState == Baler.ANIMATION_ISSTACKING or self.animationState == Baler.ANIMATION_ISSTACKINGEND); 
		self.soundMover:setSoundsState(self.state_balerMove == Baler.STATE_ON); 
	end;
	self:raiseActive();
end;

function Baler:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
	self:setFillLevel(self.fillLevel + fillLevelDelta);
	
	if self.autoOn and self.fillLevel > 4000 and self.state_baler == Baler.STATE_OFF then
		self:onTurnOnBaler();
		self:onTurnOnStacker();
	end;
end;

function Baler:getFreeCapacity(dt)
	return self.capacity - self.fillLevel;
end;

function Baler:playerTriggerCanAddActivatable(ref)
    if ref == Baler.PLAYERTRIGGER_CLEAN then
        if self.fillLevel >= 4000 or self.fillLevel == 0 then
            return false;
        end;
    end;
    return true;
end;

function Baler:playerTriggerActivated(ref)
    if ref == Baler.PLAYERTRIGGER_MAIN then
		g_company.gui:openGuiWithData("gcPlaceable_baler", false, self);
    elseif ref == Baler.PLAYERTRIGGER_CLEAN then
        if self.cleanHeap:getIsHeapEmpty() then
            if self.fillLevel < 4000 then
                self.cleanHeap.fillTypeIndex = self.activeFillTypeIndex;                    
                self.cleanHeap:updateDynamicHeap(self.fillLevel, false);
                self:setFillLevel(0);
            end;
        else
            -- heap is not empty
        end;
    end;
end;


function Baler:setFillLevelBunker(delta, onlyBunker, noEventSend)  
	self:setFillLevelBunkerEvent({delta, onlyBunker}, noEventSend);
end;

-- 1: delta
-- 2: onlyBunker
function Baler:setFillLevelBunkerEvent(data, noEventSend)    
	g_company.eventManager:createEvent(self.eventId_setFillLevelBunker, data, false, noEventSend);
	if data[1] ~= nil then
		self.fillLevelBunker = self.fillLevelBunker + data[1];
		if data[2] == nil or not data[2] then
			self:setFillLevel(self.fillLevel + (data[1] * -1), true);
		end;
		g_company.gui:updateGuiData("gcPlaceable_baler");
	end;
end;

function Baler:setFillLevel(level, noEventSend)   
	self:setFillLevelEvent({level}, noEventSend);  
end;

-- 1: level
function Baler:setFillLevelEvent(data, noEventSend)     
	g_company.eventManager:createEvent(self.eventId_setFillLevel, data, false, noEventSend);
	self.fillLevel = data[1];
	if self.isClient then
		self.movers:updateMovers(data[1], self.activeFillTypeIndex);    
		g_company.gui:updateGuiData("gcPlaceable_baler");
	end;	
end;

function Baler:setFillTyp(fillTypeIndex, onFirstRun, noEventSend)   
	self:setFillTypEvent({fillTypeIndex, onFirstRun}, noEventSend);   	
end;

-- 1: fillTypeIndex
-- 2: onFirstRun
function Baler:setFillTypEvent(data, noEventSend)    
	g_company.eventManager:createEvent(self.eventId_setFillTyp, data, false, noEventSend);
	if data[2] == nil or not data[2] then
		self.unloadTrigger.fillTypes = nil;
		self.unloadTrigger:setAcceptedFillTypeState(data[1], true);
		
		if self.stackerBaleTrigger:getNum() > 0 and self.state_balerMove == Baler.STATE_OFF and self.moverBaleTrigger:getTriggerEmpty() then
			self:onTurnOnBaleMover();
			self.stackBales = {};
			setCollisionMask(self.moveCollisionAnimationNode, self.moveCollisionAnimationColliMask);
			self.moveCollisionAnimation:setAnimationsState(true);
		end;
	end;
	self.activeFillTypeIndex = data[1]; 
end;

function Baler:setBaleObjectToAnimation(noEventSend)
	self:setBaleObjectToAnimationEvent({}, noEventSend);   
end;

-- data is empty table
function Baler:setBaleObjectToAnimationEvent(data, noEventSend)
	g_company.eventManager:createEvent(self.eventId_setBaleObjectToAnimation, data, false, noEventSend);
	--if self.isClient then
		for _,info in pairs (self.baleAnimationObjects) do
			if info.fillTypeIndex == self.activeFillTypeIndex then
				local newBale = clone(info.node, false, false, false);
				setVisibility(newBale, true);
				link(self.baleAnimationObjectNode, newBale);		
				break;
			end;
		end;
	--end;
end;

function Baler:removeBaleObjectFromFork(noEventSend)
	self:setBaleObjectToForkEvent({}, noEventSend);   
end;

-- data is empty table
function Baler:removeBaleObjectFromForkEvent(data, noEventSend)
	g_company.eventManager:createEvent(self.eventId_removeBaleObjectFromForkEvent, data, false, noEventSend);
	for i=1, getNumOfChildren(self.forkNode) do
		local child = getChildAt(self.forkNode, 0);
		self:createBale(child);
		delete(child);
	end;
end;

function Baler:setBaleObjectToFork(noEventSend)
	self:setBaleObjectToForkEvent({}, noEventSend);   
end;

-- data is empty table
function Baler:setBaleObjectToForkEvent(data, noEventSend)
	g_company.eventManager:createEvent(self.eventId_setBaleObjectToFork, data, false, noEventSend);
	for _,info in pairs (self.baleAnimationObjects) do
		if info.fillTypeIndex == self.activeFillTypeIndex then
			for i=1, self.stackerBaleTrigger:getNum() do
				local newBale = clone(info.node, false, false, false);
				setVisibility(newBale, true);
				setTranslation(newBale, 0.015, 0.958 + (i-1)*0.8,-0.063);
				link(self.forkNode, newBale);		
			end;
			break;
		end;
	end;
end;

function Baler:canUnloadBale()
	local canUnloadBale = self.baleAnimation:getAnimationTime() == 0;
	if canUnloadBale and self.hasStack then
		canUnloadBale = self.stackerBaleTrigger:getTriggerEmpty() and self.animationState ~= Baler.ANIMATION_ISSTACKING and self.animationState ~= Baler.ANIMATION_ISSTACKINGEND;
	end;
	if canUnloadBale and self.state_balerMove == Baler.STATE_ON then
		canUnloadBale = false;
	end;
	return canUnloadBale;
end;

function Baler:createBale(ref)
	local t = self.fillTypeToBaleType[self.activeFillTypeIndex];
	local baleType = g_baleTypeManager:getBale(self.activeFillTypeIndex, false, t.width, t.height, t.length, t.diameter);	
	local filename = Utils.getFilename(baleType.filename, self.baseDirectory);
	local baleObject = Bale:new(self.isServer, self.isClient);
	local x,y,z = getWorldTranslation(ref);
	local rx,ry,rz = getWorldRotation(ref);
	baleObject:load(filename, x,y,z,rx,ry,rz, 4000);
	baleObject:setOwnerFarmId(self:getOwnerFarmId(), true);
	baleObject:register();
	baleObject:setCanBeSold(false);
	table.insert(self.stackBales, baleObject);
end;

function Baler:onTurnOnBaler(noEventSend)		
	self:onTurnOnBalerEvent({}, noEventSend);   
end

-- data is empty table
function Baler:onTurnOnBalerEvent(data, noEventSend)			
	g_company.eventManager:createEvent(self.eventId_onTurnOnBaler, data, false, noEventSend);
	self.state_baler = Baler.STATE_ON;

	if self.isServer then
		self:raiseActive();
	end;

	if self.isClient then
		self.conveyorFillTypeEffect:setFillType(self.activeFillTypeIndex);
		self.conveyorFillTypeEffect:start();
		self.conveyorFillType:start();
	end;
end

function Baler:onTurnOffBaler(noEventSend)	
	self:onTurnOffBalerEvent({}, noEventSend);   
end

-- data is empty table
function Baler:onTurnOffBalerEvent(data, noEventSend)	
	g_company.eventManager:createEvent(self.eventId_onTurnOffBaler, data, false, noEventSend);
	self.state_baler = Baler.STATE_OFF;

	if self.isClient then
		self.conveyorFillTypeEffect:stop();
		self.conveyorFillType:stop();
	end;
end

function Baler:onTurnOnStacker(noEventSend)
	self:onTurnOnStackerEvent({}, noEventSend);  	
end

-- data is empty table
function Baler:onTurnOnStackerEvent(data, noEventSend)	
	g_company.eventManager:createEvent(self.eventId_onTurnOnStacker, data, false, noEventSend);
	self.state_stacker = Baler.STATE_ON;
	
	if self.isServer then
		self:raiseActive();
	end;
end

function Baler:onTurnOffStacker(noEventSend)	
	self:onTurnOffStackerEvent({}, noEventSend);  	
end

-- data is empty table
function Baler:onTurnOffStackerEvent(data, noEventSend)	
	g_company.eventManager:createEvent(self.eventId_onTurnOffStacker, data, false, noEventSend);
	self.state_stacker = Baler.STATE_OFF;
end

function Baler:onTurnOnBaleMover(noEventSend)	
	self:onTurnOnBaleMoverEvent({}, noEventSend);  	
end

-- data is empty table
function Baler:onTurnOnBaleMoverEvent(data, noEventSend)	
	g_company.eventManager:createEvent(self.eventId_onTurnOnBaleMover, data, false, noEventSend);
	self.state_balerMove = Baler.STATE_ON;
	
	if self.isServer then
		self:raiseActive();
		setFrictionVelocity(self.baleMoveCollision, 0.8);
		self.conveyorStacker:start();
		self.conveyorMover:start();
	end;
end

function Baler:onTurnOffBaleMover(noEventSend)	
	self:onTurnOffBaleMoverEvent({}, noEventSend);  	
end

-- data is empty table
function Baler:onTurnOffBaleMoverEvent(data, noEventSend)	
	g_company.eventManager:createEvent(self.eventId_onTurnOffBaleMover, data, false, noEventSend);
	self.state_balerMove = Baler.STATE_OFF;

	if self.isServer then
		setFrictionVelocity(self.baleMoveCollision, 0.0);
		self.conveyorStacker:stop();
		self.conveyorMover:stop();
	end;
end

function Baler:setStackBalesTarget(num, noEventSend)
	self:setStackBalesTargetEvent({num}, noEventSend);
end;

-- 1: num
function Baler:setStackBalesTargetEvent(data, noEventSend)
	g_company.eventManager:createEvent(self.eventId_baleTarget, data, false, noEventSend);
	print(string.format("setStackBalesTargetEvent %s", data[1]));
	self.stackBalesTarget = data[1];
end;

function Baler:setAutoOn(state, noEventSend)
	self:setAutoOnEvent({state}, noEventSend);
end;

-- 1: state
function Baler:setAutoOnEvent(data, noEventSend)
	g_company.eventManager:createEvent(self.eventId_setAutoOn, data, false, noEventSend);
	self.autoOn = data[1];
	if self.isServer and self.autoOn and self.fillLevel > 4000 and self.state_baler == Baler.STATE_OFF then --add self.isServer
		self:onTurnOnBaler();
		self:onTurnOnStacker();
	end;
end;

function Baler:getCanChangeFillType()
	return self.state_baler == Baler.STATE_OFF and self.fillLevel == 0 and self.fillLevelBunker == 0;	 
end;

function Baler:getCanTurnOn()
	return self.state_baler == Baler.STATE_OFF and self.fillLevel >= 4000;
end;

function Baler:doTurnOn()
	self:onTurnOnBaler();
	self:onTurnOnStacker();
end;

function Baler:doTurnOff()
	self.shouldTurnOff = true;
end;

function Baler:onEnterBaleTrigger(ref, bale)
	if ref ==  Baler.BALETRIGGER_MAIN then
		local alreadyExist = false;
		for k,b in pairs(self.stackBales) do
			if b == bale then
				alreadyExist = true;
				break;
			end;
		end;
		if not alreadyExist then
			table.insert(self.stackBales, bale);
		end;
	end;
end;

function Baler:onLeaveBaleTrigger(ref, bale)
	if ref ==  Baler.BALETRIGGER_MAIN then
		for k,b in pairs(self.stackBales) do
			if b == bale then
				table.remove(self.stackBales, k);
				break;
			end;
		end;
	end;
end;

function Baler:getIsOn()
	return self.state_baler == Baler.STATE_ON;
end;