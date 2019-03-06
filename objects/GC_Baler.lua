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
                    self:setFillTyp(fillType.index);
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

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------Stacker--------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	local stackPartKey = xmlKey .. ".stack";
	self.hasStack = hasXMLProperty(xmlFile, stackPartKey);
	if self.hasStack then
		self.animationState = Baler.ANIMATION_CANSTACK;
		self.stackBalesNum = 0;
		self.stackBalesTarget = 3;
		self.baleInsideCounter = 0;
		self.stackBales = {};
		
		self.forkNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, stackPartKey .. "#forkNode"), self.i3dMappings);
		self.baleTriggerNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, stackPartKey .. ".baleTrigger#node"), self.i3dMappings);
		addTrigger(self.baleTriggerNode, "baleTriggerCallback", self);

		self.raisedAnimationKeys = {};
		self.doStackAnimationEnd = GC_Animations:new(self.isServer, self.isClient)
		self.doStackAnimationEnd:load(self.nodeId, self, true, string.format("%s.doStackAnimationEnd", stackPartKey), xmlFile);
		self.doStackAnimationStart = GC_Animations:new(self.isServer, self.isClient)
		self.doStackAnimationStart:load(self.nodeId, self, true, string.format("%s.doStackAnimationStart", stackPartKey), xmlFile);
	end;

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------BaleMover-------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	local baleMoverKey = xmlKey .. ".baleMover";
	self.movedMeters = 0;

	self.baleMoveCollision = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.moveCollision#node", baleMoverKey)), self.i3dMappings);
	setPairCollision(self.nodeId, self.baleMoveCollision, false);

	self.moveCollisionAnimation = GC_Animations:new(self.isServer, self.isClient)
	self.moveCollisionAnimation:load(self.nodeId, self, true, string.format("%s.moveCollisionAnimation", baleMoverKey), xmlFile);

	self.moveCollisionAnimationNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.moveCollisionAnimation#node", baleMoverKey)), self.i3dMappings);
	self.moveCollisionAnimationColliMask = getCollisionMask(self.moveCollisionAnimationNode);
	setCollisionMask(self.moveCollisionAnimationNode, 0);
	
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

	return true;
end;

function Baler:saveToXMLFile(xmlFile, key, usedModNames)
	
end;

function Baler:update(dt)
	if self.isServer then

		if self.state_baler == Baler.STATE_ON then
			if self.fillLevelBunker >= 4000 then
				if self:canUnloadBale() then					
					self:setBaleObjectToAnimation();
					self.baleAnimation:setAnimationsState(true);
					self:setFillLevelBunker(-4000, true);
				end;
			elseif self.fillLevel + self.fillLevelBunker >= 4000 then
				self:setFillLevelBunker(math.min(dt / 1000 * self.pressPerSecond, 4000 - self.fillLevelBunker, self.fillLevel));
			elseif self.baleAnimation:getAnimationTime() == 0 then
				if self.autoOn then
					self:onTurnOffBaler();
				end;
			end;
			if self.baleAnimation:getAnimationTime() == 1 then
				self:createBale(self.baleAnimationObjectNode);
				self.baleAnimation:setAnimTime(0);
				delete(getChildAt(self.baleAnimationObjectNode, 0));
			end;
		end;

		if self.hasStack and self.state_stacker == Baler.STATE_ON then
			if self.animationState == Baler.ANIMATION_CANSTACK then
				if self:getBaleIsInside() then					
					self.stackBalesNum = self.stackBalesNum + 1;
					if self.stackBalesNum < self.stackBalesTarget then
						self.animationState = Baler.ANIMATION_ISSTACKING;
						self.doStackAnimationStart:setAnimationsState(true);
					else
						if self.state_balerMove == Baler.STATE_OFF then
							self:onTurnOnBaleMover();
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
						self.stackBalesNum = 0;
						self.stackBales = {};
						self.baleInsideCounter = 0;
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
					self.baleInsideCounter = 0;
					self.raisedAnimationKeys["0.6"] = true;
				end;
			elseif self.animationState == Baler.ANIMATION_CANSTACKEND then
				if self:getBaleIsInside() then
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
		self:raiseActive();
	end;
end;

function Baler:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
	self:setFillLevel(self.fillLevel + fillLevelDelta);
	
	if self.autoOn and self.fillLevel > 4000 and (self.state_baler == Baler.STATE_OFF) then
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
	end;	
end;

function Baler:setFillLevel(level)    
    self.fillLevel = level;
	self.movers:updateMovers(level, self.activeFillTypeIndex);    
end;

function Baler:setFillTyp(fillTypeIndex)    
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
			for i=1, self.stackBalesNum do
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
	local canUnloadBale = false;

	canUnloadBale = self.baleAnimation:getAnimationTime() == 0;

	if canUnloadBale and self.hasStack then
		canUnloadBale = not self:getBaleIsInside();
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
end

function Baler:getBaleIsInside()
	return self.baleInsideCounter ~= 0;
end;

function Baler:baleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local object = g_currentMission:getNodeObject(otherId)
	if object ~= nil and object:isa(Bale) then
		if onEnter  then	
			self.baleInsideCounter = self.baleInsideCounter + 1;
		elseif onLeave then
			self.baleInsideCounter = math.max(self.baleInsideCounter - 1, 0);
		end;
	end;
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
	end;

	if self.isClient then
	
	end;
end

function Baler:onTurnOffBaleMover()	
	--event
	self.state_balerMove = Baler.STATE_OFF;

	if self.isServer then
		setFrictionVelocity(self.baleMoveCollision, 0.0);
	end;

	if self.isClient then
	
	end;
end