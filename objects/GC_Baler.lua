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

	self.title = Utils.getNoNil(getXMLString(xmlFile, xmlKey .. "#title"), true);
	self.autoOn = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. "#autoOn"), true);

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
                    self:setFillTyp(fillType.index, true);
                end;
			else
				if fillType == nil then
					g_company.debug:writeModding(self.debugData, "[BALER - %s] Unknown fillType ( %s ) found", indexName, fillTypeName);
				end;
			end;
		end;
		i = i + 1;
	end;
	
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

	self.baleAnimation = GC_Animations:new(self.isServer, self.isClient)
	self.baleAnimation:load(self.nodeId, self, true, nil, xmlFile, string.format("%s.baleAnimation", mainPartKey));

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

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------Stacker--------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	local stackPartKey = xmlKey .. ".stack";
	self.hasStack = hasXMLProperty(xmlFile, stackPartKey);
	if self.hasStack then
		self.animationState = Baler.ANIMATION_CANSTACK;
		--self.stackerBaleTrigger:getNum() = 0;
		self.stackBalesTarget = 3;
		self.stackBales = {};
		
		self.forkNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, stackPartKey .. "#forkNode"), self.i3dMappings);		
		
		self.stackerBaleTrigger = self.triggerManager:loadTrigger(GC_BaleTrigger, self.nodeId , xmlFile, string.format("%s.baleTrigger", stackPartKey), Baler.BALETRIGGER_MAIN, GC_BaleTrigger.MODE_COUNTER);
				
		self.conveyorStacker = GC_Conveyor:new(self.isServer, self.isClient);
		self.conveyorStacker:load(self.nodeId, self, xmlFile, string.format("%s.conveyor", stackPartKey));

		self.raisedAnimationKeys = {};
		self.doStackAnimationEnd = GC_Animations:new(self.isServer, self.isClient)
		self.doStackAnimationEnd:load(self.nodeId, self, true, string.format("%s.doStackAnimationEnd", stackPartKey), xmlFile);
		self.doStackAnimationStart = GC_Animations:new(self.isServer, self.isClient)
		self.doStackAnimationStart:load(self.nodeId, self, true, string.format("%s.doStackAnimationStart", stackPartKey), xmlFile);
	end;

    self.soundStacker = g_company.sounds:new(self.isServer, self.isClient);
    self.soundStacker:load(self.nodeId, self, xmlFile, string.format("%s", stackPartKey), self.basedirectory);

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------BaleMover-------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	local baleMoverKey = xmlKey .. ".baleMover";
	self.movedMeters = 0;

	self.baleMoveCollision = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.moveCollision#node", baleMoverKey)), self.i3dMappings);
	setPairCollision(self.nodeId, self.baleMoveCollision, false);

	self.conveyorMover = GC_Conveyor:new(self.isServer, self.isClient);
	self.conveyorMover:load(self.nodeId, self, xmlFile, string.format("%s.conveyor", baleMoverKey));

	self.moveCollisionAnimation = GC_Animations:new(self.isServer, self.isClient)
	self.moveCollisionAnimation:load(self.nodeId, self, true, string.format("%s.moveCollisionAnimation", baleMoverKey), xmlFile);

	self.moveCollisionAnimationNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.moveCollisionAnimation#node", baleMoverKey)), self.i3dMappings);
	self.moveCollisionAnimationColliMask = getCollisionMask(self.moveCollisionAnimationNode);
	setCollisionMask(self.moveCollisionAnimationNode, 0);
		
	self.moverBaleTrigger = self.triggerManager:loadTrigger(GC_BaleTrigger, self.nodeId , xmlFile, string.format("%s.baleTriggerMover", baleMoverKey), Baler.BALETRIGGER_MOVER, GC_BaleTrigger.MODE_COUNTER);
	
    self.soundMover = g_company.sounds:new(self.isServer, self.isClient);
    self.soundMover:load(self.nodeId, self, xmlFile, string.format("%s", baleMoverKey), self.basedirectory);

	self.balerDirtyFlag = self:getNextDirtyFlag();
	return true;
end;

function Baler:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self)

	if self.triggerManager ~= nil then
		self.triggerManager:unregisterAllTriggers();
	end;

	self.conveyorFillType:delete();
	self.conveyorFillTypeEffect:delete();
	self.baleAnimation:delete();
	self.doStackAnimationStart:delete();
	self.doStackAnimationEnd:delete();
	self.moveCollisionAnimation:delete();

	self.soundMain:delete();
	self.soundStacker:delete();
	self.soundMover:delete();

	self.conveyorStacker:delete();
	self.conveyorMover:delete();
	
	Baler:superClass().delete(self)
end;


function Baler:readStream(streamId, connection)
	Baler:superClass().readStream(self, streamId, connection);

    if connection:getIsServer() then
    
	end;
end;

function Baler:writeStream(streamId, connection)
	Baler:superClass().writeStream(self, streamId, connection);

    if not connection:getIsServer() then
    
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
	self:setFillTyp(getXMLInt(xmlFile, key..".baler#fillType"));
	self:setFillLevel(getXMLFloat(xmlFile, key..".baler#fillLevel"));
	self:setFillLevelBunker(getXMLFloat(xmlFile, key..".baler#fillLevelBunker"), true);
	self.baleCounter = getXMLFloat(xmlFile, key..".baler#counter");
	self.autoOn = getXMLBool(xmlFile, key..".baler#autoOn");
	self.baleAnimation:setAnimTime(getXMLFloat(xmlFile, key..".baler#animationTime"));
	if self.baleAnimation:getAnimationTime() > 0 then	
		self:setBaleObjectToAnimation();	
		self.baleAnimation:setAnimationsState(true);
	end;


	self.state_stacker = getXMLInt(xmlFile, key..".stacker#state");
	self.baleTarget = getXMLInt(xmlFile, key..".stacker#stackBalesTarget");
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

	self.doStackAnimationEnd:setAnimTime(getXMLFloat(xmlFile, key..".stacker#doStackAnimationEndTime"));
	if self.doStackAnimationEnd:getAnimationTime() > 0 and self.doStackAnimationEnd:getAnimationTime() < 1 then		
		self.doStackAnimationEnd:setAnimationsState(true);
	end;

	self.doStackAnimationStart:setAnimTime(getXMLFloat(xmlFile, key..".stacker#doStackAnimationStartTime"));
	if self.doStackAnimationStart:getAnimationTime() > 0 and self.doStackAnimationStart:getAnimationTime() < 1 then		
		self.doStackAnimationStart:setAnimationsState(true);
	end;



	self.state_balerMove = getXMLInt(xmlFile, key..".mover#state");

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
	setXMLFloat(xmlFile, key .. ".baler#animationTime", self.baleAnimation:getAnimationTime());

	setXMLInt(xmlFile, key .. ".stacker#state", self.state_stacker);
	setXMLInt(xmlFile, key .. ".stacker#baleTarget", self.stackBalesTarget);
	setXMLInt(xmlFile, key .. ".stacker#animationState", self.animationState);
	setXMLInt(xmlFile, key .. ".stacker#forkNodeNums", getNumOfChildren(self.forkNode));	
	setXMLFloat(xmlFile, key .. ".stacker#doStackAnimationStartTime", self.doStackAnimationStart:getAnimationTime());
	setXMLFloat(xmlFile, key .. ".stacker#doStackAnimationEndTime", self.doStackAnimationEnd:getAnimationTime());

	setXMLInt(xmlFile, key .. ".mover#state", self.state_balerMove);
end;

function Baler:update(dt)
	if self.isServer then

		if self.state_baler == Baler.STATE_ON then
			if self.fillLevelBunker >= 4000 then
				if self:canUnloadBale() then					
					self:setBaleObjectToAnimation();
					self.baleAnimation:setAnimationsState(true);
					self.baleCounter = self.baleCounter + 1;
					self:setFillLevelBunker(-4000, true);
					if self.shouldTurnOff then
						self:onTurnOffBaler();
						self.shouldTurnOff = false;
					end;
				end;
			elseif self.fillLevel + self.fillLevelBunker >= 4000 then
				self:setFillLevelBunker(math.min(dt / 1000 * self.pressPerSecond, 4000 - self.fillLevelBunker, self.fillLevel));
			elseif self.baleAnimation:getAnimationTime() == 0 then
				if self.autoOn then
					self:onTurnOffBaler();
				end;
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
				elseif self.doStackAnimationStart:getAnimationTime() >= 0.6 and self.raisedAnimationKeys["0.6"] == nil then
					self:setBaleObjectToFork();
					for _,bale in pairs(self.stackBales) do
						bale:delete();
					end;
					self.stackBales = {};
					self.stackerBaleTrigger:reset();
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
					for i=1, getNumOfChildren(self.forkNode) do
						local child = getChildAt(self.forkNode, 0);
						self:createBale(child);
						delete(child);
					end;
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

function Baler:playerTriggerCanActivable(ref)
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

function Baler:setFillLevelBunker(delta, onlyBunker)    
	if delta ~= nil then
		self.fillLevelBunker = self.fillLevelBunker + delta;
		if onlyBunker == nil or not onlyBunker then
			self:setFillLevel(self.fillLevel + (delta * -1));
		end;
		g_company.gui:updateGuiData("gcPlaceable_baler");
	end;	
end;

function Baler:setFillLevel(level)    
    self.fillLevel = level;
	self.movers:updateMovers(level, self.activeFillTypeIndex);    
	g_company.gui:updateGuiData("gcPlaceable_baler");
end;

function Baler:setFillTyp(fillTypeIndex, onFirstRun)    
	if onFirstRun == nil or not onFirstRun then
		self.unloadTrigger.fillTypes = nil;
		self.unloadTrigger:setAcceptedFillTypeState(fillTypeIndex, true);
		
		if self.stackerBaleTrigger:getNum() > 0 and self.state_balerMove == Baler.STATE_OFF and self.moverBaleTrigger:getTriggerEmpty() then
			self:onTurnOnBaleMover();
			self.stackBales = {};
			setCollisionMask(self.moveCollisionAnimationNode, self.moveCollisionAnimationColliMask);
			self.moveCollisionAnimation:setAnimationsState(true);
		end;
	end;

	self.activeFillTypeIndex = fillTypeIndex; 
end;

function Baler:setBaleObjectToAnimation()
	for _,info in pairs (self.baleAnimationObjects) do
		if info.fillTypeIndex == self.activeFillTypeIndex then
			local newBale = clone(info.node, false, false, false);
			setVisibility(newBale, true);
			link(self.baleAnimationObjectNode, newBale);		
			break;
		end;
	end;
end;

function Baler:setBaleObjectToFork()
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
		canUnloadBale = not self.stackerBaleTrigger:getTriggerNotEmpty();
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

function Baler:onTurnOnBaler()	
	--event
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

function Baler:onTurnOffBaler()	
	--event
	self.state_baler = Baler.STATE_OFF;

	if self.isClient then
		self.conveyorFillTypeEffect:stop();
		self.conveyorFillType:stop();
	end;
end

function Baler:onTurnOnStacker()	
	--event
	self.state_stacker = Baler.STATE_ON;
	
	if self.isServer then
		self:raiseActive();
	end;

	if self.isClient then
	
	end;
end

function Baler:onTurnOffStacker()	
	--event
	self.state_stacker = Baler.STATE_OFF;

	if self.isClient then
	
	end;
end

function Baler:onTurnOnBaleMover()	
	--event
	self.state_balerMove = Baler.STATE_ON;
	
	if self.isServer then
		self:raiseActive();
		setFrictionVelocity(self.baleMoveCollision, 0.8);
		self.conveyorStacker:start();
		self.conveyorMover:start();
	end;

	if self.isClient then
	
	end;
end

function Baler:onTurnOffBaleMover()	
	--event
	self.state_balerMove = Baler.STATE_OFF;

	if self.isServer then
		setFrictionVelocity(self.baleMoveCollision, 0.0);
		self.conveyorStacker:stop();
		self.conveyorMover:stop();
	end;

	if self.isClient then
	
	end;
end

function Baler:setStackBalesTarget(num)
	--event
	self.stackBalesTarget = num;
end;

function Baler:setAutoOn(state)
	--event
	self.autoOn = state;
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

