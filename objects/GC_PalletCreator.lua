--
-- GlobalCompany - Objects - GC_PalletCreator
--
-- @Interface: 1.4.0.0 b5007
-- @Author: LS-Modcompany
-- @Date: 04.08.2019
-- @Version: 1.1.1.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.1.1.0 (04.08.2019):
-- 		- y offset is not taken from the node unless lower than terrain.
--
-- 	v1.1.0.0 (08.03.2019):
-- 		- convert to fs19
--
-- 	v1.0.0.0 (26.06.2018):
-- 		- initial fs17 ()
--
-- Notes:
--		- Parent script 'MUST' call delete().
--		- Parent script should call 'loadFromXMLFile' and 'saveToXMLFile' to save/load fillLevel that has not yet been added to a pallet.
--		- Parent script should set warnings on load using 'setWarningText(parentName, outputName)'. [outputName] is optional.
--
--		- Using 'activateDebugDraw' in the xml file will display debug boxes and text showing spawn box only when 'Key F6' is pressed. This is for testing only!
--
--
-- ToDo:
--
--

GC_PalletCreator = {}
local GC_PalletCreator_mt = Class(GC_PalletCreator, Object)
InitObjectClass(GC_PalletCreator, "GC_PalletCreator")

GC_PalletCreator.ALLOW_OFFSET_ADDON = false -- Disable addon if it tries to load. Not needed when updated.

GC_PalletCreator.debugIndex = g_company.debug:registerScriptName("GC_PalletCreator")

g_company.palletCreator = GC_PalletCreator

function GC_PalletCreator:new(isServer, isClient, customMt)
	local self = Object:new(isServer, isClient, customMt or GC_PalletCreator_mt)

	self.extraParamater = nil
	self.triggerManagerRegister = true

	self.deltaToAdd = 0
	self.warningText = ""
	self.fullPallet = nil
	self.otherObject = nil
	self.palletToUse = nil
	self.spawnerInUse = nil
	self.locatedNodeId = nil
	self.selectedPallet = nil
	self.numberOfSpawners = 0

	return self
end

function GC_PalletCreator:load(nodeId, target, xmlFile, xmlKey, baseDirectory, permittedFillTypeIndex)
	if nodeId == nil or target == nil  then
		return false
	end

	self.debugData = g_company.debug:getDebugData(GC_PalletCreator.debugIndex, target)

	self.rootNode = nodeId
	self.target = target

	self.baseDirectory = GlobalCompanyUtils.getParentBaseDirectory(target, baseDirectory)

	if self.target.getOwnerFarmId == nil then
		g_company.debug:writeModding(self.debugData, "Parent script does not contain function 'getOwnerFarmId()'! This is a minimum requirement.")
		return false
	end

	if self.target.palletCreatorInteraction == nil then
		g_company.debug:writeModding(self.debugData, "Parent script does not contain function 'palletCreatorInteraction(totalLevel, blockedLevel, deltaWaiting, fillTypeIndex, extraParamater)'.")
		return false
	end

	local returnValue = false
	local palletCreatorsKey = string.format("%s.palletCreators", xmlKey)

	local fillTypeName = getXMLString(xmlFile, palletCreatorsKey .. "#fillType")
	local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
	if fillTypeIndex ~= nil then
		if permittedFillTypeIndex == nil then
			permittedFillTypeIndex = fillTypeIndex
		end

		if fillTypeIndex == permittedFillTypeIndex then
			local filename = Utils.getNoNil(getXMLString(xmlFile, palletCreatorsKey .. "#xmlFilename"), "")
			self.palletFilename = Utils.getFilename(filename, self.baseDirectory)
			if self.palletFilename ~= nil and self.palletFilename ~= "" then
				local storeItem = g_storeManager:getItemByXMLFilename(self.palletFilename)
				if storeItem ~= nil then
					self.palletFillTypeIndex = fillTypeIndex
					self.palletFillUnitIndex = Utils.getNoNil(getXMLFloat(xmlFile, palletCreatorsKey .. "#fillUnitIndex"), 1)

					local palletCapacity = getXMLFloat(xmlFile, palletCreatorsKey .. "#palletCapacity")
					self.palletCapacity = math.max(Utils.getNoNil(palletCapacity, 0), 0)

					if self.palletCapacity > 0 then
						local sizeWidth, sizeLength, widthOffset, lengthOffset = StoreItemUtil.getSizeValues(self.palletFilename, "vehicle", 0, {})
						if sizeWidth ~= nil and sizeLength ~= nil then
							self.palletSizeWidth = sizeWidth
							self.palletSizeLength = sizeLength
							self.palletSizeWidthExtent = sizeWidth * 0.5
							self.palletSizeLengthExtent = sizeLength * 0.5

							local startFill = Utils.getNoNil(getXMLFloat(xmlFile, palletCreatorsKey .. "#startFillThreshold"), 0.75)
							self.startFillThreshold = math.max(startFill, 0.75) -- Minimum we will accept is 0.75 litres.

							self.showWarnings = Utils.getNoNil(getXMLBool(xmlFile, palletCreatorsKey .. "#showWarnings"), true)
							local warningInterval = Utils.getNoNil(getXMLInt(xmlFile, palletCreatorsKey .. "#minWarningInterval"), 5) -- Default five minutes between warnings.
							self.warningInterval = math.max(warningInterval, 1) * 60000
							self.nextWarningTime = g_currentMission.time

							local i = 0
							while true do
								local key = string.format("%s.palletCreator(%d)", palletCreatorsKey, i)
								if not hasXMLProperty(xmlFile, key) then
									break
								end

								local node = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, key .. "#node"), target.i3dMappings)
								if node ~= nil then
									if self.palletSpawners ~= nil then
										table.insert(self.palletSpawners, node)
									else
										self.palletSpawners = {node}
									end

									local palletInteractionTrigger = I3DUtil.indexToObject(nodeId, getXMLString(xmlFile, key .. "#palletInteractionTrigger"), target.i3dMappings)
									if palletInteractionTrigger ~= nil then
										if self.palletInteractionTriggers == nil then
											self.palletInteractionTriggers = {}
										end

										if self.isServer then
											addTrigger(palletInteractionTrigger, "palletInteractionTriggerCallback", self)
										end

										table.insert(self.palletInteractionTriggers, palletInteractionTrigger)
									end
								end

								i = i + 1
							end

							self.numberOfSpawners = #self.palletSpawners

							if self.numberOfSpawners > 0 then
								local activateDebugDraw = Utils.getNoNil(getXMLBool(xmlFile, palletCreatorsKey .. "#activateDebugDraw"), false)
								if self.isClient and activateDebugDraw then
									self.debugDrawData = {}
									for i = 1, self.numberOfSpawners do
										self.debugDrawData[i] = {name = "", id = ""}
										self.debugDrawData[i].name = getName(self.palletSpawners[i])
										self.debugDrawData[i].id = string.format("<palletCreator(%d) />", i - 1)
										self.debugDrawData[i].colours = {0.5, 1.0, 0.5, 1.0}
									end

									self:raiseActive()
									g_company.debug:writeWarning(self.debugData, "'drawDebug' is active at %s#activateDebugDraw! Make sure to disable this before release.", palletCreatorsKey)
								end

								if self.isServer then
									self:setPalletCreatorId()
								end

								returnValue = true
							else
								g_company.debug:writeModding(self.debugData, "No 'palletCreator' nodes have been found at %s", palletCreatorsKey)
							end
						end
					else
						g_company.debug:writeModding(self.debugData, "No 'palletCapacity' has been given, this should match capacity given in pallet xml file. ( %s )", palletCreatorsKey)
					end
				else
					g_company.debug:writeModding(self.debugData, "A store item using xml filename '%s' could not be found. ( %s#xmlFilename )", self.palletFilename, palletCreatorsKey)
				end
			else
				g_company.debug:writeModding(self.debugData, "'xmlFilename' key is 'nil' at %s#xmlFilename", palletCreatorsKey)
			end
		end
	end

	return returnValue
end

function GC_PalletCreator:delete()
	if self.isClient and self.debugDrawData ~= nil then
		g_company.removeUpdateable(self)
	end

	if self.isServer then
		if self.palletInteractionTriggers ~= nil then
			for i = 1, #self.palletInteractionTriggers do
				removeTrigger(self.palletInteractionTriggers[i])
			end
			self.palletInteractionTriggers = nil
		end
	end
end

function GC_PalletCreator:update(dt)
	if self.isServer and self.levelCheckTimer ~= nil then
		if self.levelCheckTimer > 0 then
			self.levelCheckTimer = self.levelCheckTimer - dt
			self:raiseActive()
		else
			local level, blockedLevel = self:getTotalFillLevel(true, false)
			self.target:palletCreatorInteraction(level, blockedLevel, self.deltaToAdd, self.palletFillTypeIndex, self.extraParamater)
			self.levelCheckTimer = nil
		end
	end

	if self.isClient and self.debugDrawData ~= nil then
		self:debugDrawUpdate(dt)
		self:raiseActive()
	end
end

function GC_PalletCreator:debugDrawUpdate(dt)
	if self.debugDrawData ~= nil then
		for i = 1, self.numberOfSpawners do
			local spawner = self.palletSpawners[i]
			local x, y, z = getWorldTranslation(spawner)
			local rx, ry, rz = getWorldRotation(spawner)
			DebugUtil.drawDebugNode(spawner, nil)
			DebugUtil.drawOverlapBox(x, y - 5, z, rx, ry, rz, self.palletSizeWidthExtent, 10, self.palletSizeLengthExtent, 0.5, 1.0, 0.5)
			Utils.renderTextAtWorldPosition(x, y + 5.5, z, self.debugDrawData[i].name, getCorrectTextSize(0.018), 0, self.debugDrawData[i].colours)
			Utils.renderTextAtWorldPosition(x, y + 5, z, self.debugDrawData[i].id, getCorrectTextSize(0.018), 0, self.debugDrawData[i].colours)
		end
	end
end

function GC_PalletCreator:updatePalletCreators(delta, includeDeltaToAdd)
	if self.isServer then
		self.deltaToAdd = self.deltaToAdd + delta

		if self.deltaToAdd > 0 then
			local totalFillLevel = self:getTotalFillLevel(false, false)

			local appliedDelta = 0
			if self.selectedPallet ~= nil then
				if self:checkPalletIsValid() then
					appliedDelta = self.selectedPallet:addFillUnitFillLevel(self:getOwnerFarmId(), self.palletFillUnitIndex, self.deltaToAdd, self.palletFillTypeIndex, ToolType.UNDEFINED)
					self.deltaToAdd = self.deltaToAdd - appliedDelta
					totalFillLevel = totalFillLevel + appliedDelta

					if self.deltaToAdd > 0 and self.deltaToAdd > self.startFillThreshold then
						appliedDelta = self:findNextPallet()
						totalFillLevel = totalFillLevel + appliedDelta
					end
				else
					if self.deltaToAdd > self.startFillThreshold then
						appliedDelta = self:findNextPallet()
						totalFillLevel = totalFillLevel + appliedDelta
					end
				end
			else
				if self.deltaToAdd > self.startFillThreshold then
					appliedDelta = self:findNextPallet()
					totalFillLevel = totalFillLevel + appliedDelta
				end
			end

			if appliedDelta <= 0 then
				if includeDeltaToAdd then
					totalFillLevel = totalFillLevel + self.deltaToAdd
				end
			end

			return totalFillLevel, appliedDelta > 0
		end
	end
end

function GC_PalletCreator:checkPalletIsValid()
	if self.spawnerInUse == nil then
		return false
	end

	local selectedPallet = self.selectedPallet
	if entityExists(selectedPallet.rootNode) then
		if selectedPallet:getFillUnitFreeCapacity(self.palletFillUnitIndex) < 0.001 then
			return false
		end

		local x, _, z = localToLocal(selectedPallet.rootNode, self.spawnerInUse, 0, 0, 0)
		if x < 0 or z < 0 or x > self.palletSizeWidth or z > self.palletSizeLength then
			return false
		end
	else
		return false
	end

	return true
end

function GC_PalletCreator:findNextPallet()
	local nextSpawnerToUse
	self.selectedPallet = nil

	-- Fill all of the started pallets first.
	for i = 1, self.numberOfSpawners do
		local spawner = self.palletSpawners[i]

		self.locatedNodeId = 0
		self.palletToUse = nil
		self:checkSpawner(spawner)

		if self.palletToUse ~= nil then
			self.spawnerInUse = spawner
			self.selectedPallet = self.palletToUse
			break
		else
			if nextSpawnerToUse == nil then
				if self.locatedNodeId == 0 then
					nextSpawnerToUse = {spawner = spawner, spawnerId = i}
				end
			end
		end
	end

	-- If no pallets to fill then find a free node to create a new one at.
	if self.selectedPallet ~= nil then
		local appliedDelta = self.selectedPallet:addFillUnitFillLevel(self:getOwnerFarmId(), self.palletFillUnitIndex, self.deltaToAdd, self.palletFillTypeIndex, ToolType.UNDEFINED)
		self.deltaToAdd = self.deltaToAdd - appliedDelta

		return appliedDelta
	else
		if nextSpawnerToUse ~= nil then
			self.spawnerInUse = nextSpawnerToUse.spawner
			local x, y, z = getWorldTranslation(self.spawnerInUse)
			local rx, ry, rz = getWorldRotation(self.spawnerInUse)
			
			--Thanks to grouminait! https://ls-modcompany.com/forum/thread/5655-gc-palletcreator-optionen/?postID=67874#post67874
			if g_company.utils.floatEqual(math.abs(math.deg(rx)), 180, 1) and g_company.utils.floatEqual(math.abs(math.deg(rz)), 180, 1) then
				rx = math.rad(0)
				ry = math.rad(-math.deg(ry))
				rz = math.rad(0)
			end

			local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z) + 0.5
            y = math.max(terrainHeight, y)

            self.selectedPallet = g_currentMission:loadVehicle(self.palletFilename, x, y, z, 0, ry, true, 0, Vehicle.PROPERTY_STATE_OWNED, self:getOwnerFarmId(), nil, nil)

			local appliedDelta = self.selectedPallet:addFillUnitFillLevel(self:getOwnerFarmId(), self.palletFillUnitIndex, self.deltaToAdd, self.palletFillTypeIndex, ToolType.UNDEFINED)
			self.deltaToAdd = self.deltaToAdd - appliedDelta

			self.spawnedPallet = self.selectedPallet
			self:setPalletCreatorId(self.selectedPallet, false)

			return appliedDelta
		else
			if self:canShowWarning() then
				self:showWarningMessage()
			end
		end
	end

	return 0
end

function GC_PalletCreator:checkSpawner(spawner)
	self.spawner = spawner
	local x, y, z = getWorldTranslation(spawner)
	local rx, ry, rz = getWorldRotation(spawner)
	local overlap = overlapBox(x, y - 5, z, rx, ry, rz, self.palletSizeWidthExtent, 10, self.palletSizeLengthExtent, "spawnAreaCallback", self, nil, true, false, true)

	return x, y, z, rx, ry, rz, overlap
end

function GC_PalletCreator:spawnAreaCallback(transformId)
	if transformId ~= g_currentMission.terrainRootNode and transformId ~= self.spawner then
		local object = g_currentMission:getNodeObject(transformId)
		if object ~= nil and object.isa ~= nil then
			self.locatedNodeId = transformId -- Did we collide with another object?
			if object:isa(Vehicle) then
				if object.typeName == "pallet" then
					if object:getFillUnitSupportsFillType(self.palletFillUnitIndex, self.palletFillTypeIndex) then
						self.palletInSpawner = object
						
						if object:getFillUnitFillLevel(self.palletFillUnitIndex) < object:getFillUnitCapacity(self.palletFillUnitIndex) then
							self.palletToUse = object
						else
							self.fullPallet = object
						end
						
						return
					end
				end
			end
			
			self.otherObject = object
		else
			if transformId ~= nil then
				if g_currentMission.players[transformId] ~= nil or getHasClassId(transformId, ClassIds.MESH_SPLIT_SHAPE) then
					self.locatedNodeId = transformId -- A player or log is in the spawn area.
					self.otherObject = transformId
				end
			end
		end
	end
end

function GC_PalletCreator:loadFromXMLFile(xmlFile, key)
	self.deltaToAdd = Utils.getNoNil(getXMLFloat(xmlFile, key .. ".palletCreator#deltaToAdd"), self.deltaToAdd)

	return true
end

function GC_PalletCreator:saveToXMLFile(xmlFile, key, usedModNames)
	setXMLFloat(xmlFile, key .. ".palletCreator#deltaToAdd", self.deltaToAdd)
end

function GC_PalletCreator:getTotalCapacity()
	return self.palletCapacity * self.numberOfSpawners
end

function GC_PalletCreator:getIndividualCapacity()
	return self.palletCapacity
end

function GC_PalletCreator:getTotalSpace()
	local pallets = {}
	local totalLevel = 0
	local totalCapacity = self.palletCapacity * self.numberOfSpawners

	for i = 1, self.numberOfSpawners do
		self.palletInSpawner = nil
		self.otherObject = nil
		self:checkSpawner(self.palletSpawners[i])

		-- If spawn area is blocked then remove available capacity for this space.
		if self.otherObject ~= nil then
			totalCapacity = totalCapacity - self.palletCapacity
		end

		-- If we have a pallet then add it's level to total.
		if self.palletInSpawner ~= nil then
			if pallets[self.palletInSpawner] == nil then
				pallets[self.palletInSpawner] = true
				totalLevel = totalLevel + self.palletInSpawner:getFillUnitFillLevel(self.palletFillUnitIndex)
			else
				totalCapacity = totalCapacity - self.palletCapacity
			end
		end
	end

	return totalCapacity - totalLevel
end

function GC_PalletCreator:getTotalFillLevel(getBlockedLevel, includeDeltaToAdd)
	local pallets, totalLevel, blockedLevel = {}, 0, 0

	for i = 1, self.numberOfSpawners do
		self.palletInSpawner = nil
		self.otherObject = nil
		self:checkSpawner(self.palletSpawners[i])

		if self.palletInSpawner ~= nil then
			if pallets[self.palletInSpawner] == nil then
				pallets[self.palletInSpawner] = true
				totalLevel = totalLevel + self.palletInSpawner:getFillUnitFillLevel(self.palletFillUnitIndex)
			else
				-- If a pallet is sharing the spawn area with another pallet we count it as lost fill area. (e.g  + pallet capacity for the spawner).
				blockedLevel = blockedLevel + self.palletCapacity
			end
		else
			if self.otherObject ~= nil then
				-- If another object is blocking we count it as lost fill area. (e.g + pallet capacity for the spawner).
				blockedLevel = blockedLevel + self.palletCapacity
			end
		end
	end

	if includeDeltaToAdd == true then
		totalLevel = totalLevel + self.deltaToAdd
	end

	if getBlockedLevel == true then
		return totalLevel, blockedLevel
	end

	return totalLevel
end

function GC_PalletCreator:getDeltaWaiting()
	return self.deltaToAdd
end

function GC_PalletCreator:getNumFullPallets()
	local count = 0

	for i = 1, self.numberOfSpawners do
		self.fullPallet = nil
		self:checkSpawner(self.palletSpawners[i])
		if self.fullPallet ~= nil then
			count = count + 1
		end
	end

	return count
end

function GC_PalletCreator:getOwnerFarmId()
	local targetOwnerFarmId = self.target:getOwnerFarmId()
	return g_company.utils.getCorrectValue(targetOwnerFarmId, 1, 0)
end

function GC_PalletCreator:setWarningText(parentName, outputName)
	local fillTypeName = Utils.getNoNil(outputName, "")
	local fillType = g_fillTypeManager:getFillTypeByIndex(self.palletFillTypeIndex)
	if fillType ~= nil then
		fillTypeName = fillType.title
	end

	local textBase = g_company.languageManager:getText("ingameNotification_palletSpawnerBlocked")
	self.warningText = string.format(textBase, fillTypeName, parentName)
end

function GC_PalletCreator:canShowWarning(ignoreTime)
	if ignoreTime then
		return self.showWarnings
	end

	return self.showWarnings and self.nextWarningTime < g_currentMission.time
end

function GC_PalletCreator:showWarningMessage()
	if self.warningText ~= nil and self.warningText ~= "" then
		if self.isServer then
			self.nextWarningTime = g_currentMission.time + self.warningInterval
			g_server:broadcastEvent(GC_PalletCreatorWarningEvent:new(self))
		end

		g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, self.warningText)
	end
end

function GC_PalletCreator:palletInteractionTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter or onLeave then
		local object = g_currentMission:getNodeObject(otherShapeId)
		if object ~= nil and (object.isa ~= nil and object:isa(Vehicle)) and object.typeName == "pallet" then
			if self.spawnedPallet ~= object then
				self:setPalletCreatorId(object, onLeave)
				self.levelCheckTimer = 2000
				self:raiseActive()
			else
				self.spawnedPallet = nil
			end
		end
	end
end

function GC_PalletCreator:setPalletCreatorId(pallet, onLeave)
	if pallet ~= nil then
		if onLeave then
			if pallet.gcPalletCreatorId ~= nil then
				if pallet.removeDeleteListener ~= nil then
					pallet:removeDeleteListener(self, "onDeletePallet")
				end

				pallet.gcPalletCreatorId = nil
			end
		else
			if pallet.unmountDynamic ~= nil and pallet.gcPalletCreatorId == nil then
				pallet.gcPalletCreatorId = NetworkUtil.getObjectId(self)
				pallet.unmountDynamic = Utils.appendedFunction(pallet.unmountDynamic, GC_PalletCreator.unmountDynamic)
				if pallet.addDeleteListener ~= nil then
					pallet:addDeleteListener(self, "onDeletePallet")
				end
			end
		end
	else
		for i = 1, self.numberOfSpawners do
			self.palletInSpawner = nil
			self:checkSpawner(self.palletSpawners[i])
			if self.palletInSpawner ~= nil then
				if self.palletInSpawner.unmountDynamic ~= nil and self.palletInSpawner.gcPalletCreatorId == nil then
					self.palletInSpawner.gcPalletCreatorId = NetworkUtil.getObjectId(self)
					self.palletInSpawner.unmountDynamic = Utils.appendedFunction(self.palletInSpawner.unmountDynamic, GC_PalletCreator.unmountDynamic)
					if self.palletInSpawner.addDeleteListener ~= nil then
						self.palletInSpawner:addDeleteListener(self, "onDeletePallet")
					end
				end
			end
		end
	end
end

function GC_PalletCreator:unmountDynamic(isDelete)
	if self.gcPalletCreatorId ~= nil then
		local object = NetworkUtil.getObject(self.gcPalletCreatorId)
		if object ~= nil then
			object.levelCheckTimer = 2000
			object:raiseActive()

			if self.removeDeleteListener ~= nil then
				self:removeDeleteListener(object, "onDeletePallet")
			end
		end

		self.gcPalletCreatorId = nil
	end
end

function GC_PalletCreator:onDeletePallet(pallet)
	if pallet.gcPalletCreatorId ~= nil then
		local object = NetworkUtil.getObject(pallet.gcPalletCreatorId)
		if object ~= nil then
			object.levelCheckTimer = 2000
			object:raiseActive()
		end

		pallet.gcPalletCreatorId = nil
	end
end