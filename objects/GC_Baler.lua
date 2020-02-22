--
-- GlobalCompany - Objects - GC_Baler
--
-- @Interface: 1.3.0.1 b4009
-- @Author: LS-Modcompany / kevink98
-- @Date: 22.02.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (22.02.2020):
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

GC_Baler = {}
GC_Baler._mt = Class(GC_Baler, g_company.gc_class)
InitObjectClass(GC_Baler, "GC_Baler")

GC_Baler.debugIndex = g_company.debug:registerScriptName("GC_Baler")

GC_Baler.PLAYERTRIGGER_MAIN = 0
GC_Baler.PLAYERTRIGGER_CLEAN = 1

GC_Baler.BALETRIGGER_MAIN = 0
GC_Baler.BALETRIGGER_MOVER = 1
GC_Baler.BALETRIGGER_MAIN2 = 3

GC_Baler.STATE_OFF = 0
GC_Baler.STATE_ON = 1

GC_Baler.ANIMATION_CANSTACK = 0
GC_Baler.ANIMATION_ISSTACKING = 1
GC_Baler.ANIMATION_CANSTACKEND = 2
GC_Baler.ANIMATION_ISSTACKINGEND = 3

function GC_Baler:onCreate(transformId)
	local indexName = getUserAttribute(transformId, "indexName")
	local xmlFilename = getUserAttribute(transformId, "xmlFile")
	local farmlandId = getUserAttribute(transformId, "farmlandId")

	if indexName ~= nil and xmlFilename ~= nil and farmlandId ~= nil then
		local customEnvironment = g_currentMission.loadingMapModName
		local baseDirectory = g_currentMission.loadingMapBaseDirectory

		local object = GC_Baler:new(g_server ~= nil, g_client ~= nil, nil, xmlFilename, baseDirectory, customEnvironment)
		local xmlFile, xmlKey = g_company.xmlUtils:getXMLFileAndKey(xmlFilename, baseDirectory, "globalCompany.balers.baler", indexName, "indexName")
		if xmlFile ~= nil and xmlKey ~= nil then
			if object:load(transformId, xmlFile, xmlKey, indexName, false) then
				local onCreateIndex = g_currentMission:addOnCreateLoadedObject(object)
				g_currentMission:addOnCreateLoadedObjectToSave(object)

				g_company.debug:writeOnCreate(object.debugData, "[BALER - %s]  Loaded successfully from '%s'!  [onCreateIndex = %d]", indexName, xmlFilename, onCreateIndex)
				object:register(true)

				local warningText = string.format("[BALER - %s]  Attribute 'farmlandId' is invalid! BALER will not operate correctly. 'farmlandId' should match area object is located at.", indexName)
				g_company.farmlandOwnerListener:addListener(object, farmlandId, warningText)
			else
				g_company.debug:writeOnCreate(object.debugData, "[BALER - %s]  Failed to load from '%s'!", indexName, xmlFilename)
				object:delete()
			end

			delete(xmlFile)
		else
			if xmlFile == nil then
				g_company.debug:writeModding(object.debugData, "[BALER - %s]  XML File '%s' could not be loaded!", indexName, xmlFilename)
			else
				g_company.debug:writeModding(object.debugData, "[BALER - %s]  XML Key containing  indexName '%s' could not be found in XML File '%s'", indexName, indexName, xmlFilename)
			end
		end
	else
		g_company.debug:print("  [LSMC - GlobalCompany] - [BALER]")
		if indexName == nil then
			g_company.debug:print("    ONCREATE: Trying to load 'BALER' with nodeId name %s, attribute 'indexName' could not be found.", getName(transformId))
		else
			if xmlFilename == nil then
				g_company.debug:print("    ONCREATE: [BALER - %s]  Attribute 'xmlFilename' is missing!", indexName)
			end

			if farmlandId == nil then
				g_company.debug:print("    ONCREATE: [BALER - %s]  Attribute 'farmlandId' is missing!", indexName)
			end
		end
	end
end

function GC_Baler:new(isServer, isClient, customMt, xmlFilename, baseDirectory, customEnvironment)
	return GC_Baler:superClass():new(GC_Baler._mt, isServer, isClient, scriptDebugInfo, xmlFilename, baseDirectory, customEnvironment)
end

function GC_Baler:load(nodeId, xmlFile, xmlKey, indexName, isPlaceable)
	GC_Baler:superClass().load(self)
	self.nodeId  = nodeId
	self.indexName = indexName
	self.isPlaceable = isPlaceable

	self.triggerManager = GC_TriggerManager:new(self)
	self.i3dMappings = GC_i3dLoader:loadI3dMapping(xmlFile, xmlKey .. ".i3dMappings")

	self.saveId = getXMLString(xmlFile, xmlKey .. "#saveId")
	if self.saveId == nil then
		self.saveId = "GC_Baler_" .. indexName
	end
	
	self.state_baler = GC_Baler.STATE_OFF
	self.state_stacker = GC_Baler.STATE_OFF
	self.state_balerMove = GC_Baler.STATE_OFF

	self.shouldTurnOff = false
	self.needMove = false

	self.synch_fillLevel = false
	self.synch_fillLevelBunker = false

	self.title = Utils.getNoNil(getXMLString(xmlFile, xmlKey .. "#title"), true)
	self.autoOn = Utils.getNoNil(getXMLBool(xmlFile, xmlKey .. "#autoOn"), true)
	
	local animationManager = GC_AnimationManager:new(self.isServer, self.isClient)
	if animationManager:load(self.nodeId, self, xmlFile, xmlKey, true) then
		animationManager:register(true)
		self.animationManager = animationManager
	else
		animationManager:delete()
	end

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------MainPart--------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	local mainPartKey = xmlKey .. ".mainPart"
	
    local fillTypesKey = string.format("%s.fillTypes", mainPartKey)
	if not hasXMLProperty(xmlFile, fillTypesKey) then
		--debug
		return false
    end
    
	self.fillLevel = 0
	self.fillLevelBunker = 0
    self.capacity = Utils.getNoNil(getXMLInt(xmlFile, mainPartKey .. "#capacity"), 50000)
	self.pressPerSecond = Utils.getNoNil(getXMLInt(xmlFile, mainPartKey .. "#pressPerSecond"), 400)
	self.baleCounter = 0
	    
    local capacities = {}
	self.fillTypes = {}
	self.fillTypeToBaleType = {}
	local i = 0
	while true do
		local fillTypeKey = string.format("%s.fillType(%d)", fillTypesKey, i)
		if not hasXMLProperty(xmlFile, fillTypeKey) then
			break
        end

        local fillTypeName = getXMLString(xmlFile, fillTypeKey .. "#name")
        local baleTypeName = getXMLString(xmlFile, fillTypeKey .. "#baleTypeName")
		if fillTypeName ~= nil then
			local fillType = g_fillTypeManager:getFillTypeByName(fillTypeName)
			if fillType ~= nil then
                self.fillTypes[fillType.index] = fillType
				capacities[fillType.index] = self.capacity
				self.fillTypeToBaleType[fillType.index] = g_baleTypeManager.nameToBaleType[baleTypeName]
                if self.activeFillTypeIndex == nil then
                    self:setFillTyp(fillType.index, true, true)
                end
			else
				if fillType == nil then
					--g_company.debug:writeModding(self.debugData, "[GC_Baler - %s] Unknown fillType ( %s ) found", indexName, fillTypeName)
				end
			end
		end
		i = i + 1
	end

	if self.isClient then
		self.unloadTrigger = self.triggerManager:addTrigger(GC_UnloadingTrigger, self.nodeId, self, xmlFile, string.format("%s.unloadTrigger", mainPartKey), {[1] = self.fillTypes[self.activeFillTypeIndex].index}, {[1] = "DISCHARGEABLE"})
		self.cleanHeap = self.triggerManager:addTrigger(GC_DynamicHeap, self.nodeId, self , xmlFile, string.format("%s.cleanHeap", mainPartKey), self.fillTypes[self.activeFillTypeIndex].name, nil, false)
		
		self.playerTrigger = self.triggerManager:addTrigger(GC_PlayerTrigger, self.nodeId, self , xmlFile, string.format("%s.playerTrigger", mainPartKey), GC_Baler.PLAYERTRIGGER_MAIN, true, g_company.languageManager:getText("GC_baler_openGui"))
		self.playerTriggerClean = self.triggerManager:addTrigger(GC_PlayerTrigger, self.nodeId, self , xmlFile, string.format("%s.playerTriggerClean", mainPartKey), GC_Baler.PLAYERTRIGGER_CLEAN, true, g_company.languageManager:getText("GC_baler_cleaner"), true)
	
		self.movers = GC_Movers:new(self.isServer, self.isClient)
		self.movers:load(self.nodeId , self, xmlFile, mainPartKey, self.baseDirectory, capacities)
		
		self.conveyorFillType = GC_Conveyor:new(self.isServer, self.isClient)
		self.conveyorFillType:load(self.nodeId, self, xmlFile, mainPartKey, "conveyor")
		self.conveyorFillTypeEffect = GC_ConveyorEffekt:new(self.isServer, self.isClient)
		self.conveyorFillTypeEffect:load(self.nodeId, self, xmlFile, mainPartKey, "conveyor.effect")

		if hasXMLProperty(xmlFile, mainPartKey .. ".digitalDisplayLevel") then
			local digitalDisplays = GC_DigitalDisplays:new(self.isServer, self.isClient)
			if digitalDisplays:load(self.nodeId, self, xmlFile, mainPartKey, "digitalDisplayLevel", true) then
				self.digitalDisplayLevel = digitalDisplays
				self.digitalDisplayLevel:updateLevelDisplays(self.fillLevel, self.capacity)
			end
		end

		if hasXMLProperty(xmlFile, mainPartKey .. ".digitalDisplayBunker") then
			local digitalDisplays = GC_DigitalDisplays:new(self.isServer, self.isClient)
			if digitalDisplays:load(self.nodeId, self, xmlFile, mainPartKey, "digitalDisplayBunker", true) then
				self.digitalDisplayBunker = digitalDisplays
				self.digitalDisplayBunker:updateLevelDisplays(self.fillLevel, 4000)
			end
		end

		if hasXMLProperty(xmlFile, mainPartKey .. ".digitalDisplayNum") then
			local digitalDisplays = GC_DigitalDisplays:new(self.isServer, self.isClient)
			if digitalDisplays:load(self.nodeId, self, xmlFile, mainPartKey, "digitalDisplayNum", true) then
				self.digitalDisplayNum = digitalDisplays
				self.digitalDisplayNum:updateLevelDisplays(self.baleCounter, 9999999999)
			end
		end
		
		self.baleAnimationObjects = {}
		
		i = 0
		while true do
			local objectKey = string.format("%s.baleAnimation.objects.object(%d)", mainPartKey, i)
			if not hasXMLProperty(xmlFile, objectKey) then
				break
			end

			local node = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, objectKey .. "#node"), self.i3dMappings)
			local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(getXMLString(xmlFile, objectKey .. "#fillTypeName"))
			
			setVisibility(node, false)
			table.insert(self.baleAnimationObjects, {node=node, fillTypeIndex=fillTypeIndex})
			
			i = i + 1
		end
		
		self.soundMain = g_company.sounds:new(self.isServer, self.isClient)
		self.soundMain:load(self.nodeId, self, xmlFile, string.format("%s", mainPartKey), self.basedirectory)
	end	
	
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------Stacker--------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	local stackPartKey = xmlKey .. ".stack"
	self.hasStack = hasXMLProperty(xmlFile, stackPartKey)
	if self.hasStack then
		self.animationState = GC_Baler.ANIMATION_CANSTACK
		self.stackBalesTarget = 3
		self.stackBales = {}
		
		self.stackerBaleTrigger = self.triggerManager:addTrigger(GC_BaleTrigger, self.nodeId, self , xmlFile, string.format("%s.baleTrigger", stackPartKey), GC_Baler.BALETRIGGER_MAIN, GC_BaleTrigger.MODE_COUNTER)
				
		self.conveyorStacker = GC_Conveyor:new(self.isServer, self.isClient)
		self.conveyorStacker:load(self.nodeId, self, xmlFile, stackPartKey, "conveyor")

		self.raisedAnimationKeys = {}
		
		if self.isClient then
			self.soundStacker = g_company.sounds:new(self.isServer, self.isClient)
			self.soundStacker:load(self.nodeId, self, xmlFile, string.format("%s", stackPartKey), self.basedirectory)
		end
	else
		self.mainBaleTrigger = self.triggerManager:addTrigger(GC_BaleTrigger, self.nodeId, self , xmlFile, string.format("%s.baleTrigger", mainPartKey), GC_Baler.BALETRIGGER_MAIN2, GC_BaleTrigger.MODE_COUNTER)
	end

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------BaleMover-------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	local baleMoverKey = xmlKey .. ".baleMover"
	self.movedMeters = 0

	self.baleMoveCollision = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.moveCollision#node", baleMoverKey)), self.i3dMappings)
	setPairCollision(self.nodeId, self.baleMoveCollision, false)

	self.conveyorMover = GC_Conveyor:new(self.isServer, self.isClient)
	self.conveyorMover:load(self.nodeId, self, xmlFile, baleMoverKey, "conveyor")

	self.moveCollisionAnimationNode = I3DUtil.indexToObject(self.nodeId, getXMLString(xmlFile, string.format("%s.moveCollisionAnimation#node", baleMoverKey)), self.i3dMappings)
	self.moveCollisionAnimationColliMask = getCollisionMask(self.moveCollisionAnimationNode)
	setCollisionMask(self.moveCollisionAnimationNode, 0)
		
	self.moverBaleTrigger = self.triggerManager:addTrigger(GC_BaleTrigger, self.nodeId, self , xmlFile, string.format("%s.baleTriggerMover", baleMoverKey), GC_Baler.BALETRIGGER_MOVER, GC_BaleTrigger.MODE_COUNTER)
	
	if self.isClient then
		self.soundMover = g_company.sounds:new(self.isServer, self.isClient)
		self.soundMover:load(self.nodeId, self, xmlFile, string.format("%s", baleMoverKey), self.basedirectory)
	end

	self.GC_BalerDirtyFlag = self:getNextDirtyFlag()
	return true
end

function GC_Baler:finalizePlacement()
	GC_Baler:superClass().finalizePlacement(self)	
	self.eventId_setFillLevelBunker = self:registerEvent(self, self.setFillLevelBunkerEvent, false, false)
	self.eventId_setFillLevel = self:registerEvent(self, self.setFillLevelEvent, false, false)
	self.eventId_setFillTyp = self:registerEvent(self, self.setFillTypEvent, false, false)
	self.eventId_selfonTurnOnBaler = self:registerEvent(self, self.selfonTurnOnBalerEvent, false, false)
	self.eventId_onTurnOffGC_Baler = self:registerEvent(self, self.onTurnOffGC_BalerEvent, false, false)
	self.eventId_onTurnOnStacker = self:registerEvent(self, self.onTurnOnStackerEvent, false, false)
	self.eventId_onTurnOffStacker = self:registerEvent(self, self.onTurnOffStackerEvent, false, false)
	self.eventId_onTurnOnBaleMover = self:registerEvent(self, self.onTurnOnBaleMoverEvent, false, false)
	self.eventId_onTurnOffBaleMover = self:registerEvent(self, self.onTurnOffBaleMoverEvent, false, false)
	self.eventId_baleTarget = self:registerEvent(self, self.setStackBalesTargetEvent, false, false)
	self.eventId_setAutoOn = self:registerEvent(self, self.setAutoOnEvent, false, false)
	self.eventId_setBaleObjectToAnimation = self:registerEvent(self, self.setBaleObjectToAnimationEvent, false, false)
	self.eventId_setBaleObjectToFork = self:registerEvent(self, self.setBaleObjectToForkEvent, false, false)
	self.eventId_removeBaleObjectFromForkEvent = self:registerEvent(self, self.removeBaleObjectFromForkEvent, false, false)
	self.eventId_removeBaleObjectFromAnimationEvent = self:registerEvent(self, self.removeBaleObjectFromAnimationEvent, false, false)
	self.eventId_resetBaleTrigger = self:registerEvent(self, self.resetBaleTriggerEvent, false, false)
	self.eventId_inkBaleCounter = self:registerEvent(self, self.inkBaleCounterEvent, false, false)
end

function GC_Baler:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self)

	if self.triggerManager ~= nil then
		self.triggerManager:removeAllTriggers()
	end
	if self.conveyorFillType ~= nil then
		self.conveyorFillType:delete()
	end
	if self.conveyorFillTypeEffect ~= nil then
		self.conveyorFillTypeEffect:delete()
	end
	if self.animationManager ~= nil then
		self.animationManager:delete()
	end
	if self.soundMain ~= nil then
		self.soundMain:delete()
	end
	if self.soundStacker ~= nil then
		self.soundStacker:delete()
	end
	if self.soundMover ~= nil then
		self.soundMover:delete()
	end
	if self.conveyorStacker ~= nil then
		self.conveyorStacker:delete()
	end
	if self.conveyorMover ~= nil then
		self.conveyorMover:delete()
	end
	
	GC_Baler:superClass().delete(self)
end

function GC_Baler:readStream(streamId, connection)
	GC_Baler:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then		
		if self.animationManager ~= nil then
			local animationManagerId = NetworkUtil.readNodeObjectId(streamId)
            self.animationManager:readStream(streamId, connection)
            g_client:finishRegisterObject(self.animationManager, animationManagerId)
		end

		if self.triggerManager ~= nil then
			self.triggerManager:readStream(streamId, connection)
        end

		self.state_baler = streamReadInt16(streamId)
		self.shouldTurnOff = streamReadBool(streamId)
		self.needMove = streamReadBool(streamId)
		self:setFillTyp(streamReadInt16(streamId), false)
		self:setFillLevel(streamReadFloat32(streamId), true)
		self:setFillLevelBunker(streamReadFloat32(streamId), true, true)
		self.baleCounter = streamReadInt16(streamId)
		self.autoOn = streamReadBool(streamId)
		self.animationManager:setAnimationTime("baleAnimation", streamReadFloat32(streamId))
		if self.animationManager:getAnimationTime("baleAnimation") > 0 then	
			self:setBaleObjectToAnimation(true)	
			self.animationManager:setAnimationByState("baleAnimation", true, true)
		end
		
		if self.hasStack then
			self.state_stacker = streamReadInt16(streamId)
			self.stackBalesTarget = streamReadInt16(streamId)
			self.animationState = streamReadInt16(streamId)

			local forkNodeNums = streamReadInt16(streamId)
			for _,info in pairs (self.baleAnimationObjects) do
				if info.fillTypeIndex == self.activeFillTypeIndex then
					for i=1, forkNodeNums do
						local newBale = clone(info.node, false, false, false)
						setVisibility(newBale, true)
						setTranslation(newBale, 0.015, 0.958 + (i-1)*0.8,-0.063)
						link(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node, newBale)		
					end
					break
				end
			end

			self.animationManager:setAnimationTime("stackAnimation", streamReadFloat32(streamId))
			local time = self.animationManager:getAnimationTime("stackAnimation")
			if self.animationState == GC_Baler.ANIMATION_ISSTACKING or self.animationState == GC_Baler.ANIMATION_ISSTACKINGEND then		
				self.animationManager:setAnimationByState("stackAnimation", true, true)
			end
		end
	
		if g_dedicatedServerInfo == nil then		
			self.digitalDisplayLevel:updateLevelDisplays(self.fillLevel, self.capacity)
			self.digitalDisplayBunker:updateLevelDisplays(self.fillLevelBunker, 4000)
			self.digitalDisplayNum:updateLevelDisplays(self.baleCounter, 9999999999)
		end

		if self.state_baler == Bale.STATE_ON then
			self.conveyorFillTypeEffect:setFillType(self.activeFillTypeIndex)
			self.conveyorFillTypeEffect:start()
			self.conveyorFillType:start()
		end

		self.state_balerMove = streamReadInt16(streamId)		
	end
end

function GC_Baler:writeStream(streamId, connection)
	GC_Baler:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then	
		if self.animationManager ~= nil then
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.animationManager))
            self.animationManager:writeStream(streamId, connection)
            g_server:registerObjectInStream(connection, self.animationManager)
		end

		if self.triggerManager ~= nil then
			self.triggerManager:writeStream(streamId, connection)
		end

		streamWriteInt16(streamId, self.state_baler)
		streamWriteBool(streamId, self.shouldTurnOff)
		streamWriteBool(streamId, self.needMove)
		streamWriteInt16(streamId, self.activeFillTypeIndex)
		streamWriteFloat32(streamId, self.fillLevel)
		streamWriteFloat32(streamId, self.fillLevelBunker)
		streamWriteInt16(streamId, self.baleCounter)
		streamWriteBool(streamId, self.autoOn)
		streamWriteFloat32(streamId, self.animationManager:getAnimationTime("baleAnimation"))
		
		if self.hasStack then
			streamWriteInt16(streamId, self.state_stacker)
			streamWriteInt16(streamId, self.stackBalesTarget)
			streamWriteInt16(streamId, self.animationState)
			streamWriteInt16(streamId, getNumOfChildren(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node))
			streamWriteFloat32(streamId, self.animationManager:getAnimationTime("stackAnimation"))
		end

		streamWriteInt16(streamId, self.state_balerMove)
		
		--self.dirtyObject:writeStream(streamId, connection)
	end
end

function GC_Baler:loadFromXMLFile(xmlFile, key)	
	GC_Baler:superClass().loadFromXMLFile(self, xmlFile, key)
	self.state_baler = getXMLInt(xmlFile, key..".GC_Baler#state")
	self.shouldTurnOff = getXMLBool(xmlFile, key..".GC_Baler#shouldTurnOff")
	self.needMove = Utils.getNoNil(getXMLBool(xmlFile, key..".GC_Baler#needMove"), false)
	self:setFillTyp(getXMLInt(xmlFile, key..".GC_Baler#fillType"), false)
	self:setFillLevel(getXMLFloat(xmlFile, key..".GC_Baler#fillLevel"), true)
	self:setFillLevelBunker(getXMLFloat(xmlFile, key..".GC_Baler#fillLevelBunker"), true, true)
	self.baleCounter = getXMLFloat(xmlFile, key..".GC_Baler#counter")
	self.autoOn = getXMLBool(xmlFile, key..".GC_Baler#autoOn")
	
	self.animationManager:setAnimationTime("baleAnimation", getXMLFloat(xmlFile, key..".GC_Baler#animationTime"))
	if self.animationManager:getAnimationTime("baleAnimation") > 0 then	
		self:setBaleObjectToAnimation(true)	
		self.animationManager:setAnimationByState("baleAnimation", true)
	end

	if self.hasStack then
		self.state_stacker = getXMLInt(xmlFile, key..".stacker#state")
		self.stackBalesTarget = getXMLInt(xmlFile, key..".stacker#stackBalesTarget")
		self.animationState = getXMLInt(xmlFile, key..".stacker#animationState")

		local forkNodeNums = getXMLInt(xmlFile, key..".stacker#forkNodeNums")
		for _,info in pairs (self.baleAnimationObjects) do
			if info.fillTypeIndex == self.activeFillTypeIndex then
				for i=1, forkNodeNums do
					local newBale = clone(info.node, false, false, false)
					setVisibility(newBale, true)
					setTranslation(newBale, 0.015, 0.958 + (i-1)*0.8,-0.063)
					link(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node, newBale)		
				end
				break
			end
		end
	
		self.animationManager:setAnimationTime("stackAnimation", getXMLFloat(xmlFile, key..".stacker#stackAnimation"))
		local time = self.animationManager:getAnimationTime("stackAnimation")
		
		if self.animationState == GC_Baler.ANIMATION_ISSTACKING or self.animationState == GC_Baler.ANIMATION_ISSTACKINGEND then		
			self.animationManager:setAnimationByState("stackAnimation", true)
		end
	end
	
	if g_dedicatedServerInfo == nil then		
		self.digitalDisplayLevel:updateLevelDisplays(self.fillLevel, self.capacity)
		self.digitalDisplayBunker:updateLevelDisplays(self.fillLevelBunker, 4000)
		self.digitalDisplayNum:updateLevelDisplays(self.baleCounter, 9999999999)

		if self.state_baler == GC_Baler.STATE_ON then
			self.conveyorFillTypeEffect:setFillType(self.activeFillTypeIndex)
			self.conveyorFillTypeEffect:start()
			self.conveyorFillType:start()
		end
	end

	self.state_balerMove = getXMLInt(xmlFile, key..".mover#state")

	return true
end

function GC_Baler:saveToXMLFile(xmlFile, key, usedModNames)
	GC_Baler:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
	
	setXMLInt(xmlFile, key .. ".GC_Baler#state", self.state_baler)
	setXMLBool(xmlFile, key .. ".GC_Baler#shouldTurnOff", self.shouldTurnOff)
	setXMLBool(xmlFile, key .. ".GC_Baler#needMove", self.needMove)
	setXMLFloat(xmlFile, key .. ".GC_Baler#fillLevel", self.fillLevel)
	setXMLFloat(xmlFile, key .. ".GC_Baler#fillLevelBunker", self.fillLevelBunker)
	setXMLInt(xmlFile, key .. ".GC_Baler#fillType", self.activeFillTypeIndex)
	setXMLFloat(xmlFile, key .. ".GC_Baler#counter", self.baleCounter)
	setXMLBool(xmlFile, key .. ".GC_Baler#autoOn", self.autoOn)
	setXMLFloat(xmlFile, key .. ".GC_Baler#animationTime", self.animationManager:getAnimationTime("baleAnimation"))

	if self.hasStack then
		setXMLInt(xmlFile, key .. ".stacker#state", self.state_stacker)
		setXMLInt(xmlFile, key .. ".stacker#stackBalesTarget", self.stackBalesTarget)
		setXMLInt(xmlFile, key .. ".stacker#animationState", self.animationState)
		setXMLInt(xmlFile, key .. ".stacker#forkNodeNums", getNumOfChildren(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node))	
		setXMLFloat(xmlFile, key .. ".stacker#stackAnimation", self.animationManager:getAnimationTime("stackAnimation"))
	end

	setXMLInt(xmlFile, key .. ".mover#state", self.state_balerMove)
end

function GC_Baler:update(dt)
	GC_Baler:superClass().update(self, dt)
	if self.isServer then
		if self.state_baler == GC_Baler.STATE_ON then
			if self.fillLevelBunker >= 4000 then
				if self:canUnloadBale() then					
					self:setBaleObjectToAnimation()
					self.animationManager:setAnimationByState("baleAnimation", true)
					self:inkBaleCounter()
					self:setFillLevelBunker(self.fillLevelBunker * -1, true)
					if self.shouldTurnOff or self.fillLevel + self.fillLevelBunker < 4000 then
						self:onTurnOffGC_Baler()
						self.shouldTurnOff = false
					end
				elseif not self.hasStack then
					if self.animationManager:getAnimationTime("moveCollisionAnimation") == 0 and self.moverBaleTrigger:getTriggerEmpty() then
						setCollisionMask(self.moveCollisionAnimationNode, self.moveCollisionAnimationColliMask)
						self.animationManager:setAnimationByState("moveCollisionAnimation", true)
						self:onTurnOnBaleMover()
					elseif self.animationManager:getAnimationTime("moveCollisionAnimation") == 1 then
						self.animationManager:setAnimationTime("moveCollisionAnimation", 0)
						setCollisionMask(self.moveCollisionAnimationNode, 0)
					elseif self.animationManager:getAnimationTime("moveCollisionAnimation") == 0 and not self.moverBaleTrigger:getTriggerEmpty() and self.state_balerMove == GC_Baler.STATE_OFF then	
						self:onTurnOffGC_Baler()
					end
				else
					self:onTurnOffGC_Baler()
				end
			elseif self.fillLevel + self.fillLevelBunker >= 4000 then
				self:setFillLevelBunker(math.min(dt / 1000 * self.pressPerSecond, 4000 - self.fillLevelBunker, self.fillLevel))
			else --if self.animationManager:getAnimationTime("baleAnimation") == 0 then
				self:onTurnOffGC_Baler()
			end
		elseif self.fillLevelBunker >= 4000 and not self.hasStack then
			if self:canUnloadBale() then
				self:selfonTurnOnBaler()	
				self:onTurnOnStacker()
			elseif self.moverBaleTrigger:getTriggerEmpty() then
				self.needMove = true
			end
		end
		if self.needMove then			
			local canMove = self.state_balerMove == GC_Baler.STATE_OFF and self.moverBaleTrigger:getTriggerEmpty()		

			if canMove then		
				self:onTurnOnBaleMover(true)
				self.stackBales = {}
				setCollisionMask(self.moveCollisionAnimationNode, self.moveCollisionAnimationColliMask)
				if self.isServer then
					self.animationManager:setAnimationByState("moveCollisionAnimation", true)
				end
				self.needMove = false
			end
		end
		if not self.hasStack and self.state_balerMove == GC_Baler.STATE_ON then
			if self.animationManager:getAnimationTime("moveCollisionAnimation") == 1 then
				self.animationManager:setAnimationTime("moveCollisionAnimation", 0)
				setCollisionMask(self.moveCollisionAnimationNode, 0)
			end
			if self.movedMeters >= 2.6 then
				self.movedMeters = 0
				self:onTurnOffBaleMover()
			else
				self.movedMeters = self.movedMeters + (dt / 1000 * 0.8)
			end
		end
		if self.animationManager:getAnimationTime("baleAnimation") == 1 then
			if self.animationManager:getAnimationTime("moveCollisionAnimation") == 1 then
				self.animationManager:setAnimationTime("moveCollisionAnimation", 0)
				setCollisionMask(self.moveCollisionAnimationNode, 0)
			end
			self:createBale(self.animationManager:getPartsOfAnimation("baleAnimation")[1].node)
			self:removeBaleObjectFromAnimation()
		end
		
		if self.hasStack and self.state_stacker == GC_Baler.STATE_ON then
			if self.animationState == GC_Baler.ANIMATION_CANSTACK then
				if self.stackerBaleTrigger:getTriggerNotEmpty() and self.fillLevelBunker > 0 and not self.needMove then	
					if self.stackerBaleTrigger:getNum() < self.stackBalesTarget and self.state_balerMove == GC_Baler.STATE_OFF then
						self.animationState = GC_Baler.ANIMATION_ISSTACKING
						self.raisedAnimationKeys = {}
						self.animationManager:setAnimationByState("stackAnimation", true)
					else
						if self.state_balerMove == GC_Baler.STATE_OFF and self.moverBaleTrigger:getTriggerEmpty() then
							self:onTurnOnBaleMover()
							self.stackBales = {}
							setCollisionMask(self.moveCollisionAnimationNode, self.moveCollisionAnimationColliMask)
							self.animationManager:setAnimationByState("moveCollisionAnimation", true)
						end
						if self.animationManager:getAnimationTime("moveCollisionAnimation") == 1 then
							self.animationManager:setAnimationTime("moveCollisionAnimation", 0)
							setCollisionMask(self.moveCollisionAnimationNode, 0)
						end	
					end
				end
			elseif self.animationState == GC_Baler.ANIMATION_ISSTACKING then
				if self.animationManager:getRealAnimationTimeSeconds("stackAnimation") >= 2 and self.raisedAnimationKeys["2"] == nil then
					self.animationState = GC_Baler.ANIMATION_CANSTACKEND
					self.animationManager:stopAnimation("stackAnimation")
					self:resetBaleTrigger()
					self.raisedAnimationKeys["2"] = true
				elseif self.animationManager:getRealAnimationTimeSeconds("stackAnimation") >= 1 and self.raisedAnimationKeys["1"] == nil then
					self:setBaleObjectToFork()
					for _,bale in pairs(self.stackBales) do
						bale:delete()
					end
					self.stackBales = {}
					self.raisedAnimationKeys["1"] = true
				end
			elseif self.animationState == GC_Baler.ANIMATION_CANSTACKEND then
				if self.stackerBaleTrigger:getTriggerNotEmpty() then
					self.animationState = GC_Baler.ANIMATION_ISSTACKINGEND
					self.animationManager:playAnimation("stackAnimation", 1, 2000 / self.animationManager:getAnimationDuration("stackAnimation"))
				end
			elseif self.animationState == GC_Baler.ANIMATION_ISSTACKINGEND then
				if self.animationManager:getRealAnimationTimeSeconds("stackAnimation") >= 4.59999 then
					self.animationState = GC_Baler.ANIMATION_CANSTACK
					self.animationManager:setAnimationTime("stackAnimation", 0)	
				elseif self.animationManager:getRealAnimationTimeSeconds("stackAnimation") >= 2.6 and self.raisedAnimationKeys["2.6"] == nil then
					self:removeBaleObjectFromFork()
					self.raisedAnimationKeys["2.6"] = true
				end
			end
			if self.state_balerMove == GC_Baler.STATE_ON then
				if self.movedMeters >= 2.6 then
					self.movedMeters = 0
					self:resetBaleTrigger()
					self:onTurnOffBaleMover()
					if self.state_baler == GC_Baler.STATE_OFF and self.fillLevelBunker >= 4000 then
						self:selfonTurnOnBaler()
					elseif self.state_baler == GC_Baler.STATE_OFF and self.fillLevelBunker < 4000 then
						self:onTurnOffStacker()
					end
				else
					self.movedMeters = self.movedMeters + (dt / 1000 * 0.8)
				end
			end
		end
	end

	if self.isClient then
		self.soundMain:setSoundsState(self.state_baler == GC_Baler.STATE_ON)
		if self.hasStack then 
			self.soundStacker:setSoundsState(self.animationState == GC_Baler.ANIMATION_ISSTACKING or self.animationState == GC_Baler.ANIMATION_ISSTACKINGEND) 
		end
		self.soundMover:setSoundsState(self.state_balerMove == GC_Baler.STATE_ON) 
	end
	self:raiseActive()
end

function GC_Baler:addFillLevel(farmId, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, triggerId)
	self:setFillLevel(self.fillLevel + fillLevelDelta)
	
	if self.autoOn and self.fillLevel > 4000 and self.state_baler == GC_Baler.STATE_OFF then
		self:selfonTurnOnBaler()
		self:onTurnOnStacker()
	end
end

function GC_Baler:getFreeCapacity(dt)
	return self.capacity - self.fillLevel
end

function GC_Baler:playerTriggerCanAddActivatable(ref)
    if ref == GC_Baler.PLAYERTRIGGER_CLEAN then
        if self.fillLevel >= 4000 or self.fillLevel == 0 then
            return false
        end
    end
    return true
end

function GC_Baler:playerTriggerActivated(ref)
    if ref == GC_Baler.PLAYERTRIGGER_MAIN then
		g_company.gui:openGuiWithData("gc_placeableBaler", false, self)
    elseif ref == GC_Baler.PLAYERTRIGGER_CLEAN then
        if self.cleanHeap:getIsHeapEmpty() then
            if self.fillLevel < 4000 then
                self.cleanHeap.fillTypeIndex = self.activeFillTypeIndex                    
                self.cleanHeap:updateDynamicHeap(self.fillLevel, false)
                self:setFillLevel(0)
            end
        else
            -- heap is not empty
        end
    end
end


function GC_Baler:setFillLevelBunker(delta, onlyBunker, noEventSend)  
	self:setFillLevelBunkerEvent({delta, onlyBunker}, noEventSend)
end

function GC_Baler:setFillLevelBunkerEvent(data, noEventSend)    
	self:raiseEvent(self.eventId_setFillLevelBunker, data, noEventSend)
	if data[1] ~= nil then
		self.fillLevelBunker = self.fillLevelBunker + data[1]
		if data[2] == nil or not data[2] then
			self:setFillLevel(self.fillLevel + (data[1] * -1), true)
		end
		g_company.gui:updateGuiData("gc_placeableBaler")
	end

	if g_dedicatedServerInfo == nil then		
		self.digitalDisplayBunker:updateLevelDisplays(self.fillLevelBunker, 4000)
	end
end

function GC_Baler:setFillLevel(level, noEventSend)   
	self:setFillLevelEvent({level}, noEventSend)  
end

function GC_Baler:setFillLevelEvent(data, noEventSend)     
	self:raiseEvent(self.eventId_setFillLevel, data, noEventSend)
	self.fillLevel = data[1]
	if g_dedicatedServerInfo == nil then
		self.movers:updateMovers(data[1], self.activeFillTypeIndex)    
		g_company.gui:updateGuiData("gc_placeableBaler")
		self.digitalDisplayLevel:updateLevelDisplays(self.fillLevel, self.capacity)
	end	
end

function GC_Baler:setFillTyp(fillTypeIndex, onFirstRun, noEventSend)   
	self:setFillTypEvent({fillTypeIndex, onFirstRun}, noEventSend)   	
end

function GC_Baler:setFillTypEvent(data, noEventSend)    
	self:raiseEvent(self.eventId_setFillTyp, data, noEventSend)
	if data[2] == nil or not data[2] then
		self.unloadTrigger.fillTypes = nil
		self.unloadTrigger:setAcceptedFillTypeState(data[1], true)

		if self.hasStack then
			self.needMove = self.stackerBaleTrigger:getNum() > 0
		else
			self.needMove = not self.mainBaleTrigger:getTriggerEmpty()
		end
	end
	self.activeFillTypeIndex = data[1] 
end

function GC_Baler:setBaleObjectToAnimation(noEventSend)
	self:setBaleObjectToAnimationEvent({}, noEventSend)   
end

function GC_Baler:setBaleObjectToAnimationEvent(data, noEventSend)
	self:raiseEvent(self.eventId_setBaleObjectToAnimation, data, noEventSend)
	if g_dedicatedServerInfo == nil then
		for _,info in pairs (self.baleAnimationObjects) do
			if info.fillTypeIndex == self.activeFillTypeIndex then
				local newBale = clone(info.node, false, false, false)
				setVisibility(newBale, true)
				link(self.animationManager:getPartsOfAnimation("baleAnimation")[1].node, newBale)	
				break
			end
		end
	end
end

function GC_Baler:removeBaleObjectFromFork(noEventSend)
	self:removeBaleObjectFromForkEvent({}, noEventSend)   
end

function GC_Baler:removeBaleObjectFromForkEvent(data, noEventSend)
	self:raiseEvent(self.eventId_removeBaleObjectFromForkEvent, data, noEventSend)
	for i=1, getNumOfChildren(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node) do
		local child = getChildAt(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node, 0)
		if self.isServer then
			self:createBale(child)
		end
		delete(child)	
	end
end

function GC_Baler:removeBaleObjectFromAnimation(noEventSend)
	self:removeBaleObjectFromAnimationEvent({}, noEventSend)   
end

function GC_Baler:removeBaleObjectFromAnimationEvent(data, noEventSend)
	self:raiseEvent(self.eventId_removeBaleObjectFromAnimationEvent, data, noEventSend)	
	self.animationManager:setAnimationTime("baleAnimation", 0)
	if getNumOfChildren(self.animationManager:getPartsOfAnimation("baleAnimation")[1].node) > 0 then
		delete(getChildAt(self.animationManager:getPartsOfAnimation("baleAnimation")[1].node, 0))
	end
end

function GC_Baler:setBaleObjectToFork(noEventSend)
	self:setBaleObjectToForkEvent({}, noEventSend)   
end

function GC_Baler:setBaleObjectToForkEvent(data, noEventSend)
	self:raiseEvent(self.eventId_setBaleObjectToFork, data, noEventSend)
	for _,info in pairs (self.baleAnimationObjects) do
		if info.fillTypeIndex == self.activeFillTypeIndex then
			for i=1, self.stackerBaleTrigger:getNum() do
				local newBale = clone(info.node, false, false, false)
				setVisibility(newBale, true)
				setTranslation(newBale, 0.015, 0.958 + (i-1)*0.8,-0.063)
				link(self.animationManager:getPartsOfAnimation("stackAnimation")[1].node, newBale)		
			end
			break
		end
	end
end

function GC_Baler:canUnloadBale()
	local canUnloadBale = self.animationManager:getAnimationTime("baleAnimation") == 0
	if canUnloadBale and self.hasStack then
		canUnloadBale = self.stackerBaleTrigger:getTriggerEmpty() and self.animationState ~= GC_Baler.ANIMATION_ISSTACKING and self.animationState ~= GC_Baler.ANIMATION_ISSTACKINGEND
	elseif canUnloadBale and not self.hasStack then
		canUnloadBale = self.mainBaleTrigger:getTriggerEmpty()
	end	

	if canUnloadBale and self.state_balerMove == GC_Baler.STATE_ON then
		canUnloadBale = false
	end
	return canUnloadBale
end

function GC_Baler:createBale(ref)
	local t = self.fillTypeToBaleType[self.activeFillTypeIndex]
	local baleType = g_baleTypeManager:getBale(self.activeFillTypeIndex, false, t.width, t.height, t.length, t.diameter)	
	local filename = Utils.getFilename(baleType.filename, "")
	local baleObject = Bale:new(self.isServer, g_client ~= nil)
	local x,y,z = getWorldTranslation(ref)
	local rx,ry,rz = getWorldRotation(ref)
	baleObject:load(filename, x,y,z,rx,ry,rz, 4000)
	baleObject:setOwnerFarmId(self:getOwnerFarmId(), true)
	baleObject:register()
	baleObject:setCanBeSold(false)
	if self.hasStack then
		table.insert(self.stackBales, baleObject)
	end
end

function GC_Baler:selfonTurnOnBaler(noEventSend)		
	self:selfonTurnOnBalerEvent({}, noEventSend)   
end

function GC_Baler:selfonTurnOnBalerEvent(data, noEventSend)			
	self:raiseEvent(self.eventId_selfonTurnOnBaler, data, noEventSend)
	self.state_baler = GC_Baler.STATE_ON

	if self.isServer then
		self:raiseActive()
	end

	--if g_dedicatedServerInfo == nil then
		self.conveyorFillTypeEffect:setFillType(self.activeFillTypeIndex)
		self.conveyorFillTypeEffect:start()
		self.conveyorFillType:start()
	--end
end

function GC_Baler:onTurnOffGC_Baler(noEventSend)	
	self:onTurnOffGC_BalerEvent({}, noEventSend)   
end

function GC_Baler:onTurnOffGC_BalerEvent(data, noEventSend)	
	self:raiseEvent(self.eventId_onTurnOffGC_Baler, data, noEventSend)
	self.state_baler = GC_Baler.STATE_OFF

	--if g_dedicatedServerInfo == nil then
		self.conveyorFillTypeEffect:stop()
		self.conveyorFillType:stop()
	--end
end

function GC_Baler:onTurnOnStacker(noEventSend)
	self:onTurnOnStackerEvent({}, noEventSend)  	
end

function GC_Baler:onTurnOnStackerEvent(data, noEventSend)	
	self:raiseEvent(self.eventId_onTurnOnStacker, data, noEventSend)
	self.state_stacker = GC_Baler.STATE_ON
	
	if self.isServer then
		self:raiseActive()
	end
end

function GC_Baler:onTurnOffStacker(noEventSend)	
	self:onTurnOffStackerEvent({}, noEventSend)  	
end

function GC_Baler:onTurnOffStackerEvent(data, noEventSend)	
	self:raiseEvent(self.eventId_onTurnOffStacker, data, noEventSend)
	self.state_stacker = GC_Baler.STATE_OFF
end

function GC_Baler:onTurnOnBaleMover(noEventSend)	
	self:onTurnOnBaleMoverEvent({}, noEventSend)  	
end

function GC_Baler:onTurnOnBaleMoverEvent(data, noEventSend)	
	self:raiseEvent(self.eventId_onTurnOnBaleMover, data, noEventSend)
	self.state_balerMove = GC_Baler.STATE_ON
	
	if self.isServer then
		self:raiseActive()
		setFrictionVelocity(self.baleMoveCollision, 0.8)		
		if self.hasStack then		
			self.conveyorStacker:start()
		end
		self.conveyorMover:start()
	end
end

function GC_Baler:onTurnOffBaleMover(noEventSend)	
	self:onTurnOffBaleMoverEvent({}, noEventSend)  	
end

function GC_Baler:onTurnOffBaleMoverEvent(data, noEventSend)	
	self:raiseEvent(self.eventId_onTurnOffBaleMover, data, noEventSend)
	self.state_balerMove = GC_Baler.STATE_OFF

	if self.isServer then
		setFrictionVelocity(self.baleMoveCollision, 0.0)	
		if self.hasStack then		
			self.conveyorStacker:stop()
		end
		self.conveyorMover:stop()
	end
end

function GC_Baler:setStackBalesTarget(num, noEventSend)
	self:setStackBalesTargetEvent({num}, noEventSend)
end

function GC_Baler:setStackBalesTargetEvent(data, noEventSend)
	self:raiseEvent(self.eventId_baleTarget, data, noEventSend)
	self.stackBalesTarget = data[1]
end

function GC_Baler:setAutoOn(state, noEventSend)
	self:setAutoOnEvent({state}, noEventSend)
end

function GC_Baler:setAutoOnEvent(data, noEventSend)
	self:raiseEvent(self.eventId_setAutoOn, data, noEventSend)
	self.autoOn = data[1]
	if self.isServer and self.autoOn and self.fillLevel > 4000 and self.state_baler == GC_Baler.STATE_OFF then
		self:selfonTurnOnBaler()
		self:onTurnOnStacker()
	end
end

function GC_Baler:getCanChangeFillType()
	return self.state_baler == GC_Baler.STATE_OFF and self.fillLevel == 0 and self.fillLevelBunker == 0	 
end

function GC_Baler:getCanTurnOn()
	return self.state_baler == GC_Baler.STATE_OFF and self.fillLevel >= 4000
end

function GC_Baler:doTurnOn()
	self:selfonTurnOnBaler()
	self:onTurnOnStacker()
end

function GC_Baler:doTurnOff()
	self.shouldTurnOff = true
end

function GC_Baler:onEnterBaleTrigger(ref, bale)
	if ref ==  GC_Baler.BALETRIGGER_MAIN and self.hasStack then
		local alreadyExist = false
		for k,b in pairs(self.stackBales) do
			if b == bale then
				alreadyExist = true
				break
			end
		end
		if not alreadyExist then
			table.insert(self.stackBales, bale)
		end
	end
end

function GC_Baler:onLeaveBaleTrigger(ref, bale)
	if ref ==  GC_Baler.BALETRIGGER_MAIN then
		for k,b in pairs(self.stackBales) do
			if b == bale then
				table.remove(self.stackBales, k)
				break
			end
		end
	end
end

function GC_Baler:getIsOn()
	return self.state_baler == GC_Baler.STATE_ON
end

function GC_Baler:resetBaleTrigger(noEventSend)
	self:resetBaleTriggerEvent({}, noEventSend)  	
end

function GC_Baler:resetBaleTriggerEvent(data, noEventSend)	
	self:raiseEvent(self.eventId_resetBaleTrigger, data, noEventSend)	
	self.stackerBaleTrigger:reset()
end

function GC_Baler:inkBaleCounter(noEventSend)
	self:inkBaleCounterEvent({}, noEventSend)  	
end

function GC_Baler:inkBaleCounterEvent(data, noEventSend)	
	self:raiseEvent(self.eventId_inkBaleCounter, data, noEventSend)	
	self.baleCounter = self.baleCounter + 1
	if g_dedicatedServerInfo == nil then		
		self.digitalDisplayNum:updateLevelDisplays(self.baleCounter, 9999999999)
	end
end



