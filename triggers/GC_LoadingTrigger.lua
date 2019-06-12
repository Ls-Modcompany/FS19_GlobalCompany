--
-- GlobalCompany - Triggers - GC_LoadingTrigger
--
-- @Interface: --
-- @Author: LS-Modcompany / GtX
-- @Date: 11.03.2019
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (11.03.2019):
-- 		- fix i3dMappings support for effects
--
-- 	v1.0.0.0 (12.02.2019):
-- 		- initial fs19 (GtX)
--
-- Notes:
--		- Some script functions part referenced - https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=67&class=10416
--
--
-- ToDo:
--
--

GC_LoadingTrigger = {}

local GC_LoadingTrigger_mt = Class(GC_LoadingTrigger, LoadTrigger)
InitObjectClass(GC_LoadingTrigger, "GC_LoadingTrigger")

GC_LoadingTrigger.debugIndex = g_company.debug:registerScriptName("GC_LoadingTrigger")

GC_LoadingTrigger.statusNames = {"noObject", "foundObject", "fillingActive"}

g_company.loadingTrigger = GC_LoadingTrigger

function GC_LoadingTrigger:new(isServer, isClient, customMt)
	local self = LoadTrigger:new(isServer, isClient, customMt or GC_LoadingTrigger_mt)

	self.registerTriggerInStream = true

	self.fillableObjects = {}
	self.extraParamater = nil

	self.playerTriggerNode = nil
	self.playerInTrigger = false

	self.triggerStatus = nil
	self.triggerStatusUpdate = -1

	self.stationName = "SILO"

	return self
end

function GC_LoadingTrigger:load(nodeId, source, xmlFile, xmlKey, forcedFillTypes, infiniteCapacity, blockUICapacity)
	if nodeId == nil or source == nil or xmlFile == nil or xmlKey == nil then
		local text = "Loading failed! 'nodeId' parameter = %s, 'source' parameter = %s 'xmlFile' parameter = %s, 'xmlKey' parameter = %s"
		g_company.debug:logWrite(GC_LoadingTrigger.debugIndex, GC_DebugUtils.DEV, text, nodeId ~= nil, source ~= nil, xmlFile ~= nil, xmlKey ~= nil)
		return false
	end

	self.debugData = g_company.debug:getDebugData(GC_LoadingTrigger.debugIndex, source)

	self.rootNode = nodeId
	self.source = source

	local xmlUtils = g_company.xmlUtils

	local triggerNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. "#triggerNode"), source.i3dMappings)
	if triggerNode ~= nil and source.getProvidedFillTypes ~= nil and source.getAllProvidedFillLevels ~= nil and source.getProvidedFillLevel ~= nil and source.removeFillLevel ~= nil then
		self.triggerNode = triggerNode
		addTrigger(triggerNode, "loadTriggerCallback", self)
		g_currentMission:addNodeObject(triggerNode, self)

		self.fillLitersPerMS = xmlUtils.getXMLValue(getXMLInt, xmlFile, xmlKey .. "#fillLitersPerSecond", 1000) / 1000
		self.soundNode = createTransformGroup("loadTriggerSoundNode")

		self.autoStart = xmlUtils.getXMLValue(getXMLBool, xmlFile, xmlKey .. "#autoStart", false)
		self.hasInfiniteCapacity = Utils.getNoNil(infiniteCapacity, false)
		self.blockUICapacity = Utils.getNoNil(blockUICapacity, false)

		local startText = xmlUtils.getXMLValue(getXMLString, xmlFile, xmlKey .. "#startText", "action_siloStartFilling")
		local stopText = xmlUtils.getXMLValue(getXMLString, xmlFile, xmlKey .. "#stopText", "action_siloStopFilling")
		self.startFillText = g_company.languageManager:getText(startText)
		self.stopFillText = g_company.languageManager:getText(stopText)

		self.isLoading = false
		self.activateText = self.startFillText
		self.selectedFillType = FillType.UNKNOWN

		local dischargeNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".dischargeInfo#node"), source.i3dMappings)
		if dischargeNode ~= nil then
			self.dischargeInfo = {}
			self.dischargeInfo.name = "fillVolumeDischargeInfo"
			local width = xmlUtils.getXMLValue(getXMLFloat, xmlFile, xmlKey .. ".dischargeInfo#width", 0.5)
			local length = xmlUtils.getXMLValue(getXMLFloat, xmlFile, xmlKey .. ".dischargeInfo#length", 0.5)
			self.dischargeInfo.nodes = {node = dischargeNode, width = width, length = length, priority = 1}

			link(dischargeNode, self.soundNode)
		else
			link(triggerNode, self.soundNode)
		end

		local fillTypes = forcedFillTypes
		if fillTypes == nil then
			local fillTypeNames = getXMLString(xmlFile, xmlKey .. "#fillTypes") --Allow adding by fillTypes
			local fillTypeCategories = getXMLString(xmlFile, xmlKey .. "#fillTypeCategories") -- Allow adding by FillTypeCategories.

			if fillTypeCategories ~= nil and fillTypeNames == nil then
				local warning = self.debugData.header .. "Warning: Invalid fillTypeCategory '%s' given at " .. xmlKey .. "."
				fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategories, warning)
			elseif fillTypeNames ~= nil then
				local warning = self.debugData.header .. "Warning: Invalid fillType '%s' given at " .. xmlKey .. "."
				fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeNames, warning)
			end
		end

		if fillTypes ~= nil then
			for _, fillTypeInt in pairs(fillTypes) do
				self:setAcceptedFillTypeState(fillTypeInt, true)
			end
		else
			self.fillTypes = nil
		end

		if self.isClient then
			self.samples = {}
			local fillSoundNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".sounds#fillSoundNode"), source.i3dMappings)
			if fillSoundNode == nil then
				fillSoundNode = self.rootNode
			end

			local fillSoundIdentifier = getXMLString(xmlFile, xmlKey .. ".sounds#fillSoundIdentifier")
			local xmlSoundFile = loadXMLFile("mapXML", g_currentMission.missionInfo.mapSoundXmlFilename)
			if xmlSoundFile ~= nil and xmlSoundFile ~= 0 then
				local directory = g_currentMission.baseDirectory
				local modName, baseDirectory = Utils.getModNameAndBaseDirectory(g_currentMission.missionInfo.mapSoundXmlFilename)
				if modName ~= nil then
					directory = baseDirectory .. modName
				end

				if fillSoundIdentifier ~= nil then
					self.samples.load = g_soundManager:loadSampleFromXML(xmlSoundFile, "sound.object", fillSoundIdentifier, directory, getRootNode(), 0, AudioGroup.ENVIRONMENT, nil, nil)
					if self.samples.load ~= nil then
						link(fillSoundNode, self.samples.load.soundNode)
						setTranslation(self.samples.load.soundNode, 0, 0, 0)
					end
				end
				delete(xmlSoundFile)
			end

			self.scroller = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".scroller#node"), source.i3dMappings)
			if self.scroller ~= nil then
				self.scrollerShaderParameterName = xmlUtils.getXMLValue(getXMLString, xmlFile, xmlKey .. ".scroller#shaderParameterName", "uvScrollSpeed")
				self.scrollerSpeedX = xmlUtils.getXMLValue(getXMLFloat, xmlFile, xmlKey .. ".scroller#speedX", 0)
				self.scrollerSpeedY = xmlUtils.getXMLValue(getXMLFloat, xmlFile, xmlKey .. ".scroller#speedY", -0.75)
				setShaderParameter(self.scroller, self.scrollerShaderParameterName, 0, 0, 0, 0, false)
			end

			self.effects = g_effectManager:loadEffect(xmlFile, xmlKey, nodeId, self, source.i3dMappings)

			-- Animations that are activated when filling is started and stopped when filling is ended. (Source script must have active 'animationManager'! See ProductionFactory.lua)
			-- Example: Handle and lights for a real look. (Only operates 'Client Side').
			if self.source.animationManager ~= nil then
				local fillingAnimation = self.source.animationManager:loadAnimationNameFromXML(xmlFile, xmlKey .. ".actionAnimation")
				if fillingAnimation ~= nil then
					self.fillingAnimation = fillingAnimation
				end
			end

			-- These are options to show trigger markers depending on the trailer/trigger status.
			-- Options: fallOffShader(like 'serviceVehicle markers'), statusVisNodes(visibility)).
			if hasXMLProperty(xmlFile, xmlKey .. ".triggerStatus") then
				self.triggerStatus = {}

				local fallOffShaderNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".triggerStatus.fallOffShader#node"), source.i3dMappings)
				if fallOffShaderNode ~= nil then
					local fallOffKey = xmlKey .. ".triggerStatus.fallOffShader"
					self.triggerStatus.fallOffShader = {node = fallOffShaderNode}
					setVisibility(fallOffShaderNode, true)

					local isActive = Utils.getNoNil(getXMLBool(xmlFile, fallOffKey .. ".noObject#isActive"), true)
					local rgb = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, fallOffKey .. ".noObject#rgb", 3, false, self.debugData, {0.2122, 0.5271, 0.0307})
					self.triggerStatus.fallOffShader.noObject = {isActive = isActive, rgb = rgb}
					setShaderParameter(fallOffShaderNode, "colorScale", rgb[1], rgb[2], rgb[3], 1, false)

					isActive = Utils.getNoNil(getXMLBool(xmlFile, fallOffKey .. ".foundObject#isActive"), true)
					rgb = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, fallOffKey .. ".foundObject#rgb", 3, false, self.debugData, {0.9301, 0.2874, 0.0130})
					self.triggerStatus.fallOffShader.foundObject = {isActive = isActive, rgb = rgb}

					isActive = Utils.getNoNil(getXMLBool(xmlFile, fallOffKey .. ".fillingActive#isActive"), false)
					rgb = GlobalCompanyXmlUtils.getNumbersFromXMLString(xmlFile, fallOffKey .. ".fillingActive#rgb", 3, false, self.debugData, {0.8069, 0.0097, 0.0097})
					self.triggerStatus.fallOffShader.fillingActive = {isActive = isActive, rgb = rgb}

					g_currentMission:addTriggerMarker(fallOffShaderNode)
				end

				if hasXMLProperty(xmlFile, xmlKey..".triggerStatus.visNodes") then
					local visNodesKey = xmlKey..".triggerStatus.visNodes"

					local noObjectNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, visNodesKey .. "#noObjectNode"), source.i3dMappings)
					if noObjectNode ~= nil then
						setVisibility(noObjectNode, true)
						self.triggerStatus.visNodes = {noObject = noObjectNode}
					end

					local foundObjectNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, visNodesKey.."#foundObjectNode"), source.i3dMappings)
					if foundObjectNode ~= nil then
						setVisibility(foundObjectNode, false)

						if self.triggerStatus.visNodes == nil then
							self.triggerStatus.visNodes = {}
						end
						self.triggerStatus.visNodes.foundObject = foundObjectNode
					end

					local fillingActiveNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, visNodesKey.."#fillingActiveNode"), source.i3dMappings)
					if fillingActiveNode ~= nil then
						setVisibility(fillingActiveNode, false)

						if self.triggerStatus.visNodes == nil then
							self.triggerStatus.visNodes = {}
						end
						self.triggerStatus.visNodes.fillingActive = fillingActiveNode
					end
				end

				if self.triggerStatus.fallOffShader == nil and self.triggerStatus.visNodes == nil then
					self.triggerStatus = nil
				end
			end
		end

		-- When used the filling can only be started when not in vehicle.
		local playerTriggerNode = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, xmlKey .. ".externalOperation#playerTriggerNode"), source.i3dMappings)
		if playerTriggerNode ~= nil then
			if playerTriggerNode ~= nil then
				self.playerTriggerNode = playerTriggerNode
				addTrigger(self.playerTriggerNode, "playerTriggerCallback", self)
			end
		end

		return true
	else
		-- We could use 'assert' but then we would have no header. -)
		local prefix = g_company.debug.printLevelPrefix[g_company.debug.MODDING]
		g_company.debug:printHeader(self.debugData)

		if triggerNode == nil then
			g_company.debug:print("    %s'triggerNode' could not be found.", prefix)
		end

		if source.getProvidedFillTypes == nil then
			g_company.debug:print("    %s Target function 'getProvidedFillTypes' could not be found!", prefix)
		end

		if source.getAllProvidedFillLevels == nil then
			g_company.debug:print("    %s Target function 'getAllProvidedFillLevels' could not be found!", prefix)
		end

		if  source.getProvidedFillLevel == nil then
			g_company.debug:print("    %s Target function 'getProvidedFillLevel' could not be found!", prefix)
		end

		if source.removeFillLevel == nil then
			g_company.debug:print("    %s Target function 'removeFillLevel' could not be found!", prefix)
		end
	end

	return false
end

function GC_LoadingTrigger:delete()
	if self.playerTriggerNode ~= nil then
		removeTrigger(self.playerTriggerNode)
		self.playerTriggerNode = nil
	end

	if self.triggerStatus ~= nil and self.triggerStatus.fallOffShader ~= nil then
		local node = self.triggerStatus.fallOffShader.node
		g_currentMission:removeTriggerMarker(node)
	end

	GC_LoadingTrigger:superClass().delete(self)
end

function GC_LoadingTrigger:setStationName(name)
	if name ~= nil then
		self.stationName = name
	end
end

function GC_LoadingTrigger:setAcceptedFillTypeState(fillTypeInt, state)
	if self.fillTypes == nil then
		self.fillTypes = {}
	end

	self.fillTypes[fillTypeInt] = state
end

function GC_LoadingTrigger:update(dt)
	if self.isServer then
		if self.isLoading then
			if self.currentFillableObject ~= nil then
				local fillDelta = self:addFillLevelToFillableObject(self.currentFillableObject, self.fillUnitIndex, self.selectedFillType, self.fillLitersPerMS * dt, self.dischargeInfo, ToolType.TRIGGER)
				if fillDelta == nil or fillDelta < 0.001 then
					self:setIsLoading(false)
				end
			elseif self.isLoading then
				self:setIsLoading(false)
			end

			self:raiseActive()
		end
	end

	if self.playerTriggerNode ~= nil and self.playerInTrigger then
		if g_currentMission.controlPlayer and g_currentMission.controlledVehicle == nil then
			self:raiseActive()
		else
			self.playerInTrigger = false
		end
	end
end

function GC_LoadingTrigger:updateTriggerStatus(name)
	self.triggerStatusState = name

	if self.triggerStatus.fallOffShader ~= nil then
		local node = self.triggerStatus.fallOffShader.node
		local typ = self.triggerStatus.fallOffShader[name]
		if typ ~= nil then
			local state = typ.isActive and (g_gameSettings ~= nil and g_gameSettings.showTriggerMarker)
			setShaderParameter(node, "colorScale", typ.rgb[1], typ.rgb[2], typ.rgb[3], 1, false)
			setVisibility(node, state)
		end
	end

	if self.triggerStatus.visNodes ~= nil then
		for statusName, node in pairs (self.triggerStatus.visNodes) do
			setVisibility(node, name == statusName)
		end
	end
end

function GC_LoadingTrigger:addFillLevelToFillableObject(fillableObject, fillUnitIndex, fillTypeIndex, fillDelta, fillInfo, toolType)
	if fillableObject == nil or fillTypeIndex == FillType.UNKNOWN or fillDelta == 0 or toolType == nil then
		return 0
	end

	local farmId = fillableObject:getOwnerFarmId()
	if fillableObject:isa(Vehicle) then
		farmId = fillableObject:getActiveFarm()
	end

	local availableFillLevel = self.source:getProvidedFillLevel(fillTypeIndex, farmId, self.extraParamater)
	fillDelta = math.min(fillDelta, availableFillLevel)
	if fillDelta <= 0 then
		return 0
	end

	local usedFillLevel = fillableObject:addFillUnitFillLevel(farmId, fillUnitIndex, fillDelta, fillTypeIndex, toolType, fillInfo)
	local appliedFillLevel = usedFillLevel

	local newFillLevel
	local oldFillLevel = self.source:getProvidedFillLevel(fillTypeIndex, farmId, self.extraParamater)
	if oldFillLevel > 0 then
		newFillLevel = self.source:removeFillLevel(farmId, usedFillLevel, fillTypeIndex, self.extraParamater)
	end
	if newFillLevel == nil then
		newFillLevel = self.source:getProvidedFillLevel(fillTypeIndex, farmId, self.extraParamater)
	end

	usedFillLevel = usedFillLevel - (oldFillLevel - newFillLevel)
	if usedFillLevel < 0.0001 then
		usedFillLevel = 0
	end

	fillDelta = appliedFillLevel - usedFillLevel

	return fillDelta
end

function GC_LoadingTrigger:onActivateObject()
	if not self.isLoading then
		local fillLevels, capacity = self.source:getAllProvidedFillLevels(g_currentMission:getFarmId(), self.extraParamater)
		local fillableObject = self.validFillableObject
		local fillUnitIndex = self.validFillableFillUnitIndex
		local firstFillType = nil
		local validFillLevels = {}

		for fillTypeIndex, fillLevel in pairs(fillLevels) do
			if self.fillTypes == nil or self.fillTypes[fillTypeIndex] then
				if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) then
					validFillLevels[fillTypeIndex] = fillLevel
					if firstFillType == nil then
						firstFillType = fillTypeIndex
					end
				end
			end
		end

		if not self.autoStart then
			local text
			if self.hasInfiniteCapacity or self.blockUICapacity then
				text = string.format("%s", self.stationName)
			else
				text = string.format("%s (%s)", self.stationName, g_i18n:formatFluid(capacity))
			end
			g_gui:showSiloDialog({title = text, fillLevels = validFillLevels, capacity = capacity, callback = self.onFillTypeSelection, target = self, hasInfiniteCapacity = self.hasInfiniteCapacity})
		else
			self:onFillTypeSelection(firstFillType)
		end
	else
		self:setIsLoading(false)
	end

	g_currentMission:addActivatableObject(self)
end

function GC_LoadingTrigger:getIsActivatable()
	if next(self.fillableObjects) == nil then
		return false
	else
		if self.isLoading then
			if self.playerTriggerNode ~= nil then
				return self.playerInTrigger and self.currentFillableObject ~= nil
			else
				if self.currentFillableObject ~= nil and self.currentFillableObject:getRootVehicle() == g_currentMission.controlledVehicle then
					return true
				end
			end
		else
			if self.playerTriggerNode ~= nil and not self.playerInTrigger then
				return false
			end

			self.validFillableObject = nil
			self.validFillableFillUnitIndex = nil
			local hasLowPrioObject = false
			local numOfObjects = 0
			for _, fillableObject in pairs(self.fillableObjects) do
				if fillableObject.lastWasFilled then
					hasLowPrioObject = true
				end

				numOfObjects = numOfObjects + 1
			end

			hasLowPrioObject = hasLowPrioObject and (numOfObjects > 1)
			for _, fillableObject in pairs(self.fillableObjects) do
				if not fillableObject.lastWasFilled or not hasLowPrioObject then
					local canActivate = false
					if self.playerTriggerNode ~= nil then
						canActivate = self.playerInTrigger -- Need to Test.
					else
						canActivate = fillableObject.object:getRootVehicle() == g_currentMission.controlledVehicle
					end

					if canActivate then
						if fillableObject.object:getFillUnitSupportsToolType(fillableObject.fillUnitIndex, ToolType.TRIGGER) then
							if self:getIsFillAllowedToFarm(self:farmIdForFillableObject(fillableObject.object)) then
								self.validFillableObject = fillableObject.object
								self.validFillableFillUnitIndex = fillableObject.fillUnitIndex

								return true
							else
								return false
							end
						end
					end
				end
			end
		end
	end

	return false
end

function GC_LoadingTrigger:shouldRemoveActivatable()
	return self.playerTriggerNode == nil
end

function GC_LoadingTrigger:onFillTypeSelection(fillTypeIndex)
	if fillTypeIndex ~= nil and fillTypeIndex ~= FillType.UNKNOWN then
		local validFillableObject = self.validFillableObject
		if validFillableObject ~= nil then
			local canActivate = validFillableObject:getRootVehicle() == g_currentMission.controlledVehicle
			if self.playerTriggerNode ~= nil then
				canActivate = true
			end

			if canActivate then
				local fillUnitIndex = self.validFillableFillUnitIndex
				self:setIsLoading(true, validFillableObject, fillUnitIndex, fillTypeIndex)
			end
		end
	end
end

function GC_LoadingTrigger:setIsLoading(isLoading, targetObject, fillUnitIndex, fillType, noEventSend)
	GC_LoadingTrigger:superClass().setIsLoading(self, isLoading, targetObject, fillUnitIndex, fillType, noEventSend)

	if self.isClient then
		if self.triggerStatus ~= nil then
			if isLoading then
				self:updateTriggerStatus("fillingActive")
			else
				if self.triggerStatusState ~= "noObject" and self.triggerStatusState ~= "foundObject" then
					self:updateTriggerStatus("foundObject")
				end
			end
		end

		if self.source.animationManager ~= nil and self.fillingAnimation ~= nil then
			self.source.animationManager:setAnimationByState(self.fillingAnimation, isLoading, true)
		end
	end
end

function GC_LoadingTrigger:getIsFillAllowedToFarm(farmId)
	if g_currentMission.accessHandler:canFarmAccess(farmId, self.source) then
		return true
	end

	return false
end

function GC_LoadingTrigger:loadTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local fillableObject = g_currentMission:getNodeObject(otherId)
	if fillableObject ~= nil then
		if fillableObject ~= self.source and fillableObject.getRootVehicle ~= nil and fillableObject.getFillUnitIndexFromNode ~= nil then
			local fillTypes = self.source:getProvidedFillTypes(self.extraParamater)
			if fillTypes ~= nil then
				local foundFillUnitIndex = fillableObject:getFillUnitIndexFromNode(otherId)
				if foundFillUnitIndex ~= nil then
					local found = false
					for fillTypeIndex, state in pairs(fillTypes) do
						if state and (self.fillTypes == nil or self.fillTypes[fillTypeIndex]) then
							if fillableObject:getFillUnitSupportsFillType(foundFillUnitIndex, fillTypeIndex) then
								if fillableObject:getFillUnitAllowsFillType(foundFillUnitIndex, fillTypeIndex) then
									found = true
									break
								end
							end
						end
					end

					if not found then
						foundFillUnitIndex = nil
					end
				end

				if foundFillUnitIndex == nil then
					for fillTypeIndex, state in pairs(fillTypes) do
						if state and (self.fillTypes == nil or self.fillTypes[fillTypeIndex]) then
							local fillUnits = fillableObject:getFillUnits()
							for fillUnitIndex, fillUnit in ipairs(fillUnits) do
								if fillUnit.exactFillRootNode == nil then
									if fillableObject:getFillUnitSupportsFillType(fillUnitIndex, fillTypeIndex) then
										if fillableObject:getFillUnitAllowsFillType(fillUnitIndex, fillTypeIndex) then
											foundFillUnitIndex = fillUnitIndex
											break
										end
									end
								end
							end
						end
					end
				end

				if foundFillUnitIndex ~= nil then
					if onEnter then
						self.fillableObjects[otherId] = {object = fillableObject, fillUnitIndex = foundFillUnitIndex}
					elseif onLeave then
						self.fillableObjects[otherId] = nil
						if self.isLoading and self.currentFillableObject == fillableObject then
							self:setIsLoading(false)
						end
					end

					if next(self.fillableObjects) ~= nil then
						g_currentMission:addActivatableObject(self)

						if self.isClient and self.triggerStatus ~= nil then
							if self.triggerStatusState ~= "foundObject" then
								self:updateTriggerStatus("foundObject")
							end
						end
					else
						g_currentMission:removeActivatableObject(self)

						if self.isClient and self.triggerStatus ~= nil then
							if self.triggerStatusState ~= "noObject" then
								self:updateTriggerStatus("noObject")
							end
						end
					end
				end
			end
		end
	end
end

function GC_LoadingTrigger:playerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if g_currentMission.controlPlayer and (g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode) then
		if onEnter or onLeave then
			if onEnter then
				if not self.playerInTrigger then
					if g_currentMission.accessHandler:canFarmAccess(g_currentMission:getFarmId(), self.source) then
						self.playerInTrigger = true
					end
				end
			else
				self.playerInTrigger = false
			end

			self:raiseActive()
		end
	end
end